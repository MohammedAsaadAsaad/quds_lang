/// Curated Quds scientific, real-world simulation, games & VM presets for Quds Studio.
library;

import 'presets_apps.dart';
import 'presets_benchmarks.dart';
import 'presets_cs_science.dart';
import 'presets_domains.dart';
import 'presets_extra.dart';
import 'presets_games.dart';
import 'presets_pen.dart';
import 'presets_simulations.dart';

/// Top-level thematic super-groups organizing all 18 Studio categories cleanly.
enum StudioDomain {
  gamesAndSims,
  sciences,
  mathAndCs,
  languageAndVm,
}

extension StudioDomainLabels on StudioDomain {
  String label(bool isArabic) => switch (this) {
        StudioDomain.gamesAndSims => isArabic
            ? '🖊️ القلم والتطبيقات والألعاب والمحاكاة'
            : '🖊️ Pen, Apps, Games & Sims',
        StudioDomain.sciences =>
          isArabic ? '🔬 العلوم والطبيعة والفضاء' : '🔬 Sciences & Nature',
        StudioDomain.mathAndCs => isArabic
            ? '📐 الرياضيات والذكاء والحوسبة'
            : '📐 Math, AI & Computing',
        StudioDomain.languageAndVm => isArabic
            ? '⚡ لغة قدس والأداء الفائق VM'
            : '⚡ Quds 1.2 & VM Performance',
      };

  List<StudioCategory> get categories => switch (this) {
        StudioDomain.gamesAndSims => const [
            StudioCategory.pen,
            StudioCategory.apps,
            StudioCategory.games,
            StudioCategory.simulations,
            StudioCategory.engineering,
            StudioCategory.finance,
          ],
        StudioDomain.sciences => const [
            StudioCategory.physics,
            StudioCategory.chemistry,
            StudioCategory.waves,
            StudioCategory.astronomy,
            StudioCategory.biology,
          ],
        StudioDomain.mathAndCs => const [
            StudioCategory.mathematics,
            StudioCategory.geometry,
            StudioCategory.math3d,
            StudioCategory.algorithms,
          ],
        StudioDomain.languageAndVm => const [
            StudioCategory.language,
            StudioCategory.benchmarks,
            StudioCategory.tools,
          ],
      };
}

enum StudioCategory {
  pen,
  apps,
  games,
  simulations,
  engineering,
  finance,
  physics,
  chemistry,
  mathematics,
  waves,
  geometry,
  astronomy,
  biology,
  math3d,
  algorithms,
  language,
  tools,
  benchmarks,
}

extension StudioCategoryLabels on StudioCategory {
  StudioDomain get domain => switch (this) {
        StudioCategory.pen ||
        StudioCategory.apps ||
        StudioCategory.games ||
        StudioCategory.simulations ||
        StudioCategory.engineering ||
        StudioCategory.finance =>
          StudioDomain.gamesAndSims,
        StudioCategory.physics ||
        StudioCategory.chemistry ||
        StudioCategory.waves ||
        StudioCategory.astronomy ||
        StudioCategory.biology =>
          StudioDomain.sciences,
        StudioCategory.mathematics ||
        StudioCategory.geometry ||
        StudioCategory.math3d ||
        StudioCategory.algorithms =>
          StudioDomain.mathAndCs,
        StudioCategory.language ||
        StudioCategory.benchmarks ||
        StudioCategory.tools =>
          StudioDomain.languageAndVm,
      };

  String label(bool isArabic) => switch (this) {
        StudioCategory.pen =>
          isArabic ? 'رسوم القلم (quds:pen)' : 'Pen Graphics (quds:pen)',
        StudioCategory.apps =>
          isArabic ? 'التطبيقات التفاعلية' : 'Interactive Apps',
        StudioCategory.games =>
          isArabic ? 'الألعاب التفاعلية' : 'Interactive Games',
        StudioCategory.simulations =>
          isArabic ? 'محاكاة العالم الحقيقي' : 'Real-World Sims',
        StudioCategory.engineering =>
          isArabic ? 'الهندسة والإلكترونيات' : 'Engineering & Robotics',
        StudioCategory.finance =>
          isArabic ? 'المال والأعمال والاقتصاد' : 'Finance & Econ',
        StudioCategory.physics => isArabic ? 'الفيزياء والميكانيكا' : 'Physics',
        StudioCategory.chemistry =>
          isArabic ? 'الكيمياء والتفاعلات' : 'Chemistry',
        StudioCategory.mathematics =>
          isArabic ? 'الرياضيات والتحليل' : 'Mathematics',
        StudioCategory.waves =>
          isArabic ? 'الموجات والبصريات' : 'Waves & Optics',
        StudioCategory.geometry =>
          isArabic ? 'الهندسة والفن الرياضي' : 'Geometry & Art',
        StudioCategory.astronomy =>
          isArabic ? 'الفلك والفضاء والرادار' : 'Space & Radar',
        StudioCategory.biology =>
          isArabic ? 'الأحياء والطب والنظم' : 'Biology & Medicine',
        StudioCategory.math3d =>
          isArabic ? 'الذكاء الاصطناعي و3D' : 'AI, 3D & Data',
        StudioCategory.algorithms =>
          isArabic ? 'الخوارزميات وهياكل البيانات' : 'Algorithms & CS',
        StudioCategory.language =>
          isArabic ? 'ميزات لغة قدس 1.2' : 'Quds 1.2 Showcase',
        StudioCategory.tools => isArabic ? 'الأدوات والمصحح' : 'Tools & Apps',
        StudioCategory.benchmarks =>
          isArabic ? 'اختبارات الأداء VM' : 'VM Benchmarks',
      };

  String shortLabel(bool isArabic) => switch (this) {
        StudioCategory.pen => isArabic ? '🖊️ القلم' : '🖊️ Pen',
        StudioCategory.apps => isArabic ? '📱 تطبيقات' : '📱 Apps',
        StudioCategory.games => isArabic ? '🎮 ألعاب' : '🎮 Games',
        StudioCategory.simulations => isArabic ? '🏙️ محاكاة' : '🏙️ Sims',
        StudioCategory.engineering => isArabic ? '⚙️ هندسة' : '⚙️ Eng',
        StudioCategory.finance => isArabic ? '💹 مال' : '💹 Finance',
        StudioCategory.physics => isArabic ? 'فيزياء' : 'Physics',
        StudioCategory.chemistry => isArabic ? 'كيمياء' : 'Chemistry',
        StudioCategory.mathematics => isArabic ? 'رياضيات' : 'Math',
        StudioCategory.waves => isArabic ? 'موجات' : 'Waves',
        StudioCategory.geometry => isArabic ? 'فن هندسي' : 'Art',
        StudioCategory.astronomy => isArabic ? 'فضاء' : 'Space',
        StudioCategory.biology => isArabic ? 'طب وبيئة' : 'Bio/Med',
        StudioCategory.math3d => isArabic ? 'AI و3D' : 'AI & 3D',
        StudioCategory.algorithms => isArabic ? 'خوارزميات' : 'Algos',
        StudioCategory.language => isArabic ? 'قدس 1.2' : 'Quds 1.2',
        StudioCategory.tools => isArabic ? 'أدوات' : 'Tools',
        StudioCategory.benchmarks => isArabic ? '⚡ أداء VM' : '⚡ Bench',
      };

