import 'dart:convert';

import 'package:quds/interpreter.dart';
import 'package:test/test.dart';

void main() {
  group('Package 2 — General-Purpose Reactive Notebook Engine (QudsNotebook)',
      () {
    test(
        'dependency graph auto-recomputes downstream cells on upstream edit, detects cycles, and exports .qnb/Markdown/HTML',
        () async {
      final nb = QudsNotebook(title: 'Physics & Geometry Lab');
      nb.addCell(QudsNotebookCellKind.markdown, '## Projectile Motion Lab',
          id: 'intro');
      final c1 = nb.addCell(
        QudsNotebookCellKind.code,
        'v0 = 20.0\ng = 9.81\n',
        id: 'params',
      );
      final c2 = nb.addCell(
        QudsNotebookCellKind.code,
        'flightTime = 2.0 * v0 / g\nprint "T={flightTime.toStringAsFixed(2)}"\n',
        id: 'calc',
      );
      final c3 = nb.addCell(
        QudsNotebookCellKind.code,
        '''
use quds:viz as viz
xs = [0.0, flightTime * 0.5, flightTime]
ys = [0.0, (v0 * v0) / (2.0 * g), 0.0]
viz.plot(xs, ys, title: "Trajectory")
print "peak={ys[1].toStringAsFixed(2)}"
''',
        id: 'plot',
      );

      // Dependency graph verification
      expect(nb.dependentsOf(c1.id), containsAll([c2.id, c3.id]));
      expect(nb.dependenciesOf(c3.id), containsAll([c1.id, c2.id]));

      // Run all in topological order
      final full = await nb.runAll();
      expect(full.allSucceeded, isTrue);
      expect(full.executedCellIds, ['params', 'calc', 'plot']);
      expect(c2.lastResult!.stdout, contains('T=4.08'));
      expect(c3.lastResult!.lastPlot, isNotNull);

      // Reactive edit: change v0 in cell 1 -> cell 2 and cell 3 automatically re-run!
      nb.updateCell(c1.id, 'v0 = 40.0\ng = 9.81\n');
      expect(c2.dirty, isTrue);
      expect(c3.dirty, isTrue);

      final cascade = await nb.runCell(c1.id);
      expect(cascade.allSucceeded, isTrue);
      expect(cascade.executedCellIds, ['params', 'calc', 'plot']);
      expect(c2.lastResult!.stdout, contains('T=8.15'));
      expect(c3.lastResult!.stdout, contains('peak=81.55'));

      // Portable .qnb JSON round-trip
      final rawJson = nb.toJsonString();
      final decoded = jsonDecode(rawJson) as Map<String, Object?>;
      final restored = QudsNotebook.fromJson(decoded);
      expect(restored.title, 'Physics & Geometry Lab');
      expect(restored.cells.length, 4);

      // Markdown & standalone HTML report with embedded SVG
      final md = nb.exportMarkdown();
      expect(md, contains('# Physics & Geometry Lab'));
      expect(md, contains('T=8.15'));
      final html = nb.exportHtml();
      expect(html, contains('<svg'));
      expect(html, contains('Trajectory'));

      // Cycle detection between cells
      final cycNb = QudsNotebook(title: 'Cycle Test');
      cycNb.addCell(QudsNotebookCellKind.code, 'a = b + 1', id: 'cA');
      cycNb.addCell(QudsNotebookCellKind.code, 'b = a + 1', id: 'cB');
      final cycRes = await cycNb.runAll();
      expect(cycRes.hasCycle, isTrue);
      expect(cycRes.cycleCellIds, containsAll(['cA', 'cB']));

      await nb.dispose();
      await restored.dispose();
      await cycNb.dispose();
    });
  });
}
