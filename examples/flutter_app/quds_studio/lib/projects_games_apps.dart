/// Complete, finger/touch-interactive multi-folder Quds Games & Standalone Apps
/// designed for full-screen standalone launch (`QudsStandaloneAppPage`) as well
/// as Quds Studio's embedded Register VM (`quds:viz` `viz.pointer()` + 60fps
/// `viz.animate` + `viz.state` + `quds:assets` binary BMP & JSON assets).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

import 'project_templates.dart';

// ---------------------------------------------------------------------------
// Procedural Binary BMP Sprites & App Banners (encoded via encodeQudsBmp24)
// ---------------------------------------------------------------------------

Uint8List _buildArcadeBannerBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
        return [56, 189, 248];
      }
      // Brick rows at top
      if (y >= 3 &&
          y <= 9 &&
          x >= 4 &&
          x <= 43 &&
          (x % 8 != 0) &&
          (y % 3 != 0)) {
        if (y < 6) return [244, 63, 94];
        return [245, 158, 11];
      }
      // Glowing ball
      final bx = x - 26;
      final by = y - 14;
      if (bx * bx + by * by <= 4) return [248, 250, 252];
      // Neon paddle at bottom
      if (y >= 19 && y <= 20 && x >= 16 && x <= 32) return [34, 211, 238];
      return [11, 17, 32];
    });
  });
  return encodeQudsBmp24(rows, scale: 3);
}

Uint8List _buildJetEmblemBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
        return [14, 165, 233];
      }
      // Skyscraper laser gates on right
      if (x >= 35 && x <= 39 && (y <= 7 || y >= 15)) {
        return [16, 185, 129];
      }
      // Sleek jet fuselage
      if (y >= 10 && y <= 13 && x >= 11 && x <= 25) {
        return [56, 189, 248];
      }
      if (y >= 8 && y <= 15 && x >= 14 && x <= 18) {
        return [224, 242, 254];
      }
      // Exhaust flame
      if (y >= 11 && y <= 12 && x >= 6 && x <= 10) {
        return [249, 115, 22];
      }
      return [15, 23, 42];
    });
  });
  return encodeQudsBmp24(rows, scale: 3);
}

Uint8List _buildStarfighterBadgeBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
        return [168, 85, 247];
      }
      // Enemy drones
      if ((y >= 4 && y <= 6) &&
          ((x >= 10 && x <= 14) || (x >= 32 && x <= 36))) {
        return [244, 63, 94];
      }
      // Plasma beam
      if (x == 24 && y >= 7 && y <= 14) return [34, 211, 238];
      // Player fighter triangle
      final dx = (x - 24).abs();
      if (y >= 15 && y <= 20 && dx <= (y - 14)) {
        return dx <= 1 ? [250, 204, 21] : [56, 189, 248];
      }
      if ((x * 13 + y * 7) % 29 == 0) return [148, 163, 184];
      return [8, 11, 24];
    });
  });
  return encodeQudsBmp24(rows, scale: 3);
}

Uint8List _buildTargetMapBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
        return [245, 158, 11];
      }
      if (y >= 20) return [22, 101, 52];
      // Slingshot fork on left
      if (x >= 8 && x <= 10 && y >= 14 && y <= 19) return [180, 83, 9];
      // Tower blocks on right
      if (x >= 32 && x <= 40 && y >= 10 && y <= 19) {
        if (x >= 35 && x <= 37 && y >= 13 && y <= 15) return [236, 72, 153];
        return [148, 163, 184];
      }
      // Dotted arc
      if (x >= 13 && x <= 30 && x % 4 == 0) {
        final arcY = 14 - ((x - 13) * (31 - x) ~/ 18);
        if ((y - arcY).abs() <= 1) return [250, 204, 21];
      }
      return [15, 23, 42];
    });
  });
  return encodeQudsBmp24(rows, scale: 3);
}

Uint8List _buildMandalaStudioBmp() {
  const w = 40;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
        return [236, 72, 153];
      }
      final dx = x - 20.0;
      final dy = y - 12.0;
      final r2 = dx * dx + dy * dy;
      if (r2 < 10) return [250, 204, 21];
      if (r2 >= 24 && r2 <= 42) return [236, 72, 153];
      if (r2 >= 64 && r2 <= 88) return [56, 189, 248];
      if (r2 >= 110 && r2 <= 130) return [168, 85, 247];
      return [10, 14, 28];
    });
  });
  return encodeQudsBmp24(rows, scale: 3);
}

Uint8List _buildFinAppCardBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) {
        return [16, 185, 129];
      }
      // Rising emerald growth bars
      if (y >= 18 && y <= 20 && x >= 6 && x <= 41) return [51, 65, 85];
      if (x >= 8 && x <= 12 && y >= 13 && y <= 18) return [56, 189, 248];
      if (x >= 16 && x <= 20 && y >= 10 && y <= 18) return [16, 185, 129];
      if (x >= 24 && x <= 28 && y >= 7 && y <= 18) return [34, 197, 94];
      if (x >= 32 && x <= 38 && y >= 4 && y <= 18) return [250, 204, 21];
      return [12, 20, 36];
    });
  });
  return encodeQudsBmp24(rows, scale: 3);
}

// ---------------------------------------------------------------------------
// 1. Neon Brick Breaker (Touch Slide Paddle + Tap to Launch)
// ---------------------------------------------------------------------------

