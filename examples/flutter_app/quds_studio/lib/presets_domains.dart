/// 16 Domain Presets across Finance & Economics (8) and Engineering & Electronics (8).
library;

import 'presets.dart';

const financeAndEngineeringPresets = <StudioPreset>[
  // ═══════════════════════════════════════════════════════════════════════════
  // Finance & Economics (8)
  // ═══════════════════════════════════════════════════════════════════════════

  StudioPreset(
    id: 'fin_stock_moving_avg',
    titleAr: 'مالية: محاكاة البورصة والمتوسطات المتحركة (SMA)',
    titleEn: 'Finance: Live Stock Price & Moving Average Signals',
    subtitleAr:
        'تتبع حركة السهم مع تقاطع المتوسط السريع والبطيء (التقاطع الذهبي) وحساب العائد',
    fileName: 'stock_moving_avg.quds',
    category: StudioCategory.finance,
    isAnimated: true,
    code: r'''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 30, duration: 20.0, loop: true)
vol = viz.slider("vol", min: 0.4, max: 3.0, value: 1.4, step: 0.1, label: "تقلب السوق")
trend = viz.slider("trend", min: -0.3, max: 0.6, value: 0.18, step: 0.02, label: "الاتجاه العام")

shift = clk.t * 2.5
var prices = []
var smaFast = []
var smaSlow = []
var pricePts = []
var fastPts = []
var slowPts = []

for i in 0..80:
  x = i + shift
  p = 100.0 + i * trend + vol * (4.5 * m.sin(x * 0.19) + 2.4 * m.cos(x * 0.43) + 1.1 * m.sin(x * 0.85))
  prices.add(p)
  gx = -5.0 + i * (10.0 / 80.0)
  gy = (p - 105.0) * 0.16
  pricePts.add([gx, gy])

  var sf = 0.0
  var cf = 0
  for k in m.max(0, i - 5)..i:
    sf = sf + prices[k]
    cf = cf + 1
  mf = sf / cf
  smaFast.add(mf)
  fastPts.add([gx, (mf - 105.0) * 0.16])

  var ss = 0.0
  var cs = 0
  for k in m.max(0, i - 16)..i:
    ss = ss + prices[k]
    cs = cs + 1
  ms = ss / cs
  smaSlow.add(ms)
  slowPts.add([gx, (ms - 105.0) * 0.16])

lastP = prices[prices.length - 1]
lastF = smaFast[smaFast.length - 1]
lastS = smaSlow[smaSlow.length - 1]
bullish = lastF >= lastS

s = viz.scene(title: "سوق الأسهم الحي — " + (if bullish: "إشارة شراء صاعدة 📈" else: "إشارة تصحيح هابطة 📉"), grid: true, bounds: [-5.3, 5.3, -4.0, 4.5])
s.curve("price", pricePts, color: "#38BDF8", strokeWidth: 2.2)
s.curve("fast", fastPts, color: "#10B981", strokeWidth: 2.0)
s.curve("slow", slowPts, color: "#F59E0B", strokeWidth: 2.0)
s.point("last", 5.0, (lastP - 105.0) * 0.16, color: (if bullish: "#10B981" else: "#EF4444"), radius: 6.5)
s.readout("السعر الحالي", lastP, unit: "$", color: "#38BDF8")
s.readout("SMA سريع", lastF, unit: "$", color: "#10B981")
s.readout("SMA بطيء", lastS, unit: "$", color: "#F59E0B")
s.render()
''',
  ),

  StudioPreset(
    id: 'fin_compound_interest',
    titleAr: 'مالية: الفائدة المركبة والتخطيط المالي (FIRE)',
    titleEn: 'Finance: Compound Interest & Wealth Growth',
    subtitleAr:
        'استكشف قوة العائد المركب عبر السنين بمقارنة إجمالي المدخرات مع الأرباح التراكمية',
    fileName: 'compound_interest.quds',
    category: StudioCategory.finance,
    isAnimated: false,
    code: r'''use quds:viz as viz

initial = viz.slider("init", min: 1000.0, max: 50000.0, value: 10000.0, step: 1000.0, label: "المبلغ الابتدائي ($)")
monthly = viz.slider("mon", min: 100.0, max: 3000.0, value: 500.0, step: 50.0, label: "الإيداع الشهري ($)")
rate = viz.slider("rate", min: 2.0, max: 15.0, value: 8.0, step: 0.5, label: "العائد السنوي %")
years = viz.slider("yrs", min: 5.0, max: 35.0, value: 20.0, step: 1.0, label: "عدد السنوات")

var balance = initial
var contrib = initial
var xs = [0.0]
var ys = [balance]
rMonth = rate / 100.0 / 12.0
nYears = years.toInt()

for y in 1..nYears:
  for mo in 1..12:
    balance = balance * (1.0 + rMonth) + monthly
    contrib = contrib + monthly
  xs.add(y * 1.0)
  ys.add(balance)

profit = balance - contrib
viz.plot(xs, ys, title: "نمو الثروة بالفائدة المركبة خلال " + nYears + " سنة", xLabel: "السنوات", yLabel: "الرصيد ($)", color: "#10B981")
viz.table(["البند المالي", "القيمة ($)"], [["إجمالي الإيداعات", contrib.toStringAsFixed(0)], ["الأرباح المركبة", profit.toStringAsFixed(0)], ["الرصيد النهائي", balance.toStringAsFixed(0)], ["مضاعف النمو", (balance / contrib).toStringAsFixed(2) + "x"]], title: "ملخص الاستثمار")
''',
  ),

  StudioPreset(
    id: 'fin_mortgage_amortization',
    titleAr: 'مالية: حاسبة القرض العقاري وجدول الأقساط',
    titleEn: 'Finance: Mortgage Amortization Calculator',
    subtitleAr:
        'حساب القسط الشهري وتناقص أصل القرض ومقارنة إجمالي الفوائد مع مبلغ التمويل',
    fileName: 'mortgage_calc.quds',
    category: StudioCategory.finance,
    isAnimated: false,
    code: r'''use dart:math as m
use quds:viz as viz

loan = viz.slider("loan", min: 50000.0, max: 500000.0, value: 200000.0, step: 10000.0, label: "مبلغ القرض ($)")
apr = viz.slider("apr", min: 2.0, max: 11.0, value: 5.5, step: 0.25, label: "الفائدة السنوية %")
yrs = viz.slider("yrs", min: 5.0, max: 30.0, value: 20.0, step: 1.0, label: "مدة القرض (سنة)")

r = apr / 100.0 / 12.0
n = yrs.toInt() * 12
factor = m.pow(1.0 + r, n)
pmt = loan * (r * factor) / (factor - 1.0)

var rem = loan
var xs = [0.0]
var ys = [rem]
for y in 1..yrs.toInt():
  for mo in 1..12:
    interest = rem * r
    principal = pmt - interest
    rem = m.max(0.0, rem - principal)
  xs.add(y * 1.0)
  ys.add(rem)

totalPaid = pmt * n
totalInt = totalPaid - loan
viz.plot(xs, ys, title: "تناقص رصيد القرض العقاري عبر الزمن", xLabel: "السنوات", yLabel: "المتبقي ($)", color: "#6366F1")
viz.table(["البند", "القيمة"], [["القسط الشهري", pmt.toStringAsFixed(2) + " $"], ["إجمالي السداد", totalPaid.toStringAsFixed(0) + " $"], ["إجمالي الفوائد", totalInt.toStringAsFixed(0) + " $"], ["نسبة الفائدة", (totalInt / loan * 100.0).toStringAsFixed(1) + "%"]], title: "تفاصيل التمويل العقاري")
''',
  ),

  StudioPreset(
    id: 'fin_supply_demand',
    titleAr: 'اقتصاد: منحنيات العرض والطلب وتوازن السوق',
    titleEn: 'Econ: Supply, Demand & Market Equilibrium',
    subtitleAr:
        'حرّك طلب السوق والضريبة وشاهد انتقال نقطة التوازن السعري وفائض المستهلك والمنتج',
    fileName: 'supply_demand.quds',
    category: StudioCategory.finance,
    isAnimated: false,
    code: r'''use quds:viz as viz

demandShift = viz.slider("dem", min: -2.0, max: 3.0, value: 0.5, step: 0.1, label: "إزاحة الطلب")
tax = viz.slider("tax", min: 0.0, max: 3.0, value: 0.5, step: 0.1, label: "الضريبة على الوحدة")

# الطلب: P = (8 + demandShift) - 0.8*Q
# العرض: P = (1 + tax) + 0.7*Q
a = 8.0 + demandShift
b = 1.0 + tax
qEq = (a - b) / 1.5
pEq = b + 0.7 * qEq

var demPts = []
var supPts = []
for i in 0..40:
  q = i * 0.25
  demPts.add([q, a - 0.8 * q])
  supPts.add([q, b + 0.7 * q])

s = viz.scene(title: "توازن السوق — السعر: " + pEq.toStringAsFixed(2) + " | الكمية: " + qEq.toStringAsFixed(2), grid: true, bounds: [0.0, 10.5, 0.0, 11.5])
s.curve("demand", demPts, color: "#38BDF8", strokeWidth: 2.8)
s.curve("supply", supPts, color: "#F59E0B", strokeWidth: 2.8)
s.segment("eqH", [0.0, pEq], [qEq, pEq], color: "#10B981", strokeWidth: 1.5, dashed: true)
s.segment("eqV", [qEq, 0.0], [qEq, pEq], color: "#10B981", strokeWidth: 1.5, dashed: true)
s.point("eq", qEq, pEq, label: "التوازن E", color: "#10B981", radius: 8.0)
s.readout("سعر التوازن P*", pEq, unit: "$", color: "#10B981")
s.readout("كمية التوازن Q*", qEq, unit: "وحدة", color: "#38BDF8")
s.readout("الإيراد الضريبي", tax * qEq, unit: "$", color: "#F59E0B")
s.render()
''',
  ),

  StudioPreset(
    id: 'fin_startup_breakeven',
    titleAr: 'أعمال: نقطة التعادل للشركات الناشئة (Break-Even)',
    titleEn: 'Business: Startup Break-Even & Profit Analysis',
    subtitleAr:
        'تحليل التكاليف الثابتة والمتغيرة وسعر البيع لمعرفة عدد المبيعات اللازم لتحقيق الربح',
    fileName: 'startup_breakeven.quds',
    category: StudioCategory.finance,
    isAnimated: false,
    code: r'''use quds:viz as viz

fixedCost = viz.slider("fix", min: 2000.0, max: 20000.0, value: 8000.0, step: 500.0, label: "التكاليف الثابتة ($/شهر)")
unitCost = viz.slider("uc", min: 5.0, max: 60.0, value: 18.0, step: 1.0, label: "تكلفة الوحدة ($)")
unitPrice = viz.slider("up", min: 25.0, max: 120.0, value: 50.0, step: 1.0, label: "سعر البيع ($)")

margin = unitPrice - unitCost
beUnits = (if margin > 0.0: fixedCost / margin else: 0.0)
beRev = beUnits * unitPrice

var revPts = []
var costPts = []
maxU = 500.0
for i in 0..50:
  u = maxU * i / 50.0
  revPts.add([u / 50.0, (u * unitPrice) / 4000.0])
  costPts.add([u / 50.0, (fixedCost + u * unitCost) / 4000.0])

s = viz.scene(title: "نقطة التعادل = " + beUnits.toStringAsFixed(0) + " وحدة شهرياً", grid: true, bounds: [0.0, 10.5, 0.0, 12.0])
s.curve("revenue", revPts, color: "#10B981", strokeWidth: 2.8)
s.curve("cost", costPts, color: "#EF4444", strokeWidth: 2.8)
if beUnits > 0.0 and beUnits <= maxU:
  s.point("be", beUnits / 50.0, beRev / 4000.0, label: "التعادل", color: "#FACC15", radius: 8.5)
s.readout("وحدات التعادل", beUnits, decimals: 0, color: "#FACC15")
s.readout("هامش الربح/وحدة", margin, unit: "$", color: "#10B981")
s.readout("إيراد التعادل", beRev, unit: "$", decimals: 0, color: "#38BDF8")
s.render()
''',
  ),

  StudioPreset(
    id: 'fin_inflation_decay',
    titleAr: 'اقتصاد: تآكل القوة الشرائية بسبب التضخم',
    titleEn: 'Econ: Inflation & Purchasing Power Decay',
    subtitleAr:
        'احسب كم ستساوي مدخراتك الحقيقية بعد 25 سنة في ظل معدلات التضخم المختلفة',
    fileName: 'inflation_decay.quds',
    category: StudioCategory.finance,
    isAnimated: false,
    code: r'''use dart:math as m
use quds:viz as viz

amount = viz.slider("amt", min: 1000.0, max: 100000.0, value: 10000.0, step: 1000.0, label: "المبلغ اليوم ($)")
inf = viz.slider("inf", min: 1.0, max: 15.0, value: 4.5, step: 0.5, label: "معدل التضخم السنوي %")

var yrs = []
var realVal = []
for y in 0..25:
  v = amount / m.pow(1.0 + inf / 100.0, y)
  yrs.add(y * 1.0)
  realVal.add(v)

halfLife = 72.0 / inf
viz.plot(yrs, realVal, title: "القوة الشرائية الحقيقية لـ " + amount.toInt() + "$ مع تضخم " + inf + "%", xLabel: "السنوات", yLabel: "القيمة الحقيقية ($)", color: "#EF4444")
viz.table(["السنة", "القيمة الحقيقية ($)"], [["بعد 5 سنوات", realVal[5].toStringAsFixed(0)], ["بعد 10 سنوات", realVal[10].toStringAsFixed(0)], ["بعد 25 سنة", realVal[25].toStringAsFixed(0)], ["نصف العمر التقريبي", halfLife.toStringAsFixed(1) + " سنة"]], title: "أثر التضخم")
''',
  ),

  StudioPreset(
    id: 'fin_portfolio_mc',
    titleAr: 'مالية: محاكاة مخاطر المحفظة (مونت كارلو)',
    titleEn: 'Finance: Portfolio Risk & Allocation',
    subtitleAr:
        'مقارنة سيناريوهات التفاؤل والوسط والتشاؤم حسب نسبة الأسهم مقابل السندات',
    fileName: 'portfolio_risk.quds',
    category: StudioCategory.finance,
    isAnimated: false,
    code: r'''use dart:math as m
use quds:viz as viz

stocksPct = viz.slider("stocks", min: 0.0, max: 100.0, value: 70.0, step: 5.0, label: "نسبة الأسهم %")
capital = viz.slider("cap", min: 5000.0, max: 100000.0, value: 25000.0, step: 5000.0, label: "رأس المال ($)")

w = stocksPct / 100.0
expRet = w * 0.10 + (1.0 - w) * 0.04
sigma = w * 0.16 + (1.0 - w) * 0.03

var bull = []
var base = []
var bear = []
for y in 0..15:
  gx = -5.0 + y * (10.0 / 15.0)
  vBase = capital * m.pow(1.0 + expRet, y)
  vBull = capital * m.pow(1.0 + expRet + sigma * 0.55, y)
  vBear = capital * m.pow(1.0 + m.max(-0.04, expRet - sigma * 0.65), y)
  scale = 1.0 / (capital * 0.9)
  base.add([gx, -3.2 + vBase * scale])
  bull.add([gx, -3.2 + vBull * scale])
  bear.add([gx, -3.2 + vBear * scale])

s = viz.scene(title: "مسارات المحفظة لـ 15 سنة (أسهم " + stocksPct.toInt() + "%)", grid: true, bounds: [-5.3, 5.3, -3.6, 5.8])
s.curve("bull", bull, color: "#10B981", strokeWidth: 2.2)
s.curve("base", base, color: "#38BDF8", strokeWidth: 2.8, glow: true)
s.curve("bear", bear, color: "#EF4444", strokeWidth: 2.2)
s.readout("العائد المتوقع", expRet * 100.0, unit: "%", color: "#38BDF8")
s.readout("التقلب السنوي σ", sigma * 100.0, unit: "%", color: "#F59E0B")
s.readout("نسبة شارب التقريبية", (expRet - 0.03) / m.max(0.01, sigma), decimals: 2, color: "#10B981")
s.render()
''',
  ),

  StudioPreset(
    id: 'fin_zakat_budget_app',
    titleAr: 'تطبيق مالي: حاسبة الزكاة والميزانية (50/30/20)',
    titleEn: 'Finance App: Smart Budget & Zakat Planner',
    subtitleAr:
        'تطبيق مصغّر لحساب توزيع الدخل الشهري والزكاة السنوية الواجبة تلقائياً',
    fileName: 'zakat_budget.quds',
    category: StudioCategory.finance,
    isAnimated: false,
    code: r'''use quds:viz as viz

income = viz.number("inc", value: 4000.0, min: 0.0, max: 100000.0, label: "الدخل الشهري ($)")
savings = viz.number("sav", value: 18000.0, min: 0.0, max: 1000000.0, label: "المدخرات التي حال عليها الحول ($)")
goldPrice = viz.slider("gold", min: 60.0, max: 120.0, value: 85.0, step: 1.0, label: "سعر غرام الذهب 24 ($)")

nisab = 85.0 * goldPrice
zakatDue = (if savings >= nisab: savings * 0.025 else: 0.0)
needs = income * 0.50
wants = income * 0.30
invest = income * 0.20

summary = map:
  "الضروريات (50%)": needs.toStringAsFixed(0) + " $"
  "الرغبات (30%)": wants.toStringAsFixed(0) + " $"
  "الادخار والاستثمار (20%)": invest.toStringAsFixed(0) + " $"
  "نصاب الزكاة (85غ ذهب)": nisab.toStringAsFixed(0) + " $"
  "الزكاة الواجبة (2.5%)": zakatDue.toStringAsFixed(2) + " $"

viz.form(summary, title: "المخطط المالي وحاسبة الزكاة", summary: (if savings >= nisab: "بلغت المدخرات النصاب ✅" else: "المدخرات دون النصاب"))
''',
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // Engineering & Electronics (8)
  // ═══════════════════════════════════════════════════════════════════════════

  StudioPreset(
    id: 'eng_robot_arm_ik',
    titleAr: 'هندسة: ذراع روبوتية وحساب الكينماتيكا العكسية (2-DOF)',
    titleEn: 'Eng: 2-DOF Robotic Arm Inverse Kinematics',
    subtitleAr:
        'اسحب نقطة الهدف بإصبعك لتقوم الذراع الروبوتية بحساب الزوايا θ₁ و θ₂ لحظياً',
    fileName: 'robot_arm_ik.quds',
    category: StudioCategory.engineering,
    isAnimated: false,
    code: r'''use dart:math as m
use quds:viz as viz

target = viz.point("target", 3.4, 2.2, draggable: true, label: "الهدف 🎯", color: "#FACC15")
l1 = viz.slider("l1", min: 1.5, max: 3.5, value: 2.6, step: 0.1, label: "طول الذراع 1")
l2 = viz.slider("l2", min: 1.5, max: 3.5, value: 2.3, step: 0.1, label: "طول الذراع 2")

tx = target.x
ty = target.y
dRaw = m.sqrt(tx * tx + ty * ty)
d = m.max((l1 - l2).abs() + 0.05, m.min(l1 + l2 - 0.02, dRaw))
scale = (if dRaw > 0.001: d / dRaw else: 1.0)
rx = tx * scale
ry = ty * scale

var cosT2 = (d * d - l1 * l1 - l2 * l2) / (2.0 * l1 * l2)
cosT2 = m.max(-1.0, m.min(1.0, cosT2))
theta2 = m.acos(cosT2)
phi = m.atan2(ry, rx)
psi = m.acos(m.max(-1.0, m.min(1.0, (d * d + l1 * l1 - l2 * l2) / (2.0 * l1 * d))))
theta1 = phi - psi

jx = l1 * m.cos(theta1)
jy = l1 * m.sin(theta1)
ex = jx + l2 * m.cos(theta1 + theta2)
ey = jy + l2 * m.sin(theta1 + theta2)

s = viz.scene(title: "الذراع الروبوتية — اسحب الهدف 🎯", grid: true, interactive: true, bounds: [-5.5, 5.5, -4.5, 5.5])
s.circle("reach", [0.0, 0.0], l1 + l2, stroke: "#334155", dashed: true)
s.segment("link1", [0.0, 0.0], [jx, jy], color: "#38BDF8", strokeWidth: 6.0)
s.segment("link2", [jx, jy], [ex, ey], color: "#EC4899", strokeWidth: 5.0)
s.point("base", 0.0, 0.0, label: "القاعدة", color: "#94A3B8", radius: 8.0)
s.point("elbow", jx, jy, label: "المفصل", color: "#10B981", radius: 7.0)
s.point("end", ex, ey, color: "#EC4899", radius: 6.0)
s.point("target", tx, ty, draggable: true, label: "🎯", color: "#FACC15", radius: 8.5)
s.readout("زاوية الكتف θ₁", theta1 * 57.2958, unit: "°", decimals: 1, color: "#38BDF8")
s.readout("زاوية الكوع θ₂", theta2 * 57.2958, unit: "°", decimals: 1, color: "#EC4899")
s.readout("المسافة d", d, unit: "m", color: "#FACC15")
s.render()
''',
  ),

  StudioPreset(
    id: 'eng_four_stroke_piston',
    titleAr: 'ميكانيكا: محرك المكبس وذراع التوصيل (Crankshaft)',
    titleEn: 'Eng: Crankshaft & Piston Kinematics',
    subtitleAr:
        'حركة ترددية حية للمكبس وذراع التوصيل والعمود المرفقي مع قراءة الإزاحة والسرعة',
    fileName: 'piston_crank.quds',
    category: StudioCategory.engineering,
    isAnimated: true,
    code: r'''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
rpm = viz.slider("rpm", min: 30.0, max: 180.0, value: 90.0, step: 5.0, label: "سرعة الدوران (RPM)")
rCrank = viz.slider("r", min: 0.8, max: 1.8, value: 1.3, step: 0.1, label: "نصف قطر الكرنك r")

rodL = 3.2
w = rpm * 2.0 * m.pi / 60.0
theta = clk.t * w
cx = rCrank * m.cos(theta)
cy = rCrank * m.sin(theta)
px = cx + m.sqrt(rodL * rodL - cy * cy)
pVel = -rCrank * w * m.sin(theta)

s = viz.scene(title: "آلية المكبس والعمود المرفقي (" + rpm.toInt() + " RPM)", grid: true, bounds: [-2.4, 6.2, -2.5, 2.5])
s.circle("crankPath", [0.0, 0.0], rCrank, stroke: "#334155", dashed: true)
s.polygon("cyl", [[1.4, -0.75], [5.4, -0.75], [5.4, 0.75], [1.4, 0.75]], stroke: "#475569")
s.segment("crank", [0.0, 0.0], [cx, cy], color: "#F59E0B", strokeWidth: 5.0)
s.segment("rod", [cx, cy], [px, 0.0], color: "#38BDF8", strokeWidth: 4.5)
s.polygon("piston", [[px - 0.35, -0.55], [px + 0.35, -0.55], [px + 0.35, 0.55], [px - 0.35, 0.55]], stroke: "#10B981", fill: "#065F46")
s.point("origin", 0.0, 0.0, color: "#94A3B8", radius: 7.0)
s.point("pin", cx, cy, color: "#FACC15", radius: 6.5)
s.readout("زاوية الكرنك", (theta * 57.3) % 360.0, unit: "°", decimals: 0, color: "#F59E0B")
s.readout("إزاحة المكبس", px, unit: "cm", color: "#10B981")
s.readout("سرعة المكبس", pVel, unit: "cm/s", color: "#38BDF8")
s.render()
''',
  ),

  StudioPreset(
    id: 'eng_meshing_gears',
    titleAr: 'ميكانيكا: تعشيق التروس ونسبة العزم (Gear Train)',
    titleEn: 'Eng: Meshing Gears & Torque Ratio',
    subtitleAr:
        'تروس دوّارة متعشّقة تحسب نسبة النقل والسرعة والعزم الناتج لحظياً',
    fileName: 'meshing_gears.quds',
    category: StudioCategory.engineering,
    isAnimated: true,
    code: r'''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: true)
ratio = viz.slider("ratio", min: 1.0, max: 3.0, value: 1.8, step: 0.1, label: "نسبة التروس (R2/R1)")
inRpm = viz.slider("rpm", min: 20.0, max: 120.0, value: 60.0, step: 5.0, label: "سرعة الترس القائد RPM")

r1 = 1.35
r2 = r1 * ratio
x1 = -r2 * 0.5
x2 = x1 + r1 + r2
a1 = clk.t * (inRpm * 2.0 * m.pi / 60.0)
a2 = -a1 / ratio + m.pi / 8.0

s = viz.scene(title: "منظومة التروس المتعشقة — نسبة النقل 1:" + ratio.toStringAsFixed(1), grid: false, axes: false, bounds: [-4.6, 5.6, -4.4, 4.4])
s.circle("g1", [x1, 0.0], r1, stroke: "#38BDF8", fill: "#0C4A6E")
s.circle("g2", [x2, 0.0], r2, stroke: "#F59E0B", fill: "#78350F")

for i in 0..<8:
  ag1 = a1 + i * (2.0 * m.pi / 8.0)
  s.segment("sp1_{i}", [x1, 0.0], [x1 + (r1 + 0.18) * m.cos(ag1), (r1 + 0.18) * m.sin(ag1)], color: "#38BDF8", strokeWidth: 3.0)

for i in 0..<12:
  ag2 = a2 + i * (2.0 * m.pi / 12.0)
  s.segment("sp2_{i}", [x2, 0.0], [x2 + (r2 + 0.18) * m.cos(ag2), (r2 + 0.18) * m.sin(ag2)], color: "#F59E0B", strokeWidth: 3.0)

s.point("c1", x1, 0.0, label: "قائد", color: "#F8FAFC", radius: 6.0)
s.point("c2", x2, 0.0, label: "منقاد", color: "#F8FAFC", radius: 6.0)
s.readout("سرعة الخرج", inRpm / ratio, unit: "RPM", decimals: 1, color: "#F59E0B")
s.readout("مضاعف العزم", ratio, unit: "x", decimals: 2, color: "#10B981")
s.render()
''',
  ),

  StudioPreset(
    id: 'eng_beam_bending',
    titleAr: 'مدنية: انحناء العارضة الإنشائية وعزم الانحناء',
    titleEn: 'Civil Eng: Simply Supported Beam Deflection',
    subtitleAr:
        'حرّك موقع الحمل والوزن لحساب أقصى هبوط إنشائي وعزم الانحناء وردود الأفعال',
    fileName: 'beam_bending.quds',
    category: StudioCategory.engineering,
    isAnimated: false,
    code: r'''use quds:viz as viz

loadPos = viz.slider("pos", min: 1.0, max: 9.0, value: 5.0, step: 0.25, label: "موقع الحمل a (م)")
weight = viz.slider("w", min: 10.0, max: 100.0, value: 50.0, step: 5.0, label: "الحمل المركز P (kN)")

L = 10.0
a = loadPos
b = L - a
rLeft = weight * b / L
rRight = weight * a / L
maxMoment = weight * a * b / L

var beamPts = []
for i in 0..60:
  x = L * i / 60.0
  # تقريب منحنى الهبوط المرن
  defl = (if x <= a: -(weight * b * x * (L * L - b * b - x * x)) else: -(weight * a * (L - x) * (L * L - a * a - (L - x) * (L - x)))) / 26000.0
  beamPts.add([x - 5.0, defl])

s = viz.scene(title: "انحناء العارضة الإنشائية — أقصى عزم: " + maxMoment.toStringAsFixed(1) + " kN·m", grid: true, bounds: [-5.6, 5.6, -3.5, 3.0])
s.segment("orig", [-5.0, 0.0], [5.0, 0.0], color: "#475569", strokeWidth: 1.5, dashed: true)
s.curve("beam", beamPts, color: "#38BDF8", strokeWidth: 4.5, glow: true)
s.vector("load", [a - 5.0, 2.2], [0.0, -2.0], color: "#EF4444", label: "P=" + weight.toInt() + "kN")
s.point("supL", -5.0, 0.0, label: "RA", color: "#10B981", radius: 7.5)
s.point("supR", 5.0, 0.0, label: "RB", color: "#10B981", radius: 7.5)
s.readout("رد الفعل RA", rLeft, unit: "kN", color: "#10B981")
s.readout("رد الفعل RB", rRight, unit: "kN", color: "#10B981")
s.readout("أقصى عزم Mmax", maxMoment, unit: "kN·m", color: "#F59E0B")
s.render()
''',
  ),

  StudioPreset(
    id: 'eng_digital_logic_gates',
    titleAr: 'إلكترونيات: البوابات المنطقية والجامع النصفي (Half-Adder)',
    titleEn: 'Electronics: Logic Gates & Half-Adder Simulator',
    subtitleAr:
        'بدّل المدخلين A و B وشاهد مخارج AND و OR و XOR و NAND والجامع الثنائي مباشرة',
    fileName: 'logic_gates.quds',
    category: StudioCategory.engineering,
    isAnimated: false,
    code: r'''use quds:viz as viz

inA = viz.toggle("a", value: true, label: "المدخل A (1/0)")
inB = viz.toggle("b", value: false, label: "المدخل B (1/0)")

a = (if inA: 1 else: 0)
b = (if inB: 1 else: 0)
gAnd = (if inA and inB: 1 else: 0)
gOr = (if inA or inB: 1 else: 0)
gXor = (if inA != inB: 1 else: 0)
gNand = 1 - gAnd

s = viz.scene(title: "الجامع النصفي: A=" + a + " + B=" + b + " => Sum=" + gXor + ", Carry=" + gAnd, grid: false, axes: false, bounds: [-5.2, 5.2, -3.5, 3.5])
colA = (if inA: "#10B981" else: "#475569")
colB = (if inB: "#10B981" else: "#475569")
colSum = (if gXor == 1: "#FACC15" else: "#475569")
colCar = (if gAnd == 1: "#EC4899" else: "#475569")

s.segment("wA1", [-4.2, 1.5], [-0.8, 1.5], color: colA, strokeWidth: 3.5)
s.segment("wA2", [-2.4, 1.5], [-2.4, -1.1], color: colA, strokeWidth: 3.0)
s.segment("wA3", [-2.4, -1.1], [-0.8, -1.1], color: colA, strokeWidth: 3.0)
s.segment("wB1", [-4.2, -1.7], [-0.8, -1.7], color: colB, strokeWidth: 3.5)
s.segment("wB2", [-1.9, -1.7], [-1.9, 0.9], color: colB, strokeWidth: 3.0)
s.segment("wB3", [-1.9, 0.9], [-0.8, 0.9], color: colB, strokeWidth: 3.0)

s.polygon("xorBox", [[-0.8, 0.5], [1.4, 0.5], [1.4, 1.9], [-0.8, 1.9]], stroke: "#38BDF8", fill: "#0F172A")
s.label("xorLbl", [0.3, 1.2], "XOR", color: "#38BDF8")
s.polygon("andBox", [[-0.8, -2.1], [1.4, -2.1], [1.4, -0.7], [-0.8, -0.7]], stroke: "#EC4899", fill: "#0F172A")
s.label("andLbl", [0.3, -1.4], "AND", color: "#EC4899")

s.segment("outS", [1.4, 1.2], [4.0, 1.2], color: colSum, strokeWidth: 4.0)
s.segment("outC", [1.4, -1.4], [4.0, -1.4], color: colCar, strokeWidth: 4.0)
s.point("pA", -4.2, 1.5, label: "A=" + a, color: colA, radius: 8.5)
s.point("pB", -4.2, -1.7, label: "B=" + b, color: colB, radius: 8.5)
s.point("pS", 4.0, 1.2, label: "Sum=" + gXor, color: colSum, radius: 9.0)
s.point("pC", 4.0, -1.4, label: "Carry=" + gAnd, color: colCar, radius: 9.0)
s.render()

viz.table(["البوابة", "المخرج"], [["AND (Carry)", gAnd], ["OR", gOr], ["XOR (Sum)", gXor], ["NAND", gNand]], title: "جدول البوابات المنطقية")
''',
  ),

  StudioPreset(
    id: 'eng_rc_lowpass_filter',
    titleAr: 'إلكترونيات: مرشح الترددات المنخفضة RC (Bode Plot)',
    titleEn: 'Electronics: RC Low-Pass Filter Response',
    subtitleAr:
        'اضبط المقاومة R والمكثف C لحساب تردد القطع fc ومنحنى الكسب والتوهين',
    fileName: 'rc_filter.quds',
    category: StudioCategory.engineering,
    isAnimated: false,
    code: r'''use dart:math as m
use quds:viz as viz

rOhm = viz.slider("r", min: 100.0, max: 5000.0, value: 1000.0, step: 100.0, label: "المقاومة R (Ω)")
cMicro = viz.slider("c", min: 0.1, max: 10.0, value: 1.0, step: 0.1, label: "المكثف C (µF)")

cFarad = cMicro * 0.000001
fc = 1.0 / (2.0 * m.pi * rOhm * cFarad)

var freqs = []
var gains = []
for i in 1..60:
  f = fc * (i / 15.0)
  h = 1.0 / m.sqrt(1.0 + (f / fc) * (f / fc))
  freqs.add(f)
  gains.add(h)

viz.plot(freqs, gains, title: "استجابة مرشح RC (تردد القطع fc = " + fc.toStringAsFixed(1) + " Hz)", xLabel: "التردد (Hz)", yLabel: "الكسب |H(f)|", color: "#14B8A6")
viz.table(["المعامل", "القيمة"], [["تردد القطع fc (-3dB)", fc.toStringAsFixed(2) + " Hz"], ["الثابت الزمني τ = RC", (rOhm * cFarad * 1000.0).toStringAsFixed(2) + " ms"], ["الكسب عند fc", "0.707 (-3 dB)"]], title: "خصائص المرشح")
''',
  ),

  StudioPreset(
    id: 'eng_suspension_bridge',
    titleAr: 'مدنية: الجسر المعلّق وقوى الشد في الكابلات',
    titleEn: 'Civil Eng: Suspension Bridge Cable Tension',
    subtitleAr:
        'غيّر طول الجسر والترخيم (Sag) لمشاهدة الكابل القطعي وحساب قوة الشد العظمى',
    fileName: 'suspension_bridge.quds',
    category: StudioCategory.engineering,
    isAnimated: false,
    code: '''use dart:math as m
use quds:viz as viz

sag = viz.slider("sag", min: 0.8, max: 3.2, value: 1.9, step: 0.1, label: "انخفاض الكابل Sag (م)")
loadW = viz.slider("w", min: 10.0, max: 60.0, value: 30.0, step: 2.0, label: "الحمل الموزع w (kN/m)")

halfSpan = 4.6
hTension = loadW * (2.0 * halfSpan) * (2.0 * halfSpan) / (8.0 * sag)
vForce = loadW * halfSpan
maxTension = m.sqrt(hTension * hTension + vForce * vForce)

var cable = []
for i in 0..60:
  x = -halfSpan + (2.0 * halfSpan) * i / 60.0
  y = -0.6 + sag * (x * x) / (halfSpan * halfSpan)
  cable.add([x, y])

s = viz.scene(title: "الجسر المعلّق — الشد الأعظم: " + maxTension.toStringAsFixed(0) + " kN", grid: true, bounds: [-5.5, 5.5, -2.5, 3.6])
s.segment("deck", [-5.2, -1.2], [5.2, -1.2], color: "#94A3B8", strokeWidth: 4.5)
s.segment("towerL", [-halfSpan, -2.2], [-halfSpan, -0.6 + sag + 0.3], color: "#F59E0B", strokeWidth: 6.0)
s.segment("towerR", [halfSpan, -2.2], [halfSpan, -0.6 + sag + 0.3], color: "#F59E0B", strokeWidth: 6.0)
for k in -4..4:
  hx = k * 1.0
  hy = -0.6 + sag * (hx * hx) / (halfSpan * halfSpan)
  s.segment("hang{k}", [hx, -1.2], [hx, hy], color: "#38BDF8", strokeWidth: 1.4)
s.curve("cable", cable, color: "#EC4899", strokeWidth: 3.2, glow: true)
s.readout("الشد الأفقي H", hTension, unit: "kN", decimals: 0, color: "#38BDF8")
s.readout("الشد الأعظم Tmax", maxTension, unit: "kN", decimals: 0, color: "#EC4899")
s.render()
''',
  ),

  StudioPreset(
    id: 'eng_airfoil_lift',
    titleAr: 'طيران: تدفق الهواء حول جناح الطائرة وقوة الرفع',
    titleEn: 'Aero: Airfoil Lift & Streamline Flow',
    subtitleAr:
        'تحكّم بزاوية الهجوم وسرعة الهواء لمشاهدة انحراف خطوط التيار وحساب قوة الرفع والسحب',
    fileName: 'airfoil_lift.quds',
    category: StudioCategory.engineering,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
aoa = viz.slider("aoa", min: -5.0, max: 18.0, value: 8.0, step: 0.5, label: "زاوية الهجوم (°)")
speed = viz.slider("spd", min: 40.0, max: 180.0, value: 110.0, step: 5.0, label: "سرعة الهواء (m/s)")

rad = aoa * m.pi / 180.0
cl = (if aoa < 15.0: 0.11 * aoa + 0.2 else: 1.85 - (aoa - 15.0) * 0.28)
cd = 0.02 + 0.045 * cl * cl
liftKn = 0.5 * 1.225 * speed * speed * 16.0 * cl / 1000.0

s = viz.scene(title: "ديناميكا الهواء — زاوية الهجوم " + aoa + "°" + (if aoa >= 15.0: " ⚠️ انهيار رفع!" else: ""), grid: false, axes: false, bounds: [-5.2, 5.2, -3.5, 3.8])
# خطوط التيار المتحركة
for j in -3..3:
  var linePts = []
  y0 = j * 0.85
  for i in 0..40:
    x = -5.0 + i * 0.25
    bump = m.exp(-(x * x) / 3.2) * (0.42 + aoa * 0.03) * (if y0 >= 0.0: 1.0 else: -0.5)
    y = y0 + bump - (if x > 0.0: x * aoa * 0.012 else: 0.0)
    linePts.add([x, y])
  s.curve("st{j}", linePts, color: "#38BDF8", strokeWidth: 1.6)
  px = -5.0 + ((clk.t * 3.5 + j * 1.3) % 10.0)
  py = y0 + m.exp(-(px * px) / 3.2) * (0.42 + aoa * 0.03) * (if y0 >= 0.0: 1.0 else: -0.5)
  s.point("p{j}", px, py, color: "#FACC15", radius: 4.5)

c = m.cos(-rad)
sn = m.sin(-rad)
raw = [[-1.8, 0.0], [-0.8, 0.42], [0.6, 0.25], [1.9, 0.0], [0.5, -0.16], [-0.9, -0.18]]
var wing = []
for pt in raw:
  wing.add([pt[0] * c - pt[1] * sn, pt[0] * sn + pt[1] * c])
s.polygon("wing", wing, stroke: "#F8FAFC", fill: "#334155")
s.vector("liftV", [0.0, 0.4], [0.0, m.min(2.8, cl * 1.4)], color: "#10B981", label: "الرفع L")
s.readout("معامل الرفع CL", cl, decimals: 2, color: "#10B981")
s.readout("نسبة الرفع/السحب", cl / cd, decimals: 1, color: "#38BDF8")
s.readout("قوة الرفع", liftKn, unit: "kN", decimals: 1, color: "#FACC15")
s.render()
''',
  ),
];
