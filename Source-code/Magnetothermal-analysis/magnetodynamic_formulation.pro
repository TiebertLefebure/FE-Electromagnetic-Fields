// Course starter, kept for reference only. The runnable cable model is cable.pro
// in this folder (groups, materials, constraints and bonding added there).
// The NKT datasheet describes a SOLID aluminium conductor. Use the massive
// model for that interpretation; a uniform stranded model is a comparison.
// Question tags below identify the relevant starter blocks, NOT completed answers.
// [Q3.1] Cable-specific domain, materials and outer boundary still need to be supplied.
// [Q3.4, Q3.10] Use the 0.5 mm gap baseline and 0 mm for spacing sensitivity.
// The report estimates inductance for uniform core current with screen currents omitted.
Group{
  DefineGroup[
    DomainS0_Mag // Stranded model if imposing source with js0[]
  ];
}

FunctionSpace {

  // [Q3.1, Q3.5] Magnetic vector-potential space and selectable polynomial order.
  { Name Hcurl_a_Mag_2D; Type Form1P;
    BasisFunction {
      { Name se; NameOfCoef ae; Function BF_PerpendicularEdge;
        Support Domain_Mag; Entity NodesOf[ All ]; }
      If (Flag_Degree_a == 2)
        { Name se2; NameOfCoef ae2; Function BF_PerpendicularEdge_2E;
          Support Domain_Mag; Entity EdgesOf[ All ]; }
      EndIf
    }
    Constraint {
      { NameOfCoef ae;
        EntityType NodesOf; NameOfConstraint MagneticVectorPotential_2D; }
      If (Flag_Degree_a == 2)
	    { NameOfCoef ae2; // Only OK if homogeneous BC, otherwise specify zero-BC
          EntityType EdgesOf; NameOfConstraint MagneticVectorPotential_2D; }
      EndIf
    }
  }

  // [Q3.2] Uniform-current (stranded comparison) conductor model.
  { Name Hregion_i_2D ; Type Vector ;
    BasisFunction {
      { Name sr ; NameOfCoef ir ; Function BF_RegionZ ;
        Support DomainS_Mag ; Entity DomainS_Mag ; }
    }
    GlobalQuantity {
      { Name Is ; Type AliasOf        ; NameOfCoef ir ; }
      { Name Us ; Type AssociatedWith ; NameOfCoef ir ; }
    }
    Constraint {
      { NameOfCoef Us ; EntityType Region ; NameOfConstraint Voltage_2D ; }
      { NameOfCoef Is ; EntityType Region ; NameOfConstraint Current_2D ; }
    }
  }

  // [Q3.2, Q3.3] Massive conductors: one axial potential gradient per region.
  // Net current or voltage must be constrained to define excitation/bonding.
  // Gradient of Electric scalar potential (2D)
  { Name Hregion_u_Mag_2D ; Type Form1P ;
    BasisFunction {
      { Name sr ; NameOfCoef ur ; Function BF_RegionZ ;
        Support DomainC_Mag ; Entity DomainC_Mag ; }
    }
    GlobalQuantity {
      { Name U ; Type AliasOf        ; NameOfCoef ur ; }
      { Name I ; Type AssociatedWith ; NameOfCoef ur ; }
    }
    Constraint {
      { NameOfCoef U ;
        EntityType Region ; NameOfConstraint Voltage_2D ; }
      { NameOfCoef I ;
        EntityType Region ; NameOfConstraint Current_2D ; }
    }
  }


}

