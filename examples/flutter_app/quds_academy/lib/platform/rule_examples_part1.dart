/// Executable Quds Rule Examples — Part 1:
/// Categories 1–4: Bindings & Scope, Decisions & Loops, Values & Operators, Types & Composition.
library;

import 'rule_examples_model.dart';

const Map<String, List<AcademyRuleExample>> ruleExamplesPart1 = {
  // ── 1. Bindings & Scope (7) ──────────────────────────────────────────────
  'var': [
    AcademyRuleExample(
      titleAr: 'متغير قابل للتعديل مع عوامل التحديث',
      titleEn: 'Reassignable variable with compound updates',
      noteAr: 'تسمح var بإعادة الإسناد بينما الارتباط بدون var ثابت لا يتغير.',
      noteEn:
          'var allows reassignment while plain name = value stays immutable.',
      code: '''var score = 10
score += 15
score *= 2
print "النتيجة النهائية = {score}"''',
    ),
    AcademyRuleExample(
      titleAr: 'عدّاد داخل حلقة وتجميع نصوص',
      titleEn: 'Loop accumulator and string builder',
      noteAr: 'استخدم var عند تجميع قيمة تتبدل مع كل دورة.',
      noteEn: 'Use var whenever an accumulator changes across iterations.',
      code: '''var sum = 0
var log = ""
for i in 1..4:
  sum += i * i
  log = "{log}{i}^2 "
print "المربعات: {log}"
print "مجموع المربعات = {sum}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تعديل متغير خارجي من داخل كتلة متداخلة',
      titleEn: 'Mutating an outer var inside nested blocks (QUDS-090)',
      noteAr: 'المتغير المعرّف بـ var في نطاق خارجي يمكن تعديله من الكتل الداخلية مباشرة.',
      noteEn: 'An outer var binding is directly assignable from inner blocks.',
      code: '''var status = "waiting"
if 5 > 3:
  status = "approved"
print "الحالة: {status}"''',
    ),
  ],
  'const': [
    AcademyRuleExample(
      titleAr: 'ثوابت وقت الترجمة للحسابات',
      titleEn: 'Compile-time numeric constants',
      noteAr: 'تُستخدم const للقيم الثابتة المعروفة وقت الترجمة.',
      noteEn: 'const declares compile-time constants for fixed values.',
      code: '''const piApprox = 3.14159
const radius = 5.0
area = piApprox * radius * radius
print "مساحة الدائرة = {area.toStringAsFixed(2)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'ثوابت نصية وحدود نظام',
      titleEn: 'Constant labels and limits',
      noteAr: 'ثوابت واضحة تمنع الأرقام السحرية داخل المنطق.',
      noteEn: 'Named constants eliminate magic numbers in business logic.',
      code: '''const maxRetries = 3
const appName = "Quds Academy"
print "{appName} · الحد الأقصى للمحاولات = {maxRetries}"''',
    ),
  ],
  'shadow': [
    AcademyRuleExample(
      titleAr: 'حجب مقصود دون تعديل المتغير الخارجي',
      titleEn: 'Intentional shadowing preserving outer variable',
      noteAr:
          'shadow ينشئ متغيراً جديداً محلياً ولا يغيّر قيمة المتغير الخارجي.',
      noteEn: 'shadow creates a fresh inner binding without touching the outer one.',
      code: '''var count = 10
if true:
  shadow count = 99
  print "داخل الكتلة: count = {count}"
print "خارج الكتلة (لم تتغير): count = {count}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تغيير نوع الارتباط مؤقتاً عبر shadow',
      titleEn: 'Shadowing with a formatted representation',
      noteAr: 'يمكنك حجب قيمة رقمية بنص منسّق داخل النطاق المحلي بأمان.',
      noteEn: 'Shadow a numeric value with a formatted string inside a local block.',
      code: '''price = 45
if true:
  shadow price = "{price} USD"
  print "السعر المنسّق: {price}"
print "القيمة الأصلية: {price + 5}"''',
    ),
  ],
  'late': [
    AcademyRuleExample(
      titleAr: 'تهيئة مؤجلة لارتباط غير قابل لإعادة الإسناد',
      titleEn: 'Deferred initialization with late',
      noteAr: 'تؤجّل late إسناد القيمة لحين جاهزيتها قبل أول قراءة.',
      noteEn: 'late defers assignment until the value is computed before first read.',
      code: '''late greeting: String
user = "سارة"
greeting = "أهلاً يا {user}!"
print greeting''',
    ),
    AcademyRuleExample(
      titleAr: 'دمج late مع var لمتغير يُهيّأ لاحقاً ويتغير',
      titleEn: 'Combining late with var for mutable deferred binding',
      noteAr: 'late var يسمح بالتهيئة المتأخرة ثم إعادة الإسناد لاحقاً.',
      noteEn:
          'late var allows delayed initialization followed by reassignments.',
      code: '''late var stage: String
stage = "المرحلة 1"
print stage
stage = "المرحلة 2"
print stage''',
    ),
  ],
  'let': [
    AcademyRuleExample(
      titleAr: 'فك التغليف الآمن لقيمة قابلة لـ null داخل if let',
      titleEn: 'Safe unwrapping with if let',
      noteAr: 'يدخل الفرع فقط إذا كانت القيمة غير null ويربطها باسم مضمون.',
      noteEn:
          'Enters the branch only when non-null and binds the unwrapped value.',
      code: '''nickname: String? = "قدس"
if let name = nickname:
  print "مرحباً {name} (طول الاسم = {name.length})"
else:
  print "ضيف جديد"''',
    ),
    AcademyRuleExample(
      titleAr: 'تجاهل الفرع تلقائياً عند وجود null',
      titleEn: 'Fallback branch when nullable value is null',
      noteAr: 'عندما تكون القيمة null ينتقل التنفيذ مباشرة لفرع else.',
      noteEn: 'When the value is null, control flows cleanly into else.',
      code: '''token: String? = null
if let t = token:
  print "تم التحقق: {t}"
else:
  print "لا يوجد رمز — يرجى تسجيل الدخول"''',
    ),
  ],
  'lazy': [
    AcademyRuleExample(
      titleAr: 'حساب مؤجل عند أول قراءة فقط (by lazy)',
      titleEn: 'Lazy computation on first read',
      noteAr:
          'يُنفّذ جسم by lazy: مرة واحدة فقط عند أول قراءة ثم يُخزّن الناتج.',
      noteEn: 'by lazy: runs once on first access and caches its result.',
      code: '''class Report:
  summary: String by lazy:
    print "جاري حساب التقرير المكلف..."
    result "إجمالي السجلات: 100"

r = Report()
print "قبل القراءة"
print r.summary
print r.summary''',
    ),
    AcademyRuleExample(
      titleAr: 'حساب رياضي كسول داخل كلاس',
      titleEn: 'Lazy mathematical property inside a class',
      noteAr: 'لا تُحسب القيمة إلا إذا طُلبت فعلياً.',
      noteEn: 'Avoids computing derived values unless actually accessed.',
      code: '''class Circle:
  r: double required
  area: double by lazy:
    result 3.14159 * r * r

c = Circle(4.0)
print "المساحة = {c.area.toStringAsFixed(2)}"''',
    ),
  ],
  'by': [
    AcademyRuleExample(
      titleAr: 'تفويض التهيئة المؤجلة باستخدام by lazy',
      titleEn: 'Delegating deferred initialization with by lazy',
      noteAr: 'تبدأ by صيغة by lazy: لتهيئة خاصية ثابتة عند الطلب.',
      noteEn: 'by introduces by lazy: for on-demand immutable initialization.',
      code: '''class Config:
  endpoint: String by lazy:
    result "https://api.quds.dev/v1"

cfg = Config()
print "الرابط: {cfg.endpoint}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تهيئة كسولة تعتمد على حقول الكائن',
      titleEn: 'Lazy field derived from instance state',
      noteAr: 'يمكن لجسم by lazy: قراءة حقول الكائن الأخرى.',
      noteEn: 'by lazy: blocks can read other instance fields cleanly.',
      code: '''class Rectangle:
  w: int required
  h: int required
  perimeter: int by lazy:
    result 2 * (w + h)

box = Rectangle(7, 5)
print "المحيط = {box.perimeter}"''',
    ),
  ],

  // ── 2. Decisions & Loops (13) ────────────────────────────────────────────
  'if': [
    AcademyRuleExample(
      titleAr: 'تفرّع متعدد المستويات لتقييم الدرجات',
      titleEn: 'Multi-branch grade evaluation',
      noteAr: 'تقبل if شرطاً منطقياً صريحاً وتتبعها else if و else.',
      noteEn: 'if branches on explicit booleans with else if and else.',
      code: '''grade(score: int) -> String:
  if score >= 90:
    return "ممتاز"
  else if score >= 75:
    return "جيد جداً"
  else:
    return "بحاجة لمراجعة"

print "95 -> {grade(95)}"
print "80 -> {grade(80)}"
print "60 -> {grade(60)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تعبير if المضمّن وشرط if اللاحق',
      titleEn: 'Inline if expression & trailing statement guard',
      noteAr: 'يمكن كتابة if كتعبير يعيد قيمة أو كشرط لاحق لجملة واحدة.',
      noteEn: 'if works both as a value expression and as a trailing guard.',
      code: '''temp = 34
tag = "حار" if temp > 30 else "معتدل"
print "الطقس: {tag}"
print "تنبيه حرارة!" if temp >= 32''',
    ),
    AcademyRuleExample(
      titleAr: 'تصفية العناصر بـ if داخل القوائم',
      titleEn: 'Conditional elements inside list comprehensions',
      noteAr: 'يمكن استخدام if لبناء قوائم مفلترة بسطر واحد واضح.',
      noteEn: 'Filter list comprehensions cleanly with inline if.',
      code: '''evens = [x for x in 1..10 if x % 2 == 0]
print "الأعداد الزوجية: {evens}"''',
    ),
  ],
  'else': [
    AcademyRuleExample(
      titleAr: 'فرع else القياسي مع if',
      titleEn: 'Standard if/else fallback',
      noteAr: 'ينفّذ فرع else عندما يكون شرط if خاطئاً.',
      noteEn: 'else runs whenever the preceding if condition is false.',
      code: '''balance = 40
cost = 75
if balance >= cost:
  print "تم الشراء بنجاح"
else:
  print "الرصيد غير كافٍ (ينقصك {cost - balance})"''',
    ),
    AcademyRuleExample(
      titleAr: 'else بعد الحلقة (تعمل فقط إذا لم يحدث break)',
      titleEn: 'Loop else (runs only when loop finishes without break)',
      noteAr: 'ميزة قوية في قدس: else بعد for تعمل إذا انتهت الحلقة طبيعياً دون break.',
      noteEn: 'Loop else executes only if the loop completes without hitting break.',
      code: '''target = 99
for x in [10, 20, 30]:
  if x == target:
    print "تم إيجاد {target}"
    break
else:
  print "العنصر {target} غير موجود في القائمة"''',
    ),
  ],
  'for': [
    AcademyRuleExample(
      titleAr: 'التكرار على نطاق رقمي شامل وغير شامل',
      titleEn: 'Iterating inclusive (..) and exclusive (..<) ranges',
      noteAr: '1..5 يشمل 5، بينما 0..<5 يتوقف عند 4.',
      noteEn: '1..5 includes 5, whereas 0..<5 stops at 4.',
      code: '''var a = []
for i in 1..5:
  a.add(i)
var b = []
for i in 0..<5:
  b.add(i)
print "شامل 1..5 = {a}"
print "غير شامل 0..<5 = {b}"''',
    ),
    AcademyRuleExample(
      titleAr: 'التكرار على قائمة وبناء قائمة جديدة',
      titleEn: 'Iterating collections & list comprehension',
      noteAr:
          'تعمل for على أي قائمة ويمكن استخدامها داخل [] لبناء قوائم مشتقة.',
      noteEn: 'for iterates any list and powers concise list comprehensions.',
      code: '''names = ["قدس", "يافا", "حيفا"]
for city in names:
  print "مدينة: {city}"
lengths = [c.length for c in names]
print "أطوال الأسماء: {lengths}"''',
    ),
    AcademyRuleExample(
      titleAr: 'حلقة for بخطوة مخصّصة (step)',
      titleEn: 'C-style for loop with while & step',
      noteAr: 'تدعم قدس حلقة for بمهيئ وشرط while وخطوة step.',
      noteEn: 'Quds supports initializer/while/step for loops cleanly.',
      code: '''var nums = []
for var i = 0 while i <= 10 step i += 2:
  nums.add(i)
print "قفزات بمقدار 2: {nums}"''',
    ),
  ],
  'in': [
    AcademyRuleExample(
      titleAr: 'فحص الانتماء داخل قائمة ونص',
      titleEn: 'Membership test in lists and strings',
      noteAr: 'تتحقق in من وجود عنصر داخل مجموعة أو سلسلة نصية.',
      noteEn: 'in tests membership in lists, sets, maps, and strings.',
      code: '''langs = ["Quds", "Dart", "Rust"]
print "Quds موجودة؟ {"Quds" in langs}"
print "Python موجودة؟ {"Python" in langs}"
print "كلمة قدس في الجملة؟ {"قدس" in "لغة قدس البرمجية"}"''',
    ),
    AcademyRuleExample(
      titleAr: 'ربط متغير التكرار بالمجموعة في for .. in',
      titleEn: 'Binding loop elements with for .. in',
      noteAr: 'تفصل in اسم العنصر عن المجموعة أو النطاق المراد التكرار عليه.',
      noteEn: 'in connects each loop variable to its source iterable.',
      code: '''var prod = 1
for k in [2, 3, 5]:
  prod *= k
print "حاصل الضرب = {prod}"''',
    ),
  ],
  'while': [
    AcademyRuleExample(
      titleAr: 'حلقة while لحساب خوارزمية إقليدس (GCD)',
      titleEn: 'While loop computing Euclidean GCD',
      noteAr: 'تستمر while بالتكرار ما دام الشرط المنطقي صحيحاً.',
      noteEn: 'while repeats as long as its boolean condition holds.',
      code: '''var a = 48
var b = 18
while b != 0:
  rem = a % b
  a = b
  b = rem
print "القاسم المشترك الأكبر = {a}"''',
    ),
    AcademyRuleExample(
      titleAr: 'العدّ التنازلي مع while',
      titleEn: 'Countdown loop with while',
      noteAr: 'مثال واضح لإنقاص عدّاد حتى يصل للصفر.',
      noteEn: 'Simple countdown stopping when the counter hits zero.',
      code: '''var n = 4
while n > 0:
  print "تبقّى {n}..."
  n -= 1
print "انطلاق!"''',
    ),
  ],
  'repeat': [
    AcademyRuleExample(
      titleAr: 'تكرار ثابت العدد باستخدام repeat N:',
      titleEn: 'Fixed-count repetition with repeat N:',
      noteAr: 'تُكرّر repeat الكتلة عدداً محدداً من المرات دون الحاجة لمتغير عدّاد.',
      noteEn:
          'repeat runs a block a fixed number of times with zero boilerplate.',
      code: '''var stars = ""
repeat 5:
  stars = "{stars}★"
print "التقييم: {stars}"''',
    ),
    AcademyRuleExample(
      titleAr: 'مضاعفة قيمة باستخدام repeat',
      titleEn: 'Repeated doubling with repeat',
      noteAr: 'حساب 2^6 بسطرين واضحين.',
      noteEn: 'Compute 2^6 cleanly in two lines.',
      code: '''var v = 1
repeat 6:
  v *= 2
print "2^6 = {v}"''',
    ),
  ],
  'step': [
    AcademyRuleExample(
      titleAr: 'خطوة تصاعدية في حلقة for .. while .. step',
      titleEn: 'Ascending stride with step',
      noteAr: 'تحدّد step مقدار التحديث بعد كل دورة في حلقة for.',
      noteEn: 'step specifies the update executed after each iteration.',
      code: '''var out = []
for var i = 5 while i <= 25 step i += 5:
  out.add(i)
print "مضاعفات 5: {out}"''',
    ),
    AcademyRuleExample(
      titleAr: 'خطوة تنازلية للعدّ العكسي',
      titleEn: 'Descending countdown with step',
      noteAr: 'يمكن لـ step إنقاص العدّاد أو ضربه بأي تعبير تحديث.',
      noteEn: 'step can decrement or scale the loop variable arbitrarily.',
      code: '''var rev = []
for var i = 10 while i >= 2 step i -= 2:
  rev.add(i)
print "عدّ عكسي: {rev}"''',
    ),
  ],
  'break': [
    AcademyRuleExample(
      titleAr: 'إيقاف البحث فور العثور على الهدف',
      titleEn: 'Early loop exit with break',
      noteAr: 'تُخرج break فوراً من أقرب حلقة وتلغي تنفيذ else الخاصة بالحلقة.',
      noteEn: 'break immediately leaves the loop and suppresses loop else.',
      code: '''for x in [4, 7, 12, 15, 20]:
  if x > 10:
    print "أول عدد أكبر من 10 هو: {x}"
    break''',
    ),
    AcademyRuleExample(
      titleAr: 'break مع شرط لاحق (break if)',
      titleEn: 'Trailing conditional break',
      noteAr: 'صياغة قدس المختصرة: break if condition.',
      noteEn: 'Concise guarded break: break if condition.',
      code: '''var sum = 0
for n in 1..10:
  break if sum + n > 15
  sum += n
print "أقصى مجموع <= 15 هو: {sum}"''',
    ),
  ],
  'continue': [
    AcademyRuleExample(
      titleAr: 'تخطّي القيم غير المرغوبة بـ continue if',
      titleEn: 'Skipping unwanted items with continue if',
      noteAr: 'تنتقل continue للدورة التالية مباشرة دون إنهاء الحلقة.',
      noteEn: 'continue skips to the next iteration without exiting the loop.',
      code: '''var odds = []
for n in 1..9:
  continue if n % 2 == 0
  odds.add(n)
print "الأعداد الفردية: {odds}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تخطّي القيم السالبة عند حساب المجموع',
      titleEn: 'Ignoring negative entries while summing',
      noteAr: 'تجمع القيم الموجبة فقط وتتجاوز السالبة.',
      noteEn: 'Accumulates only non-negative numbers.',
      code: '''var total = 0
for v in [10, -5, 20, -3, 15]:
  if v < 0:
    continue
  total += v
print "مجموع الموجب فقط = {total}"''',
    ),
  ],
  'label': [
    AcademyRuleExample(
      titleAr: 'الخروج من حلقتين متداخلتين باستخدام label و break',
      titleEn: 'Breaking out of nested loops with label',
      noteAr:
          'يسمّي label الحلقة الخارجية لإمكانية كسرها من داخل الحلقة الداخلية.',
      noteEn:
          'label names an outer loop so break can exit both levels at once.',
      code: '''var found = "غير موجود"
label outer
for r in 1..3:
  for c in 1..3:
    if r * c == 6:
      found = "الصف {r}، العمود {c}"
      break outer
print "النتيجة: {found}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تخطّي صف كامل باستخدام continue outer',
      titleEn: 'Continuing outer loop with label',
      noteAr: 'يمكن استخدام الوسم مع continue للقفز مباشرة إلى الدورة الخارجية التالية.',
      noteEn:
          'continue with a label jumps directly to the next outer iteration.',
      code: '''var kept = []
label rows
for r in 1..3:
  for c in 1..3:
    if r == 2:
      continue rows
    kept.add("{r}-{c}")
print "العناصر المقبولة: {kept}"''',
    ),
  ],
  'return': [
    AcademyRuleExample(
      titleAr: 'إرجاع صريح متعدد المسارات من الدوال',
      titleEn: 'Explicit multi-path return in multiline functions',
      noteAr: 'تشترط قدس return صريحاً في الدوال متعددة الأسطر (QUDS-032).',
      noteEn: 'Multiline functions use explicit return statements (QUDS-032).',
      code: '''classify(n: int) -> String:
  if n < 0:
    return "سالب"
  if n == 0:
    return "صفر"
  return "موجب"

print "-3 -> {classify(-3)}, 0 -> {classify(0)}, 7 -> {classify(7)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'دالة عودية لحساب المضروب باستخدام return',
      titleEn: 'Recursive factorial with return',
      noteAr: 'إرجاع مبكر لحالة الأساس ثم استدعاء عودي.',
      noteEn: 'Early base-case return followed by recursive step.',
      code: '''fact(n: int) -> int:
  if n <= 1:
    return 1
  return n * fact(n - 1)

print "5! = {fact(5)}"
print "7! = {fact(7)}"''',
    ),
  ],
  'do': [
    AcademyRuleExample(
      titleAr: 'كتلة تعبيرية تحسب قيمة عبر do / result',
      titleEn: 'Block expression returning a value with do/result',
      noteAr: 'تسمح do بكتابة خطوات محلية لإنتاج قيمة واحدة نظيفة دون تلويث النطاق الخارجي.',
      noteEn: 'do scopes intermediate calculations and yields one value via result.',
      code: '''discount = do:
  base = 200
  rate = 0.15
  result base * rate

print "قيمة الخصم = {discount}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تعبير do متشعّب الشروط',
      titleEn: 'Branching inside a do block expression',
      noteAr: 'كل مسار داخل do يمكنه إنهاء التعبير بـ result.',
      noteEn: 'Any branch inside do can yield the block value with result.',
      code: '''tier = do:
  points = 1250
  if points >= 1000:
    result "ذهبي"
  result "فضي"

print "المستوى: {tier}"''',
    ),
  ],
  'result': [
    AcademyRuleExample(
      titleAr: 'تزويد قيمة كتلة do عبر result',
      titleEn: 'Yielding value from do expression with result',
      noteAr: 'تنهي result أقرب كتلة do فقط ولا تخرج من الدالة المحيطة.',
      noteEn:
          'result exits only the nearest do block, not the enclosing function.',
      code: '''compute() -> int:
  part = do:
    a = 6
    b = 7
    result a * b
  return part + 10

print "الناتج = {compute()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام result داخل خاصية by lazy',
      titleEn: 'Using result inside by lazy initializer',
      noteAr: 'تُستخدم result لإرجاع القيمة المحسوبة في كتلة by lazy:.',
      noteEn: 'by lazy: blocks produce their cached value via result.',
      code: '''class Palette:
  hex: String by lazy:
    result "#147D64"

p = Palette()
print "اللون الأساسي: {p.hex}"''',
    ),
  ],

  // ── 3. Values & Operators (9) ────────────────────────────────────────────
  'and': [
    AcademyRuleExample(
      titleAr: 'دمج شرطين منطقيين باستخدام and',
      titleEn: 'Logical conjunction with and',
      noteAr: 'تعيد and القيمة true فقط إذا تحقق الشرطان معاً.',
      noteEn: 'and returns true only when both boolean conditions hold.',
      code: '''age = 22
hasTicket = true
canEnter = age >= 18 and hasTicket
print "مسموح بالدخول؟ {canEnter}"''',
    ),
    AcademyRuleExample(
      titleAr: 'التقييم المختصر (Short-circuit) في and',
      titleEn: 'Short-circuit evaluation in and',
      noteAr: 'إذا كان الطرف الأيسر false لا يُقيّم الطرف الأيمن أصلاً.',
      noteEn:
          'If the left operand is false, the right operand is never evaluated.',
      code: '''checkRight() -> bool:
  print "تم تقييم الطرف الأيمن!"
  return true

res = false and checkRight()
print "النتيجة = {res} (لم يُستدعَ الطرف الأيمن)"''',
    ),
  ],
  'or': [
    AcademyRuleExample(
      titleAr: 'تحقق بديل واحد على الأقل بـ or',
      titleEn: 'Logical disjunction with or',
      noteAr: 'تعيد or القيمة true إذا تحقق أحد الشرطين على الأقل.',
      noteEn: 'or returns true when at least one operand is true.',
      code: '''isAdmin = false
isOwner = true
print "له صلاحية التعديل؟ {isAdmin or isOwner}"''',
    ),
    AcademyRuleExample(
      titleAr: 'التقييم المختصر في or',
      titleEn: 'Short-circuit evaluation in or',
      noteAr: 'عندما يكون الطرف الأيسر true يتوقف التقييم فوراً.',
      noteEn: 'When the left operand is true, the right side is skipped.',
      code: '''fallback() -> bool:
  print "لن يُنفّذ هذا السطر"
  return false

print "النتيجة = {true or fallback()}"''',
    ),
  ],
  'not': [
    AcademyRuleExample(
      titleAr: 'نفي قيمة منطقية بـ not',
      titleEn: 'Boolean negation with not',
      noteAr: 'تعكس not القيمة المنطقية بين true و false.',
      noteEn: 'not inverts a boolean between true and false.',
      code: '''isLocked = false
if not isLocked:
  print "الباب مفتوح ✓"''',
    ),
    AcademyRuleExample(
      titleAr: 'اختبار عدم الانتماء بـ not in',
      titleEn: 'Non-membership test with not in',
      noteAr: 'صياغة مقروءة لفحص غياب عنصر من مجموعة.',
      noteEn: 'Readable check for absence from a collection.',
      code: '''banned = ["spam", "bot"]
user = "ali"
print "المستخدم آمن؟ {user not in banned}"''',
    ),
  ],
  'true': [
    AcademyRuleExample(
      titleAr: 'القيمة المنطقية true في الشروط',
      titleEn: 'Boolean literal true in control flow',
      noteAr: 'true هي القيمة المنطقية الصحيحة في لغة قدس.',
      noteEn: 'true is the positive boolean literal in Quds.',
      code: '''isReady = true
print "جاهز = {isReady}"
if isReady:
  print "بدء التشغيل الآن!"''',
    ),
    AcademyRuleExample(
      titleAr: 'تخزين قيم true في قائمة وإحصاؤها',
      titleEn: 'Counting true flags in a list',
      noteAr: 'عدّ العناصر المتحققة داخل قائمة حالات.',
      noteEn: 'Count passing boolean checks in a list.',
      code: '''checks = [true, false, true, true]
var passed = 0
for ok in checks:
  if ok:
    passed += 1
print "نجح {passed} من {checks.length} اختبارات"''',
    ),
  ],
  'false': [
    AcademyRuleExample(
      titleAr: 'تبديل حالة منطقية تبدأ بـ false',
      titleEn: 'Toggling a boolean state starting at false',
      noteAr: 'false تمثّل الحالة غير المتحققة أو المطفأة.',
      noteEn: 'false represents an inactive or failing boolean state.',
      code: '''var darkMode = false
print "قبل التبديل: {darkMode}"
darkMode = not darkMode
print "بعد التبديل: {darkMode}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام false كراية بحث',
      titleEn: 'Using false as a search sentinel flag',
      noteAr: 'تحديد ما إذا وُجد عنصر مطابق أثناء التكرار.',
      noteEn: 'Track whether a matching item was discovered.',
      code: '''var hasZero = false
for n in [3, 5, 0, 8]:
  if n == 0:
    hasZero = true
print "هل يوجد صفر؟ {hasZero}"''',
    ),
  ],
  'null': [
    AcademyRuleExample(
      titleAr: 'قيمة null مع معامل البديل ??',
      titleEn: 'Null value with fallback operator ??',
      noteAr: 'تعني null غياب القيمة، وتوفّر ?? قيمة افتراضية آمنة.',
      noteEn: 'null represents absence, and ?? supplies a safe default.',
      code: '''bio: String? = null
display = bio ?? "لا توجد نبذة شخصية بعد"
print display''',
    ),
    AcademyRuleExample(
      titleAr: 'الوصول الآمن ?. مع القيم القابلة لـ null',
      titleEn: 'Null-safe member access with ?.',
      noteAr: 'يعيد ?. القيمة null دون خطأ عندما يكون الكائن فارغاً.',
      noteEn: '?. safely evaluates to null when the receiver is null.',
      code: '''var title: String? = null
print "الطول قبل التعيين: {title?.length ?? 0}"
title = "أكاديمية قدس"
print "الطول بعد التعيين: {title?.length ?? 0}"''',
    ),
  ],
  'is': [
    AcademyRuleExample(
      titleAr: 'فحص نوع القيمة وقت التشغيل بـ is و is!',
      titleEn: 'Runtime type testing with is and is!',
      noteAr: 'تختبر is توافق القيمة مع نوع محدد، وتنفيها is!.',
      noteEn: 'is tests runtime type compatibility; is! negates it.',
      code: '''items: List<Object> = [42, "قدس", 3.5]
for item in items:
  if item is int:
    print "عدد صحيح: {item}"
  else if item is String:
    print "نص: {item}"
  else if not (item is bool):
    print "نوع آخر: {item}"''',
    ),
    AcademyRuleExample(
      titleAr: 'فحص نوع كائنات الكلاسات الفرعية',
      titleEn: 'Testing subclass instances with is',
      noteAr: 'تعمل is مع تسلسل الوراثة والكلاسات بدقة.',
      noteEn: 'is respects class inheritance hierarchies.',
      code: '''class Animal:
  name: String required
class Cat extends Animal:
  init(super.name: String):
    pass = 0

pet: Animal = Cat("لولو")
print "هل هو Cat؟ {pet is Cat}"
print "هل هو Animal؟ {pet is Animal}"''',
    ),
  ],
  'as': [
    AcademyRuleExample(
      titleAr: 'تسمية بادئة مكتبة باستخدام use .. as',
      titleEn: 'Aliasing an imported library with as',
      noteAr: 'تُستخدم as لإعطاء بادئة واضحة للمكتبة المستوردة.',
      noteEn: 'as gives imported modules a clean prefix namespace.',
      code: '''use quds:math as m
print "sqrt(81) = {m.sqrt(81.0)}"
print "gcd(36, 24) = {m.gcd(36, 24)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحويل مرجعي صريح (Cast) باستخدام as',
      titleEn: 'Type assertion cast with as',
      noteAr: 'تفحص as أن القيمة من النوع المطلوب دون استدعاء تحويل قيمي.',
      noteEn: 'as asserts the runtime type without running a value conversion.',
      code: '''raw: Object = "مرحباً من قدس"
text = raw as String
print "النص: {text} (الطول = {text.length})"''',
    ),
  ],
  'nameof': [
    AcademyRuleExample(
      titleAr: 'استخراج اسم المتغير من الشيفرة بـ nameof',
      titleEn: 'Source-level identifier name with nameof',
      noteAr:
          'تعيد nameof اسم المعرّف كنص ثابت مفيد للتسجيل والرسائل التشخيصية.',
      noteEn: 'nameof yields the identifier name as a string for diagnostics/logging.',
      code: '''totalScore = 98
print "{nameof totalScore} = {totalScore}"''',
    ),
    AcademyRuleExample(
      titleAr: 'توليد رسائل تحقق واضحة باستخدام nameof',
      titleEn: 'Building validation messages with nameof',
      noteAr: 'تضمن nameof بقاء اسم الحقل متزامناً مع الشيفرة.',
      noteEn: 'nameof keeps field names in sync with source code.',
      code: '''userAge = 16
if userAge < 18:
  print "الحقل [{nameof userAge}] يجب أن يكون >= 18 (الحالي: {userAge})"''',
    ),
  ],

  // ── 4. Types & Composition (19) ──────────────────────────────────────────
  'class': [
    AcademyRuleExample(
      titleAr: 'تعريف كلاس بحقول مطلوبة ودوال سلوك',
      titleEn: 'Class with required fields and methods',
      noteAr: 'يولّد الكلاس بانياً تلقائياً من حقوله ويمكن إضافة دوال بداخله.',
      noteEn: 'Classes synthesize constructors from fields and group behavior.',
      code: '''class Student:
  name: String required
  grade: int required
  describe() -> String = "{name} — الدرجة: {grade}"

s = Student("أحمد", 95)
print s.describe()''',
    ),
    AcademyRuleExample(
      titleAr: 'كلاس بحالة قابلة للتعديل (var)',
      titleEn: 'Stateful class with mutable var field',
      noteAr: 'استخدم var داخل الكلاس للحقول التي تتحدث عبر الدوال.',
      noteEn: 'Use var fields inside a class for mutable object state.',
      code: '''class Counter:
  var value: int = 0
  inc():
    value += 1
  add(n: int):
    value += n

c = Counter()
c.inc()
c.add(4)
print "العدّاد = {c.value}"''',
    ),
  ],
  'abstract': [
    AcademyRuleExample(
      titleAr: 'كلاس مجرد يحدد عقد الأشكال الهندسية',
      titleEn: 'Abstract base class defining a shape contract',
      noteAr: 'الكلاس abstract لا يُنشأ مباشرةً وتنفّذ الكلاسات الفرعية سلوكه.',
      noteEn: 'abstract classes cannot be instantiated directly; subclasses implement them.',
      code: '''abstract class Shape:
  name: String required
  area() -> double:
    return 0.0

class Square extends Shape:
  side: double required
  init(super.name: String, this.side: double):
    ok = true
  area() -> double = side * side

sq = Square("مربع", 6.0)
print "{sq.name}: المساحة = {sq.area()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تعدد الأشكال عبر قائمة من كلاس مجرد',
      titleEn: 'Polymorphism over an abstract base class',
      noteAr: 'توحّد الكلاسات المجردة التعامل مع أنواع متعددة بواجهة واحدة.',
      noteEn: 'Abstract classes unify heterogeneous subclasses cleanly.',
      code: '''abstract class Greeter:
  hello() -> String = ""

class ArabicGreeter extends Greeter:
  hello() -> String = "السلام عليكم!"

class EnglishGreeter extends Greeter:
  hello() -> String = "Hello!"

for g in [ArabicGreeter(), EnglishGreeter()]:
  print g.hello()''',
    ),
  ],
  'base': [
    AcademyRuleExample(
      titleAr: 'كلاس base للوراثة المنضبطة',
      titleEn: 'Base class inheritance hierarchy',
      noteAr: 'يفرض معدّل base الوراثة المنضبطة المتوافقة مع Dart.',
      noteEn: 'base enforces Dart-compatible subclassing guarantees.',
      code: '''base class Entity:
  id: int required

base class Record extends Entity:
  title: String required
  init(super.id: int, this.title: String):
    ok = true

r = Record(101, "سجل أساسي")
print "#{r.id}: {r.title}"''',
    ),
    AcademyRuleExample(
      titleAr: 'مشاركة دالة مساعدة في كلاس base',
      titleEn: 'Shared helper behavior in a base class',
      noteAr: 'ترث الكلاسات الفرعية الدوال المشتركة من الكلاس base.',
      noteEn: 'Subclasses inherit reusable methods from a base class.',
      code: '''base class Model:
  tag() -> String = "QudsModel"

base class UserModel extends Model:
  name: String required

u = UserModel("منى")
print "{u.tag()} -> {u.name}"''',
    ),
  ],
  'interface': [
    AcademyRuleExample(
      titleAr: 'تعريف واجهة وتنفيذها في كلاس',
      titleEn: 'Declaring and implementing an interface',
      noteAr:
          'تصف interface الالتزامات التي يجب على الكلاسات المنفّذة تقديمها.',
      noteEn: 'interface defines a contract satisfied by implementing classes.',
      code: '''interface Printable:
  label() -> String = ""

class Invoice implements Printable:
  number: int required
  label() -> String = "فاتورة رقم #{number}"

inv = Invoice(2026)
print inv.label()''',
    ),
    AcademyRuleExample(
      titleAr: 'كلاسان مختلفان ينفّذان الواجهة نفسها',
      titleEn: 'Multiple classes implementing the same interface',
      noteAr: 'تتيح الواجهات تبديل التنفيذ بمرونة عالية.',
      noteEn: 'Interfaces enable interchangeable implementations.',
      code: '''interface Formatter:
  format(s: String) -> String = s

class UpperFmt implements Formatter:
  format(s: String) -> String = s.toUpperCase()

class BracketFmt implements Formatter:
  format(s: String) -> String = "[{s}]"

print UpperFmt().format("quds")
print BracketFmt().format("quds")''',
    ),
  ],
  'final': [
    AcademyRuleExample(
      titleAr: 'كلاس final مغلق أمام التوريث الخارجي',
      titleEn: 'Final class preventing external subclassing',
      noteAr:
          'final هو معدّل للكلاسات فقط؛ الارتباطات الثابتة تُكتب name = value.',
      noteEn:
          'final is a class modifier; immutable locals use plain name = value.',
      code: '''final class Token:
  kind: String required
  lexeme: String required
  show() -> String = "<{kind}: {lexeme}>"

t = Token("KEYWORD", "match")
print t.show()''',
    ),
    AcademyRuleExample(
      titleAr: 'كلاس final لحمل نتيجة ثابتة',
      titleEn: 'Final result carrier class',
      noteAr: 'مناسب لأنواع البيانات الأساسية التي لا يُراد توسيعها.',
      noteEn: 'Ideal for closed core data types.',
      code: '''final class Version:
  major: int required
  minor: int required
  text() -> String = "v{major}.{minor}"

v = Version(1, 2)
print "إصدار قدس: {v.text()}"''',
    ),
  ],
  'sealed': [
    AcademyRuleExample(
      titleAr: 'نوع sealed type مع مطابقة match الشاملة',
      titleEn: 'Sealed type hierarchy with match',
      noteAr: 'يغلق sealed قائمة الحالات الممكنة لتمكين مطابقة شاملة وآمنة.',
      noteEn: 'sealed closes the set of cases for exhaustive pattern matching.',
      code: '''sealed type Status:
  Loading
  Ready
  Failed

describe(s: Status) -> String:
  return match s:
    Loading: "جاري التحميل..."
    Ready: "جاهز للعمل ✓"
    Failed: "حدث خطأ ✗"

print describe(Status.Loading)
print describe(Status.Ready)''',
    ),
    AcademyRuleExample(
      titleAr: 'sealed class لكلاسات حالات محددة',
      titleEn: 'Sealed class hierarchy for domain results',
      noteAr: 'يمكن استخدام sealed مع class لتمثيل نتائج عمليات مختلفة.',
      noteEn: 'sealed class models closed algebraic hierarchies cleanly.',
      code: '''sealed class Outcome:
  label() -> String = ""

class Ok extends Outcome:
  value: int required
  label() -> String = "نجاح: {value}"

class Err extends Outcome:
  msg: String required
  label() -> String = "فشل: {msg}"

print Ok(42).label()
print Err("غير موجود").label()''',
    ),
  ],
  'value': [
    AcademyRuleExample(
      titleAr: 'مساواة تلقائية بالقيمة في value class',
      titleEn: 'Automatic value-based equality',
      noteAr:
          'يولّد value class المساواة == و hashCode تلقائياً بناءً على الحقول.',
      noteEn: 'value class generates field-based equality and hashCode.',
      code: '''value class Point:
  x: int required
  y: int required

a = Point(3, 4)
b = Point(3, 4)
c = Point(5, 4)
print "a == b ? {a == b}"
print "a == c ? {a == c}"''',
    ),
    AcademyRuleExample(
      titleAr: 'إنشاء نسخة معدّلة باستخدام copyWith التلقائية',
      titleEn: 'Immutable updates via synthesized copyWith',
      noteAr:
          'توفّر value class دالة copyWith لإنشاء نسخة جديدة دون تعديل الأصل.',
      noteEn: 'value class synthesizes copyWith for clean immutable updates.',
      code: '''value class Book:
  title: String required
  pages: int required

b1 = Book("لغة قدس", 120)
b2 = b1.copyWith(pages: 200)
print "الأصل: {b1.title} ({b1.pages})"
print "النسخة: {b2.title} ({b2.pages})"''',
    ),
  ],
  'singleton': [
    AcademyRuleExample(
      titleAr: 'نسخة وحيدة مشتركة باستخدام singleton class',
      titleEn: 'Single shared instance via singleton class',
      noteAr:
          'يضمن singleton وجود نسخة واحدة كسولة (instance) على مستوى التطبيق.',
      noteEn: 'singleton provides one lazily-created shared instance.',
      code: '''singleton class AppConfig:
  var theme: String = "light"
  var lang: String = "ar"

AppConfig.instance.theme = "dark"
print "المظهر: {AppConfig.instance.theme}"
print "اللغة: {AppConfig.instance.lang}"''',
    ),
    AcademyRuleExample(
      titleAr: 'سجل أحداث مركزي بـ singleton',
      titleEn: 'Central logger service with singleton',
      noteAr: 'مناسب للخدمات المشتركة كالتسجيل والإعدادات.',
      noteEn: 'Great for shared services like registries and counters.',
      code: '''singleton class IdGen:
  var nextId: int = 100
  next() -> int:
    current = nextId
    nextId += 1
    return current

print "ID 1 = {IdGen.instance.next()}"
print "ID 2 = {IdGen.instance.next()}"''',
    ),
  ],
  'extends': [
    AcademyRuleExample(
      titleAr: 'وراثة الحقول والدوال باستخدام extends',
      titleEn: 'Inheriting fields and methods with extends',
      noteAr: 'يسمح extends للكلاس الفرعي بوراثة وتوسيع الكلاس الأب.',
      noteEn: 'extends lets a subclass inherit and specialize a parent class.',
      code: '''class Vehicle:
  brand: String required
  info() -> String = "مركبة: {brand}"

class ElectricCar extends Vehicle:
  rangeKm: int required
  init(super.brand: String, this.rangeKm: int):
    ok = true
  details() -> String = "{info()} · المدى {rangeKm} كم"

car = ElectricCar("QudsEV", 520)
print car.details()''',
    ),
    AcademyRuleExample(
      titleAr: 'إعادة تعريف دالة موروثة (Override)',
      titleEn: 'Overriding an inherited method',
      noteAr: 'يمكن للكلاس الفرعي تخصيص تنفيذ دالة الكلاس الأب.',
      noteEn: 'Subclasses can specialize inherited methods.',
      code: '''class Notifier:
  send(msg: String) -> String = "إشعار: {msg}"

class UrgentNotifier extends Notifier:
  send(msg: String) -> String = "🚨 عاجل: {msg}"

print Notifier().send("تحديث جديد")
print UrgentNotifier().send("البطارية منخفضة")''',
    ),
  ],
  'implements': [
    AcademyRuleExample(
      titleAr: 'تحقيق عقد واجهة عبر implements',
      titleEn: 'Satisfying an interface contract with implements',
      noteAr: 'يلزم implements الكلاس بتوفير كافة أعضاء الواجهة المتوافقة.',
      noteEn: 'implements obligates the class to provide compatible members.',
      code: '''interface AreaCalculable:
  area() -> double = 0.0

class Rect implements AreaCalculable:
  w: double required
  h: double required
  area() -> double = w * h

r = Rect(5.0, 3.0)
print "مساحة المستطيل = {r.area()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تطبيق أكثر من كلاس لواجهة موحدة',
      titleEn: 'Uniform scoring across implementing classes',
      noteAr: 'تسمح implements بمعالجة أنواع مختلفة عبر الدالة نفسها.',
      noteEn: 'Allows uniform processing across diverse implementing types.',
      code: '''interface Priced:
  price() -> int = 0

class Course implements Priced:
  fee: int required
  price() -> int = fee

class BookItem implements Priced:
  cost: int required
  price() -> int = cost

var total = 0
for x in [Course(100), BookItem(35)]:
  total += x.price()
print "الإجمالي = {total}"''',
    ),
  ],
  'mixin': [
    AcademyRuleExample(
      titleAr: 'إعادة استخدام السلوك عبر mixin و with',
      titleEn: 'Reusable behavior with mixin and with',
      noteAr: 'يضيف mixin دوال جاهزة لأي كلاس دون وراثة أحادية مقيدة.',
      noteEn: 'mixin shares behavior cleanly across unrelated classes.',
      code: '''mixin Timestamped:
  stamp(msg: String) -> String = "[LOG] {msg}"

class Service with Timestamped:
  name: String required

svc = Service("Auth")
print svc.stamp("{svc.name} جاهز")''',
    ),
    AcademyRuleExample(
      titleAr: 'دمج أكثر من mixin في كلاس واحد',
      titleEn: 'Composing multiple mixins into one class',
      noteAr: 'يمكن للكلاس دمج عدة مزائج بوضوح.',
      noteEn: 'A class can compose multiple focused mixins.',
      code: '''mixin Swimmer:
  swim() -> String = "يسبح"
mixin Flyer:
  fly() -> String = "يطير"

class Duck with Swimmer, Flyer:
  name: String required

d = Duck("بطة")
print "{d.name}: {d.swim()} و {d.fly()}"''',
    ),
  ],
  'on': [
    AcademyRuleExample(
      titleAr: 'تقييد mixin بكلاس أساس عبر on',
      titleEn: 'Constraining a mixin receiver with on',
      noteAr: 'يضمن on أن الـ mixin يُطبّق فقط على كلاسات ترث نوعاً محدداً.',
      noteEn:
          'on constrains a mixin so it can safely access superclass members.',
      code: '''class Named:
  name: String required

mixin Loud on Named:
  shout() -> String = "{name.toUpperCase()}!"

class Hero extends Named with Loud:
  init(super.name: String):
    ok = true

h = Hero("quds")
print h.shout()''',
    ),
    AcademyRuleExample(
      titleAr: 'mixin مقيّد بـ on لقراءة معرف الكيان',
      titleEn: 'Mixin accessing constrained id field',
      noteAr: 'يتيح on الوصول المباشر لحقول الكلاس المحدّد.',
      noteEn:
          'on grants direct access to fields declared on the required base.',
      code: '''class Item:
  id: int required

mixin Tagged on Item:
  tag() -> String = "ITEM-{id}"

class Product extends Item with Tagged:
  init(super.id: int):
    ok = true

print Product(77).tag()''',
    ),
  ],
  'enum': [
    AcademyRuleExample(
      titleAr: 'تعريف تعداد enum ومطابقته مع match',
      titleEn: 'Defining an enum and matching cases',
      noteAr: 'يحدّد enum مجموعة ثابتة واضحة من القيم المسمّاة.',
      noteEn: 'enum declares a fixed set of named constant values.',
      code: '''enum Traffic:
  red
  yellow
  green

action(t: Traffic) -> String:
  return match t:
    Traffic.red: "توقّف 🛑"
    Traffic.yellow: "استعد ⚠️"
    Traffic.green: "انطلق 🟢"

print action(Traffic.red)
print action(Traffic.green)''',
    ),
    AcademyRuleExample(
      titleAr: 'التكرار على جميع قيم التعداد (values)',
      titleEn: 'Iterating over enum values',
      noteAr: 'توفّر التعدادات قائمة values والاسم name لكل حالة.',
      noteEn: 'Enums expose values and each case name cleanly.',
      code: '''enum Day:
  sat
  sun
  mon

for d in Day.values:
  print "يوم: {d.name}"''',
    ),
  ],
  'type': [
    AcademyRuleExample(
      titleAr: 'اسم نوع بديل شفاف (type Alias = ...)',
      titleEn: 'Transparent type alias',
      noteAr: 'يجعل type Alias التوقيعات أسهل قراءةً وأكثر تعبيراً.',
      noteEn: 'type aliases make complex signatures readable and expressive.',
      code: '''type Scores = List<int>

avg(xs: Scores) -> double:
  var s = 0
  for x in xs:
    s += x
  return s / xs.length

data: Scores = [80, 90, 100]
print "المتوسط = {avg(data)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'نوع مميّز مغلّف باستخدام type .. wraps',
      titleEn: 'Distinct wrapped type with type .. wraps',
      noteAr: 'يمنع الخلط بين القيم المتشابهة التمثيل كالأمتار والثواني.',
      noteEn:
          'Prevents accidentally mixing identically represented quantities.',
      code: '''type Meter wraps double:
  toCm() -> double = value * 100.0

d = Meter(2.5)
print "{d.value} م = {d.toCm()} سم"''',
    ),
  ],
  'wraps': [
    AcademyRuleExample(
      titleAr: 'تغليف قيمة موجبة مع شرط require',
      titleEn: 'Wrapped type enforcing positive invariant',
      noteAr:
          'تعرّف wraps التمثيل الداخلي باسم value ويمكن فرض شروط require عليه.',
      noteEn: 'wraps exposes the underlying value and supports require checks.',
      code: '''type Positive wraps int:
  require value > 0
  doubled() -> int = value * 2

p = Positive(12)
print "القيمة = {p.value}، ضعفها = {p.doubled()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تغليف بريد إلكتروني مع دالة مساعدة',
      titleEn: 'Wrapped Email type with helper method',
      noteAr: 'إضافة سلوك مجالي فوق String دون تكلفة كائن إضافي.',
      noteEn: 'Adds domain behavior around String cleanly.',
      code: '''type Email wraps String:
  isValid() -> bool = "@" in value

e = Email("student@quds.dev")
print "{e.value} صالح؟ {e.isValid()}"''',
    ),
  ],
  'out': [
    AcademyRuleExample(
      titleAr: 'تباين الإخراج (out T) في الواجهات العامة',
      titleEn: 'Covariant output type parameter (out T)',
      noteAr: 'يسمح out T بإنتاج قيم من النوع T بأمان في مواضع الإخراج.',
      noteEn:
          'out T declares covariant output positions for generic producers.',
      code: '''interface Producer<out T>:
  produce() -> T:
    throw "abstract"

class IntProducer implements Producer<int>:
  produce() -> int = 2026

p = IntProducer()
print "القيمة المنتَجة = {p.produce()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'صندوق قراءة فقط متباين الإخراج',
      titleEn: 'Read-only covariant box',
      noteAr: 'مفيد للواجهات التي تقرأ القيم فقط دون استهلاكها.',
      noteEn: 'Useful for read-only generic containers.',
      code: '''class ReadBox<out T>:
  item: T required
  read() -> T = item

b = ReadBox<String>("لغة قدس")
print "المحتوى: {b.read()}"''',
    ),
  ],
  'where': [
    AcademyRuleExample(
      titleAr: 'تعريف أسماء محلية لتعبير عبر where',
      titleEn: 'Expression-local bindings with where',
      noteAr: 'تُقيّم ارتباطات where من اليسار لليمين قبل التعبير الرئيسي.',
      noteEn: 'where evaluates immutable local bindings left-to-right for one expression.',
      code: '''avg = total / count where total = 96, count = 4
print "المعدل = {avg}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تبسيط المعادلات الرياضية باستخدام where',
      titleEn: 'Clean math formulas using where',
      noteAr: 'تكتب المعادلة الرئيسية أولاً ثم تعرّف متغيراتها المساعدة بوضوح.',
      noteEn:
          'Write the main formula first and define its helper terms cleanly.',
      code: '''use quds:math show sqrt
hyp = sqrt(a * a + b * b) where a = 3.0, b = 4.0
print "الوتر = {hyp}"''',
    ),
  ],
  'new': [
    AcademyRuleExample(
      titleAr: 'اختصار الباني السياقي (.new)',
      titleEn: 'Contextual constructor shorthand (.new)',
      noteAr:
          'عندما يكون النوع المتوقع واضحاً يمكنك استدعاء الباني بـ .new(...).',
      noteEn:
          'When the expected type is known, .new(...) invokes its constructor.',
      code: '''class Coord:
  x: int required
  y: int required
  show() -> String = "({x}, {y})"

c: Coord = .new(5, 9)
print "الإحداثية: {c.show()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام .new في تهيئة كائنات ببيانات وصفية',
      titleEn: 'Using .new with typed declarations',
      noteAr: 'يقلل التكرار عند كتابة النوع صراحةً على اليسار.',
      noteEn: 'Eliminates repeating the type name on both sides.',
      code: '''class Tag:
  label: String required

t: Tag = .new("Quds 1.2")
print "الوسم: {t.label}"''',
    ),
  ],
};
