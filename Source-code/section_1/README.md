# Section 1: cable selection and model setup

The selected cable is the NKT 33 kV 1x240+50 mm² XLPE-AL. Three cables are
directly buried in touching trefoil, with both ends of the copper screens
bonded. The reference current is 415 A RMS per phase.

| File | Purpose |
|---|---|
| [cable_inputs.json](cable_inputs.json) | Dimensions, installation conditions and excitation; edit inputs here. |
| [materials.json](../shared/materials.json) | Electrical material data used in Section 2 and the capacitance estimate. |
| [calculate_geometry.py](calculate_geometry.py) | Calculate the radii, phase positions, effective aluminium conductivity and peak amplitudes; check the geometry. |
| [derived_geometry.json](derived_geometry.json) | Calculated values, in the units given in each key. |
| [geometry_values.tex](../../LaTeX/section_1/geometry_values.tex) | Calculated dimensions inserted into the report. |
| [main.tex](../../LaTeX/section_1/main.tex) | Report text, tables, drawing and references. |
| [build_section_1.sh](../../LaTeX/build_section_1.sh) | Run the calculation and compile the PDF. |

Run from the repository root:

```sh
python3 Source-code/section_1/calculate_geometry.py
./LaTeX/build_section_1.sh
```

The first command only updates the calculated values. The build script also
runs the calculation, then writes the Section 1 PDF in the repository root.
It needs Python 3 and `pdflatex`. Section 1 does not run Gmsh or GetDP.
After changing the inputs, regenerate the output files rather than editing
them by hand.

## Calculations and assumptions

The Python script follows the hand calculations in the report. It works in
millimetres for the radii and trefoil positions, converting to metres for
burial depth and conductor area in the resistance calculation.

The copper wires are replaced by a ring with the same 50 mm² area. The gap
between the outer semiconductor and this ring is assigned semiconducting
properties. The outer cover is treated as 2.6 mm of PE to match the nominal
45.5 mm cable diameter. These are equivalent regions, since the datasheet
does not describe all the details between the insulation and the outer sheath.

The conductor diameter and nominal area do not agree exactly. We retain the
17 mm diameter and calculate an effective conductivity from the maximum DC
resistance, using `R = length / (conductivity * area)`.

The script checks that the radii increase, the copper area is preserved,
the three jackets touch and every cable is below the ground surface. It also
calculates a coaxial capacitance estimate for Section 2, treating the
semiconducting screens as equipotentials. Permittivity values are read from
`../shared/materials.json`.

## Connection to the FE models

The [Section 2](../section_2/prepare.py) and [Section 3](../section_3/prepare.py)
`prepare.py` scripts read `cable_inputs.json` directly and write their own
`parameters.inc` in SI units. They do not read `derived_geometry.json`.
The `.geo` files define geometry and mesh regions; the `.pro` files define
the field problem. Each `run.py` handles meshing, solving and post-processing.
See the [Section 2](../section_2/README.md) and
[Section 3](../section_3/README.md) READMEs for solver commands.

Section 2 applies the phase voltages; Section 3 applies the conductor currents
and screen bonding. The 415 A datasheet rating still needs to be checked with
the coupled thermal model in Section 4.
