import "package:quds_lang/src/navigate.dart" show hoverAt;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/dart_doc_preview.dart';
import 'package:quds_lang/src/dart_api.dart';
import 'package:test/test.dart';

void main() {
  test(
      'Dart Flutter-style examples become parseable Quds only for presentation',
      () {
    const source = r'''Widget build(BuildContext context) {
  final theme = Theme.of(context);
  return Text('Hello $name', style: theme.textTheme.titleLarge);
}''';
    final converted = dartExampleToQuds(source);
    expect(converted, isNotNull);
    expect(converted, contains('build(context: BuildContext) -> Widget:'));
    expect(converted, contains('theme = Theme.of(context)'));
    expect(converted, contains('Hello {name}'));
    Parser(Lexer().tokenize(converted!)).parse();
    final markdown =
        'Intro\n\n```dart\n$source\n```\n\n[Reference](https://example.com)';
    final preview = presentDartExamples(markdown);
    expect(preview, contains('```quds'));
    expect(preview, contains('[Reference](https://example.com)'));
    expect(markdown, contains('```dart'));
    expect(presentDartExamples('```quds\nvar n = 1\n```'),
        '```quds\nvar n = 1\n```');
  });
  test(
      'unsupported comments, cascades, const calls and incomplete blocks keep Dart',
      () {
    for (final source in [
      'final x = foo()..bar();',
      'return const Text("hi");',
      '// important\nfinal x = 1;',
      'class Example {}',
      'final count = value.round();',
      'final colors = {"green": 1};',
      'if ('
    ]) {
      expect(dartExampleToQuds(source), isNull, reason: source);
      expect(presentDartExamples('```dart\n$source\n```'), contains(source));
    }
    expect(dartExampleToQuds('x' * 8001), isNull);
  });
  test(
      'translated bindings, interpolation and control flow execute like the Dart example',
      () async {
    const dartSource = r'''Future<int> answer() async { return 42; }
Future<void> main() async {
  int total = 1;
  total += 2;
  final name = 'Quds';
  final literal = r'$name {literal}';
  if (total > 1 && name != '') {
    print('Hello $name: ${total + 1}');
  } else {
    print('no');
  }
  print(literal);
  print(await answer());
}''';
    final quds = dartExampleToQuds(dartSource);
    expect(quds, isNotNull);
    expect(quds, contains('var total: int = 1'));
    final root = Directory.systemTemp.createTempSync('quds-doc-preview-');
    addTearDown(() => root.deleteSync(recursive: true));
    final generated = compile(quds!);
    writeSdkBundles(root.path, generated);
    final target = File('${root.path}/preview.dart')
      ..writeAsStringSync(generated.dart);
    final original = File('${root.path}/original.dart')
      ..writeAsStringSync(dartSource);
    final expected =
        await Process.run(Platform.resolvedExecutable, [original.path]);
    final actual =
        await Process.run(Platform.resolvedExecutable, [target.path]);
    expect(expected.exitCode, 0, reason: '${expected.stderr}');
    expect(actual.exitCode, 0, reason: '${actual.stderr}');
    expect(actual.stdout, expected.stdout);
  });
  test(
      'native of hover presents converted docs and preserves original Dart metadata',
      () {
    final root = Directory.systemTemp.createTempSync('quds-doc-hover-');
    addTearDown(() => root.deleteSync(recursive: true));
    final api = File('${root.path}/api.dart')
      ..writeAsStringSync('''class Theme {
/// Reads the theme.
///
/// ```dart
/// final theme = Theme.of(context);
/// ```
static int of(Object context) => 1;
}
''');
    const source =
        'use api.dart\nmain():\n  value = Theme.of(1)\n  print value\n';
    final compilation =
        compile(source, file: '${root.path}/main.quds', emitDart: false);
    final hover = hoverAt(
        compilation, source, 3, source.split('\n')[2].indexOf('of') + 1);
    expect(hover, contains('```quds'));
    expect(hover, contains('theme = Theme.of(context)'));
    expect(presentDartExamples(hover!), contains('translated for display'));
    final metadata = readDartFile(api)!;
    expect(metadata.types['Theme']!.statics['of']!.documentation,
        contains('final theme ='));
    expect(api.readAsStringSync(), contains('```dart'));
    final session = LspSession();
    addTearDown(session.dispose);
    final uri = File('${root.path}/main.quds').uri.toString();
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {'uri': uri, 'version': 1, 'text': source}
      }
    });
    final result = session.handle({
      'id': 8,
      'method': 'textDocument/hover',
      'params': {
        'textDocument': {'uri': uri},
        'position': {
          'line': 2,
          'character': source.split('\n')[2].indexOf('of')
        }
      }
    }).response!['result'] as Map;
    expect(result['qudsNativeDocumentation'], true);
    expect(result['contents']['kind'], 'markdown');
    expect(result['contents']['value'], isNot(contains('quds-native-doc')));
  });
  test(
      'optional documentation worker accepts queued requests and preserves Unicode',
      () async {
    final child = await Process.start(Platform.resolvedExecutable,
        [File('bin/quds.dart').absolute.path, 'doc-preview']);
    final ready = Completer<void>();
    final answer = Completer<String>();
    final errors = StringBuffer();
    child.stderr.transform(utf8.decoder).listen(errors.write);
    final subscription = child.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final value = jsonDecode(line) as Map;
      if (value['ready'] == true && !ready.isCompleted) ready.complete();
      if (value['id'] == 7 && !answer.isCompleted)
        answer.complete(value['markdown'] as String);
    });
    child.stdin.writeln(
        jsonEncode({'id': 7, 'markdown': '```dart\nfinal name = "قدس";\n```'}));
    try {
      await ready.future.timeout(const Duration(seconds: 90));
      expect(await answer.future.timeout(const Duration(seconds: 10)),
          contains('name = "قدس"'));
      await child.stdin.close();
      expect(await child.exitCode.timeout(const Duration(seconds: 5)), 0,
          reason: errors.toString());
    } finally {
      child.kill();
      await subscription.cancel();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
      'VS Code keeps cold previews responsive and transforms only native tooltips',
      () async {
    final result =
        await Process.run('node', ['test/editor/vscode_doc_preview.cjs']);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(result.stdout, contains('VSCODE DOC PREVIEW OK'));
  });
}
