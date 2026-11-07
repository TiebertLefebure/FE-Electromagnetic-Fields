# Source code: cable model and lab workflow

This folder contains the numerical model for three NKT 33 kV XLPE-AL
1×240+50 mm² single-core cables, directly buried in touching trefoil, without
steel armour or a pipe. **Section 2 is implemented and verified.** The supplied
magnetic formulation is available in `section_3/`; the complete magnetic and
coupled thermal problems have not yet been implemented.

## Start here

On macOS, double-click **[Run Section 2.command](section_2/Run%20Section%202.command)**.
It meshes the healthy cable interiors, solves with GetDP, checks the result and
opens the electric-field map in Gmsh.

From a terminal whose working directory is this `Source-code` folder:

```sh
python3 section_2/run.py --open
python3 section_2/run.py --study
```

The first command solves the fine healthy case. The second runs the ten-case
verification/design study and writes its summary and Gmsh comparison plots.
Python uses only its standard library; Gmsh and GetDP must be installed.
The runner finds executables on PATH or in the neighbouring ONELAB application.
You can specify `--gmsh /path/to/gmsh` and `--getdp /path/to/getdp`, or use the
`GMSH_BIN` and `GETDP_BIN` environment variables.

The Python runner invokes GetDP directly. The Gmsh dialog asking for the GetDP
executable belongs to Gmsh's integrated solver interface; it is not required
merely to open a previously computed result viewer.

To inspect saved results without solving, open
[`section_2/results/healthy/view.geo`](section_2/results/healthy/view.geo)
in Gmsh. Toggle potential, electric field, conduction current density and
displacement current density under **Post-processing**. The magnitude field
uses the first exported time step. The central holes represent omitted ideal
aluminium electrodes; the outside gaps include omitted copper and PE layers.
They are not physical gas gaps in the manufactured cable.

## Folder structure

```text
Source-code/
├── README.md
├── section_1/
│   ├── README.md
│   ├── cable_inputs.json
│   ├── calculate_geometry.py
│   └── derived_geometry.json
├── section_2/
│   ├── README.md
│   ├── Run Section 2.command
│   ├── electrodynamic_formulation.pro     original TA reference
│   ├── cable.geo, cable.pro, settings.inc
│   ├── prepare.py, parameters.inc
│   ├── run.py, analyse.py, study.py
│   ├── export_report.py
│   ├── results/<case>/
│   └── validation/
├── section_3/
│   ├── README.md
│   └── magnetodynamic_formulation.pro     original TA reference; no driver yet
└── shared/
    ├── README.md
    ├── Jacobian_Integration.pro
    └── materials.json
```

**Organisation policy:** put code and results for question Qn.x under
`section_n/`. Put only definitions used by multiple sections under `shared/`.
Create future section folders when their implementation begins. Keep the final
PDFs in the repository root and document sources in `../LaTeX/`.

Generated FE files stay under `results/` and are ignored by Git. Compact
validation results, plots and source files can be versioned. The final PDFs
are in the repository root; LaTeX sources and build scripts are in `../LaTeX/`.

## How the files fit together

```text
section_1/cable_inputs.json + shared/materials.json
                         |
                      prepare.py
                         |
                  parameters.inc
                         |
                    settings.inc
                    /          \
            cable.geo          cable.pro
                |                  |
              Gmsh -> cable.msh -> GetDP
                                   |
                         solution + nodal voltages
                                   |
                              analyse.py
                                   |
                         metrics + cuts + checks

run.py coordinates the workflow and exports Gmsh field maps.
study.py repeats it for the verification/design cases and creates plots.
export_report.py reads that completed study for the LaTeX report.
```

**`analyse.py` does not solve another FE problem.** It reads GetDP's nodal
voltages, reconstructs each P1 triangle gradient, integrates energy/losses and
assembles terminal reactions for an independent conservation check.

## Are the TA files called?

Inside `section_2/cable.pro`:

```c
Include "settings.inc";
Include "../shared/Jacobian_Integration.pro";
```

`settings.inc` includes `parameters.inc`. The TA integration/Jacobian file in `shared/` is
therefore used directly. All three original TA `.pro` files remain unchanged.

The TA's `electrodynamic_formulation.pro` is the starting reference for the
weak formulation, but is **not included directly**. Its geometry-specific
regions, cuts and GUI helper were replaced in `cable.pro`, with explicit
phase voltages, post-processing and per-phase capacitance checks. The physical
resistive-plus-displacement-current equation is retained. The magnetic TA file
is not used by Section 2.

