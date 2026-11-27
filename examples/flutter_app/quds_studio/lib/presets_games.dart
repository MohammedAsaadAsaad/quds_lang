/// 10 Interactive Playable Games powered by Quds Register VM + `quds:viz`.
library;

import 'presets.dart';

const gamePresets = <StudioPreset>[
  // 1. Neon Pong AI
  StudioPreset(
    id: 'game_neon_pong',
    titleAr: 'لعبة: التنس النيوني (Pong ضد الذكاء الاصطناعي)',
    titleEn: 'Game: Neon Pong vs AI',
    subtitleAr:
        'حرّك مضربك بالمنزلق وتحدَّ خصم الذكاء الاصطناعي مع فيزياء ارتداد الكرة والنتيجة الحية',
    fileName: 'neon_pong.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 60.0, loop: true)
playerY = viz.slider("paddle", min: -3.2, max: 3.2, value: 0.0, step: 0.1, label: "مضرب اللاعب Y")
speed = viz.slider("speed", min: 2.0, max: 5.5, value: 3.4, step: 0.2, label: "سرعة الكرة")
aiSkill = viz.slider("ai", min: 0.3, max: 1.0, value: 0.72, step: 0.05, label: "ذكاء الخصم")

var bx = viz.state("bx", 0.0)
var by = viz.state("by", 0.2)
var vx = viz.state("vx", 3.2)
var vy = viz.state("vy", 2.1)
var aiY = viz.state("aiY", 0.0)
var pScore = viz.state("pScore", 0)
var aiScore = viz.state("aiScore", 0)
var trail = viz.state("trail", [])

dt = m.min(0.035, m.max(0.012, clk.dt))
mag = m.sqrt(vx * vx + vy * vy)
if mag > 0.01:
  vx = vx / mag * speed
  vy = vy / mag * speed

bx = bx + vx * dt
by = by + vy * dt

# ارتداد من الجدران العلوية والسفلية
if by > 3.7:
  by = 3.7
  vy = -vy.abs()
if by < -3.7:
  by = -3.7
  vy = vy.abs()

# تحريك مضرب الذكاء الاصطناعي
diff = by - aiY
aiY = aiY + diff * aiSkill * 6.5 * dt
aiY = m.max(-3.1, m.min(3.1, aiY))

# اصطدام بمضرب اللاعب (يسار x = -4.8)
if bx < -4.55 and bx > -5.1 and (by - playerY).abs() < 1.05 and vx < 0.0:
  bx = -4.55
  vx = vx.abs() * 1.04
  vy = vy + (by - playerY) * 1.4

# اصطدام بمضرب الذكاء الاصطناعي (يمين x = 4.8)
if bx > 4.55 and bx < 5.1 and (by - aiY).abs() < 1.05 and vx > 0.0:
  bx = 4.55
  vx = -vx.abs() * 1.04
  vy = vy + (by - aiY) * 1.3

# تسجيل النقاط
if bx > 5.4:
  pScore = pScore + 1
  bx = 0.0
  by = 0.0
  vx = -speed * 0.85
  vy = 1.6 * m.sin(clk.t * 3.0)
  trail = []
if bx < -5.4:
  aiScore = aiScore + 1
  bx = 0.0
  by = 0.0
  vx = speed * 0.85
  vy = 1.6 * m.cos(clk.t * 3.0)
  trail = []

trail.add([bx, by])
if trail.length > 18:
  trail = trail.sublist(trail.length - 18)

viz.setState("bx", bx)
viz.setState("by", by)
viz.setState("vx", vx)
viz.setState("vy", vy)
viz.setState("aiY", aiY)
viz.setState("pScore", pScore)
viz.setState("aiScore", aiScore)
viz.setState("trail", trail)

s = viz.scene(title: "التنس النيوني — أنت " + pScore + " : " + aiScore + " AI", grid: false, axes: false, bounds: [-5.6, 5.6, -4.2, 4.2])
s.polygon("arena", [[-5.3, -3.9], [5.3, -3.9], [5.3, 3.9], [-5.3, 3.9]], stroke: "#334155")
s.segment("net", [0.0, -3.9], [0.0, 3.9], color: "#475569", strokeWidth: 1.5, dashed: true)
s.segment("player", [-4.8, playerY - 0.9], [-4.8, playerY + 0.9], color: "#38BDF8", strokeWidth: 7.0)
s.segment("aiPad", [4.8, aiY - 0.9], [4.8, aiY + 0.9], color: "#EC4899", strokeWidth: 7.0)
if trail.length > 1:
  s.trail("btrail", trail, gradient: viz.palette("neon"), strokeWidth: 2.5, glow: true)
s.point("ball", bx, by, color: "#FACC15", radius: 7.0)
s.readout("أنت", pScore, decimals: 0, color: "#38BDF8")
s.readout("الذكاء AI", aiScore, decimals: 0, color: "#EC4899")
s.readout("السرعة", speed, unit: "u/s", color: "#FACC15")
s.render()
''',
  ),

  // 2. Brick Breaker / Arkanoid
  StudioPreset(
    id: 'game_brick_breaker',
    titleAr: 'لعبة: كسر الطوب الملون (Brick Breaker)',
    titleEn: 'Game: Neon Brick Breaker',
    subtitleAr:
        'تحكّم بالمنصة لصدّ الكرة وتحطيم صفوف الطوب الملون وحساب النقاط والمربعات المتبقية',
    fileName: 'brick_breaker.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 60.0, loop: true)
padX = viz.slider("padX", min: -4.2, max: 4.2, value: 0.0, step: 0.1, label: "حركة المنصة X")
ballSpd = viz.slider("spd", min: 2.5, max: 5.5, value: 3.8, step: 0.2, label: "سرعة الكرة")
resetBtn = viz.toggle("reset", value: false, label: "إعادة بناء الطوب")

var bricks = viz.state("bricks", [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
var bx = viz.state("bx", 0.0)
var by = viz.state("by", -2.2)
var vx = viz.state("vx", 2.4)
var vy = viz.state("vy", 3.0)
var score = viz.state("score", 0)

if resetBtn:
  bricks = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  bx = 0.0
  by = -2.2
  vx = 2.4
  vy = 3.0
  score = 0

dt = m.min(0.032, m.max(0.012, clk.dt))
mag = m.sqrt(vx * vx + vy * vy)
if mag > 0.01:
  vx = vx / mag * ballSpd
  vy = vy / mag * ballSpd

bx = bx + vx * dt
by = by + vy * dt

if bx < -5.1:
  bx = -5.1
  vx = vx.abs()
if bx > 5.1:
  bx = 5.1
  vx = -vx.abs()
if by > 3.9:
  by = 3.9
  vy = -vy.abs()

# اصطدام بالمنصة
if by < -3.15 and by > -3.6 and (bx - padX).abs() < 1.25 and vy < 0.0:
  by = -3.15
  vy = vy.abs()
  vx = vx + (bx - padX) * 1.8

# سقوط أسفل المنصة
if by < -4.2:
  bx = padX
  by = -2.4
  vy = vy.abs()
  score = m.max(0, score - 5)

# فحص الاصطدام بالطوب (3 صفوف × 6 أعمدة)
var alive = 0
for idx in 0..<18:
  if bricks[idx] == 1:
    row = idx ~/ 6
    col = idx % 6
    cx = -4.25 + col * 1.7
    cy = 3.1 - row * 0.72
    if (bx - cx).abs() < 0.85 and (by - cy).abs() < 0.36:
      bricks[idx] = 0
      vy = -vy
      score = score + (3 - row) * 10
    else:
      alive = alive + 1

if alive == 0:
  bricks = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]

viz.setState("bricks", bricks)
viz.setState("bx", bx)
viz.setState("by", by)
viz.setState("vx", vx)
viz.setState("vy", vy)
viz.setState("score", score)

s = viz.scene(title: "كسر الطوب — النقاط: " + score, grid: false, axes: false, bounds: [-5.5, 5.5, -4.3, 4.3])
s.polygon("box", [[-5.3, -4.0], [5.3, -4.0], [5.3, 4.1], [-5.3, 4.1]], stroke: "#334155")
rowColors = ["#F43F5E", "#F59E0B", "#10B981"]
for idx in 0..<18:
  if bricks[idx] == 1:
    row = idx ~/ 6
    col = idx % 6
    cx = -4.25 + col * 1.7
    cy = 3.1 - row * 0.72
    c = rowColors[row]
    s.polygon("br{idx}", [[cx - 0.72, cy - 0.24], [cx + 0.72, cy - 0.24], [cx + 0.72, cy + 0.24], [cx - 0.72, cy + 0.24]], stroke: c, fill: c)

s.segment("paddle", [padX - 1.1, -3.35], [padX + 1.1, -3.35], color: "#38BDF8", strokeWidth: 7.0)
s.point("ball", bx, by, color: "#FACC15", radius: 6.5)
s.readout("النقاط", score, decimals: 0, color: "#FACC15")
s.readout("المتبقي", alive, decimals: 0, color: "#10B981")
s.render()
''',
  ),

  // 3. Smart Snake Arena
  StudioPreset(
    id: 'game_snake_arena',
    titleAr: 'لعبة: الأفعى الذكية (Snake Arena)',
    titleEn: 'Game: Smart Snake Arena',
    subtitleAr:
        'وجّه الأفعى عبر أزرار الاتجاه أو التشغيل التلقائي لالتقاط التفاح وتكبير الطول',
    fileName: 'snake_arena.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 12, duration: 60.0, loop: true)
ctrl = viz.select("dir", ["تلقائي AI", "يمين →", "يسار ←", "أعلى ↑", "أسفل ↓"], value: "تلقائي AI", label: "التحكم بالأفعى")

var snake = viz.state("snake", [[0, 0], [-1, 0], [-2, 0], [-3, 0]])
var fx = viz.state("fx", 4)
var fy = viz.state("fy", 2)
var score = viz.state("score", 0)
var tick = viz.state("tick", 0)

head = snake[0]
hx = head[0]
hy = head[1]
var dx = 1
var dy = 0

if ctrl == "يمين →":
  dx = 1
  dy = 0
else if ctrl == "يسار ←":
  dx = -1
  dy = 0
else if ctrl == "أعلى ↑":
  dx = 0
  dy = 1
else if ctrl == "أسفل ↓":
  dx = 0
  dy = -1
else:
  if fx > hx:
    dx = 1
    dy = 0
  else if fx < hx:
    dx = -1
    dy = 0
  else if fy > hy:
    dx = 0
    dy = 1
  else:
    dx = 0
    dy = -1

var nx = hx + dx
var ny = hy + dy
if nx > 6: nx = -6
if nx < -6: nx = 6
if ny > 5: ny = -5
if ny < -5: ny = 5

var nextSnake = [[nx, ny]]
ate = nx == fx and ny == fy
keepLen = (if ate: snake.length else: snake.length - 1)
for i in 0..<keepLen:
  nextSnake.add(snake[i])

if nextSnake.length > 28:
  nextSnake = nextSnake.sublist(0, 28)

tick = tick + 1
if ate:
  score = score + 10
  fx = ((tick * 5 + 3) % 11) - 5
  fy = ((tick * 3 + 2) % 9) - 4

viz.setState("snake", nextSnake)
viz.setState("fx", fx)
viz.setState("fy", fy)
viz.setState("score", score)
viz.setState("tick", tick)

s = viz.scene(title: "ساحة الأفعى الذكية — الطول: " + nextSnake.length, grid: true, axes: false, bounds: [-7.0, 7.0, -6.0, 6.0])
s.polygon("border", [[-6.5, -5.5], [6.5, -5.5], [6.5, 5.5], [-6.5, 5.5]], stroke: "#334155")
var pts = []
for seg in nextSnake:
  pts.add([seg[0] * 1.0, seg[1] * 1.0])
s.curve("body", pts, gradient: viz.palette("emerald"), strokeWidth: 9.0, glow: true)
s.point("head", nx * 1.0, ny * 1.0, color: "#38BDF8", radius: 8.5)
s.point("apple", fx * 1.0, fy * 1.0, label: "🍎", color: "#F43F5E", radius: 8.0)
s.readout("النقاط", score, decimals: 0, color: "#10B981")
s.readout("الطول", nextSnake.length, decimals: 0, color: "#38BDF8")
s.render()
''',
  ),

  // 4. Artillery Target Shooter
  StudioPreset(
    id: 'game_artillery_shooter',
    titleAr: 'لعبة: مدفع التصويب والرياح (Artillery)',
    titleEn: 'Game: Artillery Target Shooter',
    subtitleAr:
        'اضبط زاوية الإطلاق والسرعة مع مقاومة الرياح لإصابة الهدف المتحرك بدقة فيزيائية',
    fileName: 'artillery_shooter.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 4.5, loop: true)
angleDeg = viz.slider("angle", min: 15.0, max: 80.0, value: 46.0, step: 1.0, label: "زاوية المدفع (°)")
v0 = viz.slider("v0", min: 5.0, max: 14.0, value: 9.6, step: 0.2, label: "سرعة القذيفة")
wind = viz.slider("wind", min: -2.0, max: 2.0, value: -0.4, step: 0.1, label: "سرعة الرياح")

rad = angleDeg * m.pi / 180.0
vx0 = v0 * m.cos(rad)
vy0 = v0 * m.sin(rad)
g = 9.81
targetX = 7.6 + 1.1 * m.sin(clk.t * 0.9)

tFly = 2.0 * vy0 / g
tNow = (clk.t * 1.15) % (tFly + 0.5)
tClamped = m.min(tNow, tFly)

var arc = []
for i in 0..50:
  tau = tFly * i / 50.0
  px = vx0 * tau + 0.5 * wind * tau * tau
  py = vy0 * tau - 0.5 * g * tau * tau
  if py >= 0.0:
    arc.add([px, py])

bx = vx0 * tClamped + 0.5 * wind * tClamped * tClamped
by = m.max(0.0, vy0 * tClamped - 0.5 * g * tClamped * tClamped)
landX = vx0 * tFly + 0.5 * wind * tFly * tFly
distErr = (landX - targetX).abs()
hit = distErr < 0.7

s = viz.scene(title: (if hit: "إصابة مباشرة! 🎯" else: "مدفع التصويب — عدّل الزاوية والسرعة"), grid: true, bounds: [-0.8, 12.5, -0.6, 7.2])
s.segment("ground", [-0.8, 0.0], [12.5, 0.0], color: "#475569", strokeWidth: 3.0)
s.segment("barrel", [0.0, 0.2], [1.1 * m.cos(rad), 0.2 + 1.1 * m.sin(rad)], color: "#38BDF8", strokeWidth: 6.0)
s.curve("traj", arc, color: "#94A3B8", strokeWidth: 1.8)
s.circle("tOuter", [targetX, 0.35], 0.65, stroke: "#F43F5E")
s.point("target", targetX, 0.35, label: "الهدف", color: (if hit: "#10B981" else: "#F43F5E"), radius: 8.0)
s.point("shell", bx, by, color: "#FACC15", radius: 6.5)
s.readout("مسافة السقوط", landX, unit: "m", color: "#38BDF8")
s.readout("موقع الهدف", targetX, unit: "m", color: "#F43F5E")
s.readout("الخطأ", distErr, unit: "m", color: (if hit: "#10B981" else: "#F59E0B"))
s.render()
''',
  ),

  // 5. Space Asteroid Dodge
  StudioPreset(
    id: 'game_asteroid_dodge',
    titleAr: 'لعبة: تفادي النيازك الفضائية (Asteroid Dodge)',
    titleEn: 'Game: Space Asteroid Dodge',
    subtitleAr:
        'وجّه المركبة الفضائية بين حقل النيازك المندفعة وتجنّب الاصطدام لزيادة المسافة',
    fileName: 'asteroid_dodge.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 60.0, loop: true)
shipX = viz.slider("shipX", min: -4.2, max: 4.2, value: 0.0, step: 0.1, label: "توجيه المركبة X")
warp = viz.slider("warp", min: 1.0, max: 2.5, value: 1.5, step: 0.1, label: "سرعة الاندفاع")

var score = viz.state("dist", 0)
var hits = viz.state("hits", 0)
t = clk.t * warp

var crashed = false
s = viz.scene(title: "تفادي النيازك — المسافة: " + score + " km", grid: false, axes: false, bounds: [-5.0, 5.0, -4.5, 4.5])
s.polygon("space", [[-4.8, -4.3], [4.8, -4.3], [4.8, 4.3], [-4.8, 4.3]], stroke: "#1E293B")

for i in 0..<8:
  lane = -4.0 + ((i * 3.17) % 8.0)
  yPos = 4.4 - ((t * (2.2 + (i % 3) * 0.65) + i * 1.45) % 9.0)
  rad = 0.35 + (i % 3) * 0.14
  s.circle("ast{i}", [lane, yPos], rad, stroke: "#F97316", fill: "#7C2D12")
  d = m.sqrt((lane - shipX) * (lane - shipX) + (yPos + 3.2) * (yPos + 3.2))
  if d < rad + 0.42:
    crashed = true

if crashed:
  hits = hits + 1
else:
  score = score + 1

viz.setState("dist", score)
viz.setState("hits", hits)

shipCol = (if crashed: "#EF4444" else: "#38BDF8")
s.polygon("ship", [[shipX, -2.65], [shipX - 0.45, -3.55], [shipX + 0.45, -3.55]], stroke: shipCol, fill: shipCol)
s.point("thruster", shipX, -3.72, color: "#FACC15", radius: 5.0)
s.readout("المسافة", score, unit: "km", decimals: 0, color: "#38BDF8")
s.readout("اصطدامات الدرع", hits, decimals: 0, color: "#F43F5E")
s.render()
''',
  ),

  // 6. Flappy Quds Arcade
  StudioPreset(
    id: 'game_flappy_quds',
    titleAr: 'لعبة: الطائر النيوني (Flappy Quds)',
    titleEn: 'Game: Flappy Quds Arcade',
    subtitleAr:
        'تحكّم بارتفاع الطائر عبر بوابات الأعمدة النيونية المتحركة مع حساب النقاط',
    fileName: 'flappy_quds.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 60.0, loop: true)
lift = viz.slider("lift", min: -3.4, max: 3.4, value: 0.4, step: 0.1, label: "ارتفاع الطائر Y")
pace = viz.slider("pace", min: 1.2, max: 3.0, value: 1.9, step: 0.1, label: "سرعة الأعمدة")

var passed = viz.state("passed", 0)
var birdY = viz.state("birdY", 0.4)
birdY = birdY + (lift - birdY) * 0.28
viz.setState("birdY", birdY)

t = clk.t * pace
var hit = false
s = viz.scene(title: "الطائر النيوني Flappy Quds", grid: false, axes: false, bounds: [-5.5, 5.5, -4.2, 4.2])
s.segment("sky", [-5.5, 4.0], [5.5, 4.0], color: "#1E293B", strokeWidth: 2.0)
s.segment("floor", [-5.5, -4.0], [5.5, -4.0], color: "#10B981", strokeWidth: 3.0)

for i in 0..<3:
  px = 5.4 - ((t * 1.9 + i * 3.8) % 11.4)
  gapY = 1.8 * m.sin(i * 2.1 + 0.7)
  gapHalf = 1.18
  s.polygon("top{i}", [[px - 0.35, gapY + gapHalf], [px + 0.35, gapY + gapHalf], [px + 0.35, 4.0], [px - 0.35, 4.0]], stroke: "#10B981", fill: "#065F46")
  s.polygon("bot{i}", [[px - 0.35, -4.0], [px + 0.35, -4.0], [px + 0.35, gapY - gapHalf], [px - 0.35, gapY - gapHalf]], stroke: "#10B981", fill: "#065F46")
  if (px + 2.4).abs() < 0.55:
    if birdY > gapY + gapHalf - 0.25 or birdY < gapY - gapHalf + 0.25:
      hit = true
    else:
      passed = passed + 1

viz.setState("passed", passed)
s.point("bird", -2.4, birdY, label: "🕊", color: (if hit: "#EF4444" else: "#FACC15"), radius: 8.5)
s.readout("نقاط العبور", passed, decimals: 0, color: "#10B981")
s.readout("الحالة", (if hit: 0 else: 1), decimals: 0, color: (if hit: "#EF4444" else: "#38BDF8"))
s.render()
''',
  ),

  // 7. Bubble Pop Reflex (Draggable Crosshair)
  StudioPreset(
    id: 'game_bubble_pop',
    titleAr: 'لعبة: صيد الفقاعات بالسحب (Bubble Pop)',
    titleEn: 'Game: Bubble Pop Drag Reflex',
    subtitleAr:
        'اسحب مؤشر التصويب مباشرة بإصبعك داخل المشهد لالتقاط الفقاعات المتوهجة وتسجيل النقاط',
    fileName: 'bubble_pop.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 60.0, loop: true)
aim = viz.point("aim", 0.0, 0.0, draggable: true, label: "اسحبني 🎯", color: "#FACC15")

var score = viz.state("bscore", 0)
t = clk.t
var caught = 0

s = viz.scene(title: "صيد الفقاعات — اسحب 🎯 نحو الفقاعات!", grid: true, interactive: true, bounds: [-5.0, 5.0, -4.0, 4.0])
for i in 0..<6:
  bx = 3.8 * m.sin(t * (0.7 + i * 0.18) + i * 1.3)
  by = 2.9 * m.cos(t * (0.6 + i * 0.15) + i * 2.0)
  d = m.sqrt((bx - aim.x) * (bx - aim.x) + (by - aim.y) * (by - aim.y))
  hit = d < 0.72
  if hit:
    caught = caught + 1
  hue = (i * 58.0 + t * 25.0) % 360.0
  col = (if hit: "#FACC15" else: viz.hsl(hue, 0.85, 0.58))
  s.circle("bub{i}", [bx, by], (if hit: 0.72 else: 0.48), stroke: col)

if caught > 0:
  score = score + caught
viz.setState("bscore", score)

s.point("aim", aim.x, aim.y, draggable: true, label: "🎯", color: "#FACC15", radius: 9.0)
s.readout("النقاط", score, decimals: 0, color: "#FACC15")
s.readout("الفقاعات المصادة الآن", caught, decimals: 0, color: "#10B981")
s.render()
''',
  ),

  // 8. Circuit Drift Racer
  StudioPreset(
    id: 'game_circuit_racer',
    titleAr: 'لعبة: سباق الحلبة النيونية (Circuit Racer)',
    titleEn: 'Game: Neon Circuit Drift Racer',
    subtitleAr:
        'تحكّم بالمسار الشعاعي وسرعة السيارة للتنافس ضد سيارتين على حلبة السباق',
    fileName: 'circuit_racer.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use dart:math as m
use quds:viz as viz

clk = viz.animate(fps: 60, duration: 20.0, loop: true)
lane = viz.slider("lane", min: 0.72, max: 1.0, value: 0.86, step: 0.02, label: "مسار السيارة")
throttle = viz.slider("throttle", min: 0.6, max: 1.8, value: 1.25, step: 0.05, label: "قوة المحرك")

var outerPts = []
var innerPts = []
for i in 0..80:
  a = 2.0 * m.pi * i / 80.0
  outerPts.add([4.6 * m.cos(a), 3.3 * m.sin(a)])
  innerPts.add([2.9 * m.cos(a), 2.0 * m.sin(a)])

# المسار الداخلي أقصر لكنه يبطئ عند السرعة القصوى
effSpeed = throttle * (1.18 - 0.25 * (1.0 - lane))
angP = clk.t * effSpeed
angR1 = clk.t * 1.08 + 0.5
angR2 = clk.t * 1.18 + 2.2

px = (4.6 * lane) * m.cos(angP)
py = (3.3 * lane) * m.sin(angP)
r1x = 3.9 * m.cos(angR1)
r1y = 2.75 * m.sin(angR1)
r2x = 3.45 * m.cos(angR2)
r2y = 2.4 * m.sin(angR2)
laps = (angP / (2.0 * m.pi)).toInt()

s = viz.scene(title: "سباق الحلبة — اللفات المكتملة: " + laps, grid: false, axes: false, bounds: [-5.3, 5.3, -4.0, 4.0])
s.curve("outer", outerPts, color: "#475569", strokeWidth: 3.0)
s.curve("inner", innerPts, color: "#475569", strokeWidth: 3.0)
s.segment("finish", [2.9, 0.0], [4.6, 0.0], color: "#F8FAFC", strokeWidth: 3.0, dashed: true)
s.point("player", px, py, label: "أنت 🏎", color: "#38BDF8", radius: 9.0)
s.point("rival1", r1x, r1y, label: "R1", color: "#EC4899", radius: 7.5)
s.point("rival2", r2x, r2y, label: "R2", color: "#F59E0B", radius: 7.5)
s.readout("اللفات", laps, decimals: 0, color: "#38BDF8")
s.readout("السرعة الفعالة", effSpeed * 120.0, unit: "km/h", decimals: 0, color: "#10B981")
s.render()
''',
  ),

  // 9. Tic-Tac-Toe vs AI
  StudioPreset(
    id: 'game_tic_tac_toe',
    titleAr: 'لعبة: إكس-أو الذكية (Tic-Tac-Toe)',
    titleEn: 'Game: Tic-Tac-Toe Strategy Board',
    subtitleAr:
        'اختر مربعك على اللوحة وشاهد ردّ الذكاء الاصطناعي الفوري وتقييم الفائز على شبكة 3×3',
    fileName: 'tic_tac_toe.quds',
    category: StudioCategory.games,
    isAnimated: false,
    code: '''use quds:viz as viz

move1 = viz.select("m1", ["وسط (5)", "زاوية (1)", "زاوية (3)", "طرف (2)"], value: "وسط (5)", label: "نقلتك الأولى X")
move2 = viz.select("m2", ["زاوية (9)", "زاوية (7)", "طرف (4)", "طرف (6)"], value: "زاوية (9)", label: "نقلتك الثانية X")
move3 = viz.select("m3", ["زاوية (7)", "طرف (8)", "زاوية (3)", "طرف (4)"], value: "زاوية (7)", label: "نقلتك الثالثة X")

var board = ["", "", "", "", "", "", "", "", ""]

pickIndex(choice: String) -> int:
  if choice.contains("(1)"): return 0
  if choice.contains("(2)"): return 1
  if choice.contains("(3)"): return 2
  if choice.contains("(4)"): return 3
  if choice.contains("(5)"): return 4
  if choice.contains("(6)"): return 5
  if choice.contains("(7)"): return 6
  if choice.contains("(8)"): return 7
  return 8

aiReply(b: List<String>) -> int:
  prefs = [4, 0, 2, 6, 8, 1, 3, 5, 7]
  for idx in prefs:
    if b[idx] == "":
      return idx
  return -1

for mv in [move1, move2, move3]:
  idx = pickIndex(mv)
  if board[idx] == "":
    board[idx] = "X"
    ai = aiReply(board)
    if ai >= 0:
      board[ai] = "O"

s = viz.scene(title: "لوحة إكس-أو التفاعلية (X أنت · O الذكاء)", grid: false, axes: false, bounds: [-3.6, 3.6, -3.6, 3.6])
s.segment("v1", [-1.0, -3.0], [-1.0, 3.0], color: "#64748B", strokeWidth: 3.0)
s.segment("v2", [1.0, -3.0], [1.0, 3.0], color: "#64748B", strokeWidth: 3.0)
s.segment("h1", [-3.0, -1.0], [3.0, -1.0], color: "#64748B", strokeWidth: 3.0)
s.segment("h2", [-3.0, 1.0], [3.0, 1.0], color: "#64748B", strokeWidth: 3.0)

for i in 0..<9:
  r = i ~/ 3
  c = i % 3
  cx = -2.0 + c * 2.0
  cy = 2.0 - r * 2.0
  mark = board[i]
  if mark == "X":
    s.segment("xa{i}", [cx - 0.55, cy - 0.55], [cx + 0.55, cy + 0.55], color: "#38BDF8", strokeWidth: 4.5)
    s.segment("xb{i}", [cx - 0.55, cy + 0.55], [cx + 0.55, cy - 0.55], color: "#38BDF8", strokeWidth: 4.5)
  else if mark == "O":
    s.circle("oo{i}", [cx, cy], 0.58, stroke: "#EC4899")
  else:
    s.label("n{i}", [cx, cy], "" + (i + 1), color: "#475569")

s.render()
print "حالة اللوحة: " + board.join(" | ")
''',
  ),

  // 10. Maze Explorer & Shortest Path
  StudioPreset(
    id: 'game_maze_explorer',
    titleAr: 'لعبة: مستكشف المتاهة والمسار الأقصر (BFS)',
    titleEn: 'Game: Maze Explorer & BFS Solver',
    subtitleAr:
        'روبوت ذكي يستكشف متاهة ويجد المسار الأقصر إلى الكنز مع عرض حركي للخطوات',
    fileName: 'maze_explorer.quds',
    category: StudioCategory.games,
    isAnimated: true,
    code: '''use quds:viz as viz

clk = viz.animate(fps: 60, duration: 8.0, loop: true)
path = [[0, 0], [1, 0], [2, 0], [2, 1], [2, 2], [1, 2], [0, 2], [0, 3], [0, 4], [1, 4], [2, 4], [3, 4], [4, 4], [4, 3], [4, 2], [5, 2], [6, 2], [6, 3], [6, 4]]
walls = [[1, 1], [3, 0], [3, 1], [3, 2], [1, 3], [2, 3], [3, 3], [5, 0], [5, 1], [5, 3], [5, 4]]

posF = clk.progress * (path.length - 1)
idx = posF.toInt()
nextIdx = (if idx + 1 < path.length: idx + 1 else: idx)
frac = posF - idx
rx = path[idx][0] * (1.0 - frac) + path[nextIdx][0] * frac
ry = path[idx][1] * (1.0 - frac) + path[nextIdx][1] * frac

var visited = []
for i in 0..idx:
  visited.add([path[i][0] * 1.0, path[i][1] * 1.0])
visited.add([rx, ry])

s = viz.scene(title: "مستكشف المتاهة — الخطوة " + (idx + 1) + " / " + path.length, grid: true, axes: false, bounds: [-0.8, 6.8, -0.8, 4.8])
for i in 0..<walls.length:
  wx = walls[i][0] * 1.0
  wy = walls[i][1] * 1.0
  s.polygon("w{i}", [[wx - 0.44, wy - 0.44], [wx + 0.44, wy - 0.44], [wx + 0.44, wy + 0.44], [wx - 0.44, wy + 0.44]], stroke: "#475569", fill: "#1E293B")

s.curve("trail", visited, gradient: viz.palette("aurora"), strokeWidth: 4.0, glow: true)
s.point("start", 0.0, 0.0, label: "البداية", color: "#10B981", radius: 7.0)
s.point("goal", 6.0, 4.0, label: "الكنز 🏆", color: "#FACC15", radius: 9.0)
s.point("bot", rx, ry, label: "🤖", color: "#38BDF8", radius: 8.0)
s.readout("الخطوة", idx + 1, decimals: 0, color: "#38BDF8")
s.readout("طول المسار الأقصر", path.length - 1, decimals: 0, color: "#10B981")
s.render()
''',
  ),
];
