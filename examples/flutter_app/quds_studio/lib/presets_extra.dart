/// 21 Additional Real-Time Animated Presets across Physics, Chemistry,
/// Mathematics, Waves & Optics, Generative Art, Space, Biology/Medicine & AI.
///
/// Every preset is minimal-code, runs in <5ms/frame for silky 60–120fps VSync
/// motion, and ships live telemetry readouts + interactive sliders.
library;

import 'presets.dart';

const extraAnimatedPresets = <StudioPreset>[
  // ── Physics & Mechanics (+3) ───────────────────────────────────────────────
  StudioPreset(
    id: 'physics_coupled_oscillators',
    titleAr: 'فيزياء: نواسان مقترنان وتبادل الطاقة (الأنماط الطبيعية)',
    titleEn: 'Physics: Coupled Oscillators & Energy Transfer (Normal Modes)',
    subtitleAr:
        'كتلتان متصلتان بثلاث نوابض تتبادلان طاقة الاهتزاز كلياً ذهاباً وإياباً بظاهرة الخفقان',
    fileName: 'coupled_oscillators.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: true)
kc = viz.slider("kc", min: 0.1, max: 1.5, value: 0.35, step: 0.05, label: "ثابت الاقتران kc")
k0 = viz.slider("k0", min: 1.0, max: 4.0, value: 2.2, step: 0.2, label: "صلابة النوابض k")

w1 = m.sqrt(k0)
w2 = m.sqrt(k0 + 2.0 * kc)
t = clk.t * 2.2
# انطلاق الكتلة الأولى بإزاحة 1.1 والثانية ساكنة -> تبادل كامل للطاقة
x1 = 0.55 * (m.cos(w1 * t) + m.cos(w2 * t))
x2 = 0.55 * (m.cos(w1 * t) - m.cos(w2 * t))
v1 = -0.55 * (w1 * m.sin(w1 * t) + w2 * m.sin(w2 * t))
v2 = -0.55 * (w1 * m.sin(w1 * t) - w2 * m.sin(w2 * t))
e1 = 0.5 * (v1 * v1 + k0 * x1 * x1)
e2 = 0.5 * (v2 * v2 + k0 * x2 * x2)

p1 = -1.8 + x1
p2 = 1.8 + x2

# رسم موجات الزمن x1(t) و x2(t) في الأسفل
var tr1 = []
var tr2 = []
for i in 0..100:
  tau = t - (100 - i) * 0.05
  u1 = 0.55 * (m.cos(w1 * tau) + m.cos(w2 * tau))
  u2 = 0.55 * (m.cos(w1 * tau) - m.cos(w2 * tau))
  gx = -4.6 + i * 0.092
  tr1.add([gx, -1.6 + u1 * 0.9])
  tr2.add([gx, -3.4 + u2 * 0.9])

s = viz.scene(title: "نواسان مقترنان وتبادل الطاقة عبر النابض الأوسط", bounds: [-5.0, 5.0, -4.6, 3.0])
s.segment("wallL", [-4.6, 0.2], [-4.6, 2.2], color: "#64748B", strokeWidth: 3.0)
s.segment("wallR", [4.6, 0.2], [4.6, 2.2], color: "#64748B", strokeWidth: 3.0)
s.segment("sp1", [-4.6, 1.2], [p1, 1.2], color: "#38BDF8", strokeWidth: 2.2)
s.segment("spC", [p1, 1.2], [p2, 1.2], color: "#F59E0B", strokeWidth: 2.6)
s.segment("sp2", [p2, 1.2], [4.6, 1.2], color: "#EC4899", strokeWidth: 2.2)
s.point("m1", p1, 1.2, label: "m₁", color: "#38BDF8", radius: 11.0)
s.point("m2", p2, 1.2, label: "m₂", color: "#EC4899", radius: 11.0)
s.curve("c1", tr1, color: "#38BDF8", strokeWidth: 2.2, glow: true)
s.curve("c2", tr2, color: "#EC4899", strokeWidth: 2.2, glow: true)
s.readout("طاقة m₁", e1, unit: "J", color: "#38BDF8")
s.readout("طاقة m₂", e2, unit: "J", color: "#EC4899")
s.readout("تردد الخفقان", (w2 - w1) / 2.0, unit: "rad/s", color: "#F59E0B")
s.render()
''',
  ),
  StudioPreset(
    id: 'physics_doppler_effect',
    titleAr: 'فيزياء: تأثير دوبلر ومخروط الصدمة (عدد ماخ)',
    titleEn: 'Physics: Doppler Effect & Mach Shockwave Cone',
    subtitleAr:
        'مصدر متحرك يبث جبهات موجية دائرية تُظهر انضغاط التردد أمامه ومخروط ماخ فوق الصوتي',
    fileName: 'doppler_mach.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 7.0, loop: true)
mach = viz.slider("mach", min: 0.0, max: 1.5, value: 0.75, step: 0.05, label: "عدد ماخ v/c")

cWave = 2.0
vSrc = mach * cWave
t = clk.t
xSrc = -4.2 + vSrc * t
if xSrc > 5.0:
  xSrc = -4.2 + ((vSrc * t) % 9.2)

s = viz.scene(title: "تأثير دوبلر وجبهات الموجات الصوتية (Mach = {mach})", grid: false, bounds: [-5.5, 5.5, -4.4, 4.4])
for k in 0..10:
  age = (t * 2.2 + k * 0.45) % 4.8
  r = cWave * age
  ex = xSrc - vSrc * age
  if r > 0.1 and r < 9.5:
    hue = 195.0 - m.min(180.0, age * 35.0)
    s.circle("w{k}", [ex, 0.0], r, stroke: viz.hsl(hue, 0.88, 0.55))

if mach >= 1.0:
  sinA = 1.0 / mach
  ang = m.asin(sinA)
  dx = 5.0 * m.cos(ang)
  dy = 5.0 * m.sin(ang)
  s.segment("cone1", [xSrc, 0.0], [xSrc - dx, dy], color: "#F43F5E", strokeWidth: 2.6)
  s.segment("cone2", [xSrc, 0.0], [xSrc - dx, -dy], color: "#F43F5E", strokeWidth: 2.6)

s.point("src", xSrc, 0.0, label: "المصدر", color: "#FACC15", radius: 7.5)
fAhead = (if mach < 0.98: 1.0 / (1.0 - mach) else: 99.0)
fBehind = 1.0 / (1.0 + mach)
s.readout("عدد ماخ M", mach, decimals: 2, color: "#FACC15")
s.readout("تردد أمامي f/f₀", fAhead, decimals: 2, color: "#F43F5E")
s.readout("تردد خلفي f/f₀", fBehind, decimals: 2, color: "#38BDF8")
s.render()
''',
  ),
  StudioPreset(
    id: 'physics_elastic_collisions',
    titleAr: 'ميكانيكا: تصادم مرن وحفظ الزخم والطاقة الحركية',
    titleEn: 'Mechanics: Elastic Collisions & Momentum Conservation',
    subtitleAr:
        'تصادم كرتين داخل مسار مغلق بحساب دقيق للسرعات بعد التصادم وحفظ الزخم والطاقة الحركية',
    fileName: 'elastic_collisions.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: false)
m1 = viz.slider("m1", min: 1.0, max: 6.0, value: 1.5, step: 0.5, label: "الكتلة m₁ (kg)")
m2 = viz.slider("m2", min: 1.0, max: 6.0, value: 3.5, step: 0.5, label: "الكتلة m₂ (kg)")

var st = viz.state("col", [-3.0, 1.5, 2.8, -1.2, 0])
if clk.frame == 0:
  st = [-3.0, 1.5, 2.8, -1.2, 0]

var x1 = st[0]
var x2 = st[1]
var v1 = st[2]
var v2 = st[3]
var hits = st[4]
r1 = 0.42
r2 = 0.52
dt = 0.025

x1 = x1 + v1 * dt
x2 = x2 + v2 * dt

if x1 - r1 < -4.6:
  x1 = -4.6 + r1
  v1 = -v1
if x2 + r2 > 4.6:
  x2 = 4.6 - r2
  v2 = -v2
if x2 - x1 < r1 + r2:
  nv1 = ((m1 - m2) * v1 + 2.0 * m2 * v2) / (m1 + m2)
  nv2 = ((m2 - m1) * v2 + 2.0 * m1 * v1) / (m1 + m2)
  v1 = nv1
  v2 = nv2
  mid = 0.5 * (x1 + x2)
  x1 = mid - (r1 + r2) * 0.52
  x2 = mid + (r1 + r2) * 0.52
  hits = hits + 1

viz.setState("col", [x1, x2, v1, v2, hits])
pTot = m1 * v1 + m2 * v2
keTot = 0.5 * m1 * v1 * v1 + 0.5 * m2 * v2 * v2

s = viz.scene(title: "تصادم مرن لكرتين — حفظ الزخم والطاقة", bounds: [-5.0, 5.0, -2.5, 2.5])
s.segment("floor", [-4.6, -0.6], [4.6, -0.6], color: "#475569", strokeWidth: 2.4)
s.segment("wL", [-4.6, -0.6], [-4.6, 1.4], color: "#64748B", strokeWidth: 3.0)
s.segment("wR", [4.6, -0.6], [4.6, 1.4], color: "#64748B", strokeWidth: 3.0)
s.circle("c1", [x1, 0.0], r1, stroke: "#38BDF8", fill: "#38BDF855")
s.circle("c2", [x2, 0.0], r2, stroke: "#F43F5E", fill: "#F43F5E55")
s.vector("vec1", [x1, 0.9], [x1 + v1 * 0.35, 0.9], label: "v₁", color: "#38BDF8")
s.vector("vec2", [x2, 0.9], [x2 + v2 * 0.35, 0.9], label: "v₂", color: "#F43F5E")
s.readout("الزخم الكلي P", pTot, unit: "kg·m/s", color: "#F59E0B")
s.readout("الطاقة الحركية KE", keTot, unit: "J", color: "#10B981")
s.readout("التصادمات", "{hits}", color: "#A78BFA")
s.render()
''',
  ),
  // ── Chemistry Lab (+4) ─────────────────────────────────────────────────────
  StudioPreset(
    id: 'chem_equilibrium_lechatelier',
    titleAr: 'كيمياء: الاتزان الكيميائي ومبدأ لوشاتيليه A+B ⇌ 2C',
    titleEn: 'Chemistry: Dynamic Equilibrium & Le Chatelier (Q → Keq)',
    subtitleAr:
        'تغيّر تراكيز المتفاعلات والنواتج حياً حتى تساوي سرعتي التفاعل الأمامي والعكسي عند Q = Keq',
    fileName: 'chem_equilibrium.quds',
    category: StudioCategory.chemistry,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
kf = viz.slider("kf", min: 0.2, max: 2.0, value: 0.95, step: 0.05, label: "ثابت الأمامي kf")
kr = viz.slider("kr", min: 0.1, max: 1.5, value: 0.35, step: 0.05, label: "ثابت العكسي kr")

var a = 1.0
var b = 0.85
var c = 0.05
dt = 0.04
var curveA = []
var curveC = []
var qNow = 0.0
var aCur = a
var cCur = c
steps = 150
targetIdx = (clk.progress * steps).round()
for i in 0..steps:
  tau = i * dt
  curveA.add([tau, a * 3.5])
  curveC.add([tau, c * 3.5])
  if i == targetIdx:
    aCur = a
    cCur = c
    qNow = (c * c) / (a * b + 1e-6)
  rf = kf * a * b
  rr = kr * c * c
  net = rf - rr
  a = a - net * dt
  b = b - net * dt
  c = c + 2.0 * net * dt

kEq = kf / kr
s = viz.scene(title: "الاتزان الكيميائي الديناميكي: A + B ⇌ 2C", bounds: [-0.3, 6.4, -0.3, 4.4])
s.curve("A", curveA, color: "#38BDF8", progress: clk.progress, strokeWidth: 2.5, showHead: true)
s.curve("C", curveC, color: "#10B981", progress: clk.progress, strokeWidth: 2.8, glow: true, showHead: true)
s.readout("[A] متفاعل", aCur, unit: "M", decimals: 3, color: "#38BDF8")
s.readout("[C] ناتج", cCur, unit: "M", decimals: 3, color: "#10B981")
s.readout("حاصل التفاعل Q", qNow, decimals: 2, color: "#F59E0B")
s.readout("ثابت الاتزان Keq", kEq, decimals: 2, color: "#A78BFA")
s.render()
''',
  ),
  StudioPreset(
    id: 'chem_oscillating_brusselator',
    titleAr: 'كيمياء غير خطية: الساعة الكيميائية المتذبذبة (Brusselator)',
    titleEn: 'Nonlinear Chemistry: Brusselator Oscillating Reaction',
    subtitleAr:
        'تفاعل تحفيز ذاتي شبيه ببيلوسوف–جابوتينسكي يرسم دورة حدية متوهجة في فضاء التراكيز (X, Y)',
    fileName: 'chem_brusselator.quds',
    category: StudioCategory.chemistry,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 9.0, loop: true)
B = viz.slider("B", min: 1.4, max: 3.4, value: 2.6, step: 0.1, label: "معامل التحفيز B")
A = 1.0

var x = 1.1
var y = 1.2
dt = 0.03
var pts = []
for i in 0..240:
  dx = A - (B + 1.0) * x + x * x * y
  dy = B * x - x * x * y
  x = x + dx * dt
  y = y + dy * dt
  pts.add([x, y])

idx = (clk.progress * 240.0).round()
cur = pts[idx]
regime = (if B > 1.0 + A * A: "تذبذب دوري مستدام" else: "تخميد للاتزان")

s = viz.scene(title: "تفاعل Brusselator المتذبذب في فضاء التراكيز (X, Y)", bounds: [0.0, 4.8, 0.0, 5.2])
s.point("eq", A, B / A, label: "نقطة الاتزان", color: "#64748B", radius: 4.5)
s.curve("cycle", pts, gradient: viz.palette("plasma"), progress: clk.progress, strokeWidth: 2.6, glow: true, showHead: true)
s.readout("[X]", cur[0], unit: "M", color: "#F59E0B")
s.readout("[Y]", cur[1], unit: "M", color: "#EC4899")
s.readout("السلوك", regime, color: "#10B981")
s.render()
''',
  ),
  StudioPreset(
    id: 'chem_radioactive_decay',
    titleAr: 'كيمياء نووية: الاضمحلال الإشعاعي وعمر النصف t½',
    titleEn: 'Nuclear Chemistry: Radioactive Decay & Half-Life Series',
    subtitleAr:
        'تضمحل النظائر الأم N(t)=N₀e⁻λt وتنمو النظائر الابنة مع علامات أعمار النصف المتتالية',
    fileName: 'radioactive_decay.quds',
    category: StudioCategory.chemistry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
halfLife = viz.slider("tHalf", min: 0.8, max: 3.5, value: 1.8, step: 0.1, label: "عمر النصف t½ (s)")

lam = m.ln2 / halfLife
var parentPts = []
var daughterPts = []
for i in 0..140:
  tau = i * (8.0 / 140.0)
  nP = 100.0 * m.exp(-lam * tau)
  nD = 100.0 - nP
  parentPts.add([tau, nP * 0.04])
  daughterPts.add([tau, nD * 0.04])

tNow = clk.progress * 8.0
rem = 100.0 * m.exp(-lam * tNow)
daug = 100.0 - rem

s = viz.scene(title: "الاضمحلال الإشعاعي: النظير الأم والنظير الابن", bounds: [-0.4, 8.4, -0.4, 4.5])
for k in 1..3:
  tk = k * halfLife
  if tk < 8.0:
    s.segment("hl{k}", [tk, 0.0], [tk, 4.0], color: "#334155", dashed: true)
s.curve("parent", parentPts, color: "#F43F5E", progress: clk.progress, strokeWidth: 2.8, glow: true, showHead: true)
s.curve("daughter", daughterPts, color: "#10B981", progress: clk.progress, strokeWidth: 2.5, showHead: true)
s.readout("المتبقي الأم", rem, unit: "%", decimals: 1, color: "#F43F5E")
s.readout("النظير الابن", daug, unit: "%", decimals: 1, color: "#10B981")
s.readout("ثابت التفكك λ", lam, unit: "s⁻¹", decimals: 3, color: "#38BDF8")
s.readout("أعمار النصف", tNow / halfLife, unit: "t½", decimals: 2, color: "#F59E0B")
s.render()
''',
  ),
  StudioPreset(
    id: 'chem_van_der_waals',
    titleAr: 'كيمياء فيزيائية: غاز فان دير فالس مقابل الغاز المثالي',
    titleEn: 'Physical Chemistry: Van der Waals Real Gas Isotherms',
    subtitleAr:
        'مقارنة منحنيات الضغط والحجم P(V) للغاز الحقيقي والمثالي أثناء مسح الحرارة حول النقطة الحرجة Tc',
    fileName: 'van_der_waals.quds',
    category: StudioCategory.chemistry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
aParam = viz.slider("a", min: 0.5, max: 3.5, value: 2.0, step: 0.25, label: "قوى التجاذب a")

bParam = 0.35
R = 1.0
tc = 8.0 * aParam / (27.0 * R * bParam)
temp = tc * (0.82 + 0.55 * (0.5 - 0.5 * m.cos(clk.progress * 2.0 * m.pi)))

var realPts = []
var idealPts = []
for i in 0..130:
  v = 0.58 + i * (5.2 / 130.0)
  pReal = (R * temp) / (v - bParam) - aParam / (v * v)
  pIdeal = (R * temp) / v
  realPts.add([v, m.max(-0.4, m.min(6.2, pReal))])
  idealPts.add([v, m.max(0.0, m.min(6.2, pIdeal))])

phase = (if temp < tc: "منطقة الإسالة (T < Tc)" else: "مائع فوق حرج (T ≥ Tc)")
colReal = (if temp < tc: "#38BDF8" else: "#F43F5E")

s = viz.scene(title: "منحنيات الضغط-الحجم P(V): فان دير فالس مقابل المثالي", bounds: [0.2, 6.0, -0.5, 6.4])
s.curve("ideal", idealPts, color: "#64748B", strokeWidth: 1.8)
s.curve("real", realPts, color: colReal, strokeWidth: 2.8, glow: true)
s.readout("الحرارة T", temp, decimals: 2, color: colReal)
s.readout("الحرارة الحرجة Tc", tc, decimals: 2, color: "#F59E0B")
s.readout("الحالة", phase, color: "#10B981")
s.render()
''',
  ),
  // ── Mathematics & Calculus (+4) ────────────────────────────────────────────
  StudioPreset(
    id: 'math_newton_raphson',
    titleAr: 'تحليل عددي: طريقة نيوتن–رافسون لإيجاد الجذر √A',
    titleEn: 'Numerical Analysis: Newton-Raphson Tangent Convergence',
    subtitleAr:
        'شاهد المماسات تقفز نحو الجذر الدقيق لـ x² - A = 0 بتقارب تربيعي فائق السرعة',
    fileName: 'newton_raphson.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 7.0, loop: true)
A = viz.slider("A", min: 2.0, max: 12.0, value: 7.0, step: 0.5, label: "العدد المطلوب جذره A")

rootExact = m.sqrt(A)
var curvePts = []
for i in 0..120:
  x = 0.0 + i * (5.2 / 120.0)
  y = (x * x - A) * 0.45
  curvePts.add([x, m.max(-4.5, m.min(5.0, y))])

stepsShow = 1 + (clk.progress * 5.0).round()
var xk = 4.9
s = viz.scene(title: "طريقة نيوتن–رافسون لإيجاد √{A}", bounds: [-0.4, 5.4, -4.6, 5.2])
s.curve("fn", curvePts, color: "#38BDF8", strokeWidth: 2.6, glow: true)
s.point("exact", rootExact, 0.0, label: "√A", color: "#10B981", radius: 6.0)

for step in 0..<stepsShow:
  yk = (xk * xk - A) * 0.45
  xNext = 0.5 * (xk + A / xk)
  col = viz.hsl(30.0 + step * 35.0, 0.9, 0.58)
  s.segment("drop{step}", [xk, 0.0], [xk, yk], color: "#475569", dashed: true)
  s.segment("tan{step}", [xk, yk], [xNext, 0.0], color: col, strokeWidth: 2.2)
  s.point("p{step}", xk, yk, color: col, radius: 4.5)
  xk = xNext

err = (xk - rootExact).abs()
s.readout("التكرار n", "{stepsShow}", color: "#38BDF8")
s.readout("التقريب xₙ", xk, decimals: 6, color: "#F59E0B")
s.readout("الجذر الدقيق", rootExact, decimals: 6, color: "#10B981")
s.readout("الخطأ |xₙ-√A|", err, decimals: 6, color: "#F43F5E")
s.render()
''',
  ),
  StudioPreset(
    id: 'math_bezier_decasteljau',
    titleAr: 'هندسة الحاسوب: منحنى بيزييه وخوارزمية De Casteljau',
    titleEn: 'Computer Graphics: Cubic Bezier & De Casteljau Construction',
    subtitleAr:
        'البناء الهندسي الحي لمنحنى بيزييه التكعيبي عبر استيفاء خطي متكرر عند المعامل t ∈ [0,1]',
    fileName: 'bezier_decasteljau.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 6.0, loop: true)
hPeak = viz.slider("h", min: 1.0, max: 4.2, value: 3.4, step: 0.2, label: "ارتفاع نقطتي التحكم")

p0 = [-4.0, -2.0]
p1 = [-2.2, hPeak]
p2 = [2.2, -hPeak * 0.7]
p3 = [4.0, 2.2]

lerpPt = (a, b, u) -> [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]

var bez = []
for i in 0..120:
  u = i / 120.0
  q0 = lerpPt(p0, p1, u)
  q1 = lerpPt(p1, p2, u)
  q2 = lerpPt(p2, p3, u)
  r0 = lerpPt(q0, q1, u)
  r1 = lerpPt(q1, q2, u)
  bez.add(lerpPt(r0, r1, u))

t = clk.progress
q0 = lerpPt(p0, p1, t)
q1 = lerpPt(p1, p2, t)
q2 = lerpPt(p2, p3, t)
r0 = lerpPt(q0, q1, t)
r1 = lerpPt(q1, q2, t)
bt = lerpPt(r0, r1, t)

s = viz.scene(title: "خوارزمية De Casteljau لبناء منحنى بيزييه التكعيبي", bounds: [-4.8, 4.8, -4.2, 4.4])
s.segment("c01", p0, p1, color: "#475569", dashed: true)
s.segment("c12", p1, p2, color: "#475569", dashed: true)
s.segment("c23", p2, p3, color: "#475569", dashed: true)
s.segment("l1a", q0, q1, color: "#38BDF8", strokeWidth: 1.6)
s.segment("l1b", q1, q2, color: "#38BDF8", strokeWidth: 1.6)
s.segment("l2", r0, r1, color: "#10B981", strokeWidth: 2.0)
s.curve("bezier", bez, gradient: viz.palette("neon"), progress: t, strokeWidth: 3.0, glow: true, showHead: true)
s.point("P0", p0[0], p0[1], label: "P₀", color: "#94A3B8", radius: 5.0)
s.point("P1", p1[0], p1[1], label: "P₁", color: "#94A3B8", radius: 5.0)
s.point("P2", p2[0], p2[1], label: "P₂", color: "#94A3B8", radius: 5.0)
s.point("P3", p3[0], p3[1], label: "P₃", color: "#94A3B8", radius: 5.0)
s.readout("المعامل t", t, decimals: 3, color: "#38BDF8")
s.readout("B(t).x", bt[0], decimals: 2, color: "#EC4899")
s.readout("B(t).y", bt[1], decimals: 2, color: "#10B981")
s.render()
''',
  ),
  StudioPreset(
    id: 'math_golden_phyllotaxis',
    titleAr: 'الرياضيات في الطبيعة: زهرة فيلوتاكسيس والنسبة الذهبية',
    titleEn: 'Nature Math: Golden Angle Phyllotaxis Sunflower',
    subtitleAr:
        'نمو بذور عباد الشمس بالزاوية الذهبية 137.508° مع قابلية تعديل الزاوية وملاحظة تحول اللوالب',
    fileName: 'golden_phyllotaxis.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
angleDeg = viz.slider("ang", min: 135.0, max: 140.0, value: 137.51, step: 0.05, label: "زاوية التباعد (°)")

rad = angleDeg * m.pi / 180.0
count = 12 + (clk.progress * 150.0).round()
s = viz.scene(title: "حلزون فيلوتاكسيس النباتي — الزاوية الذهبية {angleDeg}°", grid: false, axes: false, bounds: [-4.6, 4.6, -4.6, 4.6])

for n in 0..<count:
  r = 0.31 * m.sqrt(n * 1.0)
  a = n * rad
  x = r * m.cos(a)
  y = r * m.sin(a)
  hue = (n * 2.2) % 360.0
  s.point("s{n}", x, y, color: viz.hsl(hue, 0.88, 0.58), radius: 3.4 + (n / 180.0) * 2.2)

s.readout("البذور المرسومة", "{count}", color: "#F59E0B")
s.readout("الزاوية θ", angleDeg, unit: "°", decimals: 2, color: "#38BDF8")
s.readout("الزاوية الذهبية", "137.51°", color: "#10B981")
s.render()
''',
  ),
  StudioPreset(
    id: 'math_fibonacci_spiral',
    titleAr: 'رياضيات: الحلزون اللوغاريتمي الذهبي r = a·e^(bθ)',
    titleEn: 'Mathematics: Golden Logarithmic Spiral & Tangent Angle',
    subtitleAr:
        'رسم تدريجي للحلزون الذهبي متساوي الزوايا مع إظهار ثبات الزاوية المماسية والنسبة الذهبية φ',
    fileName: 'golden_spiral.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 7.0, loop: true)
growth = viz.slider("b", min: 0.12, max: 0.36, value: 0.3063, step: 0.01, label: "معامل النمو b")

var pts = []
tMax = 4.0 * m.pi
for i in 0..200:
  u = i * (tMax / 200.0)
  r = 0.14 * m.exp(growth * u)
  pts.add([r * m.cos(u), r * m.sin(u)])

uNow = clk.progress * tMax
rNow = 0.14 * m.exp(growth * uNow)
px = rNow * m.cos(uNow)
py = rNow * m.sin(uNow)
# الزاوية الثابتة بين نصف القطر والمماس: atan(1/b)
psiDeg = m.atan(1.0 / growth) * 180.0 / m.pi

s = viz.scene(title: "الحلزون اللوغاريتمي الذهبي (متساوي الزوايا)", bounds: [-6.5, 6.5, -6.5, 6.5])
s.curve("spiral", pts, gradient: viz.palette("fire"), progress: clk.progress, strokeWidth: 2.6, glow: true, showHead: true)
s.vector("rad", [0.0, 0.0], [px, py], label: "r", color: "#38BDF8")
s.readout("نصف القطر r", rNow, color: "#F59E0B")
s.readout("الزاوية المماسية ψ", psiDeg, unit: "°", decimals: 1, color: "#38BDF8")
s.readout("النسبة الذهبية φ", 1.618, decimals: 3, color: "#10B981")
s.render()
''',
  ),
  // ── Waves, Optics & Signals (+3) ───────────────────────────────────────────
  StudioPreset(
    id: 'waves_standing_harmonics',
    titleAr: 'موجات وصوت: الموجة الموقوفة والتوافقيات الرنينية على وتر',
    titleEn: 'Waves & Acoustics: Standing Wave Harmonics on a String',
    subtitleAr:
        'تراكب موجتين متعاكستين يُولّد عقداً وبطوناً ثابتة عند التوافقيات الرنينية n=1..6',
    fileName: 'standing_wave.quds',
    category: StudioCategory.waves,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 6.0, loop: true)
harm = viz.slider("n", min: 1.0, max: 6.0, value: 3.0, step: 1.0, label: "رتبة التوافقية n")

n = harm.round()
L = 8.0
omega = n * 2.2
t = clk.t
var wave = []
var envTop = []
var envBot = []
for i in 0..140:
  x = i * (L / 140.0)
  spatial = 2.2 * m.sin(n * m.pi * x / L)
  y = spatial * m.cos(omega * t)
  wave.add([x - 4.0, y])
  envTop.add([x - 4.0, spatial.abs()])
  envBot.add([x - 4.0, -spatial.abs()])

s = viz.scene(title: "الموجة الموقوفة على وتر — التوافقية n = {n}", bounds: [-4.4, 4.4, -3.0, 3.0])
s.curve("et", envTop, color: "#334155", strokeWidth: 1.3)
s.curve("eb", envBot, color: "#334155", strokeWidth: 1.3)
s.curve("standing", wave, gradient: viz.palette("neon"), strokeWidth: 2.8, glow: true)
for k in 0..n:
  nx = -4.0 + k * (L / n)
  s.point("node{k}", nx, 0.0, color: "#F43F5E", radius: 5.0)
s.readout("التوافقية n", "{n}", color: "#38BDF8")
s.readout("عدد العُقد", "{n + 1}", color: "#F43F5E")
s.readout("التردد fₙ", n * 110.0, unit: "Hz", decimals: 0, color: "#10B981")
s.render()
''',
  ),
  StudioPreset(
    id: 'waves_am_fm_modulation',
    titleAr: 'اتصالات وإشارات: التعديل السعوي والترددي (AM / FM) حياً',
    titleEn: 'Telecom & DSP: Live AM & FM Signal Modulation',
    subtitleAr:
        'مقارنة موجة الحامل المضمّنة سعوياً AM وترددياً FM حياً مع معامل التضمين والإشارة المرسلة',
    fileName: 'am_fm_signals.quds',
    category: StudioCategory.waves,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 6.0, loop: true)
