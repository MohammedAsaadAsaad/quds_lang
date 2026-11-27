import 'package:quds/editor_engine.dart';
import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('QudsWorkspace tree, paths, dependency graph & serialization', () {
    test('normalizes paths, manages folders/files, and rejects root escape',
        () {
      final ws = QudsWorkspace(name: 'matlab_lab');
      ws.createFolder('math/ode');
      ws.createFolder('physics/models');
      ws.writeFile('/core/constants.quds', 'const G = 9.81\n');
      ws.writeFile('math/ode/rk4.quds', 'use ^.core.constants\n');
      ws.writeFile('main.quds', 'use math.ode.rk4\n');

      expect(ws.hasFile('core/constants.quds'), isTrue);
      expect(
          ws.listFolders(),
          containsAll(
              ['core', 'math', 'math/ode', 'physics', 'physics/models']));
      expect(ws.listFiles(),
          equals(['core/constants.quds', 'main.quds', 'math/ode/rk4.quds']));

      // Root escape rejected
      expect(() => QudsWorkspace.normalizePath('../outside.quds'),
          throwsArgumentError);
      expect(() => QudsWorkspace.normalizePath('a/../../outside.quds'),
          throwsArgumentError);

      // Rename & delete
      expect(ws.renameFile('core/constants.quds', 'core/consts.quds'), isTrue);
      expect(ws.hasFile('core/constants.quds'), isFalse);
      expect(ws.hasFile('core/consts.quds'), isTrue);

      final tree = ws.buildTree();
      expect(tree.isDirectory, isTrue);
      expect(tree.children.map((c) => c.name),
          containsAll(['core', 'math', 'physics', 'main.quds']));

      // Delete folder removes nested files
      expect(ws.deleteFolder('math'), equals(1));
      expect(ws.hasFile('math/ode/rk4.quds'), isFalse);
    });

    test('serializes and restores .qproj JSON losslessly', () {
      final ws = QudsWorkspace.scientificProjectTemplate();
      ws.createFolder('experiments/empty_dir');
      final jsonStr = ws.toJsonString();
      final restored = QudsWorkspace.fromJsonString(jsonStr);

      expect(restored.name, equals(ws.name));
      expect(restored.entryPoint, equals(ws.entryPoint));
      expect(restored.listFiles(), equals(ws.listFiles()));
      expect(restored.listFolders(), contains('experiments/empty_dir'));
      for (final f in ws.listFiles()) {
        expect(restored.readFile(f), equals(ws.readFile(f)));
      }
    });
  });

  group('Multi-file & nested-folder execution', () {
    test(
        '1. Deep 4-level nested imports with relative, ^., ^^., and ^^^. parent climbing',
        () async {
      final ws = QudsWorkspace(
        name: 'deep_tree',
        files: {
          'core/constants.quds': '''
const PI_APPROX = 3.14159
const GRAVITY = 9.8
''',
          'math/ode/helpers/step.quds': '''
use ^^^.core.constants

euler_step(y: double, dy: double, dt: double) -> double:
  return y + dy * dt

gravity_pull(dt: double) -> double:
  return -GRAVITY * dt
''',
          'math/ode/rk4.quds': '''
use helpers.step
use ^^.core.constants as c

integrate_fall(h0: double, steps: int, dt: double) -> double:
  var y = h0
  var v = 0.0
  for i in 0..<steps:
    v = v + gravity_pull(dt)
    y = euler_step(y, v, dt)
  return y

circle_area(r: double) -> double:
  return c.PI_APPROX * r * r
''',
          'sim/runner.quds': '''
use ^.math.ode.rk4 as solver

run_sim() -> double:
  return solver.integrate_fall(100.0, 10, 0.1) + solver.circle_area(2.0)
''',
          'main.quds': '''
use sim.runner

total = run_sim()
print(total)
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      final total = session.getVariable('total') as double;
      // After 10 Euler steps of dt=0.1: v_k = -0.98*k, sum(v_k*0.1) = -0.098 * 55 = -5.39
      // y = 100 - 5.39 = 94.61; circle_area(2) = 12.56636; total = 107.17636
      expect(total, closeTo(107.17636, 1e-4));
      expect(res.printedLines, hasLength(1));
    });

    test('2. Diamond dependency singleton guarantee & shared class identity',
        () async {
      final ws = QudsWorkspace(
        name: 'diamond',
        files: {
          'shared/signal.quds': '''
var initCount = 0
initCount = initCount + 1

class Signal:
  name: String
  amplitude: double
  scaled(factor: double) -> double:
    return amplitude * factor

get_init_count() -> int:
  return initCount
''',
          'branch_a/producer.quds': '''
use ^.shared.signal

make_signal(amp: double) -> Signal:
  return Signal("sine", amp)
''',
          'branch_b/consumer.quds': '''
use ^.shared.signal

inspect_signal(s: Object) -> Map:
  is_sig = s is Signal
  val = (s as Signal).scaled(2.5)
  return map:
    "isSignal": is_sig
    "scaled": val
    "initCount": get_init_count()
''',
          'main.quds': '''
use branch_a.producer
use branch_b.consumer
use shared.signal

sig = make_signal(4.0)
report = inspect_signal(sig)
direct_count = get_init_count()
is_sig_main = sig is Signal
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      final report = session.getVariable('report') as Map;
      expect(report['isSignal'], isTrue);
      expect(report['scaled'], closeTo(10.0, 1e-9));
      expect(report['initCount'], equals(1));
      expect(session.getVariable('direct_count'), equals(1));
      expect(session.getVariable('is_sig_main'), isTrue);
    });

    test(
        '3. Multi-level barrel export facades, show/hide filters, and folder index.quds',
        () async {
      final ws = QudsWorkspace(
        name: 'barrels',
        files: {
          'toolbox/linalg/vec.quds': '''
use dart:math as m

dot2(ax: double, ay: double, bx: double, by: double) -> double:
  return ax * bx + ay * by

norm2(x: double, y: double) -> double:
  return m.sqrt(x * x + y * y)

secret_vec_helper() -> int:
  return 999
''',
          'toolbox/stats/basic.quds': '''
avg2(a: double, b: double) -> double:
  return (a + b) / 2.0

hidden_helper() -> int:
  return -1
''',
          'toolbox/index.quds': '''
export linalg.vec show dot2, norm2
export stats.basic hide hidden_helper
''',
          'api.quds': '''
export toolbox
''',
          'main.quds': '''
use api as tb
use toolbox

d = tb.dot2(3.0, 4.0, 1.0, 2.0)
n = norm2(3.0, 4.0)
m = tb.avg2(10.0, 20.0)
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('d'), closeTo(11.0, 1e-9));
      expect(session.getVariable('n'), closeTo(5.0, 1e-9));
      expect(session.getVariable('m'), closeTo(15.0, 1e-9));

      // Verify filtered-out symbols (`secret_vec_helper`, `hidden_helper`) are NOT exported
      ws.writeFile('bad_show.quds', 'use api show hidden_helper\n');
      final bad1 = await session.runFile('bad_show.quds');
      expect(bad1.succeeded, isFalse);
      expect((bad1.error as QudsRuntimeException).code, equals('E900'));

      ws.writeFile('bad_show2.quds', 'use toolbox show secret_vec_helper\n');
      final bad2 = await session.runFile('bad_show2.quds');
      expect(bad2.succeeded, isFalse);
      expect((bad2.error as QudsRuntimeException).code, equals('E900'));
    });

    test(
        '4. Cross-file ::section imports including section-scoped barrel re-exports',
        () async {
      final ws = QudsWorkspace(
        name: 'sections',
        files: {
          'math/solvers/newton.quds': '''
sqrt_newton(x: double) -> double:
  var g = x / 2.0
  for i in range(12):
    g = 0.5 * (g + x / g)
  return g
''',
          'math/suite.quds': '''
:: trig
deg_to_rad(d: double) -> double:
  return d * 3.141592653589793 / 180.0

:: algebra
square(x: double) -> double:
  return x * x

cube(x: double) -> double:
  return x * x * x

:: solvers
export solvers.newton
''',
          'main.quds': '''
use math.suite::algebra show square
use math.suite::solvers as sol

s = square(7.0)
r = sol.sqrt_newton(25.0)
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('s'), closeTo(49.0, 1e-9));
      expect(session.getVariable('r'), closeTo(5.0, 1e-6));
      // `deg_to_rad` from `::trig` must NOT be imported
      expect(session.getVariable('deg_to_rad'), isNull);

      // Missing section fails with E900
      ws.writeFile('bad_sec.quds', 'use math.suite::quantum\n');
      final bad = await session.runFile('bad_sec.quds');
      expect(bad.succeeded, isFalse);
      expect((bad.error as QudsRuntimeException).code, equals('E900'));
    });

    test(
        '5. package:<name> and package:<name>/... resolution from nested folders',
        () async {
      final ws = QudsWorkspace(
        name: 'pkg_project',
        files: {
          'lib/matlab_core.quds': '''
const VERSION = "2.0"
linspace(a: double, b: double, n: int) -> List<double>:
  var out = []
  step = (b - a) / (n - 1)
  for i in 0..<n:
    out.add(a + i * step)
  return out
''',
          'lib/solvers/fft.quds': '''
dc_component(samples: List<double>) -> double:
  var sum = 0.0
  for s in samples:
    sum = sum + s
  return sum / samples.length
''',
          'experiments/lab1/run.quds': '''
use package:matlab_core
use package:matlab_core/solvers/fft as fft

grid = linspace(0.0, 10.0, 5)
dc = fft.dc_component(grid)
ver = VERSION
''',
        },
        entryPoint: 'experiments/lab1/run.quds',
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('ver'), equals('2.0'));
      expect(session.getVariable('grid'), equals([0.0, 2.5, 5.0, 7.5, 10.0]));
      expect(session.getVariable('dc'), closeTo(5.0, 1e-9));
    });

    test(
        '6. Visibility isolation: _private and internal declarations stay module-local',
        () async {
      final ws = QudsWorkspace(
        name: 'visibility',
        files: {
          'core/secret.quds': '''
const _SECRET_KEY = 42

_private_scale(x: int) -> int:
  return x * _SECRET_KEY

internal internal_offset(x: int) -> int:
  return x + 1

public_compute(x: int) -> int:
  return internal_offset(_private_scale(x))
''',
          'main.quds': '''
use core.secret

ans = public_compute(2)
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('ans'), equals(85));
      expect(session.getVariable('_SECRET_KEY'), isNull);
      expect(session.getVariable('_private_scale'), isNull);
      expect(session.getVariable('internal_offset'), isNull);

      ws.writeFile('try_private.quds', 'use core.secret show _private_scale\n');
      final r1 = await session.runFile('try_private.quds');
      expect(r1.succeeded, isFalse);
      expect((r1.error as QudsRuntimeException).code, equals('E900'));

      ws.writeFile(
          'try_internal.quds', 'use core.secret show internal_offset\n');
      final r2 = await session.runFile('try_internal.quds');
      expect(r2.succeeded, isFalse);
      expect((r2.error as QudsRuntimeException).code, equals('E900'));
    });

    test(
        '7. Circular import detection (E210): 2-file, 3-file nested, and root entry cycle',
        () async {
      // 7a. 2-file direct cycle
      final ws2 = QudsWorkspace(
        name: 'cycle2',
        files: {
          'a.quds': 'use b\nx = 1\n',
          'b.quds': 'use a\ny = 2\n',
          'main.quds': 'use a\n',
        },
      );
      final report2 = ws2.analyzeDependencies();
      expect(report2.hasCycles, isTrue);

      final s2 = QudsSession(projectWorkspace: ws2);
      addTearDown(s2.dispose);
      final res2 = await s2.runProject();
      expect(res2.succeeded, isFalse);
      expect(res2.error, isA<QudsRuntimeException>());
      expect((res2.error as QudsRuntimeException).code, equals('E210'));
      expect(res2.error.toString(), contains('a.quds -> b.quds -> a.quds'));

      // 7b. 3-file nested folder cycle
      final ws3 = QudsWorkspace(
        name: 'cycle3',
        files: {
          'a/one.quds': 'use ^.b.two\n',
          'b/two.quds': 'use ^.c.three\n',
          'c/three.quds': 'use ^.a.one\n',
          'main.quds': 'use a.one\n',
        },
      );
      expect(ws3.analyzeDependencies().hasCycles, isTrue);

      final s3 = QudsSession(projectWorkspace: ws3);
      addTearDown(s3.dispose);
      final res3 = await s3.runProject();
      expect(res3.succeeded, isFalse);
      expect((res3.error as QudsRuntimeException).code, equals('E210'));
      expect(res3.error.toString(),
          contains('a/one.quds -> b/two.quds -> c/three.quds -> a/one.quds'));

      // 7c. Entry-point cycle: main.quds -> helper.quds -> main.quds
      final wsRoot = QudsWorkspace(
        name: 'cycle_root',
        files: {
          'helper.quds': 'use main\n',
          'main.quds': 'use helper\n',
        },
      );
      final sRoot = QudsSession(projectWorkspace: wsRoot);
      addTearDown(sRoot.dispose);
      final resRoot = await sRoot.runProject();
      expect(resRoot.succeeded, isFalse);
      expect((resRoot.error as QudsRuntimeException).code, equals('E210'));
      expect(resRoot.error.toString(),
          contains('main.quds -> helper.quds -> main.quds'));
    });

    test(
        '8. Hot-reload surgical transitive invalidation preserves unrelated module caches',
        () async {
      var unrelatedLoads = 0;
      final ws = QudsWorkspace(
        name: 'hot_reload',
        files: {
          'core/constants.quds': 'const GRAVITY = 9.81\n',
          'physics/weight.quds': '''
use ^.core.constants

weight(mass: double) -> double:
  return mass * GRAVITY
''',
          'physics/index.quds': 'export weight\n',
          'unrelated/telemetry.quds': '''
print("telemetry_init")
const TAG = "v1"
''',
          'main.quds': '''
use physics
use unrelated.telemetry

w = weight(10.0)
tag = TAG
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      // Run 1: Earth gravity
      final r1 = await session.runProject();
      expect(r1.succeeded, isTrue, reason: '${r1.error}');
      expect(session.getVariable('w'), closeTo(98.1, 1e-9));
      unrelatedLoads +=
          r1.printedLines.where((l) => l == 'telemetry_init').length;
      expect(unrelatedLoads, equals(1));

      // Edit deep leaf `core/constants.quds` -> Moon gravity (1.62)
      ws.writeFile('core/constants.quds', 'const GRAVITY = 1.62\n');

      // Run 2: transitive dependents (`physics/weight.quds`, `physics/index.quds`)
      // must re-evaluate with 1.62, while `unrelated/telemetry.quds` stays cached!
      final r2 = await session.runProject();
      expect(r2.succeeded, isTrue, reason: '${r2.error}');
      expect(session.getVariable('w'), closeTo(16.2, 1e-9));
      expect(r2.printedLines.where((l) => l == 'telemetry_init'), isEmpty);

      // Run 3: explicit `resetWorkspaceModules: true` re-evaluates everything
      final r3 = await session.runProject(resetWorkspaceModules: true);
      expect(r3.succeeded, isTrue, reason: '${r3.error}');
      expect(r3.printedLines, contains('telemetry_init'));
    });

    test(
        '9. Cross-file OOP, inheritance, closures, operators & function overloads',
        () async {
      final ws = QudsWorkspace(
        name: 'oop_cross_file',
        files: {
          'math/vec2.quds': '''
use dart:math as m

class Vec2:
  x: double
  y: double

  operator +(other: Vec2) -> Vec2:
    return Vec2(x + other.x, y + other.y)

  operator *(s: double) -> Vec2:
    return Vec2(x * s, y * s)

  mag() -> double:
    return m.sqrt(x * x + y * y)

scale_val(v: int) -> int:
  return v * 10

scale_val(v: Vec2, s: double) -> Vec2:
  return v * s
''',
          'physics/body.quds': '''
use ^.math.vec2

class Body:
  pos: Vec2
  vel: Vec2

  advance(dt: double) -> Vec2:
    return pos + vel * dt

class ChargedBody extends Body:
  charge: double

  energy_hint() -> double:
    return charge * vel.mag()

make_stepper(accel: Vec2) -> Object:
  return (b: Body, dt: double) -> b.pos + (b.vel + accel * dt) * dt
''',
          'main.quds': '''
use math.vec2
use physics.body

b = ChargedBody(Vec2(1.0, 2.0), Vec2(3.0, 4.0), 2.0)
next_pos = b.advance(0.5)
stepper = make_stepper(Vec2(0.0, -10.0))
acc_pos = stepper(b, 0.5)
eh = b.energy_hint()
ov_int = scale_val(5)
ov_vec = scale_val(Vec2(1.0, 3.0), 2.0)
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');

      final nextPos = session.getVariable('next_pos') as QudsInstance;
      expect(nextPos.fields['x'], closeTo(2.5, 1e-9));
      expect(nextPos.fields['y'], closeTo(4.0, 1e-9));

      final accPos = session.getVariable('acc_pos') as QudsInstance;
      expect(accPos.fields['x'], closeTo(2.5, 1e-9));
      expect(accPos.fields['y'], closeTo(1.5, 1e-9));

      expect(session.getVariable('eh'), closeTo(10.0, 1e-9));
      expect(session.getVariable('ov_int'), equals(50));
      final ovVec = session.getVariable('ov_vec') as QudsInstance;
      expect(ovVec.fields['x'], closeTo(2.0, 1e-9));
      expect(ovVec.fields['y'], closeTo(6.0, 1e-9));
    });

    test(
        '10. Scientific template (5 nested files) + quds:viz + live slider updates',
        () async {
      final ws = QudsWorkspace.scientificProjectTemplate();
      final report = ws.analyzeDependencies();
      expect(report.hasCycles, isFalse);
      expect(report.hasUnresolvedImports, isFalse);

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final r1 = await session.runProject();
      expect(r1.succeeded, isTrue, reason: '${r1.error}');
      expect(r1.outputs.whereType<QudsPlot2DOutput>(), isNotEmpty);
      expect(r1.outputs.whereType<QudsTableOutput>(), isNotEmpty);
      expect(r1.printedLines, isNotEmpty);

      final range1 = session.getVariable('range_x') as double;
      expect(range1, greaterThan(20.0));

      // Live slider update (`v0` increased from 22 -> 38) recomputes multi-file simulation!
      final r2 = await session.updateInteractiveInputs({'v0': 38.0});
      expect(r2.succeeded, isTrue, reason: '${r2.error}');
      final range2 = session.getVariable('range_x') as double;
      expect(range2, greaterThan(range1 * 1.5));
    });

    test(
        '11. Multi-file project combining quds:data analytics and quds:viz reporting',
        () async {
      final ws = QudsWorkspace(
        name: 'data_pipeline',
        files: {
          'data/loader.quds': '''
use quds:data as data

load_sensors():
  csv = "sensor,temp,pressure\\nS1,22.0,101.2\\nS2,28.5,100.8\\nS3,31.0,100.4\\nS4,19.5,101.6"
  return data.parseCsv(csv)
''',
          'analytics/metrics.quds': '''
use ^.data.loader

hot_sensors_summary():
  df = load_sensors()
  hot = df.filter((row) -> row["temp"] > 25.0)
  stats = df.describe("temp")
  return map:
    "totalCount": df.rowCount
    "hotCount": hot.rowCount
    "meanTemp": stats["mean"]
    "hotCols": hot.columns
    "hotRows": hot.rows
''',
          'main.quds': '''
use quds:viz as viz
use analytics.metrics

summary = hot_sensors_summary()
viz.table(summary["hotCols"], summary["hotRows"], title: "Hot Sensors")
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      final summary = session.getVariable('summary') as Map;
      expect(summary['totalCount'], equals(4));
      expect(summary['hotCount'], equals(2));
      expect(summary['meanTemp'], closeTo(25.25, 1e-9));
      expect(res.outputs.whereType<QudsTableOutput>(), hasLength(1));
    });

    test(
        '12. Cross-file error span, breakpoints in nested file, policy limits & EditorEngine',
        () async {
      // 12a. Accurate error file & line inside nested imported file
      final wsErr = QudsWorkspace(
        name: 'err_trace',
        files: {
          'a/b/crash.quds': '''
safe_fn() -> int:
  return 1

boom(x: int) -> int:
  return x ~/ 0
''',
          'main.quds': '''
use a.b.crash

val = boom(5)
''',
        },
      );
      final sErr = QudsSession(projectWorkspace: wsErr);
      addTearDown(sErr.dispose);
      final errRes = await sErr.runProject();
      expect(errRes.succeeded, isFalse);
      final rtErr = errRes.error as QudsRuntimeException;
      expect(rtErr.span.file, equals('a/b/crash.quds'));
      expect(rtErr.span.line, equals(5));

      // 12b. Cross-file breakpoint pauses inside nested workspace module
      final wsDbg = QudsWorkspace(
        name: 'debug_multi',
        files: {
          'math/kernel.quds': '''
compute_sum(n: int) -> int:
  var acc = 0
  for i in 0..<n:
    acc = acc + i
  return acc
''',
          'main.quds': '''
use math.kernel

res = compute_sum(4)
''',
        },
      );
      final dbg = QudsDebugController();
      dbg.setLineBreakpoints('math/kernel.quds', {4});
      final sDbg = QudsSession(projectWorkspace: wsDbg, debugger: dbg);
      addTearDown(sDbg.dispose);

      final pausedLocations = <String>[];
      final sub = sDbg.events.listen((ev) {
        if (ev is QudsDebugPausedRuntimeEvent) {
          pausedLocations.add('${ev.pause.span.file}:${ev.pause.span.line}');
          // Continue automatically after inspecting nested frame locals
          dbg.continueRun();
        }
      });
      addTearDown(sub.cancel);

      final dbgRes = await sDbg.runProject();
      expect(dbgRes.succeeded, isTrue, reason: '${dbgRes.error}');
      expect(sDbg.getVariable('res'), equals(6));
      expect(pausedLocations, contains('math/kernel.quds:4'));

      // 12c. Policy enforcement inside multi-file workspace (deniedLibraries & maxSteps)
      final wsPol = QudsWorkspace(
        name: 'policy_multi',
        files: {
          'core/secret.quds': 'const X = 1\n',
          'core/infinite.quds': '''
spin() -> int:
  var i = 0
  while true:
    i = i + 1
  return i
''',
          'use_secret.quds': 'use core.secret\n',
          'use_spin.quds': 'use core.infinite\nv = spin()\n',
        },
      );
      final sPol = QudsSession(
        projectWorkspace: wsPol,
        policy: QudsExecutionPolicy.strictSandbox().copyWith(
          deniedLibraries: const {'core.secret'},
          maxSteps: 500,
        ),
      );
      addTearDown(sPol.dispose);

      final deniedRes = await sPol.runFile('use_secret.quds');
      expect(deniedRes.succeeded, isFalse);
      expect(deniedRes.error, isA<QudsPolicyViolationException>());

      final stepRes = await sPol.runFile('use_spin.quds');
      expect(stepRes.succeeded, isFalse);
      expect(stepRes.error, isA<QudsPolicyViolationException>());

      // 12d. QudsEditorEngine workspace awareness (diagnostics + completions)
      final wsIde = QudsWorkspace.scientificProjectTemplate();
      final sIde = QudsSession(
        projectWorkspace: wsIde,
        policy: QudsExecutionPolicy.strictSandbox().copyWith(
          allowedLibraries: const {
            'quds:math',
            'quds:viz',
            'quds:data',
            'dart:math'
          },
        ),
      );
      addTearDown(sIde.dispose);
      final engine = QudsEditorEngine(session: sIde);

      // Valid workspace imports in main.quds must produce ZERO errors even under strictSandbox policy!
      final mainAnalysis = engine.analyze(
        wsIde.readFile('main.quds')!,
        file: 'main.quds',
      );
      expect(mainAnalysis.diagnostics, isEmpty);

      // Missing workspace module produces E900 (not P102)
      final missingAnalysis = engine.analyze(
        'use physics.does_not_exist\n',
        file: 'main.quds',
      );
      expect(missingAnalysis.diagnostics, hasLength(1));
      expect(missingAnalysis.diagnostics.first.code, equals('E900'));

      // Import URI autocomplete suggests workspace modules (`physics.integrator`, `core.constants`, etc.)
      const usePrefix = 'use ph';
      final importItems = engine.completeAt(
        usePrefix,
        usePrefix.length,
        file: 'main.quds',
      );
      expect(
        importItems.map((i) => i.label),
        contains('physics.integrator'),
      );

      // Member autocomplete on prefixed workspace barrel import (`phys.`) suggests re-exported functions!
      const memberSrc = 'use physics.index as phys\nres = phys.step';
      final memberItems = engine.completeAt(
        memberSrc,
        memberSrc.length,
        file: 'main.quds',
      );
      expect(
        memberItems.map((i) => i.label),
        contains('stepProjectile'),
      );
    });

    test(
        '13. Large MATLAB-style 18-file multi-domain scientific toolbox execution stress test',
        () async {
      final ws = QudsWorkspace(
        name: 'quds_matlab_suite',
        packageName: 'quds_matlab_suite',
        files: {
          'core/constants.quds':
              'const PI = 3.141592653589793\nconst E = 2.718281828459045\n',
          'core/numeric.quds': '''
clamp_val(x: double, lo: double, hi: double) -> double:
  if x < lo:
    return lo
  if x > hi:
    return hi
  return x
''',
          'core/index.quds': 'export constants\nexport numeric\n',
          'linalg/vector.quds': '''
use dart:math as m

dot(a: List<double>, b: List<double>) -> double:
  var s = 0.0
  for i in 0..<a.length:
    s = s + a[i] * b[i]
  return s

l2_norm(a: List<double>) -> double:
  return m.sqrt(dot(a, a))
''',
          'linalg/matrix.quds': '''
use vector show dot

mat_vec(mat: List<List<double>>, v: List<double>) -> List<double>:
  var out: List<double> = []
  for row in mat:
    out.add(dot(row, v))
  return out
''',
          'linalg/index.quds': 'export vector\nexport matrix\n',
          'stats/central.quds': '''
mean_list(xs: List<double>) -> double:
  var s = 0.0
  for x in xs:
    s = s + x
  return s / xs.length
''',
          'stats/spread.quds': '''
use dart:math as m
use central show mean_list

std_list(xs: List<double>) -> double:
  mu = mean_list(xs)
  var acc = 0.0
  for x in xs:
    d = x - mu
    acc = acc + d * d
  return m.sqrt(acc / xs.length)
''',
          'stats/index.quds': 'export central\nexport spread\n',
          'ode/rk4.quds': '''
rk4_scalar(f: Object, y0: double, t0: double, h: double, steps: int) -> double:
  var y = y0
  var t = t0
  for i in 0..<steps:
    k1 = f(t, y)
    k2 = f(t + 0.5 * h, y + 0.5 * h * k1)
    k3 = f(t + 0.5 * h, y + 0.5 * h * k2)
    k4 = f(t + h, y + h * k3)
    y = y + (h / 6.0) * (k1 + 2.0 * k2 + 2.0 * k3 + k4)
    t = t + h
  return y
''',
          'ode/models/decay.quds': '''
use ^.rk4 show rk4_scalar

solve_decay(y0: double, rate: double, t_end: double, steps: int) -> double:
  h = t_end / steps
  return rk4_scalar((t: double, y: double) -> -rate * y, y0, 0.0, h, steps)
''',
          'ode/index.quds': 'export rk4\nexport models.decay\n',
          'signal/window.quds': '''
use dart:math as m
use ^.core.constants show PI

hann_window(n: int) -> List<double>:
  var w: List<double> = []
  for i in 0..<n:
    w.add(0.5 * (1.0 - m.cos(2.0 * PI * i / (n - 1))))
  return w
''',
          'signal/energy.quds': '''
use ^.linalg.vector show dot

signal_energy(samples: List<double>) -> double:
  return dot(samples, samples)
''',
          'signal/index.quds': 'export window\nexport energy\n',
          'toolbox/index.quds': '''
export ^.core
export ^.linalg
export ^.stats
export ^.ode
export ^.signal
''',
          'experiments/benchmark.quds': '''
use ^.toolbox as tb

run_benchmark() -> Map:
  mat = [[2.0, 1.0], [1.0, 3.0]]
  v = [1.0, 2.0]
  mv = tb.mat_vec(mat, v)
  nrm = tb.l2_norm(mv)
  decay_y = tb.solve_decay(100.0, 0.5, 2.0, 20)
  win = tb.hann_window(5)
  en = tb.signal_energy(win)
  mu = tb.mean_list(mv)
  sd = tb.std_list(mv)
  return map:
    "mv": mv
    "norm": nrm
    "decay": decay_y
    "energy": en
    "mean": mu
    "std": sd
''',
          'main.quds': '''
use experiments.benchmark

results = run_benchmark()
''',
        },
      );

      expect(ws.listFiles(), hasLength(18));
      final depReport = ws.analyzeDependencies();
      expect(depReport.hasCycles, isFalse);
      expect(depReport.hasUnresolvedImports, isFalse);

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      final results = session.getVariable('results') as Map;
      // mat_vec([[2,1],[1,3]], [1,2]) = [4, 7]
      expect(results['mv'], equals([4.0, 7.0]));
      expect(results['norm'], closeTo(8.0622577, 1e-5));
      // 100 * exp(-0.5 * 2) = 100 * exp(-1) = 36.787944
      expect(results['decay'], closeTo(36.787944, 1e-4));
      // hann_window(5) = [0, 0.5, 1, 0.5, 0] -> energy = 0 + 0.25 + 1 + 0.25 + 0 = 1.5
      expect(results['energy'], closeTo(1.5, 1e-9));
      expect(results['mean'], closeTo(5.5, 1e-9));
      expect(results['std'], closeTo(1.5, 1e-9));
    });

    test(
        '14. Multiple independent aliases & selective show/hide over same cached module',
        () async {
      final ws = QudsWorkspace(
        name: 'multi_alias',
        files: {
          'math/ops.quds': '''
print("ops_loaded")

add_n(a: int, b: int) -> int:
  return a + b

mul_n(a: int, b: int) -> int:
  return a * b

sub_n(a: int, b: int) -> int:
  return a - b
''',
          'main.quds': '''
use math.ops as adder show add_n
use math.ops as others hide add_n
use math.ops show mul_n

r1 = adder.add_n(3, 4)
r2 = others.sub_n(10, 3)
r3 = mul_n(5, 6)
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('r1'), equals(7));
      expect(session.getVariable('r2'), equals(7));
      expect(session.getVariable('r3'), equals(30));
      // Underlying module must evaluate ONCE despite 3 different import forms
      expect(res.printedLines, equals(['ops_loaded']));

      // Confirm `adder.mul_n` is NOT exposed because of `show add_n`
      ws.writeFile('bad_alias.quds',
          'use math.ops as adder show add_n\nx = adder.mul_n(2, 3)\n');
      final bad = await session.runFile('bad_alias.quds');
      expect(bad.succeeded, isFalse);
    });

    test(
        '15. Disambiguating colliding symbol names across sibling folders via aliases & hide/show',
        () async {
      final ws = QudsWorkspace(
        name: 'disambiguate',
        files: {
          'solvers/fast.quds': '''
const ENGINE = "fast"
solve(x: double) -> double:
  return x * 2.0
fast_only() -> int:
  return 100
''',
          'solvers/precise.quds': '''
const ENGINE = "precise"
solve(x: double) -> double:
  return x * 2.0001
''',
          'main.quds': '''
use solvers.fast as f
use solvers.precise as p
use solvers.fast hide solve, ENGINE
use solvers.precise show solve

a = f.solve(10.0)
b = p.solve(10.0)
c = solve(10.0)
d = fast_only()
names = [f.ENGINE, p.ENGINE]
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('a'), closeTo(20.0, 1e-9));
      expect(session.getVariable('b'), closeTo(20.001, 1e-9));
      expect(session.getVariable('c'), closeTo(20.001, 1e-9));
      expect(session.getVariable('d'), equals(100));
      expect(session.getVariable('names'), equals(['fast', 'precise']));
    });

    test('16. Cross-file async/await chains across nested folders', () async {
      final ws = QudsWorkspace(
        name: 'async_multi',
        files: {
          'io/source.quds': '''
fetch_value(id: int) async -> int:
  return id * 10
''',
          'pipeline/batch.quds': '''
use ^.io.source

sum_batch(ids: List<int>) async -> int:
  var total = 0
  for id in ids:
    v = await fetch_value(id)
    total = total + v
  return total
''',
          'main.quds': '''
use pipeline.batch

total = await sum_batch([1, 2, 3, 4])
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('total'), equals(100));
    });

    test(
        '17. Cross-file custom exception throw/catch across 3 module boundaries',
        () async {
      final ws = QudsWorkspace(
        name: 'exceptions_multi',
        files: {
          'core/errors.quds': '''
class DomainError:
  code: String
  detail: String
''',
          'math/validate.quds': '''
use ^.core.errors

safe_sqrt_arg(x: double) -> double:
  if x < 0.0:
    throw DomainError("NEG_INPUT", "Input must be non-negative")
  return x
''',
          'sim/driver.quds': '''
use ^.math.validate

run_checked(x: double) -> double:
  return safe_sqrt_arg(x) + 1.0
''',
          'main.quds': '''
use core.errors
use sim.driver

var caught_code = ""
try:
  bad = run_checked(-5.0)
catch e:
  if e is DomainError:
    caught_code = (e as DomainError).code
  else:
    caught_code = "OTHER"

good = run_checked(9.0)
''',
        },
      );

      final session = QudsSession(projectWorkspace: ws);
      addTearDown(session.dispose);

      final res = await session.runProject();
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(session.getVariable('caught_code'), equals('NEG_INPUT'));
      expect(session.getVariable('good'), closeTo(10.0, 1e-9));
    });

    test(
        '18. Live file rename, delete, and switching attached workspaces cleanly',
        () async {
      final ws1 = QudsWorkspace(
        name: 'project_one',
        files: {
          'math/old_kernel.quds': 'const FACTOR = 7\n',
          'main.quds': 'use math.old_kernel\nans = FACTOR * 2\n',
        },
      );

      final session = QudsSession(projectWorkspace: ws1);
      addTearDown(session.dispose);

      final r1 = await session.runProject();
      expect(r1.succeeded, isTrue, reason: '${r1.error}');
      expect(session.getVariable('ans'), equals(14));

      // Rename file -> stale import fails cleanly with E900
      ws1.renameFile('math/old_kernel.quds', 'math/new_kernel.quds');
      final rStale = await session.runProject();
      expect(rStale.succeeded, isFalse);
      expect((rStale.error as QudsRuntimeException).code, equals('E900'));

      // Update main.quds to new name -> succeeds immediately!
      ws1.writeFile('main.quds', 'use math.new_kernel\nans = FACTOR * 3\n');
      final rRenamed = await session.runProject();
      expect(rRenamed.succeeded, isTrue, reason: '${rRenamed.error}');
      expect(session.getVariable('ans'), equals(21));

      // Attach a completely different workspace with same relative module path -> zero stale cache leak!
      final ws2 = QudsWorkspace(
        name: 'project_two',
        files: {
          'math/new_kernel.quds': 'const FACTOR = 100\n',
          'main.quds': 'use math.new_kernel\nans = FACTOR * 3\n',
        },
      );
      session.attachWorkspace(ws2);
      final rSwitched = await session.runProject();
      expect(rSwitched.succeeded, isTrue, reason: '${rSwitched.error}');
      expect(session.getVariable('ans'), equals(300));
    });
  });
}
