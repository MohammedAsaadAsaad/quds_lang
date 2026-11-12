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
  var trace = ""
  watch count:
    trace = trace + "{count}"
  count = 1
  count = 2
  print doubled
  print trace
  count = 3
  print doubled
''', '0\n6\n9\n0\none\nmany\nRex\nAda\nhi!\n4\n012\n6\n');
  });

  test('typed catches run in order and finally still runs', () async {
    await execute('''
main():
  try:
    throw "text"
  catch error: int:
    print error
  catch error: String:
    print error
  catch error:
    print error
  finally:
    print "after"
  try:
    try:
      throw "again"
    catch error, stack:
      print "{stack}".length > 0
      rethrow
    finally:
      print "end"
  catch error:
    print error
''', 'text\nafter\ntrue\nend\nagain\n');
  });

  test('a var parameter can change locally and leaves the caller', () async {
    await execute('''
bump(var x: int) -> int:
  later = () -> x + 1
  x = x + 1
  return later()
main():
  n = 1
  print bump(n)
  print n
''', '3\n1\n');
  });

  test('nested, async, and capturing lambdas execute', () async {
    await execute('''
load() async -> int = 5
main() async:
  nested = x -> y -> x + y
  print nested(3)(4)
  var n = 1
  add = x -> x + n
  n = 4
  print add(3)
  later = () -> :
    n = n + 1
    return n
  print later()
  read = () -> await load()
  print await read()
''', '7\n7\n5\n5\n');
  });

  test('ranges, function types, generics, and nested task groups execute',
      () async {
    await execute('''
interface Named:
  name: String
interface Identifiable:
  id: int
class User implements Named, Identifiable:
  name: String required
  id: int required
show<T: Named & Identifiable>(item: T) -> String = item.name
pick<T: Named>(item: T) -> T = item
class Base:
  id(value: int) -> int = value
class Child extends Base:
  id(value: int) -> int = value + 1
load() async -> int = 5
mark() -> int:
  Probe.hits = Probe.hits + 1
  return Probe.hits
bad() -> int:
  var ready = true
  if ready:
    throw "bad"
  return 0
class Probe:
  static var hits: int = 0
main() async:
  var down = ""
  for n in 3..1:
    down = down + "{n}"
  print down
  var exclusive = ""
  for n in 3..<1:
    exclusive = exclusive + "{n}"
  print exclusive
  items: List<String> = []
  print items.length
  length: (String) -> int = text -> text.length
  print length("Ada")
  handler: ((int) -> int)? = null
  print handler == null
  read: () -> Future<int> = () -> await load()
  print await read()
  print show(User(name: "Ada", id: 7))
  chosen = pick(User(name: "Bea", id: 4))
  print chosen.name
  print Child().id(3)
  task group:
    spawn mark()
    task group:
      spawn mark()
  print Probe.hits
  Probe.hits = 0
  try:
    task group:
      spawn bad()
      task group:
        spawn mark()
  catch error:
    print Probe.hits
''', '321\n32\n0\n3\ntrue\n5\nAda\nBea\n4\n2\n0\n');
  });

  test('mixins, singletons, empty collections, and generators execute',
      () async {
    await execute('''
mixin A:
  name() -> String = "a"
mixin B:
  name() -> String = "b"
class Chosen with A, B:
  ready: int = 1
singleton class Cache:
  var hits: int = 0
  add() -> int:
    hits = hits + 1
    return hits
read() -> int = Cache.instance.hits
tick(note: String) -> int:
  print note
  return 1
call(a: int, b: int = a + tick("d")) -> int = b
count() sync* -> int:
  try:
    yield 1
  finally:
    yield 2
more() sync* -> int:
  yield* count()
boom() async* -> int:
  yield 7
  var ready = true
  if ready:
    throw "bad"
  yield 0
main() async:
  print Chosen(ready: 1).name()
  print Cache.instance.add()
  print Cache.instance.add()
  print await isolate:
    read()
  emptyMap: Map<String, int> = map:
  print emptyMap.length
  emptySet: Set<int> = set:
  print emptySet.length
  key = "a"
  ages = map:
    key: 1
    key: 2
  print ages[key]
  var text = ""
  for n in more():
    text = text + "{n}"
  print text
  try:
    await for n in boom():
      print n
  catch error:
    print error
  print call(2)
  print call(a: tick("a"), b: tick("b"))
  var left = 1
  var right = 2
  (left, right) = (right, left)
  print left
  print right
  var n = 0
  next() -> int:
    n = n + 1
    return n
  var x = 0
  var y = 0
  (x, y) = (next(), next())
  print x
  print y
  var p = 0
  var q = 0
  var r = 0
  (p, (q, r)) = (1, (2, 3))
  print p
  print q
  print r
