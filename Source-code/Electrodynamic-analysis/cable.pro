// Section 2: electric field in the XLPE insulation (healthy or with an air void).
// Search a question tag (Q2.1 ... Q2.8) to find the block that answers it.
Include "../Cable-selection-and-model-setup/parameters.pro";
SetString["GetDP/1ResolutionChoices", "Electrodynamics"];
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
  Live = Region[{LiveA, LiveB, LiveC}];
  Electrodes = Region[{Live, 111, 112, 113}];   // 111-113: grounded core screens
}

Function {
  epsilon[XLPE] = eps0*epsXLPE;  sigma[XLPE] = sigmaXLPE;
  epsilon[Void] = eps0*epsVoid;  sigma[Void] = sigmaVoid;
}

// [Q1.4, Q2.1] Electrode voltages: peak phasors, ABC sequence; screens at 0 V.
Constraint {
  { Name ElectrodeVoltage; Type Assign; Case {
      { Region LiveA; Value Complex[Vpeak, 0]; }
      { Region LiveB; Value Complex[Vpeak*Cos[-2*Pi/3], Vpeak*Sin[-2*Pi/3]]; }
      { Region LiveC; Value Complex[Vpeak*Cos[ 2*Pi/3], Vpeak*Sin[ 2*Pi/3]]; }
      { Region Region[{111, 112, 113}]; Value 0; }
  } }
}

Jacobian { { Name Vol; Case { { Region All; Jacobian Vol; } } } }
Integration { { Name I1; Case { { Type Gauss; Case { { GeoElement Triangle; NumberOfPoints 4; } } } } } }

// [Q2.3] Linear nodal v: E = -grad v is constant in each triangle.
// [Q2.6] All nodes of one electrode share one coefficient (BF_GroupOfNodes): its value is
// the electrode voltage U; its dual I is the total current injected into the XLPE there.
FunctionSpace {
  { Name Hgrad_v; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef vn; Function BF_Node;
        Support Domain_Ele; Entity NodesOf[All, Not Electrodes]; }
      { Name sf; NameOfCoef vf; Function BF_GroupOfNodes;
        Support Domain_Ele; Entity GroupsOfNodesOf[Electrodes]; } }
    GlobalQuantity {
      { Name U; Type AliasOf; NameOfCoef vf; }
      { Name I; Type AssociatedWith; NameOfCoef vf; } }
    Constraint {
      { NameOfCoef U; EntityType GroupsOfNodesOf; NameOfConstraint ElectrodeVoltage; } }
  }
}

// [Q2.1] Weak form of -div((sigma + j omega eps) grad v) = 0 (DtDof = j omega).
// [Q2.6] The GlobalTerm is the boundary integral of the weak form: the electrode current I.
Formulation {
  { Name Electrodynamics_v; Type FemEquation;
    Quantity {
      { Name v; Type Local;  NameOfSpace Hgrad_v; }
      { Name U; Type Global; NameOfSpace Hgrad_v [U]; }
      { Name I; Type Global; NameOfSpace Hgrad_v [I]; } }
    Equation {
      Galerkin { [ sigma[] * Dof{d v}, {d v} ]; In Domain_Ele; Jacobian Vol; Integration I1; }
      Galerkin { DtDof[ epsilon[] * Dof{d v}, {d v} ]; In Domain_Ele; Jacobian Vol; Integration I1; }
      GlobalTerm { [ -Dof{I}, {U} ]; In Electrodes; }
    }
  }
}

Resolution {
  { Name Electrodynamics;
    System { { Name Sys_Ele; NameOfFormulation Electrodynamics_v; Type Complex; Frequency Freq; } }
    Operation {
      CreateDir[ResultDir];
      Generate[Sys_Ele]; Solve[Sys_Ele]; SaveSolution[Sys_Ele];
      PostOperation[Ele];
    }
  }
}

PostProcessing {
  { Name Ele; NameOfFormulation Electrodynamics_v;
    Quantity {
      { Name v;  Value { Term { [ {v} ]; In Domain_Ele; Jacobian Vol; } } }
      { Name em; Value { Term { [ Norm[-{d v}] ]; In Domain_Ele; Jacobian Vol; } } }
      // [Q2.6] Radial insulation currents (A/m2, peak): conduction and displacement.
      { Name jc; Value { Term { [ Norm[-sigma[]*{d v}] ]; In Domain_Ele; Jacobian Vol; } } }
      { Name jd; Value { Term { [ Norm[-epsilon[]*Dt[{d v}]] ]; In Domain_Ele; Jacobian Vol; } } }
      { Name I;  Value { Term { [ {I} ]; In Electrodes; } } }
      // [Q2.7] Capacitance per phase from the electrode charge: C = Im(I/U)/omega (uF/km).
      { Name C_charge; Value { Term { [ Im[{I}/{U}]/(2*Pi*Freq)*1e9 ]; In Live; } } }
      // [Q2.7] Capacitance from field energy, 3-phase average: int eps |E|^2 / (3 Vpeak^2).
      { Name C_energy; Value { Integral { [ epsilon[]*SquNorm[{d v}]/(3*Vpeak^2)*1e9 ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
      // [Q2.4] Largest element |E| (register 1, filled by the field_norm print), kV/mm.
      { Name Emax; Value { Term { Type Global; [ #1*1e-6 ]; In Live; } } }
    }
  }
}

PostOperation {
  { Name Ele; NameOfPostProcessing Ele;
    Operation {
      Print[v,  OnElementsOf Domain_Ele, Name "v [V]", File StrCat[ResultDir,"/potential.pos"]];
      Print[jc, OnElementsOf Domain_Ele, Name "|J cond| [A/m2]", File StrCat[ResultDir,"/conduction_current.pos"]];
      Print[jd, OnElementsOf Domain_Ele, Name "|J disp| [A/m2]", File StrCat[ResultDir,"/displacement_current.pos"]];
      Print[em, OnElementsOf Domain_Ele, Name "|E| [V/m]", StoreMaxInRegister 1,
        File StrCat[ResultDir,"/field_norm.pos"]];
      Print[Emax, OnRegion LiveA, Format Table, SendToServer "Output/2Max field [kV per mm, peak]",
        File StrCat[ResultDir,"/max_field_kV_mm.dat"]];
      // [Q2.6] Per phase, I(live) + I(ground) must vanish. Order: 101-103, 111-113.
      Print[I, OnRegion Electrodes, Format Table, File StrCat[ResultDir,"/electrode_currents.dat"]];
      Print[C_charge, OnRegion Live, Format Table, File StrCat[ResultDir,"/capacitance_charge_uF_km.dat"]];
      Print[C_energy[Domain_Ele], OnGlobal, Format Table, SendToServer "Output/1Capacitance [uF per km]",
        File StrCat[ResultDir,"/capacitance_uF_km.dat"]];
      // [Q2.4, Q2.5, Q2.8] |E| along phase A's +x radius (through the void), 1 um inside XLPE.
      Print[em, OnLine {{xA+rSemiIn+1e-6, yA, 0}{xA+rXLPEOut-1e-6, yA, 0}} {1600},
        Format SimpleTable, File StrCat[ResultDir,"/radial_field_A.txt"]];
    }
  }
}