QudsWorkspace buildNeonBrickBreakerWorkspace() {
  final ws = QudsWorkspace(
    name: 'neon_brick_breaker',
    entryPoint: 'main.quds',
    files: {
      'assets/levels.json': '''{
  "title": "Neon Brick Breaker Arcade",
  "cols": 6,
  "rows": 4,
  "baseSpeed": 7.6,
  "paddleWidth": 2.9
}
''',
      'levels/bricks.quds':
          '''# Generates destructible brick HP array (1 = normal, 2 = armored, 0 = broken)
buildLevel(stage: int) -> List:
    var hp = []
    var r = 0
    while r < 4:
        var c = 0
        while c < 6:
            var health = 1
            if r == 0 and stage >= 1:
                health = 2
            if stage >= 2 and (r + c) % 3 == 0:
                health = 2
            hp.add(health)
            c = c + 1
        r = r + 1
    return hp

brickColor(row: int, hp: int) -> String:
    if hp >= 2:
        return "#F43F5E"
    if row == 0:
        return "#F97316"
    if row == 1:
        return "#FACC15"
    if row == 2:
        return "#10B981"
    return "#38BDF8"
''',
      'game/physics.quds': '''use dart:math as m

clampVal(v: double, lo: double, hi: double) -> double:
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v

rectPoly(cx: double, cy: double, w: double, h: double) -> List:
    hw = w * 0.5
    hh = h * 0.5
    return [[cx - hw, cy - hh], [cx + hw, cy - hh], [cx + hw, cy + hh], [cx - hw, cy + hh]]
''',
      'main.quds': '''use dart:math as m
use quds:viz as viz
use quds:assets as assets
use levels.bricks as lvl
use game.physics as phys

clk = viz.animate(fps: 60)
ptr = viz.pointer()
cfg = assets.readJson("assets/levels.json")

speedMult = viz.slider("speed", min: 0.7, max: 1.6, value: 1.0, label: "سرعة الكرة")
paddleSize = viz.slider("paddle", min: 2.0, max: 4.0, value: 2.9, label: "عرض المضرب")
resetClicks = viz.button("reset_game", label: "🔄 لعبة جديدة")

# Persistent game state
var lastReset = viz.state("lastReset", 0)
var lastTaps = viz.state("lastTaps", 0)
var stage = viz.state("stage", 1)
var score = viz.state("score", 0)
var lives = viz.state("lives", 3)
var combo = viz.state("combo", 0)
var px = viz.state("px", 0.0)
var bx = viz.state("bx", 0.0)
var by = viz.state("by", -4.4)
var bvx = viz.state("bvx", 4.2)
var bvy = viz.state("bvy", 6.2)
var launched = viz.state("launched", false)
var gameOver = viz.state("gameOver", false)
var bricks = viz.state("bricks", lvl.buildLevel(1))
var sparkX = viz.state("sparkX", 0.0)
var sparkY = viz.state("sparkY", 0.0)
var sparkLife = viz.state("sparkLife", 0.0)

# Handle reset button
if resetClicks > lastReset:
    lastReset = resetClicks
    stage = 1
    score = 0
    lives = 3
    combo = 0
    px = 0.0
    bx = 0.0
    by = -4.4
    bvx = 4.2
    bvy = 6.2
    launched = false
    gameOver = false
    bricks = lvl.buildLevel(1)

# Finger slides paddle smoothly
halfPad = paddleSize * 0.5
if ptr.down or ptr.active:
    targetX = phys.clampVal(ptr.x, -5.6 + halfPad, 5.6 - halfPad)
    px = px + (targetX - px) * 0.45

# Tap launches docked ball or restarts after Game Over
if ptr.taps > lastTaps:
    lastTaps = ptr.taps
    if gameOver:
        stage = 1
        score = 0
        lives = 3
        combo = 0
        bricks = lvl.buildLevel(1)
        gameOver = false
        launched = true
        bx = px
        by = -4.3
        bvx = 3.8
        bvy = 6.4
    else:
        if not launched:
            launched = true
            bvx = 3.6 + (px * 0.4)
            bvy = 6.4

var dt = clk.dt
if dt > 0.04:
    dt = 0.04

if sparkLife > 0.0:
    sparkLife = sparkLife - dt * 3.0
    if sparkLife < 0.0:
        sparkLife = 0.0

if not launched and not gameOver:
    bx = px
    by = -4.35
else:
    if not gameOver:
        bx = bx + bvx * speedMult * dt
        by = by + bvy * speedMult * dt

        # Wall collisions
        if bx < -5.35:
            bx = -5.35
            bvx = (bvx).abs()
        if bx > 5.35:
            bx = 5.35
            bvx = -(bvx).abs()
        if by > 6.55:
            by = 6.55
            bvy = -(bvy).abs()

        # Paddle collision
        if bvy < 0.0 and by <= -4.65 and by >= -5.35 and (bx - px).abs() <= halfPad + 0.3:
            offset = (bx - px) / halfPad
            bvy = (bvy).abs()
            bvx = offset * 6.8
            by = -4.62
            combo = 0

        # Brick collisions (4 rows x 6 cols)
        var aliveCount = 0
        var r = 0
        var hitDone = false
        while r < 4:
            var c = 0
            while c < 6:
                idx = r * 6 + c
                hp = bricks[idx]
                if hp > 0:
                    cx = -4.35 + c * 1.74
                    cy = 5.35 - r * 0.92
                    if not hitDone and (bx - cx).abs() < 0.96 and (by - cy).abs() < 0.52:
                        hitDone = true
                        bricks[idx] = hp - 1
                        bvy = -bvy
                        combo = combo + 1
                        score = score + (100 * combo)
                        sparkX = cx
                        sparkY = cy
                        sparkLife = 1.0
                    if bricks[idx] > 0:
                        aliveCount = aliveCount + 1
                c = c + 1
            r = r + 1

        # Next stage when all bricks cleared
        if aliveCount == 0:
            stage = stage + 1
            score = score + 500
            bricks = lvl.buildLevel(stage)
            launched = false
            bx = px
            by = -4.35

        # Missed ball
        if by < -6.3:
            lives = lives - 1
            combo = 0
            if lives <= 0:
                gameOver = true
                launched = false
            else:
                launched = false
                bx = px
                by = -4.35

# Persist state
viz.setState("lastReset", lastReset)
viz.setState("lastTaps", lastTaps)
viz.setState("stage", stage)
viz.setState("score", score)
viz.setState("lives", lives)
viz.setState("combo", combo)
viz.setState("px", px)
viz.setState("bx", bx)
viz.setState("by", by)
viz.setState("bvx", bvx)
viz.setState("bvy", bvy)
viz.setState("launched", launched)
viz.setState("gameOver", gameOver)
viz.setState("bricks", bricks)
viz.setState("sparkX", sparkX)
viz.setState("sparkY", sparkY)
viz.setState("sparkLife", sparkLife)

# Render Neon Arena
scene = viz.scene(title: "Neon Brick Breaker", grid: false, axes: false, bounds: [-5.8, 5.8, -6.5, 7.0], touch: true)
scene.polygon("arena", [[-5.65, -6.2], [5.65, -6.2], [5.65, 6.8], [-5.65, 6.8]], stroke: "#1E293B", fill: "#070D1D", closed: true)

# Draw bricks
var r2 = 0
while r2 < 4:
    var c2 = 0
    while c2 < 6:
        idx2 = r2 * 6 + c2
        hp2 = bricks[idx2]
        if hp2 > 0:
            cx2 = -4.35 + c2 * 1.74
            cy2 = 5.35 - r2 * 0.92
            col = lvl.brickColor(r2, hp2)
            scene.polygon("b_" + idx2.toString(), phys.rectPoly(cx2, cy2, 1.56, 0.72), stroke: "#F8FAFC", fill: col, closed: true)
        c2 = c2 + 1
    r2 = r2 + 1

# Hit explosion ring
if sparkLife > 0.05:
    scene.circle("spark", [sparkX, sparkY], 0.35 + (1.0 - sparkLife) * 1.1, stroke: "#FACC15")

# Paddle with neon glow
scene.polygon("pad", phys.rectPoly(px, -5.0, paddleSize, 0.42), stroke: "#E0F2FE", fill: "#06B6D4", closed: true)
scene.segment("pad_glow", [px - halfPad + 0.15, -4.8], [px + halfPad - 0.15, -4.8], color: "#38BDF8", strokeWidth: 3.5)

# Ball + short velocity trail
scene.segment("trail", [bx, by], [bx - bvx * 0.035, by - bvy * 0.035], color: "#38BDF8", strokeWidth: 4.5)
scene.circle("ball", [bx, by], 0.28, stroke: "#38BDF8", fill: "#F8FAFC")

if gameOver:
    scene.label("over", [0.0, 0.4], "GAME OVER — المس الشاشة للإعادة", color: "#F43F5E")
else:
    if not launched:
        scene.label("hint", [0.0, -1.6], "حرّك إصبعك للمضرب والمس للإطلاق 🚀", color: "#38BDF8")

scene.readout("النقاط", score, color: "#38BDF8")
scene.readout("المرحلة", stage, color: "#FACC15")
scene.readout("الأرواح", lives, color: "#F43F5E")
scene.readout("كومبو", combo, unit: "x", color: "#10B981")
scene.render()

assets.renderImage("assets/arcade_banner.bmp", title: "Neon Brick Breaker — Arcade Banner", caption: "لعبة تحطيم الطوب الكاملة باللمس — 60 إطار/ثانية")
''',
    },
  );
  ws.writeAssetBytes('assets/arcade_banner.bmp', _buildArcadeBannerBmp());
  return ws;
}

// ---------------------------------------------------------------------------
// 2. Sky Flappy Jet (Tap Anywhere to Boost Through Laser Skyscrapers)
// ---------------------------------------------------------------------------

