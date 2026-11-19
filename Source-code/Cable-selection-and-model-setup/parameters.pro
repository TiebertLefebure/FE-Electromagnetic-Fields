// NKT 33 kV 185+50 mm2 cable. SI units throughout.
// Section 1: this file records the inputs and assumptions; it does not solve a field.
// Search for a question number (e.g. Q1.4) to find the relevant constants.
// Sources: [NKT] local datasheet, printed pp.19-20, 185 mm2 column;
// [COURSE] NMES Assignment 2026, Appendix A;
// [CHIPP] R. Chippendale, Parameters for extra large cables (2016), Tables 3-4;
// [COMSOL] Submarine Cable 8: Inductive Effects 3D, material definitions;
// [LEE] Lee et al., Energies 16(1), 167 (2023), Table 3.
// ONELAB uses slashes in Name to create folders. Put units with a slash in Units.
DefineConstant[
  // [Q1.1, Q1.4] Cable rating and excitation: line-line RMS voltage and phase RMS current.
  // [NKT] Line-to-line RMS voltage and both-end-bonded, buried-trefoil rating.
  U_LL = {33000, Name "Cable/01 Line-line RMS voltage [V]"},
  I_RMS = {350, Name "Cable/02 Phase RMS current [A]"},
  // [Q1.4] Study frequency. [Q2.7] Override Freq for the electric frequency check.
  // [COURSE] Time-harmonic study frequency; phasors below are peak values.
  Freq = {50, Name "Cable/03 Frequency [Hz]"},
  // [Q2.3] Mesh convergence: use MeshFactor = 2, 1, 0.5 and remesh each time.
  // [Q3.5] The same input can later be used for magnetic mesh convergence.
  // [NUMERICAL] Multiplies mesh sizes; 1 gives a 0.25 mm target near the cables.
  MeshFactor = {1, Min 0.3, Max 3, Step 0.1, Name "Mesh/01 Mesh factor (smaller = finer)"},
  // [Q1.2] Local exterior geometry; the ground surface is not represented.
  // [MODEL] Half-width of the computational box, not the burial depth.
  OuterBox = {0.3, Name "Geometry/01 Electromagnetic half-box [m]"},
  // [Q1.1, Q2.2, Q3.4 - ASSUMPTION] Following TA feedback, leave 0.5 mm of
  // soil between each pair of jackets to avoid the narrow soil tips at contact.
  // Use 0 mm for the datasheet's touching trefoil. The jacket radius stays fixed.
  JacketGap = {0.5, Choices{0.5, 0}, Name "Geometry/02 Jacket gap [mm]"},
  // [Q1.1, Q1.2] Soil conditions for the chosen buried-trefoil rating.
  // [NKT] Rating conditions; these are not thermal boundary conditions yet.
  T_amb = {15, Name "Thermal/01 Soil temperature [deg C]"},
  SoilK = {1/1.2, Name "Thermal/02 Soil thermal conductivity", Units "W/(m K)"},
  // [Q1.1] Radial construction: manufacturer dimensions and assumed screens.
  // [NKT] 14.8 mm conductor diameter and 8 mm XLPE thickness.
  rCon = {0.0074, Name "Geometry/10 Conductor radius [m]"},
  // [ASSUMPTION] Jaswanth's 0.4 mm screens; NKT does not specify them.
  tSemiIn = {0.0004, Name "Geometry/11 Inner semiconductor thickness [m] (ASSUMPTION)"},
  // [Q2.8] Design trial: override tXLPE = 0.009 in BOTH Gmsh and GetDP.
  // This uses some assumed filler space; copper and outside radii stay fixed.
  tXLPE = {0.0080, Name "Geometry/12 XLPE thickness [m]"},
  tSemiOut = {0.0004, Name "Geometry/13 Outer semiconductor thickness [m] (ASSUMPTION)"},
  // [ASSUMPTION] Radial position of the equivalent copper ring, not OEM wire data.
  rWireIn = {0.0174, Name "Geometry/14 Equivalent wire ring inner radius [m] (ASSUMPTION)"},
  // [NKT] Copper area and nominal diameters over screen (38.4) and jacket (43) mm.
  AWire = {50e-6, Name "Geometry/15 Copper wire screen cross-section [m2]"},
  rScreenOuter = {0.0192, Name "Geometry/16 Over screen radius [m]"},
  rJacket = {0.0215, Name "Geometry/17 Nominal outer radius [m]"},
  // [Q1.1] Material sources. [Q2.6] sigma versus omega*epsilon sets the current ratio.
  // [Q2.7] Constant permittivity is an assumption of the capacitance/frequency check.
  // [CHIPP, COMSOL] Borrowed constant XLPE properties, not an NKT compound test.
  // No dielectric loss tangent or discharge model is included.
  epsXLPE = {2.5, Name "Materials/01 XLPE relative permittivity (REFERENCE)"},
  sigmaXLPE = {1e-18, Name "Materials/02 XLPE conductivity", Units "S/m"},
  // [Q1.1] Effective aluminium conductivity from the listed diameter and DC resistance.
  // [Q3.2, Q3.9] Inputs for later skin-depth and resistance checks, not magnetic results.
  // [DERIVED, NKT] Match R = length/(sigma*area) to the maximum DC resistance
  // 0.164 ohm/km at 20 C, keeping the listed conductor diameter.
  // Metal conductivities are not used by the current XLPE-only electric solve.
  sigmaAl = {1000/(0.164*Pi*rCon^2), Name "Materials/03 Al conductivity", Units "S/m"},
  sigmaCu = {5.95e7, Name "Materials/04 Cu conductivity", Units "S/m"}
];

