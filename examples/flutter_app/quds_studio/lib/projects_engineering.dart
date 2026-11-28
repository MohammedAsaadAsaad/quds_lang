/// 5 Flagship Multi-Folder Machine, Engine, Robotics, Aerospace, Smart-Grid &
/// Biomedical Simulation Projects for Quds Studio.
///
/// Each project ships with:
/// - Real procedural 24-bit BMP technical blueprint/schematic binary assets (`assets/*.bmp`)
/// - Engineering JSON / CSV configuration & telemetry assets (`assets/*.json`, `assets/*.csv`)
/// - Multi-folder modular Quds architecture (`core/`, `mechanics/`, `aero/`, `energy/`, `bio/`, barrels)
/// - Live 60fps animated `viz.scene` + interactive sliders + telemetry HUD + `viz.plot` + `viz.form` + `viz.table`
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

import 'project_templates.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Procedural 24-bit BMP Technical Blueprint & Emblem Generators
// ─────────────────────────────────────────────────────────────────────────────

Uint8List _buildEngineBlueprintBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      // Blueprint grid background
      final isBorder = x == 0 || y == 0 || x == w - 1 || y == h - 1;
      if (isBorder) return [56, 189, 248];
      final isGrid = (x % 6 == 0) || (y % 6 == 0);
      var col = isGrid ? [22, 45, 78] : [13, 27, 52];

      // Cylinder walls (x=14..34, y=3..14)
      final inWall = (y >= 3 && y <= 14) && (x == 14 || x == 34);
      final inHead = y == 3 && x >= 14 && x <= 34;
      if (inWall || inHead) return [148, 163, 184];

      // Combustion flame glow inside top chamber (y=4..7)
      if (y >= 4 && y <= 7 && x >= 16 && x <= 32) {
        final cx = (x - 24).abs();
        if (cx < 7 - (y - 4)) return [249, 115, 22];
      }
      // Piston crown (y=8..11, x=15..33)
      if (y >= 8 && y <= 11 && x >= 15 && x <= 33) {
        return y == 9 ? [226, 232, 240] : [100, 116, 139];
      }
      // Connecting rod (x=23..25, y=12..17)
      if (y >= 12 && y <= 17 && x >= 23 && x <= 25) return [245, 158, 11];

      // Crankshaft flywheel circle centered at (24, 18) radius 4.5
      final dx = x - 24.0;
      final dy = y - 18.0;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d <= 4.6 && d >= 2.8) return [56, 189, 248];
      if (d < 1.6) return [250, 204, 21];

      // Turbo snail housing on right (center 40, 9)
      final tx = x - 40.0;
      final ty = y - 9.0;
      final td = math.sqrt(tx * tx + ty * ty);
      if (td <= 3.8 && td >= 2.1) return [239, 68, 68];
      if (td < 1.5) return [251, 191, 36];

      return col;
    });
  });
  return encodeQudsBmp24(rows, scale: 5);
}

Uint8List _buildRobotSchematicBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) return [16, 185, 129];
      final isGrid = (x % 8 == 0) || (y % 6 == 0);
      var col = isGrid ? [18, 42, 54] : [10, 22, 34];

      // Industrial pedestal base (x=6..16, y=18..21)
      if (y >= 18 && y <= 21 && x >= 6 && x <= 16) return [100, 116, 139];
      // Link 1 diagonal from (11,18) to (22,9)
      final t1 = ((x - 11) / 11.0).clamp(0.0, 1.0);
      final ly1 = 18.0 - 9.0 * t1;
      if (x >= 11 && x <= 22 && (y - ly1).abs() <= 1.2) return [56, 189, 248];
      // Link 2 diagonal from (22,9) to (36,13)
      final t2 = ((x - 22) / 14.0).clamp(0.0, 1.0);
      final ly2 = 9.0 + 4.0 * t2;
      if (x >= 22 && x <= 36 && (y - ly2).abs() <= 1.1) return [16, 185, 129];
      // Servo joints
      for (final j in [
        [11.0, 18.0],
        [22.0, 9.0],
        [36.0, 13.0],
      ]) {
        final d = math.sqrt((x - j[0]) * (x - j[0]) + (y - j[1]) * (y - j[1]));
        if (d <= 2.1) return [245, 158, 11];
      }
      // Laser welding beam + spark at (36, 13..20)
      if (x == 36 && y >= 15 && y <= 19) return [236, 72, 153];
      if ((x - 36).abs() + (y - 20).abs() <= 2) return [250, 204, 21];

      return col;
    });
  });
  return encodeQudsBmp24(rows, scale: 5);
}

Uint8List _buildJetCrossSectionBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) return [139, 92, 246];
      final dy = (y - 12.0).abs();
      var col = (x % 6 == 0 || y % 6 == 0) ? [26, 24, 58] : [13, 14, 34];

      // Nacelle outer shell (x=7..35)
      final radius = x < 14
          ? 7.5
          : (x < 28 ? 7.5 - (x - 14) * 0.14 : 5.5 - (x - 28) * 0.28);
      if (x >= 7 && x <= 35 && (dy - radius).abs() < 1.1) {
        return [148, 163, 184];
      }
      // Intake fan blades (x=9..11)
      if (x >= 9 && x <= 11 && dy <= 6.5) {
        return (y % 2 == 0) ? [56, 189, 248] : [14, 116, 144];
      }
      // High-pressure compressor stages (x=14..20)
      if (x >= 14 && x <= 20 && dy <= 5.2 && x % 2 == 0) {
        return [96, 165, 250];
      }
      // Combustor flame core (x=22..28)
      if (x >= 22 && x <= 28 && dy <= 4.2) {
        return dy < 2.2 ? [250, 204, 21] : [249, 115, 22];
      }
      // Turbine stages (x=30..33)
      if (x >= 30 && x <= 33 && dy <= 4.0) return [239, 68, 68];
      // Supersonic exhaust plume & Mach diamonds (x=36..46)
      if (x >= 36 && x <= 46 && dy <= (3.4 - (x - 36) * 0.22)) {
        return ((x - 36) % 3 == 0 && dy < 1.6)
            ? [254, 240, 138]
            : [249, 115, 22];
      }
      return col;
    });
  });
  return encodeQudsBmp24(rows, scale: 5);
}

