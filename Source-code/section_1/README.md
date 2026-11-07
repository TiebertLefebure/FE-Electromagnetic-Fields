# Section 1: cable selection and model setup

`cable_inputs.json` is the baseline geometry/excitation/installation input.
Run `python3 calculate_geometry.py` here to regenerate `derived_geometry.json`
and the Section 1 LaTeX geometry macros. The script checks layer ordering,
50 mm² copper area, touching-trefoil spacing and burial geometry; it computes
peak excitation amplitudes. No FE problem is solved in Section 1.

| Question | Files needed | Result / interpretation |
|---|---|---|
| Q1.1 | `cable_inputs.json`, `calculate_geometry.py`, `../shared/materials.json`; manufacturer/literature sources cited in the PDF | `derived_geometry.json` for radii and effective aluminium conductivity. The full material/source table remains in `../../LaTeX/section_1/main.tex`; the JSON electrical material file covers the Section 2 subset. |
| Q1.2 | `cable_inputs.json`; datasheet and the PDF answer | Environment, depth, soil properties and explicit homogenisation assumptions. No solver run. |
| Q1.3 | `cable_inputs.json`, `../section_2/cable.pro` | Declared both-ends screen bonding; zero electric screen potential. The magnetic longitudinal bonding condition is reserved for Section 3. |
| Q1.4 | `calculate_geometry.py`, `cable_inputs.json`, `../section_2/cable.pro` | `derived_geometry.json` gives peak magnitudes; the PDF gives voltage/current phasors. Only voltage phasors are used in Section 2. |
