# Code overview

| Folder | Start here | Purpose |
|---|---|---|
| [Cable-selection-and-model-setup](Cable-selection-and-model-setup/README.md) | `parameters.pro`, `cable.geo` | All data (ONELAB parameters) and the single shared geometry/mesh. |
| [Electrodynamic-analysis](Electrodynamic-analysis/README.md) | `cable.pro` | Section 2: open in Gmsh, press Run. |
| [Magnetothermal-analysis](Magnetothermal-analysis/README.md) | `cable.pro` | Sections 3-5: resolution `Magnetodynamics` or `MagnetoThermal`. |

Each analysis folder has a one-line `cable.geo` that includes the shared geometry: Gmsh looks
for a `.geo` with the same name as the opened `.pro`. Search a question tag (`Q2.5`, `Q4.7`, ...)
to find the code that answers it. `../run_all.sh` runs every case of the reports.
