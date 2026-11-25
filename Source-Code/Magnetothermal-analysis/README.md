# Magneto-thermal analysis (Sections 3, 4 and 5)

`cable.pro` holds the magnetic a-v problem and the thermal model on the shared mesh. It includes two
course files unchanged: `../Cable-selection-and-model-setup/Jacobian_Integration.pro` and
`magnetodynamic_formulation.pro` (function spaces `Hcurl_a_Mag_2D` and `Hregion_u_Mag_2D`, weak form
`Magnetodynamic_a_2D`, post-processing quantities). `cable.pro` adds the cable problem, the heat
equation and the σ(T) coupling. The one-line `cable.geo` includes the shared geometry so the Gmsh
**Run** button works.

| Resolution | Section | What it does |
|---|---|---|
| `Magnetodynamics_cable` | 3 | a-v problem in the 0.6 m EM box, conductivities at 20 °C |
| `MagnetoThermal` (default) | 4, 5 | magnetic solve → Joule losses → heat conduction up to the ground surface; with `Flag_NL = 1` repeated with σ(T) until the relative temperature increment is below 1e-6 |

## Run in Gmsh (ONELAB)

**File > Open** `cable.pro`, choose the resolution in the GetDP panel, press **Run**.
The **Output** panel shows losses, R, L, the hot-spot and the ground-surface temperature.

| ONELAB setting | Effect |
|---|---|
| Magnetic > Conductor model | massive (solid Al, eddy currents) / stranded (uniform J) |
| Magnetic > Screen bonding | both ends (U = 0) / single point (I = 0) |
| Thermal > Conductivity model | linear (σ at 20 °C, one pass) / nonlinear σ(T) |
| Thermal > Ground surface condition | convection h(T − T_amb) / isothermal T = T_amb |
| Geometry > Formation, Jacket gap | trefoil / flat, spacing (Section 5) |

## Model

- **Magnetic** (Q3.1, course weak form): `curl(nu curl a) = j` in the EM box, `a = 0` on its edge
  (group 120). Massive regions (Al, Cu) carry `j = -sigma(j omega a + ur)` with one global pair
  (U, I) each: imposed I in the conductors; U = 0 (both ends) or I = 0 (single point) in the screens.
- **Thermal** (Q4.1-Q4.2): `-div(kappa grad T) = p`, `p = |j|²/(2 sigma)` from the complex
  solution, evaluated with `<a>[...]` (a real number). Ground surface 1 m above the trefoil
  centre: convection h = 10 W/(m² K) to 15 °C air. Sides 20 m away: zero flux. Bottom 20 m
  deep: T = 15 °C.
- **Coupling** (Q4.7): staggered. The course formulation calls `sigma[]` without arguments, so
  the metal temperature is stored as field 1 before each magnetic solve (`StoreInField`) and
  `sigma[]` reads it with `ScalarField[XYZ[]]{1}`. T starts at 20 °C everywhere, so pass 1 is the
  linear model. Then σ(T) → magnetic → thermal until ‖T_k − T_k−1‖₂ / ‖T_k‖₂ < 1e-6.
- The losses use the **total** current density, `p = sigma |j omega a + ur|² / 2` (course eq. 9);
  the course quantity `JouleLosses` leaves out `ur`, so our post-processing `Mag` computes them.

## Outputs (`res/` or `results/<case>/`)

| File | Meaning |
|---|---|
| `losses_conductors.dat`, `losses_screens.dat`, `losses_condA/B/C.dat` | Joule losses, W/m = kW/km |
| `R_conductors_ohm_km.dat`, `R_ac_ohm_km.dat` | P/(3 I²): conductors only / total |
| `L_mH_km.dat` | ∫ν\|b\|²/(3 Î²), positive-sequence inductance |
| `currents_A.dat`, `voltages_V_m.dat`, `Z_terminal_ohm_km.dat` | global I, U per region; −U/I per phase |
| `Tmax_conductor.dat`, `Tmax_surface.dat` | hot spot and maximum ground-surface temperature, °C |
| `convergence.txt` | iteration, relative temperature increment |
| `T_surface_profile.txt` | T along the ground surface |
| `j_line_A.txt` | \|J\| along phase A's vertical diameter (x, y, z, value) |
| `surface_heat_W_m.dat` | heat leaving through the ground surface |
| `b_norm.pos`, `j_norm.pos`, `T.pos`, `T_cables.pos` | maps (peak phasor norms; T in deg C) |
| `T_metals.pos` | metal temperature used for σ(T) in the last pass |

`.dat` columns: index, real part (and imaginary part for complex quantities).
