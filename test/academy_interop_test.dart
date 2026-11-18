import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:quds_lang/src/dart_api.dart';
import 'package:test/test.dart';

void main() {
  test('raw literals retain braces escapes and triple indentation at runtime',
      () async {
    const source = r'''main():
  print r"\q\n{unknown}"
  print r'{unclosed'
  text = r"""
    hello {name}
    \t stays
    """
  print text
''';
    final tokens = const Lexer().tokenize(source);
    expect(tokens.where((t) => t.kind == TokenKind.string).first.lexeme,
        startsWith('r"'));
    final dir = Directory.systemTemp.createTempSync('quds-raw-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final compilation = compile(source);
    writeSdkBundles(dir.path, compilation);
    final output = File('${dir.path}/main.dart')
      ..writeAsStringSync(compilation.dart);
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, '\\q\\n{unknown}\n{unclosed\nhello {name}\n\\t stays\n');
  });

  test('nested constructor argument blocks and contextual label compose',
      () async {
    const source = '''class Label:
  label: String required
class Box:
  child: Label required
main():
  box = Box:
    child: Label:
      label: "Quds"
  print box.child.label
''';
    final dir = Directory.systemTemp.createTempSync('quds-nested-label-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final compilation = compile(source);
    writeSdkBundles(dir.path, compilation);
    final output = File('${dir.path}/main.dart')
      ..writeAsStringSync(compilation.dart);
    final run = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, 'Quds\n');
  });

  test('collection defaults use contextual types and stay fresh per call',
      () async {
    const source = """class Bag:
  var names: List<String> = []
size(names: List<String> = []) -> int = names.length
main():
  first = Bag()
  second = Bag()
  first.names.add("Quds")
  print second.names.length
  print size()
""";
    final dir = Directory.systemTemp.createTempSync('quds-collection-default-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final compilation = compile(source);
    writeSdkBundles(dir.path, compilation);
    final file = File('${dir.path}/main.dart')
      ..writeAsStringSync(compilation.dart);
    final run = await Process.run(Platform.resolvedExecutable, [file.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, '0\n0\n');
  });

  test('definite returns include finally and every reachable catch path', () {
    expect(() => compile('''value() -> int:
  try:
    return 42
  finally:
    print "cleanup"
main():
  print value()
'''), returnsNormally);
    expect(() => compile('''value() -> int:
  try:
    return 42
  catch error:
    print error
'''), throwsA(isA<CompilerException>()));
    expect(() => compile('''value() -> int:
  try:
    print "work"
  finally:
    return 42
'''), returnsNormally);
  });

  test('conditional values join nullable callbacks and subtype branches', () {
    expect(() => compile("""class Base:
  value: int = 1
class Child extends Base:
  extra: int = 2
class Sibling extends Base:
  other: int = 3
main():
  chosen = if true: Child() else: Sibling()
  callback = if true: null else: (() -> 42)
  print chosen.value
"""), returnsNormally);
  });

  test('Dart export filters preserve names and SDK parts keep their owner', () {
    final dir = Directory.systemTemp.createTempSync('quds-embedder-');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/.dart_tool').createSync();
    Directory('${dir.path}/sdk/lib').createSync(recursive: true);
    File('${dir.path}/pubspec.yaml')
        .writeAsStringSync('name: embedder_probe\n');
    File('${dir.path}/.dart_tool/package_config.json').writeAsStringSync("""{
      "configVersion":2,"packages":[{"name":"embedded_sdk","rootUri":"../sdk/","packageUri":"lib/","languageVersion":"3.3"}]
    }""");
    final typedData = File(Platform.resolvedExecutable)
        .parent
        .parent
        .uri
        .resolve('lib/typed_data/typed_data.dart')
        .toFilePath();
    File('${dir.path}/sdk/lib/_embedder.yaml').writeAsStringSync(
        'embedded_libs:\n  "dart:ui": "ui.dart"\n  "dart:typed_data": "$typedData"\n');
    File('${dir.path}/sdk/lib/ui.dart').writeAsStringSync(
        "library dart.ui; part 'color.dart'; typedef VoidCallback = void Function();\n");
    final part = File('${dir.path}/sdk/lib/color.dart')
      ..writeAsStringSync(
          "part of dart.ui; class Color { Color(this.value); final int value; }\n");
    File('${dir.path}/public.dart').writeAsStringSync(
        "import 'dart:typed_data'; class Colors { static const String transparent = 'clear'; } void tap(VoidCallback action) {} Uint8List bytes() => Uint8List(1);\n");
    File('${dir.path}/math.dart').writeAsStringSync(
        "class Colors { static const double transparent = 1.0; } class Matrix {} class Hidden {}\n");
    final entry = File('${dir.path}/api.dart')
      ..writeAsStringSync(
          "export 'public.dart'; export 'math.dart' show Matrix; export 'dart:ui' show Color, VoidCallback; export 'dart:typed_data' show Uint8List;\n");
    final surface = readDartFile(entry, from: '${dir.path}/main.quds')!;
    expect(
        surface.names.keys, containsAll(['Colors', 'Matrix', 'Color', 'tap']));
    expect(surface.names.keys, isNot(contains('Hidden')));
    expect(surface.types['Colors']!.statics['transparent']!.type, 'String');
    expect(surface.names['tap']!.parameters.single.$2, '() -> void');
    final owner = '${dir.path}/sdk/lib/ui.dart';
    expect(surface.declarationLibraries[part.path], owner);
    expect(surface.libraryUris[owner], 'dart:ui');
    expect(() => compile('''use api.dart
use dart:typed_data
main():
  value: Uint8List = bytes()
  print value.length
''', file: '${dir.path}/main.quds'), returnsNormally);
  });

  test('Dart metadata skips delimiter characters inside method strings', () {
    final dir = Directory.systemTemp.createTempSync('quds-native-strings-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final native = File('${dir.path}/api.dart')..writeAsStringSync(r'''
class Database {
  String query() { final marker = '}'; return marker; }
  Future<void> close() async { final marker = '{'; print(marker); }
  String finish() => 'done';
}
''');
    final surface = readDartFile(native)!;
    expect(surface.types['Database']!.members.keys,
        containsAll(['query', 'close', 'finish']));
  });

  test('CLI preserves project pub identities and transitive native signatures',
      () async {
    final dir = Directory.systemTemp.createTempSync('quds-package-identity-');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/.dart_tool').createSync();
    Directory('${dir.path}/bridge/lib/src').createSync(recursive: true);
    File('${dir.path}/pubspec.yaml').writeAsStringSync('name: probe\n');
    File('${dir.path}/bridge/pubspec.yaml').writeAsStringSync('name: bridge\n');
    File('${dir.path}/.dart_tool/package_config.json').writeAsStringSync('''{
      "configVersion": 2, "packages": [
        {"name":"bridge","rootUri":"../bridge/","packageUri":"lib/","languageVersion":"3.3"},
        {"name":"probe","rootUri":"../","packageUri":"lib/","languageVersion":"3.3"}
      ]
    }''');
    File('${dir.path}/bridge/lib/api.dart')
        .writeAsStringSync("export 'package:bridge/src/api.dart';\n");
    File('${dir.path}/bridge/lib/src/api.dart').writeAsStringSync('''
import 'parents.dart' as base;
import 'dart:typed_data';
export 'parents.dart';
part 'extra.dart';
typedef Builder<T> = String Function(T value);
abstract class Root {}
class Middle extends Root {}
class Parent<T> {
  Parent({required this.value});
  final T value;
  String render(Builder<T> builder) => builder(value);
}
class Child<T> extends Parent<T> { Child({required super.value}); }
class Named extends Parent<String> { Named({required String super.value}); }
class Host<T> { T get widget => throw UnimplementedError(); }
class Offset extends base.BaseOffset { Offset(super.dx); }
Extra openExtra() => Extra();
class Database {
  String query() { final text = '}'; return text; }
  Future<void> close() async {}
}
Future<Database> open() async => Database();
int acceptRoot(Root value) => 42;
Uint8List loadBytes() => Uint8List.fromList([42]);
int acceptBytes(Uint8List value) => value.first;
''');
    File('${dir.path}/bridge/lib/src/parents.dart').writeAsStringSync(
        'class BaseOffset { BaseOffset(this.value); final double value; }\n');
    File('${dir.path}/bridge/lib/src/extra.dart').writeAsStringSync(
        "part of 'api.dart'; class Extra { int get value => 7; }\n");
    File('${dir.path}/model.quds')
        .writeAsStringSync('''use package:bridge/api.dart
class Holder:
  db: Database required
class Leaf extends Middle:
  value: int = 1
openModel() async -> Database:
  return await open()
acceptLeaf() -> int = acceptRoot(Leaf())
class Flag:
  ready: bool = true
class ChildState extends Host<Flag>:
  read() -> bool = widget.ready and true
callbackDemo() -> String:
  child = Child<int>(value: 9)
  typed = Named(value: "x")
  return child.render((value: int) -> "{value}") + typed.value
extraDemo() -> Extra = openExtra()
offsetDemo() -> double = Offset(1.5).value
bytesDemo() -> int = acceptBytes(loadBytes())
''');
    final main = File('${dir.path}/main.quds')..writeAsStringSync('''use model
main() async:
  database = await openModel()
  holder = Holder(database)
  print holder.db.query()
  print acceptLeaf()
  print callbackDemo()
  extra = extraDemo()
  print extra.value
  print offsetDemo()
  print bytesDemo()
  await database.close()
''');
    final cli = File('bin/quds.dart').absolute.path;
    final run =
        await Process.run(Platform.resolvedExecutable, [cli, 'run', main.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, '}\n42\n9x\n7\n1.5\n42\n');
    final generated =
        File('${dir.path}/.dart_tool/quds/out/model.dart').readAsStringSync();
    expect(generated,
        contains("import 'package:bridge/src/api.dart' as _qNative"));
    final suite = File('${dir.path}/probe_test.quds')
      ..writeAsStringSync('''use model
test "native project package" async:
  database = await openModel()
  expect(database.query(), r"}")
  await database.close()
''');
    final tests = await Process.run(
        Platform.resolvedExecutable, [cli, 'test', suite.path]);
    expect(tests.exitCode, 0, reason: '${tests.stdout}${tests.stderr}');
    expect(tests.stdout, contains('ok native project package'));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
