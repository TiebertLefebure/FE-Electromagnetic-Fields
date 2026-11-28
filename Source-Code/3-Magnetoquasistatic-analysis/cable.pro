// Section 3: magnetoquasistatic a-v model of the three cables, conductivities at 20 C.
// Course files, included unchanged: Jacobian_Integration.pro (Jacobians, Gauss rules) and
// magnetodynamic_formulation.pro (function spaces, weak form Magnetodynamic_a_2D, post-processing
// quantities). This file defines the cable problem, its outputs and the analytical and IEC 60287
// references it is compared with (results/<case>/references.txt).
// Sections 4 and 5 include this file (with Flag_Coupled = 1) and add the heat equation.
// Search a question tag (Q3.1 ... Q3.11) to find the block that answers it.
Include "../1-Cable-selection-and-model-setup/parameters.pro";
DefineConstant[
  Flag_Coupled = 0,   // 1 when Section 4 or 5 includes this file (not a ONELAB parameter)
  ResultDir = {"res", Name "Output/Directory"},
  // [Q3.2] 0: massive Al (net current imposed, eddy currents free); 1: uniform J = I/A.
  Flag_Conductor = {0, Choices{0="Massive (solid Al)", 1="Stranded (uniform J)"},
    Name "Magnetic/01 Conductor model"},
  // [Q1.3, Q3.3] 0: both ends bonded, U = 0 per screen; 1: single point, I = 0.
  Flag_Bonding = {0, Choices{0="Both ends (U=0)", 1="Single point (I=0)"},
    Name "Magnetic/02 Screen bonding"}
];
If (!Flag_Coupled)
  SetString["GetDP/1ResolutionChoices", "Magnetodynamics_cable"];
  SetString["GetDP/9ComputeCommand", "-solve"];
EndIf

// [Q3.1] Domain: the EM box (cables + near soil, a = 0 on its edge).
Group {
  CondA = Region[21]; CondB = Region[22]; CondC = Region[23];
  ScreenA = Region[71]; ScreenB = Region[72]; ScreenC = Region[73];
  Conductors = Region[{CondA, CondB, CondC}];
  Screens = Region[{ScreenA, ScreenB, ScreenC}];
  Metals = Region[{Conductors, Screens}];
  // Semicons (2e-3 S/m), XLPE, void, fillers, PE: no eddy currents, polymer kappa.
  Insulation = Region[{31,32,33, 41,42,43,44, 51,52,53, 61,62,63, 81,82,83, 91,92,93}];
  SoilNear = Region[99];  // soil skin depth AnaDeltaSoil (printed) >> box: sigma = 0 in the magnetic model
  Domain_Mag = Region[{Metals, Insulation, SoilNear}];
  If (Flag_Conductor == 0)
    DomainC_Mag = Region[{Metals}];       // massive: j = -sigma(j w a + ur)
    DomainS0_Mag = Region[{}];
  Else
    DomainC_Mag = Region[{Screens}];
    DomainS0_Mag = Region[{Conductors}];  // stranded: j = js0 imposed
  EndIf
  EMBoxEdge = Region[120];
}

Function {
  nu[] = 1/(muR*mu0);
  // [Q4.7, course eq. 12] sigma(T) = sigma_20 / (1 + alpha (T - 20)). Here T = 20 C; Section 4
  // defines Tmetal[] as the computed metal temperature.
  If (Flag_Coupled)
    DefineFunction[ Tmetal ];
  Else
    Tmetal[] = 20;
  EndIf
  sigma[Conductors] = sigmaAl/(1 + alphaAl*(Tmetal[] - 20));
  sigma[Screens]    = sigmaCu/(1 + alphaCu*(Tmetal[] - 20));
  // [Q3.2] Stranded model: js = I_k/A_k along z with the ABC phase angles.
  AreaCon = Pi*rCon^2;
  js0[CondA] = Vector[0,0,1] * Ipeak/AreaCon * Complex[1, 0];
  js0[CondB] = Vector[0,0,1] * Ipeak/AreaCon * Complex[Cos[-2*Pi/3], Sin[-2*Pi/3]];
  js0[CondC] = Vector[0,0,1] * Ipeak/AreaCon * Complex[Cos[ 2*Pi/3], Sin[ 2*Pi/3]];
}

