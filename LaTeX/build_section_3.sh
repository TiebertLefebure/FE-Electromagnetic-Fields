#!/usr/bin/env bash
set -euo pipefail
latex_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$latex_dir/.." && pwd)"
python_bin="${PYTHON:-$repo_dir/.venv/bin/python}"
if [[ ! -x "$python_bin" ]]; then python_bin=python3; fi
"$python_bin" "$repo_dir/Source-code/section_3/report.py"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/feem-section3.XXXXXX")"
trap 'rm -rf -- "$build_dir"' EXIT
cd -- "$latex_dir/section_3"
for pass in 1 2; do
    if ! pdflatex -interaction=nonstopmode -halt-on-error \
        -output-directory="$build_dir" -jobname=Section_3_Magnetoquasistatic_Analysis \
        main.tex > "$build_dir/compiler-output.txt" 2>&1; then
        cat "$build_dir/compiler-output.txt" >&2
        exit 1
    fi
done
if grep -Eq 'Overfull \\hbox|Overfull \\vbox|undefined references' "$build_dir/Section_3_Magnetoquasistatic_Analysis.log"; then
    grep -E 'Overfull|undefined references' "$build_dir/Section_3_Magnetoquasistatic_Analysis.log" >&2
    exit 1
fi
cp -- "$build_dir/Section_3_Magnetoquasistatic_Analysis.pdf" "$repo_dir/Section_3_Magnetoquasistatic_Analysis.pdf"
printf 'Created %s\n' "$repo_dir/Section_3_Magnetoquasistatic_Analysis.pdf"
