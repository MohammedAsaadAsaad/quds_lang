import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

const declarations = '''
class Box<T>:
  value: T required
class Numeric<T: num>:
  value: T required
class Pair<A, B: A>:
  first: A required
  second: B required
class Plain:
  value: int required
interface Named:
  name: String
class Person implements Named:
  name: String required
class Labelled<T: Named>:
  value: T required
consumeNamed(value: Named) -> int = 1
identity<T: num>(value: T) -> T = value
pick<A, B: A>(first: A, second: B) -> B = second
''';

void main() {
  test('generic constraints execute through Quds declarations', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/generic_constraints.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect('${result.stdout}'.split('\n').where((s) => s.startsWith('ok ')),
        hasLength(9));
  }, timeout: const Timeout(Duration(minutes: 3)));

  final invalid = <String, String>{
    'read(value: Box<int, String>) -> int = 1': 'E300',
    'read(value: Numeric<String>) -> int = 1': 'E300',
    'read(value: Labelled<Person?>) -> int = 1': 'E300',
    'main():\n  value: Person? = null\n  print consumeNamed(value)': 'E500',
    'read() -> Numeric<String> = null': 'E300',
    'class Invalid:\n  value: Numeric<String> required': 'E300',
    'type Invalid = Numeric<String>\nread(value: Invalid) -> int = 1': 'E300',
    'main():\n  value: Numeric<String> = null': 'E300',
    'main():\n  print Numeric<String>(value: "bad")': 'E300',
    'main():\n  print Box<int, String>(value: 1)': 'E300',
    'main():\n  print Plain<int>(value: 1)': 'E300',
    'main():\n  print Box<Unknown>(value: 1)': 'E910',
    'main():\n  print identity<Unknown>(1)': 'E910',
    'main():\n  print identity<String>("bad")': 'E300',
    'main():\n  print identity<int, int>(1)': 'E300',
    'main():\n  print identity<int?>(null)': 'E300',
    'main():\n  print Pair<int, String>(first: 1, second: "bad")': 'E300',
    'main():\n  print Pair(first: 1, second: "bad")': 'E300',
    'main():\n  print pick<int, String>(1, "bad")': 'E300',
    'invalid<T>(value: T) -> Numeric<T> = Numeric<T>(value: value)': 'E300',
    'class Outer<T: num>:\n  invalid<T>(value: T) -> Numeric<T> = null': 'E300',
    'main():\n  original: List<int> = [1]\n  widened: List<num> = original':
        'E300',
  };
  for (final entry in invalid.entries) {
    test('rejects invalid generic application: ${entry.key}', () {
      expect(() => compile('$declarations${entry.key}\n'),
          throwsA(predicate((e) => '$e'.contains(entry.value))));
    });
  }

  test('invalid bound reports the original Quds type declaration', () {
    try {
      compile(
          'class Numeric<T: num>:\n  value: T required\n'
          'read(value: Numeric<String>) -> int = 1\n',
          file: 'bounds.quds');
      fail('Expected a diagnostic');
    } on CompilerException catch (error) {
      expect(error.code, 'E300');
      expect(error.span.file, 'bounds.quds');
      expect(error.span.line, 3);
      expect(error.span.column, 6);
    }
  });

  test('bounded types preserve explicit arguments on Dart VM and JavaScript',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-generics-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/generic_constraints_web.quds');
    final source = input.readAsStringSync();
    final compilation = compile(source, file: input.path);
    final generated = compilation.dart;
    writeSdkBundles(directory.path, compilation);
    expect(generated, compile(source, file: input.path).dart);
    expect(generated,
        File('test/goldens/generic_constraints.dart.txt').readAsStringSync());
    final output = File('${directory.path}/program.dart')
      ..writeAsStringSync(generated);
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', output.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, contains('GENERIC CONSTRAINTS OK'));
    final js = '${directory.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final run = await Process.run('node', [js]);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, contains('GENERIC CONSTRAINTS OK'));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
