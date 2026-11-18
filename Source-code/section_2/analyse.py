"""Read GetDP's solution and calculate the quantities requested in Q2.3--Q2.7.

This is post-processing, not a second solver. All calculations use first-order
triangles and peak phasors. Coordinates are metres; integrated results are per metre.
"""
import cmath
import csv
import json
import math
from collections import defaultdict
from pathlib import Path


def read_mesh(path):
    """Read the nodes, triangles and electrode lines of an ASCII MSH 2.2 file."""
    lines = Path(path).read_text().splitlines()
    if not lines[1].startswith('2.2 0 '):
        raise ValueError('Use an ASCII MSH 2.2 mesh with first-order triangles.')

    start = lines.index('$Nodes')
    count = int(lines[start + 1])
    nodes = {}
    for line in lines[start + 2:start + 2 + count]:
        values = line.split()
        nodes[int(values[0])] = (float(values[1]), float(values[2]))

    start = lines.index('$Elements')
    count = int(lines[start + 1])
    triangles = []
    boundaries = defaultdict(set)
    for line in lines[start + 2:start + 2 + count]:
        values = list(map(int, line.split()))
        number, kind, tag_count = values[:3]
        region = values[3]  # First tag = Gmsh physical group.
        node_ids = values[3 + tag_count:]
        if kind == 1:
            boundaries[region].update(node_ids)
        elif kind == 2:
            triangles.append((number, region, node_ids))
        else:
            raise ValueError(f'Unsupported element type {kind}; use first-order triangles.')
    return nodes, triangles, boundaries


def read_voltages(path):
    """GetDP NodeTable rows are: node number, real voltage, imaginary voltage."""
    lines = Path(path).read_text().splitlines()
    if len(lines) - 1 != int(lines[0]):
        raise ValueError('Incomplete GetDP potential_nodes.txt file.')
    voltages = {}
    for line in lines[1:]:
        number, real, imaginary = line.split()
        voltages[int(number)] = complex(float(real), float(imaginary))
    return voltages


def triangle_field(xy, voltage):
    """P1 shape-function gradients are constant within each triangle: E = -grad(v)."""
    (x0, y0), (x1, y1), (x2, y2) = xy
    determinant = (x1 - x0)*(y2 - y0) - (x2 - x0)*(y1 - y0)
    if abs(determinant) < 1e-20:
        raise ValueError('Degenerate triangle in mesh.')
    area = abs(determinant)/2
    gradients = [
        ((y1 - y2)/determinant, (x2 - x1)/determinant),
        ((y2 - y0)/determinant, (x0 - x2)/determinant),
        ((y0 - y1)/determinant, (x1 - x0)/determinant),
    ]
    ex = -sum(v*g[0] for v, g in zip(voltage, gradients))
    ey = -sum(v*g[1] for v, g in zip(voltage, gradients))
    return area, gradients, (ex, ey)


def integrate_elements(nodes, triangles, voltages, materials, omega, centres, ri, ro):
    """Integrate energy/loss, record field maxima, and assemble K_e v_e reactions."""
    phases = {}
    for phase in 'ABC':
        phases[phase] = dict(
            epsilon_integral=0.0, loss_W_m=0.0,
            max_xlpe_peak_kV_mm=0.0, max_void_peak_kV_mm=0.0,
            inner_screen_peak_kV_mm=0.0, outer_screen_peak_kV_mm=0.0,
        )
    reactions = defaultdict(complex)
    elements = []
    for number, region, ids in triangles:
        xy = [nodes[node] for node in ids]
        voltage = [voltages[node] for node in ids]
        area, gradients, (ex, ey) = triangle_field(xy, voltage)
        field_squared = abs(ex)**2 + abs(ey)**2
        if region == 106:
            name = 'void'
        elif region % 100 == 2:
            name = 'xlpe'
        else:
            name = 'semiconductor'
        sigma = materials[name]['conductivity_S_m']
        epsilon = materials['vacuum_permittivity_F_m']*materials[name]['relative_permittivity']
        admittivity = complex(sigma, omega*epsilon)
        phase_index = region//100 - 1  # 1xx = A, 2xx = B, 3xx = C.
        stats = phases['ABC'[phase_index]]
        stats['epsilon_integral'] += area*epsilon*field_squared
        stats['loss_W_m'] += 0.5*area*sigma*field_squared

        # Electrode sums of these nodal reactions give total transverse current.
        for node, gradient in zip(ids, gradients):
            reactions[node] -= area*admittivity*(ex*gradient[0] + ey*gradient[1])
        field = math.sqrt(field_squared)/1e6  # V/m -> kV/mm.
        if name == 'xlpe':
            stats['max_xlpe_peak_kV_mm'] = max(stats['max_xlpe_peak_kV_mm'], field)
            cx, cy = centres[phase_index]
            radii = [math.hypot(x - cx, y - cy) for x, y in xy]
            for radius, key in [(ri, 'inner_screen_peak_kV_mm'), (ro, 'outer_screen_peak_kV_mm')]:
                # Two vertices on the circle identify an interface-edge triangle.
                if sum(abs(r - radius) < 1e-9 for r in radii) >= 2:
                    stats[key] = max(stats[key], field)
        elif name == 'void':
            stats['max_void_peak_kV_mm'] = max(stats['max_void_peak_kV_mm'], field)
        elements.append(dict(xy=xy, grad=gradients, E=(ex, ey), gamma=admittivity,
                             sigma=sigma, eps=epsilon, material=name))
    return phases, reactions, elements


