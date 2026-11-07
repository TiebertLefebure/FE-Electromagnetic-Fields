"""Independent P1 post-processing of GetDP nodal voltages (no second FE solver).

Reconstruct constant triangle gradients, integrate energy, and assemble element
reactions to check weak current conservation. All quantities are per metre.
"""
import cmath
import csv
import json
import math
from collections import defaultdict
from pathlib import Path


def read_mesh(path):
    lines = Path(path).read_text().splitlines()
    assert lines[1].startswith('2.2 0 '), 'Expected ASCII Gmsh MSH 2.2'
    i = lines.index('$Nodes')
    nodes = {int(a[0]): (float(a[1]), float(a[2]))
             for a in (line.split() for line in lines[i+2:i+2+int(lines[i+1])])}
    i = lines.index('$Elements')
    triangles, boundaries = [], defaultdict(set)
    for line in lines[i+2:i+2+int(lines[i+1])]:
        a = list(map(int, line.split()))
        kind, ntags = a[1:3]
        tag = a[3]
        ids = a[3+ntags:]
        if kind == 1:
            boundaries[tag].update(ids)
        elif kind == 2:
            triangles.append((a[0], tag, ids))
        else:
            raise ValueError(f'Unsupported element type {kind}; use first-order triangles')
    return nodes, triangles, boundaries


def read_voltages(path):
    lines = Path(path).read_text().splitlines()
    assert len(lines)-1 == int(lines[0])
    values = {}
    for line in lines[1:]:
        a = line.split()
        assert len(a) == 3, 'Expected complex NodeTable (node, real, imaginary)'
        values[int(a[0])] = complex(float(a[1]), float(a[2]))
    return values


def material(tag, materials):
    name = 'void' if tag == 106 else ('xlpe' if tag % 100 == 2 else 'semiconductor')
    m = materials[name]
    return name, m['conductivity_S_m'], materials['vacuum_permittivity_F_m']*m['relative_permittivity']


class Locator:
    """Spatial bins for element-local, unsmoothed field samples."""
    def __init__(self, elements, step=0.001):
        self.step, self.bins = step, defaultdict(list)
        for t in elements:
            xs, ys = zip(*t['xy'])
            for i in range(math.floor(min(xs)/step), math.floor(max(xs)/step)+1):
                for j in range(math.floor(min(ys)/step), math.floor(max(ys)/step)+1):
                    self.bins[i,j].append(t)

    def at(self, x, y):
        for t in self.bins[math.floor(x/self.step), math.floor(y/self.step)]:
            x0,y0 = t['xy'][0]
            n1 = t['grad'][1][0]*(x-x0)+t['grad'][1][1]*(y-y0)
            n2 = t['grad'][2][0]*(x-x0)+t['grad'][2][1]*(y-y0)
            if min(1-n1-n2,n1,n2) >= -1e-9:
                return t
        raise ValueError(f'Point ({x},{y}) outside solved mesh')


