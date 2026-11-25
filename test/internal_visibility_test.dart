import 'dart:io';

import 'package:quds/quds.dart';
import 'package:quds/src/complete.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

Future<void> _pubGet(String directory, {required String pubCache}) async {
  final offline = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get', '--offline'],
    workingDirectory: directory,
    environment: {...Platform.environment, 'PUB_CACHE': pubCache},
  );
  if (offline.exitCode == 0) return;
  final online = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get'],
    workingDirectory: directory,
    environment: {...Platform.environment, 'PUB_CACHE': pubCache},
  );
  expect(online.exitCode, 0,
      reason: 'dart pub get failed:\n${online.stdout}\n${online.stderr}');
}

Directory _createPaymentsPackage(Directory parent) {
  final pkg = Directory('${parent.path}/payments')..createSync(recursive: true);
  Directory('${pkg.path}/lib').createSync(recursive: true);
  Directory('${pkg.path}/bin').createSync(recursive: true);
  Directory('${pkg.path}/test').createSync(recursive: true);

  File('${pkg.path}/pubspec.yaml').writeAsStringSync('''
name: payments
version: 0.1.0
environment:
  sdk: ^3.0.0
''');

  File('${pkg.path}/lib/payments.quds').writeAsStringSync('''
internal signPayload(raw: String) -> String = "sig:{raw}"

internal class InternalToken:
  value: String

internal enum InternalMode:
  sandbox
  live

internal type SecretId = int

internal extend String InternalStrExt:
  tag() -> String = "[{this}]"

class Gateway:
  internal apiKey: String = "k-123"
  internal static var buildVersion: int = 2
  internal: bool = true

  internal property debugTag: String:
    get = "gw:{apiKey}"

  internal reset() -> String = "reset:{apiKey}"

  charge(amount: int) -> String = signPayload("amt={amount}")
''');

  File('${pkg.path}/test/payments_test.quds').writeAsStringSync('''
use package:payments

test "same-package files access all internal declarations and members":
  expect(signPayload("ok"), equals("sig:ok"))
  tok = InternalToken(value: "t1")
  expect(tok.value, equals("t1"))
  mode = InternalMode.live
  expect(mode == InternalMode.live, isTrue)
  id: SecretId = 99
  expect(id, equals(99))
  expect("hi".tag(), equals("[hi]"))
  gw = Gateway()
  expect(gw.apiKey, equals("k-123"))
  expect(Gateway.buildVersion, equals(2))
  expect(gw.debugTag, equals("gw:k-123"))
  expect(gw.reset(), equals("reset:k-123"))
  expect(gw.internal, isTrue)
  expect(gw.charge(50), equals("sig:amt=50"))
''');

  return pkg;
}

void main() {
  test(
      'internal symbols and members work across files inside the owning package and fail with E209 outside',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-internal-sym-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final pubCache = Directory('${sandbox.path}/pub_cache')..createSync();

    final payments = _createPaymentsPackage(sandbox);

    // 1. Same-package test passes via quds test
    final samePkgTest = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'test', 'test/payments_test.quds'],
      workingDirectory: payments.path,
    );
    expect(samePkgTest.exitCode, 0,
        reason: '${samePkgTest.stdout}\n${samePkgTest.stderr}');

    // 2. Consumer package app
    final app = Directory('${sandbox.path}/app')..createSync();
    Directory('${app.path}/bin').createSync();
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: app
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  payments:
    path: ../payments
''');
    await _pubGet(app.path, pubCache: pubCache.path);

    // Public API works AND consumer can define its own signPayload without colliding!
    final okFile = File('${app.path}/bin/ok.quds')..writeAsStringSync('''
use package:payments

signPayload(x: String) -> String = "local:{x}"

main():
  gw = Gateway()
  print gw.charge(10)
  print gw.internal
  print signPayload("ok")
''');
    final okRun = await Process.run(
      Platform.resolvedExecutable,
      [_qudsBin, 'run', okFile.path],
      workingDirectory: app.path,
    );
    expect(okRun.exitCode, 0, reason: '${okRun.stdout}\n${okRun.stderr}');
    expect(okRun.stdout, 'sig:amt=10\ntrue\nlocal:ok\n');

    // Every cross-package internal access must fail with E209.
    final forbidden = <String, String>{
      'show internal function': '''
use package:payments show signPayload
main():
  print 1
''',
      'direct internal function call': '''
use package:payments
main():
  print signPayload("bad")
''',
      'prefixed internal function call': '''
use package:payments as p
main():
  print p.signPayload("bad")
''',
      'internal class constructor': '''
use package:payments
main():
  t = InternalToken(value: "bad")
  print t
''',
      'internal enum access': '''
use package:payments as p
main():
  print p.InternalMode.live
''',
      'internal field read': '''
use package:payments
main():
  gw = Gateway()
  print gw.apiKey
''',
      'internal property read': '''
use package:payments
main():
  gw = Gateway()
  print gw.debugTag
''',
      'internal method call': '''
use package:payments
main():
  gw = Gateway()
  print gw.reset()
''',
      'internal static field read': '''
use package:payments
main():
  print Gateway.buildVersion
''',
    };

    for (final entry in forbidden.entries) {
      final probe = File('${app.path}/bin/probe.quds')
        ..writeAsStringSync(entry.value);
      expect(
        () => compile(entry.value, file: probe.path),
        throwsA(predicate((e) => '$e'.contains('E209'))),
        reason: 'Expected E209 for: ${entry.key}',
      );
    }

    // 3. LSP completion hides internal members outside the package and shows them inside
    List<String> memberLabels(String file, String source) {
      final lines = source.split('\n');
      final items = completeAt(
        source: source,
        line: lines.length - 2,
        character: lines[lines.length - 2].length,
        file: file,
        compileSource: (text) {
          try {
            return compile(text, file: file);
          } catch (_) {
            return null;
          }
        },
      );
      return [for (final item in items) item['label'] as String];
    }

    const probeCompletion = '''
use package:payments
main():
  gw = Gateway()
  gw.
''';
    final insideLabels =
        memberLabels('${payments.path}/bin/probe.quds', probeCompletion);
    expect(insideLabels,
        containsAll(['charge', 'internal', 'apiKey', 'debugTag', 'reset']));

    final outsideLabels =
        memberLabels('${app.path}/bin/comp.quds', probeCompletion);
    expect(outsideLabels, containsAll(['charge', 'internal']));
    expect(outsideLabels, isNot(contains('apiKey')));
    expect(outsideLabels, isNot(contains('debugTag')));
    expect(outsideLabels, isNot(contains('reset')));
  }, timeout: const Timeout.factor(3));

  test(
      'internal emits /// internal by default and @internal when package:meta is a dependency',
      () {
    final sandbox = Directory.systemTemp.createTempSync('quds-internal-meta-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    File('${sandbox.path}/pubspec.yaml').writeAsStringSync('''
name: demo
dependencies:
  meta: ^1.15.0
''');
    const source = '''
internal helper() -> int = 1
internal class Secret:
  internal count: int = 0
''';
    final noMeta = compile(source).dart;
    expect(noMeta, contains('/// internal'));
    expect(noMeta, isNot(contains('@internal')));

    final withMeta =
        compile(source, file: '${sandbox.path}/lib/demo.quds').dart;
    expect(withMeta, contains("import 'package:meta/meta.dart';"));
    expect(withMeta, contains('@internal'));
  });
}
