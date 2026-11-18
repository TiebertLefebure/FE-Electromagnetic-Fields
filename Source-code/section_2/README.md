# Section 2: electric-field analysis

Start with `cable.geo`, `cable.pro` and `settings.inc`. They define the mesh,
the GetDP problem and the case settings. The Python scripts run comparisons and
extract quantities from the solution; they do not replace GetDP.

The baseline is the Section 1 cable: three NKT 33 kV XLPE-AL single cores in
touching trefoil, directly buried, with copper screens at zero potential.

## Run one question

Open a terminal in `Source-code/section_2`. From the repository root:

```sh
cd Source-code/section_2
```

Each command below meshes with Gmsh, solves with GetDP and extracts the results.
You can run any question independently; the command selects its cases without
manual changes to `settings.inc`. `--open` also opens the relevant Gmsh view.
Omit it to calculate without opening a window.

All paths below are relative to this folder. Open `view.geo` and `.pos` plots
in Gmsh, `.json` files in a text editor, and `.csv` files in a text editor or spreadsheet.

### Q2.1: model and boundary conditions

Run `python3 run.py --question 2.1 --open`.

- **Computes:** the `healthy` case at 50 Hz.
- **Read:** `cable.geo` builds the layers and phase positions. In `cable.pro`,
  `Constraint` prescribes the electrode voltages and `Formulation` defines the weak form.
- **Inspect:** `results/healthy/view.geo` opens with `|E phasor|` visible.
  Toggle `Re(V)` to see the phase voltages and grounded screens.

### Q2.2: simplifying the geometry

Run `python3 run.py --question 2.2`.

- **Computes:** `healthy` with finite semiconductors and `ideal` with
  `IdealScreens=1`, which solves XLPE alone.
- **Read:** follow `IdealScreens` from `settings.inc` into `cable.geo`.
  `analytical_reference()` in `study.py` supplies the exact layered comparison.
- **Inspect:** compare `results/healthy/metrics.json` with `results/ideal/metrics.json`.
  Read `complex_dofs`; under `phases` → `A`, compare `max_xlpe_peak_kV_mm`,
  `capacitance_uF_km` and `loss_W_m`. The analytical check is
  `validation/analytical_reference.json`.

### Q2.3: mesh convergence

Run `python3 run.py --question 2.3 --open`.

- **Computes:** `coarse`, `medium` and `healthy`, with nominal bulk sizes
  of 1, 0.5 and 0.25 mm. Geometry, voltage and materials stay fixed.
- **Read:** `CASES` in `study.py` lists the mesh settings. `triangle_field()`
  in `analyse.py` calculates the field from the nodal voltages.
- **Inspect:** Gmsh opens `validation/field_convergence.pos`; also open
  `validation/capacitance_convergence.pos`. `validation/convergence.csv`
  contains DOFs, maximum XLPE field and phase-A capacitance for the three meshes.

### Q2.4: field-strength comparison

Run `python3 run.py --question 2.4`.

- **Computes:** the `healthy` case and its fields next to the XLPE interfaces.
- **Read:** `integrate_elements()` in `analyse.py` finds triangles touching
  each interface and records the largest field there.
- **Inspect:** in `results/healthy/metrics.json`, under `phases` → `A`, read
  `inner_screen_peak_kV_mm` and `outer_screen_peak_kV_mm`. Divide both by √2
  before comparing with the PDF's RMS values. These are fields in XLPE beside
  the screens, not fields inside the semiconductors.

### Q2.5: a gas channel in the insulation

Run `python3 run.py --question 2.5 --open`.

- **Computes:** `healthy`, `void_coarse` and `void`; the two defect meshes check
  the sensitivity of the local maximum to refinement.
- **Read:** `VoidRadius` and `VoidOffset` in `settings.inc` set the defect.
  The `Defect` branch in `cable.geo` inserts it; `write_radial_cut()` in
  `analyse.py` samples the field through its centre.
- **Inspect:** Gmsh opens `validation/defect_comparison.pos`, comparing healthy
  and fine-void cuts. Open `results/void/view.geo` for the field map. In each
  case's `metrics.json`, under `phases` → `A`, compare `max_void_peak_kV_mm`
  and `max_xlpe_peak_kV_mm`. The radial cut need not contain the global maximum.

### Q2.6: current densities and conservation

Run `python3 run.py --question 2.6 --open`.

- **Computes:** `healthy` and `void` at 50 Hz, so the gas sample is also available.
- **Read:** `PostProcessing` in `cable.pro` defines conduction/displacement
  current densities. `check_terminals()` in `analyse.py` checks current balance.
