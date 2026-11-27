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
];