QudsWorkspace buildSkyFlappyJetWorkspace() {
  final ws = QudsWorkspace(
    name: 'sky_flappy_jet',
    entryPoint: 'main.quds',
    files: {
      'assets/flight_config.json': '''{
  "gravity": -22.0,
  "flapBoost": 8.4,
  "gapSize": 3.5,
  "scrollSpeed": 4.2
}
''',
      'game/flight_physics.quds': '''use dart:math as m

jetPolygon(x: double, y: double, tilt: double) -> List:
    c = m.cos(tilt)
    s = m.sin(tilt)
    # Sleek delta jet vertices rotated by pitch tilt
    return [
        [x + 0.72 * c - 0.0 * s, y + 0.72 * s + 0.0 * c],
        [x - 0.52 * c - 0.44 * s, y - 0.52 * s + 0.44 * c],
        [x - 0.25 * c - 0.0 * s, y - 0.25 * s + 0.0 * c],
        [x - 0.52 * c + 0.44 * s, y - 0.52 * s - 0.44 * c]
    ]
''',
      'world/obstacles.quds': '''use dart:math as m

nextGapY(seed: double) -> double:
    return m.sin(seed * 1.93 + 0.7) * 2.4

pillarPoly(x: double, yBot: double, yTop: double, halfW: double) -> List:
    return [[x - halfW, yBot], [x + halfW, yBot], [x + halfW, yTop], [x - halfW, yTop]]
''',
      'main.quds': '''use dart:math as m
use quds:viz as viz
use quds:assets as assets
use game.flight_physics as fl
use world.obstacles as obs

clk = viz.animate(fps: 60)
ptr = viz.pointer()
cfg = assets.readJson("assets/flight_config.json")

gapSize = viz.slider("gap", min: 2.6, max: 4.5, value: 3.5, label: "اتساع البوابة")
scrollSpeed = viz.slider("scroll", min: 3.0, max: 6.5, value: 4.2, label: "سرعة الطيران")
resetClicks = viz.button("reset_jet", label: "🔄 إعادة الرحلة")

var lastReset = viz.state("lastReset", 0)
var lastTaps = viz.state("lastTaps", 0)
var jy = viz.state("jy", 0.5)
var jvy = viz.state("jvy", 0.0)
var started = viz.state("started", false)
var crashed = viz.state("crashed", false)
var score = viz.state("score", 0)
var best = viz.state("best", 0)
var p1x = viz.state("p1x", 5.5)
var p1g = viz.state("p1g", 0.8)
var p1s = viz.state("p1s", false)
var p2x = viz.state("p2x", 11.2)
var p2g = viz.state("p2g", -1.4)
var p2s = viz.state("p2s", false)
var seed = viz.state("seed", 1.0)
var flame = viz.state("flame", 0.0)

if resetClicks > lastReset:
    lastReset = resetClicks
    jy = 0.5
    jvy = 0.0
    started = false
    crashed = false
    score = 0
    p1x = 5.5
    p1g = 0.8
    p1s = false
    p2x = 11.2
    p2g = -1.4
    p2s = false

# Tap anywhere with finger to boost jet upward!
if ptr.taps > lastTaps:
    lastTaps = ptr.taps
    if crashed:
        jy = 0.5
        jvy = 7.6
        started = true
        crashed = false
        score = 0
        p1x = 5.8
        p1g = 0.6
        p1s = false
        p2x = 11.6
        p2g = -1.2
        p2s = false
        flame = 1.0
    else:
        started = true
        jvy = 7.8
        flame = 1.0

var dt = clk.dt
if dt > 0.04:
    dt = 0.04

if flame > 0.0:
    flame = flame - dt * 4.5
    if flame < 0.0:
        flame = 0.0

if started and not crashed:
    jvy = jvy - 21.0 * dt
    jy = jy + jvy * dt

    p1x = p1x - scrollSpeed * dt
    p2x = p2x - scrollSpeed * dt

    if p1x < -6.8:
        p1x = 6.2
        seed = seed + 1.0
        p1g = obs.nextGapY(seed)
        p1s = false
    if p2x < -6.8:
        p2x = 6.2
        seed = seed + 1.0
        p2g = obs.nextGapY(seed)
        p2s = false

    # Score when passing gate center (-2.4)
    if not p1s and p1x < -2.4:
        p1s = true
        score = score + 1
    if not p2s and p2x < -2.4:
        p2s = true
        score = score + 1
    if score > best:
        best = score

    # Collisions with floor/ceiling or laser pillars
    halfGap = gapSize * 0.5
    if jy < -5.3 or jy > 5.5:
        crashed = true
    if (p1x - (-2.4)).abs() < 0.92:
        if jy > p1g + halfGap - 0.35 or jy < p1g - halfGap + 0.35:
            crashed = true
    if (p2x - (-2.4)).abs() < 0.92:
        if jy > p2g + halfGap - 0.35 or jy < p2g - halfGap + 0.35:
            crashed = true
else:
    if not started:
        jy = 0.4 + m.sin(clk.t * 3.5) * 0.45

viz.setState("lastReset", lastReset)
viz.setState("lastTaps", lastTaps)
viz.setState("jy", jy)
viz.setState("jvy", jvy)
viz.setState("started", started)
viz.setState("crashed", crashed)
viz.setState("score", score)
viz.setState("best", best)
viz.setState("p1x", p1x)
viz.setState("p1g", p1g)
viz.setState("p1s", p1s)
viz.setState("p2x", p2x)
viz.setState("p2g", p2g)
viz.setState("p2s", p2s)
viz.setState("seed", seed)
viz.setState("flame", flame)

scene = viz.scene(title: "Sky Flappy Jet", grid: false, axes: false, bounds: [-6.0, 6.0, -5.8, 5.8], touch: true)
scene.polygon("sky", [[-6.0, -5.8], [6.0, -5.8], [6.0, 5.8], [-6.0, 5.8]], stroke: "#0F172A", fill: "#071022", closed: true)

# Ground neon runway
scene.polygon("ground", [[-6.0, -5.8], [6.0, -5.8], [6.0, -5.35], [-6.0, -5.35]], stroke: "#38BDF8", fill: "#0F172A", closed: true)

# Laser Gates
halfG = gapSize * 0.5
scene.polygon("p1_top", obs.pillarPoly(p1x, p1g + halfG, 5.8, 0.55), stroke: "#34D399", fill: "#065F46", closed: true)
scene.polygon("p1_bot", obs.pillarPoly(p1x, -5.35, p1g - halfG, 0.55), stroke: "#34D399", fill: "#065F46", closed: true)
scene.circle("star1", [p1x, p1g], 0.26, stroke: "#FACC15", fill: "#F59E0B")

scene.polygon("p2_top", obs.pillarPoly(p2x, p2g + halfG, 5.8, 0.55), stroke: "#38BDF8", fill: "#0C4A6E", closed: true)
scene.polygon("p2_bot", obs.pillarPoly(p2x, -5.35, p2g - halfG, 0.55), stroke: "#38BDF8", fill: "#0C4A6E", closed: true)
scene.circle("star2", [p2x, p2g], 0.26, stroke: "#FACC15", fill: "#F59E0B")

# Jet exhaust flame
if flame > 0.08 and not crashed:
    scene.circle("flame1", [-3.05, jy], 0.25 + flame * 0.3, stroke: "#FACC15", fill: "#F97316")

var tilt = jvy * 0.065
if tilt > 0.65:
    tilt = 0.65
if tilt < -0.75:
    tilt = -0.75
var jetFill = "#38BDF8"
if crashed:
    jetFill = "#F43F5E"
scene.polygon("jet", fl.jetPolygon(-2.4, jy, tilt), stroke: "#F8FAFC", fill: jetFill, closed: true)

if crashed:
    scene.circle("boom", [-2.4, jy], 1.15, stroke: "#F97316")
    scene.label("msg", [0.0, 0.9], "اصطدام! المس الشاشة للتحليق مجدداً ✈️", color: "#F43F5E")
else:
    if not started:
        scene.label("hint", [0.0, 2.2], "المس أي مكان في الشاشة للطيران! 👆✈️", color: "#38BDF8")

scene.readout("النقاط", score, color: "#10B981")
scene.readout("أفضل نتيجة", best, color: "#FACC15")
scene.readout("الارتفاع", jy + 5.3, unit: "m", color: "#38BDF8")
scene.render()

assets.renderImage("assets/jet_emblem.bmp", title: "Sky Flappy Jet — Emblem", caption: "لعبة الطائرة النفاثة التفاعلية باللمس المباشر")
''',
    },
  );
  ws.writeAssetBytes('assets/jet_emblem.bmp', _buildJetEmblemBmp());
  return ws;
}

