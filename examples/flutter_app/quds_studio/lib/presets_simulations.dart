/// 12 Real-World Interactive Simulations powered by Quds Register VM + `quds:viz`.
library;

import 'presets.dart';

const realWorldSimPresets = <StudioPreset>[
  // 1. Smart Traffic Intersection
  StudioPreset(
    id: 'sim_smart_traffic',
    titleAr: 'محاكاة: تقاطع إشارات المرور الذكية',
    titleEn: 'Sim: Smart 4-Way Traffic Intersection',
    subtitleAr:
        'تنظيم حركة السيارات بأربعة اتجاهات مع دورة الإشارة (أخضر/أصفر/أحمر) وزمن الانتظار',
    fileName: 'smart_traffic.quds',
    category: StudioCategory.simulations,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 16.0, loop: true)
greenSec = viz.slider("green", min: 3.0, max: 8.0, value: 5.0, step: 0.5, label: "زمن الأخضر (ث)")
flow = viz.slider("flow", min: 0.6, max: 2.2, value: 1.3, step: 0.1, label: "كثافة المرور")

cycle = (greenSec + 1.5) * 2.0
phase = clk.t % cycle
ewGreen = phase < greenSec
ewYellow = phase >= greenSec and phase < greenSec + 1.5
nsGreen = phase >= greenSec + 1.5 and phase < cycle - 1.5

s = viz.scene(title: "محاكاة تقاطع المرور الذكي", grid: false, axes: false, bounds: [-5.5, 5.5, -4.5, 4.5])
s.polygon("roadH", [[-5.5, -1.1], [5.5, -1.1], [5.5, 1.1], [-5.5, 1.1]], stroke: "#334155", fill: "#1E293B")
s.polygon("roadV", [[-1.1, -4.5], [1.1, -4.5], [1.1, 4.5], [-1.1, 4.5]], stroke: "#334155", fill: "#1E293B")
s.segment("midH", [-5.5, 0.0], [5.5, 0.0], color: "#FACC15", strokeWidth: 1.2, dashed: true)
s.segment("midV", [0.0, -4.5], [0.0, 4.5], color: "#FACC15", strokeWidth: 1.2, dashed: true)

# إشارات المرور
ewCol = (if ewGreen: "#10B981" else: (if ewYellow: "#FACC15" else: "#EF4444"))
nsCol = (if nsGreen: "#10B981" else: (if (not ewGreen and not ewYellow): "#FACC15" else: "#EF4444"))
s.point("sigEW", -1.45, 1.45, label: "شرق-غرب", color: ewCol, radius: 8.0)
s.point("sigNS", 1.45, -1.45, label: "شمال-جنوب", color: nsCol, radius: 8.0)

# سيارات شرق-غرب وشمال-جنوب
for i in 0..<4:
  rawX = -5.2 + ((clk.t * 1.9 * flow + i * 2.7) % 10.6)
  cx = (if not ewGreen and rawX > -2.4 and rawX < -1.2: -1.55 - i * 0.35 else: rawX)
  s.point("carE{i}", cx, -0.5, color: "#38BDF8", radius: 6.5)

  rawY = -4.3 + ((clk.t * 1.7 * flow + i * 2.4) % 8.8)
  cy = (if not nsGreen and rawY > -2.4 and rawY < -1.2: -1.55 - i * 0.35 else: rawY)
  s.point("carN{i}", 0.5, cy, color: "#EC4899", radius: 6.5)

s.readout("الطور الحالي", phase, unit: "s", color: "#FACC15")
s.readout("التدفق", flow * 36.0, unit: "سيارة/د", decimals: 0, color: "#38BDF8")
s.render()
''',
  ),

  // 2. Smart Multi-Floor Elevator
  StudioPreset(
    id: 'sim_smart_elevator',
    titleAr: 'محاكاة: المصعد الذكي متعدد الطوابق',
    titleEn: 'Sim: Smart 8-Floor Elevator Controller',
    subtitleAr:
        'جدولة حركة المصعد بين 8 طوابق حسب الطابق المطلوب مع حساب زمن الوصول والطاقة',
    fileName: 'smart_elevator.quds',
    category: StudioCategory.simulations,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 20.0, loop: true)
targetF = viz.slider("target", min: 1.0, max: 8.0, value: 6.0, step: 1.0, label: "الطابق المطلوب")
loadKg = viz.slider("load", min: 70.0, max: 800.0, value: 320.0, step: 10.0, label: "الحمولة (كغ)")

var curY = viz.state("elevY", 1.0)
dt = m.min(0.035, m.max(0.015, clk.dt))
diff = targetF - curY
vel = (if diff.abs() < 0.05: 0.0 else: (if diff > 0.0: 1.6 else: -1.6))
curY = curY + vel * dt
if (targetF - curY).abs() < 0.06:
  curY = targetF
viz.setState("elevY", curY)

powerKw = vel.abs() * (loadKg * 9.81 / 1000.0) * 1.15
s = viz.scene(title: "المصعد الذكي — الطابق الحالي: " + curY.toStringAsFixed(1), grid: false, axes: false, bounds: [-4.0, 4.5, 0.2, 8.8])
s.polygon("shaft", [[-1.0, 0.5], [1.0, 0.5], [1.0, 8.5], [-1.0, 8.5]], stroke: "#475569")
for f in 1..8:
  s.segment("fl{f}", [-3.4, f * 1.0], [3.6, f * 1.0], color: "#334155", strokeWidth: 1.0)
  col = (if f == targetF.toInt(): "#FACC15" else: "#94A3B8")
  s.label("lbl{f}", [-2.4, f * 1.0 + 0.2], "طابق " + f, color: col)

s.segment("cable", [0.0, 8.5], [0.0, curY + 0.42], color: "#94A3B8", strokeWidth: 2.0)
cabCol = (if diff.abs() < 0.06: "#10B981" else: "#38BDF8")
s.polygon("cabin", [[-0.78, curY - 0.36], [0.78, curY - 0.36], [0.78, curY + 0.42], [-0.78, curY + 0.42]], stroke: cabCol, fill: "#0F172A")
s.point("targetDot", 1.8, targetF, label: "الهدف", color: "#FACC15", radius: 7.0)
s.readout("الطابق الحالي", curY, decimals: 1, color: cabCol)
s.readout("القدرة اللحظية", powerKw, unit: "kW", color: "#F59E0B")
s.readout("الحمولة", loadKg, unit: "kg", decimals: 0, color: "#EC4899")
s.render()
''',
  ),

  // 3. Solar Microgrid & Home Battery
  StudioPreset(
    id: 'sim_solar_microgrid',
    titleAr: 'محاكاة: محطة طاقة شمسية وبطارية منزلية (24 ساعة)',
    titleEn: 'Sim: Solar PV Microgrid & Battery Storage',
    subtitleAr:
        'تتبّع شروق الشمس، توليد الألواح الشمسية، استهلاك المنزل، وحالة شحن البطارية على مدار اليوم',
    fileName: 'solar_microgrid.quds',
    category: StudioCategory.simulations,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 14.0, loop: true)
