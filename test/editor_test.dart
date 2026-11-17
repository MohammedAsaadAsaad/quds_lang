import 'dart:async';
import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

Map response(LspSession session, String uri, int line, int character) =>
    session.handle({
      'id': 1,
      'method': 'textDocument/completion',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': line, 'character': character}
      }
    }).response!['result'] as Map;
void open(LspSession session, String uri, String source) => session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {'uri': uri, 'version': 1, 'text': source}
      }
    });
List<Map> items(String source, String target,
    {String file = 'test/editor_buffer.quds'}) {
  final session = LspSession();
  final uri = File(file).absolute.uri.toString();
  open(session, uri, source);
  final lines = source.split('\n');
  final line = lines.indexWhere((l) => l.contains(target));
  final result =
      response(session, uri, line, lines[line].indexOf(target) + target.length);
  session.dispose();
  return (result['items'] as List).cast<Map>();
}

void main() {
  test('editor analysis retains symbols without generating Dart or SDK bundles',
      () {
    final analysis = compile(
        'use quds:math\nmain():\n  print mean([1.0, 2.0])\n',
        emitDart: false);
    expect(analysis.dart, isEmpty);
    expect(analysis.bundles, isEmpty);
    expect(analysis.sourceMap, isNull);
    expect(analysis.semantics.moduleSymbols.keys, contains('mean'));
  });
  test('completion specializes Quds generic inherited members', () {
    final result = items('''class Parent<T>:
  value: T required
class Child<U> extends Parent<List<U>>:
  tag: int = 0
main():
  child = Child<int>(value: [1])
  print child.
''', 'child.');
    expect(
        result.firstWhere((i) => i['label'] == 'value')['detail'], 'List<int>');
  });
  test('completion specializes native generic inherited members and chains',
      () {
    final result = items('''use "fixtures/dart_generics/api.dart" as native
main():
  child = native.NativeChild<int>([1])
  print child.
''', 'child.');
    expect(
        result.firstWhere((i) => i['label'] == 'value')['detail'], 'List<int>');
    final chained = items('''use "fixtures/dart_generics/api.dart" as native
main():
  child = native.NativeChild<int>([1])
  print child.value.
''', 'child.value.');
    expect(
        chained.map((i) => i['label']), containsAll(['length', 'add', 'map']));
  });
  test('completion includes native named arguments', () {
    final result = items('''use "fixtures/dart_generics/api.dart"
main():
  print nativeNamed(
''', 'nativeNamed(');
    expect(result.map((i) => i['label']), containsAll(['value', 'fallback']));
  });
  test('generic SDK extensions appear with instantiated details', () {
    final result = items('''use quds:ext
main():
  values = [1, 2]
  print values.
''', 'values.');
    expect(result.firstWhere((i) => i['label'] == 'second')['detail'],
        contains('int?'));
  });
  test('signature help uses cached Quds and native parameter names', () {
    for (final native in [false, true]) {
      final session = LspSession();
      final uri = File('test/editor_buffer.quds').absolute.uri.toString();
      final source = native
          ? 'use "fixtures/dart_generics/api.dart"\nmain():\n  print nativeNamed<int>(\n'
          : 'sum(a: int, b: int) -> int = a + b\nmain():\n  print sum(1, \n';
      open(session, uri, source);
      final text = source.split('\n')[2];
      final result = session.handle({
        'id': 1,
        'method': 'textDocument/signatureHelp',
        'params': {
          'textDocument': {'uri': uri},
          'position': {'line': 2, 'character': text.length}
        }
      }).response!['result'] as Map;
      final signatures = result['signatures'] as List;
      expect('${(signatures.first as Map)['label']}',
          contains(native ? 'value: T' : 'b: int'));
      expect(result['activeParameter'], native ? 0 : 1);
      session.dispose();
    }
  });
  test(
      'generated helpers and const lint comments retain exact breakpoint lines',
      () {
    const source =
        'class Payload:\n  value: int = 0\nmain():\n  const unused = 1\n  print 3\n';
    final c = compile(source, file: 'mapped.quds');
    final positions = SourcePositions.parse(c.sourceMap!);
    final generated = positions.generated('mapped.quds', 5)!;
    expect(c.dart.split('\n')[generated - 1], contains('print(3)'));
    final range = compile('main():\n  for value in 1..2:\n    print value\n',
        file: 'range.quds');
    final mapped =
        SourcePositions.parse(range.sourceMap!).generated('range.quds', 3)!;
    expect(range.dart.split('\n')[mapped - 1], contains('print('));
  });
  test('VS Code signature provider maps parameters and respects cancellation',
      () async {
    final result =
        await Process.run('node', ['test/editor/vscode_signature.cjs']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, 'VSCODE SIGNATURE OK\n');
  });
  test('editor analysis preserves backend boundary diagnostics', () {
    expect(
        () => compile(
            'use dart:io\nexpose(file: File) -> readonly File = file\n',
            emitDart: false),
        throwsA(predicate((e) => '$e'.contains('E910'))));
  });
  test('completion hides private imported fields', () {
    final result = items('''use "fixtures/readonly_classes/base.quds"
main():
  parent = ExternalParent<int>(value: 1)
  print parent.
''', 'parent.');
    expect(result.map((i) => i['label']), contains('read'));
    expect(result.map((i) => i['label']), isNot(contains('value')));
  });
  test('indentation call blocks suggest unused parameter names', () {
    final result = items('''configure(width: int, height: int):
  return
main():
  configure:
    width: 1
    he
''', '    he');
    final labels = result
        .where((i) => i['kind'] == 5 && '${i['textEdit']}'.contains(': '))
        .map((i) => i['label']);
    expect(labels, contains('height'));
    expect(labels, isNot(contains('width')));
  });
  test(
      'Arabic identifiers have member completion and correct replacement ranges',
      () {
    final result = items('''class صندوق:
  عدد: int = 1
  اقرأ() -> int = عدد
main():
  قيمة = صندوق()
  print قيمة.
''', 'قيمة.');
    expect(result.map((i) => i['label']), containsAll(['عدد', 'اقرأ']));
  });
  test('native argument suggestions hide backend type identities', () {
    final result = items(
        'use "fixtures/dart_generics/api.dart"\nmain():\n  print nativeFieldValue(\n',
        'nativeFieldValue(');
    final parameter =
        result.firstWhere((i) => i['label'] == 'value' && i['kind'] == 5);
    expect(parameter['detail'], 'NativeField<int>');
    expect('${parameter['detail']}', isNot(contains('@dart.')));
  });
  test('qualified debugger frame names use source function names', () {
    const source = 'calc(n: int) -> int = n + 1\nmain():\n  print calc(1)\n';
    final c = compile(source, file: 'frames.quds');
    final function =
        c.program.statements.whereType<FunctionDeclaration>().first;
    final name = c.semantics.declarations[function]!.dartName;
    final translator = DebugTranslator()
      ..bind(DebugBinary('frames.quds', 'frames.dart', c.sourceMap!));
    final result = translator.present({
      'type': 'response',
      'command': 'stackTrace',
      'body': {
        'stackFrames': [
          {
            'id': 1,
            'name': 'Holder.$name',
            'line':
                SourcePositions.parse(c.sourceMap!).generated('frames.quds', 1),
            'source': {'path': 'frames.dart'}
          }
        ]
      }
    });
    expect(
        (((result['body'] as Map)['stackFrames'] as List).single
            as Map)['name'],
        'Holder.calc');
  });
  test('background startup analyzes every open document and latest versions',
      () async {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    final seen = <String, Map>{};
    session.emit = (event) {
      seen[(event['params'] as Map)['uri'] as String] = event;
    };
    final first = File('/tmp/editor_queue_a.quds').uri.toString();
    final second = File('/tmp/editor_queue_b.quds').uri.toString();
    open(session, first, 'main():\n  print 1\n');
    open(session, second, 'main():\n  print 2\n');
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (seen.length < 2 && DateTime.now().isBefore(deadline))
      await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen.keys, containsAll([first, second]));
    final pending = response(session, first, 1, 7);
    expect(pending['isIncomplete'], isFalse);
    session.handle({
      'method': 'textDocument/didChange',
      'params': {
        'textDocument': {'uri': first, 'version': 2},
        'contentChanges': [
          {'text': 'main():\n  print missingName\n'}
        ]
      }
    });
    expect(response(session, first, 1, 7)['isIncomplete'], isTrue);
  });
}