Uint8List _buildSmartGridBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) return [16, 185, 129];
      var col = [10, 25, 38];
      // Ground line
      if (y >= 20) return [20, 62, 54];
      // Wind turbine tower at x=12, hub (12, 8)
      if (x == 12 && y >= 8 && y <= 19) return [203, 213, 225];
      if ((x - 12).abs() <= 1 && (y - 8).abs() <= 1) return [250, 204, 21];
      if (x == 12 && y >= 2 && y <= 7) return [226, 232, 240];
      if ((y - 8) == ((x - 12) ~/ 2) &&
          x >= 6 &&
          x <= 18 &&
          y >= 8 &&
          y <= 13) {
        return [226, 232, 240];
      }
      // Solar array (x=22..33, y=13..18)
      if (x >= 22 && x <= 33 && y >= 13 && y <= 18) {
        return (x % 3 == 0 || y % 2 == 0) ? [56, 189, 248] : [30, 64, 175];
      }
      // Sun glow top-right (center 39, 5)
      final sd = math.sqrt((x - 39) * (x - 39) + (y - 5) * (y - 5));
      if (sd <= 2.8) return [250, 204, 21];
      // Battery storage block (x=37..43, y=12..19)
      if (x >= 37 && x <= 43 && y >= 12 && y <= 19) {
        if (x == 37 || x == 43 || y == 12 || y == 19) return [148, 163, 184];
        return y >= 14 ? [16, 185, 129] : [30, 41, 59];
      }
      return col;
    });
  });
  return encodeQudsBmp24(rows, scale: 5);
}

Uint8List _buildMedicalEcgBmp() {
  const w = 48;
  const h = 24;
  final rows = List.generate(h, (y) {
    return List.generate(w, (x) {
      if (x == 0 || y == 0 || x == w - 1 || y == h - 1) return [239, 68, 68];
      final isGrid = (x % 6 == 0) || (y % 6 == 0);
      var col = isGrid ? [16, 40, 46] : [8, 20, 26];
      // ECG waveform across center y=13
      var waveY = 13;
      if (x == 14 || x == 15) waveY = 11; // P wave
      if (x == 19) waveY = 15; // Q
      if (x == 21) waveY = 4; // R peak
      if (x == 22) waveY = 9;
      if (x == 23) waveY = 17; // S
      if (x == 28 || x == 29 || x == 30) waveY = 10; // T wave
      if ((y - waveY).abs() <= 1 && x >= 4 && x <= 43) {
        return [16, 185, 129];
      }
      // Heart icon top-left (x=6..10, y=4..8)
      if (y >= 4 && y <= 7 && x >= 5 && x <= 10) {
        if ((x - 7.5).abs() + (y - 5.5).abs() <= 2.4) return [239, 68, 68];
      }
      return col;
    });
  });
  return encodeQudsBmp24(rows, scale: 5);
}

// ─────────────────────────────────────────────────────────────────────────────
// Project 1: 4-Stroke Turbo Internal Combustion Engine Simulator
// ─────────────────────────────────────────────────────────────────────────────