clouds = viz.slider("clouds", min: 0.0, max: 0.85, value: 0.15, step: 0.05, label: "غطاء الغيوم")
pvPeak = viz.slider("pv", min: 2.0, max: 10.0, value: 6.5, step: 0.5, label: "قدرة الألواح (kW)")

hour = clk.progress * 24.0
var pvCurve = []
var loadCurve = []
var socCurve = []
var soc = 50.0
var nowPv = 0.0
var nowLoad = 0.0
var nowSoc = 50.0

for i in 0..48:
  h = i * 0.5
  sun = (if h >= 6.0 and h <= 18.0: m.sin(m.pi * (h - 6.0) / 12.0) else: 0.0)
  pv = pvPeak * sun * (1.0 - clouds)
  load = 1.4 + 1.8 * m.exp(-((h - 19.5) * (h - 19.5)) / 10.0) + 0.9 * m.exp(-((h - 9.0) * (h - 9.0)) / 6.0)
  soc = m.max(10.0, m.min(100.0, soc + (pv - load) * 2.6))
  gx = -5.0 + h * (10.0 / 24.0)
  pvCurve.add([gx, -2.5 + pv * 0.52])
  loadCurve.add([gx, -2.5 + load * 0.52])
  socCurve.add([gx, -2.5 + soc * 0.042])
  if (h - hour).abs() <= 0.26:
    nowPv = pv
    nowLoad = load
    nowSoc = soc

