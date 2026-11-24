#!/bin/sh
# Rebuild the five section PDFs from the LaTeX sources. No solver runs here:
# the numbers come from sources/data/values.tex (python3 Reports/collect_values.py).
set -eu
cd "$(dirname "$0")/sources"
for section in 1 2 3 4 5; do
  pdflatex -interaction=nonstopmode -halt-on-error "section_${section}.tex" > /dev/null
  pdflatex -interaction=nonstopmode -halt-on-error "section_${section}.tex" > /dev/null
done
mv section_1.pdf ../Section_1_Cable_Selection_and_Model_Setup.pdf
mv section_2.pdf ../Section_2_Electrodynamic_Analysis.pdf
mv section_3.pdf ../Section_3_Magnetoquasistatic_Analysis.pdf
mv section_4.pdf ../Section_4_Magnetothermal_Analysis.pdf
mv section_5.pdf ../Section_5_Cable_Arrangement.pdf
echo "built 5 reports"
