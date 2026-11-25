// Sections 3-5: magnetoquasistatic a-v model and coupled heat conduction, one mesh.
// Course files, included unchanged: Jacobian_Integration.pro (Jacobians, Gauss rules) and
// magnetodynamic_formulation.pro (function spaces, weak form Magnetodynamic_a_2D, post-processing
// quantities). This file adds the cable problem, the heat equation and the sigma(T) coupling.
// Resolutions: Magnetodynamics_cable = magnetic only, sigma at 20 C (Section 3);
//              MagnetoThermal        = losses -> T, with the sigma(T) loop (Sections 4-5).
// Search a question tag (Q3.x, Q4.x) to find the block that answers it.
Include "../Cable-selection-and-model-setup/parameters.pro";
SetString["GetDP/1ResolutionChoices", "MagnetoThermal"];
SetString["GetDP/9ComputeCommand", "-solve"];
DefineConstant[
  ResultDir = {"res", Name "Output/Directory"},
  // [Q3.2] 0: massive Al (net current imposed, eddy currents free); 1: uniform J = I/A.
  Flag_Conductor = {0, Choices{0="Massive (solid Al)", 1="Stranded (uniform J)"},
    Name "Magnetic/01 Conductor model"},
  // [Q1.3, Q3.3] 0: both ends bonded, U = 0 per screen; 1: single point, I = 0.
  Flag_Bonding = {0, Choices{0="Both ends (U=0)", 1="Single point (I=0)"},
    Name "Magnetic/02 Screen bonding"},
  // [Q4.7] 0: linear (sigma at 20 C, one pass); 1: sigma(T), iterate magnetic <-> thermal.
  Flag_NL = {1, Choices{0="Linear: sigma at 20 C", 1="Nonlinear: sigma(T)"},
    Name "Thermal/20 Conductivity model"},
  // [Q4.5] 0: convection h(T - T_amb) at the ground surface; 1: T = T_amb (as IEC 60287).
  Flag_SurfaceBC = {0, Choices{0="Convection", 1="Isothermal T = T_amb"},
    Name "Thermal/21 Ground surface condition"},
  NL_tol = {1e-6, Name "Thermal/22 Tolerance on relative T increment"},
  NL_maxit = {30, Name "Thermal/23 Maximum coupling iterations"}
];

// [Q3.1, Q4.2] Two domains on ONE mesh: the magnetic one is the EM box (cables + near
// soil, a = 0 on its edge); the thermal one adds the soil up to the ground surface.
Group {
  CondA = Region[21]; CondB = Region[22]; CondC = Region[23];
  ScreenA = Region[71]; ScreenB = Region[72]; ScreenC = Region[73];
  Conductors = Region[{CondA, CondB, CondC}];
  Screens = Region[{ScreenA, ScreenB, ScreenC}];
  Metals = Region[{Conductors, Screens}];
  // Semicons (2e-3 S/m), XLPE, void, fillers, PE: no eddy currents, polymer kappa.
  Insulation = Region[{31,32,33, 41,42,43,44, 51,52,53, 61,62,63, 81,82,83, 91,92,93}];
  SoilNear = Region[99];  // soil delta ~ 700 m at 50 Hz: sigma = 0 in the magnetic model
  SoilFar = Region[98];
  Domain_Mag = Region[{Metals, Insulation, SoilNear}];
  If (Flag_Conductor == 0)
    DomainC_Mag = Region[{Metals}];       // massive: j = -sigma(j w a + ur)
    DomainS0_Mag = Region[{}];
  Else
    DomainC_Mag = Region[{Screens}];
    DomainS0_Mag = Region[{Conductors}];  // stranded: j = js0 imposed
  EndIf
  Domain_The = Region[{Domain_Mag, SoilFar}];
  EMBoxEdge = Region[120]; GroundSurface = Region[130]; Bottom = Region[132];
}

