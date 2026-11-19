# Magnetoquasistatic analysis

`magnetodynamic_formulation.pro` is the course starter with explanatory comments.
It contains the magnetic weak formulation but is not yet a complete cable problem.

Continue from the shared geometry in
`../Cable-selection-and-model-setup/cable.geo`. Use its generated
`meshes/gap.msh` for the initial model and `meshes/touching.msh` for the spacing
comparison. `JacketGap` in the shared `parameters.pro` selects either case.
Section 3 gives a uniform-current estimate of the inductance change.
The physical group numbers are listed in the setup folder's README.

The next step is to define the cable-specific groups, permeability and
conductivity, outer-boundary condition, 350 A RMS phase currents, and screen
bonding constraints required by the starter. Both-end bonding should allow
induced net screen current. These choices must be checked before magnetic
losses or thermal results can be claimed.

The datasheet describes a solid aluminium conductor, so a massive conductor
is the closer physical model. The uniform-current stranded case is a useful
comparison. Before using the starter's `JouleLosses` output, include the `ur`
term for massive conductors, as already done in its local `rhoj2` quantity.
The supplied global integral currently omits that term; a comment marks it.

The current Section 3 report separates analytical estimates and the proposed
implementation from FE results. No current magnetic FE results are claimed.