QudsWorkspace buildTurboEngineProject() => QudsWorkspace(
      name: 'quds_turbo_engine_sim',
      packageName: 'quds_turbo_engine_sim',
      entryPoint: 'main.quds',
      bundleVersion: '1.0.0',
      binaryAssets: {
        'assets/engine_blueprint.bmp': _buildEngineBlueprintBmp(),
      },
      files: {
        'assets/engine_specs.json': '''{
  "engineCode": "QUDS-T4-2000",
  "configuration": "Inline-4 Turbocharged DOHC",
  "displacementL": 2.0,
  "crankRadiusMm": 43.0,
  "rodLengthMm": 144.0,
  "redlineRpm": 7200,
  "fuelOctane": 98
}
''',
        'core/thermo/otto_cycle.quds':
            '''# Otto-cycle thermodynamics + turbocharger boost calculations
use dart:math as m

thermalEfficiency(compressionRatio: double) -> double:
  gamma = 1.35
  return 1.0 - (1.0 / m.pow(compressionRatio, gamma - 1.0))

instantTorqueNm(rpm: double, boostPsi: double, compRatio: double) -> double:
  volEff = 0.82 + 0.16 * m.sin(((rpm - 1200.0) / 6000.0) * 2.6)
  boostFactor = 1.0 + (boostPsi / 14.7) * 0.72
  eta = thermalEfficiency(compRatio)
  return 215.0 * volEff * boostFactor * (eta / 0.56)

horsepower(torqueNm: double, rpm: double) -> double:
  return (torqueNm * rpm) / 7127.0

chamberTempC(strokeIndex: int, boostPsi: double) -> double:
  base = (if strokeIndex == 2: 1850.0 else: (if strokeIndex == 3: 780.0 else: (if strokeIndex == 1: 420.0 else: 95.0)))
  return base + boostPsi * 14.5
''',
        'mechanics/crankshaft.quds':
            '''# Exact crank-slider kinematics for piston, connecting rod & valve lifts
use dart:math as m

pistonY(theta: double, r: double, rodLen: double) -> double:
  sx = r * m.sin(theta)
  return r * m.cos(theta) + m.sqrt(rodLen * rodLen - sx * sx)

strokePhaseIndex(cycleAngle: double) -> int:
  deg = ((cycleAngle * 180.0 / 3.14159265) % 720.0)
  if deg < 180.0:
    return 0
  if deg < 360.0:
    return 1
  if deg < 540.0:
    return 2
  return 3

strokeLabelAr(idx: int) -> String:
  if idx == 0:
    return "شوط السحب (Intake)"
  if idx == 1:
    return "شوط الضغط (Compression)"
  if idx == 2:
    return "شوط الاحتراق والقدرة (Power)"
  return "شوط العادم (Exhaust)"

strokeColor(idx: int) -> String:
  if idx == 0:
    return "#38BDF8"
  if idx == 1:
    return "#FACC15"
  if idx == 2:
    return "#F97316"
  return "#A855F7"
''',
        'mechanics/index.quds': '''# Barrel re-exporting engine kinematics
export crankshaft show pistonY, strokePhaseIndex, strokeLabelAr, strokeColor
''',
        'telemetry/dyno_curve.quds':
            '''# Full RPM Dyno Sweep generator (1000..7000 RPM)
use ^.core.thermo.otto_cycle show instantTorqueNm, horsepower

buildDynoSweep(boostPsi: double, compRatio: double) -> Map:
  var rpms = []
  var hpCurve = []
  var peakHp = 0.0
  var peakRpm = 1000.0
  var r = 1000.0
  while r <= 7000.0:
    tq = instantTorqueNm(r, boostPsi, compRatio)
    hp = horsepower(tq, r)
    rpms.add(r)
    hpCurve.add(hp)
    if hp > peakHp:
      peakHp = hp
      peakRpm = r
    r = r + 250.0
  return map:
    "rpms": rpms
    "hp": hpCurve
    "peakHp": peakHp
    "peakRpm": peakRpm
''',
        'main.quds':
            '''# محاكاة محرك احتراق داخلي تيربو 4-أشواط (60fps + مخطط BMP + منحنى الداينو)
use dart:math as m
use quds:assets as assets
use quds:viz as viz
use core.thermo.otto_cycle show thermalEfficiency, instantTorqueNm, horsepower, chamberTempC
use mechanics.index show pistonY, strokePhaseIndex, strokeLabelAr, strokeColor
use telemetry.dyno_curve show buildDynoSweep

specs = assets.readJson("assets/engine_specs.json")
clk = viz.animate(fps: 60, duration: 12.0, loop: true)
rpm = viz.slider("rpm", min: 1000.0, max: 7000.0, value: 3600.0, step: 200.0, label: "سرعة الدوران (RPM)")
boostPsi = viz.slider("boost", min: 0.0, max: 24.0, value: 14.0, step: 1.0, label: "ضغط التيربو (PSI)")
compRatio = viz.slider("comp", min: 8.5, max: 12.5, value: 10.5, step: 0.5, label: "نسبة الانضغاط")

# Kinematics scaled to canvas coordinates
r = 1.15
rodL = 3.25
omega = (rpm / 1000.0) * 2.2
cycleAngle = clk.t * omega
theta = cycleAngle % 6.2831853
crankX = r * m.sin(theta)
crankY = r * m.cos(theta)
pinY = pistonY(theta, r, rodL)

phaseIdx = strokePhaseIndex(cycleAngle)
phaseCol = strokeColor(phaseIdx)
phaseName = strokeLabelAr(phaseIdx)
chamberTop = r + rodL + 1.05

s = viz.scene(title: "🔥 {specs['engineCode']} — {phaseName}", grid: false, axes: false, bounds: [-4.4, 4.4, -2.1, 6.2])

# Cylinder block & head cutaway
s.polygon("blockL", [[-1.65, 1.5], [-1.35, 1.5], [-1.35, chamberTop], [-1.65, chamberTop]], stroke: "#64748B", fill: "#334155")
s.polygon("blockR", [[1.35, 1.5], [1.65, 1.5], [1.65, chamberTop], [1.35, chamberTop]], stroke: "#64748B", fill: "#334155")
s.polygon("head", [[-1.75, chamberTop], [1.75, chamberTop], [1.75, chamberTop + 0.45], [-1.75, chamberTop + 0.45]], stroke: "#94A3B8", fill: "#475569")

# Dynamic combustion gas volume above piston crown
crownY = pinY + 0.55
s.polygon("gas", [[-1.30, crownY], [1.30, crownY], [1.30, chamberTop - 0.04], [-1.30, chamberTop - 0.04]], stroke: phaseCol, fill: phaseCol)

# Spark plug & ignition flash at top of Power stroke
s.segment("sparkBody", [0.0, chamberTop + 0.55], [0.0, chamberTop - 0.12], color: "#E2E8F0", strokeWidth: 3.0)
if phaseIdx == 2:
  s.point("sparkFlash", 0.0, chamberTop - 0.25, color: "#FEF08A", radius: 11.0)

# Intake & Exhaust valves
inLift = (if phaseIdx == 0: 0.42 else: 0.0)
exLift = (if phaseIdx == 3: 0.42 else: 0.0)
s.segment("inValve", [-0.75, chamberTop + 0.65 - inLift], [-0.75, chamberTop - inLift], color: "#38BDF8", strokeWidth: 3.2)
s.segment("inHead", [-1.05, chamberTop - inLift], [-0.45, chamberTop - inLift], color: "#38BDF8", strokeWidth: 4.0)
s.segment("exValve", [0.75, chamberTop + 0.65 - exLift], [0.75, chamberTop - exLift], color: "#A855F7", strokeWidth: 3.2)
s.segment("exHead", [0.45, chamberTop - exLift], [1.05, chamberTop - exLift], color: "#A855F7", strokeWidth: 4.0)

# Piston body & compression rings
s.polygon("piston", [[-1.28, pinY - 0.45], [1.28, pinY - 0.45], [1.28, crownY], [-1.28, crownY]], stroke: "#E2E8F0", fill: "#94A3B8")
s.segment("ring1", [-1.26, crownY - 0.14], [1.26, crownY - 0.14], color: "#0F172A", strokeWidth: 1.6)
s.segment("ring2", [-1.26, crownY - 0.28], [1.26, crownY - 0.28], color: "#0F172A", strokeWidth: 1.6)

# Crankshaft flywheel, crank throw & connecting rod
s.circle("flywheel", [0.0, 0.0], r + 0.35, stroke: "#38BDF8", fill: "#0F172A")
s.segment("crankThrow", [0.0, 0.0], [crankX, crankY], color: "#38BDF8", strokeWidth: 5.0)
s.segment("conRod", [crankX, crankY], [0.0, pinY], color: "#F59E0B", strokeWidth: 5.5)
s.point("mainJournal", 0.0, 0.0, color: "#E2E8F0", radius: 6.5)
s.point("crankPin", crankX, crankY, color: "#FACC15", radius: 6.0)
s.point("wristPin", 0.0, pinY, color: "#FACC15", radius: 5.5)

# Spinning Turbocharger turbine indicator on the right
turboAngle = clk.t * (6.0 + boostPsi * 0.45)
s.circle("turboHousing", [3.0, 4.1], 0.85, stroke: "#EF4444", fill: "#1E293B")
for b in 0..<4:
  a = turboAngle + b * 1.570796
  s.segment("tb{b}", [3.0, 4.1], [3.0 + 0.68 * m.cos(a), 4.1 + 0.68 * m.sin(a)], color: "#FACC15", strokeWidth: 2.2)
s.point("turboHub", 3.0, 4.1, label: "تيربو {boostPsi.toInt()} PSI", color: "#EF4444", radius: 4.5)

tq = instantTorqueNm(rpm, boostPsi, compRatio)
hp = horsepower(tq, rpm)
eta = thermalEfficiency(compRatio) * 100.0
tempC = chamberTempC(phaseIdx, boostPsi)

s.readout("القدرة", hp, unit: "HP", decimals: 1, color: "#10B981")
s.readout("العزم", tq, unit: "N·m", decimals: 1, color: "#38BDF8")
s.readout("حرارة الغرفة", tempC, unit: "°C", decimals: 0, color: "#F97316")
s.readout("الكفاءة الحرارية", eta, unit: "%", decimals: 1, color: "#FACC15")
s.render()

dyno = buildDynoSweep(boostPsi, compRatio)
viz.plot(
  dyno["rpms"],
  dyno["hp"],
  title: "📈 منحنى الداينو — القدرة (HP) مقابل RPM (الذروة: {dyno['peakHp'].toStringAsFixed(0)} HP)",
  xLabel: "RPM",
  yLabel: "Horsepower (HP)",
  color: "#F97316",
)

assets.renderImage(
  "assets/engine_blueprint.bmp",
  title: "📐 المخطط الهندسي للمحرك (assets/engine_blueprint.bmp)",
  caption: "{specs['configuration']} · السعة {specs['displacementL']}L · خط أحمر {specs['redlineRpm']} RPM",
)

summary = map:
  "طراز المحرك": specs["engineCode"]
  "الشوط الحالي": phaseName
  "القدرة الحالية": "{hp.toStringAsFixed(1)} HP"
  "أقصى قدرة (Dyno Peak)": "{dyno['peakHp'].toStringAsFixed(1)} HP @ {dyno['peakRpm'].toInt()} RPM"
  "الكفاءة الحرارية (Otto)": "{eta.toStringAsFixed(1)}%"
viz.form(summary, title: "🏎️ لوحة أداء محرك التيربو")

print "Engine {specs['engineCode']} | {rpm.toInt()} RPM | {hp.toStringAsFixed(1)} HP | {tq.toStringAsFixed(1)} Nm | {phaseName}"
''',
      },
    );