sunX = -5.0 + hour * (10.0 / 24.0)
sunY = (if hour >= 6.0 and hour <= 18.0: 2.1 + 1.5 * m.sin(m.pi * (hour - 6.0) / 12.0) else: 1.7)

s = viz.scene(title: "الشبكة الشمسية المنزلية — الساعة " + hour.toStringAsFixed(1), grid: true, bounds: [-5.4, 5.4, -3.0, 4.2])
s.curve("pv", pvCurve, color: "#FACC15", strokeWidth: 2.6, glow: true)
s.curve("load", loadCurve, color: "#EC4899", strokeWidth: 2.2)
s.curve("soc", socCurve, color: "#10B981", strokeWidth: 2.2)
s.segment("nowLine", [sunX, -2.7], [sunX, 2.0], color: "#94A3B8", strokeWidth: 1.4, dashed: true)
s.point("sun", sunX, sunY, label: (if hour >= 6.0 and hour <= 18.0: "☀️" else: "🌙"), color: "#FACC15", radius: 9.0)
s.readout("توليد شمسي", nowPv, unit: "kW", color: "#FACC15")
s.readout("حمل المنزل", nowLoad, unit: "kW", color: "#EC4899")
s.readout("شحن البطارية", nowSoc, unit: "%", decimals: 0, color: "#10B981")
s.render()
''',
  ),

  // 4. PID Cruise Control
  StudioPreset(
    id: 'sim_pid_cruise',
    titleAr: 'محاكاة: مثبّت السرعة الذكي بمتحكم PID',
    titleEn: 'Sim: Automotive PID Cruise Control',
    subtitleAr:
        'اضبط معاملات Kp و Ki و Kd وشاهد استجابة سرعة السيارة للوصول للسرعة المستهدفة دون تذبذب',
    fileName: 'pid_cruise.quds',
    category: StudioCategory.simulations,
    isAnimated: false,
    code: '''use quds:viz as viz

target = viz.slider("target", min: 40.0, max: 140.0, value: 100.0, step: 5.0, label: "السرعة المستهدفة (km/h)")
kp = viz.slider("kp", min: 0.2, max: 4.0, value: 1.6, step: 0.1, label: "التناسبي Kp")
ki = viz.slider("ki", min: 0.0, max: 1.5, value: 0.45, step: 0.05, label: "التكاملي Ki")
kd = viz.slider("kd", min: 0.0, max: 1.2, value: 0.25, step: 0.05, label: "التفاضلي Kd")

var v = 20.0
var integral = 0.0
var prevErr = target - v
var ts = []
var vs = []
var maxV = 0.0
dt = 0.1

for step in 0..120:
  t = step * dt
  err = target - v
  integral = integral + err * dt
  deriv = (err - prevErr) / dt
  prevErr = err
  u = kp * err + ki * integral + kd * deriv
  # تلة طريق مفاجئة عند t = 6s
  hill = (if t > 6.0 and t < 8.5: -18.0 else: 0.0)
  accel = (u - 0.18 * v + hill) * 0.22
  v = v + accel * dt
  if v > maxV: maxV = v
  ts.add(t)
  vs.add(v)

