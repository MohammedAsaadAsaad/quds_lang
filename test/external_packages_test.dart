import 'dart:convert';
import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/complete.dart';
import 'package:quds_lang/src/navigate.dart';
import 'package:test/test.dart';

String get _qudsBin => '${Directory.current.path}/bin/quds.dart';

Future<ProcessResult> _runQuds(List<String> args,
    {required String workingDirectory, Map<String, String>? environment}) {
  return Process.run(
    Platform.resolvedExecutable,
    [_qudsBin, ...args],
    workingDirectory: workingDirectory,
    environment: environment,
  );
}

Future<void> _pubGet(String directory, {required String pubCache}) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get', '--offline'],
    workingDirectory: directory,
    environment: {...Platform.environment, 'PUB_CACHE': pubCache},
  );
  if (result.exitCode == 0) return;
  final online = await Process.run(
    Platform.resolvedExecutable,
    ['pub', 'get'],
    workingDirectory: directory,
    environment: {...Platform.environment, 'PUB_CACHE': pubCache},
  );
  expect(online.exitCode, 0,
      reason: 'dart pub get failed:\n${online.stdout}\n${online.stderr}');
}

Future<void> _gitInitCommit(String directory) async {
  for (final args in [
    ['init'],
    ['config', 'user.email', 'test@quds.dev'],
    ['config', 'user.name', 'Quds Test'],
    ['add', '.'],
    ['commit', '-m', 'Initial Quds package'],
  ]) {
    final result = await Process.run('git', args, workingDirectory: directory);
    expect(result.exitCode, 0,
        reason:
            'git ${args.join(' ')} failed:\n${result.stdout}\n${result.stderr}');
  }
}

Directory _createGreeterPackage(Directory parent, {String name = 'greeter'}) {
  final pkg = Directory('${parent.path}/$name')..createSync(recursive: true);
  Directory('${pkg.path}/lib/src').createSync(recursive: true);
  Directory('${pkg.path}/lib/internal').createSync(recursive: true);
  Directory('${pkg.path}/bin').createSync(recursive: true);
  Directory('${pkg.path}/test').createSync(recursive: true);

  File('${pkg.path}/pubspec.yaml').writeAsStringSync('''
name: $name
version: 0.1.0
environment:
  sdk: ^3.0.0
''');

  File('${pkg.path}/lib/src/secret.quds').writeAsStringSync('''
class Badge:
  label: String

secretTag() -> String = "INTERNAL"
''');

  File('${pkg.path}/lib/internal/helper.quds').writeAsStringSync('''
formatBang(text: String) -> String = "{text}!"
''');

  File('${pkg.path}/lib/extras.quds').writeAsStringSync('''
shout(text: String) -> String = text.toUpperCase()
''');

  File('${pkg.path}/lib/$name.quds').writeAsStringSync('''
use quds:text
use package:$name/src/secret
use package:$name/internal/helper
export package:$name/src/secret show Badge

:: greet
greet(who: String) -> String:
  clean = who.trim().capitalized()
  return formatBang("Hello, {clean}")

makeBadge(name: String) -> Badge = Badge(label: "{secretTag()}:{name}")

extend String GreeterExt:
  cheer() -> String = formatBang(this.trim().capitalized())

:: formal
salute(who: String) -> String = "Greetings, {who.trim()}."
''');

  File('${pkg.path}/bin/check_internal.quds').writeAsStringSync('''
use package:$name/src/secret
use package:$name/internal/helper

main():
  print formatBang(secretTag())
''');

  File('${pkg.path}/test/${name}_test.quds').writeAsStringSync('''
use package:$name
use package:$name/src/secret
use package:$name/internal/helper

test "same-package tests can access lib/src and lib/internal":
  expect(secretTag(), equals("INTERNAL"))
  expect(formatBang("ok"), equals("ok!"))
  expect(greet("  ada "), equals("Hello, Ada!"))
  expect(makeBadge("dev").label, equals("INTERNAL:dev"))
''');

  return pkg;
}

