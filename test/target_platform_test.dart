import 'dart:io';
import 'package:quds/quds.dart';
import 'package:test/test.dart';

void main() {
  test('target selection skips inactive Quds imports before parsing them',
      () async {
    final root = Directory.systemTemp.createTempSync('quds-target-');
    addTearDown(() => root.deleteSync(recursive: true));
    final input = File('${root.path}/main.quds');
    final web = File('${root.path}/browser.quds')
      ..writeAsStringSync('choice() -> String = "web"\n');
    final native = File('${root.path}/native.quds')
      ..writeAsStringSync('invalid ??? native syntax\n');
    input.writeAsStringSync('''when platform == "web":
  use browser
when platform != "web":
  use native
main():
  print choice()
''');
    final compilation = compile(input.readAsStringSync(),
        file: input.path, targetPlatform: 'web');
    String canonical(String path) =>
        File(path).absolute.uri.normalizePath().toFilePath();
    final dependencies = compilation.dependencies.map(canonical);
    expect(dependencies, contains(canonical(web.path)));
    expect(dependencies, isNot(contains(canonical(native.path))));
    expect(compilation.dart, contains("import 'browser.dart'"));
    final output = File('${root.path}/main.dart')
      ..writeAsStringSync(compilation.dart);
    File('${root.path}/browser.dart').writeAsStringSync(
        compile(web.readAsStringSync(), file: web.path, targetPlatform: 'web')
            .dart);
    final vm = await Process.run(Platform.resolvedExecutable, [output.path]);
    expect(vm.exitCode, 0, reason: '${vm.stderr}');
    expect('${vm.stdout}'.replaceAll('\r\n', '\n'), 'web\n');
    final build = await Process.run(Platform.resolvedExecutable,
        ['compile', 'js', output.path, '-o', '${root.path}/main.js']);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final node = await Process.run('node', [
      '-e',
      'globalThis.self = globalThis; require(process.argv[1]);',
      '${root.path}/main.js'
    ]);
    expect(node.exitCode, 0, reason: '${node.stderr}');
    expect('${node.stdout}'.replaceAll('\r\n', '\n'),
        '${vm.stdout}'.replaceAll('\r\n', '\n'));
  });
  test('Dart library flags distinguish native, web and Flutter context', () {
    const source = '''when dart.library.io:
  use dart:io
when dart.library.js_interop:
  use dart:js_interop
when dart.library.ui:
  use dart:ui
main():
  print "target"
''';
    final vm = compile(source);
    expect(vm.dart, contains("import 'dart:io'"));
    expect(vm.dart, isNot(contains("import 'dart:js_interop'")));
    final web = compile(source, targetPlatform: 'web');
    expect(web.dart, contains("import 'dart:js_interop'"));
    expect(web.dart, isNot(contains("import 'dart:io'")));
    expect(vm.dart, isNot(contains("import 'dart:ui'")));
    expect(web.dart, isNot(contains("import 'dart:ui'")));
    final flutter = compile(source, targetPlatform: 'web', flutter: true);
    expect(flutter.dart, contains("import 'dart:ui'"));
    expect(flutter.dart, isNot(contains("import 'dart:io'")));
    expect(
        () => compile(source, targetPlatform: 'unknown'), throwsArgumentError);
  });
}
