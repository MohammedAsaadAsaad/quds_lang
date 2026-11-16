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
  final large=m.bigInt('1208925819614629174706176');
  if ((large+BigInt.one).toString()!='1208925819614629174706177') throw 'BigInt operator';
  if (m.bigFibonacci(100).toString()!='354224848179261915075') throw 'exact Fibonacci';
  if (m.bigFactorial(30).toString()!='265252859812191058636308480000000') throw 'exact factorial';
  if (m.bigFraction(large,large).toString()!='1/1') throw 'exact rational';
  if (m.autoDerivative((m.Dual x)=>x*x*x,3.0)!=27.0) throw 'forward AD';
  final gradient=m.autoGradient((List<m.Dual> x)=>x[0]*x[1],[2.0,3.0]);
  if (gradient[0]!=3.0 || gradient[1]!=2.0) throw 'AD gradient';
  if (m.autoJacobian((List<m.Dual> x)=>[x[0]*x[1]],[2.0,3.0])[0][1]!=2.0) throw 'AD Jacobian';
  if (m.binaryFraction(0.1).toString()!='3602879701896397/36028797018963968') throw 'binary fraction';
  final origin=m.Vec2(x:0.0,y:0.0);
  if (m.orientation2D(origin,m.Vec2(x:1e-300,y:0.0),m.Vec2(x:0.0,y:1e-300))!=1) throw 'exact orientation';
  final square=[origin,m.Vec2(x:1.0,y:0.0),m.Vec2(x:1.0,y:1.0),m.Vec2(x:0.0,y:1.0)];
  if (m.convexHull(square).length!=4 || m.polygonSignedAreaExact(square).toString()!='1/1') throw 'exact polygon';
  if (!m.pointInPolygon(m.Vec2(x:0.5,y:0.5),square,true)) throw 'polygon winding';
  if (m.nextUp(1.0)!=1.0000000000000002 || m.nextDown(-1.0)!=-1.0000000000000002) throw 'binary neighbors';
  if (!m.nextUp(-5e-324).isNegative || m.nextDown(5e-324).isNegative) throw 'signed zero neighbor';
  if (m.nextUp(-double.infinity)!=-1.7976931348623157e308 || m.ulp(0.0)!=5e-324) throw 'binary limits';
  final enclosure=m.realInterval(0.1,0.1)+m.realInterval(0.2,0.2);
  if (!enclosure.contains(0.3)) throw 'interval addition';
  final product=m.realInterval(5e-324,5e-324)*m.realInterval(5e-324,5e-324);
  if (product.low>0.0 || product.high<5e-324) throw 'interval underflow';
  final overflow=m.realInterval(1e308,1e308)+m.realInterval(1e308,1e308);
  if (overflow.low!=1.7976931348623157e308 || overflow.high!=double.infinity) throw 'interval overflow';
  if (!(m.realInterval(1.0,1.0)/m.realInterval(3.0,3.0)).contains(1/3)) throw 'interval division';
  final sx=m.exprSymbol('x');
  final sz=m.exprNumber(m.bigFraction(BigInt.zero,BigInt.one));
  final so=m.exprNumber(m.bigFraction(BigInt.one,BigInt.one));
  if (m.simplifyExpr(m.exprMultiply(sz,m.exprDivide(so,sx))).kind!='multiply') throw 'symbolic domain';
  if (m.exprText(m.deriveExpr(m.exprPower(sx,sz),'x'))!='0/1') throw 'symbolic zero-power derivative';
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
