/// Main Quds Scientific Studio UI combining:
/// - `QudsCodeEditorView` (syntax highlighting, breakpoints, autocomplete, quick fixes)
/// - `QudsSession` + `QudsExecutionPolicy` + `QudsDebugController`
/// - Interactive Geometry Canvas & 2D Plot Canvas (`quds:viz`)
/// - Console, Workspace Table, and Live Debugger Inspector (Stack, Locals, Eval)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quds/editor_engine.dart';
import 'package:quds/interpreter.dart';

import 'editor_widget.dart';
import 'presets.dart';
import 'viz_widgets.dart';

class QudsStudioPage extends StatefulWidget {
  const QudsStudioPage({
    super.key,
    this.initialPresetIndex = 0,
    this.initialArabic = true,
    this.initialDark = true,
    this.autoRunInitial = true,
  });

  final int initialPresetIndex;
  final bool initialArabic;
  final bool initialDark;
  final bool autoRunInitial;

  @override
  State<QudsStudioPage> createState() => _QudsStudioPageState();
}

class _QudsStudioPageState extends State<QudsStudioPage>
    with SingleTickerProviderStateMixin {
  late bool _isArabic;
  late bool _isDark;
  late StudioPreset _preset;
  late StudioPolicyMode _policyMode;

  late QudsDebugController _debugger;
  late QudsSession _session;
  late QudsEditorEngine _engine;
  late QudsSyntaxTextController _codeController;
  final FocusNode _editorFocus = FocusNode();
  final TextEditingController _evalController = TextEditingController();

  late TabController _inspectorTabs;
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
  QudsSignatureHelp? _signatureHelp;
  Set<int> _breakpoints = {};
  QudsDebugPauseEvent? _activePause;
  QudsRunResult? _lastResult;
  bool _running = false;
  String? _liveEvalOutput;

  QudsEditorThemePalette get _palette =>
      _isDark ? QudsEditorThemePalette.dark() : QudsEditorThemePalette.light();

  @override
  void initState() {
    super.initState();
    _isArabic = widget.initialArabic;
    _isDark = widget.initialDark;
    _preset = studioPresets[widget.initialPresetIndex];
    _policyMode = _preset.defaultPolicy;
    _breakpoints = Set<int>.from(_preset.defaultBreakpoints);
    _inspectorTabs = TabController(length: 3, vsync: this);

    _buildRuntime();
    _codeController = QudsSyntaxTextController(
      text: _preset.code,
      engine: _engine,
      palette: _palette,
    );
    _codeController.addListener(_onEditorChanged);
    _reanalyze();

    if (widget.autoRunInitial && _breakpoints.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runCode();
      });
    }
  }

  void _buildRuntime() {
    _pauseSub?.cancel();
    _resumeSub?.cancel();

    _debugger = QudsDebugController();
    final sensorsMod = QudsHostModule.builder(
      'host:sensors',
      description: 'Simulated laboratory hardware sensor bridge.',
    )
        .function(
          'readCelsius',
          (pos, named, ctx) =>
              23.4 + ((pos.isNotEmpty ? (pos[0] as num) : 1) * 1.1),
          capability: 'sensors.read',
          signature: 'readCelsius(channel: int) -> double',
          documentation: 'Reads temperature in Celsius from a lab channel.',
        )
        .build();

    final policy = switch (_policyMode) {
      StudioPolicyMode.scientific => QudsExecutionPolicy.scientific(
          maxSteps: 150000,
          timeout: const Duration(seconds: 6),
        ),
      StudioPolicyMode.strictSandbox => QudsExecutionPolicy.strictSandbox(
          maxSteps: 40000,
          timeout: const Duration(seconds: 2),
        ),
      StudioPolicyMode.systemBridge => QudsExecutionPolicy.systemBridge(
          capabilities: [QudsCapability.custom('sensors.read')],
          maxSteps: 200000,
          timeout: const Duration(seconds: 8),
        ),
    };

    _session = QudsSession(
      policy: policy,
      debugger: _debugger,
      allowTopLevelRebind: true,
      hostModules: [sensorsMod],
    );
    _engine = QudsEditorEngine(session: _session);

    _pauseSub = _debugger.onPaused.listen((pause) {
      if (!mounted) return;
      setState(() {
        _activePause = pause;
        _inspectorTabs.index = 2; // Jump to Debugger tab on pause!
      });
    });
    _resumeSub = _debugger.onResumed.listen((_) {
      if (!mounted) return;
      setState(() => _activePause = null);
    });
  }

  void _onEditorChanged() {
    _reanalyze();
  }

  void _reanalyze() {
    final text = _codeController.text;
    final analysis = _engine.analyze(text, file: _preset.fileName);
    final sel = _codeController.selection;
    final offset = sel.isValid ? sel.baseOffset : text.length;
    final completions = _engine.completeAt(text, offset);
    final sig = _engine.signatureHelpAt(text, offset);
    _codeController.diagnostics = analysis.diagnostics;
    _codeController.palette = _palette;

    if (mounted) {
      setState(() {
        _analysis = analysis;
        _completions = completions.take(10).toList();
        _signatureHelp = sig;
      });
    } else {
      _analysis = analysis;
      _completions = completions.take(10).toList();
      _signatureHelp = sig;
    }
  }

  Future<void> _runCode() async {
    if (_running) return;
    _debugger.setLineBreakpoints(_preset.fileName, _breakpoints);
    setState(() {
      _running = true;
      _liveEvalOutput = null;
    });
    final res =
        await _session.run(_codeController.text, file: _preset.fileName);
    if (!mounted) return;
    setState(() {
      _running = false;
      _activePause = null;
      _lastResult = res;
    });
    _reanalyze();
  }

  Future<void> _updateInteractive(Map<String, Object?> patch) async {
    if (_running) return;
    _debugger.clearBreakpoints();
    final res = await _session.updateInteractiveInputs(
      patch,
      source: _codeController.text,
      file: _preset.fileName,
    );
    if (!mounted) return;
    setState(() => _lastResult = res);
  }

  void _selectPreset(StudioPreset preset) {
    _session.stop();
    setState(() {
      _preset = preset;
      _policyMode = preset.defaultPolicy;
      _breakpoints = Set<int>.from(preset.defaultBreakpoints);
      _lastResult = null;
      _activePause = null;
      _running = false;
    });
    _rebuildSessionKeepingCode(preset.code);
    if (_breakpoints.isEmpty) {
      _runCode();
    }
  }

  void _switchPolicy(StudioPolicyMode mode) {
    _session.stop();
    setState(() {
      _policyMode = mode;
      _running = false;
      _activePause = null;
    });
    _rebuildSessionKeepingCode(_codeController.text);
  }

  void _rebuildSessionKeepingCode(String code) {
    _session.dispose();
    _debugger.dispose();
    _buildRuntime();
    _codeController.removeListener(_onEditorChanged);
    _codeController.dispose();
    _codeController = QudsSyntaxTextController(
      text: code,
      engine: _engine,
      palette: _palette,
    );
    _codeController.addListener(_onEditorChanged);
    _reanalyze();
  }

  void _applyCompletion(QudsCompletionItem item) {
    final text = _codeController.text;
    final pos = _codeController.selection.isValid
        ? _codeController.selection.baseOffset.clamp(0, text.length)
        : text.length;
    final before = text.substring(0, pos);
    final wordMatch = RegExp(r'([A-Za-z0-9_]*)$').firstMatch(before);
    final replaceStart = pos - (wordMatch?.group(1)?.length ?? 0);
    final updated = text.replaceRange(replaceStart, pos, item.insertText);
    _codeController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(
          offset: replaceStart + item.insertText.length),
    );
  }

  void _applyQuickFix(QudsQuickFix fix) {
    final updated = _engine.applyEdits(_codeController.text, fix.edits);
    _codeController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: updated.length),
    );
  }

  void _formatCode() {
    final formatted = _engine.format(_codeController.text);
    _codeController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _toggleComment() {
    final sel = _codeController.selection;
    final res = _engine.toggleLineComment(
      _codeController.text,
      sel.isValid ? sel.start : 0,
      sel.isValid ? sel.end : 0,
    );
    _codeController.value = TextEditingValue(
      text: res.text,
      selection: TextSelection(
          baseOffset: res.selectionStart, extentOffset: res.selectionEnd),
    );
  }

  void _smartTab(bool outdent) {
    final sel = _codeController.selection;
    final res = _engine.handleTab(
      _codeController.text,
      sel.isValid ? sel.start : 0,
      sel.isValid ? sel.end : 0,
      outdent: outdent,
    );
    _codeController.value = TextEditingValue(
      text: res.text,
      selection: TextSelection(
          baseOffset: res.selectionStart, extentOffset: res.selectionEnd),
    );
  }

  Future<void> _evalInPausedFrame() async {
    final pause = _activePause;
    final expr = _evalController.text.trim();
    if (pause == null || expr.isEmpty) return;
    try {
      final val = await pause.evaluate(expr);
      if (mounted) {
        setState(() => _liveEvalOutput = '$expr => ${qudsFormatValue(val)}');
      }
    } catch (err) {
      if (mounted) {
        setState(() => _liveEvalOutput = 'Error: $err');
      }
    }
  }

  @override
  void dispose() {
    _pauseSub?.cancel();
    _resumeSub?.cancel();
    _codeController.dispose();
    _editorFocus.dispose();
    _evalController.dispose();
    _inspectorTabs.dispose();
    _debugger.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: _isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'IBMPlexSansArabic',
      colorSchemeSeed: const Color(0xFF2563EB),
      scaffoldBackgroundColor:
          _isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9),
    );

    return Theme(
      data: theme,
      child: Directionality(
        textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: Column(
            children: [
              _buildToolbar(theme),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Left Pane: Quds Code Editor
                      Expanded(
                        flex: 5,
                        child: QudsCodeEditorView(
                          controller: _codeController,
                          focusNode: _editorFocus,
                          palette: _palette,
                          analysis: _analysis,
                          breakpoints: _breakpoints,
                          pausedLine: _activePause?.span.line,
                          completions: _completions,
                          signatureHelp: _signatureHelp,
                          onToggleBreakpoint: (line) {
                            setState(() {
                              if (!_breakpoints.remove(line)) {
                                _breakpoints.add(line);
                              }
                            });
                            _debugger.setLineBreakpoints(
                                _preset.fileName, _breakpoints);
                          },
                          onApplyCompletion: _applyCompletion,
                          onApplyQuickFix: _applyQuickFix,
                          onSmartEnter: () {},
                          onSmartTab: _smartTab,
                          onFormat: _formatCode,
                          onToggleComment: _toggleComment,
                          isArabic: _isArabic,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Right Pane: Visual Interactive Canvas + Inspector
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            Expanded(flex: 6, child: _buildVisualStage(theme)),
                            const SizedBox(height: 12),
                            Expanded(
                                flex: 4, child: _buildInspectorPanel(theme)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    final surface = _isDark ? const Color(0xFF0F172A) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.functions_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 8),
              Text(
                _isArabic ? 'استوديو قُدس العلمي' : 'Quds Scientific Studio',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
            ],
          ),

          // Preset selector
          DropdownButtonHideUnderline(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                key: const Key('preset_dropdown'),
                value: _preset.id,
                isDense: true,
                items: [
                  for (final p in studioPresets)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        _isArabic ? p.titleAr : p.titleEn,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  final target = studioPresets.firstWhere((p) => p.id == id);
                  _selectPreset(target);
                },
              ),
            ),
          ),

          // Policy mode selector
          SegmentedButton<StudioPolicyMode>(
            key: const Key('policy_selector'),
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontFamily: 'IBMPlexSansArabic',
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            segments: [
              ButtonSegment(
                value: StudioPolicyMode.scientific,
                label: Text(_isArabic ? 'علمي' : 'Scientific'),
              ),
              ButtonSegment(
                value: StudioPolicyMode.strictSandbox,
                label: Text(_isArabic ? 'مقيّد' : 'Sandbox'),
              ),
              ButtonSegment(
                value: StudioPolicyMode.systemBridge,
                label: Text(_isArabic ? 'جسر النظام' : 'Bridge'),
              ),
            ],
            selected: {_policyMode},
            onSelectionChanged: (set) => _switchPolicy(set.first),
          ),

          // Run & Debugger controls
          if (!_running)
            FilledButton.icon(
              key: const Key('btn_run'),
              onPressed: _runCode,
              icon: const Icon(Icons.play_arrow_rounded, size: 17),
              label: Text(_isArabic ? 'تشغيل' : 'Run',
                  style: const TextStyle(fontSize: 12.5)),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            )
          else if (_activePause != null) ...[
            FilledButton.icon(
              key: const Key('btn_continue'),
              onPressed: _debugger.continueRun,
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(_isArabic ? 'متابعة' : 'Continue',
                  style: const TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                visualDensity: VisualDensity.compact,
              ),
            ),
            OutlinedButton.icon(
              key: const Key('btn_step_over'),
              onPressed: _debugger.stepOver,
              icon: const Icon(Icons.redo_rounded, size: 15),
              label: Text(_isArabic ? 'تخطّي' : 'Step Over',
                  style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
            OutlinedButton.icon(
              key: const Key('btn_step_into'),
              onPressed: _debugger.stepInto,
              icon:
                  const Icon(Icons.subdirectory_arrow_right_rounded, size: 15),
              label: Text(_isArabic ? 'دخول' : 'Step Into',
                  style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),
            IconButton(
              key: const Key('btn_stop'),
              tooltip: _isArabic ? 'إيقاف' : 'Stop',
              onPressed: _session.stop,
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Color(0xFFEF4444)),
              visualDensity: VisualDensity.compact,
            ),
          ] else
            OutlinedButton.icon(
              key: const Key('btn_stop_running'),
              onPressed: _session.stop,
              icon: const Icon(Icons.stop_rounded,
                  size: 16, color: Color(0xFFEF4444)),
              label: Text(_isArabic ? 'إيقاف' : 'Stop'),
              style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact),
            ),

          // Language & Theme toggles
          IconButton(
            tooltip: _isArabic ? 'English' : 'العربية',
            onPressed: () => setState(() => _isArabic = !_isArabic),
            icon: const Icon(Icons.translate_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: _isDark ? 'Light Mode' : 'Dark Mode',
            onPressed: () {
              setState(() => _isDark = !_isDark);
              _codeController.palette = _palette;
            },
            icon: Icon(
              _isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildVisualStage(ThemeData theme) {
    final surface = _isDark ? const Color(0xFF0F172A) : Colors.white;
    final res = _lastResult;
    final scene = res?.lastGeometryScene;
    final plot = res?.lastPlot;
    final tables =
        res?.outputs.whereType<QudsTableOutput>().toList() ?? const [];

    final interactiveInputs =
        scene?.interactiveInputs ?? plot?.interactiveInputs ?? const [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded,
                  size: 16, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isArabic
                      ? 'اللوحة التفاعلية والنتائج البصرية'
                      : 'Interactive Visual & Geometry Stage',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (res != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${res.stepsExecuted} steps · ${res.elapsed.inMilliseconds}ms',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: const ['IBMPlexSansArabic'],
                    fontSize: 11,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: scene != null
                ? QudsGeometryCanvas(
                    scene: scene,
                    isDark: _isDark,
                    onDragPoint: (id, x, y) => _updateInteractive({
                      id: {'x': x, 'y': y},
                    }),
                  )
                : plot != null
                    ? Column(
                        children: [
                          Expanded(
                              child:
                                  QudsPlotCanvas(plot: plot, isDark: _isDark)),
                          if (tables.isNotEmpty)
                            QudsTableCard(table: tables.first),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              res != null && !res.succeeded
                                  ? Icons.shield_outlined
                                  : Icons.science_outlined,
                              size: 36,
                              color: res != null && !res.succeeded
                                  ? const Color(0xFFEF4444)
                                  : theme.hintColor,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              res != null && !res.succeeded
                                  ? '${res.error}'
                                  : (_isArabic
                                      ? _preset.subtitleAr
                                      : 'Press Run to execute Quds code and visualize results.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: res != null && !res.succeeded
                                    ? const Color(0xFFEF4444)
                                    : theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
          if (interactiveInputs.isNotEmpty) ...[
            const SizedBox(height: 8),
            QudsInteractiveControlsBar(
              inputs: interactiveInputs,
              onChanged: (id, val) => _updateInteractive({id: val}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInspectorPanel(ThemeData theme) {
    final surface = _isDark ? const Color(0xFF0F172A) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          TabBar(
            controller: _inspectorTabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: _isArabic ? 'المخرجات (Console)' : 'Console'),
              Tab(
                text: _isArabic
                    ? 'مساحة العمل (${_session.workspace.length})'
                    : 'Workspace (${_session.workspace.length})',
              ),
              Tab(
                text: _activePause != null
                    ? (_isArabic
                        ? 'المصحح (متوقف L${_activePause!.span.line})'
                        : 'Debugger (Paused L${_activePause!.span.line})')
                    : (_isArabic ? 'المصحح (Debugger)' : 'Debugger'),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _inspectorTabs,
              children: [
                _buildConsoleTab(theme),
                _buildWorkspaceTab(theme),
                _buildDebuggerTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsoleTab(ThemeData theme) {
    final res = _lastResult;
    if (res == null) {
      return Center(
        child: Text(
          _isArabic ? 'لا توجد مخرجات بعد' : 'No console output yet.',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
      );
    }
    return ListView(
      key: const Key('console_output_list'),
      padding: const EdgeInsets.all(10),
      children: [
        for (final line in res.printedLines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SelectableText(
              line,
              style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['IBMPlexSansArabic'],
                  fontSize: 12),
            ),
          ),
        if (!res.succeeded && res.error != null)
          SelectableText(
            '${res.error}',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['IBMPlexSansArabic'],
              fontSize: 12,
              color: Color(0xFFEF4444),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkspaceTab(ThemeData theme) {
    final entries = _session.workspace.values.toList();
    if (entries.isEmpty) {
      return Center(
        child: Text(
          _isArabic ? 'مساحة العمل فارغة' : 'Workspace is empty.',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: entries.length,
      separatorBuilder: (_, __) =>
          Divider(height: 10, color: theme.dividerColor.withValues(alpha: 0.2)),
      itemBuilder: (context, idx) {
        final e = entries[idx];
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  e.name,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['IBMPlexSansArabic'],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(
                  e.typeName,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['IBMPlexSansArabic'],
                    fontSize: 11.5,
                    color: theme.hintColor,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  e.summary,
                  style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: ['IBMPlexSansArabic'],
                      fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebuggerTab(ThemeData theme) {
    final pause = _activePause;
    if (pause == null) {
      return Center(
        child: Text(
          _isArabic
              ? 'اضغط على رقم أي سطر في المحرر لوضع نقطة توقف (Breakpoint) ثم شغّل الكود.'
              : 'Click any line number in the editor gutter to set a breakpoint, then press Run.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.pause_circle_filled_rounded,
                  size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Paused at ${pause.span.file}:${pause.span.line} '
                  '(${pause.stackFrames.first.functionName})',
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['IBMPlexSansArabic'],
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: ListView(
                children: [
                  for (final entry in pause.locals.entries)
                    Text(
                      '${entry.key} = ${qudsSummarizeValue(entry.value)}',
                      style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: ['IBMPlexSansArabic'],
                          fontSize: 11.5),
                    ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    key: const Key('debug_eval_input'),
                    controller: _evalController,
                    onSubmitted: (_) => _evalInPausedFrame(),
                    style: const TextStyle(
                        fontFamily: 'JetBrainsMono', fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Evaluate expression in frame (e.g. total + i)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                key: const Key('btn_debug_eval'),
                onPressed: _evalInPausedFrame,
                child: Text(_isArabic ? 'تقييم' : 'Eval',
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (_liveEvalOutput != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  _liveEvalOutput!,
                  key: const Key('debug_eval_result'),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.5,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
