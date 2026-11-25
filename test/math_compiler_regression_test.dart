import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('deep single-signature calls do not reanalyze argument subtrees', () {
    var expression = '0';
    for (var depth = 0; depth < 40; depth++) {
      expression = 'increment($expression)';
    }
    final result = compile('increment(x: int) -> int = x + 1\n'
        'main():\n  print $expression\n');
    expect(result.dart, contains('void main()'));
    expect(result.dart, isNotEmpty);
  });

  test('section class dependencies stay in the imported library scope', () {
    expect(() => compile('''
use quds:math::symbolic as symbolic
class BigFraction:
  value: int required
class _PhaseState:
  value: int required
main():
  x = symbolic.exprSymbol("x")
  print x.number.numerator.toString()
  print BigFraction(value: 7).value
  print _PhaseState(value: 9).value
'''), returnsNormally);
    expect(() => compile('''
use quds:math::symbolic as symbolic
main():
  print symbolic.exprSymbol("x")
  print BigFraction()
'''), throwsA(predicate((e) => '$e'.contains('E200'))));
    expect(() => compile('''
use quds:math::symbolic as symbolic
main():
  print symbolic.exprSymbol("x")
  print _PhaseState()
'''), throwsA(predicate((e) => '$e'.contains('E200'))));
    expect(() => compile('''
use quds:math::symbolic as symbolic
class BigFraction:
  value: int required
main():
  own = BigFraction(value: 7)
  print symbolic.Expr(kind: "number", name: "", number: own, arguments: [])
'''), throwsA(predicate((e) => '$e'.contains('E500'))));
  });

  test('SDK sections and whole imports share declaration identity', () {
    final result = compile('''
use quds:math::scalar as scalar
use quds:math::interval::outward as spans
use quds:math as whole show RealInterval, realInterval
accept(input: whole.RealInterval) -> spans.RealInterval = input
main():
  print scalar.nextUp(1.0)
  print accept(whole.realInterval(1.0, 2.0)).contains(1.5)
  print spans.realInterval(0.0, 1.0).contains(0.5)
''');
    expect(result.dart,
        contains(RegExp(r'as spans show [^;\n]*\bRealInterval\b')));
  });

  test('collection interfaces retain the exact element type', () {
    expect(() => compile('''
accept(values: Iterable<int>) -> int = values.length
acceptNums(values: Iterable<num>) -> int = values.length
main():
  items = [1, 2]
  items.addAll([3, 4])
  print accept(items)
  print acceptNums(items)
'''), returnsNormally);
    expect(() => compile('''
accept(values: Iterable<String>) -> int = values.length
main():
  print accept([1, 2])
'''), throwsA(predicate((e) => '$e'.contains('E500'))));
    expect(() => compile('''
acceptList(values: List<num>) -> int = values.length
main():
  items = [1, 2]
  print acceptList(items)
'''), throwsA(predicate((e) => '$e'.contains('E500'))));
  });

  test('imported AD signatures preserve nominal identity and filters', () {
    expect(() => compile('''
use quds:math as m
class Dual:
  value: int required
main():
  print m.autoDerivative((x: Dual) -> x, 1.0)
'''), throwsA(predicate((e) => '$e'.contains('E500'))));
    expect(() => compile('''
use quds:math as m show autoDerivative
main():
  print m.Dual(value: 1.0, tangent: 1.0)
'''), throwsA(predicate((e) => '$e'.contains('E200'))));
    expect(() => compile('''
use quds:math show autoDerivative
main():
  print _qImportedType0.Dual(value: 1.0, tangent: 1.0)
'''), throwsA(predicate((e) => '$e'.contains('E200'))));
  });

  test('SDK BigInt operators retain static result and argument types', () {
    final result = compile('''
use dart:core show BigInt
main():
  a = BigInt.from(3)
  b = BigInt.from(2)
  total = a + b
  ratio = a / b
  integer = a ~/ b
  negative = -a
  complemented = ~a
  smaller = a < b
''');
    final main =
        result.program.statements.whereType<FunctionDeclaration>().single;
    final types = {
      for (final binding in main.body!.whereType<Binding>())
        binding.name: result.semantics.types[binding.value]
    };
    expect(types['total'], 'BigInt');
    expect(types['ratio'], 'double');
    expect(types['integer'], 'BigInt');
    expect(types['negative'], 'BigInt');
    expect(types['complemented'], 'BigInt');
    expect(types['smaller'], 'bool');
    for (final expression in ['a + 1', 'a << a', 'a >>> 1']) {
      expect(
          () => compile(
              'use dart:core show BigInt\nmain():\n  a = BigInt.one\n  print($expression)\n'),
          throwsA(predicate((e) => '$e'.contains('E300'))));
    }
    for (final expression in ['a + BigInt.one', '-a', '~a']) {
      expect(
          () => compile(
              'use dart:core show BigInt\nmain():\n  a: BigInt? = null\n  print($expression)\n'),
          throwsA(predicate((e) => '$e'.contains('E308'))));
    }
  });

  test('bit operations reject floating and mixed operands in Quds', () {
    for (final expression in ['1.5 & 1', '1 << 1.5', 'true | 1', '~1.5']) {
      expect(() => compile('main():\n  print($expression)\n'),
          throwsA(predicate((e) => '$e'.contains('E300'))),
          reason: expression);
    }
    expect(() => compile('const bad = 1 << -1\nmain():\n  print bad\n'),
        throwsA(predicate((e) => '$e'.contains('E401'))));
  });

  test('prefixed math uses its own unprefixed Dart dependencies', () {
    final result = compile('''
use quds:math as m show normalCdf
main():
  print m.normalCdf(0.0)
''');
    expect(result.dart, contains('normalCdf'));
    expect(() => compile('''
use quds:math as m show normalCdf
main():
  print sqrt(9.0)
'''), throwsA(predicate((e) => '$e'.contains('E200'))));
  });

  test('underscore members are rejected at the original Quds span', () {
    final directory = Directory.systemTemp.createTempSync('quds-privacy-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/box.quds').writeAsStringSync('''
class Box:
  _secret: int = 7
  _read() -> int = _secret
''');
    for (final expression in ['box._secret', 'box._read()']) {
      expect(
          () => compile('''
use "box.quds"
main():
  box = Box()
  print $expression
''', file: '${directory.path}/app.quds'),
          throwsA(predicate(
              (e) => '$e'.contains('E206') && '$e'.contains('app.quds:4:'))));
    }
    expect(() => compile('''
class Box:
  _secret: int = 7
main():
  print Box()._secret
'''), returnsNormally);
  });
}
