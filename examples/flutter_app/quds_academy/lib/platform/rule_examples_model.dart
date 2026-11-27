/// Live Interactive Multi-Example Runner for Quds Academy.
///
/// Renders rich, categorized executable Quds examples for every language rule,
/// keyword, and lesson — executing code live via `QudsSession` (`package:quds/interpreter.dart`)
/// and showing exact interpreter stdout, return value, execution time, and
/// one-tap "Open in Playground" / "Run All" actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds/editor_engine.dart';
import 'package:quds/interpreter.dart';

class AcademyRuleExample {
  const AcademyRuleExample({
    required this.titleAr,
    required this.titleEn,
    required this.noteAr,
    required this.noteEn,
    required this.code,
  });

  final String titleAr;
  final String titleEn;
  final String noteAr;
  final String noteEn;
  final String code;
}

class _RunState {
  const _RunState({
    required this.succeeded,
    required this.output,
    required this.elapsedMs,
    required this.usedVm,
  });

  final bool succeeded;
  final String output;
  final double elapsedMs;
  final bool usedVm;
}

/// Runs a self-contained Quds example through the live Quds interpreter and
/// returns its formatted stdout / return value.
Future<QudsRunResult> runAcademyExampleCode(
  String code, {
  String file = 'example.quds',
}) async {
  final session = QudsSession(
    policy: QudsExecutionPolicy.standard(
      maxSteps: 100000,
      timeout: const Duration(seconds: 4),
    ),
    allowTopLevelRebind: true,
  );
  try {
    return await session.run(code, file: file);
  } finally {
    await session.dispose();
  }
}

/// Displays a rich interactive collection of runnable examples for a Quds rule
/// or lesson, with live interpreter execution per example and a "Run All" button.
class AcademyRuleExamplesSection extends StatefulWidget {
  const AcademyRuleExamplesSection({
    super.key,
    required this.scopeKey,
    required this.examples,
    required this.arabic,
    required this.dark,
    required this.onOpenPlayground,
    this.headingAr,
    this.headingEn,
  });

  final String scopeKey;
  final List<AcademyRuleExample> examples;
  final bool arabic;
  final bool dark;
  final void Function(String code) onOpenPlayground;
  final String? headingAr;
  final String? headingEn;

  @override
  State<AcademyRuleExamplesSection> createState() =>
      _AcademyRuleExamplesSectionState();
}