// ─────────────────────────────────────────────────────────────────────────────
// Project 2: Industrial 3-DOF Robotic Arm & CNC Laser Path Simulator
// ─────────────────────────────────────────────────────────────────────────────

QudsWorkspace buildRoboticArmProject() => QudsWorkspace(
      name: 'quds_robotic_cnc_arm',
      packageName: 'quds_robotic_cnc_arm',
      entryPoint: 'main.quds',
      bundleVersion: '1.0.0',
      binaryAssets: {
        'assets/robot_schematic.bmp': _buildRobotSchematicBmp(),
      },
      files: {
        'assets/waypoints.csv': '''step,x,y,operation,powerW
1,2.6,1.2,Laser Cut,850
2,3.8,2.4,Arc Weld,1120
3,3.1,3.5,Precision Drill,640
4,1.6,3.2,Edge Polish,420
5,2.1,1.6,Seal Weld,980
''',
        'kinematics/ik_solver.quds':
            '''# Analytical 2-Link + Wrist Inverse Kinematics Solver
use dart:math as m

solveArmIK(tx: double, ty: double, l1: double, l2: double) -> Map:
  dist = m.sqrt(tx * tx + ty * ty)
  maxReach = (l1 + l2) * 0.98
  minReach = (l1 - l2).abs() + 0.15
  clamped = (if dist > maxReach: maxReach else: (if dist < minReach: minReach else: dist))
  scale = (if dist > 0.0001: clamped / dist else: 1.0)
  px = tx * scale
  py = ty * scale

  cosQ2 = (px * px + py * py - l1 * l1 - l2 * l2) / (2.0 * l1 * l2)
  c2 = (if cosQ2 > 1.0: 1.0 else: (if cosQ2 < -1.0: -1.0 else: cosQ2))
  q2 = -m.acos(c2)
  k1 = l1 + l2 * m.cos(q2)
  k2 = l2 * m.sin(q2)
  q1 = m.atan2(py, px) - m.atan2(k2, k1)

  ex = l1 * m.cos(q1)
  ey = l1 * m.sin(q1)
  wx = ex + l2 * m.cos(q1 + q2)
  wy = ey + l2 * m.sin(q1 + q2)
  return map:
    "q1Deg": q1 * 180.0 / 3.14159265
    "q2Deg": q2 * 180.0 / 3.14159265
    "ex": ex
    "ey": ey
    "wx": wx
    "wy": wy
    "reach": clamped
''',
        'control/torque_model.quds':
            '''# Joint gravitational torque & servo motor current estimator
use dart:math as m

computeJointTorques(q1Deg: double, q2Deg: double, l1: double, l2: double, payloadKg: double) -> Map:
  g = 9.81
  q1 = q1Deg * 3.14159265 / 180.0
  q12 = (q1Deg + q2Deg) * 3.14159265 / 180.0
  m1 = 6.5
  m2 = 4.2
  tElbow = (m2 * 0.5 * l2 + payloadKg * l2) * g * m.cos(q12).abs()
  tShoulder = (m1 * 0.5 * l1 + (m2 + payloadKg) * l1) * g * m.cos(q1).abs() + tElbow
  amps = (tShoulder + tElbow) * 0.14 + 1.8
  return map:
    "shoulderNm": tShoulder
    "elbowNm": tElbow
    "currentA": amps
''',
        'main.quds':
            '''# محاكاة ذراع روبوتية صناعية CNC 3-محاور (حركيات عكسية IK + نقاط CSV + مخطط BMP)
use quds:assets as assets
use quds:viz as viz
use kinematics.ik_solver show solveArmIK
use control.torque_model show computeJointTorques

waypoints = assets.readCsv("assets/waypoints.csv")
clk = viz.animate(fps: 60, duration: 10.0, loop: true)
speed = viz.slider("speed", min: 0.4, max: 2.5, value: 1.0, step: 0.1, label: "سرعة مسار CNC")
payloadKg = viz.slider("payload", min: 1.0, max: 18.0, value: 5.0, step: 1.0, label: "وزن الأداة / الحمولة (كغ)")
armScale = viz.slider("scale", min: 0.85, max: 1.25, value: 1.0, step: 0.05, label: "طول الذراع")

l1 = 2.65 * armScale
l2 = 2.15 * armScale

# Smooth cyclic interpolation along CSV manufacturing waypoints
nPts = waypoints.length
prog = ((clk.t * speed * 0.65) % nPts)
idx0 = prog.toInt() % nPts
idx1 = (idx0 + 1) % nPts
frac = prog - prog.toInt()
w0 = waypoints[idx0]
w1 = waypoints[idx1]
tx = (w0["x"] to double) + ((w1["x"] to double) - (w0["x"] to double)) * frac
ty = (w0["y"] to double) + ((w1["y"] to double) - (w0["y"] to double)) * frac

ik = solveArmIK(tx, ty, l1, l2)
torques = computeJointTorques(ik["q1Deg"] to double, ik["q2Deg"] to double, l1, l2, payloadKg)

s = viz.scene(title: "🦾 ذراع CNC الصناعية — {w0['operation']}", grid: true, axes: true, bounds: [-1.5, 5.5, -1.0, 5.0])

# Workspace reach envelope & pedestal base
s.circle("reachEnvelope", [0.0, 0.0], l1 + l2, stroke: "#334155")
s.polygon("base", [[-0.65, -0.75], [0.65, -0.75], [0.45, 0.0], [-0.45, 0.0]], stroke: "#94A3B8", fill: "#334155")

# Draw full CSV CNC toolpath polygon
var pathPts = []
for wp in waypoints:
  pathPts.add([wp["x"] to double, wp["y"] to double])
s.polygon("cncPath", pathPts, stroke: "#38BDF8")

for i in 0..<nPts:
  wp = waypoints[i]
  s.point("wp{i}", wp["x"] to double, wp["y"] to double, label: "P{i + 1}", color: "#64748B", radius: 4.0)

# Articulated metallic links & wrist tool
ex = ik["ex"] to double
ey = ik["ey"] to double
wx = ik["wx"] to double
wy = ik["wy"] to double
s.segment("link1", [0.0, 0.0], [ex, ey], color: "#38BDF8", strokeWidth: 7.0)
s.segment("link2", [ex, ey], [wx, wy], color: "#10B981", strokeWidth: 5.5)
s.segment("laserHead", [wx, wy], [wx + 0.32, wy - 0.18], color: "#EC4899", strokeWidth: 3.5)

s.point("shoulder", 0.0, 0.0, color: "#F59E0B", radius: 8.0)
s.point("elbow", ex, ey, color: "#F59E0B", radius: 7.0)
s.point("wrist", wx, wy, color: "#FEF08A", radius: 6.5)

s.readout("زاوية الكتف θ1", ik["q1Deg"] to double, unit: "°", decimals: 1, color: "#38BDF8")
s.readout("زاوية المرفق θ2", ik["q2Deg"] to double, unit: "°", decimals: 1, color: "#10B981")
s.readout("عزم الكتف", torques["shoulderNm"] to double, unit: "N·m", decimals: 1, color: "#F59E0B")
s.readout("تيار المحركات", torques["currentA"] to double, unit: "A", decimals: 1, color: "#EC4899")
s.render()

assets.renderImage(
  "assets/robot_schematic.bmp",
  title: "📐 المخطط الحركي للذراع الصناعية (assets/robot_schematic.bmp)",
  caption: "تم تحميل {nPts} نقاط تشغيل CNC من assets/waypoints.csv",
)

var tableRows = []
for wp in waypoints:
  tableRows.add([wp["step"].toString(), wp["operation"].toString(), "({wp['x']}, {wp['y']})", "{wp['powerW']} W"])
viz.table(["#", "العملية / Op", "الإحداثيات (m)", "قدرة الليزر"], tableRows, title: "🏭 جدول مسار CNC (assets/waypoints.csv)")

print "CNC Arm IK OK | pos=({wx.toStringAsFixed(2)},{wy.toStringAsFixed(2)}) | q1={ik['q1Deg'].toStringAsFixed(1)} deg | torque={torques['shoulderNm'].toStringAsFixed(1)} Nm"
''',
      },
    );

