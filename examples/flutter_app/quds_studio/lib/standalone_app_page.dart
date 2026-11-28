/// Full-screen standalone app & game runner for Quds projects and presets.
///
/// Launches any multi-folder Quds [QudsWorkspace] (or single-file script) in an
/// immersive edge-to-edge full-screen runtime with 60fps VSync ticker, 0ms
/// finger/touch pointer streaming (`viz.pointer()`), live HUD telemetry,
/// thumb-friendly action buttons, and a collapsible controls sheet — hiding all
/// IDE editor/console chrome so every Quds project feels like a native app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:quds/interpreter.dart';

import 'ai_agent_lab.dart' show buildAiToolsHostModule;
import 'viz2_widgets.dart';
import 'viz_widgets.dart';

class QudsStandaloneAppPage extends StatefulWidget {
  const QudsStandaloneAppPage({
    super.key,
    required this.title,
    required this.isArabic,
    required this.isDark,
    this.workspace,
    this.source,
    this.fileName = 'main.quds',
    this.icon = Icons.apps_rounded,
    this.accentColor = const Color(0xFF38BDF8),
    this.usesSystemBridge = false,
    this.usesBenchmarkPolicy = false,
    this.lineStyle = const QudsLineStyleSettings(),
  });

  final String title;
  final bool isArabic;
  final bool isDark;
  final QudsWorkspace? workspace;
  final String? source;
  final String fileName;
  final IconData icon;
  final Color accentColor;
  final bool usesSystemBridge;
  final bool usesBenchmarkPolicy;
  final QudsLineStyleSettings lineStyle;

  @override
  State<QudsStandaloneAppPage> createState() => _QudsStandaloneAppPageState();
}

