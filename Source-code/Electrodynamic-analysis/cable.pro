// 185 mm2 screened-XLPE electric model (Section 2).
// Question map: Q2.1 domain/equation/BCs; Q2.2 ideal screens; Q2.3 linear FE;
// Q2.4 field stress; Q2.5 air void; Q2.6 currents + balance; Q2.7 capacitance;
// Q2.8 thickness trial. Search for a tag (e.g. Q2.6) to find the relevant block.
Include "../Cable-selection-and-model-setup/parameters.pro";
// [Q2.1 - GMSH RUN BUTTON] The resolution already runs Ele_Maps, so use -solve.
SetString["GetDP/1ResolutionChoices", "Electrodynamics"];
SetString["GetDP/9ComputeCommand", "-solve"];
// [OUTPUT] Override with -setstring ResultDir results/case-name to keep a run.
DefineConstant[ResultDir = {"res", Name "Output/Directory"}];

// [Q2.1, Q2.2] Computational domain: the three XLPE annuli (+ the void if present).
// The semiconductors are ideal equipotentials, so the inner XLPE boundary carries
// the phase voltage and the outer XLPE boundary is grounded. Everything outside
// the grounded screens cannot influence the field in the insulation.
Group {
  XLPE = Region[{41,42,43}];
  Void = Region[{44}];                    // empty when Flag_Defect = 0
  Domain_Ele = Region[{XLPE, Void}];
  LiveA = Region[101]; LiveB = Region[102]; LiveC = Region[103];
  GroundA = Region[111]; GroundB = Region[112]; GroundC = Region[113];
  Live = Region[{LiveA, LiveB, LiveC}];
  // [Q2.6] Each boundary is one "electrode": one global voltage U and current I.
  Electrodes = Region[{Live, GroundA, GroundB, GroundC}];
}

// [Q2.1] Constitutive laws. [Q2.6] sigma vs omega*epsilon sets the current ratio.
Function {
  epsilon[XLPE] = eps0*epsXLPE;
  sigma[XLPE] = sigmaXLPE;
  epsilon[Void] = eps0*epsVoid;
  sigma[Void] = sigmaVoid;
}

// [Q2.1, Q1.4] Dirichlet conditions as electrode voltages (peak phasors, ABC).
Constraint {
  { Name ElectrodeVoltage; Type Assign;
    Case {
      { Region LiveA; Value Complex[Vpeak, 0]; }
      { Region LiveB; Value Complex[Vpeak*Cos[-2*Pi/3], Vpeak*Sin[-2*Pi/3]]; }
      { Region LiveC; Value Complex[Vpeak*Cos[ 2*Pi/3], Vpeak*Sin[ 2*Pi/3]]; }
      { Region GroundA; Value 0; }
      { Region GroundB; Value 0; }
      { Region GroundC; Value 0; }
    }
  }
}

Jacobian {
  { Name Vol; Case { { Region All; Jacobian Vol; } } }
}
Integration {
  { Name I1; Case { { Type Gauss; Case {
      { GeoElement Triangle; NumberOfPoints 4; }
      { GeoElement Quadrangle; NumberOfPoints 4; } } } } }
}

// [Q2.3] Linear nodal potential: E = -grad v is constant within each triangle.
// [Q2.6] All nodes of one electrode share ONE coefficient (BF_GroupOfNodes):
// its value is the electrode voltage U, and its associated quantity I is the
// total (conduction + displacement) current injected into the XLPE there.
FunctionSpace {
  { Name Hgrad_v_Ele; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef vn; Function BF_Node;
        Support Domain_Ele; Entity NodesOf[All, Not Electrodes]; }
      { Name sf; NameOfCoef vf; Function BF_GroupOfNodes;
        Support Domain_Ele; Entity GroupsOfNodesOf[Electrodes]; }
    }
    GlobalQuantity {
      { Name U; Type AliasOf; NameOfCoef vf; }
      { Name I; Type AssociatedWith; NameOfCoef vf; }
    }
    Constraint {
      { NameOfCoef U; EntityType GroupsOfNodesOf; NameOfConstraint ElectrodeVoltage; }
    }
  }
}

// [Q2.1] Weak form of -div((sigma + j*omega*epsilon) grad v) = 0.
// DtDof gives the j*omega factor; phasors use exp(j*omega*t), peak values.
// [Q2.6] The boundary term of the weak form is the electrode current I.
Formulation {
  { Name Electrodynamics_v; Type FemEquation;
    Quantity {
      { Name v; Type Local;  NameOfSpace Hgrad_v_Ele; }
      { Name U; Type Global; NameOfSpace Hgrad_v_Ele [U]; }
      { Name I; Type Global; NameOfSpace Hgrad_v_Ele [I]; }
    }
    Equation {
      Galerkin { [ sigma[] * Dof{d v}, {d v} ];
        In Domain_Ele; Jacobian Vol; Integration I1; }
      Galerkin { DtDof[ epsilon[] * Dof{d v}, {d v} ];
        In Domain_Ele; Jacobian Vol; Integration I1; }
      GlobalTerm { [ -Dof{I}, {U} ]; In Electrodes; }
    }
  }
}

Resolution {
  { Name Electrodynamics;
    System {
      { Name Sys_Ele; NameOfFormulation Electrodynamics_v;
        Type Complex; Frequency Freq; }
    }
    Operation {
      CreateDir[ResultDir];
      Generate[Sys_Ele]; Solve[Sys_Ele]; SaveSolution[Sys_Ele];
      PostOperation[Ele_Maps];
    }
  }
}

