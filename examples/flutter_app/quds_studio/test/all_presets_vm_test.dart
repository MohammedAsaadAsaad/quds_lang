import 'package:flutter_test/flutter_test.dart';
import 'package:quds/interpreter.dart';
import 'package:quds_studio/ai_agent_lab.dart';
import 'package:quds_studio/presets.dart';
import 'package:quds_studio/project_templates.dart';

void main() {
  test(
    'Every single Quds Studio preset executes cleanly on the Universal Register Bytecode VM',
    () async {
      // Verify massive catalog count & complete category coverage
      expect(studioPresets.length, greaterThanOrEqualTo(138));
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
      expect(vmAcceleratedCount, greaterThanOrEqualTo(120));
    },
  );

  test(
    'All 12 multi-folder Quds projects with assets/ execute cleanly on Register VM and round-trip .qproj v2 JSON',
    () async {
      expect(studioProjectTemplates, hasLength(12));

      for (final tpl in studioProjectTemplates) {
        final ws = tpl.builder();
        expect(ws.assetCount, greaterThan(0),
            reason: 'Project ${tpl.id} must include assets/');
        final deps = ws.analyzeDependencies();
        expect(deps.hasCycles, isFalse, reason: 'Project ${tpl.id} has cycles');
        expect(deps.hasUnresolvedImports, isFalse,
            reason:
                'Project ${tpl.id} has unresolved imports: ${deps.unresolvedImports}');

        // Round-trip through .qproj v2 JSON (including binary BMP assets)
        final restored = QudsWorkspace.fromJsonString(ws.toJsonString());
        final policy = tpl.usesBenchmarkPolicy
            ? QudsExecutionPolicy.standard(
                maxSteps: 180000000,
                maxCollectionLength: 500000,
                timeout: const Duration(seconds: 30),
              )
            : (tpl.usesSystemBridgePolicy
                ? QudsExecutionPolicy.systemBridge(
                    capabilities: [
                      QudsCapability.custom('ai.orders.read'),
                      QudsCapability.custom('ai.sensors.read'),
                    ],
                    maxSteps: 500000,
                    timeout: const Duration(seconds: 10),
                  )
                : QudsExecutionPolicy.standard(
                    maxSteps: 400000,
                    timeout: const Duration(seconds: 10),
                  ));
        final session = QudsSession(
          policy: policy,
          hostModules: [buildAiToolsHostModule()],
        )..attachWorkspace(restored);
        final res = await session.runProject(preferBytecode: true);
        expect(res.succeeded, isTrue,
            reason: 'Project ${tpl.id} failed: ${res.error}');
        expect(res.printedLines, isNotEmpty,
            reason: 'Project ${tpl.id} produced no stdout');

        if (tpl.id == 'heavy_vm_lab') {
          expect(res.outputs.whereType<QudsTableOutput>(), hasLength(1));
        } else if (tpl.id == 'ai_agent_sandbox') {
          expect(res.outputs.whereType<QudsTableOutput>(), hasLength(1));
          expect(res.outputs.whereType<QudsPlot2DOutput>(), hasLength(1));
          expect(res.lastForm, isNotNull);
        } else if (const {
          'v4_turbo_engine',
          'cnc_robotic_arm',
          'jet_turbine_cfd',
          'smart_power_grid',
          'cardiac_ecg_monitor',
        }.contains(tpl.id)) {
          expect(res.lastGeometryScene, isNotNull,
              reason: '${tpl.id} must emit live animated geometry scene');
          expect(res.animationSpec, isNotNull,
              reason: '${tpl.id} must emit 60fps animation spec');
          expect(res.outputs.whereType<QudsImageOutput>(), hasLength(1),
              reason: '${tpl.id} must render its BMP blueprint asset');
        } else if (tpl.id == 'quds_shop_pos') {
          expect(restored.hasAnyFile('assets/last_receipt.json'), isTrue);
          expect(res.outputs.whereType<QudsImageOutput>(), hasLength(1));
          expect(res.lastForm, isNotNull);
        } else if (tpl.id == 'quds_extensions_host') {
          expect(restored.hasAnyFile('assets/audit.json'), isTrue);
          expect(res.lastForm, isNotNull);
        } else if (tpl.id == 'pixel_asset_studio') {
          expect(res.outputs.whereType<QudsImageOutput>(), hasLength(2));
        } else if (tpl.id == 'sales_analytics_hub') {
          expect(res.lastPlot, isNotNull);
        }

        await session.dispose();
      }
    },
  );
}
