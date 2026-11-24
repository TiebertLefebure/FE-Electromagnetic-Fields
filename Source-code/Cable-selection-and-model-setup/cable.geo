// The single geometry and mesh used by ALL analyses. Lengths in metres.
// Three cables x 8 concentric layers, a soil box of +-OuterBox (electromagnetic domain)
// and a large soil region up to the ground surface (thermal domain, Section 4).
// Run here: gmsh cable.geo -2  (the analysis folders include this file for the Run button).
Include "parameters.pro";
SetFactory("Built-in");
Mesh.MshFileVersion = 2.2;
Mesh.ElementOrder = 1;          // [Q2.3] linear triangles
Mesh.Algorithm = 6;             // Frontal-Delaunay
Mesh.CharacteristicLengthFromPoints = 1;
Mesh.CharacteristicLengthExtendFromBoundary = 0;  // interior sizes from the fields below

// ---- Cables [Q1.1] -------------------------------------------------------------------------
cx[] = {xA,xB,xC};
cy[] = {yA,yB,yC};
// Al, inner semicon, XLPE, outer semicon, inner filler, Cu ring, outer filler, PE jacket.
R[] = {rCon,rSemiIn,rXLPEOut,rSemiOut,rWireIn,rWireOut,rScreenOuter,rJacket};

// [Q2.5] Optional air void in phase-A XLPE on its +x radius. In 2D it is an
// infinitely long cylindrical gas channel parallel to the cable axis.
If (Flag_Defect == 1)
  xV = xA + rVoidPos; yV = yA;
  lcV = MeshFactor*rVoid/8;
  Point(95000) = {xV,yV,0,lcV};
  Point(95001) = {xV+rVoid,yV,0,lcV}; Point(95002) = {xV,yV+rVoid,0,lcV};
  Point(95003) = {xV-rVoid,yV,0,lcV}; Point(95004) = {xV,yV-rVoid,0,lcV};
  Circle(95011) = {95001,95000,95002}; Circle(95012) = {95002,95000,95003};
  Circle(95013) = {95003,95000,95004}; Circle(95014) = {95004,95000,95001};
  Curve Loop(95020) = {95011:95014};
  Plane Surface(95030) = {95020};
EndIf

For p In {0:2}
  pc = 1000 + 100*p;
  Point(pc) = {cx[p],cy[p],0,0.001*MeshFactor};
  For k In {0:7}
    baseP = 2000 + p*1000 + k*20;   // tag offsets only keep entity numbers unique
    baseC = 5000 + p*1000 + k*20;
    lc = MeshFactor*((k <= 5) ? 0.0006 : 0.0015);
    // 12 arcs: vertices at 0, 60, 120 ... deg = the nearest points of the neighbours
    // in both trefoil and flat formations (merged by Coherence when touching).
    For q In {0:11}
      Point(baseP+q+1) = {cx[p]+R[k]*Cos(q*Pi/6), cy[p]+R[k]*Sin(q*Pi/6), 0, lc};
    EndFor
    For q In {0:11}
      Circle(baseC+q+1) = {baseP+q+1, pc, baseP+(q+1)%12+1};
    EndFor
    Curve Loop(9000+p*100+k) = {baseC+1:baseC+12};
  EndFor
  Plane Surface(10000+p*100) = {9000+p*100};
  For k In {1:7}
    If (p == 0 && k == 2 && Flag_Defect == 1)
      Plane Surface(10000+p*100+k) = {9000+p*100+k, 9000+p*100+k-1, 95020}; // XLPE_A with void
    Else
      Plane Surface(10000+p*100+k) = {9000+p*100+k, 9000+p*100+k-1};
    EndIf
  EndFor
EndFor

// ---- Electromagnetic box [Q2.1, Q3.1]: a = 0 on its edge (group 120) ----------------------
H = OuterBox;
Point(90001) = {-H,-H,0,0.035*MeshFactor}; Point(90002) = { H,-H,0,0.035*MeshFactor};
Point(90003) = { H, H,0,0.035*MeshFactor}; Point(90004) = {-H, H,0,0.035*MeshFactor};
Line(90011) = {90001,90002}; Line(90012) = {90002,90003};
Line(90013) = {90003,90004}; Line(90014) = {90004,90001};
Curve Loop(90020) = {90011:90014};
Plane Surface(90030) = {90020, 9007, 9107, 9207};

// ---- Thermal soil region [Q4.2]: ground surface BurialDepth above the origin ------------
W = ThermalHalfWidth; yTop = BurialDepth; yBot = BurialDepth - ThermalDepth;
Point(90101) = {-W,yBot,0,1}; Point(90102) = {W,yBot,0,1};
Point(90103) = { W,yTop,0,1}; Point(90104) = {-W,yTop,0,1};
Line(90111) = {90101,90102};   // bottom (T = T_amb)
Line(90112) = {90102,90103};   // right side (zero flux)
Line(90113) = {90103,90104};   // ground surface (convection)
Line(90114) = {90104,90101};   // left side (zero flux)
Curve Loop(90120) = {90111:90114};
Plane Surface(90130) = {90120, 90020};
Coherence;