overshoot = (if maxV > target: (maxV - target) / target * 100.0 else: 0.0)
viz.plot(ts, vs, title: "استجابة مثبت السرعة PID (الهدف = " + target.toInt() + " km/h)", xLabel: "الزمن (ث)", yLabel: "السرعة (km/h)", color: "#38BDF8")
viz.table(["المؤشر", "القيمة"], [["السرعة المستهدفة", target.toStringAsFixed(0) + " km/h"], ["السرعة النهائية", v.toStringAsFixed(2) + " km/h"], ["تجاوز القمة Overshoot", overshoot.toStringAsFixed(1) + "%"], ["الخطأ النهائي", (target - v).toStringAsFixed(2) + " km/h"]], title: "تحليل أداء المتحكم PID")
''',
  ),

  // 5. Smart Home HVAC Thermostat
  StudioPreset(
    id: 'sim_smart_hvac',
    titleAr: 'محاكاة: منظم الحرارة المنزلي الذكي (HVAC)',
    titleEn: 'Sim: Smart Home HVAC Thermal Control',
    subtitleAr:
        'موازنة حرارة الغرفة أمام تقلبات الطقس الخارجي مع حساب استهلاك الكهرباء والكفاءة',
    fileName: 'smart_hvac.quds',
    category: StudioCategory.simulations,
    isAnimated: false,
    code: '''use dart:math as m
use quds:viz as viz

setTemp = viz.slider("set", min: 18.0, max: 26.0, value: 22.0, step: 0.5, label: "درجة الحرارة المطلوبة °C")
insul = viz.slider("insul", min: 0.05, max: 0.45, value: 0.16, step: 0.02, label: "فقدان العزل الحراري")
outPeak = viz.slider("out", min: 28.0, max: 46.0, value: 38.0, step: 1.0, label: "ذروة حرارة الخارج °C")

var room = 26.0
var hours = []
var roomT = []
var kwh = 0.0
var active = false

for i in 0..96:
  h = i * 0.25
  outT = outPeak - 9.0 * m.cos(2.0 * m.pi * (h - 15.0) / 24.0)
  if room > setTemp + 0.6:
    active = true
  else if room < setTemp - 0.6:
    active = false
  cool = (if active: -2.4 else: 0.0)
  if active:
    kwh = kwh + 0.45
  room = room + (insul * (outT - room) + cool) * 0.25
  hours.add(h)
  roomT.add(room)

viz.plot(hours, roomT, title: "حرارة الغرفة خلال 24 ساعة (الهدف " + setTemp + "°C)", xLabel: "الساعة", yLabel: "°C", color: "#10B981")
viz.table(["المقياس", "النتيجة"], [["الهدف الحراري", setTemp.toStringAsFixed(1) + " °C"], ["ذروة الخارج", outPeak.toStringAsFixed(1) + " °C"], ["الاستهلاك اليومي", kwh.toStringAsFixed(1) + " kWh"], ["التكلفة التقديرية", (kwh * 0.14).toStringAsFixed(2) + " USD"]], title: "تقرير كفاءة التكييف")
''',
  ),

  // 6. Hospital ER Queue (M/M/c)
  StudioPreset(
    id: 'sim_hospital_queue',
    titleAr: 'محاكاة: طوابير الطوارئ وتوزيع الأطباء (M/M/c)',
    titleEn: 'Sim: Hospital ER Queue & Staffing',
    subtitleAr:
        'تحليل ضغط المرضى وزمن الانتظار ونسبة إشغال الأطباء حسب معدل الوصول وعدد العيادات',
    fileName: 'hospital_queue.quds',
    category: StudioCategory.simulations,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 12.0, loop: true)
arrival = viz.slider("arr", min: 4.0, max: 24.0, value: 14.0, step: 1.0, label: "وصول المرضى / ساعة")
doctors = viz.slider("docs", min: 1.0, max: 6.0, value: 3.0, step: 1.0, label: "عدد الأطباء")

serviceRate = 6.0
cap = doctors * serviceRate
rho = m.min(0.98, arrival / cap)
avgWaitMin = (rho / (1.0 - rho)) * (60.0 / cap)
queueLen = (arrival * avgWaitMin / 60.0).toInt()
shownQ = m.min(14, queueLen)

s = viz.scene(title: "محاكاة قسم الطوارئ — نسبة الإشغال " + (rho * 100.0).toInt() + "%", grid: false, axes: false, bounds: [-5.5, 5.5, -4.0, 4.0])
s.polygon("waitRoom", [[-5.2, -3.4], [-0.4, -3.4], [-0.4, 3.4], [-5.2, 3.4]], stroke: "#F59E0B")
s.label("wLbl", [-2.8, 3.65], "غرفة الانتظار (" + queueLen + ")", color: "#F59E0B")

for i in 0..<shownQ:
  col = i % 4
  row = i ~/ 4
  px = -4.5 + col * 1.1 + 0.08 * m.sin(clk.t * 3.0 + i)
  py = 2.4 - row * 1.3
  s.point("pat{i}", px, py, color: "#F59E0B", radius: 7.0)

dCount = doctors.toInt()
for d in 0..<dCount:
  dy = 2.5 - d * (5.0 / m.max(1, dCount))
  s.polygon("doc{d}", [[1.0, dy - 0.35], [4.8, dy - 0.35], [4.8, dy + 0.35], [1.0, dy + 0.35]], stroke: "#10B981", fill: "#064E3B")
  s.point("dr{d}", 1.5, dy, label: "طبيب " + (d + 1), color: "#38BDF8", radius: 6.5)

s.readout("متوسط الانتظار", avgWaitMin, unit: "دقيقة", decimals: 1, color: (if avgWaitMin > 25.0: "#EF4444" else: "#10B981"))
s.readout("الإشغال ρ", rho * 100.0, unit: "%", decimals: 0, color: "#F59E0B")
s.readout("الطاقة الاستيعابية", cap, unit: "/ساعة", decimals: 0, color: "#38BDF8")
s.render()
''',
  ),

  // 7. Hydroelectric Dam & Reservoir
  StudioPreset(
    id: 'sim_hydro_dam',
    titleAr: 'محاكاة: السد الكهرومائي والتوربينات',
    titleEn: 'Sim: Hydroelectric Dam & Turbine Output',
    subtitleAr:
        'تحكّم بنسبة الأمطار وفتحة البوابة لمراقبة منسوب الخزان وتوليد الكهرباء بالميجاواط',
    fileName: 'hydro_dam.quds',
    category: StudioCategory.simulations,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 15.0, loop: true)
