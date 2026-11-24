"""Collect the GetDP results of run_all.sh into LaTeX macros and small CSV files.

Reads  Source-code/*/results/<case>/*.dat   (written by the .pro files)
Writes Reports/sources/data/values.tex      (one \\newcommand per number, used by reports and slides)
       Reports/sources/data/*.csv            (data of the pgfplots figures)
No computation happens here except unit-free ratios and the Section 5 ampacity interpolation.
"""
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
E = os.path.join(ROOT, 'Source-code/Electrodynamic-analysis/results')
M = os.path.join(ROOT, 'Source-code/Magnetothermal-analysis/results')
OUT = os.path.join(ROOT, 'Reports/sources/data')


def num(case_dir, name, k=1):
    """k-th number of a GetDP 'Format Table' file (0 = index, 1 = real part, 2 = imag)."""
    return float(open(os.path.join(case_dir, name)).read().split()[k])


def dofs(case_dir):
    lines = [l for l in open(os.path.join(case_dir, 'getdp.log')) if 'Dofs' in l]
    return int(lines[0].split()[4]) if lines else 0   # needs getdp -v 3


v = {}
# ---- Section 2 ---------------------------------------------------------------------------
electric = {'gap': 'gap', 'touching': 'touching', 'coarse': 'gapcoarse', 'fine': 'gapfine',
            'thick': 'thick', 'defect': 'defect', 'defect-fine': 'defectfine',
            'f5': 'ffive', 'f500': 'fhund', 'f5000': 'fthou'}
for case, key in electric.items():
    d = os.path.join(E, case)
    v['E' + key] = num(d, 'max_field_kV_mm.dat')
    v['C' + key] = num(d, 'capacitance_uF_km.dat')
    v['Cq' + key] = num(d, 'capacitance_charge_uF_km.dat')
    v['Dofs' + key] = dofs(d)
    if 'defect' in case:
        cut = [l.split() for l in open(os.path.join(d, 'radial_field_A.txt'))]
        inside = [float(x[3]) for x in cut if 0.00855 < float(x[0]) - 0 < 0.00905]  # xA = 0 (trefoil)
        v['Vmean' + key] = sum(inside) / len(inside) / 1e6

# ---- Sections 3, 4, 5 -----------------------------------------------------------------------
magnetic = {'base': 'base', 'stranded': 'stranded', 'stranded-f500': 'strandedfhund',
            'single': 'single', 'touching': 'touching', 'coarse': 'coarse', 'fine': 'fine',
            'box06': 'box', 'f0.01': 'fdc', 'f5': 'ffive', 'f500': 'fhund',
            'lin': 'lin', 'nl': 'nl', 'lin-iso': 'liniso', 'nl-iso': 'nliso',
            'nl-h5': 'nlhfive', 'nl-h20': 'nlhtwenty', 'nl-coarse': 'nlcoarse', 'nl-fine': 'nlfine',
            'nl-dom10': 'nldomten', 'nl-dom40': 'nldomforty'}
sec5 = {'trefoil': 'trefoil', 'trefoil-sp': 'trefoilsp', 'flat': 'flat', 'flat-sp': 'flatsp',
        'flat70': 'flatsev', 'flat70-sp': 'flatsevsp'}
for case, key in sec5.items():
    magnetic[case] = key
    magnetic[case + '-I1'] = key + 'Ione'
