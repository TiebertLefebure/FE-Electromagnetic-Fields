#!/bin/sh
# Renders the field maps shown in the slides as PNG, with Gmsh (needs a display).
# Run AFTER the README "reproduce" commands, from the repository root:  ./Slides/export_maps.sh
# Each map: gmsh <result .pos> + a few view options + Print. Nothing is computed here.
# Every map is printed twice: figures/<name>.png with Gmsh's colour scale (reports, Deliverables/)
# and figures/noscale/<name>.png without it (slides, which draw the scale in LaTeX: \map in slides.tex).
set -eu
GMSH=${GMSH:-gmsh}
SRC="$(cd "$(dirname "$0")/.." && pwd)/Source-Code"
OUT="$(cd "$(dirname "$0")" && pwd)/figures"
map() { # map <pos file> <png> <zoom> <dx> <dy> [extra options]; (dx,dy) = target minus data-box centre
  pos=$1; png=$2; zoom=$3; xc=$4; yc=$5; shift 5
  cat > "$OUT/.print.geo" <<GEO
General.GraphicsWidth = 1000; General.GraphicsHeight = 800;
Print.Width = 1000; Print.Height = 800; General.Color.Background = White;
General.SmallAxes = 0; General.Trackball = 0;
General.ScaleX = $zoom; General.ScaleY = $zoom;
General.TranslationX = -($xc); General.TranslationY = -($yc);
View[0].ShowScale = 1; View[0].ScaleType = 1; View[0].IntervalsType = 3;
View[0].NbIso = 30; View[0].ShowTime = 0; View[0].Light = 0;
View[0].SaturateValues = 1; View[0].ColormapNumber = 2;
$*
Print "$OUT/$png";
View[0].ShowScale = 0;
Print "$OUT/noscale/$png";
Exit;
GEO
  "$GMSH" "$pos" "$OUT/.print.geo" -v 1
  echo "wrote $png"
}
mesh() { # mesh <msh file> <png> <zoom> <dx> <dy> <show edges 0/1>: regions coloured by physical group
  cat > "$OUT/.print.geo" <<GEO
General.GraphicsWidth = 1000; General.GraphicsHeight = 800;
Print.Width = 1000; Print.Height = 800; General.SmallAxes = 0;
General.ScaleX = $3; General.ScaleY = $3; General.TranslationX = -($4); General.TranslationY = -($5);
Mesh.SurfaceFaces = 1; Mesh.SurfaceEdges = $6; Mesh.Lines = 0; Mesh.ColorCarousel = 2;
Geometry.Points = 0; Geometry.Curves = 0; Mesh.Light = 0;
Print "$OUT/$2";
Exit;
GEO
  "$GMSH" "$1" "$OUT/.print.geo" -v 1
  echo "wrote $2"
}
mkdir -p "$OUT/noscale"
G="$SRC/1-Cable-selection-and-model-setup/meshes"
# Mesh data box: x in [-20, 20] m, y in [-19, 1] m -> centre (0, -9) m.
mesh "$G/gap.msh"      mesh_domain.png   1    0 0 1
mesh "$G/gap.msh"      mesh_gap.png      8000 -0.010875 9.006279 1
mesh "$G/touching.msh" mesh_touching.png 8000 -0.01075  9.006207 1
# Slides: the same whole-domain mesh as dark edges on white (filled faces hide the coarse elements).
cat > "$OUT/.print.geo" <<GEO
General.GraphicsWidth = 1000; General.GraphicsHeight = 800; Print.Width = 1000; Print.Height = 800;
General.SmallAxes = 0; General.Color.Background = White;
Mesh.SurfaceFaces = 0; Mesh.SurfaceEdges = 1; Mesh.Lines = 0; Mesh.ColorCarousel = 0;
Mesh.Color.Triangles = {60,60,60}; Mesh.LineWidth = 3; Geometry.Points = 0; Geometry.Curves = 0; Mesh.Light = 0;
Print "$OUT/mesh_domain_edges.png";
Exit;
GEO
"$GMSH" "$G/gap.msh" "$OUT/.print.geo" -v 1
echo "wrote mesh_domain_edges.png"
E="$SRC/2-Electrodynamic-analysis/results"
B="$SRC/3-Magnetoquasistatic-analysis/results"
H="$SRC/4-Magnetothermal-analysis/results"
A="$SRC/5-Cable-arrangement/results"
# Electric maps: data box centred at (0, 6.28 mm); the void is at (8.8, 25.11) mm.
# GetDP writes complex results as two time steps (real, imaginary; zero for a norm): RangeType 3
# scales each map to the step it shows instead of to both.
map "$E/gap/potential.pos"          e_potential.png 1 0 0 'View[0].Name = "Re(v) [V], phase A at 0 deg"; View[0].RangeType = 3;'
map "$E/gap/field_norm.pos"         e_field.png     1 0 0 'View[0].RangeType = 3;'
map "$E/gap/displacement_current.pos"    e_jdisp.png 1 0 0 'View[0].RangeType = 3;'
# Healthy vs void, shown side by side: one colour scale per quantity, spanning the real part of
# both results (|E| 2.415-6.285 MV/m, |J_d| 0.0166-0.0426 A/m2), so a colour means the same value
# in every map. The *_cmp maps are the healthy ones on that scale; alone, they keep their own.
ES='View[0].RangeType = 2; View[0].CustomMin = 2.41e6; View[0].CustomMax = 6.29e6;'
JS='View[0].RangeType = 2; View[0].CustomMin = 0.0165; View[0].CustomMax = 0.0426;'
map "$E/gap/field_norm.pos"         e_field_cmp.png 1 0 0 "$ES"
map "$E/defect/field_norm.pos"      e_field_defect.png 1 0 0 "$ES"
map "$E/defect/field_norm.pos"      e_field_defect_zoom.png 12 0.0088 0.018836 "$ES"
map "$E/gap/displacement_current.pos"    e_jdisp_cmp.png 1 0 0 "$JS"
map "$E/defect/displacement_current.pos" e_jdisp_defect.png 1 0 0 "$JS"
map "$E/defect/displacement_current.pos" e_jdisp_defect_zoom.png 12 0.0088 0.018836 "$JS"
# Magnetic maps (EM box +-0.3 m centred at 0): |B| zoomed on the trefoil, |J| in the metals.
map "$B/base/b_norm.pos"     m_b.png  5 0 0 'View[0].RangeType = 2; View[0].CustomMin = 0; View[0].CustomMax = 0.016; General.Color.Text = White;'
map "$B/base/j_norm.pos"     m_j.png  1 0 0 'View[0].RangeType = 2; View[0].CustomMin = 0; View[0].CustomMax = 3.2e6;'
map "$B/single/j_norm.pos"   m_j_single.png 1 0 0 'View[0].RangeType = 2; View[0].CustomMin = 0; View[0].CustomMax = 3.2e6;'
map "$H/nl/b_norm.pos"       m_b_nl.png  5 0 0 'View[0].RangeType = 2; View[0].CustomMin = 0; View[0].CustomMax = 0.016; General.Color.Text = White;'
map "$H/nl/j_norm.pos"       m_j_nl.png  1 0 0 'View[0].RangeType = 2; View[0].CustomMin = 0; View[0].CustomMax = 3.2e6;'
# Thermal maps: T in the cables (EM box) and around them (whole domain, centre (0,-9) m);
# linear and sigma(T) maps share one colour scale per pair, and flat +70 mm shares the trefoil's.
map "$H/nl/T_cables.pos"     t_cables_nl.png  6 0 0 'View[0].RangeType = 2; View[0].CustomMin = 30; View[0].CustomMax = 95;'
map "$H/lin/T_cables.pos"    t_cables_lin.png 6 0 0 'View[0].RangeType = 2; View[0].CustomMin = 30; View[0].CustomMax = 95;'
map "$H/nl/T.pos"            t_soil_nl.png    8 0 8 'View[0].RangeType = 2; View[0].CustomMin = 15; View[0].CustomMax = 50; General.Color.Text = White;'
map "$H/lin/T.pos"           t_soil_lin.png   8 0 8 'View[0].RangeType = 2; View[0].CustomMin = 15; View[0].CustomMax = 50; General.Color.Text = White;'
map "$A/flat70/T_cables.pos" t_cables_flat70.png 2.2 0 0 'View[0].RangeType = 2; View[0].CustomMin = 30; View[0].CustomMax = 95;'
rm -f "$OUT/.print.geo"
