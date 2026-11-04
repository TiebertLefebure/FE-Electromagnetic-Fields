from pathlib import Path
from io import BytesIO
from tempfile import TemporaryDirectory
from subprocess import run
from math import sqrt
from xml.sax.saxutils import escape

from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, PageBreak, Table, TableStyle, Flowable
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pypdf import PdfReader, PdfWriter, Transformation

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/pdf/Q1_1_Q1_2_NKT_Cable.pdf'
OUT.parent.mkdir(parents=True, exist_ok=True)
FONT = Path('/Users/tiebertlefebure/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/libreoffice-headless/libreoffice/LibreOfficeDev.app/Contents/Resources/fonts/truetype')
for name, file in [('Body', 'NotoSans-Regular.ttf'), ('Bold', 'NotoSans-Bold.ttf'), ('Italic', 'NotoSans-Italic.ttf'), ('BI', 'NotoSans-BoldItalic.ttf')]:
    pdfmetrics.registerFont(TTFont(name, str(FONT / file)))
pdfmetrics.registerFontFamily('Body', normal='Body', bold='Bold', italic='Italic', boldItalic='BI')

W, H = A4
M = 43
CW = W - 2 * M
NAVY = colors.HexColor('#15354A')
TEAL = colors.HexColor('#087F83')
INK = colors.HexColor('#263A49')
MUTED = colors.HexColor('#596C79')
PALE = colors.HexColor('#EFF6F6')
LINE = colors.HexColor('#CFDDE2')
styles = {
    'body': ParagraphStyle('body', fontName='Body', fontSize=10.1, leading=14.6, textColor=INK, spaceAfter=7),
    'small': ParagraphStyle('small', fontName='Body', fontSize=8.5, leading=12, textColor=MUTED, spaceAfter=6),
    'table': ParagraphStyle('table', fontName='Body', fontSize=9.1, leading=12.8, textColor=INK),
    'th': ParagraphStyle('th', fontName='Bold', fontSize=9, leading=12.5, textColor=colors.white),
    'h1': ParagraphStyle('h1', fontName='Bold', fontSize=22, leading=27, textColor=NAVY, spaceAfter=10),
    'h2': ParagraphStyle('h2', fontName='Bold', fontSize=11.8, leading=16, textColor=TEAL, spaceBefore=8, spaceAfter=6),
    'ref': ParagraphStyle('ref', fontName='Body', fontSize=8.2, leading=11.7, textColor=INK, spaceAfter=7),
}

story = []
equations = []
positions = []
def p(text, style='body'):
    return Paragraph(text, styles[style])
def para(text, style='body'):
    story.append(p(text, style))
def heading(text):
    para(text, 'h2')
def page(label, title):
    if story:
        story.append(PageBreak())
    para(label.upper(), 'small')
    para(title, 'h1')
def table(heads, rows, widths):
    data = [[p(x, 'th') for x in heads]] + [[p(str(x), 'table') for x in row] for row in rows]
    t = Table(data, colWidths=[CW * x / sum(widths) for x in widths], repeatRows=1, hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, PALE]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 8), ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        ('TOPPADDING', (0, 0), (-1, -1), 5.5), ('BOTTOMPADDING', (0, 0), (-1, -1), 5.5),
        ('LINEBELOW', (0, 0), (-1, -1), .35, LINE),
    ]))
    story.extend([t, Spacer(1, 7)])

class Equation(Flowable):
    def __init__(self, tex):
        super().__init__()
        self.tex = tex
        self.hAlign = 'CENTER'
        equations.append(self)
    def wrap(self, aw, ah):
        self.width = float(self.pdf_page.mediabox.width)
        self.height = float(self.pdf_page.mediabox.height) + 12
        assert self.width <= aw
        return self.width, self.height
    def draw(self):
        x, y = self.canv.absolutePosition(0, 6)
        positions.append((self.canv.getPageNumber() - 1, self.pdf_page, x, y))
def eq(tex):
    story.append(Equation(tex))

def link(url, label):
    return f'<link href="{escape(url, {chr(34): "&quot;"})}" color="#087F83"><u>{label}</u></link>'

NKT = 'https://nkt.widen.net/content/d8gut55fhb/pdf/33kV_1-core_XLPE-AL-RMP-FB-ST_CU_screen_DSENAPP_MV_DS_EN.pdf?u=gj0n1y'
LEE = 'https://doi.org/10.3390/en16010167'
SOTON = 'https://www.transmissionexcel.com/wp-content/uploads/2016/11/Parameters-for-extra-large-cables-FINAL.pdf'
COMSOL = 'https://doc.comsol.com/6.4/doc/com.comsol.help.models.acdc.submarine_cable_08_inductive_effects_3d/submarine_cable_08_inductive_effects_3d.html'
LI = 'https://doi.org/10.3390/jmse12060895'

