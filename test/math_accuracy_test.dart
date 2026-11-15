import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  setUpAll(() {
    directory = Directory.systemTemp.createTempSync('quds-math-accuracy-');
    // Referencing ln keeps the SDK bundle in the compilation output.
    final compiled = compile('use quds:math\nmain():\n  print ln(e)\n');
    writeSdkBundles(directory.path, compiled);
  });
  tearDownAll(() => directory.deleteSync(recursive: true));

  test('math SDK matches independent references and numerical identities',
      () async {
    final source =
        File('test/fixtures/math_reference.dart.txt').readAsStringSync();
    final expectedChecks =
        RegExp(r'^check\(', multiLine: true).allMatches(source).length;
    expect(expectedChecks, greaterThan(0));
    final runner = File('${directory.path}/reference.dart')
      ..writeAsStringSync(source);
    final result =
        await Process.run(Platform.resolvedExecutable, [runner.path]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('TOTAL=$expectedChecks FAILURES=0'));
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('math exports compile for JavaScript with safe integer guards',
      () async {
    final runner = File('${directory.path}/web.dart')..writeAsStringSync('''
import 'quds_math.dart' as m;
void main() {
  if (m.modPow(4000000000,2,5000000000) != 0) throw 'modular power';
  if (!m.isProbablePrime(7)) throw 'prime';
  if ((m.mean([1.0,2.0,3.0])-2).abs()>1e-12) throw 'mean';
  if ((m.poissonPmf(30,30.0)-0.07263452647159079).abs()>1e-12) throw 'poisson';
  var threw=false;
  try { m.factorial(19); } catch (_) { threw=true; }
  if (!threw) throw 'unsafe integer range';
  final edges=[m.WeightedEdge(source:0,target:1,weight:2.0),m.WeightedEdge(source:1,target:2,weight:3.0)];
  if (m.dijkstra(4,edges,0).distances[2]!=5.0) throw 'weighted Dijkstra';
  if (m.bellmanFord(4,edges,0).pathTo(2).join(',')!='0,1,2') throw 'weighted Bellman-Ford';
  final forest=m.minimumSpanningForest(4,edges);
  if (forest.componentCount!=2 || forest.weight!=5.0) throw 'weighted forest';
  print('WEB MATH OK');
}
''');
    final output = '${directory.path}/web.js';
    final compiled = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', runner.path, '-o', output]);
    expect(compiled.exitCode, 0,
        reason: '${compiled.stdout}\n${compiled.stderr}');
    ProcessResult result;
    try {
      result = await Process.run('node', [output]);
    } on ProcessException {
      markTestSkipped('JavaScript compiled; Node is unavailable for execution');
      return;
    }
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('WEB MATH OK'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
