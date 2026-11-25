"""Turn the GetDP results of run_all.sh into the numbers quoted in the reports and slides.

Reads   Source-code/*/results/<case>/*.dat (written by the .pro files) and the two base meshes.
Writes  Reports/sources/data/values.tex  -- one \\newcommand per number (no number is typed by hand)
        Reports/sources/data/*.csv        -- data of the pgfplots figures
Also computes the analytical references (course Appendix B, IEC 60287) from the same inputs
as Source-code/Cable-selection-and-model-setup/parameters.pro.
"""
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SRC = os.path.join(ROOT, 'Source-code')
E = os.path.join(SRC, 'Electrodynamic-analysis/results')
M = os.path.join(SRC, 'Magnetothermal-analysis/results')
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


def nums(case_dir, name):
    return [float(x) for x in open(os.path.join(case_dir, name)).read().split()[1:]]


def dofs(case_dir):
    lines = [l for l in open(os.path.join(case_dir, 'getdp.log')) if 'Dofs' in l]
    return int(lines[0].split()[4])


def pos_max(path):
    """Largest nodal value in a Gmsh .pos scalar-triangle file, and the element centroid."""
    best = (-1.0, 0.0, 0.0)
    for line in open(path):
        if line.startswith('ST('):
            xy, val = line.split('{')
            c = [float(t) for t in xy[3:-1].split(',')]
            t = max(float(t) for t in val.strip('};\n').split(',')[0:3])
            if t > best[0]:
                best = (t, sum(c[0::3]) / 3, sum(c[1::3]) / 3)
    return best


pct = lambda a, b: 100 * (a / b - 1)

# ===================================================================== analytical references
f = 50; w = 2 * math.pi * f; eps0 = 8.854187817e-12; mu0 = 4e-7 * math.pi
I = 350; Vp = math.sqrt(2) * 33000 / math.sqrt(3); U0 = 33000 / math.sqrt(3)
rc, ri, ro, epsr = 7.4e-3, 7.8e-3, 15.8e-3, 2.5            # conductor, XLPE interfaces
sAl = 1000 / (0.164 * math.pi * rc**2); sCu = 1 / 1.7241e-8
aAl, aCu = 0.0039, 0.00386
rsi = 17.4e-3; rso = math.sqrt(rsi**2 + 50e-6 / math.pi); rj = 21.5e-3
s_gap, s_touch = 2 * rj + 0.5e-3, 2 * rj                   # centre spacings
L_bur, rhoSoil, rhoPoly = 1.0, 1.2, 3.5

