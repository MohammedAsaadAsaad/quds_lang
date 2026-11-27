import 'package:flutter_test/flutter_test.dart';
import 'package:quds/interpreter.dart';
import 'package:quds_studio/presets.dart';

void main() {
  test(
    'Every single Quds Studio preset executes cleanly on the Universal Register Bytecode VM',
    () async {
      // Verify massive catalog count & complete category coverage
      expect(studioPresets.length, greaterThanOrEqualTo(115));
      for (final cat in StudioCategory.values) {
        final count = studioPresets.where((p) => p.category == cat).length;
        expect(count, greaterThan(0), reason: 'Category ${cat.name} is empty');
      }

      // Check unique preset IDs
      final ids = <String>{};
      for (final p in studioPresets) {
        expect(ids.add(p.id), isTrue, reason: 'Duplicate preset id: ${p.id}');
      }

      final failures = <String>[];
      var vmAcceleratedCount = 0;

      for (final p in studioPresets) {
        // Skip systemBridge-only capability preset that expects host bridge
        if (p.defaultPolicy == StudioPolicyMode.systemBridge) continue;
        // Skip heavy CPU benchmark presets here (covered in widget_test.dart with benchmark policy)
        if (p.category == StudioCategory.benchmarks) continue;

        final session = QudsSession(policy: QudsExecutionPolicy.standard());
        final res = await session.run(
          p.code,
          file: p.fileName,
          preferBytecode: true,
        );
        if (!res.succeeded) {
          failures.add('${p.id} (${p.fileName}) frame 0 FAILED: ${res.error}');
        } else {
          if (res.usedBytecodeVm) vmAcceleratedCount++;
          if (p.isAnimated) {
            final step = await session.stepFrame(
              0.033,
              time: 0.5,
              frame: 1,
              source: p.code,
              file: p.fileName,
            );
            if (!step.succeeded) {
              failures.add(
                '${p.id} (${p.fileName}) anim frame 1 FAILED: ${step.error}',
              );
            }
          }
        }
        await session.dispose();
      }

      // ignore: avoid_print
      print(
        'Verified ${studioPresets.length} Quds Studio presets across ${StudioCategory.values.length} categories ($vmAcceleratedCount VM-accelerated)!',
      );
      expect(
        failures,
        isEmpty,
        reason:
            'Preset VM failures (${failures.length}):\n${failures.join('\n')}',
      );
      expect(vmAcceleratedCount, greaterThanOrEqualTo(100));
    },
  );
}
