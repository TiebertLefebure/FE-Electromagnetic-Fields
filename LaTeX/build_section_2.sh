#!/usr/bin/env bash
set -euo pipefail
latex_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$latex_dir/.." && pwd)"
if command -v pdflatex >/dev/null 2>&1; then
    latex_bin="$(command -v pdflatex)"
elif [[ -x /Library/TeX/texbin/pdflatex ]]; then
    latex_bin=/Library/TeX/texbin/pdflatex
else
    printf 'pdflatex is required (for example MacTeX).\n' >&2
    exit 1
fi
python3 "$repo_dir/Source-code/section_2/export_report.py"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/feem-section2.XXXXXX")"
trap 'rm -rf -- "$build_dir"' EXIT
cd -- "$latex_dir/section_2"
for pass in 1 2; do
    if ! "$latex_bin" -interaction=nonstopmode -halt-on-error \
        -output-directory="$build_dir" -jobname=Section_2_Electrodynamic_Analysis \
        main.tex > "$build_dir/compiler-output.txt" 2>&1; then
        cat "$build_dir/compiler-output.txt" >&2
        exit 1
    fi
done
if grep -Eq 'Overfull \\hbox|Overfull \\vbox|undefined references' "$build_dir/Section_2_Electrodynamic_Analysis.log"; then
    grep -E 'Overfull|undefined references' "$build_dir/Section_2_Electrodynamic_Analysis.log" >&2
    exit 1
fi
cp -- "$build_dir/Section_2_Electrodynamic_Analysis.pdf" "$repo_dir/Section_2_Electrodynamic_Analysis.pdf"
printf 'Created %s\n' "$repo_dir/Section_2_Electrodynamic_Analysis.pdf"
