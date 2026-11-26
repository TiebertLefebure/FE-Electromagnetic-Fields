#!/bin/sh
# Reproduces EVERY result in the slides (about 25 min on a laptop): all meshes and cases.
# Each line is one case: the same options go to Gmsh (mesh) and GetDP (solve).
# Results land in <section folder>/results/<case>/: getdp.log, the printed values (*.dat),
# the references and comparisons of that run (references.txt) and the field maps (*.pos).
# Needs gmsh and getdp on PATH, e.g. the ONELAB bundle:
#   export PATH="/path/to/ONELAB/Gmsh.app/Contents/MacOS:$PATH"
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
S1=$ROOT/1-Cable-selection-and-model-setup
MESH=$S1/meshes
mkdir -p "$MESH" "$S1/results"

mesh() {  # mesh <name> [options]; then its size and quality (Section 1)
  name=$1; shift
  (cd "$S1" && gmsh cable.geo -2 -nt 1 -v 1 "$@" -o "$MESH/$name.msh" \
   && gmsh "$MESH/$name.msh" mesh_quality.geo -nopopup -parse_and_exit > "results/mesh_$name.txt" 2>&1)
}
solve() { # solve <folder> <resolution> <case> <mesh> [options]
  dir=$1; res=$2; name=$3; m=$4; shift 4
  (cd "$ROOT/$dir" && getdp cable.pro -msh "$MESH/$m.msh" -solve "$res" \
     -setstring ResultDir "results/$name" -v 3 "$@" > "results-$name.log" 2>&1 \
   && mv "results-$name.log" "results/$name/getdp.log")
  case "$dir/$name" in   # keep the field maps (.pos) only for the cases shown as maps
    2-*/gap|2-*/defect|3-*/base|3-*/single|4-*/lin|4-*/nl|5-*/flat70) ;;
    *) rm -f "$ROOT/$dir/results/$name/"*.pos ;;
  esac
  echo "$dir/$name done"
}
E() { solve 2-Electrodynamic-analysis Electrodynamics_cable "$@"; }
M() { solve 3-Magnetoquasistatic-analysis Magnetodynamics_cable "$@"; }
T() { solve 4-Magnetothermal-analysis MagnetoThermal "$@"; }
A() { solve 5-Cable-arrangement Ampacity "$@"; }

# ---- Section 1: meshes (results/mesh_<name>.txt: triangles and Gmsh ICN quality) ------------
mesh gap                                               # Q1.2, Q2.3
mesh touching    -setnumber JacketGap 0                # Q1.2
mesh coarse      -setnumber MeshFactor 2
mesh fine        -setnumber MeshFactor 0.5
mesh thick       -setnumber tXLPE 0.009
mesh defect      -setnumber Flag_Defect 1
mesh defect-fine -setnumber Flag_Defect 1 -setnumber MeshFactor 0.5
mesh box06       -setnumber OuterBox 0.6
mesh dom10       -setnumber ThermalHalfWidth 10 -setnumber ThermalDepth 10
mesh dom40       -setnumber ThermalHalfWidth 40 -setnumber ThermalDepth 40
mesh flat        -setnumber Formation 1
mesh flat70      -setnumber Formation 1 -setnumber JacketGap 70

# ---- Section 2: electrodynamics -------------------------------------------------------------
E gap gap                                              # Q2.1, Q2.2, Q2.4, Q2.6, Q2.7
E touching touching -setnumber JacketGap 0             # Q2.2
E coarse coarse -setnumber MeshFactor 2                # Q2.3
E fine fine -setnumber MeshFactor 0.5                  # Q2.3
E defect defect -setnumber Flag_Defect 1               # Q2.5
E defect-fine defect-fine -setnumber Flag_Defect 1 -setnumber MeshFactor 0.5
E thick thick -setnumber tXLPE 0.009                   # Q2.8
for f in 5 500 5000; do E f$f gap -setnumber Freq $f; done   # Q2.7

# ---- Section 3: magnetoquasistatics (sigma at 20 C) ----------------------------------------
M base gap                                             # Q3.1, Q3.5-Q3.10
M stranded gap -setnumber Flag_Conductor 1             # Q3.2
M stranded-f500 gap -setnumber Flag_Conductor 1 -setnumber Freq 500
M single gap -setnumber Flag_Bonding 1                 # Q3.3, Q3.10, Q3.11
M touching touching -setnumber JacketGap 0             # Q3.4, Q3.10
M coarse coarse -setnumber MeshFactor 2                # Q3.5
M fine fine -setnumber MeshFactor 0.5                  # Q3.5
M box06 box06 -setnumber OuterBox 0.6                  # Q3.1, Q3.5
for f in 0.01 5 500; do M f$f gap -setnumber Freq $f; done   # Q3.9 (DC), Q3.10

# ---- Section 4: coupled magnetothermal ---------------------------------------------------------
T lin gap -setnumber Flag_NL 0                         # Q4.1-Q4.6 (linear)
T nl gap                                               # Q4.7-Q4.9 (sigma(T))
T lin-iso gap -setnumber Flag_NL 0 -setnumber Flag_SurfaceBC 1   # Q4.5
T nl-iso gap -setnumber Flag_SurfaceBC 1               # Q4.5, Q4.6
T nl-h5 gap -setnumber hConv 5                         # Q4.2 sensitivity
T nl-h20 gap -setnumber hConv 20
T nl-coarse coarse -setnumber MeshFactor 2             # Q4.3, Q4.7 (mesh)
T nl-fine fine -setnumber MeshFactor 0.5
T nl-dom10 dom10 -setnumber ThermalHalfWidth 10 -setnumber ThermalDepth 10   # Q4.3 (domain)
T nl-dom40 dom40 -setnumber ThermalHalfWidth 40 -setnumber ThermalDepth 40

# ---- Section 5: arrangement x bonding: values at 350 A and the FE ampacity (90 C) -------------
A trefoil gap
A trefoil-sp gap -setnumber Flag_Bonding 1
A flat flat -setnumber Formation 1
A flat-sp flat -setnumber Formation 1 -setnumber Flag_Bonding 1
A flat70 flat70 -setnumber Formation 1 -setnumber JacketGap 70
A flat70-sp flat70 -setnumber Formation 1 -setnumber JacketGap 70 -setnumber Flag_Bonding 1
echo "ALL DONE"
