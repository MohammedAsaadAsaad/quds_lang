/// Interactive Quds Code Playground embedded directly inside Quds Academy.
///
/// Powered by `package:quds/interpreter.dart` and `package:quds/editor_engine.dart`:
/// - Real-time Quds syntax highlighting (`JetBrainsMono` + `Cairo` Arabic fallback)
/// - Live error squiggles, one-click Quick Fixes, Format (`formatQuds`), Autocomplete
/// - Clickable line breakpoints + `Step Over` / `Continue` / `Stop` + live Locals
/// - Live Console Output, Workspace inspection, and interactive `quds:viz` SVG/Canvas
///   geometry & 2D plot rendering!
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quds/editor_engine.dart';
import 'package:quds/interpreter.dart';

class _AcademySnippet {
  const _AcademySnippet({
    required this.titleAr,
    required this.titleEn,
    required this.code,
  });

  final String titleAr;
  final String titleEn;
  final String code;
}

const _starterSnippets = <_AcademySnippet>[
  _AcademySnippet(
    titleAr: 'مرحباً بقدس',
    titleEn: 'Hello Quds',
    code: '''name = "Quds"
var total = 0
for i in 1..5:
  total += i * i
  print "الخطوة {\$.index + 1}: total={total}"

print "أهلاً بك في {name}! المجموع = {total}"
''',
  ),
  _AcademySnippet(
    titleAr: 'رياضيات وإحصاء',
    titleEn: 'Math & Stats',
    code: '''use quds:math

scores = [78.0, 85.0, 92.0, 88.0, 95.0]
avg = mean(scores)
print "المتوسط الحسابي = {avg.toStringAsFixed(2)}"
print "sin(pi/2) = {sin(pi / 2)}"
print "توافيق 5 من 2 = {combinationsOf(5, 2).length}"
''',
  ),
  _AcademySnippet(
    titleAr: 'هندسة تفاعلية',
    titleEn: 'Interactive Geometry',
    code: '''use quds:math::vector show Vec2
use quds:math::geometry show polygonCentroid
use quds:viz as viz

A = viz.point("A", 0.0, 0.0, draggable: true, color: "#147D64")
B = viz.point("B", 6.0, 0.0, draggable: true, color: "#147D64")
C = viz.point("C", 2.0, 4.0, draggable: true, color: "#147D64")
r = viz.slider("r", min: 0.5, max: 3.5, value: 1.2, label: "نصف القطر")

poly = [Vec2(A.x, A.y), Vec2(B.x, B.y), Vec2(C.x, C.y)]
center = polygonCentroid(poly)

scene = viz.scene(title: "مثلث الأكاديمية التفاعلي", grid: true, interactive: true)
scene.polygon("tri", poly, fill: "#147D6428", stroke: "#147D64")
scene.circle("c", center, r, stroke: "#F59E0B", dashed: true)
scene.segment("m", A, center, color: "#94A3B8", dashed: true)
scene.angle("angA", B, A, C, showDegrees: true, color: "#F59E0B")
scene.point("A", A)
scene.point("B", B)
scene.point("C", C)
scene.point("G", center, label: "G", color: "#EF4444")
scene.render()

print "مركز الثقل G = ({center.x.toStringAsFixed(2)}, {center.y.toStringAsFixed(2)})"
''',
  ),
  _AcademySnippet(
    titleAr: 'دوال وأصناف',
    titleEn: 'Functions & Classes',
    code: '''value class Book:
  title: String required
  pages: int required
  summary() -> String = "{title} ({pages} صفحة)"

b = Book("لغة قدس", 180)
print b.summary()
''',
  ),
];