lnr = math.log(ro / ri)
put('AnaC', 2 * math.pi * eps0 * epsr / lnr * 1e9, '{:.6f}')               # uF/km
put('AnaEi', Vp / (ri * lnr) / 1e6, '{:.3f}')                              # kV/mm peak
put('AnaEirms', Vp / math.sqrt(2) / (ri * lnr) / 1e6, '{:.2f}')
put('AnaEorms', Vp / math.sqrt(2) / (ro * lnr) / 1e6, '{:.2f}')
E0 = Vp / (8.8e-3 * lnr) / 1e6
put('AnaEzero', E0, '{:.2f}'); put('AnaEvoid', 2 * epsr / (epsr + 1) * E0, '{:.2f}')
put('AnaIch', w * 2 * math.pi * eps0 * epsr / lnr * U0 * 1e3, '{:.3f}')    # A/km RMS
put('AnaWd', w * 2 * math.pi * eps0 * epsr / lnr * U0**2 * 1e-3, '{:.3f}')  # W/m, tan d = 1e-3
put('AnaJd', w * eps0 * epsr * Vp / (ri * lnr), '{:.4f}')                 # A/m2 peak at r_i
put('AnaJc', 1e-18 * Vp / (ri * lnr), '{:.2e}')
put('AnaRatio', 1e-18 / (w * eps0 * epsr), '{:.2e}')                       # sigma/(omega eps)
put('AnaDrop', w * eps0 * epsr * Vp / (ri * lnr) * 0.4e-3 / 2e-3 * 1e3, '{:.0f}')   # mV over semicon
Cbare = 2 * math.pi * eps0 * epsr / math.log(ro / rc) * 1e9                 # voltage on the Al instead
put('AnaCbare', Cbare, '{:.4f}'); put('dCbare', pct(Cbare, 2 * math.pi * eps0 * epsr / lnr * 1e9), '{:.1f}')
lnt = math.log(16.8e-3 / ri)                                               # 9 mm XLPE trial
put('AnaEithick', Vp / (ri * lnt) / 1e6, '{:.3f}'); put('AnaCthick', 2 * math.pi * eps0 * epsr / lnt * 1e9, '{:.6f}')
put('AnaDeltaAl', math.sqrt(2 / (w * mu0 * sAl)) * 1e3, '{:.2f}')          # mm
put('AnaDeltaCu', math.sqrt(2 / (w * mu0 * sCu)) * 1e3, '{:.2f}')
put('AnaLgap', 2e-7 * math.log(s_gap / (rc * math.exp(-0.25))) * 1e6, '{:.4f}')
put('AnaLtouch', 2e-7 * math.log(s_touch / (rc * math.exp(-0.25))) * 1e6, '{:.4f}')
put('NktL', 0.12 / w * 1e3, '{:.3f}')                                      # X = 0.12 ohm/km
X = 2 * w * 1e-7 * math.log(2 * s_gap / (rsi + rso))                       # screen reactance


def iec(theta_c, theta_s=None):
    """IEC 60287-1-1 conductor AC resistance and screen loss factor at given temperatures."""
    R = 0.164e-3 * (1 + aAl * (theta_c - 20))
    xs4 = (8 * math.pi * f / R * 1e-7)**2
    F = xs4 / (192 + 0.8 * xs4)
    dc = 2 * rc
    ys, yp = F, F * (dc / s_gap)**2 * (0.312 * (dc / s_gap)**2 + 1.18 / (F + 0.27))
    Rac = R * (1 + ys + yp)
    Rs = 1 / (sCu * 50e-6) * (1 + aCu * ((theta_s if theta_s is not None else theta_c) - 20))
    lam = Rs / Rac / (1 + (Rs / X)**2)
    return Rac, ys, yp, Rs, lam


Rac20, ys, yp, Rs20, lam20 = iec(20)
put('IecYs', 100 * ys, '{:.2f}'); put('IecYp', 100 * yp, '{:.2f}'); put('IecYsp', 100 * (ys + yp), '{:.2f}')
put('IecRcond', Rac20 * 1e3, '{:.5f}'); put('IecRs', Rs20 * 1e3, '{:.4f}'); put('IecX', X * 1e3, '{:.4f}')
put('IecLam', 100 * lam20, '{:.2f}'); put('IecRac', Rac20 * (1 + lam20) * 1e3, '{:.4f}')
put('IecIs', I * X / math.sqrt(Rs20**2 + X**2), '{:.1f}')
put('IecPc', 3 * I**2 * Rac20, '{:.2f}'); put('IecPs', 3 * I**2 * Rac20 * lam20, '{:.2f}')
put('IecPt', 3 * I**2 * Rac20 * (1 + lam20), '{:.2f}'); put('IecUs', X * I * 1e3, '{:.1f}')    # V/km

T1 = rhoPoly / (2 * math.pi) * math.log(rsi / rc)          # conductor -> screen
T3 = rhoPoly / (2 * math.pi) * math.log(rj / rso)          # screen -> jacket surface
u = 2 * L_bur / (2 * rj)
T4 = 1.5 / math.pi * rhoSoil * (math.log(2 * u) - 0.630)  # touching trefoil, IEC 60287-2-1


