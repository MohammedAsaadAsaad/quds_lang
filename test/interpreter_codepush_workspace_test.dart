import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('CodePush & Nested Multi-Folder Bytecode Caching', () {
    QudsWorkspace buildNestedProject() => QudsWorkspace(
          name: 'shop_app',
          packageName: 'shop_app',
          entryPoint: 'main.quds',
          bundleVersion: '1.0.0',
          files: {
            'core/config/rates.quds': '''
TAX_RATE = 0.10
CURRENCY = "USD"
''',
            'domain/pricing/engine.quds': '''
use ^^.core.config.rates show TAX_RATE, CURRENCY

finalPrice(subtotal: double) -> String:
  total = subtotal * (1.0 + TAX_RATE)
  return "{total.toStringAsFixed(2)} {CURRENCY}"
''',
            'domain/index.quds': '''
export pricing.engine show finalPrice
''',
            'ui/theme/labels.quds': '''
APP_TITLE = "Quds Store"
''',
            'main.quds': '''
use domain.index as dom
use ui.theme.labels show APP_TITLE

print "{APP_TITLE}: {dom.finalPrice(100.0)}"
''',
          },
        );

    test(
        'compiles nested workspace modules to bytecode, reuses cache on repeat runs, and surgically updates on CodePush patch',
        () async {
      final ws = buildNestedProject();
      final session = QudsSession(projectWorkspace: ws);

      // Run 1: cold compile of all 4 imported nested modules.
      final r1 = await session.runProject();
      expect(r1.succeeded, isTrue, reason: '${r1.error}');
      expect(r1.printedLines, ['Quds Store: 110.00 USD']);

      final statsAfterRun1 = session.compilationStats;
      expect(statsAfterRun1.compiledModules, 4);
      expect(statsAfterRun1.cachedCompiledCount, 4);
      expect(
          session.hasCompiledWorkspaceFile('core/config/rates.quds'), isTrue);
      expect(session.hasCompiledWorkspaceFile('domain/pricing/engine.quds'),
          isTrue);
      expect(session.hasCompiledWorkspaceFile('ui/theme/labels.quds'), isTrue);

      // Run 2: zero recompilation — every imported nested module hits runtime cache.
      final r2 = await session.runProject();
      expect(r2.succeeded, isTrue, reason: '${r2.error}');
      expect(r2.printedLines, ['Quds Store: 110.00 USD']);
      final statsAfterRun2 = session.compilationStats;
      expect(statsAfterRun2.compiledModules, statsAfterRun1.compiledModules);
      expect(statsAfterRun2.runtimeCacheHits, greaterThan(0));

      // CodePush OTA patch (serialized over JSON):
      // - Updates deeply nested core/config/rates.quds
      // - Adds brand-new nested folder domain/discounts/promo.quds
      // - Updates barrel domain/index.quds to re-export promo
      // - Sends ui/theme/labels.quds unchanged (should be skipped & stay cached!)
      final patchPayload = QudsWorkspacePatch(
        bundleVersion: '1.1.0-hotfix',
        upsertFiles: {
          'core/config/rates.quds': '''
TAX_RATE = 0.25
CURRENCY = "EUR"
''',
          'domain/discounts/promo.quds': '''
applyPromo(amount: double) -> double = amount * 0.8
''',
          'domain/index.quds': '''
export pricing.engine show finalPrice
export discounts.promo show applyPromo
''',
          'ui/theme/labels.quds': '''
APP_TITLE = "Quds Store"
''',
          'main.quds': '''
use domain.index as dom
use ui.theme.labels show APP_TITLE

discounted = dom.applyPromo(100.0)
print "{APP_TITLE}: {dom.finalPrice(discounted)}"
''',
        },
      );

      // Simulate OTA network JSON round-trip.
      final roundTrippedPatch =
          QudsWorkspacePatch.fromJsonString(patchPayload.toJsonString());

      final pushRes = await session.applyWorkspacePatch(roundTrippedPatch);
      expect(pushRes.applied, isTrue, reason: '${pushRes.errors}');
      expect(pushRes.bundleVersion, '1.1.0-hotfix');
      expect(pushRes.unchangedFiles, ['ui/theme/labels.quds']);
      expect(
        pushRes.changedFiles,
        containsAll([
          'core/config/rates.quds',
          'domain/discounts/promo.quds',
          'domain/index.quds',
          'main.quds',
        ]),
      );
      // Transitive dependent `domain/pricing/engine.quds` was invalidated even
      // though its own source did NOT change!
      expect(
        pushRes.invalidatedModules,
        contains('domain/pricing/engine.quds'),
      );
      expect(
        pushRes.invalidatedModules,
        isNot(contains('ui/theme/labels.quds')),
      );
      // Changed files were eagerly precompiled into bytecode.
      expect(
        pushRes.recompiledFiles,
        containsAll([
          'core/config/rates.quds',
          'domain/discounts/promo.quds',
          'domain/index.quds',
        ]),
      );

      final hitsBeforeRun3 = session.compilationStats.bytecodeCacheHits;
      final r3 = await session.runProject();
      expect(r3.succeeded, isTrue, reason: '${r3.error}');
      // 100 * 0.8 = 80; 80 * 1.25 = 100.00 EUR
      expect(r3.printedLines, ['Quds Store: 100.00 EUR']);

      // Unchanged transitive dependent `domain/pricing/engine.quds` reused its
      // cached compiled bytecode artifact instead of re-lexing/re-parsing!
      expect(
        session.compilationStats.bytecodeCacheHits,
        greaterThan(hitsBeforeRun3),
      );
      expect(ws.bundleVersion, '1.1.0-hotfix');

      // Rollback to v1.0.0 snapshot restores original nested modules cleanly.
      final rollbackRes =
          await session.restoreWorkspaceSnapshot(pushRes.previousSnapshot!);
      expect(rollbackRes.applied, isTrue);
      expect(rollbackRes.deletedFiles, ['domain/discounts/promo.quds']);
      expect(
        session.hasCompiledWorkspaceFile('domain/discounts/promo.quds'),
        isFalse,
      );
      expect(ws.bundleVersion, '1.0.0');

      final r4 = await session.runProject();
      expect(r4.succeeded, isTrue, reason: '${r4.error}');
      expect(r4.printedLines, ['Quds Store: 110.00 USD']);

      await session.dispose();
    });

    test(
        'atomic CodePush validation rejects broken patches without corrupting live workspace',
        () async {
      final ws = buildNestedProject();
      final session = QudsSession(projectWorkspace: ws);

      final beforeRev = ws.revision;
      final beforeFp = ws.workspaceFingerprint;
      final r1 = await session.runProject();
      expect(r1.succeeded, isTrue);
      expect(r1.printedLines, ['Quds Store: 110.00 USD']);

      // Patch containing a valid edit AND a syntactically broken nested file.
      final badPatch = const QudsWorkspacePatch(
        bundleVersion: '1.2.0-broken',
        upsertFiles: {
          'core/config/rates.quds': 'TAX_RATE = 0.99\nCURRENCY = "GBP"\n',
          'domain/pricing/engine.quds': 'broken(a: int -> :\n  return @@@\n',
        },
      );

      final pushRes = await session.applyWorkspacePatch(badPatch);
      expect(pushRes.applied, isFalse);
      expect(pushRes.errors, isNotEmpty);
      expect(ws.revision, beforeRev);
      expect(ws.workspaceFingerprint, beforeFp);
      expect(ws.bundleVersion, '1.0.0');

      // Live workspace remains completely healthy and unchanged!
      final r2 = await session.runProject();
      expect(r2.succeeded, isTrue, reason: '${r2.error}');
      expect(r2.printedLines, ['Quds Store: 110.00 USD']);

      await session.dispose();
    });

    test(
        'handles direct file edits, nested folder deletion, and Tier-1 accelerated external functions',
        () async {
      final ws = QudsWorkspace(
        name: 'compute_app',
        entryPoint: 'main.quds',
        files: {
          'algos/math/kernel.quds': '''
computeSum(n: int) -> int:
  var acc = 0
  var i = 1
  while i <= n:
    acc = acc + i * i
    i = i + 1
  return acc
''',
          'algos/legacy/old.quds': '''
OLD_VAL = 99
''',
          'main.quds': '''
use algos.math.kernel show computeSum
print computeSum(100)
''',
        },
      );
      final session = QudsSession(projectWorkspace: ws);

      final r1 = await session.runProject();
      expect(r1.succeeded, isTrue, reason: '${r1.error}');
      // sum_{i=1}^{100} i^2 = 338350
      expect(r1.printedLines, ['338350']);

      // Direct writeFile (without applyWorkspacePatch) still automatically
      // invalidates & recompiles the nested module on next run.
      ws.writeFile('algos/math/kernel.quds', '''
computeSum(n: int) -> int:
  var acc = 0
  var i = 1
  while i <= n:
    acc = acc + i
    i = i + 1
  return acc
''');

      final r2 = await session.runProject();
      expect(r2.succeeded, isTrue, reason: '${r2.error}');
      // sum_{i=1}^{100} i = 5050
      expect(r2.printedLines, ['5050']);
      expect(
          session.compilationStats.recompiledModules, greaterThanOrEqualTo(1));

      // Delete an entire nested folder via CodePush patch.
      final delRes = await session.applyWorkspacePatch(
        const QudsWorkspacePatch(deleteFolders: ['algos/legacy']),
      );
      expect(delRes.applied, isTrue);
      expect(delRes.deletedFiles, ['algos/legacy/old.quds']);
      expect(ws.hasFile('algos/legacy/old.quds'), isFalse);

      await session.dispose();
    });
  });
}
