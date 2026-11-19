# Cable selection and model setup

This is Jaswanth's repaired NKT 33 kV 185 + 50 mm² geometry. It is the only
geometry used by the project.

- `parameters.pro` stores the dimensions, material constants, excitation and `JacketGap`.
- `cable.geo` constructs all layers and the exterior mesh for either spacing.

## Build the two meshes

Open `cable.geo` in Gmsh and choose **Geometry > Jacket gap [mm]**. Use **0.5**
for the assignment baseline or **0** for the datasheet arrangement. Click
**Mesh > 2D** and **File > Save Mesh** if you want a mesh from the GUI.
To save both meshes under separate names, run these commands from this folder:

```sh
mkdir -p meshes
gmsh cable.geo -2 -nt 1 -setnumber JacketGap 0.5 -o meshes/gap.msh
gmsh cable.geo -2 -nt 1 -setnumber JacketGap 0   -o meshes/touching.msh
```

Open the generated `meshes/gap.msh` or `meshes/touching.msh` in Gmsh to
inspect either mesh. Git ignores these files. Generate them with the commands
above on a new checkout or after changing the geometry.
Geometry lengths are in metres. `JacketGap` is entered in millimetres and
converted in `parameters.pro`.

## Dimensions and assumptions

| Region | Inner radius [mm] | Outer radius [mm] |
|---|---:|---:|
| Aluminium | 0 | 7.4 |
| Inner semiconductor | 7.4 | 7.8 |
| XLPE | 7.8 | 15.8 |
| Outer semiconductor | 15.8 | 16.2 |
| Equivalent inner filler/contact | 16.2 | 17.4 |
| Equivalent copper ring | 17.4 | 17.8515 |
| Equivalent outer filler | 17.8515 | 19.2 |
| PE jacket | 19.2 | 21.5 |

The 0.4 mm semiconductors and copper-ring position are assumed dimensions.
The ring preserves 50 mm² of copper, but omits the individual wires and tape lay.
The effective 2.3 mm jacket closes the nominal outside diameter; the datasheet
lists a 2.2 mm sheath. These choices should be reconsidered when assessing heat flow.
The effective aluminium conductivity reproduces the datasheet maximum DC
resistance of 0.164 ohm/km using the stated 14.8 mm conductor diameter.

Each jacket has a 21.5 mm radius. The centre spacing is `2*rJacket + JacketGap*0.001`.

| Case | Gap between jackets | Centre spacing | Soil geometry |
|---|---:|---:|---|
| Assignment baseline | 0.5 mm | 43.5 mm | Soil fills the gaps and connects the centre to the exterior. |
| Datasheet comparison | 0 mm | 43 mm | Each pair shares a vertex. A separate surface fills the central pocket. |

The TA recommended a small clearance to improve triangle shape near the jackets.
The chosen 0.5 mm is a modelling assumption. The 350 A rating refers to
touching trefoil in the datasheet. We use the same current as a study input for
the gapped model. The origin is the trefoil centroid. `OuterBox = 0.3` gives a
0.6 m square local mesh. A thermal model would need a ground surface.

## Mesh

Twelve arcs per circle place vertices at the nearest points of adjacent jackets.
At contact, `Coherence` merges coincident vertices and surface 90031 fills the
enclosed pocket. With a gap, surface 90030 meshes the continuous soil. Both
cases use the same physical group 99 for soil.

The Box field gives a 0.25 mm target size around the cables, grading to larger
elements in distant soil. `MeshFactor` multiplies these sizes. At its default
value of 1, there are about 22,000 XLPE triangles per phase. Both checked meshes
cover all layers and soil with zero Gmsh warnings and no open internal edges.

| Default mesh controls | Touching | 0.5 mm gap |
|---|---:|---:|
| Total triangles | 292,312 | 295,014 |
| Minimum triangle shape quality (1 is equilateral) | 0.0197 | 0.4874 |
| Triangles with quality below 0.10 | 24 | 0 |

The 24 low-quality triangles in the touching case are all in soil next to
the contact points. Section 2 compares the electric results and Section 3
gives a hand estimate of the inductance change.

## Physical groups for the analyses

| Region | Phase A / B / C tags |
|---|---|
| Aluminium | 21 / 22 / 23 |
| Inner semiconductor | 31 / 32 / 33 |
| XLPE | 41 / 42 / 43 |
| Outer semiconductor | 51 / 52 / 53 |
| Inner filler/contact | 61 / 62 / 63 |
| Copper screen | 71 / 72 / 73 |
| Outer filler | 81 / 82 / 83 |
| PE jacket | 91 / 92 / 93 |

Exterior soil is 99. Voltage boundaries are 101/102/103 at the inner XLPE
interfaces, 110 at the outer XLPE interfaces, and 120 at the outer box.

For the electric solve, continue in [Electrodynamic-analysis](../Electrodynamic-analysis/README.md).
