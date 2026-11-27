/// Reusable Flutter Quds Code Editor widget backed by `package:quds/editor_engine.dart`.
///
/// Features real-time syntax & semantic highlighting, clickable red breakpoint
/// gutter, paused-line highlight, error squiggles + one-click Quick Fixes,
/// context-aware autocomplete, signature help, and smart indentation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds/editor_engine.dart';

/// Custom [TextEditingController] rendering live Quds syntax & semantic spans
/// plus red wavy underlines on diagnostics from [QudsEditorEngine].
class QudsSyntaxTextController extends TextEditingController {
  QudsSyntaxTextController({
    super.text,
    required this.engine,
    required this.palette,
  });

  final QudsEditorEngine engine;
  QudsEditorThemePalette palette;
  List<QudsEditorDiagnostic> diagnostics = const [];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final source = text;
    final baseStyle = (style ?? const TextStyle()).copyWith(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      color: Color(palette.foreground),
    );
    if (source.isEmpty) {
      return TextSpan(style: baseStyle, text: '');
    }

    final spans = engine.highlight(source);
    final errorRanges = <(int, int)>[
      for (final d in diagnostics)
        if (d.severity == QudsDiagnosticSeverity.error)
          (d.startOffset, d.endOffset),
    ];

    bool inError(int start, int end) =>
        errorRanges.any((r) => start < r.$2 && end > r.$1);

    final children = <TextSpan>[];
    var cursor = 0;

    for (final s in spans) {
      if (s.startOffset > cursor) {
        children.add(TextSpan(
          text: source.substring(cursor, s.startOffset),
          style: baseStyle,
        ));
      }
      final start = s.startOffset.clamp(cursor, source.length);
      final end = s.endOffset.clamp(start, source.length);
      if (end > start) {
        final hasErr =
            inError(start, end) || s.category == QudsTokenCategory.error;
        children.add(TextSpan(
          text: source.substring(start, end),
          style: baseStyle.copyWith(
            color: Color(palette.colorFor(s.category)),
            fontWeight: s.category == QudsTokenCategory.controlKeyword ||
                    s.category == QudsTokenCategory.declarationKeyword ||
                    s.category == QudsTokenCategory.sectionHeader
                ? FontWeight.w600
                : FontWeight.w400,
            fontStyle: s.category == QudsTokenCategory.comment ||
                    s.category == QudsTokenCategory.docComment
                ? FontStyle.italic
                : FontStyle.normal,
            decoration: hasErr ? TextDecoration.underline : null,
            decorationColor: hasErr ? const Color(0xFFEF4444) : null,
            decorationStyle: hasErr ? TextDecorationStyle.wavy : null,
          ),
        ));
        cursor = end;
      }
    }

    if (cursor < source.length) {
      children.add(TextSpan(
        text: source.substring(cursor),
        style: baseStyle,
      ));
    }

    return TextSpan(style: baseStyle, children: children);
  }
}

