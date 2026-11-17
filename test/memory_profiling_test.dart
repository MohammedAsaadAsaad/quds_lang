import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:vm_service/vm_service.dart';
import '../tool/profile_heap.dart' show HeapPauseCheckpoints;

void main() {
  test('heap measurements ignore replayed pauses and other isolates', () {
    final checkpoints = HeapPauseCheckpoints('main');
    Event pause(String isolate, int position, int timestamp) => Event(
        kind: EventKind.kPauseBreakpoint,
        timestamp: timestamp,
        isolate: IsolateRef(id: isolate, name: isolate),
        topFrame: Frame(
            index: 0,
            location: SourceLocation(
                script: ScriptRef(id: 'memory', uri: 'memory.dart'),
                tokenPos: position)));
    expect(checkpoints.accept(pause('other', 10, 1)), isFalse);
    expect(checkpoints.accept(pause('main', 10, 2)), isTrue);
    expect(checkpoints.accept(pause('main', 10, 3)), isFalse);
    for (final position in [20, 30, 40, 50, 60]) {
      expect(checkpoints.accept(pause('main', position, position)), isTrue);
      expect(
          checkpoints.accept(pause('main', position, position + 1)), isFalse);
    }
    expect(checkpoints.count, 6);
  });
  test(
      'VM heap profiler observes Quds retain release and weak cache collection',
      () async {
    final result = await Process.run(
        Platform.resolvedExecutable, ['run', 'tool/profile_heap.dart']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final data = jsonDecode('${result.stdout}') as Map<String, dynamic>;
    expect(data['checksum'], 213097200);
    expect(data['retained']['cell']['instancesCurrent'], 20000);
    expect(data['released']['cell']['instancesCurrent'], 0);
    expect(data['weak_cache_after_removal']['cell']['instancesCurrent'], 0);
    final counts = data['allocation_trace_counts_cumulative'];
    expect(counts['copies']['_Float64List'],
        greaterThan(counts['retained']['_Float64List']));
    expect(counts['views']['_Float64ArrayView'],
        greaterThan(counts['copies']['_Float64ArrayView']));
  }, timeout: const Timeout(Duration(minutes: 3)));
  test(
      'Node profiler measures actual compiled Quds heap and allocation samples',
      () async {
    final result = await Process.run(
        Platform.resolvedExecutable, ['run', 'tool/profile_web_memory.dart']);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final data = jsonDecode('${result.stdout}') as Map<String, dynamic>;
    expect(data['checksum'], 213097200);
    expect(data['snapshots'], hasLength(6));
    expect(data['snapshots'][1]['process']['arrayBuffers'],
        greaterThan(data['snapshots'][0]['process']['arrayBuffers']));
    expect(
        data['snapshots'].last['allocation']['sample_count'], greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