// [Q3.1] Magnetic weak equation, with both massive and uniform-current terms.
// [Q3.4] Magnetic material grouping must include the exterior, not only the XLPE.
Formulation {

  { Name Magnetodynamic_a_2D; Type FemEquation; // Magnetodynamics
    Quantity {
      { Name a;  Type Local; NameOfSpace Hcurl_a_Mag_2D; }

      // massive conductors (source or not)
      { Name ur ; Type Local  ; NameOfSpace Hregion_u_Mag_2D ; }
      { Name I  ; Type Global ; NameOfSpace Hregion_u_Mag_2D [I] ; }
      { Name U  ; Type Global ; NameOfSpace Hregion_u_Mag_2D [U] ; }

       // stranded conductors (source)
      { Name ir ; Type Local  ; NameOfSpace Hregion_i_2D ; }
      { Name Us ; Type Global ; NameOfSpace Hregion_i_2D[Us] ; }
      { Name Is ; Type Global ; NameOfSpace Hregion_i_2D[Is] ; }
    }

    Equation {
      Galerkin { [ nu[] * Dof{d a} , {d a} ];
        In Domain_Mag; Jacobian Vol; Integration I1; }
      Galerkin { DtDof [ sigma[] * Dof{a} , {a} ];
        In DomainC_Mag; Jacobian Vol; Integration I1; }

      Galerkin { [ sigma[] * Dof{ur}, {a} ] ;
        In DomainC_Mag ; Jacobian Vol ; Integration I1 ; }
      Galerkin { DtDof [ sigma[] * Dof{a} , {ur} ] ;
        In DomainC_Mag ; Jacobian Vol ; Integration I1 ; }
      Galerkin { [ sigma[] * Dof{ur}, {ur} ] ;
        In DomainC_Mag ; Jacobian Vol ; Integration I1 ; }

      // [Q3.3] Circuit closure for regions with prescribed net current.
      GlobalTerm { [ Dof{I} , {U} ] ; In DomainCWithI_Mag ; }

      // Either you impose directly the function js0[]
      Galerkin { [ -js0[] , {a} ];
        In DomainS0_Mag; Jacobian Vol; Integration I1; }

      // or you use the constraints => allows accounting for sigma[]
      Galerkin { [ -Ns[]/Sc[] * Dof{ir}, {a} ] ;
        In DomainS_Mag ; Jacobian Vol ; Integration I1 ; }
      Galerkin { DtDof [ Ns[]/Sc[] * Dof{a}, {ir} ] ;
        In DomainS_Mag ; Jacobian Vol ; Integration I1 ; }

      Galerkin { [ Ns[]/Sc[] / sigma[] * Ns[]/Sc[]* Dof{ir} , {ir} ] ; // resistance term
        In DomainS_Mag ; Jacobian Vol ; Integration I1 ; }
      //GlobalTerm { [ Rdc * Dof{Is} , {Is} ] ; In DomainS ; } // OR this resitance term
      GlobalTerm { [ Dof{Us}, {Is} ] ; In DomainS_Mag ; }

    }
  }

}


// [Q3.1] Solve sequence; it is runnable only after the missing cable definitions exist.
Resolution {

  { Name Magnetodynamics;
    System {
      { Name Sys_Mag; NameOfFormulation Magnetodynamic_a_2D;
        Type Complex; Frequency Freq; }
    }
    Operation {
      CreateDir["res"];

      InitSolution[Sys_Mag];
      Generate[Sys_Mag]; Solve[Sys_Mag]; SaveSolution[Sys_Mag];
      PostOperation[Mag_Maps];
      PostOperation[Mag_Global];
    }
  }

}