''', '''
b
1
2
0
0
0
2
12
7
bad
d
3
a
b
1
2
1
1
2
1
2
3
''');
  });

  test('batch, watch disposal, and computed cycles execute', () async {
    await execute('''
main():
  state count = 0
  var seen = ""
  watch count:
    seen = "{count}"
  batch:
    count = 1
    count = 2
    print seen
  print seen
  var inner = ""
  if true:
    watch count:
      inner = inner + "x"
    count = 3
  count = 4
  print seen
  print inner
  computed current: int = current + 1
  try:
    print current
    print "ran"
  catch error:
    print error
  state other = 0
  var flushed = -1
  watch other:
    flushed = other
  try:
    batch:
      other = 7
      throw "stop"
  catch error:
    print flushed
''', '0\n2\n4\nxx\nCycleError\n7\n');
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

  test('expression comprehensions filter, nest, and build eagerly', () async {
    await execute('''
main():
  var hits = 0
  var reads = 0
  bump() -> int:
    hits = hits + 1
    return hits
  source() -> List<int>:
    reads = reads + 1
    return [1, 2, 3]
  eager = [bump() for n in 1..3 if n != 2]
  print hits
  print eager.length
  count() sync* -> int:
    yield bump()
  print hits
  for value in count():
    print value
  print hits
  picked = [n for n in source() if n > 1]
  print reads
  print picked.length
  nested = [[n for n in 1..2] for row in 1..2 if row > 0]
  print nested.length
  print nested[0][0]
  print nested[0][1]
  print nested[1][1]
  unique = set:
    n for n in [1, 1, 2, 3] if n > 1
  print unique.length
''', '''
2
2
2
3
3
1
2
2
1
2
2
2
''');
  });

  test('null promotion, if-null assignment, and nested types execute',
      () async {
    await execute('''
class Cell:
  var n: int = 1
text() -> String? = "a"
word() -> String? = "Ada"
yes() -> bool? = true
main():
  var hits = 0
  next() -> String:
    hits = hits + 1
    return "b"
  kept = text()
  print kept ?? next()
  print hits
  var slot = text()
  slot ??= next()
  print slot
  print hits
  slot = null
  slot ??= next()
  print slot
  print hits
  print slot.length
  var name = word()
  if name != null and name.length == 3:
    print name.length
  var flag = yes()
  if flag != null and flag:
    print "yes"
  name = null
  if name == null:
    print "none"
  else:
    print name.length
  grid: List<List<List<int>>> = [[[4]]]
  print grid[0][0][0]
  var cell = Cell()
  row: readonly List<Cell> = [cell]
  print row[0].n
  cell.n = 5
  print row[0].n
''', '''
a
0
a
0
b
1
1
3
yes
none
4
1
5
''');
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

  test('if let, defer, static members, and const constructors execute',
      () async {
    await execute(
        '''
class Log:
  title: String required
  dispose() async -> void:
    print "closed {title}"
mark() async -> void:
  print "later"
pick(value: String?) -> String? = value
class MathUtil:
  static const pi = 3
  static twice(n: int) -> int = n * 2
value class Pair:
  x: int required
  y: int required
  tag: String? = null
  const init(this.x, this.y, this.tag)
main() async:
  print MathUtil.pi
  print MathUtil.twice(3)
  pair = Pair(1, 2, null)
  next = pair.copyWith(y: 5)
  print next.x
  print next.y
  print next.tag == null
  same = pair.copyWith()
  print same.x
  kept = pair.copyWith(tag: "z")
  print kept.tag
  cleared = kept.copyWith(tag: null)
  print cleared.tag == null
  if let found = pick(null):
    print found
  else:
    print "none"
  if let found = pick("Ada"):
    print found
  else:
    print "none"
  using async file = Log(title: "a"):
    defer print "first"
    defer print "second"
    print "body"
  defer await mark()
  print "after"