page('Q1.1 / Tables 2 and 3 format', 'Cable data overview')
para('<b>NKT 33 kV single-core XLPE-AL, 1×240+50 mm².</b> Each cable has a 240 mm² aluminium conductor '
     'and a 50 mm² copper wire screen. Three identical cables form the three-phase system. '
     'The layers run outward from aluminium through a semiconducting screen, XLPE, a second semiconducting screen, '
     'copper wires/tape and a black PE sheath [1].')
heading('Table 2. Geometrical data of the selected cable')
table(['Parameter', 'Dimension [mm]'], [
    ('Aluminium conductor diameter', '<b>17.0</b>'),
    ('Inner semiconductor thickness', 'Not specified'),
    ('XLPE insulation thickness', '<b>8.0</b>'),
    ('Outer semiconductor thickness', 'Not specified'),
    ('Diameter over insulation', '<b>34.6</b>'),
    ('Diameter over copper wire screen', '<b>40.3</b>'),
    ('PE outer sheath thickness', '<b>2.3</b>'),
    ('Overall cable diameter, nominal', '<b>45.5</b>'),
    ('Overall cable diameter, maximum', '<b>49.5</b>'),
], [3.8, 2.2])
para('Source: NKT datasheet [1]. Thicknesses are radial; all other dimensions are diameters. '
     'The copper screen is a wire layer, not a solid annulus; its metallic cross-sectional area is <b>50 mm²</b>. '
     'Unspecified layer dimensions require explicit geometry assumptions.', 'small')
heading('Table 3. Electromagnetic and thermal properties')
table(['Material', 'ε<sub>r</sub><br/>[-]', 'μ<sub>r</sub><br/>[-]', 'σ<br/>[S/m]', 'κ<br/>[W/(m·K)]', 'Sources'], [
    ('Aluminium', '1*', '1†', '3.65 × 10<super>7</super>', '237', '[2]'),
    ('Copper', '1*', '1†', '5.95 × 10<super>7</super>', '402', '[2]'),
    ('Semiconducting compound', '2.25', '1†', '2 × 10<super>-3</super>', '0.286', '[2]'),
    ('XLPE', '2.5', '1†', '10<super>-18</super>', '0.286', 'ε<sub>r</sub>, κ: [3]<br/>σ: [4]'),
    ('PE sheath', '2.25', '1†', '10<super>-18</super>', '0.46', '[5]'),
    ('Soil', '10', '1†', '10<super>-2</super>', '0.833', 'ε<sub>r</sub>, σ: [A]<br/>κ: 1/1.2 [1]'),
], [1.65, .60, .60, 1.3, 1.15, 1.35])
para('ε<sub>r</sub>: relative permittivity; μ<sub>r</sub>: relative permeability; σ: electrical conductivity; '
     'κ: thermal conductivity (also written k). Sources apply to ε<sub>r</sub>, σ and κ; all μ<sub>r</sub> values '
     'use the nonmagnetic approximation [A]. * and † are explained on page 2.', 'small')
para('Material values are cited baseline assumptions, not NKT-certified compound data. Metallic conductivities '
     'refer to approximately room temperature. References are on pages 2-3.', 'small')

page('Q1.1 / Rating, assumptions and references', 'Ratings and data sources')
heading('Electrical rating and laying conditions')
table(['Quantity', 'Selected datasheet value [1]'], [
    ('Rated voltage', '<b>33 kV RMS between phases</b>'),
    ('Continuous ampacity', '<b>415 A RMS per phase</b>'),
    ('Installation and arrangement', 'Direct burial; three cables touching in trefoil, S = D'),
    ('Copper-screen bonding', 'Screens bonded at both ends'),
    ('Burial depth / soil temperature', '<b>1.0 m / 15°C</b>'),
    ('Soil thermal resistivity', '<b>1.2 K·m/W</b>'),
    ('Maximum conductor temperature', '<b>90°C</b> in continuous operation'),
], [2.3, 3.7])
para('The selected rating row is “G) Screens bonded at both ends - trefoil formation, close together”. '
     'The model frequency is <b>50 Hz</b>.', 'small')
heading('Basis of the assumptions')
para('<b>* Metal permittivity.</b> The value 1 follows the convention in [2] and Appendix C [A]. '
     'At 50 Hz, conduction dominates the displacement current in aluminium and copper, so this value has negligible influence.')
