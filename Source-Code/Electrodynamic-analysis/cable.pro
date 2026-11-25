// Section 2: electric field in the XLPE insulation (healthy or with an air void).
// Course files, included unchanged: Jacobian_Integration.pro (Jacobians, Gauss rules) and
// electrodynamic_formulation.pro (function space Hgrad_v_Ele, weak form Electrodynamics_v,
// post-processing quantities EleDyn_v). This file defines the cable problem and its outputs.
// Search a question tag (Q2.1 ... Q2.8) to find the block that answers it.
Include "../Cable-selection-and-model-setup/parameters.pro";
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

Include "../Cable-selection-and-model-setup/Jacobian_Integration.pro";
Include "electrodynamic_formulation.pro";

Resolution {
  { Name Electrodynamics_cable;
    System { { Name Sys_Ele; NameOfFormulation Electrodynamics_v; Type Complex; Frequency Freq; } }
    Operation {
      CreateDir[ResultDir];
      Generate[Sys_Ele]; Solve[Sys_Ele]; SaveSolution[Sys_Ele];
      PostOperation[Ele_Fields]; PostOperation[Ele_Values];
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
      // [Q2.7] Capacitance per phase from that current (charge): C = Im(I/V)/omega (uF/km).
      { Name C_charge; Value { Integral {
            [ Im[(sigma[]*{d v} + epsilon[]*Dt[{d v}]) * {d v} / Vph[]^2]/(2*Pi*Freq)*1e9 ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
      // [Q2.7] Capacitance from field energy, 3-phase average: int eps |E|^2 / (3 Vpeak^2).
      { Name C_energy; Value { Integral { [ epsilon[]*SquNorm[{d v}]/(3*Vpeak^2)*1e9 ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
      // [Q2.4] Largest element |E| (register 1, filled by the field_norm print), kV/mm.
      { Name Emax; Value { Term { Type Global; [ #1*1e-6 ]; In LiveA; } } }
    }
  }
}

PostOperation {
  { Name Ele_Fields; NameOfPostProcessing EleDyn_v;   // course quantities
    Operation {
      Print[v,  OnElementsOf Domain_Ele, Name "v [V]", File StrCat[ResultDir,"/potential.pos"]];
      Print[jm, OnElementsOf Domain_Ele, Name "|J cond| [A/m2]", File StrCat[ResultDir,"/conduction_current.pos"]];
      Print[em, OnElementsOf Domain_Ele, Name "|E| [V/m]", StoreMaxInRegister 1,
        File StrCat[ResultDir,"/field_norm.pos"]];
      // [Q2.4, Q2.5, Q2.8] |E| along phase A's +x radius (through the void), 1 um inside XLPE.
      Print[em, OnLine {{xA+rSemiIn+1e-6, yA, 0}{xA+rXLPEOut-1e-6, yA, 0}} {1600},
        Format SimpleTable, File StrCat[ResultDir,"/radial_field_A.txt"]];
    }
  }
  { Name Ele_Values; NameOfPostProcessing Ele_Cable;
    Operation {
      Print[jd, OnElementsOf Domain_Ele, Name "|J disp| [A/m2]", File StrCat[ResultDir,"/displacement_current.pos"]];
      Print[Emax, OnRegion LiveA, Format Table, SendToServer "Output/2Max field [kV per mm, peak]",
        File StrCat[ResultDir,"/max_field_kV_mm.dat"]];
      Print[I[PhaseA], OnGlobal, Format Table, File StrCat[ResultDir,"/electrode_current_A.dat"]];
      Print[C_charge[PhaseA], OnGlobal, Format Table, File StrCat[ResultDir,"/capacitance_charge_uF_km.dat"]];
      Print[C_energy[Domain_Ele], OnGlobal, Format Table, SendToServer "Output/1Capacitance [uF per km]",
        File StrCat[ResultDir,"/capacitance_uF_km.dat"]];
    }
  }
}