class _AcademyRuleExamplesSectionState
    extends State<AcademyRuleExamplesSection> {
  final QudsEditorEngine _engine = QudsEditorEngine();
  final Map<int, _RunState> _results = {};
  final Set<int> _runningIdx = {};
  bool _runningAll = false;

  @override
  void didUpdateWidget(covariant AcademyRuleExamplesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scopeKey != widget.scopeKey) {
      _results.clear();
      _runningIdx.clear();
      _runningAll = false;
    }
  }

  Future<void> _runOne(int index) async {
    if (_runningIdx.contains(index)) return;
    final currentScope = widget.scopeKey;
    final example = widget.examples[index];
    setState(() => _runningIdx.add(index));
    final res = await runAcademyExampleCode(
      example.code,
      file: '${currentScope}_${index + 1}.quds',
    );
    if (!mounted || widget.scopeKey != currentScope) return;
    final text = _formatResult(res);
    setState(() {
      _runningIdx.remove(index);
      _results[index] = _RunState(
        succeeded: res.succeeded,
        output: text,
        elapsedMs: res.elapsed.inMicroseconds / 1000.0,
        usedVm: res.usedBytecodeVm,
      );
    });
  }

  Future<void> _runAll() async {
    if (_runningAll) return;
    final currentScope = widget.scopeKey;
    setState(() => _runningAll = true);
    for (var i = 0; i < widget.examples.length; i++) {
      if (!mounted || widget.scopeKey != currentScope) break;
      await _runOne(i);
    }
    if (mounted && widget.scopeKey == currentScope) {
      setState(() => _runningAll = false);
    }
  }

  String _formatResult(QudsRunResult res) {
    if (!res.succeeded) {
      return '${res.error}';
    }
    final out = res.stdout.trim();
    if (out.isNotEmpty) return out;
    if (res.value != null) return '=> ${qudsFormatValue(res.value)}';
    return widget.arabic ? 'تم التنفيذ بنجاح ✓' : 'Executed successfully ✓';
  }

  TextSpan _highlightCode(String source) {
    final palette = QudsEditorThemePalette.dark();
    final spans = _engine.highlight(source);
    final baseStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: const ['Cairo'],
      fontSize: 12.0,
      height: 1.85,
      color: Color(palette.foreground),
    );
    final children = <TextSpan>[];
    var cursor = 0;
    for (final s in spans) {
      if (s.startOffset > cursor) {
        children.add(
          TextSpan(
            text: source.substring(cursor, s.startOffset),
            style: baseStyle,
          ),
        );
      }
      final start = s.startOffset.clamp(cursor, source.length);
      final end = s.endOffset.clamp(start, source.length);
      if (end > start) {
        children.add(
          TextSpan(
            text: source.substring(start, end),
            style: baseStyle.copyWith(
              color: Color(palette.colorFor(s.category)),
              fontWeight:
                  s.category == QudsTokenCategory.controlKeyword ||
                      s.category == QudsTokenCategory.declarationKeyword
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
          ),
        );
        cursor = end;
      }
    }
    if (cursor < source.length) {
      children.add(TextSpan(text: source.substring(cursor), style: baseStyle));
    }
    return TextSpan(style: baseStyle, children: children);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.examples.isEmpty) return const SizedBox.shrink();
    final ar = widget.arabic;
    final dark = widget.dark;
    const brand = Color(0xFF147D64);
    const night = Color(0xFF102C29);
    final ink = dark ? const Color(0xFFEAF4EF) : const Color(0xFF182D29);
    final muted = dark ? const Color(0xFFA4BBB1) : const Color(0xFF6B7B74);
    final surface = dark ? const Color(0xFF162B27) : Colors.white;
    final border = dark ? const Color(0xFF2D443C) : const Color(0xFFE2EAE4);

    final heading = ar
        ? (widget.headingAr ??
              'أمثلة كاملة جاهزة للتشغيل بالمفسّر (${widget.examples.length})')
        : (widget.headingEn ??
              'Complete Runnable Examples (${widget.examples.length})');

    return SelectionArea(
      child: Column(
        key: Key('rule_examples_section_${widget.scopeKey}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_lesson_rounded, color: brand, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      heading,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                key: Key('btn_run_all_examples_${widget.scopeKey}'),
                onPressed: _runningAll ? null : _runAll,
                icon: _runningAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.playlist_play_rounded, size: 18),
                label: Text(
                  ar ? 'شغّل كل الأمثلة' : 'Run all examples',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ar
                ? 'كل مثال هنا مكتمل بجميع تعريفاته واستيراداته وجاهز للتشغيل الفوري أو التعديل في المختبر.'
                : 'Every example below is 100% self-contained with all declarations — run live here or open in Playground.',
            style: TextStyle(fontSize: 12.5, height: 1.7, color: muted),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < widget.examples.length; i++)
            _buildExampleCard(
              index: i,
              example: widget.examples[i],
              ar: ar,
              brand: brand,
              night: night,
              ink: ink,
              muted: muted,
              surface: surface,
              border: border,
            ),
        ],
      ),
    );
  }

  Widget _buildExampleCard({
    required int index,
    required AcademyRuleExample example,
    required bool ar,
    required Color brand,
    required Color night,
    required Color ink,
    required Color muted,
    required Color surface,
    required Color border,
  }) {
    final isRunning = _runningIdx.contains(index);
    final res = _results[index];

    return Container(
      key: Key('rule_example_card_${widget.scopeKey}_$index'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: res != null
              ? (res.succeeded
                    ? brand.withValues(alpha: 0.45)
                    : Colors.redAccent)
              : border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: brand,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ar ? example.titleAr : example.titleEn,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ar ? example.noteAr : example.noteEn,
            style: TextStyle(fontSize: 12, height: 1.6, color: muted),
          ),
          const SizedBox(height: 10),
          // Syntax-highlighted code box (uses Text.rich inside SelectionArea)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: night,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text.rich(_highlightCode(example.code)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Action row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              IconButton(
                tooltip: ar ? 'نسخ الكود' : 'Copy code',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: example.code)),
                icon: Icon(Icons.copy_rounded, size: 17, color: muted),
                visualDensity: VisualDensity.compact,
              ),
              OutlinedButton.icon(
                key: Key('btn_open_example_${widget.scopeKey}_$index'),
                onPressed: () => widget.onOpenPlayground(example.code),
                icon: const Icon(Icons.terminal_rounded, size: 15),
                label: Text(
                  ar ? 'افتح في المختبر' : 'Open in Playground',
                  style: const TextStyle(fontSize: 11.5),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
              FilledButton.icon(
                key: Key('btn_run_example_${widget.scopeKey}_$index'),
                onPressed: isRunning ? null : () => _runOne(index),
                icon: isRunning
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.play_arrow_rounded, size: 17),
                label: Text(
                  ar ? 'شغّل بالمفسّر' : 'Run live',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
          // Live Interpreter Output Panel
          if (res != null) ...[
            const SizedBox(height: 10),
            Container(
              key: Key('rule_example_output_${widget.scopeKey}_$index'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: res.succeeded
                    ? brand.withValues(alpha: 0.08)
                    : const Color(0xFFEF4444).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: res.succeeded
                      ? brand.withValues(alpha: 0.35)
                      : const Color(0xFFEF4444).withValues(alpha: 0.4),
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          res.succeeded
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          size: 14,
                          color: res.succeeded
                              ? brand
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ar ? 'ناتج المفسّر الحي' : 'LIVE INTERPRETER OUTPUT',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: res.succeeded
                                ? brand
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${res.elapsedMs.toStringAsFixed(1)} ms',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      res.output,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontFamilyFallback: const ['Cairo'],
                        fontSize: 12.5,
                        height: 1.65,
                        color: res.succeeded ? ink : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
