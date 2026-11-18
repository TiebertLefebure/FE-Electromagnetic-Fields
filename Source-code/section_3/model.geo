// Full trefoil cross-section, in metres. Linear triangles.
Include "settings.inc";
Mesh.MshFileVersion = 2.2;
Mesh.ElementOrder = 1;
Mesh.Algorithm = 6;
Mesh.MaxNumThreads2D = 1;
Mesh.MeshSizeMax = OuterRadius/5*MeshScale;
Mesh.Smoothing = 5;

Macro CircleLoop
  cp = newp; Point(cp) = {cx,cy,0,lc};
  points[] = {}; arcs[] = {};
  For q In {0:11}
    p = newp; Point(p) = {cx+rad*Cos(q*Pi/6),cy+rad*Sin(q*Pi/6),0,lc};
    points[] += {p};
  EndFor
  For q In {0:11}
    c = newl; Circle(c) = {points[q],cp,points[(q+1)%12]};
    arcs[] += {c};
  EndFor
  loop = newll; Curve Loop(loop) = {arcs[]};
Return

xs[] = {0,-Spacing/2,Spacing/2};
ys[] = {Spacing/Sqrt(3),-Spacing/(2*Sqrt(3)),-Spacing/(2*Sqrt(3))};
jackets[] = {}; jacketArcs[] = {};
For phase In {0:2}
  cx = xs[phase]; cy = ys[phase];
  radii[] = {R0,R1,R2,R3,R4,R5,R6};
  loops[] = {};
  For layer In {0:6}
    If (Detailed || layer == 0 || layer >= 4)
      rad = radii[layer]; lc = 0.0015*MeshScale;
      If (layer == 4 || layer == 5)
        lc = 0.0006*MeshScale;
      EndIf
      Call CircleLoop;
      loops[] += {loop};
      If (layer == 6)
        jacketArcs[] += {arcs[]};
      EndIf
    EndIf
  EndFor
  s = news; Plane Surface(s) = {loops[0]};
  Physical Surface(100*(phase+1)) = {s};
  For layer In {1:#loops[]-1}
    s = news; Plane Surface(s) = {loops[layer],loops[layer-1]};
    tag = layer;
    If (!Detailed)
      If (layer == 1)
        tag = 2;
      Else
        tag = layer+3;
      EndIf
    EndIf
    Physical Surface(100*(phase+1)+tag) = {s};
  EndFor
  jackets[] += {loops[#loops[]-1]};
EndFor
cx = 0; cy = 0; rad = OuterRadius; lc = OuterRadius/8*MeshScale;
Call CircleLoop;
s = news; Plane Surface(s) = {loop,jackets[]};
// The three touching jackets enclose a separate soil pocket.
Coherence;
pocketLoop = newll;
Curve Loop(pocketLoop) = {jacketArcs[8],jacketArcs[9],jacketArcs[28],jacketArcs[29],jacketArcs[12],jacketArcs[13]};
pocket = news; Plane Surface(pocket) = {pocketLoop};
Physical Surface("Soil",900) = {s,pocket};
Physical Curve("Far boundary",901) = {arcs[]};
Coherence;
Geometry.Points = 0;
