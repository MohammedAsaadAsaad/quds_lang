/// Interactive Flutter visualizers for `QudsOutput`:
/// - `QudsGeometryCanvas`: interactive 2D geometry painter with real mouse/touch
///   drag-and-drop on draggable handles (`A`, `B`, `C`) + live centroid/angle/mesh.
/// - `QudsPlotCanvas`: 2D scientific plot painter.
/// - `QudsInteractiveControlsBar`: auto-generated Sliders & Switches for `viz.slider`/`viz.toggle`.
/// - `QudsTableCard` & `QudsMatrixCard`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

/// Quick rendering quality presets for curves, plots, and geometry strokes.
enum QudsLineRenderPreset {
  crisp,
  balanced,
  softGlow,
  rawVector,
}

/// User-controllable animation smoothness (FPS), line sharpness, spline
/// smoothness, glow, and anti-aliasing.
class QudsLineStyleSettings {
  const QudsLineStyleSettings({
    this.strokeScale = 0.92,
    this.smoothness = 0.85,
    this.glowIntensity = 0.20,
    this.antiAlias = true,
    this.targetFps = 60,
  });

  static const crisp = QudsLineStyleSettings(
    strokeScale: 0.78,
    smoothness: 0.80,
    glowIntensity: 0.0,
    antiAlias: true,
    targetFps: 60,
  );

  static const balanced = QudsLineStyleSettings(
    strokeScale: 0.92,
    smoothness: 0.85,
    glowIntensity: 0.20,
    antiAlias: true,
    targetFps: 60,
  );

  static const softGlow = QudsLineStyleSettings(
    strokeScale: 1.15,
    smoothness: 1.0,
    glowIntensity: 0.85,
    antiAlias: true,
    targetFps: 60,
  );

  static const rawVector = QudsLineStyleSettings(
    strokeScale: 0.85,
    smoothness: 0.0,
    glowIntensity: 0.0,
    antiAlias: true,
    targetFps: 60,
  );

  factory QudsLineStyleSettings.fromPreset(
    QudsLineRenderPreset preset, {
    int targetFps = 60,
  }) =>
      switch (preset) {
        QudsLineRenderPreset.crisp => crisp.copyWith(targetFps: targetFps),
        QudsLineRenderPreset.balanced =>
          balanced.copyWith(targetFps: targetFps),
        QudsLineRenderPreset.softGlow =>
          softGlow.copyWith(targetFps: targetFps),
        QudsLineRenderPreset.rawVector =>
          rawVector.copyWith(targetFps: targetFps),
      };

  /// Multiplier applied to stroke widths (0.5 = razor-thin .. 1.8 = bold).
  final double strokeScale;

  /// Catmull-Rom cubic spline smoothing factor (0.0 = raw polyline .. 1.0 = ultra smooth).
  final double smoothness;

  /// Optical glow halo intensity (0.0 = razor-sharp no bloom .. 1.0 = neon glow).
  final double glowIntensity;

  /// Whether anti-aliasing is enabled on canvas strokes.
  final bool antiAlias;

  /// VSync target animation frame rate (24, 30, 60, or 120 FPS).
  final int targetFps;

  QudsLineRenderPreset? get matchingPreset {
    bool close(double a, double b) => (a - b).abs() < 0.03;
    if (antiAlias &&
        close(strokeScale, crisp.strokeScale) &&
        close(smoothness, crisp.smoothness) &&
        close(glowIntensity, crisp.glowIntensity)) {
      return QudsLineRenderPreset.crisp;
    }
    if (antiAlias &&
        close(strokeScale, balanced.strokeScale) &&
        close(smoothness, balanced.smoothness) &&
        close(glowIntensity, balanced.glowIntensity)) {
      return QudsLineRenderPreset.balanced;
    }
    if (antiAlias &&
        close(strokeScale, softGlow.strokeScale) &&
        close(smoothness, softGlow.smoothness) &&
        close(glowIntensity, softGlow.glowIntensity)) {
      return QudsLineRenderPreset.softGlow;
    }
    if (antiAlias &&
        close(strokeScale, rawVector.strokeScale) &&
        close(smoothness, rawVector.smoothness) &&
        close(glowIntensity, rawVector.glowIntensity)) {
      return QudsLineRenderPreset.rawVector;
    }
    return null;
  }