  String description(bool isArabic) => switch (this) {
        StudioCategory.pen => isArabic
            ? 'زخارف نجمية، شجرة فراكتل، ندفة كوخ، حلزون قوس قزح، سيربينسكي، ماندالا، هيلبرت ومنحنى التنين'
            : 'Geometric stars, fractal tree, Koch snowflake, rainbow spiral, Sierpinski, mandala, Hilbert & dragon',
        StudioCategory.apps => isArabic
            ? 'الفواتير، مدير المهام الحي، محوّل العملات والوحدات، تقسيم الفاتورة، GPA، السعرات، الاختبارات والمخزون'
            : 'Invoice Builder, Stateful Tasks, Unit/Currency Hub, Bill Splitter, GPA, Macros, Quiz & Inventory',
        StudioCategory.games => isArabic
            ? 'بونج، كسر الطوب، الأفعى، المدفع، النيازك، فلابي، الفقاعات، السباق، إكس-أو والمتاهة'
            : 'Pong, Brick Breaker, Snake, Artillery, Asteroids, Flappy, Racer & Maze',
        StudioCategory.simulations => isArabic
            ? 'المرور، المصعد، الطاقة الشمسية، PID، التكييف، الطوارئ، السد، المسيّرة، الحرائق والطقس'
            : 'Traffic, Elevator, Solar Grid, PID, HVAC, ER Queue, Dam, Drone & Storm',
        StudioCategory.engineering => isArabic
            ? 'ذراع روبوتية IK، محرك المكبس، التروس، العوارض، البوابات المنطقية، RC والجسور والطيران'
            : 'Robot Arm IK, Piston, Gears, Beams, Logic Gates, RC Filter & Airfoil',
        StudioCategory.finance => isArabic
            ? 'البورصة SMA، الفائدة المركبة، القرض العقاري، العرض والطلب، التعادل، التضخم والزكاة'
            : 'Stocks SMA, Compound Interest, Mortgage, Market Eq, Break-Even & Budget',
        StudioCategory.physics => isArabic
            ? 'البندول، الشق المزدوج، فضاء الطور، السيكلوترون، الكم، التصادمات، دوبلر ولورينز'
            : 'Pendulums, double-slit, phase space, cyclotron, quantum & Doppler',
        StudioCategory.chemistry => isArabic
            ? 'الحركية، المعايرة pH، ذرة بور، ماكسويل، الاتزان والاضمحلال'
            : 'Kinetics, pH titration, Bohr spectra, equilibrium & decay',
        StudioCategory.mathematics => isArabic
            ? 'ماندلبروت، الحلزون الذهبي، تايلور، ريمان، نيوتن، بيزييه والسيكلويد'
            : 'Mandelbrot, golden spiral, Taylor, Riemann, Newton & Bezier',
        StudioCategory.waves => isArabic
            ? 'فورييه، الموجات الموقوفة، التداخل، سنيل البصري وAM/FM'
            : 'Fourier epicycles, harmonics, optics & AM/FM modulation',
        StudioCategory.geometry => isArabic
            ? 'الفراشة، الوردة، نجمة مورير، هيبوتروكويد والهندسة التفاعلية'
            : 'Butterfly, spirograph, Maurer rose & interactive geometry',
        StudioCategory.astronomy => isArabic
            ? 'مدار هوهمان للمريخ، كسوف الشمس، مدارات كبلر، الأرض والقمر والرادار'
            : 'Mars Hohmann transfer, solar eclipse, Kepler orbits & live radar',
        StudioCategory.biology => isArabic
            ? 'لوتكا–فولتيرا البيئي، انتشار الأوبئة SIR وتخطيط القلب ECG'
            : 'Predator-prey ecology, SIR epidemic & live ECG monitor',
        StudioCategory.math3d => isArabic
            ? 'K-Means، الشبكات العصبية، النزول التدرجي، السطوح ثلاثية الأبعاد والحقول'
            : 'K-Means, Neural Net, Gradient Descent, 3D surfaces & vector fields',
        StudioCategory.algorithms => isArabic
            ? 'الفرز الحي، البحث الثنائي، ديكسترا، لعبة الحياة، BST، التشفير، الضغط وKnapsack'
            : 'Sorting, Binary Search, Dijkstra, Game of Life, BST, Cipher & DP',
        StudioCategory.language => isArabic
            ? 'تحميل المعاملات + augment، دمج النصوص، sealed/match، Result، sync* و with?'
            : 'Operators + augment, String + any, sealed/match, Result & generators',
        StudioCategory.tools => isArabic
            ? 'المصحح، الجسر الآمن، Bytecode VM، النماذج والرسوم البيانية'
            : 'Debugger, sandbox bridge, Bytecode VM & micro-app forms',
        StudioCategory.benchmarks => isArabic
            ? 'اختبارات ضغط ثقيلة لمحرك Register VM مع قياس الزمن (Mandelbrot, Fib, Sieve, N-Body, MatMul)'
            : 'Heavy CPU benchmarks with millisecond timing on Register VM vs AST',
      };
}

