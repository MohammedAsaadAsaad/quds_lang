/// Reusable Flutter Quds Code Editor widget backed by `package:quds/editor_engine.dart`.
///
/// Features real-time syntax & semantic highlighting, clickable red breakpoint
/// gutter, paused-line highlight, error squiggles + one-click Quick Fixes,
/// context-aware autocomplete, signature help, and smart indentation.
library;

import 'dart:math' as math;

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
class QudsCodeEditorView extends StatefulWidget {
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
  State<QudsCodeEditorView> createState() => _QudsCodeEditorViewState();
}

class _QudsCodeEditorViewState extends State<QudsCodeEditorView> {
  bool _wordWrap = false;
  final ScrollController _hScrollController = ScrollController();

  void _toggleWordWrap() => setState(() => _wordWrap = !_wordWrap);

  double _measureCanvasWidth(
    String text,
    TextStyle style,
    double minWidth,
    TextScaler textScaler,
  ) {
    var maxLineWidth = 0.0;
    final measureStyle = style.copyWith(fontWeight: FontWeight.w600);
    for (final line in text.split('\n')) {
      if (line.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: line, style: measureStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      if (painter.width > maxLineWidth) {
        maxLineWidth = painter.width;
      }
      painter.dispose();
    }
    return math.max(minWidth, maxLineWidth + 96.0);
  }

  @override
  void dispose() {
    _hScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final analysis = widget.analysis;
    final isArabic = widget.isArabic;
    final lineCount = '\n'.allMatches(widget.controller.text).length + 1;
    final bg = Color(palette.background);
    final gutterBg = Color(palette.gutterBackground);
    final gutterFg = Color(palette.gutterForeground);
    const fontSize = 13.0;
    const lineHeight = 1.62;
    final textScaler = MediaQuery.textScalerOf(context);
    final rowHeight = textScaler.scale(fontSize) * lineHeight;
    final codeStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: fontSize,
      height: lineHeight,
      color: Color(palette.foreground),
    );

    final editorField = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.tab): () =>
              widget.onSmartTab(false),
          const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
              widget.onSmartTab(true),
          const SingleActivator(LogicalKeyboardKey.bracketRight, control: true):
              () => widget.onSmartTab(false),
          const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true):
              () => widget.onSmartTab(true),
          const SingleActivator(LogicalKeyboardKey.slash, control: true):
              widget.onToggleComment,
          const SingleActivator(LogicalKeyboardKey.keyF,
              shift: true, alt: true): widget.onFormat,
          const SingleActivator(LogicalKeyboardKey.keyZ, alt: true):
              _toggleWordWrap,
        },
        child: TextField(
          key: const Key('quds_code_textfield'),
          controller: widget.controller,
          focusNode: widget.focusNode,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            QudsSmartEditFormatter(widget.controller.engine),
          ],
          style: codeStyle,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isArabic ? 'محرر كود Quds' : 'Quds Code Editor',
                    style: TextStyle(
                      color: Color(palette.foreground),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
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
                  message: isArabic
                      ? (_wordWrap
                          ? 'التفاف الأسطر مفعّل — اضغط للتمرير الأفقي (Alt+Z)'
                          : 'تمرير أفقي مفعّل — اضغط لتفعيل التفاف الأسطر (Alt+Z)')
                      : (_wordWrap
                          ? 'Word Wrap ON — switch to Horizontal Scroll (Alt+Z)'
                          : 'Horizontal Scroll ON — toggle Word Wrap (Alt+Z)'),
                  child: IconButton(
                    key: const Key('btn_toggle_wrap'),
                    onPressed: _toggleWordWrap,
                    icon: Icon(
                      Icons.wrap_text_rounded,
                      size: 16,
                      color: _wordWrap
                          ? Color(palette.colorFor(QudsTokenCategory.keyword))
                          : gutterFg,
                    ),
                    style: _wordWrap
                        ? IconButton.styleFrom(
                            backgroundColor: Color(
                              palette.colorFor(QudsTokenCategory.keyword),
                            ).withValues(alpha: 0.16),
                          )
                        : null,
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                Tooltip(
                  message:
                      isArabic ? 'تعليق/إلغاء تعليق السطر' : 'Toggle Comment',
                  child: IconButton(
                    key: const Key('btn_toggle_comment'),
                    onPressed: widget.onToggleComment,
                    icon:
                        Icon(Icons.comment_outlined, size: 16, color: gutterFg),
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                Tooltip(
                  message:
                      isArabic ? 'تنسيق الكود (quds format)' : 'Format Code',
                  child: TextButton.icon(
                    key: const Key('btn_format_code'),
                    onPressed: widget.onFormat,
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
          if (widget.signatureHelp != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              color: Color(palette.activeLineBackground),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  widget.signatureHelp!.label,
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
                              onTap: () => widget.onToggleBreakpoint(line),
                              child: Container(
                                height: rowHeight,
                                alignment: Alignment.centerRight,
                                decoration: widget.pausedLine == line
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
                                        child: widget.breakpoints.contains(line)
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
                                            : widget.pausedLine == line
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
                                        color: widget.pausedLine == line
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

                    // Syntax-highlighted editable text surface (Horizontal Scroll default, or Word Wrap)
                    Expanded(
                      child: _wordWrap
                          ? editorField
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final canvasWidth = _measureCanvasWidth(
                                  widget.controller.text,
                                  codeStyle,
                                  constraints.maxWidth,
                                  textScaler,
                                );
                                return SingleChildScrollView(
                                  key: const Key('studio_editor_hscroll'),
                                  controller: _hScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: canvasWidth,
                                    child: editorField,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // VS Code-style Quick-Keys & Indent Bar (essential for mobile phones!)
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
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _StudioQuickKey(
                    key: const Key('studio_btn_indent'),
                    label: '⇥ Tab',
                    tooltip: isArabic
                        ? 'مسافة بادئة (Tab / Ctrl+])'
                        : 'Indent (Tab / Ctrl+])',
                    highlighted: true,
                    palette: palette,
                    onPressed: () => widget.onSmartTab(false),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    key: const Key('studio_btn_outdent'),
                    label: '⇤',
                    tooltip: isArabic
                        ? 'تقليص المسافة (Shift+Tab / Ctrl+[)'
                        : 'Outdent (Shift+Tab / Ctrl+[)',
                    highlighted: true,
                    palette: palette,
                    onPressed: () => widget.onSmartTab(true),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    label: ':',
                    palette: palette,
                    onPressed: () => _insertToken(':'),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    label: '()',
                    palette: palette,
                    onPressed: () => _insertToken('()', cursorBack: 1),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    label: '[]',
                    palette: palette,
                    onPressed: () => _insertToken('[]', cursorBack: 1),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    label: '{}',
                    palette: palette,
                    onPressed: () => _insertToken('{}', cursorBack: 1),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    label: '""',
                    palette: palette,
                    onPressed: () => _insertToken('""', cursorBack: 1),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    label: '=',
                    palette: palette,
                    onPressed: () => _insertToken(' = '),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    label: '->',
                    palette: palette,
                    onPressed: () => _insertToken(' -> '),
                  ),
                  const SizedBox(width: 6),
                  _StudioQuickKey(
                    label: '#',
                    tooltip: isArabic
                        ? 'تعليق/إلغاء تعليق (Ctrl+/)'
                        : 'Toggle Comment (Ctrl+/)',
                    palette: palette,
                    onPressed: widget.onToggleComment,
                  ),
                ],
              ),
            ),
          ),

          // Context-aware Autocomplete suggestion strip
          if (widget.completions.isNotEmpty)
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
                  itemCount: widget.completions.length.clamp(0, 10),
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final item = widget.completions[index];
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
                      onPressed: () => widget.onApplyCompletion(item),
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
                      onPressed: () => widget.onApplyQuickFix(
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

  void _insertToken(String token, {int cursorBack = 0}) {
    final text = widget.controller.text;
    final sel = widget.controller.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(start, text.length) : start;
    var updated = text.replaceRange(start, end, token);
    var nextOffset = start + token.length - cursorBack;
    if (token == ':') {
      final dedented =
          widget.controller.engine.handleTypedColon(updated, nextOffset);
      if (dedented != null) {
        updated = dedented.text;
        nextOffset = dedented.selectionStart;
      }
    }
    widget.controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
  }
}

/// Smart IME & hardware-keyboard formatter for Quds: auto-indents after `:`,
/// preserves block indent, exits blank indented lines, auto-dedents `else:` /
/// `catch:` / `finally:`, and snaps Backspace on leading spaces (VS Code style).
class QudsSmartEditFormatter extends TextInputFormatter {
  QudsSmartEditFormatter(this.engine);

  final QudsEditorEngine engine;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    final oldSel = oldValue.selection;
    final newSel = newValue.selection;
    if (!oldSel.isValid || !newSel.isValid) return newValue;

    final start = oldSel.start.clamp(0, oldText.length);
    final end = oldSel.end.clamp(start, oldText.length);
    final prefix = oldText.substring(0, start);
    final suffix = oldText.substring(end);

    if (newSel.isCollapsed &&
        (newText == '$prefix\n$suffix' || newText == '$prefix\r\n$suffix')) {
      final base = '$prefix$suffix';
      final res = engine.handleNewline(base, start);
      return TextEditingValue(
        text: res.text,
        selection: TextSelection.collapsed(offset: res.selectionStart),
      );
    }

    if (oldSel.isCollapsed &&
        newSel.isCollapsed &&
        newText.length == oldText.length - 1 &&
        newSel.baseOffset == start - 1 &&
        start > 0 &&
        oldText[start - 1] == ' ') {
      final res = engine.handleBackspace(oldText, start);
      if (res != null) {
        return TextEditingValue(
          text: res.text,
          selection: TextSelection.collapsed(offset: res.selectionStart),
        );
      }
    }

    if (oldSel.isCollapsed &&
        newSel.isCollapsed &&
        newText == '$prefix:$suffix') {
      final res = engine.handleTypedColon(newText, start + 1);
      if (res != null) {
        return TextEditingValue(
          text: res.text,
          selection: TextSelection.collapsed(offset: res.selectionStart),
        );
      }
    }

    return newValue;
  }
}

class _StudioQuickKey extends StatelessWidget {
  const _StudioQuickKey({
    super.key,
    required this.label,
    required this.palette,
    required this.onPressed,
    this.tooltip,
    this.highlighted = false,
  });

  final String label;
  final QudsEditorThemePalette palette;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final bg = highlighted
        ? const Color(0xFF2563EB)
        : Color(palette.activeLineBackground);
    final fg = highlighted ? Colors.white : Color(palette.foreground);
    final btn = Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFF60A5FA)
                  : Color(palette.gutterForeground).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: const ['IBMPlexSansArabic'],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
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
