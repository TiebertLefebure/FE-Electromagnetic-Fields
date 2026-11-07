# Section 3: magnetoquasistatic analysis

`magnetodynamic_formulation.pro` is the original TA formulation, retained unchanged.
There is no complete cable-specific Section 3 geometry, driver or verified result yet.
Future Section 3 code and results belong in this folder. Common integration definitions
are in `../shared/Jacobian_Integration.pro` and baseline cable inputs in
`../section_1/cable_inputs.json`.

Do not use the Section 2 dielectric-only mesh as a magnetic/thermal cable mesh:
conductors, copper screens and an exterior magnetic domain will be required.
