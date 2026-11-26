// Section 4: magnetothermal model. The Section 3 magnetic model (included) gives the Joule
// losses; the heat equation here gives the temperature; sigma(T) couples the two.
// Its references (IEC 60287 ladder, Q4.x checks) are printed to results/<case>/references.txt.
// Section 5 includes this file. Search a question tag (Q4.1 ... Q4.9) to find the block.
Flag_Coupled = 1;   // tells the Section 3 file that Tmetal[] is defined here
Include "../3-Magnetoquasistatic-analysis/cable.pro";
SetString["GetDP/1ResolutionChoices", "MagnetoThermal"];
SetString["GetDP/9ComputeCommand", "-solve"];
DefineConstant[
  // [Q4.7] 0: linear (sigma at 20 C, one pass); 1: sigma(T), iterate magnetic <-> thermal.
  Flag_NL = {1, Choices{0="Linear: sigma at 20 C", 1="Nonlinear: sigma(T)"},
    Name "Thermal/20 Conductivity model"},
  // [Q4.5] 0: convection h(T - T_amb) at the ground surface; 1: T = T_amb (as IEC 60287).
  Flag_SurfaceBC = {0, Choices{0="Convection", 1="Isothermal T = T_amb"},
    Name "Thermal/21 Ground surface condition"},
  NL_tol = {1e-6, Name "Thermal/22 Tolerance on relative T increment"},
  NL_maxit = {30, Name "Thermal/23 Maximum coupling iterations"}
];

// [Q4.2] The thermal domain is the magnetic one plus the soil up to the ground surface (same mesh).
Group {
  SoilFar = Region[98];
  Domain_The = Region[{Domain_Mag, SoilFar}];
  GroundSurface = Region[130]; Bottom = Region[132];
}

Function {
  // [Q4.7] The course formulation calls sigma[] without arguments, so the metal temperature
  // is read from field 1: the temperature of the previous thermal solve, stored by
  // PostOperation Store_T (20 C before the first pass).
  If (Flag_NL == 1)
    Tmetal[] = ScalarField[XYZ[]]{1};
  Else
    Tmetal[] = 20;
  EndIf
  // Section 5 changes the current I = $Iscale I_RMS: for a given sigma the magnetic problem is
  // linear in I, so the loss density scales with $Iscale^2 (the magnetic model keeps I_RMS).
  LossScale[] = $Iscale^2;
  // [Q4.2] Thermal conductivities (W/(m K)).
  kappa[Conductors] = kAl;
  kappa[Screens] = kCu;
  kappa[Insulation] = kPoly;
  kappa[Region[{SoilNear, SoilFar}]] = kSoil;
}

