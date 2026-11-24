# Electrodynamic analysis

`cable.pro` is the complete electric model (Section 2), built from the course starter
`electrodynamic_formulation.pro` (see git history). It reads the shared
`../Cable-selection-and-model-setup/parameters.pro`; the one-line `cable.geo` here
includes the shared geometry so the Gmsh **Run** button works.

## Run in Gmsh (ONELAB)

1. **File > Open** `cable.pro` in this folder; keep resolution **Electrodynamics**
   and compute command **-solve**; press **Run**.
2. Gmsh meshes, GetDP solves, the `|E|` map opens and the **Output** panel shows the
   capacitance (µF/km) and the maximum field (kV/mm, peak).
3. Defect: **Geometry > Insulation defect** = *Air void in phase A*, press **Run**
   (the mesh is rebuilt). Other studies: see the table in the root README.

If Gmsh asks for the GetDP executable, select
`ONELAB Software/Gmsh.app/Contents/MacOS/getdp` in the course folder beside this repository.

## Run from a terminal

```sh
cd ../Cable-selection-and-model-setup && mkdir -p meshes && gmsh cable.geo -2 -o meshes/gap.msh
cd ../Electrodynamic-analysis
getdp cable.pro -msh ../Cable-selection-and-model-setup/meshes/gap.msh -solve Electrodynamics
```
Defect: add `-setnumber Flag_Defect 1` to **both** commands (and use another mesh name).

## Model

- Domain: the three XLPE annuli (41/42/43) and, if enabled, the air void (44).
  Semiconductors are ideal equipotentials, so the inner XLPE boundary (101/102/103)
  carries the phase voltage and the outer one (111/112/113) is grounded. The grounded
  screens shield everything outside: those regions are meshed but not solved here.
- Equation: `-div((sigma + j omega eps) grad v) = 0`, peak phasors, 26.944 kV at 0/-120/+120°.
- Each boundary is an *electrode* (`BF_GroupOfNodes`): one unknown `U`, whose dual `I`
  is the total current entering the XLPE. This gives the current balance (Q2.6) and a
  second capacitance `Im(I/U)/omega` (Q2.7).

## Outputs (`res/`)

| File | Meaning |
|---|---|
| `potential.pos`, `field_norm.pos` | v (V) and \|E\| (V/m), peak |
| `conduction_current.pos`, `displacement_current.pos` | \|sigma E\| and \|j omega eps E\| (A/m²), peak |
| `radial_field_A.txt` | \|E\| along phase A's +x radius (x y z value), through the void |
| `max_field_kV_mm.dat` | maximum element \|E\| (kV/mm, peak) |
| `capacitance_uF_km.dat` | phase-average C from field energy (µF/km) |
| `capacitance_charge_uF_km.dat` | C per phase from the electrode current |
| `electrode_currents.dat` | I of 101,102,103,111,112,113 (A/m, re/im): inner + outer = 0 |

Linear triangles: E is constant per element, so the maximum is slightly below the
interface value (−0.4 % at the default mesh, −0.15 % at `MeshFactor` 0.5).
The radial cut starts 1 µm inside XLPE to avoid ambiguous lookup on an interface.
