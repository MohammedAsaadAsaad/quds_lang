/// Interactive 3-Mode Execution Lab (AST vs Cold Bytecode vs Precompiled .qbc)
/// and Compiled Bytecode Artifact Inspector for Quds Studio.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds/interpreter.dart';

/// Execution modes supported by the Multi-Folder Compilation Lab.
enum WorkspaceRunMode {
  ast,
  coldBytecode,
  compiledCached,
}

/// Snapshot of comparative timings & checksums across all 3 execution modes.
class WorkspaceBenchComparison {
  const WorkspaceBenchComparison({
    this.astMs,
    this.coldBytecodeMs,
    this.compiledCachedMs,
    this.precompileMs,
    this.astChecksum,
    this.coldChecksum,
    this.compiledChecksum,
    this.lastMode,
    this.lastPatchSummary,
    this.error,
  });

  final double? astMs;
  final double? coldBytecodeMs;
  final double? compiledCachedMs;
  final double? precompileMs;
  final String? astChecksum;
  final String? coldChecksum;
  final String? compiledChecksum;
  final WorkspaceRunMode? lastMode;
  final String? lastPatchSummary;
  final String? error;

  bool get hasAnyResult =>
      astMs != null || coldBytecodeMs != null || compiledCachedMs != null;

  bool get checksumsMatch {
    final values = [
      if (astChecksum != null) astChecksum!,
      if (coldChecksum != null) coldChecksum!,
      if (compiledChecksum != null) compiledChecksum!,
    ];
    if (values.length < 2) return true;
    return values.every((v) => v == values.first);
  }

  WorkspaceBenchComparison copyWith({
    double? astMs,
    double? coldBytecodeMs,
    double? compiledCachedMs,
    double? precompileMs,
    String? astChecksum,
    String? coldChecksum,
    String? compiledChecksum,
    WorkspaceRunMode? lastMode,
    String? lastPatchSummary,
    String? error,
    bool clearError = false,
  }) {
    return WorkspaceBenchComparison(
      astMs: astMs ?? this.astMs,
      coldBytecodeMs: coldBytecodeMs ?? this.coldBytecodeMs,
      compiledCachedMs: compiledCachedMs ?? this.compiledCachedMs,
      precompileMs: precompileMs ?? this.precompileMs,
      astChecksum: astChecksum ?? this.astChecksum,
      coldChecksum: coldChecksum ?? this.coldChecksum,
      compiledChecksum: compiledChecksum ?? this.compiledChecksum,
      lastMode: lastMode ?? this.lastMode,
      lastPatchSummary: lastPatchSummary ?? this.lastPatchSummary,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

String formatLabDurationMs(double ms) {
  if (ms >= 1000) return '${(ms / 1000.0).toStringAsFixed(2)} s';
  if (ms >= 10) return '${ms.toStringAsFixed(1)} ms';
  if (ms >= 1) return '${ms.toStringAsFixed(2)} ms';
  return '${(ms * 1000.0).toStringAsFixed(0)} µs';
}

String formatByteSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024.0).toStringAsFixed(1)} KB';
  return '$bytes B';
}

/// Interactive card letting users run the active multi-folder workspace in:
/// 1) Raw AST Mode (`preferBytecode: false`),
/// 2) Cold Bytecode Mode (`preferBytecode: true`, fresh compile),
/// 3) Precompiled / Cached `.qbc` Mode (`precompileWorkspace` + cached run),
/// or run all 3 back-to-back with a visual comparison & live file-change test.
class QudsWorkspaceCompileLabCard extends StatelessWidget {
  const QudsWorkspaceCompileLabCard({
    super.key,
    required this.isArabic,
    required this.isDark,
    required this.running,
    required this.runningLabel,
    required this.stats,
    required this.compiledCount,
    required this.totalQudsFiles,
    required this.comparison,
    required this.onRunMode,
    required this.onCompareAll3,
    required this.onPrecompileAll,
    required this.onQuickCodePushEdit,
  });

