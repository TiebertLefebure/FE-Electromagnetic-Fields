"""Export checked study tables, report figures and Gmsh field views."""
import json
from math import pi, sqrt

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.tri as mtri
import numpy as np
from scipy.special import jv

from analyse import write_views
from prepare import HERE, ROOT, prepare
from run import input_hashes

REPORT = ROOT/'LaTeX/section_3'
COLORS = ['#2166ac','#b2182b','#28734f']


def outline(ax, parameters):
    radius = parameters['R6']*1000
    centers = [(0,2*radius/sqrt(3)),(-radius,-radius/sqrt(3)),(radius,-radius/sqrt(3))]
    for phase,(x,y) in zip('ABC',centers):
        for r in ('R0','R4','R5','R6'):
            ax.add_patch(plt.Circle((x,y),parameters[r]*1000,fill=False,color='#333333',lw=0.45))
        ax.text(x,y,phase,ha='center',va='center',fontsize=9,
                bbox=dict(facecolor='white',edgecolor='none',alpha=0.8,pad=1))
    ax.set(xlabel='x [mm]',ylabel='y [mm]',xlim=(-60,60),ylim=(-48,62),aspect='equal')


def save(fig, name):
    fig.savefig(REPORT/'figures'/f'{name}.png',dpi=190,bbox_inches='tight',facecolor='white')
    plt.close(fig)


def field_maps(case, parameters):
    data = np.load(HERE/'results'/case/'fields.npz')
    xy, tri, regions = data['coordinates'],data['triangles'],data['regions']
    triangulation = mtri.Triangulation(xy[:,0]*1000,xy[:,1]*1000,tri)
    b = np.linalg.norm(data['magnetic'],axis=1)/sqrt(2)*1000
    j = abs(data['current']).mean(axis=1)/sqrt(2)/1e6
    metals = np.isin(regions,[100,105,200,205,300,305])
    fig, axes = plt.subplots(1,2,figsize=(10.2,4.5),layout='constrained')
    for ax, values, label, mask in zip(axes,[b,j],['RMS vector norm of B [mT]','RMS longitudinal J [A/mm²]'],[None,~metals]):
        triangulation.set_mask(mask)
        view = ax.tripcolor(triangulation,facecolors=values,cmap='viridis',rasterized=True)
        outline(ax,parameters)
        fig.colorbar(view,ax=ax,shrink=0.75,label=label)
    save(fig,f'{case}_fields')
    if case == 'baseline':
        triangulation.set_mask(None)
        fig, ax = plt.subplots(figsize=(6,4.5),layout='constrained')
        ax.tricontour(triangulation,data['potential'].real,levels=30,colors=COLORS[0],linewidths=0.6)
        outline(ax,parameters)
        ax.set_title('Flux lines at t = 0: contours of Re(Az)')
        save(fig,'flux_lines')
        fig, axes = plt.subplots(1,2,figsize=(10,4.4),layout='constrained')
        for ax in axes:
            ax.triplot(triangulation,lw=0.2,color='#444444')
            ax.set(aspect='equal',xlabel='x [mm]',ylabel='y [mm]')
        axes[0].set(xlim=(-50,50),ylim=(-40,55),title='Trefoil mesh')
        axes[1].set(xlim=(18.5,21.4),ylim=(22,30.5),title='Copper screen of phase A')
        save(fig,'mesh')
    write_views(HERE/'results'/case)


def table(filename, rows):
    command = ''.join(word.capitalize() for word in filename.removesuffix('.tex').split('_'))
    body = '\n'.join(' & '.join(map(str,row))+r' \\' for row in rows)
    (REPORT/filename).write_text(f'\\newcommand{{\\{command}}}{{%\n{body}\n}}\n')


