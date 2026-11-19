// 185 mm2 screened-XLPE electric model.
// Question map: Q2.1 domain/equation/BCs; Q2.2 ideal screens; Q2.3 linear FE;
// Q2.4 field stress; Q2.6 current densities; Q2.7 capacitance; Q2.8 thickness trial.
// Q2.5 defect and the Q2.6 independent boundary-flux check are not implemented.
Include "../Cable-selection-and-model-setup/parameters.pro";
// [Q2.1 - GMSH RUN BUTTON] The resolution already runs Ele_Maps, so use -solve
// without a second -pos pass. Source: GetDP's reserved ONELAB parameter names.
SetString["GetDP/1ResolutionChoices", "Electrodynamics"];
SetString["GetDP/9ComputeCommand", "-solve"];
// [OUTPUT] Override with -setstring ResultDir results/coarse, for example.
DefineConstant[ResultDir = {"res", Name "Output/Directory"}];

// [Q2.1, Q2.2] Computational domain and geometric simplification.
// JacketGap moves the three annuli without changing their radii or voltages.
// With the ideal grounded boundaries, a gap changes only the discretisation error.
// [MODEL] Only XLPE participates. The other meshed layers have no
// electric unknowns; their blank field maps do not indicate missing mesh.
Group {
  PhaseA = Region[41]; PhaseB = Region[42]; PhaseC = Region[43];
  Domain_Ele = Region[{41,42,43}];
  LiveA = Region[101]; LiveB = Region[102]; LiveC = Region[103];
  ScreenGround = Region[110];
}

// [Q2.1] Constitutive law. [Q2.6, Q2.7] Constants used in current and energy calculations.
Function {
  epsilon[Domain_Ele] = eps0*epsXLPE;
  sigma[Domain_Ele] = sigmaXLPE;
}

// [Q2.1] Dirichlet boundary conditions. [Q1.4] Apply the chosen ABC peak phasors.
// [Q2.2] Ideal semiconductors are represented by their interface potentials.
// [ASSUMPTION] Inner SC follows its phase conductor; outer SC is grounded.
// This does not impose axial screen bonding or calculate the 350 A load.
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

// [Q2.1] 2D area mapping and numerical integration for the weak equation.
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

// [Q2.3] Linear nodal potential: its gradient is constant within each triangle.
// MeshFactor is changed in parameters.pro/Gmsh; no different FE space is needed.
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

// [Q2.1] Governing weak equation. [Q2.6] Total-current conservation in weak form;
// a separate boundary-flux balance has not yet been exported.
// [COURSE] Weak form of -div((sigma+j*omega*epsilon)*grad(v)) = 0.
// DtDof becomes j*omega; phasors use exp(j*omega*t).
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

// [Q2.1] Assemble, solve and export the electric problem at the selected frequency.
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
      // [Q2.1] Potential map checks the imposed phase and screen voltages.
      { Name v; Value {
          Term { [ {v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      // [Q2.3, Q2.4, Q2.8] Electric field and peak-phasor norm for stress comparisons.
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
      // [Q2.6] Conduction current sigma*E and displacement current j*omega*epsilon*E.
      // These are radial insulation currents, not the 350 A axial load current.
      { Name jCond; Value {
          Term { [ -sigma[]*{d v} ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      { Name jDisp; Value {
          Term { [ -epsilon[]*Dt[{d v}] ]; In Domain_Ele; Jacobian Vol; }
        }
      }
      // [Q2.7] Field-energy route to per-unit-length capacitance.
      // [PEAK PHASORS] This is Wstar = 1/2 integral(eps*|Ehat|^2).
      // Mean stored energy is Wstar/2. Keep this factor when using RMS/peak data.
      { Name ElectricEnergy; Value {
          Integral { [ 0.5*epsilon[]*SquNorm[{d v}] ];
            In Domain_Ele; Jacobian Vol; Integration I1; }
        }
      }
      // [Q2.3, Q2.7] Integral output for convergence and analytical/datasheet comparisons.
      // [DERIVED] Balanced-phase average capacitance, in microfarads/km.
      // Factor 3 accounts for all three phases; Vpeak is phase-to-ground.
      { Name CapacitancePerPhase; Value {
          Integral { [ epsilon[]*SquNorm[{d v}]/(3*Vpeak^2)*1e9 ];
            In Domain_Ele; Jacobian Vol; Integration I1; }
        }
      }
    }
  }
}

// The same solve writes the outputs used by several questions; no separate solver per question.
PostOperation {
  { Name Ele_Maps; NameOfPostProcessing EleDyn_v;
    Operation {
      // [Q2.1] Inspect the domain, phase voltages and ideal grounded screens.
      Print[v, OnElementsOf Domain_Ele, File StrCat[ResultDir,"/potential.pos"]];
      Print[e, OnElementsOf Domain_Ele, File StrCat[ResultDir,"/electric_field.pos"]];
      Print[d, OnElementsOf Domain_Ele, File StrCat[ResultDir,"/displacement.pos"]];
      // [Q2.6] Compare the magnitudes of the two current-density maps (A/m2, peak).
      Print[jCond, OnElementsOf Domain_Ele, File StrCat[ResultDir,"/conduction_current.pos"]];
      Print[jDisp, OnElementsOf Domain_Ele, File StrCat[ResultDir,"/displacement_current.pos"]];
      // [Q2.7] Capacitance in microfarads/km and the defined energy quantity.
      Print[ElectricEnergy[Domain_Ele], OnGlobal, Format Table,
        File StrCat[ResultDir,"/electric_energy.dat"]];
      Print[CapacitancePerPhase[Domain_Ele], OnGlobal, Format Table,
        File StrCat[ResultDir,"/capacitance_uF_km.dat"]];
      // [Q2.4, Q2.8] Healthy phase-A radial stress cut and thickness comparison.
      // [Q2.5 - NOT IMPLEMENTED] A defect comparison needs a separate void region/material.
      // [NUMERICAL] Sample 1 micrometre inside each XLPE boundary, avoiding
      // ambiguous element lookup exactly on an interface (false zero samples).
      Print[em, OnLine {{xA+rSemiIn+1e-6, yA, 0}{xA+rXLPEOut-1e-6, yA, 0}} {101},
        File StrCat[ResultDir,"/radial_field_A.pos"]];
      // [Q2.3, Q2.4, Q2.8] Maximum field in V/m, peak; divide by 1e6 for kV/mm.
      // Print this map last so ONELAB displays the field after pressing Run.
      Print[em, OnElementsOf Domain_Ele, File StrCat[ResultDir,"/field_norm.pos"]];
    }
  }
}