  final bool isArabic;
  final bool isDark;
  final bool running;
  final String? runningLabel;
  final QudsCompilationStats stats;
  final int compiledCount;
  final int totalQudsFiles;
  final WorkspaceBenchComparison comparison;
  final ValueChanged<WorkspaceRunMode> onRunMode;
  final VoidCallback onCompareAll3;
  final VoidCallback onPrecompileAll;
  final VoidCallback onQuickCodePushEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final tileBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final maxMs = [
      comparison.astMs ?? 0.0,
      comparison.coldBytecodeMs ?? 0.0,
      comparison.compiledCachedMs ?? 0.0,
    ].fold<double>(0.001, (a, b) => a > b ? a : b);

    return Container(
      key: const Key('workspace_compile_lab_card'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFF97316).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  size: 16, color: Color(0xFFF97316)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  isArabic
                      ? 'مختبر التنفيذ (AST · Bytecode · بعد الترجمة)'
                      : 'Execution Lab (AST · Bytecode · Compiled)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (compiledCount >= totalQudsFiles && totalQudsFiles > 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFF38BDF8))
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isArabic
                      ? 'مترجم $compiledCount/$totalQudsFiles'
                      : 'Compiled $compiledCount/$totalQudsFiles',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: compiledCount >= totalQudsFiles && totalQudsFiles > 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Action buttons (4 crisp pills that wrap cleanly on mobile)
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _ModeButton(
                key: const Key('lab_run_ast_btn'),
                label: isArabic ? '🐢 بـ AST' : '🐢 AST',
                color: const Color(0xFFF59E0B),
                enabled: !running,
                onTap: () => onRunMode(WorkspaceRunMode.ast),
              ),
              _ModeButton(
                key: const Key('lab_run_bytecode_btn'),
                label: isArabic ? '⚡ بـ Bytecode' : '⚡ Bytecode',
                color: const Color(0xFF38BDF8),
                enabled: !running,
                onTap: () => onRunMode(WorkspaceRunMode.coldBytecode),
              ),
              _ModeButton(
                key: const Key('lab_run_compiled_btn'),
                label: isArabic ? '🚀 بعد الترجمة' : '🚀 Compiled',
                color: const Color(0xFF10B981),
                enabled: !running,
                onTap: () => onRunMode(WorkspaceRunMode.compiledCached),
              ),
              _ModeButton(
                key: const Key('lab_compare_all3_btn'),
                label: isArabic ? '🏁 مقارنة الـ 3' : '🏁 Compare 3',
                color: const Color(0xFFF97316),
                filled: true,
                enabled: !running,
                onTap: onCompareAll3,
              ),
              _ModeButton(
                key: const Key('lab_precompile_btn'),
                label: isArabic ? '📦 ترجمة الملفات' : '📦 Compile All',
                color: const Color(0xFF8B5CF6),
                enabled: !running,
                onTap: onPrecompileAll,
              ),
              _ModeButton(
                key: const Key('lab_codepush_edit_btn'),
                label: isArabic ? '🧪 تعديل حي' : '🧪 Live Edit',
                color: const Color(0xFFEC4899),
                enabled: !running,
                onTap: onQuickCodePushEdit,
              ),
            ],
          ),

          if (running) ...[
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFF97316),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      runningLabel ??
                          (isArabic
                              ? 'جاري التنفيذ وقياس الزمن...'
                              : 'Running & timing...'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF97316),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (comparison.error != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                comparison.error!,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFFEF4444),
                  fontFamily: 'JetBrainsMono',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // Visual 3-mode comparison bars
          if (comparison.hasAnyResult) ...[
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (comparison.astMs != null)
                    _TimingBarRow(
                      label: isArabic ? '🐢 مفسّر AST' : '🐢 AST',
                      ms: comparison.astMs!,
                      maxMs: maxMs,
                      color: const Color(0xFFF59E0B),
                      badge: isArabic ? 'الأساس' : 'baseline',
                    ),
                  if (comparison.coldBytecodeMs != null)
                    _TimingBarRow(
                      label: isArabic
                          ? '⚡ Bytecode (أول ترجمة)'
                          : '⚡ Bytecode (Cold)',
                      ms: comparison.coldBytecodeMs!,
                      maxMs: maxMs,
                      color: const Color(0xFF38BDF8),
                      badge: comparison.astMs != null &&
                              comparison.coldBytecodeMs! > 0
                          ? '${(comparison.astMs! / comparison.coldBytecodeMs!).toStringAsFixed(1)}×'
                          : null,
                    ),
                  if (comparison.compiledCachedMs != null)
                    _TimingBarRow(
                      label: isArabic
                          ? '🚀 بعد الترجمة (.qbc)'
                          : '🚀 Compiled (.qbc)',
                      ms: comparison.compiledCachedMs!,
                      maxMs: maxMs,
                      color: const Color(0xFF10B981),
                      badge: comparison.astMs != null &&
                              comparison.compiledCachedMs! > 0
                          ? '${(comparison.astMs! / comparison.compiledCachedMs!).toStringAsFixed(1)}×'
                          : null,
                    ),
                  if (comparison.precompileMs != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      isArabic
                          ? 'زمن ترجمة المشروع مسبقًا: ${formatLabDurationMs(comparison.precompileMs!)}'
                          : 'Precompile all files: ${formatLabDurationMs(comparison.precompileMs!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.hintColor,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ],
                  if (comparison.astChecksum != null &&
                      (comparison.coldChecksum != null ||
                          comparison.compiledChecksum != null)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          comparison.checksumsMatch
                              ? Icons.verified_rounded
                              : Icons.error_outline_rounded,
                          size: 13,
                          color: comparison.checksumsMatch
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            comparison.checksumsMatch
                                ? (isArabic
                                    ? 'تطابق 100% في النواتج (Checksum) عبر جميع الأوضاع'
                                    : '100% identical checksums across all modes')
                                : (isArabic
                                    ? 'تحذير: اختلاف في النواتج!'
                                    : 'Warning: checksum mismatch!'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: comparison.checksumsMatch
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Telemetry & Live CodePush status strip
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _MiniStatChip(
                label: isArabic
                    ? 'تُرجمت: ${stats.compiledModules}'
                    : 'Compiled: ${stats.compiledModules}',
                color: const Color(0xFF38BDF8),
              ),
              _MiniStatChip(
                label: isArabic
                    ? 'أُعيدت: ${stats.recompiledModules}'
                    : 'Recompiled: ${stats.recompiledModules}',
                color: const Color(0xFFF59E0B),
              ),
              _MiniStatChip(
                label: isArabic
                    ? 'كاش .qbc: ${stats.bytecodeCacheHits}'
                    : '.qbc hits: ${stats.bytecodeCacheHits}',
                color: const Color(0xFF10B981),
              ),
              _MiniStatChip(
                label: isArabic
                    ? 'كاش تشغيل: ${stats.runtimeCacheHits}'
                    : 'Runtime hits: ${stats.runtimeCacheHits}',
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),
          if (comparison.lastPatchSummary != null) ...[
            const SizedBox(height: 4),
            Text(
              comparison.lastPatchSummary!,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFFEC4899),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(7),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: filled ? color : color.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimingBarRow extends StatelessWidget {
  const _TimingBarRow({
    required this.label,
    required this.ms,
    required this.maxMs,
    required this.color,
    this.badge,
  });

  final String label;
  final double ms;
  final double maxMs;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final frac = (ms / maxMs).clamp(0.03, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  formatLabDurationMs(ms),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2.5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Rich modal inspector for a compiled `.qbc` bytecode artifact, showing its
/// fingerprint, size, compile latency, Tier-1 promoted functions, fused
/// superinstructions, and live register-bytecode disassembly.
class QudsCompiledArtifactDialog extends StatefulWidget {
  const QudsCompiledArtifactDialog({
    super.key,
    required this.artifact,
    required this.isArabic,
    required this.isDark,
  });

  final QudsCompiledArtifactInfo artifact;
  final bool isArabic;
  final bool isDark;

  @override
  State<QudsCompiledArtifactDialog> createState() =>
      _QudsCompiledArtifactDialogState();
}

class _QudsCompiledArtifactDialogState
    extends State<QudsCompiledArtifactDialog> {
  late bool _showTier1;

  @override
  void initState() {
    super.initState();
    _showTier1 = widget.artifact.tier1Disassembly != null;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.artifact;
    final theme = Theme.of(context);
    final disassembly = _showTier1 && a.tier1Disassembly != null
        ? a.tier1Disassembly!
        : a.universalDisassembly;

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: AlertDialog(
        key: const Key('compiled_artifact_dialog'),
        titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        title: Row(
          children: [
            Icon(
              a.tier1Promoted ? Icons.bolt_rounded : Icons.memory_rounded,
              size: 18,
              color: a.tier1Promoted
                  ? const Color(0xFF10B981)
                  : const Color(0xFF38BDF8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      a.compiledPath,
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    widget.isArabic
                        ? 'المصدر: ${a.sourcePath}'
                        : 'Source: ${a.sourcePath}',
                    style: TextStyle(fontSize: 10.5, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: (a.isUpToDate
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B))
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                a.isUpToDate
                    ? (widget.isArabic ? '✓ محدّث' : '✓ Fresh')
                    : (widget.isArabic ? '⚠ قديم' : '⚠ Stale'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: a.isUpToDate
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Metadata grid
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _DetailPill(
                      title: widget.isArabic ? 'حجم المصدر' : 'Source',
                      value: formatByteSize(a.sourceBytes),
                      color: const Color(0xFF64748B),
                    ),
                    _DetailPill(
                      title: widget.isArabic ? 'حجم البايت كود' : 'Bytecode',
                      value: formatByteSize(a.estimatedBytecodeBytes),
                      color: const Color(0xFF38BDF8),
                    ),
                    _DetailPill(
                      title: widget.isArabic ? 'زمن الترجمة' : 'Compile Time',
                      value: formatLabDurationMs(a.compileTimeMicros / 1000.0),
                      color: const Color(0xFF10B981),
                    ),
                    _DetailPill(
                      title: widget.isArabic ? 'بصمة المحتوى' : 'Fingerprint',
                      value: a.fingerprint.length > 12
                          ? a.fingerprint.substring(0, 12)
                          : a.fingerprint,
                      color: const Color(0xFF8B5CF6),
                    ),
                    _DetailPill(
                      title: 'Universal Ops',
                      value:
                          '${a.universalInstructionCount} ops · ${a.universalRegisterCount} regs · ${a.universalConstantCount} consts',
                      color: const Color(0xFF0EA5E9),
                    ),
                    _DetailPill(
                      title: widget.isArabic ? 'مستوى التنفيذ' : 'VM Tier',
                      value: a.tier1Promoted
                          ? 'Tier-1 Register VM (${a.tier1InstructionCount} ops)'
                          : 'Tier-2 Universal VM',
                      color: a.tier1Promoted
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ],
                ),

                if (a.tier1Functions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.isArabic
                        ? '⚡ الدوال المرقّاة إلى Tier-1 Unboxed Register VM:'
                        : '⚡ Functions promoted to Tier-1 Unboxed Register VM:',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      for (final fn in a.tier1Functions)
                        _MiniStatChip(
                          label: '$fn()',
                          color: const Color(0xFF10B981),
                        ),
                    ],
                  ),
                ],

                if (a.tier1Superinstructions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.isArabic
                        ? '🔥 التعليمات الفائقة المدمجة (Fused Superinstructions):'
                        : '🔥 Fused Superinstructions:',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF97316),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final op in a.tier1Superinstructions)
                        _MiniStatChip(
                          label: op,
                          color: const Color(0xFFF97316),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  children: [
                    if (a.tier1Disassembly != null)
                      ChoiceChip(
                        label: const Text('Tier-1 Bytecode',
                            style: TextStyle(fontSize: 10.5)),
                        selected: _showTier1,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _showTier1 = true),
                      ),
                    if (a.tier1Disassembly != null) const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('Universal Bytecode',
                          style: TextStyle(fontSize: 10.5)),
                      selected: !_showTier1,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _showTier1 = false),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: widget.isArabic ? 'نسخ التفكيك' : 'Copy',
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: disassembly));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 1),
                            content: Text(widget.isArabic
                                ? 'تم نسخ كود البايت كود'
                                : 'Bytecode copied'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 230),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF020617)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        disassembly,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10.5,
                          color: Color(0xFFE2E8F0),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.isArabic ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 9.5,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