// ─────────────────────────────────────────────────────────────────────────────
// Project 3: Turbofan Jet Engine & Brayton Cycle Simulator
// ─────────────────────────────────────────────────────────────────────────────

QudsWorkspace buildJetTurbineProject() => QudsWorkspace(
      name: 'quds_jet_turbine_sim',
      packageName: 'quds_jet_turbine_sim',
      entryPoint: 'main.quds',
      bundleVersion: '1.0.0',
      binaryAssets: {
        'assets/jet_cross_section.bmp': _buildJetCrossSectionBmp(),
      },
      files: {
        'assets/atmosphere.json': '''{
  "engineModel": "QUDS-TF90 Turbofan",
  "bypassRatio": 8.5,
  "maxThrustKn": 145.0,
  "layers": [
    {"altKm": 0.0, "tempK": 288.15, "density": 1.225, "soundMs": 340.3},
    {"altKm": 4.0, "tempK": 262.15, "density": 0.819, "soundMs": 324.6},
    {"altKm": 8.0, "tempK": 236.15, "density": 0.526, "soundMs": 308.1},
    {"altKm": 11.0, "tempK": 216.65, "density": 0.364, "soundMs": 295.1}
  ]
}
''',
        'aero/brayton.quds':
            '''# Brayton thermodynamic cycle & turbofan thrust estimator
use dart:math as m

airDensityAt(altKm: double) -> double:
  return 1.225 * m.exp(-altKm / 8.5)

computeJetPerformance(throttlePct: double, altKm: double, mach: double) -> Map:
  rho = airDensityAt(altKm)
  densityRatio = rho / 1.225
  tFrac = throttlePct / 100.0
  massFlow = 420.0 * densityRatio * (0.35 + 0.65 * tFrac)
  exhaustVel = 320.0 + 580.0 * tFrac + mach * 95.0
  flightVel = mach * (340.0 - altKm * 4.1)
  thrustKn = (massFlow * (exhaustVel - flightVel * 0.55)) / 1000.0
  egtC = 420.0 + 560.0 * tFrac + mach * 45.0
  tsfc = 0.48 + 0.14 * mach - 0.05 * tFrac
  return map:
    "thrustKn": thrustKn
    "egtC": egtC
    "exhaustMs": exhaustVel
    "massFlow": massFlow
    "tsfc": tsfc
''',
        'main.quds':
            '''# محاكاة محرك نفاث توربيني ودورة برايتون (60fps + مقطع BMP + منحنى الدفع)
use dart:math as m
use quds:assets as assets
use quds:viz as viz
use aero.brayton show computeJetPerformance

atm = assets.readJson("assets/atmosphere.json")
clk = viz.animate(fps: 60, duration: 10.0, loop: true)
throttle = viz.slider("throttle", min: 20.0, max: 100.0, value: 82.0, step: 2.0, label: "قوة الدفع Throttle (%)")
altKm = viz.slider("alt", min: 0.0, max: 12.0, value: 6.0, step: 0.5, label: "الارتفاع (كم)")
mach = viz.slider("mach", min: 0.0, max: 0.92, value: 0.78, step: 0.04, label: "سرعة الطيران (Mach)")

perf = computeJetPerformance(throttle, altKm, mach)
tFrac = throttle / 100.0

s = viz.scene(title: "✈️ {atm['engineModel']} — دفع {perf['thrustKn'].toStringAsFixed(1)} kN", grid: false, axes: false, bounds: [-5.2, 6.2, -3.0, 3.0])

# Outer turbofan nacelle casing
s.polygon("casingTop", [[-3.6, 2.0], [1.2, 1.85], [2.8, 1.2], [2.8, 1.5], [1.2, 2.25], [-3.6, 2.35]], stroke: "#94A3B8", fill: "#334155")
s.polygon("casingBot", [[-3.6, -2.0], [1.2, -1.85], [2.8, -1.2], [2.8, -1.5], [1.2, -2.25], [-3.6, -2.35]], stroke: "#94A3B8", fill: "#334155")

# Central shaft & nose cone
s.polygon("nose", [[-4.2, 0.0], [-3.0, 0.55], [-3.0, -0.55]], stroke: "#38BDF8", fill: "#1E293B")
s.segment("shaft", [-3.0, 0.0], [2.4, 0.0], color: "#CBD5E1", strokeWidth: 4.5)

# Animated spinning fan & compressor blades
fanPhase = clk.t * (6.0 + tFrac * 14.0)
for i in 0..<5:
  yPos = 1.75 * m.sin(fanPhase + i * 1.2566)
  s.segment("fan{i}", [-2.7, 0.0], [-2.7, yPos], color: "#38BDF8", strokeWidth: 4.0)
  s.segment("comp{i}", [-1.4, 0.0], [-1.4, yPos * 0.75], color: "#60A5FA", strokeWidth: 3.2)
  s.segment("turb{i}", [1.6, 0.0], [1.6, yPos * 0.65], color: "#EF4444", strokeWidth: 3.2)

# Glowing combustion chamber core
s.polygon("combustor", [[-0.5, -1.15], [1.1, -0.95], [1.1, 0.95], [-0.5, 1.15]], stroke: "#F97316", fill: "#F97316")

# Supersonic exhaust plume + oscillating Mach shock diamonds
plumeLen = 1.8 + tFrac * 2.2
s.polygon("plume", [[2.8, 1.1], [2.8 + plumeLen, 0.0], [2.8, -1.1]], stroke: "#F97316", fill: "#F59E0B")
for d in 0..<3:
  dx = 3.25 + d * 0.75 + 0.08 * m.sin(clk.t * 18.0 + d)
  if dx < 2.6 + plumeLen:
    s.point("diamond{d}", dx, 0.0, color: "#FEF08A", radius: 6.5 - d * 1.4)

# Animated airflow particles streaming through intake
for p in 0..<6:
  px = -5.0 + ((clk.t * (3.5 + tFrac * 4.0) + p * 1.7) % 10.5)
  py = (p - 2.5) * 0.58
  pCol = (if px > 2.6: "#FEF08A" else: "#38BDF8")
  s.point("air{p}", px, py, color: pCol, radius: 3.5)

s.readout("الدفع الصافي", perf["thrustKn"] to double, unit: "kN", decimals: 1, color: "#10B981")
s.readout("حرارة العادم EGT", perf["egtC"] to double, unit: "°C", decimals: 0, color: "#F97316")
s.readout("سرعة العادم", perf["exhaustMs"] to double, unit: "m/s", decimals: 0, color: "#38BDF8")
s.readout("تدفق الهواء", perf["massFlow"] to double, unit: "kg/s", decimals: 0, color: "#A855F7")
s.render()

# Altitude vs Thrust envelope curve
var alts = []
var thrusts = []
var aKm = 0.0
while aKm <= 12.0:
  p = computeJetPerformance(throttle, aKm, mach)
  alts.add(aKm)
  thrusts.add(p["thrustKn"] to double)
  aKm = aKm + 1.0

viz.plot(
  alts,
  thrusts,
  title: "📈 غلاف الأداء الجوي: الدفع (kN) مقابل الارتفاع (km)",
  xLabel: "Altitude (km)",
  yLabel: "Net Thrust (kN)",
  color: "#8B5CF6",
)

assets.renderImage(
  "assets/jet_cross_section.bmp",
  title: "📐 المقطع العرضي للتوربين النفاث (assets/jet_cross_section.bmp)",
  caption: "نسبة التمرير (Bypass Ratio): {atm['bypassRatio']}:1 · الدفع الأقصى: {atm['maxThrustKn']} kN",
)

var layerRows = []
for layer in atm["layers"] as List:
  pAt = computeJetPerformance(throttle, layer["altKm"] to double, mach)
  layerRows.add(["{layer['altKm']} km", "{layer['tempK']} K", "{layer['density']} kg/m³", "{pAt['thrustKn'].toStringAsFixed(1)} kN"])
viz.table(["الارتفاع", "الحرارة", "كثافة الهواء", "الدفع المحسوب"], layerRows, title: "🌍 بيانات الغلاف الجوي ISA (assets/atmosphere.json)")

print "Jet {atm['engineModel']} | Thrust={perf['thrustKn'].toStringAsFixed(1)} kN | EGT={perf['egtC'].toStringAsFixed(0)} C | Alt={altKm} km"
''',
      },
    );

