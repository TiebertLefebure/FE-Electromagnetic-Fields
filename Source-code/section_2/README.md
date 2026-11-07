# Section 2 — electrodynamic cable model

Three NKT 33 kV XLPE-AL 1×240+50 mm² cables in touching trefoil, with no armour or pipe.
This directory contains a working **frequency-domain GetDP solve**, Gmsh geometry and
views, and independent post-processing of the computed nodal voltages. It uses the
geometry and electrical properties established in Section 1.

## Run and view

On this Mac, double-click **`Run Section 2.command`**. It computes the healthy model,
checks the result and opens Gmsh with the electric-field magnitude visible.

From a terminal in this directory:

```sh
python3 run.py --open
python3 run.py --study
python3 run.py --defect --case void --open
```

The first command needs Python 3, Gmsh and GetDP; **no Python packages are required**.
The launcher finds tools on PATH, in `/Applications/Gmsh.app`, or in the neighbouring
`ONELAB*` folder. For another installation, specify `--gmsh /path/to/gmsh` and
`--getdp /path/to/getdp`, or set `GMSH_BIN` and `GETDP_BIN`. Paths with spaces are supported.
The tested GetDP real-arithmetic PETSc build handles complex phasors through a real block
system; a second GetDP download is not required to run this model.

Each run writes under `results/<case>/`. Open **`results/healthy/view.geo`** in Gmsh to
reload the healthy results without solving. Under **Post-processing**, toggle the views:

- `|E phasor| [kV/mm]`: nonnegative phasor norm; the default view.
- `Re(V) [kV]`: instantaneous potential at phase-A voltage maximum.
- `Re(E) [kV/mm]`: field vector at that same instant.
- Conduction and displacement current-density magnitudes, in A/m².

The holes are the omitted aluminium conductors; gaps between the coloured annuli
include the omitted copper/PE layers. The actual PE jackets still touch in trefoil.

The maps have **no smoothing** in the analysis. P1 fields are constant per triangle;
view interpolation is only a display setting. All scalar magnitude views use their
first time step (the second exported complex component is zero).

For the investigation results open `validation/RESULTS.md`, and open these plots in Gmsh:
`validation/field_convergence.pos`, `capacitance_convergence.pos`, and
`radial_comparison.pos`. The latter compares healthy, void and thicker-insulation cuts on their common
valid radius interval. Full cuts are retained in each case CSV.

Typical further runs:

```sh
python3 run.py --case refined --mesh-scale 0.125
python3 run.py --case ideal --ideal-screens
python3 run.py --case freq100 --frequency 100
python3 run.py --case thicker_xlpe --extra-xlpe-mm 1 --open
```

Use a new case name to retain a previous result. Reusing a name overwrites only that
case's generated outputs. `--study` reruns the named study cases and validation summary.

## Files and responsibility

| File | Purpose |
|---|---|
| `cable.geo` | Three annular cable domains and optional phase-A gas channel; physical region IDs |
| `cable.pro` | Complex nodal potential formulation, ABC voltage constraints and Gmsh exports |
| `settings.inc` | Shared case switches, mesh size and investigation parameters |
| `parameters.inc` | Generated SI constants; never edit by hand |
| `prepare.py` | Reads the shared Section 1 geometry and material JSON inputs |
| `run.py` | Locates tools, runs mesher/solver, rejects logged errors, verifies and opens results |
| `analyse.py` | Reads the actual GetDP solution, reconstructs P1 gradients and computes checks |
| `study.py` | Mesh, simplification, defect, frequency and design comparisons; writes plots/report |
| `../section_1/cable_inputs.json` | Established cable dimensions, voltage and installation |
| `../shared/materials.json` | Explicit electrical properties and source provenance |
| `../shared/Jacobian_Integration.pro` | The TA's original integration/Jacobian definitions, included unchanged |

The supplied `electrodynamic_formulation.pro` is preserved unchanged as a reference.
`cable.pro` adapts its scalar-potential weak form. It replaces its example-specific cuts,
undefined GUI helper and three-phase energy normalisation with cable-specific exports
and per-phase verification. It corrects displacement units: D is C/m²; jωD is A/m².

## Q2.1 — equation, excitations and domain

Use peak phasors with `x(t) = Re(x_hat exp(jωt))`, `ω=2πf`, initially f=50 Hz:

`−div[(σ + jωε) grad(v)] = 0`, `E = −grad(v)`.

For every test function w that vanishes on the electrode boundaries, the Galerkin
weak form is `∫(σ+jωε) grad(v)·grad(w) dA = 0`. It is the supplied resistive term plus
its `DtDof` displacement term. First-order nodal triangles are used, with the TA's
quadrature. Gmsh's circular CAD boundaries become straight chords in the P1 mesh;
geometry and solution approximation are refined together.

The imposed phase-to-earth peak voltages are 26.944387 kV at angles 0°, −120°, +120°.
Phase A is above B (lower left) and C (lower right). All copper screens are at zero
potential. **The longitudinal 415 A load is not an input to this transverse electric
problem**; it will be used in magnetoquasistatics and thermal analysis.

For each phase the solved radial interval is 8.5–19.7511267 mm:

| Region | Radius interval (mm) | εr | σ (S/m) |
|---|---:|---:|---:|
| Inner semiconductor | 8.5–9.3 | 2.25 | 0.002 |
| XLPE | 9.3–17.3 | 2.5 | 1e−18 |
| Outer semiconductor | 17.3–18.1 | 2.25 | 0.002 |
| Equivalent contact bedding | 18.1–19.7511267 | 2.25 | 0.002 |

The physical model includes the conductor, copper screen and PE jacket from Section 1,
but their interiors are not meshed in this calculation. Ideal conductor voltage is
imposed at r=8.5 mm and ideal grounded copper at its inner radius r=19.7511267 mm.
These are **physical electrode boundaries**, not arbitrary distant truncations.

## Assumptions and their limits (Q2.1–Q2.2)

1. **Continuous equipotential copper screen.** The equal-area annulus of Section 1
   replaces actual helical wires/tape. Inside the uniform cable section, it perfectly
   shields the insulation from the neighbouring phases and environment. This does not
   describe screen gaps, joints, terminations, induced longitudinal voltage or end effects.
2. **Grounded exterior.** With all surrounding screen surfaces and remote earth at zero,
   the exterior homogeneous problem has v=0 as its unique solution. Thus PE jackets,
   bedding, soil and the ground surface contribute exactly zero field and energy under
   this ideal-screen assumption. Omitting them introduces zero exterior truncation error
   *within that model*. It is not evidence that the real wire screen is a perfect shield.
   Soil geometry and boundary conditions must return in Sections 3 and 4.
3. **Uniform 2D cross-section.** No helical lay, axial variation or end effects. The
   three interior domains are electrically independent, although all are solved and
   displayed in their actual trefoil positions. Finite conductor resistance is not used
   to impose longitudinal voltage drop in this transverse calculation.
4. **Finite semiconducting layers retained.** Conductivity 0.002 S/m and εr=2.25 are
   constant reference values from Section 1, also applied to the equivalent contact
   bedding. The optional `IdealScreens=1` solves only the 9.3–17.3 mm XLPE annuli,
   imposing voltages directly on their interfaces. The study quantifies its effect,
   including an exact multilayer comparison to separate physical and mesh differences.
5. **Linear isotropic, temperature-independent materials.** XLPE εr=2.5 and σ=1e−18 S/m
   come from the Section 1 references. No dielectric-loss tangent, dispersion, space charge,
   ageing or ionisation. The very small predicted conductive loss is not a complete
   estimate of real dielectric losses. No magnetically induced E is included in Section 2.
6. **Nominal geometry.** The Section 1 effective copper/contact/PE construction is
   retained. The continuous screen's metal area and jacket thickness do not affect
   this ideal-electrode interior problem, but they matter to later magnetic/thermal work.
   The unknown detailed tape/contact geometry remains an approximation.

The controlled study variants are not silent changes to the NKT baseline:

- **Void (Q2.5):** a circular gas channel of radius 0.25 mm, centred 10.3 mm from
  the phase-A axis along +x. It lies fully inside XLPE, with 0.75 mm clearance to
  the inner XLPE boundary. These are deliberately selected investigation parameters,
  not an alleged NKT manufacturing defect. In 2D it extends infinitely along the
  cable; it is not a spherical bubble. εr=1, σ=0 approximates dry gas before discharge.
- **Thicker XLPE (Q2.8):** increase XLPE from 8 to 9 mm, keep the conductor and
  semiconducting thicknesses, and shift the outer screen/contact/copper/PE interfaces
  outwards by 1 mm. The copper thickness is retained in this hypothetical variant,
  so its area would increase; it is not a new 50 mm² screen specification. Outside
  diameter and touching-trefoil spacing increase by 2 mm. Manufacturing, ampacity
  and cost are not evaluated, and the baseline 415 A rating is not transferred.

## Verification and interpretation (Q2.3, Q2.6, Q2.7)

`analyse.py` post-processes GetDP's nodal voltages; it does **not** solve a second model.
It integrates the constant P1 field over every triangle, computes the element matrix
reaction `K_e v_e`, and checks prescribed voltages and free-node residuals. Terminal
current is the sum of reactions at the inner electrode; the grounded-electrode sum
must be its negative. This is a discretely conservative current, unlike raw gradient
fluxes across arbitrary element edges. Circular flux integrals provide an additional,
independent check and expose gradient discretisation error.

For each phase:

- `Y = I_hat / V_hat`, `C = Im(Y)/ω` (F/m); multiply by 10⁹ for µF/km.
- Independently, `C_energy = ∫ε|E_hat|² dA / |V_hat|²`, with no three-phase factor error.
- Time-average stored electric energy is `W_avg = (1/4) ∫ε|E_hat|² dA`.
- Time-average conductive loss is `(1/2) ∫σ|E_hat|² dA`.
- Current densities are `J_c = σE_hat`, `J_d = jωεE_hat`, and `J_total = J_c+J_d`.

