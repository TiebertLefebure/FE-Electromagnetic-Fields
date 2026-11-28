"""Copy the numbers printed by Source-Code/run_all.sh into the reports and slides.

Reads   Source-Code/<section>/results/<case>/*.dat, references.txt, getdp.log, convergence.txt
        Source-Code/1-Cable-selection-and-model-setup/results/mesh_<name>.txt
Writes  Reports/sources/data/values.tex  -- one \\newcommand per number (no number is typed by hand)
        Reports/sources/data/*.csv        -- data of the pgfplots figures

Every value comes from the code: the .pro files print the FE results and, in references.txt,
the analytical and IEC 60287 references and the comparisons within one run. This script only
formats them; the one thing it computes is the change between two runs (pct, differences),
listed in the README table "Comparisons between runs".
"""
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SRC = os.path.join(ROOT, 'Source-Code')
S1 = os.path.join(SRC, '1-Cable-selection-and-model-setup/results')
E = os.path.join(SRC, '2-Electrodynamic-analysis/results')
M = os.path.join(SRC, '3-Magnetoquasistatic-analysis/results')
T = os.path.join(SRC, '4-Magnetothermal-analysis/results')
A = os.path.join(SRC, '5-Cable-arrangement/results')
OUT = os.path.join(ROOT, 'Reports/sources/data')
macros = {}   # name -> formatted string


def put(name, value, fmt='{:.4g}'):
    """Store a formatted number: thin-space thousands, LaTeX powers of ten and minus sign."""
    assert name.isalpha(), name
    t = fmt.format(value).replace(',', '\\,')
    if 'e' in t:                                   # 1.44e-10 -> 1.44\cdot10^{-10}
        m, e = t.split('e')
        t = (m + '\\cdot' if m not in ('1', '1.0') else '') + '10^{' + str(int(e)) + '}'
    macros[name] = '\\ensuremath{' + t + '}' if ('^' in t or t.startswith('-')) else t


def num(case_dir, name, k=1):
    """k-th number of a GetDP 'Format Table' file (0 = index, 1 = real part, 2 = imag)."""
    return float(open(os.path.join(case_dir, name)).read().split()[k])


def refs(case_dir):
    """references.txt of a run: {name: value}."""
    return {l.split()[0]: float(l.split()[1]) for l in open(os.path.join(case_dir, 'references.txt'))}


def dofs(case_dir, k=0):
    """Number of unknowns of system k, from the GetDP log."""
    return int([l for l in open(os.path.join(case_dir, 'getdp.log')) if 'Dofs' in l][k].split()[4])


def gmsh_quality(name):
    """Triangles and ICN (worst, average) printed by mesh_quality.geo."""
    out = open(os.path.join(S1, f'mesh_{name}.txt')).read().split('\n')
    tri = int(float([l for l in out if 'Triangles:' in l][0].split()[-1]))
    icn = [l for l in out if 'ICN' in l and '=' in l][0].split('=')[1].replace(',', ' ').split()
    return tri, float(icn[0]), float(icn[1])


pct = lambda a, b: 100 * (a / b - 1)      # change between two runs, %

# ===================================================================== Section 1: meshes
for case, key in [('gap', 'Gap'), ('touching', 'Touch')]:
    n_, qmin, qavg = gmsh_quality(case)
    put('MeshTri' + key, n_, '{:,}'); put('MeshQmin' + key, qmin, '{:.3f}'); put('MeshQavg' + key, qavg, '{:.3f}')
    put('MeshXlpe' + key, num(os.path.join(E, case), 'triangles_XLPE_A.dat'), '{:,.0f}')
    put('MeshHmetal' + key, refs(os.path.join(M, 'base' if case == 'gap' else case))['Hmetal'], '{:.2f}')

# ===================================================================== Section 2
r = refs(os.path.join(E, 'gap'))
for k, fm in [('AnaC', '{:.6f}'), ('AnaEi', '{:.3f}'), ('AnaEirms', '{:.2f}'), ('AnaEorms', '{:.2f}'),
              ('AnaEzero', '{:.2f}'), ('AnaEvoid', '{:.2f}'), ('AnaVoidFactor', '{:.2f}'), ('AnaSphereFactor', '{:.2f}'),
              ('AnaJdVoidFactor', '{:.2f}'), ('AnaIch', '{:.3f}'), ('AnaJd', '{:.4f}'),
              ('AnaJc', '{:.2e}'), ('AnaRatio', '{:.2e}'), ('AnaDrop', '{:.0f}'), ('AnaCbare', '{:.4f}'),
              ('dCbare', '{:.1f}'), ('AnaEb', '{:.2f}'), ('AnaEbPaschen', '{:.1f}'), ('dCnkt', '{:.1f}'),
              ('IchFE', '{:.3f}'), ('IratioFE', '{:.2e}'), ('dCcharge', '{:.0e}')]:
    put(k, r[k], fm)
