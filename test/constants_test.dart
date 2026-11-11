import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  final showcase = File('test/fixtures/const_eval.quds').readAsStringSync();

  test('evaluates arithmetic, logic, references, and lists', () {
    final result = compile(showcase, file: 'const_eval.quds');
    expect(valueOf(result, 'base'), ConstInt(10));
    expect(valueOf(result, 'step'), ConstInt(5));
    expect(valueOf(result, 'product'), ConstInt(14));
    expect(valueOf(result, 'ratio'), ConstDouble(3.5));
    expect(valueOf(result, 'max'), ConstInt(9223372036854775807));
    expect(valueOf(result, 'wrapped'), ConstInt(-9223372036854775808));
    expect(valueOf(result, 'negmin'), ConstInt(-9223372036854775808));
    expect(valueOf(result, 'mod'), ConstInt(1));
    expect(valueOf(result, 'negdiv'), ConstInt(2));
    expect(valueOf(result, 'flag'), ConstBool(false));
    expect(valueOf(result, 'other'), ConstBool(true));
    expect(valueOf(result, 'text'), ConstString('abc'));
    expect(valueOf(result, 'money'), ConstString(r'c$'));
    expect(valueOf(result, 'values'),
        ConstList('num', [ConstInt(10), ConstInt(5), ConstDouble(2.0)]));
    expect(valueOf(result, 'sameNested'), ConstBool(true));
    expect(valueOf(result, 'nan'), ConstDouble(double.nan));
    expect(valueOf(result, 'inf'), ConstDouble(double.infinity));
    expect(valueOf(result, 'ninf'), ConstDouble(double.negativeInfinity));
    expect(valueOf(result, 'negzero'), ConstDouble(-0.0));
    expect(valueOf(result, 'negzero'), isNot(ConstDouble(0.0)));
    expect(valueOf(result, 'plus'), ConstInt(-4));
    expect(valueOf(result, 'tiny'), ConstDouble(1e-10));
    expect(valueOf(result, 'approx'), ConstDouble(0.1 + 0.2));
    expect(valueOf(result, 'nanList'),
        ConstList('double', [ConstDouble(double.nan)]));
    expect(valueOf(result, 'zeros') == valueOf(result, 'poszeros'), isFalse);

    for (final name in ['flag', 'other']) {
      final remainders =
          operators(bindingNamed(result.program, name).value, '%');
      expect(remainders, isNotEmpty, reason: name);
      for (final remainder in remainders) {
        expect(result.semantics.constants.containsKey(remainder), isFalse,
            reason: '$name must not evaluate a skipped remainder');
      }
    }
    final evaluated = operators(bindingNamed(result.program, 'mod').value, '%');
    expect(result.semantics.constants.containsKey(evaluated.single), isTrue);

    final dart = result.dart;
    expect(dart, isNot(contains('&&')));
    expect(dart, isNot(contains('||')));
    expect(dart, isNot(contains('% 0')));
    expect(dart, contains('const bool _q9 = false;'));
    expect(dart, contains('const bool _q10 = true;'));
    expect(dart, contains(r'"c\$"'));
    expect('_q0'.allMatches(dart).length, greaterThan(1));
    expect('_q14'.allMatches(dart).length, greaterThan(1));
    expect(dart, contains('(_q4 + 1)'));
    expect(dart, contains('(0.0 / 0.0)'));
    expect(dart, contains('(-0.0)'));
  });

  test('const output is stable and executes with Dart semantics', () async {
    final output = compile(showcase, file: 'const_eval.quds').dart;
    expect(output, File('test/goldens/const_eval.dart.txt').readAsStringSync());
    await execute(showcase, showcaseStdout);
  });

  test('documented const example executes', () async {
    await execute(r'''main():
  const base = 10
  const step = base - 3 - 2
  const allowed = false and (1 % 0 == 0)
  const values = [base, step]
  print step
  print allowed
  print values
''', '5\nfalse\n[10, 5]\n');
  });

  test('num constants preserve the runtime numeric value', () {
    final result = compile('''main():
  const n: num = 5
  const q: num = 2.0
  const r = n % 2
  const s = n + q
  const t = n / 2
  const z: num = 0.0
  const nan = 4 % z
  const inf = n / (z + 0)
''');
    expect(valueOf(result, 'r'), ConstInt(1));
    expect(valueOf(result, 's'), ConstDouble(7));
    expect(valueOf(result, 't'), ConstDouble(2.5));
    expect(valueOf(result, 'nan'), ConstDouble(double.nan));
    expect(valueOf(result, 'inf'), ConstDouble(double.infinity));
    expect(
        result.semantics.declarations[bindingNamed(result.program, 'r')]!.type,
        'num');
    expect(result.dart, contains('const num _q2 = (_q0 % 2);'));
    expect(result.dart, contains('const num _q3 = (_q0 + _q1);'));
    expect(result.dart, contains('const double _q4 = (_q0 / 2);'));
  });

  test('logical operators use precedence and short-circuit', () {
    final result = compile('''main():
  const a = not false
  const b = not not true
  const c = not false and false
  const d = true or false and false
  const e = false and false and (1 % 0 == 0)
  const f = true or true and (1 % 0 == 0)
  const g = + -0.0
  const h = "a\\nb" + "c"
''');
    expect(valueOf(result, 'a'), ConstBool(true));
    expect(valueOf(result, 'b'), ConstBool(true));
    expect(valueOf(result, 'c'), ConstBool(false));
    expect(valueOf(result, 'd'), ConstBool(true));
    expect(valueOf(result, 'e'), ConstBool(false));
    expect(valueOf(result, 'f'), ConstBool(true));
    expect(valueOf(result, 'g'), ConstDouble(-0.0));
    expect(valueOf(result, 'h'), ConstString('a\nbc'));
    expect(
        result.semantics.constants.containsKey(
            operators(bindingNamed(result.program, 'e').value, '%').single),
        isFalse);
    expect(result.dart, contains(r'"a\nb"'));
  });

  test('list equality follows Dart const canonicalization', () {
    final result = compile('''main():
  const ints = [1]
  const sameInts = [1]
  const doubles = [1.0]
  const nums = [1, 2.0]
  const sameNums = [1, 2.0]
  const nans = [0.0 / 0.0]
  const otherNans = [0.0 / 0.0]
  const neg = [-0.0]
  const pos = [0.0]
  const eqInts = ints == sameInts
  const eqNum = ints == doubles
  const eqNums = nums == sameNums
  const eqNan = nans == otherNans
  const eqZero = neg == pos
  const eqValue = 1 == 1.0
  const eqNanValue = (0.0 / 0.0) == (0.0 / 0.0)
  const eqSignedZero = -0.0 == 0.0
''');
    expect(valueOf(result, 'eqInts'), ConstBool(true));
    expect(valueOf(result, 'eqNum'), ConstBool(false));
    expect(valueOf(result, 'eqNums'), ConstBool(true));
    expect(valueOf(result, 'eqNan'), ConstBool(true));
    expect(valueOf(result, 'eqZero'), ConstBool(false));
    expect(valueOf(result, 'eqValue'), ConstBool(true));
    expect(valueOf(result, 'eqNanValue'), ConstBool(false));
    expect(valueOf(result, 'eqSignedZero'), ConstBool(true));
  });

  final errors = <String,
      ({String source, int line, int column, String message, String code})>{
    'integer remainder by zero': (
      source: 'main():\n  const x = 1 + 2 % 0\n',
      line: 2,
      column: 17,
      message: 'Integer remainder by zero',
      code: 'Q200',
    ),
    'left remainder is reported before the right': (
      source: 'main():\n  const x = (1 % 0) + (2 % 0)\n',
      line: 2,
      column: 14,
      message: 'Integer remainder by zero',
      code: 'Q200',
    ),
    'list elements are evaluated left to right': (
      source: 'main():\n  const xs = [1 % 0, 2 % 0]\n',
      line: 2,
      column: 15,
      message: 'Integer remainder by zero',
      code: 'Q200',
    ),
    'taken logical branch still divides': (
      source: 'main():\n  const x = false or (1 % 0 == 0)\n',
      line: 2,
      column: 23,
      message: 'Integer remainder by zero',
      code: 'Q200',
    ),
    'nested taken branch still divides': (
      source: 'main():\n  const x = false or (true and (1 % 0 == 0))\n',
      line: 2,
      column: 33,
      message: 'Integer remainder by zero',
      code: 'Q200',
    ),
    'num zero is an integer remainder': (
      source: 'main():\n  const z: num = 0\n  const x = 4 % z\n',
      line: 3,
      column: 13,
      message: 'Integer remainder by zero',
      code: 'Q200',
    ),
    'unreachable const is still evaluated': (
      source: 'main():\n  if false:\n    const x = 1 % 0\n',
      line: 3,
      column: 15,
      message: 'Integer remainder by zero',
      code: 'Q200',
    ),
    'call is not a constant': (
      source: 'f() = 1\nmain():\n  const x = f()\n',
      line: 3,
      column: 13,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'skipped call is still not a constant': (
      source:
          'mark() -> bool:\n  return true\nmain():\n  const x = false and mark()\n',
      line: 4,
      column: 23,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'interpolation is not a constant': (
      source: 'main():\n  const s = "hi {1 + 2}"\n',
      line: 2,
      column: 13,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'const reference interpolation is not a constant': (
      source: 'main():\n  const name = "Quds"\n  const message = "hi {name}"\n',
      line: 3,
      column: 19,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'mutable binding is not a constant': (
      source: 'main():\n  var a = 1\n  const b = a\n',
      line: 3,
      column: 13,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'final binding is not a constant': (
      source: 'main():\n  a = 1\n  const b = a\n',
      line: 3,
      column: 13,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'shadow hides an outer constant': (
      source:
          'main():\n  const a = 1\n  if true:\n    shadow a = a + 2\n    const b = a\n',
      line: 5,
      column: 15,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'loop variable is not a constant': (
      source: 'main():\n  for item in [1]:\n    const x = item\n',
      line: 3,
      column: 15,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'integer literal outside 64 bits': (
      source: 'main():\n  const x = 9223372036854775808\n',
      line: 2,
      column: 13,
      message: 'Numeric literal is outside the supported native Dart range',
      code: 'Q100',
    ),
    'top-level remainder keeps the operator span': (
      source: 'const x = 1 % 0\nmain():\n  print x\n',
      line: 1,
      column: 11,
      message: 'Integer remainder by zero',
      code: 'Q200',
    ),
    'top-level const cannot see a later const': (
      source: 'const b = a\nconst a = 1\nmain():\n  print b\n',
      line: 1,
      column: 11,
      message: 'Undefined symbol: a',
      code: 'Q200',
    ),
    'top-level const cannot call': (
      source: 'id(value: int) = value\nconst x = id(1)\nmain():\n  print x\n',
      line: 2,
      column: 11,
      message: 'const requires a compile-time constant',
      code: 'Q200',
    ),
    'module scope rejects a mutable binding': (
      source: 'var a = 1\nmain():\n  print a\n',
      line: 1,
      column: 1,
      message: 'Module scope permits function declarations and const bindings',
      code: 'Q200',
    ),
    'top-level const cannot repeat a function name': (
      source: 'main():\n  print 1\nconst main = 1\n',
      line: 3,
      column: 1,
      message: 'Binding would shadow main; use shadow in an inner scope',
      code: 'Q200',
    ),
  };
  for (final entry in errors.entries) {
    test('rejects ${entry.key}', () {
      final error = entry.value;
      expect(
          () => compile(error.source, file: 'bad.quds'),
          throwsA(isA<CompilerException>()
              .having((e) => e.code, 'code', error.code)
              .having((e) => e.message, 'message', error.message)
              .having((e) => e.span.file, 'file', 'bad.quds')
              .having((e) => e.span.line, 'line', error.line)
              .having((e) => e.span.column, 'column', error.column)
              .having((e) => e.toString(), 'text',
                  'bad.quds:${error.line}:${error.column}: ${error.code}: ${error.message}')));
    });
  }

  test('literal interpolation is already a string constant', () {
    final result = compile('main():\n  const s = "hi {1}"\n  print s\n');
    expect(valueOf(result, 's'), ConstString('hi 1'));
  });

  test('a const read only by a folded logical operator still analyzes',
      () async {
    await execute('''main():
  const f = false
  const flag = f and (1 % 0 == 0)
  print flag
''', 'false\n');
    final dart = compile('''main():
  const f = false
  const flag = f and (1 % 0 == 0)
  print flag
''').dart;
    expect(dart, contains('// ignore: unused_local_variable'));
    expect(dart, isNot(contains('% 0')));
    expect(dart, contains('const bool _q1 = false;'));
  });

  test('unary plus lowers to the operand and evaluates it once', () async {
    const source = r'''bump(value: int) -> int:
  print value
  return value
main():
  print(+bump(4))
  print(+ -0.0)
  base = -2
  print(+base)
''';
    final dart = compile(source).dart;
    expect(dart.contains('(+'), isFalse);
    await execute(source, '4\n4\n-0.0\n-2\n');
  });

  test('runtime remainder by zero is left for Dart to throw', () async {
    final dart = compile('main():\n  print(1 % 0)\n').dart;
    expect(dart, contains('%'));
    final directory = Directory.systemTemp.createTempSync('quds-mod-');
    try {
      final output = File('${directory.path}/app.dart')
        ..writeAsStringSync(dart);
      final analysis = await Process.run(
          Platform.resolvedExecutable, ['analyze', output.path]);
      expect(analysis.exitCode, 0,
          reason: '${analysis.stdout}\n${analysis.stderr}\n$dart');
      final run = await Process.run(Platform.resolvedExecutable, [output.path]);
      expect(run.exitCode, isNonZero);
      expect(run.stderr, contains('IntegerDivisionByZeroException'));
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('const remainder diagnostic keeps original coordinates', () async {
    final directory = Directory.systemTemp.createTempSync('quds-const-');
    try {
      final source = File('${directory.path}/app.quds')
        ..writeAsStringSync('main():\n  const x = 1 % 0\n');
      final output = File('${directory.path}/app.dart');
      final built = await Process.run(Platform.resolvedExecutable,
          ['run', 'bin/quds.dart', 'build', source.path]);
      expect(built.exitCode, 65, reason: '${built.stdout}\n${built.stderr}');
      expect(built.stderr,
          contains('${source.path}:2:13: Q200: Integer remainder by zero'));
      expect(output.existsSync(), isFalse);
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('shadow still reads the outer constant before hiding it', () async {
    await execute('''main():
  const a = 1
  var gate = true
  if gate:
    shadow a = a + 2
    print a
  print a
''', '3\n1\n');
  });

  test('bool conditions stay reachable to the Dart analyzer', () async {
    const source = '''mark() -> bool:
  print 999
  return true
main():
  var gate = false
  gate = true
  if gate:
    print "yes"
  else:
    print "no"
  if false:
    print "dead"
  else:
    print "live"
  const enabled = false
  if enabled and (1 % 0 == 0):
    print "skip"
  else:
    print "kept"
  const go = false
  if go or mark():
    print "called"
  const stop = true
  if stop or mark():
    print "short"
  print(false and (1 % 0 == 0))
  print(true or (1 % 0 == 0))
''';
    final result = compile(source);
    final dart = result.dart;
    final gate = dartName(result, 'gate');
    final enabled = dartName(result, 'enabled');
    expect(dart, contains('bool _qBool(bool value) => value;'));
    expect(dart, contains('if (_qBool($gate))'));
    expect(dart, contains('if (_qBool(false))'));
    expect(dart, contains('_qBool($enabled) &&'));
    expect(dart, contains('((1 % 0) == 0)'));
    await execute(source, 'yes\nlive\nkept\n999\ncalled\nshort\nfalse\ntrue\n');
  });

  test('a taken runtime logical branch still throws for Dart', () async {
    final dart = compile('main():\n  print(true and (1 % 0 == 0))\n').dart;
    expect(dart, contains('_qBool(true)'));
    expect(dart, contains('%'));
    final directory = Directory.systemTemp.createTempSync('quds-and-');
    try {
      final output = File('${directory.path}/app.dart')
        ..writeAsStringSync(dart);
      final analysis = await Process.run(
          Platform.resolvedExecutable, ['analyze', output.path]);
      expect(analysis.exitCode, 0,
          reason: '${analysis.stdout}\n${analysis.stderr}\n$dart');
      final run = await Process.run(Platform.resolvedExecutable, [output.path]);
      expect(run.exitCode, isNonZero);
      expect(run.stderr, contains('IntegerDivisionByZeroException'));
    } finally {
      directory.deleteSync(recursive: true);
    }
  });

  test('top-level consts evaluate in order and are visible to functions',
      () async {
    const source = '''const base = 10
const step = base - 3 - 2
const hidden = false
const allowed = hidden and (1 % 0 == 0)
const enabled = false
const values = [base, step]
const same = [1]
const copy = [1]
const equal = same == copy

show(value: int) = value

main():
  print step
  print allowed
  print enabled
  print values
  print equal
  print show(base)
  const local = base + 1
  print local
''';
    final result = compile(source);
    expect(valueOf(result, 'step'), ConstInt(5));
    expect(valueOf(result, 'allowed'), ConstBool(false));
    expect(valueOf(result, 'equal'), ConstBool(true));
    expect(valueOf(result, 'local'), ConstInt(11));
    expect(
        result.semantics.constants.containsKey(
            operators(bindingNamed(result.program, 'allowed').value, '%')
                .single),
        isFalse);
    final base = dartName(result, 'base');
    final allowed = dartName(result, 'allowed');
    expect(result.dart, contains('const int $base = 10;'));
    expect(result.dart, contains('const bool $allowed = false;'));
    expect(result.dart, isNot(contains('% 0')));
    expect(result.dart, contains('// ignore: unused_element'));
    expect(result.dart, contains(dartName(result, 'hidden')));
    await execute(source, '5\nfalse\nfalse\n[10, 5]\ntrue\n10\n11\n');
  });

  test('a function can read a top-level const declared later', () async {
    await execute('''main():
  print base
const base = 4
''', '4\n');
  });

  test('a top-level const is not reassigned or implicitly shadowed', () {
    expect(
        () => compile('const a = 1\nmain():\n  a = 2\n'),
        throwsA(isA<CompilerException>().having(
            (e) => e.message, 'message', 'Cannot assign immutable binding a')));
    expect(
        () => compile('const a = 1\nmain():\n  a = a + 1\n'),
        throwsA(isA<CompilerException>().having(
            (e) => e.message, 'message', 'Cannot assign immutable binding a')));
  });
}

const showcaseStdout = '5\n'
    '5\n'
    '14\n'
    '14\n'
    '3.5\n'
    '3.5\n'
    '-9223372036854775808\n'
    '-9223372036854775808\n'
    '-9223372036854775808\n'
    '-9223372036854775808\n'
    '1\n'
    '1\n'
    '2\n'
    '2\n'
    'false\n'
    'true\n'
    'abc\n'
    r'c$'
    '\n'
    '[10, 5, 2.0]\n'
    '[[1], [1]]\n'
    'true\n'
    'true\n'
    'NaN\n'
    'false\n'
    'Infinity\n'
    '-Infinity\n'
    '-0.0\n'
    'true\n'
    '-4\n'
    '1e-10\n'
    '0.30000000000000004\n'
    'true\n'
    'false\n';

Binding bindingNamed(Program program, String name) {
  final found = findBinding(program, name);
  if (found == null) fail('Missing binding $name');
  return found;
}

Binding? findBinding(Node node, String name) => switch (node) {
      Program(:final statements) => findIn(statements, name),
      FunctionDeclaration(:final body) =>
        body == null ? null : findIn(body, name),
      IfStatement(:final thenBody, :final elseBody) =>
        findIn(thenBody, name) ?? findIn(elseBody, name),
      ForStatement(:final body) => findIn(body, name),
      Binding() when node.name == name => node,
      _ => null,
    };

Binding? findIn(List<Statement> statements, String name) {
  for (final statement in statements) {
    final found = findBinding(statement, name);
    if (found != null) return found;
  }
  return null;
}

ConstValue valueOf(Compilation compilation, String name) => compilation
    .semantics
    .declarations[bindingNamed(compilation.program, name)]!
    .constantValue!;

String dartName(Compilation compilation, String name) => compilation
    .semantics.declarations[bindingNamed(compilation.program, name)]!.dartName;

List<BinaryExpression> operators(Expression node, String op) {
  final found = <BinaryExpression>[];
  void walk(Expression current) {
    switch (current) {
      case BinaryExpression(:final left, :final operator, :final right):
        if (operator == op) found.add(current);
        walk(left);
        walk(right);
      case UnaryExpression(:final operand):
        walk(operand);
      case ListExpression(:final elements):
        for (final element in elements) {
          walk(element);
        }
      case CallExpression(:final callee, :final arguments):
        walk(callee);
        for (final argument in arguments) {
          walk(argument.value);
        }
      case InterpolatedString(:final parts):
        for (final part in parts) {
          walk(part);
        }
      case Literal() || Identifier():
        break;
    }
  }

  walk(node);
  return found;
}

Future<void> execute(String source, String stdout) async {
  final directory = Directory.systemTemp.createTempSync('quds-const-exec-');
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
    expect(run.stderr, isEmpty);
  } finally {
    directory.deleteSync(recursive: true);
  }
}