## Files needed for each question

Paths below are relative to this `Source-code` folder. **Common Section 2 model**
means `section_2/cable.geo`, `cable.pro`, `settings.inc`, `prepare.py`, generated
`parameters.inc`, and `run.py`, plus `section_1/cable_inputs.json`,
`shared/materials.json` and `shared/Jacobian_Integration.pro`. The runner supplies
matching geometry/solver options. All original TA files are preserved.

| Question | Files to use | How to obtain / inspect the result |
|---|---|---|
| Q1.1 | `section_1/cable_inputs.json`, `section_1/calculate_geometry.py`, `shared/materials.json`; datasheet/literature in the PDF | Run `python3 section_1/calculate_geometry.py`; inspect `section_1/derived_geometry.json`. The full sourced material table is in `../LaTeX/section_1/main.tex`. |
| Q1.2 | `section_1/cable_inputs.json`; datasheet and PDF answer | Read installation, burial depth, soil and modelling assumptions. No FE solve. |
| Q1.3 | `section_1/cable_inputs.json`, `section_2/cable.pro` | Read declared bonding and electric grounding. A magnetic bonding driver is not yet implemented. |
| Q1.4 | `section_1/calculate_geometry.py`, `section_1/cable_inputs.json`, `section_2/cable.pro` | `derived_geometry.json` contains peak amplitudes; `cable.pro` applies ABC voltage phasors. Current phasors are documented for the future magnetic model. |
| Q2.1 | Common Section 2 model | Read `cable.geo` for domain/physical groups and `cable.pro` for equations/BCs; run `python3 section_2/run.py --open` to inspect the field. |
| Q2.2 | Common model + `section_2/study.py`, `section_2/analyse.py` | Run `python3 section_2/run.py --study`; compare `results/healthy/metrics.json`, `results/ideal/metrics.json` and `validation/analytical_reference.json`, all under `section_2/`. |
| Q2.3 | Common model + `section_2/study.py`, `section_2/analyse.py` | Run `--study`; inspect `section_2/validation/convergence.csv`, `field_convergence.pos` and `capacitance_convergence.pos`. |
| Q2.4 | `section_2/analyse.py`, `section_2/results/healthy/metrics.json`, `section_2/README.md`; cited external source in PDF | Compare RMS interface fields with the sourced comparison limits. This is an interpretation step, not an imposed solver condition. |
| Q2.5 | Common model + `section_2/settings.inc`, `study.py`, `analyse.py` | Run `--study` for both void meshes; inspect `section_2/results/void/view.geo`, `metrics.json`, `radial_cut.csv`, and `section_2/validation/radial_comparison.pos`. |
| Q2.6 | Common model + `section_2/cable.pro`, `section_2/analyse.py` | Read `section_2/results/healthy/metrics.json` for conservation; `radial_cut.csv` for current samples; open `view.geo` and toggle conduction/displacement maps. |
| Q2.7 | Common model + `section_2/analyse.py`, `section_2/study.py`; datasheet | Run `--study`; read `section_2/validation/summary.json` for C/frequency and `analytical_reference.json` for the coaxial comparison. |
| Q2.8 | Common model + `section_2/settings.inc`, `section_2/cable.geo`, `section_2/study.py` | Run `--study`; compare `section_2/results/healthy/` with `section_2/results/thicker_xlpe/`; use `metrics.json`, `view.geo` and the validation radial plot. |

The Section 1 and Section 2 PDFs reproduce every assignment question and include
this file guidance beside its answer. Section-specific READMEs contain further
instructions. For a compact record of the executed study see
[`section_2/validation/RESULTS.md`](section_2/validation/RESULTS.md).

## Where to change inputs

| Change | Edit / command |
|---|---|
| Baseline cable dimensions, voltage, installation | `section_1/cable_inputs.json` |
| XLPE, semiconductor or gas electrical properties | `shared/materials.json` |
| Mesh size, frequency, ideal-screen/void switches | Runner arguments; defaults are in `settings.inc` |
| Void radius and position | Explicit constants in `settings.inc` |
| Geometry/topology and physical region tags | `section_2/cable.geo` |
| Boundary conditions, equations, exported quantities | `section_2/cable.pro` |
| Section 1 PDF | `../LaTeX/section_1/main.tex` |
| Section 2 PDF | `../LaTeX/section_2/main.tex` |

