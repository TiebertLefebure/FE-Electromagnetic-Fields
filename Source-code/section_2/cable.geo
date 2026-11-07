// Section 2: three screened phases, dimensions in metres.
// Only the dielectric/semiconducting domains are meshed. The conductor and
// continuous grounded copper screen are exact Dirichlet boundaries.
Include "settings.inc";
Mesh.MshFileVersion = 2.2;
Mesh.ElementOrder = 1;
Mesh.Algorithm = 6;
Mesh.Smoothing = 5;
Mesh.RandomFactor = 1e-9;
Mesh.MaxNumThreads2D = 1;
h = 0.001*MeshScale;
Mesh.MeshSizeMin = h/20;
Mesh.MeshSizeMax = h;

// Circle macro using four exact CAD arcs; P1 mesh approximates them by chords.
Macro CircleLoop
  center = newp; Point(center) = {cx,cy,0,lc};
  pts[] = {};
  For q In {0:3}
    pt = newp;
    Point(pt) = {cx+rad*Cos(q*Pi/2),cy+rad*Sin(q*Pi/2),0,lc};
    pts[] += {pt};
  EndFor
  arcs[] = {};
  For q In {0:3}
    arc = newl; Circle(arc) = {pts[q],center,pts[(q+1)%4]};
    arcs[] += {arc};
  EndFor
  loop = newll; Curve Loop(loop) = {arcs[]};
Return

xs[] = {0,-Spacing/2,Spacing/2};
ys[] = {Spacing/Sqrt(3),-Spacing/(2*Sqrt(3)),-Spacing/(2*Sqrt(3))};
For phase In {0:2}
  cx = xs[phase]; cy = ys[phase];
  radii[] = {R0,R1,R2,R3,R4};
  loops[] = {}; allArcs[] = {};
  For layer In {0:4}
    rad = radii[layer]; lc = h;
    Call CircleLoop;
    loops[] += {loop}; allArcs[] += {arcs[]};
  EndFor
  If (Defect && phase == 0)
    cx = xs[phase]+VoidOffset; cy = ys[phase];
    rad = VoidRadius; lc = h/12;
    Call CircleLoop;
    voidLoop = loop;
    voidSurface = news; Plane Surface(voidSurface) = {voidLoop};
    Physical Surface("Gas void A",106) = {voidSurface};
    Field[1] = Distance; Field[1].CurvesList = {arcs[]}; Field[1].Sampling = 100;
    Field[2] = Threshold; Field[2].InField = 1;
    Field[2].SizeMin = h/12; Field[2].SizeMax = h;
    Field[2].DistMin = VoidRadius; Field[2].DistMax = 0.002;
    Background Field = 2;
  EndIf
  For layer In {0:3}
    If (!IdealScreens || layer == 1)
      surface = news;
      If (Defect && phase == 0 && layer == 1)
        Plane Surface(surface) = {loops[layer+1],loops[layer],voidLoop};
      Else
        Plane Surface(surface) = {loops[layer+1],loops[layer]};
      EndIf
      Physical Surface(100*(phase+1)+layer+1) = {surface};
    EndIf
  EndFor
  inner = 0; outer = 4;
  If (IdealScreens)
    inner = 1; outer = 2;
  EndIf
  Physical Curve(1000+100*phase+1) = {allArcs[4*inner],allArcs[4*inner+1],allArcs[4*inner+2],allArcs[4*inner+3]};
  Physical Curve(1000+100*phase+2) = {allArcs[4*outer],allArcs[4*outer+1],allArcs[4*outer+2],allArcs[4*outer+3]};
EndFor
Geometry.Points = 0;
General.Axes = 0;
