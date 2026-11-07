#!/usr/bin/env bash
set -euo pipefail

latex_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd -- "$latex_dir/.." && pwd)"

if command -v pdflatex >/dev/null 2>&1; then
    latex_bin="$(command -v pdflatex)"
elif [[ -x /Library/TeX/texbin/pdflatex ]]; then
    latex_bin=/Library/TeX/texbin/pdflatex
else
    printf 'pdflatex is required. Install a TeX distribution such as MacTeX.\n' >&2
    exit 1
fi

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/feem-section1.XXXXXX")"
trap 'rm -rf -- "$build_dir"' EXIT
python3 "$repo_dir/Source-code/section_1/calculate_geometry.py"
cd -- "$latex_dir/section_1"

# Two passes resolve table references and the total page count.
for pass in 1 2; do
    if ! "$latex_bin" -interaction=nonstopmode -halt-on-error \
        -output-directory="$build_dir" -jobname=Section_1_Cable_Selection_and_Model_Setup \
        main.tex > "$build_dir/compiler-output.txt" 2>&1; then
        cat "$build_dir/compiler-output.txt" >&2
        exit 1
    fi
done

cp -- "$build_dir/Section_1_Cable_Selection_and_Model_Setup.pdf" "$repo_dir/Section_1_Cable_Selection_and_Model_Setup.pdf"
printf 'Created %s\n' "$repo_dir/Section_1_Cable_Selection_and_Model_Setup.pdf"
