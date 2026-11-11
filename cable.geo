// Three NKT 33 kV 1x185+50 mm2 single-core cables: trefoil.
// Mesh and physical entities; all lengths are in METRES.
// This Gmsh 'Built-in' geometry shares all interfaces exactly.
Include "parameters.pro";
SetFactory("Built-in");
Mesh.Algorithm = 6;
Mesh.CharacteristicLengthFromPoints = 1;
Mesh.CharacteristicLengthExtendFromBoundary = 0;
Mesh.SaveAll = 0;

cx[] = {xA,xB,xC};
cy[] = {yA,yB,yC};
R[]  = {rCon,rSemiIn,rXLPEOut,rSemiOut,rWireIn,rWireOut,rScreenOuter,rJacket};

// Eight concentric circles (4 circular arcs each) around each phase.
// Region indices: 0 conductor, 1 inner semicon, 2 XLPE,
// 3 outer semicon, 4 inner PE/filler, 5 equivalent copper screen,
// 6 outer PE/filler, 7 protective outer PE sheath.
For p In {0:2}
  pc = 1000 + 100*p;
  Point(pc) = {cx[p],cy[p],0,0.001*MeshFactor};
  For k In {0:7}
    baseP = 2000 + p*1000 + k*10;
    baseC = 5000 + p*1000 + k*10;
    rr = R[k];
    lc = MeshFactor * ((k==0 || k==1 || k==2 || k==3 || k==4 || k==5) ? 0.0006 : 0.0015);
    Point(baseP+1) = {cx[p]+rr,cy[p],0,lc};
    Point(baseP+2) = {cx[p],cy[p]+rr,0,lc};
    Point(baseP+3) = {cx[p]-rr,cy[p],0,lc};
    Point(baseP+4) = {cx[p],cy[p]-rr,0,lc};
    Circle(baseC+1) = {baseP+1,pc,baseP+2};
    Circle(baseC+2) = {baseP+2,pc,baseP+3};
    Circle(baseC+3) = {baseP+3,pc,baseP+4};
    Circle(baseC+4) = {baseP+4,pc,baseP+1};
    Curve Loop(9000+p*100+k) = {baseC+1,baseC+2,baseC+3,baseC+4};
  EndFor
  Plane Surface(10000+p*100) = {9000+p*100};
  For k In {1:7}
    Plane Surface(10000+p*100+k) = {9000+p*100+k,9000+p*100+k-1};
  EndFor
EndFor

// Outer background: nonconducting exterior for later magnetic study.
// Electric study solves XLPE only, because the semicon screens are equipotentials.
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

// Physical SURFACES: GetDP identifies these numbers, not visual colours.
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
Physical Surface("Exterior", 99) = {90030};

// Physical CURVES: electrical Dirichlet boundaries at interfaces of XLPE.
Physical Curve("Live_A", 101) = {5011,5012,5013,5014};
Physical Curve("Live_B", 102) = {6011,6012,6013,6014};
Physical Curve("Live_C", 103) = {7011,7012,7013,7014};
Physical Curve("GroundedScreens", 110) = {
  5021,5022,5023,5024,6021,6022,6023,6024,7021,7022,7023,7024
};
Physical Curve("OuterBoundary", 120) = {90011,90012,90013,90014};
