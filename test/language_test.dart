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

    File('${directory.path}/suite.quds').writeAsStringSync('''
test "adds":
  print 1
group "suite":
  test "inner":
    print 2
''');
    final suite = await cli(['test', '${directory.path}/suite.quds']);
    expect(suite.exitCode, 0, reason: '${suite.stdout}\n${suite.stderr}');
    expect(suite.stdout, '1\n2\n');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('do, capture, conversion, with, unions, and loops execute', () async {
    await execute('''
value class Point:
  x: int
  y: int
class Box:
  n: int
pick(flag: bool) -> int:
  value = do:
    if flag:
      return 4
    result 0
  return value
pack(values: List<int>) -> List<int> = values
main():
  answer = do:
    result 1 + 2
  print answer
  print pick(true)
  var count = 1
  saved = capture(count) -> count + 1
  count = 9
  print saved()
  var box = Box(n: 1)
  read = capture(box) -> box.n
  box = Box(n: 9)
  print read()
  print "16" to int
  print "no" to? int
  print "1" to? int?
  moved = with Point(x: 1, y: 2):
    x: 4
  print moved.x
  point: Point? = null
  skipped = with? point:
    x: 9
  print skipped
  value: int | String = 1
  match value:
    int n:
      print n
    String:
      print "text"
  number: int | double = 1
  print number
  text: String | Null = null
  print text ?? "none"
  var total = 0
  for var i = 0 while i < 4 step i += 1:
    if i == 1:
      continue
    total += i
  print total
  var n = 0
  repeat:
    n += 1
  while n < 2
  print n
  items = pack:
    values:
      1
      if total > 0:
        2
      for item in [4]:
        item
  print items.length
''', '3\n4\n2\n1\n16\nnull\n1\n4\nnull\n1\n1\nnone\n5\n2\n3\n');
  });

  test('dot shorthand, null-aware elements, and exhaustiveness', () async {
    final source = '''
sealed type Color:
  Red
  Blue
value class Point:
  x: int
  y: int
main():
  color: Color = .Red
  match color:
    Red:
      print "red"
    Blue:
      print "blue"
  point: Point = .new(x: 1, y: 2)
  print point.y
  name: String? = null
  items = [?name, "Ada"]
  print items.length
  show(skip: bool):
    chosen = Blue()
    match chosen:
      Red when skip:
        print "no"
      Blue:
        print "blue"
  show(false)
''';
    final compiled = compile(source);
    expect(compiled.semantics.warnings.map((warning) => warning.code),
        contains('W001'));
    final cycle = compile('''
main():
  computed a: int = a
  print a
''');
    expect(cycle.semantics.warnings.map((warning) => warning.code),
        contains('W007'));
    await execute(source, 'red\n2\n1\nblue\n');
  });

  test('variadics, mixins, extensions, and reactive state execute', () async {
    await execute('''
sum(...values: int) -> int:
  var total = 0
  for n in values:
    total += n
  return total
show(x: int) -> String = "one"
show(...xs: int) -> String = "many"
class Animal:
  name: String required
mixin Walkable on Animal:
  walk() -> String = name
class Dog extends Animal with Walkable:
  breed: String required
interface Named:
  name: String
class Person implements Named:
  name: String required
extend String:
  shout() -> String = this + "!"
main():
  items = [4, 5]
  absent: List<int>? = null
  print sum()
  print sum(1, 2, 3)
  print sum(...items)
  print sum(...?absent)
  print show(1)
  print show(1, 2)
  print Dog(name: "Rex", breed: "mix").walk()
  print Person(name: "Ada").name
  print "hi".shout()
  state count = 0
  computed doubled = count * 2
  var log = ""
  watch count:
    log = log + "{count}"
  count = 1
  count = 2
  print doubled
  print log
  count = 3
  print doubled
''', '0\n6\n9\n0\none\nmany\nRex\nAda\nhi!\n4\n012\n6\n');
  });

  test('aliases, extension types, modifiers, and singletons execute', () async {
    await execute('''
type UserId = int
type Meters wraps int:
  require value > 0
  next() -> Meters = Meters(value + 1)
final class Token:
  text: String required
base class Animal:
  name: String required
base class Dog extends Animal:
  breed: String required
singleton class Cache:
  hits: int = 0
abstract class Shape:
  title: String required
class Box extends Shape:
  size: int required
main():
  id: UserId = 7
  print id
  print Meters(2).next()
  print Token(text: "x").text
  print Dog(name: "Rex", breed: "mix").name
  print Cache.instance.hits
  print Box(title: "s", size: 1).size
''', '7\n3\nx\nRex\n0\n1\n');
  });

  test('small numbers match between the VM and JavaScript', () async {
    const source = '''
main():
  print 7 ~/ 2
  print 1 / 2
  print 16
''';
    final directory = Directory.systemTemp.createTempSync('quds-web-');
    try {
      final dartFile = File('${directory.path}/app.dart')
        ..writeAsStringSync(compile(source).dart);
      final script = '${directory.path}/app.js';
      final compiled = await Process.run(Platform.resolvedExecutable,
          ['compile', 'js', '-o', script, dartFile.path]);
      expect(compiled.exitCode, 0, reason: compiled.stderr.toString());
      final run = await Process.run('node', [script]);
      expect(run.exitCode, 0, reason: run.stderr.toString());
      expect(run.stdout, '3\n0.5\n16\n');
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('an integer outside the JavaScript safe range is rejected on web',
      () async {
    const source = '''
main():
  print 9007199254740993
''';
    await execute(source, '9007199254740993\n');
    final directory = Directory.systemTemp.createTempSync('quds-web-int-');
    try {
      final dartFile = File('${directory.path}/app.dart')
        ..writeAsStringSync(compile(source).dart);
      final compiled = await Process.run(Platform.resolvedExecutable,
          ['compile', 'js', '-o', '${directory.path}/app.js', dartFile.path]);
      expect(compiled.exitCode, isNot(0));
      expect('${compiled.stdout}${compiled.stderr}',
          contains("can't be represented exactly in JavaScript"));
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('spreads, enums, try, late, generators, and match expressions execute',
      () async {
    await execute('''
pack(values: List<int>) -> List<int> = values
enum Color:
  red
  green
count() sync* -> int:
  yield 1
  yield 2
more() async* -> int:
  yield 1
  yield 2
choose(flag: bool) -> int = if flag: 1 else: 2
pick(color: Color) -> String = match color:
  red: "red"
  green: "green"
shape(flag: bool) -> int:
  first = [1, 2]
  extra: List<int>? = null
  items = [...first, ...?extra, 3, if flag: 4 else: 5, for n in [6]: n]
  block = [
    1,
    if flag:
      2
    else:
      3
    ,
    for n in [4]:
      n
    ,
  ]
  chosen = pack:
    values:
      ...first
      if flag:
        9
  flags = set:
    1
    ...first
  ages = map:
    "a": 1
    ... map:
      "b": 2
  print items.length
  print block.length
  print chosen.length
  print flags.length
  print ages["b"]
  return 0
main() async:
  print shape(true)
  print pick(.red)
  late var saved: int
  saved = 4
  print saved
  print try (1 ~/ 0) else 7
  try:
    throw "no"
  catch error:
    print error
  finally:
    print "done"
  print choose(true)
  var total = 0
  for value in count():
    total += value
  await for item in more():
    total += item
  print total
''', '5\n3\n3\n2\n2\n0\nred\n4\n7\nno\ndone\n1\n6\n');
  });

  test('a non-constant zero step fails when the loop runs', () async {
    final directory = Directory.systemTemp.createTempSync('quds-step-');
    try {
      final output = File('${directory.path}/app.dart')
        ..writeAsStringSync(compile('''
step(by: int):
  for var i = 0 while i < 2 step i += by:
    i = i
main():
  step(0)
''').dart);
      final analysis = await Process.run(
          Platform.resolvedExecutable, ['analyze', output.path]);
      expect(analysis.exitCode, 0, reason: analysis.stdout.toString());
      final run = await Process.run(Platform.resolvedExecutable, [output.path]);
      expect(run.exitCode, isNonZero);
      expect(run.stderr, contains('A loop step cannot be zero'));
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('properties, operators, constructors, and conditional code execute',
      () async {
    final source = '''
use dart:math when platform == "web"
class Person:
  private var stored: String = ""
  protected note: String = "n"
  property name: String:
    get = stored
    set(value):
      stored = value
class Vec:
  x: int required
  y: int required
  operator +(other: Vec) -> Vec = Vec(x: x + other.x, y: y + other.y)
class Point:
  x: int required
  y: int required
  init(this.x, this.y):
    print x + y
  factory init same(n: int) -> Point = Point(n, n)
class File:
  title: String required
  dispose():
    print "closed"
class Box:
  private secret() -> String = "hidden"
  read() -> String = secret()
value class User:
  name: String required
  age: int? = null
main():
  person = Person()
  person.name = "Ada"
  print person.name
  print person.note
  total = Vec(x: 1, y: 2) + Vec(x: 3, y: 4)
  print total.x
  print total.y
  point = Point(1, 2)
  print point.x
  same = Point.same(3)
  print same.y
  using file = File(title: "a"):
    print file.title
  print Box().read()
  user = User(name: "Ada")
  next = user.copyWith(name: "Ann")
  aged = next.copyWith(age: 4)
  print next.name
  print aged.age
  value: String | int = "ok"
  if value is String:
    print "text"
  when platform == "vm":
    print "vm"
  when platform == "web":
    print missingName
''';
    final dart = compile(source).dart;
    expect(dart, contains('String _stored'));
    expect(dart, contains('/// protected'));
    expect(dart, contains('operator +'));
    expect(dart, contains('copyWith'));
    expect(dart, contains('_secret'));
    expect(dart, isNot(contains('dart:math')));
    expect(dart, isNot(contains('missingName')));
    await execute(
        source,
        'Ada\n'
        'n\n'
        '4\n'
        '6\n'
        '3\n'
        '1\n'
        '6\n'
        '3\n'
        'a\n'
        'closed\n'
        'hidden\n'
        'Ann\n'
        '4\n'
        'text\n'
        'vm\n');
  });

  test('part lowers to a Dart part directive', () {
    final dart = compile('part "extra.quds"\nmain():\n  print 1\n').dart;
    expect(dart, contains("part 'extra.dart';"));
  });

  test('new diagnostics reject the programs they name', () {
    final rejected = {
      'main():\n  result 1\n': 'E106',
      'main():\n  value = do:\n    print 1\n  print value\n': 'E109',
      'main():\n  for var i = 0 while i < 3 step i += 0:\n    print i\n':
          'E801',
      '''
class Bag:
  n: int
  add(value: int) -> int = n + value
main():
  bag: readonly Bag = Bag(n: 1)
  print bag.add(2)
''': 'E307',
      '''
sealed type Color:
  Red
  Blue
main():
  color = .Red
''': 'E302',
      '''
sealed type Color:
  Red
  Blue
main():
  match Red():
    _:
      print "all"
    Red:
      print "red"
''': 'E313',
      'main():\n  yield 1\n': 'E804',
      'main():\n  rethrow\n': 'E107',
      '''
enum Color:
  red
  green
main():
  color: Color = .red
  shown = match color:
    red: 1
  print shown
''': 'E314',
      '''
class Animal:
  name: String required
mixin Walkable on Animal:
  walk() -> String = name
class Cat with Walkable:
  name: String required
main():
  print "no"
''': 'E702',
      'bad(...values: int, extra: int) -> int = extra\nmain():\n  print bad(1)\n':
          'E503',
      '''
extend String:
  mark() -> String = this + "a"
extend String:
  mark() -> String = this + "b"
main():
  print "x".mark()
''': 'E205',
      '''
final mixin class Broken:
  name: String required
main():
  print "no"
''': 'E720',
      '''
final class Token:
  text: String required
class Word extends Token:
  extra: int required
main():
  print "no"
''': 'E720',
      'main():\n  print 1;\n': 'E102',
      '''
main():
  flag = true
  when flag:
    print 1
''': 'E902',
      '''
class Gap:
  x: int required
  init():
    print 1
main():
  print 1
''': 'E704',
      '''
value class Bag:
  var n: int = 1
main():
  print 1
''': 'E706',
      '''
class Box:
  var n: int = 0
  readonly bump():
    n = 1
main():
  print 1
''': 'E307',
      '''
class File:
  title: String required
  dispose():
    print title
main():
  using async file = File(title: "a"):
    print file.title
''': 'E803',
      '''
part "a.quds"
part of "b.quds"
main():
  print 1
''': 'E903',
    };
    rejected.forEach((source, code) {
      expect(() => compile(source), throwsA(predicate((error) {
        return '$error'.contains(code);
      })), reason: source);
    });
  });
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
