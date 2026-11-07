"""Reproducible Q2 comparisons, numerical checks and Gmsh plot exports."""
import csv
from bisect import bisect_left
import json
import math
from pathlib import Path
from run import run_case, command
from prepare import HERE, prepare


def write_plot(path, title, curves, xlabel, ylabel):
    """Gmsh 2D-space curves. Each sample is an SP record; x is the abscissa."""
    # Gmsh scales each 2D curve to its own sampled x extent. Crop/interpolate
    # endpoints to their common interval so overlaid curves share a true x axis.
    xmin=max(points[0][0] for _,points in curves)
    xmax=min(points[-1][0] for _,points in curves)
    aligned=[]
    for name,points in curves:
        xs0=[x for x,y in points]
        def sample(x):
            j=bisect_left(xs0,x)
            if j==0: return points[0][1]
            if j==len(points): return points[-1][1]
            x0,y0=points[j-1]; x1,y1=points[j]
            return y0+(y1-y0)*(x-x0)/(x1-x0)
        aligned.append((name,[(xmin,sample(xmin))]+[(x,y) for x,y in points if xmin<x<xmax]+[(xmax,sample(xmax))]))
    curves=aligned
    xs=[x for _,points in curves for x,y in points]
    ys=[y for _,points in curves for x,y in points]
    xmin,xmax=min(xs),max(xs)
    ymin,ymax=min(ys),max(ys)
    pad=max((ymax-ymin)*.1,abs(ymax)*1e-6,1e-12)
    lines=['If (PostProcessing.NbViews > 0)', 'For old In {0:PostProcessing.NbViews-1}', 'View[old].Visible = 0;', 'EndFor', 'EndIf', 'first = PostProcessing.NbViews;']
    for i,(name,points) in enumerate(curves):
        lines.append(f'View "{name}" {{')
        lines += [f'SP({x:.14g},0,0){{{y:.14g}}};' for x,y in points]
        lines.append('};')
        if i == 0:
            legend = 'blue healthy; red void; green 9 mm XLPE' if len(curves)==3 else 'blue FE; red analytical'
            lines.append(f'View[first].Name = "{ylabel}: {legend}";')
        lines += [f'View[first+{i}].Visible = 1;', f'View[first+{i}].Type = 4;',f'View[first+{i}].Axes = {3 if i == 0 else 0};', f'View[first+{i}].ShowScale = {1 if i == 0 else 0};', f'View[first+{i}].Color.Background2D = {{255,255,255,0}};',
                  f'View[first+{i}].ShowTime = 0;',f'View[first+{i}].LineWidth = 2;',
                  f'View[first+{i}].PointSize = 4;',f'View[first+{i}].AutoPosition = 0;',
                  f'View[first+{i}].PositionX = 110;',f'View[first+{i}].PositionY = 100;',
                  f'View[first+{i}].Width = 600;',f'View[first+{i}].Height = 380;',
                  f'View[first+{i}].AxesLabelX = "{xlabel}";',
                  f'View[first+{i}].AxesLabelY = "{ylabel}";',
                  f'View[first+{i}].AxesAutoPosition = 0;',
                  f'View[first+{i}].AxesMinX = {xmin}; View[first+{i}].AxesMaxX = {xmax};',
                  f'View[first+{i}].AxesMinY = {ymin-pad}; View[first+{i}].AxesMaxY = {ymax+pad};',
                  f'View[first+{i}].CustomMin = {ymin-pad}; View[first+{i}].CustomMax = {ymax+pad};',
                  f'View[first+{i}].RangeType = 2;', f'View[first+{i}].AbscissaRangeType = 2;',
                  f'View[first+{i}].CustomAbscissaMin = {xmin}; View[first+{i}].CustomAbscissaMax = {xmax};',
                  f'View[first+{i}].ColorTable = {{{{ {220 if i==1 else 30}, {70 if i==1 else 95}, {65 if i==1 else (60 if i==2 else 180)}, 255 }}}};']
    lines.append('Draw;')
    path.write_text('// '+title+'\n'+'\n'.join(lines)+'\n')