def check_terminals(phases, boundaries, voltages, reactions, peak_voltage, omega):
    """Q2.6/Q2.7: electrode currents, capacitance and weak conservation checks."""
    for index, phase in enumerate('ABC'):
        inner_nodes = boundaries[1001 + 100*index]
        outer_nodes = boundaries[1002 + 100*index]
        if not inner_nodes or not outer_nodes:
            raise ValueError(f'Missing phase {phase} electrode physical group.')
        voltage = peak_voltage*cmath.exp(-2j*math.pi*index/3)
        assert max(abs(voltages[n] - voltage) for n in inner_nodes) < 1e-7, 'Wrong phase voltage'
        assert max(abs(voltages[n]) for n in outer_nodes) < 1e-9, 'Screen is not grounded'
        inner_current = sum(reactions[n] for n in inner_nodes)
        outer_current = sum(reactions[n] for n in outer_nodes)
        admittance = inner_current/voltage
        stats = phases[phase]
        stats['capacitance_uF_km'] = admittance.imag/omega*1e9
        stats['energy_capacitance_uF_km'] = stats.pop('epsilon_integral')/peak_voltage**2*1e9
        stats['conductance_S_m'] = admittance.real
        stats['terminal_current_peak_A_m'] = [inner_current.real, inner_current.imag]
        stats['terminal_balance_relative'] = abs(inner_current + outer_current)/abs(inner_current)
        stats['input_loss_W_m'] = 0.5*(voltage.conjugate()*inner_current).real
        assert stats['terminal_balance_relative'] < 1e-5, 'Electrode currents do not balance'
        cap_ratio = stats['capacitance_uF_km']/stats['energy_capacitance_uF_km']
        assert abs(cap_ratio - 1) < 1e-6, 'Terminal and energy capacitance disagree'

    constrained = set().union(*boundaries.values())
    free_nodes = set(voltages) - constrained
    terminal_current = abs(complex(*phases['A']['terminal_current_peak_A_m']))
    residual = max(abs(reactions[n]) for n in free_nodes)/terminal_current
    assert residual < 1e-6, f'Unbalanced free-node residual: {residual}'
    return len(free_nodes), residual


def make_search_grid(elements, cell_size=0.001):
    """Group triangles into 1 mm squares to find radial-cut points quickly.

    This search grid is only a post-processing aid; it is not another FE mesh.
    """
    grid = defaultdict(list)
    for element in elements:
        xs, ys = zip(*element['xy'])
        for i in range(math.floor(min(xs)/cell_size), math.floor(max(xs)/cell_size) + 1):
            for j in range(math.floor(min(ys)/cell_size), math.floor(max(ys)/cell_size) + 1):
                grid[i, j].append(element)
    return grid


def field_at(x, y, grid, cell_size=0.001):
    """Find the triangle containing a point using its three barycentric weights."""
    key = (math.floor(x/cell_size), math.floor(y/cell_size))
    for element in grid[key]:
        x0, y0 = element['xy'][0]
        gradients = element['grad']
        n1 = gradients[1][0]*(x - x0) + gradients[1][1]*(y - y0)
        n2 = gradients[2][0]*(x - x0) + gradients[2][1]*(y - y0)
        if min(1 - n1 - n2, n1, n2) >= -1e-9:
            return element
    raise ValueError(f'Sampling point ({x}, {y}) lies outside the solved mesh.')


