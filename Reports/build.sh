#!/bin/sh
# Rebuild the three PDFs from the checked-in LaTeX sources. No solver runs.
set -eu
cd "$(dirname "$0")/sources"
for section in 1 2 3; do
  pdflatex -interaction=nonstopmode -halt-on-error "section_${section}.tex"
  pdflatex -interaction=nonstopmode -halt-on-error "section_${section}.tex"
done
mv section_1.pdf ../Section_1_Cable_Selection_and_Model_Setup.pdf
mv section_2.pdf ../Section_2_Electrodynamic_Analysis.pdf
mv section_3.pdf ../Section_3_Magnetoquasistatic_Analysis.pdf