def ladder(current, theta_fixed=None):
    """IEC 60287 steady state: conductor temperature at a current, or current at theta_fixed."""
    th = 90.0
    for _ in range(100):
        Rac, _, _, _, _ = iec(th)
        th_s = th - current**2 * Rac * T1                      # screen temperature
        Rac, _, _, _, lam = iec(th, th_s)
        if theta_fixed is None:
            th = 15 + current**2 * Rac * (T1 + (1 + lam) * (T3 + T4))
        else:
            th = theta_fixed
            current = math.sqrt(75 / (Rac * (T1 + (1 + lam) * (T3 + T4))))
    return th, current, Rac, lam, th_s


th350, _, Rac90, lam90, ths = ladder(I)
# Q4.2 assumption check: halving the filler conductivity (inner filler in T1, outer in T3).
dT1f = rhoPoly / (2 * math.pi) * math.log(rsi / 16.2e-3); dT3f = rhoPoly / (2 * math.pi) * math.log(19.2e-3 / rso)
put('dTfiller', I**2 * Rac90 * (dT1f + (1 + lam90) * dT3f), '{:.1f}')
put('Hrad', 4 * 0.95 * 5.670e-8 * 288.15**3, '{:.1f}')                    # W/(m2 K), e = 0.95
put('AnaWdShare', 100 * w * 2 * math.pi * eps0 * epsr / lnr * U0**2 * 1e-3 / (I**2 * Rac90), '{:.2f}')
# Q2.8 trial with the filler kept (real redesign): every radius from the screen out grows 1 mm.
T1thick = rhoPoly / (2 * math.pi) * math.log((rsi + 1e-3) / rc)
put('dToneThick', pct(T1thick, T1), '{:.1f}')
put('dTthick', (T1thick - T1) * I**2 * Rac90, '{:.1f}')
_, Iamp, _, _, _ = ladder(I, theta_fixed=90.0)
put('IecTone', T1, '{:.3f}'); put('IecTthree', T3, '{:.3f}'); put('IecTfour', T4, '{:.3f}'); put('IecU', u, '{:.1f}')
put('IecTheta', th350, '{:.1f}'); put('IecAmp', Iamp, '{:.0f}'); put('IecThetaS', ths, '{:.0f}')
put('IecRacHot', Rac90 * (1 + lam90) * 1e3, '{:.4f}'); put('IecRcondHot', Rac90 * 1e3, '{:.4f}')
put('IecLamHot', 100 * lam90, '{:.1f}')
put('IecPcHot', 3 * I**2 * Rac90, '{:.1f}'); put('IecPsHot', 3 * I**2 * Rac90 * lam90, '{:.2f}')
Eb = 24.22 * 0.05 + 6.08 * math.sqrt(0.05)                  # kV, air, 0.5 mm, 1 bar (Schumann)
put('AnaEb', Eb / 0.5, '{:.2f}')

# ===================================================================== Section 1: mesh quality
def mesh_stats(path):
    """Triangles, minimum and number of q < 0.1 with q = 4 sqrt(3) A / sum(l^2), XLPE_A count,
    longest element edge in the aluminium and copper regions (21-23, 71-73) in m."""
    nodes, tri, phys = {}, [], []
    lines = open(path).read().split('\n')
    i = lines.index('$Nodes')
    for l in lines[i + 2:i + 2 + int(lines[i + 1])]:
        t = l.split(); nodes[t[0]] = (float(t[1]), float(t[2]))
    i = lines.index('$Elements')
    for l in lines[i + 2:i + 2 + int(lines[i + 1])]:
        t = l.split()
        if t[1] == '2':
            tri.append(t[-3:]); phys.append(int(t[3]))
    q, hmetal = [], 0.0
    for (a, b_, c), p in zip(tri, phys):
        (x1, y1), (x2, y2), (x3, y3) = nodes[a], nodes[b_], nodes[c]
        area = abs((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)) / 2
        e2 = [(x2 - x1)**2 + (y2 - y1)**2, (x3 - x2)**2 + (y3 - y2)**2, (x1 - x3)**2 + (y1 - y3)**2]
        q.append(4 * math.sqrt(3) * area / sum(e2))
        if p in (21, 22, 23, 71, 72, 73):
            hmetal = max(hmetal, math.sqrt(max(e2)))
    return len(tri), min(q), sum(1 for x in q if x < 0.1), sum(1 for p in phys if p == 41), hmetal


