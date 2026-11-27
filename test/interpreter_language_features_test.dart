import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

Future<QudsRunResult> _run(String source) async {
  final session = QudsSession(
    policy: QudsExecutionPolicy.standard(
      maxSteps: 100000,
      timeout: const Duration(seconds: 5),
    ),
    allowTopLevelRebind: true,
  );
  try {
    return await session.run(source, preferBytecode: false);
  } finally {
    await session.dispose();
  }
}

void main() {
  group('Interpreter Quds 1.2 runtime features', () {
    test('reactive state, computed, watch, and batch coalescing', () async {
      final res = await _run('''
state count = 1
computed doubled = count * 2
var log: List<int> = []
watch doubled:
  log.add(doubled)

count = 3
batch:
  count = 4
  count = 5
print "doubled={doubled} log={log}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout.trim(), 'doubled=10 log=[6, 10]');
    });

    test('event declaration, listen, and raise', () async {
      final res = await _run('''
class Button:
  event clicked: (int) -> void
  press(n: int):
    raise clicked(n)

btn = Button()
var total = 0
onClick = (n: int) -> :
  total += n
btn.clicked.listen(onClick)
btn.press(2)
btn.press(5)
print "total={total}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout.trim(), 'total=7');
    });

    test('sync* generator with yield and yield*', () async {
      final res = await _run('''
evens(n: int) sync*:
  for i in 1..n:
    if i % 2 == 0:
      yield i

print evens(6)
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout.trim(), '[2, 4, 6]');
    });

    test('once: executes only on the first call', () async {
      final res = await _run('''
var hits = 0
initStep():
  once:
    hits += 1

initStep()
initStep()
initStep()
print "hits={hits}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout.trim(), 'hits=1');
    });

    test('mixin, augment, super, singleton, value copyWith, and init',
        () async {
      final res = await _run('''
mixin Stamped:
  stamp() -> String = "OK"

class Base:
  greet() -> String = "Base"

class Child extends Base with Stamped:
  id: int required
  init(v: int):
    this.id = v * 2
  greet() -> String = "{super.greet()}+Child:{id}:{stamp()}"

augment Child:
  tag() -> String = "C-{id}"

singleton class App:
  var count: int = 0
  bump():
    count += 1

value class Book:
  title: String required
  pages: int = 100

c = Child(5)
App.instance.bump()
App.instance.bump()
b = Book("Quds").copyWith(pages: 250)
print "{c.greet()}|{c.tag()}|app={App.instance.count}|book={b.title}:{b.pages}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout.trim(), 'Base+Child:10:OK|C-10|app=2|book=Quds:250');
    });

    test('this.field fluent chaining does not clobber mutations', () async {
      final res = await _run('''
class Builder:
  var text: String = ""
  add(part: String) -> Builder:
    this.text = "{this.text}{part}"
    return this

b = Builder().add("Quds ").add("1.2")
print b.text
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout.trim(), 'Quds 1.2');
    });

    test('custom implicit/explicit cast conversions, by lazy result, and .new',
        () async {
      final res = await _run('''
class Meter:
  value: double required
  implicit cast(n: int) -> Meter:
    return Meter(n.toDouble())
  explicit cast(m: Meter) -> double:
    return m.value * 100.0
  cm: double by lazy:
    result value * 100.0

m: Meter = .new(2.5)
m2 = 4 to Meter
print "m.cm={m.cm} m2={m2 to double}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout.trim(), 'm.cm=250.0 m2=400.0');
    });

    test('config, secret, task group, spawn, and test/group blocks', () async {
      final res = await _run('''
config server.port: int = 8080
config secret api.key: String
var done: List<int> = []
work(n: int) async:
  done.add(n)

task group:
  spawn work(1)
  spawn work(2)

group "math":
  test "sum":
    check 2 + 2 == 4

print "port={server.port} key={api.key} done={done}"
''');
      expect(res.succeeded, isTrue, reason: '${res.error}');
      expect(res.stdout.trim(), 'port=8080 key=null done=[1, 2]');
    });
  });
}
