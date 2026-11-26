// Section 2: electric field in the XLPE insulation (healthy or with an air void).
// Course files, included unchanged: Jacobian_Integration.pro (Jacobians, Gauss rules) and
// electrodynamic_formulation.pro (function space Hgrad_v_Ele, weak form Electrodynamics_v,
// post-processing quantities EleDyn_v). This file defines the cable problem, its outputs and
// the analytical references it is compared with (results/<case>/references.txt).
// Search a question tag (Q2.1 ... Q2.8) to find the block that answers it.
Include "../1-Cable-selection-and-model-setup/parameters.pro";
SetString["GetDP/1ResolutionChoices", "Electrodynamics_cable"];
SetString["GetDP/9ComputeCommand", "-solve"];
DefineConstant[ResultDir = {"res", Name "Output/Directory"}];

// [Q2.1] Domain: the three XLPE annuli (+ void 44 if Flag_Defect = 1). The semicons are
// ideal equipotentials, so the inner XLPE boundary carries the phase voltage and the outer
// one is grounded: nothing outside the grounded screens influences the insulation field.
Group {
  XLPE = Region[{41,42,43}];
  Void = Region[{44}];
  Domain_Ele = Region[{XLPE, Void}];
  LiveA = Region[101]; LiveB = Region[102]; LiveC = Region[103];
  Live = Region[{LiveA, LiveB, LiveC}];       // conductor screens (phase voltage)
  Grounded = Region[{111, 112, 113}];          // core screens (0 V)
  PhaseA = Region[{41, 44, LiveA}]; PhaseB = Region[{42, LiveB}]; PhaseC = Region[{43, LiveC}];
}

Function {
  epsilon[XLPE] = eps0*epsXLPE;  sigma[XLPE] = sigmaXLPE;
  epsilon[Void] = eps0*epsVoid;  sigma[Void] = sigmaVoid;
  // [Q1.4] Phase voltage (peak phasor, ABC sequence) of each phase's screen and insulation.
  Vph[PhaseA] = Complex[Vpeak, 0];
  Vph[PhaseB] = Complex[Vpeak*Cos[-2*Pi/3], Vpeak*Sin[-2*Pi/3]];
  Vph[PhaseC] = Complex[Vpeak*Cos[ 2*Pi/3], Vpeak*Sin[ 2*Pi/3]];
}

// [Q2.1] Dirichlet conditions of the course function space: v = Vph on the conductor
// screens, v = 0 on the core screens.
Constraint {
  { Name ElectricScalarPotential; Case {
      { Region Live; Value Vph[]; }
      { Region Grounded; Value 0; } } }
  { Name ZeroElectricScalarPotential; Case { { Region Region[{Live, Grounded}]; Value 0; } } }
}

// Names the course file needs. Its own resolution (Electrodynamics) and post-operations
// (Ele_Maps, Ele_Cuts) are written for the course example cable and are not used here: in this
// three-phase domain its C_from_Energy is the three-phase total (3 C).
Flag_Degree_v = 1;                                 // first-order nodal elements
V0 = Vpeak; Pa = 0; Pb = -2*Pi/3; Pc = 2*Pi/3;     // its phase voltages
dc = 2*rCon; ti = tSemiIn; txlpe = tXLPE; to = tSemiOut; tapl = 0;   // its radial cut (phase C)
tps = Spacing - (dc + 2*(ti + txlpe + to + tapl)); // so that its dist_cab is our centre spacing
Group { Cable = Region[{Domain_Ele}]; Ind_1 = Region[{LiveA}]; Ind_2 = Region[{LiveB}]; Ind_3 = Region[{LiveC}];
        DomainDummy = Region[12345]; }

Include "../1-Cable-selection-and-model-setup/Jacobian_Integration.pro";
Include "electrodynamic_formulation.pro";

// ---- Analytical references (course App. B and the cited sources), printed by the resolution
w = 2*Pi*Freq;  U0 = U_LL/Sqrt[3];  lnr = Log[rXLPEOut/rSemiIn];
AnaC  = 2*Pi*eps0*epsXLPE/lnr*1e9;                  // [Q2.7] coaxial capacitance, uF/km
AnaEi = Vpeak/(rSemiIn*lnr)/1e6;                    // [Q2.4] field at the conductor screen, kV/mm peak
AnaEo = Vpeak/(rXLPEOut*lnr)/1e6;                   //        and at the core screen
AnaE0 = Vpeak/(rVoidPos*lnr)/1e6;                   // [Q2.5] healthy field at the void centre
AnaVoidFactor = 2*epsXLPE/(epsXLPE + epsVoid);     //        E_void/E_0 for a cylinder (2D void)
AnaSphereFactor = 3*epsXLPE/(2*epsXLPE + epsVoid); //        and for a sphere (a real void)
AnaEvoid = AnaVoidFactor*AnaE0;                     //        field in a cylindrical void
AnaIch = w*AnaC*1e-9*U0*1e3;                        // [Q2.6] charging current, A/km RMS
AnaJd = w*eps0*epsXLPE*AnaEi*1e6;                   //        |J_d| at the conductor screen, A/m2 peak
AnaJc = sigmaXLPE*AnaEi*1e6;                        //        |J_c| there
AnaRatio = sigmaXLPE/(w*eps0*epsXLPE);              //        |J_c / J_d| in XLPE
AnaDrop = AnaJd*tSemiIn/sigmaSemi*1e3;              // [Q2.2] drop across the conductor semicon, mV
AnaCbare = 2*Pi*eps0*epsXLPE/Log[rXLPEOut/rCon]*1e9; // [Q2.2] voltage on the Al instead of the semicon
// [Q2.5] Breakdown of air across the void diameter d (1 bar): Schumann fit [VSSUT] and
// Paschen's law with A = 112.5 /(kPa cm), B = 2737.5 V/(kPa cm), gamma = 0.025 [Bean].
dVoid = 2*rVoid*100;                                // cm
AnaEb = (24.22*dVoid + 6.08*Sqrt[dVoid])/(dVoid*10);                 // kV/mm
pd = 101.325*dVoid;                                 // kPa cm
AnaEbPaschen = 2737.5*pd/(Log[pd] + Log[112.5/Log[1 + 1/0.025]])/1e3/(dVoid*10);   // kV/mm

