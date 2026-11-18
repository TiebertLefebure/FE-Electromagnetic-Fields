# Section 3: magnetoquasistatic analysis

Three solid aluminium phases with 50 mm² copper screens in touching trefoil.
Defaults: 415 A RMS, 50 Hz, both-end solid bonding, constant 20 °C metal
conductivities and relative permeability 1 in every region.

## Run

From the repository root, with Gmsh and GetDP installed:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r Source-code/section_3/requirements.txt
.venv/bin/python Source-code/section_3/run.py --open
.venv/bin/python Source-code/section_3/run.py --study
./LaTeX/build_section_3.sh
```

Executables are found on PATH or in the neighbouring ONELAB application.
Overrides: `--gmsh`, `--getdp`, `GMSH_BIN` and `GETDP_BIN`. The report builder
uses `.venv/bin/python`, or `PYTHON` if set.

```sh
.venv/bin/python Source-code/section_3/run.py --case refined --mesh-scale 0.25
.venv/bin/python Source-code/section_3/run.py --case stranded --stranded
.venv/bin/python Source-code/section_3/run.py --case single_point --single-point --open
.venv/bin/python Source-code/section_3/run.py --case simplified --simplified
.venv/bin/python Source-code/section_3/run.py --case large --outer-radius 1
.venv/bin/python Source-code/section_3/run.py --case high_frequency --frequency 1000 --mesh-scale 0.25
```

## Files

| File | Purpose |
|---|---|
| `prepare.py` | Read Section 1 data and generate ONELAB constants in `parameters.inc` |
| `settings.inc` | Mesh, conductor, frequency and bonding controls |
| `model.geo` | Conforming full cross-section, including the central soil pocket |
| `model.pro` | Vector potential and one longitudinal gradient per massive region |
| `run.py` | Run Gmsh/GetDP, analyse a case and optionally open field maps |
| `analyse.py` | Integrate currents, losses and energy; check conservation; export Gmsh views |
| `study.py` | Run 15 convergence, conductor, bonding, simplification and frequency cases |
| `report.py` | Export checked tables, figures and analytical comparisons |
| `magnetodynamic_formulation.pro` | Unmodified TA reference; not included directly |

## Model

Peak phasors use exp(jωt). Solve curl(μ⁻¹ curl A) = J with A = Az ez.
Each massive region uses Jz = -σ(jωAz + g), with a constant longitudinal
potential gradient g. The physical voltage drop per metre is -g.

Balanced net currents are imposed in the massive phases. Solid bonding sets
g = 0 in each copper screen. Single-point bonding instead imposes zero net
screen current and solves g. Stranded phases impose uniform J normalised to
the actual mesh area.

The outer circle has Az = 0; a 0.25/0.5/1 m study checks truncation sensitivity.
Soil uses σ = 0.01 S/m and zero applied axial gradient, with a zero-conductivity
comparison. Semiconductors use σ = 0.002 S/m and zero net axial current as an
auxiliary closure; their losses are negligible. XLPE and PE are nonconducting.

The complete current gives average loss ∫|J|²/(2σ) dA. The triangle mass matrix
integrates it exactly. With RMS phase current I, R_eq = P_total/(3 I²) and
L_eq = 2 W_average/(3 I²), where W_average = ∫|B|²/(4μ) dA.

Checks cover internal mesh interfaces, imposed phase/zero-net currents,
terminal power against integrated losses/energy, mesh convergence and the
bonding comparison. Every result carries model-input hashes.

## Results

The 29,984-complex-DOF baseline gives 69.987740 kW/km total loss,
0.135458 Ω/km equivalent resistance and 0.377822 mH/km inductance.
Halving the mesh size changes loss by 0.081% and inductance by 0.022%.
Single-point bonding gives 66.127811 kW/km, a 5.515% reduction.

See [validation/RESULTS.md](validation/RESULTS.md) for all cases. The PDF
answers Q3.1-Q3.11, including analytical/datasheet comparisons and the copper
annulus approximation. Section 4 must establish temperature and ampacity.

`results/<case>/` contains the mesh, solver logs, nodal potential, regional
gradients, `fields.npz` and `metrics.json`. A normal run also writes `view.geo`
and magnetic, current and loss maps. Report export writes views for the
baseline and single-point cases. Rerun `--study` after model changes before
rebuilding the report.

Executed versions: Gmsh 4.15.0-git; GetDP 4.0.0-git-259f4c38 with PETSc real
arithmetic. Full version information is in `validation/`. PDF compilation
requires `pdflatex`.
