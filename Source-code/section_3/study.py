"""Run mesh, boundary, conductor, bonding and frequency comparisons."""
import json
from math import log
import subprocess

from prepare import HERE, prepare
from run import run_case


def study(gmsh, getdp):
    cases = {
        'coarse': dict(MeshScale=2),
        'medium': dict(MeshScale=1),
        'baseline': {},
        'fine': dict(MeshScale=0.25),
        'small_domain': dict(OuterRadius=0.25),
        'large_domain': dict(OuterRadius=1),
        'stranded': dict(Stranded=1),
        'single_point': dict(SinglePoint=1),
        'no_screens': dict(Screens=0),
        'simplified': dict(Detailed=0),
        'no_soil': dict(SigmaSoil=0),
        'analytical_trefoil': dict(Stranded=1,Screens=0,SigmaSoil=0,OuterRadius=1),
        'frequency_5': dict(Freq=5),
        'frequency_200': dict(Freq=200),
        'frequency_1000': dict(Freq=1000,MeshScale=0.25),
    }
    summary = {name:run_case(name,options,gmsh,getdp) for name,options in cases.items()}
    validation = HERE/'validation'
    validation.mkdir(exist_ok=True)
    for name, binary, flag in [('gmsh',gmsh,'-version'),('getdp',getdp,'-info')]:
        version = subprocess.run([binary,flag],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True)
        (validation/f'{name}_version.txt').write_text(version.stdout)
    baseline, fine = summary['baseline'], summary['fine']
    for key in ('loss_total_W_m','resistance_ohm_km','inductance_mH_km'):
        if abs(baseline[key]/fine[key]-1) > 0.005:
            raise ValueError(f'Mesh convergence exceeds 0.5% for {key}')
    if summary['single_point']['loss_total_W_m'] >= baseline['loss_total_W_m']:
        raise ValueError('The bonding comparison does not reduce losses.')
    parameters = prepare()
    analytical_l = 0.2*(log(2*parameters['R6']/parameters['R0'])+0.25)
    reference = summary['analytical_trefoil']
    if abs(reference['inductance_mH_km']/analytical_l-1) > 0.005:
        raise ValueError('The analytical trefoil inductance check exceeds 0.5%.')
    if abs(reference['resistance_ohm_km']/0.125-1) > 0.005:
        raise ValueError('The uniform-current DC resistance check exceeds 0.5%.')
    (validation/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(f'Completed {len(summary)} checked cases.',flush=True)


if __name__ == '__main__':
    from run import executable
    study(executable('gmsh'),executable('getdp'))
