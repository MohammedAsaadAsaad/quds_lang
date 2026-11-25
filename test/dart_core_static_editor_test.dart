import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void _open(LspSession session, String uri, String source, {int version = 1}) {
  session.handle({
    'method': 'textDocument/didOpen',
    'params': {
      'textDocument': {'uri': uri, 'version': version, 'text': source},
    },
  });
}

List<Map> _complete(LspSession session, String uri, int line, int character) {
  final result = session.handle({
    'id': 1,
    'method': 'textDocument/completion',
    'params': {
      'textDocument': {'uri': uri},
      'position': {'line': line, 'character': character},
    },
  }).response!['result'] as Map;
  return (result['items'] as List).cast<Map>();
}

Map? _hover(LspSession session, String uri, int line, int character) {
  return session.handle({
    'id': 2,
    'method': 'textDocument/hover',
    'params': {
      'textDocument': {'uri': uri},
      'position': {'line': line, 'character': character},
    },
  }).response!['result'] as Map?;
}

Map _definition(LspSession session, String uri, int line, int character) {
  return (session.handle({
        'id': 3,
        'method': 'textDocument/definition',
        'params': {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': character},
        },
      }).response!['result'] as Map?) ??
      const {};
}

Map? _signatureHelp(LspSession session, String uri, int line, int character) {
  return session.handle({
    'id': 4,
    'method': 'textDocument/signatureHelp',
    'params': {
      'textDocument': {'uri': uri},
      'position': {'line': line, 'character': character},
    },
  }).response!['result'] as Map?;
}

