// This file only launches Quds suites; mathematical assertions live in .quds.
import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  const suites = {
    'math.quds': null,
    'math_accuracy.quds': null,
    'math_reference.quds': 'QUDS NUMERIC CHECKS=1167 FAILURES=0',
    'math_graph_reference.quds':
        'QUDS GRAPH CHECKS=151457 GRAPHS=1695 FAILURES=0',
    'math_weighted_graph.quds':
        'QUDS WEIGHTED CHECKS=224537 GRAPHS=4357 FAILURES=0',
    'math_exact.quds': null,
    'math_exact_reference.quds': 'QUDS EXACT CHECKS=1199 FAILURES=0',
    'math_autodiff.quds': null,
    'math_autodiff_reference.quds': 'QUDS AD CHECKS=598 FAILURES=0',
    'math_autodiff_imports.quds': null,
    'math_autodiff_alias.quds': null,
    'math_api.quds': null,
    'math_operators.quds': null,
    'math_prefix.quds': null,
  };
  for (final entry in suites.entries) {
    test('Quds primary suite ${entry.key}', () async {
      final path = 'test/${entry.key}';
      final source = File(path).readAsStringSync();
      final program = Parser(Lexer().tokenize(source, file: path)).parse();
      final titles = <String>[];
      void collect(List<Statement> statements) {
        for (final declaration in statements.whereType<TestDeclaration>()) {
          titles.add(declaration.title);
          collect(declaration.body);
        }
      }

      collect(program.statements);
      expect(titles, isNotEmpty);
      final result = await Process.run(
          Platform.resolvedExecutable, ['run', 'bin/quds.dart', 'test', path]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final lines = '${result.stdout}'.split('\n');
      for (final title in titles) {
        expect(lines, contains('ok $title'), reason: '${result.stdout}');
      }
      expect(lines.where((line) => line.startsWith('FAIL ')), isEmpty);
      if (entry.value != null) {
        expect(lines, contains(entry.value));
        print(entry.value);
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