rain = viz.slider("rain", min: 10.0, max: 120.0, value: 65.0, step: 5.0, label: "تدفق الأمطار (m³/s)")
gate = viz.slider("gate", min: 0.1, max: 1.0, value: 0.55, step: 0.05, label: "فتحة بوابة التوربين")

var level = viz.state("damLvl", 62.0)
outflow = gate * 110.0 * m.sqrt(level / 80.0)
level = m.max(15.0, m.min(95.0, level + (rain - outflow) * 0.03))
viz.setState("damLvl", level)

powerMw = 0.9 * 9.81 * outflow * (level * 0.65) / 1000.0
waterY = -3.2 + (level / 100.0) * 6.4

s = viz.scene(title: "السد الكهرومائي — التوليد: " + powerMw.toStringAsFixed(1) + " MW", grid: false, axes: false, bounds: [-5.5, 5.5, -3.8, 4.0])
s.polygon("water", [[-5.4, -3.2], [-0.4, -3.2], [-0.4, waterY], [-5.4, waterY]], stroke: "#38BDF8", fill: "#0369A1")
s.polygon("dam", [[-0.5, -3.2], [0.9, -3.2], [0.3, 3.4], [-0.5, 3.4]], stroke: "#94A3B8", fill: "#334155")

# دوران ريش التوربين حسب التدفق
ang = clk.t * (2.0 + outflow * 0.06)
for k in 0..<4:
  a = ang + k * m.pi / 2.0
  s.segment("blade{k}", [2.3, -2.0], [2.3 + 0.85 * m.cos(a), -2.0 + 0.85 * m.sin(a)], color: "#FACC15", strokeWidth: 3.5)
s.circle("turb", [2.3, -2.0], 0.95, stroke: "#F59E0B")
s.segment("jet", [0.85, -2.0], [1.5, -2.0], color: "#38BDF8", strokeWidth: 2.0 + gate * 5.0)