Constraint {
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
      Galerkin { [ -LossScale[]*<a>[ 0.5*sigma[]*SquNorm[Dt[{a}] + {ur}] ], {T} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }
      Galerkin { [ -LossScale[]*<a>[ 0.5/sigma[]*SquNorm[js0[]] ], {T} ];
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

// [Q4.7] Staggered coupling at the current $Iscale I_RMS: magnetic solve with sigma(T_k) ->
// losses -> thermal solve -> T_k+1, until ||T_k+1 - T_k|| / ||T_k+1|| < NL_tol. The first pass
// of a run uses T = 20 C everywhere: it is the linear model (Flag_NL = 0 stops there).
// $rsum/$nrate: mean ratio of successive increments from pass 3 on (convergence rate).
Macro CoupledSolve
  Evaluate[$it = 0, $rel = 1, $relOld = 1, $rsum = 0, $nrate = 0];
  While[$rel > NL_tol && $it < NL_maxit] {
    Evaluate[$it = $it + 1];
    PostOperation[Store_T];
    Generate[Sys_Mag]; Solve[Sys_Mag];
    Generate[Sys_The]; Solve[Sys_The];
    GetNormIncrement[Sys_The, $dT]; GetNormSolution[Sys_The, $nT];
    Evaluate[$relOld = $rel, $rel = $dT/$nT];
    If (Flag_NL == 0)
      Evaluate[$rel = 0];
    EndIf
    Test[$it >= 3] { Evaluate[$rsum = $rsum + $rel/$relOld, $nrate = $nrate + 1]; }
    Print[{$it, $rel}, Format "Coupling iteration %g: relative T increment %g"];
    PostOperation[Conv_Hist];
  }
Return

// ---- IEC 60287 references: thermal ladder [Q4.4, Q4.6], equations as printed in [KTH]
// Lindstrom (2011): eqs. 4.1-4.2 (ladder, ampacity), 4.6-4.14 (y_s, y_p, lambda_1), 4.17 (T3);
// T1 as in [UNCC] eq. 19; T4 for a touching trefoil [Karlstrand] eq. 2.
IecT1 = 1/kPoly/(2*Pi)*Log[rWireIn/rCon];          // conductor -> screen, K m/W
IecT3 = 1/kPoly/(2*Pi)*Log[rJacket/rWireOut];      // screen -> jacket surface
IecU = BurialDepth/rJacket;                         // u = 2 L / D_e
IecT4 = 1.5/Pi/kSoil*(Log[2*IecU] - 0.630);        // soil, n rho/(2 pi) with n = 3
// Conductor AC resistance and screen loss factor at conductor/screen temperatures thc/ths
// (the 20 C values are those of Section 3).
Macro IecAt
  iR = RdcNKT*1e-3*(1 + alphaAl*(thc - 20));
  iX4 = (8*Pi*Freq/iR*1e-7)^2;  iF = iX4/(192 + 0.8*iX4);
  iRac = iR*(1 + iF + iF*(2*rCon/Spacing)^2*(0.312*(2*rCon/Spacing)^2 + 1.18/(iF + 0.27)));
  iRs = 1/(sigmaCu*AWire)*(1 + alphaCu*(ths - 20));
  iLam = iRs/iRac/(1 + (iRs/IecX)^2);
Return
// Conductor temperature at I_RMS (fixed point on theta, start at 90 C).
th = 90;
For k In {1:100}
  thc = th; ths = th; Call IecAt;
  ths = th - I_RMS^2*iRac*IecT1;  Call IecAt;
  th = T_amb + I_RMS^2*iRac*(IecT1 + (1 + iLam)*(IecT3 + IecT4));
EndFor
IecTheta = th; IecThetaS = ths; IecRacHot = iRac; IecLamHot = iLam;
// Ampacity: current for theta = TadmNKT (fixed point on I).
ia = I_RMS;
For k In {1:100}
  thc = TadmNKT; ths = TadmNKT; Call IecAt;
  ths = TadmNKT - ia^2*iRac*IecT1;  Call IecAt;
  ia = Sqrt[(TadmNKT - T_amb)/(iRac*(IecT1 + (1 + iLam)*(IecT3 + IecT4)))];
EndFor
IecAmp = ia;
// [Q4.2] Halving the filler conductivity: inner filler adds to T1, outer filler to T3.
dT1f = 1/kPoly/(2*Pi)*Log[rWireIn/rSemiOut];  dT3f = 1/kPoly/(2*Pi)*Log[rScreenOuter/rWireOut];
dTfiller = I_RMS^2*IecRacHot*(dT1f + (1 + IecLamHot)*dT3f);
// [Q4.2] Radiation part of h: 4 e s T^3 with e = eGround at T = T_amb [Lienhard eq. 2.31].
Hrad = 4*eGround*5.670e-8*(T_amb + 273.15)^3;
// [Q4.1] Dielectric losses w C U0^2 tan(delta) per phase, against the conductor losses.
U0 = U_LL/Sqrt[3];
AnaWd = w*2*Pi*eps0*epsXLPE/Log[rXLPEOut/rSemiIn]*U0^2*tanDelta;
AnaWdShare = 100*AnaWd/(I_RMS^2*IecRacHot);
// [Q2.8] Thermal side of a 1 mm thicker XLPE (filler kept, every radius from the screen out
// grows 1 mm): increase of T1 and of the conductor temperature.
IecT1thick = 1/kPoly/(2*Pi)*Log[(rWireIn + 1e-3)/rCon];
dToneThick = 100*(IecT1thick/IecT1 - 1);
dTthick = (IecT1thick - IecT1)*I_RMS^2*IecRacHot;

Resolution {
  { Name MagnetoThermal;
    System {
      { Name Sys_Mag; NameOfFormulation Magnetodynamic_a_2D; Type Complex; Frequency Freq; }
      { Name Sys_The; NameOfFormulation Thermal_T; }
    }
    Operation {
      CreateDir[ResultDir];
      DeleteFile[StrCat[ResultDir,"/convergence.txt"]]; DeleteFile[StrCat[ResultDir,"/references.txt"]];
      Evaluate[$Iscale = 1];
      InitSolution[Sys_The];
      Call CoupledSolve;
      SaveSolution[Sys_Mag]; SaveSolution[Sys_The];
      PostOperation[Mag_Values]; PostOperation[The_Values];
      PostOperation[Mag_Fields]; PostOperation[Mag_Checks]; PostOperation[The_Fields];
      // References and the comparisons of this run (one "name value" per line).
      // [Q4.8] Peak |B| (mT) and |J| (A/mm2) in phase A, to compare linear and sigma(T).
      Print[{$Bmax*1e3}, Format "Bmax %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$Jmax/1e6}, Format "Jmax %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecT1},  Format "IecTone %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecT3},  Format "IecTthree %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecT4},  Format "IecTfour %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecU},   Format "IecU %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecTheta},  Format "IecTheta %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecThetaS}, Format "IecThetaS %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecAmp},    Format "IecAmp %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecRacHot*1e3}, Format "IecRcondHot %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IecRacHot*(1 + IecLamHot)*1e3}, Format "IecRacHot %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*IecLamHot}, Format "IecLamHot %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{3*I_RMS^2*IecRacHot}, Format "IecPcHot %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{3*I_RMS^2*IecRacHot*IecLamHot}, Format "IecPsHot %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{dTfiller},   Format "dTfiller %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{Hrad},       Format "Hrad %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaWd},      Format "AnaWd %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{AnaWdShare}, Format "AnaWdShare %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{dToneThick}, Format "dToneThick %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{dTthick},    Format "dTthick %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$it},        Format "Nit %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$Tc - TadmNKT}, Format "dTcNkt %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$Ts - T_amb},   Format "dTsurf %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*$Qs/($Pc + $Ps)}, Format "QsFrac %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*alphaAl*($Tc - 20)}, Format "RhoHot %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$Pc/3/(2*Pi*kPoly)*Log[rSemiIn/rCon]}, Format "dTsemi %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$TA}, Format "TcA %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$TB}, Format "TcB %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$TC}, Format "TcC %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{Fabs[$TB - $TC]}, Format "dTcBC %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{Max[$TB, $TC] - $TA}, Format "dTcAlow %.10g", File StrCat[ResultDir,"/references.txt"]];
      Test[$nrate > 0] {
        Print[{$rsum/$nrate}, Format "ConvRate %.10g", File StrCat[ResultDir,"/references.txt"]];
      }
      If (Flag_NL == 0)
        // [Q4.6] Linear model: T - T_amb scales with I^2, so the current for TadmNKT.
        Print[{I_RMS*Sqrt[(TadmNKT - T_amb)/($Tc - T_amb)]}, Format "AmpLin %.10g",
          File StrCat[ResultDir,"/references.txt"]];
      EndIf
    }
  }
}