put('dCana', abs(r['dCana']), '{:.4f}'); put('dEgap', r['dEana'], '{:+.2f}')
put('dEfine', refs(os.path.join(E, 'fine'))['dEana'], '{:+.2f}')
rt = refs(os.path.join(E, 'thick'))                          # Q2.8: references of the 9 mm run
put('AnaEithick', rt['AnaEi'], '{:.3f}'); put('AnaCthick', rt['AnaC'], '{:.6f}')
rd = refs(os.path.join(E, 'defect'))                         # Q2.5 on the default mesh; defect-fine is the check
put('VoidRatio', rd['VoidRatio'], '{:.2f}'); put('PdInception', rd['PdInception'], '{:.0f}')
electric = {'gap': 'gap', 'touching': 'touching', 'coarse': 'gapcoarse', 'fine': 'gapfine',
            'thick': 'thick', 'defect': 'defect', 'defect-fine': 'defectfine',
            'f5': 'ffive', 'f500': 'fhund', 'f5000': 'fthou'}
ev = {}
for case, key in electric.items():
    d = os.path.join(E, case)
    ev[key] = dict(E=num(d, 'max_field_kV_mm.dat'), C=num(d, 'capacitance_uF_km.dat'),
                   Cq=num(d, 'capacitance_charge_uF_km.dat'), D=dofs(d))
    put('E' + key, ev[key]['E'], '{:.2f}' if 'defect' in key else '{:.3f}'); put('C' + key, ev[key]['C'], '{:.6f}')
    put('Cq' + key, ev[key]['Cq'], '{:.6f}'); put('Dofs' + key, ev[key]['D'], '{:,}')
    if 'defect' in case:
        put('Vmean' + key, refs(d)['EvoidMean'], '{:.2f}')
put('JdFE', num(os.path.join(E, 'gap'), 'max_Jd_A_m2.dat'), '{:.4f}')
put('JcFE', num(os.path.join(E, 'gap'), 'max_Jc_A_m2.dat'), '{:.2e}')
put('dEtouch', pct(ev['gap']['E'], ev['touching']['E']), '{:+.3f}')               # between runs
put('dCtouch', abs(pct(ev['gap']['C'], ev['touching']['C'])), '{:.0e}')
put('dEthick', pct(ev['thick']['E'], ev['gap']['E']), '{:.1f}')
put('dCthick', pct(ev['thick']['C'], ev['gap']['C']), '{:.1f}')

# ===================================================================== Section 3
r = refs(os.path.join(M, 'base'))
for k, fm in [('AnaDeltaAl', '{:.2f}'), ('AnaDeltaCu', '{:.2f}'), ('AnaDeltaSoil', '{:.0f}'), ('NktL', '{:.3f}'), ('Bsingle', '{:.1f}'),
              ('Javg', '{:.2f}'), ('Bmax', '{:.1f}'), ('Jmax', '{:.2f}'),
              ('IecYs', '{:.2f}'), ('IecYp', '{:.2f}'), ('IecYsp', '{:.2f}'), ('IecRcond', '{:.5f}'),
              ('IecRs', '{:.4f}'), ('IecX', '{:.4f}'), ('IecLam', '{:.2f}'), ('IecRac', '{:.4f}'),
              ('IecIs', '{:.1f}'), ('IecPc', '{:.2f}'), ('IecPs', '{:.2f}'), ('IecPt', '{:.2f}'),
              ('IecUs', '{:.1f}'), ('Lterm', '{:.4f}'), ('dLterm', '{:.2f}'), ('dIs', '{:+.1f}'),
              ('IsSum', '{:.2f}'), ('IsPeak', '{:.0f}'), ('Jscreen', '{:.1f}'), ('LamFE', '{:.1f}'),
              ('CondShare', '{:.0f}'), ('PhaseSym', '{:.4f}'), ('PcPhase', '{:.2f}')]:
    put(k, r[k], fm)
