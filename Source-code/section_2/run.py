#!/usr/bin/env python3
"""Mesh, solve, verify and view Section 2. Python standard library only."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from prepare import prepare, HERE, PARAMETERS, SHARED
from analyse import analyse


def executable(name, override):
    candidate = override or os.environ.get(name.upper()+'_BIN') or shutil.which(name)
    if candidate:
        resolved = shutil.which(candidate) or candidate
        if Path(resolved).is_file():
            return str(Path(resolved).resolve())
        raise SystemExit(f'{name} executable not found: {candidate}')
    candidates = [Path('/Applications/Gmsh.app/Contents/MacOS')/name]
    candidates += sorted(HERE.parents[2].glob('ONELAB*/Gmsh.app/Contents/MacOS/'+name))
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate.resolve())
    raise SystemExit(f'{name} not found. Set {name.upper()}_BIN to its executable or use --{name}.')


def command(args, log):
    result = subprocess.run(args, cwd=HERE, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_text(result.stdout)
    # Some Gmsh builds return success despite parsing errors: check the log too.
    if result.returncode or re.search(r'(?im)^\s*(?:Error\s*:|Error\s*\[|Fatal|\[\d+\]PETSC ERROR)',result.stdout):
        raise RuntimeError(f'Command failed; see {log}\n{result.stdout[-5000:]}')
    return result.stdout


def write_viewer(directory):
    views = [('e_peak.pos','|E phasor| [kV/mm]'), ('potential_real.pos','Re(V) [kV]'),
             ('e_real.pos','Re(E) [kV/mm]'), ('j_conduction.pos','Conduction current density'),
             ('j_displacement.pos','Displacement current density')]
    text = '// Generated result viewer; open this file in Gmsh. Coordinates in metres.\n'
    text += 'If (PostProcessing.NbViews > 0)\n  For old In {0:PostProcessing.NbViews-1}\n    View[old].Visible = 0;\n  EndFor\nEndIf\n'
    text += 'first = PostProcessing.NbViews;\nMerge "cable.msh";\n'
    for i,(filename,_) in enumerate(views):
        text += f'Merge "{filename}";\nView[first+{i}].Visible = {1 if i == 0 else 0};\n'
        text += f'View[first+{i}].ShowTime = 0;\nView[first+{i}].TimeStep = 0;\n'
        text += f'View[first+{i}].Type = 1; View[first+{i}].ShowScale = 1;\n'
        text += f'View[first+{i}].IntervalsType = 3;\nView[first+{i}].NbIso = 30;\n'
    text += 'View[first].Type = 1; View[first].ShowScale = 1;\n'
    text += 'Mesh.SurfaceEdges = 0; Mesh.SurfaceFaces = 0; Mesh.Points = 0;\n'
    text += 'Geometry.Points = 0; General.Axes = 0; General.Trackball = 0;\n'
    text += 'General.RotationX = 0; General.RotationY = 0; General.RotationZ = 0;\n'
    text += 'General.ScaleX = 1; General.ScaleY = 1; General.ScaleZ = 1;\n'
    text += 'General.TranslationX = 0; General.TranslationY = 0; General.TranslationZ = 0;\n'
    text += 'General.Orthographic = 1; BoundingBox; Draw;\n'
    (directory/'view.geo').write_text(text)


def run_case(name, options, gmsh, getdp, maps=True):
    if not re.fullmatch(r'[a-zA-Z0-9_-]+',name):
        raise ValueError('Case name must contain only letters, digits, underscores or hyphens')
    if options['MeshScale'] <= 0 or options['Freq'] <= 0 or not 0 <= options['ExtraXLPE'] <= .004:
        raise ValueError('Require mesh scale > 0, frequency > 0, and 0 <= extra XLPE <= 0.004 m')
    params,materials = prepare()
    directory = HERE/'results'/name
    directory.mkdir(parents=True,exist_ok=True)
    flags = [item for key,value in options.items() for item in ['-setnumber',key,str(value)]]
    command([gmsh,str(HERE/'cable.geo'),'-2','-format','msh2','-o',str(directory/'cable.msh'),'-v','4',*flags],directory/'mesh.log')
    output=command([getdp,str(HERE/'cable.pro'),'-msh',str(directory/'cable.msh'),
                   '-name',str(directory/'solution'),'-solve','Electrodynamics','-pos',('Export' if maps else 'Nodes'),
                   '-setstring','ResultDir',str(directory),'-v','4',*flags],directory/'solver.log')
    metrics = analyse(directory,params,materials,options)
    # Verify complex-vs-real DOF counting against the actual solver build.
    dofs = re.search(r'System 1/1:\s+(\d+) Dofs',output)
    assert dofs and int(dofs[1]) in (metrics['complex_dofs'],metrics['real_dofs'])
    metrics['getdp_reported_dofs'] = int(dofs[1])
    metrics['input_sha256'] = {str(f.relative_to(HERE.parent)): hashlib.sha256(f.read_bytes()).hexdigest()
        for f in [HERE/'cable.geo',HERE/'cable.pro',HERE/'settings.inc',HERE/'parameters.inc',
                  SHARED/'Jacobian_Integration.pro',PARAMETERS/'cable_inputs.json',SHARED/'materials.json']}
    (directory/'metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
    (directory/'input_snapshot.json').write_text(json.dumps(dict(cable=params,materials=materials,options=options),indent=2)+'\n')
    if maps:
        write_viewer(directory)
    a = metrics['phases']['A']
    print(f'{name}: {metrics["complex_dofs"]} complex DOFs; '
          f'C_A={a["capacitance_uF_km"]:.6f} uF/km; '
          f'E_XLPE,max={a["max_xlpe_peak_kV_mm"]:.4f} kV/mm peak',flush=True)
    return metrics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--study',action='store_true',help='Run Section 2 verification and comparison cases')
    parser.add_argument('--case',default='healthy')
    parser.add_argument('--mesh-scale',type=float,default=.25,help='Nominal element size = scale * 1 mm')
    parser.add_argument('--frequency',type=float,default=50)
    parser.add_argument('--ideal-screens',action='store_true')
    parser.add_argument('--defect',action='store_true')
    parser.add_argument('--extra-xlpe-mm',type=float,default=0)
    parser.add_argument('--gmsh'); parser.add_argument('--getdp')
    parser.add_argument('--open',action='store_true',help='Open the computed result in Gmsh')
    args=parser.parse_args()
    gmsh,getdp=executable('gmsh',args.gmsh),executable('getdp',args.getdp)
    if args.study:
        from study import study
        study(gmsh,getdp)
        name='healthy'
    else:
        options=dict(MeshScale=args.mesh_scale,Freq=args.frequency,IdealScreens=int(args.ideal_screens),
                     Defect=int(args.defect),ExtraXLPE=args.extra_xlpe_mm/1000)
        run_case(args.case,options,gmsh,getdp)
        name=args.case
    if args.open:
        viewer=HERE/'results'/name/'view.geo'
        if sys.platform=='darwin':
            app=Path('/Applications/Gmsh.app')
            subprocess.run(['open','-a',str(app) if app.is_dir() else 'Gmsh',str(viewer)],check=True)
        else:
            subprocess.Popen([gmsh,str(viewer)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)

if __name__=='__main__':
    main()
