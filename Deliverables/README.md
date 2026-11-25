# Deliverables: field maps and values (assignment Section 6)

One picture per item of the assignment's list, in one folder per analysis. NKT 33 kV
1×185/50 mm² XLPE-AL, three cables in touching trefoil (0.5 mm gap), buried 1 m, 350 A, 50 Hz,
screens bonded at both ends. Field quantities are peak amplitudes; voltages and currents RMS.

Generated, not drawn by hand: `./Source-Code/run_all.sh`, `python3 Reports/collect_values.py`,
`./Slides/export_maps.sh` (maps), then `./Slides/make_deliverables.sh` (this folder). The case names below are the lines of `Source-Code/run_all.sh`.

## 1_Electrodynamic_analysis (Section 2, `Electrodynamic-analysis/cable.pro`)

| Assignment item | File | Case |
|---|---|---|
| Map of the electric potential in the cable area | `1_potential_map.png` (real part, phase A at 0°) | `gap` |
| Map of the electric field, without and with defect | `2a_E_field_map_healthy.png`, `2b_E_field_map_with_void.png`, `2c_E_field_map_with_void_zoom.png` | `gap`, `defect` |
| Map of the displacement current, without and with defect | `3a_displacement_current_map_healthy.png`, `3b_displacement_current_map_with_void.png`, `3c_displacement_current_map_with_void_zoom.png` | `gap`, `defect` |
| Electric field stress along a radial cut, with and without defect | `4_E_field_radial_cut_with_and_without_void.png` | `gap`, `defect-fine` |
| Capacitance (µF/km) vs analytical and datasheet | `5a_capacitance_vs_frequency.png`, `5b_capacitance_FE_analytical_datasheet.png` | `gap`, `f5`, `f500`, `f5000` |

The void is an air cavity of radius 0.25 mm centred at r = 8.8 mm in phase A (its edge 0.75 mm
from the conductor screen). In the full maps it is too small to see: use the zooms.

## 2_Magnetoquasistatic_analysis (Section 3, `Magnetothermal-analysis/cable.pro`, resolution `Magnetodynamics_cable`)

| Assignment item | File | Case |
|---|---|---|
| Map of the magnetic flux density norm in the cable area | `1_B_norm_map.png` | `base` |
| Map of the current density norm in the conducting parts | `2_J_norm_map.png` (aluminium and copper screens) | `base` |
| Joule losses (kW/km) in each conducting part | `3_Joule_losses_per_part.png`, `6_values_losses_resistance_inductance.png` | `base`, `single` |
| AC resistance (Ω/km) | `4_AC_resistance.png`, `6_values_losses_resistance_inductance.png` | `base`, `f0.01` |
| Inductance (mH/km) | `5_inductance_vs_frequency.png`, `6_values_losses_resistance_inductance.png` | `base`, `f0.01`, `f5`, `f500`, `touching` |

Conductivities at 20 °C. No armour or pipe; the soil is non-conducting in the magnetic model.

## 3_Magnetothermal_analysis (Section 4, `Magnetothermal-analysis/cable.pro`, resolution `MagnetoThermal`)

| Assignment item | File | Case |
|---|---|---|
| Map of the temperature in the cable (linear and σ(T)) | `1a_T_in_cable_linear.png`, `1b_T_in_cable_sigmaT.png` | `lin`, `nl` |
| Map of the temperature outside the cable (linear and σ(T)) | `2a_T_outside_cable_linear.png`, `2b_T_outside_cable_sigmaT.png` (ground surface on top) | `lin`, `nl` |
| Convergence history of the nonlinear iterations | `3_convergence_history_nonlinear_iterations.png` | `nl`, `nl-coarse`, `nl-fine` |
| σ(T): same maps compared with the linear case | `4a/4b_B_norm_map_*.png`, `5a/5b_J_norm_map_*.png` (with 1a/1b, 2a/2b) | `base` (= linear), `nl` |
| σ(T): same values compared with the linear case | `6a_values_linear_vs_sigmaT.png`, `6b_change_linear_to_sigmaT.png` | `lin`, `nl` |

Linear = conductivities at 20 °C (one pass); σ(T) = σ₂₀/(1 + α(T − 20)) iterated to a relative
temperature increment below 1e-6. Each linear / σ(T) map pair shares one colour scale (temperature
in the cables 30–95 °C, in the soil 15–50 °C), so the maps can be compared directly.