Resolution {
  { Name Electrodynamics_cable;
    System { { Name Sys_Ele; NameOfFormulation Electrodynamics_v; Type Complex; Frequency Freq; } }
    Operation {
      CreateDir[ResultDir]; DeleteFile[StrCat[ResultDir,"/references.txt"]];
      Generate[Sys_Ele]; Solve[Sys_Ele]; SaveSolution[Sys_Ele];
      PostOperation[Ele_Fields]; PostOperation[Ele_Values];
      If (Flag_Defect)
        PostOperation[Ele_Void]; Evaluate[$Evoid = $EvoidInt/$Avoid];
      EndIf
      // Analytical references and the comparisons of this run (one "name value" per line).
      Print[{AnaC},     Format "AnaC %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaEi},    Format "AnaEi %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaEi/Sqrt[2]}, Format "AnaEirms %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaEo/Sqrt[2]}, Format "AnaEorms %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaE0},    Format "AnaEzero %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaEvoid}, Format "AnaEvoid %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaVoidFactor}, Format "AnaVoidFactor %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaSphereFactor}, Format "AnaSphereFactor %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaVoidFactor*epsVoid/epsXLPE}, Format "AnaJdVoidFactor %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaIch},   Format "AnaIch %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaJd},    Format "AnaJd %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaJc},    Format "AnaJc %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaRatio}, Format "AnaRatio %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaDrop},  Format "AnaDrop %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaCbare}, Format "AnaCbare %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*(AnaCbare/AnaC - 1)}, Format "dCbare %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaEb},    Format "AnaEb %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaEbPaschen}, Format "AnaEbPaschen %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*($Emax/AnaEi - 1)}, Format "dEana %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*($Cenergy/AnaC - 1)}, Format "dCana %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*($Cenergy/CmaxNKT - 1)}, Format "dCnkt %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{w*$Ccharge*1e-9*U0*1e3}, Format "IchFE %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$Ire/$Iim}, Format "IratioFE %.10g", File StrCat[ResultDir,"/references.txt"]];
      // [Q2.6] Current balance: C from the electrode current (charge) vs C from the field energy, %.
      Print[{100*($Ccharge/$Cenergy - 1)}, Format "dCcharge %.10g", File StrCat[ResultDir,"/references.txt"]];
      If (Flag_Defect)
        Print[{$Evoid}, Format "EvoidMean %.10g", File StrCat[ResultDir,"/references.txt"]];
        Print[{$Evoid/AnaE0}, Format "VoidRatio %.10g", File StrCat[ResultDir,"/references.txt"]];
        Print[{U0/1e3*AnaEb/$Evoid}, Format "PdInception %.10g", File StrCat[ResultDir,"/references.txt"]];
      EndIf
    }
  }
}