''',
        '3\n'
            '6\n'
            '1\n'
            '5\n'
            'true\n'
            '1\n'
            'z\n'
            'true\n'
            'none\n'
            'Ada\n'
            'body\n'
            'second\n'
            'first\n'
            'closed a\n'
            'after\n'
            'later\n');
  });

  test('part lowers to a Dart part directive', () {
    final dart = compile('part "extra.quds"\nmain():\n  print 1\n').dart;
    expect(dart, contains("part 'extra.dart';"));
  });

  test('patterns, generics, await groups, and contracts execute', () async {
    final source = '''
interface Named:
  name: String
interface Identifiable:
  id: int
class User implements Named, Identifiable:
  name: String required
  id: int required
class Box<T>:
  value: T required
  same() -> T:
    return value
class Producer<out T>:
  value: T required
class Counter:
  static var count: int = 0
class Proxy:
  noSuchMethod(invocation: Invocation) -> dynamic:
    return "missing"
extend List<T>:
  secondOrNull() -> T?:
    if length < 2:
      return null
    return this[1]
value class Pair:
  x: int required
  y: int = 2
  init(this.x):
    require x == x
annotation Tag:
@Tag
@Reflectable
class Item:
  caption: String = "item"
one() async -> int:
  return 1
two() async -> int:
  return 2
doubleIt(n: int) -> int = n * 2
show(item: Named & Identifiable):
  print item.name
  print item.id
config port: int = 8080
main() async:
  print config.port
  show(User(name: "Ada", id: 7))
  box = Box(value: "Ada")
  print box.same()
  Counter.count = 4
  print Counter.count
  items = [1, 2, 3]
  print items.secondOrNull()
  pair = Pair(x: 1)
  next = pair.copyWith(x: 9)
  print next.x
  print next.y
  point = (1, 2)
  match point:
    (x, y):
      print x
      print y
  match items:
    [first, ...rest]:
      print first
      print rest.length
  match 3:
    < 0:
      print "neg"
    >= 0 and < 10:
      print "small"
    _:
      print "other"
  match 1:
    0 | 1:
      print "low"
    _:
      print "other"
  captionText: String? = "Ada"
  match captionText:
    text?:
      print text
    null:
      print "none"
  data = map:
    "mode": "dark"
  match data:
    map:
      "mode": mode
    :
      print mode
  proxy: dynamic = Proxy()
  print proxy.other()
  waited = await all:
    one()
    two()
  print waited
  print await isolate:
    doubleIt(4)
  task group:
    spawn one()
    spawn two()
  print "done"
  require 1 < 2
  check 2 > 1, "ok"
  assert true
  print symbol "name"
''';
    await execute(source, '''
8080
Ada
7
Ada
4
2
9
2
1
2
1
2
small
low
Ada
dark
missing
(1, 2)
8
done
Symbol("name")
''');
    expect(compile(source).dart, contains('qudsReflectItem'));
    expect(compile(source).dart, contains('@Tag()'));
    expect(compile(source).dart, contains('extends Named'));
  });

  test('config follows the environment, then quds.yaml, then the source',
      () async {
    const source = '''
config port: int = 8080
config secret token: String
config server.host: String = "localhost"
main():
  print config.port
  print config.server.host
  print config.token
''';
    final directory = Directory.systemTemp.createTempSync('quds-config-');
    try {
      final output = File('${directory.path}/app.dart')
        ..writeAsStringSync(compile(source).dart);
      final analysis = await Process.run(
          Platform.resolvedExecutable, ['analyze', output.path]);
      expect(analysis.exitCode, 0,
          reason: '${analysis.stdout}\n${output.readAsStringSync()}');
      Future<ProcessResult> run(
          {Map<String, String>? environment, String? yaml}) {
        final file = File('${directory.path}/quds.yaml');
        if (yaml == null) {
          if (file.existsSync()) file.deleteSync();
        } else {
          file.writeAsStringSync(yaml);
        }
        final env = Map<String, String>.of(Platform.environment)
          ..remove('PORT')
          ..remove('SERVER_HOST')
          ..remove('TOKEN');
        if (environment != null) env.addAll(environment);
        return Process.run(Platform.resolvedExecutable, [output.path],
            workingDirectory: directory.path, environment: env);
      }

      final defaults = await run();
      expect(defaults.exitCode, isNot(0), reason: '${defaults.stderr}');
      expect('${defaults.stderr}', contains('Missing required config token'));

      final yaml = await run(environment: {'TOKEN': 'hidden'}, yaml: '''
