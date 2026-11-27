/// Interactive Performance Benchmark & Timer Dashboard for Quds Studio.
///
/// Displays live millisecond execution timing, VM vs AST speedup comparison,
/// 3-run median benchmarking, throughput metrics, and recent run history.
library;

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

import 'presets.dart';

class BenchmarkRunRecord {
  const BenchmarkRunRecord({
    required this.elapsedMs,
    required this.steps,
    required this.usedVm,
    required this.succeeded,
    required this.outputSummary,
    this.isMedianOf3 = false,
    this.minMs,
    this.avgMs,
  });

  final double elapsedMs;
  final int steps;
  final bool usedVm;
  final bool succeeded;
  final String outputSummary;
  final bool isMedianOf3;
  final double? minMs;
  final double? avgMs;

  double get mStepsPerSec =>
      elapsedMs > 0 ? (steps / (elapsedMs * 1000.0)) : 0.0;
}

class QudsBenchmarkStageCard extends StatelessWidget {
  const QudsBenchmarkStageCard({
    super.key,
    required this.preset,
    required this.result,
    required this.history,
    required this.lastVmMs,
    required this.lastAstMs,
    required this.running,
    required this.isArabic,
    required this.isDark,
    required this.onRunVm,
    required this.onRunMedian3,
    required this.onRunAst,
  });

  final StudioPreset preset;
  final QudsRunResult? result;
  final List<BenchmarkRunRecord> history;
  final double? lastVmMs;
  final double? lastAstMs;
  final bool running;
  final bool isArabic;
  final bool isDark;
  final VoidCallback onRunVm;
  final VoidCallback onRunMedian3;
  final VoidCallback onRunAst;

  String _fmtMs(double ms) {
    if (ms >= 1000) return '${(ms / 1000.0).toStringAsFixed(2)} s';
    if (ms >= 10) return '${ms.toStringAsFixed(1)} ms';
    return '${ms.toStringAsFixed(2)} ms';
  }

  String _fmtSteps(int steps) {
    if (steps >= 1000000) return '${(steps / 1000000.0).toStringAsFixed(2)}M';
    if (steps >= 1000) return '${(steps / 1000.0).toStringAsFixed(1)}k';
    return '$steps';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = history.isNotEmpty ? history.first : null;
    final accent = latest == null
        ? const Color(0xFFF97316)
        : (latest.succeeded
            ? (latest.usedVm
                ? const Color(0xFF10B981)
                : const Color(0xFFF59E0B))
            : const Color(0xFFEF4444));
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final tileBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = accent.withValues(alpha: 0.35);

    final double? speedup =
        (lastVmMs != null && lastAstMs != null && lastVmMs! > 0)
            ? (lastAstMs! / lastVmMs!)
            : null;

    return Container(
      key: const Key('quds_benchmark_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Benchmark title + engine badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  size: 20,
                  color: Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? preset.titleAr : preset.titleEn,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      preset.subtitleAr,
                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Giant Stopwatch Timer Readout Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: isDark ? 0.18 : 0.10),
                  tileBg,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: running
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isArabic
                            ? 'جاري تنفيذ الاختبار وحساب الزمن الدقيق...'
                            : 'Running benchmark & timing...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined, size: 22, color: accent),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              key: const Key('bench_elapsed_readout'),
                              latest != null
                                  ? _fmtMs(latest.elapsedMs)
                                  : '-- ms',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          if (latest != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                latest.usedVm
                                    ? (isArabic
                                        ? '⚡ Quds Register VM'
                                        : '⚡ Register VM')
                                    : (isArabic
                                        ? '🐢 مفسّر AST'
                                        : '🐢 AST Evaluator'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (latest != null && latest.isMedianOf3) ...[
                        const SizedBox(height: 6),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            'Median of 3 runs · Best: ${_fmtMs(latest.minMs ?? latest.elapsedMs)} · Avg: ${_fmtMs(latest.avgMs ?? latest.elapsedMs)}',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              color: theme.hintColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      if (speedup != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          key: const Key('bench_speedup_badge'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            isArabic
                                ? '🚀 Register VM أسرع بـ ${speedup.toStringAsFixed(1)}× من AST (${_fmtMs(lastVmMs!)} مقابل ${_fmtMs(lastAstMs!)})'
                                : '🚀 Register VM is ${speedup.toStringAsFixed(1)}× faster than AST',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 10),

          // Action buttons: Run VM, Median of 3x, Compare AST
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                key: const Key('btn_bench_run_vm'),
                onPressed: running ? null : onRunVm,
                icon: const Icon(Icons.bolt_rounded, size: 17),
                label: Text(
                  isArabic ? 'قياس الزمن (VM)' : 'Run Timed (VM)',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              FilledButton.tonalIcon(
                key: const Key('btn_bench_run_3x'),
                onPressed: running ? null : onRunMedian3,
                icon: const Icon(Icons.av_timer_rounded, size: 17),
                label: Text(
                  isArabic ? 'وسيط 3 جولات' : '3-Run Median',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                key: const Key('btn_bench_run_ast'),
                onPressed: running ? null : onRunAst,
                icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                label: Text(
                  isArabic ? 'مقارنة مع AST' : 'Compare AST',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),

          if (latest != null) ...[
            const SizedBox(height: 12),
            // Metrics row (Steps, Throughput, Status)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip(
                  tileBg,
                  Icons.memory_rounded,
                  isArabic ? 'العمليات' : 'Steps',
                  _fmtSteps(latest.steps),
                  const Color(0xFF38BDF8),
                ),
                _metricChip(
                  tileBg,
                  Icons.rocket_launch_rounded,
                  isArabic ? 'معدل التنفيذ' : 'Throughput',
                  '${latest.mStepsPerSec.toStringAsFixed(1)}M/s',
                  const Color(0xFF8B5CF6),
                ),
                if (lastVmMs != null)
                  _metricChip(
                    tileBg,
                    Icons.bolt_rounded,
                    'VM',
                    _fmtMs(lastVmMs!),
                    const Color(0xFF10B981),
                  ),
                if (lastAstMs != null)
                  _metricChip(
                    tileBg,
                    Icons.hourglass_bottom_rounded,
                    'AST',
                    _fmtMs(lastAstMs!),
                    const Color(0xFFF59E0B),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Verified Output Console Preview
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  latest.succeeded
                      ? latest.outputSummary
                      : '${result?.error ?? latest.outputSummary}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: const ['IBMPlexSansArabic'],
                    fontSize: 11.5,
                    color: latest.succeeded
                        ? theme.textTheme.bodyMedium?.color
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
          ],

          // Recent Timed Runs Log
          if (history.length > 1) ...[
            const SizedBox(height: 10),
            Text(
              isArabic ? 'سجل القياسات الأخيرة:' : 'Recent Timed Runs:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 4),
            for (var i = 0; i < history.length && i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      history[i].usedVm
                          ? Icons.bolt_rounded
                          : Icons.hourglass_bottom_rounded,
                      size: 13,
                      color: history[i].usedVm
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      history[i].usedVm
                          ? (history[i].isMedianOf3 ? 'VM (3x)' : 'VM')
                          : 'AST',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${_fmtMs(history[i].elapsedMs)} · ${_fmtSteps(history[i].steps)} ops',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _metricChip(
    Color bg,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
