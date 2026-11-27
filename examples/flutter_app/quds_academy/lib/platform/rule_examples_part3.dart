/// Executable Quds Rule Examples — Part 3:
/// Categories 9–12 (Safety & Resources, Patterns & Queries, State & Events, Config & Tests)
/// plus rich extra live-executable examples for all 12 Quds Academy lessons.
library;

import 'rule_examples_model.dart';

const Map<String, List<AcademyRuleExample>> ruleExamplesPart3 = {
  // ── 9. Safety & Resources (12) ───────────────────────────────────────────
  'try': [
    AcademyRuleExample(
      titleAr: 'التقاط خطأ بأمان عبر try / catch',
      titleEn: 'Catching runtime errors with try / catch',
      noteAr: 'تسمح try بمعالجة الأخطاء بأناقة دون توقف البرنامج.',
      noteEn: 'try/catch recovers gracefully from runtime exceptions.',
      code: '''try:
  n = "ليس رقماً" to int
  print n
catch err:
  print "تم التقاط الخطأ بأمان: {err}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تعبير try .. else لقيمة بديلة فورية',
      titleEn: 'Expression fallback with try expr else default',
      noteAr: 'صياغة مختصرة لقراءة قيمة أو العودة لقيمة بديلة عند الخطأ.',
      noteEn: 'Concise inline fallback expression when an operation throws.',
      code: '''safe = try ("abc" to int) else -1
valid = try ("99" to int) else -1
print "غير صالح -> {safe} | صالح -> {valid}"''',
    ),
  ],
  'catch': [
    AcademyRuleExample(
      titleAr: 'التقاط استثناء مرمي وعرض رسالته',
      titleEn: 'Handling thrown exceptions in catch',
      noteAr: 'يربط catch كائن الاستثناء بمتغير لتسجيله أو استرداد المسار.',
      noteEn: 'catch binds the thrown error so you can inspect and recover.',
      code: '''divide(a: int, b: int) -> double:
  if b == 0:
    throw "لا يمكن القسمة على صفر"
  return a / b

try:
  print divide(10, 0)
catch e:
  print "تنبيه: {e}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استكمال التنفيذ بعد catch',
      titleEn: 'Continuing normal flow after catch',
      noteAr: 'بعد معالجة الخطأ يستمر البرنامج بشكل طبيعي.',
      noteEn: 'Execution continues normally after the catch block finishes.',
      code: '''var val = 0
try:
  val = "xyz" to int
catch e:
  val = 100
print "القيمة النهائية المعتمدة = {val}"''',
    ),
  ],
  'finally': [
    AcademyRuleExample(
      titleAr: 'تنفيذ finally في حالتي النجاح والفشل',
      titleEn: 'finally always runs on both success and failure',
      noteAr: 'يضمن finally تنفيذ شيفرة التنظيف دائماً عند مغادرة try.',
      noteEn: 'finally guarantees cleanup runs whether try succeeds or throws.',
      code: '''try:
  print "1. فتح الاتصال"
  throw "انقطع الشبكة"
catch e:
  print "2. معالجة الخطأ: {e}"
finally:
  print "3. إغلاق الاتصال دائماً (finally) ✓"''',
    ),
    AcademyRuleExample(
      titleAr: 'تنظيف الموارد بعد نجاح التنفيذ بـ finally',
      titleEn: 'Guaranteed cleanup on normal completion',
      noteAr: 'يعمل finally حتى عندما لا يقع أي خطأ.',
      noteEn: 'finally runs on normal completion too.',
      code: '''try:
  print "قراءة البيانات بنجاح"
finally:
  print "تحرير الذاكرة المؤقتة ✓"''',
    ),
  ],
  'throw': [
    AcademyRuleExample(
      titleAr: 'رمي استثناء مخصّص عند إدخال غير صالح',
      titleEn: 'Throwing an exception on invalid input',
      noteAr: 'تغادر throw المسار الطبيعي فوراً نحو أقرب معالج catch.',
      noteEn:
          'throw immediately transfers control to the nearest catch handler.',
      code: '''withdraw(balance: int, amount: int) -> int:
  if amount > balance:
    throw "الرصيد غير كافٍ ({balance} < {amount})"
  return balance - amount

try:
  print withdraw(50, 120)
catch err:
  print "عملية مرفوضة: {err}"''',
    ),
    AcademyRuleExample(
      titleAr: 'التحقق من صحة معامل دالة بـ throw',
      titleEn: 'Validating arguments with throw',
      noteAr: 'حماية الدوال من القيم الخارجة عن النطاق المسموح.',
      noteEn: 'Guards functions against out-of-range inputs.',
      code: '''setAge(age: int) -> String:
  if age < 0:
    throw "العمر لا يمكن أن يكون سالباً"
  return "العمر المسجّل: {age}"

print setAge(24)
try:
  print setAge(-5)
catch e:
  print "خطأ: {e}"''',
    ),
  ],
  'rethrow': [
    AcademyRuleExample(
      titleAr: 'تسجيل الخطأ ثم إعادة رميه بـ rethrow',
      titleEn: 'Logging an error and propagating it with rethrow',
      noteAr: 'تحافظ rethrow على الاستثناء الأصلي وتمرّره للمستوى الأعلى.',
      noteEn: 'rethrow propagates the caught exception to outer handlers.',
      code: '''inner():
  try:
    throw "فشل قراءة الملف"
  catch e:
    print "[سجل داخلي] تم رصد: {e}"
    rethrow

try:
  inner()
catch topErr:
  print "[المعالج الأعلى] استلم: {topErr}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تنظيف جزئي مع إعادة الرمي بـ rethrow',
      titleEn: 'Partial handling before rethrowing',
      noteAr: 'تُستخدم rethrow حصراً داخل كتلة catch.',
      noteEn: 'rethrow is only valid inside a catch block.',
      code: '''var retries = 0
try:
  try:
    retries += 1
    throw "انتهى الوقت"
  catch err:
    print "المحاولة #{retries} فشلت"
    rethrow
catch finalErr:
  print "توقف بعد {retries} محاولة: {finalErr}"''',
    ),
  ],
  'assert': [
    AcademyRuleExample(
      titleAr: 'التحقق من صحة الافتراضات باستخدام assert',
      titleEn: 'Checking development invariants with assert',
      noteAr: 'تفحص assert الشروط المنطقية أثناء التطوير والاختبار.',
      noteEn: 'assert verifies invariants during development and testing.',
      code: '''items = [10, 20, 30]
assert items.length == 3, "يجب أن تحتوي 3 عناصر"
assert items[0] < items[2]
print "نجحت جميع تأكيدات assert ✓"''',
    ),
    AcademyRuleExample(
      titleAr: 'التقاط فشل assert برسالة واضحة',
      titleEn: 'Inspecting an assert failure message',
      noteAr: 'لا تُقيّم رسالة الخطأ إلا عند فشل الشرط.',
      noteEn:
          'The optional failure message is evaluated only when assert fails.',
      code: '''try:
  score = -1
  assert score >= 0, "الدرجة لا تكون سالبة"
catch e:
  print "فشل التأكيد: {e}"''',
    ),
  ],
  'require': [
    AcademyRuleExample(
      titleAr: 'فرض شرط مسبق لمعامل دالة بـ require',
      titleEn: 'Enforcing preconditions with require',
      noteAr: 'يعمل require في كل الإصدارات ويرمي خطأ معامل عند الفشل.',
      noteEn: 'require always checks preconditions in every build.',
      code: '''discount(price: double, pct: double) -> double:
  require price >= 0.0, "السعر يجب أن يكون موجباً"
  require pct >= 0.0 and pct <= 100.0, "النسبة بين 0 و 100"
  return price * (1.0 - pct / 100.0)

print "السعر بعد خصم 20% = {discount(150.0, 20.0)}"
try:
  print discount(150.0, 120.0)
catch e:
  print "شرط مسبق مرفوض: {e}"''',
    ),
    AcademyRuleExample(
      titleAr: 'حماية مؤشر المصفوفة باستخدام require',
      titleEn: 'Guarding index bounds with require',
      noteAr: 'يوضّح للمتصل فوراً سبب رفض المدخلات.',
      noteEn: 'Gives callers immediate, clear argument diagnostics.',
      code: '''pick(xs: List<String>, idx: int) -> String:
  require idx >= 0 and idx < xs.length, "فهرس خارج النطاق"
  return xs[idx]

print "العنصر 1 = {pick(["أ", "ب", "ج"], 1)}"''',
    ),
  ],
  'check': [
    AcademyRuleExample(
      titleAr: 'فحص حالة داخلية (Invariant) باستخدام check',
      titleEn: 'Checking object state invariants with check',
      noteAr: 'تتحقق check من سلامة الحالة الداخلية في كل الإصدارات.',
      noteEn: 'check enforces state invariants in every build.',
      code: '''class Machine:
  var started: bool = false
  start():
    started = true
  run() -> String:
    check started, "يجب تشغيل الآلة أولاً!"
    return "الآلة تعمل بكفاءة ✓"

m = Machine()
try:
  print m.run()
catch e:
  print "حالة غير جاهزة: {e}"
m.start()
print m.run()''',
    ),
    AcademyRuleExample(
      titleAr: 'التحقق من نتيجة حسابية باستخدام check',
      titleEn: 'Post-condition check on computed value',
      noteAr: 'تضمن check بقاء الحالة ضمن الحدود الصحيحة.',
      noteEn: 'Ensures computed invariants hold before continuing.',
      code: '''total = 25 + 75
check total == 100, "المجموع يجب أن يساوي 100"
print "التحقق من الحالة سليم: total = {total} ✓"''',
    ),
  ],
  'defer': [
    AcademyRuleExample(
      titleAr: 'تنفيذ مؤجّل بترتيب عكسي (LIFO) عند خروج الدالة',
      titleEn: 'LIFO scope-exit cleanup with defer',
      noteAr: 'تُنفّذ جمل defer تلقائياً عند الخروج بترتيب آخر ما أُضيف أول ما يُنفّذ.',
      noteEn:
          'defer schedules cleanup at scope exit in last-in, first-out order.',
      code: '''process():
  print "1. بدء المعالجة"
  defer print "4. إغلاق الملف (أول defer يُنفّذ أخيراً)"
  defer print "3. تحرير القفل (آخر defer يُنفّذ أولاً)"
  print "2. تنفيذ المهمة"

process()''',
    ),
    AcademyRuleExample(
      titleAr: 'عمل defer حتى عند الإرجاع المبكر',
      titleEn: 'defer runs even on early return',
      noteAr: 'لا تُنسى خطوات التنظيف أبداً مهما كان مسار الخروج.',
      noteEn: 'Cleanup still executes cleanly on early return paths.',
      code: '''checkUser(ok: bool) -> String:
  defer print "تنظيف جلسة الفحص ✓"
  if not ok:
    return "مرفوض"
  return "مقبول"

print "النتيجة: {checkUser(false)}"''',
    ),
  ],
  'using': [
    AcademyRuleExample(
      titleAr: 'إدارة تلقائية للموارد القابلة للتخلّص عبر using',
      titleEn: 'Automatic resource disposal with using',
      noteAr: 'تستدعي using دالة dispose()/close() تلقائياً فور انتهاء الكتلة.',
      noteEn: 'using automatically disposes bound resources upon block exit.',
      code: '''class TempFile:
  name: String required
  read() -> String = "محتوى {name}"
  close():
    print "تم إغلاق {name} تلقائياً ✓"

using f = TempFile("notes.txt"):
  print "قراءة: {f.read()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحرير المورد تلقائياً حتى عند حدوث خطأ داخل using',
      titleEn: 'Resource disposal even when body throws',
      noteAr: 'يضمن using عدم تسريب الموارد في جميع المسارات.',
      noteEn: 'Guarantees zero resource leaks on exceptional exits too.',
      code: '''class Conn:
  close():
    print "تم تحرير الاتصال رغم الخطأ ✓"

try:
  using c = Conn():
    print "بدء الاستعلام..."
    throw "استعلام غير مكتمل"
catch e:
  print "التقاط: {e}"''',
    ),
  ],
  'readonly': [
    AcademyRuleExample(
      titleAr: 'حماية قائمة من التعديل عبر مرجع readonly',
      titleEn: 'Read-only list reference parameter (QUDS-092)',
      noteAr: 'يمنع readonly تعديل البيانات عبر هذا المرجع دون تجميد الكائن الأصلي.',
      noteEn: 'readonly forbids mutation through the reference without freezing aliases.',
      code: '''sumReadonly(items: readonly List<int>) -> int:
  var total = 0
  for x in items:
    total += x
  return total

nums = [10, 20, 30, 40]
print "مجموع آمن للقراءة فقط = {sumReadonly(nums)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'قراءة عناصر قائمة readonly وفحص طولها',
      titleEn: 'Inspecting elements of a readonly collection',
      noteAr: 'تسمح مراجع readonly بعمليات القراءة والفهرسة والطول بأمان كامل.',
      noteEn: 'All non-mutating reads (length, indexing, iteration) work seamlessly.',
      code: '''firstAndLast(xs: readonly List<String>) -> String:
  return "{xs[0]} ... {xs[xs.length - 1]}"

print firstAndLast(["القدس", "غزة", "نابلس", "الخليل"])''',
    ),
  ],
  'capture': [
    AcademyRuleExample(
      titleAr: 'التقاط لقطة ثابتة لقيمة متغير بـ capture(...)',
      titleEn: 'Snapshotting variable values with capture(...) (QUDS-091)',
      noteAr: 'تنسخ capture(x) قيمة x لحظة إنشاء الدالة المجهولة فلا تتأثر بتغيّره لاحقاً.',
      noteEn: 'capture(x) snapshots x at creation time so later mutations do not change it.',
      code: '''var count = 1
snap = capture(count) -> count
live = () -> count
count = 99
print "لقطة capture(count) = {snap()}"
print "الإغلاق الحي (الافتراضي) = {live()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'حفظ قيم عدّاد الحلقة داخل قائمة دوال بـ capture',
      titleEn: 'Capturing loop iteration values safely in closures',
      noteAr: 'يحل capture أشهر مشكلة في الإغلاقات داخل الحلقات بسطر واحد.',
      noteEn: 'Solves the classic loop-closure capture pitfall cleanly.',
      code: '''var fns = []
var i = 1
while i <= 3:
  fns.add(capture(i) -> i * 10)
  i += 1

for fn in fns:
  print "ناتج الدالة الملتقطة = {fn()}"''',
    ),
  ],

  // ── 10. Patterns & Queries (5) ───────────────────────────────────────────
  'with': [
    AcademyRuleExample(
      titleAr: 'تهيئة عدة خصائص لكائن بكتلة with',
      titleEn: 'Configuring an object cleanly with a with block',
      noteAr: 'تقيّم with الكائن مرة واحدة وتطبّق عليه عدة عمليات ثم تعيده.',
      noteEn:
          'with evaluates its receiver once, applies updates, and yields it.',
      code: '''class Profile:
  var name: String = ""
  var role: String = ""
  show() -> String = "{name} ({role})"

p = with Profile():
  name = "ليلى"
  role = "مهندسة برمجيات"

print p.show()''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام with في رأس الكلاس لتطبيق mixin',
      titleEn: 'Applying a mixin in a class header using with',
      noteAr: 'تُستخدم with أيضاً لإلحاق المزائج (mixins) بالكلاس.',
      noteEn: 'with also attaches mixins in class declarations.',
      code: '''mixin Describable:
  tag() -> String = "QudsObject"

class Card with Describable:
  title: String required

c = Card("بطاقة تعلّم")
print "{c.tag()}: {c.title}"''',
    ),
  ],
  'with?': [
    AcademyRuleExample(
      titleAr: 'تطبيق with? الآمن على كائن قابل لـ null',
      titleEn: 'Null-safe with? block skipping null receivers',
      noteAr: 'تتجاوز with? الكتلة وتعيد null بأمان إذا كان الكائن فارغاً.',
      noteEn:
          'with? skips the block and yields null when the receiver is null.',
      code: '''class Note:
  var text: String = ""

var empty: Note? = null
res1 = with? empty:
  text = "لن يُنفّذ"
print "حالة null: {res1}"

var real: Note? = Note()
res2 = with? real:
  text = "ملاحظة محفوظة ✓"
print "حالة كائن حقيقي: {res2?.text}"''',
    ),
    AcademyRuleExample(
      titleAr: 'سلسلة تحديث اختيارية بـ with? و ??',
      titleEn: 'Combining with? and ?? fallback',
      noteAr: 'دمج with? مع ?? يوفّر بديلاً فورياً عند غياب الكائن.',
      noteEn: 'Combine with? and ?? for concise optional updates.',
      code: '''class Box:
  var label: String = "افتراضي"

var maybe: Box? = Box()
updated = with? maybe:
  label = "محدّث بقدس"
print updated?.label ?? "لا يوجد صندوق"''',
    ),
  ],
  'match': [
    AcademyRuleExample(
      titleAr: 'تعبير match لمطابقة القيم والحراس (when)',
      titleEn: 'Match expression with literals and when guards',
      noteAr: 'يعيد match قيمة مباشرة دون الحاجة لـ break في كل فرع.',
      noteEn: 'match returns a value directly with zero fallthrough bugs.',
      code: '''season(month: int) -> String:
  return match month:
    12: "شتاء ❄️"
    1: "شتاء ❄️"
    2: "شتاء ❄️"
    m when m >= 3 and m <= 5: "ربيع 🌸"
    m when m >= 6 and m <= 8: "صيف ☀️"
    _: "خريف 🍂"

print "شهر 1 -> {season(1)}"
print "شهر 4 -> {season(4)}"
print "شهر 10 -> {season(10)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'مطابقة النصوص والأوامر باستخدام match',
      titleEn: 'Command routing with match',
      noteAr: 'بديل نظيف وسريع لسلاسل if / else if الطويلة.',
      noteEn: 'A clean, expressive replacement for long if/else chains.',
      code: '''runCmd(cmd: String) -> String:
  return match cmd:
    "start": "بدء المحرك..."
    "stop": "إيقاف آمن"
    "status": "يعمل بكفاءة 100%"
    other: "أمر غير معروف: {other}"

for c in ["start", "status", "help"]:
  print "{c} => {runCmd(c)}"''',
    ),
  ],
  'switch': [
    AcademyRuleExample(
      titleAr: 'جملة switch بنمط مطابقة قدس النظيف (بلا break)',
      titleEn: 'Switch statement with no C-style fallthrough',
      noteAr: 'تستخدم switch قواعد المطابقة نفسها كـ match دون سقوط تلقائي بين الفروع.',
      noteEn: 'switch shares match grammar without C-style fallthrough.',
      code: '''dayType(day: String):
  switch day:
    "الجمعة":
      print "{day}: عطلة نهاية الأسبوع 🌿"
    "السبت":
      print "{day}: عطلة نهاية الأسبوع 🌿"
    _:
      print "{day}: يوم عمل ودراسة 📚"

dayType("الجمعة")
dayType("الاثنين")''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام switch مع حراس when للأرقام',
      titleEn: 'Switch arms with numeric when guards',
      noteAr: 'تدعم switch الأنماط وحراس when بالكامل.',
      noteEn: 'switch fully supports binding patterns and when guards.',
      code: '''ping(ms: int):
  switch ms:
    x when x < 50:
      print "{x}ms: اتصال فائق السرعة ⚡"
    x when x < 150:
      print "{x}ms: اتصال جيد ✓"
    x:
      print "{x}ms: اتصال بطيء"

ping(22)
ping(110)''',
    ),
  ],
  'map': [
    AcademyRuleExample(
      titleAr: 'إنشاء خريطة مفتاح/قيمة بصياغة map: النظيفة',
      titleEn: 'Creating a key-value map with map:',
      noteAr:
          'تكتب أزواج الخريطة بوضوح سطراً تلو سطر تحت map: دون أقواس متشابكة.',
      noteEn: 'map: declares clean indented key: value rows.',
      code: '''capitals = map:
  "فلسطين": "القدس"
  "الأردن": "عمّان"
  "مصر": "القاهرة"

print "عاصمة فلسطين: {capitals["فلسطين"]}"
print "عدد الدول = {capitals.length}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تعديل وقراءة خريطة map مع التحقق من المفاتيح',
      titleEn: 'Updating and reading entries in a map',
      noteAr: 'يمكنك إضافة مفاتيح وتحديث قيمها بسهولة عبر الفهرسة.',
      noteEn: 'Insert and update entries cleanly via bracket indexing.',
      code: '''scores = map:
  "أحمد": 88
  "سارة": 94

scores["أحمد"] = 95
scores["عمر"] = 90
print "الدرجات: {scores}"''',
    ),
  ],

  // ── 11. State & Events (7) ───────────────────────────────────────────────
  'state': [
    AcademyRuleExample(
      titleAr: 'خلية حالة تفاعلية state تتحدّث وتُراقب',
      titleEn: 'Reactive state cell with live updates',
      noteAr:
          'تعرّف state قيمة تفاعلية تُبلّغ القيم المشتقة والمراقبين تلقائياً.',
      noteEn: 'state declares a reactive cell tracked by computed and watch.',
      code: '''state count = 1
print "البداية: count = {count}"
count = 5
count += 3
print "بعد التحديث: count = {count}"''',
    ),
    AcademyRuleExample(
      titleAr: 'ربط state مع computed لحساب تلقائي',
      titleEn: 'Pairing state with computed derived values',
      noteAr: 'كلما تغيرت state تتحدّث computed المرتبطة بها تلقائياً.',
      noteEn:
          'Changing state automatically recomputes dependent computed cells.',
      code: '''state price = 50
state qty = 3
computed total = price * qty
print "الإجمالي الأولي = {total}"
qty = 5
print "الإجمالي بعد تحديث الكمية = {total}"''',
    ),
  ],
  'computed': [
    AcademyRuleExample(
      titleAr: 'قيمة مشتقة تلقائياً باستخدام computed',
      titleEn: 'Automatically derived value with computed',
      noteAr: 'تحسب computed قيمتها من خلايا state وتتحدّث تلقائياً دون كتابة مستمعات.',
      noteEn: 'computed tracks state dependencies and updates automatically.',
      code: '''state radius = 2.0
computed area = 3.14159 * radius * radius
print "نصف القطر 2 -> المساحة = {area.toStringAsFixed(2)}"
radius = 5.0
print "نصف القطر 5 -> المساحة = {area.toStringAsFixed(2)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'سلسلة قيم مشتقة computed فوق computed',
      titleEn: 'Chained computed reactive cells',
      noteAr: 'يمكن لقيمة computed أن تعتمد على computed أخرى بسلاسة.',
      noteEn: 'Computed values can cleanly derive from other computed values.',
      code: '''state base = 100.0
computed tax = base * 0.15
computed grandTotal = base + tax
print "قبل التعديل: {grandTotal}"
base = 200.0
print "بعد التعديل: {grandTotal}"''',
    ),
  ],
  'watch': [
    AcademyRuleExample(
      titleAr: 'مراقبة تغيّرات حالة state تلقائياً عبر watch',
      titleEn: 'Observing reactive state changes with watch',
      noteAr: 'تُشغّل watch كتلتها تلقائياً عند كل تعديل في القيمة المراقَبة.',
      noteEn: 'watch runs its reaction body whenever tracked state changes.',
      code: '''state temp = 22
watch temp:
  print "تغيّرت الحرارة إلى: {temp}°C"

temp = 26
temp = 30''',
    ),
    AcademyRuleExample(
      titleAr: 'مراقبة قيمة مشتقة computed بـ watch',
      titleEn: 'Watching a computed expression',
      noteAr: 'يمكن مراقبة تعبير مشتق أو خلية computed مباشرة.',
      noteEn: 'watch reacts cleanly to computed cell changes too.',
      code: '''state items = 1
computed cost = items * 25
watch cost:
  print "التكلفة المحدّثة = {cost} دينار"

items = 3
items = 4''',
    ),
  ],
  'batch': [
    AcademyRuleExample(
      titleAr: 'تجميع عدة تعديلات في إشعار واحد عبر batch:',
      titleEn: 'Coalescing multiple state updates with batch:',
      noteAr:
          'تؤجّل batch: إشعارات watch حتى نهاية الكتلة فتطلقها مرة واحدة فقط!',
      noteEn: 'batch: defers watch notifications until exit and flushes once.',
      code: '''state x = 1
state y = 2
computed sum = x + y
watch sum:
  print "إشعار واحد مجمّع: sum = {sum}"

batch:
  x = 10
  y = 20''',
    ),
    AcademyRuleExample(
      titleAr: 'تحديث إحداثيات معاً بسلامة في batch:',
      titleEn: 'Atomic coordinate update using batch:',
      noteAr: 'يمنع الحالات الوسيطة غير المتناسقة عند تحديث عدة متغيرات معاً.',
      noteEn: 'Prevents intermediate glitch states across paired variables.',
      code: '''state first = "أحمد"
state last = "علي"
computed full = "{first} {last}"
watch full:
  print "الاسم الجديد: {full}"

batch:
  first = "سارة"
  last = "خالد"''',
    ),
  ],
  'event': [
    AcademyRuleExample(
      titleAr: 'تعريف حدث مُنمّط (event) وإطلاقه بـ raise',
      titleEn: 'Declaring a typed event member and subscribing',
      noteAr: 'تعرّف event قناة إشعارات داخل الكلاس يمكن الاشتراك بها وإطلاقها بـ raise.',
      noteEn: 'event defines a typed signal that listeners subscribe to.',
      code: '''class Button:
  event clicked: (int) -> void
  press(times: int):
    raise clicked(times)

btn = Button()
btn.clicked.listen((n: int) -> print("تم الضغط {n} مرة!"))
btn.press(1)
btn.press(2)''',
    ),
    AcademyRuleExample(
      titleAr: 'عدّة مشتركين يستمعون للحدث نفسه',
      titleEn: 'Multiple listeners subscribed to one event',
      noteAr: 'يدعم الحدث عدّة مستمعين يتلقون الحمولة نفسها عند إطلاقه.',
      noteEn: 'Multiple subscribers can react independently to one event.',
      code: '''class Sensor:
  event reading: (double) -> void
  emit(v: double):
    raise reading(v)

s = Sensor()
s.reading.listen((v: double) -> print("شاشة: {v}°C"))
s.reading.listen((v: double) -> print("سجل: حُفظت القراءة {v}"))
s.emit(24.5)''',
    ),
  ],
  'raise': [
    AcademyRuleExample(
      titleAr: 'إطلاق حدث معرّف بـ raise وتمرير بياناته',
      titleEn: 'Emitting an event payload with raise',
      noteAr: 'يرسل raise القيمة لجميع المشتركين المسجّلين في الحدث.',
      noteEn: 'raise dispatches arguments to all registered event listeners.',
      code: '''class Download:
  event progress: (int) -> void
  run():
    raise progress(50)
    raise progress(100)

d = Download()
d.progress.listen((p: int) -> print("تقدّم التحميل: {p}%"))
d.run()''',
    ),
    AcademyRuleExample(
      titleAr: 'حدث تنبيه مشروط يُطلق بـ raise',
      titleEn: 'Conditionally raising an alert event',
      noteAr: 'إطلاق التنبيه فقط عند تجاوز العتبة المحددة.',
      noteEn: 'Raises an alert only when the threshold is exceeded.',
      code: '''class Guard:
  event alert: (String) -> void
  inspect(level: int):
    if level > 80:
      raise alert("مستوى مرتفع: {level}%")

g = Guard()
g.alert.listen((msg: String) -> print("⚠️ {msg}"))
g.inspect(40)
g.inspect(92)''',
    ),
  ],
  'once': [
    AcademyRuleExample(
      titleAr: 'تنفيذ كتلة مرة واحدة فقط مهما تكرر استدعاء الدالة (once:)',
      titleEn: 'Run-at-most-once block with once:',
      noteAr: 'تضمن once: تنفيذ الكتلة في الاستدعاء الأول فقط وتخطّيها لاحقاً.',
      noteEn: 'once: executes its body at most once per call site.',
      code: '''initService(step: int):
  once:
    print "⚡ تهيئة أولية (تعمل مرة واحدة فقط!)"
  print "تنفيذ الخطوة #{step}"

initService(1)
initService(2)
initService(3)''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام once: داخل حلقة لطباعة ترويسة واحدة',
      titleEn: 'Using once: inside a loop for a one-time header',
      noteAr: 'تُطبع الترويسة في الدورة الأولى فقط تلقائياً.',
      noteEn: 'Prints a header automatically on the first iteration only.',
      code: '''for i in 1..3:
  once:
    print "--- جدول النتائج ---"
  print "سطر {i}: {i * 10}"''',
    ),
  ],

  // ── 12. Configuration & Tests (3) ────────────────────────────────────────
  'config': [
    AcademyRuleExample(
      titleAr: 'تعريف مفتاح إعداد مُنمّط بقيمة افتراضية (config)',
      titleEn: 'Typed configuration key with default value',
      noteAr: 'يقرأ config القيمة من البيئة أو quds.yaml أو يعود للقيمة الافتراضية.',
      noteEn: 'config resolves from env, quds.yaml, or its typed default.',
      code: '''config server.port: int = 8080
config app.title: String = "Quds Academy"
print "التطبيق: {app.title} على المنفذ {server.port}"''',
    ),
    AcademyRuleExample(
      titleAr: 'إعدادات متدرّجة لميزات التطبيق باستخدام config',
      titleEn: 'Feature-flag configuration keys',
      noteAr: 'مفاتيح نقطية واضحة ومُنمّطة بالكامل.',
      noteEn: 'Dotted typed config keys keep settings structured.',
      code: '''config feature.darkMode: bool = true
config feature.maxItems: int = 50
print "الوضع الداكن: {feature.darkMode} | الحد: {feature.maxItems}"''',
    ),
  ],
  'secret': [
    AcademyRuleExample(
      titleAr: 'تعريف مفتاح إعداد سري (config secret)',
      titleEn: 'Declaring a secret configuration key',
      noteAr:
          'يمنع secret كتابة القيم السرية داخل الشيفرة المصدرية لحماية الأمان.',
      noteEn: 'secret marks sensitive config keys that must come from the environment.',
      code: '''config secret api.key: String
print "تم تسجيل مفتاح سري (api.key) دون تخزين قيمته في الكود ✓"''',
    ),
    AcademyRuleExample(
      titleAr: 'الفصل بين الإعداد العام والإعداد السري',
      titleEn: 'Separating public config from secret keys',
      noteAr: 'الإعدادات العامة لها قيمة افتراضية بينما السرية تُحقن من البيئة فقط.',
      noteEn:
          'Public settings carry defaults; secrets are injected externally.',
      code: '''config db.host: String = "localhost"
config secret db.password: String
print "المضيف: {db.host} · كلمة المرور محمية عبر secret ✓"''',
    ),
  ],
  'test': [
    AcademyRuleExample(
      titleAr: 'كتابة اختبار وحدوي مباشر داخل اللغة باستخدام test',
      titleEn: 'Native unit test declaration with test',
      noteAr: 'الاختبارات جزء أصيل من صياغة قدس وتُشغّل بأمر quds test.',
      noteEn: 'Tests are first-class syntax in Quds and run with quds test.',
      code: '''doubleIt(n: int) -> int = n * 2

test "مضاعفة الأعداد":
  assert doubleIt(6) == 12
  assert doubleIt(0) == 0

print "تم اجتياز اختبار test بنجاح ✓"''',
    ),
    AcademyRuleExample(
      titleAr: 'اختبارات متعددة منظّمة داخل group و test',
      titleEn: 'Multiple unit tests inside a test group',
      noteAr: 'يمكن الجمع بين group و test لتنظيم مجموعات اختبارات كاملة.',
      noteEn: 'Combine group and test for structured test suites.',
      code: '''group "النصوص":
  test "الطول":
    assert "Quds".length == 4
  test "التكبير":
    assert "quds".toUpperCase() == "QUDS"

print "اجتازت جميع اختبارات النصوص ✓"''',
    ),
  ],
};

