import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('formatQuds normalizes operator, colon, and delimiter spacing', () {
    const messy = r'''
use dart:io

main():
  stdout.write('Enter the desired stairs of the pyramid: ')
  b: String= 'alsjd;lsad'
  a=int.tryParse(stdin.readLineSync()??'')??0
  repeat a: stdout.write((' '*(a-$.iteration))+( '* ' * $.iteration )+'\n')
''';
    const expected = r'''
use dart:io

main():
  stdout.write('Enter the desired stairs of the pyramid: ')
  b: String = 'alsjd;lsad'
  a = int.tryParse(stdin.readLineSync() ?? '') ?? 0
  repeat a: stdout.write((' ' * (a - $.iteration)) + ('* ' * $.iteration) + '\n')
''';
    final formatted = formatQuds(messy);
    expect(formatted, expected);
    expect(formatQuds(formatted), expected);
  });

  test(
      'formatQuds preserves generics, unary signs, slices, directives, operators, and comments',
      () {
    const messy = '''
use quds:text::types show TextRange,TextBoundaryPolicy
part of ^.main

:: helpers

class Box<T>:
  value: T
  operator +(other: Box<T>)->Box<T>:
    return this

compute(items: List<Map<String,List<int>>>,limit: int=10)->int?:
  var total=-1+items.length # keep comment
  if (total<limit and limit>0):
    part=items[0..<1]
    nums=[?null,-2,0..limit]
    return total+part.length+nums.length
  return null
''';
    const expected = '''
use quds:text::types show TextRange, TextBoundaryPolicy
part of ^.main

:: helpers

class Box<T>:
  value: T
  operator +(other: Box<T>) -> Box<T>:
    return this

compute(items: List<Map<String, List<int>>>, limit: int = 10) -> int?:
  var total = -1 + items.length # keep comment
  if (total < limit and limit > 0):
    part = items[0..<1]
    nums = [?null, -2, 0..limit]
    return total + part.length + nums.length
  return null
''';
    final formatted = formatQuds(messy.replaceAll('\n', '\r\n'));
    expect(formatted, expected);
    expect(formatQuds(formatted), expected);
    Parser(const Lexer().tokenize(formatted)).parse();
  });

  test('formatQuds keeps wrapped multiline generic signatures idempotent', () {
    const source = '''
nestedMap(values: Map<String, List<int>>, fallback: Map<String, List<int>>) -> int:
  return values.length + fallback.length
''';
    final once = formatQuds(source, width: 40);
    final twice = formatQuds(once, width: 40);
    expect(twice, once);
    expect(once, contains('Map<String,'));
    Parser(const Lexer().tokenize(once)).parse();
  });

  test('LSP textDocument/formatting applies token spacing on save', () {
    final session = LspSession();
    const uri = 'file:///format_demo.quds';
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'languageId': 'quds',
          'version': 1,
          'text': 'main():\n  a=1+2\n  b: String=\'hi\'\n',
        },
      },
    });
    final reply = session.handle({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'textDocument/formatting',
      'params': {
        'textDocument': {'uri': uri},
        'options': {'tabSize': 2, 'insertSpaces': true},
      },
    });
    final edits = reply.response!['result'] as List;
    expect(edits, hasLength(1));
    expect((edits.single as Map)['newText'],
        'main():\n  a = 1 + 2\n  b: String = \'hi\'\n');
  });

  test('CLI quds format supports --check, --stdout, options, and directories',
      () async {
    final dir = Directory.systemTemp.createTempSync('quds-format-cli-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final sub = Directory('${dir.path}/sub')..createSync();
    final a = File('${dir.path}/a.quds')
      ..writeAsStringSync('main():\n  a=1+2\n');
    final b = File('${sub.path}/b.quds')
      ..writeAsStringSync('main():\n  if true:\n    x=3*4\n');
    // Ignored directory should not be touched.
    final ignoredDir = Directory('${dir.path}/.dart_tool')..createSync();
    final ignored = File('${ignoredDir.path}/skip.quds')
      ..writeAsStringSync('main():\n  a=1+2\n');

    Future<ProcessResult> cli(List<String> args) => Process.run(
          Platform.resolvedExecutable,
          ['run', 'bin/quds.dart', ...args],
        );

    // --stdout prints formatted code without rewriting.
    final preview = await cli(['format', '--stdout', a.path]);
    expect(preview.exitCode, 0, reason: '${preview.stderr}');
    expect(preview.stdout, 'main():\n  a = 1 + 2\n');
    expect(a.readAsStringSync(), 'main():\n  a=1+2\n');

    // --check reports unformatted files and exits with 1 without modifying.
    final checkBefore = await cli(['format', '--check', dir.path]);
    expect(checkBefore.exitCode, 1);
    expect(checkBefore.stdout, contains('a.quds'));
    expect(checkBefore.stdout, contains('b.quds'));
    expect(checkBefore.stdout, isNot(contains('skip.quds')));

    // Directory format rewrites all .quds files in place.
    final runDir = await cli(['format', dir.path]);
    expect(runDir.exitCode, 0, reason: '${runDir.stderr}');
    expect(a.readAsStringSync(), 'main():\n  a = 1 + 2\n');
    expect(b.readAsStringSync(), 'main():\n  if true: x = 3 * 4\n');
    expect(ignored.readAsStringSync(), 'main():\n  a=1+2\n');

    // --check now exits with 0.
    final checkAfter = await cli(['format', '--check', dir.path]);
    expect(checkAfter.exitCode, 0, reason: '${checkAfter.stderr}');

    // Custom flags --indent and --no-single-line-if work via CLI.
    final custom = File('${dir.path}/custom.quds')
      ..writeAsStringSync('main():\n  if true:\n    x=1+2\n');
    final customRun = await cli(
        ['format', '--indent', '4', '--no-single-line-if', custom.path]);
    expect(customRun.exitCode, 0, reason: '${customRun.stderr}');
    expect(custom.readAsStringSync(),
        'main():\n    if true:\n        x = 1 + 2\n');

    // Invalid syntax exits with 65 and preserves file contents.
    final broken = File('${dir.path}/broken.quds')
      ..writeAsStringSync('main():\n  x = [1, 2\n');
    final brokenRun = await cli(['format', broken.path]);
    expect(brokenRun.exitCode, 65);
    expect(broken.readAsStringSync(), 'main():\n  x = [1, 2\n');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