for case, key in magnetic.items():
    d = os.path.join(M, case)
    v['Pc' + key] = num(d, 'losses_conductors.dat')
    v['Ps' + key] = num(d, 'losses_screens.dat')
    v['Pt' + key] = v['Pc' + key] + v['Ps' + key]
    v['Rc' + key] = num(d, 'R_conductors_ohm_km.dat')
    v['Rac' + key] = num(d, 'R_ac_ohm_km.dat')
    v['L' + key] = num(d, 'L_mH_km.dat')
    v['MDofs' + key] = dofs(d)
    cur = [float(x) for x in open(os.path.join(d, 'currents_A.dat')).read().split()[1:]]
    sc = cur[6:8] if len(cur) >= 12 else cur[0:2]          # first screen current (re, im)
    v['Is' + key] = math.hypot(*sc) / math.sqrt(2)
    if os.path.exists(os.path.join(d, 'Z_terminal_ohm_km.dat')):        # Q3.9-Q3.10 check
        v['Zr' + key] = num(d, 'Z_terminal_ohm_km.dat', 1)
        v['Zx' + key] = num(d, 'Z_terminal_ohm_km.dat', 2)
    if os.path.exists(os.path.join(d, 'Tmax_conductor.dat')):
        v['Tc' + key] = num(d, 'Tmax_conductor.dat')
        v['Ts' + key] = num(d, 'Tmax_surface.dat')
        hist = [l.split() for l in open(os.path.join(d, 'convergence.txt'))]
        v['Nit' + key] = int(float(hist[-1][1]))
        v['Qs' + key] = num(d, 'surface_heat_W_m.dat')

# Section 5 ampacity: T_max is close to linear in I^2 -> interpolate to 90 C.
for case, key in sec5.items():
    t0, t1 = v['Tc' + key], v['Tc' + key + 'Ione']
    i1 = 350 * math.sqrt(75 / (t0 - 15))                     # same rule as run_all.sh
    i1 = float(f'{i1:.1f}')
    v['Ione' + key] = i1
    v['Amp' + key] = math.sqrt(350**2 + (90 - t0) * (i1**2 - 350**2) / (t1 - t0))

# Derived comparisons quoted in the text (percentages, differences).
pct = lambda a, b: 100 * (a / b - 1)
v['dPtNL'] = pct(v['Ptnl'], v['Ptlin'])            # Q4.8: total losses, sigma(T) vs linear
v['dPcNL'] = pct(v['Pcnl'], v['Pclin'])
v['dPsNL'] = pct(v['Psnl'], v['Pslin'])
v['dRacNL'] = pct(v['Racnl'], v['Raclin'])
v['dLNL'] = pct(v['Lnl'], v['Llin'])
v['dTcNL'] = v['Tcnl'] - v['Tclin']
v['QsFrac'] = 100 * v['Qsnl'] / v['Ptnl']              # Q4.2: share of heat leaving at the surface
v['AmpLin'] = 350 * math.sqrt(75 / (v['Tclin'] - 15))  # Q4.9: rating a linear model would give
v['dTcIso'] = v['Tcnl'] - v['Tcnliso']                 # Q4.5: convection vs isothermal surface
v['dPtSingle'] = pct(v['Ptsingle'], v['Ptbase'])       # Q3.11
v['dAmpSingle'] = v['Amptrefoilsp'] - v['Amptrefoil']  # Section 5
v['dAmpFlatsev'] = v['Ampflatsev'] - v['Amptrefoil']

# Q4.4: location of the hot spot (element of T_conductors.pos with the highest value).
best = (-1, 0, 0)
for line in open(os.path.join(M, 'nl', 'T_conductors.pos')):
    if line.startswith('ST('):
        xy, val = line.split('{')
        c = [float(t) for t in xy[3:-1].split(',')]
        t = max(float(t) for t in val.strip('};\n').split(','))
        if t > best[0]:
            best = (t, sum(c[0::3]) / 3, sum(c[1::3]) / 3)
sp = 0.0435; h = math.sqrt(3) / 2 * sp     # trefoil centres (parameters.pro, 0.5 mm gap)
centres = {'A (top)': (0, 2 * h / 3), 'B (lower left)': (-sp / 2, -h / 3), 'C (lower right)': (sp / 2, -h / 3)}
phase = min(centres, key=lambda k: math.hypot(best[1] - centres[k][0], best[2] - centres[k][1]))
HOTSPOT = f'aluminium of phase {phase}'


