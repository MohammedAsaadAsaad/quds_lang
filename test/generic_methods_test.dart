import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

const prelude = '''
interface Transformer:
  transform<T>(value: T) -> T = value
class Identity implements Transformer:
  transform<U>(value: U) -> U = value
interface Numeric:
  keep<T: num>(value: T) -> T = value
class NumericIdentity implements Numeric:
  keep<U: num>(value: U) -> U = value
''';

void main() {
  test('generic method conformance executes in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/generic_methods.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect('${result.stdout}'.split('\n').where((s) => s.startsWith('ok ')),
        hasLength(16));
  }, timeout: const Timeout(Duration(minutes: 3)));

  final invalid = <String, String>{
    'class Bad:\n  keep<T: T>(value: T) -> T = value': 'E300',
    'class Bad:\n  keep<T: U, U: T>(value: T) -> T = value': 'E300',
    'class Bad implements Transformer:\n  transform(value: int) -> int = value':
        'E700',
    'class Bad implements Transformer:\n  transform<T, U>(value: T) -> T = value':
        'E700',
    'class Bad implements Transformer:\n  transform<T>(value: int) -> T:\n    throw "bad"':
        'E700',
    'class Bad implements Transformer:\n  transform<T>(value: T) -> int = 1':
        'E700',
    'class Bad implements Transformer:\n  transform<T: num>(value: T) -> T = value':
        'E700',
    'class Bad implements Numeric:\n  keep<T: int>(value: T) -> T = value':
        'E700',
    'class Bad implements Numeric:\n  keep<T>(value: T) -> T = value': 'E700',
    'class Bad implements Transformer:\n  static transform<T>(value: T) -> T = value':
        'E700',
    'interface Two:\n  choose<T, U>(first: T, second: U) -> T = first\nclass Bad implements Two:\n  choose<A, B>(first: A, second: B) -> B = second':
        'E700',
    'interface ConcreteReturn:\n  make<T>(value: T) -> Object:\n    throw "abstract"\nclass Bad implements ConcreteReturn:\n  make<U>(value: U) -> U = value':
        'E700',
    'interface WithDefault:\n  keep<T>(value: T, count: int = 1) -> T = value\nclass Bad implements WithDefault:\n  keep<U>(value: U, count: int) -> U = value':
        'E700',
    'main():\n  print Identity().transform<int, String>(1)': 'E300',
    'main():\n  print Identity().transform<Unknown>(1)': 'E910',
    'main():\n  print Identity().transform<int>("bad")': 'E500',
    'main():\n  print NumericIdentity().keep<String>("bad")': 'E300',
    'main():\n  print NumericIdentity().keep("bad")': 'E500',
    'main():\n  print NumericIdentity().keep<int?>(null)': 'E300',
    'class Outer<C>:\n  keep<T: C>(value: T) -> C = value\nmain():\n  print Outer<int>().keep<double>(1.5)':
        'E300',
    'class Outer<C>:\n  keep<T: C>(value: T) -> C = value\nmain():\n  print Outer<int>().keep("bad")':
        'E500',
    'class Parent:\n  transform<T>(value: T) -> T = value\nclass Bad extends Parent:\n  transform<U: num>(value: U) -> U = value':
        'E300',
    'class Parent:\n  transform<T>(value: T) -> T = value\nclass Bad extends Parent:\n  transform<U>(value: U) -> int = 1':
        'E300',
    'unsafe<T>(value: T) -> Object = value': 'E300',
    'unsafe<T, U>(value: T) -> U = value': 'E300',
    'class Optional:\n  keep<T>(value: T?) -> T? = value\nmain():\n  value: int = Optional().keep<int>(null)':
        'E300',
  };
  for (final entry in invalid.entries) {
    test('rejects an unsafe generic method: ${entry.key}', () {
      expect(() => compile('$prelude${entry.key}\n'),
          throwsA(predicate((e) => '$e'.contains(entry.value))));
    });
  }

  test('method contract failures keep the implementing Quds span', () {
    try {
      compile(
          'interface Identity:\n  keep<T>(value: T) -> T = value\nclass Bad implements Identity:\n  keep<U>(value: U) -> int = 1\n',
          file: 'method.quds');
      fail('Expected a diagnostic');
    } on CompilerException catch (error) {
      expect(error.code, 'E700');
      expect(error.span.file, 'method.quds');
      expect(error.span.line, 3);
      expect(error.span.column, 1);
    }
  });

  test('generic methods execute on Dart VM and JavaScript with stable output',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-method-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/generic_methods_web.quds');
    final source = input.readAsStringSync();
    final generated = compile(source, file: input.path).dart;
    expect(generated, compile(source, file: input.path).dart);
    expect(generated,
        File('test/goldens/generic_methods.dart.txt').readAsStringSync());
    final output = File('${directory.path}/program.dart')
      ..writeAsStringSync(generated);
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', output.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, contains('GENERIC METHODS OK'));
    final js = '${directory.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final run = await Process.run('node', [js]);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, contains('GENERIC METHODS OK'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