/// Syntax-highlighted [TextEditingController] tailored for Quds Academy.
class _AcademySyntaxController extends TextEditingController {
  _AcademySyntaxController({
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
      fontFamilyFallback: const ['Cairo'],
      color: Color(palette.foreground),
    );
    if (source.isEmpty) return TextSpan(style: baseStyle, text: '');

    final spans = engine.highlight(source);
    final errorRanges = <(int, int)>[
      for (final d in diagnostics)
        if (d.severity == QudsDiagnosticSeverity.error)
          (d.startOffset, d.endOffset),
    ];
    bool inErr(int s, int e) => errorRanges.any((r) => s < r.$2 && e > r.$1);

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
        final err = inErr(start, end) || s.category == QudsTokenCategory.error;
        children.add(TextSpan(
          text: source.substring(start, end),
          style: baseStyle.copyWith(
            color: Color(palette.colorFor(s.category)),
            fontWeight: s.category == QudsTokenCategory.controlKeyword ||
                    s.category == QudsTokenCategory.declarationKeyword
                ? FontWeight.w600
                : FontWeight.w400,
            decoration: err ? TextDecoration.underline : null,
            decorationColor: err ? const Color(0xFFEF4444) : null,
            decorationStyle: err ? TextDecorationStyle.wavy : null,
          ),
        ));
        cursor = end;
      }
    }
    if (cursor < source.length) {
      children.add(TextSpan(text: source.substring(cursor), style: baseStyle));
    }
    return TextSpan(style: baseStyle, children: children);
  }
}

/// Smart IME & keyboard formatter for Quds: auto-indents after `:`,
/// preserves block indent, exits blank indented lines, auto-dedents `else:` /
/// `catch:` / `finally:`, and snaps Backspace on leading spaces (VS Code style).
class _AcademySmartEditFormatter extends TextInputFormatter {
  _AcademySmartEditFormatter(this.engine);

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

    // 1. Enter / Newline (`\n` or `\r\n` from soft keyboard or hardware keyboard)
    if (newSel.isCollapsed &&
        (newText == '$prefix\n$suffix' || newText == '$prefix\r\n$suffix')) {
      final base = '$prefix$suffix';
      final res = engine.handleNewline(base, start);
      return TextEditingValue(
        text: res.text,
        selection: TextSelection.collapsed(offset: res.selectionStart),
      );
    }

    // 2. Smart Backspace inside leading indentation whitespace
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

    // 3. Auto-dedent `else:`, `elif ...:`, `catch ...:`, `finally:` on `:`
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

/// Interactive Quds Playground widget embedded inside Quds Academy.
class AcademyPlayground extends StatefulWidget {
  const AcademyPlayground({
    super.key,
    required this.initialCode,
    required this.arabic,
    required this.dark,
  });

  final String initialCode;
  final bool arabic;
  final bool dark;

  @override
  State<AcademyPlayground> createState() => _AcademyPlaygroundState();
}

class _AcademyPlaygroundState extends State<AcademyPlayground> {
  static const _brand = Color(0xFF147D64);

  late QudsDebugController _debugger;
  late QudsSession _session;
  late QudsEditorEngine _engine;
  late _AcademySyntaxController _controller;
  StreamSubscription<QudsDebugPauseEvent>? _pauseSub;
  StreamSubscription<void>? _resumeSub;

  QudsEditorAnalysis _analysis = const QudsEditorAnalysis(
    highlights: [],
    diagnostics: [],
    symbols: [],
    foldRanges: [],
    validSyntax: true,
  );
  List<QudsCompletionItem> _completions = const [];
  final Set<int> _breakpoints = {};
  QudsDebugPauseEvent? _activePause;
  QudsRunResult? _result;
  bool _running = false;
  bool _updatingInteractive = false;
  Map<String, Object?>? _pendingInteractivePatch;

  String tr(String en, String ar) => widget.arabic ? ar : en;

  QudsEditorThemePalette get _palette => QudsEditorThemePalette.dark();

  @override
  void initState() {
    super.initState();
    _initRuntime();
    final seed = widget.initialCode.trim().isNotEmpty
        ? widget.initialCode
        : _starterSnippets.first.code;
    _controller = _AcademySyntaxController(
      text: seed,
      engine: _engine,
      palette: _palette,
    );
    _controller.addListener(_reanalyze);
    _reanalyze();
  }

  @override
  void didUpdateWidget(covariant AcademyPlayground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCode != oldWidget.initialCode &&
        widget.initialCode.trim().isNotEmpty) {
      _controller.text = widget.initialCode;
      _result = null;
      _reanalyze();
    }
  }

  void _initRuntime() {
    _pauseSub?.cancel();
    _resumeSub?.cancel();
    _debugger = QudsDebugController();
    _session = QudsSession(
      policy: QudsExecutionPolicy.standard(
        maxSteps: 150000,
        timeout: const Duration(seconds: 6),
      ),
      debugger: _debugger,
      allowTopLevelRebind: true,
    );
    _engine = QudsEditorEngine(session: _session);
    _pauseSub = _debugger.onPaused.listen((pause) {
      if (mounted) setState(() => _activePause = pause);
    });
    _resumeSub = _debugger.onResumed.listen((_) {
      if (mounted) setState(() => _activePause = null);
    });
  }

