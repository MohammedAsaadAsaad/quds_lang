import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('throwing paths satisfy a non-void function return contract', () {
    compile('alwaysFails() -> int:\n  throw "stop"\n');
    compile(
        'f(ok: bool) -> int:\n  if ok:\n    return 1\n  else:\n    throw "stop"\n');
  });
  test('a conditional throw does not hide a missing return path', () {
    expect(() => compile('f(ok: bool) -> int:\n  if ok:\n    throw "stop"\n'),
        throwsA(isA<CompilerException>()));
  });
  test('outer mutable assignment and explicit immutable shadow', () {
    compile(
        'main():\n  var x = 1\n  if true:\n    x += 2\n    shadow x = x + 1\n    print x\n  print x\n');
  });
  test('var parameter reassignment is local, ordinary parameter immutable', () {
    compile('f(var x: int) -> int:\n  x += 1\n  return x\n');
    expect(() => compile('f(x: int) -> int:\n  x = 1\n  return x\n'),
        throwsA(isA<CompilerException>()));
  });
  test('expression function return inference and forward call', () {
    compile('main():\n  print add(1, 2)\nadd(a: int, b: int) = a + b\n');
  });
  test('numeric widening to num and typed list annotation', () {
    compile(
        'main():\n  x: num = 1\n  values: List<int> = [1, 2]\n  print x\n  print values\n');
  });
  final invalid = <String, String>{
    'immutable assignment': 'main():\n  x = 1\n  x = 2\n',
    'immutable object binding assignment': 'main():\n  xs = [1]\n  xs = [2]\n',
    'implicit shadow': 'main():\n  x = 1\n  if true:\n    var x = 2\n',
    'shadow without outer binding': 'main():\n  shadow x = 1\n',
    'same scope shadow': 'main():\n  x = 1\n  shadow x = 2\n',
    'out of scope': 'main():\n  if true:\n    x = 1\n  print x\n',
    'undefined initializer': 'main():\n  x = x + 1\n',
    'unknown function': 'main():\n  missingFunction()\n',
    'wrong argument type': 'f(x: int) = x\nmain():\n  print f("x")\n',
    'duplicate argument': 'f(x: int) = x\nmain():\n  print f(1, x: 2)\n',
    'missing argument': 'f(x: int) = x\nmain():\n  print f()\n',
    'unknown named argument': 'f(x: int) = x\nmain():\n  print f(y: 1)\n',
    'positional after named':
        'f(x: int, y: int) = x\nmain():\n  print f(x: 1, 2)\n',
    'non-bool if': 'main():\n  if 1:\n    print 1\n',
    'non-list loop': 'main():\n  for x in 1:\n    print x\n',
    'loop binding shadow': 'main():\n  x = 1\n  for x in [1]:\n    print x\n',
    'loop variable immutable': 'main():\n  for x in [1]:\n    x += 1\n',
    'return mismatch': 'f() -> int:\n  return "x"\n',
    'missing return path': 'f(x: bool) -> int:\n  if x:\n    return 1\n',
    'implicit multiline return': 'f() -> int:\n  1 + 2\n',
    'unsupported overload': 'f() = 1\nf() = 2\n',
    'unsafe numeric conversion': 'main():\n  x: double = 1\n',
    'non-constant const': 'f() = 1\nmain():\n  const x = f()\n',
    'void binding': 'main():\n  x = print(1)\n',
    'void operand': 'main():\n  print(print(1) == print(2))\n',
    'heterogeneous list': 'main():\n  xs = [1, "x"]\n',
    'recursive inference': 'f() = f()\n',
  };
  for (final entry in invalid.entries) {
    test('rejects ${entry.key}', () {
      expect(
          () => compile(entry.value, file: 'bad.quds'),
          throwsA(isA<CompilerException>()
              .having((e) => e.span.file, 'file', 'bad.quds')));
    });
  }
  test('a function name is a tear-off', () {
    compile('f() = 1\nmain():\n  x = f\n  print x()\n');
  });
  test('undefined interpolation reports original source location', () {
    expect(
        () => compile('main():\n  print "value {unknown}"\n', file: 'bad.quds'),
        throwsA(isA<CompilerException>()
            .having((e) => e.span.line, 'line', 2)
            .having((e) => e.span.column, 'column', 17)));
  });
}
