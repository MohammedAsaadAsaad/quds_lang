import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('readonly graph conformance executes in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/readonly_graph.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect('${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
        hasLength(4));
  });
  for (final body in [
    'source: readonly Set<List<int>> = set:\n    [1]\n  source.first[0] = 2',
    'source: readonly Set<List<int>> = set:\n    [1]\n  source.lookup(source.first)![0] = 2',
    'source: readonly Map<List<int>, int> = map:\n    [1]: 2\n  source.keys.first[0] = 3',
  ]) {
    test('readonly graph rejects nested writes $body', () {
      expect(() => compile('main():\n  $body\n'),
          throwsA(predicate((e) => '$e'.contains('E307'))));
    });
  }
  test('readonly graph guards and foreign lookup keys work on VM and JS',
      () async {
    final directory =
        Directory.systemTemp.createTempSync('quds-readonly-graph-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('test/readonly_graph_web.quds').readAsStringSync();
    for (final name in ['first', 'second'])
      File('${directory.path}/$name.dart')
          .writeAsStringSync(compile(source).dart);
    final driver = File('${directory.path}/driver.dart')..writeAsStringSync(r'''
import 'first.dart' as q;
import 'second.dart' as other;
void check(bool value) { if (!value) throw StateError('graph assertion'); }
void blocked(void Function() run) {
  try { run(); } on UnsupportedError { return; }
  throw StateError('readonly graph allowed mutation');
}
void main() {
  final key=<int>[1];
  final item=<int>[2];
  final values=<List<int>>{item};
  final set=q.setView(values);
  final member=set.first;
  check(set.contains(member) && set.contains(item));
  check(identical(set.lookup(member),member));
  blocked(()=>member[0]=8);
  blocked(()=>set.add([8]));
  final original=<List<int>,Set<List<int>>>{key:values};
  final map=q.mapView(original);
  final exposedKey=map.keys.first;
  check(identical(exposedKey,map.keys.first));
  check(map.containsKey(exposedKey) && identical(map[exposedKey],set));
  blocked(()=>exposedKey[0]=9);
  blocked(()=>map.clear());
  blocked(()=>map[exposedKey]!.first[0]=9);
  final foreign=other.listView([key])[0];
  check(map.containsKey(foreign) && map[foreign]!.contains(member));
  item[0]=4;
  check(member[0]==4);
  values.add([5]);
  check(set.length==2 && map[exposedKey]!.length==2);
  final inner=<int>[1];
  final nested=q.listView([inner]);
  check(identical(nested[0],nested[0]));
  print('READONLY GRAPH OK');
}
''');
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', driver.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm =
        await Process.run(Platform.resolvedExecutable, ['run', driver.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'READONLY GRAPH OK\n');
    final js = '${directory.path}/driver.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', driver.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final web = await Process.run('node', [js]);
    expect(web.exitCode, 0, reason: '${web.stdout}\n${web.stderr}');
    expect(web.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
