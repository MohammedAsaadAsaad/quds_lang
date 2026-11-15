import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
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