PostProcessing {

  { Name Magnetodynamic_a_2D; NameOfFormulation Magnetodynamic_a_2D;
    PostQuantity {
      // [Q3.6] Vector potential, flux lines and magnetic flux-density maps.
      { Name a; Value { Term { [ {a} ]; In Domain_Mag; Jacobian Vol; } } }
      { Name az; Value { Term { [ CompZ[{a}] ]; In Domain_Mag; Jacobian Vol; } } }
      { Name b; Value { Term { [ {d a} ]; In Domain_Mag; Jacobian Vol; } } }
      { Name bm; Value { Term { [ Norm[{d a}] ]; In Domain_Mag; Jacobian Vol; } } }

      // [Q3.7] Complete axial current density; include ur for massive regions.
      { Name j; Value {
          Term { [ -sigma[]*(Dt[{a}]+{ur})]; In DomainC_Mag; Jacobian Vol; }
          Term { [ js0[] ]; In DomainS0_Mag; Jacobian Vol; }
          Term { [ Ns[]/Sc[]*{ir} ]; In DomainS_Mag; Jacobian Vol; }
        } }
      { Name jz; Value {
          Term { [ CompZ[-sigma[]*(Dt[{a}]+{ur})] ]; In DomainC_Mag; Jacobian Vol; }
          Term { [ CompZ[ js0[] ] ]; In DomainS0_Mag; Jacobian Vol; }
          Term { [ CompZ[ Ns[]/Sc[]*{ir} ]]; In DomainS_Mag; Jacobian Vol; }
        } }
      { Name jm; Value {
          Term { [ Norm[-sigma[]*(Dt[{a}]+{ur})] ]; In DomainC_Mag; Jacobian Vol; }
          Term { [ Norm[ js0[] ] ]; In DomainS0_Mag; Jacobian Vol; }
          Term { [ Norm[ Ns[]/Sc[]*{ir} ]]; In DomainS_Mag; Jacobian Vol; }
        } }

      // [Q3.8] Mean local Joule heating: |Jhat|^2/(2*sigma), using peak phasors.
      { Name rhoj2; Value {
          Term { [ 0.5*sigma[]*SquNorm[Dt[{a}]+{ur}] ]; In DomainC_Mag; Jacobian Vol; }
          Term { [ 0.5/sigma[]*SquNorm[js0[]] ]; In DomainS0_Mag ; Jacobian Vol; }
          Term { [ 0.5/sigma[]*SquNorm[Ns[]/Sc[]*{ir}] ]; In DomainS_Mag; Jacobian Vol; }
        }
      }


      // [Q3.8, Q3.9] Integrated losses for resistance/loss separation; see the omission below.
      { Name JouleLosses; Value {
          // CHECK BEFORE USE: this supplied massive-conductor integral omits
          // {ur}. With global current/voltage constraints it must use the same
          // complete current as rhoj2 above: sigma*|Dt[a]+ur|^2/2.
          Integral { [ 0.5*sigma[]*SquNorm[Dt[{a}]] ]   ; In DomainC_Mag  ; Jacobian Vol ; Integration I1 ; }
          Integral { [ 0.5/sigma[]*SquNorm[js0[]] ]          ; In DomainS0_Mag ; Jacobian Vol ; Integration I1 ; }
          Integral { [ 0.5/sigma[]*SquNorm[Ns[]/Sc[]*{ir}] ] ; In DomainS_Mag  ; Jacobian Vol ; Integration I1 ; }
        }
      }

      // [Q3.3, Q3.7] Check screen voltage/current against the selected bonding closure.
      { Name U ; Value {
          Term { [ {U} ]  ; In DomainC_Mag ; }
          Term { [ {Us} ] ; In DomainS_Mag ; }
        }
      }

      { Name I ; Value {
          Term { [ {I} ]  ; In DomainC_Mag ; }
          Term { [ {Is} ] ; In DomainS_Mag ; }
        }
      }

      // [Q3.8, Q3.10] Terminal-power check needs the physical voltage sign and 1/2
      // for peak phasors; the raw starter product below has not applied those conventions.
      { Name S ; Value {
          Term { [ {U}*Conj[{I}] ] ; In DomainC_Mag ; }
          Term { [ {Us}*Conj[{Is}] ] ; In DomainS_Mag ; }
        }
      }

      // [Q3.9] Terminal resistance; system-equivalent resistance must also be checked
      // from TOTAL loss/(3*I_RMS^2), including copper-screen losses.
      { Name R ; Value {
          Term { [ -Re[{U}/{I}] ] ; In DomainC_Mag ; }
          Term { [ -Re[{Us}/{Is}] ] ; In DomainS_Mag ; }
        }
      }

      // [Q3.10] Terminal inductance; compare with full-domain magnetic energy after adaptation.
      { Name L ; Value {
          Term { [ -Im[{U}/{I}]/(2*Pi*Freq) ] ; In DomainC_Mag ; }
          Term { [ -Im[{Us}/{Is}]/(2*Pi*Freq) ] ; In DomainS_Mag ; }
        }
      }

      // For convenience... possible scaling
      { Name R_per_km ; Value {
          Term { [ -Re[{U}/{I}]*1e3 ] ; In DomainC_Mag ; }
          Term { [ -Re[{Us}/{Is}]*1e3 ] ; In DomainS_Mag ; }
        }
      }

      { Name mL_per_km ; Value {
          Term { [ -1e6*Im[{U}/{I}]/(2*Pi*Freq) ] ; In DomainC_Mag ; }
          Term { [ -1e6*Im[{Us}/{Is}]/(2*Pi*Freq) ] ; In DomainS_Mag ; }
        }
      }

    }
  }

}


