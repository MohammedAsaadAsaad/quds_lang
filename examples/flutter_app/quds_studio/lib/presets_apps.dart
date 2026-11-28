/// 8 Interactive User Micro-Apps (`StudioCategory.apps`) demonstrating how
/// Quds powers real interactive forms, stateful tools, calculators, and
/// user-facing workflows inside the Register VM interpreter.
library;

import 'presets.dart';

final List<StudioPreset> studioAppPresets = [
  // 1. Smart Invoice & Tax Builder
  StudioPreset(
    id: 'app_invoice_builder',
    titleAr: '🧾 منشئ الفواتير والضرائب الذكي',
    titleEn: 'Smart Invoice & Tax Builder',
    subtitleAr:
        'تطبيق فوترة تفاعلي: اسم العميل، العملة، كميات، خصم وضريبة مضافة',
    fileName: 'invoice_builder.quds',
    category: StudioCategory.apps,
    code: r'''# تطبيق تفاعلي 1: منشئ الفواتير والضرائب الذكي
use quds:viz as viz

client = viz.input("client", value: "شركة الأفق للتقنية", label: "اسم العميل")
currency = viz.select("currency", ["USD", "SAR", "AED", "EUR"], value: "USD", label: "العملة")
designHrs = viz.slider("designHrs", min: 0.0, max: 40.0, value: 12.0, step: 1.0, label: "ساعات التصميم (45/س)")
devHrs = viz.slider("devHrs", min: 0.0, max: 60.0, value: 24.0, step: 1.0, label: "ساعات التطوير (65/س)")
hosting = viz.toggle("hosting", value: true, label: "إضافة استضافة سنوية (+180)")
discountPct = viz.slider("discountPct", min: 0.0, max: 30.0, value: 10.0, step: 5.0, label: "نسبة الخصم (%)")
includeVat = viz.toggle("includeVat", value: true, label: "تطبيق ضريبة القيمة المضافة (15%)")

var rate = 1.0
if currency == "SAR":
  rate = 3.75
else if currency == "AED":
  rate = 3.67
else if currency == "EUR":
  rate = 0.92

designCost = designHrs * 45.0 * rate
devCost = devHrs * 65.0 * rate
var hostCost = 0.0
var hostQty = 0
if hosting:
  hostCost = 180.0 * rate
  hostQty = 1

subtotal = designCost + devCost + hostCost
discount = subtotal * (discountPct / 100.0)
afterDiscount = subtotal - discount
var vat = 0.0
if includeVat:
  vat = afterDiscount * 0.15
grandTotal = afterDiscount + vat

summary = map:
  "العميل": client
  "المجموع الفرعي": subtotal.toStringAsFixed(2) + " " + currency
  "الخصم": "-" + discount.toStringAsFixed(2) + " " + currency
  "الضريبة (15%)": vat.toStringAsFixed(2) + " " + currency
  "الإجمالي المستحق": grandTotal.toStringAsFixed(2) + " " + currency

rows = [
  ["تصميم واجهات UI/UX", designHrs.toInt(), (45.0 * rate).toStringAsFixed(2), designCost.toStringAsFixed(2)],
  ["تطوير وتكامل برمجي", devHrs.toInt(), (65.0 * rate).toStringAsFixed(2), devCost.toStringAsFixed(2)],
  ["استضافة سحابية سنوية", hostQty, (180.0 * rate).toStringAsFixed(2), hostCost.toStringAsFixed(2)]
]

viz.form(summary, title: "🧾 فاتورة إلكترونية — " + client, summary: "عدّل الساعات أو العملة أو الضريبة لحساب الفاتورة فوراً")
viz.table(["البند", "الكمية", "سعر الوحدة", "الإجمالي (" + currency + ")"], rows, title: "تفاصيل بنود الفاتورة")
print "فاتورة {client} | الإجمالي = {grandTotal.toStringAsFixed(2)} {currency}"
''',
  ),

  // 2. Stateful Task & Habit Tracker
  StudioPreset(
    id: 'app_task_habit_tracker',
    titleAr: '✅ مدير المهام التفاعلي (Stateful)',
    titleEn: 'Stateful Task & Habit Tracker',
    subtitleAr: 'أضف مهاماً وأنجزها بأزرار حية مع حفظ الحالة عبر viz.state',
    fileName: 'task_tracker.quds',
    category: StudioCategory.apps,
    code:
        r'''# تطبيق تفاعلي 2: مدير مهام حي يحفظ حالته بين الضغطات (viz.state + viz.button)
use quds:viz as viz

taskTitle = viz.input("taskTitle", value: "مراجعة معمارية قدس 1.2", label: "عنوان المهمة الجديدة")
priority = viz.select("priority", ["عالية 🔴", "متوسطة 🟡", "عادية 🟢"], value: "عالية 🔴", label: "الأولوية")
addClicks = viz.button("addTask", label: "➕ إضافة مهمة")
doneClicks = viz.button("completeOne", label: "✔️ إنجاز مهمة")
resetClicks = viz.button("resetTasks", label: "🔄 إعادة الضبط")

lastAdd = (viz.state("lastAdd", 0) as num).toInt()
lastDone = (viz.state("lastDone", 0) as num).toInt()
lastReset = (viz.state("lastReset", 0) as num).toInt()

var tasks = viz.state("tasks", [
  ["تجهيز مشروع متعدد الملفات", "عالية 🔴", "مكتملة ✅"],
  ["بناء إضافة خصومات ذكية", "متوسطة 🟡", "قيد التنفيذ ⏳"],
  ["اختبار الأصول assets/json", "عادية 🟢", "قيد التنفيذ ⏳"]
]) as List

if resetClicks != lastReset:
  tasks = [
    ["تجهيز مشروع متعدد الملفات", "عالية 🔴", "مكتملة ✅"],
    ["بناء إضافة خصومات ذكية", "متوسطة 🟡", "قيد التنفيذ ⏳"],
    ["اختبار الأصول assets/json", "عادية 🟢", "قيد التنفيذ ⏳"]
  ]
  viz.setState("lastReset", resetClicks)

if addClicks != lastAdd:
  trimmed = taskTitle.trim()
  var clean = "مهمة جديدة"
  if trimmed.length > 0:
    clean = trimmed
  tasks.add([clean, priority, "قيد التنفيذ ⏳"])
  viz.setState("lastAdd", addClicks)

if doneClicks != lastDone:
  var marked = false
  for t in tasks:
    if (not marked) and t[2] != "مكتملة ✅":
      t[2] = "مكتملة ✅"
      marked = true
  viz.setState("lastDone", doneClicks)

viz.setState("tasks", tasks)

var completed = 0
for t in tasks:
  if t[2] == "مكتملة ✅":
    completed = completed + 1
pending = tasks.length - completed
var pct = 0.0
if tasks.length > 0:
  pct = (completed * 100.0) / tasks.length

summary = map:
  "إجمالي المهام": tasks.length
  "المكتملة": completed
  "المتبقية": pending
  "نسبة الإنجاز": pct.toStringAsFixed(0) + "%"

viz.form(summary, title: "✅ لوحة المهام اليومية الحية", summary: "اضغط «➕ إضافة مهمة» أو «✔️ إنجاز مهمة» للتفاعل الفوري مع الحالة المحفوظة")
viz.table(["المهمة", "الأولوية", "الحالة"], tasks, title: "قائمة المهام الحالية")
print "المهام: {completed}/{tasks.length} مكتملة ({pct.toStringAsFixed(0)}%)"
''',
  ),

  // 3. Universal Unit & Currency Converter Hub
  StudioPreset(
    id: 'app_unit_currency_hub',
    titleAr: '🔄 محوّل الوحدات والعملات الشامل',
    titleEn: 'Unit & Currency Converter Hub',
    subtitleAr: 'تحويل فوري للطول، الوزن، الحرارة، والعملات مع جدول مقارنة',
    fileName: 'unit_converter.quds',
    category: StudioCategory.apps,
    code: r'''# تطبيق تفاعلي 3: محوّل الوحدات والعملات الشامل
use quds:viz as viz

domain = viz.select("domain", ["العملات 💱", "الطول 📏", "الحرارة 🌡️", "الوزن ⚖️"], value: "العملات 💱", label: "فئة التحويل")
val = viz.slider("val", min: 1.0, max: 1000.0, value: 100.0, step: 1.0, label: "القيمة المدخلة")

var rows: List<List<dynamic>> = []
var highlightKey = ""
var highlightVal = ""

if domain == "العملات 💱":
  highlightKey = "القيمة بالدولار (USD)"
  highlightVal = val.toStringAsFixed(2) + " USD"
  rows = [
    ["الريال السعودي (SAR)", (val * 3.75).toStringAsFixed(2), "3.75"],
    ["الدرهم الإماراتي (AED)", (val * 3.67).toStringAsFixed(2), "3.67"],
    ["اليورو (EUR)", (val * 0.92).toStringAsFixed(2), "0.92"],
    ["الجنيه الإسترليني (GBP)", (val * 0.79).toStringAsFixed(2), "0.79"],
    ["الدينار الأردني (JOD)", (val * 0.71).toStringAsFixed(2), "0.71"]
  ]
else if domain == "الطول 📏":
  highlightKey = "القيمة بالمتر (m)"
  highlightVal = val.toStringAsFixed(2) + " m"
  rows = [
    ["سنتيمتر (cm)", (val * 100.0).toStringAsFixed(1), "× 100"],
    ["كيلومتر (km)", (val / 1000.0).toStringAsFixed(4), "÷ 1000"],
    ["قدم (ft)", (val * 3.28084).toStringAsFixed(2), "× 3.281"],
    ["إنش (in)", (val * 39.3701).toStringAsFixed(2), "× 39.37"],
    ["ميل (mi)", (val / 1609.34).toStringAsFixed(4), "÷ 1609"]
  ]
else if domain == "الحرارة 🌡️":
  c = val / 10.0
  f = c * 9.0 / 5.0 + 32.0
  k = c + 273.15
  highlightKey = "مئوية (°C)"
  highlightVal = c.toStringAsFixed(1) + " °C"
  rows = [
    ["فهرنهايت (°F)", f.toStringAsFixed(2), "C×9/5 + 32"],
    ["كلفن (K)", k.toStringAsFixed(2), "C + 273.15"],
    ["رانكين (°R)", (k * 1.8).toStringAsFixed(2), "K × 1.8"]
  ]
else:
  highlightKey = "كيلوغرام (kg)"
  highlightVal = val.toStringAsFixed(2) + " kg"
  rows = [
    ["غرام (g)", (val * 1000.0).toStringAsFixed(0), "× 1000"],
    ["باوند (lb)", (val * 2.20462).toStringAsFixed(2), "× 2.205"],
    ["أونصة (oz)", (val * 35.274).toStringAsFixed(2), "× 35.27"],
    ["طن متري (t)", (val / 1000.0).toStringAsFixed(4), "÷ 1000"]
  ]

summary = map:
  "الفئة المختارة": domain
  "المدخل الأساسي": highlightKey + " = " + highlightVal
  "عدد الوحدات المقارنة": rows.length

viz.form(summary, title: "🔄 محوّل الوحدات والعملات الفوري", summary: "اختر الفئة وحرّك الشريط للحصول على تحويل فوري لجميع الوحدات")
viz.table(["الوحدة", "النتيجة", "المعامل"], rows, title: "جدول التحويلات — " + domain)
print "تحويل {domain}: {highlightVal}"
''',
  ),

  // 4. Restaurant & Group Bill Splitter
  StudioPreset(
    id: 'app_bill_splitter',
    titleAr: '🍽️ قاسم فاتورة المطعم والرحلات',
    titleEn: 'Group Bill & Tip Splitter',
    subtitleAr: 'تقسيم عادل للفاتورة والبقشيش والضريبة مع خيار تقريب المبلغ',
    fileName: 'bill_splitter.quds',
    category: StudioCategory.apps,
    code: r'''# تطبيق تفاعلي 4: قاسم فاتورة المطعم والرحلات
use quds:viz as viz

bill = viz.slider("bill", min: 20.0, max: 1200.0, value: 240.0, step: 10.0, label: "مبلغ الفاتورة ($)")
people = viz.slider("people", min: 1.0, max: 15.0, value: 4.0, step: 1.0, label: "عدد الأشخاص").toInt()
tipPct = viz.slider("tipPct", min: 0.0, max: 25.0, value: 12.0, step: 1.0, label: "نسبة الخدمة/البقشيش (%)")
taxPct = viz.slider("taxPct", min: 0.0, max: 20.0, value: 10.0, step: 1.0, label: "الضريبة (%)")
roundUp = viz.toggle("roundUp", value: true, label: "تقريب حصة الفرد لأقرب دولار")

tip = bill * (tipPct / 100.0)
tax = bill * (taxPct / 100.0)
total = bill + tip + tax
exactPerPerson = total / people
var perPerson = exactPerPerson
if roundUp:
  perPerson = exactPerPerson.ceil().toDouble()
extraPool = (perPerson * people) - total

summary = map:
  "حصة الشخص الواحد": perPerson.toStringAsFixed(2) + " $"
  "الإجمالي الكلي": total.toStringAsFixed(2) + " $"
  "الخدمة ({tipPct.toInt()}%)": tip.toStringAsFixed(2) + " $"
  "الضريبة ({taxPct.toInt()}%)": tax.toStringAsFixed(2) + " $"
  "فائض التقريب": extraPool.toStringAsFixed(2) + " $"

var scenarios: List<List<dynamic>> = []
for tRate in [0.0, 10.0, 15.0, 20.0]:
  scTotal = bill + tax + bill * (tRate / 100.0)
  scenarios.add(["بقشيش {tRate.toInt()}%", scTotal.toStringAsFixed(2) + " $", (scTotal / people).toStringAsFixed(2) + " $"])

viz.form(summary, title: "🍽️ حاسبة تقسيم الفاتورة ({people} أشخاص)", summary: "تحكم بقيمة الفاتورة وعدد الأصدقاء ونسبة البقشيش فوراً")
viz.table(["السيناريو", "الإجمالي", "لكل شخص"], scenarios, title: "مقارنة نسب الخدمة")
print "حصة الفرد = {perPerson.toStringAsFixed(2)} $ من أصل {total.toStringAsFixed(2)} $"
''',
  ),

  // 5. University GPA & Honors Study Planner
  StudioPreset(
    id: 'app_gpa_planner',
    titleAr: '🎓 حاسبة المعدل الجامعي GPA',
    titleEn: 'University GPA & Honors Planner',
    subtitleAr: 'احسب معدلك الفصلي والتراكمي واكتشف التقدير ومرتبة الشرف',
    fileName: 'gpa_planner.quds',
    category: StudioCategory.apps,
    code: r'''# تطبيق تفاعلي 5: حاسبة المعدل الجامعي GPA ومخطط التفوق
use quds:viz as viz

gradePoints(g: String) -> double:
  if g == "A+":
    return 4.0
  if g == "A":
    return 3.75
  if g == "B+":
    return 3.5
  if g == "B":
    return 3.0
  if g == "C+":
    return 2.5
  if g == "C":
    return 2.0
  return 1.0

grades = ["A+", "A", "B+", "B", "C+", "C", "D"]
g1 = viz.select("g1", grades, value: "A+", label: "تقدير: الخوارزميات (3س)")
g2 = viz.select("g2", grades, value: "A", label: "تقدير: قواعد البيانات (3س)")
g3 = viz.select("g3", grades, value: "B+", label: "تقدير: هندسة البرمجيات (3س)")
g4 = viz.select("g4", grades, value: "A", label: "تقدير: الذكاء الاصطناعي (4س)")
prevGpa = viz.slider("prevGpa", min: 1.5, max: 4.0, value: 3.45, step: 0.05, label: "المعدل التراكمي السابق")
prevCredits = viz.slider("prevCredits", min: 0.0, max: 120.0, value: 45.0, step: 3.0, label: "الساعات المنجزة سابقاً")

p1 = gradePoints(g1)
p2 = gradePoints(g2)
p3 = gradePoints(g3)
p4 = gradePoints(g4)
semCredits = 13.0
semPoints = p1 * 3.0 + p2 * 3.0 + p3 * 3.0 + p4 * 4.0
semGpa = semPoints / semCredits
cumGpa = (prevGpa * prevCredits + semPoints) / (prevCredits + semCredits)

var honors = "📘 جيد — واصل التقدم"
if cumGpa >= 3.75:
  honors = "🏆 مرتبة الشرف الأولى"
else if cumGpa >= 3.5:
  honors = "⭐ مرتبة الشرف الثانية"
else if cumGpa >= 3.0:
  honors = "✅ جيد جداً"

summary = map:
  "المعدل الفصلي": semGpa.toStringAsFixed(2) + " / 4.00"
  "المعدل التراكمي الجديد": cumGpa.toStringAsFixed(2) + " / 4.00"
  "إجمالي الساعات": (prevCredits + semCredits).toInt()
  "التقدير الأكاديمي": honors

rows = [
  ["الخوارزميات وهياكل البيانات", 3, g1, (p1 * 3.0).toStringAsFixed(2)],
  ["قواعد البيانات المتقدمة", 3, g2, (p2 * 3.0).toStringAsFixed(2)],
  ["هندسة البرمجيات", 3, g3, (p3 * 3.0).toStringAsFixed(2)],
  ["الذكاء الاصطناعي", 4, g4, (p4 * 4.0).toStringAsFixed(2)]
]

viz.form(summary, title: "🎓 بطاقة المعدل الأكاديمي GPA", summary: "غيّر تقدير أي مادة لمشاهدة الأثر المباشر على معدلك التراكمي")
viz.table(["المادة", "الساعات", "التقدير", "النقاط"], rows, title: "توزيع مواد الفصل الحالي")
print "الفصلي = {semGpa.toStringAsFixed(2)} | التراكمي = {cumGpa.toStringAsFixed(2)} | {honors}"
''',
  ),

  // 6. BMI, TDEE & Daily Nutrition Planner
  StudioPreset(
    id: 'app_bmi_calories',
    titleAr: '🏃 حاسبة الصحة والسعرات والماكروز',
    titleEn: 'BMI & Daily Nutrition App',
    subtitleAr:
        'حساب مؤشر الكتلة BMI، السعرات اليومية TDEE وتوزيع البروتين والكارب',
    fileName: 'health_macros.quds',
    category: StudioCategory.apps,
    code: r'''# تطبيق تفاعلي 6: حاسبة الصحة واللياقة والسعرات والماكروز
use quds:viz as viz

weight = viz.slider("weight", min: 40.0, max: 140.0, value: 76.0, step: 1.0, label: "الوزن (كغ)")
heightCm = viz.slider("heightCm", min: 140.0, max: 210.0, value: 176.0, step: 1.0, label: "الطول (سم)")
age = viz.slider("age", min: 15.0, max: 75.0, value: 28.0, step: 1.0, label: "العمر (سنة)")
activity = viz.select("activity", ["خامل (1.2)", "خفيف (1.375)", "متوسط (1.55)", "نشيط (1.725)"], value: "متوسط (1.55)", label: "مستوى النشاط")
goal = viz.select("goal", ["إنقاص وزن (-400)", "تثبيت الوزن (0)", "زيادة عضلات (+350)"], value: "تثبيت الوزن (0)", label: "الهدف")

hM = heightCm / 100.0
bmi = weight / (hM * hM)
var bmiStatus = "سمنة"
if bmi < 18.5:
  bmiStatus = "نقص وزن"
else if bmi < 25.0:
  bmiStatus = "وزن مثالي ✅"
else if bmi < 30.0:
  bmiStatus = "زيادة وزن"

bmr = 10.0 * weight + 6.25 * heightCm - 5.0 * age + 5.0
var mult = 1.725
if activity == "خامل (1.2)":
  mult = 1.2
else if activity == "خفيف (1.375)":
  mult = 1.375
else if activity == "متوسط (1.55)":
  mult = 1.55

tdee = bmr * mult
var delta = 0.0
if goal == "إنقاص وزن (-400)":
  delta = -400.0
else if goal == "زيادة عضلات (+350)":
  delta = 350.0
targetCal = tdee + delta

proteinG = (targetCal * 0.30) / 4.0
carbsG = (targetCal * 0.45) / 4.0
fatG = (targetCal * 0.25) / 9.0
waterL = weight * 0.035

summary = map:
  "مؤشر الكتلة BMI": "{bmi.toStringAsFixed(1)} ({bmiStatus})"
  "السعرات المستهدفة": "{targetCal.round()} سعرة/يوم"
  "الماء اليومي": "{waterL.toStringAsFixed(1)} لتر"
  "الأيض الأساسي BMR": "{bmr.round()} سعرة"

rows = [
  ["البروتين (30%)", "{proteinG.round()} غ", "{(proteinG * 4.0).round()} سعرة"],
  ["الكربوهيدرات (45%)", "{carbsG.round()} غ", "{(carbsG * 4.0).round()} سعرة"],
  ["الدهون الصحية (25%)", "{fatG.round()} غ", "{(fatG * 9.0).round()} سعرة"]
]

viz.form(summary, title: "🏃 خطة اللياقة والتغذية اليومية", summary: "اضبط قياساتك وهدفك لحساب السعرات والماكروز المثالية فوراً")
viz.table(["العنصر الغذائي", "الكمية اليومية", "السعرات"], rows, title: "توزيع المغذيات الكبرى (Macros)")
print "BMI = {bmi.toStringAsFixed(1)} | السعرات = {targetCal.round()} kcal"
''',
  ),

  // 7. Interactive Quds Quiz Engine (Stateful)
  StudioPreset(
    id: 'app_quds_quiz',
    titleAr: '🧠 تطبيق اختبارات تفاعلي (Quiz App)',
    titleEn: 'Interactive Quds Quiz Engine',
    subtitleAr: 'تطبيق أسئلة وإجابات متعدد المراحل مع تصحيح فوري وحفظ النقاط',
    fileName: 'quds_quiz.quds',
    category: StudioCategory.apps,
    code:
        r'''# تطبيق تفاعلي 7: محرك اختبارات تفاعلي بحفظ النتيجة والتقدم (viz.state)
use quds:viz as viz

questions = [
  ["ما هي الكلمة المفتاحية لتعريف متغير قابل للتعديل في قدس؟", "var", "const", "let", "final", "var"],
  ["كيف تُعرّف خريطة (Map) متعددة الأسطر في لغة قدس؟", "map:", "dict()", "hash:", "obj:", "map:"],
  ["ما نتيجة \"Ahmed\" + 10 في لغة قدس 1.2؟", "Ahmed10", "خطأ ترجمة", "10", "null", "Ahmed10"],
  ["أي وحدة مدمجة تقرأ ملفات assets/ JSON و CSV و BMP؟", "quds:assets", "quds:io", "dart:fs", "quds:net", "quds:assets"]
]

qIdx = (viz.state("qIdx", 0) as num).toInt()
score = (viz.state("score", 0) as num).toInt()
answered = (viz.state("answered", 0) as num).toInt()
lastSubmit = (viz.state("lastSubmit", 0) as num).toInt()
lastReset = (viz.state("lastReset", 0) as num).toInt()

cur = questions[qIdx]
choice = viz.select("choice", [cur[1], cur[2], cur[3], cur[4]], value: cur[1], label: "اختر إجابتك")
submitClicks = viz.button("submitAns", label: "✅ إرسال الإجابة والسؤال التالي")
resetClicks = viz.button("resetQuiz", label: "🔄 بدء الاختبار من جديد")

var feedback = "اختر إجابتك واضغط «إرسال الإجابة»"
var newIdx = qIdx
var newScore = score
var newAnswered = answered

if resetClicks != lastReset:
  newIdx = 0
  newScore = 0
  newAnswered = 0
  feedback = "تم تصفير الاختبار! بالتوفيق 🚀"
  viz.setState("lastReset", resetClicks)
else if submitClicks != lastSubmit:
  if choice == cur[5]:
    newScore = score + 1
    feedback = "🎉 إجابة صحيحة! أحسنت"
  else:
    feedback = "❌ إجابة خاطئة — الصحيح هو: " + cur[5].toString()
  newAnswered = answered + 1
  newIdx = (qIdx + 1) % questions.length
  viz.setState("lastSubmit", submitClicks)

viz.setState("qIdx", newIdx)
viz.setState("score", newScore)
viz.setState("answered", newAnswered)

nextQ = questions[newIdx]
var accuracy = 0.0
if newAnswered > 0:
  accuracy = (newScore * 100.0) / newAnswered

summary = map:
  "السؤال الحالي ({newIdx + 1}/{questions.length})": nextQ[0]
  "النتيجة": "{newScore} / {newAnswered}"
  "دقة الإجابات": accuracy.toStringAsFixed(0) + "%"
  "آخر تقييم": feedback

viz.form(summary, title: "🧠 اختبار قدس التفاعلي", summary: "مثال حقيقي على بناء تطبيق اختبارات بحالة مستمرة داخل المفسّر")
print "الاختبار: {newScore}/{newAnswered} | السؤال التالي #{newIdx + 1}"
''',
  ),

  // 8. Smart Inventory & Reorder Manager (Stateful)
  StudioPreset(
    id: 'app_inventory_manager',
    titleAr: '📦 مدير المخزون وإعادة الطلب',
    titleEn: 'Smart Inventory & Reorder Manager',
    subtitleAr: 'بيع وتوريد أصناف حيّة مع تنبيهات نقص المخزون التلقائية',
    fileName: 'inventory_manager.quds',
    category: StudioCategory.apps,
    code: r'''# تطبيق تفاعلي 8: نظام إدارة مخزون وتنبيهات إعادة الطلب (Stateful)
use quds:viz as viz

product = viz.select("product", ["لابتوب برو", "شاشة 4K", "لوحة مفاتيح ميكانيكية", "سماعة عازلة"], value: "لابتوب برو", label: "الصنف المحدد")
qty = viz.slider("qty", min: 1.0, max: 20.0, value: 3.0, step: 1.0, label: "الكمية للحركة").toInt()
minThreshold = viz.slider("minThreshold", min: 2.0, max: 25.0, value: 8.0, step: 1.0, label: "حد التنبيه الأدنى").toInt()
sellClicks = viz.button("sellBtn", label: "🛒 تسجيل بيع (-)")
restockClicks = viz.button("restockBtn", label: "🚚 توريد للمخزن (+)")
resetClicks = viz.button("resetInv", label: "🔄 إعادة ضبط المخزون")

lastSell = (viz.state("lastSell", 0) as num).toInt()
lastRestock = (viz.state("lastRestock", 0) as num).toInt()
lastReset = (viz.state("lastReset", 0) as num).toInt()

var stock = viz.state("stock", [
  ["لابتوب برو", 12, 1150.0],
  ["شاشة 4K", 7, 420.0],
  ["لوحة مفاتيح ميكانيكية", 18, 95.0],
  ["سماعة عازلة", 5, 180.0]
]) as List

if resetClicks != lastReset:
  stock = [
    ["لابتوب برو", 12, 1150.0],
    ["شاشة 4K", 7, 420.0],
    ["لوحة مفاتيح ميكانيكية", 18, 95.0],
    ["سماعة عازلة", 5, 180.0]
  ]
  viz.setState("lastReset", resetClicks)

if sellClicks != lastSell:
  for item in stock:
    if item[0] == product:
      curQty = (item[1] as num).toInt()
      if curQty >= qty:
        item[1] = curQty - qty
      else:
        item[1] = 0
  viz.setState("lastSell", sellClicks)

if restockClicks != lastRestock:
  for item in stock:
    if item[0] == product:
      item[1] = (item[1] as num).toInt() + qty
  viz.setState("lastRestock", restockClicks)

viz.setState("stock", stock)

var totalValue = 0.0
var lowAlerts = 0
var tableRows: List<List<dynamic>> = []
for item in stock:
  name = item[0].toString()
  count = (item[1] as num).toInt()
  price = (item[2] as num).toDouble()
  val = count * price
  totalValue = totalValue + val
  isLow = count <= minThreshold
  if isLow:
    lowAlerts = lowAlerts + 1
  var status = "✅ متوفر"
  if count == 0:
    status = "⛔ نفد المخزون"
  else if isLow:
    status = "⚠️ إعادة طلب"
  tableRows.add([name, count, price.toStringAsFixed(0) + " $", val.toStringAsFixed(0) + " $", status])

summary = map:
  "قيمة المخزون الكلية": totalValue.toStringAsFixed(0) + " $"
  "عدد الأصناف": stock.length
  "تنبيهات إعادة الطلب": lowAlerts
  "حد الأمان": minThreshold

viz.form(summary, title: "📦 لوحة إدارة المخزون الذكية", summary: "اختر الصنف وسجّل عمليات بيع أو توريد لمراقبة قيمة المخزون والتنبيهات حياً")
viz.table(["الصنف", "الكمية", "السعر", "القيمة", "الحالة"], tableRows, title: "جرد المستودع المباشر")
print "قيمة المخزون = {totalValue.toStringAsFixed(0)} $ | تنبيهات النقص = {lowAlerts}"
''',
  ),
];
