/// 22 Presets across Algorithms & CS (8), Quds 1.2 Language Showcase (6),
/// and Bonus Science/AI/Space/Math (8).
library;

import 'presets.dart';

const csLanguageAndBonusPresets = <StudioPreset>[
  // ═══════════════════════════════════════════════════════════════════════════
  // Algorithms & Computer Science (8)
  // ═══════════════════════════════════════════════════════════════════════════

  StudioPreset(
    id: 'algo_sorting_visualizer',
    titleAr: 'خوارزميات: تصور حي لفرز المصفوفات (Bubble Sort)',
    titleEn: 'Algo: Live Animated Sorting Visualizer',
    subtitleAr:
        'شاهد عملية الفرز خطوة بخطوة مع تمييز العناصر المقارنة والأعمدة المرتبة بالألوان',
    fileName: 'sorting_visualizer.quds',
    category: StudioCategory.algorithms,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 10, duration: 25.0, loop: true)
reset = viz.toggle("reset", value: false, label: "إعادة خلط العناصر")

var arr = viz.state("sarr", [7, 2, 9, 4, 1, 8, 5, 10, 3, 6, 11, 4])
var curI = viz.state("si", 0)
var curJ = viz.state("sj", 0)
var swaps = viz.state("swaps", 0)

if reset:
  arr = [7, 2, 9, 4, 1, 8, 5, 10, 3, 6, 11, 4]
  curI = 0
  curJ = 0
  swaps = 0

n = arr.length
var activeA = -1
var activeB = -1
if curI < n - 1:
  activeA = curJ
  activeB = curJ + 1
  if arr[curJ] > arr[curJ + 1]:
    tmp = arr[curJ]
    arr[curJ] = arr[curJ + 1]
    arr[curJ + 1] = tmp
    swaps = swaps + 1
  curJ = curJ + 1
  if curJ >= n - 1 - curI:
    curJ = 0
    curI = curI + 1

viz.setState("sarr", arr)
viz.setState("si", curI)
viz.setState("sj", curJ)
viz.setState("swaps", swaps)

s = viz.scene(title: "فرز الفقاعات الحي — عدد التبديلات: " + swaps, grid: false, axes: false, bounds: [-0.8, 12.2, -0.5, 12.5])
for k in 0..<n:
  h = arr[k] * 1.0
  col = (if k >= n - curI: "#10B981" else: (if k == activeA or k == activeB: "#FACC15" else: "#38BDF8"))
  s.polygon("bar{k}", [[k + 0.1, 0.0], [k + 0.85, 0.0], [k + 0.85, h], [k + 0.1, h]], stroke: col, fill: col)
s.readout("التبديلات", swaps, decimals: 0, color: "#FACC15")
s.readout("المرتبة", curI, decimals: 0, color: "#10B981")
s.render()
''',
  ),

  StudioPreset(
    id: 'algo_binary_search',
    titleAr: 'خوارزميات: البحث الثنائي البصري O(log n)',
    titleEn: 'Algo: Visual Binary Search Stepper',
    subtitleAr:
        'اختر الرقم المطلوب وشاهد كيف يقلّص البحث الثنائي المجال إلى النصف في خطوات معدودة',
    fileName: 'binary_search.quds',
    category: StudioCategory.algorithms,
    isAnimated: false,
    code: '''use quds:viz as viz

target = viz.slider("target", min: 2.0, max: 64.0, value: 38.0, step: 2.0, label: "القيمة المطلوبة")
data = [2, 6, 10, 14, 18, 22, 26, 30, 34, 38, 42, 46, 50, 54, 58, 62]

var lo = 0
var hi = data.length - 1
var found = -1
var steps = []

while lo <= hi:
  mid = (lo + hi) ~/ 2
  steps.add(["خطوة " + (steps.length + 1), "[" + lo + ".." + hi + "]", "mid=" + mid + " (" + data[mid] + ")"])
  if data[mid] == target.toInt():
    found = mid
    break
  else if data[mid] < target.toInt():
    lo = mid + 1
  else:
    hi = mid - 1

s = viz.scene(title: "البحث الثنائي عن " + target.toInt() + (if found >= 0: " -> الفهرس " + found else: " -> غير موجود"), grid: false, axes: false, bounds: [-0.6, 16.4, -0.5, 8.0])
for i in 0..<data.length:
  h = data[i] / 9.0
  col = (if i == found: "#10B981" else: (if i >= lo and i <= hi: "#38BDF8" else: "#334155"))
  s.polygon("b{i}", [[i + 0.1, 0.0], [i + 0.85, 0.0], [i + 0.85, h], [i + 0.1, h]], stroke: col, fill: col)
s.readout("عدد الخطوات", steps.length, decimals: 0, color: "#FACC15")
s.readout("الفهرس المكتشف", found, decimals: 0, color: "#10B981")
s.render()
viz.table(["الخطوة", "المجال", "فحص الوسط"], steps, title: "تتبع البحث الثنائي")
''',
  ),

  StudioPreset(
    id: 'algo_dijkstra_network',
    titleAr: 'خوارزميات: ديكسترا لأقصر مسار في شبكة موزونة',
    titleEn: 'Algo: Dijkstra Shortest Path Graph',
    subtitleAr:
        'شبكة خوادم موزونة تحسب المسار الأقصر وتبرزه بصرياً مع التكلفة الكلية',
    fileName: 'dijkstra_network.quds',
    category: StudioCategory.algorithms,
    isAnimated: false,
    code: '''use quds:viz as viz

dest = viz.select("dest", ["S4", "S5", "S6"], value: "S6", label: "الخادم الهدف")

g = viz.graph(title: "توجيه الشبكة بأقصر مسار (Dijkstra) من S1 إلى " + dest, directed: false)
g.node("S1", label: "S1 (البداية)", x: -3.5, y: 0.0, color: "#10B981")
g.node("S2", label: "S2", x: -1.2, y: 2.2, color: "#38BDF8")
g.node("S3", label: "S3", x: -1.2, y: -2.2, color: "#38BDF8")
g.node("S4", label: "S4", x: 1.4, y: 2.0, color: "#6366F1")
g.node("S5", label: "S5", x: 1.4, y: -2.0, color: "#6366F1")
g.node("S6", label: "S6 (الهدف)", x: 3.8, y: 0.0, color: "#F59E0B")

g.edge("S1", "S2", weight: 4, label: "4ms")
g.edge("S1", "S3", weight: 2, label: "2ms")
g.edge("S3", "S2", weight: 1, label: "1ms")
g.edge("S2", "S4", weight: 5, label: "5ms")
g.edge("S3", "S5", weight: 8, label: "8ms")
g.edge("S4", "S5", weight: 2, label: "2ms")
g.edge("S4", "S6", weight: 3, label: "3ms")
g.edge("S5", "S6", weight: 4, label: "4ms")

path = (if dest == "S4": ["S1", "S3", "S2", "S4"] else: (if dest == "S5": ["S1", "S3", "S5"] else: ["S1", "S3", "S2", "S4", "S6"]))
cost = (if dest == "S4": 8 else: (if dest == "S5": 10 else: 11))
g.highlightPath(path)
g.render()
print "أقصر مسار إلى " + dest + ": " + path.join(" → ") + " (الزمن: " + cost + "ms)"
''',
  ),

  StudioPreset(
    id: 'algo_game_of_life',
    titleAr: 'خوارزميات: لعبة الحياة لكونواي (Cellular Automaton)',
    titleEn: 'Algo: Conway Game of Life Automaton',
    subtitleAr:
        'أتمتة خلوية حيّة تولّد أنماطاً متطورة ذاتياً (Glider / Pulsar) على شبكة ثنائية',
    fileName: 'game_of_life.quds',
    category: StudioCategory.algorithms,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 8, duration: 40.0, loop: true)
pattern = viz.select("pat", ["Glider + Blinker", "Toad + Beacon"], value: "Glider + Blinker", label: "النمط الابتدائي")
reset = viz.toggle("reset", value: false, label: "إعادة التشغيل")

W = 12
H = 10
makeInit(pat: String) -> List<int>:
  var g = [0 for _ in 0..<(W * H)]
  if pat == "Glider + Blinker":
    for p in [[1, 2], [2, 3], [3, 1], [3, 2], [3, 3], [8, 5], [8, 6], [8, 7]]:
      g[p[1] * W + p[0]] = 1
  else:
    for p in [[3, 4], [4, 4], [5, 4], [2, 5], [3, 5], [4, 5], [8, 2], [9, 2], [8, 3], [10, 4], [9, 5], [10, 5]]:
      g[p[1] * W + p[0]] = 1
  return g

var grid = viz.state("golGrid", makeInit(pattern))
var gen = viz.state("golGen", 0)
if reset:
  grid = makeInit(pattern)
  gen = 0

var next = [0 for _ in 0..<(W * H)]
var alive = 0
for y in 0..<H:
  for x in 0..<W:
    var nbs = 0
    for dy in -1..1:
      for dx in -1..1:
        if dx != 0 or dy != 0:
          nx = (x + dx + W) % W
          ny = (y + dy + H) % H
          nbs = nbs + grid[ny * W + nx]
    cur = grid[y * W + x]
    nxt = (if cur == 1: (if nbs == 2 or nbs == 3: 1 else: 0) else: (if nbs == 3: 1 else: 0))
    next[y * W + x] = nxt
    alive = alive + nxt

gen = gen + 1
viz.setState("golGrid", next)
viz.setState("golGen", gen)

s = viz.scene(title: "لعبة الحياة لكونواي — الجيل " + gen, grid: true, axes: false, bounds: [-0.5, 11.5, -0.5, 9.5])
for y in 0..<H:
  for x in 0..<W:
    if next[y * W + x] == 1:
      s.polygon("c{x}_{y}", [[x - 0.42, y - 0.42], [x + 0.42, y - 0.42], [x + 0.42, y + 0.42], [x - 0.42, y + 0.42]], stroke: "#10B981", fill: "#10B981")
s.readout("الجيل", gen, decimals: 0, color: "#38BDF8")
s.readout("الخلايا الحية", alive, decimals: 0, color: "#10B981")
s.render()
''',
  ),

  StudioPreset(
    id: 'algo_bst_tree',
    titleAr: 'هياكل بيانات: شجرة البحث الثنائية المتوازنة (BST)',
    titleEn: 'Data Structures: Binary Search Tree Visualizer',
    subtitleAr:
        'عرض هرمي لشجرة بحث ثنائية مع الترتيب الوسطي (In-Order) وارتفاع الشجرة',
    fileName: 'bst_tree.quds',
    category: StudioCategory.algorithms,
    isAnimated: false,
    code: '''use quds:viz as viz

g = viz.graph(title: "شجرة البحث الثنائية المتوازنة (BST)", directed: true)
g.node("50", label: "50 (الجذر)", x: 0.0, y: 3.0, color: "#F59E0B")
g.node("25", label: "25", x: -2.6, y: 1.4, color: "#38BDF8")
g.node("75", label: "75", x: 2.6, y: 1.4, color: "#38BDF8")
g.node("12", label: "12", x: -3.9, y: -0.4, color: "#10B981")
g.node("37", label: "37", x: -1.3, y: -0.4, color: "#10B981")
g.node("62", label: "62", x: 1.3, y: -0.4, color: "#10B981")
g.node("88", label: "88", x: 3.9, y: -0.4, color: "#10B981")

g.edge("50", "25", label: "<")
g.edge("50", "75", label: ">")
g.edge("25", "12", label: "<")
g.edge("25", "37", label: ">")
g.edge("75", "62", label: "<")
g.edge("75", "88", label: ">")
g.highlightPath(["50", "75", "62"])
g.render()

viz.table(["الخاصية", "القيمة"], [["المرور الوسطي In-Order", "12, 25, 37, 50, 62, 75, 88"], ["الارتفاع", "3 مستويات"], ["تعقيد البحث", "O(log n)"]], title: "تحليل شجرة BST")
''',
  ),

  StudioPreset(
    id: 'algo_caesar_cipher',
    titleAr: 'أمن المعلومات: التشفير القيصري وفك التشفير',
    titleEn: 'Security: Caesar Cipher Encryption Lab',
    subtitleAr:
        'أدخل رسالتك واضبط مفتاح الإزاحة لمشاهدة النص المشفر وفك تشفيره الفوري',
    fileName: 'caesar_cipher.quds',
    category: StudioCategory.algorithms,
    isAnimated: false,
    code: '''use quds:viz as viz

plain = viz.input("msg", value: "QUDS LANGUAGE FAST VM", label: "الرسالة الأصلية (إنجليزي)")
shift = viz.slider("shift", min: 1.0, max: 25.0, value: 7.0, step: 1.0, label: "مفتاح الإزاحة")

alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
caesar(text: String, k: int) -> String:
  var out = ""
  upper = text.toUpperCase()
  for i in 0..<upper.length:
    ch = upper[i]
    idx = alphabet.indexOf(ch)
    if idx >= 0:
      out = out + alphabet[(idx + k + 26) % 26]
    else:
      out = out + ch
  return out

k = shift.toInt()
encrypted = caesar(plain, k)
decrypted = caesar(encrypted, -k)

info = map:
  "النص الأصلي": plain
  "مفتاح التشفير": "+" + k
  "النص المشفر": encrypted
  "بعد فك التشفير": decrypted

viz.form(info, title: "مختبر التشفير القيصري", summary: "تشفير وفك تشفير فوري بدون فقدان حرف واحد")
''',
  ),

  StudioPreset(
    id: 'algo_rle_compression',
    titleAr: 'خوارزميات: ضغط النصوص بترميز طول التكرار (RLE)',
    titleEn: 'Algo: Run-Length Encoding Compression',
    subtitleAr:
        'قياس نسبة ضغط النصوص المتكررة وعرض الرموز المضغوطة وحجم التوفير',
    fileName: 'rle_compression.quds',
    category: StudioCategory.algorithms,
    isAnimated: false,
    code: '''use quds:viz as viz

raw = viz.input("raw", value: "AAAAABBBCCCCCCDDDDDDDEEEEEEEE", label: "النص المراد ضغطه")

rleEncode(s: String) -> String:
  if s.isEmpty: return ""
  var out = ""
  var count = 1
  for i in 1..<s.length:
    if s[i] == s[i - 1]:
      count = count + 1
    else:
      out = out + s[i - 1] + count
      count = 1
  out = out + s[s.length - 1] + count
  return out

compressed = rleEncode(raw)
ratio = (if raw.length > 0: (1.0 - compressed.length / raw.length) * 100.0 else: 0.0)
viz.table(["المقياس", "القيمة"], [["النص الأصلي", raw], ["النص المضغوط", compressed], ["الطول الأصلي", "{raw.length} حرف"], ["الطول المضغوط", "{compressed.length} حرف"], ["نسبة التوفير", ratio.toStringAsFixed(1) + "%"]], title: "تحليل ضغط RLE")
''',
  ),

  StudioPreset(
    id: 'algo_knapsack_dp',
    titleAr: 'خوارزميات: مشكلة حقيبة الظهر (0/1 Knapsack DP)',
    titleEn: 'Algo: 0/1 Knapsack Dynamic Programming',
    subtitleAr:
        'غيّر سعة الحقيبة لتحسب البرمجة الديناميكية أفضل توليفة عناصر بأعلى قيمة ممكنة',
    fileName: 'knapsack_dp.quds',
    category: StudioCategory.algorithms,
    isAnimated: false,
    code: '''use quds:viz as viz

capSlider = viz.slider("cap", min: 4.0, max: 15.0, value: 10.0, step: 1.0, label: "سعة الحقيبة (كغ)")
cap = capSlider.toInt()

names = ["حاسوب محمول", "كاميرا", "بطارية شمسية", "عدسة", "كتاب مرجعي"]
weights = [4, 3, 5, 2, 3]
values = [60, 42, 72, 30, 35]
n = names.length

var dp = [0 for _ in 0..cap]
for i in 0..<n:
  w = weights[i]
  v = values[i]
  var c = cap
  while c >= w:
    cand = dp[c - w] + v
    if cand > dp[c]:
      dp[c] = cand
    c = c - 1

var rows = []
for i in 0..<n:
  rows.add([names[i], "{weights[i]} كغ", "{values[i]} نقطة", (values[i] / weights[i]).toStringAsFixed(1)])

viz.table(["العنصر", "الوزن", "القيمة", "الكثافة"], rows, title: "عناصر حقيبة الظهر — القيمة المثلى لسعة " + cap + " كغ = " + dp[cap] + " نقطة")
print "أقصى قيمة مثلى للسعة " + cap + " كغ = " + dp[cap] + " نقطة"
''',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // Quds 1.2 Language Showcase (6)
  // ═══════════════════════════════════════════════════════════════════════════

  StudioPreset(
    id: 'lang_operator_augment',
    titleAr: 'قدس 1.2: التحميل الزائد للمعاملات ودمج النصوص (+ augment)',
    titleEn: 'Quds 1.2: Operator Overloading, augment & String + any',
    subtitleAr:
        'عرض حي لدمج النصوص التلقائي ("Ahmed" + 10) وتحميل المعاملات الزائدة في class و augment',
    fileName: 'operator_augment_demo.quds',
    category: StudioCategory.language,
    isAnimated: false,
    code: '''use quds:viz as viz

class Vec2:
  x: double
  y: double
  init(this.x, this.y)

  operator +(other: Vec2) -> Vec2 = Vec2(x + other.x, y + other.y)
  operator +(scalar: int) -> Vec2 = Vec2(x + scalar, y + scalar)
  operator *(other: Vec2) -> double = x * other.x + y * other.y
  operator -() -> Vec2 = Vec2(-x, -y)
  toString() -> String = "(" + x + ", " + y + ")"

augment Vec2:
  operator *(k: int) -> Vec2 = Vec2(x * k, y * k)

augment String:
  operator -(suffix: String) -> String:
    if this.endsWith(suffix):
      return this.substring(0, this.length - suffix.length)
    return this

v1 = Vec2(2.0, 3.0)
v2 = Vec2(4.0, 1.0)

r1 = "Ahmed" + 10
r2 = "" + (v1 + v2)
r3 = "" + (v1 + 5)
r4 = "" + (v1 * 3)
r5 = "" + (v1 * v2)
r6 = "" + (-v1)
r7 = "QudsLang_v1" - "_v1"

print "دمج نص مع رقم: " + r1
print "جمع متجهين: " + r2
print "جمع متجه مع عدد: " + r3
print "ضرب قياسي عبر augment: " + r4
print "ضرب نقطي: " + r5
print "عكس المتجه: " + r6
print "طرح لاحقة من نص: " + r7

viz.table(["التعبير في قدس", "النتيجة"], [["\\"Ahmed\\" + 10", r1], ["v1 + v2", r2], ["v1 + 5", r3], ["v1 * 3 (augment)", r4], ["v1 * v2 (dot)", r5], ["-v1", r6], ["\\"QudsLang_v1\\" - \\"_v1\\"", r7]], title: "عرض التحميل الزائد للمعاملات في قدس 1.2")
''',
  ),

  StudioPreset(
    id: 'lang_sealed_match',
    titleAr: 'قدس 1.2: الأنواع المختومة والمطابقة الشاملة (sealed + match)',
    titleEn: 'Quds 1.2: Sealed Types & Pattern Matching',
    subtitleAr:
        'تقييم أشكال هندسية متعددة باستخدام sealed و match ومطابقة الأنماط النظيفة',
    fileName: 'sealed_match_demo.quds',
    category: StudioCategory.language,
    isAnimated: false,
    code: '''use dart:math as m
use quds:viz as viz

sealed type Shape:
  Circle(r: double)
  Rect(w: double, h: double)

area(s: Shape) -> double:
  return match s:
    Circle(r): m.pi * r * r
    Rect(w, h): w * h

labelOf(s: Shape) -> String:
  return match s:
    Circle(r): "دائرة r=" + r
    Rect(w, h): "مستطيل " + w + "×" + h

shapes = [Circle(3.0), Rect(4.0, 5.0), Circle(5.0), Rect(6.0, 2.5)]
var rows = []
var total = 0.0
for sh in shapes:
  a = area(sh)
  total = total + a
  rows.add([labelOf(sh), a.toStringAsFixed(2)])

print "إجمالي المساحات = " + total.toStringAsFixed(2)
viz.table(["الشكل", "المساحة"], rows, title: "حساب المساحات بـ sealed + match (المجموع = " + total.toStringAsFixed(2) + ")")
''',
  ),

  StudioPreset(
    id: 'lang_result_pipeline',
    titleAr: 'قدس 1.2: معالجة الأخطاء الآمنة (Result + ? + Pipeline)',
    titleEn: 'Quds 1.2: Safe Result<T, E> & Pipelines',
    subtitleAr:
        'تحويل النصوص وقسمة آمنة باستخدام Ok/Error وتمرير القيم بالأنبوب |>',
    fileName: 'result_pipeline.quds',
    category: StudioCategory.language,
    isAnimated: false,
    code: '''use quds:viz as viz

safeDiv(a: double, b: double):
  if b == 0.0:
    return Error("لا يمكن القسمة على صفر")
  return Ok(a / b)

cases = [[100.0, 4.0], [50.0, 0.0], [81.0, 9.0], [15.0, 2.5]]
var rows = []
for pair in cases:
  res = safeDiv(pair[0], pair[1])
  status = (if res is Ok: "✅ " + res.value else: "❌ " + res.error)
  expr = "{pair[0]} / {pair[1]}"
  rows.add([expr, status])
  print expr + " => " + status

viz.table(["العملية", "النتيجة الآمنة"], rows, title: "نمط Result<T, E> في قدس")
''',
  ),

  StudioPreset(
    id: 'lang_generators_streams',
    titleAr: 'قدس 1.2: المولّدات الكسولة (sync* / yield)',
    titleEn: 'Quds 1.2: Lazy Generators (sync* / yield)',
    subtitleAr:
        'توليد متتالية فيبوناتشي والأعداد الأولية بكسل دون استهلاك الذاكرة مسبقاً',
    fileName: 'generators_demo.quds',
    category: StudioCategory.language,
    isAnimated: false,
    code: '''use quds:viz as viz

fibStream(count: int) sync*:
  var a = 0
  var b = 1
  for _ in 0..<count:
    yield a
    next = a + b
    a = b
    b = next

n = viz.slider("n", min: 5.0, max: 20.0, value: 12.0, step: 1.0, label: "عدد الحدود")
var xs = []
var ys = []
var idx = 0
for v in fibStream(n.toInt()):
  xs.add(idx * 1.0)
  ys.add(v * 1.0)
  idx = idx + 1

print "متتالية فيبوناتشي (" + n.toInt() + " حد): " + ys
viz.plot(xs, ys, title: "نمو متتالية فيبوناتشي المولّدة بـ sync* / yield", xLabel: "الفهرس n", yLabel: "F(n)", color: "#8B5CF6")
''',
  ),

  StudioPreset(
    id: 'lang_loops_comprehensions',
    titleAr: 'قدس 1.2: الحلقات التعبيرية والفهم المباشر للقوائم',
    titleEn: 'Quds 1.2: Comprehensions, Ranges & Context Loops',
    subtitleAr:
        'بناء مصفوفات وخرائط بسطر واحد مع الشروط المدمجة والنطاقات .. و step',
    fileName: 'comprehensions_demo.quds',
    category: StudioCategory.language,
    isAnimated: false,
    code: '''use quds:viz as viz

squares = [x * x for x in 1..10 if x % 2 == 0]
var stepped = []
for x in 0..20 step 4:
  stepped.add(x)
pairs = ["#" + i + "=" + (i * i) for i in 1..6]

print "مربعات الأعداد الزوجية: " + squares
print "قفزات بمقدار 4: " + stepped
print "أزواج نصية: " + pairs

viz.table(["التعبير", "الناتج"], [["مربعات الزوجي (1..10)", "" + squares], ["نطاق step 4", "" + stepped], ["سلاسل منسقة", pairs.join(" · ")]], title: "تعبيرية الحلقات والمجموعات في قدس")
''',
  ),

  StudioPreset(
    id: 'lang_conversions_with',
    titleAr: 'قدس 1.2: التحويل الآمن (to / to?) وتحديث الكائنات بـ with?',
    titleEn: 'Quds 1.2: Safe Conversions (to?) & Null-Safe with?',
    subtitleAr:
        'تحويل النصوص بأمان دون استثناءات وتحديث الكائنات القابلة لـ null بوضوح',
    fileName: 'conversions_with.quds',
    category: StudioCategory.language,
    isAnimated: false,
    code: '''use quds:viz as viz

rawAge = viz.input("age", value: "27", label: "أدخل عمراً (رقم أو نص خاطئ)")
parsed = rawAge to? int
safeAge = parsed ?? 18

class UserProfile:
  var name: String
  var age: int
  init(this.name, this.age)

u = UserProfile("أحمد", safeAge)
with? u:
  age = safeAge + 1

details = map:
  "النص المدخل": rawAge
  "نتيجة rawAge to? int": (if parsed != null: "✅ " + parsed else: "null (تم استخدام البديل 18)")
  "العمر بعد تحديث with?": "" + u.age

viz.form(details, title: "التحويل الآمن to? وكتلة with?", summary: "أمان تام ضد أخطاء التحويل والقيم الفارغة")
''',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // Bonus Science, AI, Space & Math (+8)
  // ═══════════════════════════════════════════════════════════════════════════

  StudioPreset(
    id: 'phys_double_slit',
    titleAr: 'فيزياء الكم: تجربة الشق المزدوج ليونغ (Interference)',
    titleEn: 'Quantum: Young Double-Slit Interference',
    subtitleAr:
        'تشكّل أهداب التداخل البناء والهدام على الشاشة بتغيير الطول الموجي والمسافة بين الشقين',
    fileName: 'double_slit.quds',
    category: StudioCategory.physics,
    isAnimated: false,
    code: r'''use dart:math as m
use quds:viz as viz

slitD = viz.slider("d", min: 0.4, max: 2.5, value: 1.2, step: 0.1, label: "المسافة بين الشقين d")
lambda = viz.slider("lam", min: 0.25, max: 1.0, value: 0.5, step: 0.05, label: "الطول الموجي λ")

var xs = []
var intensity = []
for i in -80..80:
  y = i * 0.06
  phi = m.pi * slitD * y / lambda
  env = m.exp(-(y * y) / 10.0)
  I = env * m.cos(phi) * m.cos(phi)
  xs.add(y)
  intensity.add(I)

viz.latex(r"I(y) = I_0 \cos^2(\pi d y / \lambda L)", title: "شدة التداخل في الشق المزدوج")
viz.plot(xs, intensity, title: "نمط أهداب التداخل الكمومي", xLabel: "الموضع على الشاشة y", yLabel: "الشدة I", color: "#06B6D4")
''',
  ),

  StudioPreset(
    id: 'phys_phase_portrait',
    titleAr: 'فيزياء: فضاء الطور لنواس مخمّد (Phase Space Spiral)',
    titleEn: 'Physics: Damped Oscillator Phase Portrait',
    subtitleAr:
        'مسار الحلزون الطوري (السرعة مقابل الإزاحة) وتناقص الطاقة الميكانيكية مع الزمن',
    fileName: 'phase_portrait.quds',
    category: StudioCategory.physics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
zeta = viz.slider("zeta", min: 0.02, max: 0.45, value: 0.12, step: 0.02, label: "معامل التخميد ζ")

var pts = []
for i in 0..140:
  tau = i * 0.12
  env = m.exp(-zeta * tau)
  x = 3.8 * env * m.cos(tau)
  v = -3.8 * env * (m.sin(tau) + zeta * m.cos(tau))
  pts.add([x, v])

s = viz.scene(title: "فضاء الطور (v مقابل x) لنواس مخمّد", grid: true, bounds: [-4.5, 4.5, -4.5, 4.5])
s.curve("spiral", pts, gradient: viz.palette("plasma"), progress: clk.progress, strokeWidth: 2.8, glow: true, showHead: true)
s.point("eq", 0.0, 0.0, label: "الاتزان", color: "#10B981", radius: 6.0)
s.readout("التخميد ζ", zeta, decimals: 2, color: "#EC4899")
s.render()
''',
  ),

  StudioPreset(
    id: 'math_mandelbrot_visual',
    titleAr: 'رياضيات: فراكتل ماندلبروت الملون (Mandelbrot Set)',
    titleEn: 'Math: Mandelbrot Set Fractal Viewer',
    subtitleAr:
        'استكشف مجموعة ماندلبروت بالتكبير المباشر وتلوين نقاط الحدود على محرك VM',
    fileName: 'mandelbrot_visual.quds',
    category: StudioCategory.mathematics,
    isAnimated: false,
    code: '''use quds:viz as viz

zoom = viz.slider("zoom", min: 1.0, max: 4.0, value: 1.2, step: 0.2, label: "مستوى التكبير")
maxIt = viz.slider("it", min: 14.0, max: 40.0, value: 24.0, step: 2.0, label: "دقة التكرار")

cx0 = -0.5
cy0 = 0.0
spanX = 3.2 / zoom
spanY = 2.4 / zoom
limit = maxIt.toInt()

s = viz.scene(title: "مجموعة ماندلبروت z(n+1) = z(n)² + c", grid: false, axes: false, bounds: [-4.2, 4.2, -3.2, 3.2])
var inside = 0
for py in 0..<26:
  for px in 0..<34:
    cr = cx0 - spanX * 0.5 + spanX * px / 33.0
    ci = cy0 - spanY * 0.5 + spanY * py / 25.0
    var zr = 0.0
    var zi = 0.0
    var it = 0
    while zr * zr + zi * zi <= 4.0 and it < limit:
      nt = zr * zr - zi * zi + cr
      zi = 2.0 * zr * zi + ci
      zr = nt
      it = it + 1
    sx = -4.0 + px * (8.0 / 33.0)
    sy = -3.0 + py * (6.0 / 25.0)
    if it == limit:
      inside = inside + 1
      s.point("m{px}_{py}", sx, sy, color: "#0F172A", radius: 4.5)
    else if it > 4:
      hue = (220.0 + it * 14.0) % 360.0
      s.point("b{px}_{py}", sx, sy, color: viz.hsl(hue, 0.9, 0.55), radius: 4.2)

s.readout("نقاط داخل المجموعة", inside, decimals: 0, color: "#8B5CF6")
s.readout("التكبير", zoom, unit: "x", color: "#38BDF8")
s.render()
''',
  ),

  StudioPreset(
    id: 'math_golden_spiral',
    titleAr: 'رياضيات: الحلزون الذهبي ونسبة فيبوناتشي (φ = 1.618)',
    titleEn: 'Math: Golden Ratio Spiral & Phyllotaxis',
    subtitleAr:
        'توزيع البذور بالزاوية الذهبية 137.5° كما في زهرة عباد الشمس مع رسم حركي متوهج',
    fileName: 'golden_spiral.quds',
    category: StudioCategory.mathematics,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
count = viz.slider("n", min: 40.0, max: 140.0, value: 100.0, step: 5.0, label: "عدد البذور")

goldenAngle = 137.507764 * m.pi / 180.0
shown = (count * (0.2 + 0.8 * clk.progress)).toInt()

s = viz.scene(title: "الحلزون الذهبي (φ = 1.61803)", grid: false, axes: false, bounds: [-4.8, 4.8, -4.8, 4.8])
for i in 0..<shown:
  r = 0.36 * m.sqrt(i * 1.0)
  a = i * goldenAngle + clk.t * 0.25
  hue = (40.0 + i * 2.2) % 360.0
  s.point("sd{i}", r * m.cos(a), r * m.sin(a), color: viz.hsl(hue, 0.88, 0.58), radius: 4.2)
s.readout("الزاوية الذهبية", 137.51, unit: "°", color: "#FACC15")
s.readout("البذور المرسومة", shown, decimals: 0, color: "#10B981")
s.render()
''',
  ),

  StudioPreset(
    id: 'astro_hohmann_mars',
    titleAr: 'فلك: مدار هوهمان للانتقال من الأرض إلى المريخ',
    titleEn: 'Space: Earth-to-Mars Hohmann Transfer Orbit',
    subtitleAr:
        'محاكاة رحلة مسبار فضائي عبر القطع الناقص الانتقالي بين مدار الأرض ومدار المريخ',
    fileName: 'hohmann_mars.quds',
    category: StudioCategory.astronomy,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: true)
rEarth = 2.0
rMars = 3.6
aTrans = (rEarth + rMars) / 2.0
cTrans = aTrans - rEarth
bTrans = m.sqrt(rEarth * rMars)

ang = clk.progress * m.pi
px = -cTrans + aTrans * m.cos(ang)
py = bTrans * m.sin(ang)

var transPts = []
for i in 0..60:
  u = m.pi * i / 60.0
  transPts.add([-cTrans + aTrans * m.cos(u), bTrans * m.sin(u)])

eAng = clk.progress * 2.1
mAng = 0.78 + clk.progress * 1.12

s = viz.scene(title: "مدار هوهمان الانتقالي (الأرض ← المريخ)", grid: false, axes: false, bounds: [-4.6, 4.6, -4.4, 4.4])
s.circle("earthOrb", [0.0, 0.0], rEarth, stroke: "#38BDF8", dashed: true)
s.circle("marsOrb", [0.0, 0.0], rMars, stroke: "#EF4444", dashed: true)
s.curve("hohmann", transPts, gradient: viz.palette("sunset"), strokeWidth: 2.8, glow: true)
s.point("sun", 0.0, 0.0, label: "الشمس ☀️", color: "#FACC15", radius: 11.0)
s.point("earth", rEarth * m.cos(eAng), rEarth * m.sin(eAng), label: "الأرض", color: "#38BDF8", radius: 7.0)
s.point("mars", rMars * m.cos(mAng), rMars * m.sin(mAng), label: "المريخ", color: "#EF4444", radius: 6.5)
s.point("probe", px, py, label: "المسبار 🚀", color: "#10B981", radius: 6.5)
s.readout("تقدّم الرحلة", clk.progress * 100.0, unit: "%", decimals: 0, color: "#10B981")
s.readout("زمن الرحلة الفعلي", 259.0, unit: "يوم", decimals: 0, color: "#F59E0B")
s.render()
''',
  ),

  StudioPreset(
    id: 'astro_solar_eclipse',
    titleAr: 'فلك: محاكاة كسوف الشمس ومخروط الظل (Umbra)',
    titleEn: 'Space: Solar Eclipse & Umbra Shadow Cone',
    subtitleAr:
        'حركة القمر أمام قرص الشمس وتشكّل مخروط الظل التام على سطح الأرض',
    fileName: 'solar_eclipse.quds',
    category: StudioCategory.astronomy,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
moonY = 2.2 * m.sin(clk.t * 0.7)
totality = m.max(0.0, 1.0 - moonY.abs() / 0.85) * 100.0

s = viz.scene(title: "محاكاة كسوف الشمس — التغطية: " + totality.toStringAsFixed(0) + "%", grid: false, axes: false, bounds: [-5.5, 5.5, -3.5, 3.5])
s.circle("sun", [-4.0, 0.0], 1.35, stroke: "#FACC15", fill: "#F59E0B")
s.circle("earth", [4.0, 0.0], 0.95, stroke: "#38BDF8", fill: "#0369A1")
s.circle("moon", [1.0, moonY], 0.42, stroke: "#CBD5E1", fill: "#475569")

# أشعة الظل
s.segment("rayTop", [-4.0, 1.35], [4.0, moonY * 1.45 - 0.15], color: "#FACC15", strokeWidth: 1.4, dashed: true)
s.segment("rayBot", [-4.0, -1.35], [4.0, moonY * 1.45 + 0.15], color: "#FACC15", strokeWidth: 1.4, dashed: true)
if totality > 20.0:
  s.point("umbra", 3.1, moonY * 1.35, label: "ظل الكسوف", color: "#0F172A", radius: 7.5)

s.readout("نسبة الكسوف", totality, unit: "%", decimals: 0, color: "#FACC15")
s.render()
''',
  ),

  StudioPreset(
    id: 'ai_kmeans_clustering',
    titleAr: 'ذكاء اصطناعي: تجميع البيانات الحركي (K-Means)',
    titleEn: 'AI: Interactive K-Means Clustering (3 Clusters)',
    subtitleAr:
        'تجميع نقاط البيانات في 3 عناقيد وتحديث المراكز الحسابية مع تمييز لون كل عنقود',
    fileName: 'kmeans_clustering.quds',
    category: StudioCategory.math3d,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
spread = viz.slider("sp", min: 0.4, max: 1.6, value: 0.9, step: 0.1, label: "تشتت العناقيد")

centers = [[-2.6, 1.8], [2.7, 1.6], [0.2, -2.2]]
colors = ["#38BDF8", "#EC4899", "#10B981"]

s = viz.scene(title: "خوارزمية التجميع الذكي K-Means (K=3)", grid: true, bounds: [-5.2, 5.2, -4.4, 4.4])
for c in 0..<3:
  cx = centers[c][0]
  cy = centers[c][1]
  col = colors[c]
  s.circle("ring{c}", [cx, cy], spread * 1.35, stroke: col, dashed: true)
  for k in 0..<8:
    ang = k * (2.0 * m.pi / 8.0) + clk.t * 0.25 + c
    rad = spread * (0.45 + ((k * 3) % 5) * 0.18)
    s.point("pt{c}_{k}", cx + rad * m.cos(ang), cy + rad * m.sin(ang), color: col, radius: 5.0)
  s.point("ctr{c}", cx, cy, label: "مركز " + (c + 1), color: "#FACC15", radius: 9.0)

s.readout("عدد العناقيد K", 3, decimals: 0, color: "#FACC15")
s.readout("إجمالي النقاط", 24, decimals: 0, color: "#38BDF8")
s.render()
''',
  ),

  StudioPreset(
    id: 'ai_neural_boundary',
    titleAr: 'ذكاء اصطناعي: حدود قرار شبكة عصبية (Perceptron)',
    titleEn: 'AI: Neural Decision Boundary & Accuracy',
    subtitleAr:
        'عدّل الأوزان w₁ و w₂ والانحياز b لفصل الفئتين وحساب دقة التصنيف لحظياً',
    fileName: 'neural_boundary.quds',
    category: StudioCategory.math3d,
    isAnimated: false,
    code: '''use quds:viz as viz

w1 = viz.slider("w1", min: -3.0, max: 3.0, value: 1.2, step: 0.1, label: "الوزن w₁")
w2 = viz.slider("w2", min: -3.0, max: 3.0, value: 1.0, step: 0.1, label: "الوزن w₂")
bias = viz.slider("b", min: -3.0, max: 3.0, value: -0.2, step: 0.1, label: "الانحياز b")

pts = [
  [-2.8, 2.4, 1], [-1.5, 2.8, 1], [0.5, 2.1, 1], [2.2, 1.5, 1], [1.4, 2.9, 1], [3.0, 0.2, 1],
  [-3.0, -1.2, 0], [-2.0, -2.5, 0], [-0.4, -1.8, 0], [1.2, -2.4, 0], [-1.2, -0.5, 0], [2.5, -2.8, 0]
]

var correct = 0
s = viz.scene(title: "حدود قرار الشبكة العصبية (w₁x + w₂y + b = 0)", grid: true, bounds: [-4.5, 4.5, -4.0, 4.0])
for i in 0..<pts.length:
  px = pts[i][0]
  py = pts[i][1]
  cls = pts[i][2]
  pred = (if w1 * px + w2 * py + bias >= 0.0: 1 else: 0)
  if pred == cls: correct = correct + 1
  col = (if cls == 1: "#10B981" else: "#EC4899")
  s.point("d{i}", px, py, color: col, radius: 7.5)

if w2 > 0.05 or w2 < -0.05:
  yL = (-bias - w1 * (-4.5)) / w2
  yR = (-bias - w1 * 4.5) / w2
  s.segment("boundary", [-4.5, yL], [4.5, yR], color: "#FACC15", strokeWidth: 3.0)

acc = correct / pts.length * 100.0
s.readout("دقة التصنيف", acc, unit: "%", decimals: 0, color: (if acc >= 90.0: "#10B981" else: "#F59E0B"))
s.readout("صحيح / الكل", correct, decimals: 0, color: "#38BDF8")
s.render()
''',
  ),
];
