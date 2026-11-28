# Finite Elements for Electromagnetic Fields — 33 kV cable system

Electric, magnetic and coupled magneto-thermal FE analysis of three NKT 33 kV
**1×185/50 mm² XLPE-AL** single-core cables buried 1 m deep in trefoil (rating: 350 A, 90 °C).

Group: **Kutikuppala Jaswanth, Lefebure Tiebert, Miseur Torre**. Presentation: 1 December 2026.

Versions: **Gmsh 4.15.2**, **GetDP 4.0.0-git-259f4c38** (ONELAB bundle).

**The code, how to run it, the modelling assumptions and the use of AI tools are described in
[Source-Code/README.md](Source-Code/README.md).**

## Repository

```text
Source-Code/            one folder per section with its Gmsh/GetDP files (course files included
                        unchanged), run_all.sh and README.md
Slides/                 slides.tex -> slides.pdf; speaker_notes.tex -> speaker_notes.pdf;
                        export_maps.sh renders the field maps (Slides/figures);
                        make_deliverables.sh + deliverables.tex -> Deliverables/
Deliverables/           the maps and values of the assignment's deliverables list, one folder per
                        analysis, with an index (README.md)
Reports/                study notes per section (PDFs), LaTeX sources, collect_values.py (copies the
                        printed values into LaTeX macros)
```

The handed-in version is git tag `final` (upload `git archive final Source-Code`: the .geo/.pro
files and `Source-Code/README.md`, not `run_all.sh`), with `Slides/slides.pdf`.

## Reproduce every number and picture (terminal, from this folder)

The scripts are POSIX shell: on Windows run them from Git Bash or WSL, with the ONELAB folder that
holds `gmsh.exe` and `getdp.exe` on the PATH (Git Bash: `export PATH="/c/path/to/onelab:$PATH"`).

```sh
export PATH="$PWD/../ONELAB Software/Gmsh.app/Contents/MacOS:$PATH"   # macOS: gmsh + getdp
./Source-Code/run_all.sh            # all meshes and cases, about 25 min
python3 Reports/collect_values.py   # printed values -> values.tex + CSV
./Reports/build.sh                  # Section 1-5 PDFs
./Slides/export_maps.sh             # field maps (needs a display)
./Slides/make_deliverables.sh       # Deliverables/
cd Slides && pdflatex slides.tex && pdflatex slides.tex          # notes: speaker_notes.tex
```

No number in the slides or reports is typed by hand, and every number is printed by the code in
`Source-Code`: FE values in `results/<case>/*.dat`, the analytical and IEC 60287 references and the
comparisons within a run in `results/<case>/references.txt`, mesh size and quality by
`mesh_quality.geo`. `collect_values.py` only copies them into LaTeX macros
(`Reports/sources/data/values.tex`) and takes the ratio of two printed values for the comparisons
between runs (listed in `Source-Code/README.md`).