depth = viz.slider("mIdx", min: 0.2, max: 1.0, value: 0.75, step: 0.05, label: "عمق التضمين")
fCar = viz.slider("fc", min: 4.0, max: 12.0, value: 8.0, step: 1.0, label: "تردد الحامل fc")

t = clk.t * 2.2
var amPts = []
var fmPts = []
for i in 0..180:
  x = -5.0 + i * (10.0 / 180.0)
  msg = m.sin(1.2 * x - t)
  am = (1.0 + depth * msg) * m.cos(fCar * x - 4.0 * t) * 0.9
  fm = m.cos(fCar * x - 4.0 * t + 3.2 * depth * m.sin(1.2 * x - t)) * 1.1
  amPts.add([x, 1.9 + am])
  fmPts.add([x, -1.9 + fm])

s = viz.scene(title: "مقارنة التضمين السعوي AM (أعلى) والترددي FM (أسفل)", bounds: [-5.2, 5.2, -3.8, 3.8])
s.segment("sep", [-5.0, 0.0], [5.0, 0.0], color: "#334155", dashed: true)
s.curve("am", amPts, color: "#38BDF8", strokeWidth: 2.3, glow: true)
s.curve("fm", fmPts, gradient: viz.palette("plasma"), strokeWidth: 2.3, glow: true)
s.readout("الحامل fc", fCar, unit: "kHz", decimals: 0, color: "#38BDF8")
s.readout("معامل التضمين", depth * 100.0, unit: "%", decimals: 0, color: "#F59E0B")
s.readout("الزمن t", clk.t, unit: "s", color: "#10B981")
s.render()
''',
  ),
  StudioPreset(
    id: 'waves_snell_refraction',
    titleAr: 'بصريات: قانون سنيل للانكسار والانعكاس الكلي الداخلي',
    titleEn: 'Optics: Snell Refraction & Total Internal Reflection',
    subtitleAr:
        'شعاع ليزر يمسح زوايا السقوط بين وسطين n₁ → n₂ ويُظهر الزاوية الحرجة والانعكاس الكلي الداخلي',
    fileName: 'snell_optics.quds',
    category: StudioCategory.waves,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
n1 = viz.slider("n1", min: 1.0, max: 2.0, value: 1.5, step: 0.05, label: "معامل الوسط الأول n₁")
n2 = viz.slider("n2", min: 1.0, max: 2.0, value: 1.0, step: 0.05, label: "معامل الوسط الثاني n₂")

theta1 = (8.0 + 74.0 * (0.5 - 0.5 * m.cos(clk.progress * 2.0 * m.pi))) * m.pi / 180.0
sinT2 = (n1 / n2) * m.sin(theta1)
tir = sinT2 >= 1.0

s = viz.scene(title: "قانون سنيل للانكسار n₁·sin(θ₁) = n₂·sin(θ₂)", bounds: [-4.5, 4.5, -3.8, 3.8])
s.polygon("med2", [[-4.5, 0.0], [4.5, 0.0], [4.5, -3.8], [-4.5, -3.8]], stroke: "#1E293B", fill: "#38BDF814")
s.segment("boundary", [-4.5, 0.0], [4.5, 0.0], color: "#38BDF8", strokeWidth: 2.0)
s.segment("normal", [0.0, -3.5], [0.0, 3.5], color: "#64748B", dashed: true)

# الشعاع الساقط والمنعكس
s.vector("inc", [-3.4 * m.sin(theta1), 3.4 * m.cos(theta1)], [0.0, 0.0], label: "ساقط", color: "#F43F5E")
reflCol = (if tir: "#F43F5E" else: "#F43F5E66")
s.vector("refl", [0.0, 0.0], [3.4 * m.sin(theta1), 3.4 * m.cos(theta1)], label: "منعكس", color: reflCol)

var t2Deg = 90.0
if not tir:
  theta2 = m.asin(sinT2)
  t2Deg = theta2 * 180.0 / m.pi
  s.vector("refr", [0.0, 0.0], [3.4 * m.sin(theta2), -3.4 * m.cos(theta2)], label: "منكسر", color: "#10B981")

s.readout("زاوية السقوط θ₁", theta1 * 180.0 / m.pi, unit: "°", decimals: 1, color: "#F43F5E")
if tir:
  s.readout("الحالة", "انعكاس كلي داخلي!", color: "#F59E0B")
else:
  s.readout("زاوية الانكسار θ₂", t2Deg, unit: "°", decimals: 1, color: "#10B981")
if n1 > n2:
  s.readout("الزاوية الحرجة θc", m.asin(n2 / n1) * 180.0 / m.pi, unit: "°", decimals: 1, color: "#38BDF8")
s.render()
''',
  ),
  // ── Geometry & Generative Art (+2) ─────────────────────────────────────────
  StudioPreset(
    id: 'art_maurer_rose',
    titleAr: 'فن هندسي: نجمة مورير الرياضية (Maurer Rose)',
    titleEn: 'Generative Art: Maurer Rose Star Web',
    subtitleAr:
        'شبكة نجمية هندسية ساحرة تتشكل بوصل نقاط الوردة القطبية بخطوة زاوية d° تدريجياً',
    fileName: 'maurer_rose.quds',
    category: StudioCategory.geometry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 9.0, loop: true)