for case, key in [('gap', 'Gap'), ('touching', 'Touch')]:
    n_, qmin, nbad, nx, hmetal = mesh_stats(os.path.join(SRC, 'Cable-selection-and-model-setup/meshes', case + '.msh'))
    put('MeshTri' + key, n_, '{:,}'); put('MeshQmin' + key, qmin, '{:.3f}')
    put('MeshBad' + key, nbad, '{:d}'); put('MeshXlpe' + key, nx, '{:,}')
    put('MeshHmetal' + key, hmetal * 1e3, '{:.2f}')   # mm, longest edge in Al and Cu [Q3.5]

# ===================================================================== Section 2
electric = {'gap': 'gap', 'touching': 'touching', 'coarse': 'gapcoarse', 'fine': 'gapfine',
            'thick': 'thick', 'defect': 'defect', 'defect-fine': 'defectfine',
            'f5': 'ffive', 'f500': 'fhund', 'f5000': 'fthou'}
ev = {}
for case, key in electric.items():
    d = os.path.join(E, case)
    ev[key] = dict(E=num(d, 'max_field_kV_mm.dat'), C=num(d, 'capacitance_uF_km.dat'),
                   Cq=nums(d, 'capacitance_charge_uF_km.dat')[0], D=dofs(d))
    put('E' + key, ev[key]['E'], '{:.2f}' if 'defect' in key else '{:.3f}'); put('C' + key, ev[key]['C'], '{:.6f}')
    put('Cq' + key, ev[key]['Cq'], '{:.6f}'); put('Dofs' + key, ev[key]['D'], '{:,}')
    if 'defect' in case:   # mean |E| inside the void along the radial cut (void: 8.55-9.05 mm)
        cut = [l.split() for l in open(os.path.join(d, 'radial_field_A.txt'))]
        inside = [float(x[3]) for x in cut if 0.00855 < float(x[0]) < 0.00905]
        put('Vmean' + key, sum(inside) / len(inside) / 1e6, '{:.2f}')
put('JdFE', pos_max(os.path.join(E, 'gap', 'displacement_current.pos'))[0], '{:.4f}')
put('JcFE', pos_max(os.path.join(E, 'gap', 'conduction_current.pos'))[0], '{:.2e}')
Ana = Vp / (ri * lnr) / 1e6
put('dEfine', pct(ev['gapfine']['E'], Ana), '{:+.2f}'); put('dEgap', pct(ev['gap']['E'], Ana), '{:+.2f}')
put('dEtouch', pct(ev['gap']['E'], ev['touching']['E']), '{:+.3f}')
put('dCtouch', abs(pct(ev['gap']['C'], ev['touching']['C'])), '{:.0e}')
put('dCana', abs(pct(ev['gap']['C'], 2 * math.pi * eps0 * epsr / lnr * 1e9)), '{:.4f}')
put('dCnkt', pct(ev['gap']['C'], 0.22), '{:.1f}')
put('dEthick', pct(ev['thick']['E'], ev['gap']['E']), '{:.1f}')
put('dCthick', pct(ev['thick']['C'], ev['gap']['C']), '{:.1f}')
vmean = float(macros['Vmeandefectfine'])
put('VoidRatio', vmean / E0, '{:.2f}'); put('PdInception', U0 / 1e3 * Eb / 0.5 / vmean, '{:.0f}')
cur = nums(os.path.join(E, 'gap'), 'electrode_currents.dat')
pairs = [(complex(cur[2 * k], cur[2 * k + 1]), complex(cur[6 + 2 * k], cur[7 + 2 * k])) for k in range(3)]
put('Ibalance', max(abs(a + b_) / abs(a) for a, b_ in pairs), '{:.0e}')
put('IchFE', abs(pairs[0][0]) / math.sqrt(2) * 1e3, '{:.3f}')                    # A/km RMS
put('IratioFE', pairs[0][0].real / pairs[0][0].imag, '{:.2e}')