iec20 = r
put('AnaLgap', r['AnaL'], '{:.4f}'); put('AnaLtouch', refs(os.path.join(M, 'touching'))['AnaL'], '{:.4f}')
put('dLnkt', refs(os.path.join(M, 'touching'))['dLnkt'], '{:+.1f}')
put('dLana', refs(os.path.join(M, 'single'))['dLana'], '{:+.1f}')
put('Usingle', refs(os.path.join(M, 'single'))['Usingle'], '{:.1f}')
put('Zrbase', num(os.path.join(M, 'base'), 'Z_terminal_ohm_km.dat'), '{:.4f}')

magnetic = {'base': 'base', 'stranded': 'stranded', 'stranded-f500': 'strandedfhund',
            'single': 'single', 'touching': 'touching', 'coarse': 'coarse', 'fine': 'fine',
            'box06': 'box', 'f0.01': 'fdc', 'f5': 'ffive', 'f500': 'fhund'}
thermal = {'lin': 'lin', 'nl': 'nl', 'lin-iso': 'liniso', 'nl-iso': 'nliso', 'nl-h5': 'nlhfive',
           'nl-h20': 'nlhtwenty', 'nl-coarse': 'nlcoarse', 'nl-fine': 'nlfine',
           'nl-dom10': 'nldomten', 'nl-dom40': 'nldomforty'}
sec5 = {'trefoil': 'trefoil', 'trefoil-sp': 'trefoilsp', 'flat': 'flat', 'flat-sp': 'flatsp',
        'flat70': 'flatsev', 'flat70-sp': 'flatsevsp'}
mv = {}
for folder, cases in [(M, magnetic), (T, thermal), (A, sec5)]:
    for case, key in cases.items():
        d = os.path.join(folder, case)
        q = dict(Pc=num(d, 'losses_conductors.dat'), Ps=num(d, 'losses_screens.dat'), Pt=num(d, 'losses_total.dat'),
                 Rc=num(d, 'R_conductors_ohm_km.dat'), Rac=num(d, 'R_ac_ohm_km.dat'),
                 L=num(d, 'L_mH_km.dat'), Is=num(d, 'screen_current_A_rms.dat'), D=dofs(d))
        if folder != M:
            q.update(Tc=num(d, 'Tmax_conductor.dat'), Ts=num(d, 'Tmax_surface.dat'), Qs=num(d, 'surface_heat_W_m.dat'))
        if folder == T:
            q['Nit'] = refs(d)['Nit']
        mv[key] = q
        for k, fm in [('Pc', '{:.2f}'), ('Ps', '{:.2f}'), ('Pt', '{:.2f}'), ('Rc', '{:.4f}'), ('Rac', '{:.4f}'),
                      ('L', '{:.4f}'), ('Is', '{:.1f}'), ('Tc', '{:.1f}'), ('Ts', '{:.2f}'), ('Nit', '{:.0f}')]:
            if k in q:
                put(k + key, q[k], fm)
        put('MDofs' + key, q['D'], '{:,}')

# Section 3, between runs
b, s1 = mv['base'], mv['single']
put('SkinFE', pct(b['Rc'], mv['fdc']['Rac']), '{:.2f}')
put('ScreenFE', 100 * (b['Rac'] - b['Rc']) / mv['fdc']['Rac'], '{:.1f}')
put('EddyFE', 100 * s1['Ps'] / b['Pc'], '{:.1f}')
put('PcircFE', b['Ps'] - s1['Ps'], '{:.2f}'); put('dPcirc', pct(b['Ps'] - s1['Ps'], iec20['IecPs']), '{:+.0f}')
put('dPtSingle', pct(s1['Pt'], b['Pt']), '{:+.1f}'); put('dRacSingle', pct(s1['Rac'], b['Rac']), '{:+.1f}')
put('dLtouch', pct(b['L'], mv['touching']['L']), '{:+.2f}'); put('dRactouch', pct(b['Rac'], mv['touching']['Rac']), '{:+.2f}')
put('dPstouch', pct(b['Ps'], mv['touching']['Ps']), '{:+.1f}')
put('dLbox', pct(mv['box']['L'], b['L']), '{:+.2f}'); put('dRacbox', pct(mv['box']['Rac'], b['Rac']), '{:+.2f}')
put('dRacfine', pct(mv['fine']['Rac'], b['Rac']), '{:+.2f}'); put('dLfine', pct(mv['fine']['L'], b['L']), '{:+.2f}')
put('dPsfine', pct(mv['fine']['Ps'], b['Ps']), '{:+.1f}')
put('dRcstr', pct(mv['stranded']['Rc'], b['Rc']), '{:+.2f}'); put('dLstr', pct(mv['stranded']['L'], b['L']), '{:+.2f}')
put('dRcstrhund', pct(mv['strandedfhund']['Rc'], mv['fhund']['Rc']), '{:+.0f}')
put('dLfreq', pct(b['L'], mv['fdc']['L']), '{:+.1f}'); put('dLfreqhund', pct(mv['fhund']['L'], mv['fdc']['L']), '{:+.0f}')

