import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:quds_lang/quds_lang.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service_io.dart';

const _workload = r'''
final samples = <WeakReference<p.Probe>>[];
late WeakReference<p.Probe> liveReceiver;
late int Function({int amount}) live;
void cycle(int index) {
  final receiver = p.Probe(value: index);
  receiver.back = p.hold(receiver);
  samples.add(WeakReference(receiver));
}
void seed() {
  for (var i = 0; i < 1000; i++) { cycle(i); }
  final receiver = p.Probe(value: 41);
  live = p.hold(receiver);
  liveReceiver = WeakReference(receiver);
}
String inspect() => jsonEncode({
  'collected': samples.where((ref) => ref.target == null).length,
  'buckets': p.$QudsValueCache.length,
  'live': live(),
  'canonical': identical(live, p.hold(liveReceiver.target!)),
});
''';

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('quds-value-cache-gc-');
    final source = File('test/fixtures/value_cache_gc.quds').absolute;
    final result = compile(source.readAsStringSync(), file: source.path);
    File('${root.path}/program.dart').writeAsStringSync(result.dart);
    writeSdkBundles(root.path, result);
  });
  tearDown(() => root.deleteSync(recursive: true));

  void verify(Map<String, dynamic> result) {
    expect(result['collected'], greaterThanOrEqualTo(990), reason: '$result');
    expect(result['buckets'], lessThanOrEqualTo(10), reason: '$result');
    expect(result['live'], 42);
    expect(result['canonical'], isTrue);
    print('Quds function cache GC: $result');
  }

  test('VM collects cyclic Quds receivers while live values stay canonical',
      () async {
    final input = File('${root.path}/vm.dart')..writeAsStringSync('''
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'program.dart' as p;
$_workload
Future<void> main() async {
  seed();
  print('QUDS_GC_READY');
  await stdin.transform(utf8.decoder).transform(const LineSplitter()).first;
  await Future<void>.delayed(const Duration(milliseconds: 100));
  print('QUDS_GC_RESULT:' + inspect());
}
''');
    final process = await Process.start(Platform.resolvedExecutable,
        ['--enable-vm-service=0', '--disable-service-auth-codes', input.path]);
    addTearDown(() => process.kill());
    final endpoint = Completer<Uri>();
    final ready = Completer<void>();
    final result = Completer<Map<String, dynamic>>();
    final output = <String>[];
    void receive(String line) {
      output.add(line);
      final match = RegExp(r'http://127\.0\.0\.1:\d+/\S*').firstMatch(line);
      if (match != null && !endpoint.isCompleted)
        endpoint.complete(Uri.parse(match.group(0)!));
      if (line == 'QUDS_GC_READY' && !ready.isCompleted) ready.complete();
      if (line.startsWith('QUDS_GC_RESULT:') && !result.isCompleted) {
        result.complete(jsonDecode(line.substring('QUDS_GC_RESULT:'.length))
            as Map<String, dynamic>);
      }
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(receive);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(receive);
    final uri = await endpoint.future.timeout(const Duration(seconds: 20),
        onTimeout: () => throw StateError(output.join('\n')));
    final service = await vmServiceConnectUri(
        uri.replace(scheme: 'ws', path: '${uri.path}ws').toString());
    addTearDown(service.dispose);
    await ready.future.timeout(const Duration(seconds: 20));
    final vm = await service.getVM();
    final isolate =
        vm.isolates!.singleWhere((entry) => entry.name == 'main').id!;
    for (var i = 0; i < 3; i++) {
      await service.getAllocationProfile(isolate, gc: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    process.stdin.writeln('check');
    verify(await result.future.timeout(const Duration(seconds: 20)));
    expect(await process.exitCode, 0, reason: output.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 1)));

  test(
      'JavaScript collects cyclic Quds receivers while live values stay canonical',
      () async {
    final input = File('${root.path}/web.dart')..writeAsStringSync('''
import 'dart:convert';
import 'dart:js_interop';
import 'program.dart' as p;
$_workload
@JS('qudsGCResult') external set result(JSFunction value);
void main() {
  seed();
  result = (() => inspect().toJS).toJS;
}
''');
    final js = '${root.path}/program.js';
    final build = await Process.run(
        Platform.resolvedExecutable, ['compile', 'js', input.path, '-o', js]);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');
    final run = await Process.run('node', [
      '--expose-gc',
      '-e',
      r'''
globalThis.self = globalThis;
require(process.argv[1]);
(async () => {
  let result;
  for (let i = 0; i < 50; i++) {
    await new Promise(setImmediate);
    global.gc();
    await new Promise(resolve => setTimeout(resolve, 10));
    result = JSON.parse(globalThis.qudsGCResult());
    if (result.collected >= 990 && result.buckets <= 10) break;
  }
  console.log(JSON.stringify(result));
})().catch(error => { console.error(error); process.exitCode = 1; });
''',
      js
    ]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    verify(jsonDecode('${run.stdout}'.trim()) as Map<String, dynamic>);
  }, timeout: const Timeout(Duration(minutes: 1)));
  test('current ABI rebuilds a checksum-valid v12 consumer with a strong cache',
      () async {
    File('${root.path}/pubspec.yaml').writeAsStringSync(
        "name: cache_upgrade\nenvironment:\n  sdk: '>=3.3.0 <4.0.0'\n");
    final input = File('${root.path}/main.quds')
      ..writeAsStringSync(
          'extend Object:\n  inspect(value: int = 1) -> int = value\n'
          'main():\n  owner: Object = 3\n  saved = owner.inspect\n'
          '  print saved == owner.inspect\n  print saved()\n');
    final built = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'build', input.path]);
    expect(built.exitCode, 0, reason: '${built.stdout}${built.stderr}');
    const old = "// Generated by Quds MVP-0. Do not edit.\n"
        "void main() { print('legacy strong cache'); }\n";
    File('${root.path}/.dart_tool/quds/out/main.dart').writeAsStringSync(old);
    final directory = Directory('${root.path}/.dart_tool/quds/cache');
    var replaced = false;
    for (final file in directory.listSync().whereType<File>()) {
      final cache = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      cache['abi'] = 'provider-defaults-v12';
      final paths = (cache['paths'] as List).cast<String>();
      if (paths.length == 1 && paths.single == input.path) {
        cache['output'] = sha256Hex(utf8.encode(old));
        replaced = true;
      }
      file.writeAsStringSync(jsonEncode(cache));
    }
    expect(replaced, isTrue);
    final run = await Process.run(Platform.resolvedExecutable,
        ['run', 'bin/quds.dart', 'run', input.path]);
    expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');
    expect(run.stdout, 'true\n1\n');
    for (final file in directory.listSync().whereType<File>()) {
      expect((jsonDecode(file.readAsStringSync()) as Map)['abi'],
          'provider-defaults-v14');
    }
  });
}