Constraint {
  // [Q3.1] a = 0 on the EM box edge: balanced currents, field decays like 1/r^2.
  { Name MagneticVectorPotential_2D; Case { { Region EMBoxEdge; Value 0; } } }
  // [Q1.4, Q3.1] Net phase currents in massive conductors. [Q3.3] Single point: I = 0.
  { Name Current_2D; Case {
      If (Flag_Conductor == 0)
        { Region CondA; Value Complex[Ipeak, 0]; }
        { Region CondB; Value Complex[Ipeak*Cos[-2*Pi/3], Ipeak*Sin[-2*Pi/3]]; }
        { Region CondC; Value Complex[Ipeak*Cos[ 2*Pi/3], Ipeak*Sin[ 2*Pi/3]]; }
      EndIf
      If (Flag_Bonding == 1)
        { Region Screens; Value 0; }
      EndIf
  } }
  // [Q3.3] Both ends bonded (ideal earth leads): zero voltage per unit length.
  { Name Voltage_2D; Case {
      If (Flag_Bonding == 0)
        { Region Screens; Value 0; }
      EndIf
  } }
}

// Names the course file needs. Every massive region has a global current I; there are no
// stranded regions with turns (DomainS_Mag, Ns, Sc) and no steel. Its own resolution
// (Magnetodynamics) and post-operations (Mag_Maps, Mag_Global) are written for the course
// example cable and are not used here: its JouleLosses leaves out ur.
Flag_Degree_a = 1;                       // first-order nodal elements
Group {
  DomainCWithI_Mag = Region[{DomainC_Mag}]; DomainS_Mag = Region[{}];
  Inds = Region[{Conductors}]; APLSheath = Region[{Screens}]; Steel = Region[{}]; Ind_1 = Region[{CondA}];
}
Function { DefineFunction[ Ns, Sc ]; }

Include "../1-Cable-selection-and-model-setup/Jacobian_Integration.pro";
Include "magnetodynamic_formulation.pro";

// ---- Analytical and IEC 60287 references at 20 C, printed by the resolution -----------------
w = 2*Pi*Freq;
AnaDeltaAl = Sqrt[2/(w*mu0*sigmaAl)]*1e3;                // [Q3.2] skin depths, mm
AnaDeltaCu = Sqrt[2/(w*mu0*sigmaCu)]*1e3;
AnaDeltaSoil = Sqrt[2/(w*mu0*sigmaSoil)];                // [Q1.2, Q3.1] soil skin depth, m
AnaL = 2e-7*Log[Spacing/(rCon*Exp[-0.25])]*1e6;        // [Q3.10] bare trefoil, no screen currents, mH/km
NktL = XNKT/w*1e3;                                       // [Q3.10] L from the NKT reactance, mH/km
AnaBsingle = mu0*Ipeak/(2*Pi*rCon)*1e3;                  // [Q3.6] |B| at the surface of one cable, mT
AnaJavg = Ipeak/(Pi*rCon^2)/1e6;                         // [Q3.7] mean |J|, A/mm2 peak
// [Q3.8, Q3.9] IEC 60287 method at 20 C, equations as printed in [KTH] Lindstrom (2011),
// eqs. 4.6-4.14: skin (y_s) and proximity (y_p) factors, screen reactance X and loss factor.
// [KTH] L. Lindstrom, MSc thesis, KTH (2011),
//   https://www.diva-portal.org/smash/get/diva2:511556/fulltext01.pdf
R20 = RdcNKT*1e-3;                                       // ohm/m
xs4 = (8*Pi*Freq/R20*1e-7)^2;  Fs = xs4/(192 + 0.8*xs4);
IecYs = Fs;
IecYp = Fs*(2*rCon/Spacing)^2*(0.312*(2*rCon/Spacing)^2 + 1.18/(Fs + 0.27));
IecRcond = R20*(1 + IecYs + IecYp);                      // conductor AC resistance, ohm/m
IecRs = 1/(sigmaCu*AWire);                               // screen resistance, ohm/m
IecX = 2*w*1e-7*Log[2*Spacing/(rWireIn + rWireOut)];     // screen reactance, ohm/m
IecLam = IecRs/IecRcond/(1 + (IecRs/IecX)^2);            // screen loss factor lambda_1
IecIs = I_RMS*IecX/Sqrt[IecRs^2 + IecX^2];               // circulating screen current, A
IecPc = 3*I_RMS^2*IecRcond;  IecPs = IecPc*IecLam;       // W/m = kW/km

