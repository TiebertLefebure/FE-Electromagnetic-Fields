# Finite Elements for Electromagnetic Fields

The model uses three NKT 33 kV **185 + 50 mm²** single-core cables in trefoil.
The jacket diameter is **43 mm**. Following TA feedback, the default mesh
uses a **0.5 mm soil gap** between each pair of jackets. The **touching** case
represents the datasheet arrangement and serves as the comparison.

## Code layout

```text
Source-code/
  Cable-selection-and-model-setup/
    parameters.pro                  dimensions, materials and excitation
    cable.geo                       the shared cable geometry definition
  Electrodynamic-analysis/
    cable.pro                       Jaswanth's working electric model
    cable.geo                       one-line Gmsh entry, includes shared geometry
    electrodynamic_formulation.pro  original course reference
  Magnetoquasistatic-analysis/
    magnetodynamic_formulation.pro  original course starter
  shared/
    Jacobian_Integration.pro        original course integration definitions
```

Edit dimensions in `parameters.pro`. There are no Python preparation,
runner or report scripts in the active code. Both analyses use the same geometry.
See [the code overview](Source-code/README.md) and the README in each folder.

## Current reports

- [Section 1: cable selection and model setup](Reports/Section_1_Cable_Selection_and_Model_Setup.pdf)
- [Section 2: electrodynamic analysis](Reports/Section_2_Electrodynamic_Analysis.pdf)
- [Section 3: magnetoquasistatic analysis](Reports/Section_3_Magnetoquasistatic_Analysis.pdf)

Each question has its own short code guide. Datasheet values, assumptions,
derived values and results are distinguished explicitly. The defect case,
independent FE boundary-current balance and magnetic cable model remain to be
implemented; the reports state those limits. Section 3 currently contains
the proposed model and hand checks, not results from the removed solver.
See [Reports/README.md](Reports/README.md) for sources and rebuilding.

## Mesh and electric solve

In **Gmsh**, use **File > Open** to open
`Source-code/Electrodynamic-analysis/cable.pro`, then press **Run**.
Gmsh loads the shared geometry through the one-line companion `cable.geo`,
creates the mesh and runs GetDP. Keep resolution **Electrodynamics** and
compute command **-solve**. The field map is displayed after the solve.
Select **Geometry > Jacket gap [mm]** value **0.5** for the baseline or **0**
for contact. [Mesh files and regeneration commands](Source-code/Cable-selection-and-model-setup/README.md#build-the-two-meshes).
See [the electric model README](Source-code/Electrodynamic-analysis/README.md)
for details and the one-time GetDP executable selection, if requested.

Alternatively, with Gmsh and GetDP on PATH, start from the repository root:

```sh
cd Source-code/Cable-selection-and-model-setup
gmsh cable.geo -2
cd ../Electrodynamic-analysis
getdp cable.pro -msh ../Cable-selection-and-model-setup/cable.msh -solve Electrodynamics
```

For the ONELAB app stored beside this repository, first run this from the
repository root in the same terminal:

```sh
export PATH="$PWD/../ONELAB Software/Gmsh.app/Contents/MacOS:$PATH"
```

Open `cable.geo` or `cable.msh` in Gmsh to inspect the geometry and mesh.
Electric field maps are written to `Electrodynamic-analysis/res/`.
No Python installation is needed for these commands.

The magnetic folder contains the course starter. Its cable-specific groups,
materials and current/bonding constraints still need to be implemented.

Gmsh 4.15.2 and GetDP 4.0.0-git-259f4c38 were used for the mesh and electric checks.
Codex assisted with the geometry fixes, verification and repository cleanup.
