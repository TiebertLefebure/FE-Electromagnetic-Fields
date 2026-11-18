"""Cases for Q2.1--Q2.8. run.py calls study(); no FE equations are defined here."""
import csv
import json
import math

from plots import read_cut, write_plot
from prepare import HERE, prepare
from run import command, run_case

# Each entry changes only the listed settings from the healthy baseline.
CASES = {
    'coarse': {'MeshScale': 1},
    'medium': {'MeshScale': 0.5},
    'healthy': {},
    'ideal': {'IdealScreens': 1},
    'void_coarse': {'Defect': 1, 'MeshScale': 0.5},
    'void': {'Defect': 1},
    'thicker_xlpe': {'ExtraXLPE': 0.001},
    'freq_5': {'Freq': 5},
    'freq_500': {'Freq': 500},
    'freq_5000': {'Freq': 5000},
}
QUESTIONS = {
    '2.1': ['healthy'],
    '2.2': ['healthy', 'ideal'],
    '2.3': ['coarse', 'medium', 'healthy'],
    '2.4': ['healthy'],
    '2.5': ['healthy', 'void_coarse', 'void'],
    '2.6': ['healthy', 'void'],
    '2.7': ['healthy', 'freq_5', 'freq_500', 'freq_5000'],
    '2.8': ['healthy', 'thicker_xlpe'],
}


def check_results(results):
    """Numerical tolerances, not material withstand criteria."""
    healthy = results['healthy']
    phase = healthy['phases']['A']
    cap_error = abs(phase['capacitance_uF_km']/healthy['analytical_capacitance_uF_km'] - 1)
    field_error = abs(phase['max_xlpe_peak_kV_mm']/healthy['analytical_inner_peak_kV_mm'] - 1)
    assert cap_error < 0.001, f'Capacitance error: {cap_error:.3%}'
    assert field_error < 0.02, f'Peak field error: {field_error:.3%}'
    assert max(c['relative_difference'] for c in healthy['contour_flux_checks']) < 0.01
    phase_caps = [p['capacitance_uF_km'] for p in healthy['phases'].values()]
    phase_spread = max(phase_caps)/min(phase_caps) - 1
    assert phase_spread < 0.001, 'Phase capacitances differ excessively'
    checks = dict(capacitance_relative_error=cap_error, healthy_peak_field_relative_error=field_error,
                  phase_capacitance_relative_spread=phase_spread)
    if 'coarse' in results and 'medium' in results:
        dofs = [results[name]['complex_dofs'] for name in ['coarse', 'medium', 'healthy']]
        assert dofs[0] < dofs[1] < dofs[2], 'Mesh refinement did not increase the DOF count'
    if 'void' in results and 'void_coarse' in results:
        coarse = results['void_coarse']['phases']['A']['max_void_peak_kV_mm']
        fine = results['void']['phases']['A']['max_void_peak_kV_mm']
        change = abs(fine/coarse - 1)
        assert change < 0.03, f'Void field needs further refinement: {change:.3%}'
        checks['defect_peak_change_last_refinement'] = change
    return checks


def analytical_reference(parameters, materials):
    """Q2.2: exact concentric-layer impedances isolate the ideal-screen approximation."""
    omega = 2*math.pi*50
    eps0 = materials['vacuum_permittivity_F_m']
    r0 = parameters['conductor_diameter_mm']/2000
    ri = r0 + parameters['inner_semiconductor_mm']/1000
    ro = ri + parameters['xlpe_mm']/1000
    copper_inner = math.sqrt((parameters['diameter_over_copper_mm']/2000)**2
                             - parameters['copper_area_mm2']*1e-6/math.pi)
    sc = materials['semiconductor']
    xlpe = materials['xlpe']
    gamma_sc = complex(sc['conductivity_S_m'], omega*eps0*sc['relative_permittivity'])
    gamma_xlpe = complex(xlpe['conductivity_S_m'], omega*eps0*xlpe['relative_permittivity'])
    z_xlpe = math.log(ro/ri)/(2*math.pi*gamma_xlpe)
    z_sc = (math.log(ri/r0) + math.log(copper_inner/ro))/(2*math.pi*gamma_sc)
    admittance = 1/(z_xlpe + z_sc)
    voltage = parameters['line_voltage_rms_V']*math.sqrt(2/3)
    ideal_c = 2*math.pi*eps0*xlpe['relative_permittivity']/math.log(ro/ri)*1e9
    full_c = admittance.imag/omega*1e9
    full_e = abs(admittance*voltage/(2*math.pi*ri*gamma_xlpe))/1e6
    ideal_e = voltage/(ri*math.log(ro/ri))/1e6
    return dict(full_C_uF_km=full_c, ideal_C_uF_km=ideal_c, full_inner_E_peak_kV_mm=full_e,
                relative_XLPE_voltage_drop=abs(z_xlpe/(z_xlpe + z_sc)),
                ideal_minus_full_C_relative=ideal_c/full_c - 1,
                ideal_minus_full_E_relative=ideal_e/full_e - 1,
                model='Concentric-layer series impedances per metre; peak phasors')