/// Rich extra live-executable examples for EVERY ONE of the 12 Academy Lessons!
const Map<String, List<AcademyRuleExample>> lessonExtraExamples = {
  'hello': [
    AcademyRuleExample(
      titleAr: 'الطباعة المتعددة والعمليات الفورية',
      titleEn: 'Multiple prints and inline expressions',
      noteAr: 'يمكن استدعاء print بدون أقواس للمعامل البسيط وبأقواس للتعابير المركبة.',
      noteEn: 'print omits parentheses for simple arguments and evaluates expressions.',
      code: '''name = "أكاديمية قدس"
year = 2026
print "مرحباً بك في {name}!"
print "عام الإطلاق: {year} · 6 × 7 = {6 * 7}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحية ثنائية اللغة عبر دالة بسيطة',
      titleEn: 'Bilingual greeting helper function',
      noteAr: 'النقطتان والمسافة البادئة تكفيان لإنشاء دالة نظيفة بلا أقواس معقوفة.',
      noteEn: 'A colon and indentation are all you need for a clean function.',
      code: '''welcome(user: String):
  print "السلام عليكم يا {user}!"
  print "Welcome to Quds, {user}!"

welcome("مطور المستقبل")''',
    ),
    AcademyRuleExample(
      titleAr: 'رسم بطاقة ترحيبية نصية',
      titleEn: 'Drawing a formatted text banner',
      noteAr: 'مثال يجمع الطباعة والتكرار في 4 أسطر.',
      noteEn: 'Combines printing and repeat in four clear lines.',
      code: '''print "===================="
print "  لغة قدس البرمجية  "
print "===================="
repeat 2:
  print "★ ابدأ صغيرًا وابنِ بلا حدود"''',
    ),
  ],
  'bindings': [
    AcademyRuleExample(
      titleAr: 'الفرق بين الارتباط الثابت و var',
      titleEn: 'Immutable binding vs mutable var',
      noteAr: 'الافتراضي في قدس هو الثبات (name = value)، واستخدام var يعلن نية التغيير.',
      noteEn: 'Immutability is default; var explicitly signals reassignment.',
      code: '''language = "Quds"
var version = 1
version += 1
print "{language} v{version}"''',
    ),
    AcademyRuleExample(
      titleAr: 'حجب مقصود بـ shadow دون المساس بالأصل',
      titleEn: 'Safe local shadowing with shadow',
      noteAr: 'يحمي shadow المتغيرات الخارجية من التعديل غير المقصود.',
      noteEn: 'shadow prevents accidental mutation of outer bindings.',
      code: '''var x = 10
if true:
  shadow x = 50
  print "داخل الكتلة: x = {x}"
print "خارج الكتلة: x = {x}"''',
    ),
    AcademyRuleExample(
      titleAr: 'ثوابت const مع تهيئة مؤجلة late',
      titleEn: 'Compile-time const with deferred late',
      noteAr: 'تجمع قدس بين وضوح const ومرونة late.',
      noteEn: 'Combine fixed const limits with deferred late bindings.',
      code: '''const taxRate = 0.15
late receipt: String
subtotal = 200.0
receipt = "المجموع مع الضريبة = {subtotal * (1.0 + taxRate)}"
print receipt''',
    ),
  ],
  'strings': [
    AcademyRuleExample(
      titleAr: 'تضمين التعابير والعمليات داخل النص {expr}',
      titleEn: 'Interpolating expressions with {expr}',
      noteAr: 'أي تعبير صالح يمكن وضعه داخل { } ليُقيّم ويُنسّق تلقائياً.',
      noteEn: 'Any valid expression fits inside { } for automatic formatting.',
      code: '''price = 19.5
qty = 4
print "العدد: {qty} × {price} = {(price * qty).toStringAsFixed(2)} USD"''',
    ),
    AcademyRuleExample(
      titleAr: 'النصوص الخام r"..." والأقواس الحرفية \\{ \\}',
      titleEn: r'Raw strings r"..." and escaped braces \{ \}',
      noteAr: r'النص الخام r"..." يتجاهل التضمين، و \{ \} تطبع أقواساً حرفية.',
      noteEn:
          r'Raw strings r"..." skip interpolation; \{ \} print literal braces.',
      code: r'''raw = r"مسار خام: C:\quds\{name}"
escaped = "قالب قدس: \{ lang: Quds \}"
print raw
print escaped''',
    ),
    AcademyRuleExample(
      titleAr: 'دوال النصوص: التكبير والقص والبحث',
      titleEn: 'Useful String methods',
      noteAr: 'معالجة النصوص بسرعة بـ trim و toUpperCase و contains.',
      noteEn: 'Clean, uppercase, and inspect strings effortlessly.',
      code: '''raw = "   quds language   "
clean = raw.trim()
print "منظّف: [{clean}]"
print "أحرف كبيرة: {clean.toUpperCase()}"
print "يحتوي quds؟ {"quds" in clean}"''',
    ),
  ],
  'functions': [
    AcademyRuleExample(
      titleAr: 'دوال الجسم التعبيري (=) والدوال متعددة الأسطر',
      titleEn: 'Expression-body (=) vs multiline functions',
      noteAr: 'الجسم التعبيري يُرجع القيمة مباشرة، ومتعددة الأسطر تستخدم return صريحاً.',
      noteEn: 'Single-line functions use =; multiline functions use explicit return.',
      code: '''square(x: int) -> int = x * x

hypotenuseSq(a: int, b: int) -> int:
  return square(a) + square(b)

print "3^2 + 4^2 = {hypotenuseSq(3, 4)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'المعاملات الثنائية (بالترتيب أو بالاسم) والقيم الافتراضية',
      titleEn: 'Dual positional/named parameters & defaults (QUDS-081/086)',
      noteAr: 'كل معامل عادي في قدس يُمرّر بالترتيب أو بالاسم مع دعم القيم الافتراضية.',
      noteEn: 'Parameters work both positionally and by name with defaults.',
      code: '''greet(name: String, prefix: String = "أهلاً") -> String:
  return "{prefix} يا {name}!"

print greet("سارة")
print greet(prefix: "مرحباً", name: "عمر")''',
    ),
    AcademyRuleExample(
      titleAr: 'دوال عليا (Higher-Order) وتمرير دوال مجهولة (Lambda)',
      titleEn: 'Passing lambdas to higher-order functions',
      noteAr: 'الدوال في قدس قيم من الدرجة الأولى يمكن تمريرها كمعاملات.',
      noteEn: 'Functions are first-class values that accept lambdas cleanly.',
      code: '''applyTwice(x: int, f: (int) -> int) -> int = f(f(x))

print "تطبيق ×3 مرتين على 2 = {applyTwice(2, (n: int) -> n * 3)}"''',
    ),
  ],
  'branches': [
    AcademyRuleExample(
      titleAr: 'سلسلة شروط if / else if مع عوامل المقارنة المتسلسلة',
      titleEn: 'Chained comparisons (10 <= x <= 20) with if/else',
      noteAr: 'تدعم قدس المقارنة الرياضية المتسلسلة مثل 0 <= score <= 100!',
      noteEn: 'Quds supports natural math-style chained comparisons!',
      code: '''score = 84
if 90 <= score <= 100:
  print "امتياز"
else if 75 <= score < 90:
  print "جيد جداً ({score})"
else:
  print "بحاجة لتحسين"''',
    ),
    AcademyRuleExample(
      titleAr: 'المطابقة المتقدمة باستخدام match و when',
      titleEn: 'Pattern matching with match and when',
      noteAr: 'تختصر match القرارات المعقدة في جدول مقروء.',
      noteEn: 'match condenses complex branching into a readable table.',
      code: '''bmiLabel(bmi: double) -> String:
  return match bmi:
    x when x < 18.5: "نقص وزن"
    x when x < 25.0: "وزن مثالي ✓"
    x when x < 30.0: "زيادة طفيفة"
    _: "يُنصح بمتابعة صحية"

print "BMI 22.4 -> {bmiLabel(22.4)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تعبير if المضمّن وحارس if اللاحق',
      titleEn: 'Inline if expression & trailing guard',
      noteAr: 'كتابة قرارات قصيرة بوضوح دون كتل متعددة الأسطر.',
      noteEn: 'Express compact decisions cleanly on a single line.',
      code: '''stock = 3
badge = "متوفر" if stock > 0 else "نفد"
print "الحالة: {badge}"
print "تنبيه: الكمية منخفضة!" if stock <= 5''',
    ),
  ],
  'loops': [
    AcademyRuleExample(
      titleAr: 'جدول ضرب مصغّر بحلقتين متداخلتين و label',
      titleEn: 'Nested multiplication loop with label',
      noteAr: 'استخدام حلقات for المتداخلة مع break للتحكم الدقيق.',
      noteEn: 'Nested for loops with crisp break control.',
      code: '''for i in 1..3:
  var row = ""
  for j in 1..3:
    row = "{row}{i * j}  "
  print "الصف {i}: {row}"''',
    ),
    AcademyRuleExample(
      titleAr: 'حلقة while مع continue و break',
      titleEn: 'while loop with continue and break',
      noteAr: 'جمع الأعداد الفردية فقط حتى يتجاوز المجموع 20.',
      noteEn: 'Sums only odd numbers until the total exceeds 20.',
      code: '''var n = 0
var sum = 0
while n < 20:
  n += 1
  continue if n % 2 == 0
  sum += n
  break if sum > 20
print "توقّف عند n={n} بمجموع فردي={sum}"''',
    ),
    AcademyRuleExample(
      titleAr: 'حلقة repeat و for .. step و loop else',
      titleEn: 'Combining repeat, step, and loop else',
      noteAr: 'تعدّد صيغ الحلقات في قدس يمنحك أنسب أداة لكل موقف.',
      noteEn: 'Pick the clearest loop form for each task.',
      code: '''var steps = []
for var k = 1 while k <= 16 step k *= 2:
  steps.add(k)
print "قوى العدد 2: {steps}"''',
    ),
  ],
  'collections': [
    AcademyRuleExample(
      titleAr: 'قوائم مُشتقّة (List Comprehensions) مع التصفية',
      titleEn: 'Filtered list comprehensions',
      noteAr: 'بناء قوائم مصفّاة ومحوّلة في سطر واحد أنيق.',
      noteEn: 'Transform and filter collections in one expressive line.',
      code: '''cubes = [n * n * n for n in 1..6 if n % 2 == 1]
print "مكعبات الأعداد الفردية: {cubes}"''',
    ),
    AcademyRuleExample(
      titleAr: 'الخرائط map: والمجموعات الفريدة set:',
      titleEn: 'Maps (map:) and unique Sets (set:)',
      noteAr: 'صياغة قدس المعمارية تجعل هياكل البيانات سهلة القراءة.',
      noteEn: 'Indented map: and set: literals stay clean and readable.',
      code: '''menu = map:
  "قهوة": 12
  "شاي": 8
  "عصير": 15
uniqueTags = set:
  "حار"
  "بارد"
  "حار"
print "سعر القهوة = {menu["قهوة"]} | التصنيفات = {uniqueTags}"''',
    ),
    AcademyRuleExample(
      titleAr: 'شرائح القوائم (Slicing) والانتشار (...)',
      titleEn: 'List slicing and spread operator (...)',
      noteAr: 'دمج قوائم واقتطاع أجزاء منها بسهولة.',
      noteEn: 'Combine and slice lists cleanly.',
      code: '''a = [1, 2, 3]
b = [4, 5, 6]
merged = [...a, ...b]
print "المدمج: {merged}"
print "العناصر 1..4: {merged[1..4]}"''',
    ),
  ],
  'classes': [
    AcademyRuleExample(
      titleAr: 'كلاس قيمة (value class) مع == و copyWith',
      titleEn: 'Value class with automatic equality and copyWith',
      noteAr: 'مثالي لنماذج البيانات غير القابلة للتعديل.',
      noteEn: 'Ideal for clean immutable data models.',
      code: '''value class Task:
  title: String required
  done: bool = false

t1 = Task("تعلّم قدس")
t2 = t1.copyWith(done: true)
print "الأصل: {t1.title} (مكتمل={t1.done})"
print "المحدّث: {t2.title} (مكتمل={t2.done})"''',
    ),
    AcademyRuleExample(
      titleAr: 'الوراثة والخصائص المحسوبة وتحميل العوامل',
      titleEn: 'Inheritance, computed properties, and operator overloading',
      noteAr: 'تتكامل ميزات الكلاسات في قدس لبناء نماذج مجال غنية.',
      noteEn: 'Combine properties and operators for expressive domain models.',
      code: '''class Vec:
  x: double required
  y: double required
  property lenSq: double:
    get = x * x + y * y
  operator +(o: Vec) -> Vec = Vec(x + o.x, y + o.y)

v = Vec(2.0, 1.0) + Vec(1.0, 3.0)
print "({v.x}, {v.y}) · مربع الطول = {v.lenSq}"''',
    ),
    AcademyRuleExample(
      titleAr: 'باني مسمّى init + عضو static + تغليف private',
      titleEn: 'Named init, static factory, and private field',
      noteAr: 'تصميم واجهة كلاس محمية ونظيفة.',
      noteEn: 'Build clean encapsulated class APIs.',
      code: '''class BankAccount:
  private var _bal: int = 0
  init opening(initial: int):
    _bal = initial
  deposit(v: int):
    _bal += v
  balance() -> int = _bal

a = BankAccount.opening(500)
a.deposit(250)
print "الرصيد الحالي = {a.balance()}"''',
    ),
  ],
  'nullability': [
    AcademyRuleExample(
      titleAr: 'فك التغليف الآمن بـ if let و ?? و ?.',
      titleEn: 'Safe null handling with if let, ??, and ?.',
      noteAr: 'تعالج قدس غياب القيمة صراحةً دون أخطاء NullPointer مفاجئة.',
      noteEn: 'Explicit nullability prevents unexpected null crashes.',
      code: '''var email: String? = null
print "قبل التعيين: {email?.toUpperCase() ?? "غير مسجّل"}"
email = "ali@quds.dev"
if let e = email:
  print "بعد التعيين: {e.toUpperCase()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحديث مشروط بـ with? للأنواع القابلة لـ null',
      titleEn: 'Null-safe with? receiver blocks',
      noteAr: 'تنفّذ الكتلة فقط عند وجود كائن غير فارغ.',
      noteEn: 'Executes the configuration block only when non-null.',
      code: '''class Draft:
  var title: String = ""

var d: Draft? = Draft()
with? d:
  title = "مسودة الدرس الأول"
print "العنوان: {d?.title ?? "لا يوجد"}"''',
    ),
    AcademyRuleExample(
      titleAr: 'التمييز بين null وغياب المعامل بـ Optional',
      titleEn: 'Nullable parameters with safe defaults',
      noteAr: 'تمرير null بشكل صريح والتعامل معه بوضوح.',
      noteEn: 'Handle explicit null arguments cleanly.',
      code: '''displayName(nick: String?, fallback: String = "زائر") -> String:
  return nick ?? fallback

print displayName(null)
print displayName("نور")''',
    ),
  ],
  'modules': [
    AcademyRuleExample(
      titleAr: 'استيراد أقسام مكتبة الرياضيات (::vector و ::geometry)',
      titleEn: 'Importing specialized sections from quds:math',
      noteAr:
          'تسمح قدس باستيراد أقسام محددة مثل quds:math::vector مع مرشح show.',
      noteEn: 'Import targeted library sections using ::section and show.',
      code: '''use quds:math::vector show Vec2
use quds:math::geometry show polygonCentroid

tri = [Vec2(0.0, 0.0), Vec2(6.0, 0.0), Vec2(0.0, 3.0)]
c = polygonCentroid(tri)
print "مركز ثقل المثلث = ({c.x}, {c.y})"''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام البادئة as ومرشّح hide لمنع التضارب',
      titleEn: 'Avoiding collisions with as and hide',
      noteAr: 'أدوات الاستيراد تضمن عدم تداخل الأسماء في المشاريع الكبيرة.',
      noteEn: 'Prefixes and hide filters keep large projects conflict-free.',
      code: '''use quds:math as m
use dart:math as dm
print "gcd(54, 24) = {m.gcd(54, 24)}"
print "sqrt(169) = {dm.sqrt(169.0)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'التحميل الكسول لمكتبة عبر deferred',
      titleEn: 'Deferred lazy library loading',
      noteAr: 'تحميل المكتبة وقت الحاجة فقط عبر await prefix.loadLibrary().',
      noteEn: 'Load libraries on demand via await prefix.loadLibrary().',
      code: '''use dart:math as m deferred
run() async:
  await m.loadLibrary()
  print "cos(0) بعد التحميل الكسول = {m.cos(0.0)}"

await run()''',
    ),
  ],
  'conversions': [
    AcademyRuleExample(
      titleAr: 'مقارنة to و to? مع مدخلات صالحة وخاطئة',
      titleEn: 'Comparing to vs safe to? on mixed inputs',
      noteAr: 'to يرمي خطأ عند الفشل بينما to? يعيد null بأمان.',
      noteEn: 'to throws on invalid input; to? returns null safely.',
      code: '''a = "256" to int
b = "3.5" to double
c = "bad" to? int
print "256 to int = {a}"
print "3.5 to double = {b}"
print "bad to? int = {c}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحويل مخصّص explicit cast + توسيع extend',
      titleEn: 'Custom explicit cast + extend methods',
      noteAr: 'بناء تحويلات نظيفة وذات دلالة لأنواعك الخاصة.',
      noteEn: 'Define meaningful conversions for custom domain types.',
      code: '''class Km:
  value: double required
  explicit cast(k: Km) -> double:
    return k.value * 1000.0

meters = Km(3.25) to double
print "3.25 كم = {meters} متر"''',
    ),
    AcademyRuleExample(
      titleAr: 'توسيع نوع مدمج بـ extend مع التحويل الآمن',
      titleEn: 'Combining extend with safe to? conversion',
      noteAr: 'إضافة دالة parseOrZero مباشرة على String!',
      noteEn: 'Attach a parseOrZero helper directly to String!',
      code: '''extend String:
  parseOrZero() -> int = (this to? int) ?? 0

print "75 -> {"75".parseOrZero()}"
print "oops -> {"oops".parseOrZero()}"''',
    ),
  ],
  'packages': [
    AcademyRuleExample(
      titleAr: 'تحليل البيانات والإحصاء عبر مكتبة quds:data و quds:math',
      titleEn: 'Data analysis with quds:data and quds:math',
      noteAr: 'توفّر المكتبات المدمجة تحليل الإحصاءات وتطبيع الإشارات مباشرة داخل المفسّر.',
      noteEn: 'Built-in libraries provide statistical analysis and signal normalization live.',
      code: '''use quds:math show mean, median
use quds:data as data
vals = [12.0, 18.0, 24.0, 30.0, 36.0]
norm = data.normalize(vals)
print "المتوسط = {mean(vals)} | الوسيط = {median(vals)}"
print "القيم المطبّعة [0..1] = {norm}"''',
    ),
    AcademyRuleExample(
      titleAr: 'دوال async و await للتعامل مع العمليات غير المتزامنة',
      titleEn: 'Async/await workflow simulation',
      noteAr: 'نفس أسلوب await المستخدم مع قواعد بيانات sqlite_plus والشبكات.',
      noteEn:
          'Same async/await pattern used with sqlite_plus and network APIs.',
      code: '''queryRow(id: int) async -> String:
  return "السجل #{id}: أكاديمية قدس (مكتمل)"

row1 = await queryRow(1)
row2 = await queryRow(2)
print row1
print row2''',
    ),
    AcademyRuleExample(
      titleAr: 'تنفيذ استعلامات متزامنة معاً بـ await all:',
      titleEn: 'Concurrent async queries with await all:',
      noteAr: 'تشغيل عدة استعلامات في آن واحد وجمع نتائجها بترتيب المصدر.',
      noteEn: 'Run multiple async queries concurrently and collect results in order.',
      code: '''countUsers() async -> int = 120
countLessons() async -> int = 12

stats = await all:
  countUsers()
  countLessons()

print "إحصاءات قاعدة البيانات (مستخدمون، دروس): {stats}"''',
    ),
  ],
};