config:
  port: 9090
  server:
    host: db
''');
      expect(yaml.exitCode, 0, reason: '${yaml.stderr}\n${yaml.stdout}');
      expect(yaml.stdout, '9090\ndb\nhidden\n');

      final environment = await run(environment: {
        'PORT': '7070',
        'SERVER_HOST': 'primary',
        'TOKEN': 'secret'
      }, yaml: '''
config:
  port: 9090
  server:
    host: db
''');
      expect(environment.exitCode, 0, reason: '${environment.stderr}');
      expect(environment.stdout, '7070\nprimary\nsecret\n');
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('annotation arguments and constructor-body copyWith execute', () async {
    final source = '''
annotation Tag(caption: String = "item"):
@Tag(caption: "box")
value class Pair:
  x: int
  y: int
  init(this.x):
    y = x + 1
main():
  pair = Pair(x: 1)
  print pair.y
  copied = pair.copyWith(x: 4)
  print copied.x
  print copied.y
  replaced = pair.copyWith(y: 9)
  print replaced.x
  print replaced.y
''';
    final dart = compile(source).dart;
    expect(dart, contains('@Tag(caption: "box")'));
    expect(dart, contains('this.caption = "item"'));
    expect(dart, contains('_qudsCopy'));
    await execute(
        source,
        '2\n'
        '4\n'
        '2\n'
        '1\n'
        '9\n');
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
      '''
mixin A:
  name() -> String = "a"
mixin B:
  name() -> int = 1
class C with A, B:
  ready: int = 1
main():
  print 1
''': 'E300',
      '''
singleton class A:
  other: B = B.instance
singleton class B:
  other: A = A.instance
main():
  print 1
''': 'E707',
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
      '''
main():
  found = "outer"
  name: String? = "Ada"
  if let found = name:
    print found
''': 'E203',
      '''
main():
  defer await ready()
''': 'E803',
      '''
class MathUtil:
  static const pi = 3
main():
  box = MathUtil()
  print box.pi
''': 'E300',
      '''
class Bad<out T>:
  take(item: T) -> void:
    return
main():
  print 1
''': 'E304',
      '''
class Bad<out T>:
  reader: (T) -> int
main():
  print 1
''': 'E304',
      '''
class Base:
  id(value: int) -> int = value
class Child extends Base:
  id(value: int) -> String = "no"
main():
  print 1
''': 'E300',
      '''
main():
  f = x -> x
''': 'E302',
      '''
main():
  items = []
''': 'E302',
      '''
main():
  empty = map:
  print 1
''': 'E302',
      '''
main():
  empty = set:
  print 1
''': 'E302',
      '''
main():
  values = [n for n in 1..2 if n]
''': 'E300',
      '''
main():
  name: String? = "Ada"
  print name.length
''': 'E308',
      '''
main():
  var flag: bool? = true
  if flag:
    print 1
''': 'E308',
      '''
main():
  var name: String? = "Ada"
  if name != null:
    name = null
    print name.length
''': 'E308',
      '''
main():
  var n = 1
  n ??= 2
''': 'E300',
      '''
class Cell:
  var n: int = 1
main():
  row: readonly List<Cell> = [Cell()]
  row[0].n = 2
''': 'E307',
      '''
twice() -> int = 2
main():
  twice
''': 'E110',
      '''
interface Named:
  name: String
interface Identifiable:
  id: int
class Only implements Named:
  name: String required
show<T: Named & Identifiable>(item: T) -> String = item.name
main():
  print show(Only(name: "No"))
''': 'E500',
      '''
show(item: int & String):
  print item
main():
  print 1
''': 'E306',
      '''
main() async:
  n = 4
  print await isolate:
    doubleIt(n)
doubleIt(n: int) -> int = n
''': 'E805',
      '''
config secret token: String = "hidden"
main():
  print 1
''': 'E908',
      '''
annotation Tag(caption: String):
@Tag
class Item:
  n: int = 1
main():
  print 1
''': 'E500',
      '''
annotation Tag(caption: String = "a"):
@Tag(caption: captionText())
class Item:
  n: int = 1
