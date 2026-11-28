import 'dart:io';

import 'package:quds/interpreter.dart';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

String _runCompiledOnDartVm(String source) {
  final dir = Directory.systemTemp.createTempSync('quds_unary_parity_');
  try {
    final qudsFile = File('${dir.path}/main.quds')..writeAsStringSync(source);
    final compiled = compile(source, file: qudsFile.path);
    writeSdkBundles(dir.path, compiled);
    final dartFile = File('${dir.path}/main.dart')
      ..writeAsStringSync(compiled.dart);
    final res = Process.runSync(Platform.resolvedExecutable, [dartFile.path]);
    if (res.exitCode != 0) {
      fail(
        'Compiled Dart failed (${res.exitCode}):\n${res.stderr}\n--- Dart ---\n${compiled.dart}',
      );
    }
    return (res.stdout as String).trimRight().replaceAll('\r\n', '\n');
  } finally {
    dir.deleteSync(recursive: true);
  }
}

Future<void> _expectThreeWayParity(
  String source,
  List<String> expectedLines,
) async {
  final expected = expectedLines.join('\n');

  // 1. Compiled Dart VM
  final compiledOut = _runCompiledOnDartVm(source);
  expect(compiledOut, expected, reason: 'Compiled Dart VM mismatch');

  // 2. Register Bytecode / Universal VM Interpreter
  final vmSession = QudsSession();
  final vmRes = await vmSession.run('$source\nmain()\n', preferBytecode: true);
  expect(vmRes.succeeded, isTrue, reason: 'Register VM failed: ${vmRes.error}');
  expect(vmRes.stdout.trimRight(), expected, reason: 'Register VM mismatch');
  await vmSession.dispose();

  // 3. AST Tree-Walking Interpreter
  final astSession = QudsSession();
  final astRes =
      await astSession.run('$source\nmain()\n', preferBytecode: false);
  expect(astRes.succeeded, isTrue, reason: 'AST failed: ${astRes.error}');
  expect(astRes.stdout.trimRight(), expected, reason: 'AST mismatch');
  await astSession.dispose();
}

void main() {
  group('Unary prefix operators (-, +, ~) & linear algebra built-ins', () {
    test('custom class, augment, and extend unary operators (-, +, ~)',
        () async {
      const source = '''
class Point:
  x: int
  y: int
  init(this.x, this.y)
  operator -() -> Point = Point(-x, -y)
  operator +() -> Point = Point(x * 10, y * 10)
  operator ~() -> Point = Point(y, x)
  toString() -> String = "({x},{y})"

class Vector2:
  x: double
  y: double
  init(this.x, this.y)
  toString() -> String = "<{x},{y}>"

augment Vector2:
  operator -() -> Vector2 = Vector2(-x, -y)
  operator +() -> Vector2 = Vector2(x, y)
  operator ~() -> Vector2 = Vector2(y, x)

main():
  p = Point(2, 3)
  print(-p)
  print(+p)
  print(~p)
  v = Vector2(1.5, -2.5)
  print(-v)
  print(+v)
  print(~v)
''';
      await _expectThreeWayParity(source, [
        '(-2,-3)',
        '(20,30)',
        '(3,2)',
        '<-1.5,2.5>',
        '<1.5,-2.5>',
        '<-2.5,1.5>',
      ]);
    });

    test(
        'built-in element-wise unary -, +, ~ on 1D/2D lists and custom element types',
        () async {
      const source = '''
class Point:
  x: int
  y: int
  init(this.x, this.y)
  operator -() -> Point = Point(-x, -y)
  operator +() -> Point = Point(x, y)
  operator ~() -> Point = Point(y, x)
  toString() -> String = "({x},{y})"

const kNeg = -[1, -2, 3]
const kMat = -[[1, -2], [3, -4]]

main():
  print(kNeg)
  print(kMat)
  a = [1, -2, 3]
  print(-a)
  print(+a)
  print(~a)
  m = [[1.0, -2.0], [3.0, -4.0]]
  print(-m)
  pts = [Point(2, 3), Point(-1, 4)]
  npts = -pts
  spts = ~pts
  print("{npts[0]}|{npts[1]}")
  print("{spts[0]}|{spts[1]}")
  d = -5s
  print(d.inSeconds)
''';
      await _expectThreeWayParity(source, [
        '[-1, 2, -3]',
        '[[-1, 2], [-3, 4]]',
        '[-1, 2, -3]',
        '[1, -2, 3]',
        '[-2, 1, -4]',
        '[[-1.0, 2.0], [-3.0, 4.0]]',
        '(-2,-3)|(1,-4)',
        '(3,2)|(4,-1)',
        '-5',
      ]);
    });

    test('quds:math linear algebra unary and binary operators parity',
        () async {
      const source = '''
use quds:math

main():
  np = -Point(2, 3)
  print("{np.x},{np.y}")

  v2 = Vec2(x: 2.0, y: -3.0)
  nv2 = -v2
  print("{nv2.x},{nv2.y}")

  z = Complex(real: 3.0, imag: 4.0)
  cz = ~z
  nz = -z
  print("{cz.real},{cz.imag}|{nz.real},{nz.imag}")

  a = [[1.0, 2.0], [3.0, 4.0]]
  print(-a)
  print(~a)
  print(a * [1.0, 2.0])
  print(a * 2.0)

  t = tensor([2, 3], [1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
  print((-t).values)
  print((~t).shape)
  print((~t).values)

  s = sparseMatrix(2, [0, 1], [1, 0], [3.0, 5.0])
  print((-s) * [1.0, 2.0])
  print((~s) * [1.0, 2.0])

  fe = fieldElement(3, 7)
  print((-fe).residue)
''';
      await _expectThreeWayParity(source, [
        '-2,-3',
        '-2.0,3.0',
        '3.0,-4.0|-3.0,-4.0',
        '[[-1.0, -2.0], [-3.0, -4.0]]',
        '[[1.0, 3.0], [2.0, 4.0]]',
        '[5.0, 11.0]',
        '[[2.0, 4.0], [6.0, 8.0]]',
        '[-1.0, -2.0, -3.0, -4.0, -5.0, -6.0]',
        '[3, 2]',
        '[1.0, 4.0, 2.0, 5.0, 3.0, 6.0]',
        '[-6.0, -5.0]',
        '[10.0, 3.0]',
        '4',
      ]);
    });

    test('fast bytecode VM handles unboxed unary + / - and postfix ! cleanly',
        () async {
      const source = '''
main():
  var total = 0
  for i in 1..5:
    total += +i - (-i)
  print(total)
  maybe: int? = 42
  print(maybe!)
''';
      await _expectThreeWayParity(source, [
        '30',
        '42',
      ]);
    });

    test('rejects unsupported element-wise list unary ops at compile time', () {
      expect(
        () => compile('main():\n  x = -["a", "b"]\n  print(x)\n'),
        throwsA(isA<CompilerException>()),
      );
      expect(
        () => compile('main():\n  x = ~[1.0, 2.0]\n  print(x)\n'),
        throwsA(isA<CompilerException>()),
      );
      expect(
        () => compile(
            'main():\n  xs: List<int?> = [1, null]\n  y = -xs\n  print(y)\n'),
        throwsA(isA<CompilerException>()),
      );
      expect(
        () => compile(
            'class Box:\n  v: int\n  init(this.v)\nmain():\n  xs = [Box(1)]\n  print(-xs)\n'),
        throwsA(isA<CompilerException>()),
      );
    });
  });
}
