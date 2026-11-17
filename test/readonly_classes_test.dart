import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';

void main() {
  test('readonly class conformance executes in Quds', () async {
    final result = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'test', 'test/readonly_classes.quds']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect('${result.stdout}'.split('\n').where((l) => l.startsWith('ok ')),
        hasLength(8));
  });
  test('readonly class boundaries protect on VM and JavaScript', () async {
    final dir = Directory.systemTemp.createTempSync('quds-readonly-class-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final compilation =
        compile(File('test/readonly_classes_web.quds').readAsStringSync());
    File('${dir.path}/program.dart').writeAsStringSync(compilation.dart);
    writeSdkBundles(dir.path, compilation);
    final driver = File('${dir.path}/driver.dart')..writeAsStringSync(r'''
import 'program.dart' as q;
import 'quds_readonly.dart' as runtime;
void check(bool value) { if (!value) throw StateError('class guard assertion'); }
void blocked(void Function() run) {
  try { run(); } on UnsupportedError { return; }
  throw StateError('class guard allowed mutation');
}
Future<void> main() async {
  final source=q.Box<int>(values:[1]);
  source.child=source;
  final view=q.expose(source);
  check(identical(view, q.expose(source)) && identical(view.child, view));
  source.increment();
  check(view.read()==2);
  blocked(()=>view.count=9);
  blocked(()=>view.increment());
  blocked(()=>view.values[0]=3);
  blocked(()=>view.items().add(3));
  blocked(()=>view.impure);
  check(source.count==2);
  final generic=q.exposeGeneric<List<int>>(q.Box<List<int>>(values:[[1]]));
  blocked(()=>generic.values[0][0]=3);
  final owner=q.LazyBox(values:[1]);
  final lazy=q.lazyView(owner);
  check(lazy.cached[0]==1);
  owner.cached.add(2);
  check(lazy.cached.length==2 && owner.values.length==2);
  final fake=runtime.LazySlot<List<int>>();
  final attempted=fake.readonlyValue(()=>lazy.cached, const runtime.ListGuard<int>(runtime.AutoGuard<int>()));
  blocked(()=>attempted.add(3));
  blocked(()=>fake.mutableValue(()=>[]) .add(3));
  final original=q.Value(values:[1]);
  final protected=q.valueView(original);
  check(original==protected && protected==original);
  final equal=q.Value(values:[1]);
  check(original==equal && original.hashCode==equal.hashCode);
  check(protected.hashCode==original.hashCode);
  blocked(()=>protected.copyWith().values.add(2));
  final values=[1];
  final future=await q.futureView(Future.value(values));
  blocked(()=>future.add(2));
  final asyncValue=await q.asyncView(values);
  blocked(()=>asyncValue.add(2));
  await for(final row in q.streamView(Stream.value(values))) {
    blocked(()=>row.add(2));
  }
  values.add(2);
  check(future.length==2 && asyncValue.length==2);
  print('READONLY CLASSES OK');
}
''');
    final analyze = await Process.run(
        Platform.resolvedExecutable, ['analyze', '--fatal-infos', driver.path]);
    expect(analyze.exitCode, 0, reason: '${analyze.stdout}\n${analyze.stderr}');
    final vm =
        await Process.run(Platform.resolvedExecutable, ['run', driver.path]);
    expect(vm.exitCode, 0, reason: '${vm.stdout}\n${vm.stderr}');
    expect(vm.stdout, 'lazy computed\nREADONLY CLASSES OK\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', driver.path, '-o', '${dir.path}/driver.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final js = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      '${dir.path}/driver.js'
    ]);
    expect(js.exitCode, 0, reason: '${js.stdout}\n${js.stderr}');
    expect(js.stdout, vm.stdout);
  }, timeout: const Timeout(Duration(minutes: 3)));
  test('built dependency directories share one readonly runtime', () async {
    final root = Directory.systemTemp.createTempSync('quds-readonly-build-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/quds.yaml').writeAsStringSync('language: 1.2\n');
    File('${root.path}/base.quds').writeAsStringSync(
        'class Parent<T>:\n  private value: T required\n  readonly read() -> readonly T = value\n');
    final input = File('${root.path}/src/app.quds')..parent.createSync();
    input.writeAsStringSync('''use "../base.quds"
class Child extends Parent<List<int>>:
  tag: int = 0
main():
  owner = Child(value: [1])
  view: readonly Child = owner
  print view.read()[0]
''');
    final build = await Process.run(Platform.resolvedExecutable,
        ['run', File('bin/quds.dart').absolute.path, 'build', input.path]);
    expect(build.exitCode, 0, reason: '${build.stdout}\n${build.stderr}');
    final output = '${root.path}/.dart_tool/quds/out/src/app.dart';
    final run = await Process.run(Platform.resolvedExecutable, [output]);
    expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
    expect(run.stdout, '1\n');
  });
  test('unproxyable native return boundaries fail at Quds coordinates', () {
    try {
      compile('use dart:io\nexpose(value: File) -> readonly File = value\n',
          file: 'native_boundary.quds');
      fail('Expected E910');
    } on CompilerException catch (error) {
      expect(error.code, 'E910');
      expect(error.span.file, 'native_boundary.quds');
      expect(error.span.line, 2);
    }
  });
  for (final source in [
    'produce(values: List<int>) async -> readonly List<int> = values\nmain() async:\n  value = await produce([1])\n  value[0] = 2\n',
    'consume(values: Stream<readonly List<int>>) async:\n  await for row in values:\n    row[0] = 2\n',
  ]) {
    test('async delivery retains nested readonly qualifications $source', () {
      expect(() => compile(source),
          throwsA(predicate((e) => '$e'.contains('E307'))));
    });
  }
  test('embedded readonly runtime matches its canonical source', () {
    final bundle = compile('class A:\n  value: int = 1\n')
        .bundles
        .singleWhere((b) => b.fileName == 'quds_readonly.dart')
        .source;
    expect(bundle, File('lib/src/readonly_runtime.dart').readAsStringSync());
  });
}