# ===================================================================== Section 4
r = refs(os.path.join(T, 'nl'))
for k, fm in [('IecTone', '{:.3f}'), ('IecTthree', '{:.3f}'), ('IecTfour', '{:.3f}'), ('IecU', '{:.1f}'),
              ('IecTheta', '{:.1f}'), ('IecAmp', '{:.0f}'), ('IecThetaS', '{:.0f}'), ('IecRacHot', '{:.4f}'),
              ('IecRcondHot', '{:.4f}'), ('IecLamHot', '{:.1f}'), ('IecPcHot', '{:.1f}'), ('IecPsHot', '{:.2f}'),
              ('dTfiller', '{:.1f}'), ('Hrad', '{:.1f}'), ('AnaWd', '{:.3f}'), ('AnaWdShare', '{:.2f}'),
              ('dToneThick', '{:.1f}'), ('dTthick', '{:.1f}'), ('QsFrac', '{:.1f}'), ('dTcNkt', '{:+.1f}'),
              ('dTsurf', '{:.1f}'), ('RhoHot', '{:.0f}'), ('dTsemi', '{:.1f}'), ('TcA', '{:.2f}'),
              ('TcB', '{:.2f}'), ('TcC', '{:.2f}'), ('dTcBC', '{:.2f}'), ('dTcAlow', '{:.1f}'),
              ('ConvRate', '{:.2f}')]:
    put(k, r[k], fm)
put('AmpLin', refs(os.path.join(T, 'lin'))['AmpLin'], '{:.0f}')
rl = refs(os.path.join(T, 'lin'))                            # Q4.8: peak |B| and |J|, linear and sigma(T)
put('BmaxLin', rl['Bmax'], '{:.2f}'); put('BmaxNL', r['Bmax'], '{:.2f}')
put('JmaxLin', rl['Jmax'], '{:.3f}'); put('JmaxNL', r['Jmax'], '{:.3f}')
put('dBNL', pct(r['Bmax'], rl['Bmax']), '{:+.2f}'); put('dJNL', pct(r['Jmax'], rl['Jmax']), '{:+.1f}')
put('TDofsnl', dofs(os.path.join(T, 'nl'), 1), '{:,}')
n, l = mv['nl'], mv['lin']                                                      # between runs
put('dPtNL', pct(n['Pt'], l['Pt']), '{:+.1f}'); put('dPcNL', pct(n['Pc'], l['Pc']), '{:+.1f}')
put('dPsNL', pct(n['Ps'], l['Ps']), '{:+.1f}'); put('dRacNL', pct(n['Rac'], l['Rac']), '{:+.1f}')
put('dLNL', pct(n['L'], l['L']), '{:+.2f}'); put('dTcNL', n['Tc'] - l['Tc'], '{:+.1f}')
put('dTcIso', n['Tc'] - mv['nliso']['Tc'], '{:.1f}')
put('dTcFine', mv['nlfine']['Tc'] - n['Tc'], '{:+.1f}'); put('dTcCoarse', mv['nlcoarse']['Tc'] - n['Tc'], '{:+.1f}')
put('dTcDom', mv['nldomforty']['Tc'] - n['Tc'], '{:+.2f}'); put('dTcDomten', mv['nldomten']['Tc'] - n['Tc'], '{:+.2f}')

# ===================================================================== Section 5
dev, steps = [], []
for case, key in sec5.items():
    r = refs(os.path.join(A, case))
    put('Amp' + key, r['Amp'], '{:.0f}'); put('dNkt' + key, r['dNkt'], '{:+.1f}')
    mv[key]['Amp'] = r['Amp']; dev.append(r['dNkt']); steps.append(r['AmpSteps'])