// Quantities the course post-processing does not have (v, |E| and |J cond| come from EleDyn_v).
PostProcessing {
  { Name Ele_Cable; NameOfFormulation Electrodynamics_v;
    Quantity {
      // [Q2.6] Displacement current density |j omega eps E| (A/m2, peak).
      { Name jd; Value { Term { [ Norm[-epsilon[]*Dt[{d v}]] ]; In Domain_Ele; Jacobian Vol; } } }
      // [Q2.6] Current entering one phase's insulation (A/m, peak phasor): the weak form tested
      // with the FE function v/Vph (1 on the conductor screen, 0 on the core screen).
      { Name I; Value { Integral { [ (sigma[]*{d v} + epsilon[]*Dt[{d v}]) * {d v} / Vph[] ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
      { Name I_re; Value { Integral { [ Re[(sigma[]*{d v} + epsilon[]*Dt[{d v}]) * {d v} / Vph[]] ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
      { Name I_im; Value { Integral { [ Im[(sigma[]*{d v} + epsilon[]*Dt[{d v}]) * {d v} / Vph[]] ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
      // [Q2.7] Capacitance per phase from that current (charge): C = Im(I/V)/omega (uF/km).
      { Name C_charge; Value { Integral {
            [ Im[(sigma[]*{d v} + epsilon[]*Dt[{d v}]) * {d v} / Vph[]^2]/(2*Pi*Freq)*1e9 ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
      // [Q2.7] Capacitance from field energy, 3-phase average: int eps |E|^2 / (3 Vpeak^2).
      { Name C_energy; Value { Integral { [ epsilon[]*SquNorm[{d v}]/(3*Vpeak^2)*1e9 ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
      // [Q2.4] Largest element |E| (register 1, filled by the field_norm print), kV/mm;
      // largest |J_d| and |J_c| (registers 2 and 3), A/m2.
      { Name Emax;  Value { Term { Type Global; [ #1*1e-6 ]; In LiveA; } } }
      { Name Jdmax; Value { Term { Type Global; [ #2 ]; In LiveA; } } }
      { Name Jcmax; Value { Term { Type Global; [ #3 ]; In LiveA; } } }
      // [Q2.5] Mean |E| in the void (kV/mm) and its area.
      { Name Evoid; Value { Integral { [ Norm[{d v}]*1e-6 ]; In Void; Jacobian Vol; Integration I1; } } }
      { Name Area;  Value { Integral { [ 1 ]; In Domain_Ele; Jacobian Vol; Integration I1; } } }
      // [Section 1] Number of triangles in a region (each triangle contributes 1).
      { Name Ntri;  Value { Integral { [ 1/ElementVol[] ]; In Domain_Ele; Jacobian Vol; Integration I1; } } }
    }
  }
}

PostOperation {
  { Name Ele_Fields; NameOfPostProcessing EleDyn_v;   // course quantities
    Operation {
      Print[v,  OnElementsOf Domain_Ele, Name "v [V]", File StrCat[ResultDir,"/potential.pos"]];
      Print[jm, OnElementsOf Domain_Ele, Name "|J cond| [A/m2]", StoreMaxInRegister 3,
        File StrCat[ResultDir,"/conduction_current.pos"]];
      Print[em, OnElementsOf Domain_Ele, Name "|E| [V/m]", StoreMaxInRegister 1,
        File StrCat[ResultDir,"/field_norm.pos"]];
      // [Q2.4, Q2.5, Q2.8] |E| along phase A's +x radius (through the void), 1 um inside XLPE.
      Print[em, OnLine {{xA+rSemiIn+1e-6, yA, 0}{xA+rXLPEOut-1e-6, yA, 0}} {1600},
        Format SimpleTable, File StrCat[ResultDir,"/radial_field_A.txt"]];
    }
  }
  { Name Ele_Values; NameOfPostProcessing Ele_Cable;
    Operation {
      Print[jd, OnElementsOf Domain_Ele, Name "|J disp| [A/m2]", StoreMaxInRegister 2,
        File StrCat[ResultDir,"/displacement_current.pos"]];
      Print[Emax, OnRegion LiveA, Format Table, StoreInVariable $Emax,
        SendToServer "Output/2Max field [kV per mm, peak]", File StrCat[ResultDir,"/max_field_kV_mm.dat"]];
      Print[Jdmax, OnRegion LiveA, Format Table, File StrCat[ResultDir,"/max_Jd_A_m2.dat"]];
      Print[Jcmax, OnRegion LiveA, Format Table, File StrCat[ResultDir,"/max_Jc_A_m2.dat"]];
      Print[I[PhaseA], OnGlobal, Format Table, File StrCat[ResultDir,"/electrode_current_A.dat"]];
      Print[I_re[PhaseA], OnGlobal, Format Table, StoreInVariable $Ire, File StrCat[ResultDir,"/electrode_current_A_re.dat"]];
      Print[I_im[PhaseA], OnGlobal, Format Table, StoreInVariable $Iim, File StrCat[ResultDir,"/electrode_current_A_im.dat"]];
      Print[C_charge[PhaseA], OnGlobal, Format Table, StoreInVariable $Ccharge,
        File StrCat[ResultDir,"/capacitance_charge_uF_km.dat"]];
      Print[C_energy[Domain_Ele], OnGlobal, Format Table, StoreInVariable $Cenergy,
        SendToServer "Output/1Capacitance [uF per km]", File StrCat[ResultDir,"/capacitance_uF_km.dat"]];
      Print[Ntri[Region[41]], OnGlobal, Format Table, File StrCat[ResultDir,"/triangles_XLPE_A.dat"]];
    }
  }
  // [Q2.5] Mean field in the void = integral of |E| over the void / its area.
  { Name Ele_Void; NameOfPostProcessing Ele_Cable;
    Operation {
      Print[Area[Void], OnGlobal, Format Table, StoreInVariable $Avoid, File StrCat[ResultDir,"/void_area.dat"]];
      Print[Evoid[Void], OnGlobal, Format Table, StoreInVariable $EvoidInt, File StrCat[ResultDir,"/void_field_integral.dat"]];
    }
  }
}