Resolution {
  { Name Magnetodynamics_cable;
    System { { Name Sys_Mag; NameOfFormulation Magnetodynamic_a_2D; Type Complex; Frequency Freq; } }
    Operation {
      CreateDir[ResultDir]; DeleteFile[StrCat[ResultDir,"/references.txt"]];
      Generate[Sys_Mag]; Solve[Sys_Mag]; SaveSolution[Sys_Mag];
      PostOperation[Mag_Values]; PostOperation[Mag_Fields]; PostOperation[Mag_Checks];
      // References and the comparisons of this run (one "name value" per line).
      Print[{AnaDeltaAl}, Format "AnaDeltaAl %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaDeltaCu}, Format "AnaDeltaCu %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaDeltaSoil}, Format "AnaDeltaSoil %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaL},       Format "AnaL %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{NktL},       Format "NktL %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaBsingle}, Format "Bsingle %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaJavg},    Format "Javg %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{R20*1e3},    Format "IecRdc %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*IecYs},  Format "IecYs %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*IecYp},  Format "IecYp %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*(IecYs + IecYp)}, Format "IecYsp %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecRcond*1e3}, Format "IecRcond %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecRs*1e3},  Format "IecRs %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecX*1e3},   Format "IecX %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*IecLam}, Format "IecLam %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecRcond*(1 + IecLam)*1e3}, Format "IecRac %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecIs},      Format "IecIs %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecPc},      Format "IecPc %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecPs},      Format "IecPs %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecPc + IecPs}, Format "IecPt %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecX*I_RMS*1e3}, Format "IecUs %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*($L/AnaL - 1)}, Format "dLana %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*($L/NktL - 1)}, Format "dLnkt %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*$Pc/($Pc + $Ps)}, Format "CondShare %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*$Ps/$Pc}, Format "LamFE %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$Pc/3}, Format "PcPhase %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*(Max[$PA, Max[$PB, $PC]]/Min[$PA, Min[$PB, $PC]] - 1)}, Format "PhaseSym %.10g",
        File StrCat[ResultDir,"/references.txt"]];
      Print[{$Bmax*1e3}, Format "Bmax %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$Jmax/1e6}, Format "Jmax %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$Hmax}, Format "Hmetal %.10g", File StrCat[ResultDir,"/references.txt"]];
      If (Flag_Conductor == 0)
        Print[{$Zim/w*1e3}, Format "Lterm %.10g", File StrCat[ResultDir,"/references.txt"]];
        Print[{Fabs[100*($Zim/w*1e3/$L - 1)]}, Format "dLterm %.10g", File StrCat[ResultDir,"/references.txt"]];
      EndIf
      If (Flag_Bonding == 0)
        Print[{$IsA}, Format "Is %.10g", File StrCat[ResultDir,"/references.txt"]];
        Print[{100*($IsA/IecIs - 1)}, Format "dIs %.10g", File StrCat[ResultDir,"/references.txt"]];
        Print[{$IsA*Sqrt[2]}, Format "IsPeak %.10g", File StrCat[ResultDir,"/references.txt"]];
        Print[{$IsA*Sqrt[2]/AWire/1e6}, Format "Jscreen %.10g", File StrCat[ResultDir,"/references.txt"]];
        Print[{Sqrt[$IsumRe^2 + $IsumIm^2]}, Format "IsSum %.10g", File StrCat[ResultDir,"/references.txt"]];
      Else
        Print[{Max[$UA, Max[$UB, $UC]]}, Format "Usingle %.10g", File StrCat[ResultDir,"/references.txt"]];
      EndIf
    }
  }
}