class _QudsStandaloneAppPageState extends State<QudsStandaloneAppPage>
    with SingleTickerProviderStateMixin {
  late QudsSession _session;
  final ValueNotifier<QudsRunResult?> _result = ValueNotifier(null);

  Ticker? _ticker;
  Duration? _lastTickElapsed;
  bool _animPlaying = false;
  bool _running = false;
  bool _updating = false;
  bool _showControlsPanel = false;
  double _measuredFps = 0.0;
  Map<String, Object?>? _pendingPatch;

  @override
  void initState() {
    super.initState();
    _initSession();
    _launch();
  }

  @override
  void dispose() {
    _stopTicker();
    _session.stop();
    _session.dispose();
    _result.dispose();
    super.dispose();
  }

  void _initSession() {
    final policy = widget.usesBenchmarkPolicy
        ? QudsExecutionPolicy.standard(
            maxSteps: 180000000,
            maxCallDepth: 256,
            maxCollectionLength: 500000,
            timeout: const Duration(seconds: 30),
          ).copyWith(yieldEveryNSteps: 4000)
        : widget.usesSystemBridge
            ? QudsExecutionPolicy.standard(
                maxSteps: 600000,
                maxCallDepth: 128,
                maxCollectionLength: 50000,
                timeout: const Duration(seconds: 12),
              ).copyWith(
                yieldEveryNSteps: 3000,
                capabilities: [
                  QudsCapability.custom('ai.orders.read'),
                  QudsCapability.custom('ai.sensors.read'),
                ],
              )
            : QudsExecutionPolicy.standard(
                maxSteps: 600000,
                maxCallDepth: 128,
                maxCollectionLength: 50000,
                timeout: const Duration(seconds: 12),
              ).copyWith(yieldEveryNSteps: 3000);

    final hostModules = <QudsHostModule>[];
    if (widget.usesSystemBridge) {
      hostModules.add(
        buildAiToolsHostModule(auditLog: <String>[]),
      );
    }

    _session = QudsSession(
      policy: policy,
      projectWorkspace: widget.workspace,
      hostModules: hostModules,
      allowTopLevelRebind: true,
    );
  }

  String _execSource() =>
      widget.workspace?.readFile(widget.workspace!.entryPoint) ??
      (widget.source ?? '');

  String _execFile() => widget.workspace?.entryPoint ?? widget.fileName;

  Future<void> _launch() async {
    if (_running) return;
    _stopTicker();
    _session.resetAnimation();
    setState(() => _running = true);
    try {
      if (widget.workspace != null) {
        _session.precompileWorkspace();
      }
      final res = widget.workspace != null
          ? await _session.runProject(preferBytecode: true)
          : await _session.run(
              _execSource(),
              file: _execFile(),
              preferBytecode: true,
            );
      if (!mounted) return;
      _result.value = res;
      final anim = res.animationSpec;
      if (res.succeeded && anim != null && anim.autoPlay) {
        _startTicker(targetFps: anim.fps);
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _stopTicker() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
    _lastTickElapsed = null;
    _animPlaying = false;
  }

  void _startTicker({int? targetFps}) {
    _stopTicker();
    final fps = (targetFps ?? widget.lineStyle.targetFps).clamp(24, 120);
    setState(() => _animPlaying = true);
    _lastTickElapsed = null;
    _ticker = createTicker((elapsed) {
      if (!mounted || !_animPlaying) return;
      final prev = _lastTickElapsed;
      if (prev == null) {
        _lastTickElapsed = elapsed;
        return;
      }
      final deltaUs = (elapsed - prev).inMicroseconds;
      final minFrameUs = (1000000 / fps).round();
      if (deltaUs < minFrameUs - 1200) return;
      if (_updating || _running) return;
      _lastTickElapsed = elapsed;
      final dt = (deltaUs / 1000000.0).clamp(0.004, 0.05);
      final instFps = 1.0 / dt;
      _measuredFps =
          _measuredFps <= 0 ? instFps : (_measuredFps * 0.85 + instFps * 0.15);
      _stepFrame(dt);
    })
      ..start();
  }

  Future<void> _stepFrame(double dt) async {
    if (_updating || _running) return;
    _updating = true;
    try {
      final res = await _session.stepFrame(
        dt,
        source: _execSource(),
        file: _execFile(),
      );
      if (!mounted) return;
      _result.value = res;
    } finally {
      _updating = false;
    }
  }

  void _handlePointerEvent(Map<String, Object?> pointerState) {
    // When running at 60fps, patch pointer state in-place for zero-lag pickup
    // on the very next VSync frame without queuing extra interpreter passes.
    if (_animPlaying) {
      _session.patchInteractiveInputs({'__quds_pointer': pointerState});
      return;
    }
    _updateInteractive({'__quds_pointer': pointerState});
  }

  Future<void> _updateInteractive(Map<String, Object?> patch) async {
    if (_running) return;
    _pendingPatch = {...?_pendingPatch, ...patch};
    if (_updating) return;
    _updating = true;
    try {
      while (_pendingPatch != null && mounted && !_running) {
        final next = _pendingPatch!;
        _pendingPatch = null;
        final res = widget.workspace != null
            ? await _session.runProject(
                interactiveInputs: next,
                preferBytecode: true,
              )
            : await _session.updateInteractiveInputs(
                next,
                source: _execSource(),
                file: _execFile(),
              );
        if (!mounted) return;
        _result.value = res;
      }
    } finally {
      _updating = false;
    }
  }

  Future<void> _restartApp() async {
    _stopTicker();
    _pendingPatch = null;
    await _launch();
  }

  void _togglePlayPause() {
    if (_animPlaying) {
      setState(_stopTicker);
    } else {
      _startTicker(targetFps: _result.value?.animationSpec?.fps);
    }
  }

  void _openDetailsSheet(
    BuildContext context, {
    QudsPlot2DOutput? plot,
    List<QudsImageOutput> images = const [],
    QudsFormOutput? form,
    List<QudsTableOutput> tables = const [],
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(14),
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_rounded,
                      size: 18, color: widget.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isArabic
                          ? 'البيانات والرسوم والمخططات المرفقة'
                          : 'Attached Charts, Blueprints & Tables',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (plot != null) ...[
                SizedBox(
                  height: 240,
                  child: QudsPlotCanvas(
                    plot: plot,
                    isDark: widget.isDark,
                    lineStyle: widget.lineStyle,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              for (final img in images) ...[
                QudsImageOutputCard(image: img, isDark: widget.isDark),
                const SizedBox(height: 10),
              ],
              if (form != null) ...[
                QudsFormOutputCard(form: form, isDark: widget.isDark),
                const SizedBox(height: 10),
              ],
              for (final tbl in tables) ...[
                QudsTableCard(table: tbl),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9);
    final barBg =
        widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFFFF);
    final borderCol =
        widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);

    return Directionality(
      textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        key: const Key('quds_standalone_app_page'),
        backgroundColor: bg,
        body: SafeArea(
          child: ValueListenableBuilder<QudsRunResult?>(
            valueListenable: _result,
            builder: (context, res, _) {
              final scene = res?.lastGeometryScene;
              final surface3d = res?.lastSurface3D;
              final vectorField = res?.lastVectorField;
              final graph = res?.lastGraph;
              final form = res?.lastForm;
              final plot = res?.lastPlot;
              final animSpec = res?.animationSpec;
              final images =
                  res?.outputs.whereType<QudsImageOutput>().toList() ??
                      const [];
              final tables =
                  res?.outputs.whereType<QudsTableOutput>().toList() ??
                      const [];
              final readings =
                  scene?.readings ?? const <QudsTelemetryReading>[];

              // Deduplicate interactive inputs by id
              final inputMap = <String, QudsInteractiveInput>{};
              for (final list in [
                scene?.interactiveInputs,
                surface3d?.interactiveInputs,
                vectorField?.interactiveInputs,
                graph?.interactiveInputs,
                form?.interactiveInputs,
                plot?.interactiveInputs,
              ]) {
                if (list == null) continue;
                for (final item in list) {
                  inputMap[item.id] = item;
                }
              }
              final allInputs = inputMap.values.toList();
              final buttonInputs =
                  allInputs.where((i) => i.kind == 'button').toList();
              final nonButtonInputs = allInputs
                  .where(
                      (i) => i.kind != 'button' && i.kind != 'draggablePoint')
                  .toList();

              final hasSecondaryCards = (plot != null && scene != null) ||
                  images.isNotEmpty ||
                  form != null ||
                  tables.isNotEmpty;

              // Immersive canvas mode: when there is a geometry/game scene,
              // 3D surface, vector field, or graph, dedicate the FULL screen
              // to the interactive canvas and tuck secondary reports into a
              // 1-tap bottom sheet.
              final isImmersiveCanvas = scene != null ||
                  surface3d != null ||
                  vectorField != null ||
                  graph != null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Minimal Native App Top Bar
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: barBg,
                      border: Border(
                        bottom: BorderSide(color: borderCol),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('btn_exit_standalone_app'),
                          visualDensity: VisualDensity.compact,
                          tooltip: widget.isArabic
                              ? 'العودة إلى استوديو قدس'
                              : 'Back to Quds Studio',
                          icon: Icon(
                            widget.isArabic
                                ? Icons.arrow_forward_rounded
                                : Icons.arrow_back_rounded,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.icon,
                            size: 15,
                            color: widget.accentColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_animPlaying && _measuredFps > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  '${_measuredFps.round()} FPS',
                                  style: const TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (animSpec != null)
                          IconButton(
                            key: const Key('btn_standalone_play_pause'),
                            visualDensity: VisualDensity.compact,
                            tooltip: _animPlaying
                                ? (widget.isArabic ? 'إيقاف مؤقت' : 'Pause')
                                : (widget.isArabic ? 'تشغيل' : 'Play'),
                            icon: Icon(
                              _animPlaying
                                  ? Icons.pause_circle_rounded
                                  : Icons.play_circle_rounded,
                              size: 21,
                              color: widget.accentColor,
                            ),
                            onPressed: _togglePlayPause,
                          ),
                        IconButton(
                          key: const Key('btn_standalone_reset'),
                          visualDensity: VisualDensity.compact,
                          tooltip:
                              widget.isArabic ? 'إعادة من البداية' : 'Reset',
                          icon: const Icon(Icons.replay_rounded, size: 19),
                          onPressed: _restartApp,
                        ),
                        if (isImmersiveCanvas && hasSecondaryCards)
                          IconButton(
                            key: const Key('btn_standalone_details'),
                            visualDensity: VisualDensity.compact,
                            tooltip: widget.isArabic
                                ? 'المخططات والبيانات'
                                : 'Charts & Assets',
                            icon:
                                const Icon(Icons.analytics_outlined, size: 19),
                            onPressed: () => _openDetailsSheet(
                              context,
                              plot: plot,
                              images: images,
                              form: form,
                              tables: tables,
                            ),
                          ),
                        if (nonButtonInputs.isNotEmpty)
                          IconButton(
                            key: const Key('btn_standalone_controls'),
                            visualDensity: VisualDensity.compact,
                            tooltip: widget.isArabic
                                ? 'إعدادات التطبيق'
                                : 'App Controls',
                            icon: Icon(
                              _showControlsPanel
                                  ? Icons.tune_rounded
                                  : Icons.display_settings_rounded,
                              size: 19,
                              color: _showControlsPanel
                                  ? widget.accentColor
                                  : null,
                            ),
                            onPressed: () => setState(
                              () => _showControlsPanel = !_showControlsPanel,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Live Telemetry HUD Strip (Score, Lives, Speed, BPM, etc.)
                  if (readings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
                      child: QudsTelemetryHudBar(
                        readings: readings,
                        isDark: widget.isDark,
                      ),
                    ),

                  // Collapsible Sliders / Controls Drawer
                  if (_showControlsPanel && nonButtonInputs.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: barBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: SingleChildScrollView(
                        child: QudsInteractiveControlsBar(
                          inputs: nonButtonInputs,
                          onChanged: (id, val) => _updateInteractive({id: val}),
                        ),
                      ),
                    ),

                  // Main Full-Screen App Body
                  Expanded(
                    child: _running && res == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: widget.accentColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.isArabic
                                      ? 'جاري تشغيل التطبيق بمحرك قدس...'
                                      : 'Launching Quds App...',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : res != null && !res.succeeded
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    '${res.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            : isImmersiveCanvas
                                ? Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: _buildImmersiveCanvas(
                                      scene: scene,
                                      surface3d: surface3d,
                                      vectorField: vectorField,
                                      graph: graph,
                                    ),
                                  )
                                : SingleChildScrollView(
                                    key: const Key('standalone_app_scroll'),
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (nonButtonInputs.isNotEmpty &&
                                            !_showControlsPanel) ...[
                                          QudsInteractiveControlsBar(
                                            inputs: nonButtonInputs,
                                            onChanged: (id, val) =>
                                                _updateInteractive({id: val}),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        if (plot != null) ...[
                                          SizedBox(
                                            height: 250,
                                            child: QudsPlotCanvas(
                                              plot: plot,
                                              isDark: widget.isDark,
                                              lineStyle: widget.lineStyle,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        for (final img in images) ...[
                                          QudsImageOutputCard(
                                            image: img,
                                            isDark: widget.isDark,
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        if (form != null) ...[
                                          QudsFormOutputCard(
                                            form: form,
                                            isDark: widget.isDark,
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        for (final tbl in tables) ...[
                                          QudsTableCard(table: tbl),
                                          const SizedBox(height: 10),
                                        ],
                                      ],
                                    ),
                                  ),
                  ),

                  // Bottom Thumb-Reach Action Buttons (e.g. Clear / Undo / Next Level / Boost)
                  if (buttonInputs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: barBg,
                        border: Border(top: BorderSide(color: borderCol)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final btn in buttonInputs)
                            FilledButton.tonal(
                              key: Key('standalone_btn_${btn.id}'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                              onPressed: () {
                                final prev = btn.value is num
                                    ? (btn.value as num).toInt()
                                    : 0;
                                _updateInteractive({btn.id: prev + 1});
                              },
                              child: Text(
                                btn.label ?? btn.id,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImmersiveCanvas({
    QudsGeometrySceneOutput? scene,
    QudsSurface3DOutput? surface3d,
    QudsVectorFieldOutput? vectorField,
    QudsGraphOutput? graph,
  }) {
    if (scene != null) {
      return QudsGeometryCanvas(
        scene: scene,
        isDark: widget.isDark,
        lineStyle: widget.lineStyle,
        padding: 10.0,
        onPointerEvent: _handlePointerEvent,
        onDragPoint: (id, x, y) => _updateInteractive({
          id: {'x': x, 'y': y},
        }),
      );
    }
    if (surface3d != null && vectorField != null) {
      return Column(
        children: [
          Expanded(
            flex: 6,
            child: QudsSurface3DCanvas(
              surface: surface3d,
              isDark: widget.isDark,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 4,
            child: QudsVectorFieldCanvas(
              field: vectorField,
              isDark: widget.isDark,
            ),
          ),
        ],
      );
    }
    if (surface3d != null) {
      return QudsSurface3DCanvas(surface: surface3d, isDark: widget.isDark);
    }
    if (vectorField != null) {
      return QudsVectorFieldCanvas(field: vectorField, isDark: widget.isDark);
    }
    return QudsGraphCanvas(graph: graph!, isDark: widget.isDark);
  }
}
