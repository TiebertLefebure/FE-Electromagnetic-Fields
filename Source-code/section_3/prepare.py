"""Write the common geometry and material parameters for Gmsh and GetDP."""
import json
from math import pi, sqrt
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def prepare():
    cable = json.loads((HERE.parent / 'section_1/cable_inputs.json').read_text())
    materials = json.loads((HERE.parent / 'shared/materials.json').read_text())
    r0 = cable['conductor_diameter_mm'] / 2000
    r1 = r0 + cable['inner_semiconductor_mm'] / 1000
    r2 = r1 + cable['xlpe_mm'] / 1000
    r3 = r2 + cable['outer_semiconductor_mm'] / 1000
    r5 = cable['diameter_over_copper_mm'] / 2000
    r4 = sqrt(r5**2 - cable['copper_area_mm2'] * 1e-6 / pi)
    values = dict(R0=r0, R1=r1, R2=r2, R3=r3, R4=r4, R5=r5,
                  R6=cable['single_cable_diameter_mm'] / 2000,
                  Current=cable['reference_current_rms_A'], Freq=cable['frequency_Hz'],
                  SigmaAl=1000 / (cable['max_dc_resistance_ohm_per_km'] * pi * r0**2),
                  SigmaCu=5.95e7, SigmaSC=materials['semiconductor']['conductivity_S_m'],
                  SigmaSoil=0.01)
    lines = ['// Generated from Section 1 inputs by prepare.py.', 'DefineConstant[']
    lines += [f'  {key} = {{{value:.16g}, Name "Inputs/{key}"}}{"," if i < len(values)-1 else ""}'
              for i, (key, value) in enumerate(values.items())]
    (HERE / 'parameters.inc').write_text('\n'.join(lines) + '\n];\n')
    return values


if __name__ == '__main__':
    prepare()
