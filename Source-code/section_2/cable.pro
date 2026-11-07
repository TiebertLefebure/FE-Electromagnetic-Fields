// Derived from the TA electrodynamic_formulation.pro (kept unchanged).
// Solves div((sigma+j*omega*epsilon)*grad(v)) = 0 with peak ABC phasors.
// The 415 A longitudinal load is NOT an excitation of this transverse problem.
Include "settings.inc";
DefineConstant[ResultDir = {"res", Name "Output/Directory"}];
Include "../shared/Jacobian_Integration.pro";
Group {
  SC = Region[{101,103,104,201,203,204,301,303,304}];
  XLPE = Region[{102,202,302}];
  Void = Region[106];
  Domain = Region[{SC,XLPE,Void}];
  HV_A = Region[1001]; HV_B = Region[1101]; HV_C = Region[1201];
  Ground = Region[{1002,1102,1202}];
}
Function {
  epsilon[SC] = Eps0*EpsSC; sigma[SC] = SigSC;
  epsilon[XLPE] = Eps0*EpsXLPE; sigma[XLPE] = SigXLPE;
  epsilon[Void] = Eps0*EpsVoid; sigma[Void] = SigVoid;
  voltageA[] = Complex[Vpeak,0];
  voltageB[] = Complex[-Vpeak/2,-Sqrt[3]*Vpeak/2];
  voltageC[] = Complex[-Vpeak/2,Sqrt[3]*Vpeak/2];
}
Constraint {
  { Name Voltage; Type Assign;
    Case {
      { Region HV_A; Value voltageA[]; }
      { Region HV_B; Value voltageB[]; }
      { Region HV_C; Value voltageC[]; }
      { Region Ground; Value 0; }
    }
  }
}
FunctionSpace {
  { Name Hgrad_v; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef vn; Function BF_Node;
        Support Domain; Entity NodesOf[All]; }
    }
    Constraint {
      { NameOfCoef vn; EntityType NodesOf; NameOfConstraint Voltage; }
    }
  }
}
Formulation {
  { Name Electrodynamics_v; Type FemEquation;
    Quantity { { Name v; Type Local; NameOfSpace Hgrad_v; } }
    Equation {
      Galerkin { [ sigma[]*Dof{d v}, {d v} ];
        In Domain; Jacobian Vol; Integration I1; }
      Galerkin { DtDof [ epsilon[]*Dof{d v}, {d v} ];
        In Domain; Jacobian Vol; Integration I1; }
    }
  }
}
Resolution {
  { Name Electrodynamics;
    System {
      { Name Sys; NameOfFormulation Electrodynamics_v; Type Complex; Frequency Freq; }
    }
    Operation { Generate[Sys]; Solve[Sys]; SaveSolution[Sys]; }
  }
}
PostProcessing {
  { Name Fields; NameOfFormulation Electrodynamics_v;
    Quantity {
      { Name v; Value { Term { [ {v} ]; In Domain; Jacobian Vol; } } }
      { Name vReal; Value { Term { [ Re[{v}]/1000 ]; In Domain; Jacobian Vol; } } }
      // Explicit conjugate norm: a nonnegative phasor magnitude for every phase.
      { Name Epeak; Value { Term {
        [ Sqrt[SquNorm[Re[{d v}]]+SquNorm[Im[{d v}]]]/1e6 ];
        In Domain; Jacobian Vol; } } }
      { Name EReal; Value { Term { [ -Re[{d v}]/1e6 ]; In Domain; Jacobian Vol; } } }
      { Name Jconductive; Value { Term {
        [ sigma[]*Sqrt[SquNorm[Re[{d v}]]+SquNorm[Im[{d v}]]] ];
        In Domain; Jacobian Vol; } } }
      { Name Jdisplacement; Value { Term {
        [ 2*Pi*Freq*epsilon[]*Sqrt[SquNorm[Re[{d v}]]+SquNorm[Im[{d v}]]] ];
        In Domain; Jacobian Vol; } } }
    }
  }
}
PostOperation {
  { Name Export; NameOfPostProcessing Fields;
    Operation {
      CreateDir[ResultDir];
      Print[vReal, OnElementsOf Domain, File StrCat[ResultDir,"/potential_real.pos"], Name "Re(V) [kV]"];
      Print[Epeak, OnElementsOf Domain, File StrCat[ResultDir,"/e_peak.pos"], Name "|E phasor| [kV/mm]"];
      Print[EReal, OnElementsOf Domain, File StrCat[ResultDir,"/e_real.pos"], Name "Re(E) [kV/mm]"];
      Print[Jconductive, OnElementsOf Domain, File StrCat[ResultDir,"/j_conduction.pos"], Name "|J conduction| [A/m2]"];
      Print[Jdisplacement, OnElementsOf Domain, File StrCat[ResultDir,"/j_displacement.pos"], Name "|J displacement| [A/m2]"];
      Print[v, OnElementsOf Domain, Format NodeTable, File StrCat[ResultDir,"/potential_nodes.txt"]];
    }
  }
}

PostOperation {
  { Name Nodes; NameOfPostProcessing Fields;
    Operation {
      CreateDir[ResultDir];
      Print[v, OnElementsOf Domain, Format NodeTable, File StrCat[ResultDir,"/potential_nodes.txt"]];
    }
  }
}
