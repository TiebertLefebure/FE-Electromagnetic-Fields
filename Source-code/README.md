# Code overview

| Folder | Start here | Purpose |
|---|---|---|
| [Cable-selection-and-model-setup](Cable-selection-and-model-setup/README.md) | `parameters.pro`, `cable.geo` | Cable data and the single shared geometry. |
| [Electrodynamic-analysis](Electrodynamic-analysis/README.md) | `cable.pro` | Open in Gmsh and press Run for the electric problem and field maps. |
| [Magnetoquasistatic-analysis](Magnetoquasistatic-analysis/README.md) | `magnetodynamic_formulation.pro` | Course starter for the next analysis. |
| [shared](shared/README.md) | `Jacobian_Integration.pro` | Original course integration rules. |

For the Gmsh Run button, open `Electrodynamic-analysis/cable.pro`.
Its one-line companion `cable.geo` includes the shared geometry, so ONELAB
can mesh and solve without terminal commands. For the terminal workflow,
build the mesh in `Cable-selection-and-model-setup`, then pass that mesh to
GetDP from `Electrodynamic-analysis`. The exact steps are in both READMEs.
Edit the dimensions in `Cable-selection-and-model-setup/parameters.pro` and
remesh after changing them. There is only one geometry definition; the electric
folder's `.geo` entry file only includes it. Question-number comments identify
the relevant blocks, with unfinished work labelled explicitly.

Generated meshes, ONELAB databases, solutions and `res/` field maps are ignored
by Git. The old Python study/report workflow is no longer part of the active code.
