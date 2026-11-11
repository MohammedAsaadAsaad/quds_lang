import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('classes, lambdas, nullability, and tear-offs execute', () async {
    await execute('''
class User:
  name: String
  greet() -> String = "Hello {name}"
main():
  user = User(name: "Ada")
  print user.greet()
  twice(x: int) = x * 2
  print twice(4)
  f = x -> x + 1
  print f(2)
  called = twice
  print called(3)
  name: String? = "Ada"
  print name!
  missingName: String? = null
  print missingName ?? "none"
''', 'Hello Ada\n8\n3\n6\nAda\nnone\n');
  });

  test('ranges, loops, maps, sets, and records execute', () async {
    await execute('''
main():
  var total = 0
  for n in 1..3:
    total += n
  var exclusive = 0
  for n in 1..<4:
    exclusive += n
  while total < 10:
    total += 1
    if total == 8:
      break
  print total
  print exclusive
  ages = map:
    "Ada": 36
  print ages["Ada"]
  flags = set:
    1
    2
  print flags.length
  pair = (1, "a")
  (a, b) = pair
  print a
  print b
''', '8\n6\n36\n2\n1\na\n');
  });

  test('labels, defaults, overloads, Optional, and Result execute', () async {
    await execute(
        '''
greet(name: String, title: String = "Mx") -> String = "{title} {name}"
id(value: int) -> int = value
id(value: String) -> String = value
load() -> Result<int, String>:
  return Ok(1)
show() -> Result<int, String>:
  value = load()?
  return Ok(value)
fail() -> Result<int, String>:
  return Error("no")
failed() -> Result<int, String>:
  value = fail()?
  return Ok(value)
main():
  var total = 0
  label search
  for n in 1..5:
    if n == 2:
      continue
    total += n
    if n == 4:
      break search
  print total
  print greet("Ada")
  print id(3)
  print id("x")
  print show()
  print failed()
  print missing
  print present(1)
''',
        '8\n'
            'Mx Ada\n'
            '3\n'
            'x\n'
            "Instance of 'Ok<int, String>'\n"
            "Instance of 'Error<int, String>'\n"
            "Instance of 'Optional<Never>'\n"
            "Instance of 'Optional<int>'\n");
  });

  test('async, sealed match, imports, value classes, and macros execute',
      () async {
    await execute('''
use dart:math
sealed type Color:
  Red
  Named(name: String)
value class Point:
  x: int
  y: int
read() async -> int = 7
@macro
class Greetings:
  hello(who: String) -> String = "Hi {who}"
  define(builder: Builder):
    builder.addMethod(hello)
@Greetings
class Person:
  name: String
main() async:
  color = Red()
  match color:
    Red:
      print "red"
    Named(name: name):
      print name
  print await read()
  print sqrt(9)
  print Point(x: 1, y: 2) == Point(x: 1, y: 2)
  person = Person(name: "Ada")
  print person.hello("Ada")
  print 0x10
  print 1_000
  print 1e2
''', 'red\n7\n3.0\ntrue\nHi Ada\n16\n1000\n100.0\n');
  });

  test('pipeline and partial application execute', () async {
    await execute('''
double(x: int) -> int = x * 2
add(a: int, b: int) -> int = a + b
main():
  print 3 |> double
  print 3 |> add(_, 4)
''', '6\n7\n');
  });

  test('build writes a source map without changing generated Dart', () async {
    final directory = Directory.systemTemp.createTempSync('quds-map-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('main():\n  print 1\n');
    final cli = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', source.path]);
    expect(cli.exitCode, 0, reason: cli.stderr.toString());
    final dart = File('${directory.path}/app.dart').readAsStringSync();
    expect(dart, compile(source.readAsStringSync(), file: source.path).dart);
    final map = File('${directory.path}/app.dart.map').readAsStringSync();
    expect(map, contains('"version":3'));
    expect(map, contains('app.quds'));
  });

  test('run, analyze, test, format, doc, migrate, and create', () async {
    final directory = Directory.systemTemp.createTempSync('quds-cli-more-');
    addTearDown(() => directory.deleteSync(recursive: true));
    Future<ProcessResult> cli(List<String> args) => Process.run(
        Platform.resolvedExecutable, ['run', 'bin/quds.dart', ...args]);

    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('/// Says hello.\nmain():\n    print "hi"\n');
    final ran = await cli(['run', source.path]);
    expect(ran.exitCode, 0, reason: '${ran.stdout}\n${ran.stderr}');
    expect(ran.stdout, 'hi\n');
    final analyzed = await cli(['analyze', source.path]);
    expect(analyzed.exitCode, 0,
        reason: '${analyzed.stdout}\n${analyzed.stderr}');

    File('${directory.path}/checks.quds')
        .writeAsStringSync('test():\n  print "ok"\n');
    final tested = await cli(['test', '${directory.path}/checks.quds']);
    expect(tested.exitCode, 0, reason: '${tested.stdout}\n${tested.stderr}');
    expect(tested.stdout, 'ok\n');

    final formatted = await cli(['format', source.path]);
    expect(formatted.exitCode, 0, reason: formatted.stderr.toString());
    expect(source.readAsStringSync(), contains('  print "hi"'));
    final docs = await cli(['doc', source.path]);
    expect(docs.exitCode, 0);
    expect(docs.stdout, contains('Says hello.'));

    final migrated = await cli(['migrate', '${directory.path}/quds.yaml']);
    expect(migrated.exitCode, 0);
    expect(File('${directory.path}/quds.yaml').readAsStringSync(),
        contains('language: 1.2'));

    final created = await cli(['create', '${directory.path}/sample']);
    expect(created.exitCode, 0, reason: created.stderr.toString());
    expect(File('${directory.path}/sample/main.quds').existsSync(), isTrue);
    expect(File('${directory.path}/sample/quds.yaml').readAsStringSync(),
        contains('language: 1.2'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<void> execute(String source, String stdout) async {
  final directory = Directory.systemTemp.createTempSync('quds-language-');
  try {
    final output = File('${directory.path}/app.dart')
      ..writeAsStringSync(compile(source).dart);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason:
            '${analysis.stdout}\n${analysis.stderr}\n${output.readAsStringSync()}');
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.exitCode, 0,
        reason: '${run.stderr}\n${output.readAsStringSync()}');
    expect(run.stdout, stdout);
  } finally {
    directory.deleteSync(recursive: true);
  }
}
