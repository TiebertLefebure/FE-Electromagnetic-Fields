// Magnetoquasistatic (Section 3) and coupled magneto-thermal (Sections 4-5) model.
// Resolutions:  Magnetodynamics  -> a-v problem only, sigma at 20 C           (Section 3)
//               MagnetoThermal   -> losses -> heat -> T, optional sigma(T) loop (Section 4)
// Question tags: Q3.x magnetic, Q4.x thermal. Built from the course starter
// magnetodynamic_formulation.pro (kept in this folder as reference only).
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
  // Semicons (2e-3 S/m), XLPE, void, fillers, PE: no eddy currents, polymer kappa.
  Insulation = Region[{31,32,33, 41,42,43,44, 51,52,53, 61,62,63, 81,82,83, 91,92,93}];
  SoilNear = Region[99];  // soil delta ~ 700 m at 50 Hz: sigma = 0 in the magnetic model
  SoilFar = Region[98];
  Domain_Mag = Region[{Conductors, Screens, Insulation, SoilNear}];
  If (Flag_Conductor == 0)
    DomainC_Mag = Region[{Conductors, Screens}];  // massive: j = -sigma(j w a + ur)
    DomainS0_Mag = Region[{}];
  Else
    DomainC_Mag = Region[{Screens}];
    DomainS0_Mag = Region[{Conductors}];          // stranded: j = js0
  EndIf
  Domain_The = Region[{Domain_Mag, SoilFar}];
  EMBoxEdge = Region[120]; GroundSurface = Region[130]; Bottom = Region[132];
}