def write_comparisons(results, folder):
    """Make only the plots for which this run supplied all required cases."""
    if 'coarse' in results and 'medium' in results:
        names = ['coarse', 'medium', 'healthy']
        field_points, cap_points = [], []
        with (folder/'convergence.csv').open('w', newline='') as stream:
            writer = csv.writer(stream, lineterminator='\n')
            writer.writerow(['case', 'complex_dofs', 'real_dofs', 'C_A_uF_km', 'Emax_XLPE_peak_kV_mm'])
            for name in names:
                case = results[name]
                phase = case['phases']['A']
                dofs = case['complex_dofs']
                field_points.append((dofs, phase['max_xlpe_peak_kV_mm']))
                cap_points.append((dofs, phase['capacitance_uF_km']))
                writer.writerow([name, dofs, case['real_dofs'], phase['capacitance_uF_km'],
                                 phase['max_xlpe_peak_kV_mm']])
        healthy = results['healthy']
        field_reference = [(x, healthy['analytical_inner_peak_kV_mm']) for x, y in field_points]
        cap_reference = [(x, healthy['analytical_capacitance_uF_km']) for x, y in cap_points]
        write_plot(folder/'field_convergence.pos', [('FE', field_points), ('coaxial', field_reference)],
                   'Complex degrees of freedom', 'Peak field [kV/mm]')
        write_plot(folder/'capacitance_convergence.pos', [('FE', cap_points), ('coaxial', cap_reference)],
                   'Complex degrees of freedom', 'Capacitance [uF/km]')
    for name, filename, label in [('void', 'defect_comparison.pos', 'void'),
                                  ('thicker_xlpe', 'design_comparison.pos', '9 mm XLPE')]:
        if name in results:
            healthy = read_cut(HERE/'results/healthy/radial_cut.csv')
            changed = read_cut(HERE/'results'/name/'radial_cut.csv')
            write_plot(folder/filename, [('healthy', healthy), (label, changed)],
                       'Radius from phase A axis [mm]', 'Peak field [kV/mm]')
    if 'void' in results and 'thicker_xlpe' in results:
        curves = [(name, read_cut(HERE/'results'/name/'radial_cut.csv'))
                  for name in ['healthy', 'void', 'thicker_xlpe']]
        write_plot(folder/'radial_comparison.pos', curves, 'Radius from phase A axis [mm]',
                   'Peak field [kV/mm]')


def write_results(summary, folder):
    """A short results index; explanations and sources are in the PDF/README."""
    results = summary['cases']
    lines = ['# Section 2 results', '', 'Run `python3 run.py --study` to regenerate.', '',
             'Fields are peak phasor norms. Capacitance is per phase.', '',
             '| Case | Complex DOFs | C_A (µF/km) | Max XLPE (kV/mm) | Max gas (kV/mm) |',
             '|---|---:|---:|---:|---:|']
    for name, case in results.items():
        phase = case['phases']['A']
        lines.append(f'| {name} | {case["complex_dofs"]} | {phase["capacitance_uF_km"]:.8f} '
                     f'| {phase["max_xlpe_peak_kV_mm"]:.5f} | {phase["max_void_peak_kV_mm"]:.5f} |')
    lines += ['', '## Checks', '']
    for name, value in summary['checks'].items():
        lines.append(f'- {name}: {value:.6g} (relative).')
    lines += ['', '## Where to look', '',
              '- Q2.1/Q2.4: `results/healthy/view.geo` and `metrics.json`.',
              '- Q2.2: `results/ideal/metrics.json` and `validation/analytical_reference.json`.',
              '- Q2.3: `validation/convergence.csv`, `field_convergence.pos`, `capacitance_convergence.pos`.',
              '- Q2.5: `results/void/view.geo` and `validation/defect_comparison.pos`.',
              '- Q2.6: current-density views and conservation checks in `results/healthy/`.',
              '- Q2.7: the frequency cases in `validation/summary.json`.',
              '- Q2.8: `results/thicker_xlpe/view.geo` and `validation/design_comparison.pos`.', '',
              'Paths above are relative to `section_2/`. See `README.md` and the Section 2 PDF',
              'for equations, assumptions and source applicability. The linear void model',
              'does not determine discharge inception or withstand.', '']
    (folder/'RESULTS.md').write_text('\n'.join(lines))


def study(gmsh, getdp, question=None):
    """Run the named cases, verify them, and return a relevant Gmsh file to open."""
    names = QUESTIONS[question] if question else list(CASES)
    results = {}
    for name in names:
        maps = name in ['healthy', 'ideal', 'void', 'thicker_xlpe']
        results[name] = run_case(name, CASES[name], gmsh, getdp, maps=maps)
    checks = check_results(results)
    folder = HERE/'validation'
    folder.mkdir(exist_ok=True)
    parameters, materials = prepare()
    reference = analytical_reference(parameters, materials)
    (folder/'analytical_reference.json').write_text(json.dumps(reference, indent=2) + '\n')
    write_comparisons(results, folder)
    if question is None:
        versions = {}
        for name, tool in [('gmsh', gmsh), ('getdp', getdp)]:
            versions[name] = command([tool, '-info'], folder/(name + '_version.txt')).strip()
        summary = dict(cases=results, checks=checks, tool_versions=versions)
        (folder/'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
        write_results(summary, folder)
    if question is not None:
        summary_file = HERE/'results'/('question_' + question.replace('.', '_') + '.json')
        summary_file.write_text(json.dumps(dict(cases=results, checks=checks), indent=2) + '\n')
    viewer = HERE/'results/healthy/view.geo'
    if question == '2.3':
        viewer = folder/'field_convergence.pos'
    elif question == '2.5':
        viewer = folder/'defect_comparison.pos'
    elif question == '2.8':
        viewer = folder/'design_comparison.pos'
    print(f'Checks passed. Open {viewer.relative_to(HERE)} in Gmsh.', flush=True)
    return viewer