# ===================================================================== Sections 3, 4, 5
magnetic = {'base': 'base', 'stranded': 'stranded', 'stranded-f500': 'strandedfhund',
            'single': 'single', 'touching': 'touching', 'coarse': 'coarse', 'fine': 'fine',
            'box06': 'box', 'f0.01': 'fdc', 'f5': 'ffive', 'f500': 'fhund',
            'lin': 'lin', 'nl': 'nl', 'lin-iso': 'liniso', 'nl-iso': 'nliso',
            'nl-h5': 'nlhfive', 'nl-h20': 'nlhtwenty', 'nl-coarse': 'nlcoarse', 'nl-fine': 'nlfine',
            'nl-dom10': 'nldomten', 'nl-dom40': 'nldomforty'}
sec5 = {'trefoil': 'trefoil', 'trefoil-sp': 'trefoilsp', 'flat': 'flat', 'flat-sp': 'flatsp',
        'flat70': 'flatsev', 'flat70-sp': 'flatsevsp'}
nkt = {'trefoil': 350, 'trefoilsp': 350, 'flat': 350, 'flatsp': 350, 'flatsev': 365, 'flatsevsp': 380}
for case, key in sec5.items():
    magnetic[case] = key
    magnetic[case + '-I1'] = key + 'Ione'
mv = {}
for case, key in magnetic.items():
    d = os.path.join(M, case)
    r = dict(Pc=num(d, 'losses_conductors.dat'), Ps=num(d, 'losses_screens.dat'),
             Rc=num(d, 'R_conductors_ohm_km.dat'), Rac=num(d, 'R_ac_ohm_km.dat'),
             L=num(d, 'L_mH_km.dat'), D=dofs(d), I=nums(d, 'currents_A.dat'), U=nums(d, 'voltages_V_m.dat'))
    r['Pt'] = r['Pc'] + r['Ps']
    sc = r['I'][6:8] if len(r['I']) >= 12 else r['I'][0:2]        # screen A current (re, im)
    r['Is'] = math.hypot(*sc) / math.sqrt(2)
    if os.path.exists(os.path.join(d, 'Tmax_conductor.dat')):
        r['Tc'] = num(d, 'Tmax_conductor.dat'); r['Ts'] = num(d, 'Tmax_surface.dat')
        r['Qs'] = num(d, 'surface_heat_W_m.dat')
        r['Nit'] = int(float(open(os.path.join(d, 'convergence.txt')).read().split('\n')[-2].split()[1]))
    mv[key] = r
    for q, fm in [('Pc', '{:.2f}'), ('Ps', '{:.2f}'), ('Pt', '{:.2f}'), ('Rc', '{:.4f}'), ('Rac', '{:.4f}'),
                  ('L', '{:.4f}'), ('Is', '{:.1f}'), ('Tc', '{:.1f}'), ('Ts', '{:.2f}'), ('Nit', '{:d}')]:
        if q in r:
            put(q + key, r[q], fm)
    put('MDofs' + key, r['D'], '{:,}')

