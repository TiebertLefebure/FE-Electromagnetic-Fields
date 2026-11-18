# Section 2 results

Run `python3 run.py --study` to regenerate.

Fields are peak phasor norms. Capacitance is per phase.

| Case | Complex DOFs | C_A (µF/km) | Max XLPE (kV/mm) | Max gas (kV/mm) |
|---|---:|---:|---:|---:|
| coarse | 3645 | 0.22407752 | 4.57877 | 0.00000 |
| medium | 14157 | 0.22407594 | 4.62530 | 0.00000 |
| healthy | 56305 | 0.22407466 | 4.65135 | 0.00000 |
| ideal | 36761 | 0.22407466 | 4.65135 | 0.00000 |
| void_coarse | 15336 | 0.22398569 | 5.96934 | 6.10226 |
| void | 61106 | 0.22398426 | 5.97591 | 6.11522 |
| thicker_xlpe | 63451 | 0.20547224 | 4.26098 | 0.00000 |
| freq_5 | 56305 | 0.22407466 | 4.65135 | 0.00000 |
| freq_500 | 56305 | 0.22407466 | 4.65135 | 0.00000 |
| freq_5000 | 56305 | 0.22407464 | 4.65135 | 0.00000 |

## Checks

- capacitance_relative_error: 8.07735e-07 (relative).
- healthy_peak_field_relative_error: 0.0035173 (relative).
- phase_capacitance_relative_spread: 1.86139e-07 (relative).
- defect_peak_change_last_refinement: 0.00212316 (relative).

## Where to look

- Q2.1/Q2.4: `results/healthy/view.geo` and `metrics.json`.
- Q2.2: `results/ideal/metrics.json` and `validation/analytical_reference.json`.
- Q2.3: `validation/convergence.csv`, `field_convergence.pos`, `capacitance_convergence.pos`.
- Q2.5: `results/void/view.geo` and `validation/defect_comparison.pos`.
- Q2.6: current-density views and conservation checks in `results/healthy/`.
- Q2.7: the frequency cases in `validation/summary.json`.
- Q2.8: `results/thicker_xlpe/view.geo` and `validation/design_comparison.pos`.

Paths above are relative to `section_2/`. See `README.md` and the Section 2 PDF
for equations, assumptions and source applicability. The linear void model
does not determine discharge inception or withstand.
