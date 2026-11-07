// Shared by Gmsh and GetDP. Parameters can be overridden with -setnumber.
Include "parameters.inc";
DefineConstant[
  MeshScale = {1, Min 0.125, Max 4, Name "Model/Mesh size multiplier"},
  IdealScreens = {0, Choices{0,1}, Name "Model/Ideal semiconductor screens"},
  Defect = {0, Choices{0,1}, Name "Model/Gas void in phase A"},
  ExtraXLPE = {0, Min 0, Max 0.004, Name "Model/Additional XLPE thickness [m]"},
  Freq = {50, Min 1, Name "Model/Frequency [Hz]"}
];
R2 = R2base + ExtraXLPE;
R3 = R3base + ExtraXLPE;
R4 = R4base + ExtraXLPE;
Spacing = CableDiameter + 2*ExtraXLPE;
// Defect: 0.5 mm diameter axial gas channel, entirely within phase A XLPE.
VoidRadius = 0.00025;
VoidOffset = R1 + 0.001;