b, s1 = mv['base'], mv['single']
z = complex(*nums(os.path.join(M, 'base'), 'Z_terminal_ohm_km.dat')[0:2])
Lt = z.imag / w * 1e3                                       # ohm/km -> mH/km
put('Zrbase', z.real, '{:.4f}'); put('Lterm', Lt, '{:.4f}'); put('dLterm', abs(pct(Lt, b['L'])), '{:.2f}')
put('SkinFE', 100 * (b['Rc'] / mv['fdc']['Rac'] - 1), '{:.2f}')
put('ScreenFE', 100 * (b['Rac'] - b['Rc']) / mv['fdc']['Rac'], '{:.1f}')
put('LamFE', 100 * b['Ps'] / b['Pc'], '{:.1f}'); put('EddyFE', 100 * s1['Ps'] / b['Pc'], '{:.1f}')
put('PcircFE', b['Ps'] - s1['Ps'], '{:.2f}')
put('dPcirc', pct(b['Ps'] - s1['Ps'], 3 * I**2 * Rac20 * lam20), '{:+.0f}')
put('dIs', pct(b['Is'], I * X / math.sqrt(Rs20**2 + X**2)), '{:+.1f}')
sc = [complex(b['I'][6 + 2 * k], b['I'][7 + 2 * k]) for k in range(3)]
put('IsSum', abs(sum(sc)), '{:.2f}'); put('IsPeak', abs(sc[0]), '{:.0f}')
put('Usingle', max(abs(complex(s1['U'][6 + 2 * k], s1['U'][7 + 2 * k])) for k in range(3)) / math.sqrt(2) * 1e3, '{:.1f}')
put('dPtSingle', pct(s1['Pt'], b['Pt']), '{:+.1f}'); put('dRacSingle', pct(s1['Rac'], b['Rac']), '{:+.1f}')
put('dLtouch', pct(b['L'], mv['touching']['L']), '{:+.2f}'); put('dRactouch', pct(b['Rac'], mv['touching']['Rac']), '{:+.2f}')
put('dPstouch', pct(b['Ps'], mv['touching']['Ps']), '{:+.1f}')
put('dLbox', pct(mv['box']['L'], b['L']), '{:+.2f}'); put('dRacbox', pct(mv['box']['Rac'], b['Rac']), '{:+.2f}')
put('dRacfine', pct(mv['fine']['Rac'], b['Rac']), '{:+.2f}'); put('dLfine', pct(mv['fine']['L'], b['L']), '{:+.2f}')
put('dPsfine', pct(mv['fine']['Ps'], b['Ps']), '{:+.1f}')
put('dRcstr', pct(mv['stranded']['Rc'], b['Rc']), '{:+.2f}'); put('dLstr', pct(mv['stranded']['L'], b['L']), '{:+.2f}')
put('dRcstrhund', pct(mv['strandedfhund']['Rc'], mv['fhund']['Rc']), '{:+.0f}')
put('dLfreq', pct(b['L'], mv['fdc']['L']), '{:+.1f}'); put('dLfreqhund', pct(mv['fhund']['L'], mv['fdc']['L']), '{:+.0f}')
put('dLnkt', pct(mv['touching']['L'], 0.12 / w * 1e3), '{:+.1f}')
put('dLana', pct(s1['L'], 2e-7 * math.log(s_gap / (rc * math.exp(-0.25))) * 1e6), '{:+.1f}')
put('CondShare', 100 * b['Pc'] / b['Pt'], '{:.0f}')
phase_losses = [nums(os.path.join(M, 'base'), f'losses_cond{p}.dat')[0] for p in 'ABC']
put('PhaseSym', 100 * (max(phase_losses) / min(phase_losses) - 1), '{:.4f}')
put('PcPhase', b['Pc'] / 3, '{:.2f}')
bmax = pos_max(os.path.join(M, 'base', 'b_norm.pos'))
put('Bmax', bmax[0] * 1e3, '{:.1f}'); put('Bsingle', mu0 * math.sqrt(2) * I / (2 * math.pi * rc) * 1e3, '{:.1f}')
jmax = pos_max(os.path.join(M, 'base', 'j_norm.pos'))
put('Jmax', jmax[0] / 1e6, '{:.2f}'); put('Javg', math.sqrt(2) * I / (math.pi * rc**2) / 1e6, '{:.2f}')
put('Jscreen', abs(sc[0]) / 50e-6 / 1e6, '{:.1f}')