// ─────────────────────────────────────────────────────────────────────────────
// Project 4: Smart Microgrid & Wind Turbine Digital Twin
// ─────────────────────────────────────────────────────────────────────────────

QudsWorkspace buildSmartGridProject() => QudsWorkspace(
      name: 'quds_smart_microgrid',
      packageName: 'quds_smart_microgrid',
      entryPoint: 'main.quds',
      bundleVersion: '1.0.0',
      binaryAssets: {
        'assets/grid_diagram.bmp': _buildSmartGridBmp(),
      },
      files: {
        'assets/hourly_load.csv': '''hour,loadMW,sunFactor,windMs
0,32.0,0.00,7.5
3,28.5,0.00,8.2
6,36.0,0.18,7.0
9,52.0,0.68,6.4
12,64.0,1.00,8.8
15,68.5,0.84,9.6
18,74.0,0.22,10.4
21,58.0,0.00,9.1
''',
        'energy/wind_turbine.quds':
            '''# Betz-limit wind turbine aerodynamics (array of 8 offshore 5MW turbines)
windPowerMW(windMs: double, turbineCount: int) -> double:
  if windMs < 3.0 or windMs > 25.0:
    return 0.0
  rho = 1.225
  area = 12469.0
  cp = 0.44
  rawWatts = 0.5 * rho * area * cp * windMs * windMs * windMs
  singleMW = rawWatts / 1000000.0
  capped = (if singleMW > 5.5: 5.5 else: singleMW)
  return capped * turbineCount
''',
        'energy/solar_battery.quds':
            '''# Solar PV array & utility-scale battery dispatch balance
solarPowerMW(irradiance: double, pvCapacityMW: double) -> double:
  return pvCapacityMW * irradiance * 0.86

gridBalance(windMW: double, solarMW: double, loadMW: double) -> Map:
  gen = windMW + solarMW
  net = gen - loadMW
  share = (if loadMW > 0.01: ((if gen > loadMW: loadMW else: gen) / loadMW) * 100.0 else: 100.0)
  co2TonsHr = gen * 0.42
  mode = (if net >= 0.0: "شحن البطاريات (+فائض)" else: "تفريغ البطاريات لتغطية العجز")
  return map:
    "genMW": gen
    "netMW": net
    "renewablePct": share
    "co2Saved": co2TonsHr
    "mode": mode
''',
        'main.quds':
            '''# التوأم الرقمي لشبكة طاقة متجددة ذكية (توربينات رياح + شمس + بطاريات + CSV)
use dart:math as m
use quds:assets as assets
use quds:viz as viz
use energy.wind_turbine show windPowerMW
use energy.solar_battery show solarPowerMW, gridBalance

hourly = assets.readCsv("assets/hourly_load.csv")
clk = viz.animate(fps: 60, duration: 12.0, loop: true)
windSpeed = viz.slider("wind", min: 2.0, max: 18.0, value: 9.5, step: 0.5, label: "سرعة الرياح (m/s)")
sunIrrad = viz.slider("sun", min: 0.0, max: 1.0, value: 0.80, step: 0.05, label: "شدة الإشعاع الشمسي")
cityLoad = viz.slider("load", min: 25.0, max: 95.0, value: 58.0, step: 2.0, label: "حمل المدينة (MW)")

wMW = windPowerMW(windSpeed, 10)
sMW = solarPowerMW(sunIrrad, 45.0)
bal = gridBalance(wMW, sMW, cityLoad)

s = viz.scene(title: "⚡ التوأم الرقمي للشبكة الذكية — {bal['mode']}", grid: false, axes: false, bounds: [-5.5, 5.5, -2.5, 4.8])

# Ground & transmission busbar
s.polygon("ground", [[-5.5, -2.5], [5.5, -2.5], [5.5, -1.6], [-5.5, -1.6]], stroke: "#10B981", fill: "#064E3B")
s.segment("busbar", [-3.2, -1.2], [3.6, -1.2], color: "#38BDF8", strokeWidth: 3.0)

# Spinning 3-blade Wind Turbine on left (-3.2, 1.9)
s.segment("tower", [-3.2, -1.6], [-3.2, 1.9], color: "#CBD5E1", strokeWidth: 5.0)
rotorAng = clk.t * (0.9 + windSpeed * 0.38)
for b in 0..<3:
  a = rotorAng + b * 2.094395
  s.segment("blade{b}", [-3.2, 1.9], [-3.2 + 1.85 * m.cos(a), 1.9 + 1.85 * m.sin(a)], color: "#E2E8F0", strokeWidth: 4.0)
s.point("hub", -3.2, 1.9, label: "رياح {wMW.toStringAsFixed(1)} MW", color: "#38BDF8", radius: 6.5)

# Solar PV Array in center
sunCol = (if sunIrrad > 0.35: "#FACC15" else: "#475569")
s.point("sun", 0.2, 3.7, color: sunCol, radius: 11.0 * (0.5 + sunIrrad * 0.6))
s.polygon("pv1", [[-1.1, -0.7], [1.4, -0.7], [1.7, 0.5], [-0.8, 0.5]], stroke: "#38BDF8", fill: "#1D4ED8")
s.segment("pvLink", [0.2, -0.7], [0.2, -1.2], color: "#FACC15", strokeWidth: 2.5)
s.point("pvLabel", 0.2, 0.9, label: "شمسي {sMW.toStringAsFixed(1)} MW", color: "#FACC15", radius: 4.5)

# Battery & City Load tower on right
netMW = bal["netMW"] to double
batCol = (if netMW >= 0.0: "#10B981" else: "#F97316")
fillH = (if netMW >= 0.0: 1.55 else: 0.75)
s.polygon("batOuter", [[2.7, -1.0], [4.3, -1.0], [4.3, 1.4], [2.7, 1.4]], stroke: "#94A3B8", fill: "#1E293B")
s.polygon("batFill", [[2.85, -0.85], [4.15, -0.85], [4.15, -0.85 + fillH], [2.85, -0.85 + fillH]], stroke: batCol, fill: batCol)
s.point("batTag", 3.5, 1.9, label: "صافي {netMW.toStringAsFixed(1)} MW", color: batCol, radius: 5.0)

# Animated energy pulse packets flowing on the busbar
for p in 0..<4:
  px = -3.0 + ((clk.t * 2.8 + p * 1.65) % 6.4)
  s.point("pulse{p}", px, -1.2, color: "#FEF08A", radius: 4.5)

s.readout("التوليد المتجدد", bal["genMW"] to double, unit: "MW", decimals: 1, color: "#10B981")
s.readout("تغطية الحمل", bal["renewablePct"] to double, unit: "%", decimals: 0, color: "#38BDF8")
s.readout("صافي البطارية", netMW, unit: "MW", decimals: 1, color: batCol)
s.readout("وفر CO₂", bal["co2Saved"] to double, unit: "طن/س", decimals: 1, color: "#FACC15")
s.render()

# 24-hour generation curve from assets/hourly_load.csv
var hours = []
var genCurve = []
var rows = []
for row in hourly:
  h = row["hour"] to double
  l = row["loadMW"] to double
  sf = row["sunFactor"] to double
  ws = row["windMs"] to double
  gTotal = windPowerMW(ws, 10) + solarPowerMW(sf, 45.0)
  hours.add(h)
  genCurve.add(gTotal)
  rows.add(["{h.toInt()}:00", "{l.toStringAsFixed(1)} MW", "{gTotal.toStringAsFixed(1)} MW", "{(gTotal - l).toStringAsFixed(1)} MW"])

viz.plot(hours, genCurve, title: "📈 منحنى التوليد المتجدد خلال 24 ساعة (assets/hourly_load.csv)", xLabel: "Hour", yLabel: "Renewable MW", color: "#10B981")
assets.renderImage("assets/grid_diagram.bmp", title: "🗺️ مخطط الشبكة الذكية (assets/grid_diagram.bmp)", caption: "تكامل طاقة الرياح + الألواح الشمسية + تخزين البطاريات")
viz.table(["الساعة", "حمل المدينة", "التوليد المتجدد", "الفائض/العجز"], rows, title: "⚡ جدول توازن الشبكة على مدار اليوم")

print "SmartGrid OK | Wind={wMW.toStringAsFixed(1)} MW | Solar={sMW.toStringAsFixed(1)} MW | Net={netMW.toStringAsFixed(1)} MW"
''',
      },
    );

