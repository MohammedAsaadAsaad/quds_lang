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
import 'notebook_panel.dart';
import 'presets.dart';
import 'viz2_widgets.dart';
import 'viz_widgets.dart';
import 'workspace_panel.dart';

class QudsStudioPage extends StatefulWidget {
  const QudsStudioPage({
    super.key,
    this.initialPresetIndex = 0,
    this.initialArabic = true,
    this.initialDark = true,
    this.autoRunInitial = true,
    this.autoPlayAnimations = false,
  });

  final int initialPresetIndex;
  final bool initialArabic;
  final bool initialDark;
  final bool autoRunInitial;
  final bool autoPlayAnimations;

  @override
  State<QudsStudioPage> createState() => _QudsStudioPageState();
}

class _QudsStudioPageState extends State<QudsStudioPage>
    with SingleTickerProviderStateMixin {
  late bool _isArabic;
  late bool _isDark;
  late StudioPreset _preset;
  late StudioPolicyMode _policyMode;

  late QudsWorkspace _projectWorkspace;
  bool _workspaceMode = false;
  String _activeWorkspaceFile = 'main.quds';

  late QudsDebugController _debugger;
  late QudsProfiler _profiler;
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
  final ValueNotifier<QudsRunResult?> _visualResult =
      ValueNotifier<QudsRunResult?>(null);
  bool _running = false;
  bool _updatingInteractive = false;
  Map<String, Object?>? _pendingInteractivePatch;
  String? _liveEvalOutput;

  // Bytecode VM, Time-Travel + Profiler, and 60fps Animation state
  bool _preferBytecode = false;
  bool _enableProfiling = false;
  Timer? _animTimer;
  bool _animPlaying = false;
  double _animSpeed = 1.0;

  int _mobileTabIndex = 0;

  // Fully customizable policy parameters (proving policies are host-defined,
  // not hardcoded to any single domain like "scientific").
  int _customMaxSteps = 150000;
  int _customTimeoutSec = 6;
  bool _customAllowMutation = true;
  bool _customAllowClasses = true;
  bool _customAllowAsync = true;
  final Set<String> _customLibraries = {
    'quds:math',
    'quds:core',
    'quds:collection',
    'quds:text',
    'quds:json',
    'quds:async',
    'quds:ext',
    'quds:viz',
    'quds:data',
    'dart:math',
    'dart:convert',
  };
  bool _customAllowSensors = false;

  String get _activeFileName =>
      _workspaceMode ? _activeWorkspaceFile : _preset.fileName;

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
    _enableProfiling = _preset.id == 'profiler_bytecode_lab';
    _projectWorkspace = QudsWorkspace.scientificProjectTemplate();
    _activeWorkspaceFile = _projectWorkspace.entryPoint;
    _inspectorTabs = TabController(length: 6, vsync: this);

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
        if (mounted) _runCode(switchMobileTab: false);
      });
    }
  }

  void _buildRuntime() {
    _pauseSub?.cancel();
    _resumeSub?.cancel();

    _debugger = QudsDebugController(recordHistory: _enableProfiling);
    _profiler = QudsProfiler(enabled: _enableProfiling);
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
      StudioPolicyMode.standard => QudsExecutionPolicy.standard(
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
      StudioPolicyMode.custom => QudsExecutionPolicy(
          name: 'custom',
          maxSteps: _customMaxSteps,
          timeout: Duration(seconds: _customTimeoutSec),
          allowMutation: _customAllowMutation,
          allowClasses: _customAllowClasses,
          allowAsync: _customAllowAsync,
          allowedLibraries: {
            ..._customLibraries,
            if (_customAllowSensors) 'host:sensors',
          },
          capabilities: [
            if (_customAllowSensors) QudsCapability.custom('sensors.read'),
          ],
        ),
    };

    _session = QudsSession(
      policy: policy,
      debugger: _debugger,
      profiler: _profiler,
      allowTopLevelRebind: true,
      hostModules: [sensorsMod],
      projectWorkspace: _projectWorkspace,
    );
    _engine = QudsEditorEngine(session: _session);

    _pauseSub = _debugger.onPaused.listen((pause) {
      if (!mounted) return;
      setState(() {
        _activePause = pause;
        _inspectorTabs.index = 2; // Jump to Debugger tab on pause!
        _mobileTabIndex = 2;
      });
    });
    _resumeSub = _debugger.onResumed.listen((_) {
      if (!mounted) return;
      setState(() => _activePause = null);
    });
  }

  void _onEditorChanged() {
    if (_workspaceMode) {
      final current = _projectWorkspace.readFile(_activeWorkspaceFile);
      if (current != _codeController.text) {
        _projectWorkspace.writeFile(_activeWorkspaceFile, _codeController.text);
      }
    }
    _reanalyze();
  }

  void _reanalyze() {
    final text = _codeController.text;
    final fileName = _activeFileName;
    final analysis = _engine.analyze(text, file: fileName);
    final sel = _codeController.selection;
    final offset = sel.isValid ? sel.baseOffset : text.length;
    final completions = _engine.completeAt(text, offset, file: fileName);
    final sig = _engine.signatureHelpAt(text, offset, file: fileName);
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

  Future<void> _runCode({bool switchMobileTab = true}) async {
    if (_running) return;
    _stopAnimTimer();
    if (_workspaceMode) {
      _projectWorkspace.writeFile(_activeWorkspaceFile, _codeController.text);
    }
    _debugger.setLineBreakpoints(_activeFileName, _breakpoints);
    _debugger.recordHistory = _enableProfiling;
    _profiler.enabled = _enableProfiling;
    setState(() {
      _running = true;
      _liveEvalOutput = null;
    });
    final res = _workspaceMode
        ? await _session.runProject(preferBytecode: _preferBytecode)
        : await _session.run(
            _codeController.text,
            file: _preset.fileName,
            preferBytecode: _preferBytecode,
          );
    if (!mounted) return;
    final hasVisual = res.lastGeometryScene != null ||
        res.lastPlot != null ||
        res.lastSurface3D != null ||
        res.lastVectorField != null ||
        res.lastGraph != null ||
        res.lastForm != null ||
        res.outputs.whereType<QudsTableOutput>().isNotEmpty;
    setState(() {
      _running = false;
      _activePause = null;
      _lastResult = res;
      if (switchMobileTab) {
        _mobileTabIndex = hasVisual ? 1 : 2;
      }
      if (_enableProfiling && _profiler.totalCalls > 0 && !hasVisual) {
        _inspectorTabs.index = 3; // Jump to Profiler / Call Tree tab
      }
    });
    _visualResult.value = res;
    _reanalyze();
    final anim = res.lastGeometryScene?.animation ??
        res.lastPlot?.animation ??
        res.lastSurface3D?.animation ??
        res.lastVectorField?.animation;
    if (widget.autoPlayAnimations &&
        res.succeeded &&
        (anim?.autoPlay ?? false)) {
      _startAnimTimer();
    }
  }

  void _openWorkspaceFile(String path, {bool switchToEditorOnMobile = true}) {
    final content = _projectWorkspace.readFile(path);
    if (content == null) return;
    if (_workspaceMode) {
      _projectWorkspace.writeFile(_activeWorkspaceFile, _codeController.text);
    }
    _stopAnimTimer();
    _session.stop();
    setState(() {
      _workspaceMode = true;
      _activeWorkspaceFile = path;
      _breakpoints = {};
      if (switchToEditorOnMobile) {
        _mobileTabIndex = 0;
      }
    });
    _codeController.removeListener(_onEditorChanged);
    _codeController.text = content;
    _codeController.addListener(_onEditorChanged);
    _reanalyze();
  }

  Future<void> _runWorkspaceProject() async {
    if (!_workspaceMode) {
      _openWorkspaceFile(
        _projectWorkspace.entryPoint,
        switchToEditorOnMobile: false,
      );
    }
    await _runCode(switchMobileTab: true);
  }

  void _createWorkspaceFile(String path, String initialContent) {
    final norm = QudsWorkspace.normalizePath(path);
    _projectWorkspace.writeFile(norm, initialContent);
    _openWorkspaceFile(norm);
  }

  void _createWorkspaceFolder(String folderPath) {
    _projectWorkspace.createFolder(folderPath);
    setState(() {});
  }

  void _deleteWorkspaceFile(String path) {
    _projectWorkspace.deleteFile(path);
    if (_workspaceMode && _activeWorkspaceFile == path) {
      _openWorkspaceFile(_projectWorkspace.entryPoint,
          switchToEditorOnMobile: false);
    } else {
      setState(() {});
    }
  }

  void _resetWorkspaceTemplate() {
    _projectWorkspace = QudsWorkspace.scientificProjectTemplate();
    _session.attachWorkspace(_projectWorkspace);
    _openWorkspaceFile(
      _projectWorkspace.entryPoint,
      switchToEditorOnMobile: false,
    );
  }

  void _stopAnimTimer() {
    _animTimer?.cancel();
    _animTimer = null;
    _animPlaying = false;
  }

  void _startAnimTimer() {
    _animTimer?.cancel();
    setState(() => _animPlaying = true);
    _animTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!mounted || !_animPlaying) return;
      _stepAnimFrame();
    });
  }

  void _toggleAnimPlay() {
    if (_animPlaying) {
      setState(_stopAnimTimer);
      return;
    }
    _startAnimTimer();
  }

  String _activeExecutionSource() => _workspaceMode
      ? (_projectWorkspace.readFile(_projectWorkspace.entryPoint) ??
          _codeController.text)
      : _codeController.text;

  String _activeExecutionFile() =>
      _workspaceMode ? _projectWorkspace.entryPoint : _preset.fileName;

  Future<void> _stepAnimFrame() async {
    if (_updatingInteractive || _running) return;
    _updatingInteractive = true;
    try {
      final res = await _session.stepFrame(
        0.033 * _animSpeed,
        source: _activeExecutionSource(),
        file: _activeExecutionFile(),
      );
      if (!mounted) return;
      _lastResult = res;
      _visualResult.value = res;
    } finally {
      _updatingInteractive = false;
    }
  }

  Future<void> _seekAnimTime(double targetTime) async {
    if (_updatingInteractive || _running) return;
    _updatingInteractive = true;
    try {
      final res = await _session.seekTime(
        targetTime,
        source: _activeExecutionSource(),
        file: _activeExecutionFile(),
      );
      if (!mounted) return;
      _lastResult = res;
      _visualResult.value = res;
    } finally {
      _updatingInteractive = false;
    }
  }

  Future<void> _resetAnim() async {
    _stopAnimTimer();
    _session.resetAnimation();
    final res = await _session.updateInteractiveInputs(
      {},
      source: _activeExecutionSource(),
      file: _activeExecutionFile(),
    );
    if (!mounted) return;
    setState(() => _lastResult = res);
    _visualResult.value = res;
  }

  Future<void> _updateInteractive(Map<String, Object?> patch) async {
    if (_running) return;
    // Coalesce rapid 60Hz–120Hz touch/slider events into a single-flight loop
    // so interpreter frames never pile up on mobile devices.
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
          source: _activeExecutionSource(),
          file: _activeExecutionFile(),
        );
        if (!mounted) return;
        _lastResult = res;
        // Update ONLY the visual canvas & sliders via ValueNotifier (no editor rebuild!)
        _visualResult.value = res;
      }
    } finally {
      _updatingInteractive = false;
    }
  }

  void _selectPreset(StudioPreset preset) {
    _stopAnimTimer();
    _session.stop();
    _pendingInteractivePatch = null;
    setState(() {
      _workspaceMode = false;
      _preset = preset;
      _policyMode = preset.defaultPolicy;
      _breakpoints = Set<int>.from(preset.defaultBreakpoints);
      _enableProfiling = preset.id == 'profiler_bytecode_lab';
      _lastResult = null;
      _activePause = null;
      _running = false;
    });
    _visualResult.value = null;
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

  Future<void> _openCustomPolicyDialog() async {
    var steps = _customMaxSteps;
    var timeoutSec = _customTimeoutSec;
    var allowMutation = _customAllowMutation;
    var allowClasses = _customAllowClasses;
    var allowAsync = _customAllowAsync;
    var allowSensors = _customAllowSensors;
    final libs = Set<String>.from(_customLibraries);

    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(
              _isArabic
                  ? 'تخصيص سياسة وقيود المفسّر'
                  : 'Customize Execution Policy',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isArabic
                        ? 'حد الخطوات (maxSteps): $steps'
                        : 'Max steps: $steps',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  Slider(
                    value: steps.toDouble().clamp(5000, 300000),
                    min: 5000,
                    max: 300000,
                    divisions: 59,
                    onChanged: (v) => setModalState(() => steps = v.round()),
                  ),
                  Text(
                    _isArabic
                        ? 'المهلة الزمنية (ثوانٍ): $timeoutSec'
                        : 'Timeout (seconds): $timeoutSec',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  Slider(
                    value: timeoutSec.toDouble().clamp(1, 30),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    onChanged: (v) =>
                        setModalState(() => timeoutSec = v.round()),
                  ),
                  SwitchListTile(
                    key: const Key('switch_allow_mutation'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isArabic
                          ? 'السماح بالمتغيرات القابلة للتعديل (var)'
                          : 'Allow mutable variables (var)',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    value: allowMutation,
                    onChanged: (v) => setModalState(() => allowMutation = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isArabic ? 'السماح بالأصناف (class)' : 'Allow classes',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    value: allowClasses,
                    onChanged: (v) => setModalState(() => allowClasses = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isArabic
                          ? 'السماح بـ async / await'
                          : 'Allow async / await',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    value: allowAsync,
                    onChanged: (v) => setModalState(() => allowAsync = v),
                  ),
                  SwitchListTile(
                    key: const Key('switch_allow_sensors'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isArabic
                          ? 'منح صلاحية host:sensors (sensors.read)'
                          : 'Grant host:sensors (sensors.read)',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    value: allowSensors,
                    onChanged: (v) => setModalState(() => allowSensors = v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isArabic ? 'المكتبات المسموحة:' : 'Allowed libraries:',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final lib in const [
                        'quds:math',
                        'quds:viz',
                        'quds:json',
                        'quds:async',
                        'quds:text',
                      ])
                        FilterChip(
                          label:
                              Text(lib, style: const TextStyle(fontSize: 11)),
                          selected: libs.contains(lib),
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) => setModalState(() {
                            if (selected) {
                              libs.add(lib);
                            } else {
                              libs.remove(lib);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(_isArabic ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                key: const Key('btn_apply_custom_policy'),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(_isArabic ? 'تطبيق القيود' : 'Apply Policy'),
              ),
            ],
          ),
        ),
      ),
    );

    if (applied == true && mounted) {
      setState(() {
        _customMaxSteps = steps;
        _customTimeoutSec = timeoutSec;
        _customAllowMutation = allowMutation;
        _customAllowClasses = allowClasses;
        _customAllowAsync = allowAsync;
        _customAllowSensors = allowSensors;
        _customLibraries
          ..clear()
          ..addAll(libs);
        _policyMode = StudioPolicyMode.custom;
        _running = false;
        _activePause = null;
      });
      _session.stop();
      _rebuildSessionKeepingCode(_codeController.text);
    }
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
    _stopAnimTimer();
    _pauseSub?.cancel();
    _resumeSub?.cancel();
    _visualResult.dispose();
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 840;
            final workspacePanel = QudsWorkspacePanel(
              workspace: _projectWorkspace,
              activeFile: _activeWorkspaceFile,
              workspaceMode: _workspaceMode,
              isArabic: _isArabic,
              isDark: _isDark,
              running: _running,
              onOpenFile: (path) => _openWorkspaceFile(path),
              onRunProject: _runWorkspaceProject,
              onCreateFile: _createWorkspaceFile,
              onCreateFolder: _createWorkspaceFolder,
              onDeleteFile: _deleteWorkspaceFile,
              onResetTemplate: _resetWorkspaceTemplate,
            );

            final editorView = Column(
              children: [
                if (_workspaceMode)
                  Container(
                    key: const Key('workspace_active_file_bar'),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open_rounded,
                            size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_projectWorkspace.name} / $_activeWorkspaceFile',
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF38BDF8),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _isArabic
                              ? 'تشغيل: ${_projectWorkspace.entryPoint}'
                              : 'Entry: ${_projectWorkspace.entryPoint}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: QudsCodeEditorView(
                    controller: _codeController,
                    focusNode: _editorFocus,
                    palette: _palette,
                    analysis: _analysis,
                    breakpoints: _breakpoints,
                    pausedLine: _activePause?.span.file == _activeFileName
                        ? _activePause?.span.line
                        : null,
                    completions: _completions,
                    signatureHelp: _signatureHelp,
                    onToggleBreakpoint: (line) {
                      setState(() {
                        if (!_breakpoints.remove(line)) {
                          _breakpoints.add(line);
                        }
                      });
                      _debugger.setLineBreakpoints(
                          _activeFileName, _breakpoints);
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
              ],
            );

            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    _buildToolbar(theme),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isCompact ? 8 : 12),
                        child: isCompact
                            ? IndexedStack(
                                index: _mobileTabIndex,
                                children: [
                                  editorView,
                                  _buildVisualStage(theme),
                                  _buildInspectorPanel(theme, workspacePanel),
                                  QudsNotebookPanel(
                                    isArabic: _isArabic,
                                    isDark: _isDark,
                                  ),
                                  workspacePanel,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(flex: 5, child: editorView),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        Expanded(
                                            flex: 6,
                                            child: _buildVisualStage(theme)),
                                        const SizedBox(height: 12),
                                        Expanded(
                                            flex: 4,
                                            child: _buildInspectorPanel(
                                                theme, workspacePanel)),
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
              bottomNavigationBar: isCompact
                  ? NavigationBar(
                      key: const Key('mobile_bottom_nav'),
                      selectedIndex: _mobileTabIndex,
                      height: 62,
                      onDestinationSelected: (idx) =>
                          setState(() => _mobileTabIndex = idx),
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.code_rounded),
                          label: _isArabic ? 'المحرر' : 'Editor',
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.auto_graph_rounded),
                          label: _isArabic ? 'اللوحة' : 'Canvas',
                        ),
                        NavigationDestination(
                          icon: Icon(_activePause != null
                              ? Icons.bug_report_rounded
                              : Icons.terminal_rounded),
                          label: _isArabic ? 'المصحح' : 'Console',
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.menu_book_rounded),
                          label: _isArabic ? 'الدفتر' : 'Notebook',
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.folder_copy_rounded),
                          label: _isArabic ? 'المشروع' : 'Project',
                        ),
                      ],
                    )
                  : null,
            );
          },
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
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
                  isExpanded: true,
                  items: [
                    for (final p in studioPresets)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          _isArabic ? p.titleAr : p.titleEn,
                          style: const TextStyle(fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
          ),

          // Policy selector (example templates + full custom policy builder)
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
                value: StudioPolicyMode.standard,
                label: Text(_isArabic ? 'قياسي' : 'Standard'),
              ),
              ButtonSegment(
                value: StudioPolicyMode.strictSandbox,
                label: Text(_isArabic ? 'مقيّد' : 'Sandbox'),
              ),
              ButtonSegment(
                value: StudioPolicyMode.systemBridge,
                label: Text(_isArabic ? 'جسر النظام' : 'Bridge'),
              ),
              if (_policyMode == StudioPolicyMode.custom)
                ButtonSegment(
                  value: StudioPolicyMode.custom,
                  label: Text(_isArabic ? 'مخصّص' : 'Custom'),
                ),
            ],
            selected: {_policyMode},
            onSelectionChanged: (set) => _switchPolicy(set.first),
          ),

          OutlinedButton.icon(
            key: const Key('btn_custom_policy'),
            onPressed: _openCustomPolicyDialog,
            icon: const Icon(Icons.tune_rounded, size: 15),
            label: Text(
              _isArabic ? 'تخصيص القيود' : 'Custom Policy',
              style: const TextStyle(fontSize: 11.5),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
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

          // Bytecode VM & Profiler/Time-Travel mode chips
          FilterChip(
            key: const Key('chip_bytecode_vm'),
            selected: _preferBytecode,
            onSelected: (v) => setState(() => _preferBytecode = v),
            label: Text(
              _isArabic ? '⚡ Bytecode' : '⚡ Bytecode',
              style: const TextStyle(fontSize: 11),
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          FilterChip(
            key: const Key('chip_profiler_timetravel'),
            selected: _enableProfiling,
            onSelected: (v) => setState(() => _enableProfiling = v),
            label: Text(
              _isArabic ? 'تتبع / Time-Travel' : 'Trace / Time-Travel',
              style: const TextStyle(fontSize: 11),
            ),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
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
    return ValueListenableBuilder<QudsRunResult?>(
      valueListenable: _visualResult,
      builder: (context, res, _) {
        final scene = res?.lastGeometryScene;
        final surface3d = res?.lastSurface3D;
        final vectorField = res?.lastVectorField;
        final graph = res?.lastGraph;
        final form = res?.lastForm;
        final plot = res?.lastPlot;
        final animSpec = res?.animationSpec;
        final tables =
            res?.outputs.whereType<QudsTableOutput>().toList() ?? const [];
        final interactiveInputs = scene?.interactiveInputs ??
            surface3d?.interactiveInputs ??
            vectorField?.interactiveInputs ??
            graph?.interactiveInputs ??
            form?.interactiveInputs ??
            plot?.interactiveInputs ??
            const <QudsInteractiveInput>[];

        final elapsedText = res == null
            ? ''
            : res.elapsed.inMilliseconds >= 10
                ? '${res.elapsed.inMilliseconds}ms'
                : '${(res.elapsed.inMicroseconds / 1000).toStringAsFixed(1)}ms';
        final engineBadge =
            res == null ? '' : (res.usedBytecodeVm ? '⚡ VM · ' : '');

        Widget stageBody;
        if (scene != null) {
          stageBody = QudsGeometryCanvas(
            scene: scene,
            isDark: _isDark,
            onDragPoint: (id, x, y) => _updateInteractive({
              id: {'x': x, 'y': y},
            }),
          );
        } else if (surface3d != null && vectorField != null) {
          stageBody = Column(
            children: [
              Expanded(
                flex: 6,
                child: QudsSurface3DCanvas(surface: surface3d, isDark: _isDark),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 4,
                child:
                    QudsVectorFieldCanvas(field: vectorField, isDark: _isDark),
              ),
            ],
          );
        } else if (surface3d != null) {
          stageBody = QudsSurface3DCanvas(surface: surface3d, isDark: _isDark);
        } else if (vectorField != null) {
          stageBody =
              QudsVectorFieldCanvas(field: vectorField, isDark: _isDark);
        } else if (graph != null) {
          stageBody = QudsGraphCanvas(graph: graph, isDark: _isDark);
        } else if (form != null) {
          stageBody = SingleChildScrollView(
            child: QudsFormOutputCard(form: form, isDark: _isDark),
          );
        } else if (plot != null) {
          stageBody = Column(
            children: [
              Expanded(child: QudsPlotCanvas(plot: plot, isDark: _isDark)),
              if (tables.isNotEmpty) QudsTableCard(table: tables.first),
            ],
          );
        } else if (tables.isNotEmpty) {
          stageBody = SingleChildScrollView(
            child: QudsTableCard(table: tables.first),
          );
        } else {
          stageBody = Center(
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
          );
        }

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
                      '$engineBadge${res.stepsExecuted} steps · $elapsedText',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontFamilyFallback: const ['IBMPlexSansArabic'],
                        fontSize: 11,
                        color: res.usedBytecodeVm
                            ? const Color(0xFF10B981)
                            : theme.hintColor,
                      ),
                    ),
                  ],
                ],
              ),
              if (animSpec != null) ...[
                const SizedBox(height: 8),
                QudsAnimationControlsBar(
                  spec: animSpec,
                  playing: _animPlaying,
                  speed: _animSpeed,
                  isArabic: _isArabic,
                  onTogglePlay: _toggleAnimPlay,
                  onStepFrame: _stepAnimFrame,
                  onReset: _resetAnim,
                  onSpeedChanged: (s) => setState(() => _animSpeed = s),
                  onSeekTime: _seekAnimTime,
                ),
              ],
              const SizedBox(height: 8),
              Expanded(child: stageBody),
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
      },
    );
  }

  Widget _buildInspectorPanel(ThemeData theme, Widget workspacePanel) {
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
                    : (_isArabic ? 'المصحح / Time-Travel' : 'Debugger'),
              ),
              Tab(
                text: _isArabic
                    ? 'التحليل (${_profiler.totalCalls})'
                    : 'Profiler (${_profiler.totalCalls})',
              ),
              Tab(text: _isArabic ? 'الدفتر التفاعلي' : 'Notebook'),
              Tab(
                key: const Key('inspector_project_tab'),
                text: _isArabic
                    ? 'المشروع (${_projectWorkspace.listFiles().length})'
                    : 'Project (${_projectWorkspace.listFiles().length})',
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
                _buildProfilerTab(theme),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: QudsNotebookPanel(
                    isArabic: _isArabic,
                    isDark: _isDark,
                  ),
                ),
                workspacePanel,
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
      final hist = _debugger.history;
      if (hist.isNotEmpty) {
        final cur = _debugger.currentHistoryEntry ?? hist.last;
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 16, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _isArabic
                          ? 'Time-Travel: خطوة ${_debugger.historyIndex + 1}/${hist.length} (سطر L${cur.span.line})'
                          : 'Time-Travel: step ${_debugger.historyIndex + 1}/${hist.length} (L${cur.span.line})',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('btn_timetravel_back'),
                    onPressed: _debugger.canStepBack
                        ? () => setState(() => _debugger.stepBack())
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded, size: 18),
                    tooltip: _isArabic ? 'خطوة للخلف (Step Back)' : 'Step Back',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    key: const Key('btn_timetravel_forward'),
                    onPressed: _debugger.canStepForward
                        ? () => setState(() => _debugger.stepForward())
                        : null,
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    tooltip: _isArabic
                        ? 'خطوة للأمام (Step Forward)'
                        : 'Step Forward',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (hist.length > 1)
                Slider(
                  value: _debugger.historyIndex
                      .toDouble()
                      .clamp(0, (hist.length - 1).toDouble()),
                  min: 0,
                  max: (hist.length - 1).toDouble(),
                  divisions: hist.length - 1,
                  onChanged: (v) =>
                      setState(() => _debugger.jumpToHistory(v.round())),
                ),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: ListView(
                    children: [
                      for (final e in cur.locals.entries)
                        Text(
                          '${e.key} = ${qudsSummarizeValue(e.value)}',
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: ['IBMPlexSansArabic'],
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Text(
          _isArabic
              ? 'اضغط على رقم أي سطر لوضع نقطة توقف (Breakpoint) أو فعّل «تتبع / Time-Travel» للتنقل للخلف والأمام.'
              : 'Click any line number for a breakpoint, or enable Trace / Time-Travel to scrub execution history.',
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

  Widget _buildProfilerTab(ThemeData theme) {
    final spots = _profiler.hotspots(top: 8);
    final trees = _profiler.callTrees;
    if (spots.isEmpty && trees.isEmpty) {
      return Center(
        child: Text(
          _isArabic
              ? 'فعّل خيار «تتبع / Time-Travel» من الشريط العلوي ثم شغّل الكود لعرض شجرة الاستدعاءات ومناطق السخونة.'
              : 'Enable "Trace / Time-Travel" in the toolbar and press Run to view hotspots & recursive Call Tree.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
      );
    }

    final flattenedCalls = <QudsCallNode>[];
    void visit(QudsCallNode n) {
      if (flattenedCalls.length >= 60) return;
      flattenedCalls.add(n);
      for (final c in n.children) {
        visit(c);
      }
    }

    for (final root in trees) {
      visit(root);
    }

    return Padding(
      key: const Key('quds_profiler_tab'),
      padding: const EdgeInsets.all(10),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(
          children: [
            if (spots.isNotEmpty) ...[
              Text(
                _isArabic
                    ? 'أكثر الأسطر تنفيذاً (Hotspots):'
                    : 'Line Hotspots:',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B)),
              ),
              const SizedBox(height: 4),
              for (final s in spots)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    'L${s.line.toString().padLeft(2)} · ${s.hits} hits · ${(s.totalMicros / 1000).toStringAsFixed(2)}ms',
                    style: const TextStyle(
                        fontFamily: 'JetBrainsMono', fontSize: 11),
                  ),
                ),
              const Divider(height: 16),
            ],
            if (flattenedCalls.isNotEmpty) ...[
              Text(
                _isArabic
                    ? 'شجرة الاستدعاءات (Call Tree — ${_profiler.totalCalls} استدعاء):'
                    : 'Call Tree (${_profiler.totalCalls} calls):',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38BDF8)),
              ),
              const SizedBox(height: 4),
              for (final node in flattenedCalls)
                Padding(
                  padding: EdgeInsets.only(
                      left: (node.depth * 14.0).clamp(0, 120),
                      top: 1.5,
                      bottom: 1.5),
                  child: Text(
                    '${node.depth > 0 ? '└─ ' : ''}${node.name}(${node.argsSummary}) => ${node.returnSummary}',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