para('<b>† Magnetic properties.</b> A nonmagnetic approximation, μ<sub>r</sub> = 1, is used for all listed materials, '
     'consistent with Appendix C [A]. This cable construction contains no steel armour.')
para('<b>Polymer and thermal data.</b> Semiconducting PE represents both semiconducting layers [2]. '
     'The XLPE thermal conductivity follows the cable-rating reference [3]. These are initial constant properties; '
     'the later coupled model must include the temperature dependence of metal conductivity.')
heading('References for Tables 2 and 3')
para('[1] NKT, <i>33 kV single core cable XLPE-AL Halogen free</i>, printed pp. 19-20, 240 mm² column. '
     + link(NKT, 'Manufacturer datasheet'), 'ref')
para('[2] Lee et al., <i>Comparative Analysis of XLPE and Thermoplastic Insulation-Based HVDC Power Cables</i>, '
     '<i>Energies</i> 16(1), 167 (2023), Table 3. ' + link(LEE, 'doi:10.3390/en16010167'), 'ref')
para('[3] R. Chippendale, University of Southampton, <i>Parameters for extra large cables</i>, '
     'deliverable report 15242-RE2-v7 (14 October 2016), Tables 3-4. ' + link(SOTON, 'Report'), 'ref')
para('[4] COMSOL, <i>Submarine Cable 8 - Inductive Effects 3D</i>, section “Conductors and Insulators”: '
     'XLPE conductivity approximately 10<super>-18</super> S/m. ' + link(COMSOL, 'Official model documentation'), 'ref')
para('[5] W. Li et al., <i>Numerical Study on Electromagnetic Thermal Performance of Non-Metallic Armoured '
     'Optoelectronic Cable Winch System</i>, <i>Journal of Marine Science and Engineering</i> 12(6), 895 (2024), '
     'Table 2, PE column. ' + link(LI, 'doi:10.3390/jmse12060895'), 'ref')

class Trefoil(Flowable):
    def __init__(self):
        super().__init__()
        self.width = CW
        self.height = 112
    def draw(self):
        c = self.canv
        c.setFillColor(PALE)
        c.roundRect(0, 0, CW, 109, 5, stroke=0, fill=1)
        c.setStrokeColor(LINE)
        c.setLineWidth(.7)
        c.line(15, 90, CW-15, 90)
        c.setFillColor(MUTED)
        c.setFont('Body', 8)
        c.drawString(23, 95, 'Ground surface')
        radius, cx, cy = 15.3, 115, 43
        pts = [(cx, cy+2*radius/sqrt(3)), (cx-radius, cy-radius/sqrt(3)), (cx+radius, cy-radius/sqrt(3))]
        for tag, (x, y) in zip(['A', 'B', 'C'], pts):
            c.setFillColor(colors.white)
            c.setStrokeColor(NAVY)
            c.circle(x, y, radius, fill=1, stroke=1)
            c.setFillColor(TEAL)
            c.circle(x, y, 8, fill=1, stroke=0)
            c.setFillColor(colors.white)
            c.setFont('Bold', 8)
            c.drawCentredString(x, y-3, tag)
        c.setDash(2, 2)
        c.setStrokeColor(MUTED)
        c.line(172, cy, 172, 90)
        c.setDash()
        c.line(166, cy, 178, cy)
        c.line(166, 90, 178, 90)
        c.setFillColor(INK)
        c.setFont('Body', 9)
        c.drawString(193, 67, '1.0 m to the trefoil centre')
        c.drawString(193, 49, 'Three touching single-core cables')
        c.setFont('Body', 8)
        c.setFillColor(MUTED)
        c.drawString(193, 28, 'Depth reference is a model convention; drawing not to scale.')

page('Q1.2 / Environment', 'Direct burial in soil')
para('The three cables are buried in <b>homogeneous soil</b> in touching trefoil. This matches the installation '
     'associated with the selected 415 A rating [1]. There is no duct, pipe or separate backfill layer in the baseline model.')
