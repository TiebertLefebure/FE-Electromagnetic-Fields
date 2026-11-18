# FE Electromagnetic Fields

Finite-element analysis of three NKT 33 kV, 1x240+50 mm² XLPE-AL cables,
directly buried in touching trefoil. The reference load is 415 A RMS with
both-end screen bonding. There is no armour or pipe.

## Layout

```text
Source-code/
  section_1/       cable inputs and derived geometry
  section_2/       electric model and verification study
  section_3/       magnetic model and verification study
  shared/          material inputs and TA integration rules
  legacy/          superseded 185 mm² starter model
LaTeX/
  section_1/       Section 1 report sources
  section_2/       Section 2 report sources and data
  section_3/       Section 3 report sources, tables and figures
```

Final PDFs and the original assignment/datasheet stay in the repository root.
Generated meshes, solutions and maps belong in each section's `results/`
directory and are ignored by Git. Compact verification records are kept in
`validation/`. See [the code guide](Source-code/README.md) for file responsibilities.

## Run

Gmsh and GetDP are required. The runners search PATH and the neighbouring
ONELAB installation, or accept `--gmsh` and `--getdp` executable paths.

Section 2 uses Python's standard library:

```sh
python3 Source-code/section_2/run.py --question 2.1 --open
python3 Source-code/section_2/run.py --study
```

Section 3 uses NumPy, SciPy and Matplotlib:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r Source-code/section_3/requirements.txt
.venv/bin/python Source-code/section_3/run.py --open
.venv/bin/python Source-code/section_3/run.py --study
```

The magnetic study runs 15 cases covering mesh/domain convergence,
massive/stranded phases, screen bonding, simplification and frequency.
Executed versions: Gmsh 4.15.0-git and GetDP 4.0.0-git-259f4c38.
Full build information is in `Source-code/section_3/validation/`.

## Build the reports

With `pdflatex` installed, run from the repository root:

```sh
./LaTeX/build_section_1.sh
./LaTeX/build_section_2.sh
./LaTeX/build_section_3.sh
```

The Section 2 and 3 scripts export completed studies and check saved input
hashes before compiling. LaTeX intermediates use temporary directories.
Section 3 assumes constant conductivities at 20 °C; the coupled thermal
analysis and ampacity calculation remain Section 4.

## AI assistance

Codex assisted with implementation, numerical checks and report preparation.
The reports state the modelling assumptions, sources and limitations.