- **Inspect:** in `results/healthy/view.geo`, toggle `|J conduction|` and
  `|J displacement|`. Both case folders contain `radial_cut.csv`, with columns
  `J_cond_peak_A_m2` and `J_disp_peak_A_m2`. In `metrics.json`, inspect
  `phases` → `A` → `terminal_balance_relative`, `max_free_residual_relative`
  at the top level, and `contour_flux_checks` for the independent circle integrals.

### Q2.7: capacitance and frequency

Run `python3 run.py --question 2.7`.

- **Computes:** `freq_5`, `healthy`, `freq_500` and `freq_5000`, corresponding
  to 5, 50, 500 and 5 000 Hz, with fixed geometry and material properties.
- **Read:** `check_terminals()` in `analyse.py` calculates terminal and energy
  capacitance. `analytical_reference()` in `study.py` gives the layered reference.
- **Inspect:** open `results/question_2_7.json`. Under `cases`, select a case,
  then `phases` → `A`. Compare `capacitance_uF_km` with
  `energy_capacitance_uF_km`; repeat for all four frequencies. The unit is µF/km
  per phase. NKT's 0.24 µF/km is a maximum, not a nominal target.

### Q2.8: reducing electric stress

Run `python3 run.py --question 2.8 --open`.

- **Computes:** `healthy` with 8 mm XLPE and `thicker_xlpe` with 9 mm XLPE.
- **Read:** the `thicker_xlpe` entry in `study.py` adds 1 mm via `ExtraXLPE`.
  `settings.inc` shifts the outer radii and cable spacing accordingly.
- **Inspect:** Gmsh opens `validation/design_comparison.pos`. Open
  `results/thicker_xlpe/view.geo` for the variant's map. In
  `results/question_2_8.json`, compare the two cases under `cases` → case name
  → `phases` → `A`: `max_xlpe_peak_kV_mm` and `capacitance_uF_km`.

## Run the full study

Each question run saves its cases under `results/<case>/` and a small combined
record under `results/question_2_n.json`. It does not overwrite the full-study
summary. Reusing a case name replaces that case's generated output.

To reproduce the whole report:

```sh
python3 run.py --study
```

This runs ten cases: three healthy meshes, ideal screens, two void meshes,
9 mm XLPE, and three extra frequencies. Read `validation/RESULTS.md` for a
compact table. From the repository root, rebuild the PDF with
`./LaTeX/build_section_2.sh`. Keep the generated PDF in the repository root.

## What each file does

| File | Read it for |
|---|---|
| `cable.geo` | Concentric layers, trefoil positions, physical groups, mesh size and the phase-A void. |
| `cable.pro` | Materials, ABC voltages, grounded screens, weak form, resolution and exported fields. |
| `settings.inc` | `MeshScale`, `IdealScreens`, `Defect`, `ExtraXLPE` and `Freq`. |
| `prepare.py` | Converts Section 1 dimensions and material inputs into `parameters.inc` in SI units. |
| `analyse.py` | Triangle gradients, energy/loss integrals, capacitance, conservation checks and radial cuts. |
| `study.py` | The explicit case list for each question, analytical comparison and study checks. |
| `run.py` | Tool paths, mesh/solve commands, saved inputs and command-line options. |
| `plots.py` | Gmsh viewer/curve formatting; it contains no FE calculations. |
| `export_report.py` | Reads a completed study and exports LaTeX values/tables and code-line references. |
| `electrodynamic_formulation.pro` | The unchanged TA reference. Its weak form is adapted in `cable.pro`. |

The shared inputs are `../section_1/cable_inputs.json` and
`../shared/materials.json`. `cable.pro` directly includes the unchanged
`../shared/Jacobian_Integration.pro`. The original TA electric formulation is
kept for comparison rather than included: its region names, example cuts and
GUI helper do not match this cable.

Physical surface tags are 101/201/301 for inner semiconductor, 102/202/302 for
XLPE, 103/203/303 for outer semiconductor and 104/204/304 for contact bedding.
The void is 106. Electrode curves are 1001/1101/1201 (phase A/B/C) and
1002/1102/1202 (grounded copper screens).

## Model choices

- Solve `−div[(σ+jωε) grad(v)] = 0`, with `E = −grad(v)` and peak phasors
  `Re(v_hat exp(jωt))`. At 50 Hz, apply 26.9444 kV peak at 0°, −120°, +120°.
  The axial 415 A load is used in the magnetic/thermal analysis.
- Mesh the finite-conductivity semiconductors/contact bedding and XLPE between
  r=8.5 and 19.7511 mm. Treat aluminium and copper as equipotential electrodes.
  The centre holes in Gmsh are omitted aluminium, not physical air spaces.
- Replace the real wire/tape screen with a continuous grounded screen. Under
  this assumption, the jackets and soil have zero electric field and can be
  omitted from Section 2. This reduction does not apply to magnetic or thermal
  analysis, joints or terminations. Error from actual wire/tape gaps is unknown.