story.extend([Trefoil(), Spacer(1, 9)])
para('The nominal outside diameter is used to define the touching arrangement:', 'small')
eq(r'S=D_{\mathrm{nom}}=45.5\,\mathrm{mm}')
table(['Environmental property', 'Value', 'Source / justification'], [
    ('Burial depth', '1.0 m', 'NKT rating condition [1]'),
    ('Undisturbed soil temperature', '15°C', 'NKT rating condition [1]'),
    ('Thermal resistivity', '1.2 K·m/W', 'NKT rating condition [1]'),
    ('Thermal conductivity', '0.833 W/(m·K)', 'Reciprocal of the rated soil thermal resistivity'),
    ('Relative permittivity', '10', 'Representative baseline from Appendix C [A]'),
    ('Relative permeability', '1', 'Nonmagnetic soil approximation; Appendix C [A]'),
    ('Electrical conductivity', '0.01 S/m', 'Representative baseline from Appendix C [A]'),
], [2.35, 1.55, 2.65])
eq(r'k_{\mathrm{soil}}=\frac{1}{\rho_{\mathrm{th,soil}}}=\frac{1}{1.2}\simeq 0.833\;\mathrm{W\,m^{-1}\,K^{-1}}')
heading('Justification and modelling conventions')
para('<b>Thermal consistency.</b> The laying conditions match the manufacturer rating. '
     'The resulting soil conductivity, 0.833 W/(m·K), replaces the illustrative 1.0 W/(m·K) in Appendix C. '
     'Soil properties are uniform and constant; moisture migration and drying are neglected.')
para('<b>Electrical soil properties.</b> Appendix C provides a reproducible reference soil, rather than a measured site. '
     'With intact screens idealised as continuous and grounded, the soil has little influence on the field inside the XLPE. '
     'If exterior soil currents affect results, these electrical values require a sensitivity check.')
para('<b>Depth convention.</b> The datasheet does not define the reference point for its 1.0 m depth. '
     'The FE model takes it from the ground surface to the trefoil centroid, as shown above.', 'small')
para('[A] KU Leuven, <i>NMES Assignment 2026</i>, Section 1 and Appendix C, Table 3. '
     'The Appendix C electrical soil values are adopted as justified baseline assumptions; '
     'the thermal soil value is taken from NKT instead.', 'ref')

def header(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(LINE)
    canvas.setLineWidth(.5)
    canvas.line(M, H-32, W-M, H-32)
    canvas.setFont('Body', 8)
    canvas.setFillColor(MUTED)
    canvas.drawString(M, H-25, 'FINITE ELEMENTS FOR ELECTROMAGNETIC FIELDS')
    canvas.drawRightString(W-M, H-25, 'NKT 33 kV | 1×240+50 mm²')
    canvas.line(M, 35, W-M, 35)
    canvas.drawString(M, 22, 'Q1.1-Q1.2 | Cable selection and environment')
    canvas.drawRightString(W-M, 22, f'{doc.page} / 3')
    canvas.restoreState()

tex_preamble = r'''\documentclass[multi=formulabox,border=1pt]{standalone}
\usepackage{lmodern,amsmath,amssymb,xcolor}
\input{glyphtounicode}
\pdfgentounicode=1
\newenvironment{formulabox}{}{}
\definecolor{navy}{HTML}{15354A}
\begin{document}
'''
with TemporaryDirectory(dir=Path(__file__).parent) as tmp:
    t = Path(tmp)
    blocks = [r'\begin{formulabox}\color{navy}\fontsize{12}{15}\selectfont\(\displaystyle ' + e.tex + r'\)\end{formulabox}' for e in equations]
    (t / 'math.tex').write_text(tex_preamble + '\n'.join(blocks) + '\n' + r'\end{document}')
    result = run(['/Library/TeX/texbin/pdflatex', '-interaction=nonstopmode', '-halt-on-error', 'math.tex'], cwd=t, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    math_pdf = PdfReader(BytesIO((t / 'math.pdf').read_bytes()))
for e, pdf_page in zip(equations, math_pdf.pages, strict=True):
    e.pdf_page = pdf_page

buffer = BytesIO()
doc = BaseDocTemplate(buffer, pagesize=A4, title='Q1.1 and Q1.2 - NKT 33 kV Cable',
                      subject='Cable construction, material properties, rating and burial environment',
                      author='Tiebert Lefebure', leftMargin=M, rightMargin=M, topMargin=47, bottomMargin=47)
doc.addPageTemplates(PageTemplate(id='answers', frames=[Frame(M, 47, CW, H-94, leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)], onPage=header))
doc.build(story)
assert doc.page == 3, f'Unexpected page count: {doc.page}'
assert len(positions) == len(equations)
buffer.seek(0)
final = PdfWriter(clone_from=buffer)
for index, pdf_page, x, y in positions:
    final.pages[index].merge_transformed_page(pdf_page, Transformation().translate(x, y))
with OUT.open('wb') as f:
    final.write(f)
print(OUT)
