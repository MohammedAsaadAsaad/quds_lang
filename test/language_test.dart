import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/sdk.dart';
import 'package:test/test.dart';

void main() {
  test('several bindings can share one line', () async {
    compile('''
main():
  if true: var shown = 1, extra = shown + 1
''');
    await execute('''
const left = 2, right = 3
main():
  var whole = 0.0, fraction = 0.0
  var scale = 1.0, dot = false
  var piece = "ab", amount = whole + scale
  var items = [left, right], count = 2
  if true:
    var shown = 1, extra = shown + 1
    print extra
  print whole
  print fraction
  print amount
  print dot
  print piece
  print items.length
  print count
  print left + right
''', '2\n0.0\n0.0\n1.0\nfalse\nab\n2\n2\n5\n');
  });

  test('slices, characters, numbers, and chained comparisons execute',
      () async {
    await execute(
        '''
main():
  text = "ab cd"
  print text[1..]
  print text[..<4]
  print text[1..<3]
  items = [0, 1, 2, 3, 4]
  print items[1..3]
  print items[2..]
  print text.drop(1)
  print text.dropLast(1)
  print text.take(2)
  print text.takeLast(2)
  print items.drop(1)
  print items.dropLast(1)
  print items.take(2)
  print items.takeLast(2)
  var letters = ""
  for piece in text:
    if piece != " ": letters = letters + piece
  print letters
  print text.chars.where(piece -> piece != " ").toList()
  n = -3
  print n.abs
  print 4.round
  print 1.6.round
  print 1.2.floor
  print 1.8.ceil
  print 4.clamp(0, 3)
  print min(4, 2)
  print max(4, 2)
  piece = "5"
  if "0" <= piece <= "9": print piece
  index = 1
  if 0 <= index < items.length: print items[index]
  var shown = ""
  for i, item in items.take(3):
    shown = shown + "{i}{item}"
  print shown
  var marked = ""
  for i, letter in "ab":
    marked = marked + "{i}{letter}"
  print marked
  print "-" * 4
  print 2 * "ab"
  print 7.pad(3)
  negative = (-3).pad(4)
  print negative
  var steps = 0
  step() -> int:
    steps = steps + 1
    return steps
  print step() > step() < step()
  print steps
''',
        'b cd\n'
            'ab c\n'
            'b \n'
            '[1, 2, 3]\n'
            '[2, 3, 4]\n'
            'b cd\n'
            'ab c\n'
            'ab\n'
            'cd\n'
            '[1, 2, 3, 4]\n'
            '[0, 1, 2, 3]\n'
            '[0, 1]\n'
            '[3, 4]\n'
            'abcd\n'
            '[a, b, c, d]\n'
            '3\n'
            '4\n'
            '2\n'
            '1\n'
            '2\n'
            '3\n'
            '2\n'
            '4\n'
            '5\n'
            '1\n'
            '001122\n'
            '0a1b\n'
            '----\n'
            'abab\n'
            '007\n'
            '-003\n'
            'false\n'
            '3\n');
  });

  test('negative indexes, membership, counted repeat, and zip execute',
      () async {
    await execute(
        r'''
main():
  text = "abcd"
  print text[-1]
  items = [0, 1, 2, 3, 4]
  print items[-1]
  print items[-2..]
  print text[..<-1]
  print text[-3..-1]
  if "2" in "012": print "yes"
  if "12" in "0123": print "12"
  if "a" not in "012": print "no"
  seen = ["a", "b"]
  if "b" in seen: print "b"
  if "c" not in seen: print "c"
  ages = map:
    "Ada": 1
  if "Ada" in ages: print "Ada"
  keys = map:
    -1: "end"
  print keys[-1]
  var n = 0
  repeat 3:
    n = n + 1
  print n
  repeat 0:
    n = n + 1
  print n
  names = ["Ada", "Bea"]
  scores = [1, 2, 3]
  var shown = ""
  for name, score in names.zip(scores):
    shown = shown + "{name}{score}"
  print shown
  var marked = ""
  for i, item in scores.take(2):
    marked = marked + "{i}{item}"
  print marked
  lines = "a\n\nb"
  print lines.lines
  print "hi".padEnd(4)
  print "hi".padStart(4, "0")
  print "hello".padEnd(3)
  var reads = 0
  left() -> List<String>:
    reads = reads + 1
    return ["A"]
  right() -> List<int>:
    reads = reads + 1
    return [1, 2]
  for name, score in left().zip(right()):
    print "{name}{score}"
  print reads
''',
        'd\n'
            '4\n'
            '[3, 4]\n'
            'abc\n'
            'bcd\n'
            'yes\n'
            '12\n'
            'no\n'
            'b\n'
            'c\n'
            'Ada\n'
            'end\n'
            '3\n'
            '3\n'
            'Ada1Bea2\n'
            '0112\n'
            '[a, , b]\n'
            'hi  \n'
            '00hi\n'
            'hello\n'
            'A1\n'
            '2\n');
  });

  test(
      'pairs, dedent, number text, range steps, and joined collections execute',
      () async {
    await execute(
        '''
main():
  marks = ["AC", "+"]
  tones = ["fn", "op"]
  row = [
    for mark, tone in marks.zip(tones):
      "{mark}{tone}"
  ]
  print row
  letters = ["a", "b"]
  indexed = [
    for i, letter in letters:
      "{i}{letter}"
  ]
  print indexed
  name = "Ada"
  message = """
  Hello
  {name}
  """
  print message
  block = """
  a

  b
  """
  print block
  fixed = (1.5).fixed(2)
  negative = (-1.2).fixed(2)
  whole = (10).fixed(1)
  trimmed = (10.0).plain
  one = (1.0).plain
  huge = (1e21).plain
  print fixed
  print negative
  print whole
  print trimmed
  print one
  print huge
  var up = ""
  for i in 0..10 step 2:
    up = up + "{i}"
  print up
  var down = ""
  for i in 10..0 step -2:
    down = down + "{i}"
  print down
  var cut = ""
  for i in 10..<0 step -2:
    cut = cut + "{i}"
  print cut
  var stalled = ""
  for i in 0..10 step -2:
    stalled = stalled + "{i}"
  print stalled
  var called = ""
  for i in range(0, 4) step 2:
    called = called + "{i}"
  print called
  var legacy = ""
  for i in 4..2:
    legacy = legacy + "{i}"
  print legacy
  left = [1]
  right = [2, 3]
  mixed = [1.5]
  print left + right
  print left + mixed
  kept: readonly List<int> = [1]
  print kept + right
  ages = map:
    "a": 1
  extra = map:
    "a": 2
    "b": 3
  print ages + extra
  var reads = 0
  mark(note: String, value: int) -> int:
    print note
    return value
  for i in mark("a", 0)..mark("b", 4) step mark("c", 2):
    print i
  listLeft() -> List<int>:
    reads = reads + 1
    return [1]
  listRight() -> List<int>:
    reads = reads + 1
    return [2]
  print listLeft() + listRight()
  print reads
''',
        '[ACfn, +op]\n'
            '[0a, 1b]\n'
            'Hello\n'
            'Ada\n'
            'a\n'
            '\n'
            'b\n'
            '1.50\n'
            '-1.20\n'
            '10.0\n'
            '10\n'
            '1\n'
            '1e+21\n'
            '0246810\n'
            '1086420\n'
            '108642\n'
            '\n'
            '024\n'
            '432\n'
            '[1, 2, 3]\n'
            '[1, 1.5]\n'
            '[1, 2, 3]\n'
            '{a: 2, b: 3}\n'
            'a\n'
            'b\n'
            'c\n'
            '0\n'
            '2\n'
            '4\n'
            '[1, 2]\n'
            '2\n');
    final zero = compile('''
main():
  var n = 0
  for i in 0..2 step n:
    print i
''').dart;
    final negative = compile('''
main():
  shown = (1.5).fixed(-1)
  print shown
''').dart;
    final directory = Directory.systemTemp.createTempSync('quds-step-');
    try {
      final stepFile = File('${directory.path}/step.dart')
        ..writeAsStringSync(zero);
      final fixedFile = File('${directory.path}/fixed.dart')
        ..writeAsStringSync(negative);
      final step =
          await Process.run(Platform.resolvedExecutable, [stepFile.path]);
      final digits =
          await Process.run(Platform.resolvedExecutable, [fixedFile.path]);
      expect(step.exitCode, isNot(0), reason: '${step.stdout}');
      expect('${step.stderr}', contains('RangeError'));
      expect(digits.exitCode, isNot(0), reason: '${digits.stdout}');
      expect('${digits.stderr}', contains('RangeError'));
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('a misspelled name suggests the nearest spelling', () {
    expect(
        () => compile('''
dropLast(text: String) -> String = text
main():
  print dropLas
'''),
        throwsA(isA<CompilerException>().having((error) => error.message,
            'message', 'Undefined symbol: dropLas. Did you mean dropLast?')));
    expect(
        () => compile('''
main():
  print "hi".dropLas()
'''),
        throwsA(isA<CompilerException>().having((error) => error.message,
            'message', 'No method dropLas on String. Did you mean dropLast?')));
    expect(
        () => compile('''
main():
  print "hi".lenght
'''),
        throwsA(isA<CompilerException>().having((error) => error.message,
            'message', 'No member lenght on String. Did you mean length?')));
    expect(
        () => compile('''
main():
  dropLast = 1
  print droplast
'''),
        throwsA(isA<CompilerException>().having((error) => error.message,
            'message', 'Undefined symbol: droplast. Did you mean dropLast?')));
    expect(
        () => compile('''
main():
  cat = 1
  car = 2
  print cap
'''),
        throwsA(isA<CompilerException>().having(
            (error) => error.message, 'message', 'Undefined symbol: cap')));
  });

  test('trailing conditions and parallel assignment execute', () async {
    await execute(
        '''
read(values: List<String?>, index: int) -> String?:
  if index >= values.length: return null
  return values[index]
show(text: String) -> String:
  return text if text.isNotEmpty
  return "empty"
main():
  print show("Ada")
  print show("")
  var kept = ""
  for name in ["a", "", "b"]:
    continue if name == ""
    kept = kept + name
  print kept
  loaded = Ok("Ada")
  print "yes" if loaded is Ok
  failed = Error("no")
  print "no" if failed is Error
  var value: String? = "Ada"
  print line if let line = value
  value = null
  var caption = "skip"
  caption = line if let line = value
  print caption
  firstLine: String? = "a"
  secondLine: String? = "b"
  thirdLine: String? = null
  values = [firstLine, secondLine, thirdLine]
  var i = 0
  var shown = ""
  while let line = read(values, i):
    shown = shown + line
    i = i + 1
  print shown
  first: Object = "a"
  second: Object = "b"
  third: Object = 1
  items = [first, second, third]
  i = 0
  var texts = ""
  while items[i] is String text:
    texts = texts + text
    i = i + 1
  print texts
  letters = ["a", "b", "c", "d"]
  [head, ...middle, tail] = letters
  print head
  print middle
  print tail
  person = ("Ada", 36)
  name, age = person
  print name
  print age
  var a = 1
  var b = 2
  var n = 0
  bump(mark: int) -> int:
    n = n + 1
    print mark
    return mark
  a, b = bump(b), bump(a)
  print a
  print b
  print n
  outer = "outer"
  if true:
    shadow outer, extra = person
    print outer
    print extra
  print outer
''',
        'Ada\n'
            'empty\n'
            'ab\n'
            'yes\n'
            'no\n'
            'Ada\n'
            'skip\n'
            'ab\n'
            'ab\n'
            'a\n'
            '[b, c]\n'
            'd\n'
            'Ada\n'
            '36\n'
            '2\n'
            '1\n'
            '2\n'
            '1\n'
            '2\n'
            'Ada\n'
            '36\n'
            'outer\n');
    final directory = Directory.systemTemp.createTempSync('quds-pattern-');
    try {
      final short = compile('''
main():
  [first, second] = ["only"]
  print first
''').dart;
      final file = File('${directory.path}/short.dart')
        ..writeAsStringSync(short);
      final run = await Process.run(Platform.resolvedExecutable, [file.path]);
      expect(run.exitCode, isNot(0), reason: '${run.stdout}');
      expect('${run.stderr}', contains('Pattern did not match'));
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('loop else, value loops, and where execute', () async {
    await execute(
        '''
main():
  show(text: String) -> String:
    return text if text.isNotEmpty else "empty"
  print show("Ada")
  print show("")
  var caption = "x"
  read() -> String?:
    return null
  caption = line if let line = read() else "فارغ"
  print caption
  var number: Object = 1
  print text if number is String text else "ليس نصاً"
  objectText() -> Object:
    return "Ada"
  word: Object = objectText()
  print text if word is String text else "ليس نصاً"
  names = ["Ada", "Bea"]
  ids = [1, 2]
  var found = ""
  for i, name in names:
    if ids[i] == 2:
      found = name
      break
  else:
    found = "غير موجود"
  print found
  found = ""
  for i, name in names:
    if ids[i] == 9:
      found = name
      break
  else:
    found = "غير موجود"
  print found
  picked = for i, name in names:
    if ids[i] == 2: break name
  else:
    null
  print picked
  absent = for i, name in names:
    if ids[i] == 9: break name
  else:
    "none"
  print absent
  var seen = ""
  for name in ["a", "", "b"]:
    continue if name == ""
    seen = seen + name
  else:
    seen = seen + "!"
  print seen
  var n = 0
  while n < 2:
    n = n + 1
  else:
    n = n + 10
  print n
  var hit = 0
  while hit < 5:
    hit = hit + 1
    if hit == 1: break
  else:
    hit = 100
  print hit
  items = [1, 2, 3]
  print total / count where total = items.sum(), count = items.length
  title = "{name} ({age})" where:
    name = "Ada"
    age = 36
  print title
''',
        'Ada\n'
            'empty\n'
            'فارغ\n'
            'ليس نصاً\n'
            'Ada\n'
            'Bea\n'
            'غير موجود\n'
            'Bea\n'
            'none\n'
            'ab!\n'
            '12\n'
            '1\n'
            '2.0\n'
            'Ada (36)\n');
  });

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
reject() -> Result<int, String>:
  return Error("no")
failed() -> Result<int, String>:
  value = reject()?
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
use dart:math show sqrt
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
    final dart = File('${directory.path}/.dart_tool/quds/out/app.dart')
        .readAsStringSync();
    expect(dart, compile(source.readAsStringSync(), file: source.path).dart);
    final map = File('${directory.path}/.dart_tool/quds/out/app.dart.map')
        .readAsStringSync();
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
    expect(suite.stdout, '1\nok adds\n2\nok inner\nok suite\n');
    File('${directory.path}/miss.quds').writeAsStringSync('''
test "no":
  expect(1, 2)
test "near":
  expect(1.0, closeTo(2.0, 0.1), reason: "needed two")
''');
    final missed = await cli(['test', '${directory.path}/miss.quds']);
    expect(missed.exitCode, isNot(0), reason: '${missed.stdout}');
    expect(missed.stdout, contains('FAIL no: Expected: <2>'));
    expect(missed.stdout, contains('  Actual: <1>'));
    expect(missed.stdout, contains('a numeric value within <0.1> of <2.0>'));
    expect(missed.stdout, contains('needed two'));
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

  test('wrapped values, nullable extensions, and readonly boundaries execute',
      () async {
    const source = '''
type Percentage wraps int:
  require value >= 0 and value <= 100
extend String?:
  orEmpty() -> String = this ?? ""
expose() -> readonly List<int> = [1]
keep(items: readonly List<int>) -> int = items.length
add(a: int, b: int) -> int = a + b
later(read: () -> int) async -> int:
  return read()
main() async:
  items: List<num> = [1]
  print items[0]
  flags: Set<num> = set:
    1
  print flags.length
  ages: Map<String, num> = map:
    "Ada": 1
  print ages["Ada"]
  const ok = Percentage(50)
  print ok
  try:
    Percentage(-1)
    print "kept"
  catch error:
    print "rejected"
  text: String? = null
  print text.orEmpty()
  named: String? = "ab"
  print named.orEmpty()
  print expose().length
  print keep(expose())
  var first = () -> 0
  var second = () -> 0
  var index = 0
  for n in [1, 2]:
    saved = () -> n
    if index == 0:
      first = saved
    else:
      second = saved
    index = index + 1
  print first()
  print second()
  var count = 1
  read = () -> count
  count = 2
  print await later(read)
  partial = add(a: 1, b: _)
  print partial(4)
''';
    await execute(source, '''1
1
1
50
rejected

ab
1
1
1
2
2
5
''');
    final dart = compile(source).dart;
    expect(dart, contains('UnmodifiableListView<int>'));
    expect(dart, contains('Percentage._(50)'));
    expect(dart, isNot(contains("import 'package:quds_lang")));
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
  made = Point.same(3)
  print made.y
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
  copied = pair.copyWith()
  print copied.x
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
      '''
main():
  a = 1
  b = 2
  a, b = b, a
''': 'E202',
      '''
main():
  items = [1, 2]
  [1, second] = items
''': 'E100',
      '''
main():
  text = "x"
  value: Object = "Ada"
  while value is String text:
    print text
''': 'E203',
      '''
main():
  a, b = 1
''': 'E300',
      '''
main():
  line = "Ada"
  print line if let line = line
''': 'E203',
      '''
main():
  read() -> String?:
    return "Ada"
  caption = bound if let bound = read() else bound
''': 'E200',
      '''
main():
  names = ["a"]
  found = for name in names:
    break
''': 'E300',
      '''
main():
  names = ["a"]
  for name in names:
    break name
''': 'E300',
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
main():
  items: readonly List<int> = [1]
  items.add(2)
''': 'E307',
      '''
main():
  grid: readonly List<List<int>> = [[1]]
  grid[0].add(2)
''': 'E307',
      '''
take(items: List<int>):
  print items.length
main():
  items: readonly List<int> = [1]
  take(items)
''': 'E500',
      '''
type Percentage wraps int:
  require value >= 0 and value <= 100
const bad = Percentage(-1)
main():
  print bad
''': 'E401',
      '''
type Percentage wraps int:
  require value >= 0 and value <= 100
main():
  print Percentage._(1)
''': 'E300',
      '''
main():
  items: List<int> = [1]
  taken: List<num> = items
''': 'E300',
      '''
parse() -> Result<int, String> = Ok(1)
main():
  print parse()?
''': 'E600',
      '''
parse() -> Result<int, String> = Ok(1)
main() -> Result<int, int>:
  value = parse()?
  return Ok(value)
''': 'E601',
      '''
read(p: Pointer<Int32>) -> int = 1
main():
  print 1
''': 'E910',
      '''
main():
  +
''': 'E100',
      '''
annotation Tag:
main():
  @Tag
  print 1
''': 'E100',
      '''
show<T: num>(value: T) -> T = value
main():
  print show("x")
''': 'E500',
      '''
main():
  value = Ok(1)
  print match value:
    Ok(n):
      n
''': 'E314',
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
      '''
class Box:
  n: int = 1
main():
  print [Box()].sorted()
''': 'E300',
      '''
main():
  print ["a"].sum()
''': 'E300',
      'main():\n  var a = 1, a = 2\n': 'E203',
      'main():\n  print min(1, 1.0)\n': 'E300',
      'main():\n  print true[0..1]\n': 'E300',
      'main():\n  print 1 < 2 < "a"\n': 'E300',
      'main():\n  repeat 1.5:\n    print 1\n': 'E300',
      'main():\n  print 1 in "ab"\n': 'E300',
      '''
main():
  items = [1, 2]
  for x in items step 2:
    print x
''': 'E300',
      '''
main():
  items = 0..4
  for i in items step 2:
    print i
''': 'E300',
      '''
main():
  for i in 0..4 step 0:
    print i
''': 'E801',
      'main():\n  print "a".fixed(2)\n': 'E300',
      '''
main():
  items = [1]
  ages = map:
    "a": 1
  print items + ages
''': 'E300',
      '''
main():
  text = """
  Hello
 Hello
  """
  print text
''': 'E100',
    };
    rejected.forEach((source, code) {
      expect(() => compile(source), throwsA(predicate((error) {
        return '$error'.contains(code);
      })), reason: source);
    });
  });

  test('collection methods build new lists and numbers without a loop',
      () async {
    await execute('''
main():
  items = [1, 2, 3, 4]
  words = ["a", "bb"]
  mixed = [3, 1, 2]
  descending = [1, 2, 3]
  repeated = [1, 1, 2, 2]
  nested = [[1, 2], [3]]
  parts = [1, 2, 3]
  pair = [1, 2]
  halves = [1.5, 2.5]
  print items.map(n -> n * n)[0]
  print items.map(n -> n * n).length
  print words.map(s -> s.length)[1]
  print items.where(n -> n > 2).toList().length
  print items.sum()
  print items.min()
  print items.max()
  print items.count()
  print items.count(n -> n > 2)
  print items.find(n -> n > 2)
  print items.find(n -> n > 9) == null
  print items.findLast(n -> n < 3)
  print items.take(2)[1]
  print items.skip(3)[0]
  print mixed.sorted()[0]
  print descending.sorted((a, b) -> b - a)[0]
  print repeated.unique().length
  print nested.flat().length
  grouped = items.group(n -> n % 2)
  print grouped[0]
  print items.fold(0, (a, n) -> a + n)
  print items.reduce((a, n) -> a + n)
  print range(1, 3).sum()
  print range(1, 3).length
  print parts.join("-")
  print pair.join()
  print "abcd".substring(1, 3)
  print "abcd"[1]
  empty: List<int> = []
  print empty.sum()
  print empty.min() == null
  print halves.sum()
''', '''1
4
2
2
10
1
4
4
2
3
true
2
2
4
1
3
2
3
[2, 4]
10
10
6
3
1-2-3
12
bc
b
0
true
4.0
''');
  });

  test('collection methods mutate through an alias and Result ? nests',
      () async {
    await execute(
        '''
parse() -> Result<int, String> = Ok(3)
addOne(n: int) -> int = n + 1
calculate() -> Result<int, String>:
  return Ok(addOne(parse()?))
later() async -> Result<int, String>:
  value = parse()?
  return Ok(value)
main() async:
  var items = [1]
  other = items
  other.add(2)
  print items.length
  print items[1]
  print items.contains(2)
  print items.isEmpty
  print "Ab".toUpperCase()
  ages = map:
    "Ada": 1
  print ages.containsKey("Ada")
  flags = set:
    1
  kept = flags.add(1)
  added = flags.add(2)
  print kept
  print added
  print flags.length
  var last = 0
  for n in [1, 2]:
    read = () -> n
    last = read()
  print last
  print calculate()
  print await later()
''',
        '2\n2\ntrue\nfalse\nAB\ntrue\nfalse\ntrue\n2\n2\n'
            "Instance of 'Ok<int, String>'\n"
            "Instance of 'Ok<int, String>'\n");
  });

  test('fix-its name shadow and parentheses', () {
    expect(
        () => compile('''
main():
  found = "outer"
  name: String? = "Ada"
  if let found = name:
    print found
'''),
        throwsA(predicate((error) =>
            '$error'.contains('E203') && '$error'.contains('shadow'))));
    expect(
        () => compile('twice() -> int = 2\nmain():\n  twice\n'),
        throwsA(predicate((error) =>
            '$error'.contains('E110') && '$error'.contains('twice()'))));
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
    expect(dart.contains('dart:mirrors'), isFalse);
    final directory = Directory.systemTemp.createTempSync('quds-reflect-');
    addTearDown(() => directory.deleteSync(recursive: true));
    final output = File('${directory.path}/app.dart')..writeAsStringSync(dart);
    final analysis = await Process.run(
        Platform.resolvedExecutable, ['analyze', output.path]);
    expect(analysis.exitCode, 0,
        reason: '${analysis.stdout}\n${analysis.stderr}\n$dart');
  });

  test('parallel failures, sealed cases, and named blocks execute', () async {
    const source = '''
annotation Mark(caption: String = "go"):
@Mark(caption: "go")
class Note:
  text: String = "noted"
sealed class State:
  kind() -> String = "state"
class Idle extends State:
  kind() -> String = "idle"
class Done extends State:
  kind() -> String = "done"
class Text:
  value: String required
class Column:
  spacing: int required
  children: List<Text> required
class Widget:
  title: String = "w"
make(item: Widget) -> String = item.title
map(items: int) -> int = items
showNum<T: num>(value: T) -> T = value
boom(message: String) async -> int:
  if message.length > 0:
    throw message
  return 0
total(values: List<int>) -> int:
  var sum = 0
  for n in values:
    sum = sum + n
  return sum
eight() -> Result<int, String> = Ok(8)
failed() -> Result<int, String> = Error("no")
inner() -> Result<int, String> = Ok(5)
nestedResult() -> Result<Result<int, String>, String> = Ok(inner())
describe(value: Result<int, String>) -> String = match value:
  Ok(n):
    "{n}"
  Error(message):
    message
main() async:
  value: Object = 1
  print value is int
  print value is String
  print value as int
  print showNum(4)
  print Note().text
  current: State = Done()
  match current:
    Idle():
      print "idle"
    Done():
      print "done"
  view = Column:
    spacing: 12
    children:
      Text "Hello"
  print view.spacing
  print view.children[0].value
  made = make:
    item: Widget()
  print made
  shown = map 3
  print shown
  print describe(eight())
  print describe(failed())
  nested = nestedResult()
  match nested:
    Ok(inner):
      match inner:
        Ok(n):
          print n
        Error(_):
          print "inner"
    Error(_):
      print "bad"
  try:
    waited = await all:
      boom("first")
      boom("second")
    print waited
    print "kept"
  catch error:
    print error
  print await isolate:
    total([1, 2])
  var n = 1
  seen = await all:
    n
    n
  n = 9
  later = await all:
    n
  print seen
  print later
''';
    await execute(source, '''
true
false
1
4
noted
done
12
Hello
w
3
8
no
5
first
3
(1, 1)
(9)
''');
    final dart = compile(source).dart;
    expect(dart, contains('@Mark(caption: "go")'));

    final directory = Directory.systemTemp.createTempSync('quds-rest-');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/left.quds')
        .writeAsStringSync('value() -> int = 1\n');
    File('${directory.path}/right.quds')
        .writeAsStringSync('value() -> int = 2\n');
    expect(() => compile('''
use "left.quds"
use "right.quds"
main():
  print value()
''', file: '${directory.path}/clash.quds'),
        throwsA(predicate((error) => '$error'.contains('E204'))));
    final twice = compile('''
use "left.quds"
use "left.quds"
main():
  print value()
''', file: '${directory.path}/twice.quds');
    expect(twice.dart, contains('value()'));
    File('${directory.path}/state.quds').writeAsStringSync('''
sealed class State:
  kind() -> String = "state"
''');
    expect(() => compile('''
use "state.quds"
class Idle extends State:
  kind() -> String = "idle"
main():
  print 1
''', file: '${directory.path}/outside.quds'),
        throwsA(predicate((error) => '$error'.contains('E703'))));
    expect(() => compile('''
use "state.quds"
class Idle implements State:
  kind() -> String = "idle"
main():
  print 1
''', file: '${directory.path}/implemented.quds'),
        throwsA(predicate((error) => '$error'.contains('E703'))));
    expect(() => compile('''
main() async:
  items = [1, 2]
  print await isolate:
    total(items)
total(values: List<int>) -> int = values.length
''', file: '${directory.path}/capture.quds'),
        throwsA(predicate((error) => '$error'.contains('E805'))));
    expect(() => compile('main():\n  +\n  print 1\n  +\n'),
        throwsA(predicate((error) {
      final text = '$error';
      return text.contains('E100') &&
          text.contains(':2:') &&
          text.contains(':4:');
    })));
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

  test('quds:ext matches the embedded library and extends existing types',
      () async {
    expect(File('lib/sdk/ext.quds').readAsStringSync(), extSdkSource);
    await execute('''
use quds:ext
main():
  print "  ".blank()
  print "ab".capitalized()
  print "ab".reversed()
  print "ababa".count("ab")
  print "prefix-value".removePrefix("prefix-")
  print "value-suffix".removeSuffix("-suffix")
  numbers: List<int> = [1, 2, 3]
  print numbers.second()
  copy = numbers.reversedCopy()
  print copy.first
  print numbers.without(2).length
  print 4.even()
  print 5.odd()
  negative = -2
  print negative.signum()
  print 3.between(1, 3)
  ages: Map<String, int> = map:
    "Ada": 1
    "Bea": 1
  print ages.keysOf(1).length
  print "a-b".before("-")
  print "a-b".after("-")
  print "ab".repeated(3)
  print "a b".words().length
  print numbers.third()
  print numbers.chunk(2).length
  print 12.divisible(3)
  print 100.digits()
  print 4.squared()
  print ages.missing("Cara")
  flags: Set<int> = set:
    1
    2
  print flags.without(1).length
  print 1.5.whole()
''', 'true\nAb\nba\n2\nvalue\nvalue\n2\n3\n2\ntrue\ntrue\n-1\ntrue\n2\na\nb\nababab\n2\n3\n2\ntrue\n3\n16\ntrue\n1\n1\n');
  });

  test('quds:math source matches the embedded library', () {
    expect(File('lib/sdk/math.quds').readAsStringSync(), mathSdkSource);
  });

  test('a quds library section imports that section and its children',
      () async {
    expect(
        formatQuds(':: graph\n\nf() = 1\n::\n'), ':: graph\n\nf() = 1\n::\n');
    expect(
        sdkSectionNames('math'),
        containsAll([
          'scalar',
          'number',
          'complex',
          'vector',
          'interval',
          'stats',
          'distribution',
          'calculus',
          'interp',
          'linalg',
          'polynomial',
          'signal',
          'special',
          'optimize',
          'support',
          'graph',
          'graph::weighted',
          'exact',
          'autodiff',
          'geometry',
        ]));
    compile('''
:: kept
kept() = 1
::
main():
  print kept()
''');
    expect(() => compile('''
:: graph::
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E100'))));
    expect(() => compile('''
main():
  :: graph
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E100'))));

    final graph = compile('''
use quds:math::graph
main():
  noEdges: List<int> = []
  print bfsDistances([noEdges], 0)[0]
''');
    expect(graph.dart, contains("import 'quds_math.dart' show bfsDistances;"));
    expect(graph.dart, isNot(contains('dijkstra')));
    expect(graph.dart, isNot(contains('mean')));
    expect(graph.dart, isNot(contains('bigInt')));

    compile('''
use quds:math::graph show bfsDistances
main():
  noEdges: List<int> = []
  print bfsDistances([noEdges], 0)[0]
''');
    compile('''
use quds:math::graph::weighted as paths
main():
  print paths.dijkstra(1, [], 0).distances[0]
''');
    compile('''
use quds:math
main():
  print bigInt("1")
''');
    expect(() => compile('''
use quds:math::graph
main():
  print bigInt("1")
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:math::graph
main():
  print mean([1.0])
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    final stats = compile('''
use quds:math::stats
main():
  print mean([1.0, 3.0])
  print geometricMean([1.0, 4.0])
  print spearman([1.0, 2.0, 3.0], [3.0, 2.0, 1.0])
''');
    expect(
        stats.dart,
        contains(
            "import 'quds_math.dart' show mean, geometricMean, spearman;"));
    expect(stats.dart, isNot(contains('bfsDistances')));
    expect(stats.dart, isNot(contains('dijkstra')));
    compile('''
use quds:math::scalar
main():
  print ln(1.0)
''');
    compile('''
use quds:math::exact
main():
  print bigInt("1")
''');
    compile('''
use quds:math::geometry
main():
  print binaryFraction(0.5)
''');
    compile('''
use quds:math::support
main():
  print 1
''');
    expect(() => compile('''
use quds:math::stats
main():
  print ln(1.0)
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:math::scalar
main():
  print mean([1.0])
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:math::support
main():
  print mean([1.0])
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:math::graph::weighted
main():
  noEdges: List<int> = []
  print bfsDistances([noEdges], 0)[0]
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:math::graph show dijkstra
main():
  noEdges: List<int> = []
  print bfsDistances([noEdges], 0)[0]
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:math::graph hide dijkstra
main():
  edges: List<WeightedEdge> = []
  print dijkstra(1, edges, 0).distances[0]
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:math::missing
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E900'))));
    expect(() => compile('''
use quds:math::
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E900'))));
    await execute('''
use quds:math::graph
main():
  noEdges: List<int> = []
  edges: List<WeightedEdge> = [WeightedEdge(source: 0, target: 1, weight: 2.0)]
  print bfsDistances([noEdges], 0)[0]
  print dijkstra(2, edges, 0).distances[1]
''', '0\n2.0\n');
  });

  test('quds:core matches the embedded library and executes', () async {
    expect(File('lib/sdk/core.quds').readAsStringSync(), coreSdkSource);
    final result = compile('''
use quds:core
main():
  stack = Stack<int>()
  stack.push(1)
  print stack.pop()
''');
    expect(result.dart, contains("import 'quds_core.dart';"));
    expect(result.dart, isNot(contains("import 'quds:core'")));
    expect(result.bundles, hasLength(1));
    expect(result.bundles.single.fileName, 'quds_core.dart');
    expect(result.bundles.single.source, contains('class Stack<'));
    expect(compile('''
use quds:core hide Ok
main():
  print 1
''').dart, isNot(contains('quds_core')));
    expect(() => compile('''
main():
  Stack<int>()
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:missing
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E900'))));
    expect(() => compile('''
use quds:core show Stack
main():
  print Ok(1)
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:core show Nope
main():
  print 1
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    expect(() => compile('''
use quds:core as core
main():
  Stack<int>()
'''), throwsA(predicate((error) => '$error'.contains('E200'))));
    await execute('''
use quds:core
main():
  numbers: Array<int> = [1, 2, 3]
  print numbers.length
  ages: Dict<String, int> = map:
    "Ada": 36
  print ages["Ada"]
  again = 1
  seen: HashSet<int> = set:
    again
    again
  print seen.length
  stack = Stack<int>()
  stack.push(1)
  stack.push(2)
  print stack.top()
  print stack.pop()
  print stack.size()
  line = Queue<String>()
  line.add("a")
  line.add("b")
  print line.take()
  print line.next()
  bag = Bag<String>()
  bag.add("go")
  bag.add("go")
  print bag.count("go")
  print bag.count("stop")
  print bag.total()
''', '3\n36\n1\n2\n2\n1\na\nb\n2\n0\n2\n');
    await execute('''
use quds:core as core
main():
  stack = core.Stack<int>()
  stack.push(4)
  print stack.pop()
''', '4\n');
  });

  test('local functions, nameof, events, numeric constraints, and deconstruct',
      () async {
    await execute('''
class Node:
  child: Node? = null

class Point:
  x: int required
  y: int required
  deconstruct() -> (int, int) = (x, y)

class Button:
  event clicked: () -> void
  press():
    raise clicked

walk(node: Node) -> int:
  depth(current: Node, level: int) -> int:
    if current.child == null: return level
    return depth(current.child!, level + 1)
  return depth(node, 0)

scale(value: int) -> int:
  twice(n: int) -> int = n * value
  return twice(3)

sum<T>(values: List<T>) -> T where T is Numeric:
  var total = values.first
  for value in values.skip(1):
    total = total + value
  return total

main():
  root = Node(child: Node())
  print walk(root)
  print scale(2)
  user = "Ada"
  print nameof user
  print user
  spot = Point(x: 3, y: 4)
  print nameof spot.x
  x, y = spot
  print x
  print y
  button = Button()
  button.clicked.add:
    print "pressed"
  button.press()
  print sum([1, 2, 3])
  print sum([1.5, 2.5])
  age = -1
  try:
    require age >= 0
  catch error:
    print "{error}".contains("age >= 0")
''', '1\n6\nuser\nAda\nspot.x\n3\n4\npressed\n6\n4.0\ntrue\n');
    expect(() => compile('''
main():
  raise clicked
'''), throwsA(predicate((error) => '$error'.contains('raise'))));
    expect(() => compile('''
sum<T>(values: List<T>) -> T where T is Numeric:
  return values.first
main():
  print sum(["a"])
'''), throwsA(predicate((error) => '$error'.contains('No overload'))));
    expect(() => compile('''
class Bare:
  x: int required
main():
  a, b = Bare(x: 1)
'''), throwsA(predicate((error) => '$error'.contains('record'))));
    expect(() => compile('''
class Button:
  event clicked: () -> void
  press():
    clicked()
'''), throwsA(predicate((error) => '$error'.contains('raise'))));
  });

  test('try else runs only when nothing is caught, and {expr=} shows the text',
      () async {
    await execute('''
read() -> int:
  print "once"
  return 4

stop(value: bool):
  if value:
    throw "no"

main():
  try:
    print "ran"
  catch error:
    print "caught"
  else:
    print "saved"
  try:
    stop(value: true)
  catch error:
    print "caught"
  else:
    print "skipped"
  finally:
    print "done"
  age = -1
  print "{age=}"
  print "{age == 1}"
  print "{read()=}"
''', 'ran\nsaved\ncaught\ndone\nage=-1\nfalse\nonce\nread()=4\n');
    expect(() => compile('''
main():
  try:
    print 1
  else:
    print 2
'''), throwsA(predicate((error) => '$error'.contains('catch'))));
  });

  test('lazy fields, extension properties, call, and once', () async {
    await execute('''
readFile(path: String) -> String:
  print "read"
  return path

class Report:
  path: String required
  text: String by lazy:
    result readFile(path)
  note: String? by lazy:
    print "note"
    result null

class Cache:
  static banner: String by lazy:
    print "static"
    result "ready"

extend String Text:
  property shouted: String:
    get = this.toUpperCase()

class Greeter:
  call(name: String) -> String = "Hello {name}"

tick():
  once:
    print "tick"

main():
  once = 1
  print once
  report = Report(path: "a")
  print report.text
  print report.text
  print report.note
  print report.note
  print Cache.banner
  print Cache.banner
  print "ab".shouted
  print Greeter()("Ada")
  greeter = Greeter()
  print greeter("Bo")
  for n in 1..3:
    once:
      print n
  tick()
  tick()
''', '1\nread\na\na\nnote\nnull\nnull\nstatic\nready\nready\nAB\nHello Ada\nHello Bo\n1\ntick\ntick\n');
    expect(() => compile('''
class Box:
  var text: String by lazy:
    result "a"
'''), throwsA(predicate((error) => '$error'.contains('var'))));
    expect(() => compile('''
class Box:
  text: String by lazy:
    result "a"
main():
  box = Box()
  box.text = "b"
'''), throwsA(predicate((error) => '$error'.contains('immutable'))));
  });
}

Future<void> execute(String source, String stdout) async {
  final directory = Directory.systemTemp.createTempSync('quds-language-');
  try {
    final result = compile(source);
    final output = File('${directory.path}/app.dart')
      ..writeAsStringSync(result.dart);
    writeSdkBundles(directory.path, result);
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
