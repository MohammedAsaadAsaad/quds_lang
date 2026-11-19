import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('parameter forms execute', () async {
    final result = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'test',
      'test/parameter_forms.quds',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(
        '${result.stdout}'.split('\n').where((line) => line.startsWith('ok ')),
        hasLength(4));
  });

  final rejected = <String, String>{
    'main():\n  print greet(name: "Q")\n': 'ok',
    'main():\n  print greet("Q")\n': 'No overload',
    'main():\n  print place(1, extra: 2)\n': 'ok',
    'bad(value: int = 1, other: int) -> int = value\nmain():\n  print bad(1)\n':
        'E500',
    'bad([value: int], name: String = "a") -> int = 1\nmain():\n  print bad()\n':
        'E503',
    'bad([value: int]) -> int = 1\nmain():\n  print bad()\n': 'E503',
    'class Box:\n  read(value: int) -> int = value\n  read(value: num) -> int = 1\nmain():\n  print Box().read(1)\n':
        'E310',
  };
  rejected.forEach((source, diagnostic) {
    test(
        'parameter form ${diagnostic == 'ok' ? 'accepts' : 'rejects'}: $source',
        () {
      final program = source.contains('greet(') || source.contains('place(')
          ? 'greet(name: String required, times: int = 1) -> String = name\n'
              'place(base: int, [extra: int = 4]) -> int = base + extra\n$source'
          : source;
      if (diagnostic == 'ok') {
        compile(program);
        return;
      }
      expect(() => compile(program),
          throwsA(predicate((error) => '$error'.contains(diagnostic))));
    });
  });
}