void main() {
  test('implicit dart:core static methods, factories, and generics execute',
      () async {
    const source = '''class Box<T>:
  value: T required
  init of(this.value):
    assert true

main() async:
  m = int.parse("55")
  hex = int.parse("ff", radix: 16)
  bad = int.tryParse("nope")
  f = double.parse("3.5")
  ch = String.fromCharCode(65)
  xs = List<int>.filled(3, 7)
  ys = List.generate(3, (i) -> i + 1)
  s = Set<int>.of([1, 2, 1])
  d = DateTime.utc(2026, 11, 23)
  dur = Duration(seconds: 5)
  u = Uri.parse("https://example.com/a")
  esc = RegExp.escape("a+b")
  v = await Future<int>.value(9)
  v2 = await Future.value(10)
  b = Box<int>.of(42)
  print "{m}|{hex}|{bad}|{f}|{ch}|{xs.length}|{ys[2]}|{s.length}|{d.year}|{dur.inSeconds}|{u.host}|{esc}|{v}|{v2}|{b.value}"
''';
    final compiled = compile(source, file: 'core_statics.quds');
    final directory = Directory.systemTemp.createTempSync('quds-core-statics-');
    addTearDown(() => directory.deleteSync(recursive: true));
    for (final bundle in compiled.bundles) {
      File('${directory.path}/${bundle.fileName}')
          .writeAsStringSync(bundle.source);
    }
    final dartFile = File('${directory.path}/core_statics.dart')
      ..writeAsStringSync(compiled.dart);
    final analyzed = await Process.run(
        Platform.resolvedExecutable, ['analyze', dartFile.path]);
    expect(analyzed.exitCode, 0,
        reason: '${analyzed.stdout}\n${analyzed.stderr}\n${compiled.dart}');
    final run = await Process.run(Platform.resolvedExecutable, [dartFile.path]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(
      run.stdout,
      '55|255|null|3.5|A|3|3|2|2026|5|example.com|a\\+b|9|10|42\n',
    );
  });

  test('instance members on dart:core types are rejected and shadowing works',
      () {
    expect(
      () => compile('main():\n  print int.toDouble()\n', file: 'bad_int.quds'),
      throwsA(isA<CompilerException>()
          .having((e) => e.message, 'message', contains('Instance member'))),
    );
    expect(
      () => compile('main():\n  print String.length\n', file: 'bad_str.quds'),
      throwsA(isA<CompilerException>()
          .having((e) => e.message, 'message', contains('Instance member'))),
    );
    expect(
      () =>
          compile('main():\n  print List<int>.add(1)\n', file: 'bad_list.quds'),
      throwsA(isA<CompilerException>()
          .having((e) => e.message, 'message', contains('Instance member'))),
    );
    // Quds prelude Error still builds Result and user classes can shadow dart:core.
    final shadowed = compile('''class Match:
  label: String required
parseOne(raw: String) -> Result<int, String>:
  parsed = int.tryParse(raw)
  if parsed == null:
    return Error("bad")
  return Ok(parsed)
main():
  m = Match(label: "ok")
  print m.label
  print parseOne("7")
''', file: 'shadow_core.quds');
    expect(shadowed.dart, contains('class Match'));
  });

  test('completion lists static methods and factories for core and Quds types',
      () {
    List<Map> completeAtTarget(String source, String target) {
      final session = LspSession();
      addTearDown(session.dispose);
      final uri = File('test/core_complete.quds').absolute.uri.toString();
      _open(session, uri, source);
      final lines = source.split('\n');
      final line = lines.indexWhere((l) => l.contains(target));
      return _complete(
          session, uri, line, lines[line].indexOf(target) + target.length);
    }

    final intItems = completeAtTarget('main():\n  m = int.\n', 'int.');
    final intLabels = intItems.map((i) => i['label']).toList();
    expect(intLabels, containsAll(['parse', 'tryParse', 'fromEnvironment']));
    expect(intLabels, isNot(contains('isEven')));

    final doubleLabels = completeAtTarget('main():\n  d = double.\n', 'double.')
        .map((i) => i['label']);
    expect(doubleLabels, containsAll(['parse', 'tryParse', 'infinity', 'nan']));

    final strLabels =
        completeAtTarget('use quds:text\nmain():\n  s = String.\n', 'String.')
            .map((i) => i['label']);
    expect(strLabels,
        containsAll(['fromCharCode', 'fromCharCodes', 'fromEnvironment']));
    expect(strLabels, isNot(contains('blank')));

    final listLabels =
        completeAtTarget('main():\n  xs = List<int>.\n', 'List<int>.')
            .map((i) => i['label']);
    expect(listLabels,
        containsAll(['filled', 'empty', 'generate', 'from', 'of', 'castFrom']));

    final dateLabels =
        completeAtTarget('main():\n  d = DateTime.\n', 'DateTime.')
            .map((i) => i['label']);
    expect(
        dateLabels, containsAll(['now', 'utc', 'parse', 'tryParse', 'monday']));

    final futureLabels = completeAtTarget('main():\n  f = Future.\n', 'Future.')
        .map((i) => i['label']);
    expect(
        futureLabels, containsAll(['value', 'delayed', 'wait', 'microtask']));

    final qudsLabels = completeAtTarget('''class Token<T>:
  static count: int = 0
  static helper() -> int = 1
  value: T required
  init of(this.value):
    assert true
  factory init empty(fallback: T) -> Token<T> = Token<T>.of(fallback)
main():
  t = Token<int>.
''', 'Token<int>.').map((i) => i['label']);
    expect(qudsLabels, containsAll(['count', 'helper', 'of', 'empty']));

    // Instance completion on int has no duplicate labels and exposes SDK members.
    final intInstance = completeAtTarget('main():\n  n = 5\n  print n.\n', 'n.')
        .map((i) => i['label'])
        .toList();
    expect(intInstance.toSet().length, intInstance.length);
    expect(intInstance, containsAll(['abs', 'toDouble', 'bitLength']));
  });

  test(
      'signature help and named arguments work on core statics and Quds factories',
      () {
    final session = LspSession();
    addTearDown(session.dispose);
    final uriA = File('test/core_sig_a.quds').absolute.uri.toString();
    const sourceA = 'main():\n  a = int.parse("ff", \n';
    _open(session, uriA, sourceA);
    final lineA = sourceA.split('\n')[1];
    final intSig = _signatureHelp(session, uriA, 1, lineA.length);
    expect('${((intSig?['signatures'] as List).first as Map)['label']}',
        contains('radix: int?'));
    expect(intSig?['activeParameter'], 1);

    final intNamed =
        _complete(session, uriA, 1, lineA.length).map((i) => i['label']);
    expect(intNamed, contains('radix'));

    final uriB = File('test/core_sig_b.quds').absolute.uri.toString();
    const sourceB = '''class Token:
  value: int required
  init(this.value):
    assert true
  factory init fromText(raw: String, radix: int = 10) -> Token = Token(int.parse(raw, radix: radix))
main():
  b = Token.fromText("ff", 
''';
    _open(session, uriB, sourceB);
    final lineB = sourceB.split('\n')[6];
    final qudsSig = _signatureHelp(session, uriB, 6, lineB.length);
    expect('${((qudsSig?['signatures'] as List).first as Map)['label']}',
        contains('radix: int'));
    expect(qudsSig?['activeParameter'], 1);
  });

  test(
      'go-to-definition and hover work on int, parse, type annotations, and Quds factories',
      () {
    final session = LspSession();
    addTearDown(session.dispose);
    final uri = File('test/core_nav.quds').absolute.uri.toString();
    const source = '''class Token:
  value: int required
  init(this.value):
    assert true
  factory init fromText(raw: String) -> Token = Token(int.parse(raw))

main():
  a: int = 5
  m = int.parse("55")
  t = Token.fromText("55")
  print "{a} {m} {t.value}"
''';
    _open(session, uri, source);
    final lines = source.split('\n');

    // Type annotation `int` on line 7 (`  a: int = 5`)
    final typeCol = lines[7].indexOf('int');
    final typeDef = _definition(session, uri, 7, typeCol);
    expect('${typeDef['uri']}', endsWith('/lib/core/int.dart'));
    final typeHover = _hover(session, uri, 7, typeCol);
    expect(
        '${(typeHover?['contents'] as Map?)?['value']}', contains('class int'));

    // `int` in `m = int.parse("55")` on line 8
    final intCol = lines[8].indexOf('int');
    final intDef = _definition(session, uri, 8, intCol);
    expect('${intDef['uri']}', endsWith('/lib/core/int.dart'));
    final intHover = _hover(session, uri, 8, intCol);
    expect(
        '${(intHover?['contents'] as Map?)?['value']}', contains('class int'));

    // `parse` in `m = int.parse("55")` on line 8
    final parseCol = lines[8].indexOf('parse');
    final parseDef = _definition(session, uri, 8, parseCol);
    expect('${parseDef['uri']}', endsWith('/lib/core/int.dart'));
    expect(((parseDef['range'] as Map)['start'] as Map)['line'] as int,
        greaterThan(50));
    final parseHover = _hover(session, uri, 8, parseCol);
    expect('${(parseHover?['contents'] as Map?)?['value']}',
        contains('parse(source: String, radix: int?) -> int'));

    // Quds factory `fromText` in `Token.fromText("55")` on line 9
    final factoryCol = lines[9].indexOf('fromText');
    final factoryDef = _definition(session, uri, 9, factoryCol);
    expect(factoryDef['uri'], uri);
    expect(((factoryDef['range'] as Map)['start'] as Map)['line'], 4);
    final factoryHover = _hover(session, uri, 9, factoryCol);
    expect('${(factoryHover?['contents'] as Map?)?['value']}',
        contains('factory Token.fromText(raw: String) -> Token'));
  });

  test('live hover never shows stale print: void on an edited failing line',
      () async {
    final session = LspSession()..background = true;
    addTearDown(session.dispose);
    var published = 0;
    session.emit = (event) {
      if (event['method'] == 'textDocument/publishDiagnostics' &&
          (event['params'] as Map)['qudsAnalysisComplete'] != false) {
        published++;
      }
    };
    final uri = File('/tmp/quds_live_stale_hover.quds').uri.toString();
    _open(session, uri, 'main():\n  print 1\n');
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (published < 1 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(published, greaterThanOrEqualTo(1));

    // Edit line 1 so it fails to compile while mentioning int.parse.
    session.handle({
      'method': 'textDocument/didChange',
      'params': {
        'textDocument': {'uri': uri, 'version': 2},
        'contentChanges': [
          {'text': 'main():\n  m = int.parse("55") + missingSymbol\n'}
        ],
      },
    });
    while (published < 2 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final hoverInt = _hover(session, uri, 1, 7);
    final intText = '${(hoverInt?['contents'] as Map?)?['value']}';
    expect(intText, isNot(contains('print: void')));
    expect(intText, contains('class int'));

    final hoverParse = _hover(session, uri, 1, 11);
    final parseText = '${(hoverParse?['contents'] as Map?)?['value']}';
    expect(parseText, contains('parse(source: String, radix: int?) -> int'));

    final defParse = _definition(session, uri, 1, 11);
    expect('${defParse['uri']}', endsWith('/lib/core/int.dart'));

    // Also verify uncompiled live completion on int. works.
    session.handle({
      'method': 'textDocument/didChange',
      'params': {
        'textDocument': {'uri': uri, 'version': 3},
        'contentChanges': [
          {'text': 'main():\n  x = missingSymbol\n  m = int.\n'}
        ],
      },
    });
    final liveItems = _complete(session, uri, 2, 10).map((i) => i['label']);
    expect(liveItems, containsAll(['parse', 'tryParse', 'fromEnvironment']));
  });
}
