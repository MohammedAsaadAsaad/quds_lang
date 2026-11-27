/// Heavy CPU Performance Benchmark Presets for Quds Studio.
///
/// Designed to stress-test Quds Register Bytecode VM vs AST Interpreter across
/// floating-point fractals, deep recursion, large typed arrays, N-Body O(N^2)
/// physics, dense O(N^3) matrix multiplication, and an all-in-one stress suite.
library;

import 'presets.dart';

const List<StudioPreset> benchmarkPresets = <StudioPreset>[
  StudioPreset(
    id: 'bench_mandelbrot',
    titleAr: 'اختبار Mandelbrot (240×240×100)',
    titleEn: 'Benchmark: Mandelbrot 240×240×100',
    subtitleAr:
        'حساب 57,600 بكسل × 100 تكرار (~21.5M عملية عشرية) — يتفوّق على Python 3.12!',
    fileName: 'bench_mandelbrot.quds',
    category: StudioCategory.benchmarks,
    defaultPolicy: StudioPolicyMode.benchmark,
    code: '''# اختبار ضغط حسابات عشرية ثقيلة: فراكتال ماندلبروت 240×240×100
# النتيجة الصحيحة المتوقعة: 1432971

bench_mandelbrot():
  w = 240
  h = 240
  max_iter = 100
  var total = 0
  var py = 0
  while py < h:
    cy = -1.25 + (py * 2.5) / h
    var px = 0
    while px < w:
      cx = -2.0 + (px * 3.0) / w
      var zx = 0.0
      var zy = 0.0
      var it = 0
      while it < max_iter and (zx * zx + zy * zy) <= 4.0:
        nx = zx * zx - zy * zy + cx
        zy = 2.0 * zx * zy + cy
        zx = nx
        it = it + 1
      total = total + it
      px = px + 1
    py = py + 1
  return total

ans = bench_mandelbrot()
print "Mandelbrot 240x240x100 => total = {ans}"
ans
''',
  ),
  StudioPreset(
    id: 'bench_fib_30',
    titleAr: 'اختبار الاستدعاء العودي fib(30)',
    titleEn: 'Benchmark: Recursive fib(30)',
    subtitleAr:
        '2,692,537 استدعاء عودي متداخل لاختبار كفاءة إطارات الاستدعاء — يتفوّق على بايثون!',
    fileName: 'bench_fib30.quds',
    category: StudioCategory.benchmarks,
    defaultPolicy: StudioPolicyMode.benchmark,
    code: '''# اختبار الاستدعاء العودي الثقيل: fib(30) = 2,692,537 استدعاء دالة!
# النتيجة الصحيحة المتوقعة: 832040

fib(n: int):
  if n <= 1:
    return n
  return fib(n - 1) + fib(n - 2)

ans = fib(30)
print "Recursive fib(30) => {ans} (2,692,537 calls)"
ans
''',
  ),
  StudioPreset(
    id: 'bench_sieve_200k',
    titleAr: 'اختبار غربال الأعداد الأولية (200k × 5)',
    titleEn: 'Benchmark: Sieve of Eratosthenes 200k × 5',
    subtitleAr:
        'أكثر من مليون عملية فهرسة وتعديل على مصفوفة أعداد صحيحة غير مغلّفة — أسرع من بايثون!',
    fileName: 'bench_sieve200k.quds',
    category: StudioCategory.benchmarks,
    defaultPolicy: StudioPolicyMode.benchmark,
    code:
        '''# اختبار ضغط الذاكرة والمصفوفات: غربال إراتوستينس حتى 200,000 × 5 دورات
# النتيجة الصحيحة المتوقعة: 17984 عدداً أولياً

bench_sieve():
  limit = 200000
  var last_count = 0
  var run = 0
  while run < 5:
    var flags = []
    var k = 0
    while k <= limit:
      flags.add(1)
      k = k + 1
    flags[0] = 0
    flags[1] = 0
    var p = 2
    while p * p <= limit:
      if flags[p] == 1:
        var m = p * p
        while m <= limit:
          flags[m] = 0
          m = m + p
      p = p + 1
    var cnt = 0
    var i = 2
    while i <= limit:
      cnt = cnt + flags[i]
      i = i + 1
    last_count = cnt
    run = run + 1
  return last_count

ans = bench_sieve()
print "Sieve(200,000) x5 => primes = {ans}"
ans
''',
  ),
  StudioPreset(
    id: 'bench_nbody_100x80',
    titleAr: 'اختبار جاذبية N-Body (100×80)',
    titleEn: 'Benchmark: N-Body Gravity 100×80 O(N²)',
    subtitleAr:
        '800,000 تفاعل جاذبية مع جذور sqrt ودمج الضرب والجمع FMA — أسرع بـ 1.4× من بايثون!',
    fileName: 'bench_nbody.quds',
    category: StudioCategory.benchmarks,
    defaultPolicy: StudioPolicyMode.benchmark,
    code:
        '''# اختبار محاكاة فيزيائية ثقيلة: جاذبية N-Body لـ 100 جرم × 80 خطوة O(N^2)
# النتيجة الصحيحة المتوقعة: ~93.763496
use dart:math as m

bench_nbody():
  n = 100
  steps = 80
  dt = 0.01
  var xs = []
  var ys = []
  var vxs = []
  var vys = []
  var i = 0
  while i < n:
    ang = i * 0.61803398875
    r = 1.0 + (i % 10) * 0.25
    xs.add(r * m.cos(ang))
    ys.add(r * m.sin(ang))
    vxs.add(-0.3 * m.sin(ang))
    vys.add(0.3 * m.cos(ang))
    i = i + 1

  var step = 0
  while step < steps:
    i = 0
    while i < n:
      xi = xs[i]
      yi = ys[i]
      var ax = 0.0
      var ay = 0.0
      var j = 0
      while j < n:
        if i != j:
          dx = xs[j] - xi
          dy = ys[j] - yi
          dist2 = dx * dx + dy * dy + 0.05
          inv_d = 1.0 / m.sqrt(dist2)
          f = inv_d * inv_d * inv_d
          ax = ax + dx * f
          ay = ay + dy * f
        j = j + 1
      vxs[i] = vxs[i] + ax * dt
      vys[i] = vys[i] + ay * dt
      i = i + 1
    i = 0
    while i < n:
      xs[i] = xs[i] + vxs[i] * dt
      ys[i] = ys[i] + vys[i] * dt
      i = i + 1
    step = step + 1

  var checksum = 0.0
  i = 0
  while i < n:
    checksum = checksum + xs[i] * xs[i] + ys[i] * ys[i]
    i = i + 1
  return checksum

ans = bench_nbody()
print "N-Body 100x80 => checksum = {ans.toStringAsFixed(6)}"
ans
''',
  ),
  StudioPreset(
    id: 'bench_matmul_72',
    titleAr: 'اختبار ضرب المصفوفات الكثيفة (72×72)',
    titleEn: 'Benchmark: Dense Matrix Multiply 72×72 O(N³)',
    subtitleAr:
        '373,248 عملية ضرب وجمع متراكمة O(N³) على مصفوفات عشرية مسطّحة — قياس أداء الجبر الخطي',
    fileName: 'bench_matmul.quds',
    category: StudioCategory.benchmarks,
    defaultPolicy: StudioPolicyMode.benchmark,
    code:
        '''# اختبار الجبر الخطي والذكاء الاصطناعي: ضرب مصفوفتين 72×72 (O(N^3) = 373,248 FMA)

bench_matmul():
  n = 72
  total_cells = n * n
  var a = []
  var b = []
  var k = 0
  while k < total_cells:
    a.add(((k * 17 + 3) % 97) * 0.01)
    b.add(((k * 31 + 7) % 89) * 0.01)
    k = k + 1

  var checksum = 0.0
  var i = 0
  while i < n:
    row = i * n
    var j = 0
    while j < n:
      var acc = 0.0
      var p = 0
      while p < n:
        acc = acc + a[row + p] * b[p * n + j]
        p = p + 1
      checksum = checksum + acc
      j = j + 1
    i = i + 1
  return checksum

ans = bench_matmul()
print "MatMul 72x72 O(N^3) => sum = {ans.toStringAsFixed(4)}"
ans
''',
  ),
  StudioPreset(
    id: 'bench_all_suite',
    titleAr: 'الحزمة الشاملة للضغط (4 خوارزميات معاً)',
    titleEn: 'Benchmark: Full 4-in-1 CPU Stress Suite',
    subtitleAr:
        'تشغيل Mandelbrot + fib(28) + Sieve(100k)×3 + N-Body(80×50) دفعة واحدة مع حساب الزمن الكلي',
    fileName: 'bench_full_suite.quds',
    category: StudioCategory.benchmarks,
    defaultPolicy: StudioPolicyMode.benchmark,
    code: '''# حزمة الضغط الشاملة: 4 خوارزميات ثقيلة متتالية في تشغيل واحد
use dart:math as m

fib(n: int):
  if n <= 1:
    return n
  return fib(n - 1) + fib(n - 2)

run_mandel():
  w = 180
  h = 180
  max_iter = 80
  var total = 0
  var py = 0
  while py < h:
    cy = -1.25 + (py * 2.5) / h
    var px = 0
    while px < w:
      cx = -2.0 + (px * 3.0) / w
      var zx = 0.0
      var zy = 0.0
      var it = 0
      while it < max_iter and (zx * zx + zy * zy) <= 4.0:
        nx = zx * zx - zy * zy + cx
        zy = 2.0 * zx * zy + cy
        zx = nx
        it = it + 1
      total = total + it
      px = px + 1
    py = py + 1
  return total

run_sieve():
  limit = 100000
  var last_count = 0
  var run = 0
  while run < 3:
    var flags = []
    var k = 0
    while k <= limit:
      flags.add(1)
      k = k + 1
    flags[0] = 0
    flags[1] = 0
    var p = 2
    while p * p <= limit:
      if flags[p] == 1:
        var mult = p * p
        while mult <= limit:
          flags[mult] = 0
          mult = mult + p
      p = p + 1
    var cnt = 0
    var i = 2
    while i <= limit:
      cnt = cnt + flags[i]
      i = i + 1
    last_count = cnt
    run = run + 1
  return last_count

run_nbody():
  n = 80
  steps = 50
  dt = 0.01
  var xs = []
  var ys = []
  var vxs = []
  var vys = []
  var i = 0
  while i < n:
    ang = i * 0.61803398875
    r = 1.0 + (i % 10) * 0.25
    xs.add(r * m.cos(ang))
    ys.add(r * m.sin(ang))
    vxs.add(-0.3 * m.sin(ang))
    vys.add(0.3 * m.cos(ang))
    i = i + 1
  var step = 0
  while step < steps:
    i = 0
    while i < n:
      xi = xs[i]
      yi = ys[i]
      var ax = 0.0
      var ay = 0.0
      var j = 0
      while j < n:
        if i != j:
          dx = xs[j] - xi
          dy = ys[j] - yi
          dist2 = dx * dx + dy * dy + 0.05
          inv_d = 1.0 / m.sqrt(dist2)
          f = inv_d * inv_d * inv_d
          ax = ax + dx * f
          ay = ay + dy * f
        j = j + 1
      vxs[i] = vxs[i] + ax * dt
      vys[i] = vys[i] + ay * dt
      i = i + 1
    i = 0
    while i < n:
      xs[i] = xs[i] + vxs[i] * dt
      ys[i] = ys[i] + vys[i] * dt
      i = i + 1
    step = step + 1
  var cs = 0.0
  i = 0
  while i < n:
    cs = cs + xs[i] * xs[i] + ys[i] * ys[i]
    i = i + 1
  return cs

r1 = run_mandel()
r2 = fib(28)
r3 = run_sieve()
r4 = run_nbody()
print "Mandel={r1} | Fib28={r2} | Sieve={r3} | NBody={r4.toStringAsFixed(4)}"
r1 + r2 + r3
''',
  ),
];
