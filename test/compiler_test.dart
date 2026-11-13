import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/flutter_project.dart';
import 'package:test/test.dart';

void main() {
  test('acceptance output is deterministic and matches golden Dart', () {
    final source = File('examples/sum.quds').readAsStringSync();
    final output = compile(source, file: 'examples/sum.quds').dart;
    expect(output, File('test/goldens/sum.dart.txt').readAsStringSync());
    expect(compile(source).dart, output);
  });
  test('literal dollar, braces, escaped quotes and triple strings', () async {
    await execute(r'''main():
  print "\{literal\} $notDart \"quoted\""
  print """first
second"""
''', '{literal} \$notDart "quoted"\nfirst\nsecond\n');
  });
  test('quoted interpolation expressions use the same parser', () async {
    await execute('''echo(value: String) = value
main():
  print "nested {echo("hello")}"
''', 'nested hello\n');
  });
  test('acceptance generated Dart analyzes and executes', () async {
    await execute(
        File('examples/sum.quds').readAsStringSync(), 'Total: 60\n12\n');
  });
  test('named blocks preserve written evaluation order, exactly once',
      () async {
    await execute('''mark(value: int) -> int:
  print value
  return value
subtract(a: int, b: int) = a - b
main():
  answer = subtract:
    b: mark(2)
    a: mark(1)
  print answer
  print subtract(mark(3), b: mark(4))
''', '2\n1\n-1\n3\n4\n-1\n');
  });
  test('scopes, shadow, const, branches, lists and Unicode execute', () async {
    await execute('''main():
  const قاعدة = 2
  var total = 0
  for item in [1, 2, 3]:
    total += item
  if total == 6 and not false:
    shadow total = total + قاعدة
    print total
  else:
    print 0
  print total
''', '8\n6\n');
  });
  test('boolean operators short circuit and arithmetic is left associative',
      () async {
    await execute('''flag(value: bool) = value
mark() -> bool:
  print 999
  return true
main():
  print(flag(false) and mark())
  print(flag(true) or mark())
  print(10 - 3 - 2)
  print(1 + 2 * 3)
''', 'false\ntrue\n5\n7\n');
  });
  test('CLI build, diagnostics, usage, and overwrite protection', () async {
    final directory = Directory.systemTemp.createTempSync('quds-cli-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('main():\n  print 42\n');
    final output = builtDart(source);
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final built = await cli(['build', source.path]);
    expect(built.exitCode, 0, reason: '${built.stderr}');
    expect(File('${directory.path}/app.dart').existsSync(), isFalse);
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(run.stdout, '42\n');
    expect((await cli(['build', source.path])).exitCode, 0);
    output.writeAsStringSync('user file');
    expect((await cli(['build', source.path])).exitCode, 73);
    expect(output.readAsStringSync(), 'user file');
    source.writeAsStringSync('main():\n  print unknown\n');
    final bad = await cli(['build', source.path]);
    expect(bad.exitCode, 65);
    expect(bad.stderr, contains('${source.path}:2:9: E200'));
    expect(output.readAsStringSync(), 'user file');
    expect((await cli([])).exitCode, 64);
    expect(
        (await cli(['build', '${directory.path}/missing.quds'])).exitCode, 74);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('build writes under the package out directory', () async {
    final root = Directory.systemTemp.createTempSync('quds-out-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    final source = File('${root.path}/lib/app.quds')
      ..createSync(recursive: true)
      ..writeAsStringSync('main():\n  print 7\n');
    final built = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', source.path]);
    expect(built.exitCode, 0, reason: '${built.stderr}');
    final output = File('${root.path}/.dart_tool/quds/out/lib/app.dart');
    expect(output.existsSync(), isTrue);
    expect(File('${root.path}/lib/app.dart').existsSync(), isFalse);
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.stdout, '7\n', reason: '${run.stderr}');
  });

  test('sha256 matches the empty and abc vectors', () {
    expect(sha256Hex(const []),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('build caches unchanged sources and rebuilds a changed import',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-cache-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final math = File('${directory.path}/math.quds')
      ..writeAsStringSync('doubleIt(n: int) -> int = n * 2\n');
    final app = File('${directory.path}/app.quds')
      ..writeAsStringSync('use "math.quds"\nmain():\n  print doubleIt(4)\n');
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final first = await cli(['build', app.path]);
    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    expect(first.stdout, contains('Built'));
    expect(Directory('${directory.path}/.dart_tool/quds/cache').existsSync(),
        isTrue);
    final run =
        await Process.run(Platform.resolvedExecutable, [builtDart(app).path]);
    expect(run.stdout, '8\n', reason: '${run.stderr}');
    final again = await cli(['build', app.path]);
    expect(again.exitCode, 0, reason: '${again.stderr}');
    expect(again.stdout, contains('Unchanged'));
    expect(again.stdout.contains('Built'), isFalse);
    math.writeAsStringSync('doubleIt(n: int) -> int = n * 3\n');
    final rebuilt = await cli(['build', app.path]);
    expect(rebuilt.exitCode, 0, reason: '${rebuilt.stdout}\n${rebuilt.stderr}');
    expect(rebuilt.stdout, contains('Built'));
    final after =
        await Process.run(Platform.resolvedExecutable, [builtDart(app).path]);
    expect(after.stdout, '12\n', reason: '${after.stderr}');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('build rebuilds when a macro in the same source changes', () async {
    final directory = Directory.systemTemp.createTempSync('quds-macro-cache-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')..writeAsStringSync('''
@macro
class Greetings:
  hello(who: String) -> String = "Hi {who}"
  define(builder: Builder):
    builder.addMethod(hello)
@Greetings
class Person:
  name: String
main():
  print Person(name: "Ada").hello("Ada")
''');
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final first = await cli(['build', source.path]);
    expect(first.exitCode, 0, reason: '${first.stdout}\n${first.stderr}');
    expect(builtDart(source).readAsStringSync(), contains('Hi'));
    final again = await cli(['build', source.path]);
    expect(again.stdout, contains('Unchanged'));
    source.writeAsStringSync(source.readAsStringSync().replaceAll('Hi', 'Yo'));
    final rebuilt = await cli(['build', source.path]);
    expect(rebuilt.exitCode, 0, reason: '${rebuilt.stdout}\n${rebuilt.stderr}');
    expect(rebuilt.stdout, contains('Built'));
    expect(builtDart(source).readAsStringSync(), contains('Yo'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('quds build --watch rebuilds after the source changes', () async {
    final directory = Directory.systemTemp.createTempSync('quds-watch-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('main():\n  print 1\n');
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'build',
      '--watch',
      source.path,
    ]);
    addTearDown(() => process.kill());
    final output = StringBuffer();
    process.stdout.transform(utf8.decoder).listen(output.write);
    final errors = StringBuffer();
    process.stderr.transform(utf8.decoder).listen(errors.write);
    Future<void> waitFor(String text) async {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!output.toString().contains(text)) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for $text\n$output\n$errors');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    await waitFor('Built');
    source.writeAsStringSync('main():\n  print 2\n');
    final built = output.toString().split('Built').length;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (output.toString().split('Built').length <= built) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for a second build\n$output\n$errors');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(builtDart(source).readAsStringSync(), contains('print(2)'));
    process.kill();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a macro that expands itself or its peer is E904', () {
    expect(() => compile('''
@A
@macro
class A:
  hello() -> int = 1
  define(builder: Builder):
    builder.addMethod(hello)
@A
class User:
  name: String = "a"
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E904'))));
    expect(() => compile('''
@B
@macro
class A:
  hello() -> int = 1
  define(builder: Builder):
    builder.addMethod(hello)
@A
@macro
class B:
  hello() -> int = 2
  define(builder: Builder):
    builder.addMethod(hello)
@A
class User:
  name: String = "a"
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E904'))));
  });

  test('macro source text and a forbidden capability are E905', () {
    expect(
        () => compile('''
@macro
class Text:
  hello() -> int = 1
  define(builder: Builder):
    builder.addMethod("class Extra:")
@Text
class User:
  name: String = "a"
main():
  print 1
'''),
        throwsA(predicate((error) =>
            '$error'.contains('E905') && '$error'.contains('source text'))));
    expect(() => compile('''
@macro
class Clock:
  hello() -> int = 1
  define(builder: Builder):
    now = DateTime.now()
    builder.addMethod(hello)
@Clock
class User:
  name: String = "a"
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E905'))));
  });

  test('macro depth past 8 and more than 1000 declarations are E906', () {
    final chain = StringBuffer();
    for (var i = 9; i >= 1; i--) {
      if (i < 9) chain.writeln('@M${i + 1}');
      chain.writeln('@macro');
      chain.writeln('class M$i:');
      chain.writeln('  hello() -> int = $i');
      chain.writeln('  define(builder: Builder):');
      chain.writeln('    builder.addMethod(hello)');
    }
    chain
      ..writeln('@M1')
      ..writeln('class User:')
      ..writeln('  name: String = "a"')
      ..writeln('main():')
      ..writeln('  print 1');
    expect(() => compile(chain.toString()),
        throwsA(predicate((error) => '$error'.contains('E906'))));
    final calls = List.filled(1001, '    builder.addMethod(hello)').join('\n');
    expect(() => compile('''
@macro
class Big:
  hello() -> int = 1
  define(builder: Builder):
$calls
@Big
class User:
  name: String = "a"
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E906'))));
  });

  test('mapStack rewrites a hitting frame and leaves the other frame', () {
    final compiled = compile('main():\n  print 1\n', file: 'app.quds');
    final map = compiled.sourceMap!;
    final data = jsonDecode(map) as Map<String, Object?>;
    final sections = (data['mappings'] as String).split(';');
    var line = 1;
    for (var i = 0; i < sections.length; i++) {
      if (sections[i].isNotEmpty) {
        line = i + 1;
        break;
      }
    }
    final stack = '#0      main (file:///tmp/app.dart:$line:1)\n'
        '#1      other (file:///tmp/other.dart:4:2)\n'
        '#2      missed (file:///tmp/app.dart:99:1)';
    final mapped = mapStack(stack, map);
    expect(mapped, contains('app.quds:'));
    expect(mapped, contains('other.dart:4:2'));
    expect(mapped, contains('app.dart:99:1'));
    final asyncStack = '#0      main (file:///tmp/app.dart:$line:1)\n'
        '<asynchronous suspension>\n'
        '#1      _startIsolate.<anonymous closure> (file:///tmp/app.dart:$line:1)\n';
    final asyncMapped = mapStack(asyncStack, map);
    expect(asyncMapped, contains('app.quds:'));
    expect(asyncMapped, contains('<asynchronous suspension>'));
    expect(asyncMapped.split('app.quds:').length, 3);
    final script = encodeSourceMap(
        'app.dart.js', 'app.dart', [(1, const SourceSpan(3, 1, 1))]);
    final quds = encodeSourceMap(
        'app.dart', 'app.quds', [(3, const SourceSpan(2, 4, 1))]);
    final once = mapStack('#0      main (file:///tmp/app.dart.js:1:1)', script);
    expect(once, contains('app.dart:3:1'));
    expect(mapStack(once, quds), contains('app.quds:2:4'));
    expect(mapStack('#0      a (file:///tmp/app.dart.js:1:1)', script),
        contains('app.dart:3:1'));
  });

  test('debug translator maps a quds breakpoint to the generated line', () {
    const source = 'main():\n  print 1\n\n  print 2\n';
    const qudsPath = '/tmp/app.quds';
    const dartPath = '/tmp/out/app.dart';
    final compiled = compile(source, file: qudsPath);
    final positions = SourcePositions.parse(compiled.sourceMap!);
    final translator = DebugTranslator()
      ..bind(DebugBinary(qudsPath, dartPath, compiled.sourceMap!));
    final launch = translator.accept({
      'seq': 1,
      'type': 'request',
      'command': 'launch',
      'arguments': {'program': qudsPath},
    });
    expect(launch.reply, isNull);
    expect(launch.message!['arguments']['program'], dartPath);
    expect(launch.message!['arguments']['cwd'], '/tmp');

    final generated = positions.generated(qudsPath, 4);
    expect(generated, isNotNull);
    expect(positions.generated(qudsPath, 3), isNull);
    final set = translator.accept({
      'seq': 2,
      'type': 'request',
      'command': 'setBreakpoints',
      'arguments': {
        'source': {'path': qudsPath, 'name': 'app.quds'},
        'breakpoints': [
          {'line': 4},
          {'line': 3},
        ],
      },
    });
    final forwarded = (set.message!['arguments']['breakpoints'] as List)
        .cast<Map<dynamic, dynamic>>();
    expect(forwarded, [
      {'line': generated}
    ]);
    expect(set.message!['arguments']['source']['path'], dartPath);
    final presented = translator.present({
      'seq': 9,
      'type': 'response',
      'request_seq': 2,
      'success': true,
      'command': 'setBreakpoints',
      'body': {
        'breakpoints': [
          {'verified': true, 'line': generated}
        ],
      },
    });
    final breakpoints =
        (presented['body'] as Map)['breakpoints'] as List<dynamic>;
    expect(breakpoints, [
      {'verified': true, 'line': 4},
      {'verified': false, 'line': 3},
    ]);
    final stack = translator.present({
      'type': 'response',
      'command': 'stackTrace',
      'body': {
        'stackFrames': [
          {
            'id': 1,
            'name': 'main',
            'line': generated,
            'column': 1,
            'source': {'path': dartPath, 'name': 'app.dart'},
          }
        ],
      },
    });
    final frame = ((stack['body'] as Map)['stackFrames'] as List).single as Map;
    expect(frame['source']['path'], qudsPath);
    expect(frame['line'], 4);
    expect(frame['source']['name'], 'app.quds');

    final failed = DebugTranslator(build: (path, fail) {
      fail('broken $path');
      return null;
    }).accept({
      'seq': 3,
      'type': 'request',
      'command': 'launch',
      'arguments': {'program': '/tmp/missing.quds'},
    });
    expect(failed.message, isNull);
    expect(failed.reply!['success'], isFalse);
    expect(failed.reply!['message'], contains('broken'));
  });

  test('quds debug stops on the quds line', () async {
    final directory = Directory.systemTemp.createTempSync('quds-debug-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('main():\n  print 1\n  print 2\n');
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'debug',
    ]);
    addTearDown(() => process.kill());
    final client = _DebugClient(process);
    client.start();
    final init = await client.request('initialize', {
      'adapterID': 'quds',
      'pathFormat': 'path',
    });
    expect(init['success'], isTrue,
        reason: '${init['message']}\n${client.stderr}');
    await client.event('initialized').timeout(const Duration(seconds: 20));
    final breakpoints = await client.request('setBreakpoints', {
      'source': {'path': source.path, 'name': 'app.quds'},
      'breakpoints': [
        {'line': 3}
      ],
    });
    final reported =
        ((breakpoints['body'] as Map)['breakpoints'] as List).single as Map;
    expect(reported['line'], 3, reason: '$reported\n${client.stderr}');
    final configured = await client.request('configurationDone');
    expect(configured['success'], isTrue, reason: '${configured['message']}');
    final launched = await client.request('launch', {
      'program': source.path,
      'cwd': directory.path,
    });
    expect(launched['success'], isTrue,
        reason: '${launched['message']}\n${client.stderr}');
    final event = await _stopForBreakpoint(client);
    final thread = (event['body'] as Map)['threadId'];
    final stack = await client.request('stackTrace', {'threadId': thread});
    final frames = (stack['body'] as Map)['stackFrames'] as List;
    final frame = frames.cast<Map>().firstWhere(
        (item) => '${item['source']?['path']}'.endsWith('app.quds'),
        orElse: () => frames.first as Map);
    expect(frame['source']['path'], source.path);
    expect(frame['line'], 3);
    await client.request('disconnect');
    await process.stdin.close();
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('definition, rename, and breakpoint use the source span', () {
    const source = 'doubleIt(n: int) -> int = n * 2\n'
        'main():\n'
        '  value = 1\n'
        '  print value\n'
        '  print doubleIt(value)\n';
    final compiled = compile(source);
    final lines = source.split('\n');
    final valueColumn = lines[3].indexOf('value') + 1;
    final defined = definitionAt(compiled, 4, valueColumn);
    expect(defined?.line, 3);
    final callColumn = lines[4].indexOf('doubleIt') + 1;
    expect(definitionAt(compiled, 5, callColumn)?.line, 1);
    final renamed = renameAt(compiled, source, 4, valueColumn, 'total');
    expect(
        renamed,
        'doubleIt(n: int) -> int = n * 2\n'
        'main():\n'
        '  total = 1\n'
        '  print total\n'
        '  print doubleIt(total)\n');
    expect(compile(renamed).dart, contains('print('));
    final printColumn = lines[3].indexOf('print') + 1;
    expect(breakpointAt(compiled, 4, printColumn)?.line, 4);
    expect(breakpointAt(compiled, 4, 1), isNull);
  });

  test('definition opens the quds declaration of a member or import', () {
    const member = 'class Cart:\n'
        '  total() -> int = 1\n'
        'main():\n'
        '  line = Cart()\n'
        '  print line.total()\n';
    final compiled = compile(member);
    final call = member.split('\n')[4];
    final memberColumn = call.indexOf('total') + 1;
    expect(definitionAt(compiled, 5, memberColumn)?.line, 2);
    final objectColumn = call.indexOf('line') + 1;
    expect(definitionAt(compiled, 5, objectColumn)?.line, 4);

    final directory = Directory.systemTemp.createTempSync('quds-definition-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final library = File('${directory.path}/math.quds')
      ..writeAsStringSync('doubleIt(n: int) -> int = n * 2\n');
    final source = 'use "math.quds"\nmain():\n  print doubleIt(4)\n';
    final uri = Uri.file('${directory.path}/app.quds').toString();
    final session = LspSession();
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'languageId': 'quds',
          'version': 1,
          'text': source,
        }
      }
    });
    final use = source.split('\n')[2];
    final defined = session.handle({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'textDocument/definition',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 2, 'character': use.indexOf('doubleIt')},
      }
    });
    final result = defined.response!['result'] as Map;
    expect(result['uri'], Uri.file(library.path).toString());
    final start = (result['range'] as Map)['start'] as Map;
    expect(start['line'], 0);
    expect(start['character'], 0);
  });

  test('package and generated libraries resolve from the package root',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-package-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: demo
environment:
  sdk: '>=3.3.0 <4.0.0'
''');
    Directory('${root.path}/lib/src').createSync(recursive: true);
    Directory('${root.path}/lib/generated').createSync(recursive: true);
    Directory('${root.path}/bin').createSync(recursive: true);
    File('${root.path}/lib/demo.quds').writeAsStringSync('''
doubleIt(n: int) -> int = n * 2
''');
    File('${root.path}/lib/src/util.quds').writeAsStringSync('''
triple(n: int) -> int = n * 3
''');
    File('${root.path}/lib/generated/user_models.quds').writeAsStringSync('''
class User:
  name: String
''');
    final app = '''
use package:demo
use package:demo/src/util
use generated:user_models
main():
  print doubleIt(4)
  print triple(4)
  print User(name: "Ada").name
''';
    final compiled = compile(app, file: '${root.path}/bin/app.quds');
    expect(compiled.dart, contains("import 'package:demo/demo.dart';"));
    expect(compiled.dart, contains("import 'package:demo/src/util.dart';"));
    expect(compiled.dart,
        contains("import 'package:demo/generated/user_models.dart';"));
    File('${root.path}/lib/demo.dart').writeAsStringSync(compile(
            File('${root.path}/lib/demo.quds').readAsStringSync(),
            file: '${root.path}/lib/demo.quds')
        .dart);
    File('${root.path}/lib/src/util.dart').writeAsStringSync(compile(
            File('${root.path}/lib/src/util.quds').readAsStringSync(),
            file: '${root.path}/lib/src/util.quds')
        .dart);
    File('${root.path}/lib/generated/user_models.dart').writeAsStringSync(
        compile(
                File('${root.path}/lib/generated/user_models.quds')
                    .readAsStringSync(),
                file: '${root.path}/lib/generated/user_models.quds')
            .dart);
    File('${root.path}/bin/app.dart').writeAsStringSync(compiled.dart);
    final run = await Process.run(
        Platform.resolvedExecutable, ['run', 'bin/app.dart'],
        workingDirectory: root.path);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, '8\n12\nAda\n');
    expect(() => compile('''
use package:other
main():
  print 1
''', file: '${root.path}/bin/missing.quds'),
        throwsA(predicate((error) => '$error'.contains('E900'))));
    final loose = compile('use package:example\nmain():\n  print 1\n');
    expect(loose.dart, contains("import 'package:example';"));
    expect(() => compile('use package:example\nmain():\n  print missingName\n'),
        throwsA(predicate((error) => '$error'.contains('Undefined'))));
  });

  test('a package dart library passes its names through to Dart', () {
    final root = Directory.systemTemp.createTempSync('quds-flutter-app-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: hello
environment:
  sdk: ">=3.3.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
''');
    Directory('${root.path}/lib').createSync();
    final compiled = compile(flutterApp, file: '${root.path}/lib/main.quds');
    expect(compiled.dart, contains("import 'package:flutter/material.dart';"));
    expect(compiled.dart, contains('runApp(MyApp())'));
    expect(compiled.dart, contains('extends StatelessWidget'));
    expect(compiled.dart, contains('extends StatefulWidget'));
    expect(compiled.dart, contains('extends State<Home>'));
    expect(compiled.dart, contains('Widget build(BuildContext '));
    expect(compiled.dart, contains('Text([count].join())'));
    expect(compiled.dart, contains('setState('));
    expect(compiled.dart, contains('home: Home()'));
    expect(compiled.dart, contains('onPressed: '));
  });

  test('quds create flutter writes the app in quds', () async {
    final root = Directory.systemTemp.createTempSync('quds-create-flutter-');
    addTearDown(() => root.deleteSync(recursive: true));
    final quds = File('bin/quds.dart').absolute.path;
    final created = await Process.run(
      Platform.resolvedExecutable,
      ['run', quds, 'create', 'flutter', 'hello'],
      workingDirectory: root.path,
    );
    final output = '${created.stdout}\n${created.stderr}';
    if (created.exitCode != 0) {
      expect(output, contains('Flutter was not found'), reason: output);
      return;
    }
    expect(File('${root.path}/hello/lib/main.quds').existsSync(), isTrue);
    expect(File('${root.path}/hello/lib/main.dart').existsSync(), isFalse);
    expect(File('${root.path}/hello/quds.yaml').readAsStringSync(),
        contains('name: hello'));
    expect(File('${root.path}/hello/pubspec.yaml').readAsStringSync(),
        contains('sdk: flutter'));
    expect(File('${root.path}/hello/.gitignore').readAsStringSync(),
        contains('lib/quds_gen/'));
    final source = File('${root.path}/hello/lib/main.quds').readAsStringSync();
    final compiled = compile(source, file: '${root.path}/hello/lib/main.quds');
    expect(compiled.dart, contains("import 'package:flutter/material.dart';"));
    expect(compiled.dart, contains('extends StatelessWidget'));
  }, timeout: const Timeout(Duration(minutes: 6)));

  test('quds run launches flutter with the generated target', () async {
    final root = Directory.systemTemp.createTempSync('quds-run-flutter-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: hello
environment:
  sdk: ">=3.3.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
''');
    Directory('${root.path}/lib').createSync();
    File('${root.path}/lib/main.quds')
        .writeAsStringSync('main():\n  print "hi"\n');
    final bin = Directory('${root.path}/fake-bin')..createSync();
    final script = File('${bin.path}/flutter');
    script.writeAsStringSync('''#!/bin/sh
printf '%s\\n' "\$*" > '${root.path}/flutter-args'
exit 0
''');
    await Process.run('chmod', ['+x', script.path]);
    final quds = File('bin/quds.dart').absolute.path;
    final env = Map<String, String>.from(Platform.environment);
    final pathSeparator = Platform.isWindows ? ';' : ':';
    env['PATH'] = '${bin.path}$pathSeparator${env['PATH']}';
    final run = await Process.run(
      Platform.resolvedExecutable,
      ['run', quds, 'run', '${root.path}/lib/main.quds'],
      environment: env,
    );
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    final generated = File('${root.path}/lib/quds_gen/main.dart');
    expect(generated.existsSync(), isTrue);
    expect(generated.readAsStringSync(), contains('void main()'));
    expect(File('${root.path}/lib/main.dart').existsSync(), isFalse);
    expect(File('${root.path}/flutter-args').readAsStringSync().trim(),
        'run -t lib/quds_gen/main.dart');
  });

  test('declare adds a function and define adds a field', () async {
    await execute('''
@macro
class Helpers:
  greet(name: String) -> String = "Hi {name}"
  declare(library: Library, builder: Builder):
    builder.addFunction(greet)
@macro
class Extra:
  tag: String = "ok"
  define(builder: Builder):
    builder.addField(tag)
@Helpers
@Extra
class Box:
  value: int = 1
main():
  print greet("Ada")
  print Box().tag
''', 'Hi Ada\nok\n');
  });

  test('define copies a property and a constructor', () async {
    await execute('''
@macro
class Labels:
  property title: String:
    get = "Ada"
  define(builder: Builder):
    builder.addProperty(title)
@macro
class Marked:
  init():
    print "made"
  define(builder: Builder):
    builder.addConstructor(init)
@Labels
@Marked
class Box:
  noop() -> int = 1
main():
  item = Box()
  print item.title
''', 'made\nAda\n');
  });

  test('a generic call method accepts named arguments', () async {
    await execute('''
class Adder<T>:
  call(a: T, b: T) -> T = a
main():
  add = Adder<int>()
  print add(b: 2, a: 1)
''', '1\n');
  });

  test('protected uses the meta annotation when that package is a dependency',
      () {
    final root = Directory.systemTemp.createTempSync('quds-meta-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: demo
environment:
  sdk: '>=3.3.0 <4.0.0'
dependencies:
  meta: ^1.0.0
''');
    final source = '''
class Box:
  protected shown: int = 1
main():
  print Box().shown
''';
    File('${root.path}/box.quds').writeAsStringSync(source);
    final marked = compile(source, file: '${root.path}/box.quds').dart;
    expect(marked, contains('@protected'));
    expect(marked, contains("import 'package:meta/meta.dart';"));
    final plain = compile(source).dart;
    expect(plain, contains('/// protected'));
  });

  test('migrate leaves a project pinned to an older language', () async {
    final directory = Directory.systemTemp.createTempSync('quds-migrate-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final yaml = File('${directory.path}/quds.yaml')
      ..writeAsStringSync('language: "1.0"\n');
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('main():\n  print 1\n');
    final migrated = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'migrate',
      yaml.path,
    ]);
    expect(migrated.exitCode, 0,
        reason: '${migrated.stdout}\n${migrated.stderr}');
    expect(yaml.readAsStringSync(), 'language: "1.0"\n');
    expect(source.readAsStringSync(), 'main():\n  print 1\n');
    expect(migrated.stdout, contains('1.0'));
  });

  test('lsp and debug answer definition, rename, and breakpoints', () async {
    final directory = Directory.systemTemp.createTempSync('quds-lsp-');
    addTearDown(() => directory.deleteSync(recursive: true));
    const source = 'main():\n  value = 1\n  print value\n';
    final file = File('${directory.path}/app.quds')..writeAsStringSync(source);
    final uri = Uri.file(file.path).toString();
    final line = source.split('\n')[2];
    final character = line.indexOf('value');
    final definition = respondLsp({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'textDocument/definition',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 2, 'character': character},
      },
    });
    final range = (definition!['result'] as Map)['range'] as Map;
    expect((range['start'] as Map)['line'], 1);
    final renamed = respondLsp({
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'textDocument/rename',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 2, 'character': character},
        'newName': 'total',
      },
    });
    final changes =
        ((renamed!['result'] as Map)['changes'] as Map)[uri] as List;
    expect((changes.single as Map)['newText'], contains('total = 1'));
    expect((changes.single as Map)['newText'], contains('print total'));
    final stopped = respondDebug({
      'jsonrpc': '2.0',
      'id': 4,
      'method': 'setBreakpoints',
      'params': {
        'source': {'path': file.path},
        'breakpoints': [
          {'line': 3}
        ],
      },
    });
    final breakpoints = (stopped!['result'] as Map)['breakpoints'] as List;
    expect((breakpoints.single as Map)['verified'], isTrue);
    expect((breakpoints.single as Map)['line'], 3);
    final process = await Process.start(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'lsp',
    ]);
    addTearDown(() => process.kill());
    process.stdin.write(encodeFrame({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': <String, Object?>{},
    }));
    await process.stdin.close();
    final output = await process.stdout.transform(utf8.decoder).join();
    expect(output, contains('definitionProvider'));
    expect(output, contains('hoverProvider'));
    expect(output, contains('completionProvider'));
    expect(output, contains('codeLensProvider'));
    expect(output, contains('documentFormattingProvider'));
  });

  test('lsp formats an open buffer and publishes its diagnostics', () {
    final directory = Directory.systemTemp.createTempSync('quds-buffer-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final uri = Uri.file('${directory.path}/app.quds').toString();
    final session = LspSession();
    final source = 'main():\n  value = 1\n  print value\n';
    final opened = session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'languageId': 'quds',
          'version': 1,
          'text': source,
        }
      }
    });
    expect(opened.response, isNull);
    final published = opened.notifications.single['params'] as Map;
    expect(published['diagnostics'], isEmpty);
    final line = source.split('\n')[2];
    final definition = session.handle({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'textDocument/definition',
      'params': {
        'textDocument': {'uri': uri},
        'position': {'line': 2, 'character': line.indexOf('value')},
      }
    });
    final range = (definition.response!['result'] as Map)['range'] as Map;
    expect((range['start'] as Map)['line'], 1);
    expect(File('${directory.path}/app.quds').existsSync(), isFalse);

    final indented = session.handle({
      'method': 'textDocument/didChange',
      'params': {
        'textDocument': {'uri': uri, 'version': 2},
        'contentChanges': [
          {'text': 'main():\n    print 1\n'}
        ],
      }
    });
    expect((indented.notifications.single['params'] as Map)['diagnostics'],
        isEmpty);
    final formatted = session.handle({
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'textDocument/formatting',
      'params': {
        'textDocument': {'uri': uri},
      }
    });
    final edits = formatted.response!['result'] as List;
    expect((edits.single as Map)['newText'], 'main():\n  print 1\n');

    final broken = session.handle({
      'method': 'textDocument/didChange',
      'params': {
        'textDocument': {'uri': uri, 'version': 3},
        'contentChanges': [
          {'text': 'main():\n  x = [1, 2\n'}
        ],
      }
    });
    final diagnostics =
        (broken.notifications.single['params'] as Map)['diagnostics'] as List;
    expect((diagnostics.single as Map)['code'], 'E100');
    expect((diagnostics.single as Map)['source'], 'quds');
    final refused = session.handle({
      'jsonrpc': '2.0',
      'id': 4,
      'method': 'textDocument/formatting',
      'params': {
        'textDocument': {'uri': uri},
      }
    });
    expect(refused.response!['error'], isNotNull);
    final closed = session.handle({
      'method': 'textDocument/didClose',
      'params': {
        'textDocument': {'uri': uri}
      }
    });
    expect(
        (closed.notifications.single['params'] as Map)['diagnostics'], isEmpty);
  });

  test('lsp hover shows a type and main offers run, debug, and profile', () {
    final directory = Directory.systemTemp.createTempSync('quds-hover-');
    addTearDown(() => directory.deleteSync(recursive: true));
    const source = '''
sum(a: int, b: int) -> int:
  return a + b
main():
  numbers = [10, 20, 30]
  print sum(5, 7)
''';
    final uri = Uri.file('${directory.path}/app.quds').toString();
    final session = LspSession();
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'languageId': 'quds',
          'version': 1,
          'text': source,
        }
      }
    });
    String hover(int line, String token) {
      final row = source.split('\n')[line];
      final response = session.handle({
        'jsonrpc': '2.0',
        'id': 8,
        'method': 'textDocument/hover',
        'params': {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': row.indexOf(token)},
        }
      });
      final contents = (response.response!['result'] as Map)['contents'] as Map;
      return contents['value'] as String;
    }

    expect(hover(0, 'sum'), contains('sum(a: int, b: int) -> int'));
    expect(hover(1, 'a'), contains('a: int'));
    expect(hover(1, '+'), contains('int'));
    expect(hover(2, 'main'), contains('main() -> void'));
    expect(hover(3, 'numbers'), contains('numbers: List<int>'));
    expect(hover(3, '10'), contains('int'));
    expect(hover(4, 'sum'), contains('sum(a: int, b: int) -> int'));

    final lenses = session.handle({
      'jsonrpc': '2.0',
      'id': 9,
      'method': 'textDocument/codeLens',
      'params': {
        'textDocument': {'uri': uri}
      }
    });
    final items = lenses.response!['result'] as List;
    expect(items, hasLength(3));
    expect(
      items.map((item) => ((item as Map)['command'] as Map)['title']),
      ['Run', 'Debug', 'Profile'],
    );
    expect(
      items.map((item) => ((item as Map)['command'] as Map)['command']),
      ['quds.run', 'quds.debug', 'quds.profile'],
    );
    final range = (items.first as Map)['range'] as Map;
    expect((range['start'] as Map)['line'], 2);
  });

  test('completion offers scope, members, arguments, and snippets', () {
    final directory = Directory.systemTemp.createTempSync('quds-complete-');
    addTearDown(() => directory.deleteSync(recursive: true));
    const source = '''
use dart:math as math
class CartLine:
  units: int required
  cents: int required
  total() -> int = units * cents
class Meter:
  private var stored: int = 0
  property total: int:
    get = stored
    set(value):
      stored = value
sum(a: int, b: int) -> int:
  return a + b
main():
  numbers = [10, 20, 30]
  text = "Hi"
  for item in numbers:
    print item
  if true:
    inner = 1
    print inner
  print numbers
  line = CartLine(units: 1, cents: 2)
  meter = Meter()
  print line.total()
  print meter.total
  print math.pi
''';
    final uri = Uri.file('${directory.path}/app.quds').toString();
    final session = LspSession();
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'languageId': 'quds',
          'version': 1,
          'text': source,
        }
      }
    });
    List<Map<dynamic, dynamic>> at(String text, int line, int character) {
      final response = session.handle({
        'jsonrpc': '2.0',
        'id': 21,
        'method': 'textDocument/completion',
        'params': {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': character},
        }
      });
      final result = response.response!['result'] as Map;
      return (result['items'] as List).cast<Map<dynamic, dynamic>>();
    }

    Map<dynamic, dynamic> one(
        List<Map<dynamic, dynamic>> items, String label, String detail) {
      return items.firstWhere(
          (item) => item['label'] == label && item['detail'] == detail);
    }

    final rows = source.split('\n');
    final afterIf = rows.indexOf('  print numbers');
    final outside = at(source, afterIf, rows[afterIf].indexOf('numbers'));
    expect(outside.map((item) => item['label']), contains('numbers'));
    expect(outside.map((item) => item['label']), contains('sum'));
    expect(outside.map((item) => item['label']), contains('print'));
    expect(outside.map((item) => item['label']), isNot(contains('inner')));
    expect(outside.map((item) => item['label']), isNot(contains('item')));
    expect(one(outside, 'numbers', 'List<int>')['kind'], 6);

    final itemLine = rows.indexOf('    print item');
    final insideLoop = at(source, itemLine, rows[itemLine].indexOf('item'));
    expect(insideLoop.map((item) => item['label']), contains('item'));
    expect(insideLoop.map((item) => item['label']), contains('numbers'));

    final innerLine = rows.indexOf('    print inner');
    final insideIf = at(source, innerLine, rows[innerLine].indexOf('inner'));
    expect(insideIf.map((item) => item['label']), contains('inner'));
    expect(insideIf.map((item) => item['label']), isNot(contains('item')));

    final quoted = rows.indexOf('  text = "Hi"');
    expect(at(source, quoted, rows[quoted].indexOf('Hi')), isEmpty);

    void edit(int version, String text) {
      session.handle({
        'method': 'textDocument/didChange',
        'params': {
          'textDocument': {'uri': uri, 'version': version},
          'contentChanges': [
            {'text': text}
          ],
        }
      });
    }

    final dotted = source.replaceFirst('  print numbers', '  print numbers.');
    edit(2, dotted);
    final members =
        at(dotted, afterIf, dotted.split('\n')[afterIf].indexOf('.') + 1);
    expect(one(members, 'length', 'int')['kind'], 10);
    expect(members.map((item) => item['label']), contains('add'));
    expect(members.map((item) => item['label']), contains('where'));
    final lengthEdit = one(members, 'length', 'int')['textEdit'] as Map;
    expect(lengthEdit['newText'], 'length');

    final textDot = source.replaceFirst('  text = "Hi"', '  text = "Hi".');
    edit(3, textDot);
    final letters =
        at(textDot, quoted, textDot.split('\n')[quoted].indexOf('.') + 1);
    expect(letters.map((item) => item['label']), contains('toUpperCase'));
    expect(one(letters, 'length', 'int')['detail'], 'int');

    final call = source.replaceFirst(
        '  line = CartLine(units: 1, cents: 2)', '  line = CartLine(');
    edit(4, call);
    final callLine = rows.indexOf('  line = CartLine(units: 1, cents: 2)');
    final arguments =
        at(call, callLine, call.split('\n')[callLine].indexOf('(') + 1);
    expect(one(arguments, 'units', 'int')['textEdit'],
        containsPair('newText', 'units: '));
    expect(arguments.map((item) => item['label']), contains('cents'));

    final sumCall = source.replaceFirst('  print numbers', '  print sum(');
    edit(5, sumCall);
    final named =
        at(sumCall, afterIf, sumCall.split('\n')[afterIf].indexOf('(') + 1);
    expect(named.map((item) => item['label']), containsAll(['a', 'b']));

    final mathDot = source.replaceFirst('  print math.pi', '  print math.');
    edit(6, mathDot);
    final mathLine = rows.indexOf('  print math.pi');
    final mathItems =
        at(mathDot, mathLine, mathDot.split('\n')[mathLine].indexOf('.') + 1);
    expect(mathItems.map((item) => item['label']), containsAll(['pi', 'sqrt']));

    final lineDot =
        source.replaceFirst('  print line.total()', '  print line.');
    edit(7, lineDot);
    final lineRow = rows.indexOf('  print line.total()');
    final lineItems =
        at(lineDot, lineRow, lineDot.split('\n')[lineRow].indexOf('.') + 1);
    expect(one(lineItems, 'total', '() -> int')['kind'], 2);
    expect(lineItems.map((item) => item['label']), contains('units'));

    final meterDot =
        source.replaceFirst('  print meter.total', '  print meter.');
    edit(8, meterDot);
    final meterRow = rows.indexOf('  print meter.total');
    final meterItems =
        at(meterDot, meterRow, meterDot.split('\n')[meterRow].indexOf('.') + 1);
    expect(one(meterItems, 'total', 'property int')['kind'], 10);
    expect(
        meterItems.map((item) => item['detail']), isNot(contains('() -> int')));

    final snippetText = source.replaceFirst('  print numbers', '  ');
    edit(9, snippetText);
    final snippets =
        at(snippetText, afterIf, snippetText.split('\n')[afterIf].length);
    final snippet = one(snippets, 'if', 'snippet');
    expect(snippet['insertTextFormat'], 2);
    expect((snippet['textEdit'] as Map)['newText'],
        contains('if \${1:condition}:'));
  });

  test('a property total is not presented as the function total()', () {
    final directory = Directory.systemTemp.createTempSync('quds-property-');
    addTearDown(() => directory.deleteSync(recursive: true));
    const source = '''
class CartLine:
  units: int required
  cents: int required
  total() -> int = units * cents
class Meter:
  private var stored: int = 0
  property total: int:
    get = stored
    set(value):
      stored = value
main():
  var total = 0
  line = CartLine(units: 3, cents: 40)
  total += line.total()
  meter = Meter()
  seen = meter.total
''';
    final uri = Uri.file('${directory.path}/app.quds').toString();
    final session = LspSession();
    session.handle({
      'method': 'textDocument/didOpen',
      'params': {
        'textDocument': {
          'uri': uri,
          'languageId': 'quds',
          'version': 1,
          'text': source,
        }
      }
    });
    String hover(int line, int character) {
      final response = session.handle({
        'jsonrpc': '2.0',
        'id': 11,
        'method': 'textDocument/hover',
        'params': {
          'textDocument': {'uri': uri},
          'position': {'line': line, 'character': character},
        }
      });
      final result = response.response!['result'];
      expect(result, isNotNull, reason: 'line $line:$character');
      return ((result as Map)['contents'] as Map)['value'] as String;
    }

    final rows = source.split('\n');
    final binding = hover(11, rows[11].indexOf('total'));
    expect(binding, contains('var total: int'));
    expect(binding, isNot(contains('()')));
    final call = rows[13];
    final called = hover(13, call.indexOf('line.total') + 'line.'.length);
    expect(called, contains('total() -> int'));
    expect(called, isNot(contains('property')));
    final read = rows[15];
    final property = hover(15, read.indexOf('meter.total') + 'meter.'.length);
    expect(property, contains('property total: int'));
    expect(property, isNot(contains('()')));

    final tokens = session.handle({
      'jsonrpc': '2.0',
      'id': 12,
      'method': 'textDocument/semanticTokens/full',
      'params': {
        'textDocument': {'uri': uri}
      }
    });
    final data =
        ((tokens.response!['result'] as Map)['data'] as List).cast<int>();
    int? typeAt(int line, int character) {
      var row = 0;
      var column = 0;
      for (var i = 0; i + 4 < data.length; i += 5) {
        final deltaLine = data[i];
        row += deltaLine;
        column = deltaLine == 0 ? column + data[i + 1] : data[i + 1];
        final length = data[i + 2];
        if (row == line && character >= column && character < column + length) {
          return data[i + 3];
        }
      }
      return null;
    }

    expect(typeAt(11, rows[11].indexOf('total')), 3, reason: 'var total');
    expect(
      typeAt(13, call.indexOf('line.total') + 'line.'.length),
      1,
      reason: 'CartLine.total()',
    );
    expect(
      typeAt(13, call.indexOf('total')),
      3,
      reason: 'assignment to var total',
    );
    expect(
      typeAt(15, read.indexOf('meter.total') + 'meter.'.length),
      2,
      reason: 'Meter.total property',
    );
  });

  test('linux installer stages the editor extension without prompts', () {
    final syntax = Process.runSync('bash', ['-n', 'install.sh']);
    expect(syntax.exitCode, 0, reason: '${syntax.stdout}\n${syntax.stderr}');
    final home = Directory.systemTemp.createTempSync('quds-install-');
    final bin = Directory.systemTemp.createTempSync('quds-install-bin-');
    addTearDown(() => home.deleteSync(recursive: true));
    addTearDown(() => bin.deleteSync(recursive: true));
    for (final tool in ['dirname', 'python3', 'mktemp', 'rm', 'mkdir', 'cp']) {
      Link('${bin.path}/$tool').createSync('/usr/bin/$tool');
    }
    final installed = Process.runSync(
      '/bin/bash',
      ['install.sh', '--skip-dart', '--skip-cli'],
      environment: {'HOME': home.path, 'PATH': bin.path},
    );
    expect(installed.exitCode, 0,
        reason: '${installed.stdout}\n${installed.stderr}');
    final extension = File(
        '${home.path}/.vscode/extensions/quds-lang.quds-0.0.1/package.json');
    expect(extension.existsSync(), isTrue);
    expect(extension.readAsStringSync(), contains('"name": "quds"'));
    expect(extension.readAsStringSync(), contains('quds.showDart'));
    expect(
        File('${home.path}/.cursor/extensions/quds-lang.quds-0.0.1/extension.js')
            .existsSync(),
        isTrue);
    expect(
        File('${home.path}/.vscode/extensions/quds-lang.quds-0.0.1/syntaxes/quds.tmLanguage.json')
            .existsSync(),
        isTrue);
  });

  test('format keeps comments, documentation, and multiline strings', () async {
    final directory = Directory.systemTemp.createTempSync('quds-format-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')..writeAsStringSync('''
# note   
main():
    # inner
    text = """
      kept
"""
    print text
    print add(
        1,
        2
    )
add(a: int, b: int) -> int = a + b
''');
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final formatted = await cli(['format', source.path]);
    expect(formatted.exitCode, 0, reason: '${formatted.stderr}');
    final once = source.readAsStringSync();
    expect(once, contains('# note'));
    expect(once, contains('  # inner'));
    expect(once, contains('      kept'));
    expect(once, endsWith('\n'));
    expect(once, isNot(contains(' \n')));
    await cli(['format', source.path]);
    expect(source.readAsStringSync(), once);
    await execute(once, '\n      kept\n\n3\n');
  });

  test('doc test reports a broken link and a failing example', () async {
    final directory = Directory.systemTemp.createTempSync('quds-doc-');
    addTearDown(() => directory.deleteSync(recursive: true));
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final broken = File('${directory.path}/broken.quds')
      ..writeAsStringSync('/// See [Missing].\nmain():\n  print 1\n');
    final failed = await cli(['doc', 'test', broken.path]);
    expect(failed.exitCode, 65);
    expect(failed.stderr, contains('Broken link: Missing'));
    final example = File('${directory.path}/example.quds')
      ..writeAsStringSync('''
/// See [main].
/// ```
/// main():
///   print "doc"
/// ```
main():
  print 1
''');
    final passed = await cli(['doc', 'test', example.path]);
    expect(passed.exitCode, 0, reason: '${passed.stdout}\n${passed.stderr}');
    example.writeAsStringSync('''
/// ```
/// main():
///   print nowhere
/// ```
main():
  print 1
''');
    final bad = await cli(['doc', 'test', example.path]);
    expect(bad.exitCode, 65);
    expect(bad.stderr, contains('E200'));
  });

  test('assert runs in development and is absent in production', () async {
    final directory = Directory.systemTemp.createTempSync('quds-assert-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final dart = compile('''
tick() -> bool:
  print "tick"
  return false
main():
  assert tick(), "boom"
  require true
  check true
  print "ok"
''').dart;
    final output = File('${directory.path}/app.dart')..writeAsStringSync(dart);
    final debug = await Process.run(
        Platform.resolvedExecutable, ['run', '--enable-asserts', output.path]);
    expect(debug.stdout, contains('tick'));
    expect(debug.exitCode, isNot(0));
    final release = await Process.run(Platform.resolvedExecutable,
        ['run', '--no-enable-asserts', output.path]);
    expect(release.exitCode, 0, reason: '${release.stderr}');
    expect(release.stdout, 'ok\n');
  });

  test('GenerateModel emits deterministic Quds and drops a stale file',
      () async {
    const source = '''
@GenerateModel
class User:
  name: String
  age: int
main():
  print 1
''';
    final first = compile(source, file: 'user.quds');
    final second = compile(source, file: 'user.quds');
    expect(first.models, hasLength(1));
    expect(first.models.single.fileName, 'user_model.quds');
    expect(first.models.single.source, second.models.single.source);
    expect(first.models.single.sourceMap, second.models.single.sourceMap);
    expect(first.models.single.sourceMap, contains('user.quds'));
    expect(first.models.single.source, contains('value class UserModel:'));
    expect(first.models.single.source.indexOf('name:'),
        lessThan(first.models.single.source.indexOf('age:')));
    await execute('''
${first.models.single.source}
main():
  print UserModel(name: "Ada", age: 36).name
''', 'Ada\n');
    expect(
        () => compile('''
class UserModel:
  other: int
@GenerateModel
class User:
  name: String
main():
  print 1
'''),
        throwsA(isA<CompilerException>()
            .having((error) => error.code, 'code', 'E904')));
    final directory = Directory.systemTemp.createTempSync('quds-gen-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/app.quds')..writeAsStringSync(source);
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final built = await cli(['build', file.path]);
    expect(built.exitCode, 0, reason: '${built.stdout}\n${built.stderr}');
    final generated = File('${directory.path}/generated/user_model.quds');
    final bytes = generated.readAsBytesSync();
    expect(
        File('${generated.path}.map').readAsStringSync(), contains('app.quds'));
    final again = await cli(['build', file.path]);
    expect(again.exitCode, 0, reason: '${again.stderr}');
    expect(generated.readAsBytesSync(), bytes);
    file.writeAsStringSync('main():\n  print 1\n');
    final dropped = await cli(['build', file.path]);
    expect(dropped.exitCode, 0, reason: '${dropped.stderr}');
    expect(generated.existsSync(), isFalse);
  });

  test('format wraps at 80 columns without touching comments or strings',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-width-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final wide = 'x' * 90;
    final comment = 'n' * 90;
    final numbers = [for (var i = 1; i <= 24; i++) '$i'].join(', ');
    final source = File('${directory.path}/app.quds')..writeAsStringSync('''
# $comment
main():
    text = """
$wide
"""
    values = [$numbers]
    print values.length
    print text.length
''');
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final formatted = await cli(['format', source.path]);
    expect(formatted.exitCode, 0, reason: '${formatted.stderr}');
    final once = source.readAsStringSync();
    final lines = once.split('\n');
    expect(lines.where((line) => line.startsWith('#')).single.length,
        greaterThan(80));
    expect(lines, contains(wide));
    for (final line in lines) {
      if (line.startsWith('#') || line == wide) continue;
      expect(line.length, lessThanOrEqualTo(80), reason: line);
    }
    await cli(['format', source.path]);
    expect(source.readAsStringSync(), once);
    await execute(once, '24\n92\n');
  });

  test('doc html writes the documentation page', () async {
    final directory = Directory.systemTemp.createTempSync('quds-html-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('/// Returns the sum.\nmain():\n  print 1\n');
    final page = File('${directory.path}/api.html');
    final written = await Process.run(Platform.resolvedExecutable, [
      'run',
      'bin/quds.dart',
      'doc',
      'html',
      source.path,
      page.path,
    ]);
    expect(written.exitCode, 0, reason: '${written.stderr}');
    final html = page.readAsStringSync();
    expect(html, contains('<h1>app.quds</h1>'));
    expect(html, contains('Returns the sum.'));
    expect(html, contains('<h2>main():</h2>'));
  });

  test('benchmark checks debug/release parity and a regression', () async {
    final directory = Directory.systemTemp.createTempSync('quds-bench-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('main():\n  print 1\n');
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final stable =
        await cli(['benchmark', source.path, '--baseline', '600000000']);
    expect(stable.exitCode, 0, reason: '${stable.stdout}\n${stable.stderr}');
    expect(stable.stdout, contains('parity ok'));
    final regressed = await cli(['benchmark', source.path, '--baseline', '0']);
    expect(regressed.exitCode, 1);
    expect(regressed.stderr, contains('Benchmark regression'));
    source.writeAsStringSync('''
ready() -> bool:
  print "debug"
  return true
main():
  assert ready()
  print "done"
''');
    final drifted = await cli(['benchmark', source.path]);
    expect(drifted.exitCode, 1);
    expect(drifted.stderr, contains('Debug/release output differs'));
  });

  test('dart:ffi types compile on the VM and stay off the web branch', () {
    final native = compile('''
use dart:ffi
read(p: Pointer<Int32>) -> int = 1
main():
  print 1
''');
    expect(native.dart, contains("import 'dart:ffi';"));
    expect(native.dart, contains('Pointer<Int32>'));
    final web = compile('''
use dart:ffi when platform == "web"
main():
  print 1
''');
    expect(web.dart, isNot(contains('dart:ffi')));
  });

  test('a Dart program calls generated Quds without the compiler', () async {
    final directory = Directory.systemTemp.createTempSync('quds-dart-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('add(a: int, b: int) -> int = a + b\n');
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart, isNot(contains('quds_lang')));
    File('${directory.path}/app.dart').writeAsStringSync(result.dart);
    File('${directory.path}/main.dart').writeAsStringSync('''
import 'app.dart';
void main() {
  print(add(2, 3));
}
''');
    final run = await Process.run(
        Platform.resolvedExecutable, ['run', 'main.dart'],
        workingDirectory: directory.path);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, '5\n');
  });

  test('a Dart caller passes null and matches Result', () async {
    final directory = Directory.systemTemp.createTempSync('quds-null-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')..writeAsStringSync('''
greet(name: String?) -> String:
  if name == null:
    return "hi"
  else:
    return name
parse() -> Result<int, String> = Ok(4)
''');
    final result = compile(source.readAsStringSync(), file: source.path);
    expect(result.dart, contains('String?'));
    expect(result.dart, contains('final greet ='));
    expect(result.dart, isNot(contains('quds_lang')));
    File('${directory.path}/app.dart').writeAsStringSync(result.dart);
    File('${directory.path}/main.dart').writeAsStringSync('''
import 'app.dart';
void main() {
  print(greet(null));
  print(greet('Ada'));
  switch (parse()) {
    case Ok(value: final n):
      print(n);
    case Error():
      print('no');
  }
}
''');
    final run = await Process.run(
        Platform.resolvedExecutable, ['run', 'main.dart'],
        workingDirectory: directory.path);
    expect(run.exitCode, 0,
        reason: '${run.stdout}\n${run.stderr}\n${result.dart}');
    expect(run.stdout, 'hi\nAda\n4\n');
  });

  test('quds get writes a lockfile and reports a version conflict', () async {
    final directory = Directory.systemTemp.createTempSync('quds-pub-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/pubspec.yaml').writeAsStringSync('''
name: demo
environment:
  sdk: '>=3.3.0 <4.0.0'
''');
    final quds = File('bin/quds.dart').absolute.path;
    Future<ProcessResult> cli(List<String> args) =>
        Process.run(Platform.resolvedExecutable, ['run', quds, ...args],
            workingDirectory: directory.path);
    final got = await cli(['get']);
    expect(got.exitCode, 0, reason: '${got.stdout}\n${got.stderr}');
    expect(File('${directory.path}/pubspec.lock').existsSync(), isTrue);
    File('${directory.path}/pubspec.yaml').writeAsStringSync('''
name: demo
environment:
  sdk: '>=3.3.0 <4.0.0'
dependencies:
  meta: '>=99.0.0 <99.0.0'
''');
    final conflict = await cli(['get', '--offline']);
    expect(conflict.exitCode, isNot(0));
    expect('${conflict.stdout}\n${conflict.stderr}', contains('meta'));
  });

  test('quds run reports a thrown error on the quds line', () async {
    final directory = Directory.systemTemp.createTempSync('quds-run-map-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/bad.quds')
      ..writeAsStringSync('main():\n  numbers = [10]\n  print numbers[3]\n');
    final quds = File('bin/quds.dart').absolute.path;
    final run = await Process.run(Platform.resolvedExecutable, [
      'run',
      quds,
      'run',
      source.path,
    ]);
    final combined = '${run.stdout}\n${run.stderr}';
    expect(run.exitCode, isNot(0), reason: combined);
    expect(combined, contains('${source.path}:3:'));
    expect(combined, isNot(contains('main.dart:')));
  });
}

File builtDart(File source) {
  final name =
      source.uri.pathSegments.last.replaceFirst(RegExp(r'\.quds$'), '.dart');
  return File('${source.parent.path}/.dart_tool/quds/out/$name');
}

Future<void> execute(String source, String stdout) async {
  final directory = Directory.systemTemp.createTempSync('quds-execution-');
  try {
    final output = File('${directory.path}/app.dart')
      ..writeAsStringSync(compile(source).dart);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason:
            '${analysis.stdout}\n${analysis.stderr}\n${output.readAsStringSync()}');
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.exitCode, 0, reason: '${run.stderr}');
    expect(run.stdout, stdout);
    expect(run.stderr, isEmpty);
  } finally {
    directory.deleteSync(recursive: true);
  }
}

class _DebugClient {
  _DebugClient(this.process);
  final Process process;
  final _buffer = <int>[];
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _waiters = <String, List<Completer<Map<String, dynamic>>>>{};
  final _seen = <String, List<Map<String, dynamic>>>{};
  var _sequence = 1;
  final stderr = StringBuffer();

  void start() {
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    process.stdout.listen((chunk) {
      _buffer.addAll(chunk);
      while (true) {
        final headerEnd = _headerEnd(_buffer);
        if (headerEnd < 0) return;
        final header = utf8.decode(_buffer.sublist(0, headerEnd));
        final match = RegExp(r'Content-Length: (\d+)').firstMatch(header);
        if (match == null) return;
        final length = int.parse(match.group(1)!);
        final start = headerEnd + 4;
        if (_buffer.length < start + length) return;
        final body = utf8.decode(_buffer.sublist(start, start + length));
        _buffer.removeRange(0, start + length);
        final decoded = jsonDecode(body);
        if (decoded is! Map) continue;
        final message = decoded
            .map((key, value) => MapEntry(key.toString(), value as dynamic));
        if (message['type'] == 'response') {
          final id = (message['request_seq'] as num?)?.toInt();
          final waiter = id == null ? null : _pending.remove(id);
          waiter?.complete(message);
        } else if (message['type'] == 'event') {
          final name = message['event'];
          if (name is! String) continue;
          final waiting = _waiters[name];
          if (waiting != null && waiting.isNotEmpty) {
            waiting.removeAt(0).complete(message);
          } else {
            _seen.putIfAbsent(name, () => []).add(message);
          }
        }
      }
    });
  }

  Future<Map<String, dynamic>> request(String command,
      [Map<String, Object?> arguments = const {}]) {
    final id = _sequence++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    process.stdin.write(encodeFrame({
      'seq': id,
      'type': 'request',
      'command': command,
      'arguments': arguments,
    }));
    return completer.future.timeout(const Duration(seconds: 90), onTimeout: () {
      throw TimeoutException('$command\n$stderr');
    });
  }

  Future<Map<String, dynamic>> event(String name) {
    final queued = _seen[name];
    if (queued != null && queued.isNotEmpty) {
      return Future.value(queued.removeAt(0));
    }
    final completer = Completer<Map<String, dynamic>>();
    _waiters.putIfAbsent(name, () => []).add(completer);
    return completer.future;
  }
}

Future<Map<String, dynamic>> _stopForBreakpoint(_DebugClient client) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    final event =
        await client.event('stopped').timeout(const Duration(seconds: 60));
    final body = event['body'] as Map;
    if (body['reason'] == 'breakpoint') return event;
    await client.request('continue', {'threadId': body['threadId']});
  }
  throw TimeoutException('no breakpoint stop\n${client.stderr}');
}

int _headerEnd(List<int> buffer) {
  for (var i = 0; i + 3 < buffer.length; i++) {
    if (buffer[i] == 13 &&
        buffer[i + 1] == 10 &&
        buffer[i + 2] == 13 &&
        buffer[i + 3] == 10) {
      return i;
    }
  }
  return -1;
}
