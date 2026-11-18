Include "parameters.inc";
DefineConstant[
  MeshScale = {1, Name "Mesh/Scale"},
  OuterRadius = {0.5, Name "Domain/Outer radius [m]"},
  Stranded = {0, Choices{0,1}, Name "Model/Stranded phases"},
  SinglePoint = {0, Choices{0,1}, Name "Model/Single point bonding"},
  Detailed = {1, Choices{0,1}, Name "Model/Retain semiconductors"},
  Screens = {1, Choices{0,1}, Name "Model/Conducting copper screens"}
];
Mu0 = 4*Pi*1e-7;
Ipeak = Sqrt[2]*Current;
Spacing = 2*R6;
DefineConstant[PhaseArea = {Pi*R0^2, Name "Mesh/Phase area [m2]"}];