# Section 4
n, l = mv['nl'], mv['lin']
put('dPtNL', pct(n['Pt'], l['Pt']), '{:+.1f}'); put('dPcNL', pct(n['Pc'], l['Pc']), '{:+.1f}')
put('dPsNL', pct(n['Ps'], l['Ps']), '{:+.1f}'); put('dRacNL', pct(n['Rac'], l['Rac']), '{:+.1f}')
put('dLNL', pct(n['L'], l['L']), '{:+.2f}'); put('dTcNL', n['Tc'] - l['Tc'], '{:+.1f}')
put('QsFrac', 100 * n['Qs'] / n['Pt'], '{:.1f}')
put('AmpLin', 350 * math.sqrt(75 / (l['Tc'] - 15)), '{:.0f}')
put('dTcIso', n['Tc'] - mv['nliso']['Tc'], '{:.1f}')
put('dTcFine', mv['nlfine']['Tc'] - n['Tc'], '{:+.1f}'); put('dTcCoarse', mv['nlcoarse']['Tc'] - n['Tc'], '{:+.1f}')
put('dTcDom', mv['nldomforty']['Tc'] - n['Tc'], '{:+.2f}'); put('dTcDomten', mv['nldomten']['Tc'] - n['Tc'], '{:+.2f}')
put('dTcNkt', n['Tc'] - 90, '{:+.1f}'); put('dTsurf', n['Ts'] - 15, '{:.1f}')
put('RhoHot', 100 * aAl * (n['Tc'] - 20), '{:.0f}')
put('dTsemi', n['Pc'] / 3 / (2 * math.pi / rhoPoly) * math.log(ri / rc), '{:.1f}')   # drop across conductor semicon
th_lines = [l_ for l_ in open(os.path.join(M, 'nl', 'getdp.log')) if 'Dofs' in l_]
put('TDofsnl', int(th_lines[1].split()[4]), '{:,}')
# Q4.4: hottest conductor per phase (trefoil centres as in parameters.pro).
sp = s_gap; h = math.sqrt(3) / 2 * sp
centres = {'A': (0, 2 * h / 3), 'B': (-sp / 2, -h / 3), 'C': (sp / 2, -h / 3)}
tph = {k: -1.0 for k in centres}
for line in open(os.path.join(M, 'nl', 'T_conductors.pos')):
    if line.startswith('ST('):
        xy, val = line.split('{'); c = [float(t) for t in xy[3:-1].split(',')]
        k = min(centres, key=lambda q: math.hypot(c[0] - centres[q][0], c[1] - centres[q][1]))
        tph[k] = max(tph[k], max(float(t) for t in val.strip('};\n').split(',')[0:3]))
put('TcA', tph['A'], '{:.2f}'); put('TcB', tph['B'], '{:.2f}'); put('TcC', tph['C'], '{:.2f}')
put('dTcBC', abs(tph['B'] - tph['C']), '{:.2f}'); put('dTcAlow', max(tph['B'], tph['C']) - tph['A'], '{:.1f}')
hist = [l_.split() for l_ in open(os.path.join(M, 'nl', 'convergence.txt'))]
rates = [float(hist[k + 1][2]) / float(hist[k][2]) for k in range(1, len(hist) - 1)]
put('ConvRate', sum(rates) / len(rates), '{:.2f}')