PostProcessing {
  { Name The; NameOfFormulation Thermal_T;
    Quantity {
      { Name T; Value { Term { [ {T} ]; In Region[{Domain_The, GroundSurface}]; Jacobian Vol; } } }
      // [Q4.7] Convergence history: iteration number and relative T increment.
      { Name ConvHist; Value { Term { Type Global; [ Vector[$it, $rel, 0] ]; In GroundSurface; } } }
      // [Q4.4, Q4.5] Maxima stored in registers 4 to 8 by the prints in The_Values.
      { Name Tmax_cond; Value { Term { Type Global; [ #4 ]; In GroundSurface; } } }
      { Name Tmax_surf; Value { Term { Type Global; [ #5 ]; In GroundSurface; } } }
      { Name Tmax_A; Value { Term { Type Global; [ #6 ]; In GroundSurface; } } }
      { Name Tmax_B; Value { Term { Type Global; [ #7 ]; In GroundSurface; } } }
      { Name Tmax_C; Value { Term { Type Global; [ #8 ]; In GroundSurface; } } }
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
  { Name The_Values; NameOfPostProcessing The;
    Operation {
      // [Q4.4] Hot spot: maximum conductor temperature, overall and per phase.
      Print[T, OnElementsOf Conductors, StoreMaxInRegister 4, File StrCat[ResultDir,"/T_conductors.pos"]];
      Print[Tmax_cond, OnRegion GroundSurface, Format Table, StoreInVariable $Tc,
        SendToServer "Output/6Max conductor temperature [deg C]", File StrCat[ResultDir,"/Tmax_conductor.dat"]];
      Print[T, OnElementsOf CondA, StoreMaxInRegister 6, File StrCat[ResultDir,"/T_condA.pos"]];
      Print[T, OnElementsOf CondB, StoreMaxInRegister 7, File StrCat[ResultDir,"/T_condB.pos"]];
      Print[T, OnElementsOf CondC, StoreMaxInRegister 8, File StrCat[ResultDir,"/T_condC.pos"]];
      Print[Tmax_A, OnRegion GroundSurface, Format Table, StoreInVariable $TA, File StrCat[ResultDir,"/Tmax_condA.dat"]];
      Print[Tmax_B, OnRegion GroundSurface, Format Table, StoreInVariable $TB, File StrCat[ResultDir,"/Tmax_condB.dat"]];
      Print[Tmax_C, OnRegion GroundSurface, Format Table, StoreInVariable $TC, File StrCat[ResultDir,"/Tmax_condC.dat"]];
      // [Q4.5] Maximum ground-surface temperature and the surface profile.
      Print[T, OnElementsOf GroundSurface, StoreMaxInRegister 5, File StrCat[ResultDir,"/T_surface.pos"]];
      Print[Tmax_surf, OnRegion GroundSurface, Format Table, StoreInVariable $Ts,
        SendToServer "Output/7Max surface temperature [deg C]", File StrCat[ResultDir,"/Tmax_surface.dat"]];
      Print[T, OnLine {{-ThermalHalfWidth, BurialDepth-1e-6, 0}{ThermalHalfWidth, BurialDepth-1e-6, 0}} {500},
        Format SimpleTable, File StrCat[ResultDir,"/T_surface_profile.txt"]];
      Print[SurfaceHeat[GroundSurface], OnGlobal, Format Table, StoreInVariable $Qs,
        File StrCat[ResultDir,"/surface_heat_W_m.dat"]];
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
