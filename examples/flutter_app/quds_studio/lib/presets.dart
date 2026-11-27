/// Curated Quds scientific presets for Quds Studio.
library;

class StudioPreset {
  const StudioPreset({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.fileName,
    required this.code,
    this.defaultBreakpoints = const {},
    this.defaultPolicy = StudioPolicyMode.standard,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String fileName;
  final String code;
  final Set<int> defaultBreakpoints;
  final StudioPolicyMode defaultPolicy;
}

enum StudioPolicyMode {
  standard,
  strictSandbox,
  systemBridge,
  custom,
}

const studioPresets = <StudioPreset>[
  StudioPreset(
    id: 'interactive_geometry',
    titleAr: 'هندسة تفاعلية: مثلث ومركز الثقل',
    titleEn: 'Interactive Geometry: Triangle & Centroid',
    subtitleAr:
        'اسحب النقاط A, B, C وحرّك منزلق نصف القطر لإعادة الحساب لحظياً',
    fileName: 'triangle_lab.quds',
    code: '''use quds:math::vector show Vec2
use quds:math::geometry show polygonCentroid, triangulatePolygon
use quds:viz as viz

# نقاط قابلة للسحب المباشر على اللوحة الهندسية
A = viz.point("A", 0.0, 0.0, draggable: true, color: "#38BDF8")
B = viz.point("B", 6.0, 0.0, draggable: true, color: "#38BDF8")
C = viz.point("C", 2.0, 4.5, draggable: true, color: "#38BDF8")
radius = viz.slider("radius", min: 0.5, max: 4.0, value: 1.4, step: 0.1, label: "نصف قطر الدائرة")

poly = [Vec2(A.x, A.y), Vec2(B.x, B.y), Vec2(C.x, C.y)]
center = polygonCentroid(poly)
tris = triangulatePolygon(poly)

scene = viz.scene(title: "المثلث التفاعلي ومركز ثقله", grid: true, interactive: true)
scene.polygon("tri", poly, fill: "#2563EB28", stroke: "#38BDF8")
scene.mesh("mesh", tris, vertices: poly)
scene.segment("mA", A, center, color: "#94A3B8", dashed: true)
scene.segment("mB", B, center, color: "#94A3B8", dashed: true)
scene.segment("mC", C, center, color: "#94A3B8", dashed: true)
scene.circle("cG", center, radius, stroke: "#10B981", fill: "#10B98118", dashed: true)
scene.angle("angA", B, A, C, showDegrees: true, color: "#F59E0B")
scene.point("A", A)
scene.point("B", B)
scene.point("C", C)
scene.point("G", center, label: "G (المركز)", color: "#EF4444")
scene.render()

print "المركز G = ({center.x.toStringAsFixed(2)}, {center.y.toStringAsFixed(2)}) | المثلثات = {tris.length}"
''',
  ),
  StudioPreset(
    id: 'signal_plot',
    titleAr: 'رسم دالة موجية وجدول إحصائي',
    titleEn: 'Wave Signal Plot & Statistics',
    subtitleAr: 'حساب sin(x) عبر quds:math مع رسم بياني وجدول بيانات',
    fileName: 'signal_lab.quds',
    code: '''use quds:math
use quds:viz as viz

freq = viz.slider("freq", min: 0.5, max: 4.0, value: 1.5, step: 0.25, label: "التردد (Hz)")
amp = viz.slider("amp", min: 0.5, max: 3.0, value: 1.2, step: 0.1, label: "السعة")

var xs: List<double> = []
var ys: List<double> = []
for i in 0..40:
  t = i * 0.2
  xs.add(t)
  ys.add(amp * sin(freq * t))

avg = mean(ys)
viz.plot(xs, ys, title: "الموجة الجيبية y = A·sin(f·t)", xLabel: "الزمن t", yLabel: "y(t)", color: "#38BDF8")
viz.table(["المقياس", "القيمة"], [["التردد", freq], ["السعة", amp], ["المتوسط", avg.toStringAsFixed(4)]], title: "ملخص الإشارة")
print "تم رسم {xs.length} نقطة | المتوسط = {avg.toStringAsFixed(4)}"
''',
  ),
  StudioPreset(
    id: 'debugger_lab',
    titleAr: 'مختبر التصحيح ونقاط التوقف (Breakpoints)',
    titleEn: 'Debugger & Breakpoints Lab',
    subtitleAr:
        'اضغط تشغيل للتوقف عند نقطة التوقف واستخدم Step Into / Over وفحص المتغيرات',
    fileName: 'debug_lab.quds',
    defaultBreakpoints: {7},
    code: '''stepEnergy(n: int) -> int:
  squared = n * n
  return squared + n

var total = 0
for i in 1..5:
  delta = stepEnergy(i)
  total += delta
  print "i={i} -> delta={delta}, total={total}"

print "المجموع النهائي = {total}"
''',
  ),
  StudioPreset(
    id: 'policy_bridge',
    titleAr: 'اختبار السياسات وجسر النظام المقيّد',
    titleEn: 'Policy Sandbox & System Bridge',
    subtitleAr:
        'جرّب التبديل بين وضع Sandbox المقيّد ووضع جسر النظام بصلاحيات محددة',
    fileName: 'policy_lab.quds',
    defaultPolicy: StudioPolicyMode.systemBridge,
    code: '''use quds:math
use host:sensors as sensors

# دالة مضيفة محمية بصلاحية sensors.read
tempC = sensors.readCelsius(1)
tempK = tempC + 273.15
print "قراءة الحساس = {tempC} °C ({tempK.toStringAsFixed(2)} K)"
''',
  ),
  StudioPreset(
    id: 'physics_pendulum',
    titleAr: 'محاكاة زمنية: البندول الفيزيائي مع القراءات',
    titleEn: 'Time-Based Physics: Live Pendulum & Telemetry',
    subtitleAr:
        'حركة زمنية مستمرة للبندول اللاخطي مع متجه السرعة ومسار متدرج وقراءات الزاوية والطاقة الحية',
    fileName: 'pendulum_60fps.quds',
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 20.0, loop: true)
len = viz.slider("len", min: 1.5, max: 4.0, value: 2.8, step: 0.1, label: "طول الخيط L (م)")
amp = viz.slider("amp", min: 0.2, max: 1.4, value: 0.95, step: 0.05, label: "الزاوية الابتدائية θ₀")
damp = viz.slider("damp", min: 0.0, max: 0.4, value: 0.06, step: 0.02, label: "التخميد b")
g = 9.81
mass = 1.0

# تكامل عددي حي للبندول اللاخطي θ'' = -(g/L)sin(θ) - b·ω مع دعم التحريك الزمني
omega0 = m.sqrt(g / len)
decay = m.exp(-0.5 * damp * clk.t)
omegaD = m.sqrt((omega0 * omega0 - 0.25 * damp * damp).abs())
theta = amp * decay * m.cos(omegaD * clk.t)
omega = -amp * decay * (omegaD * m.sin(omegaD * clk.t) + 0.5 * damp * m.cos(omegaD * clk.t))

bobX = len * m.sin(theta)
bobY = -len * m.cos(theta)
vx = len * omega * m.cos(theta)
vy = len * omega * m.sin(theta)
speed = m.sqrt(vx * vx + vy * vy)
ke = 0.5 * mass * speed * speed
pe = mass * g * len * (1.0 - m.cos(theta))
period = 2.0 * m.pi / omega0

var trailPts = []
for i in 0..32:
  ti = clk.t - (32 - i) * 0.035
  if ti >= 0.0:
    di = m.exp(-0.5 * damp * ti)
    thi = amp * di * m.cos(omegaD * ti)
    trailPts.add([len * m.sin(thi), -len * m.cos(thi)])

scene = viz.scene(title: "محاكاة البندول الفيزيائي الحية", grid: true, axes: true, bounds: [-4.4, 4.4, -4.6, 1.0])
scene.segment("ref", [0.0, 0.0], [0.0, -len - 0.3], color: "#475569", dashed: true, strokeWidth: 1.4)
scene.trail("path", trailPts, gradient: viz.palette("ocean"), strokeWidth: 2.6, glow: true)
scene.angle("ang", [0.0, -len], [0.0, 0.0], [bobX, bobY], color: "#F59E0B", showDegrees: true)
scene.segment("rod", [0.0, 0.0], [bobX, bobY], color: "#CBD5E1", strokeWidth: 2.6)
scene.vector("vel", [bobX, bobY], [bobX + vx * 0.35, bobY + vy * 0.35], label: "v", color: "#10B981")
scene.point("pivot", 0.0, 0.0, label: "O", color: "#F59E0B", radius: 5.5)
scene.point("bob", bobX, bobY, label: "m", color: "#EF4444", radius: 9.0)

scene.readout("t", clk.t, unit: "s", color: "#38BDF8")
scene.readout("θ", theta * 180.0 / m.pi, unit: "°", decimals: 1, color: "#F59E0B")
scene.readout("ω", omega, unit: "rad/s", color: "#A855F7")
scene.readout("v", speed, unit: "m/s", color: "#10B981")
scene.readout("KE", ke, unit: "J", color: "#F43F5E")
scene.readout("PE", pe, unit: "J", color: "#60A5FA")
scene.readout("T", period, unit: "s", color: "#FACC15")
scene.render()

print "t={clk.t.toStringAsFixed(2)}s | θ={(theta * 180.0 / m.pi).toStringAsFixed(1)}° | v={speed.toStringAsFixed(2)} m/s | E={(ke + pe).toStringAsFixed(2)} J"
''',
  ),
  StudioPreset(
    id: 'surface3d_vector_field',
    titleAr: 'سطح 3D تفاعلي وحقل متجهات',
    titleEn: 'Interactive 3D Surface & Vector Field',
    subtitleAr:
        'اسحب السطح ثلاثي الأبعاد لتدويره باللمس مع حقل دوّامي ثنائي الأبعاد',
    fileName: 'surface3d_lab.quds',
    code: '''use dart:math as m
use quds:viz as viz

freq = viz.slider("freq", min: 0.8, max: 3.0, value: 1.6, step: 0.1, label: "تردد الموجة")
palette = viz.select("palette", ["viridis", "plasma", "emerald"], value: "plasma", label: "التدرّج اللوني")

ripple(x: double, y: double) -> double:
  r = m.sqrt(x * x + y * y)
  return m.sin(freq * r) / (r + 0.6)

viz.surface3d(ripple, xMin: -4.0, xMax: 4.0, yMin: -4.0, yMax: 4.0, steps: 16, title: "سطح موجي ثلاثي الأبعاد z = sin(fr)/(r+0.6)", colorMap: palette)

vortex(x: double, y: double) -> List<double>:
  return [-y - 0.15 * x, x - 0.15 * y]

viz.vectorField(vortex, xMin: -3.0, xMax: 3.0, yMin: -3.0, yMax: 3.0, steps: 9, title: "حقل متجهات دوّامي")
print "تم بناء سطح 17×17 ثلاثي الأبعاد + حقل متجهات ({palette})"
''',
  ),
  StudioPreset(
    id: 'graph_shortest_path',
    titleAr: 'شبكات وخوارزميات: أقصر مسار',
    titleEn: 'Graph & Shortest Path Visualizer',
    subtitleAr: 'تمثيل شبكة موزونة وإبراز المسار الأقصر بين العقد تلقائياً',
    fileName: 'graph_lab.quds',
    code: '''use quds:viz as viz

target = viz.select("target", ["D", "E", "F"], value: "E", label: "العقدة الهدف")

g = viz.graph(title: "شبكة المدن والمسار الأقصر", directed: false)
g.circleLayout(["A", "B", "C", "D", "E", "F"], radius: 4.0)
g.edge("A", "B", weight: 2.0)
g.edge("B", "C", weight: 3.0)
g.edge("C", "D", weight: 2.0)
g.edge("B", "F", weight: 4.0)
g.edge("F", "E", weight: 2.0)
g.edge("D", "E", weight: 5.0)
g.edge("A", "F", weight: 7.0)

path = if target == "D": ["A", "B", "C", "D"] else: (if target == "E": ["A", "B", "F", "E"] else: ["A", "B", "F"])
g.highlightPath(path)
g.render()

print "المسار الأقصر إلى {target}: {path}"
''',
  ),
  StudioPreset(
    id: 'data_csv_fft',
    titleAr: 'تحليل بيانات CSV وطيف FFT',
    titleEn: 'DataTable CSV, Regression & FFT Spectrum',
    subtitleAr:
        'استخدام quds:data لتحليل جدول CSV وانحدار خطي وتحليل ترددات FFT',
    fileName: 'data_fft_lab.quds',
    code: '''use dart:math as m
use quds:data as data
use quds:viz as viz

tone = viz.slider("tone", min: 2.0, max: 20.0, value: 8.0, step: 1.0, label: "تردد الإشارة (Hz)")

csv = "city,temp,sales\\nالقدس,22.0,120.0\\nالخليل,20.0,100.0\\nالقدس,26.0,160.0\\nنابلس,28.0,180.0"
df = data.parseCsv(csv)
reg = df.linearRegression("temp", "sales")
byCity = df.groupBy("city", "sales", op: "mean").sortBy("mean_sales", desc: true)
byCity.toVizTable(title: "متوسط المبيعات حسب المدينة")

sr = 64.0
var sig = []
for i in 0..63:
  t = i / sr
  sig.add(2.0 * m.sin(2.0 * m.pi * tone * t) + 0.6 * m.sin(2.0 * m.pi * 22.0 * t))

spec = data.fftMagnitude(sig, sampleRate: sr)
viz.plot(spec["freqs"], spec["magnitudes"], title: "طيف الترددات FFT (الذروة = {spec['peakFreq'].toStringAsFixed(1)} Hz)", xLabel: "Hz", yLabel: "|X(f)|", color: "#10B981")

print "انحدار خطي: slope={reg['slope'].toStringAsFixed(1)}, R²={reg['r2'].toStringAsFixed(2)} | ذروة FFT = {spec['peakFreq'].toStringAsFixed(1)} Hz"
''',
  ),
  StudioPreset(
    id: 'micro_app_form',
    titleAr: 'تطبيق مصغّر: حاسبة تسعير فورية',
    titleEn: 'Micro-App: Instant Quote Calculator',
    subtitleAr: 'حقول نص وأرقام وقائمة منسدلة وأزرار تتحول فوراً لتطبيق تفاعلي',
    fileName: 'quote_microapp.quds',
    code: '''use quds:viz as viz

client = viz.input("client", value: "شركة الأفق", label: "اسم العميل")
amount = viz.number("amount", value: 1500.0, min: 0.0, max: 100000.0, label: "المبلغ الأساسي")
plan = viz.select("plan", ["أساسي", "متقدم", "شركات"], value: "متقدم", label: "الباقة")
includeTax = viz.toggle("tax", value: true, label: "شامل الضريبة 15%")
recalc = viz.button("recalc", label: "تأكيد العرض")

discount = if plan == "شركات": 0.20 else: (if plan == "متقدم": 0.10 else: 0.0)
afterDisc = amount * (1.0 - discount)
taxVal = if includeTax: afterDisc * 0.15 else: 0.0
finalTotal = afterDisc + taxVal

summary = map:
  "العميل": client
  "الباقة": plan
  "الخصم": "{(discount * 100).toStringAsFixed(0)}%"
  "الضريبة": "{taxVal.toStringAsFixed(2)}"
  "الإجمالي النهائي": "{finalTotal.toStringAsFixed(2)}"
  "عدد التأكيدات": recalc

viz.form(summary, title: "حاسبة عروض الأسعار (Micro-App)", summary: "تطبيق مصغّر مولّد بالكامل من 20 سطر Quds")
print "العرض لـ {client}: الإجمالي = {finalTotal.toStringAsFixed(2)}"
''',
  ),
  StudioPreset(
    id: 'profiler_bytecode_lab',
    titleAr: 'شجرة الاستدعاءات + Bytecode VM',
    titleEn: 'Call Tree, Time-Travel & Bytecode VM',
    subtitleAr:
        'استكشف شجرة fib العودية ومناطق السخونة وفعّل وضع Bytecode VM للسرعة الفائقة',
    fileName: 'perf_lab.quds',
    code: '''fib(n: int) -> int:
  if n <= 2:
    return 1
  return fib(n - 1) + fib(n - 2)

var acc = 0
for i in 1..6:
  v = fib(i)
  acc += v
  print "fib({i}) = {v}"

print "المجموع = {acc}"
''',
  ),
  StudioPreset(
    id: 'animated_butterfly',
    titleAr: 'رسم حركي متدرج: فراشة تيمبل فاي',
    titleEn: 'Animated Gradient Curve: Temple Fay Butterfly',
    subtitleAr:
        'رسم منحنى الفراشة بالكود نقطة بنقطة من البداية للنهاية مع تدرج ألوان وتوهّج وقراءات حية',
    fileName: 'butterfly_gradient.quds',
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
paletteName = viz.select("palette", ["butterfly", "rainbow", "aurora", "sunset", "neon", "ocean"], value: "butterfly", label: "تدرج الألوان")
scale = viz.slider("scale", min: 0.6, max: 1.35, value: 1.0, step: 0.05, label: "حجم الفراشة")
strokeW = viz.slider("stroke", min: 1.5, max: 4.5, value: 2.8, step: 0.1, label: "سمك الخط")

# منحنى فراشة تيمبل فاي: r(u) = e^cos(u) - 2cos(4u) - sin^5(u/12)
totalPts = 320
maxU = 12.0 * m.pi
var pts = []
for i in 0..totalPts:
  u = (i / totalPts) * maxU
  s = m.sin(u / 12.0)
  r = m.exp(m.cos(u)) - 2.0 * m.cos(4.0 * u) - s * s * s * s * s
  pts.add([scale * r * m.sin(u), scale * r * m.cos(u)])

p = clk.progress
curU = p * maxU
curS = m.sin(curU / 12.0)
curR = m.exp(m.cos(curU)) - 2.0 * m.cos(4.0 * curU) - curS * curS * curS * curS * curS
curX = scale * curR * m.sin(curU)
curY = scale * curR * m.cos(curU)
drawn = (p * totalPts).round()

scene = viz.scene(title: "فراشة تيمبل فاي (رسم حركي بتدرج ألوان)", grid: true, axes: true, bounds: [-4.6, 4.6, -4.0, 4.6])
scene.curve("butterfly", pts, gradient: viz.palette(paletteName), progress: p, strokeWidth: strokeW, glow: true, showHead: true)
scene.readout("الزمن", clk.t, unit: "s", color: "#38BDF8")
scene.readout("الاكتمال", p * 100.0, unit: "%", decimals: 1, color: "#FF007F")
scene.readout("النقاط", "{drawn}/{totalPts}", color: "#FFD166")
scene.readout("r(u)", curR, color: "#06D6A0")
scene.readout("x", curX, color: "#A855F7")
scene.readout("y", curY, color: "#EC4899")
scene.render()

print "t={clk.t.toStringAsFixed(2)}s | الاكتمال={(p * 100.0).toStringAsFixed(1)}% | الرأس=({curX.toStringAsFixed(2)}, {curY.toStringAsFixed(2)})"
''',
  ),
];
