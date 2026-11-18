#!/usr/bin/env python3
"""Run Section 2: python3 run.py --question 2.5 --open (or --study for all cases)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory

from analyse import analyse
from plots import write_viewer
from prepare import HERE, PARAMETERS, SHARED, prepare

DEFAULTS = dict(MeshScale=0.25, Freq=50, IdealScreens=0, Defect=0, ExtraXLPE=0)


def executable(name, override=None):
    """Find gmsh/getdp; --gmsh, --getdp and environment variables override defaults."""
    candidate = override or os.environ.get(name.upper() + '_BIN') or shutil.which(name)
    if candidate:
        path = Path(shutil.which(candidate) or candidate)
        if path.is_file():
            return str(path.resolve())
        raise FileNotFoundError(f'{name} not found at {candidate}')
    candidates = [Path('/Applications/Gmsh.app/Contents/MacOS')/name]
    candidates += sorted(HERE.parents[2].glob('ONELAB*/Gmsh.app/Contents/MacOS/' + name))
    for path in candidates:
        if path.is_file():
            return str(path.resolve())
    raise FileNotFoundError(f'Set {name.upper()}_BIN or pass --{name} /path/to/{name}.')


def command(arguments, log):
    """Run one tool and keep its complete output. Gmsh can return 0 after an error."""
    result = subprocess.run(arguments, cwd=HERE, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    log.write_text(result.stdout)
    error = re.search(r'(?im)^\s*(Error\s*:|Fatal|\[\d+\]PETSC ERROR)', result.stdout)
    if result.returncode or error:
        raise RuntimeError(f'Command failed; see {log}\n{result.stdout[-3000:]}')
    return result.stdout


def input_hashes():
    """Record model and numerical scripts so an edited model cannot reuse a stale report."""
    files = [HERE/name for name in ['cable.geo', 'cable.pro', 'settings.inc',
                                   'parameters.inc', 'prepare.py', 'analyse.py', 'run.py']]
    files += [PARAMETERS/'cable_inputs.json', SHARED/'materials.json', SHARED/'Jacobian_Integration.pro']
    return {str(path.relative_to(HERE.parent)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in files}


def run_case(name, options, gmsh, getdp, maps=True):
    """Mesh -> solve -> analyse. Both Gmsh and GetDP receive the same case options."""
    if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
        raise ValueError('Use letters, numbers, underscores or hyphens for the case name.')
    options = DEFAULTS | options
    if options['MeshScale'] <= 0 or options['Freq'] <= 0 or not 0 <= options['ExtraXLPE'] <= 0.004:
        raise ValueError('Require mesh scale/frequency > 0, and extra XLPE between 0 and 4 mm.')
    parameters, materials = prepare()
    destination = HERE/'results'/name
    destination.mkdir(parents=True, exist_ok=True)
    flags = []
    for key, value in options.items():
        flags += ['-setnumber', key, str(value)]

    # Work locally: cloud-sync providers can time out reading large meshes.
    # Copy completed outputs back to the normal results/<case> folder.
    with TemporaryDirectory(prefix='feem-electric-') as temporary:
        directory = Path(temporary)
        command([gmsh, str(HERE/'cable.geo'), '-2', '-format', 'msh2',
                 '-o', str(directory/'cable.msh'), '-v', '4', *flags], directory/'mesh.log')
        output = command([
            getdp, str(HERE/'cable.pro'), '-msh', str(directory/'cable.msh'),
            '-name', str(directory/'solution'), '-solve', 'Electrodynamics',
            '-pos', 'Export' if maps else 'Nodes', '-setstring', 'ResultDir', str(directory),
            '-v', '4', *flags,
        ], directory/'solver.log')
        metrics = analyse(directory, parameters, materials, options)
        reported_dofs = int(re.search(r'System 1/1:\s+(\d+) Dofs', output)[1])
        assert reported_dofs in (metrics['complex_dofs'], metrics['real_dofs']), 'Unexpected solver DOF count'
        metrics['getdp_reported_dofs'] = reported_dofs
        metrics['input_sha256'] = input_hashes()
        (directory/'metrics.json').write_text(json.dumps(metrics, indent=2) + '\n')
        snapshot = dict(cable=parameters, materials=materials, options=options)
        (directory/'input_snapshot.json').write_text(json.dumps(snapshot, indent=2) + '\n')
        if maps:
            write_viewer(directory)
        for path in directory.iterdir():
            # Replacing a fresh file avoids downloading an old cloud placeholder
            # merely to open it for writing. The final filenames stay unchanged.
            new_file = destination/('.' + directory.name + '-' + path.name)
            shutil.copyfile(path, new_file)
            new_file.replace(destination/path.name)
    phase = metrics['phases']['A']
    print(f'{name}: {metrics["complex_dofs"]} complex DOFs; '
          f'C_A={phase["capacitance_uF_km"]:.6f} uF/km; '
          f'E_XLPE,max={phase["max_xlpe_peak_kV_mm"]:.4f} kV/mm peak', flush=True)
    return metrics


def open_in_gmsh(path, gmsh):
    """Open a field viewer or comparison plot after the calculation finishes."""
    if sys.platform == 'darwin':
        app = Path('/Applications/Gmsh.app')
        subprocess.run(['open', '-a', str(app) if app.is_dir() else 'Gmsh', str(path)], check=True)
    else:
        subprocess.Popen([gmsh, str(path)])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--question', choices=[f'2.{n}' for n in range(1, 9)],
                      help='Run the cases needed for one assignment question')
    mode.add_argument('--study', action='store_true', help='Run all ten verification/design cases')
    parser.add_argument('--case', default='healthy', help='Output folder name for a custom single case')
    parser.add_argument('--mesh-scale', type=float, default=0.25, help='Bulk element size / 1 mm')
    parser.add_argument('--frequency', type=float, default=50)
    parser.add_argument('--ideal-screens', action='store_true')
    parser.add_argument('--defect', action='store_true')
    parser.add_argument('--extra-xlpe-mm', type=float, default=0)
    parser.add_argument('--gmsh')
    parser.add_argument('--getdp')
    parser.add_argument('--open', action='store_true', help='Open the relevant result in Gmsh')
    args = parser.parse_args()
    options = dict(MeshScale=args.mesh_scale, Freq=args.frequency,
                   IdealScreens=int(args.ideal_screens), Defect=int(args.defect),
                   ExtraXLPE=args.extra_xlpe_mm/1000)
    if (args.study or args.question) and (options != DEFAULTS or args.case != 'healthy'):
        parser.error('Question/study runs choose their own settings. Use --case for custom settings.')
    gmsh = executable('gmsh', args.gmsh)
    getdp = executable('getdp', args.getdp)
    if args.study or args.question:
        from study import study
        viewer = study(gmsh, getdp, args.question)
    else:
        run_case(args.case, options, gmsh, getdp)
        viewer = HERE/'results'/args.case/'view.geo'
    if args.open:
        open_in_gmsh(viewer, gmsh)


if __name__ == '__main__':
    main()
