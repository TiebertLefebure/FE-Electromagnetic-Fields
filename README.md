# FE Electromagnetic Fields

Section 1 defines three NKT 33 kV single-core XLPE-AL, 1x240+50 mm2 cables
in touching trefoil, directly buried without armour or a pipe. The 415 A RMS
manufacturer rating is the validation reference under the stated soil,
burial-depth and both-ends screen-bonding conditions.

## Repository layout

PDFs are kept in the repository root. The current source layout is:

```text
.
├── Source-code/
│   ├── README.md             codebase and question-to-file guide
│   ├── section_1/            cable data, geometry calculations
│   ├── section_2/            electric FE model, runner, results
│   ├── section_3/            TA magnetic formulation; driver not yet implemented
│   └── shared/               TA integration rules and common electrical properties
├── LaTeX/
│   ├── assignment_questions.tex
│   ├── build_section_1.sh
│   ├── build_section_2.sh
│   ├── section_1/
│   └── section_2/
├── Section_1_Cable_Selection_and_Model_Setup.pdf
├── Section_2_Electrodynamic_Analysis.pdf
├── Datasheet 33 kV single core cable XLPE-AL.pdf
├── NMES_Assignment_2026.pdf
└── Intro GetDP.pdf
```

Store code and generated results per numbered assignment section under
`Source-code/section_n/`. Common definitions belong to `Source-code/shared/`.
See `Source-code/README.md` for exactly which files each question needs.
The supplied `.pro` files are supporting formulations and integration rules.
The `section_2/` subfolder implements Section 2 with three screened cable
interiors, complex ABC voltages, Gmsh field views and a verified comparison study.
Magnetoquasistatic and coupled thermal main problems are still to be implemented.

## Model data and assumptions

Edit `Source-code/section_1/cable_inputs.json` for dimensions and provenance.
`calculate_geometry.py` derives all radii, preserves the 50 mm2 copper metal
area, checks the layer ordering and touching-trefoil spacing, and computes
the resistance-calibrated aluminium conductivity
and peak excitations. It writes `derived_geometry.json` and the LaTeX macros
in `geometry_values.tex`.

The PDF distinguishes manufacturer dimensions, choices borrowed from utility
specifications, geometric equivalents, and material proxies. In particular,
bedding and backfill are homogenised as soil, the 1 m depth is measured to the
trefoil centroid, and discrete installation restraints are omitted from the 2D
section. Only the three copper screens require bonding conditions. The former
armour/pipe geometry and its preliminary derating estimate are no longer part
of the model. The coupled FE calculation must still validate the 415 A rating.

## Run Section 2

Double-click `Source-code/section_2/Run Section 2.command` to solve and open
Gmsh. Or, from the repository root:

```sh
python3 "Source-code/section_2/run.py" --open
python3 "Source-code/section_2/run.py" --study
```

See `Source-code/section_2/README.md` for equations, sources, assumptions,
case controls and tool setup. `Source-code/README.md` explains the full codebase.
`validation/RESULTS.md` in the section_2 directory contains
the executed Q2 study. The launcher needs only Python's standard library plus
Gmsh/GetDP. Bulky reproducible FE results remain in the source subfolder and are
ignored by Git; compact validation summaries and Gmsh plots are versionable.

## Build the PDFs

Requires Python 3 (standard library only) and `pdflatex`, for example from
MacTeX. Run from the repository root:

```sh
./LaTeX/build_section_1.sh
./LaTeX/build_section_2.sh
```

The Section 1 script updates the derived geometry and writes
`Section_1_Cable_Selection_and_Model_Setup.pdf`. The Section 2 script exports the existing verified
GetDP study and writes `Section_2_Electrodynamic_Analysis.pdf`, covering Q2.1–Q2.8
with modelling choices, plots and limitations. Both PDFs are in the repository root. LaTeX build
intermediates are created in the system temporary directory and removed
automatically. Open `LaTeX/section_1` in Codex to edit the LaTeX project.

## AI assistance

Codex assisted with the Section 1 draft, source research, modelling assumptions,
LaTeX typesetting, geometry calculations, the PDF build script, and the Section 2
Gmsh/GetDP implementation and verification study. Sources and
limitations are stated in the document; the calculations do not substitute for
FE validation of fields, losses or ampacity.
