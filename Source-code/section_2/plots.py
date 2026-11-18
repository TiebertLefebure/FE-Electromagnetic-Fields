"""Gmsh display files. The numerical calculations are in analyse.py."""
import csv
from pathlib import Path


def write_viewer(directory):
    """Open view.geo to see the electric-field map and toggle the other fields."""
    files = ['e_peak.pos', 'potential_real.pos', 'e_real.pos',
             'j_conduction.pos', 'j_displacement.pos']
    lines = [
        '// Generated Gmsh viewer; coordinates in metres.',
        'If (PostProcessing.NbViews > 0)',
        '  For old In {0:PostProcessing.NbViews-1}',
        '    View[old].Visible = 0;',
        '  EndFor',
        'EndIf',
        'first = PostProcessing.NbViews;',
        'Merge "cable.msh";',
    ]
    for index, filename in enumerate(files):
        visible = int(index == 0)
        lines.append(f'''Merge "{filename}";
View[first+{index}].Visible = {visible};
View[first+{index}].Type = 1;
View[first+{index}].ShowScale = 1;
View[first+{index}].ShowTime = 0;
View[first+{index}].TimeStep = 0;
View[first+{index}].IntervalsType = 3;
View[first+{index}].NbIso = 30;''')
    lines.append('''Mesh.SurfaceEdges = 0; Mesh.SurfaceFaces = 0; Mesh.Points = 0;
Geometry.Points = 0; General.Axes = 0; General.Trackball = 0;
General.RotationX = 0; General.RotationY = 0; General.RotationZ = 0;
General.ScaleX = 1; General.ScaleY = 1; General.ScaleZ = 1;
General.TranslationX = 0; General.TranslationY = 0; General.TranslationZ = 0;
General.Orthographic = 1;
BoundingBox; Draw;''')
    (directory/'view.geo').write_text('\n'.join(lines) + '\n')


def read_cut(path):
    """Read radius (mm) and field magnitude (kV/mm) from a saved radial cut."""
    with Path(path).open() as stream:
        return [(float(row['radius_mm']), float(row['E_peak_kV_mm']))
                for row in csv.DictReader(stream)]


def interpolate(points, x):
    """Linear interpolation at a common plot endpoint."""
    for index in range(1, len(points)):
        x0, y0 = points[index - 1]
        x1, y1 = points[index]
        if x <= x1:
            return y0 + (y1 - y0)*(x - x0)/(x1 - x0)
    return points[-1][1]


def write_plot(path, curves, xlabel, ylabel):
    """Overlay curves on a common x interval, using blue/red/green in that order."""
    xmin = max(points[0][0] for name, points in curves)
    xmax = min(points[-1][0] for name, points in curves)
    aligned = []
    for name, points in curves:
        cropped = [(xmin, interpolate(points, xmin))]
        cropped += [(x, y) for x, y in points if xmin < x < xmax]
        cropped.append((xmax, interpolate(points, xmax)))
        aligned.append((name, cropped))
    values = [y for name, points in aligned for x, y in points]
    padding = max((max(values) - min(values))*0.1, abs(max(values))*1e-6, 1e-12)
    ymin, ymax = max(0, min(values) - padding), max(values) + padding
    colors = [(33, 102, 172), (178, 24, 43), (40, 115, 79)]
    legend = '; '.join(f'{color}: {curve[0]}'
                       for color, curve in zip(['blue', 'red', 'green'], aligned))
    lines = [
        'If (PostProcessing.NbViews > 0)',
        '  For old In {0:PostProcessing.NbViews-1}',
        '    View[old].Visible = 0;',
        '  EndFor',
        'EndIf',
        'first = PostProcessing.NbViews;',
    ]
    for index, (name, points) in enumerate(aligned):
        lines.append(f'View "{name}" {{')
        for x, y in points:
            lines.append(f'SP({x:.14g},0,0){{{y:.14g}}};')
        lines.append('};')
        r, g, b = colors[index]
        axes = 3 if index == 0 else 0
        lines.append(f'''View[first+{index}].Visible = 1;
View[first+{index}].Type = 4;
View[first+{index}].Axes = {axes};
View[first+{index}].ShowScale = {int(index == 0)};
View[first+{index}].ShowTime = 0;
View[first+{index}].Color.Background2D = {{255,255,255,0}};
View[first+{index}].ColorTable = {{{{ {r}, {g}, {b}, 255 }}}};
View[first+{index}].LineWidth = 2;
View[first+{index}].AutoPosition = 0;
View[first+{index}].PositionX = 110; View[first+{index}].PositionY = 100;
View[first+{index}].Width = 600; View[first+{index}].Height = 380;
View[first+{index}].AxesLabelX = "{xlabel}";
View[first+{index}].AxesAutoPosition = 0;
View[first+{index}].AxesMinX = {xmin}; View[first+{index}].AxesMaxX = {xmax};
View[first+{index}].AxesMinY = {ymin}; View[first+{index}].AxesMaxY = {ymax};
View[first+{index}].RangeType = 2;
View[first+{index}].CustomMin = {ymin}; View[first+{index}].CustomMax = {ymax};
View[first+{index}].AbscissaRangeType = 2;
View[first+{index}].CustomAbscissaMin = {xmin};
View[first+{index}].CustomAbscissaMax = {xmax};''')
    lines.append(f'View[first].Name = "{ylabel} | {legend}";')
    lines.append('Draw;')
    Path(path).write_text('\n'.join(lines) + '\n')