  void _reanalyze() {
    final text = _controller.text;
    final analysis = _engine.analyze(text, file: 'playground.quds');
    final sel = _controller.selection;
    final offset = sel.isValid ? sel.baseOffset : text.length;
    final comps = _engine.completeAt(text, offset).take(8).toList();
    _controller.diagnostics = analysis.diagnostics;
    if (mounted) {
      setState(() {
        _analysis = analysis;
        _completions = comps;
      });
    } else {
      _analysis = analysis;
      _completions = comps;
    }
  }

  Future<void> _run() async {
    if (_running) return;
    _debugger.setLineBreakpoints('playground.quds', _breakpoints);
    setState(() => _running = true);

    var source = _controller.text;
    // Many Academy lesson snippets define `main(): ...` without invoking it.
    // Auto-invoke `main()` cleanly if defined and not already called at top-level!
    if (RegExp(r'^main\(\s*\):', multiLine: true).hasMatch(source) &&
        !RegExp(r'^main\(\s*\)\s*$', multiLine: true).hasMatch(source)) {
      source = '$source\nmain()\n';
    }

    final res = await _session.run(source, file: 'playground.quds');
    if (!mounted) return;
    setState(() {
      _running = false;
      _activePause = null;
      _result = res;
    });
    _reanalyze();
  }

  Future<void> _updateInteractive(Map<String, Object?> patch) async {
    if (_running) return;
    _pendingInteractivePatch = {
      ...?_pendingInteractivePatch,
      ...patch,
    };
    if (_updatingInteractive) return;
    _updatingInteractive = true;
    _debugger.clearBreakpoints();
    try {
      while (_pendingInteractivePatch != null && mounted && !_running) {
        final nextPatch = _pendingInteractivePatch!;
        _pendingInteractivePatch = null;
        final res = await _session.updateInteractiveInputs(
          nextPatch,
          source: _controller.text,
          file: 'playground.quds',
        );
        if (!mounted) return;
        setState(() => _result = res);
      }
    } finally {
      _updatingInteractive = false;
    }
  }

