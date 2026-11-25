# Source code — FE analysis of a 33 kV cable system

Electric, magnetic and coupled magneto-thermal FE analysis of three NKT 33 kV
**1×185/50 mm² XLPE-AL** single-core cables buried 1 m deep in trefoil (rating: 350 A, 90 °C).
Group: **Kutikuppala Jaswanth, Lefebure Tiebert, Miseur Torre**. Submitted version: git tag `final`.

Versions: **Gmsh 4.15.2**, **GetDP 4.0.0-git-259f4c38** (ONELAB bundle).

## Files

```text
Cable-selection-and-model-setup/
  parameters.pro               ALL data as ONELAB parameters (excitation, dimensions, materials, thermal)
  cable.geo                    the single geometry and mesh (cables, EM box, soil up to the ground surface)
  Jacobian_Integration.pro     course file, unchanged: Jacobians and Gauss rules (both models)
Electrodynamic-analysis/
  cable.pro                    Section 2: XLPE (+ air void) problem, resolution and outputs
  electrodynamic_formulation.pro   course file, unchanged: function space, weak form, post-processing
  cable.geo                    one-line include of the shared geometry (Gmsh Run button)
Magnetothermal-analysis/
  cable.pro                    Sections 3-5: magnetic problem, heat equation, sigma(T) coupling
  magnetodynamic_formulation.pro   course file, unchanged: a-v function spaces, weak form, post-processing
  cable.geo                    one-line include of the shared geometry (Gmsh Run button)
run_all.sh                     every case in the slides (exact commands, one line per case)
```

Each `cable.pro` defines what the course files leave to the user (groups, materials, sources,
constraints) and the resolutions and outputs for this cable, then includes the course files.
GetDP does not allow redefining a name, so our resolutions are `Electrodynamics_cable`,
`Magnetodynamics_cable` and `MagnetoThermal`; the course resolutions (`Electrodynamics`,
`Magnetodynamics`) are written for the course example cable and are not used. Search a question
tag (`Q2.5`, `Q4.7`, ...) in the `.pro`/`.geo` files to find the code that answers it.

## Run in Gmsh (ONELAB)

**File > Open** `Electrodynamic-analysis/cable.pro` or `Magnetothermal-analysis/cable.pro`, keep
the default resolution (or pick one in the GetDP panel), press **Run**. Gmsh meshes, GetDP solves,
the key numbers appear under **Output** and the maps open. If Gmsh asks for the GetDP executable:
`Gmsh.app/Contents/MacOS/getdp` of the ONELAB bundle.

| Result in the slides | File / resolution | ONELAB setting before **Run** |
|---|---|---|
| Electric baseline (Q2.1–Q2.7) | Electrodynamic / `Electrodynamics_cable` | defaults |
| Mesh convergence (Q2.3, Q3.5, Q4.3) | any | Mesh > Mesh factor = 2, 1, 0.5 |
| Touching trefoil (Q2.2, Q3.4) | any | Geometry > Jacket gap = 0 |
| Air void (Q2.5) | Electrodynamic | Geometry > Insulation defect = Air void |
| 9 mm XLPE (Q2.8) | Electrodynamic | Geometry > XLPE thickness = 0.009 |
| Frequency (Q2.7, Q3.10) | any | Cable > Frequency |
| Magnetic baseline (Q3.1–Q3.10) | Magnetothermal / `Magnetodynamics_cable` | defaults |
| EM box size (Q3.1, Q3.5) | Magnetothermal | Geometry > Electromagnetic half-box = 0.6 |
| Stranded conductor (Q3.2) | Magnetothermal | Magnetic > Conductor model = Stranded |
| Single-point bonding (Q3.3, Q3.11) | Magnetothermal | Magnetic > Screen bonding = Single point |
| Thermal, linear (Q4.1–Q4.6) | Magnetothermal / `MagnetoThermal` | Thermal > Conductivity model = Linear |
| Thermal, σ(T) (Q4.7–Q4.9) | Magnetothermal / `MagnetoThermal` | defaults |
| Isothermal ground surface (Q4.5) | Magnetothermal / `MagnetoThermal` | Thermal > Ground surface condition = Isothermal |
| Heat transfer coefficient (Q4.2) | Magnetothermal / `MagnetoThermal` | Thermal > Surface heat transfer coefficient = 5, 20 |
| Thermal domain size (Q4.3) | Magnetothermal / `MagnetoThermal` | Thermal > half-width and depth = 10, 40 |
| Arrangement (Section 5) | Magnetothermal / `MagnetoThermal` | Geometry > Formation = Flat; Jacket gap 0.5 or 70; bonding as above |