// [Q1.1, Q2.2] Screen thicknesses determine the actual XLPE interface radii.
rSemiIn = rCon + tSemiIn;        // [DERIVED] 7.8 mm, inner XLPE interface.
rXLPEOut = rSemiIn + tXLPE;     // [DERIVED] 15.8 mm, outer XLPE interface.
rSemiOut = rXLPEOut + tSemiOut; // [DERIVED] 16.2 mm.
// [Q1.1] Equivalent copper annulus. [Q3.4] Its magnetic loss error is not yet checked.
// [MODEL] A smooth ring preserves copper area but omits wire/tape lay and gaps.
rWireOut = Sqrt[rWireIn*rWireIn + AWire/Pi];
// [MODEL] Filler regions close the published envelopes; their composition is
// unspecified. They are meshed but not solved in the current electric model.
// The effective jacket is 2.3 mm; NKT lists a nominal 2.2 mm sheath.

// [Q1.1, Q1.2] Arrangement and local coordinates of the three cable centres.
// [MODEL] Equilateral trefoil, centred at the origin. Convert the gap to metres.
// The centre spacing is 43.5 mm with the gap or 43.0 mm at exact contact.
Diameter = 2*rJacket;
Spacing = Diameter + JacketGap*0.001;
triHeight = Sqrt[3]/2*Spacing;
xA = 0;           yA = 2*triHeight/3;
xB = -Spacing/2;  yB = -triHeight/3;
xC = Spacing/2;   yC = -triHeight/3;
// [Q1.4] Excitation conversion: Vpeak = 26944.4 V, Ipeak = 494.975 A.
// [COURSE] Convert line-to-line RMS voltage to phase-to-ground peak voltage.
Vpeak = Sqrt[2]*U_LL/Sqrt[3];
Ipeak = Sqrt[2]*I_RMS;
eps0 = 8.854187817e-12;
// [Q1.3] Bonding choice recorded here. [Q3.3] Axial circuit constraints remain to be added.
// [ASSUMPTION FOR SECTION 3] Both ends of each screen are bonded to common
// earth with ideal leads. Axial bonding/current constraints are not implemented
// by the electric grounding condition; they belong to the magnetic model.
