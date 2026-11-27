import 'dart:io';

import 'package:quds/interpreter.dart';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

String _runCompiledOnDartVm(String source) {
  final dir = Directory.systemTemp.createTempSync('quds_op_parity_');
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

  // 2. Default Universal Register Bytecode VM Interpreter
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
  group('String + any concatenation & multi-type operator overloading', () {
    test('String + any value concatenates cleanly across compiler, VM, and AST',
        () async {
      const source = '''
class Tag:
  text: String
  init(this.text)
  toString() -> String = "Tag(" + text + ")"

const greeting = "Ahmed" + 10

main():
  print greeting
  print "Ahmed" + 10
  print "Score: " + 99.5
  print "Active=" + true
  var maybe: int? = null
  print "Empty=" + maybe
  print "User " + "Ahmed" + " #" + 42 + " (" + false + ")"
  var s = "ID:"
  s += 7
  s += "-"
  s += true
  print s
  tag = Tag("v1")
  print "Obj=" + tag
''';
      await _expectThreeWayParity(source, [
        'Ahmed10',
        'Ahmed10',
        'Score: 99.5',
        'Active=true',
        'Empty=null',
        'User Ahmed #42 (false)',
        'ID:7-true',
        'Obj=Tag(v1)',
      ]);
    });

    test('multi-type operator overloading inside a class (binary + unary)',
        () async {
      const source = '''
class Vec2:
  x: double
  y: double
  init(this.x, this.y)

  operator +(other: Vec2) -> Vec2 = Vec2(x + other.x, y + other.y)
  operator +(scalar: int) -> Vec2 = Vec2(x + scalar, y + scalar)
  operator +(scalar: double) -> Vec2 = Vec2(x + scalar, y + scalar)
  operator *(factor: int) -> Vec2 = Vec2(x * factor, y * factor)
  operator *(other: Vec2) -> double = x * other.x + y * other.y
  operator -() -> Vec2 = Vec2(-x, -y)

  toString() -> String = "(" + x + "," + y + ")"

main():
  a = Vec2(1.0, 2.0)
  b = Vec2(3.0, 4.0)
  print a + b
  print a + 10
  print a + 0.5
  print a * 3
  print a * b
  print(-a)
  var v = Vec2(2.0, 5.0)
  v += 3
  v += Vec2(1.0, 1.0)
  print v
''';
      await _expectThreeWayParity(source, [
        '(4.0,6.0)',
        '(11.0,12.0)',
        '(1.5,2.5)',
        '(3.0,6.0)',
        '11.0',
        '(-1.0,-2.0)',
        '(6.0,9.0)',
      ]);
    });

    test('adding extra operator overloads to a class via augment', () async {
      const source = '''
class Money:
  cents: int
  init(this.cents)
  operator +(other: Money) -> Money = Money(cents + other.cents)
  toString() -> String = cents.toString() + "c"

augment Money:
  operator +(extraCents: int) -> Money = Money(cents + extraCents)
  operator *(factor: int) -> Money = Money(cents * factor)

main():
  m1 = Money(100)
  m2 = Money(250)
  print m1 + m2
  print m1 + 50
  print m1 * 3
  var wallet = Money(40)
  wallet += 15
  wallet += Money(5)
  print wallet
''';
      await _expectThreeWayParity(source, [
        '350c',
        '150c',
        '300c',
        '60c',
      ]);
    });

    test('operator overloading on built-in types via augment and extend',
        () async {
      const source = '''
augment String:
  operator -(suffix: String) -> String:
    if this.endsWith(suffix):
      return this.substring(0, this.length - suffix.length)
    return this

augment int:
  operator %(caption: String) -> String = "" + this + " " + caption

extend double:
  operator %(unit: String) -> String = "" + this + unit

main():
  print "hello_world" - "_world"
  print "hello" - "_world"
  print 5 % "stars"
  print 12.5 % "kg"
  print "Count=" + 5
''';
      await _expectThreeWayParity(source, [
        'hello',
        'hello',
        '5 stars',
        '12.5kg',
        'Count=5',
      ]);
    });

    test('augment String can customize String + int when explicitly overloaded',
        () async {
      const source = '''
augment String:
  operator +(n: int) -> String = this + "#" + n.toString()

main():
  print "Ahmed" + 10
  print "Score=" + 99.5
''';
      await _expectThreeWayParity(source, [
        'Ahmed#10',
        'Score=99.5',
      ]);
    });

    test('overloaded indexing operators [] and []= on user classes', () async {
      const source = '''
class Pair:
  var a: int
  var b: int
  init(this.a, this.b)

  operator [](index: int) -> int:
    if index == 0:
      return a
    return b

  operator [](key: String) -> int:
    if key == "sum":
      return a + b
    return a * b

  operator []=(index: int, value: int) -> void:
    if index == 0:
      a = value
    else:
      b = value

main():
  p = Pair(3, 4)
  print p[0]
  print p[1]
  print p["sum"]
  print p["prod"]
  p[0] = 10
  print p[0]
  print p["sum"]
''';
      await _expectThreeWayParity(source, [
        '3',
        '4',
        '7',
        '12',
        '10',
        '14',
      ]);
    });

    test('rejects duplicate operator signatures and preserves null safety', () {
      expect(
        () => compile('''
class Box:
  v: int
  init(this.v)
  operator +(other: int) -> Box = Box(v + other)
  operator +(other: int) -> Box = Box(v + other)
'''),
        throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E201')),
      );

      expect(
        () => compile('''
class Box:
  v: int
  init(this.v)
  operator +(other: int) -> Box = Box(v + other)

augment Box:
  operator +(other: int) -> Box = Box(v + other)
'''),
        throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E201')),
      );

      expect(
        () => compile('''
main():
  var s: String? = null
  x = s + 10
  print x
'''),
        throwsA(isA<CompilerException>().having((e) => e.code, 'code', 'E308')),
      );
    });
  });
}
