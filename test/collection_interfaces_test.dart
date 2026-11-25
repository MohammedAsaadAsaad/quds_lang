import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

const prelude = '''
lookup<K, V>(values: Map<K, V>, key: K) -> V? = values[key]
identity<T>(value: T) -> T = value
choose<T>(left: T, right: T) -> T = left
class Holder<T>:
  value: T required
interface Container<T>:
  value: T
interface Reader<T>:
  read(value: T) -> T = value
interface Writable<T>:
  property value: T:
    get:
      throw "abstract"
    set(value):
      throw "abstract"
''';

void main() {
  test('collection and interface conformance executes in Quds', () async {
    for (final entry in {
      'collection_inference.quds': 16,
      'generic_interfaces.quds': 6
    }.entries) {
      final result = await Process.run(Platform.resolvedExecutable,
          ['run', 'bin/quds.dart', 'test', 'test/${entry.key}']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect('${result.stdout}'.split('\n').where((s) => s.startsWith('ok ')),
          hasLength(entry.value));
    }
  }, timeout: const Timeout(Duration(minutes: 4)));

  final invalid = <String, String>{
    'class Bad implements Container<int>:\n  property value: int:\n    set(value):\n      print value':
        'E700',
    'interface CallbackContainer:\n  value: () -> int\nclass Bad implements CallbackContainer:\n  value() -> int = 1':
        'E700',
    'main():\n  values = map:\n    "x": 1\n  print lookup(values, 2)': 'E500',
    'main():\n  values = map:\n    "x": 1\n  value: String? = lookup(values, "x")':
        'E500',
    'main():\n  values: Map<String, int>? = null\n  print lookup(values, "x")':
        'E500',
    'main():\n  values: Map<String, int?> = map:\n    "x": null\n  value: int = lookup(values, "x")':
        'E300',
    'main():\n  value = identity([])': 'E302',
    'take<T>(values: List<T>) -> T = values[0]\nmain():\n  print take([])':
        'E302',
    'main():\n  integers = [1]\n  broad: List<num> = identity(integers)':
        'E500',
    'main():\n  integers = [1]\n  broad: List<num> = [2.5]\n  print choose(integers, broad)':
        'E500',
    'main():\n  values = map:\n    "x": 1\n  broad: Map<String, num> = identity(values)':
        'E500',
    'main():\n  original = [1]\n  nested: Map<String, List<num>> = map:\n    "x": original':
        'E300',
    'main():\n  print choose(1, "bad")': 'E500',
    'class Bad implements Container<int>:\n  value: String required': 'E700',
    'class Bad implements Container<int>:\n  other: int required': 'E700',
    'class Bad implements Container<int>:\n  static var value: int = 1': 'E700',
    'class Bad implements Container<int, String>:\n  value: int required':
        'E300',
    'class Bad implements Reader<int>:\n  other: int required': 'E700',
    'class Bad implements Reader<int>:\n  read(value: String) -> int = 1':
        'E700',
    'class Bad implements Reader<int>:\n  read(value: int) -> String = "bad"':
        'E700',
    'class Bad implements Writable<int>:\n  value: int required': 'E700',
    'class Bad implements Writable<num>:\n  var value: int = 0': 'E700',
    'class Good implements Container<int>:\n  value: int required\naccept(value: Container<String>) -> int = 1\nmain():\n  print accept(Good(value: 1))':
        'E500',
    'interface CycleA extends CycleB:\n  x: int\ninterface CycleB extends CycleA:\n  y: int':
        'E700',
    'interface NamedReader extends Reader<int>:\n  name: String\nclass Bad implements NamedReader:\n  name: String required':
        'E700',
    'class Good implements Writable<int>:\n  var value: int = 0\nalter(value: Writable<int>):\n  value.value /= 2':
        'E300',
  };
  for (final entry in invalid.entries) {
    test('rejects unsafe inference or contract: ${entry.key}', () {
      expect(() => compile('$prelude${entry.key}\n'),
          throwsA(predicate((e) => '$e'.contains(entry.value))));
    });
  }

  test('interface mismatch retains the implementing Quds span', () {
    try {
      compile(
          'interface Container<T>:\n  value: T\nclass Bad implements Container<int>:\n  value: String required\n',
          file: 'contracts.quds');
      fail('Expected a diagnostic');
    } on CompilerException catch (error) {
      expect(error.code, 'E700');
      expect(error.span.file, 'contracts.quds');
      expect(error.span.line, 3);
      expect(error.span.column, 1);
    }
  });

  test('inferred arguments and interface calls execute on VM and JavaScript',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-collections-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/collection_interfaces_web.quds');
    final source = input.readAsStringSync();
    final compilation = compile(source, file: input.path);
    final generated = compilation.dart;
    expect(generated, compile(source, file: input.path).dart);
    expect(generated,
        File('test/goldens/collection_interfaces.dart.txt').readAsStringSync());
    final output = File('${directory.path}/program.dart')
      ..writeAsStringSync(generated);
    writeSdkBundles(directory.path, compilation);
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', output.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, contains('COLLECTION INTERFACES OK'));
    final js = '${directory.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final run = await Process.run('node', [js]);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, contains('COLLECTION INTERFACES OK'));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
