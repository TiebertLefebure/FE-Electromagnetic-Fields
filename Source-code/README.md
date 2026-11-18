# Cable analysis code

Each assignment section owns its model, runner, results and verification data.
Common inputs and the TA integration rules belong in `shared/`. Reports are
built from `../LaTeX/`; final PDFs are in the repository root.

| Folder | Contents |
|---|---|
| `section_1/` | Cable data and derived geometry |
| `section_2/` | Electric-field model and Q2 verification/design cases |
| `section_3/` | Magnetic model and Q3 verification/design cases |
| `shared/` | Material inputs and original TA integration rules |
| `legacy/` | Superseded 185 mm² starter, excluded from current analyses |

## Question guide

Paths are relative to this folder. Section READMEs contain exact commands.

| Questions | Main files |
|---|---|
| Q1.1-Q1.4 | `section_1/cable_inputs.json`, `calculate_geometry.py`, `derived_geometry.json`; Section 1 PDF |
| Q2.1-Q2.2 | `section_2/cable.geo`, `cable.pro`, `settings.inc`, `prepare.py` |
| Q2.3-Q2.8 | `section_2/study.py`, `analyse.py`, `validation/`; Section 2 PDF |
| Q3.1 | `section_3/model.geo`, `model.pro`, `settings.inc`, `prepare.py` |
| Q3.2-Q3.3 | `section_3/model.pro`: conductor models and global current/voltage constraints |
| Q3.4-Q3.5 | `section_3/study.py`, `model.geo`, `analyse.py`, `validation/summary.json` |
| Q3.6-Q3.8 | `section_3/analyse.py`, `results/baseline/fields.npz`, `metrics.json`, `view.geo` |
| Q3.9-Q3.11 | `section_3/report.py`, `validation/analytical_checks.json`, `validation/RESULTS.md`; Section 3 PDF |

For one electric-analysis question, run for example
`python3 section_2/run.py --question 2.5 --open`. The
[Section 2 README](section_2/README.md) lists a command, output files and the
relevant code for every Q2 question. `--study` reproduces all ten cases.

The electric model solves screened dielectric interiors. The magnetic model
includes aluminium, copper and the surrounding domain. The 415 A longitudinal
load belongs to the magnetic model; it does not excite the transverse electric
problem. Both `analyse.py` files integrate GetDP results rather than solving
another FE problem.

Edit `section_1/cable_inputs.json` for dimensions and excitation. Section 2
material data are in `shared/materials.json`; Section 3 reference metal/soil
values are in `section_3/prepare.py`, following the Section 1 material table.
The runners generate `parameters.inc` and expose its values to ONELAB.

`results/<case>/` holds bulky reproducible output. Reusing a case name replaces
that case. `validation/` holds the compact record supporting each report.
Original TA formulations remain in their sections; cable-specific formulations
include `shared/Jacobian_Integration.pro` directly.
