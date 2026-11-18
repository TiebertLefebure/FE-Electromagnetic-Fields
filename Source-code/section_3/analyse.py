"""Integrate the exported P1 solution, including the complete massive current."""
import json
from math import pi, sqrt

import numpy as np

MU0 = 4*pi*1e-7


def read_mesh(path):
    lines = path.read_text().splitlines()
    start = lines.index('$Nodes') + 1
    nodes = np.array([list(map(float, s.split())) for s in lines[start+1:start+1+int(lines[start])]])
    coordinates = np.zeros((int(nodes[:, 0].max())+1, 2))
    coordinates[nodes[:, 0].astype(int)] = nodes[:, 1:3]
    start = lines.index('$Elements') + 1
    triangles, regions, boundary = [], [], set()
    for line in lines[start+1:start+1+int(lines[start])]:
        row = list(map(int, line.split()))
        if row[1] == 2:
            triangles.append(row[3+row[2]:])
            regions.append(row[3])
        elif row[1] == 1 and row[3] == 901:
            boundary.update(row[3+row[2]:])
    return coordinates, np.array(triangles), np.array(regions), boundary


def triangle_geometry(coordinates, triangles):
    xy = coordinates[triangles]
    dx = xy[:, [1, 2, 0], 0] - xy[:, [2, 0, 1], 0]
    dy = xy[:, [1, 2, 0], 1] - xy[:, [2, 0, 1], 1]
    determinant = np.sum(xy[:, :, 0] * dy, axis=1)
    area = abs(determinant)/2
    lengths = np.sqrt(dx**2 + dy**2)
    quality = 4*sqrt(3)*area/np.sum(lengths**2, axis=1)
    return area, dy/determinant[:, None], -dx/determinant[:, None], lengths, quality


