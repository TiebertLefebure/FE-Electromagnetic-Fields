#!/bin/sh
# Builds Deliverables/: one picture per item of the assignment's list of
# deliverables (Section 6), in one folder per analysis. Nothing is computed here:
#   field maps   = Slides/figures/*.png (Slides/export_maps.sh, Gmsh)
#   plots/tables = Slides/deliverables.tex (same figure sources and generated numbers as the slides)
# Run after Source-Code/run_all.sh, Reports/collect_values.py and Slides/export_maps.sh:  ./Slides/make_deliverables.sh
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FIG=$ROOT/Slides/figures
OUT=$ROOT/Deliverables
E=$OUT/1_Electrodynamic_analysis
M=$OUT/2_Magnetoquasistatic_analysis
T=$OUT/3_Magnetothermal_analysis
rm -rf "$E" "$M" "$T"
mkdir -p "$E" "$M" "$T"

# Plots and value tables: one PDF page each, rendered at 300 dpi.
(cd "$ROOT/Slides" && pdflatex -interaction=nonstopmode -halt-on-error deliverables.tex > /dev/null \
  && pdflatex -interaction=nonstopmode -halt-on-error deliverables.tex > /dev/null)
page() { # page <number> <png>
  gs -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r300 -dFirstPage="$1" -dLastPage="$1" \
     -sOutputFile="$2" "$ROOT/Slides/deliverables.pdf"
}
# Field maps: the Gmsh PNGs, with their transparent background made white.
map() { # map <figure name> <png>
  python3 - "$FIG/$1.png" "$2" <<'PY'
import shutil, sys
try:
    from PIL import Image
    im = Image.open(sys.argv[1]).convert('RGBA')
    bg = Image.new('RGBA', im.size, 'white'); bg.alpha_composite(im)
    bg.convert('RGB').save(sys.argv[2])
except ImportError:
    shutil.copy(sys.argv[1], sys.argv[2])
PY
}

# ---- Electrodynamic analysis (Section 2) --------------------------------------------------
map e_potential           "$E/1_potential_map.png"
map e_field               "$E/2a_E_field_map_healthy.png"
map e_field_defect        "$E/2b_E_field_map_with_void.png"
map e_field_defect_zoom   "$E/2c_E_field_map_with_void_zoom.png"
map e_jdisp               "$E/3a_displacement_current_map_healthy.png"
map e_jdisp_defect        "$E/3b_displacement_current_map_with_void.png"
map e_jdisp_defect_zoom   "$E/3c_displacement_current_map_with_void_zoom.png"
page 1                    "$E/4_E_field_radial_cut_with_and_without_void.png"
page 2                    "$E/5a_capacitance_vs_frequency.png"
page 3                    "$E/5b_capacitance_FE_analytical_datasheet.png"

# ---- Magnetoquasistatic analysis (Section 3) ----------------------------------------------
map m_b                   "$M/1_B_norm_map.png"
map m_j                   "$M/2_J_norm_map.png"
page 4                    "$M/3_Joule_losses_per_part.png"
page 5                    "$M/4_AC_resistance.png"
page 6                    "$M/5_inductance_vs_frequency.png"
page 7                    "$M/6_values_losses_resistance_inductance.png"

# ---- Coupled magneto-thermal analysis (Section 4): linear and sigma(T) --------------------
map t_cables_lin          "$T/1a_T_in_cable_linear.png"
map t_cables_nl           "$T/1b_T_in_cable_sigmaT.png"
map t_soil_lin            "$T/2a_T_outside_cable_linear.png"
map t_soil_nl             "$T/2b_T_outside_cable_sigmaT.png"
page 8                    "$T/3_convergence_history_nonlinear_iterations.png"
map m_b                   "$T/4a_B_norm_map_linear.png"
map m_b_nl                "$T/4b_B_norm_map_sigmaT.png"
map m_j                   "$T/5a_J_norm_map_linear.png"
map m_j_nl                "$T/5b_J_norm_map_sigmaT.png"
page 9                    "$T/6a_values_linear_vs_sigmaT.png"
page 10                   "$T/6b_change_linear_to_sigmaT.png"

echo "Deliverables/ written"
