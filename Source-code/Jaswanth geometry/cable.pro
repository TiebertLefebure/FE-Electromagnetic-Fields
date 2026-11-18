// 185 mm2 screened-XLPE electric model.
Include "parameters.pro";

Group {
  PhaseA = Region[41]; PhaseB = Region[42]; PhaseC = Region[43];
  Domain_Ele = Region[{41,42,43}];
  LiveA = Region[101]; LiveB = Region[102]; LiveC = Region[103];
  ScreenGround = Region[110];
}

Function {
  epsilon[Domain_Ele] = eps0*epsXLPE;
  sigma[Domain_Ele] = sigmaXLPE;
}

Constraint {
  { Name ElectricScalarPotential; Type Assign;
    Case {
      { Region LiveA; Value Complex[Vpeak, 0]; }
      { Region LiveB; Value Complex[Vpeak*Cos[-2*Pi/3], Vpeak*Sin[-2*Pi/3]]; }
      { Region LiveC; Value Complex[Vpeak*Cos[ 2*Pi/3], Vpeak*Sin[ 2*Pi/3]]; }
      { Region ScreenGround; Value 0; }
    }
  }
}

Jacobian {
  { Name Vol; Case { { Region All; Jacobian Vol; } } }
}
Integration {
  { Name I1; Case {
      { Type Gauss; Case {
          { GeoElement Triangle; NumberOfPoints 4; }
          { GeoElement Quadrangle; NumberOfPoints 4; }
        }
      }
    }
  }
}

FunctionSpace {
  { Name Hgrad_v_Ele; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef vn; Function BF_Node;
        Support Domain_Ele; Entity NodesOf[All]; }
    }
    Constraint {
      { NameOfCoef vn; EntityType NodesOf;
        NameOfConstraint ElectricScalarPotential; }
    }
  }
}

Formulation {
  { Name Electrodynamics_v; Type FemEquation;
    Quantity { { Name v; Type Local; NameOfSpace Hgrad_v_Ele; } }
    Equation {
      Galerkin { [sigma[]*Dof{d v}, {d v}];
        In Domain_Ele; Jacobian Vol; Integration I1; }
      Galerkin { DtDof[epsilon[]*Dof{d v}, {d v}];
        In Domain_Ele; Jacobian Vol; Integration I1; }
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
      CreateDir["res"];
      Generate[Sys_Ele]; Solve[Sys_Ele]; SaveSolution[Sys_Ele];
      PostOperation[Ele_Maps];
    }
  }
}

PostProcessing {
  { Name EleDyn_v; NameOfFormulation Electrodynamics_v;
    Quantity {
      { Name v; Value {
          Term { [ {v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name e; Value {
          Term { [ -{d v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name em; Value {
          Term { [ Norm[-{d v}] ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name d; Value {
          Term { [ -epsilon[]*{d v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name jCond; Value {
          Term { [ -sigma[]*{d v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name jDisp; Value {
          Term { [ -epsilon[]*Dt[{d v}] ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name ElectricEnergy; Value {
          Integral { [ 0.5*epsilon[]*SquNorm[{d v}] ];
            In Domain_Ele; Jacobian Vol; Integration I1; }
        }
      }
    }
  }
}

PostOperation {
  { Name Ele_Maps; NameOfPostProcessing EleDyn_v;
    Operation {
      Print[v, OnElementsOf Domain_Ele, File "res/potential.pos"];
      Print[e, OnElementsOf Domain_Ele, File "res/electric_field.pos"];
      Print[em, OnElementsOf Domain_Ele, File "res/field_norm.pos"];
      Print[d, OnElementsOf Domain_Ele, File "res/displacement.pos"];
      Print[jCond, OnElementsOf Domain_Ele, File "res/conduction_current.pos"];
      Print[jDisp, OnElementsOf Domain_Ele, File "res/displacement_current.pos"];
      Print[ElectricEnergy[Domain_Ele], OnGlobal, Format Table,
        File "res/electric_energy.dat"];
      Print[em, OnLine {{xA+rSemiIn, yA, 0}{xA+rXLPEOut, yA, 0}} {101},
        File "res/radial_field_A.pos"];
    }
  }
}
