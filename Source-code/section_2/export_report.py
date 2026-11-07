"""Export the verified Section 2 study to LaTeX tables; does not run FE solves."""
from pathlib import Path
import csv
import hashlib
import json
import math

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEST = ROOT/'LaTeX/section_2'


def main():
    summary = json.loads((HERE/'validation/summary.json').read_text())
    cases = summary['cases']
    for key,case in cases.items():
        saved = json.loads((HERE/'results'/key/'metrics.json').read_text())
        if saved['options'] != case['options'] or saved['input_sha256'] != case['input_sha256']:
            raise ValueError(f'Case {key} was overwritten; rerun run.py --study.')
        for name, expected in case['input_sha256'].items():
            actual = hashlib.sha256((HERE.parent/name).read_bytes()).hexdigest()
            if actual != expected:
                raise ValueError(f'FE inputs changed: {name}. Rerun run.py --study before building the report.')
    h = cases['healthy']; a = h['phases']['A']
    v = cases['void']['phases']['A']; t = cases['thicker_xlpe']['phases']['A']
    i = cases['ideal']['phases']['A']
    exact = json.loads((HERE/'validation/analytical_reference.json').read_text())
    macros = {
        'HealthyE': f'{a["max_xlpe_peak_kV_mm"]:.4f}',
        'AnalyticalE': f'{h["analytical_inner_peak_kV_mm"]:.5f}',
        'AnalyticalOuterE': f'{h["analytical_outer_peak_kV_mm"]:.5f}',
        'HealthyC': f'{a["capacitance_uF_km"]:.8f}',
        'AnalyticalC': f'{h["analytical_capacitance_uF_km"]:.8f}',
        'FieldError': f'{summary["checks"]["healthy_peak_field_relative_error"]*100:.3f}',
        'CapError': f'{summary["checks"]["capacitance_relative_error"]*100:.5f}',
        'VoidE': f'{v["max_void_peak_kV_mm"]:.4f}',
        'VoidXLPE': f'{v["max_xlpe_peak_kV_mm"]:.4f}',
        'VoidChange': f'{summary["checks"]["defect_peak_change_last_refinement"]*100:.3f}',
        'VoidIncrease': f'{(v["max_xlpe_peak_kV_mm"]/a["max_xlpe_peak_kV_mm"]-1)*100:.2f}',
        'VoidCapChange': f'{(v["capacitance_uF_km"]/a["capacitance_uF_km"]-1)*100:.4f}',
        'ThickerE': f'{t["max_xlpe_peak_kV_mm"]:.4f}',
        'ThickerC': f'{t["capacitance_uF_km"]:.8f}',
        'FieldReduction': f'{(1-t["max_xlpe_peak_kV_mm"]/a["max_xlpe_peak_kV_mm"])*100:.2f}',
        'CapReduction': f'{(1-t["capacitance_uF_km"]/a["capacitance_uF_km"])*100:.2f}',
        'BelowMax': f'{(1-a["capacitance_uF_km"]/.24)*100:.2f}',
        'DofReduction': f'{(1-cases["ideal"]["complex_dofs"]/h["complex_dofs"])*100:.2f}',
        'ChargingPeak': f'{abs(complex(*a["terminal_current_peak_A_m"]))*1000:.5f}',
        'ChargingRMS': f'{abs(complex(*a["terminal_current_peak_A_m"]))*1000/math.sqrt(2):.5f}',
        'ContourError': f'{max(c["relative_difference"] for c in h["contour_flux_checks"])*100:.4f}',
        'InnerRMS': f'{h["analytical_inner_peak_kV_mm"]/math.sqrt(2):.4f}',
        'OuterRMS': f'{h["analytical_outer_peak_kV_mm"]/math.sqrt(2):.4f}',
        'SCFullLoss': f'{a["loss_W_m"]:.5g}',
        'IdealLoss': f'{i["loss_W_m"]:.5g}',
    }
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST/'result_values.tex').write_text('% Generated from validation/summary.json.\n'+
        '\n'.join('\\newcommand{\\%s}{%s}'%(key,value) for key,value in macros.items())+'\n')
    def table(name, header, rows):
        with (DEST/name).open('w') as f:
            w=csv.writer(f);w.writerow(header);w.writerows(rows)
    table('convergence.csv',['dof','triangles','h','cap','field','caperror'],[
        [cases[k]['complex_dofs'],cases[k]['triangles'],cases[k]['options']['MeshScale'],
         cases[k]['phases']['A']['capacitance_uF_km'],cases[k]['phases']['A']['max_xlpe_peak_kV_mm'],
         (cases[k]['phases']['A']['capacitance_uF_km']/h['analytical_capacitance_uF_km']-1)*1e6]
        for k in ['coarse','medium','healthy']])
    for case in ['healthy','void','thicker_xlpe']:
        rows=list(csv.DictReader((HERE/'results'/case/'radial_cut.csv').open()))
        table(case+'_cut.csv',['radius','field'],[(r['radius_mm'],r['E_peak_kV_mm']) for r in rows])
    table('frequency.csv',['frequency','cap'],[(cases[k]['options']['Freq'],cases[k]['phases']['A']['capacitance_uF_km'])
          for k in ['freq_5','healthy','freq_500','freq_5000']])
    rows=[]
    with (HERE/'results/healthy/radial_cut.csv').open() as f: samples=list(csv.DictReader(f))
    with (HERE/'results/void/radial_cut.csv').open() as f: voidsamples=list(csv.DictReader(f))
    for data,target,label in [(samples,8.9,'Inner semiconductor'),(samples,13.3,'XLPE'),
                               (samples,17.7,'Outer semiconductor'),(voidsamples,10.3,'Gas void (defect)')]:
        r=min(data,key=lambda x:abs(float(x['radius_mm'])-target))
        rows.append(label+' & '+f'{float(r["radius_mm"]):.3f}'+
                    ' & '+r'\num{'+f'{float(r["J_cond_peak_A_m2"]):.3g}'+'} & '+r'\num{'+f'{float(r["J_disp_peak_A_m2"]):.3g}'+'}'+r' \\')
    (DEST/'current_rows.tex').write_text('\\newcommand{\\CurrentRows}{%\n'+'\n'.join(rows)+'%\n}\n')
    # Formula comparison is exported separately to avoid reporting rounded zeros.
    (DEST/'analytical_checks.json').write_text(json.dumps(exact,indent=2)+'\n')
    print('Exported Section 2 report data; all 10 FE input hashes match.')

if __name__=='__main__':
    main()