// ---------------------------------------------------------------------------
// 3. Galaxy Defender (Drag Starfighter + Auto-Fire Twin Plasma Cannons)
// ---------------------------------------------------------------------------

QudsWorkspace buildSpaceDefenderWorkspace() {
  final ws = QudsWorkspace(
    name: 'space_defender_touch',
    entryPoint: 'main.quds',
    files: {
      'assets/enemies.json': '''{
  "enemyCount": 5,
  "baseWaveSpeed": 2.4,
  "maxShield": 100
}
''',
      'game/combat.quds': '''fighterPoly(x: double, y: double) -> List:
    return [
        [x, y + 0.72],
        [x - 0.68, y - 0.52],
        [x, y - 0.25],
        [x + 0.68, y - 0.52]
    ]

dronePoly(x: double, y: double, s: double) -> List:
    return [
        [x, y - s],
        [x - s, y + s * 0.45],
        [x, y + s],
        [x + s, y + s * 0.45]
    ]
''',
      'game/waves.quds': '''use dart:math as m

spawnEnemyX(slot: int, wave: double) -> double:
    return -4.2 + ((slot * 2.15 + wave * 0.9) % 8.4)
''',
      'main.quds': '''use dart:math as m
use quds:viz as viz
use quds:assets as assets
use game.combat as cmb
use game.waves as wv

clk = viz.animate(fps: 60)
ptr = viz.pointer()
cfg = assets.readJson("assets/enemies.json")

overdrive = viz.toggle("overdrive", value: true, label: "مدفع البلازما المزدوج ⚡")
resetClicks = viz.button("reset_space", label: "🔄 موجة جديدة")

var lastReset = viz.state("lastReset", 0)
var lastTaps = viz.state("lastTaps", 0)
var sx = viz.state("sx", 0.0)
var sy = viz.state("sy", -4.6)
var shield = viz.state("shield", 100)
var score = viz.state("score", 0)
var wave = viz.state("wave", 1)
var fireCd = viz.state("fireCd", 0.0)

# Active bullets [x1, y1, x2, y2, ...] (up to 10 bolts)
var bxList = viz.state("bxList", [])
var byList = viz.state("byList", [])

# 5 Enemy drones
var ex = viz.state("ex", [-3.8, -1.8, 0.2, 2.2, 4.0])
var ey = viz.state("ey", [6.2, 7.6, 5.4, 8.2, 6.8])
var boomX = viz.state("boomX", 0.0)
var boomY = viz.state("boomY", 0.0)
var boomT = viz.state("boomT", 0.0)

if resetClicks > lastReset or (shield <= 0 and ptr.taps > lastTaps):
    lastReset = resetClicks
    lastTaps = ptr.taps
    sx = 0.0
    sy = -4.6
    shield = 100
    score = 0
    wave = 1
    bxList = []
    byList = []
    ex = [-3.8, -1.8, 0.2, 2.2, 4.0]
    ey = [6.2, 7.6, 5.4, 8.2, 6.8]

if ptr.taps > lastTaps:
    lastTaps = ptr.taps

var dt = clk.dt
if dt > 0.04:
    dt = 0.04

if boomT > 0.0:
    boomT = boomT - dt * 3.5
    if boomT < 0.0:
        boomT = 0.0

if shield > 0:
    # Drag starfighter smoothly toward finger
    if ptr.down or ptr.active:
        var tx = ptr.x
        var ty = ptr.y
        if tx < -5.0:
            tx = -5.0
        if tx > 5.0:
            tx = 5.0
        if ty < -5.4:
            ty = -5.4
        if ty > 1.5:
            ty = 1.5
        sx = sx + (tx - sx) * 0.32
        sy = sy + (ty - sy) * 0.32

    # Auto-fire while touching (or pulse fire)
    fireCd = fireCd - dt
    if fireCd <= 0.0 and (ptr.down or not ptr.active):
        fireCd = 0.16
        if overdrive:
            bxList.add(sx - 0.38)
            byList.add(sy + 0.55)
            bxList.add(sx + 0.38)
            byList.add(sy + 0.55)
        else:
            bxList.add(sx)
            byList.add(sy + 0.72)

    # Advance bullets
    var nextBx = []
    var nextBy = []
    var bi = 0
    while bi < bxList.length:
        nbx = bxList[bi]
        nby = byList[bi] + 13.5 * dt
        var consumed = false
        var ei = 0
        while ei < 5:
            if not consumed and (nbx - ex[ei]).abs() < 0.72 and (nby - ey[ei]).abs() < 0.72:
                consumed = true
                boomX = ex[ei]
                boomY = ey[ei]
                boomT = 1.0
                score = score + 50
                wave = 1 + (score / 400).floor()
                ex[ei] = wv.spawnEnemyX(ei, wave + score * 0.03)
                ey[ei] = 6.6 + (ei % 3) * 1.1
            ei = ei + 1
        if not consumed and nby < 7.2:
            nextBx.add(nbx)
            nextBy.add(nby)
        bi = bi + 1
    bxList = nextBx
    byList = nextBy

    # Advance enemies
    var ei2 = 0
    enemySpeed = 2.1 + wave * 0.35
    while ei2 < 5:
        ey[ei2] = ey[ei2] - enemySpeed * dt
        ex[ei2] = ex[ei2] + m.sin(clk.t * 2.6 + ei2 * 1.3) * 1.4 * dt
        if ex[ei2] < -5.1:
            ex[ei2] = -5.1
        if ex[ei2] > 5.1:
            ex[ei2] = 5.1
        # Collision with player
        if (ex[ei2] - sx).abs() < 0.88 and (ey[ei2] - sy).abs() < 0.88:
            shield = shield - 25
            if shield < 0:
                shield = 0
            boomX = sx
            boomY = sy
            boomT = 1.0
            ey[ei2] = 7.2
            ex[ei2] = wv.spawnEnemyX(ei2, wave + 1)
        if ey[ei2] < -6.3:
            ey[ei2] = 6.8
            ex[ei2] = wv.spawnEnemyX(ei2, wave + clk.t)
        ei2 = ei2 + 1

viz.setState("lastReset", lastReset)
viz.setState("lastTaps", lastTaps)
viz.setState("sx", sx)
viz.setState("sy", sy)
viz.setState("shield", shield)
viz.setState("score", score)
viz.setState("wave", wave)
viz.setState("fireCd", fireCd)
viz.setState("bxList", bxList)
viz.setState("byList", byList)
viz.setState("ex", ex)
viz.setState("ey", ey)
viz.setState("boomX", boomX)
viz.setState("boomY", boomY)
viz.setState("boomT", boomT)

scene = viz.scene(title: "Galaxy Defender", grid: false, axes: false, bounds: [-5.8, 5.8, -6.4, 6.8], touch: true)
scene.polygon("space", [[-5.8, -6.4], [5.8, -6.4], [5.8, 6.8], [-5.8, 6.8]], stroke: "#1E1B4B", fill: "#050816", closed: true)

# Parallax starfield
var st = 0
while st < 16:
    starX = -5.2 + ((st * 1.73) % 10.4)
    starY = 6.4 - (((clk.t * (1.8 + (st % 3) * 0.9)) + st * 1.37) % 12.8)
    scene.point("st_" + st.toString(), starX, starY, color: "#475569", radius: 1.8)
    st = st + 1

# Plasma bolts
var bDraw = 0
while bDraw < bxList.length:
    scene.segment("bl_" + bDraw.toString(), [bxList[bDraw], byList[bDraw] - 0.3], [bxList[bDraw], byList[bDraw] + 0.3], color: "#22D3EE", strokeWidth: 3.2)
    bDraw = bDraw + 1

# Enemy drones
var eDraw = 0
while eDraw < 5:
    scene.polygon("en_" + eDraw.toString(), cmb.dronePoly(ex[eDraw], ey[eDraw], 0.52), stroke: "#FDA4AF", fill: "#E11D48", closed: true)
    eDraw = eDraw + 1

# Explosion shockwave
if boomT > 0.05:
    scene.circle("boom", [boomX, boomY], 0.4 + (1.0 - boomT) * 1.4, stroke: "#FACC15")

# Player starfighter + engine glow
if shield > 0:
    scene.circle("thruster", [sx, sy - 0.55], 0.24 + m.sin(clk.t * 30.0) * 0.06, stroke: "#FACC15", fill: "#F97316")
    scene.polygon("ship", cmb.fighterPoly(sx, sy), stroke: "#E0F2FE", fill: "#38BDF8", closed: true)
    if not ptr.active:
        scene.label("hint", [0.0, -2.2], "اسحب بإصبعك للقيادة وإطلاق الليزر 🚀", color: "#A855F7")
else:
    scene.label("over", [0.0, 0.5], "تدمّر الدرع! المس الشاشة لموجة جديدة 💥", color: "#F43F5E")

scene.readout("النقاط", score, color: "#38BDF8")
scene.readout("الموجة", wave, color: "#A855F7")
scene.readout("الدرع", shield, unit: "%", color: "#10B981")
scene.render()

assets.renderImage("assets/starfighter_badge.bmp", title: "Galaxy Defender — Starfighter Badge", caption: "لعبة تصويب فضائية تفاعلية بالسحب واللمس")
''',
    },
  );
  ws.writeAssetBytes(
      'assets/starfighter_badge.bmp', _buildStarfighterBadgeBmp());
  return ws;
}

