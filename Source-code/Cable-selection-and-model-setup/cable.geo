// Full 185 mm2 trefoil geometry. Lengths in metres, except JacketGap in mm.
// [Q1.1, Q1.2] Shared cable construction and local exterior.
// Run in this folder: gmsh cable.geo -2. This builds the mesh, not the electric solve.
Include "parameters.pro";
SetFactory("Built-in");
Mesh.MshFileVersion = 2.2;
// [Q2.3] First-order triangular mesh; the electric potential also uses linear elements.
Mesh.ElementOrder = 1;
Mesh.Algorithm = 6;
Mesh.CharacteristicLengthFromPoints = 1;
Mesh.CharacteristicLengthExtendFromBoundary = 0;
Mesh.SaveAll = 0;

// [Q1.1, Q2.2] Three concentric circular layer stacks; no individual screen wires.
cx[] = {xA,xB,xC};
cy[] = {yA,yB,yC};
// [MODEL] Eight circular regions. The extra filler rings are equivalent
// geometry, not measured extruded layers. Only XLPE is active electrically.
R[]  = {rCon,rSemiIn,rXLPEOut,rSemiOut,rWireIn,rWireOut,rScreenOuter,rJacket};

For p In {0:2}
  pc = 1000 + 100*p;
  Point(pc) = {cx[p],cy[p],0,0.001*MeshFactor};
  For k In {0:7}
    // These tag offsets only keep CAD entity numbers unique.
    baseP = 2000 + p*1000 + k*20;
    baseC = 5000 + p*1000 + k*20;
    rr = R[k];
    lc = MeshFactor * ((k==0 || k==1 || k==2 || k==3 || k==4 || k==5) ? 0.0006 : 0.0015);
    // Twelve arcs put vertices at the nearest points in both spacing cases.
    // In the touching case, Coherence merges the two vertices at each contact.
    For q In {0:11}
      Point(baseP+q+1) = {cx[p]+rr*Cos(q*Pi/6),cy[p]+rr*Sin(q*Pi/6),0,lc};
    EndFor
    For q In {0:11}
      Circle(baseC+q+1) = {baseP+q+1,pc,baseP+(q+1)%12+1};
    EndFor
    Curve Loop(9000+p*100+k) = {baseC+1:baseC+12};
  EndFor
  Plane Surface(10000+p*100) = {9000+p*100};
  For k In {1:7}
    Plane Surface(10000+p*100+k) = {9000+p*100+k,9000+p*100+k-1};
  EndFor
EndFor

// [Q1.2] Exterior box, centred on the trefoil rather than on the ground surface.
// [Q2.1] This exterior is meshed but excluded from the XLPE-only electric domain.
H = OuterBox;
Point(90001) = {-H,-H,0,0.035*MeshFactor};
Point(90002) = { H,-H,0,0.035*MeshFactor};
Point(90003) = { H, H,0,0.035*MeshFactor};
Point(90004) = {-H, H,0,0.035*MeshFactor};
Line(90011) = {90001,90002};
Line(90012) = {90002,90003};
Line(90013) = {90003,90004};
Line(90014) = {90004,90001};
Curve Loop(90020) = {90011,90012,90013,90014};
Plane Surface(90030) = {90020,9007,9107,9207};
Coherence;

// [Q1.1, Q1.2, Q3.5] With a gap, soil between the cables connects to the exterior.
// At exact contact the six inner jacket arcs enclose a separate soil pocket.
// Assign all soil to region 99 in both cases so the solver groups stay the same.
soilSurfaces[] = {90030};
If (JacketGap == 0)
  Curve Loop(90021) = {5149,5150,7145,7146,6141,6142};
  Plane Surface(90031) = {90021};
  soilSurfaces[] += {90031};
EndIf

// [Q2.3, Q3.5] Mesh control: MeshFactor scales this near-cable target and the far mesh.
// [NUMERICAL] Target 0.25 mm elements around all three cables, grading into the soil.
Field[1] = Box;
Field[1].XMin = xB-rJacket-0.002; Field[1].XMax = xC+rJacket+0.002;
Field[1].YMin = yB-rJacket-0.002; Field[1].YMax = yA+rJacket+0.002;
Field[1].VIn = 0.00025*MeshFactor; Field[1].VOut = 0.035*MeshFactor;
Field[1].Thickness = 0.04;
Background Field = 1;

// [Q1.1] Named material regions. These tags are how GetDP identifies each layer.
// [Q2.1] Only XLPE tags 41/42/43 are selected by the working electric model.
Physical Surface("Conductor_A", 21) = {10000};
Physical Surface("Conductor_B", 22) = {10100};
Physical Surface("Conductor_C", 23) = {10200};
Physical Surface("SemiIn_A", 31) = {10001};
Physical Surface("SemiIn_B", 32) = {10101};
Physical Surface("SemiIn_C", 33) = {10201};
Physical Surface("XLPE_A", 41) = {10002};
Physical Surface("XLPE_B", 42) = {10102};
Physical Surface("XLPE_C", 43) = {10202};
Physical Surface("SemiOut_A", 51) = {10003};
Physical Surface("SemiOut_B", 52) = {10103};
Physical Surface("SemiOut_C", 53) = {10203};
Physical Surface("FillerInner_A", 61) = {10004};
Physical Surface("FillerInner_B", 62) = {10104};
Physical Surface("FillerInner_C", 63) = {10204};
Physical Surface("CuScreen_A", 71) = {10005};
Physical Surface("CuScreen_B", 72) = {10105};
Physical Surface("CuScreen_C", 73) = {10205};
Physical Surface("FillerOuter_A", 81) = {10006};
Physical Surface("FillerOuter_B", 82) = {10106};
Physical Surface("FillerOuter_C", 83) = {10206};
Physical Surface("PEJacket_A", 91) = {10007};
Physical Surface("PEJacket_B", 92) = {10107};
Physical Surface("PEJacket_C", 93) = {10207};
Physical Surface("Exterior", 99) = {soilSurfaces[]};

// [Q2.1, Q2.2] Voltage-boundary tags for the ideal-semiconductor approximation.
// [ELECTRIC APPROXIMATION] These are the XLPE interfaces, not the actual
// aluminium/copper surfaces. Both semiconductors are ideal equipotentials.
Physical Curve("Live_A", 101) = {5021:5032};
Physical Curve("Live_B", 102) = {6021:6032};
Physical Curve("Live_C", 103) = {7021:7032};
Physical Curve("GroundedScreens", 110) = {
  5041:5052,6041:6052,7041:7052
};
// [Q3.1] Boundary for the proposed magnetic truncation; unused by the electric solve.
Physical Curve("OuterBoundary", 120) = {90011,90012,90013,90014};

// [Q2.5 - NOT IMPLEMENTED] No void/defect surface exists in this healthy geometry.
// [Q2.8] Changing tXLPE rebuilds the XLPE/outer-SC interfaces in the same layer loop.

Coherence;

// [Q2.1 - GMSH RUN BUTTON] Open ../Electrodynamic-analysis/cable.pro in Gmsh.
// Its one-line companion cable.geo includes THIS geometry; press Run to mesh and solve.
