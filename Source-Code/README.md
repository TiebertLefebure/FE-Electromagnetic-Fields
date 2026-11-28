# Source code — FE analysis of a 33 kV cable system

Electric, magnetic and coupled magnetothermal FE analysis of three NKT 33 kV
**1×185/50 mm² XLPE-AL** single-core cables buried 1 m deep in trefoil (rating: 350 A, 90 °C).
Group: **Kutikuppala Jaswanth, Lefebure Tiebert, Miseur Torre**.

Versions: **Gmsh 4.15.2**, **GetDP 4.0.0-git-259f4c38** (ONELAB bundle).

Every number and map in the slides is printed by these files: FE values in
`results/<case>/*.dat`, field maps in `*.pos`, and in `results/<case>/references.txt` the analytical
and IEC 60287 references with the comparisons within that run. A change between two runs is the
ratio (or difference) of two printed values; those are listed in
[Comparisons between runs](#comparisons-between-runs).

## Files: one folder per section of the assignment

```text
1-Cable-selection-and-model-setup/
  parameters.pro           ALL cable, material, excitation, thermal and datasheet data as ONELAB
                           parameters, each with its source tag ([NKT], [NBS], [ASSUMPTION], ...)
  cable.geo                the only geometry and mesh (cables, EM box, soil up to the ground surface)
  mesh_quality.geo         number of triangles and Gmsh's quality (ICN) of a mesh
  Jacobian_Integration.pro course file, unchanged: Jacobians and Gauss rules (all models)
2-Electrodynamic-analysis/
  cable.pro                Section 2: electric problem in the XLPE (+ air void), resolution
                           Electrodynamics_cable, outputs and analytical references
  electrodynamic_formulation.pro   course file, unchanged: function space, weak form, post-processing
3-Magnetoquasistatic-analysis/
  cable.pro                Section 3: a-v magnetic problem (sigma at 20 C), resolution
                           Magnetodynamics_cable, outputs, analytical and IEC 60287 references
  magnetodynamic_formulation.pro   course file, unchanged: a-v function spaces, weak form, post-processing
4-Magnetothermal-analysis/
  cable.pro                Section 4: includes the Section 3 model unchanged, adds the heat equation
                           and the sigma(T) coupling; resolution MagnetoThermal; IEC 60287 thermal ladder
5-Cable-arrangement/
  cable.pro                Section 5: includes the Section 4 model unchanged, adds resolution Ampacity
                           (current for a 90 C hot spot)
2-5/cable.geo              one-line include of the shared geometry (so the Gmsh Run button works)
```

Each `cable.pro` defines what the course files leave to the user (groups, materials, sources,
constraints) and the resolutions and outputs for this cable, then includes the course files.
GetDP does not allow redefining a name, so our resolutions are `Electrodynamics_cable`,
`Magnetodynamics_cable`, `MagnetoThermal` and `Ampacity`; the course resolutions (`Electrodynamics`,
`Magnetodynamics`) are written for the course example cable and are not used. Search a question
tag (`Q2.5`, `Q4.7`, ...) in the `.pro`/`.geo` files to find the code that answers it.

## Run in Gmsh (ONELAB)

**File > Open** the `cable.pro` of a section folder and press **Run**: Gmsh meshes, GetDP solves
with the folder's resolution, the key numbers appear under **Output** and the maps open. If Gmsh asks
for the GetDP executable, select `getdp` (`getdp.exe` on Windows) of the ONELAB bundle. Set
**Output > Directory** = `results/<name>` to keep a run (otherwise `res/` is overwritten).

| Result in the slides | Folder (resolution) | ONELAB setting before **Run** |
|---|---|---|
| Mesh size and quality (Q1.2) | 1 | terminal: `gmsh meshes/gap.msh mesh_quality.geo -nopopup -parse_and_exit` (below) |
| Electric baseline (Q2.1–Q2.7) | 2 (`Electrodynamics_cable`) | defaults |
| Mesh convergence (Q2.3, Q3.5, Q4.3) | 2, 3, 4 | Mesh > Mesh factor = 2, 1, 0.5 |
| Touching trefoil (Q1.2, Q2.2, Q3.4) | 2, 3 | Geometry > Jacket gap = 0 |
| Air void (Q2.5) | 2 | Geometry > Insulation defect = Air void (and Mesh factor 0.5 for the fine run) |
| 9 mm XLPE (Q2.8) | 2 | Geometry > XLPE thickness = 0.009 |
| Frequency (Q2.7, Q3.9, Q3.10) | 2, 3 | Cable > Frequency = 5, 500, 5000 (2); 0.01, 5, 500 (3) |
| Magnetic baseline (Q3.1–Q3.10) | 3 (`Magnetodynamics_cable`) | defaults |
| EM box size (Q3.1, Q3.5) | 3 | Geometry > Electromagnetic half-box = 0.6 |
| Stranded conductor (Q3.2) | 3 | Magnetic > Conductor model = Stranded (also at 500 Hz) |
| Single-point bonding (Q3.3, Q3.10, Q3.11) | 3 | Magnetic > Screen bonding = Single point |
| Thermal, linear (Q4.1–Q4.6) | 4 (`MagnetoThermal`) | Thermal > Conductivity model = Linear |
| Thermal, σ(T) (Q4.4–Q4.9) | 4 (`MagnetoThermal`) | defaults |
| Isothermal ground surface (Q4.5, Q4.6) | 4 | Thermal > Ground surface condition = Isothermal (linear and σ(T)) |
| Heat transfer coefficient (Q4.2) | 4 | Thermal > Surface heat transfer coefficient = 5, 20 |
| Thermal domain size (Q4.3) | 4 | Thermal > half-width and depth = 10, 40 |
| Arrangement × bonding, ampacity (Section 5) | 5 (`Ampacity`) | Geometry > Formation = Trefoil / Flat; Jacket gap = 0.5 / 70 (flat); Magnetic > Screen bonding |

## Exact commands (terminal)

Every result in the slides comes from one mesh command and one solve command. `<options>` are the
`-setnumber` options of the tables below; a case passes the options of its mesh to GetDP as well.
`gmsh` and `getdp` are the executables of the ONELAB bundle: put their folder on the PATH or type
their full path. The commands are the same in any terminal (Windows, macOS, Linux).

1. Mesh `<m>`, its size and quality: in `1-Cable-selection-and-model-setup`, with the empty folders
   `meshes` and `results` created there first,

   ```text
   gmsh cable.geo -2 -nt 1 <options> -o meshes/<m>.msh
   gmsh meshes/<m>.msh mesh_quality.geo -nopopup -parse_and_exit > results/mesh_<m>.txt
   ```

2. Case `<c>` on mesh `<m>`: in the section folder of the case (GetDP creates `results/<c>`),

   ```text
   getdp cable.pro -msh ../1-Cable-selection-and-model-setup/meshes/<m>.msh -solve <resolution> -setstring ResultDir results/<c> <options>
   ```

Example, the magnetic baseline: mesh `gap` with no options, then in `3-Magnetoquasistatic-analysis`
`getdp cable.pro -msh ../1-Cable-selection-and-model-setup/meshes/gap.msh -solve Magnetodynamics_cable -setstring ResultDir results/base`.

**Meshes** (folder 1):

| Mesh | Options | Used for |
|---|---|---|
| `gap` | — | default (Q1.2, all baselines) |
| `touching` | `-setnumber JacketGap 0` | Q1.2, Q2.2, Q3.4 |
| `coarse` / `fine` | `-setnumber MeshFactor 2` / `0.5` | Q2.3, Q3.5, Q4.3 |
| `thick` | `-setnumber tXLPE 0.009` | Q2.8 |
| `defect` / `defect-fine` | `-setnumber Flag_Defect 1` (fine: also `-setnumber MeshFactor 0.5`) | Q2.5 |
| `box06` | `-setnumber OuterBox 0.6` | Q3.1, Q3.5 |
| `dom10` / `dom40` | `-setnumber ThermalHalfWidth 10 -setnumber ThermalDepth 10` (40: both 40) | Q4.3 |
| `flat` / `flat70` | `-setnumber Formation 1` (70: also `-setnumber JacketGap 70`) | Section 5 |

**Cases** (results in `<folder>/results/<case>/`; options of the mesh not repeated):

| Folder, resolution | Case: mesh, extra options | Questions |
|---|---|---|
| 2, `Electrodynamics_cable` | `gap`: gap · `touching`: touching · `coarse`: coarse · `fine`: fine · `defect`: defect · `defect-fine`: defect-fine · `thick`: thick · `f5`, `f500`, `f5000`: gap, `-setnumber Freq 5` (500, 5000) | Q2.1–Q2.8 |
| 3, `Magnetodynamics_cable` | `base`: gap · `stranded`: gap, `-setnumber Flag_Conductor 1` · `stranded-f500`: same + `-setnumber Freq 500` · `single`: gap, `-setnumber Flag_Bonding 1` · `touching`: touching · `coarse`: coarse · `fine`: fine · `box06`: box06 · `f0.01`, `f5`, `f500`: gap, `-setnumber Freq 0.01` (5, 500) | Q3.1–Q3.11 |
| 4, `MagnetoThermal` | `lin`: gap, `-setnumber Flag_NL 0` · `nl`: gap · `lin-iso`: gap, `-setnumber Flag_NL 0 -setnumber Flag_SurfaceBC 1` · `nl-iso`: gap, `-setnumber Flag_SurfaceBC 1` · `nl-h5`, `nl-h20`: gap, `-setnumber hConv 5` (20) · `nl-coarse`: coarse · `nl-fine`: fine · `nl-dom10`: dom10 · `nl-dom40`: dom40 | Q4.1–Q4.9 |
| 5, `Ampacity` | `trefoil`: gap · `trefoil-sp`: gap, `-setnumber Flag_Bonding 1` · `flat`: flat · `flat-sp`: flat, `-setnumber Flag_Bonding 1` · `flat70`: flat70 · `flat70-sp`: flat70, `-setnumber Flag_Bonding 1` | Section 5 |

All 12 meshes and 37 cases take about 25 minutes on a laptop.

## What each run prints

`.dat` files (GetDP `Format Table`): index, real part, imaginary part for complex quantities.
`references.txt`: one `name value` per line. `getdp.log`: the number of unknowns ("Dofs").

| Section | FE values (`results/<case>/`) | `references.txt` (analytical, IEC 60287, within-run comparisons) |
|---|---|---|
| 1 | `mesh_<name>.txt`: `Triangles:`, `ICN = worst, average, best` | — |
| 2 | `max_field_kV_mm.dat`, `capacitance_uF_km.dat` (energy), `capacitance_charge_uF_km.dat`, `electrode_current_A*.dat`, `max_Jd_A_m2.dat`, `max_Jc_A_m2.dat`, `triangles_XLPE_A.dat`, `radial_field_A.txt`; maps `potential.pos`, `field_norm.pos`, `displacement_current.pos`, `conduction_current.pos`; with the void: `void_area.dat`, `void_field_integral.dat` | `AnaC`, `AnaEi` (and RMS values), `AnaEzero`, `AnaEvoid`, `AnaIch`, `AnaJd`, `AnaJc`, `AnaRatio`, `AnaDrop`, `AnaCbare`/`dCbare`, `AnaEb` (Schumann), `AnaEbPaschen`, `dEana`, `dCana`, `dCnkt`, `IchFE`, `IratioFE`, `dCcharge` (charge vs energy C); with the void `EvoidMean`, `VoidRatio`, `PdInception` |
| 3 | `losses_conductors.dat`, `losses_screens.dat`, `losses_total.dat`, `losses_condA/B/C.dat` (W/m = kW/km), `R_conductors_ohm_km.dat`, `R_ac_ohm_km.dat`, `L_mH_km.dat`, `screen_current_A_rms.dat`, `currents_A.dat`, `voltages_V_m.dat`, `Z_terminal_ohm_km.dat`, `j_line_A.txt`; maps `b_norm.pos`, `j_norm.pos` | `AnaDeltaAl/Cu/Soil` (skin depths), `AnaL`, `NktL`, `Bsingle`, `Javg`, `Bmax`, `Jmax`, `Hmetal` (element size in the metals), IEC at 20 °C: `IecRdc`, `IecYs`, `IecYp`, `IecRcond`, `IecRs`, `IecX`, `IecLam`, `IecRac`, `IecIs`, `IecPc`, `IecPs`, `IecPt`, `IecUs`; `dLana`, `dLnkt`, `CondShare`, `LamFE`, `PcPhase`, `PhaseSym`, `Lterm`, `dLterm`, `Is`, `dIs`, `IsPeak`, `Jscreen`, `IsSum`; single point: `Usingle` |
| 4 | Section 3 files plus `Tmax_conductor.dat`, `Tmax_condA/B/C.dat`, `Tmax_surface.dat`, `surface_heat_W_m.dat`, `convergence.txt` (iteration, relative increment), `T_surface_profile.txt`; maps `T.pos`, `T_cables.pos` | IEC ladder: `IecTone`, `IecTthree`, `IecTfour`, `IecU`, `IecTheta`, `IecThetaS`, `IecAmp`, `IecRcondHot`, `IecRacHot`, `IecLamHot`, `IecPcHot`, `IecPsHot`; `dTfiller`, `Hrad`, `AnaWd`, `AnaWdShare`, `dToneThick`, `dTthick` (Q2.8); `Nit`, `ConvRate`, `dTcNkt`, `dTsurf`, `QsFrac`, `RhoHot`, `dTsemi`, `TcA/B/C`, `dTcBC`, `dTcAlow`, `Bmax`, `Jmax`; linear runs: `AmpLin` |
| 5 | Section 4 files at 350 A; `Tmax_conductor_amp.dat` (hot spot at the ampacity) | `Amp` (FE ampacity), `AmpNKT`, `dNkt` (% from NKT), `TcAmp`, `AmpSteps` |

## Comparisons between runs

`pct(a, b) = 100 (a/b − 1)`; the runs are the case names above (folder 2: E, 3: M, 4: T, 5: A).

| Slide value | Definition |
|---|---|
| ΔE_max, ΔC touching (Q2.2) | pct(E gap, E touching), pct(C gap, C touching) (E) |
| ΔE_max, ΔC 9 mm XLPE (Q2.8) | pct(thick, gap) (E) |
| Mesh convergence (Q2.3, Q3.5) | values of coarse, gap/base, fine; Δ = pct(fine, base) for R_AC, L, P_s (M) |
| EM box (Q3.1, Q3.5) | pct(box06, base) for L and R_AC (M) |
| Stranded vs massive (Q3.2) | pct(stranded, base) for R_cond and L; pct(stranded-f500, f500) for R_cond (M) |
| Single point vs both ends (Q3.3) | pct(single, base) for P_total and R_AC; eddy share P_s(single)/P_c(base); circulating loss P_s(base) − P_s(single), and its pct to `IecPs` (M) |
| Touching vs gap (Q3.4) | pct(base, touching) for L, R_AC, P_s (M) |
| Skin and screen parts of R_AC (Q3.9) | pct(R_cond base, R_AC f0.01); (R_AC − R_cond)(base) / R_AC(f0.01) (M) |
| L vs frequency (Q3.10) | pct(base, f0.01), pct(f500, f0.01) (M) |
| σ(T) vs linear (Q4.8) | pct(nl, lin) for P_c, P_s, P_total, R_AC, L, B_max, J_max; T_max(nl) − T_max(lin) (T) |
| Surface condition, mesh, domain (Q4.3, Q4.5) | T_max(nl) − T_max(nl-iso); T_max(nl-fine / nl-coarse / nl-dom40 / nl-dom10) − T_max(nl) (T) |
| Single-point gain, wider L (Section 5) | Amp(trefoil-sp) − Amp(trefoil); pct(L flat70-sp, L trefoil); range of `dNkt` over the six runs (A) |

## Model in short

- **Geometry** (`cable.geo`, Q1.1–Q1.2): per cable Al conductor, 0.4 mm semicons, 8 mm XLPE,
  fillers, the Cu wires and tape as one 50 mm² ring, PE jacket. Trefoil with a 0.5 mm soil gap
  between jackets (centre spacing 43.5 mm); origin at the trefoil centre, 1 m below the surface.
  Electromagnetic box ±0.3 m; thermal domain ±20 m wide, 20 m deep. One mesh for all analyses.
  Physical groups: Al 21–23, inner semicon 31–33, XLPE 41–43 (void 44), outer semicon 51–53, inner
  filler 61–63, Cu 71–73, outer filler 81–83, PE 91–93, soil in the box 99, soil outside 98;
  curves 101–103 / 111–113 conductor / insulation screens, 120 box edge, 130 ground surface, 132 bottom.
- **Electric** (Section 2): `-div((σ + jωε) grad v) = 0` in the XLPE (and void), phase voltage on
  the conductor screen, 0 on the insulation screen (semicons as ideal electrodes).
- **Magnetic** (Section 3): `curl(ν curl a) = j`, `a = 0` on the box edge; Al and Cu massive with one
  (U, I) pair each: imposed I in the conductors, U = 0 (both ends) or I = 0 (single point) in the
  screens. Losses use the total current density `σ|jωa + u_r|²/2` (course eq. 9).
- **Thermal and coupling** (Section 4): `-div(κ grad T) = p` with `p` from the complex magnetic
  solution (`<a>[...]`); convection h(T − 15 °C) at the surface, 15 °C at the bottom, no flux at the
  sides. σ(T) = σ₂₀/(1 + α(T − 20)): the course formulation calls `sigma[]` without arguments, so the
  metal temperature is stored as field 1 and read with `ScalarField[XYZ[]]{1}`. Fixed point from
  20 °C (pass 1 = linear model) until ‖T_k − T_k−1‖₂/‖T_k‖₂ < 1e-6.
- **Ampacity** (Section 5): coupled solve at 350 A, then a secant search on I² (first guess
  T − 15 ∝ I²) until the hot spot is within 0.01 K of 90 °C. For a given σ the magnetic problem is
  linear in I, so a new current only scales the loss density by (I/350 A)².

## Modelling assumptions

| Assumption | Why / effect | Where |
|---|---|---|
| 0.5 mm soil gap between jackets | removes zero-angle soil wedges (worst triangle quality 0.020 → 0.575); ΔE 0.01 %, ΔL 0.5 % vs touching | Q1.2, Q2.2, Q3.4 |
| Semiconductors 0.4 mm, ideal equipotentials (electric) | NKT gives 32.4 mm over insulation; drop across them ≈ 7 mV | Q1.1, Q2.2 |
| Cu wires + tape → ring of 50 mm² | same DC resistance; lay not representable in 2D | Q1.1, Q3.4 |
| σ_Al fitted to R_DC = 0.164 Ω/km | NKT gives diameter and R_DC, not σ; within 0.2 % of 61 % IACS aluminium (NBS Handbook 109) | Q1.1 |
| σ_Cu = 5.80e7 S/m (annealed copper) | IACS value, NBS Handbook 100 (free); same value as the IEC check | Q1.1 |
| Air void 0.5 mm, centred at r = 8.8 mm, 1 bar | typical cavity near the highest stress; 2D = cylinder (conservative) | Q2.5 |
| Both-end bonding, ideal earth leads (U = 0) | matches the NKT rating row; single point (I = 0) studied | Q1.3, Q3.3 |
| Soil, semicons, fillers σ = 0 (magnetic) | skin depth ≫ size | Q3.1, Q3.4 |
| Polymers and fillers κ = 0.286 W/(m K) | ρ = 3.5 K m/W (IEC 60287 value, from Enescu et al. 2020, open access); same data as the IEC check; halving the filler κ adds ≈2 K | Q1.1, Q4.2 |
| Cu ring midway in the 3 mm screen layer | NKT gives only the envelope; ±2 mm on its diameter changes screen loss ≈ ±13 % | Q1.1, Q3.4 |
| h = 10 W/(m² K) at the ground surface | natural convection ≈2 + radiation ≈5 + wind; 5–20 and isothermal studied | Q4.2, Q4.5 |
| Domain ±20 m, 20 m deep; bottom T = 15 °C, sides adiabatic | T_max within 0.1 K of a 40 m domain | Q4.3 |
| No dielectric losses | 0.09 W/m per phase, 0.35 % of the conductor loss (printed `AnaWdShare`); IEC 60287 neglects them for XLPE below U₀ = 127 kV | Q4.1 |
| Section 5 topic: free choice (arrangement × bonding) | arrangement can be checked against six NKT rating rows | S5 |

## Use of AI tools

Codex (OpenAI) helped with the Section 1 geometry fixes and repository cleanup. Claude Code
(Anthropic) helped write the defect geometry, the `cable.pro` files around the course
formulation files, the printed references, the run scripts, the report text and the slides.
All results were rerun locally with the versions above and checked against analytical formulas,
IEC 60287 and the datasheet. We are responsible for all code and results.