Function {
  nu[] = 1/(muR*mu0);
  // [Q4.7, course eq. 12] sigma(T) = sigma_20 / (1 + alpha (T - 20)), T in deg C. The course
  // formulation calls sigma[] without arguments, so T is read from field 1: the temperature of
  // the previous thermal solve, stored by PostOperation Store_T (20 C before the first pass).
  If (Flag_NL == 1)
    sigma[Conductors] = sigmaAl/(1 + alphaAl*(ScalarField[XYZ[]]{1} - 20));
    sigma[Screens]    = sigmaCu/(1 + alphaCu*(ScalarField[XYZ[]]{1} - 20));
  Else
    sigma[Conductors] = sigmaAl;
    sigma[Screens]    = sigmaCu;
  EndIf
  // [Q3.2] Stranded model: js = I_k/A_k along z with the ABC phase angles.
  AreaCon = Pi*rCon^2;
  js0[CondA] = Vector[0,0,1] * Ipeak/AreaCon * Complex[1, 0];
  js0[CondB] = Vector[0,0,1] * Ipeak/AreaCon * Complex[Cos[-2*Pi/3], Sin[-2*Pi/3]];
  js0[CondC] = Vector[0,0,1] * Ipeak/AreaCon * Complex[Cos[ 2*Pi/3], Sin[ 2*Pi/3]];
  // [Q4.2] Thermal conductivities (W/(m K)).
  kappa[Conductors] = kAl;
  kappa[Screens] = kCu;
  kappa[Insulation] = kPoly;
  kappa[Region[{SoilNear, SoilFar}]] = kSoil;
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
  // [Q4.2] T = T_amb at the bottom (and at the surface if isothermal).
  // [Q4.7] Init: the coupling loop starts from 20 C, so its first pass is the linear case.
  { Name Temperature; Case {
      { Region Bottom; Type Assign; Value T_amb; }
      If (Flag_SurfaceBC == 1)
        { Region GroundSurface; Type Assign; Value T_amb; }
      EndIf
      { Region Domain_The; Type Init; Value 20; }
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

Include "../Cable-selection-and-model-setup/Jacobian_Integration.pro";
Include "magnetodynamic_formulation.pro";

FunctionSpace {
  // [Q4.1] Temperature (deg C), first-order nodal functions on the thermal domain.
  { Name Hgrad_T; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef Tn; Function BF_Node;
        Support Region[{Domain_The, GroundSurface}]; Entity NodesOf[All]; } }
    Constraint {
      { NameOfCoef Tn; EntityType NodesOf; NameOfConstraint Temperature; } }
  }
}

Formulation {
  // [Q4.1] -div(kappa grad T) = p, with p = |j|^2/(2 sigma) the time-averaged Joule loss
  // density of the complex magnetic solution (<a>[...] evaluates it in that system: a real
  // number). [Q4.2] Convection -kappa dT/dn = h (T - T_amb) on the ground surface.
  { Name Thermal_T; Type FemEquation;
    Quantity {
      { Name T;  Type Local; NameOfSpace Hgrad_T; }
      { Name a;  Type Local; NameOfSpace Hcurl_a_Mag_2D; }
      { Name ur; Type Local; NameOfSpace Hregion_u_Mag_2D; }
    }
    Equation {
      Galerkin { [ kappa[] * Dof{d T}, {d T} ];
        In Domain_The; Jacobian Vol; Integration I1; }
      Galerkin { [ -<a>[ 0.5*sigma[]*SquNorm[Dt[{a}] + {ur}] ], {T} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      Galerkin { [ -<a>[ 0.5/sigma[]*SquNorm[js0[]] ], {T} ];
        In DomainS0_Mag; Jacobian Vol; Integration I1; }
      If (Flag_SurfaceBC == 0)
        Galerkin { [ hConv * Dof{T}, {T} ];
          In GroundSurface; Jacobian Sur; Integration I1; }
        Galerkin { [ -hConv * T_amb, {T} ];
          In GroundSurface; Jacobian Sur; Integration I1; }
      EndIf
    }
  }
}

Resolution {
  // [Section 3] Magnetic problem only; T stays at its initial 20 C, so sigma = sigma(20 C).
  { Name Magnetodynamics_cable;
    System {
      { Name Sys_Mag; NameOfFormulation Magnetodynamic_a_2D; Type Complex; Frequency Freq; }
      { Name Sys_The; NameOfFormulation Thermal_T; }
    }
    Operation {
      CreateDir[ResultDir];
      InitSolution[Sys_The]; PostOperation[Store_T];
      Generate[Sys_Mag]; Solve[Sys_Mag]; SaveSolution[Sys_Mag];
      PostOperation[Mag_Values]; PostOperation[Mag_Fields];
    }
  }
  // [Section 4] Staggered coupling: magnetic solve with sigma(T_k) -> losses ->
  // thermal solve -> T_k+1, until ||T_k+1 - T_k|| / ||T_k+1|| < NL_tol (Q4.7).
  // Pass 1 uses T = 20 C everywhere: it is the linear model (Flag_NL = 0 stops there).
  { Name MagnetoThermal;
    System {
      { Name Sys_Mag; NameOfFormulation Magnetodynamic_a_2D; Type Complex; Frequency Freq; }
      { Name Sys_The; NameOfFormulation Thermal_T; }
    }
    Operation {
      CreateDir[ResultDir];
      DeleteFile[StrCat[ResultDir,"/convergence.txt"]];
      InitSolution[Sys_The];
      Evaluate[$it = 0, $rel = 1];
      While[$rel > NL_tol && $it < NL_maxit] {
        Evaluate[$it = $it + 1];
        PostOperation[Store_T];
        Generate[Sys_Mag]; Solve[Sys_Mag];
        Generate[Sys_The]; Solve[Sys_The];
        GetNormIncrement[Sys_The, $dT]; GetNormSolution[Sys_The, $nT];
        Evaluate[$rel = $dT/$nT];
        If (Flag_NL == 0)
          Evaluate[$rel = 0];
        EndIf
        Print[{$it, $rel}, Format "Coupling iteration %g: relative T increment %g"];
        PostOperation[Conv_Hist];
      }
      SaveSolution[Sys_Mag]; SaveSolution[Sys_The];
      PostOperation[Mag_Values]; PostOperation[The_Values];
      PostOperation[Mag_Fields]; PostOperation[The_Fields];
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
      { Name Zterm_ohm_km; Value { Term { [ -{U}/{I}*1e3 ]; In Conductors; } } }
    }
  }
  { Name The; NameOfFormulation Thermal_T;
    Quantity {
      { Name T; Value { Term { [ {T} ]; In Region[{Domain_The, GroundSurface}]; Jacobian Vol; } } }
      // [Q4.7] Convergence history: iteration number and relative T increment.
      { Name ConvHist; Value { Term { Type Global; [ Vector[$it, $rel, 0] ]; In GroundSurface; } } }
      // [Q4.4, Q4.5] Maxima stored in registers 1 and 2 by the prints in The_Values.
      { Name Tmax_cond; Value { Term { Type Global; [ #1 ]; In GroundSurface; } } }
      { Name Tmax_surf; Value { Term { Type Global; [ #2 ]; In GroundSurface; } } }
      // [Q4.2] Heat leaving through the ground surface (W/m): equals the total losses.
      { Name SurfaceHeat; Value {
          Integral { [ hConv*({T} - T_amb) ]; In GroundSurface; Jacobian Sur; Integration I1; } } }
    }
  }
}

PostOperation {
  // [Q4.7] Field 1 = temperature of the metals, read by sigma[] (StoreInField replaces it).
  { Name Store_T; NameOfPostProcessing The;
    Operation {
      Print[T, OnElementsOf Metals, StoreInField 1, File StrCat[ResultDir,"/T_metals.pos"]];
    }
  }
  { Name Mag_Values; NameOfPostProcessing Mag;
    Operation {
      Print[Losses[Conductors], OnGlobal, Format Table,
        SendToServer "Output/1Losses conductors [W per m]", File StrCat[ResultDir,"/losses_conductors.dat"]];
      Print[Losses[Screens], OnGlobal, Format Table,
        SendToServer "Output/2Losses screens [W per m]", File StrCat[ResultDir,"/losses_screens.dat"]];
      Print[Losses[CondA], OnGlobal, Format Table, File StrCat[ResultDir,"/losses_condA.dat"]];
      Print[Losses[CondB], OnGlobal, Format Table, File StrCat[ResultDir,"/losses_condB.dat"]];
      Print[Losses[CondC], OnGlobal, Format Table, File StrCat[ResultDir,"/losses_condC.dat"]];
      Print[R_ohm_km[Conductors], OnGlobal, Format Table,
        SendToServer "Output/3R conductors only [ohm per km]", File StrCat[ResultDir,"/R_conductors_ohm_km.dat"]];
      Print[R_ohm_km[Metals], OnGlobal, Format Table,
        SendToServer "Output/4R AC total [ohm per km]", File StrCat[ResultDir,"/R_ac_ohm_km.dat"]];
      Print[L_mH_km[Domain_Mag], OnGlobal, Format Table,
        SendToServer "Output/5L [mH per km]", File StrCat[ResultDir,"/L_mH_km.dat"]];
      Print[I, OnRegion DomainC_Mag, Format Table, File StrCat[ResultDir,"/currents_A.dat"]];
      Print[U, OnRegion DomainC_Mag, Format Table, File StrCat[ResultDir,"/voltages_V_m.dat"]];
      If (Flag_Conductor == 0)
        Print[Zterm_ohm_km, OnRegion Conductors, Format Table, File StrCat[ResultDir,"/Z_terminal_ohm_km.dat"]];
      EndIf
    }
  }
  { Name Mag_Fields; NameOfPostProcessing Magnetodynamic_a_2D;   // course quantities
    Operation {
      // [Q3.7] TOTAL current density norm (A/m2, peak). [Q3.6] Flux density norm (T, peak).
      Print[jm, OnElementsOf Region[{DomainC_Mag, DomainS0_Mag}], Name "|J| [A/m2]",
        File StrCat[ResultDir,"/j_norm.pos"]];
      Print[bm, OnElementsOf Domain_Mag, Name "|B| [T]", File StrCat[ResultDir,"/b_norm.pos"]];
      // [Q3.2, Q3.7] |J| along phase A's vertical diameter (bottom = side facing the trefoil centre).
      Print[jm, OnLine {{xA, yA-rCon+1e-6, 0}{xA, yA+rCon-1e-6, 0}} {200},
        Format SimpleTable, File StrCat[ResultDir,"/j_line_A.txt"]];
    }
  }
  { Name The_Values; NameOfPostProcessing The;
    Operation {
      // [Q4.4] Hot spot: maximum conductor temperature (register 1).
      Print[T, OnElementsOf Conductors, StoreMaxInRegister 1, File StrCat[ResultDir,"/T_conductors.pos"]];
      Print[Tmax_cond, OnRegion GroundSurface, Format Table,
        SendToServer "Output/6Max conductor temperature [deg C]", File StrCat[ResultDir,"/Tmax_conductor.dat"]];
      // [Q4.5] Maximum ground-surface temperature (register 2) and the surface profile.
      Print[T, OnElementsOf GroundSurface, StoreMaxInRegister 2, File StrCat[ResultDir,"/T_surface.pos"]];
      Print[Tmax_surf, OnRegion GroundSurface, Format Table,
        SendToServer "Output/7Max surface temperature [deg C]", File StrCat[ResultDir,"/Tmax_surface.dat"]];
      Print[T, OnLine {{-ThermalHalfWidth, BurialDepth-1e-6, 0}{ThermalHalfWidth, BurialDepth-1e-6, 0}} {500},
        Format SimpleTable, File StrCat[ResultDir,"/T_surface_profile.txt"]];
      Print[SurfaceHeat[GroundSurface], OnGlobal, Format Table, File StrCat[ResultDir,"/surface_heat_W_m.dat"]];
    }
  }
  { Name Conv_Hist; NameOfPostProcessing The;
    Operation {
      Print[ConvHist, OnRegion GroundSurface, Format Table, File > StrCat[ResultDir,"/convergence.txt"]];
    }
  }
  { Name The_Fields; NameOfPostProcessing The;
    Operation {
      Print[T, OnElementsOf Region[{Domain_Mag}], Name "T [deg C] (cables)", File StrCat[ResultDir,"/T_cables.pos"]];
      Print[T, OnElementsOf Domain_The, Name "T [deg C]", File StrCat[ResultDir,"/T.pos"]];
    }
  }
}