Function {
  nu[] = 1/(muR*mu0);
  // [Q4.7, course eq. 12] sigma(T) with T in deg C ($1 = {T}); Flag_NL = 0 freezes it at 20 C.
  // T comes from the real thermal system: <T>[{T}] reads it in that system's context.
  sigma[Conductors] = sigmaAl/(1 + Flag_NL*alphaAl*($1 - 20));
  sigma[Screens]    = sigmaCu/(1 + Flag_NL*alphaCu*($1 - 20));
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

Jacobian {
  { Name Vol; Case { { Region All; Jacobian Vol; } } }
  { Name Sur; Case { { Region All; Jacobian Sur; } } }
}
Integration {
  { Name I1; Case { { Type Gauss; Case {
      { GeoElement Line; NumberOfPoints 4; }
      { GeoElement Triangle; NumberOfPoints 4; }
      { GeoElement Quadrangle; NumberOfPoints 4; } } } } }
}

FunctionSpace {
  // [Q3.1] a = az(x,y) ez, first-order nodal functions.
  { Name Hcurl_a_Mag_2D; Type Form1P;
    BasisFunction {
      { Name se; NameOfCoef ae; Function BF_PerpendicularEdge;
        Support Domain_Mag; Entity NodesOf[All]; } }
    Constraint {
      { NameOfCoef ae; EntityType NodesOf; NameOfConstraint MagneticVectorPotential_2D; } }
  }
  // [Q3.2, Q3.3] One ur (uniform axial voltage gradient) per massive region,
  // with global voltage U and net current I; one of the two is imposed per region.
  { Name Hregion_u_Mag_2D; Type Form1P;
    BasisFunction {
      { Name sr; NameOfCoef ur; Function BF_RegionZ;
        Support DomainC_Mag; Entity DomainC_Mag; } }
    GlobalQuantity {
      { Name U; Type AliasOf;        NameOfCoef ur; }
      { Name I; Type AssociatedWith; NameOfCoef ur; } }
    Constraint {
      { NameOfCoef U; EntityType Region; NameOfConstraint Voltage_2D; }
      { NameOfCoef I; EntityType Region; NameOfConstraint Current_2D; } }
  }
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
  // [Q3.1] curl(nu curl a) = j; j = -sigma(T)(j w a + ur) (massive) or js0 (stranded).
  // The ur-equation imposes int jz dA = I in every massive region.
  { Name Magnetodynamics_a; Type FemEquation;
    Quantity {
      { Name a;  Type Local;  NameOfSpace Hcurl_a_Mag_2D; }
      { Name ur; Type Local;  NameOfSpace Hregion_u_Mag_2D; }
      { Name I;  Type Global; NameOfSpace Hregion_u_Mag_2D [I]; }
      { Name U;  Type Global; NameOfSpace Hregion_u_Mag_2D [U]; }
      { Name T;  Type Local;  NameOfSpace Hgrad_T; }   // only read, for sigma(T)
    }
    Equation {
      Galerkin { [ nu[] * Dof{d a}, {d a} ];
        In Domain_Mag; Jacobian Vol; Integration I1; }
      Galerkin { DtDof[ sigma[<T>[{T}]] * Dof{a}, {a} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      Galerkin { [ sigma[<T>[{T}]] * Dof{ur}, {a} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      Galerkin { DtDof[ sigma[<T>[{T}]] * Dof{a}, {ur} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      Galerkin { [ sigma[<T>[{T}]] * Dof{ur}, {ur} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      GlobalTerm { [ Dof{I}, {U} ]; In DomainC_Mag; }
      Galerkin { [ -js0[], {a} ];
        In DomainS0_Mag; Jacobian Vol; Integration I1; }
    }
  }
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
      Galerkin { [ -<a>[ 0.5*sigma[<T>[{T}]]*SquNorm[Dt[{a}] + {ur}] ], {T} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      Galerkin { [ -<a>[ 0.5/sigma[<T>[{T}]]*SquNorm[js0[]] ], {T} ];
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
  { Name Magnetodynamics;
    System {
      { Name Sys_Mag; NameOfFormulation Magnetodynamics_a; Type Complex; Frequency Freq; }
      { Name Sys_The; NameOfFormulation Thermal_T; }
    }
    Operation {
      CreateDir[ResultDir];
      InitSolution[Sys_The];
      Generate[Sys_Mag]; Solve[Sys_Mag]; SaveSolution[Sys_Mag];
      PostOperation[Mag_Global]; PostOperation[Mag_Maps];
    }
  }
  // [Section 4] Staggered coupling: magnetic solve with sigma(T_k) -> losses ->
  // thermal solve -> T_k+1, until ||T_k+1 - T_k|| / ||T_k+1|| < NL_tol (Q4.7).
  // Pass 1 uses T = 20 C everywhere: it is the linear model (Flag_NL = 0 stops there).
  { Name MagnetoThermal;
    System {
      { Name Sys_Mag; NameOfFormulation Magnetodynamics_a; Type Complex; Frequency Freq; }
      { Name Sys_The; NameOfFormulation Thermal_T; }
    }
    Operation {
      CreateDir[ResultDir];
      DeleteFile[StrCat[ResultDir,"/convergence.txt"]];
      InitSolution[Sys_The];
      Evaluate[$it = 0, $rel = 1];
      While[$rel > NL_tol && $it < NL_maxit] {
        Evaluate[$it = $it + 1];
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
      PostOperation[Mag_Global]; PostOperation[The_Global];
      PostOperation[Mag_Maps]; PostOperation[The_Maps];
    }
  }
}

PostProcessing {
  { Name Mag; NameOfFormulation Magnetodynamics_a;
    Quantity {
      // [Q3.6] Flux density norm (T, peak phasor).
      { Name bm; Value { Term { [ Norm[{d a}] ]; In Domain_Mag; Jacobian Vol; } } }
      // [Q3.7] TOTAL current density norm (A/m2, peak), including ur in massive regions.
      { Name jm; Value {
          Term { [ Norm[-sigma[<T>[{T}]]*(Dt[{a}] + {ur})] ]; In DomainC_Mag; Jacobian Vol; }
          Term { [ Norm[js0[]] ]; In DomainS0_Mag; Jacobian Vol; } } }
      // [Q3.8, Q4.1] Time-averaged Joule loss density |j|^2/(2 sigma) (W/m3).
      { Name p; Value {
          Term { [ 0.5*sigma[<T>[{T}]]*SquNorm[Dt[{a}] + {ur}] ]; In DomainC_Mag; Jacobian Vol; }
          Term { [ 0.5/sigma[<T>[{T}]]*SquNorm[js0[]] ]; In DomainS0_Mag; Jacobian Vol; } } }
      // [Q3.8] Losses per unit length (W/m = kW/km).
      { Name Losses; Value {
          Integral { [ 0.5*sigma[<T>[{T}]]*SquNorm[Dt[{a}] + {ur}] ];
            In DomainC_Mag; Jacobian Vol; Integration I1; }
          Integral { [ 0.5/sigma[<T>[{T}]]*SquNorm[js0[]] ];
            In DomainS0_Mag; Jacobian Vol; Integration I1; } } }
      // [Q3.9] R = P/(3 I_rms^2) in ohm/km (conductors only: skin+proximity; all: R_AC).
      { Name R_ohm_km; Value {
          Integral { [ 0.5*sigma[<T>[{T}]]*SquNorm[Dt[{a}] + {ur}]/(3*I_RMS^2)*1e3 ];
            In DomainC_Mag; Jacobian Vol; Integration I1; }
          Integral { [ 0.5/sigma[<T>[{T}]]*SquNorm[js0[]]/(3*I_RMS^2)*1e3 ];
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
      // [Q4.4, Q4.5] Maxima stored in registers by the prints below.
      // [Q4.7] Convergence history: iteration number and relative T increment.
      { Name ConvHist; Value { Term { Type Global; [ Vector[$it, $rel, 0] ]; In GroundSurface; } } }
      { Name Tmax_cond; Value { Term { Type Global; [ #1 ]; In GroundSurface; } } }
      { Name Tmax_surf; Value { Term { Type Global; [ #2 ]; In GroundSurface; } } }
      // [Q4.2] Heat leaving through the ground surface (W/m): equals the total losses.
      { Name SurfaceHeat; Value {
          Integral { [ hConv*({T} - T_amb) ]; In GroundSurface; Jacobian Sur; Integration I1; } } }
    }
  }
}

PostOperation {
  { Name Mag_Global; NameOfPostProcessing Mag;
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
      Print[R_ohm_km[Region[{Conductors, Screens}]], OnGlobal, Format Table,
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
  { Name Mag_Maps; NameOfPostProcessing Mag;
    Operation {
      Print[jm, OnElementsOf Region[{DomainC_Mag, DomainS0_Mag}], Name "|J| [A/m2]",
        File StrCat[ResultDir,"/j_norm.pos"]];
      Print[p, OnElementsOf Region[{DomainC_Mag, DomainS0_Mag}], Name "Joule loss density [W/m3]",
        File StrCat[ResultDir,"/loss_density.pos"]];
      Print[bm, OnElementsOf Domain_Mag, Name "|B| [T]", File StrCat[ResultDir,"/b_norm.pos"]];
    }
  }
  { Name The_Global; NameOfPostProcessing The;
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
      Print[T, OnLine {{0, BurialDepth-1e-6, 0}{0, BurialDepth-ThermalDepth+1e-6, 0}} {600},
        Format SimpleTable, File StrCat[ResultDir,"/T_vertical_profile.txt"]];
      Print[SurfaceHeat[GroundSurface], OnGlobal, Format Table, File StrCat[ResultDir,"/surface_heat_W_m.dat"]];
    }
  }
  { Name Conv_Hist; NameOfPostProcessing The;
    Operation {
      Print[ConvHist, OnRegion GroundSurface, Format Table, File > StrCat[ResultDir,"/convergence.txt"]];
    }
  }
  { Name The_Maps; NameOfPostProcessing The;
    Operation {
      Print[T, OnElementsOf Region[{Domain_Mag}], Name "T [deg C] (cables)", File StrCat[ResultDir,"/T_cables.pos"]];
      Print[T, OnElementsOf Domain_The, Name "T [deg C]", File StrCat[ResultDir,"/T.pos"]];
    }
  }
}
