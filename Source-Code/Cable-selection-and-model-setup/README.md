# Cable selection and model setup

- `parameters.pro`: **all** cable, material, excitation, thermal and arrangement data, as
  ONELAB parameters, each tagged with its basis ([NKT], [IEC], [ASSUMPTION], ...).
- `cable.geo`: the only geometry and mesh, used by every analysis.
- `Jacobian_Integration.pro`: course file, unchanged (Jacobians and Gauss rules), included by both models.

Open `cable.geo` in Gmsh to inspect it, or build a mesh from this folder:

```sh
mkdir -p meshes && gmsh cable.geo -2 -o meshes/gap.msh
```
Pass the same `-setnumber` options as the solver (e.g. `-setnumber JacketGap 0`);
`../run_all.sh` builds every mesh used in the slides.

## Radial construction (one cable)

| Region | Inner radius [mm] | Outer radius [mm] | Basis |
|---|---:|---:|---|
| Aluminium (solid) | 0 | 7.4 | NKT diameter 14.8 mm |
| Inner semiconductor | 7.4 | 7.8 | assumed 0.4 mm |
| XLPE | 7.8 | 15.8 | NKT 8.0 mm |
| Outer semiconductor | 15.8 | 16.2 | assumed 0.4 mm (NKT 32.4 mm over insulation) |
| Inner filler | 16.2 | 17.4 | assumed ring position |
| Copper ring | 17.4 | 17.8515 | area = 50 mm² (NKT) |
| Outer filler | 17.8515 | 19.2 | NKT 38.4 mm over screen |
| PE jacket | 19.2 | 21.5 | NKT 43 mm nominal |

The copper wires and tape are one ring of equal area (lay and gaps omitted). σ_Al is fitted
so that the 14.8 mm conductor has the NKT maximum DC resistance 0.164 Ω/km at 20 °C.

## Arrangement and spacing

Origin = centre of the arrangement, `BurialDepth` = 1 m below the ground surface.
Centre spacing = `2 rJacket + JacketGap` (gap in mm).

| Case | Settings | Spacing |
|---|---|---:|
| Baseline: trefoil, 0.5 mm gap (TA advice) | defaults | 43.5 mm |
| Touching trefoil (NKT rating geometry) | `JacketGap 0` | 43.0 mm |
| Flat, close (Section 5) | `Formation 1` | 43.5 mm |
| Flat, NKT "S = D + 70 mm" (Section 5) | `Formation 1`, `JacketGap 70` | 113 mm |

The 0.5 mm gap removes the zero-angle soil wedges at the contact points: minimum triangle
quality 4√3·A/Σℓ² 0.020 (touching) → 0.575 (gap). Sections 2–3 show it changes E_max by 0.01 %,
C by < 1e-5 %, L by 0.5 %.

## Mesh

- 12 arcs per circle; vertices at the nearest points of neighbouring cables.
- 0.25 mm target inside a box around the cables (`MeshFactor` scales all sizes),
  35 mm in the rest of the EM box, then +15 cm per metre in the thermal soil.
- Optional void: `rVoid/8` at its edge (Ball field).

## Physical groups

| Region | Phase A / B / C |
|---|---|
| Aluminium | 21 / 22 / 23 |
| Inner semiconductor | 31 / 32 / 33 |
| XLPE (air void: 44, phase A) | 41 / 42 / 43 |
| Outer semiconductor | 51 / 52 / 53 |
| Inner filler | 61 / 62 / 63 |
| Copper screen | 71 / 72 / 73 |
| Outer filler | 81 / 82 / 83 |
| PE jacket | 91 / 92 / 93 |

Soil inside the EM box: 99; soil outside it (thermal only): 98.
Curves: 101/102/103 conductor-screen interfaces, 111/112/113 core-screen interfaces,
120 EM box edge (a = 0), 130 ground surface (convection), 132 bottom (T = T_amb).

The thermal domain: ground surface 1 m above the centre, sides ±20 m, bottom 20 m below the
surface. One mesh serves all analyses: the EM problems use the inner box only.

Next: [Electrodynamic-analysis](../Electrodynamic-analysis/README.md),
[Magnetothermal-analysis](../Magnetothermal-analysis/README.md).