put('dNktMin', min(dev), '{:+.1f}'); put('dNktMax', max(dev), '{:+.1f}'); put('AmpStepsMax', max(steps), '{:.0f}')
put('dAmpSingle', mv['trefoilsp']['Amp'] - mv['trefoil']['Amp'], '{:+.0f}')               # between runs
put('dLflat', pct(mv['flatsevsp']['L'], mv['trefoil']['L']), '{:+.0f}')

# ===================================================================== write
with open(os.path.join(OUT, 'values.tex'), 'w') as fo:
    fo.write('% Generated by Reports/collect_values.py. Do not edit.\n')
    for k in sorted(macros):
        fo.write('\\newcommand{\\' + k + '}{' + macros[k] + '}\n')


def csv(name, header, rows):
    with open(os.path.join(OUT, name), 'w') as fo:
        fo.write(header + '\n' + '\n'.join(','.join(str(x) for x in r) for r in rows) + '\n')


csv('convergence.csv', 'h,dofs,Emax,C',
    [(h_, ev[k]['D'], ev[k]['E'], ev[k]['C']) for h_, k in [(0.5, 'gapcoarse'), (0.25, 'gap'), (0.125, 'gapfine')]])
csv('mag_convergence.csv', 'mf,dofs,Rac,Rc,L,Ps',
    [(mf, mv[k]['D'], mv[k]['Rac'], mv[k]['Rc'], mv[k]['L'], mv[k]['Ps']) for mf, k in [(2, 'coarse'), (1, 'base'), (0.5, 'fine')]])
for case, name in [('gap', 'radial_healthy'), ('defect', 'radial_defect'), ('thick', 'radial_thick')]:
    cut = [l_.split() for l_ in open(os.path.join(E, case, 'radial_field_A.txt'))]
    csv(name + '.csv', 'r,E', [(f'{float(x[0]) * 1e3:.4f}', f'{float(x[3]) / 1e6:.5f}') for i, x in enumerate(cut)
                               if i % 4 == 0 or 'defect' in case and 0.0085 < float(x[0]) < 0.0091])
for case, name in [('nl', 'nl_history'), ('nl-coarse', 'nl_history_coarse'), ('nl-fine', 'nl_history_fine')]:
    hist = [l_.split() for l_ in open(os.path.join(T, case, 'convergence.txt'))]
    csv(name + '.csv', 'it,rel', [(int(float(x[1])), x[2]) for x in hist])
for case, name in [('nl', 'surface_nl'), ('nl-h20', 'surface_h20'), ('nl-h5', 'surface_h5')]:
    prof = [l_.split() for l_ in open(os.path.join(T, case, 'T_surface_profile.txt'))]
    csv(name + '.csv', 'x,T', [(f'{float(x[0]):.3f}', f'{float(x[3]):.4f}') for x in prof])
# Q3.2: |J| (A/mm2) along phase A's vertical diameter; s < 0 = side facing the trefoil centre.
jl = {c: [l_.split() for l_ in open(os.path.join(M, c, 'j_line_A.txt'))] for c in ('base', 'stranded')}
yc = (float(jl['base'][0][1]) + float(jl['base'][-1][1])) / 2
csv('j_profile.csv', 's,massive,stranded', [(f'{(float(a[1]) - yc) * 1e3:.3f}', f'{float(a[3]) / 1e6:.4f}',
                                             f'{float(c[3]) / 1e6:.4f}') for a, c in zip(jl['base'], jl['stranded'])])
# Q3.9: R_AC split into DC, skin + proximity and screens (ohm/km), FE and IEC 60287 at 20 C.
csv('rac_split.csv', 'model,dc,skin,screens',
    [('FE', f"{mv['fdc']['Rac']:.5f}", f"{b['Rc'] - mv['fdc']['Rac']:.5f}", f"{b['Rac'] - b['Rc']:.5f}"),
     ('IEC', f"{iec20['IecRdc']:.5f}", f"{iec20['IecRcond'] - iec20['IecRdc']:.5f}",
      f"{iec20['IecRac'] - iec20['IecRcond']:.5f}")])
# Q4.8: change from the linear (20 C) to the sigma(T) model, %.
csv('nl_change.csv', 'q,change', [(k, f"{pct(mv['nl'][k], mv['lin'][k]):.2f}") for k in ('Pc', 'Ps', 'Pt', 'Rac', 'L')])
print(len(macros), 'values written')