// ---------------------------------------------------------------------------
// 4. Gravity Slingshot Demolition (Pull Back with Finger & Release to Launch!)
// ---------------------------------------------------------------------------

QudsWorkspace buildSlingshotPhysicsWorkspace() {
  final ws = QudsWorkspace(
    name: 'slingshot_physics_angry',
    entryPoint: 'main.quds',
    files: {
      'assets/targets.json': '''{
  "anchorX": -4.4,
  "anchorY": -1.8,
  "gravity": -9.8,
  "maxPull": 2.4,
  "powerScale": 6.4
}
''',
      'physics/trajectory.quds':
          '''predictArc(x0: double, y0: double, vx: double, vy: double, wind: double, gravity: double) -> List:
    var pts = []
    var i = 0
    while i < 16:
        t = i * 0.085
        px = x0 + vx * t + 0.5 * wind * t * t
        py = y0 + vy * t + 0.5 * gravity * t * t
        if py >= -4.2:
            pts.add([px, py])
        i = i + 1
    return pts
''',
      'levels/fortress.quds': '''initTargetAlive() -> List:
    return [1, 1, 1, 1, 1]

targetCoords(stage: int) -> List:
    if stage % 2 == 1:
        return [[2.6, -3.5], [4.2, -3.5], [3.4, -2.2], [2.6, -0.9], [4.2, -0.9]]
    return [[2.0, -3.5], [3.5, -3.5], [5.0, -3.5], [2.75, -2.0], [4.25, -2.0]]

blockPoly(cx: double, cy: double, w: double, h: double) -> List:
    hw = w * 0.5
    hh = h * 0.5
    return [[cx - hw, cy - hh], [cx + hw, cy - hh], [cx + hw, cy + hh], [cx - hw, cy + hh]]
''',
      'main.quds': '''use dart:math as m
use quds:viz as viz
use quds:assets as assets
use physics.trajectory as traj
use levels.fortress as fort

clk = viz.animate(fps: 60)
ptr = viz.pointer()
cfg = assets.readJson("assets/targets.json")

wind = viz.slider("wind", min: -3.5, max: 3.5, value: 0.0, label: "الرياح الجانبية")
nextBtn = viz.button("next_stage", label: "🏰 قلعة جديدة")

anchorX = -4.4
anchorY = -1.8
gravity = -9.8

var lastBtn = viz.state("lastBtn", 0)
var stage = viz.state("stage", 1)
var score = viz.state("score", 0)
var shots = viz.state("shots", 5)
var orbX = viz.state("orbX", anchorX)
var orbY = viz.state("orbY", anchorY)
var orbVx = viz.state("orbVx", 0.0)
var orbVy = viz.state("orbVy", 0.0)
var flying = viz.state("flying", false)
var aiming = viz.state("aiming", false)
var targets = viz.state("targets", fort.initTargetAlive())
var hitX = viz.state("hitX", 0.0)
var hitY = viz.state("hitY", 0.0)
var hitT = viz.state("hitT", 0.0)

if nextBtn > lastBtn:
    lastBtn = nextBtn
    stage = stage + 1
    shots = 5
    flying = false
    aiming = false
    orbX = anchorX
    orbY = anchorY
    targets = fort.initTargetAlive()

var dt = clk.dt
if dt > 0.04:
    dt = 0.04

if hitT > 0.0:
    hitT = hitT - dt * 3.0
    if hitT < 0.0:
        hitT = 0.0

# Pull back & release slingshot with finger
if not flying and shots > 0:
    if ptr.down:
        aiming = true
        var dx = ptr.x - anchorX
        var dy = ptr.y - anchorY
        dist = m.sqrt(dx * dx + dy * dy)
        if dist > 2.35:
            dx = dx * (2.35 / dist)
            dy = dy * (2.35 / dist)
        orbX = anchorX + dx
        orbY = anchorY + dy
    else:
        if aiming:
            aiming = false
            pullX = anchorX - orbX
            pullY = anchorY - orbY
            pullDist = m.sqrt(pullX * pullX + pullY * pullY)
            if pullDist > 0.25:
                orbVx = pullX * 6.4
                orbVy = pullY * 6.4
                flying = true
                shots = shots - 1
            else:
                orbX = anchorX
                orbY = anchorY

# Projectile physics & tower collisions
coords = fort.targetCoords(stage)
if flying:
    orbVx = orbVx + wind * dt
    orbVy = orbVy + gravity * dt
    orbX = orbX + orbVx * dt
    orbY = orbY + orbVy * dt

    # Ground bounce
    if orbY < -3.95:
        orbY = -3.95
        orbVy = -orbVy * 0.52
        orbVx = orbVx * 0.78

    # Check fortress targets
    var ti = 0
    while ti < 5:
        if targets[ti] == 1:
            tx = coords[ti][0]
            ty = coords[ti][1]
            if (orbX - tx).abs() < 0.78 and (orbY - ty).abs() < 0.78:
                targets[ti] = 0
                score = score + 250
                hitX = tx
                hitY = ty
                hitT = 1.0
                orbVx = orbVx * 0.65
                orbVy = orbVy * 0.65
        ti = ti + 1

    # End flight when out of bounds or stopped
    speedNow = m.sqrt(orbVx * orbVx + orbVy * orbVy)
    if orbX > 6.8 or orbX < -6.8 or (orbY <= -3.92 and speedNow < 0.85):
        flying = false
        orbX = anchorX
        orbY = anchorY
        orbVx = 0.0
        orbVy = 0.0

var remaining = 0
var k = 0
while k < 5:
    if targets[k] == 1:
        remaining = remaining + 1
    k = k + 1

if remaining == 0 and not flying:
    stage = stage + 1
    score = score + 500
    shots = 5
    targets = fort.initTargetAlive()

viz.setState("lastBtn", lastBtn)
viz.setState("stage", stage)
viz.setState("score", score)
viz.setState("shots", shots)
viz.setState("orbX", orbX)
viz.setState("orbY", orbY)
viz.setState("orbVx", orbVx)
viz.setState("orbVy", orbVy)
viz.setState("flying", flying)
viz.setState("aiming", aiming)
viz.setState("targets", targets)
viz.setState("hitX", hitX)
viz.setState("hitY", hitY)
viz.setState("hitT", hitT)

scene = viz.scene(title: "Gravity Slingshot", grid: false, axes: false, bounds: [-6.4, 6.4, -4.6, 4.8], touch: true)
scene.polygon("sky", [[-6.4, -4.2], [6.4, -4.2], [6.4, 4.8], [-6.4, 4.8]], stroke: "#1E293B", fill: "#0A1328", closed: true)
scene.polygon("ground", [[-6.4, -4.6], [6.4, -4.6], [6.4, -4.2], [-6.4, -4.2]], stroke: "#10B981", fill: "#064E3B", closed: true)

# Slingshot fork
scene.segment("fork_base", [anchorX, -4.2], [anchorX, anchorY - 0.55], color: "#D97706", strokeWidth: 6.0)
scene.segment("fork_l", [anchorX, anchorY - 0.55], [anchorX - 0.32, anchorY + 0.15], color: "#F59E0B", strokeWidth: 4.5)
scene.segment("fork_r", [anchorX, anchorY - 0.55], [anchorX + 0.32, anchorY + 0.15], color: "#F59E0B", strokeWidth: 4.5)

# Elastic bands + live parabolic trajectory preview while pulling
if aiming or not flying:
    scene.segment("band_l", [anchorX - 0.32, anchorY + 0.1], [orbX, orbY], color: "#F43F5E", strokeWidth: 2.8)
    scene.segment("band_r", [anchorX + 0.32, anchorY + 0.1], [orbX, orbY], color: "#F43F5E", strokeWidth: 2.8)
if aiming:
    arcPts = traj.predictArc(orbX, orbY, (anchorX - orbX) * 6.4, (anchorY - orbY) * 6.4, wind, gravity)
    if arcPts.length >= 2:
        scene.curve("preview", arcPts, color: "#FACC15", strokeWidth: 2.2)

# Fortress tower blocks & glowing crystal cores
var td = 0
while td < 5:
    if targets[td] == 1:
        tx2 = coords[td][0]
        ty2 = coords[td][1]
        scene.polygon("blk_" + td.toString(), fort.blockPoly(tx2, ty2, 1.15, 1.1), stroke: "#CBD5E1", fill: "#334155", closed: true)
        scene.circle("core_" + td.toString(), [tx2, ty2], 0.28, stroke: "#F472B6", fill: "#EC4899")
    td = td + 1

if hitT > 0.05:
    scene.circle("hit_ring", [hitX, hitY], 0.45 + (1.0 - hitT) * 1.4, stroke: "#FACC15")

# Plasma projectile orb
scene.circle("orb", [orbX, orbY], 0.36, stroke: "#FDE047", fill: "#F97316")

if shots <= 0 and not flying and remaining > 0:
    scene.label("done", [0.0, 2.2], "انتهت الطلقات — اضغط (قلعة جديدة) 🏰", color: "#F43F5E")
else:
    if not aiming and not flying:
        scene.label("hint", [-0.6, 2.5], "اسحب الكرة للخلف بإصبعك ثم أطلقها! 🎯", color: "#FACC15")

scene.readout("النقاط", score, color: "#FACC15")
scene.readout("القلعة", stage, color: "#38BDF8")
scene.readout("الأهداف", remaining, color: "#EC4899")
scene.readout("الطلقات", shots, color: "#10B981")
scene.render()

assets.renderImage("assets/target_map.bmp", title: "Slingshot Arena Map", caption: "لعبة المنجنيق الفيزيائي — مسار قذيفة حقيقي مع الجاذبية والرياح")
''',
    },
  );
  ws.writeAssetBytes('assets/target_map.bmp', _buildTargetMapBmp());
  return ws;
}

