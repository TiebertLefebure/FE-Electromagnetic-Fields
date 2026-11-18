// A_z and one longitudinal potential gradient per massive region.
Include "settings.inc";
DefineConstant[ResultDir = {"results/baseline", Name "Output/Directory"}];
Include "../shared/Jacobian_Integration.pro";
Group {
  Phases = Region[{100,200,300}];
  Copper = Region[{105,205,305}];
  Semi = Region[{101,103,104,201,203,204,301,303,304}];
  Insulation = Region[{102,106,202,206,302,306}];
  Soil = Region[900]; Boundary = Region[901];
  Domain = Region[{Phases,Copper,Semi,Insulation,Soil}];
  Massive = Region[{Copper,Soil}];
  Strands = Region[{}];
  CurrentDriven = Region[{}];
  If (Detailed)
    Massive += Region[Semi];
    CurrentDriven += Region[Semi];
  EndIf
  If (Stranded)
    Strands += Region[Phases];
  Else
    Massive += Region[Phases];
    CurrentDriven += Region[Phases];
  EndIf
  If (SinglePoint)
    CurrentDriven += Region[Copper];
  EndIf
}
Function {
  sigma[Phases] = SigmaAl;
  If (Screens)
    sigma[Copper] = SigmaCu;
  Else
    sigma[Copper] = 1e-12;
  EndIf
  sigma[Semi] = SigmaSC;
  sigma[Soil] = SigmaSoil;
  source[Region[100]] = Vector[0,0,Ipeak/PhaseArea];
  source[Region[200]] = Vector[0,0,Complex[-Ipeak/2,-Sqrt[3]*Ipeak/2]/PhaseArea];
  source[Region[300]] = Vector[0,0,Complex[-Ipeak/2,Sqrt[3]*Ipeak/2]/PhaseArea];
}
Constraint {
  { Name FarField; Type Assign;
    Case { { Region Boundary; Value 0; } }
  }
  { Name CurrentConstraint; Type Assign;
    Case {
      If (!Stranded)
        { Region Region[100]; Value Ipeak; }
        { Region Region[200]; Value Complex[-Ipeak/2,-Sqrt[3]*Ipeak/2]; }
        { Region Region[300]; Value Complex[-Ipeak/2,Sqrt[3]*Ipeak/2]; }
      EndIf
      If (SinglePoint)
        { Region Copper; Value 0; }
      EndIf
      If (Detailed)
        { Region Semi; Value 0; }
      EndIf
    }
  }
  { Name GradientConstraint; Type Assign;
    Case {
      { Region Soil; Value 0; }
      If (!SinglePoint)
        { Region Copper; Value 0; }
      EndIf
    }
  }
}
FunctionSpace {
  { Name VectorPotential; Type Form1P;
    BasisFunction {
      { Name n; NameOfCoef an; Function BF_PerpendicularEdge;
        Support Domain; Entity NodesOf[All]; }
    }
    Constraint { { NameOfCoef an; EntityType NodesOf; NameOfConstraint FarField; } }
  }
  { Name Gradient; Type Form1P;
    BasisFunction {
      { Name r; NameOfCoef g; Function BF_RegionZ;
        Support Massive; Entity Massive; }
    }
    GlobalQuantity {
      { Name G; Type AliasOf; NameOfCoef g; }
      { Name I; Type AssociatedWith; NameOfCoef g; }
    }
    Constraint {
      { NameOfCoef G; EntityType Region; NameOfConstraint GradientConstraint; }
      { NameOfCoef I; EntityType Region; NameOfConstraint CurrentConstraint; }
    }
  }
}
Formulation {
  { Name Magnetic; Type FemEquation;
    Quantity {
      { Name a; Type Local; NameOfSpace VectorPotential; }
      { Name g; Type Local; NameOfSpace Gradient; }
      { Name G; Type Global; NameOfSpace Gradient[G]; }
      { Name I; Type Global; NameOfSpace Gradient[I]; }
    }
    Equation {
      Galerkin { [ Dof{d a}/Mu0, {d a} ]; In Domain; Jacobian Vol; Integration I1; }
      Galerkin { DtDof [ sigma[]*Dof{a}, {a} ]; In Massive; Jacobian Vol; Integration I1; }
      Galerkin { [ sigma[]*Dof{g}, {a} ]; In Massive; Jacobian Vol; Integration I1; }
      Galerkin { DtDof [ sigma[]*Dof{a}, {g} ]; In Massive; Jacobian Vol; Integration I1; }
      Galerkin { [ sigma[]*Dof{g}, {g} ]; In Massive; Jacobian Vol; Integration I1; }
      GlobalTerm { [ Dof{I}, {G} ]; In CurrentDriven; }
      Galerkin { [ -source[], {a} ]; In Strands; Jacobian Vol; Integration I1; }
    }
  }
}
Resolution {
  { Name SolveMagnetic;
    System { { Name Sys; NameOfFormulation Magnetic; Type Complex; Frequency Freq; } }
    Operation { Generate[Sys]; Solve[Sys]; SaveSolution[Sys]; }
  }
}
PostProcessing {
  { Name Fields; NameOfFormulation Magnetic;
    Quantity {
      { Name az; Value { Term { [ CompZ[{a}] ]; In Domain; Jacobian Vol; } } }
      { Name gradient; Value { Term { [ {G} ]; In Massive; } } }
      { Name current; Value { Term { [ {I} ]; In Massive; } } }
    }
  }
}
PostOperation {
  { Name Export; NameOfPostProcessing Fields;
    Operation {
      Print[az, OnElementsOf Domain, Format NodeTable, File StrCat[ResultDir,"/potential.txt"]];
      Print[gradient, OnRegion Massive, Format Table, File StrCat[ResultDir,"/gradients.txt"]];
      Print[current, OnRegion Massive, Format Table, File StrCat[ResultDir,"/currents.txt"]];
    }
  }
}