captionText() -> String = "b"
main():
  print 1
''': 'E401',
      '''
main():
  spawn ready()
''': 'E107',
      '''
main():
  log.minimum = "verbose"
''': 'E300',
    };
    rejected.forEach((source, code) {
      expect(() => compile(source), throwsA(predicate((error) {
        return '$error'.contains(code);
      })), reason: source);
    });
  });

  test('logs filter and redact, and a task group skips an unentered child',
      () async {
    await execute('''
class Probe:
  static var hits: int = 0
boom() -> int:
  var ready = true
  if ready:
    throw "bad"
  return 0
later() -> int:
  Probe.hits = Probe.hits + 1
  return Probe.hits
slow() async -> int:
  Probe.hits = Probe.hits + 1
  return Probe.hits
boomAsync() async -> int:
  var ready = true
  if ready:
    throw "bad"
  return 0
inner() async -> int:
  task group:
    spawn boom()
    spawn later()
  return 1
record(level: String, message: dynamic, data: dynamic):
  print "{level}:{message}:{data}"
failSink(level: String, message: dynamic, data: dynamic):
  throw "sink"
main() async:
  log.minimum = "info"
  log.debug "skip", data: map:
    "secret": "nope"
  log.info "Loaded", data: map:
    "count": "3"
    "secret": "token"
    "token_secret": "abc"
  log.sink record
  log.warning "kept", data: map:
    "name": "Ada"
    "api_secret": "hidden"
  log.sink failSink
  try:
    log.error "boom"
  catch error:
    print error
  try:
    task group:
      spawn boom()
      spawn later()
  catch error:
    print Probe.hits
  Probe.hits = 0
  try:
    task group:
      spawn boomAsync()
      spawn slow()
  catch error:
    print Probe.hits
  Probe.hits = 0
  try:
    print await inner()
  catch error:
    print Probe.hits
''', '''
[info] Loaded {count: 3, secret: ***, token_secret: ***}
warning:kept:{name: Ada, api_secret: ***}
sink
0
1
0
''');
  });

  test('an imported library hides private members and exports the public ones',
      () async {
    final directory = Directory.systemTemp.createTempSync('quds-library-');
    File('${directory.path}/math.quds').writeAsStringSync('''
doubleIt(n: int) -> int = n * 2
class Box:
  value: int required
  private secret: int = 1
  protected shown: int = 2
  read() -> int = secret
  reveal() -> int = shown
''');
    File('${directory.path}/api.quds').writeAsStringSync('''
export "math.quds"
''');
    final app = File('${directory.path}/app.quds')..writeAsStringSync('''
use "api.quds"
main():
  print doubleIt(4)
  box = Box(value: 3)
  print box.read()
  print box.reveal()
''');
    final child = File('${directory.path}/child.quds')..writeAsStringSync('''
use "math.quds"
class Child extends Box:
  peek() -> int = shown
main():
  print Child(value: 5).peek()
  print Child(value: 5).read()
''');
    expect(() => compile('''
use "math.quds"
main():
  print Box(value: 1).secret
''', file: '${directory.path}/secret.quds'),
        throwsA(predicate((error) => '$error'.contains('E206'))));
    expect(() => compile('''
use "math.quds"
main():
  print Box(value: 1).shown
''', file: '${directory.path}/shown.quds'),
        throwsA(predicate((error) => '$error'.contains('E207'))));
    expect(() => compile('''
use "math.quds"
class Child extends Box:
  peek() -> int = secret
main():
  print 1
