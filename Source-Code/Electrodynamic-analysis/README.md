# Electrodynamic analysis (Section 2)

`cable.pro` is the electric model. It reads the shared `../Cable-selection-and-model-setup/parameters.pro`,
defines the problem (groups, materials, electrode voltages) and the outputs, and includes two course
files unchanged: `../Cable-selection-and-model-setup/Jacobian_Integration.pro` and
`electrodynamic_formulation.pro` (function space `Hgrad_v_Ele`, weak form `Electrodynamics_v`,
post-processing `EleDyn_v`). The one-line `cable.geo` includes the shared geometry so the Gmsh
**Run** button works.

## Run in Gmsh (ONELAB)

1. **File > Open** `cable.pro` in this folder; keep resolution **Electrodynamics_cable**
   and compute command **-solve**; press **Run**.
2. Gmsh meshes, GetDP solves, the `|E|` map opens and the **Output** panel shows the
   capacitance (µF/km) and the maximum field (kV/mm, peak).
3. Defect: **Geometry > Insulation defect** = *Air void in phase A*, press **Run**
   (the mesh is rebuilt). Other studies: see the table in `../README.md`.

## Run from a terminal

```sh
cd ../Cable-selection-and-model-setup && mkdir -p meshes && gmsh cable.geo -2 -o meshes/gap.msh
cd ../Electrodynamic-analysis
getdp cable.pro -msh ../Cable-selection-and-model-setup/meshes/gap.msh -solve Electrodynamics_cable
```
Defect: add `-setnumber Flag_Defect 1` to **both** commands (and use another mesh name).

## Model

- Domain: the three XLPE annuli (41/42/43) and, if enabled, the air void (44).
  Semiconductors are ideal equipotentials, so the inner XLPE boundary (101/102/103)
  carries the phase voltage and the outer one (111/112/113) is grounded: Dirichlet
  conditions (constraint `ElectricScalarPotential`) of the course function space. The grounded
  screens shield everything outside: those regions are meshed but not solved here.
- Equation (course weak form): `-div((sigma + j omega eps) grad v) = 0`, peak phasors,
  26.944 kV at 0/-120/+120°.
- Current into one phase's insulation: the weak form tested with the FE function v/V
  (1 on the conductor screen, 0 on the core screen), `I = (1/V) int (sigma + j omega eps) grad v . grad v`.
  It gives the charging current (Q2.6) and a second capacitance `Im(I/V)/omega` (Q2.7).

## Outputs (`res/` or `results/<case>/`)

| File | Meaning |
|---|---|
| `potential.pos`, `field_norm.pos` | v (V) and \|E\| (V/m), peak |
| `conduction_current.pos`, `displacement_current.pos` | \|sigma E\| and \|j omega eps E\| (A/m²), peak |
| `radial_field_A.txt` | \|E\| along phase A's +x radius (x y z value), through the void |
| `max_field_kV_mm.dat` | maximum element \|E\| (kV/mm, peak) |
| `capacitance_uF_km.dat` | phase-average C from field energy (µF/km) |
| `capacitance_charge_uF_km.dat` | C of phase A from its current (charge) |
| `electrode_current_A.dat` | current into phase A's insulation (A/m, re/im, peak) |

Linear triangles: E is constant per element, so the maximum is slightly below the
interface value (−0.43 % at the default mesh, −0.17 % at `MeshFactor` 0.5).
The radial cut starts 1 µm inside XLPE to avoid ambiguous lookup on an interface.