// ─────────────────────────────────────────────────────────────────────────────
// Project 5: Biomedical ECG Heart Monitor & Arrhythmia Analyzer
// ─────────────────────────────────────────────────────────────────────────────

QudsWorkspace buildMedicalEcgProject() => QudsWorkspace(
      name: 'quds_medical_ecg_monitor',
      packageName: 'quds_medical_ecg_monitor',
      entryPoint: 'main.quds',
      bundleVersion: '1.0.0',
      binaryAssets: {
        'assets/medical_badge.bmp': _buildMedicalEcgBmp(),
      },
      files: {
        'assets/patient_profile.json': '''{
  "device": "QUDS-CARDIO-12X",
  "ward": "ICU Bed #04",
  "spo2Pct": 98.4,
  "normalMinBpm": 60,
  "normalMaxBpm": 100
}
''',
        'bio/ecg_synth.quds':
            '''# Synthetic P-Q-R-S-T Gaussian cardiac ECG waveform generator
use dart:math as m

gauss(x: double, mu: double, sigma: double, amp: double) -> double:
  d = (x - mu) / sigma
  return amp * m.exp(-0.5 * d * d)

ecgSample(phase: double, stShift: double, noiseAmp: double, idx: int) -> double:
  # phase in [0, 1) representing one heartbeat cycle
  p = gauss(phase, 0.18, 0.032, 0.18)
  q = gauss(phase, 0.34, 0.012, -0.22)
  r = gauss(phase, 0.38, 0.014, 1.45)
  s = gauss(phase, 0.42, 0.013, -0.32)
  st = gauss(phase, 0.50, 0.045, stShift)
  t = gauss(phase, 0.64, 0.055, 0.36)
  noise = noiseAmp * m.sin(idx * 1.73) * m.cos(idx * 0.61)
  return p + q + r + s + st + t + noise
''',
        'clinical/triage.quds': '''# Automated clinical rhythm classifier
classifyRhythm(bpm: double, stShift: double) -> Map:
  var status = "نظم جيبي طبيعي (Normal Sinus)"
  var color = "#10B981"
  if stShift >= 0.25:
    status = "⚠️ ارتفاع ST (يستدعي تقييمًا فوريًا)"
    color = "#EF4444"
  else if bpm < 60.0:
    status = "بطء نبض (Bradycardia)"
    color = "#F59E0B"
  else if bpm > 100.0:
    status = "تسارع نبض (Tachycardia)"
    color = "#F97316"
  rrMs = 60000.0 / bpm
  return map:
    "status": status
    "color": color
    "rrMs": rrMs
''',
        'main.quds':
            '''# جهاز تخطيط قلب طبي حي (ECG 60fps + تحليل طيف FFT + ملف مريض JSON + شعار BMP)
use quds:assets as assets
use quds:math show fftReal, mean, stddev
use quds:viz as viz
use bio.ecg_synth show ecgSample
use clinical.triage show classifyRhythm

patient = assets.readJson("assets/patient_profile.json")
clk = viz.animate(fps: 60, duration: 10.0, loop: true)
bpm = viz.slider("bpm", min: 45.0, max: 145.0, value: 74.0, step: 1.0, label: "نبض القلب (BPM)")
stShift = viz.slider("st", min: 0.0, max: 0.45, value: 0.05, step: 0.05, label: "إزاحة مقطع ST (mV)")
noiseAmp = viz.slider("noise", min: 0.0, max: 0.15, value: 0.02, step: 0.01, label: "ضوضاء الحساس")

triage = classifyRhythm(bpm, stShift)
traceCol = triage["color"].toString()
beatsPerSec = bpm / 60.0

s = viz.scene(title: "❤️ {patient['device']} — {triage['status']}", grid: true, axes: false, bounds: [0.0, 4.0, -0.8, 1.9])

# Generate live scrolling 4-second ECG oscilloscope trace (128 samples)
var ecgPts = []
var waveSamples = []
var rPeaks = 0
var i = 0
while i < 128:
  x = (i / 127.0) * 4.0
  ph = ((x + clk.t * 0.85) * beatsPerSec) % 1.0
  y = ecgSample(ph, stShift, noiseAmp, i)
  ecgPts.add([x, y])
  waveSamples.add(y)
  if y > 1.15:
    rPeaks = rPeaks + 1
  i = i + 1

s.curve("ecgTrace", ecgPts, color: traceCol, strokeWidth: 2.6)
headPt = ecgPts[127] as List
s.point("scanHead", headPt[0] to double, headPt[1] to double, color: "#FEF08A", radius: 6.0)

s.readout("النبض", bpm, unit: "BPM", decimals: 0, color: traceCol)
s.readout("فترة RR", triage["rrMs"] to double, unit: "ms", decimals: 0, color: "#38BDF8")
s.readout("الأكسجة SpO₂", patient["spo2Pct"] to double, unit: "%", decimals: 1, color: "#10B981")
s.readout("انحراف الإشارة", stddev(waveSamples), unit: "mV", decimals: 3, color: "#A855F7")
s.render()

# Spectral FFT analysis of the ECG waveform using native quds:math
spec = fftReal(waveSamples)
var fBins = []
var fMags = []
var k = 1
while k < 40:
  fBins.add(k to double)
  fMags.add(spec[k].abs())
  k = k + 1

viz.plot(fBins, fMags, title: "📊 التحليل الطيفي لنبضة ECG عبر quds:math FFT", xLabel: "Harmonic Bin", yLabel: "Amplitude", color: traceCol)
assets.renderImage("assets/medical_badge.bmp", title: "🏥 شاشة العناية الطبية (assets/medical_badge.bmp)", caption: "{patient['device']} · {patient['ward']} · النطاق الطبيعي {patient['normalMinBpm']}–{patient['normalMaxBpm']} BPM")

card = map:
  "الجهاز / القسم": "{patient['device']} · {patient['ward']}"
  "التصنيف السريري": triage["status"]
  "معدل النبض / RR": "{bpm.toInt()} BPM ({triage['rrMs'].toStringAsFixed(0)} ms)"
  "متوسط الجهد": "{mean(waveSamples).toStringAsFixed(3)} mV"
viz.form(card, title: "🩺 التقرير الحيوي الفوري للمريض")

print "ECG Monitor OK | BPM={bpm.toInt()} | RR={triage['rrMs'].toStringAsFixed(0)} ms | {triage['status']}"
''',
      },
    );