def export():
    parameters = prepare()
    summary = json.loads((HERE/'validation/summary.json').read_text())
    if any(case['input_sha256'] != input_hashes() for case in summary.values()):
        raise ValueError('Study inputs have changed. Run run.py --study before rebuilding the report.')
    REPORT.mkdir(parents=True,exist_ok=True)
    (REPORT/'figures').mkdir(exist_ok=True)
    plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False})
    for case in ('baseline','single_point'):
        field_maps(case,parameters)
    base = summary['baseline']
    meshes = [summary[name] for name in ('coarse','medium','baseline','fine')]
    fig,axes = plt.subplots(1,3,figsize=(10.2,3.3),layout='constrained')
    for ax,key,label in zip(axes,['loss_total_W_m','resistance_ohm_km','inductance_mH_km'],
                           ['Total loss [kW/km]','AC resistance [Ω/km]','Inductance [mH/km]']):
        ax.plot([m['complex_dofs'] for m in meshes],[m[key] for m in meshes],'o-',color=COLORS[0])
        ax.set(xlabel='Complex DOFs',ylabel=label,xscale='log')
        ax.grid(alpha=0.2)
    save(fig,'convergence')
    frequencies = [summary[name] for name in ('frequency_5','baseline','frequency_200','frequency_1000')]
    fig,ax = plt.subplots(figsize=(9.5,2.2),layout='constrained')
    ax.plot([m['options']['Freq'] for m in frequencies],
            [m['inductance_mH_km'] for m in frequencies],'o-',color=COLORS[0])
    ax.set(xlabel='Frequency [Hz]',ylabel='Inductance [mH/km]',xscale='log')
    ax.tick_params(labelsize=11)
    ax.xaxis.label.set_size(12)
    ax.yaxis.label.set_size(12)
    ax.grid(alpha=0.2)
    save(fig,'frequency')
    table('mesh_rows.tex',[(m['options']['MeshScale'],f"{m['complex_dofs']:,}",f"{m['loss_total_W_m']:.4f}",
        f"{m['resistance_ohm_km']:.6f}",f"{m['inductance_mH_km']:.6f}") for m in meshes])
    table('domain_rows.tex',[(summary[n]['options']['OuterRadius'],f"{summary[n]['loss_total_W_m']:.5f}",
        f"{summary[n]['inductance_mH_km']:.6f}") for n in ('small_domain','baseline','large_domain')])
    table('comparison_rows.tex',[(label,f"{summary[n]['loss_conductors_W_m']:.4f}",
        f"{summary[n]['loss_screens_W_m']:.4f}",f"{summary[n]['loss_total_W_m']:.4f}",
        f"{summary[n]['inductance_mH_km']:.5f}") for n,label in
        [('baseline','Massive, solid bonding'),('stranded','Stranded, solid bonding'),
         ('single_point','Massive, single point'),('no_screens','Massive, inactive copper'),('simplified','Merged nonmetal layers')]])
    table('loss_rows.tex',[(f'Aluminium {phase}',f"{base['regions'][str(100*k)]['loss_W_m']:.5f}")
        for k,phase in enumerate('ABC',1)]+[(f'Copper screen {phase}',f"{base['regions'][str(100*k+5)]['loss_W_m']:.5f}")
        for k,phase in enumerate('ABC',1)]+[('Semiconducting regions',f"{sum(v['loss_W_m'] for r,v in base['regions'].items() if int(r)%100 in (1,3,4)):.3e}"),
        ('Soil',f"{base['loss_soil_W_m']:.3e}"),('Armour / pipe','0 (absent)'),('Total',f"{base['loss_total_W_m']:.5f}")])
    table('current_rows.tex',[(f'{label} {phase}',f"{abs(complex(*base['regions'][str(100*k+layer)]['current_peak_A']))/sqrt(2):.4f}",
        f"{np.angle(complex(*base['regions'][str(100*k+layer)]['current_peak_A']),deg=True):.2f}",
        f"{base['regions'][str(100*k+layer)]['max_J_peak_A_mm2']/sqrt(2):.4f}")
        for layer,label in [(0,'Al'),(5,'Cu')] for k,phase in enumerate('ABC',1)])
    table('frequency_rows.tex',[(m['options']['Freq'],f"{m['resistance_ohm_km']:.6f}",
        f"{m['inductance_mH_km']:.6f}",f"{m['loss_screens_W_m']:.4f}") for m in frequencies])
    r = parameters['R0']; sigma = parameters['SigmaAl']; omega = 2*pi*50
    delta = sqrt(2/(omega*4*pi*1e-7*sigma)); k = (1-1j)/delta
    internal_impedance = k*jv(0,k*r)/(2*pi*r*sigma*jv(1,k*r))
    analytic_l = 0.2*(np.log(2*parameters['R6']/r)+0.25)
    no_screens = summary['no_screens']
    resistance_conductors = base['loss_conductors_W_m']/(3*parameters['Current']**2)*1000
    values = dict(BaseLoss=base['loss_total_W_m'],BaseR=base['resistance_ohm_km'],BaseL=base['inductance_mH_km'],
        BaseB=base['max_B_phasor_mT']/sqrt(2),AlLoss=base['loss_conductors_W_m'],CuLoss=base['loss_screens_W_m'],
        AlR=resistance_conductors,CuR=base['loss_screens_W_m']/(3*parameters['Current']**2)*1000,
        ExtraR=resistance_conductors-0.125,DeltaAl=delta*1000,DeltaCu=base['mesh']['copper']['skin_depth_mm'],
        SkinR=internal_impedance.real*1000,AnalyticL=analytic_l,
        ProximityR=no_screens['loss_conductors_W_m']/(3*parameters['Current']**2)*1000-internal_impedance.real*1000,
        ScreenFeedbackR=resistance_conductors-no_screens['loss_conductors_W_m']/(3*parameters['Current']**2)*1000,
        SingleLoss=summary['single_point']['loss_total_W_m'],SingleCu=summary['single_point']['loss_screens_W_m'],
        Saving=100*(1-summary['single_point']['loss_total_W_m']/base['loss_total_W_m']),
        SavingAbsolute=base['loss_total_W_m']-summary['single_point']['loss_total_W_m'],
        StrandedDifference=100*(base['loss_total_W_m']/summary['stranded']['loss_total_W_m']-1),
        FineLossChange=100*abs(base['loss_total_W_m']/summary['fine']['loss_total_W_m']-1),
        FineLChange=100*abs(base['inductance_mH_km']/summary['fine']['inductance_mH_km']-1),
        SimplifiedLossChange=100*abs(base['loss_total_W_m']/summary['simplified']['loss_total_W_m']-1),
        SimplifiedLChange=100*abs(base['inductance_mH_km']/summary['simplified']['inductance_mH_km']-1),
        DatasheetLDifference=100*(base['inductance_mH_km']/(0.12/(2*pi*50)*1000)-1),
        AnalyticLDifference=100*(summary['analytical_trefoil']['inductance_mH_km']/analytic_l-1),
        AnalyticLFE=summary['analytical_trefoil']['inductance_mH_km'],
        DomainLChange=100*abs(base['inductance_mH_km']/summary['large_domain']['inductance_mH_km']-1),
        Quality=base['min_quality'],MetalQuality=base['conducting_min_quality'],
        AlEdge=base['mesh']['aluminium']['max_edge_mm'],CuEdge=base['mesh']['copper']['max_edge_mm'])
    (REPORT/'values.tex').write_text('\n'.join(f'\\newcommand{{\\{name}}}{{{value:.6f}}}' for name,value in values.items())+'\n')
    (HERE/'validation/analytical_checks.json').write_text(json.dumps(dict(skin_depth_al_mm=delta*1000,
        isolated_skin_resistance_ohm_km=internal_impedance.real*1000,
        stranded_trefoil_inductance_mH_km=analytic_l,generated_values=values),indent=2)+'\n')
    lines = ['# Section 3 results','', '| Case | P [kW/km] | R [ohm/km] | L [mH/km] |','|---|---:|---:|---:|']
    lines += [f'| {name} | {m["loss_total_W_m"]:.6f} | {m["resistance_ohm_km"]:.6f} | {m["inductance_mH_km"]:.6f} |'
              for name,m in summary.items()]
    lines += ['',f'Maximum phase-current residual: {max(m["phase_current_relative_error"] for m in summary.values()):.3e}.',
              f'Maximum zero-net-current residual: {max(m["zero_net_current_relative_error"] for m in summary.values()):.3e}.',
              f'Maximum active-power residual: {max(m["power_balance_relative"] for m in summary.values()):.3e}.',
              f'Maximum reactive-power residual: {max(m["reactive_balance_relative"] for m in summary.values()):.3e}.',
              '', 'All losses are time averages at 20 C; current is 415 A RMS per phase.']
    (HERE/'validation/RESULTS.md').write_text('\n'.join(lines)+'\n')
    print(f'Exported Section 3 tables and figures to {REPORT}')


if __name__ == '__main__':
    export()