// ---------------------------------------------------------------------------
// 5. Kaleidoscope Finger Art Studio (Real-Time Mandala Touch Painting App)
// ---------------------------------------------------------------------------

QudsWorkspace buildKaleidoscopeArtWorkspace() {
  final ws = QudsWorkspace(
    name: 'finger_paint_kaleidoscope',
    entryPoint: 'main.quds',
    files: {
      'assets/palettes.json': '''{
  "appName": "Quds Mandala Finger Studio",
  "maxSegments": 160,
  "defaultFolds": 8
}
''',
      'brush/symmetry.quds': '''use dart:math as m

rotateX(x: double, y: double, ang: double) -> double:
    return x * m.cos(ang) - y * m.sin(ang)

rotateY(x: double, y: double, ang: double) -> double:
    return x * m.sin(ang) + y * m.cos(ang)
''',
      'palette/themes.quds': '''parseFolds(mode: String) -> int:
    if mode == "6-Fold":
        return 6
    if mode == "12-Fold":
        return 12
    return 8
''',
      'main.quds': '''use dart:math as m
use quds:viz as viz
use quds:assets as assets
use brush.symmetry as sym
use palette.themes as th

clk = viz.animate(fps: 60)
ptr = viz.pointer()
cfg = assets.readJson("assets/palettes.json")

foldsLabel = viz.select("folds", ["6-Fold", "8-Fold", "12-Fold"], value: "8-Fold", label: "التماثل")
rainbowMode = viz.toggle("rainbow", value: true, label: "ألوان قوس قزح الحية 🌈")
brushColor = viz.color("brush_color", value: "#38BDF8", label: "لون الفرشاة")
brushWidth = viz.slider("width", min: 1.5, max: 6.0, value: 3.0, label: "سمك الخط")
undoClicks = viz.button("undo", label: "↩️ تراجع")
clearClicks = viz.button("clear", label: "🧹 مسح اللوحة")

folds = th.parseFolds(foldsLabel)

# Stroke segments stored as parallel lists [x1, y1, x2, y2, hue]
var x1s = viz.state("x1s", [])
var y1s = viz.state("y1s", [])
var x2s = viz.state("x2s", [])
var y2s = viz.state("y2s", [])
var cols = viz.state("cols", [])
var wasDown = viz.state("wasDown", false)
var prevX = viz.state("prevX", 0.0)
var prevY = viz.state("prevY", 0.0)
var hue = viz.state("hue", 190.0)
var lastClear = viz.state("lastClear", 0)
var lastUndo = viz.state("lastUndo", 0)

if clearClicks > lastClear:
    lastClear = clearClicks
    x1s = []
    y1s = []
    x2s = []
    y2s = []
    cols = []

if undoClicks > lastUndo:
    lastUndo = undoClicks
    var keep = x1s.length - 10
    if keep < 0:
        keep = 0
    var nx1 = []
    var ny1 = []
    var nx2 = []
    var ny2 = []
    var nc = []
    var ui = 0
    while ui < keep:
        nx1.add(x1s[ui])
        ny1.add(y1s[ui])
        nx2.add(x2s[ui])
        ny2.add(y2s[ui])
        nc.add(cols[ui])
        ui = ui + 1
    x1s = nx1
    y1s = ny1
    x2s = nx2
    y2s = ny2
    cols = nc

# Capture finger strokes cleanly
if ptr.down:
    if wasDown:
        dx = ptr.x - prevX
        dy = ptr.y - prevY
        dist = m.sqrt(dx * dx + dy * dy)
        if dist >= 0.14:
            hue = (hue + 5.0) % 360.0
            var segColor = brushColor
            if rainbowMode:
                segColor = viz.hsl(hue, 0.92, 0.58)
            # Keep memory bounded at 90 base strokes (90 * 8 = 720 crisp mirrored lines)
            if x1s.length >= 90:
                var trimmed1 = []
                var trimmed2 = []
                var trimmed3 = []
                var trimmed4 = []
                var trimmedC = []
                var ti = 1
                while ti < x1s.length:
                    trimmed1.add(x1s[ti])
                    trimmed2.add(y1s[ti])
                    trimmed3.add(x2s[ti])
                    trimmed4.add(y2s[ti])
                    trimmedC.add(cols[ti])
                    ti = ti + 1
                x1s = trimmed1
                y1s = trimmed2
                x2s = trimmed3
                y2s = trimmed4
                cols = trimmedC
            x1s.add(prevX)
            y1s.add(prevY)
            x2s.add(ptr.x)
            y2s.add(ptr.y)
            cols.add(segColor)
            prevX = ptr.x
            prevY = ptr.y
    else:
        wasDown = true
        prevX = ptr.x
        prevY = ptr.y
else:
    wasDown = false

viz.setState("x1s", x1s)
viz.setState("y1s", y1s)
viz.setState("x2s", x2s)
viz.setState("y2s", y2s)
viz.setState("cols", cols)
viz.setState("wasDown", wasDown)
viz.setState("prevX", prevX)
viz.setState("prevY", prevY)
viz.setState("hue", hue)
viz.setState("lastClear", lastClear)
viz.setState("lastUndo", lastUndo)

scene = viz.scene(title: "Kaleidoscope Finger Art", grid: false, axes: false, bounds: [-6.0, 6.0, -6.0, 6.0], touch: true)
scene.polygon("canvas_bg", [[-6.0, -6.0], [6.0, -6.0], [6.0, 6.0], [-6.0, 6.0]], stroke: "#1E293B", fill: "#050814", closed: true)

# Subtle mandala symmetry guide rings & axes
scene.circle("ring1", [0.0, 0.0], 2.0, stroke: "#1E293B")
scene.circle("ring2", [0.0, 0.0], 4.2, stroke: "#1E293B")
stepAng = (2.0 * m.pi) / folds
var g = 0
while g < folds:
    ang = g * stepAng
    scene.segment("axis_" + g.toString(), [0.0, 0.0], [m.cos(ang) * 5.6, m.sin(ang) * 5.6], color: "#1E293B", strokeWidth: 1.0, dashed: true)
    g = g + 1

# Draw starter glowing lotus if empty so screen looks inviting immediately
if x1s.length == 0:
    var p = 0
    while p < folds:
        a1 = p * stepAng + clk.t * 0.25
        a2 = a1 + stepAng * 0.5
        scene.segment("demo_" + p.toString(), [m.cos(a1) * 1.4, m.sin(a1) * 1.4], [m.cos(a2) * 3.1, m.sin(a2) * 3.1], color: viz.hsl((p * 45.0 + clk.t * 40.0) % 360.0, 0.85, 0.55), strokeWidth: 2.2)
        p = p + 1
    scene.label("hint", [0.0, -4.8], "ارسم بإصبعك على الشاشة لصنع لوحة مندالا مضيئة ✨🎨", color: "#F472B6")

# Render all user finger strokes mirrored across rotational symmetry
var sIdx = 0
while sIdx < x1s.length:
    ax = x1s[sIdx]
    ay = y1s[sIdx]
    bx = x2s[sIdx]
    by = y2s[sIdx]
    cHex = cols[sIdx]
    var f = 0
    while f < folds:
        ang = f * stepAng
        rx1 = sym.rotateX(ax, ay, ang)
        ry1 = sym.rotateY(ax, ay, ang)
        rx2 = sym.rotateX(bx, by, ang)
        ry2 = sym.rotateY(bx, by, ang)
        scene.segment("s_" + sIdx.toString() + "_" + f.toString(), [rx1, ry1], [rx2, ry2], color: cHex, strokeWidth: brushWidth)
        f = f + 1
    sIdx = sIdx + 1

# Live glowing cursor halo under finger
if ptr.down:
    scene.circle("cursor", [ptr.x, ptr.y], 0.22, stroke: "#F8FAFC", fill: "#EC4899")

scene.readout("التماثل", folds, unit: "محاور", color: "#EC4899")
scene.readout("ضربات الفرشاة", x1s.length, color: "#38BDF8")
scene.readout("الخطوط المرسومة", x1s.length * folds, color: "#FACC15")
scene.render()

assets.renderImage("assets/studio_logo.bmp", title: "Quds Mandala Studio Logo", caption: "تطبيق رسم فني تفاعلي بالأصابع مع تماثل هندسي حي")
''',
    },
  );
  ws.writeAssetBytes('assets/studio_logo.bmp', _buildMandalaStudioBmp());
  return ws;
}

