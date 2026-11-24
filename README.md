# Finite Elements for Electromagnetic Fields — 33 kV cable system

Electric, magnetic and coupled magneto-thermal FE analysis of three NKT 33 kV
**1×185/50 mm² XLPE-AL** single-core cables buried 1 m deep in trefoil (rating: 350 A, 90 °C).

Group: **Kutikuppala Jaswanth, Lefebure Tiebert, Miseur Torre**. Presentation: 1 December 2026.

Versions: **Gmsh 4.15.2**, **GetDP 4.0.0-git-259f4c38** (ONELAB bundle).

## Files

```text
Source-code/
  Cable-selection-and-model-setup/
    parameters.pro      ALL data as ONELAB parameters (excitation, dimensions, materials, thermal)
    cable.geo           the single geometry and mesh (cables, EM box, soil up to the ground surface)
  Electrodynamic-analysis/
    cable.pro           Section 2: XLPE (+ air void) electric model, E, J, C, current balance
    cable.geo           one-line include of the shared geometry (Gmsh Run button)
  Magnetothermal-analysis/
    cable.pro           Sections 3-5: a-v magnetic model + heat conduction + sigma(T) coupling
    cable.geo           one-line include of the shared geometry (Gmsh Run button)
run_all.sh              every case in the reports and slides (exact commands)
Reports/                Section 1-5 PDFs, LaTeX sources, collect_values.py (results -> numbers)
Slides/                 slides.tex -> slides.pdf; export_maps.sh renders the field maps;
                        speaker_notes.tex -> speaker_notes.pdf (timing + notes per main slide)
```

Search a question tag (`Q2.5`, `Q4.7`, ...) in the `.pro`/`.geo` files to find the code that
answers it. Meshes and results are generated (ignored by Git).

## Run in Gmsh (ONELAB)

**File > Open** `Source-code/Electrodynamic-analysis/cable.pro` or
`Source-code/Magnetothermal-analysis/cable.pro`, pick the resolution, press **Run**.
Key numbers appear under **Output** in the left panel; maps open automatically.
If Gmsh asks for the GetDP executable: `ONELAB Software/Gmsh.app/Contents/MacOS/getdp`.

| Result | File / resolution | ONELAB setting before **Run** |
|---|---|---|
| Electric baseline (Q2.1–Q2.7) | Electrodynamic / `Electrodynamics` | defaults |
| Mesh convergence | any | Mesh > Mesh factor = 2, 1, 0.5 |
| Touching trefoil | any | Geometry > Jacket gap = 0 |
| Air void (Q2.5) | Electrodynamic | Geometry > Insulation defect = Air void |
| 9 mm XLPE (Q2.8) | Electrodynamic | Geometry > XLPE thickness = 0.009 |
| Magnetic baseline (Q3.1–Q3.10) | Magnetothermal / `Magnetodynamics` | defaults |
| Stranded conductor (Q3.2) | Magnetothermal | Magnetic > Conductor model = Stranded |
| Single-point bonding (Q3.3, Q3.11) | Magnetothermal | Magnetic > Screen bonding = Single point |
| Thermal, linear (Q4.1–Q4.6) | Magnetothermal / `MagnetoThermal` | Thermal > Conductivity model = Linear |
| Thermal, σ(T) (Q4.7–Q4.9) | Magnetothermal / `MagnetoThermal` | defaults |
| Isothermal ground surface (Q4.5) | Magnetothermal / `MagnetoThermal` | Thermal > Ground surface condition = Isothermal |
| Flat formation (Section 5) | Magnetothermal / `MagnetoThermal` | Geometry > Formation = Flat (Jacket gap 0.5 or 70) |

Set **Output > Directory** = `results/<name>` to keep a run (otherwise `res/` is overwritten).

## Reproduce every number (terminal)

```sh
export PATH="$PWD/../ONELAB Software/Gmsh.app/Contents/MacOS:$PATH"   # gmsh + getdp
./run_all.sh                        # all meshes and cases, about 50 min
python3 Reports/collect_values.py   # results + analytical/IEC references -> values.tex + CSV
./Reports/build.sh                  # Section 1-5 PDFs
./Slides/export_maps.sh             # field maps (needs a display)
cd Slides && pdflatex slides.tex && pdflatex slides.tex          # notes: speaker_notes.tex
```

`run_all.sh` lists one line per case with the question it answers. The same `-setnumber`
options are passed to Gmsh and GetDP.

## Modelling assumptions (defended in the reports)

| Assumption | Why / effect | Where |
|---|---|---|
| 0.5 mm soil gap between jackets | removes zero-angle soil wedges (min. quality 0.02 → 0.49); ΔE 0.01 %, ΔL 0.5 % vs touching | S1, Q2.2, Q3.4 |
| Semiconductors 0.4 mm, ideal equipotentials (electric) | NKT gives 32.4 mm over insulation; drop across them ≈ 7 mV | Q1.1, Q2.2 |
| Cu wires + tape → ring of 50 mm² | same DC resistance; lay not representable in 2D | Q1.1, Q3.4 |
| σ_Al fitted to R_DC = 0.164 Ω/km | NKT gives diameter and R_DC, not σ; within 0.2 % of the IEC value | Q1.1 |
| σ_Cu = 5.80e7 S/m (annealed copper) | IEC 60287-1-1 Table 1 / IEC 60228, same value as the IEC check | Q1.1 |
| Air void 0.5 mm at r = 8.8 mm, 1 bar | typical cavity near the highest stress; 2D = cylinder (conservative) | Q2.5 |
| Both-end bonding, ideal earth leads (U = 0) | matches the NKT rating row; single point (I = 0) studied | Q1.3, Q3.3 |
| Soil, semicons, fillers σ = 0 (magnetic) | skin depth ≫ size | Q3.1, Q3.4 |
| Polymers and fillers κ = 0.286 W/(m K) | IEC 60287-2-1 ρ = 3.5 K m/W; same data as the IEC check; halving the filler κ adds ≈2 K | Q1.1, Q4.2 |
| Cu ring midway in the 3 mm screen layer | NKT gives only the envelope; ±2 mm on its diameter changes screen loss ≈ ±13 % | Q1.1, Q3.4 |
| h = 10 W/(m² K) at the ground surface | natural convection ≈2 + radiation ≈5 + wind; 5–20 and isothermal studied | Q4.2, Q4.5 |
| Domain ±20 m, 20 m deep; bottom T = 15 °C, sides adiabatic | T_max within 0.1 K of a 40 m domain | Q4.3 |
| No dielectric losses | IEC 60287: negligible for XLPE below U₀ = 127 kV | Q4.1 |
| Section 5 topic chosen by us (none assigned yet) | arrangement can be checked against six NKT rating rows | S5 |

## Use of AI tools

Codex (OpenAI) helped with the Section 1 geometry fixes and repository cleanup. Claude Code
(Anthropic) helped write the defect geometry, the electrode current balance, the magnetic and
magneto-thermal `cable.pro`, `run_all.sh`, `collect_values.py`, the report text and the slides.
All results were rerun locally with the versions above and checked against analytical formulas,
IEC 60287 and the datasheet. We are responsible for all code and results.
