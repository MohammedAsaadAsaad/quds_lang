import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
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