def analyse(directory, parameters, options):
    xy, triangles, regions, boundary = read_mesh(directory/'model.msh')
    mesh_edges = np.sort(np.concatenate([triangles[:, [0,1]], triangles[:, [1,2]], triangles[:, [2,0]]]), axis=1)
    unique_edges, counts = np.unique(mesh_edges, axis=0, return_counts=True)
    if counts.max() != 2 or any(not set(edge) <= boundary for edge in unique_edges[counts == 1]):
        raise ValueError('The mesh contains an open internal interface or a nonmanifold edge.')
    area, gx, gy, edges, quality = triangle_geometry(xy, triangles)
    nodes = np.loadtxt(directory/'potential.txt', skiprows=1)
    potential = np.zeros(len(xy), dtype=complex)
    potential[nodes[:, 0].astype(int)] = nodes[:, 1] + 1j*nodes[:, 2]
    a = potential[triangles]
    magnetic = np.column_stack((np.sum(gy*a, axis=1), -np.sum(gx*a, axis=1)))
    bnorm = np.sqrt(np.sum(abs(magnetic)**2, axis=1))
    massive = sorted({105, 205, 305, 900}
                     | (set() if options['Stranded'] else {100, 200, 300})
                     | ({101, 103, 104, 201, 203, 204, 301, 303, 304} if options['Detailed'] else set()))
    data = np.loadtxt(directory/'gradients.txt').reshape(-1)[1:]
    if len(data) != 2*len(massive):
        raise ValueError('Unexpected GetDP region-gradient table')
    gradients = dict(zip(massive, data[0::2]+1j*data[1::2]))
    omega = 2*pi*options['Freq']
    iphase = sqrt(2)*parameters['Current']*np.exp(-2j*pi*np.arange(3)/3)
    jnodes = np.zeros_like(a)
    losses = np.zeros(len(triangles))
    details = {}
    for region in sorted(set(regions)):
        mask = regions == region
        layer = region % 100
        sigma = (parameters['SigmaSoil'] if region == 900 else
                 parameters['SigmaAl'] if layer == 0 else
                 parameters['SigmaCu'] if layer == 5 and options['Screens'] else
                 1e-12 if layer == 5 else
                 parameters['SigmaSC'] if options['Detailed'] and layer in (1, 3, 4) else 0)
        if region == 900:
            sigma = options.get('SigmaSoil', sigma)
        region_area = area[mask].sum()
        if region in (100,200,300) and options['Stranded']:
            current = iphase[region//100-1]
            jnodes[mask] = current/region_area
            drop = current/(sigma*region_area) + 1j*omega*np.sum(area[mask]*a[mask].mean(axis=1))/region_area
        elif region in gradients:
            jnodes[mask] = -sigma*(1j*omega*a[mask]+gradients[region])
            current = np.sum(area[mask]*jnodes[mask].mean(axis=1))
            drop = -gradients[region]
        else:
            continue
        # The P1 current is linear. This is the exact quadratic mass integral.
        norm_integral = area[mask]/12*(np.sum(abs(jnodes[mask])**2, axis=1)
                                     + abs(jnodes[mask].sum(axis=1))**2)
        losses[mask] = norm_integral/(2*sigma) if sigma else 0
        details[str(region)] = dict(area_m2=float(region_area), conductivity_S_m=sigma,
            current_peak_A=[float(current.real), float(current.imag)],
            voltage_drop_peak_V_m=[float(drop.real), float(drop.imag)],
            loss_W_m=float(losses[mask].sum()),
            max_J_peak_A_mm2=float(abs(jnodes[mask]).max()/1e6))
    conductor_loss = sum(details[str(r)]['loss_W_m'] for r in (100, 200, 300))
    screen_loss = sum(details[str(r)]['loss_W_m'] for r in (105, 205, 305))
    total_loss = losses.sum()
    energy = np.sum(area*bnorm**2)/(4*MU0)
    complex_power = sum(complex(*details[str(r)]['voltage_drop_peak_V_m'])*np.conj(iphase[k])/2
                        for k, r in enumerate((100, 200, 300)))
    current_error = max(abs(complex(*details[str(r)]['current_peak_A'])-iphase[k])/abs(iphase[k])
                        for k, r in enumerate((100, 200, 300)))
    conducting = np.isin(regions, massive + ([100, 200, 300] if options['Stranded'] else [])) & (regions != 900)
    mesh_checks = {}
    for name, ids, sigma in [('aluminium', [100, 200, 300], parameters['SigmaAl']),
                             ('copper', [105, 205, 305], parameters['SigmaCu']),
                             ('soil', [900], parameters['SigmaSoil'])]:
        skin = sqrt(2/(omega*MU0*sigma))
        selected = np.isin(regions, ids)
        mesh_checks[name] = dict(skin_depth_mm=skin*1000,
            max_edge_mm=float(edges[selected].max()*1000),
            max_edge_over_skin=float(edges[selected].max()/skin))
    metrics = dict(options=options, complex_dofs=len(np.unique(triangles))-len(boundary)
                   +len(massive)-len([r for r in massive if r in (105,205,305,900) and
                                     (r == 900 or not options['SinglePoint'])]),
        triangles=len(triangles), regions=details, mesh=mesh_checks,
        min_quality=float(quality.min()), conducting_min_quality=float(quality[conducting].min()),
        loss_conductors_W_m=conductor_loss, loss_screens_W_m=screen_loss,
        loss_soil_W_m=details['900']['loss_W_m'],
        loss_semiconductors_W_m=sum(v['loss_W_m'] for r,v in details.items() if int(r)%100 in (1,3,4)),
        loss_total_W_m=float(total_loss), resistance_ohm_km=float(total_loss/(3*parameters['Current']**2)*1000),
        inductance_mH_km=float(2*energy/(3*parameters['Current']**2)*1e6),
        energy_time_average_J_m=float(energy), complex_input_power_VA_m=[float(complex_power.real),float(complex_power.imag)],
        power_balance_relative=float(abs(complex_power.real-total_loss)/total_loss),
        reactive_balance_relative=float(abs(complex_power.imag-2*omega*energy)/(2*omega*energy)),
        phase_current_relative_error=float(current_error), max_B_phasor_mT=float(bnorm.max()*1000),
        phase_R_ohm_km=[float((complex(*details[str(r)]['voltage_drop_peak_V_m'])/iphase[k]).real*1000)
                        for k,r in enumerate((100,200,300))],
        phase_L_mH_km=[float((complex(*details[str(r)]['voltage_drop_peak_V_m'])/iphase[k]).imag/omega*1e6)
                      for k,r in enumerate((100,200,300))])
    zero_current_regions = [r for r in massive if r%100 in (1,3,4) or
                            (options['SinglePoint'] and r in (105,205,305))]
    zero_current_error = max((abs(complex(*details[str(r)]['current_peak_A']))/abs(iphase[0])
                              for r in zero_current_regions), default=0)
    metrics['zero_net_current_relative_error'] = float(zero_current_error)
    if max(current_error,zero_current_error) > 1e-7 or metrics['power_balance_relative'] > 1e-6 or metrics['reactive_balance_relative'] > 1e-6:
        raise ValueError(f'Current or power balance failed: {metrics}')
    np.savez_compressed(directory/'fields.npz', coordinates=xy, triangles=triangles, regions=regions,
                        potential=potential, magnetic=magnetic, current=jnodes,
                        loss_density=losses/area, quality=quality)
    (directory/'metrics.json').write_text(json.dumps(metrics, indent=2)+'\n')
    return metrics


def write_views(directory):
    data = np.load(directory/'fields.npz')
    xy = data['coordinates'][data['triangles']]
    quantities = [('magnetic_rms','RMS vector norm B [mT]',np.linalg.norm(data['magnetic'],axis=1)/sqrt(2)*1000),
                  ('current_rms','RMS Jz [A/mm2]',abs(data['current']).mean(axis=1)/sqrt(2)/1e6),
                  ('joule_loss','Average Joule loss [W/m3]',data['loss_density'])]
    for filename,title,values in quantities:
        with (directory/f'{filename}.pos').open('w') as f:
            f.write(f'View "{title}" {{\n')
            for points,value in zip(xy,values):
                coords = ','.join(f'{v:.9g}' for point in points for v in (*point,0))
                f.write(f'ST({coords}){{{value:.9g},{value:.9g},{value:.9g}}};\n')
            f.write('};\n')
    (directory/'view.geo').write_text('Merge "model.msh";\nMerge "magnetic_rms.pos";\n'
        'Merge "current_rms.pos";\nMerge "joule_loss.pos";\n'
        'Mesh.SurfaceEdges=0; Geometry.Points=0;\nView[1].Visible=0; View[2].Visible=0;\n')
