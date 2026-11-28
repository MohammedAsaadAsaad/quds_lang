/// Main Quds Scientific Studio UI combining:
/// - `QudsCodeEditorView` (syntax highlighting, breakpoints, autocomplete, quick fixes)
/// - `QudsSession` + `QudsExecutionPolicy` + `QudsDebugController`
/// - Interactive Geometry Canvas & 2D Plot Canvas (`quds:viz`)
/// - Console, Workspace Table, and Live Debugger Inspector (Stack, Locals, Eval)
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:quds/editor_engine.dart';
import 'package:quds/interpreter.dart';

import 'ai_agent_lab.dart';
import 'benchmark_card.dart';
import 'compile_lab_panel.dart';
import 'editor_widget.dart';
import 'notebook_panel.dart';
import 'preset_gallery.dart';
import 'presets.dart';
import 'project_templates.dart';
import 'standalone_app_page.dart';
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
    this.onDarkModeChanged,
  });

  final int initialPresetIndex;
  final bool initialArabic;
  final bool initialDark;
  final bool autoRunInitial;
  final bool autoPlayAnimations;
  final ValueChanged<bool>? onDarkModeChanged;

  @override
  State<QudsStudioPage> createState() => _QudsStudioPageState();
}

class _QudsStudioPageState extends State<QudsStudioPage>
    with TickerProviderStateMixin {
  late bool _isArabic;
  late bool _isDark;
  late StudioPreset _preset;
  late StudioPolicyMode _policyMode;
  StudioFilterKind _activeFilter = StudioFilterKind.all;

  late QudsWorkspace _projectWorkspace;
  String _activeProjectId = 'orbital_lab';
  bool _workspaceMode = false;
  String _activeWorkspaceFile = 'main.quds';
  WorkspaceBenchComparison _workspaceComparison =
      const WorkspaceBenchComparison();
  String? _workspaceRunStatus;
  int _quickPatchVersion = 1;

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

  // Bytecode VM, Time-Travel + Profiler, and VSync 60/120fps Animation state
  bool _preferBytecode = true;
  bool _enableProfiling = false;
  final Map<String, List<BenchmarkRunRecord>> _benchHistory = {};
  final Map<String, double> _benchVmMs = {};
  final Map<String, double> _benchAstMs = {};
  Ticker? _animTicker;
  Duration? _lastTickElapsed;
  double _measuredFps = 0.0;
  bool _animPlaying = false;
  double _animSpeed = 1.0;
  QudsLineStyleSettings _lineStyle = QudsLineStyleSettings.balanced;
  bool _showLineQualityPanel = false;

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
    'quds:pen',
    'quds:data',
    'quds:assets',
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
    _preferBytecode = true;
    _enableProfiling = _preset.id == 'profiler_bytecode_lab';
    _projectWorkspace = buildOrbitalLabProject();
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
          maxSteps: 400000,
          timeout: const Duration(seconds: 10),
        ),
      StudioPolicyMode.strictSandbox => QudsExecutionPolicy.strictSandbox(
          maxSteps: 40000,
          timeout: const Duration(seconds: 2),
        ),
      StudioPolicyMode.systemBridge => QudsExecutionPolicy.systemBridge(
          capabilities: [
            QudsCapability.custom('sensors.read'),
            QudsCapability.custom('ai.orders.read'),
            QudsCapability.custom('ai.sensors.read'),
          ],
          maxSteps: 500000,
          timeout: const Duration(seconds: 10),
        ),
      StudioPolicyMode.benchmark => QudsExecutionPolicy.standard(
          maxSteps: 180000000,
          maxCallDepth: 256,
          maxCollectionLength: 500000,
          timeout: const Duration(seconds: 30),
        ).copyWith(
          yieldEveryNSteps: 4000,
          capabilities: [
            QudsCapability.custom('ai.orders.read'),
            QudsCapability.custom('ai.sensors.read'),
          ],
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
            'host:ai_tools',
          },
          capabilities: [
            if (_customAllowSensors) QudsCapability.custom('sensors.read'),
            QudsCapability.custom('ai.orders.read'),
            QudsCapability.custom('ai.sensors.read'),
          ],
        ),
    };

    _session = QudsSession(
      policy: policy,
      debugger: _debugger,
      profiler: _profiler,
      allowTopLevelRebind: true,
      hostModules: [sensorsMod, buildAiToolsHostModule()],
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
    if (_workspaceMode &&
        !_projectWorkspace.isBinaryFile(_activeWorkspaceFile)) {
      _projectWorkspace.writeFile(_activeWorkspaceFile, _codeController.text);
    }
    _debugger.setLineBreakpoints(_activeFileName, _breakpoints);
    _debugger.recordHistory = _enableProfiling;
    _profiler.enabled = _enableProfiling;
    setState(() {
      _running = true;
      _liveEvalOutput = null;
    });
    if (_preset.category == StudioCategory.benchmarks) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
    }
    final res = _workspaceMode
        ? await _session.runProject(preferBytecode: _preferBytecode)
        : await _session.run(
            _codeController.text,
            file: _preset.fileName,
            preferBytecode: _preferBytecode,
          );
    if (!mounted) return;
    final isBench = _preset.category == StudioCategory.benchmarks;
    if (isBench) {
      _recordBenchmarkRun(res);
    }
    final hasVisual = isBench ||
        res.lastGeometryScene != null ||
        res.lastPlot != null ||
        res.lastSurface3D != null ||
        res.lastVectorField != null ||
        res.lastGraph != null ||
        res.lastForm != null ||
        res.outputs.whereType<QudsImageOutput>().isNotEmpty ||
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

  void _recordBenchmarkRun(
    QudsRunResult res, {
    double? overrideMs,
    bool isMedianOf3 = false,
    double? minMs,
    double? avgMs,
  }) {
    final ms = overrideMs ?? (res.elapsed.inMicroseconds / 1000.0);
    final summary = res.stdout.trim().isNotEmpty
        ? res.stdout.trim()
        : (res.value != null ? 'result = ${res.value}' : 'OK');
    final rec = BenchmarkRunRecord(
      elapsedMs: ms,
      steps: res.stepsExecuted,
      usedVm: res.usedBytecodeVm,
      succeeded: res.succeeded,
      outputSummary: summary,
      isMedianOf3: isMedianOf3,
      minMs: minMs,
      avgMs: avgMs,
    );
    final list = _benchHistory.putIfAbsent(_preset.id, () => []);
    list.insert(0, rec);
    if (list.length > 10) list.removeLast();
    if (res.succeeded) {
      if (res.usedBytecodeVm) {
        _benchVmMs[_preset.id] = ms;
      } else {
        _benchAstMs[_preset.id] = ms;
      }
    }
  }

  Future<void> _runBenchmarkSingle({required bool useVm}) async {
    if (_running) return;
    setState(() {
      _preferBytecode = useVm;
      _enableProfiling = false;
      _running = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    final res = await _session.run(
      _codeController.text,
      file: _preset.fileName,
      preferBytecode: useVm,
    );
    if (!mounted) return;
    _recordBenchmarkRun(res);
    setState(() {
      _running = false;
      _lastResult = res;
    });
    _visualResult.value = res;
  }

  Future<void> _runBenchmarkMedian3() async {
    if (_running) return;
    setState(() {
      _preferBytecode = true;
      _enableProfiling = false;
      _running = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;
    final src = _codeController.text;
    // 1 warm-up run + 3 timed runs -> median
    final warm = await _session.run(
      src,
      file: _preset.fileName,
      preferBytecode: true,
    );
    if (!mounted) return;
    if (!warm.succeeded) {
      _recordBenchmarkRun(warm);
      setState(() {
        _running = false;
        _lastResult = warm;
      });
      _visualResult.value = warm;
      return;
    }
    final times = <double>[];
    var last = warm;
    for (var i = 0; i < 3; i++) {
      last = await _session.run(
        src,
        file: _preset.fileName,
        preferBytecode: true,
      );
      times.add(last.elapsed.inMicroseconds / 1000.0);
    }
    if (!mounted) return;
    times.sort();
    final median = times[1];
    final avg = (times[0] + times[1] + times[2]) / 3.0;
    _recordBenchmarkRun(
      last,
      overrideMs: median,
      isMedianOf3: true,
      minMs: times[0],
      avgMs: avg,
    );
    setState(() {
      _running = false;
      _lastResult = last;
    });
    _visualResult.value = last;
  }

  void _openWorkspaceFile(String path, {bool switchToEditorOnMobile = true}) {
    final content = _projectWorkspace.readFile(path);
    if (content == null) return;
    if (_workspaceMode &&
        !_projectWorkspace.isBinaryFile(_activeWorkspaceFile)) {
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

  void _createWorkspaceAsset(
    String path, {
    String? textContent,
    Uint8List? binaryBytes,
  }) {
    final norm = QudsWorkspace.normalizePath(path);
    if (binaryBytes != null) {
      _projectWorkspace.writeAssetBytes(norm, binaryBytes);
      setState(() {});
    } else {
      _projectWorkspace.writeFile(norm, textContent ?? '');
      _openWorkspaceFile(norm);
    }
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

  void _selectProjectTemplate(
    StudioProjectTemplate tpl, {
    bool switchMobileTab = false,
  }) {
    _stopAnimTimer();
    _session.stop();
    _session.resetAnimation();
    _pendingInteractivePatch = null;
    _projectWorkspace = tpl.builder();
    final targetPolicy = tpl.usesBenchmarkPolicy
        ? StudioPolicyMode.benchmark
        : (tpl.usesSystemBridgePolicy
            ? StudioPolicyMode.systemBridge
            : StudioPolicyMode.standard);
    final policyChanged = _policyMode != targetPolicy;
    setState(() {
      _activeProjectId = tpl.id;
      _workspaceMode = true;
      _activeWorkspaceFile = _projectWorkspace.entryPoint;
      _policyMode = targetPolicy;
      _breakpoints = {};
      _workspaceComparison = const WorkspaceBenchComparison();
      _quickPatchVersion = 1;
    });
    if (policyChanged) {
      _buildRuntime();
    } else {
      _session.attachWorkspace(_projectWorkspace);
    }
    _openWorkspaceFile(
      _projectWorkspace.entryPoint,
      switchToEditorOnMobile: false,
    );
    _runCode(switchMobileTab: switchMobileTab);
  }

  void _openAiAgentLab() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QudsAiAgentLabPage(
          isArabic: _isArabic,
          isDark: _isDark,
          onOpenAiWorkspaceInStudio: () {
            final aiTpl = studioProjectTemplates
                .firstWhere((t) => t.id == 'ai_agent_sandbox');
            _selectProjectTemplate(aiTpl, switchMobileTab: false);
            setState(() {
              _mobileTabIndex = 4; // Jump directly to Project tab on mobile
              _inspectorTabs.index = 5; // Project tab on desktop
            });
          },
        ),
      ),
    );
  }

  Future<void> _launchStandaloneApp({StudioProjectTemplate? template}) async {
    _stopAnimTimer();
    if (_workspaceMode &&
        !_projectWorkspace.isBinaryFile(_activeWorkspaceFile)) {
      _projectWorkspace.writeFile(_activeWorkspaceFile, _codeController.text);
    }

    final StudioProjectTemplate? matchedTpl = template ??
        (_workspaceMode
            ? studioProjectTemplates
                .where((t) => t.id == _activeProjectId)
                .firstOrNull
            : null);

    final QudsWorkspace? ws = template != null
        ? template.builder()
        : (_workspaceMode ? _projectWorkspace : null);

    final title = matchedTpl != null
        ? (_isArabic ? matchedTpl.nameAr : matchedTpl.nameEn)
        : (_workspaceMode
            ? _projectWorkspace.name
            : (_isArabic ? _preset.titleAr : _preset.titleEn));

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QudsStandaloneAppPage(
          title: title,
          isArabic: _isArabic,
          isDark: _isDark,
          workspace: ws,
          source: ws == null ? _codeController.text : null,
          fileName: ws?.entryPoint ?? _preset.fileName,
          icon: matchedTpl?.icon ?? Icons.apps_rounded,
          accentColor: matchedTpl?.accentColor ?? const Color(0xFF38BDF8),
          usesSystemBridge: matchedTpl?.usesSystemBridgePolicy ??
              (_policyMode == StudioPolicyMode.systemBridge),
          usesBenchmarkPolicy: matchedTpl?.usesBenchmarkPolicy ??
              (_policyMode == StudioPolicyMode.benchmark),
          lineStyle: _lineStyle,
        ),
      ),
    );
  }

  void _importQprojWorkspace(QudsWorkspace imported) {
    _stopAnimTimer();
    _session.stop();
    _session.resetAnimation();
    _pendingInteractivePatch = null;
    _projectWorkspace = imported;
    _session.attachWorkspace(_projectWorkspace);
    setState(() {
      _activeProjectId = imported.name;
      _workspaceMode = true;
      _activeWorkspaceFile = _projectWorkspace.entryPoint;
      _breakpoints = {};
      _workspaceComparison = const WorkspaceBenchComparison();
    });
    _openWorkspaceFile(
      _projectWorkspace.entryPoint,
      switchToEditorOnMobile: false,
    );
    _runCode(switchMobileTab: false);
  }

  void _resetWorkspaceTemplate() {
    final tpl = studioProjectTemplates.firstWhere(
      (t) => t.id == _activeProjectId,
      orElse: () => studioProjectTemplates.first,
    );
    _projectWorkspace = tpl.builder();
    _session.attachWorkspace(_projectWorkspace);
    setState(() {
      _workspaceComparison = const WorkspaceBenchComparison();
      _quickPatchVersion = 1;
    });
    _openWorkspaceFile(
      _projectWorkspace.entryPoint,
      switchToEditorOnMobile: false,
    );
  }

  QudsExecutionPolicy _workspaceLabPolicy() => QudsExecutionPolicy.standard(
        maxSteps: 180000000,
        maxCallDepth: 256,
        maxCollectionLength: 500000,
        timeout: const Duration(seconds: 30),
      ).copyWith(
        yieldEveryNSteps: 4000,
        capabilities: [
          QudsCapability.custom('ai.orders.read'),
          QudsCapability.custom('ai.sensors.read'),
        ],
      );

  void _precompileWorkspaceAll() {
    if (_running) return;
    final sw = Stopwatch()..start();
    final compiled = _session.precompileWorkspace();
    sw.stop();
    final ms = sw.elapsedMicroseconds / 1000.0;
    setState(() {
      _workspaceMode = true;
      _workspaceComparison = _workspaceComparison.copyWith(
        precompileMs: ms,
        clearError: true,
        lastPatchSummary: _isArabic
            ? (compiled.isEmpty
                ? '✓ جميع الملفات (${_session.compiledWorkspaceArtifacts.length}) مترجمة ومحدّثة بالفعل في .quds_cache/'
                : '📦 تمت ترجمة ${compiled.length} ملفًا إلى .quds_cache/ خلال ${formatLabDurationMs(ms)}')
            : (compiled.isEmpty
                ? '✓ All ${_session.compiledWorkspaceArtifacts.length} files are already compiled & fresh in .quds_cache/'
                : '📦 Compiled ${compiled.length} files into .quds_cache/ in ${formatLabDurationMs(ms)}'),
      );
    });
  }

  Future<QudsRunResult> _executeWorkspaceModeInternal(
      WorkspaceRunMode mode) async {
    final policy = _workspaceLabPolicy();
    if (mode == WorkspaceRunMode.ast) {
      final temp = QudsSession(
        policy: policy,
        allowTopLevelRebind: true,
        hostModules: [buildAiToolsHostModule()],
        projectWorkspace: _projectWorkspace,
      );
      try {
        final sw = Stopwatch()..start();
        final res = await temp.runProject(
          preferBytecode: false,
          resetWorkspaceModules: true,
        );
        sw.stop();
        return QudsRunResult(
          succeeded: res.succeeded,
          value: res.value,
          printedLines: res.printedLines,
          outputs: res.outputs,
          stepsExecuted: res.stepsExecuted,
          elapsed: sw.elapsed,
          error: res.error,
          usedBytecodeVm: false,
        );
      } finally {
        await temp.dispose();
      }
    }

    if (mode == WorkspaceRunMode.coldBytecode) {
      final temp = QudsSession(
        policy: policy,
        allowTopLevelRebind: true,
        hostModules: [buildAiToolsHostModule()],
        projectWorkspace: _projectWorkspace,
      );
      try {
        final sw = Stopwatch()..start();
        final res = await temp.runProject(
          preferBytecode: true,
          resetWorkspaceModules: true,
        );
        sw.stop();
        // Ensure the live Studio session also exposes the compiled .qbc tree.
        _session.precompileWorkspace();
        return QudsRunResult(
          succeeded: res.succeeded,
          value: res.value,
          printedLines: res.printedLines,
          outputs: res.outputs,
          stepsExecuted: res.stepsExecuted,
          elapsed: sw.elapsed,
          error: res.error,
          usedBytecodeVm: true,
        );
      } finally {
        await temp.dispose();
      }
    }

    // Mode 3: Compiled & Cached (.qbc) — ensure benchmark policy on _session
    // and precompile all nested files first, then time pure cached execution.
    if (_policyMode != StudioPolicyMode.benchmark) {
      _policyMode = StudioPolicyMode.benchmark;
      _buildRuntime();
    }
    _session.precompileWorkspace();
    final sw = Stopwatch()..start();
    final res = await _session.runProject(
      preferBytecode: true,
      resetWorkspaceModules: false,
    );
    sw.stop();
    return QudsRunResult(
      succeeded: res.succeeded,
      value: res.value,
      printedLines: res.printedLines,
      outputs: res.outputs,
      stepsExecuted: res.stepsExecuted,
      elapsed: sw.elapsed,
      error: res.error,
      usedBytecodeVm: true,
    );
  }

  Future<void> _runWorkspaceInMode(WorkspaceRunMode mode) async {
    if (_running) return;
    _stopAnimTimer();
    final statusLabel = switch (mode) {
      WorkspaceRunMode.ast => _isArabic
          ? '🐢 جاري التشغيل بمفسّر AST (بدون بايت كود)...'
          : '🐢 Running with AST interpreter (no bytecode)...',
      WorkspaceRunMode.coldBytecode => _isArabic
          ? '⚡ جاري الترجمة والتشغيل بـ Bytecode (أول مرة)...'
          : '⚡ Compiling & running Cold Bytecode...',
      WorkspaceRunMode.compiledCached => _isArabic
          ? '🚀 جاري التشغيل من الملفات المترجمة (.qbc)...'
          : '🚀 Running from compiled .qbc artifacts...',
    };
    setState(() {
      _workspaceMode = true;
      _running = true;
      _workspaceRunStatus = statusLabel;
    });
    await Future<void>.delayed(const Duration(milliseconds: 24));
    if (!mounted) return;

    final res = await _executeWorkspaceModeInternal(mode);
    if (!mounted) return;
    final ms = res.elapsed.inMicroseconds / 1000.0;
    final checksum = res.stdout.trim();

    setState(() {
      _running = false;
      _workspaceRunStatus = null;
      _lastResult = res;
      _visualResult.value = res;
      if (!res.succeeded) {
        _workspaceComparison = _workspaceComparison.copyWith(
          error: '${res.error}',
          lastMode: mode,
        );
      } else {
        _workspaceComparison = switch (mode) {
          WorkspaceRunMode.ast => _workspaceComparison.copyWith(
              astMs: ms,
              astChecksum: checksum,
              lastMode: mode,
              clearError: true,
            ),
          WorkspaceRunMode.coldBytecode => _workspaceComparison.copyWith(
              coldBytecodeMs: ms,
              coldChecksum: checksum,
              lastMode: mode,
              clearError: true,
            ),
          WorkspaceRunMode.compiledCached => _workspaceComparison.copyWith(
              compiledCachedMs: ms,
              compiledChecksum: checksum,
              lastMode: mode,
              clearError: true,
            ),
        };
      }
    });
  }

  Future<void> _compareAllThreeWorkspaceModes() async {
    if (_running) return;
    _stopAnimTimer();
    setState(() {
      _workspaceMode = true;
      _running = true;
      _workspaceComparison = const WorkspaceBenchComparison();
      _workspaceRunStatus = _isArabic
          ? '1/3 🐢 جاري قياس مفسّر AST (قد يستغرق بضع ثوانٍ)...'
          : '1/3 🐢 Measuring AST interpreter...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 24));
    if (!mounted) return;

    // 1. AST Mode
    final astRes = await _executeWorkspaceModeInternal(WorkspaceRunMode.ast);
    if (!mounted) return;
    final astMs = astRes.elapsed.inMicroseconds / 1000.0;
    setState(() {
      _lastResult = astRes;
      _visualResult.value = astRes;
      _workspaceComparison = _workspaceComparison.copyWith(
        astMs: astRes.succeeded ? astMs : null,
        astChecksum: astRes.succeeded ? astRes.stdout.trim() : null,
        error: astRes.succeeded ? null : '${astRes.error}',
        clearError: astRes.succeeded,
      );
      _workspaceRunStatus = _isArabic
          ? '2/3 ⚡ جاري قياس Bytecode (أول ترجمة + تشغيل)...'
          : '2/3 ⚡ Measuring Cold Bytecode (compile + run)...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 24));
    if (!mounted) return;

    // 2. Cold Bytecode Mode
    final coldRes =
        await _executeWorkspaceModeInternal(WorkspaceRunMode.coldBytecode);
    if (!mounted) return;
    final coldMs = coldRes.elapsed.inMicroseconds / 1000.0;
    setState(() {
      _lastResult = coldRes;
      _visualResult.value = coldRes;
      _workspaceComparison = _workspaceComparison.copyWith(
        coldBytecodeMs: coldRes.succeeded ? coldMs : null,
        coldChecksum: coldRes.succeeded ? coldRes.stdout.trim() : null,
        error: coldRes.succeeded ? null : '${coldRes.error}',
        clearError: coldRes.succeeded,
      );
      _workspaceRunStatus = _isArabic
          ? '3/3 🚀 جاري ترجمة الملفات وقياس التشغيل بعد الترجمة...'
          : '3/3 🚀 Precompiling & measuring cached .qbc run...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 24));
    if (!mounted) return;

    // 3. Precompile fresh + Compiled Cached Mode
    if (_policyMode != StudioPolicyMode.benchmark) {
      _policyMode = StudioPolicyMode.benchmark;
      _buildRuntime();
    }
    _session.attachWorkspace(_projectWorkspace);
    final swPre = Stopwatch()..start();
    _session.precompileWorkspace();
    swPre.stop();
    final preMs = swPre.elapsedMicroseconds / 1000.0;

    final compiledRes =
        await _executeWorkspaceModeInternal(WorkspaceRunMode.compiledCached);
    if (!mounted) return;
    final compiledMs = compiledRes.elapsed.inMicroseconds / 1000.0;

    setState(() {
      _running = false;
      _workspaceRunStatus = null;
      _lastResult = compiledRes;
      _visualResult.value = compiledRes;
      _workspaceComparison = _workspaceComparison.copyWith(
        precompileMs: preMs,
        compiledCachedMs: compiledRes.succeeded ? compiledMs : null,
        compiledChecksum:
            compiledRes.succeeded ? compiledRes.stdout.trim() : null,
        lastMode: WorkspaceRunMode.compiledCached,
        error: compiledRes.succeeded ? null : '${compiledRes.error}',
        clearError: compiledRes.succeeded,
      );
    });
  }

  Future<void> _applyQuickCodePushEdit() async {
    if (_running) return;
    // Ensure compiled artifacts exist before applying a surgical live edit
    _session.precompileWorkspace();
    _quickPatchVersion++;
    final versionTag = '1.$_quickPatchVersion.0-live';

    late final String targetPath;
    late final String nextContent;
    if (_projectWorkspace.hasFile('core/config/workload.quds')) {
      targetPath = 'core/config/workload.quds';
      final heavyAlt = _quickPatchVersion.isEven;
      nextContent = heavyAlt
          ? '''# Live CodePush Patch v$versionTag — only this file is recompiled!
SUITE_LABEL = "Heavy 4-Kernel Suite (Live Patch #$versionTag)"
SIEVE_LIMIT = 140000
SIEVE_ROUNDS = 5
MATMUL_N = 64
NBODY_COUNT = 64
NBODY_STEPS = 40
MANDEL_SIZE = 140
MANDEL_ITER = 64
'''
          : '''# Heavy benchmark parameters — restored via Live CodePush v$versionTag
SUITE_LABEL = "Heavy 4-Kernel Suite"
SIEVE_LIMIT = 120000
SIEVE_ROUNDS = 4
MATMUL_N = 64
NBODY_COUNT = 64
NBODY_STEPS = 40
MANDEL_SIZE = 140
MANDEL_ITER = 64
''';
    } else {
      targetPath = _projectWorkspace.entryPoint;
      final existing = _projectWorkspace.readFile(targetPath) ?? '';
      final cleaned =
          existing.replaceFirst(RegExp(r'^# Live CodePush Patch .*?\n'), '');
      nextContent = '# Live CodePush Patch $versionTag\n$cleaned';
    }

    final sw = Stopwatch()..start();
    final pushRes = await _session.applyWorkspacePatch(
      QudsWorkspacePatch(
        bundleVersion: versionTag,
        upsertFiles: {targetPath: nextContent},
      ),
      precompileAffected: true,
    );
    sw.stop();
    final patchMs = sw.elapsedMicroseconds / 1000.0;

    if (_workspaceMode && _activeWorkspaceFile == targetPath) {
      _codeController.value = TextEditingValue(
        text: nextContent,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    setState(() {
      _workspaceComparison = _workspaceComparison.copyWith(
        lastPatchSummary: _isArabic
            ? '🧪 تحديث حي ($versionTag) خلال ${formatLabDurationMs(patchMs)}: أُعيدت ترجمة ${pushRes.recompiledFiles.length} ملف فقط (${pushRes.recompiledFiles.join(', ')}) · الملفات المعتمدة أُبطل تشغيلها فقط وبقي بايت كودها محفوظًا'
            : '🧪 Live Patch ($versionTag) in ${formatLabDurationMs(patchMs)}: recompiled ${pushRes.recompiledFiles.length} file (${pushRes.recompiledFiles.join(', ')}); unchanged .qbc files stayed cached',
      );
    });
  }

  void _stopAnimTimer() {
    _animTicker?.stop();
    _animTicker?.dispose();
    _animTicker = null;
    _lastTickElapsed = null;
    _animPlaying = false;
  }

  void _startAnimTimer() {
    _stopAnimTimer();
    setState(() => _animPlaying = true);
    _lastTickElapsed = null;
    _animTicker = createTicker((elapsed) {
      if (!mounted || !_animPlaying) return;
      final prev = _lastTickElapsed;
      if (prev == null) {
        _lastTickElapsed = elapsed;
        return;
      }
      final deltaUs = (elapsed - prev).inMicroseconds;
      final minFrameUs = (1000000 / _lineStyle.targetFps).round();
      if (deltaUs < minFrameUs - 1200) return;
      if (_updatingInteractive || _running) return;
      _lastTickElapsed = elapsed;
      final dt = (deltaUs / 1000000.0).clamp(0.002, 0.05);
      final instFps = 1.0 / dt;
      _measuredFps =
          _measuredFps <= 0 ? instFps : (_measuredFps * 0.85 + instFps * 0.15);
      _stepAnimFrame(dtSeconds: dt);
    })
      ..start();
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

  Future<void> _stepAnimFrame({double? dtSeconds}) async {
    if (_updatingInteractive || _running) return;
    _updatingInteractive = true;
    try {
      final stepDt = (dtSeconds ?? (1.0 / _lineStyle.targetFps)) * _animSpeed;
      final res = await _session.stepFrame(
        stepDt,
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
        final res = _workspaceMode
            ? await _session.runProject(
                interactiveInputs: nextPatch,
                preferBytecode: _preferBytecode,
              )
            : await _session.updateInteractiveInputs(
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
    _session.resetAnimation();
    _pendingInteractivePatch = null;
    setState(() {
      _workspaceMode = false;
      _preset = preset;
      _policyMode = preset.defaultPolicy;
      _breakpoints = Set<int>.from(preset.defaultBreakpoints);
      _preferBytecode = true;
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

  void _stepPreset(int delta) {
    final list = filterStudioPresets(_activeFilter);
    if (list.isEmpty) return;
    final idx = list.indexWhere((p) => p.id == _preset.id);
    final nextIdx = idx < 0 ? 0 : (idx + delta + list.length) % list.length;
    _selectPreset(list[nextIdx]);
  }

  Future<void> _openPresetGallery({bool expandWorkspaces = false}) async {
    final picked = await showQudsPresetGalleryDialog(
      context,
      initialFilter: _activeFilter,
      activePresetId: _preset.id,
      workspaceMode: _workspaceMode,
      activeWorkspaceId: _activeProjectId,
      isArabic: _isArabic,
      isDark: _isDark,
      expandWorkspaces: expandWorkspaces,
    );
    if (picked != null && mounted) {
      if (picked.workspaceTemplate != null) {
        if (picked.launchFullscreen) {
          _launchStandaloneApp(template: picked.workspaceTemplate!);
        } else {
          _selectProjectTemplate(
            picked.workspaceTemplate!,
            switchMobileTab: true,
          );
          _inspectorTabs.index = 5; // Show Project files/assets tab on desktop!
        }
      } else if (picked.preset != null) {
        setState(() => _activeFilter = picked.filter);
        _selectPreset(picked.preset!);
      }
    }
  }

  List<StudioPreset> _dropdownPresets() {
    final list = filterStudioPresets(_activeFilter);
    if (list.any((p) => p.id == _preset.id)) return list;
    return [_preset, ...list];
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
                        'quds:pen',
                        'quds:assets',
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
              activeProjectId: _activeProjectId,
              activeFile: _activeWorkspaceFile,
              workspaceMode: _workspaceMode,
              isArabic: _isArabic,
              isDark: _isDark,
              running: _running,
              onOpenFile: (path) => _openWorkspaceFile(path),
              onRunProject: _runWorkspaceProject,
              onCreateFile: _createWorkspaceFile,
              onCreateAsset: _createWorkspaceAsset,
              onCreateFolder: _createWorkspaceFolder,
              onDeleteFile: _deleteWorkspaceFile,
              onSelectTemplate: _selectProjectTemplate,
              onImportQproj: _importQprojWorkspace,
              onResetTemplate: _resetWorkspaceTemplate,
              compilationStats: _session.compilationStats,
              compiledArtifacts: _session.compiledWorkspaceArtifacts,
              comparison: _workspaceComparison,
              runningStatusLabel: _workspaceRunStatus,
              onRunMode: _runWorkspaceInMode,
              onCompareAll3: _compareAllThreeWorkspaceModes,
              onPrecompileAll: _precompileWorkspaceAll,
              onQuickCodePushEdit: _applyQuickCodePushEdit,
              onLaunchFullscreen: _launchStandaloneApp,
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
                    _buildToolbar(theme, isCompact: isCompact),
                    QudsPresetQuickBar(
                      activeFilter: _activeFilter,
                      activePreset: _preset,
                      workspaceMode: _workspaceMode,
                      activeWorkspaceName: _projectWorkspace.name,
                      isArabic: _isArabic,
                      isDark: _isDark,
                      onOpenGallery: () => _openPresetGallery(),
                      onOpenWorkspaces: () =>
                          _openPresetGallery(expandWorkspaces: true),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(isCompact ? 8 : 12),
                        child: isCompact
                            ? IndexedStack(
                                index: _mobileTabIndex,
                                children: [
                                  editorView,
                                  _buildVisualStage(theme, isCompact: true),
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
                                            child: _buildVisualStage(theme,
                                                isCompact: false)),
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

  Future<void> _openMobileSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Directionality(
          textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isArabic
                        ? 'إعدادات المحرك والسياسة والمظهر'
                        : 'Engine, Policy & Display Settings',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isArabic ? 'سياسة التنفيذ' : 'Execution Policy',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(ctx).hintColor),
                  ),
                  const SizedBox(height: 6),
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
                      if (_policyMode == StudioPolicyMode.benchmark)
                        ButtonSegment(
                          value: StudioPolicyMode.benchmark,
                          label: Text(_isArabic ? 'أداء فائق' : 'Bench'),
                        ),
                      if (_policyMode == StudioPolicyMode.custom)
                        ButtonSegment(
                          value: StudioPolicyMode.custom,
                          label: Text(_isArabic ? 'مخصّص' : 'Custom'),
                        ),
                    ],
                    selected: {_policyMode},
                    onSelectionChanged: (set) {
                      _switchPolicy(set.first);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('btn_custom_policy'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _openCustomPolicyDialog();
                    },
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(_isArabic ? 'تخصيص القيود' : 'Custom Policy'),
                  ),
                  const Divider(height: 20),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_isArabic
                        ? 'وضع Bytecode VM (السرعة الفائقة)'
                        : 'Bytecode VM Mode'),
                    value: _preferBytecode,
                    onChanged: (v) {
                      setState(() => _preferBytecode = v);
                      setSheetState(() {});
                    },
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_isArabic
                        ? 'تتبع الأداء وTime-Travel'
                        : 'Profiler & Time-Travel Trace'),
                    value: _enableProfiling,
                    onChanged: (v) {
                      setState(() {
                        _enableProfiling = v;
                        _debugger.recordHistory = v;
                        _profiler.enabled = v;
                      });
                      setSheetState(() {});
                    },
                  ),
                  const Divider(height: 16),
                  QudsLineQualityPanel(
                    settings: _lineStyle,
                    isArabic: _isArabic,
                    isDark: _isDark,
                    onChanged: (next) {
                      setState(() => _lineStyle = next);
                      setSheetState(() {});
                    },
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _isArabic = !_isArabic);
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.translate_rounded, size: 16),
                          label: Text(_isArabic ? 'English' : 'العربية'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _isDark = !_isDark);
                            widget.onDarkModeChanged?.call(_isDark);
                            _reanalyze();
                            setSheetState(() {});
                          },
                          icon: Icon(
                            _isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            size: 16,
                          ),
                          label: Text(_isDark
                              ? (_isArabic ? 'مظهر فاتح' : 'Light Mode')
                              : (_isArabic ? 'مظهر داكن' : 'Dark Mode')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(ThemeData theme, {required bool isCompact}) {
    final surface = _isDark ? const Color(0xFF0F172A) : Colors.white;
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: surface,
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.25),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.functions_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isArabic ? 'استوديو قُدس' : 'Quds Studio',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('btn_open_ai_lab'),
                  onPressed: _openAiAgentLab,
                  icon: const Icon(Icons.smart_toy_rounded,
                      size: 14, color: Color(0xFF06B6D4)),
                  label: Text(
                    _isArabic ? 'مختبر AI' : 'AI Lab',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF06B6D4),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.55),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  ),
                ),
                const SizedBox(width: 5),
                if (!_running)
                  FilledButton.icon(
                    key: const Key('btn_run'),
                    onPressed: _runCode,
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: Text(_isArabic ? 'تشغيل' : 'Run',
                        style: const TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  )
                else if (_activePause != null) ...[
                  FilledButton.icon(
                    key: const Key('btn_continue'),
                    onPressed: _debugger.continueRun,
                    icon: const Icon(Icons.play_arrow_rounded, size: 15),
                    label: Text(_isArabic ? 'متابعة' : 'Go',
                        style: const TextStyle(fontSize: 11.5)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  IconButton(
                    key: const Key('btn_stop'),
                    onPressed: _session.stop,
                    icon: const Icon(Icons.stop_circle_outlined,
                        color: Color(0xFFEF4444), size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ] else
                  IconButton(
                    key: const Key('btn_stop_running'),
                    onPressed: _session.stop,
                    icon: const Icon(Icons.stop_circle_outlined,
                        color: Color(0xFFEF4444), size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('btn_mobile_settings'),
                  tooltip: _isArabic ? 'إعدادات المحرك والقيود' : 'Settings',
                  onPressed: _openMobileSettingsSheet,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                IconButton(
                  key: const Key('btn_prev_preset'),
                  tooltip: _isArabic ? 'المثال السابق' : 'Previous',
                  onPressed: () => _stepPreset(-1),
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                ),
                Expanded(
                  child: DropdownButtonHideUnderline(
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
                          for (final p in _dropdownPresets())
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                _isArabic ? p.titleAr : p.titleEn,
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null) return;
                          final target =
                              studioPresets.firstWhere((p) => p.id == id);
                          _selectPreset(target);
                        },
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('btn_next_preset'),
                  tooltip: _isArabic ? 'المثال التالي' : 'Next',
                  onPressed: () => _stepPreset(1),
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      );
    }

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
          OutlinedButton.icon(
            key: const Key('btn_open_ai_lab'),
            onPressed: _openAiAgentLab,
            icon: const Icon(Icons.smart_toy_rounded,
                size: 14, color: Color(0xFF06B6D4)),
            label: Text(
              _isArabic ? 'AI' : 'AI',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF06B6D4),
              ),
            ),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.55),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            ),
          ),

          // Preset selector + 1-tap Prev/Next stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('btn_prev_preset'),
                tooltip: _isArabic ? 'المثال السابق' : 'Previous Example',
                onPressed: () => _stepPreset(-1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
              DropdownButtonHideUnderline(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
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
                        for (final p in _dropdownPresets())
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
                        final target =
                            studioPresets.firstWhere((p) => p.id == id);
                        _selectPreset(target);
                      },
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('btn_next_preset'),
                tooltip: _isArabic ? 'المثال التالي' : 'Next Example',
                onPressed: () => _stepPreset(1),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
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
              if (_policyMode == StudioPolicyMode.benchmark)
                ButtonSegment(
                  value: StudioPolicyMode.benchmark,
                  label: Text(_isArabic ? 'أداء فائق' : 'Bench'),
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
              widget.onDarkModeChanged?.call(_isDark);
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

  Widget _buildVisualStage(ThemeData theme, {required bool isCompact}) {
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
        final images =
            res?.outputs.whereType<QudsImageOutput>().toList() ?? const [];
        final tables =
            res?.outputs.whereType<QudsTableOutput>().toList() ?? const [];
        final readings = scene?.readings ?? const <QudsTelemetryReading>[];
        final interactiveInputs = <QudsInteractiveInput>[
          ...?scene?.interactiveInputs,
          ...?surface3d?.interactiveInputs,
          ...?vectorField?.interactiveInputs,
          ...?graph?.interactiveInputs,
          ...?form?.interactiveInputs,
          ...?plot?.interactiveInputs,
        ];

        final elapsedText = res == null
            ? ''
            : res.elapsed.inMilliseconds >= 10
                ? '${res.elapsed.inMilliseconds}ms'
                : '${(res.elapsed.inMicroseconds / 1000).toStringAsFixed(1)}ms';
        final engineBadge =
            res == null ? '' : (res.usedBytecodeVm ? '⚡ VM · ' : '');

        // 1. Primary interactive canvas (geometry, 3D surface, vector field, graph, or standalone plot)
        Widget? primaryCanvas;
        bool plotUsedAsPrimary = false;
        if (scene != null) {
          primaryCanvas = QudsGeometryCanvas(
            scene: scene,
            isDark: _isDark,
            lineStyle: _lineStyle,
            onPointerEvent: (ptr) {
              if (_animPlaying) {
                _session.patchInteractiveInputs({'__quds_pointer': ptr});
              } else {
                _updateInteractive({'__quds_pointer': ptr});
              }
            },
            onDragPoint: (id, x, y) => _updateInteractive({
              id: {'x': x, 'y': y},
            }),
          );
        } else if (surface3d != null && vectorField != null) {
          primaryCanvas = Column(
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
          primaryCanvas =
              QudsSurface3DCanvas(surface: surface3d, isDark: _isDark);
        } else if (vectorField != null) {
          primaryCanvas =
              QudsVectorFieldCanvas(field: vectorField, isDark: _isDark);
        } else if (graph != null) {
          primaryCanvas = QudsGraphCanvas(graph: graph, isDark: _isDark);
        } else if (plot != null && form == null && images.isEmpty) {
          plotUsedAsPrimary = true;
          primaryCanvas = QudsPlotCanvas(
            plot: plot,
            isDark: _isDark,
            lineStyle: _lineStyle,
          );
        }

        // 2. Rich secondary & card outputs (NEVER dropped when combined with a canvas or plot!)
        final secondaryWidgets = <Widget>[
          if (plot != null && !plotUsedAsPrimary)
            SizedBox(
              height: isCompact ? 230 : 250,
              child: QudsPlotCanvas(
                plot: plot,
                isDark: _isDark,
                lineStyle: _lineStyle,
              ),
            ),
          for (final img in images)
            QudsImageOutputCard(image: img, isDark: _isDark),
          if (form != null) QudsFormOutputCard(form: form, isDark: _isDark),
          for (final tbl in tables) QudsTableCard(table: tbl),
        ];

        final bool isBenchmarkView = primaryCanvas == null &&
            secondaryWidgets.isEmpty &&
            _preset.category == StudioCategory.benchmarks;

        final Widget emptyOrBenchmarkWidget = isBenchmarkView
            ? QudsBenchmarkStageCard(
                preset: _preset,
                result: res,
                history: _benchHistory[_preset.id] ?? const [],
                lastVmMs: _benchVmMs[_preset.id],
                lastAstMs: _benchAstMs[_preset.id],
                running: _running,
                isArabic: _isArabic,
                isDark: _isDark,
                onRunVm: () => _runBenchmarkSingle(useVm: true),
                onRunMedian3: _runBenchmarkMedian3,
                onRunAst: () => _runBenchmarkSingle(useVm: false),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
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
              );

        final headerRow = Row(
          children: [
            const Icon(Icons.auto_graph_rounded,
                size: 16, color: Color(0xFF38BDF8)),
            const SizedBox(width: 6),
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
            if (res != null && !isCompact) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '$engineBadge${res.stepsExecuted} · $elapsedText',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: const ['IBMPlexSansArabic'],
                      fontSize: 10,
                      color: res.usedBytecodeVm
                          ? const Color(0xFF10B981)
                          : theme.hintColor,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            InkWell(
              key: const Key('btn_launch_standalone_app'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => _launchStandaloneApp(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.open_in_full_rounded,
                      size: 13,
                      color: Color(0xFF818CF8),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _isArabic ? 'شاشة كاملة' : 'Full',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            InkWell(
              key: const Key('btn_line_quality'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(
                () => _showLineQualityPanel = !_showLineQualityPanel,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _showLineQualityPanel
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.2)
                      : (_isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _showLineQualityPanel
                        ? const Color(0xFF38BDF8)
                        : theme.dividerColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_fix_high_rounded,
                      size: 13,
                      color: _showLineQualityPanel
                          ? const Color(0xFF38BDF8)
                          : theme.hintColor,
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 3),
                      Text(
                        _isArabic ? 'الجودة' : 'Quality',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _showLineQualityPanel
                              ? const Color(0xFF38BDF8)
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );

        final lineQualityPanel = _showLineQualityPanel
            ? QudsLineQualityPanel(
                settings: _lineStyle,
                isArabic: _isArabic,
                isDark: _isDark,
                measuredFps: _animPlaying ? _measuredFps : null,
                onChanged: (next) => setState(() => _lineStyle = next),
              )
            : null;

        final animBar = animSpec == null
            ? null
            : QudsAnimationControlsBar(
                spec: animSpec,
                playing: _animPlaying,
                speed: _animSpeed,
                isArabic: _isArabic,
                onTogglePlay: _toggleAnimPlay,
                onStepFrame: () => _stepAnimFrame(),
                onReset: _resetAnim,
                onSpeedChanged: (s) => setState(() => _animSpeed = s),
                onSeekTime: _seekAnimTime,
              );

        // Use smooth scrollable stage whenever compact (mobile), when Line Quality
        // is open, or whenever multiple rich cards/canvases are stacked together.
        final bool useScrollableStack = isCompact ||
            _showLineQualityPanel ||
            secondaryWidgets.isNotEmpty ||
            isBenchmarkView;

        if (useScrollableStack) {
          final double canvasHeight = isCompact
              ? ((surface3d != null && vectorField != null) ? 420.0 : 320.0)
              : ((surface3d != null && vectorField != null) ? 360.0 : 310.0);

          return Container(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.25),
              ),
            ),
            child: SingleChildScrollView(
              key: const Key('visual_stage_scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerRow,
                  if (lineQualityPanel != null && !isCompact) ...[
                    const SizedBox(height: 8),
                    lineQualityPanel,
                  ],
                  const SizedBox(height: 8),
                  if (primaryCanvas != null)
                    SizedBox(height: canvasHeight, child: primaryCanvas)
                  else if (secondaryWidgets.isEmpty)
                    emptyOrBenchmarkWidget,
                  if (lineQualityPanel != null && isCompact) ...[
                    const SizedBox(height: 8),
                    lineQualityPanel,
                  ],
                  if (readings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    QudsTelemetryHudBar(readings: readings, isDark: _isDark),
                  ],
                  if (animBar != null) ...[
                    const SizedBox(height: 8),
                    animBar,
                  ],
                  if (interactiveInputs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? const Color(0xFF0B1120)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: QudsInteractiveControlsBar(
                        inputs: interactiveInputs,
                        onChanged: (id, val) => _updateInteractive({id: val}),
                      ),
                    ),
                  ],
                  for (final w in secondaryWidgets) ...[
                    const SizedBox(height: 10),
                    w,
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        }

        // Desktop standalone full-height canvas (geometry, 3D, vector field, graph, or empty)
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
              headerRow,
              if (animBar != null) ...[
                const SizedBox(height: 6),
                animBar,
              ],
              const SizedBox(height: 8),
              Expanded(child: primaryCanvas ?? emptyOrBenchmarkWidget),
              if (readings.isNotEmpty) ...[
                const SizedBox(height: 6),
                QudsTelemetryHudBar(readings: readings, isDark: _isDark),
              ],
              if (interactiveInputs.isNotEmpty) ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 110),
                  child: SingleChildScrollView(
                    child: QudsInteractiveControlsBar(
                      inputs: interactiveInputs,
                      onChanged: (id, val) => _updateInteractive({id: val}),
                    ),
                  ),
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
                    ? 'المشروع (${_projectWorkspace.listAllEntries().length})'
                    : 'Project (${_projectWorkspace.listAllEntries().length})',
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