def analyse(directory, params, materials, options):
    directory = Path(directory)
    nodes, triangles, boundaries = read_mesh(directory/'cable.msh')
    voltages = read_voltages(directory/'potential_nodes.txt')
    omega = 2*math.pi*options['Freq']
    peak = params['line_voltage_rms_V']*math.sqrt(2/3)
    reactions = defaultdict(complex)
    phases = {k: dict(epsilon_integral=0., loss_W_m=0., max_xlpe_peak_kV_mm=0.,
                     max_void_peak_kV_mm=0., inner_screen_peak_kV_mm=0.,
                     outer_screen_peak_kV_mm=0.) for k in 'ABC'}
    r1 = params['conductor_diameter_mm']/2000 + params['inner_semiconductor_mm']/1000
    r2 = r1 + params['xlpe_mm']/1000 + options['ExtraXLPE']
    spacing = params['single_cable_diameter_mm']/1000+2*options['ExtraXLPE']
    centres = [(0,spacing/math.sqrt(3)),(-spacing/2,-spacing/(2*math.sqrt(3))),
               (spacing/2,-spacing/(2*math.sqrt(3)))]
    elements = []
    for number,tag,ids in triangles:
        xy = [nodes[n] for n in ids]
        (x0,y0),(x1,y1),(x2,y2) = xy
        det = (x1-x0)*(y2-y0)-(x2-x0)*(y1-y0)
        assert abs(det) > 1e-20
        area = abs(det)/2
        grad = [((y1-y2)/det,(x2-x1)/det),((y2-y0)/det,(x0-x2)/det),
                ((y0-y1)/det,(x1-x0)/det)]
        ex = -sum(voltages[n]*g[0] for n,g in zip(ids,grad))
        ey = -sum(voltages[n]*g[1] for n,g in zip(ids,grad))
        e2 = abs(ex)**2+abs(ey)**2
        name,sigma,eps = material(tag,materials)
        gamma = complex(sigma,omega*eps)
        phase_index = tag//100-1
        stats = phases['ABC'[phase_index]]
        stats['epsilon_integral'] += area*eps*e2
        stats['loss_W_m'] += 0.5*area*sigma*e2
        for node,g in zip(ids,grad):
            reactions[node] -= area*gamma*(ex*g[0]+ey*g[1])
        if name == 'xlpe':
            field = math.sqrt(e2)/1e6
            stats['max_xlpe_peak_kV_mm'] = max(stats['max_xlpe_peak_kV_mm'],field)
            cx,cy = centres[phase_index]
            radii = [math.hypot(x-cx,y-cy) for x,y in xy]
            for radius,key in [(r1,'inner_screen_peak_kV_mm'),(r2,'outer_screen_peak_kV_mm')]:
                if sum(abs(r-radius)<1e-9 for r in radii) >= 2:
                    stats[key] = max(stats[key],field)
        if name == 'void':
            stats['max_void_peak_kV_mm'] = max(stats['max_void_peak_kV_mm'],math.sqrt(e2)/1e6)
        elements.append(dict(number=number,tag=tag,xy=xy,grad=grad,E=(ex,ey),
                             gamma=gamma,sigma=sigma,eps=eps,material=name))
    for k,key in enumerate('ABC'):
        stat = phases[key]
        inner = sum(reactions[n] for n in boundaries[1001+100*k])
        outer = sum(reactions[n] for n in boundaries[1002+100*k])
        voltage = peak*cmath.exp(-2j*math.pi*k/3)
        y = inner/voltage
        stat.update(capacitance_uF_km=y.imag/omega*1e9,
                    energy_capacitance_uF_km=stat.pop('epsilon_integral')/peak**2*1e9,
                    conductance_S_m=y.real,
                    terminal_current_peak_A_m=[inner.real,inner.imag],
                    terminal_balance_relative=abs(inner+outer)/abs(inner),
                    input_loss_W_m=0.5*(voltage.conjugate()*inner).real)
        assert abs(stat['capacitance_uF_km']/stat['energy_capacitance_uF_km']-1) < 1e-6
        assert stat['terminal_balance_relative'] < 1e-5
    constrained = set().union(*boundaries.values())
    free = set(voltages)-constrained
    max_free = max(abs(reactions[n]) for n in free)
    relative_residual = max_free/abs(complex(*phases['A']['terminal_current_peak_A_m']))
    assert relative_residual < 1e-6, f'Unbalanced weak residual: {relative_residual}'
    # Verify Dirichlet phases, so an absent physical group cannot silently yield v=0.
    for k in range(3):
        target = peak*cmath.exp(-2j*math.pi*k/3)
        assert max(abs(voltages[n]-target) for n in boundaries[1001+100*k]) < 1e-7
        assert max(abs(voltages[n]) for n in boundaries[1002+100*k]) < 1e-9
    locate = Locator(elements)
    cx,cy = centres[0]
    r0 = params['conductor_diameter_mm']/2000
    r4 = math.sqrt((params['diameter_over_copper_mm']/2000)**2-params['copper_area_mm2']*1e-6/math.pi)+options['ExtraXLPE']
    start,stop = (r1,r2) if options['IdealScreens'] else (r0,r4)
    cuts = []
    # Midpoint samples avoid ambiguous values exactly on material interfaces.
    for i in range(600):
        r = start+(stop-start)*(i+0.5)/600
        t = locate.at(cx+r,cy)
        ex,ey = t['E']
        magnitude = math.sqrt(abs(ex)**2+abs(ey)**2)
        cuts.append([r*1000,t['material'],magnitude/1e6,ex.real,ex.imag,ey.real,ey.imag,
                     t['sigma']*magnitude,omega*t['eps']*magnitude])
    with (directory/'radial_cut.csv').open('w') as f:
        writer = csv.writer(f)
        writer.writerow(['radius_mm','material','E_peak_kV_mm','Ex_real_V_m','Ex_imag_V_m',
                         'Ey_real_V_m','Ey_imag_V_m','J_cond_peak_A_m2','J_disp_peak_A_m2'])
        writer.writerows(cuts)
    # Independent raw-gradient contour flux (not an exactly equilibrated H(div) flux).
    contours = []
    for radius in [r1+0.0015, (r1+r2)/2, r2-0.0005]:
        flux = 0j
        for j in range(1024):
            theta=2*math.pi*(j+0.5)/1024
            nx,ny=math.cos(theta),math.sin(theta)
            t=locate.at(cx+radius*nx,cy+radius*ny)
            flux+=t['gamma']*(t['E'][0]*nx+t['E'][1]*ny)*radius*2*math.pi/1024
        terminal = complex(*phases['A']['terminal_current_peak_A_m'])
        contours.append(dict(radius_mm=radius*1000,current_A_m=[flux.real,flux.imag],
                             relative_difference=abs(flux-terminal)/abs(terminal)))
    reference_cap=2*math.pi*materials['vacuum_permittivity_F_m']*materials['xlpe']['relative_permittivity']/math.log(r2/r1)*1e9
    result = dict(options=options,nodes=len(voltages),complex_dofs=len(free),real_dofs=2*len(free),
                  triangles=len(triangles),phases=phases,max_free_residual_relative=relative_residual,
                  contour_flux_checks=contours,analytical_capacitance_uF_km=reference_cap,
                  analytical_inner_peak_kV_mm=peak/(r1*math.log(r2/r1))/1e6,
                  analytical_outer_peak_kV_mm=peak/(r2*math.log(r2/r1))/1e6,
                  datasheet_max_capacitance_uF_km=0.24)
    (directory/'metrics.json').write_text(json.dumps(result,indent=2)+'\n')
    return result