''', file: '${directory.path}/child_secret.quds'),
        throwsA(predicate((error) => '$error'.contains('E206'))));
    for (final source in [File('${directory.path}/math.quds'), app, child]) {
      final dartPath = source.path.replaceFirst(RegExp(r'\.quds$'), '.dart');
      File(dartPath).writeAsStringSync(
          compile(source.readAsStringSync(), file: source.path).dart);
    }
    File('${directory.path}/api.dart').writeAsStringSync(compile(
            File('${directory.path}/api.quds').readAsStringSync(),
            file: '${directory.path}/api.quds')
        .dart);
    for (final name in ['app.dart', 'child.dart']) {
      final output = File('${directory.path}/$name');
      final analysis = await Process.run(
          Platform.resolvedExecutable, ['analyze', output.path]);
      expect(analysis.exitCode, 0,
          reason:
              '${analysis.stdout}\n${analysis.stderr}\n${output.readAsStringSync()}');
      final run = await Process.run(Platform.resolvedExecutable, [output.path]);
      expect(run.exitCode, 0,
          reason: '${run.stderr}\n${output.readAsStringSync()}');
    }
    final appRun = await Process.run(
        Platform.resolvedExecutable, ['${directory.path}/app.dart']);
    final childRun = await Process.run(
        Platform.resolvedExecutable, ['${directory.path}/child.dart']);
    expect(appRun.stdout, '8\n1\n2\n');
    expect(childRun.stdout, '2\n1\n');
    directory.deleteSync(recursive: true);
  });

  test('show, hide, and a prefix bind only the selected names', () async {
    final directory = Directory.systemTemp.createTempSync('quds-show-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/math.quds').writeAsStringSync('''
doubleIt(n: int) -> int = n * 2
class Box:
  value: int required
  private secret: int = 1
  protected shown: int = 2
''');
    File('${directory.path}/api.quds').writeAsStringSync('''
export "math.quds" show doubleIt
''');
    expect(() => compile('''
use "math.quds" show missingName
main():
  print 1
''', file: '${directory.path}/missing.quds'),
        throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use "math.quds" show doubleIt
main():
  item = Box(value: 1)
  print item.value
''', file: '${directory.path}/only.quds'),
        throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use "math.quds" hide Box
main():
  item = Box(value: 1)
  print item.value
''', file: '${directory.path}/hidden.quds'),
        throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use "api.quds"
main():
  item = Box(value: 1)
  print item.value
''', file: '${directory.path}/exported.quds'),
        throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:core hide Ok
main():
  print Ok(1)
''', file: '${directory.path}/prelude.quds'),
        throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use dart:math as m show sqrt
main():
  print m.sin(0)
''', file: '${directory.path}/trig.quds'),
        throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use "math.quds" as math
main():
  print math.Box(value: 1).secret
''', file: '${directory.path}/prefixed_secret.quds'),
        throwsA(predicate((error) => '$error'.contains('E206'))));

    final shown = File('${directory.path}/shown.quds')..writeAsStringSync('''
use "math.quds" show doubleIt
use "math.quds" as math
use dart:math as m show sqrt
main():
  print doubleIt(4)
  print math.doubleIt(4)
  item = math.Box(value: 3)
  print item.value
  print m.sqrt(9)
''');
    final apiApp = File('${directory.path}/api_app.quds')..writeAsStringSync('''
use "api.quds"
main():
  print doubleIt(5)
''');
    for (final source in [
      shown,
      apiApp,
      File('${directory.path}/math.quds'),
      File('${directory.path}/api.quds'),
    ]) {
      final dartPath = source.path.replaceFirst(RegExp(r'\.quds$'), '.dart');
      File(dartPath).writeAsStringSync(
          compile(source.readAsStringSync(), file: source.path).dart);
    }
    final shownDart = File('${directory.path}/shown.dart').readAsStringSync();
    expect(shownDart, contains("import 'math.dart' show doubleIt;"));
    expect(shownDart, contains("import 'math.dart' as math;"));
    expect(shownDart, contains("import 'dart:math' as m show sqrt;"));
    expect(shownDart, contains('math.Box'));
    expect(shownDart, contains('math.doubleIt'));
    expect(File('${directory.path}/api.dart').readAsStringSync(),
        contains("export 'math.dart' show doubleIt;"));
    for (final name in ['shown.dart', 'api_app.dart']) {
      final output = File('${directory.path}/$name');
      final analysis = await Process.run(
          Platform.resolvedExecutable, ['analyze', output.path]);
      expect(analysis.exitCode, 0,
          reason:
              '${analysis.stdout}\n${analysis.stderr}\n${output.readAsStringSync()}');
      final run = await Process.run(Platform.resolvedExecutable, [output.path]);
      expect(run.exitCode, 0,
          reason: '${run.stderr}\n${output.readAsStringSync()}');
    }
    final shownRun = await Process.run(
        Platform.resolvedExecutable, ['${directory.path}/shown.dart']);
    final apiRun = await Process.run(
        Platform.resolvedExecutable, ['${directory.path}/api_app.dart']);
    expect(shownRun.stdout, '8\n8\n3\n3.0\n');
    expect(apiRun.stdout, '10\n');
  });

  test('part files share one library privacy scope', () async {
    final directory = Directory.systemTemp.createTempSync('quds-part-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final parent = File('${directory.path}/parent.quds')..writeAsStringSync('''