  void _format() {
    final formatted = _engine.format(_controller.text);
    _controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _applyCompletion(QudsCompletionItem item) {
    final text = _controller.text;
    final pos = _controller.selection.isValid
        ? _controller.selection.baseOffset.clamp(0, text.length)
        : text.length;
    final before = text.substring(0, pos);
    final wordMatch = RegExp(r'([A-Za-z0-9_]*)$').firstMatch(before);
    final replaceStart = pos - (wordMatch?.group(1)?.length ?? 0);
    final updated = text.replaceRange(replaceStart, pos, item.insertText);
    _controller.value = TextEditingValue(
      text: updated,
      selection:
          TextSelection.collapsed(offset: replaceStart + item.insertText.length),
    );
  }

  void _applyQuickFix(QudsQuickFix fix) {
    final updated = _engine.applyEdits(_controller.text, fix.edits);
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  void _applyTab(bool outdent) {
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : _controller.text.length;
    final end = sel.isValid ? sel.end : start;
    final res = _engine.handleTab(_controller.text, start, end, outdent: outdent);
    _controller.value = TextEditingValue(
      text: res.text,
      selection: TextSelection(
        baseOffset: res.selectionStart,
        extentOffset: res.selectionEnd,
      ),
    );
  }

  void _toggleComment() {
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start : _controller.text.length;
    final end = sel.isValid ? sel.end : start;
    final res = _engine.toggleLineComment(_controller.text, start, end);
    _controller.value = TextEditingValue(
      text: res.text,
      selection: TextSelection(
        baseOffset: res.selectionStart,
        extentOffset: res.selectionEnd,
      ),
    );
  }

  void _insertToken(String token, {int cursorBack = 0}) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(start, text.length) : start;
    var updated = text.replaceRange(start, end, token);
    var nextOffset = start + token.length - cursorBack;
    if (token == ':') {
      final dedented = _engine.handleTypedColon(updated, nextOffset);
      if (dedented != null) {
        updated = dedented.text;
        nextOffset = dedented.selectionStart;
      }
    }
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
  }

  @override
  void dispose() {
    _pauseSub?.cancel();
    _resumeSub?.cancel();
    _controller.dispose();
    _debugger.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.dark ? const Color(0xFF162B27) : Colors.white;
    final border = widget.dark ? const Color(0xFF2D443C) : const Color(0xFFE5EBE6);
    final ink = widget.dark ? const Color(0xFFEAF4EF) : const Color(0xFF182D29);
    final muted = widget.dark ? const Color(0xFFA4BBB1) : const Color(0xFF73817B);
    final lineCount = '\n'.allMatches(_controller.text).length + 1;
    final scene = _result?.lastGeometryScene;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header + starter snippet chips
        Text(
          tr('Interactive Quds Playground', 'مختبر قدس التفاعلي'),
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'Write, format, debug with breakpoints, and run real Quds code directly on your device using the embedded interpreter.',
            'اكتب كود قدس، نسّقه، ضع نقاط توقف (Breakpoints)، وشغّله مباشرةً داخل التطبيق عبر المفسّر المدمج.',
          ),
          style: TextStyle(fontSize: 13.5, height: 1.7, color: muted),
        ),
        const SizedBox(height: 14),

        // Quick starter snippets
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _starterSnippets)
              ActionChip(
                label: Text(widget.arabic ? s.titleAr : s.titleEn,
                    style: const TextStyle(fontSize: 12)),
                avatar: const Icon(Icons.bolt_rounded, size: 16, color: _brand),
                onPressed: () {
                  _controller.text = s.code;
                  _breakpoints.clear();
                  setState(() => _result = null);
                  _reanalyze();
                },
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Editor Card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F1F1C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Editor toolbar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: const Color(0xFF0A1614),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!_running)
                      FilledButton.icon(
                        key: const Key('academy_playground_run'),
                        onPressed: _run,
                        style: FilledButton.styleFrom(
                          backgroundColor: _brand,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(tr('Run', 'تشغيل')),
                      )
                    else if (_activePause != null) ...[
                      FilledButton.icon(
                        onPressed: _debugger.continueRun,
                        style: FilledButton.styleFrom(
                          backgroundColor: _brand,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: Text(tr('Continue', 'متابعة')),
                      ),
                      OutlinedButton.icon(
                        onPressed: _debugger.stepOver,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.redo_rounded, size: 15),
                        label: Text(tr('Step', 'خطوة')),
                      ),
                      IconButton(
                        onPressed: _session.stop,
                        icon: const Icon(Icons.stop_circle_outlined,
                            color: Color(0xFFEF4444)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ] else
                      OutlinedButton.icon(
                        onPressed: _session.stop,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.stop_rounded, size: 16),
                        label: Text(tr('Stop', 'إيقاف')),
                      ),
                    TextButton.icon(
                      key: const Key('academy_playground_format'),
                      onPressed: _format,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF9BCAB3),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                      label: Text(tr('Format', 'تنسيق')),
                    ),
                  ],
                ),
              ),

              // Code editor with clickable Breakpoint gutter
              Directionality(
                textDirection: TextDirection.ltr,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 220, maxHeight: 340),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            children: [
                              for (var line = 1; line <= lineCount; line++)
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (!_breakpoints.remove(line)) {
                                        _breakpoints.add(line);
                                      }
                                    });
                                    _debugger.setLineBreakpoints(
                                        'playground.quds', _breakpoints);
                                  },
                                  child: Container(
                                    height: 21.0,
                                    decoration: _activePause?.span.line == line
                                        ? BoxDecoration(
                                            color: const Color(0x44F59E0B),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          )
                                        : null,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        SizedBox(
                                          width: 10,
                                          child: _breakpoints.contains(line)
                                              ? Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(0xFFEF4444),
                                                    shape: BoxShape.circle,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        Text(
                                          '$line',
                                          style: const TextStyle(
                                            fontFamily: 'JetBrainsMono',
                                            fontSize: 11,
                                            color: Color(0xFF6B8E82),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: CallbackShortcuts(
                              bindings: {
                                const SingleActivator(LogicalKeyboardKey.tab):
                                    () => _applyTab(false),
                                const SingleActivator(LogicalKeyboardKey.tab,
                                    shift: true): () => _applyTab(true),
                                const SingleActivator(
                                    LogicalKeyboardKey.bracketRight,
                                    control: true): () => _applyTab(false),
                                const SingleActivator(
                                    LogicalKeyboardKey.bracketLeft,
                                    control: true): () => _applyTab(true),
                                const SingleActivator(LogicalKeyboardKey.slash,
                                    control: true): _toggleComment,
                                const SingleActivator(LogicalKeyboardKey.keyF,
                                    shift: true, alt: true): _format,
                              },
                              child: TextField(
                                key: const Key('academy_playground_editor'),
                                controller: _controller,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                autocorrect: false,
                                enableSuggestions: false,
                                inputFormatters: [
                                  _AcademySmartEditFormatter(_engine),
                                ],
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontFamilyFallback: ['Cairo'],
                                  fontSize: 13,
                                  height: 1.62,
                                  color: Color(0xFFD3EDDF),
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

              // VS Code-style Quick-Keys & Indent Bar (works great on phones & tablets)
              Container(
                height: 40,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A1614),
                  border: Border(
                    top: BorderSide(color: Color(0xFF1F3831)),
                  ),
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _QuickKeyButton(
                        key: const Key('academy_btn_indent'),
                        label: '⇥ Tab',
                        tooltip: tr('Indent (Tab / Ctrl+])',
                            'مسافة بادئة (Tab / Ctrl+])'),
                        highlighted: true,
                        onPressed: () => _applyTab(false),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        key: const Key('academy_btn_outdent'),
                        label: '⇤',
                        tooltip: tr('Outdent (Shift+Tab / Ctrl+[)',
                            'تقليص المسافة (Shift+Tab)'),
                        highlighted: true,
                        onPressed: () => _applyTab(true),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        label: ':',
                        onPressed: () => _insertToken(':'),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        label: '()',
                        onPressed: () => _insertToken('()', cursorBack: 1),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        label: '[]',
                        onPressed: () => _insertToken('[]', cursorBack: 1),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        label: '{}',
                        onPressed: () => _insertToken('{}', cursorBack: 1),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        label: '""',
                        onPressed: () => _insertToken('""', cursorBack: 1),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        label: '=',
                        onPressed: () => _insertToken(' = '),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        label: '->',
                        onPressed: () => _insertToken(' -> '),
                      ),
                      const SizedBox(width: 6),
                      _QuickKeyButton(
                        key: const Key('academy_btn_comment'),
                        label: '#',
                        tooltip: tr('Toggle Comment (Ctrl+/)',
                            'تعليق/إلغاء تعليق (Ctrl+/)'),
                        onPressed: _toggleComment,
                      ),
                    ],
                  ),
                ),
              ),

              // Autocomplete bar
              if (_completions.isNotEmpty)
                Container(
                  height: 38,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: const Color(0xFF0A1614),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _completions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, idx) {
                        final item = _completions[idx];
                        return ActionChip(
                          label: Text(
                            item.label,
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11,
                              color: Color(0xFFEAF4EF),
                            ),
                          ),
                          backgroundColor: const Color(0xFF162B27),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _applyCompletion(item),
                        );
                      },
                    ),
                  ),
                ),

              // Diagnostics + Quick Fix
              if (_analysis.diagnostics.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: const Color(0x28EF4444),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: Color(0xFFF87171)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'L${_analysis.diagnostics.first.line}: '
                          '${_analysis.diagnostics.first.code} — '
                          '${_analysis.diagnostics.first.message}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFFEE2E2)),
                        ),
                      ),
                      if (_analysis.diagnostics.first.quickFixes.isNotEmpty)
                        TextButton(
                          onPressed: () => _applyQuickFix(
                              _analysis.diagnostics.first.quickFixes.first),
                          child: Text(tr('Quick Fix', 'إصلاح سريع')),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Debugger paused locals banner
        if (_activePause != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x22F59E0B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x66F59E0B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paused at line ${_activePause!.span.line} (${_activePause!.stackFrames.first.functionName})',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 6),
                for (final e in _activePause!.locals.entries)
                  Text(
                    '${e.key} = ${qudsSummarizeValue(e.value)}',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: const ['Cairo'],
                      fontSize: 12,
                      color: ink,
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Interactive Geometry output (when `quds:viz` is used!)
        if (scene != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 260,
                  child: _AcademyGeoCanvas(
                    scene: scene,
                    dark: widget.dark,
                    onDragPoint: (id, x, y) => _updateInteractive({
                      id: {'x': x, 'y': y},
                    }),
                  ),
                ),
                for (final input
                    in scene.interactiveInputs.where((i) => i.kind == 'slider'))
                  Row(
                    children: [
                      Text(input.label ?? input.id,
                          style: TextStyle(fontSize: 12, color: ink)),
                      Expanded(
                        child: Slider(
                          value: (input.value as num)
                              .toDouble()
                              .clamp(input.min ?? 0.0, input.max ?? 10.0),
                          min: input.min ?? 0.0,
                          max: input.max ?? 10.0,
                          activeColor: _brand,
                          onChanged: (v) => _updateInteractive({input.id: v}),
                        ),
                      ),
                      Text(
                        (input.value as num).toStringAsFixed(2),
                        style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 11.5,
                            color: muted),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],

        // Live Output Card
        if (_result != null) ...[
          const SizedBox(height: 14),
          Container(
            key: const Key('academy_playground_output'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _result!.succeeded
                    ? _brand.withValues(alpha: 0.4)
                    : const Color(0xFFEF4444).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _result!.succeeded
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 16,
                      color:
                          _result!.succeeded ? _brand : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('LIVE OUTPUT', 'ناتج التشغيل الحي'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: _result!.succeeded
                            ? _brand
                            : const Color(0xFFEF4444),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_result!.stepsExecuted} steps · ${_result!.elapsed.inMilliseconds}ms',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10.5,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_result!.printedLines.isNotEmpty)
                  SelectableText(
                    _result!.printedLines.join('\n'),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: const ['Cairo'],
                      fontSize: 13,
                      height: 1.7,
                      color: ink,
                    ),
                  )
                else if (_result!.succeeded && _result!.value != null)
                  SelectableText(
                    qudsFormatValue(_result!.value),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: const ['Cairo'],
                      fontSize: 13,
                      color: ink,
                    ),
                  )
                else if (!_result!.succeeded && _result!.error != null)
                  SelectableText(
                    '${_result!.error}',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['Cairo'],
                      fontSize: 12.5,
                      color: Color(0xFFEF4444),
                    ),
                  )
                else
                  Text(
                    tr('(Completed with no printed output)',
                        '(تم التنفيذ بنجاح بدون مخرجات نصية)'),
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact interactive 2D geometry canvas for Quds Academy Playground.
class _AcademyGeoCanvas extends StatefulWidget {
  const _AcademyGeoCanvas({
    required this.scene,
    required this.dark,
    required this.onDragPoint,
  });

  final QudsGeometrySceneOutput scene;
  final bool dark;
  final void Function(String id, double x, double y) onDragPoint;

  @override
  State<_AcademyGeoCanvas> createState() => _AcademyGeoCanvasState();
}

class _AcademyGeoCanvasState extends State<_AcademyGeoCanvas> {
  String? _draggingId;
  QudsGeoBounds? _lockedBounds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final bounds = _lockedBounds ?? widget.scene.bounds;
        const pad = 28.0;
        final scale = math.min(
          math.max(size.width - pad * 2, 10.0) / math.max(bounds.width, 1e-6),
          math.max(size.height - pad * 2, 10.0) / math.max(bounds.height, 1e-6),
        );
        final midX = (bounds.minX + bounds.maxX) / 2;
        final midY = (bounds.minY + bounds.maxY) / 2;
        Offset toScreen(double x, double y) => Offset(
              size.width / 2 + (x - midX) * scale,
              size.height / 2 - (y - midY) * scale,
            );
        Offset toWorld(Offset p) => Offset(
              midX + (p.dx - size.width / 2) / scale,
              midY - (p.dy - size.height / 2) / scale,
            );

        return GestureDetector(
          onPanStart: (d) {
            String? hit;
            var best = 38.0;
            for (final pt in widget.scene.draggablePoints) {
              final dist = (toScreen(pt.x, pt.y) - d.localPosition).distance;
              if (dist < best) {
                best = dist;
                hit = pt.id;
              }
            }
            if (hit != null) {
              setState(() {
                _draggingId = hit;
                _lockedBounds = widget.scene.bounds;
              });
            }
          },
          onPanUpdate: (d) {
            if (_draggingId == null) return;
            final w = toWorld(d.localPosition);
            widget.onDragPoint(
              _draggingId!,
              double.parse(w.dx.toStringAsFixed(2)),
              double.parse(w.dy.toStringAsFixed(2)),
            );
          },
          onPanEnd: (_) => setState(() {
            _draggingId = null;
            _lockedBounds = null;
          }),
          onPanCancel: () => setState(() {
            _draggingId = null;
            _lockedBounds = null;
          }),
          child: RepaintBoundary(
            child: CustomPaint(
              size: size,
              painter: _AcademyGeoPainter(
                scene: widget.scene,
                dark: widget.dark,
                toScreen: toScreen,
                scale: scale,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AcademyGeoPainter extends CustomPainter {
  const _AcademyGeoPainter({
    required this.scene,
    required this.dark,
    required this.toScreen,
    required this.scale,
  });

  final QudsGeometrySceneOutput scene;
  final bool dark;
  final Offset Function(double x, double y) toScreen;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()
        ..color = dark ? const Color(0xFF0A1614) : const Color(0xFFF3F7F4),
    );
    final origin = toScreen(0, 0);
    final axisPaint = Paint()
      ..color = dark ? const Color(0xFF2D443C) : const Color(0xFFCBD5E1)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(0, origin.dy), Offset(size.width, origin.dy), axisPaint);
    canvas.drawLine(
        Offset(origin.dx, 0), Offset(origin.dx, size.height), axisPaint);

    for (final p in scene.primitives) {
      switch (p) {
        case QudsGeoPolygon():
          if (p.points.length < 2) break;
          final path = Path();
          final s0 = toScreen(p.points.first.$1, p.points.first.$2);
          path.moveTo(s0.dx, s0.dy);
          for (var i = 1; i < p.points.length; i++) {
            final pt = toScreen(p.points[i].$1, p.points[i].$2);
            path.lineTo(pt.dx, pt.dy);
          }
          if (p.closed) path.close();
          if (p.fill != null) {
            canvas.drawPath(path, Paint()..color = _hex(p.fill!));
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = _hex(p.stroke)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        case QudsGeoCircle():
          final c = toScreen(p.cx, p.cy);
          canvas.drawCircle(
            c,
            p.radius * scale,
            Paint()
              ..color = _hex(p.stroke)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        case QudsGeoSegment():
          canvas.drawLine(
            toScreen(p.x1, p.y1),
            toScreen(p.x2, p.y2),
            Paint()
              ..color = _hex(p.color)
              ..strokeWidth = p.strokeWidth,
          );
        case QudsGeoPoint():
          final c = toScreen(p.x, p.y);
          final color = _hex(p.color);
          if (p.draggable) {
            canvas.drawCircle(c, 12, Paint()..color = color.withValues(alpha: 0.22));
          }
          canvas.drawCircle(c, p.draggable ? 6 : 4.5, Paint()..color = color);
          canvas.drawCircle(
            c,
            p.draggable ? 6 : 4.5,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6,
          );
          if (p.label != null) {
            final tp = TextPainter(
              text: TextSpan(
                text: '${p.label} (${p.x.toStringAsFixed(1)}, ${p.y.toStringAsFixed(1)})',
                style: TextStyle(
                  color: dark ? Colors.white : const Color(0xFF182D29),
                  fontSize: 11,
                  fontFamily: 'Cairo',
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, c + const Offset(8, -12));
          }
        case QudsGeoAngle():
          final v = toScreen(p.vx, p.vy);
          final tp = TextPainter(
            text: TextSpan(
              text: '${p.degrees.toStringAsFixed(1)}°',
              style: TextStyle(
                color: _hex(p.color),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, v + const Offset(14, -18));
        default:
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AcademyGeoPainter old) =>
      old.scene != scene || old.dark != dark;
}

Color _hex(String hex) {
  final c = hex.replaceFirst('#', '').trim();
  if (c.length == 6) return Color(int.parse('FF$c', radix: 16));
  if (c.length == 8) {
    return Color(int.parse('${c.substring(6, 8)}${c.substring(0, 6)}', radix: 16));
  }
  return const Color(0xFF147D64);
}

class _QuickKeyButton extends StatelessWidget {
  const _QuickKeyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.highlighted = false,
  });

  final String label;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: highlighted ? const Color(0xFF147D64) : const Color(0xFF162B27),
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
                  ? const Color(0xFF2AA789)
                  : const Color(0xFF2D443C),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['Cairo'],
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEAF4EF),
            ),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

