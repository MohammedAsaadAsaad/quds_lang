import 'dart:convert';
import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
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
    final output = File('${directory.path}/app.dart');
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);
    final built = await cli(['build', source.path]);
    expect(built.exitCode, 0, reason: '${built.stderr}');
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
    final run = await Process.run(
        Platform.resolvedExecutable, ['${directory.path}/app.dart']);
    expect(run.stdout, '8\n', reason: '${run.stderr}');
    final again = await cli(['build', app.path]);
    expect(again.exitCode, 0, reason: '${again.stderr}');
    expect(again.stdout, contains('Unchanged'));
    expect(again.stdout.contains('Built'), isFalse);
    math.writeAsStringSync('doubleIt(n: int) -> int = n * 3\n');
    final rebuilt = await cli(['build', app.path]);
    expect(rebuilt.exitCode, 0, reason: '${rebuilt.stdout}\n${rebuilt.stderr}');
    expect(rebuilt.stdout, contains('Built'));
    final after = await Process.run(
        Platform.resolvedExecutable, ['${directory.path}/app.dart']);
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
    expect(
        File('${directory.path}/app.dart').readAsStringSync(), contains('Hi'));
    final again = await cli(['build', source.path]);
    expect(again.stdout, contains('Unchanged'));
    source.writeAsStringSync(source.readAsStringSync().replaceAll('Hi', 'Yo'));
    final rebuilt = await cli(['build', source.path]);
    expect(rebuilt.exitCode, 0, reason: '${rebuilt.stdout}\n${rebuilt.stderr}');
    expect(rebuilt.stdout, contains('Built'));
    expect(
        File('${directory.path}/app.dart').readAsStringSync(), contains('Yo'));
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
    expect(File('${directory.path}/app.dart').readAsStringSync(),
        contains('print(2)'));
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