def study(gmsh,getdp):
    base=dict(MeshScale=.25,Freq=50,IdealScreens=0,Defect=0,ExtraXLPE=0)
    cases=[('coarse',dict(MeshScale=1),False),('medium',dict(MeshScale=.5),False),
           ('healthy',{},True),('ideal',dict(IdealScreens=1),False),
           ('void_coarse',dict(Defect=1,MeshScale=.5),False),
           ('void',dict(Defect=1),True),
           ('thicker_xlpe',dict(ExtraXLPE=.001),True),
           ('freq_5',dict(Freq=5),False),('freq_500',dict(Freq=500),False),
           ('freq_5000',dict(Freq=5000),False)]
    results={}
    for name,changes,maps in cases:
        results[name]=run_case(name,base|changes,gmsh,getdp,maps)
    healthy=results['healthy']; a=healthy['phases']['A']
    # Numerical checks are deliberately independent of any desired defect outcome.
    healthy_mesh=[results[k] for k in ['coarse','medium','healthy']]
    assert all(b['complex_dofs']>a0['complex_dofs'] for a0,b in zip(healthy_mesh,healthy_mesh[1:]))
    cap_error=abs(a['capacitance_uF_km']/healthy['analytical_capacitance_uF_km']-1)
    field_error=abs(a['max_xlpe_peak_kV_mm']/healthy['analytical_inner_peak_kV_mm']-1)
    assert cap_error<.001, f'Coaxial capacitance error {cap_error:.3%}'
    assert field_error<.02, f'Coaxial maximum field error {field_error:.3%}'
    assert max(c['relative_difference'] for c in healthy['contour_flux_checks'])<.01
    phase_spread=max(v['capacitance_uF_km'] for v in healthy['phases'].values())/min(v['capacitance_uF_km'] for v in healthy['phases'].values())-1
    assert phase_spread<.001
    coarse_void=results['void_coarse']['phases']['A']; void=results['void']['phases']['A']
    defect_field_change=abs(void['max_void_peak_kV_mm']/coarse_void['max_void_peak_kV_mm']-1)
    assert defect_field_change<.03, f'Void field requires refinement: {defect_field_change:.3%}'
    validation=HERE/'validation'
    validation.mkdir(exist_ok=True)
    versions={}
    for name,tool in [('gmsh',gmsh),('getdp',getdp)]:
        versions[name]=command([tool,'-info'],validation/(name+'_version.txt')).strip()
    summary=dict(cases=results,checks=dict(capacitance_relative_error=cap_error,
         healthy_peak_field_relative_error=field_error,phase_capacitance_relative_spread=phase_spread,
         defect_peak_change_last_refinement=defect_field_change),tool_versions=versions)
    (validation/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    with (validation/'convergence.csv').open('w') as f:
        writer=csv.writer(f);writer.writerow(['case','complex_dofs','real_dofs','C_A_uF_km','Emax_XLPE_peak_kV_mm'])
        for name in ['coarse','medium','healthy']:
            r=results[name];s=r['phases']['A']
            writer.writerow([name,r['complex_dofs'],r['real_dofs'],s['capacitance_uF_km'],s['max_xlpe_peak_kV_mm']])
    dofs=[r['complex_dofs'] for r in healthy_mesh]
    write_plot(validation/'field_convergence.pos','Healthy field convergence',[
        ('FE peak XLPE field',[(r['complex_dofs'],r['phases']['A']['max_xlpe_peak_kV_mm']) for r in healthy_mesh]),
        ('Analytical inner-screen field',[(n,healthy['analytical_inner_peak_kV_mm']) for n in dofs])],
        'Complex degrees of freedom','Peak field [kV/mm]')
    write_plot(validation/'capacitance_convergence.pos','Capacitance convergence',[
        ('FE phase A',[(r['complex_dofs'],r['phases']['A']['capacitance_uF_km']) for r in healthy_mesh]),
        ('Analytical coaxial',[(n,healthy['analytical_capacitance_uF_km']) for n in dofs])],
        'Complex degrees of freedom','Capacitance [uF/km]')
    curves=[]
    for name in ['healthy','void','thicker_xlpe']:
        with (HERE/'results'/name/'radial_cut.csv').open() as f:
            points=[(float(row['radius_mm']),float(row['E_peak_kV_mm'])) for row in csv.DictReader(f)]
        curves.append((name,points))
    write_plot(validation/'radial_comparison.pos','Phase A radial comparison',curves,'Radius from A axis [mm]','Peak field [kV/mm]')
    report(results,summary,validation)
    print('All verification checks passed. See validation/RESULTS.md and *.pos plots.',flush=True)


def report(results,summary,folder):
    h=results['healthy']; a=h['phases']['A']; v=results['void']['phases']['A']; t=results['thicker_xlpe']['phases']['A']
    ideal=results['ideal']['phases']['A']
    lines=['# Section 2: computed results','',
           'Generated by `python3 run.py --study`. Fields are **peak phasor norms**, not RMS. '
           'Capacitance is per phase and per kilometre. These are 2D numerical results, not a cable qualification test.','',
           '## Q2.3: healthy mesh refinement','',
           '| Case | Complex DOFs | Triangles | C_A (µF/km) | Maximum XLPE field (kV/mm peak) |',
           '|---|---:|---:|---:|---:|']
    for name in ['coarse','medium','healthy']:
        r=results[name];p=r['phases']['A']
        lines.append(f'| {name} | {r["complex_dofs"]} | {r["triangles"]} | {p["capacitance_uF_km"]:.8f} | {p["max_xlpe_peak_kV_mm"]:.5f} |')
    lines += ['',f'Analytical values: **{h["analytical_capacitance_uF_km"]:.8f} µF/km**, '
              f'**{h["analytical_inner_peak_kV_mm"]:.5f} kV/mm** at the inner XLPE interface and '
              f'**{h["analytical_outer_peak_kV_mm"]:.5f} kV/mm** at the outer interface. '
              f'Fine-mesh C error: {summary["checks"]["capacitance_relative_error"]*100:.5f}%; '
              f'peak-field error: {summary["checks"]["healthy_peak_field_relative_error"]*100:.3f}%.',
              '', 'Open `field_convergence.pos` and `capacitance_convergence.pos` in Gmsh. '
              'GetDP real-arithmetic builds report twice the complex DOF count. '
              'Raw P1 gradients are elementwise constant, so maxima and one-sided interface values converge more slowly than integrated capacitance. '
              'No nodal averaging is used in the reported maxima.',
              '', '## Q2.2: semiconductor simplification','',
              f'At the same nominal fine mesh size, replacing the finite-conductivity screens/contact region with '
              f'Dirichlet boundaries on XLPE changes C by **{(ideal["capacitance_uF_km"]/a["capacitance_uF_km"]-1)*100:.5f}%** '
              f'and the maximum XLPE field by **{(ideal["max_xlpe_peak_kV_mm"]/a["max_xlpe_peak_kV_mm"]-1)*100:.3f}%**. '
              'These FE differences include the different meshes and cannot all be attributed to the physical simplification. '
              'The exact multilayer comparison is in `analytical_reference.json`.',
              '', '## Q2.4: field assessment','',
              f'The healthy maximum is **{a["max_xlpe_peak_kV_mm"]/math.sqrt(2):.3f} kV/mm RMS**. '
              f'The analytical outer-interface value is **{h["analytical_outer_peak_kV_mm"]/math.sqrt(2):.3f} kV/mm RMS**. '
              'Both are below the adopted external screening benchmarks of 8 and 4 kV/mm RMS, respectively '
              '(Eskom 240-56030625, Rev. 3, §3.3(i), Annex B). '
              '**That specification covers 44–132 kV cables, not this 33 kV NKT product.** '
              'These are explicitly adopted comparison limits, not NKT guarantees or universal XLPE breakdown strengths. '
              'The selected datasheet gives no admissible local-field values; manufacturer-specific certification remains unestablished.',
              '', '## Q2.5: axial gas-channel defect','',
              f'Phase A contains a 0.5 mm diameter circular void at radius 10.3 mm on the +x radial cut. '
              f'The fine result gives **{v["max_void_peak_kV_mm"]:.4f} kV/mm peak in the void** and '
              f'**{v["max_xlpe_peak_kV_mm"]:.4f} kV/mm peak in XLPE**. '
              f'The void maximum changes by {summary["checks"]["defect_peak_change_last_refinement"]*100:.2f}% '
              'on the last refinement. Open `radial_comparison.pos` and `results/void/view.geo`.',
              '', 'The 2D circular void represents an infinitely long axial channel, not a spherical bubble. '
              'Its size/location are controlled investigation parameters, not manufacturer defects or tolerances. '
              'Gas permittivity is 1 and conductivity is zero before discharge. '
              '**Withstand is not established:** this linear model contains no ionisation, space charge, discharge inception, '
              'pressure dependence or ageing. XLPE screening limits must not be applied to the gas. '
              'A discharge model or appropriate test data are needed to decide whether this defective cable withstands service.',
              '', '## Q2.6: current densities and conservation','',
              'Gmsh views contain |σE| and |jωεE| in A/m². The radial CSV includes both and complex E components. '
              'These are transverse charging/leakage currents; the 415 A longitudinal load belongs to Section 3.',
              '', f'Maximum free-node weak residual / phase-A terminal current: **{h["max_free_residual_relative"]:.3e}**. '
              f'Phase-A terminal imbalance: **{a["terminal_balance_relative"]:.3e}**. '
              f'Largest independent circular-contour flux discrepancy: **{max(c["relative_difference"] for c in h["contour_flux_checks"])*100:.3f}%**. '
              'Terminal reactions are discretely conservative; raw P1 gradients are not a pointwise flux-conforming field. '
              'The independent contour check exposes that discretisation error.',
              '', 'At 50 Hz, σ/(ωε) is approximately 3.20×10⁵ in the semiconducting regions and 1.44×10⁻¹⁰ in XLPE. '
              'Conduction dominates in the screens, displacement in XLPE/gas; total normal current is continuous in the weak solution. '
              f'Phase-A peak charging current is approximately **{abs(complex(*a["terminal_current_peak_A_m"]))*1000:.4f} A/km** '
              '(divide by √2 for RMS). Tiny conductive losses are not a prediction of all real dielectric losses: '
              'the adopted XLPE model has no dielectric-loss tangent.',
              '', '## Q2.7: capacitance and frequency','',
              f'Computed C_A = **{a["capacitance_uF_km"]:.6f} µF/km**, '
              f'{(1-a["capacitance_uF_km"]/.24)*100:.2f}% below NKT’s **maximum** 0.24 µF/km. '
              'The maximum is not an exact target for fitting. C is obtained both from terminal susceptance '
              'Im(I/V)/ω and from ∫ε|E|²dA/|V|². The implementation checks that they agree; '
              'it does not divide the three-phase energy by one phase voltage without the factor of three.',
              '', '| Frequency (Hz) | C_A (µF/km) |','|---:|---:|']
    for name in ['freq_5','healthy','freq_500','freq_5000']:
        r=results[name];lines.append(f'| {r["options"]["Freq"]} | {r["phases"]["A"]["capacitance_uF_km"]:.9f} |')
    lines += ['', 'With constant ε and perfectly equipotential screens the analytical C is frequency independent. '
              'Finite screen conductivity gives a weak frequency dependence; real dispersion, dielectric loss and temperature dependence are not modelled.',
              '', '## Q2.8: an insulation-thickness improvement','',
              f'Increasing XLPE from 8 to 9 mm while retaining the conductor and screen thicknesses gives '
              f'**{t["max_xlpe_peak_kV_mm"]:.4f} kV/mm peak**, '
              f'a **{(1-t["max_xlpe_peak_kV_mm"]/a["max_xlpe_peak_kV_mm"])*100:.2f}% reduction**, '
              f'and **{t["capacitance_uF_km"]:.6f} µF/km**. '
              'All outside interfaces shift outwards by 1 mm and the touching-trefoil spacing increases by 2 mm. '
              'This is a hypothetical design variant, not a change to the selected NKT baseline or its 415 A rating. '
              'Larger dimensions, changed screen geometry and poorer thermal transfer require separate manufacturing/thermal assessment.',
              '', '## Provenance','',
              'See `../README.md` for equations, boundary conditions, modelling assumptions, source links and run instructions. '
              '`summary.json` records all cases, checks, input hashes and tool versions. The supplied TA files are unchanged.','']
    (folder/'RESULTS.md').write_text('\n'.join(lines))
    # Exact cylindrical layered admittance isolates approximation error from FE error.
    p,m=prepare();eps0=m['vacuum_permittivity_F_m'];w=2*math.pi*50
    r0=p['conductor_diameter_mm']/2000;r1=r0+p['inner_semiconductor_mm']/1000
    r2=r1+p['xlpe_mm']/1000;r3=r2+p['outer_semiconductor_mm']/1000
    r4=math.sqrt((p['diameter_over_copper_mm']/2000)**2-p['copper_area_mm2']*1e-6/math.pi)
    gsc=complex(m['semiconductor']['conductivity_S_m'],w*eps0*m['semiconductor']['relative_permittivity'])
    gx=complex(m['xlpe']['conductivity_S_m'],w*eps0*m['xlpe']['relative_permittivity'])
    zx=math.log(r2/r1)/(2*math.pi*gx)
    zsc=(math.log(r1/r0)+math.log(r4/r2))/(2*math.pi*gsc)
    admittance=1/(zx+zsc)
    exact=dict(full_C_uF_km=admittance.imag/w*1e9,ideal_C_uF_km=h['analytical_capacitance_uF_km'],
               full_inner_E_peak_kV_mm=abs(admittance*p['line_voltage_rms_V']*math.sqrt(2/3)/(2*math.pi*r1*gx))/1e6,
               relative_XLPE_voltage_drop=abs(zx/(zx+zsc)),
               model='Exact concentric multilayer series impedances per metre; peak phasors')
    exact['ideal_minus_full_C_relative'] = exact['ideal_C_uF_km']/exact['full_C_uF_km']-1
    exact['ideal_minus_full_E_relative'] = h['analytical_inner_peak_kV_mm']/exact['full_inner_E_peak_kV_mm']-1
    (folder/'analytical_reference.json').write_text(json.dumps(exact,indent=2)+'\n')
