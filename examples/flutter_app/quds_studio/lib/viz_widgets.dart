/// Interactive Flutter visualizers for `QudsOutput`:
/// - `QudsGeometryCanvas`: interactive 2D geometry painter with real mouse/touch
///   drag-and-drop on draggable handles (`A`, `B`, `C`) + live centroid/angle/mesh.
/// - `QudsPlotCanvas`: 2D scientific plot painter.
/// - `QudsInteractiveControlsBar`: auto-generated Sliders & Switches for `viz.slider`/`viz.toggle`.
/// - `QudsTableCard` & `QudsMatrixCard`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

/// Interactive 2D Geometry Canvas rendering [QudsGeometrySceneOutput] with
/// pointer hit-testing and real-time drag-and-drop for draggable handles.
class QudsGeometryCanvas extends StatefulWidget {
  const QudsGeometryCanvas({
    super.key,
    required this.scene,
    required this.onDragPoint,
    required this.isDark,
  });

  final QudsGeometrySceneOutput scene;
  final void Function(String id, double x, double y) onDragPoint;
  final bool isDark;

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
  });

  final QudsGeometrySceneOutput scene;
  final _GeoViewport viewport;
  final String? draggingId;
  final bool isDark;

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
            canvas.drawPath(path, Paint()..color = _parseColor(p.fill!));
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = _parseColor(p.stroke)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        case QudsGeoCircle():
          final c = viewport.toScreen(p.cx, p.cy);
          final r = p.radius * viewport.scale;
          if (p.fill != null) {
            canvas.drawCircle(c, r, Paint()..color = _parseColor(p.fill!));
          }
          canvas.drawCircle(
            c,
            r,
            Paint()
              ..color = _parseColor(p.stroke)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        case QudsGeoSegment():
          final a = viewport.toScreen(p.x1, p.y1);
          final b = viewport.toScreen(p.x2, p.y2);
          final paint = Paint()
            ..color = _parseColor(p.color)
            ..strokeWidth = p.strokeWidth;
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
                ..color = _parseColor(p.color)
                ..strokeWidth = 1.5,
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
              ..color = vecColor
              ..strokeWidth = 2.4
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
            canvas.drawPath(arrow, Paint()..color = vecColor);
          }
          if (p.label != null && p.label!.isNotEmpty) {
            _drawLabel(canvas, p.label!, b + const Offset(8, -10), vecColor);
          }
        case QudsGeoCurve():
          final visible = p.visiblePoints();
          if (visible.length >= 2) {
            final hasMultiColor =
                p.gradientColors.length >= 2 || p.pointColors.isNotEmpty;
            if (hasMultiColor) {
              final denom = math.max(1, p.points.length - 1);
              final corePaint = Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = p.strokeWidth
                ..strokeCap = StrokeCap.round;
              final glowPaint = p.glow
                  ? (Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = p.strokeWidth * 2.8
                    ..strokeCap = StrokeCap.round)
                  : null;
              for (var i = 0; i < visible.length - 1; i++) {
                final t = (i / denom).clamp(0.0, 1.0);
                final segColor = _parseColor(p.colorAt(i, t));
                final pa = viewport.toScreen(visible[i].$1, visible[i].$2);
                final pb =
                    viewport.toScreen(visible[i + 1].$1, visible[i + 1].$2);
                if (glowPaint != null) {
                  glowPaint.color = segColor.withValues(alpha: 0.22);
                  canvas.drawLine(pa, pb, glowPaint);
                }
                corePaint.color = segColor;
                canvas.drawLine(pa, pb, corePaint);
              }
            } else {
              final path = Path();
              final first =
                  viewport.toScreen(visible.first.$1, visible.first.$2);
              path.moveTo(first.dx, first.dy);
              for (var i = 1; i < visible.length; i++) {
                final pt = viewport.toScreen(visible[i].$1, visible[i].$2);
                path.lineTo(pt.dx, pt.dy);
              }
              final baseColor = _parseColor(p.color);
              if (p.glow) {
                canvas.drawPath(
                  path,
                  Paint()
                    ..color = baseColor.withValues(alpha: 0.24)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = p.strokeWidth * 2.8
                    ..strokeCap = StrokeCap.round
                    ..strokeJoin = StrokeJoin.round,
                );
              }
              canvas.drawPath(
                path,
                Paint()
                  ..color = baseColor
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = p.strokeWidth
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
            canvas.drawCircle(
              tip,
              11,
              Paint()..color = tipColor.withValues(alpha: 0.28),
            );
            canvas.drawCircle(tip, 5.5, Paint()..color = tipColor);
            canvas.drawCircle(tip, 2.3, Paint()..color = Colors.white);
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
      old.isDark != isDark;
}

/// 2D Scientific Plot widget rendering [QudsPlot2DOutput].
class QudsPlotCanvas extends StatelessWidget {
  const QudsPlotCanvas({
    super.key,
    required this.plot,
    required this.isDark,
  });

  final QudsPlot2DOutput plot;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const Key('quds_plot_canvas'),
      painter: _PlotPainter(plot: plot, isDark: isDark),
      child: const SizedBox.expand(),
    );
  }
}

class _PlotPainter extends CustomPainter {
  const _PlotPainter({required this.plot, required this.isDark});
  final QudsPlot2DOutput plot;
  final bool isDark;

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

    for (final s in plot.series) {
      final n = math.min(s.xs.length, s.ys.length);
      if (n < 2) continue;
      final path = Path()..moveTo(sx(s.xs[0]), sy(s.ys[0]));
      for (var i = 1; i < n; i++) {
        path.lineTo(sx(s.xs[i]), sy(s.ys[i]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _parseColor(s.color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
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
      old.plot != plot || old.isDark != isDark;
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
