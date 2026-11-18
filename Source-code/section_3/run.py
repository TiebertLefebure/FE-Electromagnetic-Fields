"""Mesh, solve and check the Section 3 magnetic model."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from analyse import analyse, read_mesh, triangle_geometry, write_views
from prepare import HERE, prepare

DEFAULTS = dict(MeshScale=0.5, OuterRadius=0.5, Stranded=0, SinglePoint=0,
                Detailed=1, Screens=1, Freq=50)


def executable(name, override=None):
    candidate = override or os.environ.get(name.upper()+'_BIN') or shutil.which(name)
    if candidate:
        path = Path(shutil.which(candidate) or candidate)
        if path.is_file():
            return str(path.resolve())
    candidates = [Path('/Applications/Gmsh.app/Contents/MacOS')/name]
    candidates += sorted(HERE.parents[2].glob('ONELAB*/Gmsh.app/Contents/MacOS/'+name))
    for path in candidates:
        if path.is_file():
            return str(path.resolve())
    raise FileNotFoundError(f'Set {name.upper()}_BIN or pass --{name}.')


def command(args, log):
    result = subprocess.run(args, cwd=HERE, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_text(result.stdout)
    if result.returncode or re.search(r'(?im)^\s*(Error\s*:|Fatal|\[\d+\]PETSC ERROR)', result.stdout):
        raise RuntimeError(f'Command failed; see {log}\n{result.stdout[-3000:]}')
    return result.stdout


def input_hashes():
    paths = [HERE/name for name in ('model.geo','model.pro','settings.inc','parameters.inc','analyse.py','run.py','prepare.py')]
    paths += [HERE.parent/'shared/Jacobian_Integration.pro', HERE.parent/'shared/materials.json',
              HERE.parent/'section_1/cable_inputs.json']
    return {str(p.relative_to(HERE.parent)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def run_case(name, options, gmsh, getdp):
    if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
        raise ValueError('Use letters, numbers, underscores or hyphens for the case name.')
    options = DEFAULTS | options
    if options['MeshScale'] <= 0 or options['OuterRadius'] <= 0.06 or options['Freq'] <= 0:
        raise ValueError('Require positive mesh scale and frequency, and outer radius > 0.06 m.')
    parameters = prepare()
    directory = HERE/'results'/name
    directory.mkdir(parents=True, exist_ok=True)
    flags = [s for key,value in options.items() for s in ('-setnumber', key, str(value))]
    command([gmsh,str(HERE/'model.geo'),'-2','-format','msh2','-o',str(directory/'model.msh'),'-v','4',*flags],directory/'mesh.log')
    xy, tri, regions, _ = read_mesh(directory/'model.msh')
    area = triangle_geometry(xy, tri)[0]
    phase_areas = [area[regions == r].sum() for r in (100,200,300)]
    if max(phase_areas)/min(phase_areas)-1 > 1e-10:
        raise ValueError('The three conductor areas differ.')
    flags += ['-setnumber','PhaseArea',str(phase_areas[0])]
    output = command([getdp,str(HERE/'model.pro'),'-msh',str(directory/'model.msh'),
        '-name',str(directory/'solution'),'-solve','SolveMagnetic','-pos','Export',
        '-setstring','ResultDir',str(directory),'-v','4',*flags],directory/'solver.log')
    metrics = analyse(directory, parameters, options)
    metrics['getdp_real_dofs'] = int(re.search(r'System 1/1:\s+(\d+) Dofs',output)[1])
    if metrics['getdp_real_dofs'] != 2*metrics['complex_dofs']:
        raise ValueError('Unexpected GetDP degree-of-freedom count.')
    metrics['input_sha256'] = input_hashes()
    (directory/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    (directory/'inputs.json').write_text(json.dumps(dict(parameters=parameters,options=options),indent=2)+'\n')
    print(f'{name}: {metrics["complex_dofs"]} complex DOFs; '
          f'P={metrics["loss_total_W_m"]:.6f} W/m; '
          f'R={metrics["resistance_ohm_km"]:.6f} ohm/km; '
          f'L={metrics["inductance_mH_km"]:.6f} mH/km',flush=True)
    return metrics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--study',action='store_true')
    parser.add_argument('--case',default='baseline')
    parser.add_argument('--mesh-scale',type=float,default=0.5)
    parser.add_argument('--outer-radius',type=float,default=0.5)
    parser.add_argument('--frequency',type=float,default=50)
    parser.add_argument('--stranded',action='store_true')
    parser.add_argument('--single-point',action='store_true')
    parser.add_argument('--simplified',action='store_true')
    parser.add_argument('--open',action='store_true',help='Open the result in Gmsh')
    parser.add_argument('--gmsh'); parser.add_argument('--getdp')
    args = parser.parse_args()
    gmsh, getdp = executable('gmsh',args.gmsh), executable('getdp',args.getdp)
    if args.study:
        from study import study
        study(gmsh,getdp)
    else:
        run_case(args.case,dict(MeshScale=args.mesh_scale,OuterRadius=args.outer_radius,
            Freq=args.frequency,Stranded=int(args.stranded),SinglePoint=int(args.single_point),
            Detailed=int(not args.simplified)),gmsh,getdp)
    directory = HERE/'results'/('baseline' if args.study else args.case)
    write_views(directory)
    if args.open:
        subprocess.Popen([gmsh,str(directory/'view.geo')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    main()