`parameters.inc`, `derived_geometry.json`, and the report's numerical tables
are generated. Edit their inputs, then regenerate them. Gmsh and GetDP must
receive matching case switches; `run.py` passes the same options to both.

From this folder, examples are:

```sh
python3 section_2/run.py --case refined --mesh-scale 0.125
python3 section_2/run.py --case void --defect --open
python3 section_2/run.py --case ideal --ideal-screens
python3 section_2/run.py --case thicker_xlpe --extra-xlpe-mm 1 --open
```

A new case name retains previous results. Reusing one replaces that case's
outputs. After changing model inputs, rerun `--study` before rebuilding the
report. The LaTeX exporter checks saved FE input hashes; it does not silently
rerun the numerical simulations.

## Modelling choices to understand before using the results

- **Section 2 solves screened electric interiors.** Ideal voltage is imposed at
  each aluminium boundary; zero voltage at each continuous copper-screen boundary.
  Under this assumption, the omitted conductor interior and grounded exterior
  have zero electric field. Soil must return for thermal analysis and an exterior
  domain is needed for the magnetic field.
- **Finite semiconductors are retained in the reference.** An optional XLPE-only
  model quantifies their omission for fields and capacitance. Their conductive
  losses are not preserved by that simplification.
- **The screen is an equivalent continuous electrode.** Actual wire/tape gaps,
  helical lay, joints, end effects and induced longitudinal screen voltages are
  outside this electric model. The shielding error of the real construction
  has not been quantified.
- **The 415 A current is for Sections 3–4.** Section 2 is driven by balanced
  phase-to-earth peak voltage phasors. Its computed currents are transverse
  leakage and charging currents.
- **Fields are phasor norms.** Healthy radial fields have peak magnitude equal
  to that norm; RMS magnitudes are divided by √2. The model has no dielectric-loss
  tangent or gas-discharge law.
- **Variants are controlled investigations.** The 0.5 mm gas channel is an
  infinite axial channel in 2D. The 9 mm XLPE case changes the cable design;
  neither represents a manufacturer-approved variation or a verified new ampacity.

The detailed assumptions, source links and limits are in
[`section_2/README.md`](section_2/README.md). The numerical answers to
Q2.1–Q2.8 are presented in the Section 2 PDF in the repository root.

## Verification and outputs

The study compares three healthy meshes, finite/ideal semiconductors, two void
meshes, thicker XLPE, and 5/50/500/5000 Hz excitations. It checks boundary voltages,
free-node residuals, terminal current balance, independent contour fluxes, energy
versus terminal capacitance, phase consistency, and analytical convergence.

| Output | What it contains |
|---|---|
| `results/<case>/view.geo` | Ready-to-open Gmsh field viewer |
| `results/<case>/radial_cut.csv` | Radius, material, field phasors and current magnitudes |
| `results/<case>/metrics.json` | Per-phase results, checks and FE input hashes |
| `results/<case>/input_snapshot.json` | Geometry/material inputs and case options |
| `results/<case>/mesh.log`, `solver.log` | Actual mesh/solver messages |
| `validation/RESULTS.md` | Human-readable study results and interpretation |
| `validation/summary.json` | Complete ten-case record and software versions |
| `validation/*convergence.pos` | Gmsh convergence plots |
| `validation/radial_comparison.pos` | Healthy, void and thicker-XLPE field cuts |

The documented healthy solution gives approximately 0.224075 µF/km and
4.651 kV/mm peak, versus 0.2240745 µF/km and 4.6678 kV/mm analytically.
Numerical agreement does not establish dielectric withstand. The adopted
external field limits are not NKT-specific; the void model does not predict
partial discharge or breakdown.

## Building the reports

From this `Source-code` folder:

```sh
../LaTeX/build_section_1.sh
../LaTeX/build_section_2.sh
```

Requires Python 3 and a LaTeX installation with `pdflatex`, `newtx` and
`pgfplots` (for example MacTeX). Builds use temporary directories; finished PDFs
are copied to the repository root. The Section 2 build exports data from the
existing verified study rather than rerunning GetDP.

## AI assistance

Codex assisted with source research, modelling assumptions, Gmsh/GetDP code,
post-processing, the executed verification study, documentation and LaTeX
reports. The supplied TA files are retained. Numerical results come from GetDP
solutions and the stated independent checks. As required by the assignment,
the student must review and be able to explain every submitted line and choice.