nPetal = viz.slider("n", min: 2.0, max: 9.0, value: 6.0, step: 1.0, label: "رتبة الوردة n")
dStep = viz.slider("d", min: 19.0, max: 97.0, value: 71.0, step: 2.0, label: "زاوية القفزة d°")

var pts = []
for i in 0..240:
  k = i * dStep * m.pi / 180.0
  r = 3.7 * m.sin(nPetal * k)
  pts.add([r * m.cos(k), r * m.sin(k)])

s = viz.scene(title: "نجمة مورير الهندسية (n={nPetal}, d={dStep}°)", grid: false, axes: false, bounds: [-4.2, 4.2, -4.2, 4.2])
s.curve("maurer", pts, gradient: viz.palette("neon"), progress: clk.progress, strokeWidth: 1.5, glow: true, showHead: true)
s.readout("الرتبة n", nPetal, decimals: 0, color: "#EC4899")
s.readout("زاوية القفزة d", dStep, unit: "°", decimals: 0, color: "#38BDF8")
s.readout("الاكتمال", clk.progress * 100.0, unit: "%", decimals: 0, color: "#10B981")
s.render()
''',
  ),
  StudioPreset(
    id: 'art_hypotrochoid_gear',
    titleAr: 'تروس سبيروغراف: منحنى الهيبوتروكويد (Hypotrochoid)',
    titleEn: 'Spirograph Gears: Live Hypotrochoid Curve',
    subtitleAr:
        'ترس دائري يتدحرج داخل حلقة ثابتة ليرسم زخارف سبيروغراف هندسية متدرجة الألوان',
    fileName: 'hypotrochoid.quds',
    category: StudioCategory.geometry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 9.0, loop: true)
rIn = viz.slider("r", min: 0.7, max: 2.3, value: 1.4, step: 0.1, label: "نصف قطر الترس r")
pen = viz.slider("d", min: 0.4, max: 2.4, value: 1.8, step: 0.1, label: "ذراع القلم d")

R = 3.5
var pts = []
tMax = 10.0 * m.pi
for i in 0..240:
  u = i * (tMax / 240.0)
  k = (R - rIn) / rIn
  x = (R - rIn) * m.cos(u) + pen * m.cos(k * u)
  y = (R - rIn) * m.sin(u) - pen * m.sin(k * u)
  pts.add([x, y])

uNow = clk.progress * tMax
cx = (R - rIn) * m.cos(uNow)
cy = (R - rIn) * m.sin(uNow)
px = cx + pen * m.cos(((R - rIn) / rIn) * uNow)
py = cy - pen * m.sin(((R - rIn) / rIn) * uNow)

s = viz.scene(title: "ترس سبيروغراف الدوار (Hypotrochoid)", grid: false, axes: false, bounds: [-4.6, 4.6, -4.6, 4.6])
s.circle("outer", [0.0, 0.0], R, stroke: "#334155")
s.circle("gear", [cx, cy], rIn, stroke: "#64748B", fill: "#38BDF814")
s.segment("arm", [cx, cy], [px, py], color: "#F59E0B", strokeWidth: 2.0)
s.curve("spiro", pts, gradient: viz.palette("rainbow"), progress: clk.progress, strokeWidth: 2.3, glow: true, showHead: true)
s.readout("نسبة التروس R/r", R / rIn, decimals: 2, color: "#38BDF8")
s.readout("الذراع d", pen, decimals: 1, color: "#F59E0B")
s.readout("الاكتمال", clk.progress * 100.0, unit: "%", decimals: 0, color: "#10B981")
s.render()
''',
  ),
  // ── Space & Astronomy (+1) ─────────────────────────────────────────────────
  StudioPreset(
    id: 'space_earth_moon_mars',
    titleAr: 'فلك: نظام الشمس والأرض والقمر والمريخ (أوتار الرنين)',
    titleEn: 'Astronomy: Sun-Earth-Moon-Mars Resonance Web',
    subtitleAr:
        'حركة متزامنة للأرض والقمر والمريخ حول الشمس مع رسم أوتار الاقتران الهندسية بين الكوكبين',
    fileName: 'earth_moon_mars.quds',
    category: StudioCategory.astronomy,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
ratio = viz.slider("ratio", min: 1.3, max: 2.5, value: 1.88, step: 0.04, label: "نسبة دورة المريخ")

rE = 2.1
rM = 3.55
rMoon = 0.42
t = clk.progress * 4.0 * m.pi

s = viz.scene(title: "النظام الشمسي: الأرض والقمر والمريخ وأوتار الاقتران", grid: false, axes: false, bounds: [-4.3, 4.3, -4.3, 4.3])
s.circle("orbE", [0.0, 0.0], rE, stroke: "#1E3A5F", dashed: true)
s.circle("orbM", [0.0, 0.0], rM, stroke: "#3F1D2E", dashed: true)

# أوتار الاقتران الهندسية بين الأرض والمريخ
nChords = 4 + (clk.progress * 42.0).round()
for i in 0..<nChords:
  u = i * (4.0 * m.pi / 46.0)
  ex = rE * m.cos(u)
  ey = rE * m.sin(u)
  mx = rM * m.cos(u / ratio)
  my = rM * m.sin(u / ratio)
  s.segment("ch{i}", [ex, ey], [mx, my], color: "#38BDF82A", strokeWidth: 1.0)

ex = rE * m.cos(t)
ey = rE * m.sin(t)
mx = rM * m.cos(t / ratio)
my = rM * m.sin(t / ratio)
lx = ex + rMoon * m.cos(t * 12.0)
ly = ey + rMoon * m.sin(t * 12.0)
dist = m.sqrt((mx - ex) * (mx - ex) + (my - ey) * (my - ey))

s.point("sun", 0.0, 0.0, label: "الشمس", color: "#FACC15", radius: 10.0)
s.point("earth", ex, ey, label: "الأرض", color: "#38BDF8", radius: 6.5)
s.point("moon", lx, ly, color: "#E2E8F0", radius: 3.0)
s.point("mars", mx, my, label: "المريخ", color: "#EF4444", radius: 6.0)
s.segment("link", [ex, ey], [mx, my], color: "#F59E0B", dashed: true)
s.readout("المسافة أرض-مريخ", dist * 0.47, unit: "AU", color: "#F59E0B")
s.readout("دورات الأرض", t / (2.0 * m.pi), unit: "yr", color: "#38BDF8")
s.render()
''',
  ),
  // ── Biology, Medicine & Systems (+3 brand-new folder!) ─────────────────────
  StudioPreset(
    id: 'bio_lotka_volterra',
    titleAr: 'علم البيئة: نموذج الفريسة والمفترس (لوتكا–فولتيرا)',
    titleEn: 'Ecology: Lotka-Volterra Predator-Prey Cycle',
    subtitleAr:
        'تذبذب دوري مترابط لأعداد الفرائس والمفترسات في فضاء الطور البيئي مع دورة مغلقة حية',
    fileName: 'lotka_volterra.quds',
    category: StudioCategory.biology,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 9.0, loop: true)
alpha = viz.slider("a", min: 0.6, max: 1.8, value: 1.1, step: 0.1, label: "تكاثر الفرائس α")
gamma = viz.slider("g", min: 0.3, max: 1.2, value: 0.6, step: 0.1, label: "وفيات المفترس γ")

beta = 0.45
delta = 0.25
var prey = 2.6
var pred = 1.2
dt = 0.04
var orbit = []
for i in 0..220:
  orbit.add([prey, pred])
  dp = (alpha * prey - beta * prey * pred) * dt
  dq = (delta * prey * pred - gamma * pred) * dt
  prey = prey + dp
  pred = pred + dq

idx = (clk.progress * 220.0).round()
cur = orbit[idx]
eqPrey = gamma / delta
eqPred = alpha / beta

s = viz.scene(title: "الدورة البيئية للفريسة والمفترس (لوتكا–فولتيرا)", bounds: [0.0, 6.2, 0.0, 6.2])
s.point("eq", eqPrey, eqPred, label: "التوازن البيئي", color: "#64748B", radius: 5.0)
s.curve("eco", orbit, gradient: viz.palette("viridis"), progress: clk.progress, strokeWidth: 2.8, glow: true, showHead: true)
s.readout("الفرائس (x)", cur[0] * 100.0, decimals: 0, color: "#10B981")
s.readout("المفترسات (y)", cur[1] * 100.0, decimals: 0, color: "#F43F5E")
s.readout("توازن الفرائس", eqPrey * 100.0, decimals: 0, color: "#38BDF8")
s.render()
''',
  ),
  StudioPreset(
    id: 'bio_sir_epidemic',
    titleAr: 'علم الأوبئة: نموذج انتشار العدوى SIR ومعدل التكاثر R₀',
    titleEn: 'Epidemiology: Live SIR Epidemic & Curve Flattening',
    subtitleAr:
        'تتبع المنحنيات الثلاثة (المعرّضون S، المصابون I، المتعافون R) وتأثير تسطيح المنحنى عبر β',
    fileName: 'sir_epidemic.quds',
    category: StudioCategory.biology,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
beta = viz.slider("beta", min: 0.25, max: 1.4, value: 0.75, step: 0.05, label: "معدل العدوى β")
gamma = viz.slider("gamma", min: 0.1, max: 0.5, value: 0.22, step: 0.02, label: "معدل التعافي γ")

var S = 0.98
var I = 0.02
var R = 0.0
dt = 0.2
var cS = []
var cI = []
var cR = []
var sCur = S
var iCur = I
var rCur = R
var iPeak = 0.0
steps = 140
target = (clk.progress * steps).round()
for step in 0..steps:
  day = step * dt
  cS.add([day * 0.32, S * 4.0])
  cI.add([day * 0.32, I * 4.0])
  cR.add([day * 0.32, R * 4.0])
  if I > iPeak:
    iPeak = I
  if step == target:
    sCur = S
    iCur = I
    rCur = R
  dS = -beta * S * I * dt
  dI = (beta * S * I - gamma * I) * dt
  dR = gamma * I * dt
  S = S + dS
  I = I + dI
  R = R + dR

s = viz.scene(title: "نموذج انتشار الوباء SIR وتسطيح منحنى الإصابات", bounds: [-0.3, 9.2, -0.3, 4.5])
s.curve("S", cS, color: "#38BDF8", progress: clk.progress, strokeWidth: 2.5, showHead: true)
s.curve("I", cI, color: "#F43F5E", progress: clk.progress, strokeWidth: 2.9, glow: true, showHead: true)
s.curve("R", cR, color: "#10B981", progress: clk.progress, strokeWidth: 2.5, showHead: true)
s.readout("R₀ (التكاثر)", beta / gamma, decimals: 2, color: "#F59E0B")
s.readout("المصابون I", iCur * 100.0, unit: "%", decimals: 1, color: "#F43F5E")
s.readout("ذروة الوباء", iPeak * 100.0, unit: "%", decimals: 1, color: "#A78BFA")
s.readout("المتعافون R", rCur * 100.0, unit: "%", decimals: 1, color: "#10B981")
s.render()
''',
  ),
  StudioPreset(
    id: 'bio_live_ecg_monitor',
    titleAr: 'الطب الحيوي: تخطيط القلب الكهربائي الحي (ECG P-QRS-T)',
    titleEn: 'Biomedical: Live Scrolling ECG Monitor (P-QRS-T)',
    subtitleAr:
        'موجة تخطيط قلب حيّة متكاملة بمركبات P و QRS و T مع تحكم مباشر بمعدل النبض BPM',
    fileName: 'live_ecg.quds',
    category: StudioCategory.biology,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
bpm = viz.slider("bpm", min: 45.0, max: 145.0, value: 75.0, step: 5.0, label: "معدل النبض (BPM)")

period = 60.0 / bpm
gauss = (x, mu, sig, amp) -> amp * m.exp(-((x - mu) * (x - mu)) / (2.0 * sig * sig))

var pts = []
for i in 0..180:
  x = -5.0 + i * (10.0 / 180.0)
  u = ((x * 0.25 + clk.t) % period + period) % period
  ph = u / period
  mv = gauss(ph, 0.16, 0.025, 0.35) + gauss(ph, 0.30, 0.011, -0.35) + gauss(ph, 0.33, 0.012, 2.55) + gauss(ph, 0.36, 0.012, -0.65) + gauss(ph, 0.56, 0.045, 0.62)
  pts.add([x, mv])

s = viz.scene(title: "شاشة تخطيط القلب الحي ECG — مركبات P-QRS-T", bounds: [-5.2, 5.2, -1.6, 3.2])
s.curve("ecg", pts, color: "#10B981", strokeWidth: 2.6, glow: true, showHead: true)
var diag = "إيقاع جيبي طبيعي"
if bpm < 60.0:
  diag = "بطء نبض"
if bpm > 100.0:
  diag = "تسرّع نبض"
s.readout("النبض HR", bpm, unit: "BPM", decimals: 0, color: "#10B981")
s.readout("دورة النبضة R-R", period * 1000.0, unit: "ms", decimals: 0, color: "#38BDF8")
s.readout("التشخيص", diag, color: "#F59E0B")
s.render()
''',
  ),
  // ── AI & Engineering (+1) ──────────────────────────────────────────────────
  StudioPreset(
    id: 'ai_gradient_descent',
    titleAr: 'ذكاء اصطناعي: النزول التدرجي (Gradient Descent) على دالة خسارة',
    titleEn: 'AI & ML: Live Gradient Descent Optimization',
    subtitleAr:
        'شاهد خوارزمية التعلم الآلي تهبط على منحنى الخسارة J(w) حسب معدل التعلم η وتأثير التجاوز',
    fileName: 'gradient_descent.quds',
    category: StudioCategory.math3d,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
lr = viz.slider("lr", min: 0.04, max: 0.48, value: 0.16, step: 0.02, label: "معدل التعلم η")

loss = (w) -> 0.14 * w * w + 0.75 * m.cos(1.4 * w) + 1.0
grad = (w) -> 0.28 * w - 1.05 * m.sin(1.4 * w)

var curve = []
for i in 0..140:
  x = -4.5 + i * (9.0 / 140.0)
  curve.add([x, loss(x)])

nSteps = 1 + (clk.progress * 24.0).round()
var w = -4.1
var trail = [[w, loss(w)]]
for k in 0..<nSteps:
  w = w - lr * grad(w)
  w = m.max(-4.5, m.min(4.5, w))
  trail.add([w, loss(w)])

curL = loss(w)
curG = grad(w)
s = viz.scene(title: "النزول التدرجي (Gradient Descent) على دالة الخسارة J(w)", bounds: [-4.8, 4.8, -0.3, 4.6])
s.curve("loss", curve, color: "#475569", strokeWidth: 2.2)
s.curve("path", trail, gradient: viz.palette("fire"), strokeWidth: 2.6, glow: true, showHead: true)
s.point("ball", w, curL, label: "w", color: "#FACC15", radius: 6.5)
s.readout("الخطوة Epoch", "{nSteps}", color: "#38BDF8")
s.readout("الوزن w", w, decimals: 3, color: "#F59E0B")
s.readout("الخسارة J(w)", curL, decimals: 3, color: "#10B981")
s.readout("الميل ∇J", curG, decimals: 3, color: "#F43F5E")
s.render()
''',
  ),
];
