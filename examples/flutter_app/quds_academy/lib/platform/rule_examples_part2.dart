/// Executable Quds Rule Examples — Part 2:
/// Categories 5–8: Members & Access, Conversions & Augmentation, Libraries & Interop, Async & Concurrency.
library;

import 'rule_examples_model.dart';

const Map<String, List<AcademyRuleExample>> ruleExamplesPart2 = {
  // ── 5. Members & Access (13) ─────────────────────────────────────────────
  'this': [
    AcademyRuleExample(
      titleAr: 'التمييز بين الحقل والمعامل باستخدام this',
      titleEn: 'Disambiguating fields and parameters with this',
      noteAr: 'يشير this إلى الكائن الحالي ويُستخدم أيضاً في باني التهيئة this.field.',
      noteEn:
          'this refers to the current instance and initializes fields in init.',
      code: '''class Box:
  var width: int = 0
  init(this.width: int):
    ok = true
  resize(width: int):
    this.width = width

b = Box(10)
b.resize(25)
print "العرض الجديد = {b.width}"''',
    ),
    AcademyRuleExample(
      titleAr: 'سلسلة استدعاءات (Fluent API) بإرجاع this',
      titleEn: 'Fluent method chaining returning this',
      noteAr: 'إرجاع this يمكّنك من وصل عدة استدعاءات بسطر واحد.',
      noteEn: 'Returning this enables clean fluent method chaining.',
      code: '''class Builder:
  var text: String = ""
  add(part: String) -> Builder:
    this.text = "{this.text}{part}"
    return this

b = Builder().add("لغة ").add("قدس ").add("1.2")
print b.text''',
    ),
  ],
  'super': [
    AcademyRuleExample(
      titleAr: 'تمرير معامل التهيئة للأب باستخدام super.field',
      titleEn: 'Forwarding constructor parameters via super',
      noteAr: 'يُمرّر super.name قيمة المعامل مباشرة إلى الكلاس الأب.',
      noteEn: 'super.field forwards initializer arguments cleanly to the superclass.',
      code: '''class Person:
  name: String required
  greet() -> String = "مرحباً {name}"

class Teacher extends Person:
  subject: String required
  init(super.name: String, this.subject: String):
    ok = true
  intro() -> String = "{greet()} — مدرّس {subject}"

t = Teacher("خالد", "الفيزياء")
print t.intro()''',
    ),
    AcademyRuleExample(
      titleAr: 'استدعاء دالة الكلاس الأب عبر super',
      titleEn: 'Calling superclass method via super',
      noteAr:
          'يتيح super البناء فوق تنفيذ الكلاس الأب بدلاً من استبداله كلياً.',
      noteEn:
          'super lets subclasses extend rather than replace parent behavior.',
      code: '''class Logger:
  format(m: String) -> String = "[INFO] {m}"

class StarLogger extends Logger:
  format(m: String) -> String = "★ {super.format(m)}"

print StarLogger().format("تم التشغيل")''',
    ),
  ],
  'init': [
    AcademyRuleExample(
      titleAr: 'باني رئيسي وباني مسمّى باستخدام init',
      titleEn: 'Primary and named constructors with init',
      noteAr:
          'لا تعيد قدس اسم الكلاس في الباني؛ تستخدم init أو init name(...).',
      noteEn: 'Constructors use init instead of repeating the class name.',
      code: '''class Point:
  x: int
  y: int
  init(this.x: int, this.y: int):
    ok = true
  init origin():
    this.x = 0
    this.y = 0
  show() -> String = "({x}, {y})"

print Point(3, 7).show()
print Point.origin().show()''',
    ),
    AcademyRuleExample(
      titleAr: 'التحقق من القيم داخل جسم الباني init',
      titleEn: 'Validating inputs inside init body',
      noteAr:
          'يمكنك التحقق من صحة المدخلات أو تهيئة القيم المشتقة في جسم init.',
      noteEn: 'Validate inputs or compute derived fields inside init.',
      code: '''class Temperature:
  c: double
  f: double
  init(this.c: double):
    this.f = c * 9.0 / 5.0 + 32.0

t = Temperature(25.0)
print "{t.c}°C = {t.f}°F"''',
    ),
  ],
  'factory': [
    AcademyRuleExample(
      titleAr: 'باني مصنع (factory init) لإنشاء حالات جاهزة',
      titleEn: 'Factory constructor producing preset instances',
      noteAr: 'يعيد factory init كائناً مُنشأً منطقياً دون تهيئة this مباشرة.',
      noteEn: 'factory init returns a constructed instance via custom logic.',
      code: '''class ColorRgb:
  r: int required
  g: int required
  b: int required
  factory init emerald() -> ColorRgb = ColorRgb(20, 125, 100)
  hex() -> String = "rgb({r}, {g}, {b})"

c = ColorRgb.emerald()
print "اللون: {c.hex()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'factory init يختار قيماً افتراضية حسب الشرط',
      titleEn: 'Conditional factory constructor',
      noteAr: 'مناسب لتطبيع المدخلات قبل بناء الكائن.',
      noteEn: 'Great for normalizing inputs before creating an object.',
      code: '''class Page:
  size: int required
  factory init safe(n: int) -> Page:
    clamped = 10 if n < 1 else n
    return Page(clamped)

print "حجم صفحة (-5) -> {Page.safe(-5).size}"
print "حجم صفحة (25) -> {Page.safe(25).size}"''',
    ),
  ],
  'static': [
    AcademyRuleExample(
      titleAr: 'دوال وحقول ثابتة على مستوى الكلاس (static)',
      titleEn: 'Static utility methods and fields on a class',
      noteAr: 'الأعضاء static تُستدعى عبر اسم الكلاس مباشرة دون إنشاء كائن.',
      noteEn:
          'static members belong to the class itself without instantiation.',
      code: '''class MathHelper:
  static square(n: int) -> int = n * n
  static cube(n: int) -> int = n * n * n

print "4^2 = {MathHelper.square(4)}"
print "3^3 = {MathHelper.cube(3)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'عدّاد مشترك بين كل الكائنات بـ static var',
      titleEn: 'Shared instance counter using static var',
      noteAr: 'يشترك حقل static بين جميع نسخ الكلاس.',
      noteEn: 'A static var field is shared across every instance.',
      code: '''class Session:
  static var count: int = 0
  id: int
  init():
    Session.count += 1
    this.id = Session.count

s1 = Session()
s2 = Session()
print "الجلسات المنشأة = {Session.count} (آخر معرف: {s2.id})"''',
    ),
  ],
  'private': [
    AcademyRuleExample(
      titleAr: 'تغليف الرصيد بحقل private داخل الكلاس',
      titleEn: 'Encapsulating internal state with private',
      noteAr: 'يقصر private الوصول على المكتبة المعرّفة ويحمي الحالة الداخلية.',
      noteEn:
          'private scopes members to their library for clean encapsulation.',
      code: '''class Wallet:
  private var balance: int = 0
  deposit(amount: int):
    if amount > 0:
      balance += amount
  readBalance() -> int = balance

w = Wallet()
w.deposit(150)
w.deposit(50)
print "الرصيد المحمي = {w.readBalance()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'دالة مساعدة خاصة private داخل كلاس',
      titleEn: 'Private helper method inside a class',
      noteAr: 'فصل التفاصيل الداخلية عن الواجهة العامة للكلاس.',
      noteEn: 'Keeps helper logic hidden from the public API.',
      code: '''class Greeter:
  private clean(s: String) -> String = s.trim()
  welcome(raw: String) -> String = "أهلاً {clean(raw)}!"

print Greeter().welcome("  مريم  ")''',
    ),
  ],
  'protected': [
    AcademyRuleExample(
      titleAr: 'حقل protected متاح للكلاس الفرعي',
      titleEn: 'Protected member accessible to subclasses',
      noteAr: 'يتيح protected للكلاسات الفرعية قراءة وتحديث أعضاء الكلاس الأب.',
      noteEn: 'protected exposes parent internals to subclasses.',
      code: '''class BaseMeter:
  protected var ticks: int = 0
  current() -> int = ticks

class FastMeter extends BaseMeter:
  boost():
    ticks += 10

m = FastMeter()
m.boost()
m.boost()
print "القراءة = {m.current()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'دالة مساعدة protected تُستخدم في الكلاس الفرعي',
      titleEn: 'Protected helper invoked from a subclass',
      noteAr: 'مفيدة لبناء دوال قالبية (Template Method Pattern).',
      noteEn: 'Ideal for template-method designs across inheritance.',
      code: '''class ReportBase:
  protected header(t: String) -> String = "=== {t} ==="

class SalesReport extends ReportBase:
  render() -> String = "{header("المبيعات")} | الإجمالي: 5000"

print SalesReport().render()''',
    ),
  ],
  'required': [
    AcademyRuleExample(
      titleAr: 'حقول مطلوبة (required) في باني الكلاس التلقائي',
      titleEn: 'Required class fields in synthesized constructor',
      noteAr: 'يفرض required تمرير القيمة عند إنشاء الكائن بالترتيب أو بالاسم.',
      noteEn: 'required fields must be passed positionally or by name.',
      code: '''class Course:
  title: String required
  hours: int = 10
  info() -> String = "{title} ({hours} ساعات)"

c1 = Course("مقدمة قدس")
c2 = Course(title: "خوارزميات", hours: 24)
print c1.info()
print c2.info()''',
    ),
    AcademyRuleExample(
      titleAr: 'معامل دالة مسمّى ومطلوب (required)',
      titleEn: 'Required named function parameter',
      noteAr: 'معاملات الدوال في قدس تدعم التمرير بالاسم بوضوح تام.',
      noteEn: 'Required parameters ensure callers supply essential arguments.',
      code: '''sendEmail(to: String required, subject: String = "ترحيب"):
  print "إلى: {to} | الموضوع: {subject}"

sendEmail(to: "dev@quds.dev")
sendEmail(to: "team@quds.dev", subject: "تحديث الإصدار")''',
    ),
  ],
  'property': [
    AcademyRuleExample(
      titleAr: 'خاصية محسوبة للقراءة فقط (property + get)',
      titleEn: 'Computed read-only property',
      noteAr: 'تعرّف property حقلاً محسوباً يُقرأ كالحقل العادي دون أقواس.',
      noteEn: 'property exposes computed values with clean field-like access.',
      code: '''class Square:
  side: double required
  property area: double:
    get = side * side
  property perimeter: double:
    get = side * 4.0

s = Square(5.0)
print "المساحة = {s.area} | المحيط = {s.perimeter}"''',
    ),
    AcademyRuleExample(
      titleAr: 'خاصية بقارئ وكاتب (get و set) مع تحقق',
      titleEn: 'Read-write property with validation in set',
      noteAr: 'يسمح set بالتحقق من القيمة الجديدة قبل تخزينها.',
      noteEn: 'set validates incoming assignments before mutating state.',
      code: '''class Volume:
  var _level: int = 50
  property level: int:
    get = _level
    set(v):
      if v < 0:
        _level = 0
      else if v > 100:
        _level = 100
      else:
        _level = v

vol = Volume()
vol.level = 140
print "مستوى الصوت (مقصوص عند 100) = {vol.level}"
vol.level = 35
print "مستوى الصوت = {vol.level}"''',
    ),
  ],
  'get': [
    AcademyRuleExample(
      titleAr: 'قارئ خاصية بجسم تعبيري (get = ...)',
      titleEn: 'Expression-body property getter',
      noteAr: 'صيغة موجزة لحساب خاصية مباشرة من حقول الكائن.',
      noteEn: 'Concise getter syntax for derived properties.',
      code: '''class FullName:
  first: String required
  last: String required
  property full: String:
    get = "{first} {last}"

p = FullName("سلمى", "المنصور")
print "الاسم الكامل: {p.full}"''',
    ),
    AcademyRuleExample(
      titleAr: 'قارئ خاصية بكتلة تعليمات (get:)',
      titleEn: 'Multiline block getter',
      noteAr: 'يُستخدم get: مع return صريح عندما يتطلب الحساب عدة خطوات.',
      noteEn: 'Use multiline get: with explicit return for richer logic.',
      code: '''class Cart:
  prices: List<int> required
  property total: int:
    get:
      var sum = 0
      for p in prices:
        sum += p
      return sum

c = Cart([30, 45, 25])
print "إجمالي السلة = {c.total}"''',
    ),
  ],
  'set': [
    AcademyRuleExample(
      titleAr: 'بناء مجموعة عناصر فريدة باستخدام set:',
      titleEn: 'Unique set collection literal (set:)',
      noteAr: 'تُزيل set: التكرار تلقائياً وتحتفظ بالقيم الفريدة فقط.',
      noteEn: 'set: builds a collection of unique elements automatically.',
      code: '''tags = set:
  "quds"
  "dart"
  "quds"
  "flutter"
print "الوسوم الفريدة ({tags.length}): {tags}"''',
    ),
    AcademyRuleExample(
      titleAr: 'كاتب خاصية (set) لتطبيع النص',
      titleEn: 'Property setter normalizing text',
      noteAr: 'ينظّف set المدخلات تلقائياً عند كل إسناد للخاصية.',
      noteEn: 'A property setter automatically normalizes assigned values.',
      code: '''class Handle:
  var _raw: String = ""
  property name: String:
    get = _raw
    set(v):
      _raw = "@{v.trim().toLowerCase()}"

h = Handle()
h.name = "  QudsLang  "
print "المعرّف: {h.name}"''',
    ),
  ],
  'operator': [
    AcademyRuleExample(
      titleAr: 'تحميل عاملي الجمع والطرح (+ و -) لمتجه ثنائي',
      titleEn: 'Overloading + and - operators on Vec2D',
      noteAr: 'تتيح operator كتابة عمليات رياضية طبيعية على أنواعك الخاصة.',
      noteEn: 'operator enables natural mathematical syntax on custom types.',
      code: '''class Vec2D:
  x: double required
  y: double required
  operator +(other: Vec2D) -> Vec2D = Vec2D(x + other.x, y + other.y)
  operator -(other: Vec2D) -> Vec2D = Vec2D(x - other.x, y - other.y)
  show() -> String = "({x}, {y})"

a = Vec2D(3.0, 4.0)
b = Vec2D(1.0, 2.0)
print "a + b = {(a + b).show()}"
print "a - b = {(a - b).show()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحميل عامل الضرب (*) لتكرار نص أو قياس متجه',
      titleEn: 'Overloading * operator for scalar scaling',
      noteAr: 'يمكن تحميل * لتوسيع القيم بمعامل عددي.',
      noteEn: 'Overload * to scale custom numeric structures.',
      code: '''class Money:
  cents: int required
  operator *(factor: int) -> Money = Money(cents * factor)
  show() -> String = "{cents / 100.0} USD"

m = Money(250) * 4
print "المبلغ = {m.show()}"''',
    ),
  ],
  'annotation': [
    AcademyRuleExample(
      titleAr: 'تعريف بيانات وصفية (annotation) وإرفاقها بكلاس',
      titleEn: 'Declaring and attaching custom @annotation metadata',
      noteAr:
          'تعرّف annotation بيانات وصفية ثابتة تُرفق بالتصريحات باستخدام @.',
      noteEn: 'annotation declares constant metadata applied via @Name.',
      code: '''annotation Author(name: String):

@Author(name: "Quds Team")
class LibraryInfo:
  version: String = "1.2"

info = LibraryInfo()
print "مكتبة موثّقة · الإصدار {info.version}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام أكثر من annotation على دالة وكلاس',
      titleEn: 'Multiple annotations on classes and functions',
      noteAr: 'يمكن إرفاق عدة بيانات وصفية لتوثيق الأدوار والخصائص.',
      noteEn: 'Stack multiple annotations cleanly for metadata.',
      code: '''annotation Route(path: String):
annotation Pure():

@Route(path: "/courses")
@Pure()
getCoursesCount() -> int = 12

print "عدد الدورات عبر المسار /courses = {getCoursesCount()}"''',
    ),
  ],

  // ── 6. Conversions & Augmentation (7) ────────────────────────────────────
  'to': [
    AcademyRuleExample(
      titleAr: 'تحويل صريح بين النصوص والأعداد باستخدام to',
      titleEn: 'Explicit conversion between String, int, and double',
      noteAr: 'to يُجري تحويلاً صريحاً (QUDS-082) مختلفاً عن فحص النوع as.',
      noteEn:
          'to performs explicit value conversion, distinct from type cast as.',
      code: '''n = "42" to int
d = "3.14" to double
s = 2026 to String
print "int={n}, double={d}, String={s}"
print "n + 8 = {n + 8}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحويل الأعداد العشرية والصحيحة مع to',
      titleEn: 'Numeric conversions with to int / to double',
      noteAr: 'لا توجد تحويلات ضمنية خطرة؛ كل تحويل رقمي يُكتب بوضوح بـ to.',
      noteEn:
          'Explicit numeric conversions keep precision intent crystal clear.',
      code: '''exact = 9.87
whole = exact to int
asDouble = 15 to double
print "9.87 -> int: {whole}"
print "15 -> double: {asDouble}"''',
    ),
  ],
  'to?': [
    AcademyRuleExample(
      titleAr: 'تحويل آمن يعيد null عند الفشل دون استثناء (to?)',
      titleEn: 'Safe conversion returning null on failure (to?)',
      noteAr: 'مثالي لتحليل مدخلات المستخدم دون الحاجة لكتلة try/catch.',
      noteEn: 'Ideal for parsing user input without try/catch boilerplate.',
      code: '''good = "128" to? int
bad = "abc" to? int
print "صالح: {good}"
print "غير صالح: {bad}"
print "مع قيمة بديلة: {bad ?? 0}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تصفية قائمة مدخلات نصية باستخدام to?',
      titleEn: 'Filtering mixed string inputs using to?',
      noteAr: 'جمع الأرقام الصالحة فقط وتجاهل النصوص التالفة بأمان.',
      noteEn: 'Collects only valid integers from raw string inputs.',
      code: '''inputs = ["10", "oops", "25", "??", "5"]
var sum = 0
for raw in inputs:
  if let num = raw to? int:
    sum += num
print "مجموع القيم الصالحة = {sum}"''',
    ),
  ],
  'extend': [
    AcademyRuleExample(
      titleAr: 'إضافة دوال امتداد جديدة لنوع int عبر extend',
      titleEn: 'Extending int with helper methods',
      noteAr: 'تضيف extend دوال مريحة لأنواع موجودة دون تعديلها أو وراثتها.',
      noteEn: 'extend adds convenient methods to existing types cleanly.',
      code: '''extend int:
  doubled() -> int = this * 2
  isEvenNum() -> bool = this % 2 == 0

print "7.doubled() = {7.doubled()}"
print "8 زوجي؟ {8.isEvenNum()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'توسيع النصوص String بدالة اقتباس مخصّصة',
      titleEn: 'Extending String with custom formatting',
      noteAr: 'اجعل عمليات التنسيق المتكررة تبدو جزءاً أصيلاً من النوع.',
      noteEn: 'Make frequent string helpers feel native to String.',
      code: '''extend String:
  quoted() -> String = "«{this}»"

print "أكاديمية قدس".quoted()''',
    ),
  ],
  'augment': [
    AcademyRuleExample(
      titleAr: 'تعزيز كلاس موجود بدوال إضافية باستخدام augment',
      titleEn: 'Augmenting a class with extra methods',
      noteAr: 'تسمح augment بتقسيم وتنظيم سلوك النوع دون وراثة.',
      noteEn: 'augment merges additional methods into an existing type.',
      code: '''class Account:
  owner: String required
  balance: int required

augment Account:
  summary() -> String = "حساب {owner}: {balance} دينار"

acc = Account("طارق", 420)
print acc.summary()''',
    ),
    AcademyRuleExample(
      titleAr: 'إضافة تحويل مخصّص إلى نوع عبر augment',
      titleEn: 'Adding a helper conversion method via augment',
      noteAr: 'يمكن استخدام augment لتنظيم التحويلات والوظائف التكميلية.',
      noteEn: 'Organize domain helpers and conversions cleanly via augment.',
      code: '''class Celsius:
  value: double required

augment Celsius:
  toFahrenheit() -> double = value * 1.8 + 32.0

c = Celsius(30.0)
print "30°C = {c.toFahrenheit()}°F"''',
    ),
  ],
  'implicit': [
    AcademyRuleExample(
      titleAr: 'تعريف تحويل مخصّص implicit cast داخل كلاس',
      titleEn: 'Declaring an implicit cast conversion inside a class',
      noteAr:
          'تُعرّف implicit cast تحويلاً من نوع مصدر واحد إلى النوع المستهدف.',
      noteEn: 'implicit cast declares a single-hop expected-type conversion.',
      code: '''class Meter:
  val: double required
  implicit cast(source: int) -> Meter:
    return Meter(source to double)
  show() -> String = "{val} م"

m = 5 to Meter
print "التحويل: {m.show()}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحويل مخصّص لنوع ملف تعريف مستخدم',
      titleEn: 'Custom conversion to a wrapper class',
      noteAr: 'يبقى التحويل صريح النطاق ومحدداً داخل الكلاس بخطوة واحدة.',
      noteEn: 'Resolution is static and strictly one hop.',
      code: '''class Label:
  text: String required
  implicit cast(s: String) -> Label:
    return Label("[{s}]")

lbl = "Quds" to Label
print lbl.text''',
    ),
  ],
  'explicit': [
    AcademyRuleExample(
      titleAr: 'تحويل صريح explicit cast يُستدعى عبر to',
      titleEn: 'Explicit custom conversion invoked with to',
      noteAr:
          'يتطلب explicit cast كتابة عامل to أو to? صراحةً عند موضع الاستدعاء.',
      noteEn:
          'explicit cast always requires explicit to / to? at the call site.',
      code: '''class Score:
  points: int required
  explicit cast(source: Score) -> String:
    return "{source.points} نقطة"

s = Score(95)
print s to String''',
    ),
    AcademyRuleExample(
      titleAr: 'تحويل explicit cast آمن مع to?',
      titleEn: 'Safe explicit cast with to?',
      noteAr: 'تعمل explicit cast بسلاسة مع كل من to و to?.',
      noteEn: 'Works seamlessly with both to and safe to?.',
      code: '''class BoxInt:
  n: int required
  explicit cast(b: BoxInt) -> int:
    return b.n

b = BoxInt(77)
print "القيمة المستخرجة = {b to int}"''',
    ),
  ],
  'cast': [
    AcademyRuleExample(
      titleAr: 'استخدام explicit cast لتحويل كائن إلى رقم',
      titleEn: 'Using explicit cast inside a class body',
      noteAr:
          'تأتي cast بعد implicit أو explicit لتعريف دالة التحويل داخل النوع.',
      noteEn: 'cast follows implicit/explicit to declare a conversion body.',
      code: '''class Kilogram:
  kg: double required
  explicit cast(k: Kilogram) -> double:
    return k.kg * 1000.0

grams = Kilogram(2.5) to double
print "2.5 كغ = {grams} غرام"''',
    ),
    AcademyRuleExample(
      titleAr: 'تحويل بين كلاسين مخصّصين عبر explicit cast',
      titleEn: 'Converting between two domain classes with cast',
      noteAr: 'يبني تحويلات واضحة وقابلة للقراءة بين نماذج البيانات.',
      noteEn: 'Defines clean, readable conversions between domain models.',
      code: '''class Seconds:
  val: int required
class Minutes:
  val: double required
  explicit cast(s: Seconds) -> Minutes:
    return Minutes(s.val / 60.0)

m = Seconds(150) to Minutes
print "150 ثانية = {m.val} دقيقة"''',
    ),
  ],

  // ── 7. Libraries & Interoperability (8) ──────────────────────────────────
  'use': [
    AcademyRuleExample(
      titleAr: 'استيراد مكتبة الرياضيات القياسية quds:math',
      titleEn: 'Importing quds:math standard library',
      noteAr: 'تستورد use المكتبات القياسية أو الحزم أو الملفات النسبية.',
      noteEn:
          'use imports Quds standard libraries, packages, or local modules.',
      code: '''use quds:math
print "gcd(42, 30) = {gcd(42, 30)}"
print "lcm(12, 18) = {lcm(12, 18)}"
print "sin(pi/2) = {sin(pi / 2).toStringAsFixed(2)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استيراد مكتبة ببادئة مخصّصة (use .. as)',
      titleEn: 'Prefixed import with use .. as',
      noteAr: 'تمنع البادئة تضارب الأسماء وتوضح مصدر كل دالة.',
      noteEn: 'Prefixes prevent name collisions and clarify call origins.',
      code: '''use dart:math as m
print "sqrt(144) = {m.sqrt(144.0)}"
print "max(19, 42) = {m.max(19, 42)}"''',
    ),
  ],
  'export': [
    AcademyRuleExample(
      titleAr: 'تنظيم واجهة مكتبة موحّدة (Barrel Pattern)',
      titleEn: 'Understanding library re-exports and public APIs',
      noteAr: 'تعيد export تصدير أسماء من مكتبة فرعية لتسهيل استيرادها من نقطة واحدة.',
      noteEn:
          'export re-exports selected symbols to form clean facade modules.',
      code: '''use quds:math show gcd, lcm
# في ملف واجهة (barrel) نكتب: export quds:math show gcd, lcm
print "واجهة موحّدة: gcd(24, 16) = {gcd(24, 16)}, lcm(6, 8) = {lcm(6, 8)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام الدوال المُعاد تصديرها من أقسام quds:math',
      titleEn: 'Using re-exported math sections',
      noteAr:
          'مكتبة quds:math نفسها تعيد تصدير أقسامها (vector, geometry, stats).',
      noteEn:
          'quds:math itself uses export to expose its specialized sections.',
      code: '''use quds:math::vector show Vec2
v1 = Vec2(3.0, 4.0)
print "طول المتجه (3, 4) = {v1.length()}"''',
    ),
  ],
  'show': [
    AcademyRuleExample(
      titleAr: 'استيراد انتقائي لأسماء محددة بـ show',
      titleEn: 'Selective import with show',
      noteAr: 'يقصر show الاستيراد على الرموز التي تحتاجها فقط لنظافة النطاق.',
      noteEn: 'show imports only the named symbols you actually need.',
      code: '''use quds:math show sqrt, gcd, pi
print "pi ≈ {pi.toStringAsFixed(4)}"
print "sqrt(25) = {sqrt(25.0)}"
print "gcd(45, 30) = {gcd(45, 30)}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استيراد انتقائي من قسم فرعي (::section show)',
      titleEn: 'Selective section import with ::section show',
      noteAr: 'ادمج اختيار القسم مع مرشّح show لدقة قصوى.',
      noteEn: 'Combine ::section selection with show for crisp imports.',
      code: '''use quds:math::vector show Vec2
a = Vec2(1.0, 2.0)
b = Vec2(4.0, 6.0)
print "المسافة = {a.distance(b)}"''',
    ),
  ],
  'hide': [
    AcademyRuleExample(
      titleAr: 'استثناء أسماء متضاربة باستخدام hide',
      titleEn: 'Excluding colliding names with hide',
      noteAr:
          'يستبعد hide أسماء محددة لتعريف دالتك الخاصة بنفس الاسم دون تعارض.',
      noteEn: 'hide excludes specific symbols so your own definition never collides.',
      code: '''use quds:math hide max
max(a: int, b: int) -> String:
  best = a if a > b else b
  return "الأكبر هو {best}"
print max(12, 27)''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام بقية دوال المكتبة بعد hide',
      titleEn: 'Using remaining library members after hide',
      noteAr: 'تظل جميع الدوال الأخرى في المكتبة متاحة بشكل طبيعي.',
      noteEn: 'All non-hidden library members remain directly available.',
      code: '''use quds:math hide tan
print "cos(0) = {cos(0.0)}"
print "gcd(18, 12) = {gcd(18, 12)}"''',
    ),
  ],
  'deferred': [
    AcademyRuleExample(
      titleAr: 'التحميل الكسول للمكتبات بـ deferred و loadLibrary()',
      titleEn: 'Lazy library loading with deferred and loadLibrary()',
      noteAr: 'تؤجّل deferred تحميل المكتبة حتى استدعاء await prefix.loadLibrary().',
      noteEn:
          'deferred delays library loading until await prefix.loadLibrary().',
      code: '''use dart:math as m deferred
loadAndCompute() async:
  await m.loadLibrary()
  print "تم تحميل المكتبة كسولاً: sqrt(49) = {m.sqrt(49.0)}"

await loadAndCompute()''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام عدة دوال بعد التحميل المؤجل',
      titleEn: 'Using multiple functions after deferred load',
      noteAr: 'بعد اكتمال loadLibrary() تصبح جميع رموز البادئة متاحة.',
      noteEn: 'Once loadLibrary() finishes, all prefixed members are ready.',
      code: '''use quds:math as qm deferred
run() async:
  await qm.loadLibrary()
  print "gcd(28, 35) = {qm.gcd(28, 35)}"
  print "lcm(4, 6) = {qm.lcm(4, 6)}"

await run()''',
    ),
  ],
  'when': [
    AcademyRuleExample(
      titleAr: 'حارس شرطي (when) داخل فروع match',
      titleEn: 'Match arm guard using when',
      noteAr: 'تضيف when شرطاً دقيقاً لفرع المطابقة فوق النمط الأساسي.',
      noteEn: 'when adds a boolean guard predicate to a match arm.',
      code: '''describeNum(n: int) -> String:
  return match n:
    x when x < 0: "عدد سالب ({x})"
    0: "صفر"
    x when x % 2 == 0: "موجب زوجي ({x})"
    x: "موجب فردي ({x})"

print describeNum(-4)
print describeNum(12)
print describeNum(9)''',
    ),
    AcademyRuleExample(
      titleAr: 'كتلة مشروطة وقت الترجمة باستخدام when condition:',
      titleEn: 'Conditional block with when condition:',
      noteAr: 'تنفّذ كتلة when عندما يتحقق الشرط الثابت.',
      noteEn: 'A standalone when block selects code conditionally.',
      code: '''const enableVerbose = true
when enableVerbose:
  print "الوضع التفصيلي مفعّل ✓"''',
    ),
  ],
  'part': [
    AcademyRuleExample(
      titleAr: 'تنظيم المكتبة الواحدة عبر عدة ملفات (part)',
      titleEn: 'Splitting one library across part files',
      noteAr: 'تجمع part عدة ملفات ضمن مكتبة واحدة تشارك الخصوصية نفسها.',
      noteEn: 'part unites source files into one shared library privacy scope.',
      code: '''# في المشروع متعدد الملفات:
# main.quds يحتوي: part src.helpers
# src/helpers.quds يحتوي: part of ^.main
part helpers
print "توجيه part يجمع الملفات ضمن مكتبة واحدة وخصوصية مشتركة ✓"''',
    ),
    AcademyRuleExample(
      titleAr: 'التعاون بين الأجزاء الخاصة داخل المكتبة نفسها',
      titleEn: 'Shared library-private access across parts',
      noteAr: 'يمكن لملفات part رؤية الأعضاء private في المكتبة نفسها.',
      noteEn: 'Part files share library-private declarations seamlessly.',
      code: '''class InternalHelper:
  private secretCode() -> String = "LIB-OK-2026"
  read() -> String = secretCode()

print "وصول مشترك داخل المكتبة: {InternalHelper().read()}"''',
    ),
  ],
  'of': [
    AcademyRuleExample(
      titleAr: 'ربط الملف الفرعي بالمكتبة المالكة (part of)',
      titleEn: 'Linking a part file to its owning library (part of)',
      noteAr: 'تُستخدم of حصراً في part of لتحديد المكتبة الأم بمسار نسبي مثل ^.main.',
      noteEn: 'of completes part of to point back to the owning library.',
      code: '''# داخل ملف فرعي نكتب: part of ^.main
# كلمة of سياقية ويمكن استخدامها كاسم متغير عادي خارج part of!
of = "Quds Library"
print "المكتبة المالكة: {of}"''',
    ),
    AcademyRuleExample(
      titleAr: 'توجيه part of بمسار صاعد (^.)',
      titleEn: 'Parent-relative library reference in part of',
      noteAr:
          'الرمز ^. يصعد مجلداً واحداً إلى الأعلى للوصول لملف المكتبة الأم.',
      noteEn: '^. climbs one directory upward to locate the owning library.',
      code: '''part of ^.main
print "تم ربط الملف الفرعي بالمكتبة الأم ^.main بنجاح ✓"''',
    ),
  ],

  // ── 8. Async & Concurrency (9) ───────────────────────────────────────────
  'async': [
    AcademyRuleExample(
      titleAr: 'تعريف دالة غير متزامنة (async) وانتظار نتيجتها',
      titleEn: 'Defining and awaiting an async function',
      noteAr: 'تُعلّم async الدالة كغير متزامنة وتسمح باستخدام await بداخلها.',
      noteEn:
          'async marks a function asynchronous and enables await inside it.',
      code: '''fetchScore() async -> int:
  return 96

score = await fetchScore()
print "النتيجة المحمّلة = {score}"''',
    ),
    AcademyRuleExample(
      titleAr: 'سلسلة استدعاءات غير متزامنة متتابعة',
      titleEn: 'Chaining multiple async steps',
      noteAr: 'تقرأ الشيفرة غير المتزامنة بوضوح كأنها متسلسلة.',
      noteEn: 'Async workflows read cleanly from top to bottom.',
      code: '''step1(x: int) async -> int = x + 10
step2(x: int) async -> int = x * 3

run() async -> int:
  a = await step1(5)
  b = await step2(a)
  return b

print "الناتج النهائي = {await run()}"''',
    ),
  ],
  'await': [
    AcademyRuleExample(
      titleAr: 'انتظار عملية غير متزامنة باستخدام await',
      titleEn: 'Awaiting an async computation',
      noteAr: 'تعلّق await تنفيذ الدالة الحالية حتى تجهز النتيجة دون تجميد البرنامج.',
      noteEn: 'await suspends cleanly until the async result completes.',
      code: '''loadTitle() async -> String:
  return "أكاديمية قدس"

title = await loadTitle()
print "تم التحميل: {title}"''',
    ),
    AcademyRuleExample(
      titleAr: 'استخدام await داخل تعبير حسابي مباشر',
      titleEn: 'Using await inline inside expressions',
      noteAr: 'يمكن دمج نتائج عدة استدعاءات await مباشرة داخل التعبير.',
      noteEn: 'Combine awaited results directly within arithmetic expressions.',
      code: '''getA() async -> int = 18
getB() async -> int = 24
total = (await getA()) + (await getB())
print "18 + 24 = {total}"''',
    ),
  ],
  'sync': [
    AcademyRuleExample(
      titleAr: 'مولّد متزامن sync* ينتج قيماً عند الطلب',
      titleEn: 'Synchronous generator with sync* and yield',
      noteAr: 'تُنشئ sync* مولّداً يعيد Iterable يُنتج العناصر تدريجياً.',
      noteEn: 'sync* defines a synchronous generator producing an Iterable.',
      code: '''evens(limit: int) sync* -> int:
  for i in 1..limit:
    if i % 2 == 0:
      yield i

var out = []
for v in evens(10):
  out.add(v)
print "الأعداد الزوجية المولّدة: {out}"''',
    ),
    AcademyRuleExample(
      titleAr: 'مولّد متتالية فيبوناتشي بـ sync*',
      titleEn: 'Fibonacci generator with sync*',
      noteAr: 'توليد متتاليات رياضية بأناقة وبدون قوائم مؤقتة.',
      noteEn:
          'Generate mathematical sequences cleanly without temporary lists.',
      code: '''fibGen(count: int) sync* -> int:
  var a = 0
  var b = 1
  repeat count:
    yield a
    next = a + b
    a = b
    b = next

var seq = []
for n in fibGen(8):
  seq.add(n)
print "فيبوناتشي: {seq}"''',
    ),
  ],
  'yield': [
    AcademyRuleExample(
      titleAr: 'إصدار عناصر متتابعة من مولّد باستخدام yield',
      titleEn: 'Emitting items one by one with yield',
      noteAr:
          'تُصدر yield عنصراً للمستهلك وتُكمل التنفيذ عند طلب العنصر التالي.',
      noteEn: 'yield emits an element and resumes on the next iteration.',
      code: '''countdown(start: int) sync* -> int:
  var n = start
  while n > 0:
    yield n
    n -= 1

for x in countdown(4):
  print "العدّ: {x}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تصفية وتحويل القيم باستخدام مولّد yield',
      titleEn: 'Transforming values inside a yield generator',
      noteAr: 'إنتاج مربعات الأعداد مباشرة أثناء التكرار.',
      noteEn: 'Produce squared values on the fly via yield.',
      code: '''squares(xs: List<int>) sync* -> int:
  for x in xs:
    yield x * x

var res = []
for s in squares([2, 4, 6]):
  res.add(s)
print "المربعات: {res}"''',
    ),
  ],
  'all': [
    AcademyRuleExample(
      titleAr: 'تنفيذ مهام متوازية معاً عبر await all:',
      titleEn: 'Running concurrent async tasks with await all:',
      noteAr: 'تشغّل await all: عدة مهام معاً وتعيد النتائج بالترتيب نفسه.',
      noteEn: 'await all: runs child tasks concurrently and returns results in order.',
      code: '''fetchUser() async -> String = "أحمد"
fetchPoints() async -> int = 350

res = await all:
  fetchUser()
  fetchPoints()

print "النتائج المتزامنة: {res}"''',
    ),
    AcademyRuleExample(
      titleAr: 'حساب ثلاث قيم بالتوازي مع await all:',
      titleEn: 'Three parallel computations via await all:',
      noteAr: 'مناسب لتجميع بيانات من عدة مصادر في وقت واحد.',
      noteEn: 'Ideal for gathering independent results simultaneously.',
      code: '''calcA() async -> int = 10 * 2
calcB() async -> int = 20 * 2
calcC() async -> int = 30 * 2

results = await all:
  calcA()
  calcB()
  calcC()

print "المخرجات: {results}"''',
    ),
  ],
  'isolate': [
    AcademyRuleExample(
      titleAr: 'تشغيل حساب ثقيل في عزل مستقل (await isolate:)',
      titleEn: 'Running heavy computation via await isolate:',
      noteAr: 'تنفّذ await isolate: استدعاءً معزولاً دون تجميد واجهة المستخدم.',
      noteEn: 'await isolate: offloads pure compute cleanly off the UI thread.',
      code: '''sumSquares(n: int) -> int:
  var total = 0
  for i in 1..n:
    total += i * i
  return total

ans = await isolate:
  sumSquares(20)

print "ناتج العزل المستقل = {ans}"''',
    ),
    AcademyRuleExample(
      titleAr: 'حساب رياضي معزول وإرجاع النتيجة',
      titleEn: 'Isolated factorial computation',
      noteAr: 'ترسل معاملات نقية وتستقبل النتيجة بأمان.',
      noteEn: 'Passes sendable arguments and receives the computed result.',
      code: '''fact(n: int) -> int:
  var r = 1
  for i in 2..n:
    r *= i
  return r

out = await isolate:
  fact(8)

print "8! داخل isolate = {out}"''',
    ),
  ],
  'task': [
    AcademyRuleExample(
      titleAr: 'تزامن منظّم باستخدام task group و spawn',
      titleEn: 'Structured concurrency with task group and spawn',
      noteAr:
          'تنتظر task group: اكتمال كافة المهام المتفرعة قبل مغادرة الكتلة.',
      noteEn: 'task group: waits for every spawned child task before exiting.',
      code: '''var done: List<String> = []
work(name: String) async:
  done.add(name)

task group:
  spawn work("المهمة 1")
  spawn work("المهمة 2")
  spawn work("المهمة 3")

print "اكتملت جميع المهام: {done}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تجميع نتائج عدة مهام متفرعة داخل task group',
      titleEn: 'Aggregating child work in a task group',
      noteAr: 'لا تُترك أي مهمة يتيمة بعد انتهاء كتلة task group.',
      noteEn: 'Guarantees no orphaned background tasks escape the block.',
      code: '''var sum = 0
addPart(v: int) async:
  sum += v

task group:
  spawn addPart(15)
  spawn addPart(25)
  spawn addPart(60)

print "مجموع المهام = {sum}"''',
    ),
  ],
  'group': [
    AcademyRuleExample(
      titleAr: 'تجميع اختبارات منطقية تحت group',
      titleEn: 'Grouping test cases under group',
      noteAr: 'تنظّم group الاختبارات المرتبطة تحت عنوان واحد واضح.',
      noteEn: 'group organizes related tests under a descriptive suite name.',
      code: '''group "حسابات أساسية":
  test "الجمع":
    assert 2 + 3 == 5
  test "الضرب":
    assert 4 * 5 == 20
print "اجتازت مجموعة الاختبارات بنجاح ✓"''',
    ),
    AcademyRuleExample(
      titleAr: 'إكمال التزامن المنظم بـ task group:',
      titleEn: 'Structured task group concurrency',
      noteAr: 'تعمل group أيضاً مع task لإنشاء نطاق مهام متزامنة.',
      noteEn: 'group also pairs with task for structured concurrency.',
      code: '''var log: List<int> = []
job(id: int) async:
  log.add(id)

task group:
  spawn job(1)
  spawn job(2)

print "المهام المنفذة: {log}"''',
    ),
  ],
  'spawn': [
    AcademyRuleExample(
      titleAr: 'تفريع مهام فرعية داخل task group عبر spawn',
      titleEn: 'Spawning concurrent child tasks',
      noteAr: 'تُجدول spawn مهمة طفلة داخل أقرب task group:.',
      noteEn: 'spawn schedules a child task inside the enclosing task group.',
      code: '''var messages: List<String> = []
emit(m: String) async:
  messages.add(m)

task group:
  spawn emit("تحميل الصور")
  spawn emit("تجهيز البيانات")

print "تم التنفيذ: {messages}"''',
    ),
    AcademyRuleExample(
      titleAr: 'تفريع عدة مهام حسابية متوازية بـ spawn',
      titleEn: 'Spawning multiple computation tasks in a task group',
      noteAr:
          'يحتوي task group على عبارات spawn مباشرة تكتمل جميعها قبل المتابعة.',
      noteEn: 'A task group holds direct spawn tasks that all finish before continuing.',
      code: '''var squares: List<int> = []
compute(n: int) async:
  squares.add(n * n)

task group:
  spawn compute(1)
  spawn compute(2)
  spawn compute(3)
  spawn compute(4)

print "النتائج: {squares}"''',
    ),
  ],
};
