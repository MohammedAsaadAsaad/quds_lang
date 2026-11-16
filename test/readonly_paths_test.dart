import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('readonly paths execute in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/readonly_paths.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect('${result.stdout}'.split('\n').where((s) => s.startsWith('ok ')),
        hasLength(6));
  });
  const prefix = '''class Counter:
  var count: int = 1
  increment():
    count += 1
  readonly read() -> int = count
class Child extends Counter:
  tag: int = 0
''';
  final rejects = <String, String>{
    'view: readonly Counter = Counter()\n  mutable: Object? = view': 'E300',
    'view: readonly Counter = Counter()\n  saved = () -> view\n  saved().increment()':
        'E307',
    'view: readonly Counter = Counter()\n  view.increment()': 'E307',
    'view: readonly Child = Child()\n  view.increment()': 'E307',
    'view: readonly Counter = Counter()\n  saved = view.increment\n  saved()':
        'E307',
    'view: readonly Counter = Counter()\n  mutable: Counter = view': 'E300',
    'view: readonly Counter = Counter()\n  mutable: dynamic = view': 'E300',
    'view: readonly List<int> = [1]\n  mutable = view as List<int>\n  mutable[0] = 2':
        'E307',
    'view: readonly List<int> = [1]\n  mutable = view to List<int>\n  mutable[0] = 2':
        'E307',
    'view: readonly List<int> = [1]\n  mutable = view to? List<int>\n  mutable![0] = 2':
        'E307',
    'view: readonly List<int> = [1]\n  erased = view as Object\n  mutable = erased as List<int>\n  mutable[0] = 2':
        'E307',
    'view: readonly List<int> = [1]\n  erased = view as dynamic\n  erased.unknown()':
        'E307',
    'view: readonly List<List<int>> = [[1]]\n  for row in view:\n    row[0] = 2':
        'E307',
    'view: readonly List<List<int>> = [[1]]\n  row = view.find((item: readonly List<int>) -> true)\n  row![0] = 2':
        'E307',
    'view: readonly List<List<int>> = [[1]]\n  view.map((row: List<int>) -> row.length)':
        'E300',
    'view: readonly List<List<int>> = [[1]]\n  copy = view.toList()\n  copy[0][0] = 2':
        'E307',
    'view: readonly Map<String, List<int>> = map:\n    "a": [1]\n  for row in view.values:\n    row[0] = 2':
        'E307',
  };
  for (final e in rejects.entries) {
    test('readonly rejects ${e.key}', () {
      expect(() => compile('${prefix}main():\n  ${e.key}\n'),
          throwsA(predicate((e2) => '$e2'.contains(e.value))));
    });
  }
  test('readonly diagnostics retain the original Quds location', () {
    try {
      compile('main():\n  view: readonly List<int> = [1]\n  view[0] = 2\n',
          file: 'readonly.quds');
      fail('Expected readonly diagnostic');
    } on CompilerException catch (error) {
      expect(error.code, 'E307');
      expect(error.span.file, 'readonly.quds');
      expect(error.span.line, 3);
    }
  });
  test('unsupported class proxies are rejected at an erased Dart boundary', () {
    expect(
        () => compile(
            'use dart:convert\n${prefix}main():\n  view: readonly Counter = Counter()\n  print jsonEncode(view)\n'),
        throwsA(predicate((e) => '$e'.contains('E910'))));
  });
  test('deep collection guards execute on VM and JavaScript', () async {
    final directory = Directory.systemTemp.createTempSync('quds-readonly-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final input = File('test/readonly_paths_web.quds');
    final result = compile(input.readAsStringSync(), file: input.path);
    File('${directory.path}/views.dart').writeAsStringSync(result.dart);
    final driver = File('${directory.path}/driver.dart')..writeAsStringSync(r'''
import 'views.dart' as q;
void check(bool value) { if (!value) throw StateError('readonly assertion'); }
void blocked(void Function() run) {
  try { run(); } on UnsupportedError { return; }
  throw StateError('readonly allowed mutation');
}
void main() {
  final original=<List<int>>[[1]];
  final view=q.nested(original);
  blocked(()=>view.add([2]));
  blocked(()=>view[0][0]=2);
  original[0][0]=3;
  original.add([4]);
  check(view[0][0]==3 && view.length==2);
  blocked(()=>q.throughDynamic(original)[0][0]=5);
  check(q.consume(original,(dynamic data) { blocked(()=>data[0][0]=9); return true; }));
  final map=<String,List<int>>{'a':[1]};
  final readMap=q.nestedMap(map);
  blocked(()=>readMap['a']![0]=2);
  blocked(()=>readMap['b']=[3]);
  map['a']![0]=4;
  check(readMap['a']![0]==4);
  check(readMap['missing']==null);
  check(q.nullable(null)==null);
  blocked(()=>q.nullable(original)![0][0]=7);
  print('READONLY PATHS OK');
}
''');
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', driver.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm =
        await Process.run(Platform.resolvedExecutable, ['run', driver.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'READONLY PATHS OK\n');
    final js = '${directory.path}/driver.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', driver.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final web = await Process.run('node', [js]);
    expect(web.exitCode, 0, reason: '${web.stdout}\n${web.stderr}');
    expect(web.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