s.readout("منسوب الخزان", level, unit: "%", decimals: 1, color: "#38BDF8")
s.readout("التدفق الخارج", outflow, unit: "m³/s", decimals: 1, color: "#06B6D4")
s.readout("الطاقة المولدة", powerMw, unit: "MW", decimals: 1, color: "#FACC15")
s.render()
''',
  ),

  // 8. Quadcopter Altitude & Wind Stabilizer
  StudioPreset(
    id: 'sim_quadcopter_drone',
    titleAr: 'محاكاة: توازن طائرة مسيّرة (Drone) ضد الرياح',
    titleEn: 'Sim: Quadcopter Altitude & Wind Stabilizer',
    subtitleAr:
        'تحكّم بالارتفاع المطلوب وهبّات الرياح لمراقبة استقرار المراوح الأربع وميل الطائرة',
    fileName: 'quadcopter_drone.quds',
    category: StudioCategory.simulations,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 20.0, loop: true)
targetAlt = viz.slider("alt", min: -2.0, max: 3.0, value: 1.2, step: 0.1, label: "الارتفاع المستهدف")
windGust = viz.slider("wind", min: -2.5, max: 2.5, value: 0.9, step: 0.1, label: "هبّة الرياح")

var dy = viz.state("dy", 0.0)
var vy = viz.state("vy", 0.0)
dt = m.min(0.032, m.max(0.012, clk.dt))

err = targetAlt - dy
thrust = 9.81 + 5.5 * err - 3.2 * vy
vy = vy + (thrust - 9.81) * dt
dy = m.max(-3.0, m.min(3.4, dy + vy * dt))
viz.setState("dy", dy)
viz.setState("vy", vy)

dx = 0.65 * m.sin(clk.t * 1.6) + windGust * 0.45
tilt = -windGust * 0.14
c = m.cos(tilt)
sn = m.sin(tilt)
lx = dx - 1.3 * c
ly = dy - 1.3 * sn
rx = dx + 1.3 * c
ry = dy + 1.3 * sn

s = viz.scene(title: "مسيّرة ذاتية التوازن — الدفع: " + thrust.toStringAsFixed(1) + " N", grid: true, bounds: [-5.0, 5.0, -3.6, 4.2])
s.segment("targetLine", [-4.8, targetAlt], [4.8, targetAlt], color: "#10B981", strokeWidth: 1.5, dashed: true)
s.segment("frame", [lx, ly], [rx, ry], color: "#38BDF8", strokeWidth: 5.0)
spin = 0.55 * m.sin(clk.t * 28.0)
s.segment("rotL", [lx - spin, ly + 0.25], [lx + spin, ly + 0.25], color: "#FACC15", strokeWidth: 3.0)
s.segment("rotR", [rx - spin, ry + 0.25], [rx + spin, ry + 0.25], color: "#FACC15", strokeWidth: 3.0)
s.point("core", dx, dy, color: "#EC4899", radius: 7.5)
s.vector("windVec", [-4.2, 3.3], [windGust * 0.8, 0.0], color: "#94A3B8", label: "رياح")
s.readout("الارتفاع", dy, unit: "m", color: "#38BDF8")
s.readout("زاوية الميل", tilt * 57.3, unit: "°", color: "#F59E0B")
s.readout("الدفع الكلي", thrust, unit: "N", color: "#10B981")
s.render()
''',
  ),

  // 9. Forest Fire Cellular Spread
  StudioPreset(
    id: 'sim_forest_fire',
    titleAr: 'محاكاة: انتشار حرائق الغابات واتجاه الرياح',
    titleEn: 'Sim: Forest Fire Cellular Spread Model',
    subtitleAr:
        'نموذج خلوي لانتشار جبهة النار عبر الغابة حسب كثافة الأشجار وسرعة الرياح',
    fileName: 'forest_fire.quds',
    category: StudioCategory.simulations,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 10.0, loop: true)
density = viz.slider("dens", min: 0.35, max: 1.0, value: 0.78, step: 0.05, label: "كثافة الأشجار")
windSpd = viz.slider("wind", min: 0.0, max: 2.0, value: 0.85, step: 0.1, label: "سرعة الرياح شرقاً")