/// Interactive Quds code editor panel with clickable breakpoint gutter,
/// autocomplete bar, signature hint, and diagnostics/quick-fix strip.
class QudsCodeEditorView extends StatelessWidget {
  const QudsCodeEditorView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.palette,
    required this.analysis,
    required this.breakpoints,
    required this.pausedLine,
    required this.completions,
    required this.signatureHelp,
    required this.onToggleBreakpoint,
    required this.onApplyCompletion,
    required this.onApplyQuickFix,
    required this.onSmartEnter,
    required this.onSmartTab,
    required this.onFormat,
    required this.onToggleComment,
    required this.isArabic,
  });

  final QudsSyntaxTextController controller;
  final FocusNode focusNode;
  final QudsEditorThemePalette palette;
  final QudsEditorAnalysis analysis;
  final Set<int> breakpoints;
  final int? pausedLine;
  final List<QudsCompletionItem> completions;
  final QudsSignatureHelp? signatureHelp;
  final void Function(int line) onToggleBreakpoint;
  final void Function(QudsCompletionItem item) onApplyCompletion;
  final void Function(QudsQuickFix fix) onApplyQuickFix;
  final VoidCallback onSmartEnter;
  final void Function(bool outdent) onSmartTab;
  final VoidCallback onFormat;
  final VoidCallback onToggleComment;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final lineCount = '\n'.allMatches(controller.text).length + 1;
    final bg = Color(palette.background);
    final gutterBg = Color(palette.gutterBackground);
    final gutterFg = Color(palette.gutterForeground);
    const fontSize = 13.0;
    const lineHeight = 1.62;
    const rowHeight = fontSize * lineHeight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(palette.gutterForeground).withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact editor action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: gutterBg,
              border: Border(
                bottom: BorderSide(
                  color: gutterFg.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.code_rounded,
                    size: 16,
                    color: Color(palette.colorFor(QudsTokenCategory.keyword))),
                const SizedBox(width: 8),
                Text(
                  isArabic ? 'محرر كود Quds' : 'Quds Code Editor',
                  style: TextStyle(
                    color: Color(palette.foreground),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                if (analysis.hasErrors)
                  _StatusPill(
                    color: const Color(0xFFEF4444),
                    label: isArabic
                        ? '${analysis.diagnostics.length} خطأ'
                        : '${analysis.diagnostics.length} error(s)',
                  )
                else
                  _StatusPill(
                    color: const Color(0xFF10B981),
                    label: isArabic ? 'سليم' : 'Valid',
                  ),
                const Spacer(),
                Tooltip(
                  message:
                      isArabic ? 'تعليق/إلغاء تعليق السطر' : 'Toggle Comment',
                  child: IconButton(
                    key: const Key('btn_toggle_comment'),
                    onPressed: onToggleComment,
                    icon:
                        Icon(Icons.comment_outlined, size: 16, color: gutterFg),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Tooltip(
                  message:
                      isArabic ? 'تنسيق الكود (quds format)' : 'Format Code',
                  child: TextButton.icon(
                    key: const Key('btn_format_code'),
                    onPressed: onFormat,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
                    label: Text(
                      isArabic ? 'تنسيق' : 'Format',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Signature help bar when typing inside a call
          if (signatureHelp != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              color: Color(palette.activeLineBackground),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  signatureHelp!.label,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: const ['IBMPlexSansArabic'],
                    fontSize: 11.5,
                    color:
                        Color(palette.colorFor(QudsTokenCategory.functionName)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // Main LTR Code Canvas + Clickable Breakpoint Gutter
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Clickable line numbers & breakpoint gutter
                    Container(
                      width: 56,
                      color: gutterBg,
                      padding: const EdgeInsets.only(right: 8, left: 6),
                      child: Column(
                        children: [
                          for (var line = 1; line <= lineCount; line++)
                            InkWell(
                              key: Key('gutter_line_$line'),
                              onTap: () => onToggleBreakpoint(line),
                              child: Container(
                                height: rowHeight,
                                alignment: Alignment.centerRight,
                                decoration: pausedLine == line
                                    ? BoxDecoration(
                                        color:
                                            Color(palette.pausedLineBackground),
                                        borderRadius: BorderRadius.circular(4),
                                      )
                                    : null,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      child: Center(
                                        child: breakpoints.contains(line)
                                            ? Container(
                                                key: Key('bp_dot_$line'),
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                  color: Color(
                                                      palette.breakpointColor),
                                                  shape: BoxShape.circle,
                                                ),
                                              )
                                            : pausedLine == line
                                                ? const Icon(
                                                    Icons.play_arrow_rounded,
                                                    size: 13,
                                                    color: Color(0xFFF59E0B),
                                                  )
                                                : null,
                                      ),
                                    ),
                                    Text(
                                      '$line',
                                      style: TextStyle(
                                        fontFamily: 'JetBrainsMono',
                                        fontFamilyFallback: const [
                                          'IBMPlexSansArabic'
                                        ],
                                        fontSize: 11.5,
                                        color: pausedLine == line
                                            ? const Color(0xFFF59E0B)
                                            : gutterFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Syntax-highlighted editable text surface
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.tab): () =>
                                onSmartTab(false),
                            const SingleActivator(LogicalKeyboardKey.tab,
                                shift: true): () => onSmartTab(true),
                          },
                          child: TextField(
                            key: const Key('quds_code_textfield'),
                            controller: controller,
                            focusNode: focusNode,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: const ['IBMPlexSansArabic'],
                              fontSize: fontSize,
                              height: lineHeight,
                              color: Color(palette.foreground),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Context-aware Autocomplete suggestion strip
          if (completions.isNotEmpty)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: gutterBg,
                border: Border(
                  top: BorderSide(color: gutterFg.withValues(alpha: 0.2)),
                ),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: completions.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final item = completions[index];
                    return ActionChip(
                      key: Key('completion_${item.label}'),
                      label: Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: const ['IBMPlexSansArabic'],
                          fontSize: 11.5,
                          color: Color(palette.foreground),
                        ),
                      ),
                      tooltip: item.detail ?? item.documentation ?? item.label,
                      backgroundColor: Color(palette.activeLineBackground),
                      side: BorderSide(
                        color: gutterFg.withValues(alpha: 0.25),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onApplyCompletion(item),
                    );
                  },
                ),
              ),
            ),

          // Live Diagnostics + One-Click Quick Fix strip
          if (analysis.diagnostics.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                border: const Border(
                  top: BorderSide(color: Color(0x55EF4444)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'L${analysis.diagnostics.first.line}: '
                      '${analysis.diagnostics.first.code} — '
                      '${analysis.diagnostics.first.message}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(palette.foreground),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (analysis.diagnostics.first.quickFixes.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      key: const Key('btn_quick_fix'),
                      onPressed: () => onApplyQuickFix(
                        analysis.diagnostics.first.quickFixes.first,
                      ),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                      ),
                      child: Text(
                        isArabic ? 'إصلاح سريع' : 'Quick Fix',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