// ---------------------------------------------------------------------------
// 6. Quds FinApp — Interactive Touch Budget Wheel & Compound Wealth Simulator
// ---------------------------------------------------------------------------

QudsWorkspace buildSmartFinAppWorkspace() {
  final ws = QudsWorkspace(
    name: 'smart_calc_budget_app',
    entryPoint: 'main.quds',
    files: {
      'assets/categories.json': '''{
  "currency": "USD",
  "labels": ["السكن والمعيشة", "الطعام والالتزامات", "الاستثمار والادخار", "التعليم والتطوير"],
  "colors": ["#38BDF8", "#F97316", "#10B981", "#A855F7"]
}
''',
      'finance/compound.quds':
          '''projectWealth(monthlySave: double, annualPct: double, years: int) -> List:
    r = (annualPct / 100.0) / 12.0
    var balance = 0.0
    var ys = []
    var y = 0
    while y <= years:
        ys.add(balance)
        var mIdx = 0
        while mIdx < 12:
            balance = balance * (1.0 + r) + monthlySave
            mIdx = mIdx + 1
        y = y + 1
    return ys
''',
      'finance/budget_engine.quds': '''use dart:math as m

slicePolygon(startAng: double, endAng: double, innerR: double, outerR: double) -> List:
    var pts = []
    var steps = 10
    var i = 0
    while i <= steps:
        a = startAng + (endAng - startAng) * (i / steps)
        pts.add([m.cos(a) * outerR, m.sin(a) * outerR])
        i = i + 1
    var j = steps
    while j >= 0:
        a2 = startAng + (endAng - startAng) * (j / steps)
        pts.add([m.cos(a2) * innerR, m.sin(a2) * innerR])
        j = j - 1
    return pts
''',
      'main.quds': '''use dart:math as m
use quds:viz as viz
use quds:assets as assets
use finance.compound as comp
use finance.budget_engine as bud

ptr = viz.pointer()
cfg = assets.readJson("assets/categories.json")

income = viz.slider("income", min: 800.0, max: 12000.0, value: 3500.0, label: "الدخل الشهري (\$)")
savePct = viz.slider("save_pct", min: 5.0, max: 60.0, value: 25.0, label: "نسبة الادخار (%)")
returnPct = viz.slider("return_pct", min: 2.0, max: 18.0, value: 9.0, label: "العائد السنوي (%)")
years = viz.slider("years", min: 3.0, max: 25.0, value: 10.0, label: "سنوات الاستثمار")

# Compute budget allocation
investAmt = income * (savePct / 100.0)
remain = income - investAmt
housingAmt = remain * 0.48
livingAmt = remain * 0.34
growthAmt = remain * 0.18

amounts = [housingAmt, livingAmt, investAmt, growthAmt]
labels = cfg["labels"]
colors = cfg["colors"]

# Detect which slice the user tapped with their finger!
var selected = viz.state("selected", 2)
if ptr.active and ptr.taps > 0:
    var ang = m.atan2(ptr.tapY, ptr.tapX)
    if ang < 0.0:
        ang = ang + 2.0 * m.pi
    var acc = 0.0
    var si = 0
    while si < 4:
        span = (amounts[si] / income) * 2.0 * m.pi
        if ang >= acc and ang <= acc + span:
            selected = si
        acc = acc + span
        si = si + 1
viz.setState("selected", selected)

# Interactive Touch Donut Chart
scene = viz.scene(title: "توزيع الميزانية التفاعلي (المس أي قسم)", grid: false, axes: false, bounds: [-5.6, 5.6, -4.4, 4.4], touch: true)
scene.polygon("bg", [[-5.6, -4.4], [5.6, -4.4], [5.6, 4.4], [-5.6, 4.4]], stroke: "#1E293B", fill: "#071020", closed: true)

var curAng = 0.0
var i = 0
while i < 4:
    span = (amounts[i] / income) * 2.0 * m.pi
    var outerR = 3.1
    if i == selected:
        outerR = 3.55
    poly = bud.slicePolygon(curAng + 0.03, curAng + span - 0.03, 1.65, outerR)
    scene.polygon("sl_" + i.toString(), poly, stroke: "#F8FAFC", fill: colors[i], closed: true)
    midA = curAng + span * 0.5
    pctVal = ((amounts[i] / income) * 100.0).round()
    scene.label("lb_" + i.toString(), [m.cos(midA) * 2.4, m.sin(midA) * 2.4], pctVal.toString() + "%", color: "#0F172A")
    curAng = curAng + span
    i = i + 1

selAmt = amounts[selected].round()
scene.label("center_t", [0.0, 0.35], labels[selected], color: colors[selected])
scene.label("center_v", [0.0, -0.45], "\$" + selAmt.toString() + "/mo", color: "#F8FAFC")
scene.label("tip", [0.0, -3.95], "المس أي شريحة في الدائرة لمعاينة تفاصيلها 👆", color: "#94A3B8")

# Compound Wealth Projection
yrsInt = years.round()
wealthCurve = comp.projectWealth(investAmt, returnPct, yrsInt)
var xs = []
var yIdx = 0
while yIdx <= yrsInt:
    xs.add(yIdx * 1.0)
    yIdx = yIdx + 1
finalWealth = wealthCurve[yrsInt]
totalContrib = investAmt * 12.0 * yrsInt
profit = finalWealth - totalContrib

scene.readout("الدخل الشهري", income.round(), unit: "\$", color: "#38BDF8")
scene.readout("الاستثمار الشهري", investAmt.round(), unit: "\$", color: "#10B981")
scene.readout("الثروة المتوقعة", finalWealth.round(), unit: "\$", color: "#FACC15")
scene.readout("الأرباح المركبة", profit.round(), unit: "\$", color: "#A855F7")
scene.render()

viz.plot(xs, wealthCurve, title: "نمو الثروة المركبة عبر السنوات (\$)", kind: "line", color: "#10B981")

summary = map:
    "الدخل الشهري": "\$" + income.round().toString()
    "الادخار الشهري": "\$" + investAmt.round().toString()
    "إجمالي المساهمات": "\$" + totalContrib.round().toString()
    "العائد المركب": "\$" + profit.round().toString()
    "الثروة النهائية": "\$" + finalWealth.round().toString()
    "القسم المختار باللمس": labels[selected]
viz.form(summary, title: "لوحة Quds FinApp المالية", summary: "تحليل فوري للتدفق النقدي والفائدة المركبة")

var rows = []
var rStep = 1
if yrsInt > 10:
    rStep = 2
var ry = 1
while ry <= yrsInt:
    bal = wealthCurve[ry].round()
    inv = (investAmt * 12.0 * ry).round()
    gain = bal - inv
    rows.add(["السنة " + ry.toString(), "\$" + inv.toString(), "\$" + gain.toString(), "\$" + bal.toString()])
    ry = ry + rStep
viz.table(["السنة", "المساهمات", "الأرباح", "إجمالي الرصيد"], rows, title: "جدول نمو الاستثمار السنوي")

assets.renderImage("assets/finapp_card.bmp", title: "Quds FinApp — Growth Card", caption: "تطبيق إدارة الميزانية ومحاكاة الثروة التفاعلي")
''',
    },
  );
  ws.writeAssetBytes('assets/finapp_card.bmp', _buildFinAppCardBmp());
  return ws;
}

