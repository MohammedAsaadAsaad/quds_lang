import 'dart:convert';
import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  final cli = File('bin/quds.dart').absolute.path;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('quds-export-cast-');
    Directory('${directory.path}/src').createSync();
    File('${directory.path}/pubspec.yaml').writeAsStringSync(
        'name: cast_repro\nenvironment:\n  sdk: ">=3.13.0 <4.0.0"\n');
    for (final path in ['main.quds', 'src/some.quds']) {
      File('${directory.path}/$path').writeAsStringSync(
          File('test/fixtures/export_cast/$path').readAsStringSync());
    }
  });
  tearDown(() => directory.deleteSync(recursive: true));
  Future<ProcessResult> command(String verb) =>
      Process.run(Platform.resolvedExecutable, [cli, verb, 'main.quds'],
          workingDirectory: directory.path);
  void successful(ProcessResult result) {
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, 'test_lang_quds\nInstance of \'Fraction\'\n');
  }

  test('Quds re-export conformance', () async {
    final result = await Process.run(
        Platform.resolvedExecutable, [cli, 'test', 'test/export_cast.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout,
        contains('ok local module exports SDK types and conversions'));
  });
  test('fresh run builds dependencies and shares SDK and exception identities',
      () async {
    successful(await command('run'));
    final root = '${directory.path}/.dart_tool/quds/out';
    expect(File('$root/src/some.dart').existsSync(), isTrue);
    expect(File('$root/quds_math.dart').existsSync(), isTrue);
    expect(File('$root/src/quds_math.dart').existsSync(), isFalse);
    final nested = File('$root/src/some.dart').readAsStringSync();
    expect(nested, contains("export '../quds_math.dart'"));
    expect(File('$root/quds_math.dart').readAsStringSync(),
        contains("import 'quds_readonly.dart'"));
    expect(File('$root/main.dart').readAsStringSync(),
        contains("import 'quds_readonly.dart'"));
    final analyze = await Process.run(Platform.resolvedExecutable,
        ['analyze', '$root/main.dart', '$root/src/some.dart']);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('warm run repairs missing or damaged generated dependencies and bundles',
      () async {
    successful(await command('run'));
    final root = '${directory.path}/.dart_tool/quds/out';
    final main = File('$root/main.dart');
    final timestamp = main.lastModifiedSync();
    for (final artifact in [
      'src/some.dart',
      'src/some.dart.map',
      'quds_math.dart',
      'quds_readonly.dart'
    ]) {
      File('$root/$artifact').deleteSync();
      successful(await command('run'));
      expect(File('$root/$artifact').existsSync(), isTrue);
      expect(main.lastModifiedSync(), timestamp,
          reason: 'A valid cached entry need not be regenerated');
    }
    File('$root/quds_math.dart')
        .writeAsStringSync('// interrupted or damaged output\n');
    successful(await command('run'));
    expect(File('$root/quds_math.dart').readAsStringSync(),
        contains('class Fraction'));
  }, timeout: const Timeout(Duration(minutes: 2)));
  test(
      'rebuilding a dependency revalidates callers against a changed SDK artifact',
      () async {
    successful(await command('run'));
    final root = '${directory.path}/.dart_tool/quds/out';
    final main = File('$root/main.dart'), sdk = File('$root/quds_math.dart');
    final original = main.readAsStringSync();
    final helper = RegExp(r'_qCast\w+\.(\$QudsCast[a-f0-9]+)')
        .firstMatch(original)!
        .group(1)!;
    final legacy = r'$Legacy' + helper.substring(1);
    final legacyMain = original.replaceAll(helper, legacy);
    final legacySdk = sdk.readAsStringSync().replaceAll(helper, legacy);
    main.writeAsStringSync(legacyMain);
    sdk.writeAsStringSync(legacySdk);
    // Model a self-consistent older generated bundle and its cached caller.
    final key = sha256Hex(
        utf8.encode(File('${directory.path}/main.quds').absolute.path));
    final cache = File('${directory.path}/.dart_tool/quds/cache/$key.json');
    final saved = jsonDecode(cache.readAsStringSync()) as Map;
    saved['output'] = sha256Hex(utf8.encode(legacyMain));
    (saved['artifacts'] as Map)[sdk.absolute.path] =
        sha256Hex(utf8.encode(legacySdk));
    cache.writeAsStringSync(jsonEncode(saved));
    final validLegacy =
        await Process.run(Platform.resolvedExecutable, [main.path]);
    successful(validLegacy);
    File('$root/src/some.dart').deleteSync();
    successful(await command('run'));
    expect(main.readAsStringSync(), isNot(contains(legacy)));
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('run reports errors in dependency bodies before starting the entry',
      () async {
    successful(await command('run'));
    final dependency = File('${directory.path}/src/some.quds');
    dependency.writeAsStringSync(
        '${dependency.readAsStringSync()}\nbroken() -> int = unknownValue\n');
    final failed = await command('run');
    expect(failed.exitCode, 65);
    expect(failed.stdout, isEmpty);
    expect(failed.stderr, contains('some.quds'));
    expect(failed.stderr, contains('E200'));
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('explicit custom cast does not replace the implicit SDK conversion', () {
    final main = File('${directory.path}/main.quds');
    final result = compile(main.readAsStringSync(), file: main.path);
    expect(result.semantics.implicitConversions.values.single.library,
        'quds:math');
    main.writeAsStringSync(
        'use src.some\nmain():\n  f = 1 to Fraction\n  print f\n');
    expect(
        () => compile(main.readAsStringSync(), file: main.path),
        throwsA(
            isA<CompilerException>().having((e) => e.code, 'code', 'E310')));
  });
  test('fresh debug launch builds the same nested graph and Quds breakpoint',
      () async {
    final result = await Process.run('node', [
      'test/editor/export_debug.cjs',
      Platform.resolvedExecutable,
      cli,
      '${directory.path}/main.quds'
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('EXPORT DEBUG OK'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
