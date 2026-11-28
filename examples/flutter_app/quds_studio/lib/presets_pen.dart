/// 10 Showcase Presets for the built-in `quds:pen` vector pen-drawing library
/// (fractals, Islamic geometric stars, rainbow spirals, space-filling curves,
/// mandalas, and filled polygons with live 60fps progressive drawing).
library;

import 'presets.dart';

final List<StudioPreset> studioPenPresets = [
  // 1. Islamic Geometric Star Rosette (Animated)
  StudioPreset(
    id: 'pen_islamic_star',
    titleAr: '⭐ نجمة وزخرفة هندسية (quds:pen)',
    titleEn: 'Geometric Star Rosette (quds:pen)',
    subtitleAr:
        'رسم حي متدرج لزخرفة نجمية متداخلة بأوامر القلم forward و right',
    fileName: 'pen_islamic_star.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — زخرفة نجمية هندسية مرسومة حياً بالقلم
use quds:pen as pen
use quds:viz as viz

petals = viz.slider("petals", min: 6.0, max: 24.0, value: 12.0, step: 2.0, label: "عدد المحاور").toInt()
size = viz.slider("size", min: 40.0, max: 110.0, value: 78.0, step: 5.0, label: "حجم النجمة")

pen.width(2.0)
rotStep = 360.0 / petals

for k in 0..(petals - 1):
  pen.color(pen.hsl(k * rotStep, 0.88, 0.60))
  pen.up()
  pen.home()
  pen.setHeading(k * rotStep)
  pen.down()
  for side in 1..4:
    pen.forward(size)
    pen.right(90.0)
    pen.forward(size * 0.45)
    pen.right(45.0)

pen.readout("المحاور", petals, color: "gold")
pen.render(title: "⭐ زخرفة هندسية بـ quds:pen", animate: true, duration: 5.0, showPen: true)
''',
  ),

  // 2. Recursive Fractal Tree (Animated)
  StudioPreset(
    id: 'pen_fractal_tree',
    titleAr: '🌳 شجرة فراكتل متكررة (Fractal Tree)',
    titleEn: 'Recursive Fractal Tree (quds:pen)',
    subtitleAr:
        'شجرة تنمو تلقائياً بالتكرار الذاتي (Recursion) مع تحكم بالزاوية والعمق',
    fileName: 'pen_fractal_tree.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — شجرة فراكتل متكررة (Recursive Tree)
use quds:pen as pen
use quds:viz as viz

maxDepth = viz.slider("depth", min: 3.0, max: 8.0, value: 7.0, step: 1.0, label: "عمق التفرع").toInt()
spread = viz.slider("spread", min: 14.0, max: 42.0, value: 25.0, step: 1.0, label: "زاوية التفرع (°)")

drawBranch(length: double, level: int) -> void:
  if level <= 0:
    pen.dot(3.8, "emerald")
    return
  if level <= 2:
    pen.color("#34D399")
  else if level <= 4:
    pen.color("#10B981")
  else:
    pen.color("#D97706")
  pen.width(level * 0.85)
  pen.forward(length)
  pen.left(spread)
  drawBranch(length * 0.72, level - 1)
  pen.right(spread * 2.0)
  drawBranch(length * 0.72, level - 1)
  pen.left(spread)
  pen.up()
  pen.backward(length)
  pen.down()

pen.up()
pen.goto(0.0, -110.0)
pen.setHeading(90.0)
pen.down()
drawBranch(72.0, maxDepth)

pen.readout("العمق", maxDepth, color: "emerald")
pen.render(title: "🌳 شجرة فراكتل متكررة (quds:pen)", animate: true, duration: 6.0, showPen: true)
''',
  ),

  // 3. Koch Snowflake Fractal (Animated)
  StudioPreset(
    id: 'pen_koch_snowflake',
    titleAr: '❄️ ندفة ثلج كوخ (Koch Snowflake)',
    titleEn: 'Koch Snowflake Fractal (quds:pen)',
    subtitleAr: 'أشهر فراكتل كلاسيكي مرسوم بأوامر القلم المتكررة',
    fileName: 'pen_koch_snowflake.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — ندفة ثلج كوخ (Koch Snowflake)
use quds:pen as pen
use quds:viz as viz

order = viz.slider("order", min: 1.0, max: 4.0, value: 3.0, step: 1.0, label: "رتبة الفراكتل").toInt()

var segCounter = 0

koch(length: double, depth: int) -> void:
  if depth == 0:
    segCounter = segCounter + 1
    pen.color(pen.hsl(185.0 + (segCounter * 3.0) % 70.0, 0.90, 0.65))
    pen.forward(length)
    return
  third = length / 3.0
  koch(third, depth - 1)
  pen.left(60.0)
  koch(third, depth - 1)
  pen.right(120.0)
  koch(third, depth - 1)
  pen.left(60.0)
  koch(third, depth - 1)

pen.width(2.0)
pen.up()
pen.goto(-95.0, 55.0)
pen.setHeading(0.0)
pen.down()

for edge in 1..3:
  koch(190.0, order)
  pen.right(120.0)

pen.readout("الرتبة", order, color: "sky")
pen.render(title: "❄️ ندفة ثلج كوخ — quds:pen", animate: true, duration: 5.5, showPen: true)
''',
  ),

  // 4. Rainbow Spiral Web (Animated)
  StudioPreset(
    id: 'pen_rainbow_spiral',
    titleAr: '🌀 حلزون قوس قزح المضيء',
    titleEn: 'Neon Rainbow Spiral Web (quds:pen)',
    subtitleAr:
        'شبكة حلزونية ملوّنة تتشكّل من تكرار forward + right بزاوية مائلة',
    fileName: 'pen_rainbow_spiral.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — حلزون قوس قزح الهندسي
use quds:pen as pen
use quds:viz as viz

sides = viz.slider("sides", min: 3.0, max: 8.0, value: 6.0, step: 1.0, label: "أضلاع المضلع").toInt()
twist = viz.slider("twist", min: 0.5, max: 8.0, value: 2.0, step: 0.5, label: "زاوية الالتفاف (°)")
steps = viz.slider("steps", min: 40.0, max: 160.0, value: 110.0, step: 10.0, label: "عدد الخطوات").toInt()

turnAngle = (360.0 / sides) + twist
pen.width(1.9)

for i in 1..steps:
  pen.color(pen.hsl(i * 4.5, 0.92, 0.58))
  pen.forward(i * 1.45)
  pen.right(turnAngle)

pen.readout("الزاوية", turnAngle.toStringAsFixed(1), unit: "°", color: "pink")
pen.render(title: "🌀 حلزون قوس قزح بـ quds:pen", animate: true, duration: 5.0, showPen: true)
''',
  ),

  // 5. Sierpinski Fractal Triangle (Animated)
  StudioPreset(
    id: 'pen_sierpinski',
    titleAr: '🔺 مثلث سيربينسكي الهندسي',
    titleEn: 'Sierpinski Fractal Triangle (quds:pen)',
    subtitleAr: 'تقسيم ذاتي للمثلثات الملوّنة مع beginFill و endFill',
    fileName: 'pen_sierpinski.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — مثلث سيربينسكي الفراكتلي بالتعبئة
use quds:pen as pen
use quds:viz as viz

depth = viz.slider("depth", min: 1.0, max: 4.0, value: 3.0, step: 1.0, label: "عمق التقسيم").toInt()

var triIdx = 0

drawTri(size: double) -> void:
  triIdx = triIdx + 1
  col = pen.hsl((triIdx * 19.0) % 360.0, 0.86, 0.58)
  pen.color(col, col)
  pen.beginFill()
  for k in 1..3:
    pen.forward(size)
    pen.left(120.0)
  pen.endFill()

sierpinski(size: double, level: int) -> void:
  if level == 0:
    drawTri(size)
    return
  half = size / 2.0
  sierpinski(half, level - 1)
  pen.up()
  pen.forward(half)
  pen.down()
  sierpinski(half, level - 1)
  pen.up()
  pen.backward(half)
  pen.left(60.0)
  pen.forward(half)
  pen.right(60.0)
  pen.down()
  sierpinski(half, level - 1)
  pen.up()
  pen.left(60.0)
  pen.backward(half)
  pen.right(60.0)
  pen.down()

pen.width(1.6)
pen.up()
pen.goto(-100.0, -82.0)
pen.setHeading(0.0)
pen.down()
sierpinski(200.0, depth)

pen.readout("المثلثات", triIdx, color: "amber")
pen.render(title: "🔺 مثلث سيربينسكي — quds:pen", animate: true, duration: 5.5, showPen: true)
''',
  ),

  // 6. Circular Pen Mandala (Animated)
  StudioPreset(
    id: 'pen_mandala_petals',
    titleAr: '🌸 ماندالا هندسية بالدوائر والأقواس',
    titleEn: 'Circular Pen Mandala (quds:pen)',
    subtitleAr: 'رسم بتلات متناظرة باستخدام pen.circle و pen.arc',
    fileName: 'pen_mandala.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — ماندالا هندسية باستخدام الدوائر والأقواس
use quds:pen as pen
use quds:viz as viz

count = viz.slider("count", min: 6.0, max: 24.0, value: 16.0, step: 2.0, label: "عدد البتلات").toInt()
radius = viz.slider("radius", min: 25.0, max: 65.0, value: 46.0, step: 3.0, label: "نصف قطر الدائرة")

stepDeg = 360.0 / count
pen.width(1.8)

for i in 0..(count - 1):
  pen.color(pen.hsl(i * stepDeg, 0.90, 0.62))
  pen.circle(radius, steps: 28)
  pen.right(stepDeg)

pen.readout("البتلات", count, color: "pink")
pen.render(title: "🌸 ماندالا دائرية بـ quds:pen", animate: true, duration: 5.0, showPen: true)
''',
  ),

  // 7. Hilbert Space-Filling Curve (Animated)
  StudioPreset(
    id: 'pen_hilbert_curve',
    titleAr: '🧩 منحنى هيلبرت المالئ للفراغ',
    titleEn: 'Hilbert Space-Filling Curve (quds:pen)',
    subtitleAr:
        'خوارزمية كلاسيكية في علوم الحاسوب ترسم مساراً متصلاً يملأ المربع كاملاً',
    fileName: 'pen_hilbert.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — منحنى هيلبرت المالئ للفراغ (Hilbert Curve)
use quds:pen as pen
use quds:viz as viz

order = viz.slider("order", min: 2.0, max: 5.0, value: 4.0, step: 1.0, label: "رتبة المنحنى").toInt()

var stepNum = 0

hilbert(level: int, angle: double, stepLen: double) -> void:
  if level == 0:
    return
  pen.right(angle)
  hilbert(level - 1, -angle, stepLen)
  stepNum = stepNum + 1
  pen.color(pen.hsl((stepNum * 2.2) % 360.0, 0.90, 0.60))
  pen.forward(stepLen)
  pen.left(angle)
  hilbert(level - 1, angle, stepLen)
  stepNum = stepNum + 1
  pen.color(pen.hsl((stepNum * 2.2) % 360.0, 0.90, 0.60))
  pen.forward(stepLen)
  hilbert(level - 1, angle, stepLen)
  pen.left(angle)
  stepNum = stepNum + 1
  pen.color(pen.hsl((stepNum * 2.2) % 360.0, 0.90, 0.60))
  pen.forward(stepLen)
  hilbert(level - 1, -angle, stepLen)
  pen.right(angle)

pen.width(2.1)
hilbert(order, 90.0, 14.0)

pen.readout("الرتبة", order, color: "cyan")
pen.render(title: "🧩 منحنى هيلبرت — quds:pen", animate: true, duration: 6.0, showPen: true)
''',
  ),

  // 8. Heighway Dragon Curve (Animated)
  StudioPreset(
    id: 'pen_dragon_curve',
    titleAr: '🐉 منحنى التنين الفراكتلي (Dragon Curve)',
    titleEn: 'Heighway Dragon Curve (quds:pen)',
    subtitleAr: 'فراكتل طيّ الورقة الشهير مرسوم خطوة بخطوة بـ quds:pen',
    fileName: 'pen_dragon.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — منحنى التنين (Heighway Dragon Curve)
use quds:pen as pen
use quds:viz as viz

order = viz.slider("order", min: 4.0, max: 10.0, value: 8.0, step: 1.0, label: "عمق الطيّ").toInt()

var idx = 0

dragon(level: int, length: double, sign: double) -> void:
  if level == 0:
    idx = idx + 1
    pen.color(pen.hsl(200.0 + (idx * 0.9) % 160.0, 0.92, 0.62))
    pen.forward(length)
    return
  nextLen = length / 1.41421356
  pen.left(45.0 * sign)
  dragon(level - 1, nextLen, 1.0)
  pen.right(90.0 * sign)
  dragon(level - 1, nextLen, -1.0)
  pen.left(45.0 * sign)

pen.width(2.0)
dragon(order, 180.0, 1.0)

pen.readout("الطيّات", order, color: "purple")
pen.render(title: "🐉 منحنى التنين — quds:pen", animate: true, duration: 5.5, showPen: true)
''',
  ),

  // 9. Golden Angle Sunflower Spiral (Animated)
  StudioPreset(
    id: 'pen_sunflower_spiral',
    titleAr: '🌻 دوّار الشمس بالزاوية الذهبية',
    titleEn: 'Golden-Angle Pen Sunflower (quds:pen)',
    subtitleAr: 'نقاط وخطوط متناغمة بزاوية فيبوناتشي الذهبية 137.5°',
    fileName: 'pen_sunflower.quds',
    category: StudioCategory.pen,
    isAnimated: true,
    code: r'''# مكتبة quds:pen — حلزون دوّار الشمس بالزاوية الذهبية 137.508°
use quds:pen as pen
use quds:viz as viz
use dart:math as m

seeds = viz.slider("seeds", min: 30.0, max: 140.0, value: 90.0, step: 10.0, label: "عدد البذور").toInt()
angle = viz.slider("angle", min: 135.0, max: 140.0, value: 137.5, step: 0.1, label: "الزاوية الذهبية (°)")

pen.width(1.3)
for i in 1..seeds:
  r = 9.0 * m.sqrt(i.toDouble())
  col = pen.hsl(32.0 + (i * 1.4) % 90.0, 0.92, 0.58)
  pen.color(col)
  pen.up()
  pen.home()
  pen.setHeading(i * angle)
  pen.forward(r * 0.72)
  pen.down()
  pen.forward(r * 0.28)
  pen.dot(4.5, col)

pen.readout("الزاوية", angle.toStringAsFixed(1), unit: "°", color: "gold")
pen.render(title: "🌻 دوّار الشمس الذهبي — quds:pen", animate: true, duration: 5.0, showPen: true)
''',
  ),

  // 10. Filled Polygons, Stars & Stamps Beginner Showcase
  StudioPreset(
    id: 'pen_polygon_garden',
    titleAr: '🔷 حديقة المضلعات والنجوم المعبّأة',
    titleEn: 'Filled Polygons & Stars Showcase (quds:pen)',
    subtitleAr: 'دليل سريع لأوامر polygon و star و beginFill و stamp و text',
    fileName: 'pen_garden.quds',
    category: StudioCategory.pen,
    isAnimated: false,
    code: r'''# مكتبة quds:pen — استعراض شامل للمضلعات والنجوم والتعبئة والنصوص
use quds:pen as pen
use quds:viz as viz

starPts = viz.slider("starPts", min: 5.0, max: 11.0, value: 7.0, step: 2.0, label: "رؤوس النجمة").toInt()

# 1. سداسي منتظم معبّأ
pen.up()
pen.goto(-110.0, -30.0)
pen.setHeading(0.0)
pen.down()
pen.color("sky", "sky")
pen.width(2.4)
pen.beginFill()
pen.polygon(6, 42.0)
pen.endFill()
pen.up()
pen.goto(-88.0, 62.0)
pen.text("سداسي", "sky")

# 2. نجمة هندسية
pen.goto(10.0, 18.0)
pen.setHeading(0.0)
pen.down()
pen.color("gold")
pen.width(2.4)
pen.star(starPts, 88.0)
pen.up()
pen.goto(42.0, 62.0)
pen.text("نجمة {starPts}", "gold")

# 3. دائرة مضيئة مع أختام القلم
pen.goto(10.0, -95.0)
pen.setHeading(0.0)
pen.down()
pen.color("emerald")
pen.circle(34.0, steps: 36)
pen.stamp("emerald")
pen.up()
pen.goto(-15.0, -112.0)
pen.text("quds:pen", "emerald")

pen.readout("رؤوس النجمة", starPts, color: "gold")
pen.render(title: "🔷 حديقة الأشكال بـ quds:pen", showGrid: true, showPen: true)
''',
  ),
];
