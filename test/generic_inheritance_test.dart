import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

const declarations = '''
class Base<T>:
  var value: T required
  read() -> T = value
class Child<U> extends Base<List<U>>:
  tag: String required
''';

void main() {
  test('generic inheritance conformance executes in Quds', () async {
    for (final entry in {
      'generic_inheritance.quds': 11,
      'generic_inheritance_prefix.quds': 2
    }.entries) {
      final result = await Process.run(Platform.resolvedExecutable,
          ['run', 'bin/quds.dart', 'test', 'test/${entry.key}']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect('${result.stdout}'.split('\n').where((s) => s.startsWith('ok ')),
          hasLength(entry.value));
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  final invalid = <String, String>{
    'main():\n  print Child<int>(value: "bad", tag: "x")': 'E500',
    'main():\n  values: List<num> = [1]\n  print Child<int>(value: values, tag: "x")':
        'E500',
    'main():\n  value = Child<int>(value: [1], tag: "x")\n  value.value = ["bad"]':
        'E300',
    'main():\n  value = Child<int>(value: [1], tag: "x")\n  value.value = [1.5]':
        'E300',
    'class Bad extends Base<int, String>:\n  tag: String required': 'E300',
    'class NumberBase<T: num>:\n  value: T required\nclass Bad extends NumberBase<String>:\n  tag: String required':
        'E300',
    'class NumberBase<T: num>:\n  value: T required\nclass Bad<U> extends NumberBase<U>:\n  tag: String required':
        'E300',
    'class Bad<U> extends Base<List<U>>:\n  read() -> String = "bad"': 'E300',
    'class ArgumentBase<T>:\n  accept(value: T) -> T = value\nclass Bad<U> extends ArgumentBase<List<U>>:\n  accept(value: String) -> List<U> = []':
        'E300',
    'class Bad<U> extends Base<List<U>>:\n  static read() -> List<U> = []':
        'E300',
    'class ReadonlyBase<T>:\n  value: T required\n  readonly read() -> T = value\nclass Bad<U> extends ReadonlyBase<List<U>>:\n  read() -> List<U> = value':
        'E300',
    'class DefaultBase<T>:\n  accept(value: int = 1) -> int = value\nclass Bad<U> extends DefaultBase<U>:\n  accept(value: int) -> int = value':
        'E300',
    'class CycleA<T> extends CycleB<T>:\n  a: int = 1\nclass CycleB<U> extends CycleA<U>:\n  b: int = 2':
        'E700',
    'final class FinalBase<T>:\n  value: T required\nclass Bad<U> extends FinalBase<U>:\n  tag: String required':
        'E720',
    'class Bad<U> extends Base<U>:\n  init(this.value):\n    require true':
        'E704',
    'class Bad<U> extends Base<U>:\n  init():\n    require true': 'E704',
    'class Bad<U> extends Base<U>:\n  extra: int = 0\n  init(super.value, super.extra):\n    require true':
        'E200',
    'class ExplicitBase<T>:\n  value: T required\n  init(this.value):\n    require true\nclass Unsupported<U> extends ExplicitBase<U>:\n  tag: String required':
        'E910',
    'class Unsupported extends Base:\n  tag: String required': 'E910',
    'class NamedBase<T>:\n  value: T required\n  init named(this.value):\n    require true\nclass Bad<U> extends NamedBase<U>:\n  init(super.value):\n    require true':
        'E700',
  };
  for (final entry in invalid.entries) {
    test('rejects unsafe inherited types: ${entry.key}', () {
      expect(() => compile('$declarations${entry.key}\n'),
          throwsA(predicate((e) => '$e'.contains(entry.value))));
    });
  }

  final foreign = <String, String>{
    'main():\n  value = Child<int>(secret: [1], shared: [2])\n  print value.secret':
        'E206',
    'main():\n  value = Child<int>(secret: [1], shared: [2])\n  value.secret = [3]':
        'E206',
    'main():\n  value = Child<int>(secret: [1], shared: [2])\n  print value.shared':
        'E207',
    'main():\n  value = Child<int>(secret: [1], shared: [2])\n  value.shared = [3]':
        'E207',
    'class Bad<U> extends foreign.LibraryBase<List<U>>:\n  leak() -> List<U> = secret':
        'E206',
  };
  for (final entry in foreign.entries) {
    test('inherited visibility survives library prefixes: ${entry.key}', () {
      expect(
          () => compile(
              'use "generic_inheritance_library.quds" as foreign\n'
              'class Child<U> extends foreign.LibraryBase<List<U>>:\n  tag: String = "x"\n${entry.key}\n',
              file: 'test/inherited_invalid.quds'),
          throwsA(predicate((e) => '$e'.contains(entry.value))));
    });
  }

  test('override diagnostics retain original Quds spans', () {
    try {
      compile(
          'class Base<T>:\n  read() -> int = 1\nclass Bad<U> extends Base<U>:\n  read() -> String = "bad"\n',
          file: 'override.quds');
      fail('Expected a diagnostic');
    } on CompilerException catch (error) {
      expect(error.code, 'E300');
      expect(error.span.file, 'override.quds');
      expect(error.span.line, 4);
      expect(error.span.column, 3);
    }
  });

  test('generic constructors and private writes execute on VM and JavaScript',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-inheritance-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/generic_inheritance_web.quds');
    final source = input.readAsStringSync();
    final generated = compile(source, file: input.path).dart;
    expect(generated, compile(source, file: input.path).dart);
    expect(generated,
        File('test/goldens/generic_inheritance.dart.txt').readAsStringSync());
    final output = File('${directory.path}/program.dart')
      ..writeAsStringSync(generated);
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', output.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, contains('GENERIC INHERITANCE OK'));
    final js = '${directory.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final run = await Process.run('node', [js]);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, contains('GENERIC INHERITANCE OK'));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
