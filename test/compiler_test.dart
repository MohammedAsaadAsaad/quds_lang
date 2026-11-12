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
    final script = encodeSourceMap(
        'app.dart.js', 'app.dart', [(1, const SourceSpan(3, 1, 1))]);
    final quds = encodeSourceMap(
        'app.dart', 'app.quds', [(3, const SourceSpan(2, 4, 1))]);
    final once = mapStack('#0      main (file:///tmp/app.dart.js:1:1)', script);
    expect(once, contains('app.dart:3:1'));
    expect(mapStack(once, quds), contains('app.quds:2:4'));
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