- `IdealScreens=1` solves XLPE alone, between r=9.3 and 17.3 mm. The study checks
  field/C changes against the finite-screen case and an exact layered solution.
  It removes semiconductor losses even though field/C changes are negligible.
- Materials are linear, isotropic and constant. XLPE uses εr=2.5, σ=1e−18 S/m;
  semiconductors/contact bedding use εr=2.25, σ=0.002 S/m. There is no
  dielectric-loss tangent, space charge or discharge model.
- The defect is a 0.5 mm diameter gas channel, centred 10.3 mm from the phase-A
  axis. εr=1 and σ=0 approximate gas before discharge. In 2D it extends along
  the cable; it is not a spherical bubble. Size and location are study choices.
- The design variant adds 1 mm of XLPE radially and shifts the outer layers.
  Keeping copper thickness would increase its area; a manufactured redesign
  would need a consistent screen specification and a new thermal assessment.

## How the numerical checks work

`analyse.py` reads GetDP's nodal voltages. `triangle_field()` evaluates the
constant P1 gradient. `integrate_elements()` accumulates energy and conductive
loss, records unsmoothed maxima and assembles element reactions. In
`check_terminals()`, electrode reaction sums give current, and free-node sums
should vanish. `write_radial_cut()` and `contour_currents()` sample the same
computed field. The small search grid only finds triangles for these samples.

Per phase, `Y'=I_hat'/V_hat`, `C'=Im(Y')/ω`. Independently,
`C'=∫ε|E_hat|² dA/|V_hat|²`. Peak phasors give average electric energy
`(1/4)∫ε|E_hat|²dA` and average conductive loss `(1/2)∫σ|E_hat|²dA`.
Conduction/displacement currents are `σE_hat` and `jωεE_hat`.

The coaxial reference uses XLPE interface radii: `C'=2πε/ln(17.3/9.3)` and
`E(r)=V_hat/[r ln(17.3/9.3)]`. It predicts 0.2240745 µF/km and 4.66777 kV/mm
peak at the inner interface. The fine P1 model gives about 0.224075 µF/km and
4.65135 kV/mm. Field maxima converge more slowly than integrated C.

Checks stop a run if electrode voltages, current conservation or capacitance
identities fail. The study requires healthy C error <0.1%, maximum-field error
<2%, phase C spread <0.1%, contour flux discrepancy <1%, and last-step void
maximum-field change <3%. These are numerical tolerances. A conservative weak
current balance does not imply exact pointwise flux continuity for P1 gradients.

NKT's 0.24 µF/km is a maximum, not a measured nominal value to fit. The PDF
uses external 8/4 kV/mm RMS screen-stress comparisons from Eskom's 44–132 kV
specification and states that limitation. They are not NKT-specific limits.
The linear gas model cannot establish discharge inception or withstand.

## Custom cases and tool setup

```sh
python3 run.py --case refined --mesh-scale 0.125
python3 run.py --case void_custom --defect --open
python3 run.py --case thicker_custom --extra-xlpe-mm 1 --open
```

Custom settings belong to a single `--case` run. `--question` and `--study`
choose their own settings so comparisons use consistent baselines.

Requires Python 3, Gmsh and GetDP; no Python packages. Tool paths can be set with
`--gmsh /path/to/gmsh`, `--getdp /path/to/getdp`, or `GMSH_BIN`/`GETDP_BIN`.
Meshing/solving use a local temporary folder; completed files are copied back
with replacement so cloud sync does not have to download old files to overwrite
them. The runner also searches `/Applications/Gmsh.app` and the neighbouring ONELAB
folder. Double-clicking `Run Section 2.command` solves/opens the healthy case.
The tested real-arithmetic GetDP build supports complex phasors as a real block
system. Logs are saved per case; large results are ignored by Git.

Open `results/<case>/view.geo` to reload maps without solving. Scalar magnitude
views use the first exported time step. Potentials/vectors show their real part
at phase-A voltage maximum. Norms are `sqrt(|Ex_hat|²+|Ey_hat|²)`; for the healthy
radial field this is its instantaneous peak. RMS vector norms are divided by √2.

## Sources and AI assistance

The Section 2 PDF gives source references and applicability. Material inputs
are inherited from Section 1: NKT datasheet, OES 2 screen data, Lee et al.
[10.3390/en16010167](https://doi.org/10.3390/en16010167), Southampton cable
parameters and COMSOL's XLPE conductivity example. Solver syntax follows the
[GetDP manual](https://getdp.info/doc/texinfo/getdp.html) and geometry/views the
[Gmsh manual](https://gmsh.info/doc/texinfo/gmsh.html).

Codex assisted with implementation, source lookup, the executed checks and the
LaTeX report. The TA files are unchanged. Review the equations and code before
submission; the assignment requires being able to explain the submitted work.