// Exact touching trefoil: the three inner jacket arcs enclose a soil pocket.
soilNear[] = {90030};
If (JacketGap == 0 && Formation == 0)
  Curve Loop(90021) = {5149,5150,7145,7146,6141,6142};
  Plane Surface(90031) = {90021};
  soilNear[] += {90031};
EndIf

// ---- Mesh sizes [Q2.3, Q3.5, Q4.3] ---------------------------------------------------------
// Field 1: 0.25 mm around the cables, 35 mm elsewhere in the EM box.
Field[1] = Box;
Field[1].XMin = Min(xA,Min(xB,xC)) - rJacket - 0.002; Field[1].XMax = Max(xA,Max(xB,xC)) + rJacket + 0.002;
Field[1].YMin = Min(yA,Min(yB,yC)) - rJacket - 0.002; Field[1].YMax = Max(yA,Max(yB,yC)) + rJacket + 0.002;
Field[1].VIn = 0.00025*MeshFactor; Field[1].VOut = 0.035*MeshFactor;
Field[1].Thickness = 0.04;
// Field 2: grows by 15 cm per metre outside the EM box (thermal soil only).
Field[2] = MathEval;
Field[2].F = Sprintf("%g*(0.035 + 0.15*(Sqrt(x*x+y*y) - %g))", MeshFactor, H);
Field[3] = Max;
Field[3].FieldsList = {1,2};
Background Field = 3;
// [Q2.5] Void: rVoid/8 at its edge, back to the cable size within a few radii.
If (Flag_Defect == 1)
  Field[4] = Ball;
  Field[4].XCenter = xV; Field[4].YCenter = yV; Field[4].ZCenter = 0;
  Field[4].Radius = 1.5*rVoid; Field[4].Thickness = 4*rVoid;
  Field[4].VIn = lcV; Field[4].VOut = 1e3;   // no constraint outside the ball
  Field[5] = Min;
  Field[5].FieldsList = {3,4};
  Background Field = 5;
EndIf

// ---- Physical groups (the tags GetDP uses) --------------------------------------------------
Physical Surface("Conductor_A", 21) = {10000};  Physical Surface("Conductor_B", 22) = {10100};
Physical Surface("Conductor_C", 23) = {10200};
Physical Surface("SemiIn_A", 31) = {10001};     Physical Surface("SemiIn_B", 32) = {10101};
Physical Surface("SemiIn_C", 33) = {10201};
Physical Surface("XLPE_A", 41) = {10002};       Physical Surface("XLPE_B", 42) = {10102};
Physical Surface("XLPE_C", 43) = {10202};
Physical Surface("SemiOut_A", 51) = {10003};    Physical Surface("SemiOut_B", 52) = {10103};
Physical Surface("SemiOut_C", 53) = {10203};
Physical Surface("FillerIn_A", 61) = {10004};   Physical Surface("FillerIn_B", 62) = {10104};
Physical Surface("FillerIn_C", 63) = {10204};
Physical Surface("CuScreen_A", 71) = {10005};   Physical Surface("CuScreen_B", 72) = {10105};
Physical Surface("CuScreen_C", 73) = {10205};
Physical Surface("FillerOut_A", 81) = {10006};  Physical Surface("FillerOut_B", 82) = {10106};
Physical Surface("FillerOut_C", 83) = {10206};
Physical Surface("PEJacket_A", 91) = {10007};   Physical Surface("PEJacket_B", 92) = {10107};
Physical Surface("PEJacket_C", 93) = {10207};
Physical Surface("SoilFar", 98) = {90130};       // thermal domain only
Physical Surface("SoilNear", 99) = {soilNear[]}; // inside the EM box
If (Flag_Defect == 1)
  Physical Surface("Void_A", 44) = {95030};
EndIf
// [Q2.1] Electric boundaries = XLPE interfaces (ideal semicons).
Physical Curve("Live_A", 101) = {5021:5032};
Physical Curve("Live_B", 102) = {6021:6032};
Physical Curve("Live_C", 103) = {7021:7032};
Physical Curve("Ground_A", 111) = {5041:5052};
Physical Curve("Ground_B", 112) = {6041:6052};
Physical Curve("Ground_C", 113) = {7041:7052};
Physical Curve("EMBoxEdge", 120) = {90011:90014};   // [Q3.1] a = 0
Physical Curve("GroundSurface", 130) = {90113};     // [Q4.2] convection
Physical Curve("Bottom", 132) = {90111};            // [Q4.2] T = T_amb
