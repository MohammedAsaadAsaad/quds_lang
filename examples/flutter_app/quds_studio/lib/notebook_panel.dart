/// Interactive Reactive Notebook UI panel powered by `QudsNotebook`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds/interpreter.dart';

import 'viz_widgets.dart';

class QudsNotebookPanel extends StatefulWidget {
  const QudsNotebookPanel({
    super.key,
    required this.isArabic,
    required this.isDark,
  });

  final bool isArabic;
  final bool isDark;

  @override
  State<QudsNotebookPanel> createState() => _QudsNotebookPanelState();
}

class _QudsNotebookPanelState extends State<QudsNotebookPanel> {
  late QudsNotebook _notebook;
  final Map<String, TextEditingController> _controllers = {};
  bool _running = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _notebook = QudsNotebook(title: 'دفتر قدس التفاعلي / Quds Reactive Lab');
    _notebook.addCell(
      QudsNotebookCellKind.markdown,
      'عدّل السرعة الابتدائية v0 في الخلية 1 واضغط تشغيل — ستُعاد الخلايا المرتبطة تلقائياً عبر رسم الاعتمادية!',
      id: 'intro',
    );
    _notebook.addCell(
      QudsNotebookCellKind.code,
      'v0 = 24.0\nangle = 0.785\ng = 9.81',
      id: 'params',
    );
    _notebook.addCell(
      QudsNotebookCellKind.code,
      'use dart:math as m\nvx = v0 * m.cos(angle)\nvy = v0 * m.sin(angle)\nflight = 2.0 * vy / g\nrangeX = vx * flight\nprint "المدى = {rangeX.toStringAsFixed(2)} م | زمن التحليق = {flight.toStringAsFixed(2)} ث"',
      id: 'physics',
    );
    _notebook.addCell(
      QudsNotebookCellKind.code,
      'use quds:viz as viz\nvar xs: List<double> = []\nvar ys: List<double> = []\nfor i in 0..20:\n  t = flight * i / 20.0\n  xs.add(vx * t)\n  ys.add(vy * t - 0.5 * g * t * t)\nviz.plot(xs, ys, title: "مسار المقذوف", xLabel: "x (m)", yLabel: "y (m)", color: "#10B981")',
      id: 'chart',
    );
    for (final c in _notebook.cells) {
      _controllers[c.id] = TextEditingController(text: c.source);
    }
    _runAll();
  }

  Future<void> _runAll() async {
    setState(() => _running = true);
    for (final c in _notebook.cells) {
      final ctrl = _controllers[c.id];
      if (ctrl != null) _notebook.updateCell(c.id, ctrl.text);
    }
    final summary = await _notebook.runAll();
    if (!mounted) return;
    setState(() {
      _running = false;
      _statusMessage = summary.hasCycle
          ? (widget.isArabic
              ? 'تم اكتشاف دورة اعتمادية بين الخلايا!'
              : 'Cycle detected between cells!')
          : (widget.isArabic
              ? 'تم تشغيل ${summary.executedCellIds.length} خلية تلقائياً'
              : 'Executed ${summary.executedCellIds.length} cells reactively');
    });
  }

  Future<void> _runCell(String id) async {
    setState(() => _running = true);
    final ctrl = _controllers[id];
    if (ctrl != null) _notebook.updateCell(id, ctrl.text);
    final summary = await _notebook.runCell(id, reactive: true);
    if (!mounted) return;
    setState(() {
      _running = false;
      _statusMessage = summary.hasCycle
          ? (widget.isArabic ? 'دورة اعتمادية!' : 'Dependency cycle!')
          : (widget.isArabic
              ? 'تحديث تفاعلي لـ ${summary.executedCellIds.length} خلية (${summary.executedCellIds.join(' → ')})'
              : 'Cascaded ${summary.executedCellIds.length} cells (${summary.executedCellIds.join(' -> ')})');
    });
  }

  void _addCodeCell() {
    final cell = _notebook.addCell(
      QudsNotebookCellKind.code,
      'print "Range = {rangeX.toStringAsFixed(1)}m"',
    );
    _controllers[cell.id] = TextEditingController(text: cell.source);
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _notebook.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);
    final fg = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    return Column(
      key: const Key('quds_notebook_panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Notebook toolbar
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('btn_notebook_run_all'),
              onPressed: _running ? null : _runAll,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(
                widget.isArabic ? 'تشغيل الكل' : 'Run All',
                style: const TextStyle(fontSize: 12),
              ),
              style:
                  FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            OutlinedButton.icon(
              key: const Key('btn_notebook_add_cell'),
              onPressed: _addCodeCell,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(
                widget.isArabic ? 'خلية كود' : 'Add Cell',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
            TextButton.icon(
              onPressed: () {
                final html = _notebook.exportHtml();
                Clipboard.setData(ClipboardData(text: html));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.isArabic
                          ? 'تم نسخ تقرير HTML التفاعلي (${html.length} حرف)'
                          : 'Copied standalone HTML report (${html.length} chars)',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.html_rounded, size: 17),
              label: Text(
                widget.isArabic ? 'تصدير HTML' : 'Export HTML',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
            if (_statusMessage != null)
              Text(
                _statusMessage!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _notebook.cells.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final cell = _notebook.cells[idx];
              final ctrl = _controllers[cell.id]!;
              final deps = _notebook.dependenciesOf(cell.id);
              final dependents = _notebook.dependentsOf(cell.id);
              final res = cell.lastResult;

              return Container(
                key: Key('nb_cell_${cell.id}'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cell.dirty
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                        : border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cell.kind == QudsNotebookCellKind.markdown
                                ? const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.18)
                                : const Color(0xFF2563EB)
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${cell.id} · ${cell.kind == QudsNotebookCellKind.markdown ? 'MD' : 'QUDS'}',
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (deps.isNotEmpty)
                          Flexible(
                            child: Text(
                              '← ${deps.join(', ')}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (dependents.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '→ ${dependents.join(', ')}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF38BDF8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (cell.kind == QudsNotebookCellKind.code)
                          IconButton(
                            key: Key('btn_run_cell_${cell.id}'),
                            onPressed:
                                _running ? null : () => _runCell(cell.id),
                            icon: const Icon(Icons.play_circle_fill_rounded,
                                size: 20, color: Color(0xFF10B981)),
                            visualDensity: VisualDensity.compact,
                            tooltip: widget.isArabic
                                ? 'تشغيل وتحديث الخلايا المرتبطة'
                                : 'Run & cascade',
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (cell.kind == QudsNotebookCellKind.markdown)
                      Text(
                        cell.source,
                        style: TextStyle(fontSize: 12.5, color: fg),
                      )
                    else
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: ctrl,
                          maxLines: null,
                          onChanged: (v) =>
                              setState(() => _notebook.updateCell(cell.id, v)),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: const ['IBMPlexSansArabic'],
                            fontSize: 12,
                            color: fg,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF020617)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: border),
                            ),
                            contentPadding: const EdgeInsets.all(8),
                          ),
                        ),
                      ),
                    if (res != null &&
                        (res.printedLines.isNotEmpty ||
                            res.outputs.isNotEmpty ||
                            !res.succeeded)) ...[
                      const SizedBox(height: 8),
                      if (res.printedLines.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0B1120)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            res.stdout,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: const ['IBMPlexSansArabic'],
                              fontSize: 11.5,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      if (res.lastPlot != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 170,
                          child: QudsPlotCanvas(
                            plot: res.lastPlot!,
                            isDark: isDark,
                          ),
                        ),
                      ],
                      if (!res.succeeded && res.error != null)
                        Text(
                          '${res.error}',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