# Section 5: two coupled runs per case; T_max is close to linear in I^2 -> interpolate to 90 C.
dev = []
for case, key in sec5.items():
    t0, t1 = mv[key]['Tc'], mv[key + 'Ione']['Tc']
    i1 = float(f'{350 * math.sqrt(75 / (t0 - 15)):.1f}')     # same rule as run_all.sh
    if abs(t1 - t0) > 1e-6:
        amp = math.sqrt(350**2 + (90 - t0) * (i1**2 - 350**2) / (t1 - t0))
    else:                                                   # already at 90 C: same run twice
        amp = 350 * math.sqrt(75 / (t0 - 15))
    put('Ione' + key, i1, '{:.0f}'); put('Amp' + key, amp, '{:.0f}')
    put('dNkt' + key, pct(amp, nkt[key]), '{:+.1f}'); dev.append(pct(amp, nkt[key]))
    mv[key]['Amp'] = amp
put('dNktMin', min(dev), '{:+.1f}'); put('dNktMax', max(dev), '{:+.1f}')
put('dTIone', max(abs(mv[k + 'Ione']['Tc'] - 90) for k in sec5.values()), '{:.1f}')
put('dAmpSingle', mv['trefoilsp']['Amp'] - mv['trefoil']['Amp'], '{:+.0f}')
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
for case, name in [('gap', 'radial_healthy'), ('defect-fine', 'radial_defect'), ('thick', 'radial_thick')]:
    cut = [l_.split() for l_ in open(os.path.join(E, case, 'radial_field_A.txt'))]
    csv(name + '.csv', 'r,E', [(f'{float(x[0]) * 1e3:.4f}', f'{float(x[3]) / 1e6:.5f}') for i, x in enumerate(cut)
                               if i % 4 == 0 or 'defect' in case and 0.0085 < float(x[0]) < 0.0091])
for case, name in [('nl', 'nl_history'), ('nl-coarse', 'nl_history_coarse'), ('nl-fine', 'nl_history_fine')]:
    hist = [l_.split() for l_ in open(os.path.join(M, case, 'convergence.txt'))]
    csv(name + '.csv', 'it,rel', [(int(float(x[1])), x[2]) for x in hist])
for case, name in [('nl', 'surface_nl'), ('nl-h20', 'surface_h20'), ('nl-h5', 'surface_h5')]:
    prof = [l_.split() for l_ in open(os.path.join(M, case, 'T_surface_profile.txt'))]
    csv(name + '.csv', 'x,T', [(f'{float(x[0]):.3f}', f'{float(x[3]):.4f}') for x in prof])
# Q3.2: |J| (A/mm2) along phase A's vertical diameter; s < 0 = side facing the trefoil centre.
jl = {c: [l_.split() for l_ in open(os.path.join(M, c, 'j_line_A.txt'))] for c in ('base', 'stranded')}
yc = (float(jl['base'][0][1]) + float(jl['base'][-1][1])) / 2
csv('j_profile.csv', 's,massive,stranded', [(f'{(float(a[1]) - yc) * 1e3:.3f}', f'{float(a[3]) / 1e6:.4f}',
                                             f'{float(c[3]) / 1e6:.4f}') for a, c in zip(jl['base'], jl['stranded'])])
# Q3.9: R_AC split into DC, skin + proximity and screens (ohm/km), FE and IEC 60287 at 20 C.
R20 = Rac20 / (1 + ys + yp)
csv('rac_split.csv', 'model,dc,skin,screens',
    [('FE', f"{mv['fdc']['Rac']:.5f}", f"{b['Rc'] - mv['fdc']['Rac']:.5f}", f"{b['Rac'] - b['Rc']:.5f}"),
     ('IEC', f'{R20 * 1e3:.5f}', f'{(Rac20 - R20) * 1e3:.5f}', f'{Rac20 * lam20 * 1e3:.5f}')])
# Q4.8: change from the linear (20 C) to the sigma(T) model, %.
csv('nl_change.csv', 'q,change', [(k, f"{pct(mv['nl'][k], mv['lin'][k]):.2f}") for k in ('Pc', 'Ps', 'Pt', 'Rac', 'L')])
print(len(macros), 'values written')