/// The 5 flagship engineering, robotics, aerospace, energy & medical projects.
final List<StudioProjectTemplate> engineeringProjectTemplates = [
  StudioProjectTemplate(
    id: 'v4_turbo_engine',
    nameAr: 'محرك تيربو 4-أشواط',
    nameEn: '4-Stroke Turbo Engine',
    subtitleAr:
        'محاكاة حية 60fps للمكبس والصمامات والتيربو + مخطط BMP + منحنى الداينو',
    subtitleEn: '60fps Piston/Valves/Turbo sim + BMP blueprint + Dyno HP curve',
    icon: Icons.engineering_rounded,
    accentColor: const Color(0xFFF97316),
    builder: buildTurboEngineProject,
  ),
  StudioProjectTemplate(
    id: 'cnc_robotic_arm',
    nameAr: 'ذراع روبوتية CNC',
    nameEn: '3-DOF Robotic CNC Arm',
    subtitleAr: 'حركيات عكسية IK + مسار لحام CSV + عزوم المحركات + مخطط BMP',
    subtitleEn:
        'Inverse Kinematics + CSV CNC path + Joint torques + BMP schematic',
    icon: Icons.precision_manufacturing_rounded,
    accentColor: const Color(0xFF10B981),
    builder: buildRoboticArmProject,
  ),
  StudioProjectTemplate(
    id: 'jet_turbine_cfd',
    nameAr: 'محرك نفاث توربيني',
    nameEn: 'Turbofan Jet Engine',
    subtitleAr: 'دورة برايتون + ريش دوّارة + غلاف جوي ISA JSON + مقطع BMP',
    subtitleEn:
        'Brayton cycle + spinning fan + ISA atmosphere JSON + BMP cutaway',
    icon: Icons.flight_takeoff_rounded,
    accentColor: const Color(0xFF8B5CF6),
    builder: buildJetTurbineProject,
  ),
  StudioProjectTemplate(
    id: 'smart_power_grid',
    nameAr: 'شبكة طاقة وتوربين رياح',
    nameEn: 'Smart Grid & Wind Twin',
    subtitleAr:
        'توربين رياح + ألواح شمسية + بطاريات + أحمال 24 ساعة CSV + مخطط BMP',
    subtitleEn:
        'Wind turbine + Solar PV + Battery + 24h CSV dispatch + BMP diagram',
    icon: Icons.wind_power_rounded,
    accentColor: const Color(0xFF0EA5E9),
    builder: buildSmartGridProject,
  ),
  StudioProjectTemplate(
    id: 'cardiac_ecg_monitor',
    nameAr: 'جهاز تخطيط القلب ECG',
    nameEn: 'Cardiac ECG Monitor',
    subtitleAr: 'موجة PQRST حية 60fps + تحليل طيف FFT + تصنيف سريري + شعار BMP',
    subtitleEn:
        'Live 60fps PQRST trace + FFT spectrum + clinical triage + BMP badge',
    icon: Icons.monitor_heart_rounded,
    accentColor: const Color(0xFFEF4444),
    builder: buildMedicalEcgProject,
  ),
];