def fmt(k, x):
    if isinstance(x, int):
        return f'{x:,}'.replace(',', '\\,')
    if k.startswith('dAmp'):
        return f'{x:+.0f}'
    if k.startswith('d') or k in ('QsFrac',):
        return f'{x:+.1f}' if k.startswith('d') else f'{x:.1f}'
    if k == 'AmpLin':
        return f'{x:.0f}'
    for prefix, f in [('MDofs', '{:,.0f}'), ('Dofs', '{:,.0f}'), ('Pc', '{:.2f}'), ('Ps', '{:.2f}'),
                      ('Pt', '{:.2f}'), ('Rac', '{:.4f}'), ('Rc', '{:.4f}'), ('Cq', '{:.6f}'),
                      ('C', '{:.6f}'), ('L', '{:.4f}'), ('Is', '{:.1f}'), ('Tc', '{:.1f}'),
                      ('Ts', '{:.2f}'), ('Amp', '{:.0f}'), ('Ione', '{:.0f}'), ('Zr', '{:.5f}'), ('Zx', '{:.5f}'), ('Vmean', '{:.2f}'), ('Edefect', '{:.2f}'),
                      ('E', '{:.3f}')]:
        if k.startswith(prefix):
            return f.format(x).replace(',', '\\,')
    return f'{x:.4g}'


with open(os.path.join(OUT, 'values.tex'), 'w') as f:
    f.write('% Generated by Reports/collect_values.py from Source-code/*/results. Do not edit.\n')
    f.write('\\newcommand{\\HotSpot}{' + HOTSPOT + '}\n')
    for k, x in sorted(v.items()):
        assert k.isalpha(), k
        f.write('\\newcommand{\\' + k + '}{' + fmt(k, x) + '}\n')


def csv(name, header, rows):
    with open(os.path.join(OUT, name), 'w') as f:
        f.write(header + '\n')
        for r in rows:
            f.write(','.join(str(x) for x in r) + '\n')


csv('convergence.csv', 'h,dofs,Emax,C',
    [(h, v['Dofs' + k], v['E' + k], v['C' + k]) for h, k in [(0.5, 'gapcoarse'), (0.25, 'gap'), (0.125, 'gapfine')]])
csv('mag_convergence.csv', 'mf,dofs,Rac,Rc,L,Ps',
    [(mf, v['MDofs' + k], v['Rac' + k], v['Rc' + k], v['L' + k], v['Ps' + k]) for mf, k in [(2, 'coarse'), (1, 'base'), (0.5, 'fine')]])
for case, name in [('gap', 'radial_healthy'), ('defect-fine', 'radial_defect'), ('thick', 'radial_thick')]:
    cut = [l.split() for l in open(os.path.join(E, case, 'radial_field_A.txt'))]
    csv(name + '.csv', 'r,E', [(f'{float(x[0]) * 1e3:.4f}', f'{float(x[3]) / 1e6:.5f}') for i, x in enumerate(cut)
                               if i % 4 == 0 or 'defect' in case and 0.0085 < float(x[0]) < 0.0091])
for case, name in [('nl', 'nl_history'), ('nl-coarse', 'nl_history_coarse'), ('nl-fine', 'nl_history_fine')]:
    hist = [l.split() for l in open(os.path.join(M, case, 'convergence.txt'))]
    csv(name + '.csv', 'it,rel', [(int(float(x[1])), x[2]) for x in hist])
for case, name in [('nl', 'surface_nl'), ('lin', 'surface_lin'), ('nl-h20', 'surface_h20'), ('nl-h5', 'surface_h5')]:
    prof = [l.split() for l in open(os.path.join(M, case, 'T_surface_profile.txt'))]
    csv(name + '.csv', 'x,T', [(f'{float(x[0]):.3f}', f'{float(x[3]):.4f}') for x in prof])
print(len(v), 'values written')
