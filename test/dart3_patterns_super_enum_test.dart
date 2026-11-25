import 'dart:io';

import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  String runQuds(String source) {
    final result = compile(source);
    final dir = Directory.systemTemp.createTempSync('quds_d3_');
    try {
      final file = File('${dir.path}/main.dart')
        ..writeAsStringSync(result.dart);
      writeSdkBundles(dir.path, result);
      final proc = Process.runSync(Platform.resolvedExecutable, [file.path]);
      expect(proc.exitCode, 0,
          reason: 'Dart failed:\n${proc.stderr}\nCode:\n${result.dart}');
      return proc.stdout as String;
    } finally {
      dir.deleteSync(recursive: true);
    }
  }

  group('Explicit super(...) constructor forwarding', () {
    test('forwards to explicit, named, synthesized, and generic superclasses',
        () {
      final out = runQuds('''
class Box<T>:
  value: T required
  tag: String = "box"

class LabeledBox<U> extends Box<U>:
  label: String required
  init(v: U, this.label) super(v, tag: "labeled")

class Base:
  id: String required
  init(this.id)
  init fromInt(n: int):
    id = "id-{n}"

class Child extends Base:
  extra: int required
  init(raw: String, this.extra) super(raw.toUpperCase())
  init numbered(n: int, this.extra) super.fromInt(n)

main():
  b = LabeledBox<int>(42, "answer")
  c1 = Child("ok", 1)
  c2 = Child.numbered(9, 2)
  print "{b.tag}:{b.label}:{b.value}"
  print "{c1.id}:{c1.extra}"
  print "{c2.id}:{c2.extra}"
''');
      expect(out, 'labeled:answer:42\nOK:1\nid-9:2\n');
    });

    test('rejects missing required super argument (E704)', () {
      expect(
        () => compile('''
class Base:
  a: int required
  b: int required
  init(this.a, this.b)

class Sub extends Base:
  init(x: int) super(x)
'''),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', equals('E704'))),
      );
    });

    test('rejects nonexistent named super constructor (E700)', () {
      expect(
        () => compile('''
class Base:
  x: int required
  init(this.x)

class Sub extends Base:
  init(x: int) super.missing(x)
'''),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', equals('E700'))),
      );
    });

    test('rejects super(...) type mismatch (E300)', () {
      expect(
        () => compile('''
class Base:
  x: int required
  init(this.x)

class Sub extends Base:
  init(s: String) super(s)
'''),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', equals('E300'))),
      );
    });
  });

  group('Enhanced enums (QUDS-025)', () {
    test('supports synthesized constructor, fields, properties, and methods',
        () {
      final out = runQuds('''
enum Planet:
  mercury(3.3, 2439)
  earth(5.9, 6371)

  mass: double required
  radius: int required

  property densityHint: double:
    get = mass / radius

  describe() -> String = "{name}:m={mass},r={radius}"

main():
  for p in Planet.values:
    print p.describe()
  print Planet.earth.mass
  print Planet.mercury.radius
''');
      expect(out, 'mercury:m=3.3,r=2439\nearth:m=5.9,r=6371\n5.9\n2439\n');
    });

    test('supports explicit const init, named init, and exhaustive match', () {
      final out = runQuds('''
enum Code:
  ok(200)
  missing.err(404, "not found")

  value: int required
  detail: String = "ok"

  const init(this.value)
  const init err(this.value, this.detail)

describeCode(c: Code) -> String:
  return match c:
    ok: "good-{c.value}"
    missing: "bad-{c.value}:{c.detail}"

main():
  print describeCode(Code.ok)
  print describeCode(Code.missing)
''');
      expect(out, 'good-200\nbad-404:not found\n');
    });

    test('rejects mutable var field on enum (E706)', () {
      expect(
        () => compile('''
enum Bad:
  a(1)
  var x: int required
'''),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', equals('E706'))),
      );
    });

    test('rejects missing required enum case argument (E704)', () {
      expect(
        () => compile('''
enum Bad:
  a(1)
  x: int required
  y: String required
'''),
        throwsA(isA<CompilerException>()
            .having((e) => e.code, 'code', equals('E704'))),
      );
    });
  });

  group('if-is patterns with guards, else, and collection if-is', () {
    test('supports when guard, else-if chains, definite return, and patterns',
        () {
      final out = runQuds('''
class Pair:
  a: int required
  b: int required

classify(v: Object?) -> String:
  if v is int n when n > 10:
    return "big:{n}"
  else if v is int n:
    return "small:{n}"
  else if v is Pair(a: x, b: > 0):
    return "pair:{x}"
  else if v is [first, ...rest]:
    return "list:{first}:{rest.length}"
  else if v is (title: String name, count: int c) when c > 0:
    return "rec:{name}:{c}"
  else:
    return "other"

main():
  print classify(25)
  print classify(3)
  print classify(Pair(a: 7, b: 2))
  print classify([1, 2, 3])
  print classify((title: "ok", count: 4))
  print classify("nope")

  items: List<Object?> = [1, "hi", 15, null]
  filtered = [
    for item in items:
      if item is int n when n > 5:
        n * 10
      else:
        0
  ]
  print filtered
''');
      expect(out,
          'big:25\nsmall:3\npair:7\nlist:1:2\nrec:ok:4\nother\n[0, 0, 150, 0]\n');
    });

    test('rejects non-bool guard in if-is', () {
      expect(
        () => compile('''
main():
  v: Object = 1
  if v is int n when n:
    print n
'''),
        throwsA(isA<CompilerException>()),
      );
    });

    test('pattern binding does not leak into else branch', () {
      expect(
        () => compile('''
main():
  v: Object = 1
  if v is int n:
    print n
  else:
    print n
'''),
        throwsA(isA<CompilerException>()),
      );
    });
  });
}
