import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/complete.dart';
import 'package:test/test.dart';

void main() {
  test('typed numeric storage is exercised by Quds declarations', () async {
    const suites = {
      'typed_storage.quds': 7,
      'typed_storage_prefix.quds': 1,
      'typed_storage_core.quds': 1
    };
    for (final entry in suites.entries) {
      final result = await Process.run(Platform.resolvedExecutable,
          ['run', 'bin/quds.dart', 'test', 'test/${entry.key}']);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect('${result.stdout}'.split('\n').where((s) => s.startsWith('ok ')),
          hasLength(entry.value));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('typed native identities do not accept a same-named caller class', () {
    expect(() => compile('''
use quds:core::typed as storage
class Float64List:
  value: int required
accept(value: storage.Float64List) -> int = value.length
main():
  print accept(Float64List(value: 7))
'''), throwsA(predicate((e) => '$e'.contains('E500'))));
    expect(
        () => compile('use quds:core::typed show Float64List\n'
            'main():\n  print ByteData(4)\n'),
        throwsA(predicate((e) => '$e'.contains('E200'))));
  });

  test(
      'typed collection completion includes inherited members without internal type keys',
      () {
    const prefix = 'use quds:core::typed\nmain():\n  values = Float64List(2)\n';
    final stable = compile('${prefix}  print values[0]\n');
    final items = completeAt(
        source: '${prefix}  values.',
        line: 3,
        character: 9,
        stable: stable,
        compileSource: (source) {
          try {
            return compile(source);
          } catch (_) {
            return null;
          }
        });
    final names = items.map((item) => item['label']).toSet();
    expect(names, containsAll(['buffer', 'length', 'map', 'setAll']));
    expect(items.toString(), isNot(contains('@dart.typed.')));
  });

  test('re-export filters keep an empty intersection empty', () {
    expect(
        () => compile(
            'use quds:core show Stack\nmain():\n  print Float64List(1)\n'),
        throwsA(predicate((e) => '$e'.contains('E200'))));
    final directory = Directory.systemTemp.createTempSync('quds-filter-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/child.quds')
        .writeAsStringSync('exposed() -> int = 1\n');
    File('${directory.path}/barrel.quds').writeAsStringSync(
        'export "child.quds" show exposed\nkept() -> int = 2\n');
    expect(
        () => compile(
            'use "barrel.quds" show kept\nmain():\n  print exposed()\n',
            file: '${directory.path}/caller.quds'),
        throwsA(predicate((e) => '$e'.contains('E200'))));
    expect(
        () => compile('use "barrel.quds" show kept\nmain():\n  print kept()\n',
            file: '${directory.path}/caller.quds'),
        returnsNormally);
  });

  final rejects = <String, String>{
    'data = Int32List(1)\n  data[0] = 1.5': 'E300',
    'data = Float64List(1)\n  data[0.5] = 1.0': 'E300',
    'data: Float64List? = null\n  data[0] = 1.0': 'E308',
    'data: readonly Float64List = Float64List(1)\n  data[0] = 1.0': 'E307',
    'data: readonly Float64List = Float64List(1)\n  data.setAll(0, [1.0])':
        'E307',
    'data: readonly ByteData = ByteData(8)\n  data.setFloat64(0, 1.0)': 'E307',
    'data: readonly Float64List = Float64List(1)\n  saved = capture(data) -> data\n  saved()[0] = 1.0':
        'E307',
    'data: readonly Float64List = Float64List(1)\n  data.buffer.asFloat64List()[0] = 1.0':
        'E307',
    'data: readonly Float64List = Float64List(1)\n  data.buffer.asByteData().setFloat64(0, 1.0)':
        'E307',
    'data: List<num> = Float64List(1)': 'E300',
    'data = Int64List(1)': 'E200',
  };
  for (final entry in rejects.entries) {
    test('rejects unsafe typed storage: ${entry.key}', () {
      expect(() => compile('use quds:core::typed\nmain():\n  ${entry.key}\n'),
          throwsA(predicate((e) => '$e'.contains(entry.value))));
    });
  }

  test(
      'typed views retain readonly guards across Dart and JavaScript boundaries',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-typed-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('test/typed_storage_web.quds');
    final compiled = compile(file.readAsStringSync(), file: file.path);
    writeSdkBundles(directory.path, compiled);
    File('${directory.path}/program.dart').writeAsStringSync(compiled.dart);
    final driver = File('${directory.path}/driver.dart')..writeAsStringSync('''
import 'dart:typed_data';
import 'program.dart' as q;
void blocked(void Function() action) {
  try { action(); } on UnsupportedError { return; }
  throw StateError('readonly storage permitted a write');
}
void main() {
  q.main();
  final values=Float64List.fromList([1.0,2.0]);
  final read=q.readonlyFloats(values);
  final captured=q.capturedReadonly(values);
  blocked(()=>captured()[0]=9.0);
  blocked(()=>read[0]=9.0);
  blocked(()=>read.buffer.asFloat64List()[0]=9.0);
  values[0]=3.0;
  if(read[0]!=3.0) throw 'view copied instead of sharing';
  final bytes=ByteData(16);
  blocked(()=>q.readonlyBytes(bytes).setFloat64(0,9.0));
  final base=q.readonlyBase(values);
  if(base is! Float64List || base.elementSizeInBytes!=8) throw 'base storage changed representation';
  blocked(()=>base.buffer.asFloat64List()[0]=9.0);
  blocked(()=>q.readonlyBuffer(bytes.buffer).asFloat64List()[0]=9.0);
  final guarded=q.probeFloats(values,(dynamic data) {
    try { data[0]=9.0; } on UnsupportedError { return true; }
    return false;
  });
  if(!guarded || values[0]!=3.0) throw 'readonly parameter escaped';
  print('TYPED BRIDGE OK');
}
''');
    final vm = await Process.run(Platform.resolvedExecutable, [driver.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, contains('TYPED BRIDGE OK'));
    final output = '${directory.path}/driver.js';
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', driver.path, '-o', output]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', [output]);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect(js.stdout, contains('TYPED BRIDGE OK'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}
