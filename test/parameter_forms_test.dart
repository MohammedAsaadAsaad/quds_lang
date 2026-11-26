import 'dart:io';
import 'dart:convert';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test(
      'Quds declarations preserve required named and optional positional forms',
      () async {
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/parameter_forms.quds']);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect('${run.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(15));
  });

  test('run rebuilds a v4 provider lacking parameter-form bridges', () async {
    final root = Directory.systemTemp.createTempSync('quds-parameter-upgrade-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: parameter_upgrade\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final provider = File('${root.path}/provider.quds')
      ..writeAsStringSync(
          'named(value: int required) -> int = value\noptional([value: int = 7]) -> int = value\n');
    final input = File('${root.path}/main.quds')
      ..writeAsStringSync(
          'use provider as api\nmain():\n  saved = api.named\n  print saved(value: 8)\n  optional = api.optional\n  print optional()\n  print optional == api.optional\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final output = File('${root.path}/.dart_tool/quds/out/provider.dart');
    final legacy = output
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.contains(r' $QudsDefault'))
        .join('\n');
    output.writeAsStringSync(legacy);
    final cache = Directory('${root.path}/.dart_tool/quds/cache');
    for (final file in cache.listSync().whereType<File>()) {
      final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      saved['abi'] = 'provider-defaults-v4';
      final paths = (saved['paths'] as List).cast<String>();
      if (paths.length == 1 && paths.single == provider.path) {
        saved['output'] = sha256Hex(utf8.encode(legacy));
      }
      file.writeAsStringSync(jsonEncode(saved));
    }
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', input.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, '8\n7\ntrue\n');
    expect(output.readAsStringSync(), contains(r' $QudsDefault'));
    for (final file in cache.listSync().whereType<File>()) {
      expect((jsonDecode(file.readAsStringSync()) as Map)['abi'],
          'provider-defaults-v16');
    }
  });

  test('imported computed constructor defaults stay in the provider', () async {
    final root =
        Directory.systemTemp.createTempSync('quds-constructor-boundary-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/provider.quds').writeAsStringSync(
        '_seed() -> int = 7\nclass Owner:\n  value: int\n  init([this.value: int = _seed()]):\n    require value >= 0\n');
    final file = File('${root.path}/main.quds')
      ..writeAsStringSync(
          'use provider as api\nmain():\n  print api.Owner().value\n  print api.Owner(4).value\n');
    final compiled = compile(file.readAsStringSync(), file: file.path);
    expect(compiled.dart, contains(r'$QudsCtor'));
    final provider = File('${root.path}/provider.quds');
    final implementation =
        compile(provider.readAsStringSync(), file: provider.path);
    expect(implementation.dart, contains(r'$QudsCtor'));
    expect(implementation.dart, contains('_q0()'));
    expect(compiled.dart, isNot(contains('_q0')));
    expect(compiled.dart, isNot(contains('_seed')));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(root.path, compiled);
    writeSdkBundles(root.path, implementation);
    final emitted = File('${root.path}/provider.dart')
      ..writeAsStringSync(relocateGeneratedLibraries(implementation, '').dart);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path, emitted.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect(vm.stdout, '7\n4\n');
  });

  test('synthesized constructors keep imported private parent defaults',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-parent-default-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/provider.quds').writeAsStringSync(
        '_seed() -> int = 7\nclass Parent:\n  value: int\n  init([this.value: int = _seed()]):\n    require value >= 0\n');
    final file = File('${root.path}/main.quds')..writeAsStringSync('''
use provider as api
class Child extends api.Parent:
  tag: String required
main():
  made = Child(tag: "ok")
  print made.value
  print made.tag
  print Child(value: 4, tag: "set").value
''');
    final compiled = compile(file.readAsStringSync(), file: file.path);
    expect(compiled.dart, contains(r'$QudsCtor'));
    expect(compiled.dart, isNot(contains('_seed')));
    expect(compiled.dart, isNot(contains('_q0()')));
    final provider = File('${root.path}/provider.quds');
    final implementation =
        compile(provider.readAsStringSync(), file: provider.path);
    expect(implementation.dart, contains(r'$QudsCtorSlots'));
    expect(implementation.dart, contains('_q0()'));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(root.path, compiled);
    writeSdkBundles(root.path, implementation);
    final emitted = File('${root.path}/provider.dart')
      ..writeAsStringSync(relocateGeneratedLibraries(implementation, '').dart);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path, emitted.path]);
    expect(analysis.exitCode, 0,
        reason:
            '${analysis.stdout}${analysis.stderr}\n${compiled.dart}\n${implementation.dart}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0,
        reason: '${vm.stdout}${vm.stderr}\n${compiled.dart}');
    expect(vm.stdout, '7\nok\n4\n');
  });

  final negative = <String, String>{
    'required positional': 'main():\n  api.named(1)\n',
    'required omitted': 'main():\n  api.named()\n',
    'unknown label': 'main():\n  api.named(other: 1)\n',
    'duplicate label': 'main():\n  api.named(value: 1, value: 2)\n',
    'required function value': 'main():\n  saved = api.named\n  saved(1)\n',
    'required callback shape': 'main():\n  saved: (int) -> int = api.named\n',
    'required constructor': 'main():\n  owner = api.Constructed(1)\n',
    'required generic constructor':
        'main():\n  owner = api.GenericConstructed<int>(1)\n',
    'nonnullable implicit null':
        'bad([value: int]) -> int = value\nmain():\n  print 1\n',
    'required default':
        'bad(value: int required = 1) -> int = value\nmain():\n  print 1\n',
    'required bracket':
        'bad([value: int required]) -> int = value\nmain():\n  print 1\n',
    'variadic default':
        'bad(...values: int = 1) -> int = values.length\nmain():\n  print 1\n',
    'variadic bracket':
        'bad([...values: int]) -> int = values.length\nmain():\n  print 1\n',
    'override kind':
        'class Parent:\n  read(value: int required) -> int = value\nclass Child extends Parent:\n  read(value: int) -> int = value\nmain():\n  print 1\n',
    'optional named positional':
        'bad(value: int = 1) -> int = value\nmain():\n  print bad(2)\n',
  };
  for (final entry in negative.entries) {
    test('parameter forms reject ${entry.key} at Quds coordinates', () {
      final file = File('test/parameter_bad.quds').absolute.path;
      expect(
          () => compile(
              'use fixtures.parameter_forms.provider as api\n${entry.value}',
              file: file),
          throwsA(isA<CompilerException>()
              .having((error) => error.span.file, 'source', file)));
    });
  }

  test('packet values and generic constructor defaults execute', () async {
    final provider =
        Directory.systemTemp.createTempSync('quds-packet-provider-');
    addTearDown(() => provider.deleteSync(recursive: true));
    File('${provider.path}/provider.quds').writeAsStringSync('''
_seed<T>() -> List<T> = []
class Box<T>:
  items: List<T>
  init([this.items: List<T> = _seed<T>()]):
    if items.length < 0:
      throw "empty"
''');
    final file = File('${provider.path}/main.quds');
    file.writeAsStringSync('''
use "provider.quds" as api
mixed([value: int = 1], amount: int required) -> int = value + amount
join(prefix: String = "x", ...items: int) -> String = "{prefix}:{items.length}"
tail([first: int = 1], ...items: int) -> int = first + items.length
main():
  saved = mixed
  print saved(amount: 4)
  print saved(3, amount: 4)
  print saved == mixed
  grouped = ([value: int = 1], amount: int required) -> value + amount
  print grouped(amount: 5)
  print grouped(2, amount: 5)
  text = join
  print text()
  print text(1, 2, prefix: "a")
  print text == join
  rest = tail
  print rest()
  print rest(4, 8, 9)
  print rest == tail
  print api.Box<int>().items.length
  print api.Box<String>(items: ["q"]).items.length
''');
    final compiled = compile(file.readAsStringSync(), file: file.path);
    expect(compiled.dart, contains(r'$QudsPacket'));
    expect(compiled.dart, isNot(contains('_seed')));
    final implementation = compile(
        File('${provider.path}/provider.quds').readAsStringSync(),
        file: '${provider.path}/provider.quds');
    expect(implementation.dart, contains(r'$QudsCtorSlots'));
    expect(implementation.dart, contains('_q0<T>()'));
    expect(compiled.dart, isNot(contains('_q0<T>()')));
    final output = File('${provider.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(provider.path, compiled);
    writeSdkBundles(provider.path, implementation);
    File('${provider.path}/provider.dart')
        .writeAsStringSync(relocateGeneratedLibraries(implementation, '').dart);
    final analysis = await Process.run(Platform.resolvedExecutable,
        ['analyze', output.path, '${provider.path}/provider.dart']);
    expect(analysis.exitCode, 0,
        reason:
            '${analysis.stdout}${analysis.stderr}\n${compiled.dart}\n${implementation.dart}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0,
        reason: '${vm.stdout}${vm.stderr}\n${compiled.dart}');
    expect(vm.stdout, '5\n7\ntrue\n6\n7\nx:0\na:2\ntrue\n1\n6\ntrue\n0\n1\n');
  });

  test('parent synthesis, lambda kinds, and override widening execute',
      () async {
    final source = '''
class Parent:
  value: int
  init(this.value: int required):
    require value > 0
class Child extends Parent:
  tag: String required
class Base:
  value: int
  init([this.value: int = 3]):
    require value > 0
class Next extends Base:
  init([super.value: int = 4]):
    require value > 0
class Point:
  x: int
  const init([this.x: int = 1])
class Holder<T>:
  value: int
  init([this.value: int = 2]):
    require value > 0
class Reader:
  read(value: int required) -> int = value
class Wider extends Reader:
  read(value: int = 2) -> int = value
choose(value: int, pick: (item: int, [fallback: int]) -> int) -> int = pick(value)
main():
  child = Child(value: 4, tag: "ok")
  print child.value
  print child.tag
  print Wider().read()
  parent: Reader = Wider()
  print parent.read(value: 5)
  print choose(3, (item: int, [fallback: int = item]) -> fallback)
  labeled: (value: int required) -> int = (value: int required) -> value
  print labeled(value: 6)
  print Next().value
  print Next(value: 8).value
  print Point().x
  print Point(x: 5).x
  print Holder<String>().value
''';
    final file = File('test/parameter_shape.quds').absolute;
    final compiled = compile(source, file: file.path);
    final root = Directory.systemTemp.createTempSync('quds-parameter-shape-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(root.path, compiled);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}\n${compiled.dart}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0,
        reason: '${vm.stdout}${vm.stderr}\n${compiled.dart}');
    expect(vm.stdout, '4\nok\n2\n5\n3\n6\n4\n8\n1\n5\n2\n');
  });

  test('parameter forms generate deterministic Dart and execute on VM and JS',
      () async {
    final input = File('test/parameter_forms_web.quds').absolute;
    final compiled = compile(input.readAsStringSync(), file: input.path);
    expect(compiled.dart,
        compile(input.readAsStringSync(), file: input.path).dart);
    expect(compiled.dart,
        File('test/goldens/parameter_forms.dart.txt').readAsStringSync());
    final root = Directory.systemTemp.createTempSync('quds-parameter-forms-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(root.path, compiled);
    final provider =
        File('test/fixtures/parameter_forms/provider.quds').absolute;
    final implementation =
        compile(provider.readAsStringSync(), file: provider.path);
    final emitted = File('${root.path}/fixtures/parameter_forms/provider.dart');
    emitted.parent.createSync(recursive: true);
    emitted.writeAsStringSync(
        relocateGeneratedLibraries(implementation, '../../').dart);
    writeSdkBundles(root.path, implementation);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}${analysis.stderr}');
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}${vm.stderr}');
    expect(vm.stdout,
        '8\ntrue\n14\n10\n11\ntrue\n16\n16\nnull\n3\nQuds\n11\n6\ntrue\nsafe\n3\ntrue\n70\n20\ntrue\n70\n9\n8\nleft:4\n');
    final js = '${root.path}/main.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', output.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node',
        ['-e', 'globalThis.self = globalThis; require(process.argv[1]);', js]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect(node.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