Magnitudes mean `sqrt(|Ex_hat|²+|Ey_hat|²)`, equal to √2 times the time-RMS vector
norm. For a linearly polarised sinusoidal field this is the instantaneous peak;
for a general elliptically polarised complex vector it need not equal that peak.
The healthy coaxial field is linearly polarised. All comparisons use the same norm.

The coaxial check uses the **XLPE interfaces**, not the metal radii:
`C = 2πε / ln(17.3/9.3)` and `E(r)=V_hat/[r ln(17.3/9.3)]`.
For the full finite-screen model, add cylindrical layer impedances
`Z_layer = ln(r_outer/r_inner)/(2π(σ+jωε))`, then `Y=1/ΣZ_layer`.

The study rejects: logged tool errors, missing/wrong electrode potentials, current
imbalance >1e−5, free-node residual >1e−6 of terminal current, mismatch between
energy and terminal C >1e−6 relative, healthy C error >0.1%, healthy Emax error >2%,
phase C spread >0.1%, fine-mesh contour error >1%, and last-step void E change >3%.
These are numerical acceptance tolerances, **not industry insulation limits**.

Mesh scale 1, 0.5 and 0.25 corresponds to a nominal bulk element size of 1, 0.5 and
0.25 mm. The void boundary is refined to one twelfth of that size, grading back to
the bulk mesh over 2 mm. Refine near the inner XLPE boundary (highest healthy field),
material interfaces and void boundary. P1 boundary stresses are one-sided adjacent
triangle values, not exact interface extrapolations. Prefer the converged analytical
healthy boundary value when discussing the residual discretisation error.

NKT lists a **maximum** capacitance of 0.24 µF/km. It is a consistency bound, not an
exact measured target for parameter fitting. Constant material properties imply
nearly frequency-independent capacitance in the studied range; the finite screen
resistance gives a small frequency effect. This does not establish broadband accuracy.

## Field limits and withstand (Q2.4–Q2.5)

The selected NKT sheet provides no admissible local electric-field strengths.
For an explicitly external design-screening comparison, use Eskom 240-56030625
Rev. 3, §3.3(i), Annex B rows 3.29–3.30: **8 kV/mm at the conductor screen and
4 kV/mm at the insulation/core screen at U0**. Compare to RMS stresses, or multiply
both limits by √2 for peak stresses. This source applies to **44–132 kV XLPE cables**;
using it for this 33 kV example is an engineering comparison assumption, not a
manufacturer-specific acceptance rule or a universal breakdown strength.

The healthy cable meets those adopted comparison limits. This is a field-stress
screening result only. Neither the healthy nor defective FE calculation certifies
withstand. In particular, the linear gas-void model cannot predict partial-discharge
inception or breakdown. Do not compare gas stress to the XLPE limit or claim the
void is safe merely because XLPE remains below a comparison limit.

## Sources

- NKT, *33 kV single core cable XLPE-AL*, printed pp. 19–20: local datasheet in the
  repository root; geometry, rated voltage, construction and maximum capacitance.
- KU Leuven, *NMES Assignment 2026*, Section 2 and Appendices A–B: local assignment;
  equations, phasor conventions, analytical formula and requested investigations.
- [GetDP reference manual](https://getdp.info/doc/texinfo/getdp.html): complex systems,
  nodal formulation, post-processing and NodeTable. The TA's weak form is the starting point.
- [Gmsh reference manual](https://gmsh.info/doc/texinfo/gmsh.html): geometry, physical
  groups, meshing, MSH 2.2 and post-processing views.
- [Lee et al., Energies 16, 167 (2023), Table 3](https://doi.org/10.3390/en16010167):
  semiconducting PE εr and conductivity, as adopted in Section 1.
- [Chippendale, *Parameters for extra large cables*, Tables 3–4](https://www.transmissionexcel.com/wp-content/uploads/2016/11/Parameters-for-extra-large-cables-FINAL.pdf):
  XLPE εr, as adopted in Section 1.
- [COMSOL, *Submarine Cable 8 — Inductive Effects 3D*](https://doc.comsol.com/6.4/doc/com.comsol.help.models.acdc.submarine_cable_08_inductive_effects_3d/submarine_cable_08_inductive_effects_3d.html):
  the adopted ideal-insulator XLPE conductivity; its submarine geometry is not used.
- [OES 2 Fourth Edition (2024), 33 kV screen specification](https://www.dcrp-oman.com/documents/DCRP%20Updates/OES2%204th%20Edition-Circular.pdf):
  the 0.8 mm screen thickness design reference and resistivity limits from Section 1.
- [Eskom 240-56030625 Rev. 3 (2022), XLPE cables for 44–132 kV](https://www.etenders.gov.za/home/Download/?blobName=b55b97a6-fb2e-492f-8eb0-01bc9574c555.pdf&downloadedFileName=240-56030625_Specificatin+for+HV+XLPE+cables+and+accessories.pdf):
  explicitly adopted external screen-stress benchmarks; applicability limitation above.

## AI assistance

Codex assisted with the Gmsh/GetDP implementation, documentation, source lookup,
verification routines, and the executed Section 2 study. All numerical results here
come from the saved GetDP solutions. The student must review and be able to explain
the equations, code and assumptions; automated numerical checks are not physical certification.