PostOperation{
  // Magnetic
  //-------------------------------

  { Name Mag_Maps; NameOfPostProcessing Magnetodynamic_a_2D;
    Operation {
      // [Q3.6, Q3.7, Q3.8] Flux, current and loss maps for the future cable solve.
      // You may want to see the result only in part of the domain => adapt domain that follows OnElementsOf
      // Name is not compulsory, it can be modified
      // Echo instructions are not necessary, useful for changing default visualisation options in the GUI

      Print[ az, OnElementsOf Domain_Mag, //Smoothing 1,
        Name "flux lines: Az [T m]", File "res/az.pos" ];
      Echo[Str["View[PostProcessing.NbViews-1].RangeType = 3;" ,// per timestep
          "View[PostProcessing.NbViews-1].NbIso = 25;" ,
          "View[PostProcessing.NbViews-1].IntervalsType = 1;" // isolines
        ], File "res/maps.opt"];

      Print[ b, OnElementsOf Domain_Mag, //Smoothing 1,
        Name "B [T]", File "res/b.pos" ];
      Echo[Str["View[PostProcessing.NbViews-1].RangeType = 3;" ,// per timestep
          "View[PostProcessing.NbViews-1].IntervalsType = 2;"
        ], File "res/maps.opt"];

      Print[ bm , OnElementsOf Domain_Mag,
        Name "|B| [T]", File "res/bm.pos" ];
       Echo[Str["View[PostProcessing.NbViews-1].RangeType = 3;" ,// per timestep
          "View[PostProcessing.NbViews-1].ShowTime = 0;",
          "View[PostProcessing.NbViews-1].IntervalsType = 2;"
        ], File "res/maps.opt"];

      Print[ jz , OnElementsOf Region[{DomainC_Mag, DomainS_Mag}],
        Name "jz [A/m^2] Conducting domain", File "res/jz_inds.pos" ];
      Echo[Str["View[PostProcessing.NbViews-1].RangeType = 3;" ,// per timestep
          "View[PostProcessing.NbViews-1].IntervalsType = 2;"
        ], File "res/maps.opt"];

      Print[ rhoj2 , OnElementsOf Region[{DomainC_Mag, DomainS_Mag}],
        Name "Power density", File "res/rhoj2.pos" ];
      Echo[Str["View[PostProcessing.NbViews-1].RangeType = 3;" ,// per timestep
          "View[PostProcessing.NbViews-1].ShowTime = 0;",
          "View[PostProcessing.NbViews-1].IntervalsType = 2;"
        ], File "res/maps.opt"];


      Print[ jm , OnElementsOf DomainC_Mag,
        Name "|j| [A/m^2] Conducting domain", File "res/jm.pos" ];
       Echo[Str["View[PostProcessing.NbViews-1].RangeType = 3;" ,// per timestep
          "View[PostProcessing.NbViews-1].ShowTime = 0;",
          "View[PostProcessing.NbViews-1].IntervalsType = 2;"
        ], File "res/maps.opt"];

    }
  }

  // This two definitions refer to the GUI => organisation of the results
  po = "{01Losses/";
  po2 = "{02PU-parameters/";
  { Name Mag_Global; NameOfPostProcessing Magnetodynamic_a_2D;
    Operation {
      // [Q3.8, Q3.9, Q3.10] Adapt the example Steel/APLSheath groups to this cable.
      // No armour/pipe exists here; split aluminium and copper losses instead.
      // You may restrict DomainC_Mag to part of it

      Print[ JouleLosses[DomainC_Mag], OnGlobal, Format Table,
        SendToServer StrCat[po,"0Total conducting domain"],
        Units "W/m", File "res/losses_total.dat" ];

      Print[ JouleLosses[Inds], OnGlobal, Format Table,
        SendToServer StrCat[po,"3Source (stranded OR massive)"],
        Units "W/m", File "res/losses_inds.dat" ];

       Print[ JouleLosses[Steel], OnGlobal, Format Table,
        SendToServer StrCat[po,"1Steel"],
        Units "W/m", File "res/losses_steel.dat" ];

       Print[ JouleLosses[APLSheath], OnGlobal, Format Table,
        SendToServer StrCat[po,"2APLSheath"],
        Units "W/m", File "res/losses_APLSheath.dat" ];

      // Region to adapt according to your cable
      Print[ R, OnRegion Ind_1, Format Table,
        SendToServer StrCat[po2,"0R"],
        Units "Ω", File "res/Rinds.dat" ];
      Print[ L, OnRegion Ind_1, Format Table,
        SendToServer StrCat[po2,"1L"],
        Units "H", File "res/Linds.dat" ];

    }
  }
}

// The cable-specific model built from this starter is cable.pro in this folder.