  QudsLineStyleSettings copyWith({
    double? strokeScale,
    double? smoothness,
    double? glowIntensity,
    bool? antiAlias,
    int? targetFps,
  }) =>
      QudsLineStyleSettings(
        strokeScale: strokeScale ?? this.strokeScale,
        smoothness: smoothness ?? this.smoothness,
        glowIntensity: glowIntensity ?? this.glowIntensity,
        antiAlias: antiAlias ?? this.antiAlias,
        targetFps: targetFps ?? this.targetFps,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QudsLineStyleSettings &&
          other.strokeScale == strokeScale &&
          other.smoothness == smoothness &&
          other.glowIntensity == glowIntensity &&
          other.antiAlias == antiAlias &&
          other.targetFps == targetFps;

  @override
  int get hashCode =>
      Object.hash(strokeScale, smoothness, glowIntensity, antiAlias, targetFps);
}

/// Compact live control card for adjusting animation smoothness (FPS),
/// line sharpness, spline smoothness, glow & AA.
class QudsLineQualityPanel extends StatelessWidget {
  const QudsLineQualityPanel({
    super.key,
    required this.settings,
    required this.isArabic,
    required this.isDark,
    required this.onChanged,
    this.measuredFps,
  });

  final QudsLineStyleSettings settings;
  final bool isArabic;
  final bool isDark;
  final ValueChanged<QudsLineStyleSettings> onChanged;
  final double? measuredFps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePreset = settings.matchingPreset;
    return Container(
      key: const Key('quds_line_quality_panel'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high_rounded,
                  size: 14, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isArabic
                      ? 'نعومة الحركة وجودة الخطوط'
                      : 'Motion Smoothness & Line Quality',
                  style: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (measuredFps != null && measuredFps! > 1) ...[
                const SizedBox(width: 6),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${measuredFps!.round()} FPS',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              InkWell(
                key: const Key('toggle_line_aa'),
                borderRadius: BorderRadius.circular(6),
                onTap: () => onChanged(
                  settings.copyWith(antiAlias: !settings.antiAlias),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: settings.antiAlias
                        ? const Color(0xFF10B981).withValues(alpha: 0.16)
                        : theme.dividerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: settings.antiAlias
                          ? const Color(0xFF10B981).withValues(alpha: 0.5)
                          : theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    settings.antiAlias ? 'AA ON' : 'AA OFF',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: settings.antiAlias
                          ? const Color(0xFF10B981)
                          : theme.hintColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // VSync target frame rate (Motion Smoothness)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  isArabic ? 'نعومة الحركة (FPS): ' : 'Motion FPS: ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: theme.hintColor,
                  ),
                ),
                for (final fps in const [24, 30, 60, 120])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 5),
                    child: ChoiceChip(
                      key: Key('fps_chip_$fps'),
                      label: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          fps == 120
                              ? (isArabic ? '120 فائق' : '120 Ultra')
                              : '$fps fps',
                          style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: ['IBMPlexSansArabic'],
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      selected: settings.targetFps == fps,
                      onSelected: (_) =>
                          onChanged(settings.copyWith(targetFps: fps)),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in [
                  (
                    QudsLineRenderPreset.crisp,
                    isArabic ? 'حاد جداً' : 'Razor Crisp',
                  ),
                  (
                    QudsLineRenderPreset.balanced,
                    isArabic ? 'متوازن' : 'Balanced',
                  ),
                  (
                    QudsLineRenderPreset.softGlow,
                    isArabic ? 'ناعم متوهج' : 'Soft Glow',
                  ),
                  (
                    QudsLineRenderPreset.rawVector,
                    isArabic ? 'هندسي خام' : 'Raw Polyline',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      key: Key('line_preset_${entry.$1.name}'),
                      label: Text(entry.$2,
                          style: const TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w600)),
                      selected: activePreset == entry.$1,
                      onSelected: (_) => onChanged(
                        QudsLineStyleSettings.fromPreset(
                          entry.$1,
                          targetFps: settings.targetFps,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              _MiniQualitySlider(
                sliderKey: const Key('slider_line_stroke'),
                label: isArabic ? 'سُمك / حدة الخط' : 'Stroke Width',
                valueText: '${settings.strokeScale.toStringAsFixed(2)}x',
                value: settings.strokeScale,
                min: 0.5,
                max: 1.8,
                onChanged: (v) => onChanged(settings.copyWith(strokeScale: v)),
              ),
              _MiniQualitySlider(
                sliderKey: const Key('slider_line_smooth'),
                label: isArabic ? 'نعومة المنحنى' : 'Smoothness',
                valueText: '${(settings.smoothness * 100).round()}%',
                value: settings.smoothness,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => onChanged(settings.copyWith(smoothness: v)),
              ),
              _MiniQualitySlider(
                sliderKey: const Key('slider_line_glow'),
                label: isArabic ? 'شدة التوهج' : 'Glow',
                valueText: '${(settings.glowIntensity * 100).round()}%',
                value: settings.glowIntensity,
                min: 0.0,
                max: 1.0,
                onChanged: (v) =>
                    onChanged(settings.copyWith(glowIntensity: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniQualitySlider extends StatelessWidget {
  const _MiniQualitySlider({
    required this.sliderKey,
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  valueText,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: SizedBox(
              height: 24,
              child: Slider(
                key: sliderKey,
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive 2D Geometry Canvas rendering [QudsGeometrySceneOutput] with
/// pointer hit-testing and real-time drag-and-drop for draggable handles.
class QudsGeometryCanvas extends StatefulWidget {
  const QudsGeometryCanvas({
    super.key,
    required this.scene,
    required this.onDragPoint,
    required this.isDark,
    this.lineStyle = const QudsLineStyleSettings(),
  });

  final QudsGeometrySceneOutput scene;
  final void Function(String id, double x, double y) onDragPoint;
  final bool isDark;
  final QudsLineStyleSettings lineStyle;

  @override
  State<QudsGeometryCanvas> createState() => _QudsGeometryCanvasState();
}

class _QudsGeometryCanvasState extends State<QudsGeometryCanvas> {
  String? _draggingId;
  QudsGeoBounds? _lockedBounds;

  _GeoViewport _viewportFor(Size size) {
    final bounds = _lockedBounds ?? widget.scene.bounds;
    const pad = 36.0;
    final viewW = math.max(size.width - pad * 2, 10.0);
    final viewH = math.max(size.height - pad * 2, 10.0);
    final scale = math.min(
      viewW / math.max(bounds.width, 1e-6),
      viewH / math.max(bounds.height, 1e-6),
    );
    final midX = (bounds.minX + bounds.maxX) / 2;
    final midY = (bounds.minY + bounds.maxY) / 2;
    return _GeoViewport(
      size: size,
      scale: scale,
      midX: midX,
      midY: midY,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 480,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 320,
        );
        final vp = _viewportFor(size);
        final hasDraggable = widget.scene.draggablePoints.isNotEmpty;
        return MouseRegion(
          cursor: !hasDraggable
              ? MouseCursor.defer
              : _draggingId != null
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
          child: GestureDetector(
            key: const Key('quds_geometry_canvas'),
            onPanStart: !hasDraggable
                ? null
                : (details) {
                    final local = details.localPosition;
                    String? hitId;
                    var bestDist = 38.0;
                    for (final p in widget.scene.draggablePoints) {
                      final pos = vp.toScreen(p.x, p.y);
                      final d = (pos - local).distance;
                      if (d < bestDist) {
                        bestDist = d;
                        hitId = p.id;
                      }
                    }
                    if (hitId != null) {
                      setState(() {
                        _draggingId = hitId;
                        _lockedBounds = widget.scene.bounds;
                      });
                    }
                  },
            onPanUpdate: !hasDraggable
                ? null
                : (details) {
                    if (_draggingId == null) return;
                    final world = vp.toWorld(details.localPosition);
                    widget.onDragPoint(
                      _draggingId!,
                      double.parse(world.dx.toStringAsFixed(2)),
                      double.parse(world.dy.toStringAsFixed(2)),
                    );
                  },
            onPanEnd: !hasDraggable
                ? null
                : (_) {
                    setState(() {
                      _draggingId = null;
                      _lockedBounds = null;
                    });
                  },
            onPanCancel: !hasDraggable
                ? null
                : () {
                    setState(() {
                      _draggingId = null;
                      _lockedBounds = null;
                    });
                  },
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: _GeometryScenePainter(
                  scene: widget.scene,
                  viewport: vp,
                  draggingId: _draggingId,
                  isDark: widget.isDark,
                  lineStyle: widget.lineStyle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Clean standalone live telemetry strip displayed directly below the canvas
/// (never covering the drawing), with proper LTR formatting for numeric values + units.
class QudsTelemetryHudBar extends StatelessWidget {
  const QudsTelemetryHudBar({
    super.key,
    required this.readings,
    required this.isDark,
  });

  final List<QudsTelemetryReading> readings;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const Key('quds_telemetry_hud'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final r in readings)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (r.color != null
                        ? _parseColor(r.color!)
                        : const Color(0xFF38BDF8))
                    .withValues(alpha: isDark ? 0.12 : 0.09),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: (r.color != null
                          ? _parseColor(r.color!)
                          : const Color(0xFF38BDF8))
                      .withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: r.color != null
                          ? _parseColor(r.color!)
                          : const Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${r.label}: ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569),
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      r.unit != null ? '${r.value} ${r.unit}' : r.value,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontFamilyFallback: const ['IBMPlexSansArabic'],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: r.color != null
                            ? _parseColor(r.color!)
                            : (isDark
                                ? const Color(0xFFF8FAFC)
                                : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GeoViewport {
  const _GeoViewport({
    required this.size,
    required this.scale,
    required this.midX,
    required this.midY,
  });

  final Size size;
  final double scale;
  final double midX;
  final double midY;

  Offset toScreen(double x, double y) => Offset(
        size.width / 2 + (x - midX) * scale,
        size.height / 2 - (y - midY) * scale,
      );

  Offset toWorld(Offset screen) => Offset(
        midX + (screen.dx - size.width / 2) / scale,
        midY - (screen.dy - size.height / 2) / scale,
      );
}

class _GeometryScenePainter extends CustomPainter {
  const _GeometryScenePainter({
    required this.scene,
    required this.viewport,
    required this.draggingId,
    required this.isDark,
    required this.lineStyle,
  });

  final QudsGeometrySceneOutput scene;
  final _GeoViewport viewport;
  final String? draggingId;
  final bool isDark;
  final QudsLineStyleSettings lineStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      bgPaint,
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
    );

    final gridColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final axisColor =
        isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
    final textColor =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);

    // Grid
    if (scene.showGrid) {
      final gridPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      final topLeft = viewport.toWorld(Offset.zero);
      final bottomRight = viewport.toWorld(Offset(size.width, size.height));
      final startX = topLeft.dx.floor();
      final endX = bottomRight.dx.ceil();
      final startY = bottomRight.dy.floor();
      final endY = topLeft.dy.ceil();
      if (endX - startX < 120) {
        for (var gx = startX; gx <= endX; gx++) {
          final sx = viewport.toScreen(gx.toDouble(), 0).dx;
          canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), gridPaint);
        }
      }
      if (endY - startY < 120) {
        for (var gy = startY; gy <= endY; gy++) {
          final sy = viewport.toScreen(0, gy.toDouble()).dy;
          canvas.drawLine(Offset(0, sy), Offset(size.width, sy), gridPaint);
        }
      }
    }

    // Axes
    if (scene.showAxes) {
      final axisPaint = Paint()
        ..color = axisColor
        ..strokeWidth = 1.4;
      final origin = viewport.toScreen(0, 0);
      canvas.drawLine(
          Offset(0, origin.dy), Offset(size.width, origin.dy), axisPaint);
      canvas.drawLine(
          Offset(origin.dx, 0), Offset(origin.dx, size.height), axisPaint);
    }

    // Primitives
    for (final p in scene.primitives) {
      switch (p) {
        case QudsGeoPolygon():
          if (p.points.length < 2) break;
          final path = Path();
          final first = viewport.toScreen(p.points.first.$1, p.points.first.$2);
          path.moveTo(first.dx, first.dy);
          for (var i = 1; i < p.points.length; i++) {
            final pt = viewport.toScreen(p.points[i].$1, p.points[i].$2);
            path.lineTo(pt.dx, pt.dy);
          }
          if (p.closed) path.close();
          if (p.fill != null) {
            canvas.drawPath(
              path,
              Paint()
                ..isAntiAlias = lineStyle.antiAlias
                ..color = _parseColor(p.fill!),
            );
          }
          canvas.drawPath(
            path,
            Paint()
              ..isAntiAlias = lineStyle.antiAlias
              ..color = _parseColor(p.stroke)
              ..style = PaintingStyle.stroke
              ..strokeWidth = (1.9 * lineStyle.strokeScale).clamp(0.7, 6.0)
              ..strokeJoin = StrokeJoin.round,
          );
        case QudsGeoCircle():
          final c = viewport.toScreen(p.cx, p.cy);
          final r = p.radius * viewport.scale;
          if (p.fill != null) {
            canvas.drawCircle(
              c,
              r,
              Paint()
                ..isAntiAlias = lineStyle.antiAlias
                ..color = _parseColor(p.fill!),
            );
          }
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..isAntiAlias = lineStyle.antiAlias
              ..color = _parseColor(p.stroke)
              ..style = PaintingStyle.stroke
              ..strokeWidth = (1.8 * lineStyle.strokeScale).clamp(0.7, 6.0),
          );
        case QudsGeoSegment():
          final a = viewport.toScreen(p.x1, p.y1);
          final b = viewport.toScreen(p.x2, p.y2);
          final paint = Paint()
            ..isAntiAlias = lineStyle.antiAlias
            ..color = _parseColor(p.color)
            ..strokeCap = StrokeCap.round
            ..strokeWidth =
                (p.strokeWidth * lineStyle.strokeScale).clamp(0.7, 8.0);
          if (p.dashed) {
            _drawDashedLine(canvas, a, b, paint);
          } else {
            canvas.drawLine(a, b, paint);
          }
        case QudsGeoLine():
          final a = viewport.toScreen(p.x1, p.y1);
          final b = viewport.toScreen(p.x2, p.y2);
          final dir = b - a;
          if (dir.distance > 1e-6) {
            final u = dir / dir.distance;
            canvas.drawLine(
              a - u * 2000,
              a + u * 2000,
              Paint()
                ..isAntiAlias = lineStyle.antiAlias
                ..color = _parseColor(p.color)
                ..strokeWidth = (1.4 * lineStyle.strokeScale).clamp(0.6, 5.0),
            );
          }
        case QudsGeoVector():
          final a = viewport.toScreen(p.x1, p.y1);
          final b = viewport.toScreen(p.x2, p.y2);
          final vecColor = _parseColor(p.color);
          canvas.drawLine(
            a,
            b,
            Paint()
              ..isAntiAlias = lineStyle.antiAlias
              ..color = vecColor
              ..strokeWidth = (2.2 * lineStyle.strokeScale).clamp(0.8, 6.0)
              ..strokeCap = StrokeCap.round,
          );
          final delta = b - a;
          if (delta.distance > 6.0) {
            final ang = math.atan2(delta.dy, delta.dx);
            const headLen = 9.0;
            const spread = 0.48;
            final left = Offset(
              b.dx - headLen * math.cos(ang - spread),
              b.dy - headLen * math.sin(ang - spread),
            );
            final right = Offset(
              b.dx - headLen * math.cos(ang + spread),
              b.dy - headLen * math.sin(ang + spread),
            );
            final arrow = Path()
              ..moveTo(b.dx, b.dy)
              ..lineTo(left.dx, left.dy)
              ..lineTo(right.dx, right.dy)
              ..close();
            canvas.drawPath(
              arrow,
              Paint()
                ..isAntiAlias = lineStyle.antiAlias
                ..color = vecColor,
            );
          }
          if (p.label != null && p.label!.isNotEmpty) {
            _drawLabel(canvas, p.label!, b + const Offset(8, -10), vecColor);
          }
        case QudsGeoCurve():
          final visible = p.visiblePoints();
          if (visible.length >= 2) {
            final screenPts = <Offset>[
              for (final pt in visible) viewport.toScreen(pt.$1, pt.$2),
            ];
            final effectiveWidth =
                (p.strokeWidth * lineStyle.strokeScale).clamp(0.7, 10.0);
            final glowStrength =
                p.glow ? lineStyle.glowIntensity.clamp(0.0, 1.0) : 0.0;
            final hasMultiColor =
                p.gradientColors.length >= 2 || p.pointColors.isNotEmpty;

            if (hasMultiColor) {
              // Batch into at most 28 smooth Catmull-Rom chunks so mobile GPUs
              // render silky 60-120fps with continuous color gradients and ZERO
              // per-segment MaskFilter.blur overhead!
              final denom = math.max(1, p.points.length - 1);
              final n = screenPts.length;
              final chunkStep = math.max(1, (n / 28).ceil());
              final chunks =
                  <(Path path, Offset a, Offset b, Color cA, Color cB)>[];
              for (var start = 0; start < n - 1; start += chunkStep) {
                final end = math.min(n - 1, start + chunkStep);
                final chunkPath = _buildCatmullRomSubPath(
                  screenPts,
                  start,
                  end,
                  lineStyle.smoothness,
                );
                final tA = (start / denom).clamp(0.0, 1.0);
                final tB = (end / denom).clamp(0.0, 1.0);
                chunks.add((
                  chunkPath,
                  screenPts[start],
                  screenPts[end],
                  _parseColor(p.colorAt(start, tA)),
                  _parseColor(p.colorAt(end, tB)),
                ));
              }

              // Pass 1: lightweight soft halo strictly underneath (NO blur shader in loop!)
              if (glowStrength > 0.01) {
                final outerHalo = Paint()
                  ..isAntiAlias = lineStyle.antiAlias
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = effectiveWidth * (2.3 + 1.1 * glowStrength)
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round;
                final innerHalo = Paint()
                  ..isAntiAlias = lineStyle.antiAlias
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = effectiveWidth * (1.45 + 0.5 * glowStrength)
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round;
                for (final ch in chunks) {
                  outerHalo.color =
                      ch.$4.withValues(alpha: 0.13 * glowStrength);
                  canvas.drawPath(ch.$1, outerHalo);
                  innerHalo.color =
                      ch.$4.withValues(alpha: 0.22 * glowStrength);
                  canvas.drawPath(ch.$1, innerHalo);
                }
              }

              // Pass 2: razor-sharp 100% opaque smooth core stroke cleanly ON TOP
              final corePaint = Paint()
                ..isAntiAlias = lineStyle.antiAlias
                ..style = PaintingStyle.stroke
                ..strokeWidth = effectiveWidth
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round;
              for (final ch in chunks) {
                if ((ch.$3 - ch.$2).distanceSquared > 1e-3 && ch.$4 != ch.$5) {
                  corePaint
                    ..color = ch.$4
                    ..shader = ui.Gradient.linear(ch.$2, ch.$3, [ch.$4, ch.$5]);
                } else {
                  corePaint
                    ..shader = null
                    ..color = ch.$4;
                }
                canvas.drawPath(ch.$1, corePaint);
              }
            } else {
              final path = _buildSmoothPath(screenPts, lineStyle.smoothness);
              final baseColor = _parseColor(p.color);
              // Pass 1: fast 2-layer optical halo underneath (no expensive GPU blur stall)
              if (glowStrength > 0.01) {
                canvas.drawPath(
                  path,
                  Paint()
                    ..isAntiAlias = lineStyle.antiAlias
                    ..color = baseColor.withValues(alpha: 0.14 * glowStrength)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = effectiveWidth * (2.3 + 1.1 * glowStrength)
                    ..strokeCap = StrokeCap.round
                    ..strokeJoin = StrokeJoin.round,
                );
                canvas.drawPath(
                  path,
                  Paint()
                    ..isAntiAlias = lineStyle.antiAlias
                    ..color = baseColor.withValues(alpha: 0.24 * glowStrength)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = effectiveWidth * (1.45 + 0.5 * glowStrength)
                    ..strokeCap = StrokeCap.round
                    ..strokeJoin = StrokeJoin.round,
                );
              }
              // Pass 2: crisp solid vector core on top
              canvas.drawPath(
                path,
                Paint()
                  ..isAntiAlias = lineStyle.antiAlias
                  ..color = baseColor
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = effectiveWidth
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round,
              );
            }
          }
          if (p.showHead && visible.isNotEmpty) {
            final tip = viewport.toScreen(visible.last.$1, visible.last.$2);
            final tipColor = _parseColor(
              p.colorAt(visible.length - 1, p.progress.clamp(0.0, 1.0)),
            );
            if (lineStyle.glowIntensity > 0.05) {
              canvas.drawCircle(
                tip,
                9.5,
                Paint()
                  ..isAntiAlias = lineStyle.antiAlias
                  ..color = tipColor.withValues(
                      alpha: 0.28 * lineStyle.glowIntensity.clamp(0.2, 1.0)),
              );
            }
            canvas.drawCircle(
              tip,
              4.8,
              Paint()
                ..isAntiAlias = lineStyle.antiAlias
                ..color = tipColor,
            );
            canvas.drawCircle(
              tip,
              2.0,
              Paint()
                ..isAntiAlias = lineStyle.antiAlias
                ..color = Colors.white,
            );
          }
        case QudsGeoArc():
          final c = viewport.toScreen(p.cx, p.cy);
          final r = p.radius * viewport.scale;
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            -p.startAngle,
            -(p.endAngle - p.startAngle),
            false,
            Paint()
              ..color = _parseColor(p.color)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        case QudsGeoAngle():
          final v = viewport.toScreen(p.vx, p.vy);
          final a = viewport.toScreen(p.ax, p.ay);
          final b = viewport.toScreen(p.bx, p.by);
          final angA = math.atan2(a.dy - v.dy, a.dx - v.dx);
          final angB = math.atan2(b.dy - v.dy, b.dx - v.dx);
          var sweep = angB - angA;
          while (sweep > math.pi) {
            sweep -= 2 * math.pi;
          }
          while (sweep < -math.pi) {
            sweep += 2 * math.pi;
          }
          const arcR = 26.0;
          canvas.drawArc(
            Rect.fromCircle(center: v, radius: arcR),
            angA,
            sweep,
            false,
            Paint()
              ..color = _parseColor(p.color)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2,
          );
          final label = p.label ??
              (p.showDegrees ? '${p.degrees.toStringAsFixed(1)}°' : '');
          if (label.isNotEmpty) {
            final midAngle = angA + sweep / 2;
            final tx = v.dx + math.cos(midAngle) * (arcR + 14);
            final ty = v.dy + math.sin(midAngle) * (arcR + 14);
            _drawLabel(canvas, label, Offset(tx, ty), _parseColor(p.color));
          }
        case QudsGeoPoint():
          final c = viewport.toScreen(p.x, p.y);
          final color = _parseColor(p.color);
          final isDragged = draggingId == p.id;
          if (p.draggable) {
            canvas.drawCircle(
              c,
              isDragged ? 16 : 12,
              Paint()..color = color.withValues(alpha: isDragged ? 0.35 : 0.2),
            );
          }
          canvas.drawCircle(
              c, p.draggable ? 6.5 : p.radius, Paint()..color = color);
          canvas.drawCircle(
            c,
            p.draggable ? 6.5 : p.radius,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = p.draggable ? 2.2 : 1.2,
          );
          if (p.label != null && p.label!.isNotEmpty) {
            _drawLabel(
              canvas,
              '${p.label} (${p.x.toStringAsFixed(1)}, ${p.y.toStringAsFixed(1)})',
              c + const Offset(10, -14),
              textColor,
            );
          }
        case QudsGeoLabel():
          final c = viewport.toScreen(p.x, p.y);
          _drawLabel(canvas, p.text, c, _parseColor(p.color));
      }
    }

    if (scene.title != null && scene.title!.isNotEmpty) {
      _drawLabel(canvas, scene.title!, const Offset(14, 12), textColor,
          fontSize: 13, bold: true);
    }

    canvas.restore();
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final total = (b - a).distance;
    if (total < 1e-3) return;
    final dir = (b - a) / total;
    const dash = 6.0;
    const gap = 4.0;
    var d = 0.0;
    while (d < total) {
      final end = math.min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d += dash + gap;
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    double fontSize = 11.5,
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
          fontFamily: 'IBMPlexSansArabic',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _GeometryScenePainter old) =>
      old.scene != scene ||
      old.draggingId != draggingId ||
      old.isDark != isDark ||
      old.lineStyle != lineStyle;
}

/// Builds a smooth Catmull-Rom -> Cubic Bezier [Path] passing strictly through
/// all screen points [pts], blended cleanly from raw polyline (`smoothness = 0`)
/// to full C1 Catmull-Rom spline (`smoothness = 1`).
Path _buildSmoothPath(List<Offset> pts, double smoothness) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 1) return path;
  final s = smoothness.clamp(0.0, 1.0);
  if (s <= 0.02 || pts.length < 3) {
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }
  final tension = s * 0.5;
  final n = pts.length;
  for (var i = 0; i < n - 1; i++) {
    final p0 = pts[i > 0 ? i - 1 : 0];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = pts[i + 2 < n ? i + 2 : n - 1];
    final c1 = p1 + (p2 - p0) * (tension / 3.0);
    final c2 = p2 - (p3 - p1) * (tension / 3.0);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// Builds a smooth Catmull-Rom cubic Bezier sub-path spanning `[start..end]`
/// using full neighboring context `(p0, p3)` so adjacent chunks join with C1 continuity.
Path _buildCatmullRomSubPath(
  List<Offset> pts,
  int start,
  int end,
  double smoothness,
) {
  final path = Path()..moveTo(pts[start].dx, pts[start].dy);
  final n = pts.length;
  final s = smoothness.clamp(0.0, 1.0);
  if (s <= 0.02 || n < 3) {
    for (var i = start + 1; i <= end; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }
  final tension = s * 0.5;
  for (var i = start; i < end; i++) {
    final p0 = pts[i > 0 ? i - 1 : 0];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = pts[i + 2 < n ? i + 2 : n - 1];
    final c1 = p1 + (p2 - p0) * (tension / 3.0);
    final c2 = p2 - (p3 - p1) * (tension / 3.0);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path;
}

/// 2D Scientific Plot widget rendering [QudsPlot2DOutput].
class QudsPlotCanvas extends StatelessWidget {
  const QudsPlotCanvas({
    super.key,
    required this.plot,
    required this.isDark,
    this.lineStyle = const QudsLineStyleSettings(),
  });

  final QudsPlot2DOutput plot;
  final bool isDark;
  final QudsLineStyleSettings lineStyle;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const Key('quds_plot_canvas'),
      painter: _PlotPainter(plot: plot, isDark: isDark, lineStyle: lineStyle),
      child: const SizedBox.expand(),
    );
  }
}

class _PlotPainter extends CustomPainter {
  const _PlotPainter({
    required this.plot,
    required this.isDark,
    required this.lineStyle,
  });
  final QudsPlot2DOutput plot;
  final bool isDark;
  final QudsLineStyleSettings lineStyle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()
        ..color = isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
    );
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final s in plot.series) {
      for (final x in s.xs) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
      }
      for (final y in s.ys) {
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (!minX.isFinite) return;
    if ((maxX - minX).abs() < 1e-9) {
      minX -= 1;
      maxX += 1;
    }
    if ((maxY - minY).abs() < 1e-9) {
      minY -= 1;
      maxY += 1;
    }

    const padL = 48.0;
    const padR = 20.0;
    const padT = 34.0;
    const padB = 34.0;
    final w = math.max(size.width - padL - padR, 20.0);
    final h = math.max(size.height - padT - padB, 20.0);
    double sx(double x) => padL + ((x - minX) / (maxX - minX)) * w;
    double sy(double y) => padT + h - ((y - minY) / (maxY - minY)) * h;

    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final gx = padL + w * i / 4;
      final gy = padT + h * i / 4;
      canvas.drawLine(Offset(gx, padT), Offset(gx, padT + h), gridPaint);
      canvas.drawLine(Offset(padL, gy), Offset(padL + w, gy), gridPaint);
    }

    canvas.drawRect(
      Rect.fromLTWH(padL, padT, w, h),
      Paint()
        ..color = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)
        ..style = PaintingStyle.stroke,
    );

    final strokeW = (2.2 * lineStyle.strokeScale).clamp(0.8, 6.0);
    for (final s in plot.series) {
      final n = math.min(s.xs.length, s.ys.length);
      if (n < 2) continue;
      final pts = <Offset>[
        for (var i = 0; i < n; i++) Offset(sx(s.xs[i]), sy(s.ys[i])),
      ];
      final path = _buildSmoothPath(pts, lineStyle.smoothness);
      final baseColor = _parseColor(s.color);
      if (lineStyle.glowIntensity > 0.05) {
        canvas.drawPath(
          path,
          Paint()
            ..isAntiAlias = lineStyle.antiAlias
            ..color =
                baseColor.withValues(alpha: 0.25 * lineStyle.glowIntensity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW * (1.5 + 0.8 * lineStyle.glowIntensity)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              1.4 + 2.4 * lineStyle.glowIntensity,
            ),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = lineStyle.antiAlias
          ..color = baseColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (plot.title != null && plot.title!.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: plot.title!,
          style: TextStyle(
            color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, Offset(padL, 10));
    }
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) =>
      old.plot != plot || old.isDark != isDark || old.lineStyle != lineStyle;
}

/// Interactive controls bar auto-generated from `viz.slider`, `viz.toggle`,
/// `viz.select`, `viz.input`, `viz.number`, `viz.color`, and `viz.button`.
class QudsInteractiveControlsBar extends StatelessWidget {
  const QudsInteractiveControlsBar({
    super.key,
    required this.inputs,
    required this.onChanged,
  });

  final List<QudsInteractiveInput> inputs;
  final void Function(String id, Object? value) onChanged;

  @override
  Widget build(BuildContext context) {
    final visible = inputs.where((i) => i.kind != 'draggablePoint').toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final input in visible)
          switch (input.kind) {
            'slider' => SizedBox(
                width: 210,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            input.label ?? input.id,
                            style: const TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          (input.value as num).toStringAsFixed(2),
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: ['IBMPlexSansArabic'],
                            fontSize: 11,
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 26,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6.5),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          key: Key('slider_${input.id}'),
                          value: (input.value as num)
                              .toDouble()
                              .clamp(input.min ?? 0.0, input.max ?? 10.0),
                          min: input.min ?? 0.0,
                          max: input.max ?? 10.0,
                          onChanged: (v) => onChanged(input.id, v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            'toggle' => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    key: Key('toggle_${input.id}'),
                    value: input.value == true,
                    onChanged: (v) => onChanged(input.id, v),
                  ),
                  Text(input.label ?? input.id,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            'select' => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${input.label ?? input.id}: ',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  DropdownButton<String>(
                    key: Key('select_${input.id}'),
                    value: '${input.value}',
                    isDense: true,
                    items: [
                      for (final opt in input.options)
                        DropdownMenuItem(
                          value: '$opt',
                          child: Text('$opt',
                              style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) onChanged(input.id, v);
                    },
                  ),
                ],
              ),
            'textInput' || 'numberInput' => SizedBox(
                width: 165,
                child: TextFormField(
                  key: Key('input_${input.id}_${input.value}'),
                  initialValue: '${input.value ?? ''}',
                  keyboardType: input.kind == 'numberInput'
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    labelText: input.label ?? input.id,
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onFieldSubmitted: (v) {
                    if (input.kind == 'numberInput') {
                      final parsed = double.tryParse(v);
                      if (parsed != null) onChanged(input.id, parsed);
                    } else {
                      onChanged(input.id, v);
                    }
                  },
                ),
              ),
            'color' => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${input.label ?? input.id}: ',
                      style: const TextStyle(fontSize: 12)),
                  for (final hex in const [
                    '#2563EB',
                    '#10B981',
                    '#F59E0B',
                    '#EF4444',
                    '#8B5CF6',
                  ])
                    GestureDetector(
                      onTap: () => onChanged(input.id, hex),
                      child: Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Color(
                              int.parse('FF${hex.substring(1)}', radix: 16)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: '${input.value}' == hex
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            'button' => FilledButton.tonal(
                key: Key('btn_input_${input.id}'),
                onPressed: () {
                  final next =
                      (input.value is num ? (input.value as num).toInt() : 0) +
                          1;
                  onChanged(input.id, next);
                },
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  '${input.label ?? input.id} (${input.value ?? 0})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            _ => const SizedBox.shrink(),
          },
      ],
    );
  }
}

/// Structured table renderer for [QudsTableOutput].
class QudsTableCard extends StatelessWidget {
  const QudsTableCard({super.key, required this.table});
  final QudsTableOutput table;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (table.title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  table.title!,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 32,
                dataRowMinHeight: 28,
                dataRowMaxHeight: 34,
                columns: [
                  for (final col in table.columns)
                    DataColumn(
                      label: Text(col,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
                rows: [
                  for (final row in table.rows)
                    DataRow(cells: [
                      for (final cell in row)
                        DataCell(Text('$cell',
                            style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontFamilyFallback: ['IBMPlexSansArabic'],
                                fontSize: 12))),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _parseColor(String hex) {
  final cleaned = hex.replaceFirst('#', '').trim();
  if (cleaned.length == 6) {
    final val = int.tryParse('FF$cleaned', radix: 16);
    if (val != null) return Color(val);
  } else if (cleaned.length == 8) {
    // CSS #RRGGBBAA -> Flutter 0xAARRGGBB
    final rrggbb = cleaned.substring(0, 6);
    final aa = cleaned.substring(6, 8);
    final val = int.tryParse('$aa$rrggbb', radix: 16);
    if (val != null) return Color(val);
  }
  return const Color(0xFF38BDF8);
}