Set **Output > Directory** = `results/<name>` to keep a run (otherwise `res/` is overwritten).

## Run every case (terminal)

```sh
export PATH="/path/to/ONELAB/Gmsh.app/Contents/MacOS:$PATH"   # gmsh + getdp
./run_all.sh                                                   # all meshes and cases, about 25 min
```

`run_all.sh` lists one line per case with the question it answers; the same `-setnumber`
options go to Gmsh (mesh) and GetDP (solve). Results land in `<analysis>/results/<case>/`.
One case by hand, from `Electrodynamic-analysis/`:

```sh
(cd ../Cable-selection-and-model-setup && mkdir -p meshes && gmsh cable.geo -2 -o meshes/gap.msh)
getdp cable.pro -msh ../Cable-selection-and-model-setup/meshes/gap.msh -solve Electrodynamics_cable
```

## Modelling assumptions

| Assumption | Why / effect | Where |
|---|---|---|
| 0.5 mm soil gap between jackets | removes zero-angle soil wedges (min. triangle quality 0.020 → 0.575); ΔE 0.01 %, ΔL 0.5 % vs touching | S1, Q2.2, Q3.4 |
| Semiconductors 0.4 mm, ideal equipotentials (electric) | NKT gives 32.4 mm over insulation; drop across them ≈ 7 mV | Q1.1, Q2.2 |
| Cu wires + tape → ring of 50 mm² | same DC resistance; lay not representable in 2D | Q1.1, Q3.4 |
| σ_Al fitted to R_DC = 0.164 Ω/km | NKT gives diameter and R_DC, not σ; within 0.2 % of the IEC value | Q1.1 |
| σ_Cu = 5.80e7 S/m (annealed copper) | IEC 60287-1-1 Table 1 / IEC 60228, same value as the IEC check | Q1.1 |
| Air void 0.5 mm, centred at r = 8.8 mm, 1 bar | typical cavity near the highest stress; 2D = cylinder (conservative) | Q2.5 |
| Both-end bonding, ideal earth leads (U = 0) | matches the NKT rating row; single point (I = 0) studied | Q1.3, Q3.3 |
| Soil, semicons, fillers σ = 0 (magnetic) | skin depth ≫ size | Q3.1, Q3.4 |
| Polymers and fillers κ = 0.286 W/(m K) | IEC 60287-2-1 ρ = 3.5 K m/W; same data as the IEC check; halving the filler κ adds ≈2 K | Q1.1, Q4.2 |
| Cu ring midway in the 3 mm screen layer | NKT gives only the envelope; ±2 mm on its diameter changes screen loss ≈ ±13 % | Q1.1, Q3.4 |
| h = 10 W/(m² K) at the ground surface | natural convection ≈2 + radiation ≈5 + wind; 5–20 and isothermal studied | Q4.2, Q4.5 |
| Domain ±20 m, 20 m deep; bottom T = 15 °C, sides adiabatic | T_max within 0.1 K of a 40 m domain | Q4.3 |
| No dielectric losses | IEC 60287: negligible for XLPE below U₀ = 127 kV | Q4.1 |
| Section 5 topic: free choice (arrangement × bonding) | arrangement can be checked against six NKT rating rows | S5 |

## Use of AI tools

Codex (OpenAI) helped with the Section 1 geometry fixes and repository cleanup. Claude Code
(Anthropic) helped write the defect geometry, the two `cable.pro` files around the course
formulation files, `run_all.sh`, the post-processing scripts, the report text and the slides.
All results were rerun locally with the versions above and checked against analytical formulas,
IEC 60287 and the datasheet. We are responsible for all code and results.