void main() {
  test(
      'pure-Quds GitHub-style git package works across run, build, test, analyze, VM and JS without mutating pub-cache',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-ext-git-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final pubCache = Directory('${sandbox.path}/pub_cache')..createSync();

    final greeter = _createGreeterPackage(sandbox);
    await _gitInitCommit(greeter.path);

    // Same-package test and bin inside greeter can access lib/src and lib/internal.
    final pkgTest = await _runQuds(
      ['test', 'test/greeter_test.quds'],
      workingDirectory: greeter.path,
    );
    expect(pkgTest.exitCode, 0, reason: '${pkgTest.stdout}\n${pkgTest.stderr}');

    final pkgBin = await _runQuds(
      ['run', 'bin/check_internal.quds'],
      workingDirectory: greeter.path,
    );
    expect(pkgBin.exitCode, 0, reason: '${pkgBin.stdout}\n${pkgBin.stderr}');
    expect(pkgBin.stdout, 'INTERNAL!\n');

    // Consumer app depends on greeter via a real Git URL (same mechanism as GitHub).
    final app = Directory('${sandbox.path}/app')..createSync();
    Directory('${app.path}/bin').createSync();
    Directory('${app.path}/test').createSync();
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: app
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  greeter:
    git:
      url: ${Uri.directory(greeter.path)}
''');
    await _pubGet(app.path, pubCache: pubCache.path);

    File('${app.path}/bin/main.quds').writeAsStringSync('''
use package:greeter::greet
use package:greeter as g
use package:greeter/extras

main():
  print greet("  quds ")
  print "  world ".cheer()
  print g.salute("Ada")
  badge = makeBadge("v1")
  print badge.label
  print shout("ok")
''');

    File('${app.path}/test/app_test.quds').writeAsStringSync('''
use package:greeter

test "external Quds package functions, extensions, and re-exported classes work":
  expect(greet("  quds "), equals("Hello, Quds!"))
  expect("  hi ".cheer(), equals("Hi!"))
  expect(salute("Ada"), equals("Greetings, Ada."))
  expect(makeBadge("ok").label, equals("INTERNAL:ok"))
''');

    // Snapshot pub_cache files before building/running consumer app.
    List<String> listDartFiles(Directory dir) => dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.path)
        .toList()
      ..sort();
    expect(listDartFiles(pubCache), isEmpty);

    // 1. quds run
    final run =
        await _runQuds(['run', 'bin/main.quds'], workingDirectory: app.path);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(
      run.stdout,
      'Hello, Quds!\nWorld!\nGreetings, Ada.\nINTERNAL:v1\nOK\n',
    );

    // 2. quds build
    final build =
        await _runQuds(['build', 'bin/main.quds'], workingDirectory: app.path);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final builtMain = File('${app.path}/.dart_tool/quds/out/bin/main.dart');
    final builtPkg =
        File('${app.path}/.dart_tool/quds/out/_packages/greeter/greeter.dart');
    expect(builtMain.existsSync(), isTrue);
    expect(builtPkg.existsSync(), isTrue);
    // Pub cache must remain completely untouched (read-only safe).
    expect(listDartFiles(pubCache), isEmpty);

    // 3. quds analyze
    final analyze = await _runQuds(['analyze', 'bin/main.quds'],
        workingDirectory: app.path);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');

    // 4. quds test
    final appTest = await _runQuds(['test', 'test/app_test.quds'],
        workingDirectory: app.path);
    expect(appTest.exitCode, 0, reason: '${appTest.stdout}\n${appTest.stderr}');

    // 5. JS parity via dart compile js + node
    final jsOut = '${sandbox.path}/main.js';
    final jsCompile = await Process.run(
      Platform.resolvedExecutable,
      ['compile', 'js', '-o', jsOut, builtMain.path],
      workingDirectory: app.path,
    );
    expect(jsCompile.exitCode, 0,
        reason: '${jsCompile.stdout}\n${jsCompile.stderr}');
    final nodeRun = await Process.run('node', [jsOut]);
    expect(nodeRun.exitCode, 0, reason: '${nodeRun.stdout}\n${nodeRun.stderr}');
    expect(nodeRun.stdout, run.stdout);
  }, timeout: const Timeout.factor(4));

  test(
      'transitive external Quds packages (app -> mid -> leaf) resolve via consumer package_config',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-ext-trans-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final pubCache = Directory('${sandbox.path}/pub_cache')..createSync();

    final leaf = Directory('${sandbox.path}/pkg_leaf')..createSync();
    Directory('${leaf.path}/lib/src').createSync(recursive: true);
    File('${leaf.path}/pubspec.yaml').writeAsStringSync('''
name: pkg_leaf
version: 0.1.0
environment:
  sdk: ^3.0.0
''');
    File('${leaf.path}/lib/src/base.quds').writeAsStringSync('''
class LeafToken:
  value: String
''');
    File('${leaf.path}/lib/pkg_leaf.quds').writeAsStringSync('''
use package:pkg_leaf/src/base
export package:pkg_leaf/src/base show LeafToken

leafMake(text: String) -> LeafToken = LeafToken(value: "leaf:{text}")
''');

    final mid = Directory('${sandbox.path}/pkg_mid')..createSync();
    Directory('${mid.path}/lib').createSync();
    File('${mid.path}/pubspec.yaml').writeAsStringSync('''
name: pkg_mid
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  pkg_leaf:
    path: ../pkg_leaf
''');
    File('${mid.path}/lib/pkg_mid.quds').writeAsStringSync('''
use package:pkg_leaf
export package:pkg_leaf show LeafToken

midWrap(text: String) -> LeafToken:
  t = leafMake(text)
  return LeafToken(value: "mid({t.value})")
''');

    // Note: pkg_mid intentionally has NO .dart_tool/package_config.json!
    expect(File('${mid.path}/.dart_tool/package_config.json').existsSync(),
        isFalse);

    final app = Directory('${sandbox.path}/app')..createSync();
    Directory('${app.path}/bin').createSync();
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: app
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  pkg_mid:
    path: ../pkg_mid
''');
    await _pubGet(app.path, pubCache: pubCache.path);

    File('${app.path}/bin/main.quds').writeAsStringSync('''
use package:pkg_mid

main():
  token = midWrap("ok")
  print token.value
''');

    final run =
        await _runQuds(['run', 'bin/main.quds'], workingDirectory: app.path);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, 'mid(leaf:ok)\n');

    final analyze = await _runQuds(['analyze', 'bin/main.quds'],
        workingDirectory: app.path);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
  });

  test(
      'package-internal libraries under lib/src and lib/internal are rejected with E208 from outside the package',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-ext-internal-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final pubCache = Directory('${sandbox.path}/pub_cache')..createSync();

    _createGreeterPackage(sandbox);

    final app = Directory('${sandbox.path}/app')..createSync();
    Directory('${app.path}/bin').createSync();
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: app
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  greeter:
    path: ../greeter
''');
    await _pubGet(app.path, pubCache: pubCache.path);

    final forbidden = [
      'use package:greeter/src/secret',
      'use package:greeter.src.secret',
      'use package:greeter/src/secret.quds',
      'use package:greeter/src/secret.dart',
      'use package:greeter/internal/helper',
      'use package:greeter.internal.helper',
      'export package:greeter/src/secret',
      'export package:greeter/internal/helper',
      'use ../../greeter/lib/src/secret.quds',
      'use ../../greeter/lib/internal/helper.quds',
    ];

    for (final directive in forbidden) {
      final probe = File('${app.path}/bin/probe.quds');
      final source = '$directive\nmain():\n  print 1\n';
      probe.writeAsStringSync(source);
      expect(
        () => compile(source, file: probe.path),
        throwsA(predicate((e) => '$e'.contains('E208'))),
        reason: 'Expected E208 for: $directive',
      );
    }

    // Re-exporting a public facade that itself imports lib/src is allowed.
    final allowed = File('${app.path}/bin/ok.quds');
    const okSource = '''
use package:greeter
main():
  print makeBadge("ok").label
''';
    allowed.writeAsStringSync(okSource);
    expect(() => compile(okSource, file: allowed.path), returnsNormally);

    // Transitive illegal re-export: a middle package cannot export another package's lib/src.
    final badMid = Directory('${sandbox.path}/bad_mid')..createSync();
    Directory('${badMid.path}/lib').createSync();
    File('${badMid.path}/pubspec.yaml').writeAsStringSync('''
name: bad_mid
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  greeter:
    path: ../greeter
''');
    File('${badMid.path}/lib/bad_mid.quds')
        .writeAsStringSync('export package:greeter/src/secret\n');
    final badApp = Directory('${sandbox.path}/bad_app')..createSync();
    Directory('${badApp.path}/bin').createSync();
    File('${badApp.path}/pubspec.yaml').writeAsStringSync('''
name: bad_app
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  bad_mid:
    path: ../bad_mid
''');
    await _pubGet(badApp.path, pubCache: pubCache.path);
    final badEntry = File('${badApp.path}/bin/main.quds');
    const badSource = 'use package:bad_mid\nmain():\n  print 1\n';
    badEntry.writeAsStringSync(badSource);
    expect(
      () => compile(badSource, file: badEntry.path),
      throwsA(predicate((e) => '$e'.contains('E208'))),
    );
  });

  test(
      'quds build --package generates lib/*.dart for dual Quds+Dart publishing and refuses to overwrite hand-written Dart',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-build-pkg-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final pubCache = Directory('${sandbox.path}/pub_cache')..createSync();

    final greeter = _createGreeterPackage(sandbox);

    final buildPkg = await _runQuds(['build', '--package', greeter.path],
        workingDirectory: sandbox.path);
    expect(buildPkg.exitCode, 0,
        reason: '${buildPkg.stdout}\n${buildPkg.stderr}');

    expect(File('${greeter.path}/lib/greeter.dart').existsSync(), isTrue);
    expect(File('${greeter.path}/lib/src/secret.dart').existsSync(), isTrue);
    expect(
        File('${greeter.path}/lib/internal/helper.dart').existsSync(), isTrue);
    expect(
        File('${greeter.path}/lib/src/_quds_sdk/quds_text.dart').existsSync(),
        isTrue);

    // Running --package again reports Unchanged.
    final buildAgain = await _runQuds(['build', '--package', greeter.path],
        workingDirectory: sandbox.path);
    expect(buildAgain.exitCode, 0,
        reason: '${buildAgain.stdout}\n${buildAgain.stderr}');
    expect(buildAgain.stdout, contains('Unchanged'));

    // Plain Dart package can now directly import package:greeter/greeter.dart!
    final dartConsumer = Directory('${sandbox.path}/dart_app')..createSync();
    Directory('${dartConsumer.path}/bin').createSync();
    File('${dartConsumer.path}/pubspec.yaml').writeAsStringSync('''
name: dart_app
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  greeter:
    path: ../greeter
''');
    await _pubGet(dartConsumer.path, pubCache: pubCache.path);
    File('${dartConsumer.path}/bin/main.dart').writeAsStringSync('''
import 'package:greeter/greeter.dart';

void main() {
  print(greet('  dart '));
  print(makeBadge('dual').label);
}
''');
    final dartRun = await Process.run(
      Platform.resolvedExecutable,
      ['run', 'bin/main.dart'],
      workingDirectory: dartConsumer.path,
    );
    expect(dartRun.exitCode, 0, reason: '${dartRun.stdout}\n${dartRun.stderr}');
    expect(dartRun.stdout, 'Hello, Dart!\nINTERNAL:dual\n');

    // Hand-written Dart file is never overwritten.
    File('${greeter.path}/lib/manual.quds')
        .writeAsStringSync('val() -> int = 1\n');
    final manualDart = File('${greeter.path}/lib/manual.dart')
      ..writeAsStringSync('// hand-written dart\nint manual() => 99;\n');
    final refused = await _runQuds(['build', '--package', greeter.path],
        workingDirectory: sandbox.path);
    expect(refused.exitCode, 73);
    expect(refused.stderr, contains('Refusing to overwrite non-generated'));
    expect(manualDart.readAsStringSync(), contains('hand-written dart'));
  }, timeout: const Timeout.factor(2));

  test(
      'LSP completion and go-to-definition support external Quds packages and hide external internal folders',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-ext-lsp-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final pubCache = Directory('${sandbox.path}/pub_cache')..createSync();

    final greeter = _createGreeterPackage(sandbox);
    final app = Directory('${sandbox.path}/app')..createSync();
    Directory('${app.path}/bin').createSync();
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: app
version: 0.1.0
environment:
  sdk: ^3.0.0
dependencies:
  greeter:
    path: ../greeter
''');
    await _pubGet(app.path, pubCache: pubCache.path);

    final appMain = File('${app.path}/bin/main.quds');
    List<String> labels(String source, String file) {
      final lines = source.split('\n');
      final items = completeAt(
        source: source,
        line: lines.length - 1,
        character: lines.last.length,
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

    // 1. Package list includes greeter and greeter:: (because lib/greeter.quds has sections)
    final pkgs = labels('use package:', appMain.path);
    expect(pkgs, containsAll(['greeter', 'greeter::']));

    // 2. Section completion on external Quds package
    final sections = labels('use package:greeter::', appMain.path);
    expect(sections, containsAll(['greet', 'formal']));

    // 3. External package folder completion shows public .quds and hides src/ & internal/
    final slashEntries = labels('use package:greeter/', appMain.path);
    expect(slashEntries, containsAll(['greeter', 'greeter::', 'extras']));
    expect(slashEntries, isNot(contains('src')));
    expect(slashEntries, isNot(contains('internal')));

    final dottedEntries = labels('use package:greeter.', appMain.path);
    expect(dottedEntries, containsAll(['greeter', 'greeter::', 'extras']));
    expect(dottedEntries, isNot(contains('src')));
    expect(dottedEntries, isNot(contains('internal')));

    // Manually typing package:greeter/src/ still hides forbidden .quds files.
    expect(labels('use package:greeter/src/', appMain.path), isEmpty);
    expect(labels('use package:greeter/internal/', appMain.path), isEmpty);

    // Inside greeter itself, src/ and internal/ ARE shown.
    final selfEntries = labels(
        'use package:greeter/', '${greeter.path}/bin/check_internal.quds');
    expect(selfEntries, containsAll(['src', 'internal', 'greeter']));

    // 4. libraryAt opens external lib/greeter.quds
    final place = libraryAt('use package:greeter\n', 1, 8, from: appMain.path);
    expect(place, isNotNull);
    expect(
      File(place!.file).resolveSymbolicLinksSync(),
      File('${greeter.path}/lib/greeter.quds').resolveSymbolicLinksSync(),
    );

    // 5. definitionAt jumps to greet in external lib/greeter.quds
    const appSource = 'use package:greeter\nmain():\n  print greet("Ada")\n';
    appMain.writeAsStringSync(appSource);
    final compiled = compile(appSource, file: appMain.path);
    final def = definitionAt(
      compiled,
      3,
      10,
      sourceOf: (path) =>
          File(path).existsSync() ? File(path).readAsStringSync() : null,
    );
    expect(def, isNotNull);
    expect(
      File(def!.file).resolveSymbolicLinksSync(),
      File('${greeter.path}/lib/greeter.quds').resolveSymbolicLinksSync(),
    );
    expect(
      utf8.decode(File(def.file).readAsBytesSync()).split('\n')[def.line - 1],
      contains('greet(who: String)'),
    );
  });

  test(
      'barrel re-exports, diamond sealed types, imported SDK defaults, List.sort comparator, and nullable List<Base>? work together',
      () async {
    final sandbox = Directory.systemTemp.createTempSync('quds-ext-ledger-reg-');
    addTearDown(() => sandbox.deleteSync(recursive: true));

    final pkg = Directory('${sandbox.path}/kit')..createSync();
    Directory('${pkg.path}/lib/src').createSync(recursive: true);
    File('${pkg.path}/pubspec.yaml').writeAsStringSync(
        'name: kit\nenvironment:\n  sdk: ">=3.13.0 <4.0.0"\n');
    File('${pkg.path}/lib/src/math_money.quds').writeAsStringSync('''
use quds:math::number show Fraction, fraction

class Coin:
  amount: Fraction required

makeCoin(cents: int, scale: int = 100) -> Coin:
  return Coin(amount: fraction(cents, scale))
''');
    File('${pkg.path}/lib/src/status.quds').writeAsStringSync('''
use package:kit/src/math_money

sealed type Health:
  Good(note: String)
  Warn(note: String)

class Item:
  val: int required
  status: Health required
''');
    File('${pkg.path}/lib/src/ops.quds').writeAsStringSync('''
use package:kit/src/math_money
use package:kit/src/status

sortDesc(items: List<Item>) -> List<int>:
  items.sort((a: Item, b: Item) -> b.val.compareTo(a.val))
  return [it.val for it in items]

coinLabel(cents: int) -> String:
  c = makeCoin(cents, scale: 100)
  return "{c.amount.numerator}/{c.amount.denominator}"
''');
    File('${pkg.path}/lib/kit.quds').writeAsStringSync('''
export package:kit/src/math_money
export package:kit/src/status
export package:kit/src/ops
''');

    final app = Directory('${sandbox.path}/app')..createSync();
    Directory('${app.path}/bin').createSync(recursive: true);
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: app
environment:
  sdk: ">=3.13.0 <4.0.0"
dependencies:
  kit:
    path: ../kit
''');
    final pubCache = Directory('${sandbox.path}/pub_cache')..createSync();
    await _pubGet(app.path, pubCache: pubCache.path);
    File('${app.path}/bin/main.quds').writeAsStringSync('''
use package:kit

class Base:
  id: int required

class Sub extends Base:
  tag: String required

acceptOptional(items: List<Base>? = null) -> int:
  return items?.length ?? 0

main():
  c = makeCoin(50, scale: 100)
  items = [Item(val: 1, status: Good(note: "ok")), Item(val: 5, status: Warn(note: "hi"))]
  ordered = sortDesc(items)
  count = acceptOptional(items: [Base(id: 1), Sub(id: 2, tag: "s")])
  print "{c.amount.numerator}/{c.amount.denominator}|{coinLabel(25)}|{ordered}|{count}"
''');

    final run =
        await _runQuds(['run', 'bin/main.quds'], workingDirectory: app.path);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, '1/2|1/4|[5, 1]|2\n');
  }, timeout: const Timeout.factor(4));

  test(
      'external Dart setters, void generic top bounds, callable fields, and cross-package package: backend URIs',
      () async {
    final sandbox =
        Directory.systemTemp.createTempSync('quds-ext-interop-reg-');
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final pubCache = Directory('${sandbox.path}/pub_cache')..createSync();

    final dartLib = Directory('${sandbox.path}/native_box')..createSync();
    Directory('${dartLib.path}/lib').createSync(recursive: true);
    File('${dartLib.path}/pubspec.yaml').writeAsStringSync(
        'name: native_box\nenvironment:\n  sdk: ">=3.13.0 <4.0.0"\n');
    File('${dartLib.path}/lib/native_box.dart').writeAsStringSync('''
class Box {
  int _value = 0;
  int get value => _value;
  set value(int v) => _value = v;
  String label = 'init';
  int get readOnly => _value;
}

T runTyped<T>(T Function() body) => body();
''');

    final qudsPkg = Directory('${sandbox.path}/models_pkg')..createSync();
    Directory('${qudsPkg.path}/lib/src').createSync(recursive: true);
    File('${qudsPkg.path}/pubspec.yaml').writeAsStringSync(
        'name: models_pkg\nenvironment:\n  sdk: ">=3.13.0 <4.0.0"\n');
    File('${qudsPkg.path}/lib/src/tag.quds').writeAsStringSync('''
sealed type Tag:
  OkTag(label: String)
  WarnTag(label: String)
''');
    File('${qudsPkg.path}/lib/models_pkg.quds').writeAsStringSync('''
export package:models_pkg/src/tag
''');

    final app = Directory('${sandbox.path}/app')..createSync();
    Directory('${app.path}/lib/src').createSync(recursive: true);
    Directory('${app.path}/bin').createSync(recursive: true);
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: app
environment:
  sdk: ">=3.13.0 <4.0.0"
dependencies:
  native_box:
    path: ../native_box
  models_pkg:
    path: ../models_pkg
''');
    await _pubGet(qudsPkg.path, pubCache: pubCache.path);
    await _pubGet(app.path, pubCache: pubCache.path);

    File('${app.path}/lib/src/consumer.quds').writeAsStringSync('''
use package:native_box/native_box.dart
use package:models_pkg

class Runner:
  onDone: () -> void required

  fire() -> void:
    onDone()

describeTag(tag: Tag) -> String:
  return match tag:
    OkTag(label: text): "ok:{text}"
    WarnTag(label: text): "warn:{text}"

exercise() -> String:
  box = Box()
  box.value = 42
  box.label = "ready"
  var called = 0
  inc = () -> :
    called = called + 1
  runner = Runner(onDone: inc)
  runner.onDone()
  runner.fire()
  bump = () -> :
    called = called + 10
  runTyped<void>(bump)
  return "{box.value}|{box.label}|{called}|{describeTag(OkTag(label: 'go'))}"
''');

    // Build both packages with --package and verify package: backend URI (no broken ../..).
    final buildModels = await _runQuds(['build', '--package', qudsPkg.path],
        workingDirectory: sandbox.path);
    expect(buildModels.exitCode, 0,
        reason: '${buildModels.stdout}\n${buildModels.stderr}');
    final buildApp = await _runQuds(['build', '--package', app.path],
        workingDirectory: sandbox.path);
    expect(buildApp.exitCode, 0,
        reason: '${buildApp.stdout}\n${buildApp.stderr}');

    final generated =
        File('${app.path}/lib/src/consumer.dart').readAsStringSync();
    expect(generated, isNot(contains('../models_pkg/')));

    // Verify read-only Dart getter assignment is rejected.
    final badFile = File('${app.path}/bin/bad.quds');
    const badSource = '''
use package:native_box/native_box.dart

main():
  b = Box()
  b.readOnly = 1
''';
    badFile.writeAsStringSync(badSource);
    expect(
      () => compile(badSource, file: badFile.path),
      throwsA(predicate((e) => '$e'.contains('read-only'))),
    );

    // Execute generated Dart directly via `dart run` to verify end-to-end runtime.
    File('${app.path}/bin/run.dart').writeAsStringSync('''
import 'package:app/src/consumer.dart';

void main() {
  print(exercise());
}
''');
    final dartRun = await Process.run(
      Platform.resolvedExecutable,
      ['run', 'bin/run.dart'],
      workingDirectory: app.path,
    );
    expect(dartRun.exitCode, 0, reason: '${dartRun.stdout}\n${dartRun.stderr}');
    expect(dartRun.stdout, '42|ready|12|ok:go\n');
  }, timeout: const Timeout.factor(4));
}
