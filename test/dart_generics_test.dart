import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  for (final suite in ['dart_generics', 'dart_generics_prefix']) {
    test('native generic Quds conformance $suite', () async {
      final result = await Process.run(Platform.resolvedExecutable,
          ['run', 'bin/quds.dart', 'test', 'test/$suite.quds']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect('${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
          hasLength(suite == 'dart_generics' ? 7 : 1));
    });
  }
  final cases = <String, String>{
    'nativeIdentity<int>("wrong")': 'E300',
    'NativeField<int>("wrong")': 'E300',
    'NativeParent.read()': 'E300',
    'NativeAbstract<int>()': 'E300',
    'nativeRecord()': 'E910',
    'nativeGenericCallback((value: int) -> value)': 'E910',
    'nativeOptionalCallback((value: int) -> value)': 'E300',
    'saved = nativeIdentity': 'E910',
    'saved = NativeChild<int>([1]).identity': 'E910',
    'nativeBounded<String>("wrong")': 'E300',
    'nativeIdentity<int, String>(1)': 'E300',
    'nativeIdentity<int>()': 'E500',
    'nativeNamed<int>(other: 1)': 'E500',
    'nativeNamed<int>(value: "wrong")': 'E300',
    'NativeNumbers<String>("wrong")': 'E300',
    'NativeChild<int>(["wrong"])': 'E300',
    'NativeChild<int>([1]).bounded<String>("wrong")': 'E300',
    'NativeChild<int>([1]).identity<int>("wrong")': 'E300',
  };
  for (final entry in cases.entries) {
    test('native generics reject ${entry.key}', () {
      try {
        compile(
            'use "fixtures/dart_generics/api.dart"\nmain():\n  ${entry.key}\n',
            file: 'test/native_reject.quds');
        fail('Expected ${entry.value}');
      } on CompilerException catch (e) {
        expect(e.code, entry.value, reason: '$e');
        expect(e.span.file, 'test/native_reject.quds');
        expect(e.span.line, 3);
      }
    });
  }
  test('a same-named Quds class cannot impersonate a native generic class', () {
    expect(() => compile('''use "fixtures/dart_generics/api.dart" as native
class NativeField<T>:
  value: T required
main():
  print native.nativeFieldValue(NativeField<int>(value: 1))
''', file: 'test/native_identity.quds'),
        throwsA(predicate((e) => '$e'.contains('E300'))));
  });
  test('native generic Dart output analyzes and runs on VM and JS', () async {
    final dir = Directory.systemTemp.createTempSync('quds-dart-generics-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final input = File('test/dart_generics_web.quds');
    final compilation = compile(input.readAsStringSync(), file: input.path);
    expect(compilation.dart,
        compile(input.readAsStringSync(), file: input.path).dart);
    String normalizeNativePrefixes(String source) {
      final ids = <String, String>{};
      return source
          .replaceAll(Directory.current.absolute.uri.toString(), '<repo>/')
          .replaceAllMapped(RegExp(r'_qNative[0-9a-f]{12}'), (m) {
        final key = m.group(0)!;
        return ids.putIfAbsent(key, () => '_qNative<${ids.length}>');
      });
    }

    final golden = File('test/goldens/dart_generics.dart.txt');
    expect(
        normalizeNativePrefixes(compilation.dart),
        normalizeNativePrefixes(
            golden.readAsStringSync().replaceAll('\r\n', '\n')));
    final output = File('${dir.path}/program.dart')
      ..writeAsStringSync(compilation.dart.replaceAll(
          "import 'fixtures/dart_generics/api.dart'",
          "import '${File('test/fixtures/dart_generics/api.dart').absolute.uri}'"));
    writeSdkBundles(dir.path, compilation);
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', output.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'DART GENERICS OK\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', output.path, '-o', '${dir.path}/program.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      '${dir.path}/program.js'
    ]);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect(js.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