radius = clk.progress * (4.2 + windSpd * 1.4) * density
var burning = 0
var trees = 0
var ash = 0

s = viz.scene(title: "محاكاة انتشار حريق الغابة", grid: false, axes: false, bounds: [-5.2, 5.2, -4.2, 4.2])
for r in 0..<8:
  for c in 0..<10:
    px = -4.5 + c * 1.0
    py = -3.5 + r * 1.0
    seed = ((r * 13 + c * 7) % 10) / 10.0
    if seed < density:
      dx = (px + 2.8) / (1.0 + windSpd * 0.55)
      dy = py
      dist = m.sqrt(dx * dx + dy * dy)
      if dist < radius - 0.9:
        ash = ash + 1
        s.point("a{r}_{c}", px, py, color: "#475569", radius: 5.5)
      else if dist < radius:
        burning = burning + 1
        s.point("f{r}_{c}", px, py, color: "#F97316", radius: 8.0)
      else:
        trees = trees + 1
        s.point("t{r}_{c}", px, py, color: "#10B981", radius: 6.5)

s.readout("أشجار سليمة", trees, decimals: 0, color: "#10B981")
s.readout("جبهة مشتعلة", burning, decimals: 0, color: "#F97316")
s.readout("مساحة محترقة", ash, decimals: 0, color: "#94A3B8")
s.render()
''',
  ),

  // 10. Newton Cooling & Heat Sink
  StudioPreset(
    id: 'sim_newton_cooling',
    titleAr: 'محاكاة: قانون نيوتن للتبريد وتشتيت الحرارة',
    titleEn: 'Sim: Newton Law of Cooling & Thermal Decay',
    subtitleAr:
        'حساب انخفاض حرارة سائل ساخن أو معالج حاسوب عبر الزمن ومقارنة معامل التبريد k',
    fileName: 'newton_cooling.quds',
    category: StudioCategory.simulations,
    isAnimated: false,
    code: '''use dart:math as m
use quds:viz as viz

t0 = viz.slider("t0", min: 55.0, max: 100.0, value: 92.0, step: 1.0, label: "الحرارة الابتدائية °C")
tEnv = viz.slider("env", min: 5.0, max: 35.0, value: 22.0, step: 1.0, label: "حرارة المحيط °C")
k = viz.slider("k", min: 0.03, max: 0.25, value: 0.09, step: 0.01, label: "معامل التبريد k")

var mins = []
var temps = []
for i in 0..45:
  t = i * 1.0
  temp = tEnv + (t0 - tEnv) * m.exp(-k * t)
  mins.add(t)
  temps.add(temp)

