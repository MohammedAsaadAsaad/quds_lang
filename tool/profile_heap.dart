import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:quds_lang/quds_lang.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

// VM-service measurements on actual compiled Quds. Diagnostic, not CI budgets.
Future<void> main() async {
  final directory = Directory.systemTemp.createTempSync('quds-heap-');
  Process? process;
  VmService? service;
  try {
    final source = File('bench/memory_workload.quds');
    final compilation = compile(source.readAsStringSync(), file: source.path);
    writeSdkBundles(directory.path, compilation);
    final output = File('${directory.path}/memory.dart')
      ..writeAsStringSync(compilation.dart);
    final endpoint = Completer<Uri>();
    final lines = <String>[];
    process = await Process.start(Platform.resolvedExecutable, [
      '--enable-vm-service=0',
      '--profiler',
      '--disable-service-auth-codes',
      '--pause-isolates-on-start',
      output.path
    ]);
    void receive(String line) {
      lines.add(line);
      final match = RegExp(r'http://127\.0\.0\.1:\d+/\S*').firstMatch(line);
      if (match != null && !endpoint.isCompleted)
        endpoint.complete(Uri.parse(match.group(0)!));
    }

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(receive);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(receive);
    final uri = await endpoint.future.timeout(const Duration(seconds: 30));
    service = await vmServiceConnectUri(
        uri.replace(scheme: 'ws', path: '${uri.path}ws').toString());
    final pauses = StreamController<Event>();
    final subscription = service.onDebugEvent.listen((event) {
      if (event.kind == EventKind.kPauseBreakpoint) pauses.add(event);
    });
    await service.streamListen(EventStreams.kDebug);
    final iterator = StreamIterator(pauses.stream);
    final vm = await service.getVM();
    final isolate = vm.isolates!.singleWhere((i) => i.name == 'main').id!;
    final startupDeadline = DateTime.now().add(const Duration(seconds: 30));
    while ((await service.getIsolate(isolate)).runnable != true) {
      if (DateTime.now().isAfter(startupDeadline))
        throw StateError('Isolate did not become runnable');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    Future<void> advance() async {
      await service!.resume(isolate).timeout(const Duration(seconds: 30));
      if (!await iterator.moveNext().timeout(const Duration(seconds: 30)))
        throw StateError('Missing workload pause');
    }

    await advance();
    final classes = await service.getClassList(isolate);
    final cell = classes.classes!.singleWhere((c) => c.name == 'HeapCell');
    for (final type in classes.classes!.where((c) =>
        c.id == cell.id ||
        (c.name?.contains('Float64') ?? false) ||
        c.name == '_ByteBuffer')) {
      await service.setTraceClassAllocation(isolate, type.id!, true);
    }
    final typedClasses = classes.classes!
        .where((c) =>
            c.name == '_Float64List' ||
            c.name == '_Float64ArrayView' ||
            c.name == '_ExternalFloat64Array')
        .toList();
    Future<Map<String, int>> traces() async => {
          for (final type in typedClasses)
            type.name!:
                (await service!.getAllocationTraces(isolate, classId: type.id))
                    .samples!
                    .length,
        };
    final traceCounts = <String, Map<String, int>>{};
    Map<String, Object?> snapshot(AllocationProfile p) => {
          'memory': p.memoryUsage!.toJson(),
          'cell':
              p.members!.singleWhere((m) => m.classRef?.id == cell.id).toJson(),
          'typed_data': p.members!
              .where((m) => m.classRef?.name?.contains('Float64') ?? false)
              .map((m) => m.toJson())
              .toList(),
        };
    final baseline =
        await service.getAllocationProfile(isolate, gc: true, reset: true);
    await advance();
    traceCounts['retained'] = await traces();
    final retained = await service.getAllocationProfile(isolate, gc: true);
    await advance();
    final released =
        await service.getAllocationProfile(isolate, gc: true, reset: true);
    await advance();
    traceCounts['copies'] = await traces();
    final copies = await service.getAllocationProfile(isolate, gc: true);
    await service.getAllocationProfile(isolate, reset: true);
    await advance();
    traceCounts['views'] = await traces();
    final views = await service.getAllocationProfile(isolate, gc: true);
    await advance();
    final weakCache = await service.getAllocationProfile(isolate, gc: true);
    await service.resume(isolate);
    final code = await process.exitCode.timeout(const Duration(seconds: 30));
    if (code != 0 || !lines.contains('213097200'))
      throw StateError('Workload checksum failed: $lines');
    final before =
        baseline.members!.singleWhere((m) => m.classRef?.id == cell.id);
    final after =
        retained.members!.singleWhere((m) => m.classRef?.id == cell.id);
    final cleared =
        released.members!.singleWhere((m) => m.classRef?.id == cell.id);
    if (after.instancesCurrent! - before.instancesCurrent! != 20000 ||
        cleared.instancesCurrent != before.instancesCurrent)
      throw StateError('Retain/release object counts disagree');
    if (weakCache.members!
            .singleWhere((m) => m.classRef?.id == cell.id)
            .instancesCurrent !=
        before.instancesCurrent)
      throw StateError('Readonly cache retained removed graph elements');
    print(const JsonEncoder.withIndent('  ').convert({
      'schema': 1,
      'dart': Platform.version,
      'mode': 'JIT, VM Service, paused isolate, requested full GC',
      'allocation_tracking':
          'HeapCell and Float64 runtime classes traced after warmup; cumulative allocation traces include collected objects',
      'allocation_trace_counts_cumulative': traceCounts,
      'payload_bytes_retained': 8 * 65536 * 8,
      'checksum': 213097200,
      'baseline': snapshot(baseline),
      'retained': snapshot(retained),
      'released': snapshot(released),
      'copies': snapshot(copies),
      'views': snapshot(views),
      'weak_cache_after_removal': snapshot(weakCache),
    }));
    await subscription.cancel();
    await iterator.cancel();
    await pauses.close();
  } finally {
    process?.kill();
    await service?.dispose().timeout(const Duration(seconds: 5));
    directory.deleteSync(recursive: true);
  }
}
