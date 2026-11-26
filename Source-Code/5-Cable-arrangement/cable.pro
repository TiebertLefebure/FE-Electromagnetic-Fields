// Section 5 (own choice): arrangement (trefoil, flat touching, flat 70 mm apart) x screen
// bonding (both ends, single point). The coupled model of Section 4 is included unchanged;
// this file adds the FE ampacity: the current that brings the hottest conductor to TadmNKT.
// Choose the case with the ONELAB parameters Formation, JacketGap and Flag_Bonding.
Include "../4-Magnetothermal-analysis/cable.pro";
SetString["GetDP/1ResolutionChoices", "Ampacity"];
DefineConstant[
  Amp_tol = {0.01, Name "Thermal/24 Ampacity: tolerance on the hot spot [K]"},
  Amp_maxit = {10, Name "Thermal/25 Ampacity: maximum secant steps"}
];

// NKT rating of the same arrangement and bonding (in ground, 15 C, 1 m, 1.2 K m/W).
If (Formation == 0)
  IampNKT = IampTrefoil;  If (Flag_Bonding == 1) IampNKT = IampTrefoilSP; EndIf
ElseIf (JacketGap < 35)
  IampNKT = IampFlat;     If (Flag_Bonding == 1) IampNKT = IampFlatSP; EndIf
Else
  IampNKT = IampFlat70;   If (Flag_Bonding == 1) IampNKT = IampFlat70SP; EndIf
EndIf

Resolution {
  { Name Ampacity;
    System {
      { Name Sys_Mag; NameOfFormulation Magnetodynamic_a_2D; Type Complex; Frequency Freq; }
      { Name Sys_The; NameOfFormulation Thermal_T; }
    }
    Operation {
      CreateDir[ResultDir];
      DeleteFile[StrCat[ResultDir,"/convergence.txt"]]; DeleteFile[StrCat[ResultDir,"/references.txt"]];
      // 1) Coupled solution at I_RMS (350 A): all values (.dat) and maps (.pos) of this case.
      Evaluate[$Iscale = 1];
      InitSolution[Sys_The];
      Call CoupledSolve;
      SaveSolution[Sys_Mag]; SaveSolution[Sys_The];
      PostOperation[Mag_Values]; PostOperation[The_Values];
      PostOperation[Mag_Fields]; PostOperation[The_Fields];
      // 2) Secant method on s = (I/I_RMS)^2 for T_max(s) = TadmNKT; T_max is close to linear
      //    in s. First guess: T_max - T_amb proportional to I^2. Each step is a full coupled
      //    solve with sigma(T) (loss source scaled by s, see Section 4).
      Evaluate[$s0 = 1, $T0 = $Tc, $s1 = (TadmNKT - T_amb)/($Tc - T_amb), $k = 1];
      Evaluate[$Iscale = Sqrt[$s1]];
      Call CoupledSolve; PostOperation[The_Hot];
      Evaluate[$T1 = $Tc];
      While[Fabs[$T1 - TadmNKT] > Amp_tol && $k < Amp_maxit] {
        Evaluate[$s2 = $s1 + (TadmNKT - $T1)*($s1 - $s0)/($T1 - $T0)];
        Evaluate[$s0 = $s1, $T0 = $T1, $s1 = $s2, $Iscale = Sqrt[$s2], $k = $k + 1];
        Call CoupledSolve; PostOperation[The_Hot];
        Evaluate[$T1 = $Tc];
      }
      Print[{I_RMS*Sqrt[$s1]}, Format "Amp %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{IampNKT}, Format "AmpNKT %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{100*(I_RMS*Sqrt[$s1]/IampNKT - 1)}, Format "dNkt %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$T1}, Format "TcAmp %.10g", File StrCat[ResultDir,"/references.txt"]];
      Print[{$k}, Format "AmpSteps %.10g", File StrCat[ResultDir,"/references.txt"]];
    }
  }
}

PostOperation {
  // Hot spot of each secant step (the files end with the value at the ampacity).
  { Name The_Hot; NameOfPostProcessing The;
    Operation {
      Print[T, OnElementsOf Conductors, StoreMaxInRegister 4, File StrCat[ResultDir,"/T_conductors_amp.pos"]];
      Print[Tmax_cond, OnRegion GroundSurface, Format Table, StoreInVariable $Tc,
        SendToServer "Output/8Max conductor temperature at the ampacity [deg C]",
        File StrCat[ResultDir,"/Tmax_conductor_amp.dat"]];
    }
  }
}