class StudioPreset {
  const StudioPreset({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.fileName,
    required this.code,
    this.category = StudioCategory.geometry,
    this.isAnimated = false,
    this.defaultBreakpoints = const {},
    this.defaultPolicy = StudioPolicyMode.standard,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String fileName;
  final String code;
  final StudioCategory category;
  final bool isAnimated;
  final Set<int> defaultBreakpoints;
  final StudioPolicyMode defaultPolicy;
}

enum StudioPolicyMode {
  standard,
  strictSandbox,
  systemBridge,
  benchmark,
  custom,
}

final List<StudioPreset> studioPresets = <StudioPreset>[
  ..._baseStudioPresets,
  ...extraAnimatedPresets,
  ...studioPenPresets,
  ...studioAppPresets,
  ...gamePresets,
  ...realWorldSimPresets,
  ...financeAndEngineeringPresets,
  ...csLanguageAndBonusPresets,
  ...benchmarkPresets,
];

const _baseStudioPresets = <StudioPreset>[
  StudioPreset(
    id: 'interactive_geometry',
    titleAr: 'هندسة تفاعلية: مثلث ومركز الثقل',
    titleEn: 'Interactive Geometry: Triangle & Centroid',
    subtitleAr:
        'اسحب النقاط A, B, C وحرّك منزلق نصف القطر لإعادة الحساب لحظياً',
    fileName: 'triangle_lab.quds',
    category: StudioCategory.geometry,
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
    category: StudioCategory.waves,
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
    category: StudioCategory.tools,
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
    category: StudioCategory.tools,
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
    category: StudioCategory.physics,
    isAnimated: true,
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
    category: StudioCategory.math3d,
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
    category: StudioCategory.math3d,
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
    category: StudioCategory.math3d,
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
    category: StudioCategory.tools,
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
    category: StudioCategory.tools,
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
    category: StudioCategory.geometry,
    isAnimated: true,
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
  // -------------------------------------------------------------------------
  // 10 Diverse Minimal-Code Real-Time Motion Examples
  // -------------------------------------------------------------------------
  StudioPreset(
    id: 'solar_orbit',
    titleAr: 'فلك: مدار كوكب وقمر حول الشمس',
    titleEn: 'Astronomy: Planet & Moon Elliptical Orbit',
    subtitleAr:
        'حركة كوكب في مدار إهليلجي مع قمر يدور حوله ومسار متدرج وقراءات المسافة والسرعة',
    fileName: 'solar_orbit.quds',
    category: StudioCategory.astronomy,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: true)
ecc = viz.slider("ecc", min: 0.0, max: 0.65, value: 0.35, step: 0.05, label: "اللامركزية e")
a = 3.6
b = a * m.sqrt(1.0 - ecc * ecc)
ang = clk.progress * 2.0 * m.pi

px = a * m.cos(ang) - a * ecc
py = b * m.sin(ang)
mx = px + 0.75 * m.cos(ang * 7.0)
my = py + 0.75 * m.sin(ang * 7.0)
dist = m.sqrt(px * px + py * py)

var orbit = []
var moonTrail = []
for i in 0..80:
  u = (i / 80.0) * 2.0 * m.pi
  orbit.add([a * m.cos(u) - a * ecc, b * m.sin(u)])
for i in 0..24:
  u = ang - (24 - i) * 0.05
  moonTrail.add([a * m.cos(u) - a * ecc + 0.75 * m.cos(u * 7.0), b * m.sin(u) + 0.75 * m.sin(u * 7.0)])

s = viz.scene(title: "مدار كوكب وقمر حول الشمس", bounds: [-6.2, 4.8, -4.5, 4.5])
s.curve("orbit", orbit, color: "#334155", strokeWidth: 1.4)
s.trail("mtrail", moonTrail, gradient: viz.palette("ocean"), strokeWidth: 2.0)
s.segment("radius", [0.0, 0.0], [px, py], color: "#F59E0B", dashed: true)
s.point("sun", 0.0, 0.0, label: "الشمس", color: "#FACC15", radius: 11.0)
s.point("planet", px, py, label: "كوكب", color: "#38BDF8", radius: 7.0)
s.point("moon", mx, my, label: "قمر", color: "#E2E8F0", radius: 4.0)
s.readout("المسافة r", dist, unit: "AU", color: "#38BDF8")
s.readout("زاوية المدار", ang * 180.0 / m.pi, unit: "°", decimals: 0, color: "#FACC15")
s.readout("e", ecc, color: "#A855F7")
s.render()
''',
  ),
  StudioPreset(
    id: 'spirograph_rose',
    titleAr: 'فن رياضي: الوردة والسبيروغراف المتدرج',
    titleEn: 'Parametric Art: Animated Gradient Rose Curve',
    subtitleAr:
        'ارسم وردة رياضية r = 3.5·cos(k·u) بتدرج قوس قزح من أول نقطة لآخرها بـ 16 سطر كود',
    fileName: 'rose_spirograph.quds',
    category: StudioCategory.geometry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
k = viz.slider("k", min: 2.0, max: 7.0, value: 5.0, step: 1.0, label: "عدد البتلات k")

var pts = []
for i in 0..240:
  u = (i / 240.0) * 2.0 * m.pi
  r = 3.5 * m.cos(k * u)
  pts.add([r * m.cos(u), r * m.sin(u)])

s = viz.scene(title: "الوردة الرياضية r = 3.5·cos({k.toInt()}u)", bounds: [-4.2, 4.2, -4.2, 4.2])
s.curve("rose", pts, gradient: viz.palette("rainbow"), progress: clk.progress, strokeWidth: 3.0, glow: true, showHead: true)
s.readout("البتلات k", k.toInt(), color: "#F43F5E")
s.readout("الاكتمال", clk.progress * 100.0, unit: "%", decimals: 1, color: "#38BDF8")
s.readout("t", clk.t, unit: "s", color: "#FFD60A")
s.render()
''',
  ),
  StudioPreset(
    id: 'lissajous_oscilloscope',
    titleAr: 'راسم إشارة حي: منحنيات ليساجو',
    titleEn: 'Live Oscilloscope: Lissajous Figures',
    subtitleAr:
        'تراكب ترددين متعامدين مع انزياح طور حي بتدرج نيون متوهّج كجهاز أوسيلوسكوب',
    fileName: 'lissajous_scope.quds',
    category: StudioCategory.waves,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: true)
fx = viz.slider("fx", min: 1.0, max: 6.0, value: 3.0, step: 1.0, label: "تردد X")
fy = viz.slider("fy", min: 1.0, max: 6.0, value: 4.0, step: 1.0, label: "تردد Y")
phase = clk.t * 0.9

var pts = []
for i in 0..220:
  u = (i / 220.0) * 2.0 * m.pi
  pts.add([3.4 * m.sin(fx * u + phase), 3.4 * m.sin(fy * u)])

s = viz.scene(title: "راسم إشارة ليساجو ({fx.toInt()}:{fy.toInt()})", bounds: [-4.2, 4.2, -4.2, 4.2])
s.curve("scope", pts, gradient: viz.palette("neon"), strokeWidth: 2.6, glow: true, showHead: true)
s.readout("النسبة", "{fx.toInt()}:{fy.toInt()}", color: "#00F5D4")
s.readout("الطور φ", (phase * 180.0 / m.pi) % 360.0, unit: "°", decimals: 0, color: "#F15BB5")
s.readout("t", clk.t, unit: "s", color: "#FEE440")
s.render()
''',
  ),
  StudioPreset(
    id: 'fourier_epicycles',
    titleAr: 'فورييه الحي: دوائر ترسم موجة مربعة',
    titleEn: 'Fourier Epicycles Drawing a Square Wave',
    subtitleAr:
        'شاهد كيف تبني الدوائر الدوّارة موجة مربعة حيّة بزيادة عدد التوافقيات N',
    fileName: 'fourier_circles.quds',
    category: StudioCategory.waves,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
harmonics = viz.slider("harm", min: 1.0, max: 6.0, value: 4.0, step: 1.0, label: "عدد الدوائر N")
t = clk.t * 1.8

s = viz.scene(title: "دوائر فورييه المتداخلة (موجة مربعة)", bounds: [-4.6, 5.2, -3.4, 3.4])
var cx = -2.2
var cy = 0.0
for k in 0..<harmonics.toInt():
  n = 2 * k + 1
  r = 1.6 / n
  nx = cx + r * m.cos(n * t)
  ny = cy + r * m.sin(n * t)
  s.circle("c{k}", [cx, cy], r, stroke: "#334155")
  s.segment("r{k}", [cx, cy], [nx, ny], color: "#38BDF8", strokeWidth: 2.0)
  cx = nx
  cy = ny

var wave = []
for i in 0..90:
  wx = 0.4 + i * 0.05
  wt = t - i * 0.07
  var wy = 0.0
  for k in 0..<harmonics.toInt():
    n = 2 * k + 1
    wy = wy + (1.6 / n) * m.sin(n * wt)
  wave.add([wx, wy])

s.segment("link", [cx, cy], [0.4, cy], color: "#F59E0B", dashed: true)
s.curve("wave", wave, gradient: viz.palette("aurora"), strokeWidth: 2.8, glow: true)
s.point("tip", cx, cy, color: "#F43F5E", radius: 5.0)
s.readout("التوافقيات N", harmonics.toInt(), color: "#38BDF8")
s.readout("y(t)", cy, color: "#34D399")
s.readout("t", clk.t, unit: "s", color: "#F59E0B")
s.render()
''',
  ),
  StudioPreset(
    id: 'spring_mass_oscillator',
    titleAr: 'فيزياء: نابض وكتلة متذبذبة مع القوة',
    titleEn: 'Physics: Damped Spring-Mass Oscillator',
    subtitleAr:
        'زنبرك حلزوني متحرك مع متجه قوة الإرجاع F = -kx ومنحنى الحركة المخمّدة',
    fileName: 'spring_mass.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: true)
k = viz.slider("k", min: 2.0, max: 16.0, value: 8.0, step: 0.5, label: "ثابت النابض k")
b = viz.slider("b", min: 0.0, max: 0.8, value: 0.15, step: 0.05, label: "التخميد b")
w = m.sqrt(k)
y = -1.2 * m.exp(-0.5 * b * clk.t) * m.cos(w * clk.t)
force = -k * y

# رسم لفّات النابض من السقف (y=3.2) إلى الكتلة (y)
var coils = [[0.0, 3.2]]
for i in 1..11:
  cy = 3.2 - (i / 12.0) * (3.2 - y)
  cx = if i % 2 == 0: 0.35 else: -0.35
  coils.add([cx, cy])
coils.add([0.0, y])

var history = []
for i in 0..60:
  ti = clk.t - i * 0.04
  if ti >= 0.0:
    hy = -1.2 * m.exp(-0.5 * b * ti) * m.cos(w * ti)
    history.add([1.0 + i * 0.055, hy])

s = viz.scene(title: "نابض وكتلة في حركة توافقية مخمّدة", bounds: [-2.0, 4.6, -2.8, 3.6])
s.segment("roof", [-1.2, 3.2], [1.2, 3.2], color: "#94A3B8", strokeWidth: 3.5)
s.curve("spring", coils, color: "#38BDF8", strokeWidth: 2.4)
s.curve("trace", history, gradient: viz.palette("sunset"), strokeWidth: 2.4, glow: true)
s.vector("force", [0.0, y], [0.0, y + force * 0.12], label: "F", color: "#10B981")
s.point("mass", 0.0, y, label: "M", color: "#EF4444", radius: 11.0)
s.readout("الإزاحة y", y, unit: "m", color: "#38BDF8")
s.readout("القوة F", force, unit: "N", color: "#10B981")
s.readout("التردد ω", w, unit: "rad/s", color: "#F59E0B")
s.render()
''',
  ),
  StudioPreset(
    id: 'projectile_live',
    titleAr: 'فيزياء: إطلاق مقذوف ومتجه السرعة الحي',
    titleEn: 'Physics: Live Projectile Launch & Velocity Vector',
    subtitleAr:
        'مقذوف يطير بالزمن الحقيقي مع مسار ناري متدرج ومتجه سرعة حي وقراءات المدى والارتفاع',
    fileName: 'projectile_live.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 5.0, loop: true)
v0 = viz.slider("v0", min: 8.0, max: 18.0, value: 14.0, step: 0.5, label: "السرعة الابتدائية v₀")
deg = viz.slider("deg", min: 20.0, max: 75.0, value: 50.0, step: 1.0, label: "زاوية الإطلاق °")
g = 9.81
rad = deg * m.pi / 180.0
vx = v0 * m.cos(rad)
vy0 = v0 * m.sin(rad)
tFlight = 2.0 * vy0 / g
t = clk.progress * tFlight

x = vx * t
y = vy0 * t - 0.5 * g * t * t
vy = vy0 - g * t
speed = m.sqrt(vx * vx + vy * vy)

var arc = []
for i in 0..80:
  ti = (i / 80.0) * tFlight
  arc.add([vx * ti, vy0 * ti - 0.5 * g * ti * ti])

s = viz.scene(title: "إطلاق المقذوف بالزمن الحقيقي", bounds: [-1.0, 34.0, -2.0, 18.0])
s.segment("ground", [-1.0, 0.0], [34.0, 0.0], color: "#475569", strokeWidth: 2.0)
s.curve("arc", arc, gradient: viz.palette("fire"), progress: clk.progress, strokeWidth: 3.0, glow: true)
s.vector("vel", [x, y], [x + vx * 0.28, y + vy * 0.28], label: "v", color: "#38BDF8")
s.point("ball", x, y, color: "#FACC15", radius: 7.0)
s.readout("x", x, unit: "m", color: "#38BDF8")
s.readout("الارتفاع y", y, unit: "m", color: "#F97316")
s.readout("السرعة v", speed, unit: "m/s", color: "#10B981")
s.readout("المدى", vx * tFlight, unit: "m", color: "#FACC15")
s.render()
''',
  ),
  StudioPreset(
    id: 'double_wave_interference',
    titleAr: 'موجات: تداخل موجتين (النبضات Beats)',
    titleEn: 'Waves: Superposition & Acoustic Beats',
    subtitleAr:
        'مراقبة تداخل موجتين متحركتين وتكوّن ظاهرة النبض الصوتي حيّاً بتدرج ألوان',
    fileName: 'wave_beats.quds',
    category: StudioCategory.waves,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
df = viz.slider("df", min: 0.1, max: 1.5, value: 0.4, step: 0.1, label: "فرق التردد Δf")
f1 = 2.5
f2 = f1 + df

var w1 = []
var w2 = []
var sumW = []
for i in 0..140:
  x = -5.0 + i * (10.0 / 140.0)
  y1 = m.sin(f1 * x - 4.0 * clk.t)
  y2 = m.sin(f2 * x - 4.0 * clk.t)
  w1.add([x, y1 + 2.2])
  w2.add([x, y2 - 2.2])
  sumW.add([x, (y1 + y2) * 0.85])

s = viz.scene(title: "تداخل موجتين وتكوّن النبضات (y₁ + y₂)", bounds: [-5.2, 5.2, -3.8, 3.8])
s.curve("w1", w1, color: "#38BDF8", strokeWidth: 1.6)
s.curve("w2", w2, color: "#A855F7", strokeWidth: 1.6)
s.curve("sum", sumW, gradient: viz.palette("aurora"), strokeWidth: 3.0, glow: true)
s.readout("f₁", f1, unit: "Hz", color: "#38BDF8")
s.readout("f₂", f2, unit: "Hz", color: "#A855F7")
s.readout("النبض Δf", df, unit: "Hz", color: "#34D399")
s.render()
''',
  ),
  StudioPreset(
    id: 'heart_curve_glow',
    titleAr: 'فن رياضي: القلب النابض بتدرج ألوان',
    titleEn: 'Parametric Art: Pulsing Gradient Heart',
    subtitleAr:
        'رسم معادلة القلب الرياضية نقطة بنقطة مع نبض حي متدرج الألوان وتوهّج',
    fileName: 'pulsing_heart.quds',
    category: StudioCategory.geometry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 6.0, loop: true)
bpm = viz.slider("bpm", min: 45.0, max: 130.0, value: 72.0, step: 3.0, label: "النبض BPM")
pulse = 1.0 + 0.08 * m.sin(clk.t * (bpm / 60.0) * 2.0 * m.pi)

var pts = []
for i in 0..180:
  u = (i / 180.0) * 2.0 * m.pi
  su = m.sin(u)
  x = 0.22 * pulse * (16.0 * su * su * su)
  y = 0.22 * pulse * (13.0 * m.cos(u) - 5.0 * m.cos(2.0 * u) - 2.0 * m.cos(3.0 * u) - m.cos(4.0 * u))
  pts.add([x, y])

s = viz.scene(title: "القلب الرياضي النابض بتدرج ألوان", bounds: [-4.5, 4.5, -4.5, 4.2])
s.curve("heart", pts, gradient: viz.palette("sunset"), progress: clk.progress, strokeWidth: 3.4, glow: true, showHead: true)
s.readout("النبض", bpm.toInt(), unit: "BPM", color: "#FF006E")
s.readout("الاكتمال", clk.progress * 100.0, unit: "%", decimals: 1, color: "#FFBE0B")
s.readout("التوسّع", pulse, color: "#8338EC")
s.render()
''',
  ),
  StudioPreset(
    id: 'chaos_lorenz_2d',
    titleAr: 'فوضى حتمية: جاذب لورينز (تأثير الفراشة)',
    titleEn: 'Chaos Theory: Lorenz Strange Attractor',
    subtitleAr:
        'حل المعادلات التفاضلية الفوضوية للورينز ورسم جناحَي الفوضى تدريجياً بتدرج Plasma',
    fileName: 'lorenz_chaos.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: true)
rho = viz.slider("rho", min: 20.0, max: 32.0, value: 28.0, step: 0.5, label: "معامل الفوضى ρ")
sigma = 10.0
beta = 8.0 / 3.0

var x = 0.1
var y = 0.0
var z = 0.0
dt = 0.012
var pts = []
for i in 0..420:
  dx = sigma * (y - x)
  dy = x * (rho - z) - y
  dz = x * y - beta * z
  x = x + dx * dt
  y = y + dy * dt
  z = z + dz * dt
  pts.add([x, z - 25.0])

idx = (clk.progress * 420.0).round()
cur = pts[idx]
s = viz.scene(title: "جاذب لورينز الفوضوي (X-Z)", bounds: [-24.0, 24.0, -24.0, 26.0])
s.curve("lorenz", pts, gradient: viz.palette("plasma"), progress: clk.progress, strokeWidth: 2.2, glow: true, showHead: true)
s.readout("ρ", rho, color: "#F89540")
s.readout("x", cur[0], color: "#CC4778")
s.readout("z", cur[1] + 25.0, color: "#F0F921")
s.readout("المسار", clk.progress * 100.0, unit: "%", decimals: 0, color: "#38BDF8")
s.render()
''',
  ),
  StudioPreset(
    id: 'radar_sonar_sweep',
    titleAr: 'رادار حي: مسح دائري وكشف الأهداف',
    titleEn: 'Live Radar Sweep & Target Detection',
    subtitleAr:
        'شعاع رادار يدور 360° داخل دوائر المدى ويضيء الأهداف لحظة عبور الشعاع فوقها',
    fileName: 'radar_sweep.quds',
    category: StudioCategory.astronomy,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 6.0, loop: true)
rpm = viz.slider("rpm", min: 0.5, max: 2.5, value: 1.0, step: 0.25, label: "سرعة المسح")
ang = (clk.t * rpm * 2.0 * m.pi / 6.0) % (2.0 * m.pi)
R = 4.0

s = viz.scene(title: "رادار مسح دائري حي (360°)", grid: false, axes: false, bounds: [-4.6, 4.6, -4.6, 4.6])
for ring in 1..4:
  s.circle("r{ring}", [0.0, 0.0], ring * 1.0, stroke: "#1E3A5F", dashed: true)
s.segment("ax", [-R, 0.0], [R, 0.0], color: "#1E293B")
s.segment("ay", [0.0, -R], [0.0, R], color: "#1E293B")

# ذيل الشعاع المضيء
var sweep = [[0.0, 0.0]]
for i in 0..10:
  a = ang - i * 0.04
  sweep.add([R * m.cos(a), R * m.sin(a)])
s.polygon("fan", sweep, stroke: "#10B981", fill: "#10B98133")
s.segment("beam", [0.0, 0.0], [R * m.cos(ang), R * m.sin(ang)], color: "#34D399", strokeWidth: 2.8)

targets = [[2.1, 1.4], [-2.5, 1.8], [-1.3, -2.6], [2.4, -1.9]]
var active = 0
for i in 0..<targets.length:
  tx = targets[i][0]
  ty = targets[i][1]
  var ta = m.atan2(ty, tx)
  if ta < 0.0:
    ta = ta + 2.0 * m.pi
  diff = (ang - ta + 2.0 * m.pi) % (2.0 * m.pi)
  lit = diff < 0.75
  if lit:
    active += 1
  lbl = (if lit: "هدف {i + 1}" else: "")
  col = (if lit: "#EF4444" else: "#334155")
  rad = (if lit: 7.5 else: 4.0)
  s.point("t{i}", tx, ty, label: lbl, color: col, radius: rad)

s.readout("زاوية الشعاع", ang * 180.0 / m.pi, unit: "°", decimals: 0, color: "#34D399")
s.readout("أهداف مرصودة", "{active}/4", color: "#EF4444")
s.readout("المدى", "4.0 km", color: "#38BDF8")
s.render()
''',
  ),
  // ── 4 New Physics & Electromagnetism / Quantum Motion Presets ──────────────
  StudioPreset(
    id: 'lorentz_cyclotron',
    titleAr: 'فيزياء: حركة شحنة في مجال مغناطيسي (سيكلوترون)',
    titleEn: 'Physics: Charged Particle Cyclotron & Lorentz Force',
    subtitleAr:
        'مسار شحنة متسارعة تحت قوة لورنتز F = q(v×B) مع نصف قطر لارمور ومتجهات السرعة والقوة',
    fileName: 'lorentz_cyclotron.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
B = viz.slider("B", min: 0.6, max: 3.0, value: 1.5, step: 0.1, label: "شدة المجال B (T)")
accel = viz.slider("accel", min: 0.0, max: 0.45, value: 0.22, step: 0.03, label: "تسارع الفجوة E")

q = 1.0
mass = 1.0
wc = q * B / mass
var pts = []
var vx = 0.0
var vy = 0.0
var px = 0.0
var py = 0.0
steps = 220
for i in 0..steps:
  tau = (i / steps) * clk.t * 2.2
  r = 0.55 + accel * tau
  ang = wc * tau
  x = r * m.cos(ang)
  y = r * m.sin(ang)
  pts.add([x, y])
  if i == steps:
    px = x
    py = y
    vx = accel * m.cos(ang) - r * wc * m.sin(ang)
    vy = accel * m.sin(ang) + r * wc * m.cos(ang)

speed = m.sqrt(vx * vx + vy * vy)
rLarmor = mass * speed / (q * B)
fx = q * vy * B
fy = -q * vx * B
fMag = m.sqrt(fx * fx + fy * fy)

s = viz.scene(title: "سيكلوترون وقوة لورنتز F = q(v × B)", bounds: [-5.2, 5.2, -5.2, 5.2])
s.circle("dee", [0.0, 0.0], 4.5, stroke: "#1E3A5F", dashed: true)
s.segment("gap", [0.0, -4.5], [0.0, 4.5], color: "#334155", dashed: true)
s.curve("orbit", pts, gradient: viz.palette("plasma"), strokeWidth: 2.4, glow: true, showHead: true)
s.vector("v", [px, py], [px + vx * 0.28, py + vy * 0.28], label: "v", color: "#38BDF8")
s.vector("F", [px, py], [px + fx * 0.16, py + fy * 0.16], label: "F", color: "#F43F5E")
s.point("q", px, py, color: "#FACC15", radius: 6.0)
s.readout("نصف قطر لارمور rL", rLarmor, unit: "m", color: "#F59E0B")
s.readout("التردد ωc", wc, unit: "rad/s", color: "#38BDF8")
s.readout("السرعة |v|", speed, unit: "m/s", color: "#10B981")
s.readout("قوة لورنتز |F|", fMag, unit: "N", color: "#F43F5E")
s.render()
''',
  ),
  StudioPreset(
    id: 'quantum_wavepacket',
    titleAr: 'ميكانيكا الكم: حزمة موجية غاوسية |ψ(x,t)|²',
    titleEn: 'Quantum Mechanics: Spreading Gaussian Wavepacket',
    subtitleAr:
        'انتشار وتشتت حزمة موجية كمّية مع دالة الاحتمال |ψ|² والجزء الحقيقي Re(ψ) وعرض عدم اليقين σ(t)',
    fileName: 'quantum_wavepacket.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
k0 = viz.slider("k0", min: 2.0, max: 10.0, value: 5.5, step: 0.5, label: "متجه الموجة k₀")
sigma0 = viz.slider("s0", min: 0.35, max: 1.2, value: 0.65, step: 0.05, label: "العرض الابتدائي σ₀")

t = clk.t
xc = -4.2 + 1.05 * t
# انتشار الحزمة الكمّية: σ(t) = σ₀ * sqrt(1 + (t / (2 σ₀²))²)
spread = m.sqrt(1.0 + m.pow(t * 0.35 / (sigma0 * sigma0), 2.0))
sig = sigma0 * spread
amp = 2.4 / m.sqrt(spread)

var prob = []
var realPsi = []
for i in 0..180:
  x = -6.0 + i * (12.0 / 180.0)
  dx = x - xc
  env = m.exp(-(dx * dx) / (2.0 * sig * sig))
  pDens = amp * env * env
  re = amp * env * m.cos(k0 * dx - 0.5 * k0 * t)
  prob.add([x, pDens])
  realPsi.add([x, re])

s = viz.scene(title: "الحزمة الموجية الكمّية ψ(x,t) وكثافة الاحتمال |ψ|²", bounds: [-6.2, 6.2, -3.0, 3.4])
s.curve("re", realPsi, color: "#38BDF8", strokeWidth: 1.8)
s.curve("prob", prob, gradient: viz.palette("viridis"), strokeWidth: 2.8, glow: true)
s.segment("mean", [xc, 0.0], [xc, amp], color: "#F59E0B", dashed: true)
s.readout("⟨x⟩", xc, unit: "nm", color: "#F59E0B")
s.readout("عدم اليقين σ(t)", sig, unit: "nm", color: "#34D399")
s.readout("الزخم k₀", k0, unit: "ħ/nm", color: "#38BDF8")
s.readout("الذروة |ψ|²", amp, color: "#A78BFA")
s.render()
''',
  ),
  StudioPreset(
    id: 'double_pendulum_chaos',
    titleAr: 'ميكانيكا لاغرانج: البندول المزدوج الفوضوي',
    titleEn: 'Lagrangian Mechanics: Chaotic Double Pendulum',
    subtitleAr:
        'تكامل حركي حقيقي لبندول مزدوج مترابط مع ذيل فوضوي متدرج وطاقة ميكانيكية لحظية',
    fileName: 'double_pendulum.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 16.0, loop: false)
g = viz.slider("g", min: 3.0, max: 18.0, value: 9.8, step: 0.4, label: "الجاذبية g")
m2 = viz.slider("m2", min: 0.5, max: 3.0, value: 1.2, step: 0.1, label: "الكتلة الثانية m₂")

L1 = 2.0
L2 = 2.0
m1 = 1.0
var st = viz.state("dp", [2.15, 2.55, 0.0, 0.0, []])
if clk.frame == 0:
  st = [2.15, 2.55, 0.0, 0.0, []]

var th1 = st[0]
var th2 = st[1]
var w1 = st[2]
var w2 = st[3]
var trail = st[4]

dt = 0.012
for sub in 0..3:
  d = th1 - th2
  den = 2.0 * m1 + m2 - m2 * m.cos(2.0 * d)
  a1 = (-g * (2.0 * m1 + m2) * m.sin(th1) - m2 * g * m.sin(th1 - 2.0 * th2) - 2.0 * m.sin(d) * m2 * (w2 * w2 * L2 + w1 * w1 * L1 * m.cos(d))) / (L1 * den)
  a2 = (2.0 * m.sin(d) * (w1 * w1 * L1 * (m1 + m2) + g * (m1 + m2) * m.cos(th1) + w2 * w2 * L2 * m2 * m.cos(d))) / (L2 * den)
  w1 = w1 + a1 * dt
  w2 = w2 + a2 * dt
  th1 = th1 + w1 * dt
  th2 = th2 + w2 * dt

x1 = L1 * m.sin(th1)
y1 = -L1 * m.cos(th1)
x2 = x1 + L2 * m.sin(th2)
y2 = y1 - L2 * m.cos(th2)
trail.add([x2, y2])
if trail.length > 140:
  trail.removeAt(0)
viz.setState("dp", [th1, th2, w1, w2, trail])

s = viz.scene(title: "البندول المزدوج الفوضوي (لاغرانج)", bounds: [-4.6, 4.6, -4.6, 4.6])
if trail.length >= 2:
  s.curve("trail", trail, gradient: viz.palette("fire"), strokeWidth: 2.4, glow: true)
s.segment("rod1", [0.0, 0.0], [x1, y1], color: "#94A3B8", strokeWidth: 2.4)
s.segment("rod2", [x1, y1], [x2, y2], color: "#E2E8F0", strokeWidth: 2.4)
s.point("piv", 0.0, 0.0, color: "#64748B", radius: 4.5)
s.point("b1", x1, y1, color: "#38BDF8", radius: 7.5)
s.point("b2", x2, y2, color: "#F43F5E", radius: 8.5)
s.readout("θ₁", th1 * 180.0 / m.pi, unit: "°", decimals: 1, color: "#38BDF8")
s.readout("θ₂", th2 * 180.0 / m.pi, unit: "°", decimals: 1, color: "#F43F5E")
s.readout("ω₂", w2, unit: "rad/s", color: "#F59E0B")
s.render()
''',
  ),
  StudioPreset(
    id: 'rlc_phase_portrait',
    titleAr: 'كهرومغناطيسية: دائرة RLC ومخطط الطور (Vc, I)',
    titleEn: 'Electromagnetism: RLC Resonance & Phase Portrait',
    subtitleAr:
        'مسار التخميد الرنيني لدائرة RLC في فضاء الطور (الجهد مقابل التيار) مع عامل الجودة Q',
    fileName: 'rlc_phase.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
R = viz.slider("R", min: 0.1, max: 2.5, value: 0.45, step: 0.05, label: "المقاومة R (Ω)")
w0 = viz.slider("w0", min: 1.5, max: 5.0, value: 3.0, step: 0.25, label: "تردد الرنين ω₀")

alpha = R * 0.5
wd = m.sqrt(m.max(0.05, w0 * w0 - alpha * alpha))
Q = w0 / (2.0 * alpha)
V0 = 4.2

var pts = []
for i in 0..220:
  tau = i * 0.045
  env = V0 * m.exp(-alpha * tau)
  vc = env * m.cos(wd * tau)
  curI = -env * (alpha * m.cos(wd * tau) + wd * m.sin(wd * tau)) / w0
  pts.add([vc, curI])

idx = (clk.progress * 220.0).round()
pt = pts[idx]
s = viz.scene(title: "مخطط الطور لدائرة RLC: التيار I مقابل الجهد Vc", bounds: [-4.8, 4.8, -4.8, 4.8])
s.curve("phase", pts, gradient: viz.palette("neon"), progress: clk.progress, strokeWidth: 2.5, glow: true, showHead: true)
s.vector("state", [0.0, 0.0], pt, color: "#38BDF8")
s.readout("جهد المكثف Vc", pt[0], unit: "V", color: "#38BDF8")
s.readout("التيار I", pt[1], unit: "A", color: "#EC4899")
s.readout("عامل الجودة Q", Q, color: "#10B981")
s.readout("نسبة التخميد ζ", alpha / w0, color: "#F59E0B")
s.render()
''',
  ),
  // ── 4 Brand-New Chemistry Animated Presets ──────────────────────────────────
  StudioPreset(
    id: 'chem_consecutive_kinetics',
    titleAr: 'كيمياء حركية: تفاعل متسلسل A → B → C',
    titleEn: 'Chemical Kinetics: Consecutive Reaction A → B → C',
    subtitleAr:
        'تتبع تراكيز المتفاعل A والوسيط B والناتج C لحظياً مع تحديد زمن ذروة الوسيط [B]max',
    fileName: 'chem_kinetics.quds',
    category: StudioCategory.chemistry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
k1 = viz.slider("k1", min: 0.2, max: 2.5, value: 1.1, step: 0.1, label: "ثابت السرعة k₁ (A→B)")
k2 = viz.slider("k2", min: 0.15, max: 2.0, value: 0.45, step: 0.05, label: "ثابت السرعة k₂ (B→C)")

tMaxWindow = 8.0
var cA = []
var cB = []
var cC = []
for i in 0..160:
  tau = i * (tMaxWindow / 160.0)
  a = m.exp(-k1 * tau)
  var b = 0.0
  if (k1 - k2).abs() < 0.02:
    b = k1 * tau * m.exp(-k1 * tau)
  else:
    b = (k1 / (k1 - k2)) * (m.exp(-k2 * tau) - m.exp(-k1 * tau))
  c = 1.0 - a - b
  cA.add([tau, a * 4.0])
  cB.add([tau, b * 4.0])
  cC.add([tau, c * 4.0])

tNow = clk.progress * tMaxWindow
aNow = m.exp(-k1 * tNow)
var bNow = 0.0
if (k1 - k2).abs() < 0.02:
  bNow = k1 * tNow * m.exp(-k1 * tNow)
else:
  bNow = (k1 / (k1 - k2)) * (m.exp(-k2 * tNow) - m.exp(-k1 * tNow))
cNow = 1.0 - aNow - bNow

var tPeak = 1.0 / k1
if (k1 - k2).abs() >= 0.02:
  tPeak = m.log(k1 / k2) / (k1 - k2)

s = viz.scene(title: "حركية التفاعل المتسلسل: A → B → C", bounds: [-0.4, 8.4, -0.4, 4.6])
s.curve("A", cA, color: "#38BDF8", progress: clk.progress, strokeWidth: 2.6, showHead: true)
s.curve("B", cB, color: "#F59E0B", progress: clk.progress, strokeWidth: 2.8, glow: true, showHead: true)
s.curve("C", cC, color: "#10B981", progress: clk.progress, strokeWidth: 2.6, showHead: true)
if tPeak > 0.0 and tPeak < tMaxWindow:
  s.segment("peak", [tPeak, 0.0], [tPeak, 4.2], color: "#F59E0B", dashed: true)
s.readout("[A] المتفاعل", aNow, unit: "M", color: "#38BDF8")
s.readout("[B] الوسيط", bNow, unit: "M", color: "#F59E0B")
s.readout("[C] الناتج", cNow, unit: "M", color: "#10B981")
s.readout("ذروة B عند", tPeak, unit: "s", color: "#A78BFA")
s.render()
''',
  ),
  StudioPreset(
    id: 'chem_titration_ph',
    titleAr: 'كيمياء تحليلية: معايرة حمض ضعيف بقاعدة قوية (pH)',
    titleEn: 'Analytical Chemistry: Weak Acid Titration Curve (pH)',
    subtitleAr:
        'رسم منحنى pH حياً مع منطقة المحلول المنظم pH=pKa وقفزة نقطة التكافؤ ومؤشر لوني متغيّر',
    fileName: 'chem_titration.quds',
    category: StudioCategory.chemistry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
pKa = viz.slider("pKa", min: 2.5, max: 6.5, value: 4.76, step: 0.1, label: "ثابت الحمض pKa")
vEq = viz.slider("vEq", min: 15.0, max: 35.0, value: 25.0, step: 1.0, label: "حجم التكافؤ (mL)")

var pts = []
var cols = []
var curPh = pKa
var curV = 0.0
steps = 160
for i in 0..steps:
  v = i * (50.0 / steps)
  var ph = 7.0
  if v < 0.2:
    ph = 0.5 * (pKa + 1.0)
  else:
    if v < vEq - 0.35:
      ph = pKa + m.log(v / (vEq - v)) / m.ln10
    else:
      if v <= vEq + 0.35:
        frac = (v - (vEq - 0.35)) / 0.7
        ph = (pKa + 2.0) + frac * (11.2 - (pKa + 2.0))
      else:
        excess = (v - vEq) / (50.0 + v) * 0.1
        pOH = -m.log(m.max(excess, 1e-7)) / m.ln10
        ph = 14.0 - pOH
  if ph < 0.5:
    ph = 0.5
  if ph > 13.8:
    ph = 13.8
  pts.add([v * 0.2, ph])
  # لون الكاشف الشامل من الأحمر (حمضي) للأخضر (متعادل) للبنفسجي (قاعدي)
  hue = (ph / 14.0) * 280.0
  cols.add(viz.hsl(hue, 0.9, 0.56))
  if i == (clk.progress * steps).round():
    curPh = ph
    curV = v

indColor = viz.hsl((curPh / 14.0) * 280.0, 0.92, 0.58)
s = viz.scene(title: "منحنى المعايرة pH(V) — المحلول المنظم والتكافؤ", bounds: [-0.5, 10.6, 0.0, 14.5])
s.segment("neutral", [0.0, 7.0], [10.0, 7.0], color: "#334155", dashed: true)
s.segment("eqLine", [vEq * 0.2, 0.0], [vEq * 0.2, 14.0], color: "#F43F5E", dashed: true)
s.point("halfEq", vEq * 0.1, pKa, label: "pH=pKa", color: "#38BDF8", radius: 4.5)
s.curve("phCurve", pts, pointColors: cols, progress: clk.progress, strokeWidth: 2.8, glow: true, showHead: true)
s.point("indicator", 9.2, 12.6, label: "الكاشف", color: indColor, radius: 10.0)
s.readout("الحجم NaOH", curV, unit: "mL", decimals: 1, color: "#38BDF8")
s.readout("pH اللحظي", curPh, decimals: 2, color: indColor)
s.readout("نقطة التكافؤ", vEq, unit: "mL", decimals: 0, color: "#F43F5E")
s.readout("pKa", pKa, decimals: 2, color: "#A78BFA")
s.render()
''',
  ),
  StudioPreset(
    id: 'chem_bohr_transitions',
    titleAr: 'كيمياء كمّية: ذرة بور وطيف بالمر للهيدروجين',
    titleEn: 'Quantum Chemistry: Bohr Hydrogen & Balmer Photon Emission',
    subtitleAr:
        'مدارات الهيدروجين الكمّية n=1..5 وقفزات الإلكترون مع انبعاث موجة الفوتون بطول موجي λ حقيقي',
    fileName: 'bohr_hydrogen.quds',
    category: StudioCategory.chemistry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
nUpper = viz.slider("nUp", min: 3.0, max: 5.0, value: 3.0, step: 1.0, label: "المستوى الابتدائي nᵢ")

n1 = nUpper.round()
n2 = 2
# طاقة الفوتون بوحدة eV (معادلة ريدبرغ)
dE = 13.6 * (1.0 / (n2 * n2) - 1.0 / (n1 * n1))
lambdaNm = 1239.84 / dE

var photonCol = "#EF4444"
if n1 == 4:
  photonCol = "#06B6D4"
if n1 == 5:
  photonCol = "#6366F1"

p = clk.progress
var rOrb = n1 * 0.85
var emitting = false
if p > 0.45:
  emitting = true
  jumpFrac = m.min(1.0, (p - 0.45) / 0.12)
  rOrb = (n1 * (1.0 - jumpFrac) + n2 * jumpFrac) * 0.85

ang = clk.t * (4.5 / rOrb)
ex = rOrb * m.cos(ang)
ey = rOrb * m.sin(ang)

s = viz.scene(title: "ذرة بور للهيدروجين: انتقال بالمر n={n1} → n=2", grid: false, axes: false, bounds: [-5.2, 5.2, -5.0, 5.0])
for n in 1..5:
  col = (if n == n1 or n == n2: "#475569" else: "#1E293B")
  s.circle("n{n}", [0.0, 0.0], n * 0.85, stroke: col, dashed: true)
s.point("nuc", 0.0, 0.0, label: "H⁺", color: "#F59E0B", radius: 8.5)
s.point("e", ex, ey, label: "e⁻", color: "#38BDF8", radius: 5.5)

if emitting:
  travel = (p - 0.45) * 6.5
  var wave = []
  for i in 0..48:
    u = i / 48.0
    wx = 1.7 + travel + u * 2.0
    wy = 0.25 * m.sin(u * 20.0 * (450.0 / lambdaNm))
    wave.add([wx, wy])
  s.curve("photon", wave, color: photonCol, strokeWidth: 2.6, glow: true, showHead: true)

s.readout("الانتقال", "n={n1} → n=2", color: "#38BDF8")
s.readout("طاقة الفوتون ΔE", dE, unit: "eV", decimals: 2, color: "#F59E0B")
s.readout("الطول الموجي λ", lambdaNm, unit: "nm", decimals: 1, color: photonCol)
s.render()
''',
  ),
  StudioPreset(
    id: 'chem_maxwell_boltzmann',
    titleAr: 'كيمياء فيزيائية: توزيع ماكسويل–بولتزمان للغازات',
    titleEn: 'Physical Chemistry: Maxwell-Boltzmann Speed Distribution',
    subtitleAr:
        'تغيّر توزيع سرعات الجزيئات ديناميكياً مع درجة الحرارة T والكتلة المولية M وإبراز vp و vrms',
    fileName: 'maxwell_boltzmann.quds',
    category: StudioCategory.chemistry,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
molar = viz.slider("M", min: 4.0, max: 44.0, value: 28.0, step: 2.0, label: "الكتلة المولية M (g/mol)")
baseT = viz.slider("T", min: 150.0, max: 900.0, value: 300.0, step: 25.0, label: "متوسط الحرارة T (K)")

# تذبذب حراري حي لاستعراض توسّع المنحنى مع التسخين والتبريد
temp = baseT + 140.0 * m.sin(clk.progress * 2.0 * m.pi)
if temp < 80.0:
  temp = 80.0

R = 8.314
massKg = molar / 1000.0
vp = m.sqrt(2.0 * R * temp / massKg)
vAvg = m.sqrt(8.0 * R * temp / (m.pi * massKg))
vRms = m.sqrt(3.0 * R * temp / massKg)

var pts = []
var cols = []
aCoef = massKg / (2.0 * R * temp)
norm = 4.0 * m.pi * m.pow(aCoef / m.pi, 1.5)
for i in 0..160:
  v = i * 10.0
  fv = norm * v * v * m.exp(-aCoef * v * v) * 2600.0
  pts.add([v / 200.0, fv])
  hue = 220.0 - (i / 160.0) * 210.0
  cols.add(viz.hsl(hue, 0.9, 0.56))

s = viz.scene(title: "توزيع ماكسويل–بولتزمان لسرعات الغاز f(v)", bounds: [-0.3, 8.4, -0.3, 5.2])
s.curve("mb", pts, pointColors: cols, strokeWidth: 2.6, glow: true)
s.segment("vpLine", [vp / 200.0, 0.0], [vp / 200.0, 4.4], color: "#38BDF8", dashed: true)
s.segment("rmsLine", [vRms / 200.0, 0.0], [vRms / 200.0, 3.6], color: "#F43F5E", dashed: true)
s.readout("الحرارة T", temp, unit: "K", decimals: 0, color: "#F59E0B")
s.readout("vp (الأكثر احتمالاً)", vp, unit: "m/s", decimals: 0, color: "#38BDF8")
s.readout("v_avg", vAvg, unit: "m/s", decimals: 0, color: "#10B981")
s.readout("v_rms", vRms, unit: "m/s", decimals: 0, color: "#F43F5E")
s.render()
''',
  ),
  // ── 4 Brand-New Mathematics & Analysis Animated Presets ─────────────────────
  StudioPreset(
    id: 'math_taylor_series',
    titleAr: 'رياضيات: تقارب متسلسلة تايلور للدالة sin(x) حياً',
    titleEn: 'Mathematics: Live Taylor Series Convergence for sin(x)',
    subtitleAr:
        'شاهد متعدد الحدود لتايلور ينطبق تدريجياً على sin(x) مع ازدياد الرتبة N وهبوط الخطأ الأقصى',
    fileName: 'taylor_series.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
maxTerms = viz.slider("maxN", min: 3.0, max: 9.0, value: 7.0, step: 1.0, label: "أقصى عدد حدود")

nTerms = 1 + (clk.progress * (maxTerms - 1.0)).round()
degree = 2 * nTerms - 1

var exactPts = []
var taylorPts = []
var maxErr = 0.0
for i in 0..160:
  x = -5.5 + i * (11.0 / 160.0)
  yExact = m.sin(x)
  var sum = 0.0
  var term = x
  for k in 0..<nTerms:
    if k > 0:
      term = -term * x * x / ((2 * k) * (2 * k + 1))
    sum = sum + term
  if x >= -m.pi and x <= m.pi:
    err = (sum - yExact).abs()
    if err > maxErr:
      maxErr = err
  yClamp = m.max(-3.8, m.min(3.8, sum))
  exactPts.add([x, yExact])
  taylorPts.add([x, yClamp])

s = viz.scene(title: "تقارب متسلسلة تايلور P_{degree}(x) نحو sin(x)", bounds: [-5.8, 5.8, -4.0, 4.0])
s.curve("exact", exactPts, color: "#475569", strokeWidth: 2.0)
s.curve("taylor", taylorPts, gradient: viz.palette("neon"), strokeWidth: 2.6, glow: true)
s.segment("piL", [-m.pi, -3.5], [-m.pi, 3.5], color: "#1E3A5F", dashed: true)
s.segment("piR", [m.pi, -3.5], [m.pi, 3.5], color: "#1E3A5F", dashed: true)
s.readout("عدد الحدود", "{nTerms}", color: "#38BDF8")
s.readout("درجة كثير الحدود", "P{degree}(x)", color: "#EC4899")
s.readout("الخطأ على [-π,π]", maxErr, decimals: 4, color: "#10B981")
s.render()
''',
  ),
  StudioPreset(
    id: 'math_riemann_integral',
    titleAr: 'تفاضل وتكامل: مجاميع ريمان وتقارب التكامل المحدد',
    titleEn: 'Calculus: Animated Riemann Sums Converging to Integral',
    subtitleAr:
        'تجزئة المساحة تحت المنحنى من 3 إلى 36 مستطيلاً ومقارنة المجموع العددي بالتكامل التحليلي الدقيق',
    fileName: 'riemann_integral.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
maxN = viz.slider("maxN", min: 8.0, max: 36.0, value: 28.0, step: 2.0, label: "أقصى عدد مستطيلات")

a = 0.0
b = 6.0
nRect = 3 + (clk.progress * (maxN - 3.0)).round()
dx = (b - a) / nRect

# f(x) = sin(x) + 0.35*x + 1.4  =>  F(x) = -cos(x) + 0.175*x^2 + 1.4*x
exact = (-m.cos(b) + 0.175 * b * b + 1.4 * b) - (-m.cos(a))

s = viz.scene(title: "مجاميع ريمان الوسطية وتقارب ∫ f(x) dx", bounds: [-0.6, 6.6, -0.5, 4.6])
var rSum = 0.0
for i in 0..<nRect:
  x0 = a + i * dx
  x1 = x0 + dx
  xm = 0.5 * (x0 + x1)
  ym = m.sin(xm) + 0.35 * xm + 1.4
  rSum = rSum + ym * dx
  s.polygon("r{i}", [[x0, 0.0], [x1, 0.0], [x1, ym], [x0, ym]], stroke: "#38BDF8", fill: "#38BDF824")

var curvePts = []
for i in 0..140:
  x = a + i * ((b - a) / 140.0)
  y = m.sin(x) + 0.35 * x + 1.4
  curvePts.add([x, y])

s.curve("fx", curvePts, gradient: viz.palette("viridis"), strokeWidth: 2.8, glow: true)
s.readout("عدد الفترات n", "{nRect}", color: "#38BDF8")
s.readout("مجموع ريمان", rSum, decimals: 4, color: "#10B981")
s.readout("التكامل الدقيق", exact, decimals: 4, color: "#F59E0B")
s.readout("الخطأ المطلق", (rSum - exact).abs(), decimals: 4, color: "#F43F5E")
s.render()
''',
  ),
  StudioPreset(
    id: 'math_cycloid_brachistochrone',
    titleAr: 'هندسة تفاضلية: الدحروج (السيكلويد) ومقارنة أسرع مسار',
    titleEn: 'Differential Geometry: Rolling Cycloid & Brachistochrone',
    subtitleAr:
        'عجلة تتدحرج لترسم السيكلويد x=R(θ-sinθ), y=R(1-cosθ) مع طول القوس ومتجه السرعة المماسي',
    fileName: 'cycloid_curve.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 7.0, loop: true)
R = viz.slider("R", min: 0.7, max: 1.6, value: 1.15, step: 0.05, label: "نصف قطر العجلة R")

thetaMax = 4.0 * m.pi
theta = clk.progress * thetaMax
var pts = []
for i in 0..200:
  u = i * (thetaMax / 200.0)
  pts.add([R * (u - m.sin(u)), R * (1.0 - m.cos(u))])

cx = R * theta
cy = R
px = R * (theta - m.sin(theta))
py = R * (1.0 - m.cos(theta))
# متجه السرعة المماسي dx/dθ, dy/dθ
vx = R * (1.0 - m.cos(theta))
vy = R * m.sin(theta)
# طول القوس في القوس الأول 4R(1 - cos(θ/2))
arcLen = 8.0 * R * (theta / (2.0 * m.pi))

s = viz.scene(title: "منحنى الدحروج (السيكلويد): عجلة متدحرجة وطول القوس", bounds: [-0.8, 16.0, -0.6, 4.4])
s.segment("ground", [-0.5, 0.0], [15.5, 0.0], color: "#475569", strokeWidth: 2.0)
s.circle("wheel", [cx, cy], R, stroke: "#64748B", fill: "#38BDF814")
s.segment("spoke", [cx, cy], [px, py], color: "#94A3B8", strokeWidth: 1.8)
s.curve("cycloid", pts, gradient: viz.palette("rainbow"), progress: clk.progress, strokeWidth: 2.6, glow: true, showHead: true)
s.vector("tangent", [px, py], [px + vx * 0.5, py + vy * 0.5], label: "v", color: "#F59E0B")
s.point("center", cx, cy, color: "#38BDF8", radius: 4.0)
s.readout("الزاوية θ", theta / m.pi, unit: "π rad", color: "#38BDF8")
s.readout("طول القوس ≈", arcLen, color: "#10B981")
s.readout("الارتفاع y", py, color: "#F59E0B")
s.render()
''',
  ),
  StudioPreset(
    id: 'math_complex_roots',
    titleAr: 'تحليل مركّب: جذور الوحدة zⁿ = eⁱʷᵗ والمضلع النجمي',
    titleEn: 'Complex Analysis: Rotating Roots of Unity & Star Polygon',
    subtitleAr:
        'تدوير الجذور النونية في المستوى المركّب ℂ مع أوتار المضلع المنتظم وأقطار النجمة المتدرجة',
    fileName: 'complex_roots.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
nRoots = viz.slider("n", min: 3.0, max: 11.0, value: 7.0, step: 1.0, label: "رتبة الجذر n")
stepStar = viz.slider("step", min: 1.0, max: 4.0, value: 3.0, step: 1.0, label: "قفزة النجمة k")

n = nRoots.round()
k = stepStar.round()
phi = clk.progress * 2.0 * m.pi
R = 3.2

s = viz.scene(title: "المستوى المركّب ℂ: جذور الوحدة z^{n} = eⁱᵠ", bounds: [-4.2, 4.2, -4.2, 4.2])
s.circle("unit", [0.0, 0.0], R, stroke: "#334155", dashed: true)

var verts = []
for j in 0..<n:
  a = (phi + 2.0 * m.pi * j) / n
  verts.add([R * m.cos(a), R * m.sin(a)])

# المضلع المنتظم والأوتار النجمية
for j in 0..<n:
  nxt = (j + 1) % n
  star = (j + k) % n
  col = viz.hsl((j / n) * 360.0, 0.88, 0.58)
  s.segment("edge{j}", verts[j], verts[nxt], color: "#38BDF8", strokeWidth: 1.6)
  s.segment("star{j}", verts[j], verts[star], color: col, strokeWidth: 2.2)
  s.vector("vec{j}", [0.0, 0.0], verts[j], color: "#475569")
  s.point("z{j}", verts[j][0], verts[j][1], label: "z{j}", color: col, radius: 5.5)

a0 = phi / n
s.readout("الجذور n", "{n}", color: "#38BDF8")
s.readout("Re(z₀)", m.cos(a0), decimals: 3, color: "#10B981")
s.readout("Im(z₀)", m.sin(a0), decimals: 3, color: "#EC4899")
s.readout("الطور φ", phi * 180.0 / m.pi, unit: "°", decimals: 0, color: "#F59E0B")
s.render()
''',
  ),
];