tDrink = (if t0 > 60.0 and tEnv < 60.0: -m.log((60.0 - tEnv) / (t0 - tEnv)) / k else: 0.0)
viz.latex(r"T(t) = T_{env} + (T_0 - T_{env})\,e^{-kt}", title: "معادلة نيوتن للتبريد")
viz.plot(mins, temps, title: "منحنى التبريد الحراري T(t)", xLabel: "الزمن (دقيقة)", yLabel: "°C", color: "#F97316")
viz.table(["البيان", "القيمة"], [["الحرارة الابتدائية", t0.toStringAsFixed(1) + " °C"], ["حرارة الغرفة", tEnv.toStringAsFixed(1) + " °C"], ["زمن الوصول إلى 60°C", tDrink.toStringAsFixed(1) + " دقيقة"], ["الحرارة بعد 20 دقيقة", temps[20].toStringAsFixed(1) + " °C"]], title: "ملخص التبريد")
''',
  ),

  // 11. Factory Assembly Line & QA
  StudioPreset(
    id: 'sim_factory_line',
    titleAr: 'محاكاة: خط إنتاج مصنع وفحص الجودة الآلي (OEE)',
    titleEn: 'Sim: Factory Conveyor Belt & Automated QA',
    subtitleAr:
        'حركة المنتجات على سير الإنتاج مع مستشعر فرز المعيب وحساب الكفاءة الكلية OEE',
    fileName: 'factory_line.quds',
    category: StudioCategory.simulations,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 15.0, loop: true)
beltSpd = viz.slider("spd", min: 0.8, max: 3.0, value: 1.6, step: 0.1, label: "سرعة السير")
defectPct = viz.slider("def", min: 0.0, max: 35.0, value: 12.0, step: 1.0, label: "نسبة العيوب %")

s = viz.scene(title: "خط الإنتاج الآلي ومحطة فحص الجودة", grid: false, axes: false, bounds: [-5.5, 5.5, -3.5, 3.5])
s.polygon("belt", [[-5.2, -0.55], [5.2, -0.55], [5.2, 0.55], [-5.2, 0.55]], stroke: "#64748B", fill: "#1E293B")
s.polygon("scanner", [[-0.5, 0.7], [0.5, 0.7], [0.5, 2.2], [-0.5, 2.2]], stroke: "#38BDF8", fill: "#0F172A")
s.segment("laser", [0.0, 0.7], [0.0, -0.55], color: "#EF4444", strokeWidth: 2.0, dashed: true)
s.label("scanLbl", [0.0, 2.55], "مستشعر QA", color: "#38BDF8")

var good = 0
var bad = 0
for i in 0..<7:
  x = -5.0 + ((clk.t * beltSpd * 1.4 + i * 1.5) % 10.2)
  isBad = ((i * 29) % 100) < defectPct
  y = (if isBad and x > 0.4: -1.6 else: 0.0)
  col = (if x < 0.0: "#94A3B8" else: (if isBad: "#EF4444" else: "#10B981"))
  s.point("item{i}", x, y, color: col, radius: 8.5)
  if isBad: bad = bad + 1 else: good = good + 1

throughput = beltSpd * 42.0
oee = (100.0 - defectPct) * 0.92
s.readout("الإنتاجية", throughput, unit: "قطعة/د", decimals: 0, color: "#38BDF8")
s.readout("كفاءة OEE", oee, unit: "%", decimals: 1, color: "#10B981")
s.readout("معدل المعيب", defectPct, unit: "%", decimals: 0, color: "#EF4444")
s.render()
''',
  ),

  // 12. Atmospheric Pressure & Storm Vortex
  StudioPreset(
    id: 'sim_storm_vortex',
    titleAr: 'محاكاة: المنخفض الجوي وحقل الرياح الدوار (Coriolis)',
    titleEn: 'Sim: Atmospheric Cyclone & Pressure Field',
    subtitleAr:
        'حقل متجهات الرياح حول عين الإعصار مع حركة المنخفض الجوي وسرعة الدوران',
    fileName: 'storm_vortex.quds',
    category: StudioCategory.simulations,
    isAnimated: false,
    code: '''use dart:math as m
use quds:viz as viz

intensity = viz.slider("int", min: 0.5, max: 3.0, value: 1.8, step: 0.1, label: "شدة المنخفض الجوي")
inflow = viz.slider("inflow", min: 0.1, max: 0.9, value: 0.35, step: 0.05, label: "معامل الشفط نحو العين")

stormWind(x: double, y: double) -> List<double>:
  r = m.sqrt(x * x + y * y) + 0.45
  swirl = intensity / r
  vx = -y * swirl - x * inflow * 0.55
  vy = x * swirl - y * inflow * 0.55
  return [vx, vy]

viz.vectorField(stormWind, xMin: -3.5, xMax: 3.5, yMin: -3.5, yMax: 3.5, steps: 10, title: "حقل الرياح الدوار حول عين المنخفض الجوي")
pEye = 1013.0 - intensity * 28.0
maxWind = intensity * 62.0
viz.table(["عنصر الرصد", "القيمة"], [["الضغط في العين", pEye.toStringAsFixed(1) + " hPa"], ["سرعة الرياح القصوى", maxWind.toStringAsFixed(0) + " km/h"], ["التصنيف", (if maxWind > 120.0: "إعصار قوي" else: "منخفض نشط")]], title: "بيانات الأرصاد الجوية")
''',
  ),
];