PostProcessing {
  { Name EleDyn_v; NameOfFormulation Electrodynamics_v;
    Quantity {
      // [Q2.1] Potential map: checks the imposed phase and screen voltages.
      { Name v; Value { Term { [ {v} ]; In Domain_Ele; Jacobian Vol; } } }
      // [Q2.3, Q2.4, Q2.5] Field vector and peak-phasor norm (V/m).
      { Name e;  Value { Term { [ -{d v} ]; In Domain_Ele; Jacobian Vol; } } }
      { Name em; Value { Term { [ Norm[-{d v}] ]; In Domain_Ele; Jacobian Vol; } } }
      // [Q2.6] Conduction sigma*E and displacement j*omega*epsilon*E (A/m2, peak).
      // These are RADIAL insulation currents, not the 350 A axial load current.
      { Name jCond; Value { Term { [ -sigma[]*{d v} ]; In Domain_Ele; Jacobian Vol; } } }
      { Name jDisp; Value { Term { [ -epsilon[]*Dt[{d v}] ]; In Domain_Ele; Jacobian Vol; } } }
      { Name jDispNorm; Value { Term { [ Norm[-epsilon[]*Dt[{d v}]] ]; In Domain_Ele; Jacobian Vol; } } }
      // [Q2.6] Electrode voltage and injected current per unit length (V, A/m peak).
      { Name U; Value { Term { [ {U} ]; In Electrodes; } } }
      { Name I; Value { Term { [ {I} ]; In Electrodes; } } }
      // [Q2.7] Capacitance per phase from the electrode charge: C = Im(I/U)/omega.
      { Name C_charge_uF_km; Value {
          Term { [ Im[{I}/{U}]/(2*Pi*Freq)*1e9 ]; In Live; } } }
      // [Q2.3, Q2.4] Maximum |E| over all elements, read from register #1 (kV/mm).
      { Name Emax_kV_mm; Value { Term { Type Global; [ #1*1e-6 ]; In Live; } } }
      // [Q2.7] Capacitance from field energy, averaged over the 3 phases:
      // C = sum(int eps |E|^2) / (3 Vpeak^2), converted from F/m to uF/km.
      { Name C_energy_uF_km; Value {
          Integral { [ epsilon[]*SquNorm[{d v}]/(3*Vpeak^2)*1e9 ];
            In Domain_Ele; Jacobian Vol; Integration I1; } } }
    }
  }
}

PostOperation {
  { Name Ele_Maps; NameOfPostProcessing EleDyn_v;
    Operation {
      Print[v, OnElementsOf Domain_Ele, Name "v [V]", File StrCat[ResultDir,"/potential.pos"]];
      Print[e, OnElementsOf Domain_Ele, Name "E [V/m]", File StrCat[ResultDir,"/electric_field.pos"]];
      Print[jCond, OnElementsOf Domain_Ele, Name "J cond [A/m2]",
        File StrCat[ResultDir,"/conduction_current.pos"]];
      Print[jDisp, OnElementsOf Domain_Ele, Name "J disp [A/m2]",
        File StrCat[ResultDir,"/displacement_current.pos"]];
      Print[jDispNorm, OnElementsOf Domain_Ele, Name "|J disp| [A/m2]",
        File StrCat[ResultDir,"/displacement_current_norm.pos"]];
      // [Q2.6] Current balance: per phase, I(live) + I(ground) must be 0.
      Print[I, OnRegion Electrodes, Format Table, File StrCat[ResultDir,"/electrode_currents.dat"]];
      // [Q2.7] Two independent capacitance extractions (uF/km per phase).
      Print[C_charge_uF_km, OnRegion Live, Format Table,
        File StrCat[ResultDir,"/capacitance_charge_uF_km.dat"]];
      Print[C_energy_uF_km[Domain_Ele], OnGlobal, Format Table,
        SendToServer "Output/1Capacitance [uF per km]",
        File StrCat[ResultDir,"/capacitance_uF_km.dat"]];
      // [Q2.4, Q2.5, Q2.8] Phase-A radial cut along +x (through the void if present),
      // 1 um inside each XLPE boundary to avoid ambiguous lookup on an interface.
      Print[em, OnLine {{xA+rSemiIn+1e-6, yA, 0}{xA+rXLPEOut-1e-6, yA, 0}} {1600},
        Format SimpleTable, File StrCat[ResultDir,"/radial_field_A.txt"]];
      Print[em, OnLine {{xA+rSemiIn+1e-6, yA, 0}{xA+rXLPEOut-1e-6, yA, 0}} {400},
        Name "|E| radial cut phase A [V/m]", File StrCat[ResultDir,"/radial_field_A.pos"]];
      // [Q2.3, Q2.4] Maximum field: the GUI shows the map range; the register
      // keeps the largest element value, sent to the ONELAB panel in kV/mm.
      Print[em, OnElementsOf Domain_Ele, Name "|E| [V/m]", StoreMaxInRegister 1,
        File StrCat[ResultDir,"/field_norm.pos"]];
      Print[Emax_kV_mm, OnRegion LiveA, Format Table,
        SendToServer "Output/2Max field [kV per mm, peak]",
        File StrCat[ResultDir,"/max_field_kV_mm.dat"]];
    }
  }
}