def write_radial_cut(directory, grid, centre, start, stop, omega):
    """Q2.5/Q2.6: sample the +x radius of phase A; retain unsmoothed P1 fields."""
    rows = []
    cx, cy = centre
    for index in range(600):
        radius = start + (stop - start)*(index + 0.5)/600
        element = field_at(cx + radius, cy, grid)
        ex, ey = element['E']
        magnitude = math.sqrt(abs(ex)**2 + abs(ey)**2)
        rows.append([
            radius*1000, element['material'], magnitude/1e6,
            ex.real, ex.imag, ey.real, ey.imag,
            element['sigma']*magnitude, omega*element['eps']*magnitude,
        ])
    with (directory/'radial_cut.csv').open('w', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(['radius_mm', 'material', 'E_peak_kV_mm', 'Ex_real_V_m',
                         'Ex_imag_V_m', 'Ey_real_V_m', 'Ey_imag_V_m',
                         'J_cond_peak_A_m2', 'J_disp_peak_A_m2'])
        writer.writerows(rows)


def contour_currents(grid, centre, ri, ro, terminal_current):
    """Q2.6: integrate J_total.n along three circles, independently of reactions."""
    checks = []
    cx, cy = centre
    for radius in [ri + 0.0015, (ri + ro)/2, ro - 0.0005]:
        current = 0j
        for index in range(1024):
            angle = 2*math.pi*(index + 0.5)/1024
            nx, ny = math.cos(angle), math.sin(angle)
            element = field_at(cx + radius*nx, cy + radius*ny, grid)
            ex, ey = element['E']
            current += element['gamma']*(ex*nx + ey*ny)*radius*2*math.pi/1024
        checks.append(dict(radius_mm=radius*1000, current_A_m=[current.real, current.imag],
                           relative_difference=abs(current - terminal_current)/abs(terminal_current)))
    return checks


def analyse(directory, parameters, materials, options):
    """Read one case, calculate fields/integrals/checks, then save metrics.json."""
    directory = Path(directory)
    nodes, triangles, boundaries = read_mesh(directory/'cable.msh')
    voltages = read_voltages(directory/'potential_nodes.txt')
    omega = 2*math.pi*options['Freq']
    peak_voltage = parameters['line_voltage_rms_V']*math.sqrt(2/3)
    ri = parameters['conductor_diameter_mm']/2000 + parameters['inner_semiconductor_mm']/1000
    ro = ri + parameters['xlpe_mm']/1000 + options['ExtraXLPE']
    spacing = parameters['single_cable_diameter_mm']/1000 + 2*options['ExtraXLPE']
    centres = [(0, spacing/math.sqrt(3)), (-spacing/2, -spacing/(2*math.sqrt(3))),
               (spacing/2, -spacing/(2*math.sqrt(3)))]

    phases, reactions, elements = integrate_elements(
        nodes, triangles, voltages, materials, omega, centres, ri, ro)
    free_dofs, residual = check_terminals(phases, boundaries, voltages, reactions, peak_voltage, omega)
    grid = make_search_grid(elements)
    start = parameters['conductor_diameter_mm']/2000
    stop = math.sqrt((parameters['diameter_over_copper_mm']/2000)**2
                     - parameters['copper_area_mm2']*1e-6/math.pi) + options['ExtraXLPE']
    if options['IdealScreens']:
        start, stop = ri, ro
    write_radial_cut(directory, grid, centres[0], start, stop, omega)
    terminal_current = complex(*phases['A']['terminal_current_peak_A_m'])
    contours = contour_currents(grid, centres[0], ri, ro, terminal_current)
    epsilon = materials['vacuum_permittivity_F_m']*materials['xlpe']['relative_permittivity']
    result = dict(
        options=options, nodes=len(voltages), complex_dofs=free_dofs, real_dofs=2*free_dofs,
        triangles=len(triangles), phases=phases, max_free_residual_relative=residual,
        contour_flux_checks=contours,
        analytical_capacitance_uF_km=2*math.pi*epsilon/math.log(ro/ri)*1e9,
        analytical_inner_peak_kV_mm=peak_voltage/(ri*math.log(ro/ri))/1e6,
        analytical_outer_peak_kV_mm=peak_voltage/(ro*math.log(ro/ri))/1e6,
        datasheet_max_capacitance_uF_km=0.24,
    )
    return result
