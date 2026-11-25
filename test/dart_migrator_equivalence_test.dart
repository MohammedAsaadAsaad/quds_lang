import 'dart:io';

import 'package:quds/migrate.dart';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

/// Differential equivalence harness:
/// 1. Executes [dartSource] directly with the Dart VM.
/// 2. Converts [dartSource] to Quds via [convertDartToQuds] with full semantic verification.
/// 3. Compiles the migrated Quds back to Dart via [compile] and executes it.
/// 4. Asserts both programs succeed with exit code 0 and produce **byte-for-byte identical stdout**.
Future<String> assertDartAndQudsEquivalent(
  String name,
  String dartSource,
) async {
  final dir = Directory.systemTemp.createTempSync('quds-equiv-$name-');
  try {
    final origFile = File('${dir.path}/orig.dart')
      ..writeAsStringSync(dartSource);
    final origRun = await Process.run(
      Platform.resolvedExecutable,
      [origFile.path],
    );
    expect(
      origRun.exitCode,
      0,
      reason:
          'Reference Dart failed for $name:\n${origRun.stdout}\n${origRun.stderr}',
    );

    final converted = convertDartToQuds(
      dartSource,
      verifySemantics: true,
    );
    expect(
      converted.issues,
      isEmpty,
      reason:
          'Migration failed for $name:\n${converted.issues.join('\n')}\n--- Quds ---\n${converted.qudsSource}',
    );
    expect(converted.qudsSource, isNotNull);
    final qudsSource = converted.qudsSource!;

    final compiled = compile(qudsSource);
    final genFile = File('${dir.path}/from_quds.dart')
      ..writeAsStringSync(compiled.dart);
    writeSdkBundles(dir.path, compiled);

    final qudsRun = await Process.run(
      Platform.resolvedExecutable,
      [genFile.path],
    );
    expect(
      qudsRun.exitCode,
      0,
      reason:
          'Migrated Quds execution failed for $name:\n${qudsRun.stdout}\n${qudsRun.stderr}\n--- Quds ---\n$qudsSource\n--- Generated Dart ---\n${compiled.dart}',
    );

    expect(
      qudsRun.stdout,
      equals(origRun.stdout),
      reason:
          'Output mismatch for $name!\n--- Quds ---\n$qudsSource\n--- Generated Dart ---\n${compiled.dart}',
    );
    return qudsSource;
  } finally {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

void main() {
  group('Dart -> Quds behavioral equivalence (byte-for-byte stdout)', () {
    test(
        '1. arithmetic, bitwise, precedence (?? vs &&/||), nested ternary, compound ops',
        () async {
      await assertDartAndQudsEquivalent('ops', r'''
void main() {
  var a = 17;
  a ~/= 3;
  var b = 25;
  b %= 7;
  var bits = 0x0F;
  bits &= 0x06;
  bits |= 0x10;
  bits ^= 0x02;
  bits <<= 1;
  bits >>= 1;
  print('arith=$a,$b,$bits,${~5},${16 >>> 2}');

  bool? n1 = null;
  bool? n2 = true;
  final r1 = n1 ?? false || true;
  final r2 = n1 ?? true && false;
  final r3 = (n1 ?? false) || false;
  final r4 = n2 ?? false && false;
  print('prec=$r1,$r2,$r3,$r4');

  for (var score in [95, 78, 52, 20]) {
    final grade = score >= 90
        ? 'A'
        : score >= 70
            ? 'B'
            : score >= 50
                ? 'C'
                : 'F';
    final nested = score > 50 ? (score > 80 ? 'top' : 'mid') : 'low';
    print('$score:$grade:$nested');
  }

  int? maybe;
  maybe ??= 42;
  maybe ??= 99;
  print('coalesce=$maybe');
}
''');
    });

    test(
        '2. strings, escapes, braces, raw strings, adjacent strings, interpolation',
        () async {
      await assertDartAndQudsEquivalent('strings', r'''
void main() {
  final name = 'Quds';
  final count = 3;
  final plain = 'Hello {world} and \$price';
  final escaped = 'line1\nline2\t"quoted"\\slash';
  final rawPath = r'C:\Users\quds\file.txt';
  final rawQuotes = r'raw "quotes" and \n literal';
  final interp = '$name has ${count * 2} items ({ok})';
  final adj = 'part1-' 'part2-' '$count';
  print(plain);
  print(escaped);
  print(rawPath);
  print(rawQuotes);
  print(interp);
  print(adj);
}
''');
    });

    test(
        '3. lexical scoping & variable shadowing (final, var, mutation vs shadow)',
        () async {
      await assertDartAndQudsEquivalent('scoping', r'''
int shadowTest(int x) {
  var outer = 10;
  final fixed = 'outer';
  final out = <String>[];
  out.add('start:$x,$outer,$fixed');
  if (x > 0) {
    final x = 99;
    var outer = 200;
    final fixed = 'inner';
    outer += 5;
    out.add('if:$x,$outer,$fixed');
  }
  outer += 1;
  out.add('after:$x,$outer,$fixed');
  for (var i = 0; i < 2; i++) {
    final fixed = 'loop-$i';
    out.add('loop:$fixed');
  }
  out.add('end:$x,$outer,$fixed');
  print(out.join('|'));
  return outer;
}

void main() {
  print(shadowTest(5));
}
''');
    });

    test(
        '4. collections: untyped/typed List, Set, Map, inline & block literals, spreads, if/for',
        () async {
      await assertDartAndQudsEquivalent('collections', r'''
String describeMap(Map<String, int> m) {
  final keys = m.keys.toList()..sort();
  return [for (final k in keys) '$k=${m[k]}'].join(',');
}

String describeSet(Set<int> s) {
  final sorted = s.toList()..sort();
  return sorted.join(',');
}

void main() {
  final emptyMap = {};
  emptyMap['k'] = 1;
  final typedEmptyMap = <String, int>{};
  typedEmptyMap['x'] = 10;
  typedEmptyMap['y'] = 20;

  final blockMap = {'b': 2, 'a': 1};
  final typedMap = <String, int>{'m': 3, 'n': 4};

  final emptySet = <int>{};
  emptySet.add(7);
  emptySet.add(7);
  emptySet.add(2);
  final blockSet = {3, 1, 2, 1};
  final typedSet = <int>{9, 4, 9};

  final emptyList = <String>[];
  emptyList.add('hi');
  final typedList = <int>[10, 20];
  final includeExtra = true;
  final base = [1, 2];
  final List<int>? maybeNull = null;
  final built = [
    ...base,
    ...?maybeNull,
    if (includeExtra) 3 else 99,
    for (final n in [4, 5]) n * 10,
  ];

  print('emptyMap=${emptyMap['k']}');
  print('typedEmptyMap=${describeMap(typedEmptyMap)}');
  print('blockMap=${blockMap['a']},${blockMap['b']}');
  print('inlineMap=${describeMap(<String, int>{'z': 8, 'a': 2})}');
  print('typedMap=${describeMap(typedMap)}');
  print('emptySet=${describeSet(emptySet)}');
  print('blockSet=${blockSet.length}');
  print('inlineSet=${describeSet(<int>{5, 1, 5})}');
  print('typedSet=${describeSet(typedSet)}');
  print('lists=${emptyList.join(',')}|${typedList.join(',')}|${built.join(',')}');
}
''');
    });

    test(
        '5. loops: range, C-for with continue/break, reverse, body mutation, do-while, labeled break',
        () async {
      await assertDartAndQudsEquivalent('loops', r'''
void main() {
  // Canonical ascending loop
  var sum1 = 0;
  for (var i = 0; i < 6; i++) {
    sum1 += i;
  }

  // Inclusive ascending loop
  var sum2 = 0;
  for (var i = 1; i <= 5; i++) {
    sum2 += i;
  }

  // Step loop WITH continue (must NOT infinite loop!)
  final evens = <int>[];
  for (var i = 0; i < 12; i += 2) {
    if (i == 4 || i == 8) continue;
    evens.add(i);
  }

  // Reverse loop WITH continue and break
  final desc = <int>[];
  for (var i = 10; i > 0; i -= 3) {
    if (i == 7) continue;
    desc.add(i);
    if (i <= 2) break;
  }

  // Loop whose body mutates loop variable `i`
  final skipped = <int>[];
  for (var i = 0; i < 8; i++) {
    skipped.add(i);
    if (i == 2) i += 2;
  }

  // do-while
  var n = 0;
  final dw = <int>[];
  do {
    dw.add(n);
    n += 1;
  } while (n < 3);

  // Labeled break
  var found = '';
  outer:
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 4; c++) {
      if (r * 4 + c == 6) {
        found = '$r,$c';
        break outer;
      }
    }
  }

  print('sums=$sum1,$sum2');
  print('evens=${evens.join(',')}');
  print('desc=${desc.join(',')}');
  print('skipped=${skipped.join(',')}');
  print('dw=${dw.join(',')}');
  print('found=$found');
}
''');
    });

    test(
        '6. switch statements (grouped fallthrough, patterns, guards, default) & switch expressions',
        () async {
      await assertDartAndQudsEquivalent('switch', r'''
String classify(int code) {
  switch (code) {
    case 1:
    case 2:
      return 'small';
    case 3 || 4:
      return 'medium';
    case int n when n > 10:
      return 'big:$n';
    default:
      return 'other:$code';
  }
}

String describe(int v) {
  final text = switch (v) {
    0 => 'zero',
    1 || 2 => 'one-or-two',
    int n when n < 0 => 'neg:$n',
    _ => 'pos:$v',
  };
  return text;
}

void main() {
  for (final x in [-3, 0, 1, 2, 3, 4, 7, 15]) {
    print('$x:${classify(x)}:${describe(x)}');
  }
}
''');
    });

    test(
        '7. functions, optional positional & named params, defaults, closures, recursion, void arrow',
        () async {
      await assertDartAndQudsEquivalent('functions', r'''
void logLine(String s) => print('LOG:$s');

int calc(int a, [int b = 10, int c = 1]) => a + b * c;

String fmt({required String name, int count = 1, String? suffix}) {
  final tail = suffix ?? '';
  return '$name($count)$tail';
}

int fib(int n) {
  if (n <= 1) return n;
  return fib(n - 1) + fib(n - 2);
}

void main() {
  logLine('start');
  print('${calc(5)},${calc(5, 2)},${calc(5, 2, 3)}');
  print(fmt(name: 'item'));
  print(fmt(name: 'item', count: 4, suffix: '!'));
  print('fib=${fib(7)}');

  int makeLocal(int k) => k * k;
  final nums = [1, 2, 3, 4];
  final mapped = nums.map((x) => makeLocal(x)).toList();
  final filtered = mapped.where((x) {
    return x > 2;
  }).toList();
  print('fn=${mapped.join(',')}|${filtered.join(',')}');
}
''');
    });

    test(
        '8. async/await, Future<void>, async* streams, sync* generators, try/catch/on/finally/rethrow',
        () async {
      await assertDartAndQudsEquivalent('async_try', r'''
Future<int> computeAsync(int x) async {
  await Future<void>.delayed(Duration.zero);
  return x * 3;
}

Future<void> runSideEffect(List<String> log) async {
  final v = await computeAsync(7);
  log.add('async=$v');
}

Stream<int> countStream(int max) async* {
  for (var i = 1; i <= max; i++) {
    yield i * 10;
  }
}

Iterable<int> odds(int max) sync* {
  for (var i = 1; i <= max; i += 2) {
    yield i;
  }
}

void risky(int mode) {
  if (mode == 1) throw FormatException('bad format');
  if (mode == 2) throw StateError('bad state');
}

String catchTest(int mode) {
  final trace = <String>[];
  try {
    try {
      risky(mode);
      trace.add('ok');
    } on FormatException catch (e) {
      trace.add('fmt:${e.message}');
    } catch (e) {
      trace.add('rethrow');
      rethrow;
    } finally {
      trace.add('fin');
    }
  } on StateError catch (e) {
    trace.add('outer:${e.message}');
  }
  return trace.join('/');
}

Future<void> main() async {
  final log = <String>[];
  await runSideEffect(log);
  final streamed = <int>[];
  await for (final v in countStream(3)) {
    streamed.add(v);
  }
  print(log.join(','));
  print('stream=${streamed.join(',')}');
  print('sync=${odds(7).join(',')}');
  print('try=${catchTest(0)}|${catchTest(1)}|${catchTest(2)}');
}
''');
    });

    test(
        '9. classes: positional & const init, named widget-style init, factory, properties, operators, enum, mixin, extension, generics, records',
        () async {
      await assertDartAndQudsEquivalent('oop', r'''
typedef IntPair = (int, int);

enum Priority { low, medium, high }

class Vec2 {
  final int x;
  final int y;

  const Vec2(this.x, this.y);

  factory Vec2.zero() => const Vec2(0, 0);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  @override
  String toString() => '($x,$y)';
}

class BadgeConfig {
  final String title;
  final int count;
  final String? note;

  const BadgeConfig({required this.title, this.count = 0, this.note});

  String render() => '$title#$count:${note ?? 'none'}';
}

class Meter {
  int _value;
  final String unit;

  Meter(this.unit, int initial) : _value = initial;

  int get value => _value;
  set value(int v) {
    _value = v < 0 ? 0 : v;
  }

  static String format(int n, String u) => '$n$u';
}

class Box<T> {
  final T item;
  Box(this.item);
  T unwrap() => item;
}

mixin Taggable {
  String tag(String s) => '[$s]';
}

class Note with Taggable {
  final String body;
  Note(this.body);
  String show() => tag(body);
}

extension IntUtils on int {
  int doubled() => this * 2;
}

void main() {
  final v = const Vec2(3, 4) + Vec2.zero() + const Vec2(1, -2);
  final b1 = const BadgeConfig(title: 'Inbox');
  final b2 = const BadgeConfig(title: 'Alerts', count: 5, note: 'urgent');
  final m = Meter('km', 12);
  m.value = -5;
  final mAfterNeg = m.value;
  m.value = 42;
  final box = Box<String>('ok');
  final note = Note('hello');
  final IntPair pair = (7, 8);
  print('vec=$v');
  print('badges=${b1.render()}|${b2.render()}');
  print('meter=$mAfterNeg,${m.value},${Meter.format(m.value, m.unit)}');
  print('box=${box.unwrap()}');
  print('note=${note.show()}');
  print('ext=${9.doubled()}');
  print('enum=${Priority.high.name}');
  print('rec=${pair.$1},${pair.$2}');
}
''');
    });

    test(
        '10. multi-file Dart project: dart run lib/main.dart == quds run lib/main.quds',
        () async {
      final dir = Directory.systemTemp.createTempSync('quds-equiv-proj-');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: ledger_mini
version: 1.0.0
environment:
  sdk: ">=3.3.0 <4.0.0"
''');
      Directory('${dir.path}/lib/src').createSync(recursive: true);
      File('${dir.path}/lib/src/entry.dart').writeAsStringSync(r'''
class Entry {
  final String title;
  final int cents;

  const Entry({required this.title, required this.cents});

  String summary() => '$title:${cents / 100}';
}
''');
      File('${dir.path}/lib/src/calc.dart').writeAsStringSync(r'''
import 'entry.dart';

int totalCents(List<Entry> entries) {
  var sum = 0;
  for (final e in entries) {
    sum += e.cents;
  }
  return sum;
}

Map<String, int> totalsByTitle(List<Entry> entries) {
  final out = <String, int>{};
  for (final e in entries) {
    out[e.title] = (out[e.title] ?? 0) + e.cents;
  }
  return out;
}
''');
      File('${dir.path}/lib/main.dart').writeAsStringSync(r'''
import 'src/entry.dart';
import 'src/calc.dart';

void main() {
  final entries = <Entry>[
    const Entry(title: 'Food', cents: 1250),
    const Entry(title: 'Books', cents: 2500),
    const Entry(title: 'Food', cents: 750),
  ];
  final total = totalCents(entries);
  final grouped = totalsByTitle(entries);
  final keys = grouped.keys.toList()..sort();
  print('total=$total');
  for (final k in keys) {
    print('$k=${grouped[k]}');
  }
  print(entries.first.summary());
}
''');

      // 1. Run original Dart project.
      final dartRun = await Process.run(
        Platform.resolvedExecutable,
        ['lib/main.dart'],
        workingDirectory: dir.path,
      );
      expect(dartRun.exitCode, 0,
          reason: '${dartRun.stdout}\n${dartRun.stderr}');

      // 2. Inspect (including full multi-file Quds semantic verification!), backup, and migrate.
      final report = inspectProjectForMigration(dir);
      expect(report.blockedFiles, isEmpty,
          reason: report.blockedFiles
              .map((f) => '${f.relativePath}: ${f.issues.join('; ')}')
              .join('\n'));
      expect(report.readyFiles, hasLength(3));
      backupProjectLib(dir);
      final exec = executeProjectMigration(report);
      expect(exec.migratedFiles, hasLength(3));
      expect(exec.totalDartLines, greaterThan(0));
      expect(exec.totalQudsLines, greaterThan(0));

      // 3. Compile migrated Quds entry & run generated Dart.
      final compiled = compile(
        File('${dir.path}/lib/main.quds').readAsStringSync(),
        file: '${dir.path}/lib/main.quds',
      );
      final outDir = Directory('${dir.path}/.dart_tool/quds/out')
        ..createSync(recursive: true);
      // Emit all compiled Quds dependencies into outDir.
      for (final dep in compiled.dependencies) {
        if (!dep.endsWith('.quds')) continue;
        final depComp = compile(File(dep).readAsStringSync(), file: dep);
        final rel = dep.substring(dir.path.length + 1);
        final dartOut =
            File('${outDir.path}/${rel.substring(0, rel.length - 5)}.dart');
        dartOut.parent.createSync(recursive: true);
        dartOut.writeAsStringSync(depComp.dart);
      }
      // Run via `dart bin/quds.dart run lib/main.quds` from repo root? Even faster:
      final qudsRun = await Process.run(
        Platform.resolvedExecutable,
        ['${Directory.current.path}/bin/quds.dart', 'run', 'lib/main.quds'],
        workingDirectory: dir.path,
      );
      expect(qudsRun.exitCode, 0,
          reason: '${qudsRun.stdout}\n${qudsRun.stderr}');
      expect(qudsRun.stdout, equals(dartRun.stdout));
    });
  });

  group('Safety gates: never silently alter semantics', () {
    test(
        'rejects non-trivial super(...) constructor initializer instead of silently dropping it',
        () {
      const dartCode = '''
class Animal {
  final String name;
  Animal(this.name);
}

class Dog extends Animal {
  Dog(String n) : super(n);
}
''';
      final res = convertDartToQuds(dartCode);
      expect(res.qudsSource, isNull);
      expect(res.issues.join('\n'), contains('super(...)'));
    });

    test('rejects reserved Quds keyword identifier with clear diagnostic', () {
      const dartCode = '''
void main() {
  final label = 'ok';
  print(label);
}
''';
      final res = convertDartToQuds(dartCode);
      expect(res.qudsSource, isNull);
      expect(res.issues.join('\n'), contains('reserved keyword in Quds'));
    });

    test(
        'rejects multi-variable for-loop with continue instead of creating an infinite loop',
        () {
      const dartCode = '''
void main() {
  for (var i = 0, j = 10; i < j; i++, j--) {
    if (i == 2) continue;
    print(i + j);
  }
}
''';
      final res = convertDartToQuds(dartCode);
      expect(res.qudsSource, isNull);
      expect(res.issues.join('\n'), contains('continue'));
    });

    test('semantic verification catches type errors even if syntax parses', () {
      const dartCode = '''
void main() {
  final x = unknownSymbolThatDoesNotExist();
  print(x);
}
''';
      final parseOnly = convertDartToQuds(dartCode, verifySemantics: false);
      expect(parseOnly.qudsSource, isNotNull);

      final withSemantics = convertDartToQuds(dartCode, verifySemantics: true);
      expect(withSemantics.qudsSource, isNull);
      expect(withSemantics.issues.join('\n'), contains('verification'));
    });
  });
}
