import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

const box = '''class Box:
  value: int required
  implicit cast(value: int) -> Box = Box(value: value)
''';
void main() {
  for (final suite in [
    'conversions',
    'conversions_import',
    'conversions_math',
    'conversions_external',
    'conversions_native',
    'conversions_parts',
    'augment_generic'
  ]) {
    test('Quds $suite conformance', () async {
      final result = await Process.run(Platform.resolvedExecutable,
          ['run', 'bin/quds.dart', 'test', 'test/$suite.quds']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(
          '${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
          hasLength(suite == 'conversions'
              ? 7
              : suite == 'conversions_import'
                  ? 2
                  : 1));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
  final negatives = <String, String>{
    'no conversion chains': '''$box
class Outer:
  value: Box required
  implicit cast(value: Box) -> Outer = Outer(value: value)
main():
  item: Outer = 1
''',
    'explicit is never implicit': '''class Box:
  value: int required
  explicit cast(value: int) -> Box = Box(value: value)
main():
  item: Box = 1
''',
    'to does not chain': '''$box
class Outer:
  value: Box required
  explicit cast(value: Box) -> Outer = Outer(value: value)
main():
  item = 1 to Outer
''',
    'const cannot run conversion': '''${box}main():
  const item: Box = 1
''',
    'explicit const conversion': '''${box}main():
  const item = 1 to Box
''',
    'readonly source cannot lose qualifier': '''class Box:
  value: List<int> required
  implicit cast(value: Box) -> int = value.value.length
main():
  item: readonly Box = Box(value: [1])
  number: int = item
''',
    'nullable source cannot lose qualifier': '''${box}main():
  item: int? = null
  converted: Box = item
''',
    'ambiguous declarations': '''$box
augment Box:
  implicit cast(value: int) -> Box = Box(value: value + 1)
main():
  item: Box = 1
''',
    'one endpoint must belong to owner': '''class Box:
  explicit cast(value: int) -> String = "wrong owner"
''',
    'identity cannot be replaced': '''class Box:
  explicit cast(value: Box) -> Box = value
''',
    'parameter arity': '''class Box:
  implicit cast(a: int, b: int) -> Box = Box()
''',
    'return annotation required': '''class Box:
  implicit cast(value: int) = Box()
''',
    'async is not a conversion': '''class Box:
  implicit cast(value: int) async -> Box = Box()
''',
    'conversion has no instance this': '''class Box:
  value: int = 1
  explicit cast(value: Box) -> int = this.value
''',
    'generic bound cannot be bypassed': '''class Box<T: num>:
  value: T required
  implicit cast(value: T) -> Box<T> = Box<T>(value: value)
main():
  item: Box<int> = "no"
''',
  };
  for (final entry in negatives.entries) {
    test('rejects ${entry.key}', () {
      expect(() => compile(entry.value), throwsA(isA<CompilerException>()));
    });
  }
  test('equally specific imported converters are ambiguous in Quds coordinates',
      () {
    final file = File('test/fixtures/conversions/ambiguous.quds').absolute;
    expect(
        () => compile(file.readAsStringSync(), file: file.path),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', 'E310')
            .having((e) => e.span.file, 'source file', file.path)
            .having((e) => e.span.line, 'source line', 5)));
  });
  test('duplicate unused converter declarations fail early', () {
    expect(
        () => compile(
            '${box}augment Box:\n  explicit cast(value: int) -> Box = Box(value: value)\n'),
        throwsA(
            isA<CompilerException>().having((e) => e.code, 'code', 'E201')));
  });
  test('as remains a runtime type check without conversion', () {
    final result = compile('${box}main():\n  item = 1 as Box\n  print item\n');
    expect(result.semantics.implicitConversions, isEmpty);
    expect(result.semantics.explicitConversions, isEmpty);
    expect(result.dart, contains('1 as Box'));
  });
  test('unannotated literals retain their original type', () {
    final result = compile('${box}main():\n  item = 1\n  print item\n');
    final main = result.program.statements
        .whereType<FunctionDeclaration>()
        .firstWhere((f) => f.name == 'main');
    final binding = main.body!.first as Binding;
    expect(result.semantics.declarations[binding]!.type, 'int');
    expect(result.semantics.implicitConversions, isEmpty);
  });
  test('conversion Dart golden is deterministic', () {
    const source =
        '${box}read(value: Box) -> int = value.value\nmain():\n  item: Box = 7\n  print read(8)\n  print item.value\n';
    final result = compile(source);
    expect(result.dart,
        File('test/goldens/conversions.dart.golden').readAsStringSync());
    expect(compile(source).dart, result.dart);
  });
  test('CLI keeps converter identities across relative and absolute builds',
      () async {
    final dir = Directory.systemTemp.createTempSync('quds-cast-cli-');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/pubspec.yaml').writeAsStringSync(
        'name: cast_cli\nenvironment:\n  sdk: ">=3.13.0 <4.0.0"\n');
    File('${dir.path}/provider.quds').writeAsStringSync(box);
    File('${dir.path}/main.quds').writeAsStringSync(
        'use "provider.quds" as types show Box\nmain():\n  item: types.Box = 7\n  print item.value\n');
    final cli = File('bin/quds.dart').absolute.path;
    for (final input in ['provider.quds', 'main.quds']) {
      final build = await Process.run(
          Platform.resolvedExecutable, [cli, 'build', input],
          workingDirectory: dir.path);
      expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    }
    final output = '${dir.path}/.dart_tool/quds/out/main.dart';
    final analyzer =
        await Process.run(Platform.resolvedExecutable, ['analyze', output]);
    expect(analyzer.exitCode, 0,
        reason: '${analyzer.stdout}\n${analyzer.stderr}');
    final execution = await Process.run(Platform.resolvedExecutable, [output]);
    expect(execution.exitCode, 0,
        reason: '${execution.stdout}\n${execution.stderr}');
    expect(execution.stdout, '7\n');
    expect(File('${dir.path}/provider.dart').existsSync(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
  test('SDK Fraction conversions execute on VM and JavaScript', () async {
    final source = File('test/conversions_math.quds')
        .readAsStringSync()
        .replaceFirst(
            'test "SDK integer and Fraction conversions are exact":', 'main():')
        .replaceAll('expect(', 'checkEqual(');
    final result = compile(source.replaceFirst('main():',
        'checkEqual(actual: dynamic, expected: dynamic):\n  check actual == expected\nmain():'));
    final dir = Directory.systemTemp.createTempSync('quds-fraction-casts-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/program.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(dir.path, result);
    final analyzer = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', file.path]);
    expect(analyzer.exitCode, 0,
        reason: '${analyzer.stdout}\n${analyzer.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [file.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', file.path, '-o', '${dir.path}/program.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', ['${dir.path}/program.js']);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect(js.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('conversions execute on VM and JavaScript with Dart analysis', () async {
    final source =
        File('test/conversions.quds').readAsStringSync().split('test "').first +
            '''main():
  item: Ratio = 7
  check item.numerator == 7
  check readRatio(8) == 8
  check returnRatio().numerator == 8
  check choose(1) == "int"
  check choose(item) == "ratio"
  check (item + 2).numerator == 9
  check item to int == 7
  half = Ratio(numerator: 1, denominator: 2)
  check (half to? int) == null
  print "CONVERSIONS OK"
''';
    final result = compile(source);
    final dir = Directory.systemTemp.createTempSync('quds-casts-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/program.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(dir.path, result);
    final analyzer = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', file.path]);
    expect(analyzer.exitCode, 0,
        reason: '${analyzer.stdout}\n${analyzer.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [file.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'CONVERSIONS OK\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', file.path, '-o', '${dir.path}/program.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', ['${dir.path}/program.js']);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect(js.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
      'custom primitive-to-primitive implicit and explicit casts execute on VM and JS',
      () async {
    const source = '''
augment String:
  implicit cast(source: int) -> String:
    return "n:{source}"

augment int:
  explicit cast(source: String) -> int:
    if source == "seven":
      return 7
    throw ConversionError("not seven")

takeText(text: String) -> String = text

main():
  var a: String = ""
  a = 7
  b: String = 42
  c = takeText(9)
  d = 5 to String
  e = "seven" to int
  f = "nope" to? int
  print "{a}|{b}|{c}|{d}|{e}|{f}"
''';
    final result = compile(source);
    final dir = Directory.systemTemp.createTempSync('quds-prim-casts-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/program.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(dir.path, result);
    final analyzer = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', file.path]);
    expect(analyzer.exitCode, 0,
        reason: '${analyzer.stdout}\n${analyzer.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [file.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'n:7|n:42|n:9|n:5|7|null\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', file.path, '-o', '${dir.path}/program.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', ['${dir.path}/program.js']);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect(js.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