// ---------------------------------------------------------------------------
// Exported List of Interactive Touch Games & Standalone Apps
// ---------------------------------------------------------------------------

final List<StudioProjectTemplate> interactiveGamesAndAppsTemplates = [
  StudioProjectTemplate(
    id: 'neon_brick_breaker',
    nameAr: 'لعبة تحطيم الطوب النيون (باللمس)',
    nameEn: 'Neon Brick Breaker (Touch)',
    subtitleAr: 'حرّك المضرب بإصبعك · 60FPS · مراحل + كومبو + أصول BMP',
    subtitleEn:
        'Slide paddle with finger · 60fps · stages + combo + BMP assets',
    icon: Icons.sports_esports_rounded,
    accentColor: const Color(0xFF06B6D4),
    builder: buildNeonBrickBreakerWorkspace,
  ),
  StudioProjectTemplate(
    id: 'sky_flappy_jet',
    nameAr: 'لعبة الطائرة النفاثة (لمس للطيران)',
    nameEn: 'Sky Flappy Jet (Tap to Fly)',
    subtitleAr: 'المس أي مكان للطيران بين البوابات الليزرية · 60FPS',
    subtitleEn: 'Tap anywhere to boost through laser gates · 60fps arcade',
    icon: Icons.flight_rounded,
    accentColor: const Color(0xFF38BDF8),
    builder: buildSkyFlappyJetWorkspace,
  ),
  StudioProjectTemplate(
    id: 'space_defender_touch',
    nameAr: 'لعبة مدافع المجرة (سحب وإطلاق)',
    nameEn: 'Galaxy Defender (Touch Shooter)',
    subtitleAr: 'اسحب مركبتك بإصبعك مع إطلاق بلازما تلقائي وموجات أعداء',
    subtitleEn: 'Drag starfighter with auto-fire twin plasma & enemy waves',
    icon: Icons.rocket_launch_rounded,
    accentColor: const Color(0xFFA855F7),
    builder: buildSpaceDefenderWorkspace,
  ),
  StudioProjectTemplate(
    id: 'slingshot_physics_angry',
    nameAr: 'لعبة المنجنيق الفيزيائي (اسحب وأطلق)',
    nameEn: 'Gravity Slingshot Demolition',
    subtitleAr: 'اسحب الكرة للخلف بإصبعك مع مسار قذيفة حي لهدم القلعة',
    subtitleEn: 'Pull back with finger, aim live arc & demolish fortress',
    icon: Icons.gps_fixed_rounded,
    accentColor: const Color(0xFFF59E0B),
    builder: buildSlingshotPhysicsWorkspace,
  ),
  StudioProjectTemplate(
    id: 'finger_paint_kaleidoscope',
    nameAr: 'تطبيق الرسم السحري والمندالا',
    nameEn: 'Kaleidoscope Finger Art Studio',
    subtitleAr: 'ارسم بإصبعك لوحات مندالا مضيئة بتماثل 6/8/12 محور حي',
    subtitleEn: 'Paint glowing 6/8/12-fold rotational mandala art with finger',
    icon: Icons.brush_rounded,
    accentColor: const Color(0xFFEC4899),
    builder: buildKaleidoscopeArtWorkspace,
  ),
  StudioProjectTemplate(
    id: 'smart_calc_budget_app',
    nameAr: 'تطبيق المحفظة والآلة المالية FinApp',
    nameEn: 'Quds FinApp (Touch Budget & Wealth)',
    subtitleAr: 'عجلة ميزانية تفاعلية باللمس + منحنى الثروة المركبة + جداول',
    subtitleEn: 'Touch budget wheel + compound wealth simulator + tables',
    icon: Icons.account_balance_wallet_rounded,
    accentColor: const Color(0xFF10B981),
    builder: buildSmartFinAppWorkspace,
  ),
];
