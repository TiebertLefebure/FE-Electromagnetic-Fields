// NKT 33 kV 1x185+50 mm2 XLPE-AL, three single cores buried in soil. SI units, T in deg C.
// ALL cable, material and excitation data are ONELAB parameters (left panel in Gmsh).
// Basis tags: [DERIVED] computed from NKT data; [ASSUMPTION] our choice, defended in the slides
// (appendix, per question). Sources cited in the code (all free to open):
//  [NKT]        NKT 33 kV single core cable XLPE-AL datasheet, pp. 19-20, 185 mm2 column
//  [COURSE]     H9x34A cable assignment 2026-27, Appendices A-C
//  [NBS]        NBS Handbook 100 (copper, pp. 2-3) and 109 (aluminium, Table 1),
//               https://nvlpubs.nist.gov/nistpubs/Legacy/hb/nbshandbook100.pdf and ...109.pdf
//  [LEE]        Lee et al., Energies 16, 167 (2023), Table 3, doi:10.3390/en16010167
//  [SUCUROVIC]  Sucurovic et al., IEEE Access 14 (2026), Table 1, doi:10.1109/ACCESS.2026.3678088
//  [ENESCU]     Enescu et al., Energies 13, 5319 (2020), Table 2, doi:10.3390/en13205319
//  [OES]        APSR Oman, OES 2 Cables and Accessories, 4th ed. (2024), S4.1, pp. 20-21
//  [COMSOL]     COMSOL Application Gallery, "Submarine Cable 1 - Introduction" (v6.4), p. 28
//  [LIENHARD]   Lienhard & Lienhard, A Heat Transfer Textbook, 6th ed. (2024), https://ahtt.mit.edu/
//  [VSSUT], [Bean]: Section 2 file; [KTH], [UNCC], [Karlstrand]: Section 3 and 4 files.
// Search a question tag (Q1.4, Q4.2, ...) to find where a value is used.
DefineConstant[
  // ---- Excitation [Q1.4] ---------------------------------------------------------
  U_LL  = {33000, Name "Cable/01 Line-line RMS voltage [V]"},          // [NKT]
  I_RMS = {350,   Name "Cable/02 Phase RMS current [A]"},              // [NKT] trefoil rating
  Freq  = {50,    Name "Cable/03 Frequency [Hz]"},                     // [NKT]

  // ---- Mesh and electromagnetic box [Q2.3, Q3.5, Q4.3] ---------------------------
  MeshFactor = {1, Min 0.3, Max 3, Step 0.1, Name "Mesh/01 Mesh factor (smaller = finer)"},
  OuterBox = {0.3, Name "Geometry/01 Electromagnetic half-box [m]"},   // [ASSUMPTION] a = 0 here

  // ---- Arrangement [Q1.1, Section 5] ----------------------------------------------
  // 0 = trefoil (datasheet rating), 1 = flat (A, B, C from left to right).
  Formation = {0, Choices{0="Trefoil", 1="Flat"}, Name "Geometry/02 Formation"},
  // [ASSUMPTION] 0.5 mm soil between jackets (TA advice: no zero-angle soil wedges).
  // 0 = exact touching (trefoil only); 70 = NKT "flat, free distance S = D + 70 mm".
  JacketGap = {0.5, Name "Geometry/03 Jacket gap [mm]"},

  // ---- Insulation defect [Q2.5] ------------------------------------------------------
  Flag_Defect = {0, Choices{0="Healthy", 1="Air void in phase A"}, Name "Geometry/04 Insulation defect"},
  rVoid    = {0.00025, Name "Geometry/05 Void radius [m]"},                       // [ASSUMPTION]
  rVoidPos = {0.0088,  Name "Geometry/06 Void centre distance from phase-A axis [m]"}, // [ASSUMPTION]

  // ---- Radial construction [Q1.1] ---------------------------------------------------
  rCon     = {0.0074, Name "Geometry/10 Conductor radius [m]"},                   // [NKT] 14.8 mm diameter
  // [DERIVED] NKT "over insulation" 32.4 mm = 14.8 + 2 x 8.0 + 2 x 0.8: 0.4 mm per semicon,
  // assuming both semicons are included in that diameter.
  tSemiIn  = {0.0004, Name "Geometry/11 Inner semicon thickness [m]"},
  tXLPE    = {0.0080, Name "Geometry/12 XLPE thickness [m]"},                     // [NKT]; Q2.8: tXLPE = 0.0090 m
  tSemiOut = {0.0004, Name "Geometry/13 Outer semicon thickness [m]"},
  // [ASSUMPTION] Cu ring placed midway in the 3 mm screen layer (16.2 to 19.2 mm).
  rWireIn  = {0.0174, Name "Geometry/14 Cu ring inner radius [m] (ASSUMPTION)"},
  AWire    = {50e-6,  Name "Geometry/15 Cu screen cross-section [m2]"},          // [NKT]
  rScreenOuter = {0.0192, Name "Geometry/16 Over-screen radius [m]"},             // [NKT] 38.4 mm diameter
  rJacket  = {0.0215, Name "Geometry/17 Outer radius [m]"},                       // [NKT] 43 mm diameter

  // ---- Datasheet values, used as references in the printed comparisons [NKT] -------------
  RdcNKT   = {0.164, Name "Datasheet/1 Max. DC resistance at 20 C [Ohm per km]"},
  CmaxNKT  = {0.22,  Name "Datasheet/2 Max. capacitance [uF per km]"},
  XNKT     = {0.12,  Name "Datasheet/3 Reactance, touching trefoil [Ohm per km]"},
  TadmNKT  = {90,    Name "Datasheet/4 Max. conductor temperature [deg C]"},
  // Ampacity in ground, 15 C, 1 m, 1.2 K m/W: both ends bonded / single point bonded.
  IampTrefoil    = {350, Name "Datasheet/5 Ampacity, trefoil touching [A]"},
  IampTrefoilSP  = {350, Name "Datasheet/6 Ampacity, trefoil touching, single point [A]"},
  IampFlat       = {350, Name "Datasheet/7 Ampacity, flat touching [A]"},
  IampFlatSP     = {350, Name "Datasheet/8 Ampacity, flat touching, single point [A]"},
  IampFlat70     = {365, Name "Datasheet/9 Ampacity, flat 70 mm apart [A]"},
  IampFlat70SP   = {380, Name "Datasheet/10 Ampacity, flat 70 mm apart, single point [A]"},

  // ---- Electromagnetic materials [Q1.1, Q2.1, Q3.1] -----------------------------------
  epsXLPE   = {2.5,   Name "Materials/01 XLPE relative permittivity"},           // [SUCUROVIC, LEE]
  sigmaXLPE = {1e-18, Name "Materials/02 XLPE conductivity", Units "S/m"},        // [COURSE]
  // [DERIVED] Fitted so that 1/(sigma*pi*rCon^2) = 0.164 Ohm/km, the NKT DC maximum at 20 C
  // (3.544e7 S/m; 61 % IACS aluminium [NBS] gives 3.538e7: 0.2 % apart).
  sigmaAl = {1000/(RdcNKT*Pi*rCon^2), Name "Materials/03 Al conductivity at 20 C", Units "S/m"},
  // [NBS] Annealed copper (IACS), rho = 1.7241e-8 Ohm m at 20 C (NBS Handbook 100, p. 2).
  sigmaCu = {1/1.7241e-8, Name "Materials/04 Cu conductivity at 20 C", Units "S/m"},
  muR     = {1,      Name "Materials/05 Relative permeability (all regions)"},    // no steel
  epsVoid   = {1.0,   Name "Materials/06 Void relative permittivity (air)"},
  sigmaVoid = {1e-15, Name "Materials/07 Void conductivity (dry air)", Units "S/m"},
  pVoid     = {101.325, Name "Materials/12 Void gas pressure (air, 1 bar)", Units "kPa"},   // [ASSUMPTION]
  // [COURSE eq. 12] sigma(T) = sigma0 / (1 + alpha (T - 20 C)).
  alphaAl = {0.00390, Name "Materials/08 Al temperature coefficient", Units "1/K"},
  alphaCu = {0.00386, Name "Materials/09 Cu temperature coefficient", Units "1/K"},
  tanDelta = {4e-3, Name "Materials/10 XLPE loss tangent"},                     // [SUCUROVIC] 19/33 kV
  // [OES] insulation-screen resistivity limit 500 Ohm m; only used for the drop across the
  // semicons (Q2.2), which are ideal electrodes in the electric model.
  sigmaSemi = {2e-3, Name "Materials/11 Semicon conductivity", Units "S/m"},
  // [COURSE App. C, COMSOL] PE jacket and soil. Not inside any solved domain: the electric model
  // stops at the grounded screens and the magnetic model sets sigma = 0 outside the metals
  // (justified by the printed soil skin depth, Q1.2, Q3.1).
  epsPE     = {2.25,  Name "Materials/13 PE relative permittivity"},
  sigmaPE   = {1e-18, Name "Materials/14 PE conductivity", Units "S/m"},
  epsSoil   = {10,    Name "Materials/15 Soil relative permittivity"},
  sigmaSoil = {1e-2,  Name "Materials/16 Soil conductivity", Units "S/m"},

  // ---- Thermal data [Q1.1, Q1.2, Q4.2] -------------------------------------------------
  T_amb = {15, Name "Thermal/01 Ambient (air and deep soil) temperature [deg C]"}, // [NKT]
  BurialDepth = {1.0, Name "Thermal/02 Burial depth of trefoil centre [m]"},        // [NKT]
  kSoil = {1/1.2, Name "Thermal/03 Soil thermal conductivity", Units "W/(m K)"},    // [NKT] 1.2 K m/W
  // [ASSUMPTION] bare ground in still air: natural convection ~2 + radiation 4 e s T^3 ~5
  // (e = 0.95, T = 288 K), raised for wind; 5 to 20 and isothermal studied in Q4.5.
  hConv = {10, Name "Thermal/04 Surface heat transfer coefficient", Units "W/(m2 K)"},
  // [LIENHARD] emissivity of bare ground, used only to justify the radiation part of hConv.
  eGround = {0.95, Name "Thermal/07 Ground surface emissivity"},
  // [ASSUMPTION] lateral (zero flux) and bottom (T = T_amb) boundaries 20 m away: Q4.3
  // shows T_max changes by about 0.1 K from 20 m to 40 m (and -0.3 K at 10 m).
  ThermalHalfWidth = {20, Name "Thermal/05 Thermal domain half-width [m]"},
  ThermalDepth     = {20, Name "Thermal/06 Thermal domain depth below surface [m]"},
  kAl  = {237, Name "Thermal/10 Al thermal conductivity", Units "W/(m K)"},          // [LEE]
  kCu  = {402, Name "Thermal/11 Cu thermal conductivity", Units "W/(m K)"},          // [LEE]
  // [ENESCU, SUCUROVIC] rho = 3.5 K m/W for XLPE and PE (IEC 60287 value). Semicons and the
  // equivalent fillers are polymer compounds/tapes: [ASSUMPTION] same value.
  kPoly = {1/3.5, Name "Thermal/12 XLPE, PE, semicon, filler conductivity", Units "W/(m K)"}
];

