# Electrodynamic analysis

`cable.pro` is Jaswanth's working electric model. It reads the shared
`../Cable-selection-and-model-setup/parameters.pro` directly.
`electrodynamic_formulation.pro` is the unchanged course reference; it is
not included in `cable.pro` and is not a standalone cable problem.

## Run in Gmsh (ONELAB)

1. Use **File > Open** and select `cable.pro` in this folder.
2. Check that the resolution is **Electrodynamics** and the compute command
   is **-solve**, then press **Run** at the bottom of the left panel.
3. Gmsh builds the mesh, GetDP solves, and the electric-field magnitude is
   displayed. Other maps are available in the post-processing list.

`cable.geo` beside `cable.pro` is a one-line entry file that includes
`../Cable-selection-and-model-setup/cable.geo`. The geometry is defined only
in the setup folder. Gmsh needs this companion because it looks for a `.geo`
file with the same name and folder as the opened `.pro` file. Opening the
`.pro` without it previously produced an empty mesh.

If Gmsh asks for the GetDP executable, select
`ONELAB Software/Gmsh.app/Contents/MacOS/getdp` in the course folder beside
this repository. This is a one-time solver setup for that Gmsh installation.

For parameter studies, change **Mesh factor**, **Frequency [Hz]** or
**XLPE thickness [m]** in the left panel, then press **Run** again. Gmsh
updates the shared geometry when needed. Leave the compute command at
`-solve`: the resolution already calls the field exports.

## Run from a terminal (alternative)

First create the shared mesh:

```sh
cd ../Cable-selection-and-model-setup
gmsh cable.geo -2
cd ../Electrodynamic-analysis
getdp cable.pro -msh ../Cable-selection-and-model-setup/cable.msh -solve Electrodynamics
```

These commands assume a terminal initially in this folder and Gmsh/GetDP on PATH.
GetDP writes `cable.pre`, `cable.res` and the `res/` field maps here.
With the Gmsh Run button, its same-folder mesh is `cable.msh` here. The terminal
command above instead explicitly uses the mesh in the setup folder. Both
meshes come from the same geometry definition.

## Find the code for a question

Search for `Q2.1`, `Q2.3`, etc. in `cable.pro` and the shared setup files.
Comments sit above the domain, boundary conditions, weak equation, field/current
outputs and capacitance calculation. Missing work is labelled `NOT IMPLEMENTED`;
a question tag on the magnetic starter indicates where to adapt it, not a
completed cable calculation.

## Model

Only XLPE regions 41, 42 and 43 are solved. The inner semiconductors are
assumed to follow their conductor voltages; the outer semiconductors are
assumed grounded. Apply 33 kV line-to-line RMS as phase-to-ground peak
phasors of 26.9444 kV at 0, -120 and +120 degrees, at 50 Hz.

Other regions remain in the shared mesh but do not participate in this
electric solve. A blank field map there does not mean the mesh is missing.
The 350 A axial load is for the later magnetic/thermal analysis.

## Inspect

Open these files in Gmsh:

- `res/potential.pos`: complex potential, in volts.
- `res/electric_field.pos`: electric field vector, in V/m.
- `res/field_norm.pos`: field phasor norm, in V/m; divide by 1e6 for kV/mm.
- `res/displacement_current.pos` and `res/conduction_current.pos`: A/m².
- `res/radial_field_A.pos`: field along the phase-A radial cut.
- `res/capacitance_uF_km.dat`: phase-average capacitance, in µF/km
  (the second column is its real value).
- `res/electric_energy.dat`: half the integral of epsilon times squared
  peak field over all three phases. Mean stored energy is half this value.

Phasors are peak values; divide by sqrt(2) for RMS. At the default mesh size,
the gapped mesh gives a maximum field of about 4.873 kV/mm peak versus 4.894
analytically, an error of about 0.43%. The coaxial capacitance reference is 0.197031 µF/km per
phase. A more detailed field study and defect analysis can be added from here.

The radial cut starts and ends 1 µm inside XLPE to avoid a false zero caused
by ambiguous element lookup exactly on an interface.

## Small parameter studies

For Q2.2, select **Geometry > Jacket gap [mm]** in Gmsh and run **0.5** and **0**
with identical inputs. Use **Output > Directory** values `results/gap` and
`results/touching` to keep both sets of maps. Compare the peak in `field_norm.pos`
and the capacitance in `capacitance_uF_km.dat`. The ideal grounded screens fix
each XLPE solution independently, so small FE differences reflect the mesh.
For the terminal workflow, generate the two named meshes using the setup README:

```sh
getdp cable.pro -msh ../Cable-selection-and-model-setup/meshes/gap.msh -solve Electrodynamics -setnumber JacketGap 0.5 -setstring ResultDir results/gap
getdp cable.pro -msh ../Cable-selection-and-model-setup/meshes/touching.msh -solve Electrodynamics -setnumber JacketGap 0 -setstring ResultDir results/touching
```

Use the same `JacketGap` in Gmsh and GetDP so the phase-A radial cut is in
the right location. Gmsh shares this parameter automatically with GetDP.

Use `gmsh cable.geo -2 -setnumber MeshFactor 0.5` from the setup folder to
refine the mesh, then run the same GetDP command. The default factor is 1.
Frequency does not require remeshing: append `-setnumber Freq 500` to GetDP.
To try 9 mm XLPE, append `-setnumber tXLPE 0.009` to **both** Gmsh and GetDP.
This keeps the copper ring and outside diameter fixed and reduces the assumed
inner filler to 0.2 mm. It is a trial design, not manufacturer data.

Each run overwrites `res/`. To preserve a case, append
`-setstring ResultDir results/case-name` to GetDP; the output directory is
created automatically. Mesh convergence, frequency and thickness checks are
reported with input settings in `../../Reports/`.

The independent FE boundary-flux conservation check and defect model are not
implemented. Solving the weak current equation alone is not a quantified
boundary-current balance test.