// Quantities the course post-processing does not have or computes differently
// (|B| and |J| maps come from its post-processing Magnetodynamic_a_2D).
PostProcessing {
  { Name Mag; NameOfFormulation Magnetodynamic_a_2D;
    Quantity {
      // [Q3.8] Time-averaged Joule losses |j|^2/(2 sigma) per unit length (W/m = kW/km),
      // with the TOTAL current density j = -sigma(j w a + ur) (course eq. 9).
      { Name Losses; Value {
          Integral { [ 0.5*sigma[]*SquNorm[Dt[{a}] + {ur}] ];
            In DomainC_Mag; Jacobian Vol; Integration I1; }
          Integral { [ 0.5/sigma[]*SquNorm[js0[]] ];
            In DomainS0_Mag; Jacobian Vol; Integration I1; } } }
      // [Q3.9] R = P/(3 I_rms^2) in ohm/km (conductors only: skin+proximity; all: R_AC).
      { Name R_ohm_km; Value {
          Integral { [ 0.5*sigma[]*SquNorm[Dt[{a}] + {ur}]/(3*I_RMS^2)*1e3 ];
            In DomainC_Mag; Jacobian Vol; Integration I1; }
          Integral { [ 0.5/sigma[]*SquNorm[js0[]]/(3*I_RMS^2)*1e3 ];
            In DomainS0_Mag; Jacobian Vol; Integration I1; } } }
      // [Q3.10] Positive-sequence inductance: W = 1/4 int nu|b|^2 = 3/4 L Ipeak^2.
      { Name L_mH_km; Value {
          Integral { [ nu[]*SquNorm[{d a}]/(3*Ipeak^2)*1e6 ];
            In Domain_Mag; Jacobian Vol; Integration I1; } } }
      // [Q3.3] Net current and voltage per unit length of each massive region.
      { Name U; Value { Term { [ {U} ]; In DomainC_Mag; } } }
      { Name I; Value { Term { [ {I} ]; In DomainC_Mag; } } }
      { Name I_rms; Value { Term { [ Norm[{I}]/Sqrt[2] ]; In DomainC_Mag; } } }
      { Name U_V_km; Value { Term { [ Norm[{U}]/Sqrt[2]*1e3 ]; In DomainC_Mag; } } }
      { Name Zterm_ohm_km; Value { Term { [ -{U}/{I}*1e3 ]; In Conductors; } } }
      { Name Zterm_im; Value { Term { [ Im[-{U}/{I}*1e3] ]; In Conductors; } } }
      // Sum of the three screen currents (A, peak): integral of j_z over the screens.
      { Name IsumRe; Value { Integral { [ Re[CompZ[-sigma[]*(Dt[{a}] + {ur})]] ]; In Screens; Jacobian Vol; Integration I1; } } }
      { Name IsumIm; Value { Integral { [ Im[CompZ[-sigma[]*(Dt[{a}] + {ur})]] ]; In Screens; Jacobian Vol; Integration I1; } } }
      // Largest |B|, |J| (registers 1 and 2, filled by Mag_Fields) and largest element size in
      // the metals (register 3). [Q3.5] Element size h = edge of the equilateral triangle with
      // the same area (mm).
      { Name Reg1; Value { Term { Type Global; [ #1 ]; In CondA; } } }
      { Name Reg2; Value { Term { Type Global; [ #2 ]; In CondA; } } }
      { Name Reg3; Value { Term { Type Global; [ #3 ]; In CondA; } } }
      { Name h_mm; Value { Term { [ Sqrt[4*ElementVol[]/Sqrt[3]]*1e3 ]; In Metals; Jacobian Vol; } } }
    }
  }
}

PostOperation {
  { Name Mag_Values; NameOfPostProcessing Mag;
    Operation {
      Print[Losses[Conductors], OnGlobal, Format Table, StoreInVariable $Pc,
        SendToServer "Output/1Losses conductors [W per m]", File StrCat[ResultDir,"/losses_conductors.dat"]];
      Print[Losses[Screens], OnGlobal, Format Table, StoreInVariable $Ps,
        SendToServer "Output/2Losses screens [W per m]", File StrCat[ResultDir,"/losses_screens.dat"]];
      Print[Losses[Metals], OnGlobal, Format Table, File StrCat[ResultDir,"/losses_total.dat"]];
      Print[Losses[CondA], OnGlobal, Format Table, StoreInVariable $PA, File StrCat[ResultDir,"/losses_condA.dat"]];
      Print[Losses[CondB], OnGlobal, Format Table, StoreInVariable $PB, File StrCat[ResultDir,"/losses_condB.dat"]];
      Print[Losses[CondC], OnGlobal, Format Table, StoreInVariable $PC, File StrCat[ResultDir,"/losses_condC.dat"]];
      Print[R_ohm_km[Conductors], OnGlobal, Format Table,
        SendToServer "Output/3R conductors only [ohm per km]", File StrCat[ResultDir,"/R_conductors_ohm_km.dat"]];
      Print[R_ohm_km[Metals], OnGlobal, Format Table,
        SendToServer "Output/4R AC total [ohm per km]", File StrCat[ResultDir,"/R_ac_ohm_km.dat"]];
      Print[L_mH_km[Domain_Mag], OnGlobal, Format Table, StoreInVariable $L,
        SendToServer "Output/5L [mH per km]", File StrCat[ResultDir,"/L_mH_km.dat"]];
      Print[I, OnRegion DomainC_Mag, Format Table, File StrCat[ResultDir,"/currents_A.dat"]];
      Print[I_rms, OnRegion ScreenA, Format Table, StoreInVariable $IsA, File StrCat[ResultDir,"/screen_current_A_rms.dat"]];
      Print[U, OnRegion DomainC_Mag, Format Table, File StrCat[ResultDir,"/voltages_V_m.dat"]];
      If (Flag_Conductor == 0)
        Print[Zterm_ohm_km, OnRegion Conductors, Format Table, File StrCat[ResultDir,"/Z_terminal_ohm_km.dat"]];
      EndIf
    }
  }
  { Name Mag_Fields; NameOfPostProcessing Magnetodynamic_a_2D;   // course quantities
    Operation {
      // [Q3.7] TOTAL current density norm (A/m2, peak). [Q3.6] Flux density norm (T, peak).
      Print[jm, OnElementsOf Region[{DomainC_Mag, DomainS0_Mag}], Name "|J| [A/m2]", StoreMaxInRegister 2,
        File StrCat[ResultDir,"/j_norm.pos"]];
      Print[bm, OnElementsOf Domain_Mag, Name "|B| [T]", StoreMaxInRegister 1, File StrCat[ResultDir,"/b_norm.pos"]];
      // [Q3.2, Q3.7] |J| along phase A's vertical diameter (bottom = side facing the trefoil centre).
      Print[jm, OnLine {{xA, yA-rCon+1e-6, 0}{xA, yA+rCon-1e-6, 0}} {200},
        Format SimpleTable, File StrCat[ResultDir,"/j_line_A.txt"]];
    }
  }
  // Values for the comparisons printed by Magnetodynamics_cable (Section 3 only).
  { Name Mag_Checks; NameOfPostProcessing Mag;
    Operation {
      Print[Reg1, OnRegion CondA, Format Table, StoreInVariable $Bmax, File StrCat[ResultDir,"/max_B_T.dat"]];
      Print[Reg2, OnRegion CondA, Format Table, StoreInVariable $Jmax, File StrCat[ResultDir,"/max_J_A_m2.dat"]];
      Print[h_mm, OnElementsOf Metals, StoreMaxInRegister 3, File StrCat[ResultDir,"/element_size_metals.pos"]];
      Print[Reg3, OnRegion CondA, Format Table, StoreInVariable $Hmax, File StrCat[ResultDir,"/max_element_size_metals_mm.dat"]];
      Print[IsumRe[Screens], OnGlobal, Format Table, StoreInVariable $IsumRe, File StrCat[ResultDir,"/screen_current_sum_re.dat"]];
      Print[IsumIm[Screens], OnGlobal, Format Table, StoreInVariable $IsumIm, File StrCat[ResultDir,"/screen_current_sum_im.dat"]];
      If (Flag_Conductor == 0)
        Print[Zterm_im, OnRegion CondA, Format Table, StoreInVariable $Zim, File StrCat[ResultDir,"/Z_terminal_im_A.dat"]];
      EndIf
      If (Flag_Bonding == 1)
        Print[U_V_km, OnRegion ScreenA, Format Table, StoreInVariable $UA, File StrCat[ResultDir,"/screen_voltage_A.dat"]];
        Print[U_V_km, OnRegion ScreenB, Format Table, StoreInVariable $UB, File StrCat[ResultDir,"/screen_voltage_B.dat"]];
        Print[U_V_km, OnRegion ScreenC, Format Table, StoreInVariable $UC, File StrCat[ResultDir,"/screen_voltage_C.dat"]];
      EndIf
    }
  }
}