// ---- Derived radii [Q1.1, Q2.2] --------------------------------------------------------
rSemiIn  = rCon + tSemiIn;          // 7.8 mm, inner XLPE interface (conductor screen)
rXLPEOut = rSemiIn + tXLPE;         // 15.8 mm, outer XLPE interface (core screen)
rSemiOut = rXLPEOut + tSemiOut;     // 16.2 mm
rWireOut = Sqrt[rWireIn^2 + AWire/Pi]; // Cu ring with the 50 mm2 area of the wires + tape

// ---- Cable centres [Q1.1, Section 5] ----------------------------------------------------
// Origin = centre of the arrangement (trefoil centroid), BurialDepth below the surface.
Spacing = 2*rJacket + JacketGap*0.001;   // centre-to-centre distance
If (Formation == 0)
  triHeight = Sqrt[3]/2*Spacing;
  xA = 0;          yA = 2*triHeight/3;
  xB = -Spacing/2; yB = -triHeight/3;
  xC = Spacing/2;  yC = -triHeight/3;
Else
  xA = -Spacing; yA = 0;
  xB = 0;        yB = 0;
  xC = Spacing;  yC = 0;
EndIf

// ---- Excitation as peak phasors [Q1.4] ---------------------------------------------------
Vpeak = Sqrt[2]*U_LL/Sqrt[3];   // 26944 V phase-to-ground
Ipeak = Sqrt[2]*I_RMS;          // 494.97 A
eps0 = 8.854187817e-12;
mu0 = 4*Pi*1e-7;
// [Q1.3] Screens bonded at both ends (rating row): 3-Magnetoquasistatic-analysis/cable.pro,
// Flag_Bonding = 0 (U = 0 per screen); single-point bonding is Flag_Bonding = 1 (I = 0).
