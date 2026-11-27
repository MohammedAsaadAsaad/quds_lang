import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('Phase 3 — Execution Policy, Sandboxing, Capabilities & Host Bridge',
      () {
    test(
        'maxSteps halts infinite loops with accurate span and cannot be caught by user try/catch',
        () async {
      final session = QudsSession(
        policy: QudsExecutionPolicy.strictSandbox(maxSteps: 200),
      );
      final res = await session.run('''
var count = 0
try:
  while true:
    count += 1
catch e:
  print "should-never-catch"
''', file: 'loop.quds');

      expect(res.succeeded, isFalse);
      expect(res.printedLines, isEmpty);
      expect(res.error, isA<QudsPolicyViolationException>());
      final violation = res.error as QudsPolicyViolationException;
      expect(violation.kind, QudsPolicyViolationKind.stepLimit);
      expect(violation.span.file, 'loop.quds');
      expect(violation.span.line, greaterThanOrEqualTo(3));
    });

    test(
        'maxCallDepth, maxCollectionLength, and maxLoopIterations enforce resource boundaries',
        () async {
      // Call depth
      final depthSession = QudsSession(
        policy: QudsExecutionPolicy.strictSandbox(maxCallDepth: 12),
      );
      final depthRes = await depthSession.run('''
recurse(n: int) -> int = recurse(n + 1)
recurse(0)
''');
      expect(depthRes.succeeded, isFalse);
      expect((depthRes.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.callDepth);

      // Collection size
      final collSession = QudsSession(
        policy: QudsExecutionPolicy.strictSandbox(maxCollectionLength: 5),
      );
      final collRes = await collSession.run('''
var items: List<int> = []
for i in 1..10:
  items.add(i)
''');
      expect(collRes.succeeded, isFalse);
      expect((collRes.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.collectionLimit);

      // Loop iterations
      final loopSession = QudsSession(
        policy: QudsExecutionPolicy.strictSandbox(maxLoopIterations: 4),
      );
      final loopRes = await loopSession.run('''
var s = 0
for i in 1..20:
  s += i
''');
      expect(loopRes.succeeded, isFalse);
      expect((loopRes.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.loopLimit);
    });

    test(
        'strictSandbox blocks disallowed libraries, async, and optional allowMutation: false',
        () async {
      final sandbox = QudsSession(policy: QudsExecutionPolicy.strictSandbox());

      final deniedLib = await sandbox.run('use quds:async');
      expect(deniedLib.succeeded, isFalse);
      expect((deniedLib.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.libraryDenied);

      final deniedAsync = await sandbox.run('''
work() async -> int = 1
''');
      expect(deniedAsync.succeeded, isFalse);
      expect((deniedAsync.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.featureDisabled);

      // Pure formula mode: immutable-only!
      final formulaOnly = QudsSession(
        policy: QudsExecutionPolicy.strictSandbox(allowMutation: false),
      );
      final okPure = await formulaOnly.run('''
use quds:math
x = sin(pi / 2) + 10
print x
''');
      expect(okPure.succeeded, isTrue, reason: '${okPure.error}');
      expect(okPure.printedLines, ['11.0']);

      final badMut = await formulaOnly.run('var x = 1');
      expect(badMut.succeeded, isFalse);
      expect((badMut.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.featureDisabled);
    });

    test(
        'systemBridge capability gating, dynamic permission callback, and call interceptor',
        () async {
      final auditLog = <String>[];

      final fsModule = QudsHostModule.builder(
        'host:fs',
        description: 'Scoped virtual filesystem bridge.',
      )
          .function(
            'readText',
            (pos, named, ctx) => 'CONTENT(${pos[0]})',
            capability: 'fs.read',
            signature: 'readText(path: String) -> String',
          )
          .function(
            'deleteFile',
            (pos, named, ctx) => 'DELETED(${pos[0]})',
            capability: 'fs.delete',
            signature: 'deleteFile(path: String) -> String',
          )
          .build();

      final session = QudsSession(
        policy: QudsExecutionPolicy.systemBridge(
          capabilities: [
            QudsCapability.fileRead(allowedRoots: ['/workspace/data/']),
          ],
          onPermissionCheck: (req) {
            if (req.capability == 'fs.read') {
              final path = '${req.positionalArguments.first}';
              final roots =
                  (req.grantedScope?['allowedRoots'] as List?) ?? const [];
              final inside = roots.any((r) => path.startsWith('$r'));
              return inside
                  ? const QudsPermissionDecision.allow()
                  : QudsPermissionDecision.deny(
                      'Path `$path` is outside allowed root');
            }
            return const QudsPermissionDecision.allow();
          },
          onCallIntercept: (event) {
            auditLog.add(event.functionName);
            if (event.functionName == 'blockedFn') {
              return const QudsInterceptDecision.deny(
                  'blocked by audit policy');
            }
            return const QudsInterceptDecision.allow();
          },
        ),
        hostModules: [fsModule],
      );

      // 1. Authorized path succeeds
      final ok = await session.run('''
use host:fs as fs
data = fs.readText("/workspace/data/sensor.csv")
print data
''');
      expect(ok.succeeded, isTrue, reason: '${ok.error}');
      expect(ok.printedLines, ['CONTENT(/workspace/data/sensor.csv)']);
      expect(auditLog, contains('host:fs::readText'));

      // 2. Unauthorized path denied by dynamic onPermissionCheck
      final deniedPath = await session.run('''
use host:fs as fs
fs.readText("/etc/passwd")
''');
      expect(deniedPath.succeeded, isFalse);
      final pathErr = deniedPath.error as QudsPolicyViolationException;
      expect(pathErr.kind, QudsPolicyViolationKind.permissionDenied);
      expect(pathErr.message, contains('/etc/passwd'));

      // 3. Ungranted capability denied before calling host callback
      final deniedCap = await session.run('''
use host:fs as fs
fs.deleteFile("/workspace/data/sensor.csv")
''');
      expect(deniedCap.succeeded, isFalse);
      expect((deniedCap.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.permissionDenied);

      // 4. Dynamic call interceptor blocks specific user function
      final blockedCall = await session.run('''
blockedFn() -> int = 42
blockedFn()
''');
      expect(blockedCall.succeeded, isFalse);
      expect((blockedCall.error as QudsPolicyViolationException).kind,
          QudsPolicyViolationKind.interceptDenied);
    });

    test('custom importResolver provides virtual Quds libraries dynamically',
        () async {
      final session = QudsSession(
        policy: QudsExecutionPolicy.scientific(
          allowedLibraries: {'quds:math', 'lab:physics'},
          importResolver: (uri) {
            if (uri == 'lab:physics') {
              return const QudsImportProvideSource('''
const g = 9.81
potentialEnergy(mass: double, height: double) -> double = mass * g * height
''');
            }
            return const QudsImportAllow();
          },
        ),
      );
      final res = await session.run('''
use lab:physics
print potentialEnergy(2.0, 10.0).toStringAsFixed(1)
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.printedLines, ['196.2']);
    });
  });
}