part "detail.quds"
class Box:
  private secret: int = 1
main():
  print read(box: Box(secret: 1))
''');
    final detail = File('${directory.path}/detail.quds')..writeAsStringSync('''
part of "parent.quds"
read(box: Box) -> int = box.secret
''');
    expect(() => compile('''
part "gone.quds"
main():
  print 1
''', file: '${directory.path}/missing_part.quds'),
        throwsA(predicate((error) => '$error'.contains('E900'))));
    File('${directory.path}/bad.quds').writeAsStringSync('''
part of "other.quds"
read() -> int = 1
''');
    expect(() => compile('''
part "bad.quds"
main():
  print 1
''', file: '${directory.path}/bad_parent.quds'),
        throwsA(predicate((error) => '$error'.contains('E903'))));
    expect(() => compile('''
part of "other.quds"
read() -> int = 1
''', file: detail.path),
        throwsA(predicate((error) => '$error'.contains('E903'))));
    for (final source in [parent, detail]) {
      final dartPath = source.path.replaceFirst(RegExp(r'\.quds$'), '.dart');
      File(dartPath).writeAsStringSync(
          compile(source.readAsStringSync(), file: source.path).dart);
    }
    final parentDart = File('${directory.path}/parent.dart');
    final detailDart = File('${directory.path}/detail.dart');
    expect(detailDart.readAsStringSync(), contains('_secret'));
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', parentDart.path]);
    expect(analysis.exitCode, 0,
        reason:
            '${analysis.stdout}\n${analysis.stderr}\n${parentDart.readAsStringSync()}\n${detailDart.readAsStringSync()}');
    final run =
        await Process.run(Platform.resolvedExecutable, [parentDart.path]);
    expect(run.exitCode, 0,
        reason:
            '${run.stderr}\n${parentDart.readAsStringSync()}\n${detailDart.readAsStringSync()}');
    expect(run.stdout, '1\n');
  });

  test('quds.yaml selects the language version and a comment does not', () {
    final directory = Directory.systemTemp.createTempSync('quds-version-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final source = File('${directory.path}/app.quds')
      ..writeAsStringSync('# quds: 1.2\nmain():\n  print 1\n');
    File('${directory.path}/quds.yaml').writeAsStringSync('language: "1.0"\n');
    expect(() => compile(source.readAsStringSync(), file: source.path),
        throwsA(predicate((error) => '$error'.contains('E901'))));
    File('${directory.path}/quds.yaml').writeAsStringSync('language: "1.2"\n');
    final built =
        compile('# quds: 1.0\nmain():\n  print 1\n', file: source.path);
    expect(built.dart, contains('print(1)'));
  });

  test('reflectable metadata lists private fields and type parameters',
      () async {
    final source = '''
@Reflectable
class Box<T>:
  value: T required
  private secret: int = 1
  read() -> int = secret
class Other:
  name: String = "a"
main():
  print Box<int>(value: 1, secret: 2).read()
''';
    final dart = compile(source).dart;
    expect(dart, contains("'fields': <String>['value']"));
    expect(dart, contains("'private': <String>['secret']"));
    expect(dart, contains("'typeParameters': <String>['T']"));
    expect(
        dart, contains('const qudsReflectable = <Object?>[qudsReflectBox];'));
    expect(dart.contains('qudsReflectOther'), isFalse);
    final directory = Directory.systemTemp.createTempSync('quds-reflect-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final output = File('${directory.path}/app.dart')..writeAsStringSync(dart);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}\n${analysis.stderr}\n$dart');
  });

  test('generated Dart runs without the Quds package', () async {
    final dart = compile('main():\n  print 7\n').dart;
    expect(dart.contains('package:quds_lang'), isFalse);
    final directory = Directory.systemTemp.createTempSync('quds-consumer-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final output = File('${directory.path}/app.dart')..writeAsStringSync(dart);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}\n${analysis.stderr}\n$dart');
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.exitCode, 0, reason: '${run.stderr}\n$dart');
    expect(run.stdout, '7\n');
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
