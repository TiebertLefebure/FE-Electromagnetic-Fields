# Current reports

These PDFs describe the simple active model, using Jaswanth's repaired
185 + 50 mm² geometry. Each question has a local code guide: files to read,
what to run, and the output to check. File links are relative to this folder;
keep the PDFs here if you want those links to work.

- Section 1 documents the 0.5 mm gap assumption and compares both meshes.
  The touching case represents the datasheet rating geometry. Only XLPE
  properties are used by the current electric solver.
- Section 2 contains newly checked healthy-cable results, mesh convergence,
  frequency checks, the paired gap comparison and the 9 mm XLPE trial. The defect case and independent
  FE boundary-flux balance are explicitly unfinished.
- Section 3 gives an analytical estimate of how the spacing changes inductance. The active
  magnetic file is an annotated course starter, not a complete cable problem.
  Archived magnetic results are not treated as results of that starter.

The original question wording remains in shaded boxes. Inputs and model
assumptions are commented directly in the simple `.pro` and `.geo` files.

## Rebuild

With `pdflatex` on PATH, run from the repository root:

```sh
./Reports/build.sh
```

This compiles `sources/section_1.tex`, `section_2.tex` and `section_3.tex` using
the shared layout in `sources/common.tex` and the original question text in
`sources/questions.tex`. It does not run Gmsh or GetDP.

`sources/data/` contains the checked electric values and CSV plot data;
`sources/figures/` contains the figures used in the PDFs. These are report
snapshots, not solver inputs. If you change the model, rerun the relevant
question's commands and update the report data before rebuilding.
