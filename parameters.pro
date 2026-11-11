// NKT 33 kV 1x185+50 mm2 XLPE-AL: three single-core cables in trefoil.
// SI units throughout: m, V, A, Hz, S/m, F/m.
// Values labelled ASSUMPTION are NOT specified in the NKT datasheet.
DefineConstant[
  U_LL = {33000, Name "Cable/01 Line-line RMS voltage [V]"},
  I_RMS = {350, Name "Cable/02 Phase RMS current [A]"},
  Freq = {50, Name "Cable/03 Frequency [Hz]"},
  MeshFactor = {1, Min 0.3, Max 3, Step 0.1, Name "Mesh/01 Mesh factor (smaller = finer)"},
  OuterBox = {0.3, Name "Geometry/01 Electromagnetic half-box [m]"},
  Diameter = {0.043, Name "Geometry/02 Cable outer diameter [m]"},
  T_amb = {15, Name "Thermal/01 Soil temperature [deg C]"},
  SoilK = {1/1.2, Name "Thermal/02 Soil thermal conductivity [W/(m K)]"},
  // NKT dimensions: conductor 14.8 mm; XLPE 8 mm;
  // diameter over insulation 32.4 mm; over wire screen 38.4 mm;
  // nominal diameter over sheath 43.0 mm.
  rCon = {0.0074, Name "Geometry/10 Conductor radius [m]"},
  tSemiIn = {0.0004, Name "Geometry/11 Inner semiconductor thickness [m] (ASSUMPTION)"},
  tXLPE = {0.0080, Name "Geometry/12 XLPE thickness [m]"},
  tSemiOut = {0.0004, Name "Geometry/13 Outer semiconductor thickness [m] (ASSUMPTION)"},
  rWireIn = {0.0174, Name "Geometry/14 Equivalent wire ring inner radius [m] (ASSUMPTION)"},
  AWire = {50e-6, Name "Geometry/15 Copper wire screen cross-section [m2]"},
  rScreenOuter = {0.0192, Name "Geometry/16 Over screen radius [m]"},
  rJacket = {0.0215, Name "Geometry/17 Nominal outer radius [m]"},
  epsXLPE = {2.5, Name "Materials/01 XLPE relative permittivity (ASSUMPTION)"},
  sigmaXLPE = {1e-18, Name "Materials/02 XLPE conductivity [S/m] (ASSUMPTION)"},
  sigmaAl = {3.77e7, Name "Materials/03 Al conductivity [S/m] (REFERENCE)"},
  sigmaCu = {5.99e7, Name "Materials/04 Cu conductivity [S/m] (REFERENCE)"}
];

// Derived radii. 0.4 mm + 8 mm + 0.4 mm makes 16.2 mm over insulation.
rSemiIn = rCon + tSemiIn;       // 7.8 mm
rXLPEOut = rSemiIn + tXLPE;    // 15.8 mm
rSemiOut = rXLPEOut + tSemiOut;// 16.2 mm
rWireOut = Sqrt[rWireIn*rWireIn + AWire/Pi];

// Trefoil: centre-to-centre spacing equal to nominal outside diameter.
triHeight = Sqrt[3]/2*Diameter;
xA = 0;           yA = 2*triHeight/3;
xB = -Diameter/2; yB = -triHeight/3;
xC = Diameter/2;  yC = -triHeight/3;
Vpeak = Sqrt[2]*U_LL/Sqrt[3];
Ipeak = Sqrt[2]*I_RMS;
eps0 = 8.854187817e-12;
