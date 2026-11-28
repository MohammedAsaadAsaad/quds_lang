/// Structured rich scientific outputs and interactive geometry scene protocol
/// (`QudsOutput`, `QudsPlot2DOutput`, `QudsGeometrySceneOutput`, `QudsTableOutput`,
/// `QudsMatrixOutput`, `QudsTextOutput`).
///
/// 100% pure Dart (zero `dart:io` or Flutter dependencies), fully JSON
/// serializable, and includes a clean built-in SVG exporter for testing,
/// reporting, and lightweight web/desktop previews.
library;

import 'dart:math' as math;

/// Base sealed class for all rich scientific outputs emitted by a [QudsSession].
sealed class QudsOutput {
  const QudsOutput();
  String get kind;
  Map<String, Object?> toJson();
}

/// Text, Markdown, or LaTeX output block.
class QudsTextOutput extends QudsOutput {
  const QudsTextOutput(this.text, {this.format = 'plain', this.title});

  final String text;
  final String format; // 'plain' | 'markdown' | 'latex'
  final String? title;

  @override
  String get kind => 'text';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'format': format,
        'text': text,
        if (title != null) 'title': title,
      };
}

/// Structured tabular output (DataFrame / experiment table).
class QudsTableOutput extends QudsOutput {
  const QudsTableOutput({
    required this.columns,
    required this.rows,
    this.title,
  });

  final List<String> columns;
  final List<List<Object?>> rows;
  final String? title;

  @override
  String get kind => 'table';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        if (title != null) 'title': title,
        'columns': columns,
        'rows': rows,
      };
}

/// Structured 2D numeric matrix output with dimensions and quick statistics.
class QudsMatrixOutput extends QudsOutput {
  const QudsMatrixOutput(this.values, {this.title});

  final List<List<double>> values;
  final String? title;

  int get rows => values.length;
  int get cols => values.isEmpty ? 0 : values.first.length;

  @override
  String get kind => 'matrix';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        if (title != null) 'title': title,
        'rows': rows,
        'cols': cols,
        'values': values,
      };
}

/// One data series inside a [QudsPlot2DOutput].
class QudsPlotSeries {
  const QudsPlotSeries({
    required this.xs,
    required this.ys,
    this.name = '',
    this.kind = 'line',
    this.color = '#2563EB',
  });

  final List<double> xs;
  final List<double> ys;
  final String name;
  final String kind; // 'line' | 'scatter' | 'bar' | 'area'
  final String color;

  Map<String, Object?> toJson() => {
        'name': name,
        'kind': kind,
        'color': color,
        'xs': xs,
        'ys': ys,
      };
}

/// Structured 2D scientific plot output with built-in SVG export.
class QudsPlot2DOutput extends QudsOutput {
  const QudsPlot2DOutput({
    required this.series,
    this.interactiveInputs = const [],
    this.animation,
    this.title,
    this.xLabel,
    this.yLabel,
    this.showGrid = true,
    this.showLegend = true,
  });

  final List<QudsPlotSeries> series;
  final List<QudsInteractiveInput> interactiveInputs;
  final QudsAnimationSpec? animation;
  final String? title;
  final String? xLabel;
  final String? yLabel;
  final bool showGrid;
  final bool showLegend;

  @override
  String get kind => 'plot2d';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        if (title != null) 'title': title,
        if (xLabel != null) 'xLabel': xLabel,
        if (yLabel != null) 'yLabel': yLabel,
        'showGrid': showGrid,
        'showLegend': showLegend,
        if (animation != null) 'animation': animation!.toJson(),
        'interactiveInputs': [for (final i in interactiveInputs) i.toJson()],
        'series': [for (final s in series) s.toJson()],
      };

  /// Renders a clean standalone SVG representation of this 2D plot.
  String toSvg({int width = 640, int height = 400}) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final s in series) {
      for (final x in s.xs) {
        if (x.isFinite) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
        }
      }
      for (final y in s.ys) {
        if (y.isFinite) {
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    if (!minX.isFinite) {
      minX = 0;
      maxX = 1;
      minY = 0;
      maxY = 1;
    }
    if ((maxX - minX).abs() < 1e-12) {
      minX -= 1;
      maxX += 1;
    }
    if ((maxY - minY).abs() < 1e-12) {
      minY -= 1;
      maxY += 1;
    }

    const padL = 56.0;
    const padR = 24.0;
    const padT = 36.0;
    const padB = 44.0;
    final plotW = width - padL - padR;
    final plotH = height - padT - padB;
    double sx(double x) => padL + ((x - minX) / (maxX - minX)) * plotW;
    double sy(double y) => padT + plotH - ((y - minY) / (maxY - minY)) * plotH;

    final buf = StringBuffer()
      ..writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">')
      ..writeln('<rect width="100%" height="100%" fill="#0F172A"/>');
    if (title != null && title!.isNotEmpty) {
      buf.writeln(
          '<text x="${width / 2}" y="22" text-anchor="middle" fill="#F8FAFC" font-family="sans-serif" font-size="14" font-weight="600">${_esc(title!)}</text>');
    }
    if (showGrid) {
      for (var i = 0; i <= 4; i++) {
        final gx = padL + (plotW * i / 4);
        final gy = padT + (plotH * i / 4);
        buf.writeln(
            '<line x1="${gx.toStringAsFixed(1)}" y1="$padT" x2="${gx.toStringAsFixed(1)}" y2="${padT + plotH}" stroke="#1E293B" stroke-width="1"/>');
        buf.writeln(
            '<line x1="$padL" y1="${gy.toStringAsFixed(1)}" x2="${padL + plotW}" y2="${gy.toStringAsFixed(1)}" stroke="#1E293B" stroke-width="1"/>');
      }
    }
    buf.writeln(
        '<rect x="$padL" y="$padT" width="$plotW" height="$plotH" fill="none" stroke="#475569" stroke-width="1"/>');

    for (final s in series) {
      final n = math.min(s.xs.length, s.ys.length);
      if (n == 0) continue;
      if (s.kind == 'scatter') {
        for (var i = 0; i < n; i++) {
          buf.writeln(
              '<circle cx="${sx(s.xs[i]).toStringAsFixed(2)}" cy="${sy(s.ys[i]).toStringAsFixed(2)}" r="3.5" fill="${_esc(s.color)}"/>');
        }
      } else {
        final pts = [
          for (var i = 0; i < n; i++)
            '${sx(s.xs[i]).toStringAsFixed(2)},${sy(s.ys[i]).toStringAsFixed(2)}'
        ].join(' ');
        buf.writeln(
            '<polyline fill="none" stroke="${_esc(s.color)}" stroke-width="2" points="$pts"/>');
      }
    }
    if (xLabel != null && xLabel!.isNotEmpty) {
      buf.writeln(
          '<text x="${padL + plotW / 2}" y="${height - 10}" text-anchor="middle" fill="#CBD5E1" font-family="sans-serif" font-size="12">${_esc(xLabel!)}</text>');
    }
    if (yLabel != null && yLabel!.isNotEmpty) {
      buf.writeln(
          '<text x="16" y="${padT + plotH / 2}" text-anchor="middle" fill="#CBD5E1" font-family="sans-serif" font-size="12" transform="rotate(-90 16 ${padT + plotH / 2})">${_esc(yLabel!)}</text>');
    }
    buf.writeln('</svg>');
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// Interactive 2D Geometry Scene Protocol
// ---------------------------------------------------------------------------

/// Axis-aligned world-coordinate bounding box for a geometry scene.
class QudsGeoBounds {
  const QudsGeoBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;

  Map<String, Object?> toJson() => {
        'minX': minX,
        'maxX': maxX,
        'minY': minY,
        'maxY': maxY,
      };

  static QudsGeoBounds fromJson(Map<String, Object?> json) => QudsGeoBounds(
        minX: (json['minX'] as num).toDouble(),
        maxX: (json['maxX'] as num).toDouble(),
        minY: (json['minY'] as num).toDouble(),
        maxY: (json['maxY'] as num).toDouble(),
      );
}

/// Interactive parameter declared by a Quds script (slider, draggable point,
/// toggle, or choice) so the host UI can render live controls and call
/// `session.updateInteractiveInputs(...)`.
class QudsInteractiveInput {
  const QudsInteractiveInput({
    required this.id,
    required this.kind,
    required this.value,
    this.label,
    this.min,
    this.max,
    this.step,
    this.options = const [],
  });

  final String id;
  final String kind; // 'draggablePoint' | 'slider' | 'toggle' | 'choice'
  final Object? value;
  final String? label;
  final double? min;
  final double? max;
  final double? step;
  final List<Object?> options;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'value': value,
        if (label != null) 'label': label,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (step != null) 'step': step,
        if (options.isNotEmpty) 'options': options,
      };

  static QudsInteractiveInput fromJson(Map<String, Object?> json) =>
      QudsInteractiveInput(
        id: json['id'] as String,
        kind: json['kind'] as String,
        value: json['value'],
        label: json['label'] as String?,
        min: (json['min'] as num?)?.toDouble(),
        max: (json['max'] as num?)?.toDouble(),
        step: (json['step'] as num?)?.toDouble(),
        options: (json['options'] as List?) ?? const [],
      );
}

/// Base class for all 2D geometric primitives inside [QudsGeometrySceneOutput].
sealed class QudsGeoPrimitive {
  const QudsGeoPrimitive({required this.id, this.label});
  final String id;
  final String? label;
  String get kind;
  Map<String, Object?> toJson();

  static QudsGeoPrimitive fromJson(Map<String, Object?> json) {
    final kind = json['kind'] as String;
    return switch (kind) {
      'point' => QudsGeoPoint(
          id: json['id'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          label: json['label'] as String?,
          color: (json['color'] as String?) ?? '#2563EB',
          radius: (json['radius'] as num?)?.toDouble() ?? 5.0,
          draggable: (json['draggable'] as bool?) ?? false,
        ),
      'segment' => QudsGeoSegment(
          id: json['id'] as String,
          x1: (json['x1'] as num).toDouble(),
          y1: (json['y1'] as num).toDouble(),
          x2: (json['x2'] as num).toDouble(),
          y2: (json['y2'] as num).toDouble(),
          label: json['label'] as String?,
          color: (json['color'] as String?) ?? '#64748B',
          dashed: (json['dashed'] as bool?) ?? false,
          strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
        ),
      'line' => QudsGeoLine(
          id: json['id'] as String,
          x1: (json['x1'] as num).toDouble(),
          y1: (json['y1'] as num).toDouble(),
          x2: (json['x2'] as num).toDouble(),
          y2: (json['y2'] as num).toDouble(),
          label: json['label'] as String?,
          color: (json['color'] as String?) ?? '#94A3B8',
          dashed: (json['dashed'] as bool?) ?? false,
        ),
      'circle' => QudsGeoCircle(
          id: json['id'] as String,
          cx: (json['cx'] as num).toDouble(),
          cy: (json['cy'] as num).toDouble(),
          radius: (json['radius'] as num).toDouble(),
          label: json['label'] as String?,
          stroke: (json['stroke'] as String?) ?? '#2563EB',
          fill: json['fill'] as String?,
          dashed: (json['dashed'] as bool?) ?? false,
        ),
      'arc' => QudsGeoArc(
          id: json['id'] as String,
          cx: (json['cx'] as num).toDouble(),
          cy: (json['cy'] as num).toDouble(),
          radius: (json['radius'] as num).toDouble(),
          startAngle: (json['startAngle'] as num).toDouble(),
          endAngle: (json['endAngle'] as num).toDouble(),
          label: json['label'] as String?,
          color: (json['color'] as String?) ?? '#10B981',
        ),
      'polygon' => QudsGeoPolygon(
          id: json['id'] as String,
          points: [
            for (final pt in (json['points'] as List))
              ((pt as List)[0] as num).toDouble(),
          ].isEmpty
              ? const []
              : [
                  for (final pt in (json['points'] as List))
                    ((pt as List)[0] as num).toDouble()
                ].indexed.map((e) {
                  final raw = (json['points'] as List)[e.$1] as List;
                  return (
                    (raw[0] as num).toDouble(),
                    (raw[1] as num).toDouble()
                  );
                }).toList(),
          label: json['label'] as String?,
          stroke: (json['stroke'] as String?) ?? '#2563EB',
          fill: json['fill'] as String?,
          closed: (json['closed'] as bool?) ?? true,
        ),
      'vector' => QudsGeoVector(
          id: json['id'] as String,
          x1: (json['x1'] as num).toDouble(),
          y1: (json['y1'] as num).toDouble(),
          x2: (json['x2'] as num).toDouble(),
          y2: (json['y2'] as num).toDouble(),
          label: json['label'] as String?,
          color: (json['color'] as String?) ?? '#F59E0B',
        ),
      'angle' => QudsGeoAngle(
          id: json['id'] as String,
          ax: (json['ax'] as num).toDouble(),
          ay: (json['ay'] as num).toDouble(),
          vx: (json['vx'] as num).toDouble(),
          vy: (json['vy'] as num).toDouble(),
          bx: (json['bx'] as num).toDouble(),
          by: (json['by'] as num).toDouble(),
          degrees: (json['degrees'] as num).toDouble(),
          label: json['label'] as String?,
          color: (json['color'] as String?) ?? '#10B981',
          showDegrees: (json['showDegrees'] as bool?) ?? true,
        ),
      'curve' => QudsGeoCurve(
          id: json['id'] as String,
          points: [
            for (final pt in (json['points'] as List))
              (((pt as List)[0] as num).toDouble(), (pt[1] as num).toDouble()),
          ],
          label: json['label'] as String?,
          color: (json['color'] as String?) ?? '#8B5CF6',
          strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 2.0,
          gradientColors: [
            for (final c in (json['gradientColors'] as List? ?? const [])) '$c',
          ],
          pointColors: [
            for (final c in (json['pointColors'] as List? ?? const [])) '$c',
          ],
          progress: (json['progress'] as num?)?.toDouble() ?? 1.0,
          glow: (json['glow'] as bool?) ?? false,
          showHead: (json['showHead'] as bool?) ?? false,
        ),
      'label' => QudsGeoLabel(
          id: json['id'] as String,
          x: (json['x'] as num).toDouble(),
          y: (json['y'] as num).toDouble(),
          text: json['text'] as String,
          color: (json['color'] as String?) ?? '#F8FAFC',
        ),
      _ => throw FormatException('Unknown geometry primitive kind: $kind'),
    };
  }
}

class QudsGeoPoint extends QudsGeoPrimitive {
  const QudsGeoPoint({
    required super.id,
    required this.x,
    required this.y,
    super.label,
    this.color = '#2563EB',
    this.radius = 5.0,
    this.draggable = false,
  });

  final double x;
  final double y;
  final String color;
  final double radius;
  final bool draggable;

  @override
  String get kind => 'point';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'x': x,
        'y': y,
        if (label != null) 'label': label,
        'color': color,
        'radius': radius,
        'draggable': draggable,
      };
}

class QudsGeoSegment extends QudsGeoPrimitive {
  const QudsGeoSegment({
    required super.id,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    super.label,
    this.color = '#64748B',
    this.dashed = false,
    this.strokeWidth = 2.0,
  });

  final double x1, y1, x2, y2;
  final String color;
  final bool dashed;
  final double strokeWidth;

  @override
  String get kind => 'segment';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        if (label != null) 'label': label,
        'color': color,
        'dashed': dashed,
        'strokeWidth': strokeWidth,
      };
}

class QudsGeoLine extends QudsGeoPrimitive {
  const QudsGeoLine({
    required super.id,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    super.label,
    this.color = '#94A3B8',
    this.dashed = false,
  });

  final double x1, y1, x2, y2;
  final String color;
  final bool dashed;

  @override
  String get kind => 'line';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        if (label != null) 'label': label,
        'color': color,
        'dashed': dashed,
      };
}

class QudsGeoCircle extends QudsGeoPrimitive {
  const QudsGeoCircle({
    required super.id,
    required this.cx,
    required this.cy,
    required this.radius,
    super.label,
    this.stroke = '#2563EB',
    this.fill,
    this.dashed = false,
  });

  final double cx, cy, radius;
  final String stroke;
  final String? fill;
  final bool dashed;

  @override
  String get kind => 'circle';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'cx': cx,
        'cy': cy,
        'radius': radius,
        if (label != null) 'label': label,
        'stroke': stroke,
        if (fill != null) 'fill': fill,
        'dashed': dashed,
      };
}

class QudsGeoArc extends QudsGeoPrimitive {
  const QudsGeoArc({
    required super.id,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.startAngle,
    required this.endAngle,
    super.label,
    this.color = '#10B981',
  });

  final double cx, cy, radius, startAngle, endAngle;
  final String color;

  @override
  String get kind => 'arc';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'cx': cx,
        'cy': cy,
        'radius': radius,
        'startAngle': startAngle,
        'endAngle': endAngle,
        if (label != null) 'label': label,
        'color': color,
      };
}

class QudsGeoPolygon extends QudsGeoPrimitive {
  const QudsGeoPolygon({
    required super.id,
    required this.points,
    super.label,
    this.stroke = '#2563EB',
    this.fill,
    this.closed = true,
  });

  final List<(double, double)> points;
  final String stroke;
  final String? fill;
  final bool closed;

  @override
  String get kind => 'polygon';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'points': [
          for (final p in points) [p.$1, p.$2]
        ],
        if (label != null) 'label': label,
        'stroke': stroke,
        if (fill != null) 'fill': fill,
        'closed': closed,
      };
}

class QudsGeoVector extends QudsGeoPrimitive {
  const QudsGeoVector({
    required super.id,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    super.label,
    this.color = '#F59E0B',
  });

  final double x1, y1, x2, y2;
  final String color;

  @override
  String get kind => 'vector';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'x1': x1,
        'y1': y1,
        'x2': x2,
        'y2': y2,
        if (label != null) 'label': label,
        'color': color,
      };
}

class QudsGeoAngle extends QudsGeoPrimitive {
  const QudsGeoAngle({
    required super.id,
    required this.ax,
    required this.ay,
    required this.vx,
    required this.vy,
    required this.bx,
    required this.by,
    required this.degrees,
    super.label,
    this.color = '#10B981',
    this.showDegrees = true,
  });

  final double ax, ay, vx, vy, bx, by, degrees;
  final String color;
  final bool showDegrees;

  @override
  String get kind => 'angle';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'ax': ax,
        'ay': ay,
        'vx': vx,
        'vy': vy,
        'bx': bx,
        'by': by,
        'degrees': degrees,
        if (label != null) 'label': label,
        'color': color,
        'showDegrees': showDegrees,
      };
}

class QudsGeoCurve extends QudsGeoPrimitive {
  const QudsGeoCurve({
    required super.id,
    required this.points,
    super.label,
    this.color = '#8B5CF6',
    this.strokeWidth = 2.0,
    this.gradientColors = const [],
    this.pointColors = const [],
    this.progress = 1.0,
    this.glow = false,
    this.showHead = false,
  });

  final List<(double, double)> points;
  final String color;
  final double strokeWidth;

  /// Optional multi-stop color gradient sampled smoothly along the curve
  /// (from point 0 to the last point).
  final List<String> gradientColors;

  /// Optional explicit per-point hex colors (`pointColors.length == points.length`).
  final List<String> pointColors;

  /// Progressive drawing ratio in `[0.0, 1.0]` (`1.0` draws the full curve;
  /// animating `0.0 -> 1.0` draws smoothly from the first point to the last).
  final double progress;

  /// Whether to render a luminous outer glow bloom along the curve.
  final bool glow;

  /// Whether to render a moving pen-head indicator dot at the live drawing tip.
  final bool showHead;

  /// Computes the active visible slice of [points] up to [progress] (with smooth
  /// linear interpolation of the final tip point).
  List<(double, double)> visiblePoints() {
    if (points.isEmpty) return const [];
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0.0) return [points.first];
    if (p >= 1.0 || points.length == 1) return points;
    final exactIdx = p * (points.length - 1);
    final lastFull = exactIdx.floor();
    final frac = exactIdx - lastFull;
    final out = points.sublist(0, lastFull + 1);
    if (frac > 1e-6 && lastFull + 1 < points.length) {
      final a = points[lastFull];
      final b = points[lastFull + 1];
      out.add((a.$1 + (b.$1 - a.$1) * frac, a.$2 + (b.$2 - a.$2) * frac));
    }
    return out;
  }

  /// Resolves the hex color at normalized position [t] in `[0.0, 1.0]` or vertex [index].
  String colorAt(int index, double t) {
    if (pointColors.isNotEmpty) {
      return pointColors[index.clamp(0, pointColors.length - 1)];
    }
    if (gradientColors.length >= 2) {
      return qudsSampleGradientHex(gradientColors, t);
    }
    if (gradientColors.length == 1) return gradientColors.first;
    return color;
  }

  @override
  String get kind => 'curve';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'points': [
          for (final p in points) [p.$1, p.$2]
        ],
        if (label != null) 'label': label,
        'color': color,
        'strokeWidth': strokeWidth,
        if (gradientColors.isNotEmpty) 'gradientColors': gradientColors,
        if (pointColors.isNotEmpty) 'pointColors': pointColors,
        if (progress != 1.0) 'progress': progress,
        if (glow) 'glow': glow,
        if (showHead) 'showHead': showHead,
      };
}

class QudsGeoLabel extends QudsGeoPrimitive {
  const QudsGeoLabel({
    required super.id,
    required this.x,
    required this.y,
    required this.text,
    this.color = '#F8FAFC',
  }) : super(label: text);

  final double x, y;
  final String text;
  final String color;

  @override
  String get kind => 'label';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'id': id,
        'x': x,
        'y': y,
        'text': text,
        'color': color,
      };
}

/// Live key-value telemetry reading attached to a [QudsGeometrySceneOutput]
/// (for monitoring physical measurements, coordinates, energy, or progress).
class QudsTelemetryReading {
  const QudsTelemetryReading({
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String? unit;
  final String? color;

  Map<String, Object?> toJson() => {
        'label': label,
        'value': value,
        if (unit != null) 'unit': unit,
        if (color != null) 'color': color,
      };

  static QudsTelemetryReading fromJson(Map<String, Object?> json) =>
      QudsTelemetryReading(
        label: '${json['label'] ?? ''}',
        value: '${json['value'] ?? ''}',
        unit: json['unit'] as String?,
        color: json['color'] as String?,
      );
}

/// Interactive 2D geometry scene output supporting draggable points, parameter
/// sliders, live telemetry readings, auto-fitted or fixed world bounds, full
/// JSON round-trip, and SVG rendering.
class QudsGeometrySceneOutput extends QudsOutput {
  const QudsGeometrySceneOutput({
    required this.primitives,
    required this.bounds,
    this.interactiveInputs = const [],
    this.readings = const [],
    this.animation,
    this.title,
    this.showGrid = true,
    this.showAxes = true,
    this.interactive = true,
  });

  final List<QudsGeoPrimitive> primitives;
  final QudsGeoBounds bounds;
  final List<QudsInteractiveInput> interactiveInputs;
  final List<QudsTelemetryReading> readings;
  final QudsAnimationSpec? animation;
  final String? title;
  final bool showGrid;
  final bool showAxes;
  final bool interactive;

  @override
  String get kind => 'geometry_scene';

  /// Looks up a primitive by its hit-test [id].
  QudsGeoPrimitive? findPrimitive(String id) {
    for (final p in primitives) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// All draggable handle points in this scene.
  List<QudsGeoPoint> get draggablePoints => [
        for (final p in primitives)
          if (p is QudsGeoPoint && p.draggable) p,
      ];

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        if (title != null) 'title': title,
        'showGrid': showGrid,
        'showAxes': showAxes,
        'interactive': interactive,
        'bounds': bounds.toJson(),
        if (animation != null) 'animation': animation!.toJson(),
        'interactiveInputs': [for (final i in interactiveInputs) i.toJson()],
        if (readings.isNotEmpty)
          'readings': [for (final r in readings) r.toJson()],
        'primitives': [for (final p in primitives) p.toJson()],
      };

  static QudsGeometrySceneOutput fromJson(Map<String, Object?> json) =>
      QudsGeometrySceneOutput(
        title: json['title'] as String?,
        showGrid: (json['showGrid'] as bool?) ?? true,
        showAxes: (json['showAxes'] as bool?) ?? true,
        interactive: (json['interactive'] as bool?) ?? true,
        bounds: QudsGeoBounds.fromJson(
            (json['bounds'] as Map).cast<String, Object?>()),
        animation: json['animation'] is Map
            ? QudsAnimationSpec.fromJson(
                (json['animation'] as Map).cast<String, Object?>())
            : null,
        interactiveInputs: [
          for (final raw in (json['interactiveInputs'] as List? ?? const []))
            QudsInteractiveInput.fromJson((raw as Map).cast<String, Object?>()),
        ],
        readings: [
          for (final raw in (json['readings'] as List? ?? const []))
            QudsTelemetryReading.fromJson((raw as Map).cast<String, Object?>()),
        ],
        primitives: [
          for (final raw in (json['primitives'] as List? ?? const []))
            QudsGeoPrimitive.fromJson((raw as Map).cast<String, Object?>()),
        ],
      );

  /// Renders a clean, crisp SVG representation of the geometric scene.
  String toSvg({int width = 640, int height = 420}) {
    const pad = 40.0;
    final viewW = width - pad * 2;
    final viewH = height - pad * 2;
    final scale = math.min(
      viewW / math.max(bounds.width, 1e-6),
      viewH / math.max(bounds.height, 1e-6),
    );
    final midX = (bounds.minX + bounds.maxX) / 2;
    final midY = (bounds.minY + bounds.maxY) / 2;
    double sx(double x) => width / 2 + (x - midX) * scale;
    double sy(double y) => height / 2 - (y - midY) * scale;

    final buf = StringBuffer()
      ..writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">')
      ..writeln('<rect width="100%" height="100%" fill="#0F172A"/>');

    if (showAxes) {
      final ox = sx(0);
      final oy = sy(0);
      buf.writeln(
          '<line x1="0" y1="${oy.toStringAsFixed(1)}" x2="$width" y2="${oy.toStringAsFixed(1)}" stroke="#334155" stroke-width="1"/>');
      buf.writeln(
          '<line x1="${ox.toStringAsFixed(1)}" y1="0" x2="${ox.toStringAsFixed(1)}" y2="$height" stroke="#334155" stroke-width="1"/>');
    }

    if (title != null && title!.isNotEmpty) {
      buf.writeln(
          '<text x="${width / 2}" y="22" text-anchor="middle" fill="#F8FAFC" font-family="sans-serif" font-size="14" font-weight="600">${_esc(title!)}</text>');
    }

    for (final p in primitives) {
      switch (p) {
        case QudsGeoPolygon():
          final pts = [
            for (final pt in p.points)
              '${sx(pt.$1).toStringAsFixed(2)},${sy(pt.$2).toStringAsFixed(2)}'
          ].join(' ');
          final tag = p.closed ? 'polygon' : 'polyline';
          buf.writeln(
              '<$tag data-id="${_esc(p.id)}" points="$pts" fill="${_esc(p.fill ?? 'none')}" stroke="${_esc(p.stroke)}" stroke-width="2"/>');
        case QudsGeoCircle():
          buf.writeln(
              '<circle data-id="${_esc(p.id)}" cx="${sx(p.cx).toStringAsFixed(2)}" cy="${sy(p.cy).toStringAsFixed(2)}" r="${(p.radius * scale).toStringAsFixed(2)}" fill="${_esc(p.fill ?? 'none')}" stroke="${_esc(p.stroke)}" stroke-width="2"${p.dashed ? ' stroke-dasharray="5,4"' : ''}/>');
        case QudsGeoSegment():
          buf.writeln(
              '<line data-id="${_esc(p.id)}" x1="${sx(p.x1).toStringAsFixed(2)}" y1="${sy(p.y1).toStringAsFixed(2)}" x2="${sx(p.x2).toStringAsFixed(2)}" y2="${sy(p.y2).toStringAsFixed(2)}" stroke="${_esc(p.color)}" stroke-width="${p.strokeWidth}"${p.dashed ? ' stroke-dasharray="5,4"' : ''}/>');
        case QudsGeoLine():
          final dx = p.x2 - p.x1;
          final dy = p.y2 - p.y1;
          final extend = math.max(bounds.width, bounds.height) * 4;
          final len = math.sqrt(dx * dx + dy * dy);
          if (len > 1e-12) {
            final ux = dx / len;
            final uy = dy / len;
            buf.writeln(
                '<line data-id="${_esc(p.id)}" x1="${sx(p.x1 - ux * extend).toStringAsFixed(2)}" y1="${sy(p.y1 - uy * extend).toStringAsFixed(2)}" x2="${sx(p.x1 + ux * extend).toStringAsFixed(2)}" y2="${sy(p.y1 + uy * extend).toStringAsFixed(2)}" stroke="${_esc(p.color)}" stroke-width="1.5"${p.dashed ? ' stroke-dasharray="5,4"' : ''}/>');
          }
        case QudsGeoVector():
          buf.writeln(
              '<line data-id="${_esc(p.id)}" x1="${sx(p.x1).toStringAsFixed(2)}" y1="${sy(p.y1).toStringAsFixed(2)}" x2="${sx(p.x2).toStringAsFixed(2)}" y2="${sy(p.y2).toStringAsFixed(2)}" stroke="${_esc(p.color)}" stroke-width="2.2"/>');
        case QudsGeoCurve():
          final visible = p.visiblePoints();
          if (visible.length >= 2) {
            final hasMultiColor =
                p.gradientColors.length >= 2 || p.pointColors.isNotEmpty;
            if (hasMultiColor) {
              final denom = math.max(1, p.points.length - 1);
              for (var i = 0; i < visible.length - 1; i++) {
                final t = (i / denom).clamp(0.0, 1.0);
                final segColor = p.colorAt(i, t);
                final a = visible[i];
                final b = visible[i + 1];
                buf.writeln(
                    '<line data-id="${_esc(p.id)}_$i" x1="${sx(a.$1).toStringAsFixed(2)}" y1="${sy(a.$2).toStringAsFixed(2)}" x2="${sx(b.$1).toStringAsFixed(2)}" y2="${sy(b.$2).toStringAsFixed(2)}" stroke="${_esc(segColor)}" stroke-width="${p.strokeWidth}" stroke-linecap="round"/>');
              }
            } else {
              final pts = [
                for (final pt in visible)
                  '${sx(pt.$1).toStringAsFixed(2)},${sy(pt.$2).toStringAsFixed(2)}'
              ].join(' ');
              buf.writeln(
                  '<polyline data-id="${_esc(p.id)}" fill="none" stroke="${_esc(p.color)}" stroke-width="${p.strokeWidth}" points="$pts"/>');
            }
            if (p.showHead) {
              final tip = visible.last;
              final headColor =
                  p.colorAt(visible.length - 1, p.progress.clamp(0.0, 1.0));
              buf.writeln(
                  '<circle data-id="${_esc(p.id)}_head" cx="${sx(tip.$1).toStringAsFixed(2)}" cy="${sy(tip.$2).toStringAsFixed(2)}" r="5" fill="${_esc(headColor)}" stroke="#FFFFFF" stroke-width="1.5"/>');
            }
          }
        case QudsGeoArc():
          final x1 = sx(p.cx + p.radius * math.cos(p.startAngle));
          final y1 = sy(p.cy + p.radius * math.sin(p.startAngle));
          final x2 = sx(p.cx + p.radius * math.cos(p.endAngle));
          final y2 = sy(p.cy + p.radius * math.sin(p.endAngle));
          final r = p.radius * scale;
          buf.writeln(
              '<path data-id="${_esc(p.id)}" d="M ${x1.toStringAsFixed(2)} ${y1.toStringAsFixed(2)} A ${r.toStringAsFixed(2)} ${r.toStringAsFixed(2)} 0 0 0 ${x2.toStringAsFixed(2)} ${y2.toStringAsFixed(2)}" fill="none" stroke="${_esc(p.color)}" stroke-width="2"/>');
        case QudsGeoAngle():
          final text = p.label ??
              (p.showDegrees ? '${p.degrees.toStringAsFixed(1)}°' : '');
          if (text.isNotEmpty) {
            buf.writeln(
                '<text data-id="${_esc(p.id)}" x="${(sx(p.vx) + 12).toStringAsFixed(2)}" y="${(sy(p.vy) - 10).toStringAsFixed(2)}" fill="${_esc(p.color)}" font-family="sans-serif" font-size="11">${_esc(text)}</text>');
          }
        case QudsGeoPoint():
          final cx = sx(p.x);
          final cy = sy(p.y);
          buf.writeln(
              '<circle data-id="${_esc(p.id)}" data-draggable="${p.draggable}" cx="${cx.toStringAsFixed(2)}" cy="${cy.toStringAsFixed(2)}" r="${p.radius}" fill="${_esc(p.color)}" stroke="#FFFFFF" stroke-width="${p.draggable ? 2 : 1}"/>');
          if (p.label != null && p.label!.isNotEmpty) {
            buf.writeln(
                '<text x="${(cx + p.radius + 4).toStringAsFixed(2)}" y="${(cy - p.radius - 2).toStringAsFixed(2)}" fill="#F8FAFC" font-family="sans-serif" font-size="12">${_esc(p.label!)}</text>');
          }
        case QudsGeoLabel():
          buf.writeln(
              '<text data-id="${_esc(p.id)}" x="${sx(p.x).toStringAsFixed(2)}" y="${sy(p.y).toStringAsFixed(2)}" fill="${_esc(p.color)}" font-family="sans-serif" font-size="12">${_esc(p.text)}</text>');
      }
    }

    buf.writeln('</svg>');
    return buf.toString();
  }
}

/// Samples a multi-stop hex color gradient at [t] in `[0.0, 1.0]`.
String qudsSampleGradientHex(List<String> colors, double t) {
  if (colors.isEmpty) return '#8B5CF6';
  if (colors.length == 1) return colors.first;
  final clamped = t.clamp(0.0, 1.0);
  final scaled = clamped * (colors.length - 1);
  final idx = scaled.floor().clamp(0, colors.length - 2);
  final frac = scaled - idx;
  return qudsLerpHexColor(colors[idx], colors[idx + 1], frac);
}

/// Linearly interpolates two `#RRGGBB` hex colors at [t] in `[0.0, 1.0]`.
String qudsLerpHexColor(String c1, String c2, double t) {
  final a = _parseHexRgb(c1);
  final b = _parseHexRgb(c2);
  final clamped = t.clamp(0.0, 1.0);
  final r = (a.$1 + (b.$1 - a.$1) * clamped).round().clamp(0, 255);
  final g = (a.$2 + (b.$2 - a.$2) * clamped).round().clamp(0, 255);
  final bl = (a.$3 + (b.$3 - a.$3) * clamped).round().clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${bl.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

(int, int, int) _parseHexRgb(String raw) {
  var hex = raw.trim().replaceFirst('#', '');
  if (hex.length == 8) hex = hex.substring(2);
  if (hex.length == 3) {
    hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
  }
  if (hex.length != 6) return (139, 92, 246);
  final v = int.tryParse(hex, radix: 16);
  if (v == null) return (139, 92, 246);
  return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
}

// ---------------------------------------------------------------------------
// Animation Loop, 3D Surface, Vector Field, Graph & Micro-App Form Outputs
// ---------------------------------------------------------------------------

/// Metadata declaring a live frame-stepped animation/simulation loop
/// (driven by `QudsSession.stepFrame(dt)` or `QudsSession.runTimeline(...)`).
class QudsAnimationSpec {
  const QudsAnimationSpec({
    this.fps = 60,
    this.duration,
    this.loop = true,
    this.autoPlay = true,
    this.playing = true,
    this.time = 0.0,
    this.dt = 1.0 / 60.0,
    this.frame = 0,
  });

  final int fps;
  final double? duration;
  final bool loop;
  final bool autoPlay;
  final bool playing;
  final double time;
  final double dt;
  final int frame;

  /// Normalized timeline progress in `[0.0, 1.0]` when [duration] is set.
  double get progress => (duration != null && duration! > 0)
      ? (time / duration!).clamp(0.0, 1.0)
      : 0.0;

  Map<String, Object?> toJson() => {
        'fps': fps,
        if (duration != null) 'duration': duration,
        'loop': loop,
        'autoPlay': autoPlay,
        'playing': playing,
        'time': time,
        'dt': dt,
        'frame': frame,
      };

  static QudsAnimationSpec fromJson(Map<String, Object?> json) =>
      QudsAnimationSpec(
        fps: (json['fps'] as num?)?.toInt() ?? 60,
        duration: (json['duration'] as num?)?.toDouble(),
        loop: (json['loop'] as bool?) ?? true,
        autoPlay: (json['autoPlay'] as bool?) ?? true,
        playing: (json['playing'] as bool?) ?? true,
        time: (json['time'] as num?)?.toDouble() ?? 0.0,
        dt: (json['dt'] as num?)?.toDouble() ?? (1.0 / 60.0),
        frame: (json['frame'] as num?)?.toInt() ?? 0,
      );
}

/// 3D surface grid output `z = f(x, y)` with camera angles, colormap, and SVG export.
class QudsSurface3DOutput extends QudsOutput {
  const QudsSurface3DOutput({
    required this.xs,
    required this.ys,
    required this.zs,
    this.title,
    this.colorMap = 'viridis',
    this.wireframe = true,
    this.yaw = 0.68,
    this.pitch = 0.54,
    this.interactiveInputs = const [],
    this.animation,
  });

  final List<double> xs;
  final List<double> ys;
  final List<List<double>> zs;
  final String? title;
  final String colorMap;
  final bool wireframe;
  final double yaw;
  final double pitch;
  final List<QudsInteractiveInput> interactiveInputs;
  final QudsAnimationSpec? animation;

  @override
  String get kind => 'surface3d';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        if (title != null) 'title': title,
        'colorMap': colorMap,
        'wireframe': wireframe,
        'yaw': yaw,
        'pitch': pitch,
        'xs': xs,
        'ys': ys,
        'zs': zs,
        if (animation != null) 'animation': animation!.toJson(),
        'interactiveInputs': [for (final i in interactiveInputs) i.toJson()],
      };

  static QudsSurface3DOutput fromJson(Map<String, Object?> json) =>
      QudsSurface3DOutput(
        title: json['title'] as String?,
        colorMap: (json['colorMap'] as String?) ?? 'viridis',
        wireframe: (json['wireframe'] as bool?) ?? true,
        yaw: (json['yaw'] as num?)?.toDouble() ?? 0.68,
        pitch: (json['pitch'] as num?)?.toDouble() ?? 0.54,
        xs: [for (final v in (json['xs'] as List)) (v as num).toDouble()],
        ys: [for (final v in (json['ys'] as List)) (v as num).toDouble()],
        zs: [
          for (final row in (json['zs'] as List))
            [for (final v in (row as List)) (v as num).toDouble()]
        ],
        animation: json['animation'] is Map
            ? QudsAnimationSpec.fromJson(
                (json['animation'] as Map).cast<String, Object?>())
            : null,
        interactiveInputs: [
          for (final raw in (json['interactiveInputs'] as List? ?? const []))
            QudsInteractiveInput.fromJson((raw as Map).cast<String, Object?>()),
        ],
      );

  /// Renders a clean isometric-projected 3D surface mesh as standalone SVG.
  String toSvg({int width = 640, int height = 420}) {
    final rows = zs.length;
    final cols = rows == 0 ? 0 : zs.first.length;
    final buf = StringBuffer()
      ..writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">')
      ..writeln('<rect width="100%" height="100%" fill="#0F172A"/>');
    if (title != null && title!.isNotEmpty) {
      buf.writeln(
          '<text x="${width / 2}" y="24" text-anchor="middle" fill="#F8FAFC" font-family="sans-serif" font-size="14" font-weight="600">${_esc(title!)}</text>');
    }
    if (rows < 2 || cols < 2) {
      buf.writeln('</svg>');
      return buf.toString();
    }

    var minZ = double.infinity;
    var maxZ = double.negativeInfinity;
    for (final row in zs) {
      for (final z in row) {
        if (z.isFinite) {
          if (z < minZ) minZ = z;
          if (z > maxZ) maxZ = z;
        }
      }
    }
    if (!minZ.isFinite || (maxZ - minZ).abs() < 1e-12) {
      minZ = -1;
      maxZ = 1;
    }

    final minX = xs.first;
    final maxX = xs.last == minX ? minX + 1 : xs.last;
    final minY = ys.first;
    final maxY = ys.last == minY ? minY + 1 : ys.last;
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final scale = math.min(width, height) * 0.32;

    (double, double, double) project(int r, int c) {
      final nx = ((xs[c] - minX) / (maxX - minX)) * 2 - 1;
      final ny = ((ys[r] - minY) / (maxY - minY)) * 2 - 1;
      final nz = ((zs[r][c] - minZ) / (maxZ - minZ)) * 1.4 - 0.7;
      final rx = nx * cosY - ny * sinY;
      final ry = nx * sinY + ny * cosY;
      final py = ry * cosP - nz * sinP;
      final pz = ry * sinP + nz * cosP;
      return (width * 0.5 + rx * scale, height * 0.55 - py * scale, pz);
    }

    final quads = <(double depth, String pts, double normZ)>[];
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final p0 = project(r, c);
        final p1 = project(r, c + 1);
        final p2 = project(r + 1, c + 1);
        final p3 = project(r + 1, c);
        final depth = (p0.$3 + p1.$3 + p2.$3 + p3.$3) / 4;
        final avgZ =
            (zs[r][c] + zs[r][c + 1] + zs[r + 1][c + 1] + zs[r + 1][c]) / 4;
        final t = ((avgZ - minZ) / (maxZ - minZ)).clamp(0.0, 1.0);
        final pts = '${p0.$1.toStringAsFixed(1)},${p0.$2.toStringAsFixed(1)} '
            '${p1.$1.toStringAsFixed(1)},${p1.$2.toStringAsFixed(1)} '
            '${p2.$1.toStringAsFixed(1)},${p2.$2.toStringAsFixed(1)} '
            '${p3.$1.toStringAsFixed(1)},${p3.$2.toStringAsFixed(1)}';
        quads.add((depth, pts, t));
      }
    }
    quads.sort((a, b) => a.$1.compareTo(b.$1));
    for (final q in quads) {
      final fill = _colorMapHex(colorMap, q.$3);
      final stroke = wireframe ? '#0F172A' : fill;
      buf.writeln(
          '<polygon points="${q.$2}" fill="$fill" fill-opacity="0.88" stroke="$stroke" stroke-width="0.7"/>');
    }
    buf.writeln('</svg>');
    return buf.toString();
  }
}

/// One vector arrow inside a [QudsVectorFieldOutput].
class QudsVectorFieldArrow {
  const QudsVectorFieldArrow({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;

  double get magnitude => math.sqrt(vx * vx + vy * vy);

  Map<String, Object?> toJson() => {'x': x, 'y': y, 'vx': vx, 'vy': vy};

  static QudsVectorFieldArrow fromJson(Map<String, Object?> json) =>
      QudsVectorFieldArrow(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        vx: (json['vx'] as num).toDouble(),
        vy: (json['vy'] as num).toDouble(),
      );
}

/// 2D Vector / Slope field visualization output (`dx/dt, dy/dt`).
class QudsVectorFieldOutput extends QudsOutput {
  const QudsVectorFieldOutput({
    required this.arrows,
    required this.bounds,
    this.title,
    this.color = '#38BDF8',
    this.interactiveInputs = const [],
    this.animation,
  });

  final List<QudsVectorFieldArrow> arrows;
  final QudsGeoBounds bounds;
  final String? title;
  final String color;
  final List<QudsInteractiveInput> interactiveInputs;
  final QudsAnimationSpec? animation;

  @override
  String get kind => 'vector_field';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        if (title != null) 'title': title,
        'color': color,
        'bounds': bounds.toJson(),
        'arrows': [for (final a in arrows) a.toJson()],
        if (animation != null) 'animation': animation!.toJson(),
        'interactiveInputs': [for (final i in interactiveInputs) i.toJson()],
      };

  static QudsVectorFieldOutput fromJson(Map<String, Object?> json) =>
      QudsVectorFieldOutput(
        title: json['title'] as String?,
        color: (json['color'] as String?) ?? '#38BDF8',
        bounds: QudsGeoBounds.fromJson(
            (json['bounds'] as Map).cast<String, Object?>()),
        arrows: [
          for (final a in (json['arrows'] as List? ?? const []))
            QudsVectorFieldArrow.fromJson((a as Map).cast<String, Object?>()),
        ],
        animation: json['animation'] is Map
            ? QudsAnimationSpec.fromJson(
                (json['animation'] as Map).cast<String, Object?>())
            : null,
        interactiveInputs: [
          for (final raw in (json['interactiveInputs'] as List? ?? const []))
            QudsInteractiveInput.fromJson((raw as Map).cast<String, Object?>()),
        ],
      );

  /// Renders the 2D vector field as a clean standalone SVG.
  String toSvg({int width = 640, int height = 400}) {
    const pad = 42.0;
    final viewW = width - pad * 2;
    final viewH = height - pad * 2;
    double sx(double x) =>
        pad + ((x - bounds.minX) / math.max(bounds.width, 1e-6)) * viewW;
    double sy(double y) =>
        pad +
        viewH -
        ((y - bounds.minY) / math.max(bounds.height, 1e-6)) * viewH;

    var maxMag = 0.0;
    for (final a in arrows) {
      if (a.magnitude > maxMag) maxMag = a.magnitude;
    }
    if (maxMag < 1e-12) maxMag = 1.0;

    final buf = StringBuffer()
      ..writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">')
      ..writeln('<rect width="100%" height="100%" fill="#0F172A"/>');
    if (title != null && title!.isNotEmpty) {
      buf.writeln(
          '<text x="${width / 2}" y="22" text-anchor="middle" fill="#F8FAFC" font-family="sans-serif" font-size="14" font-weight="600">${_esc(title!)}</text>');
    }
    final stepPx =
        math.min(viewW, viewH) / math.max(math.sqrt(arrows.length), 4) * 0.72;
    for (final a in arrows) {
      final mag = a.magnitude;
      if (mag < 1e-12) continue;
      final t = (mag / maxMag).clamp(0.0, 1.0);
      final len = stepPx * (0.35 + 0.65 * t);
      final ux = a.vx / mag;
      final uy = a.vy / mag;
      final x1 = sx(a.x);
      final y1 = sy(a.y);
      final x2 = x1 + ux * len;
      final y2 = y1 - uy * len;
      final col = _colorMapHex('viridis', t);
      buf.writeln(
          '<line x1="${x1.toStringAsFixed(1)}" y1="${y1.toStringAsFixed(1)}" x2="${x2.toStringAsFixed(1)}" y2="${y2.toStringAsFixed(1)}" stroke="$col" stroke-width="1.6"/>');
      buf.writeln(
          '<circle cx="${x2.toStringAsFixed(1)}" cy="${y2.toStringAsFixed(1)}" r="2" fill="$col"/>');
    }
    buf.writeln('</svg>');
    return buf.toString();
  }
}

/// One node inside an interactive [QudsGraphOutput].
class QudsGraphNode {
  const QudsGraphNode({
    required this.id,
    required this.x,
    required this.y,
    this.label,
    this.color = '#2563EB',
    this.highlighted = false,
  });

  final String id;
  final double x;
  final double y;
  final String? label;
  final String color;
  final bool highlighted;

  Map<String, Object?> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        if (label != null) 'label': label,
        'color': color,
        'highlighted': highlighted,
      };

  static QudsGraphNode fromJson(Map<String, Object?> json) => QudsGraphNode(
        id: json['id'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        label: json['label'] as String?,
        color: (json['color'] as String?) ?? '#2563EB',
        highlighted: (json['highlighted'] as bool?) ?? false,
      );
}

/// One edge inside an interactive [QudsGraphOutput].
class QudsGraphEdge {
  const QudsGraphEdge({
    required this.from,
    required this.to,
    this.weight,
    this.directed = false,
    this.color = '#64748B',
    this.highlighted = false,
  });

  final String from;
  final String to;
  final double? weight;
  final bool directed;
  final String color;
  final bool highlighted;

  Map<String, Object?> toJson() => {
        'from': from,
        'to': to,
        if (weight != null) 'weight': weight,
        'directed': directed,
        'color': color,
        'highlighted': highlighted,
      };

  static QudsGraphEdge fromJson(Map<String, Object?> json) => QudsGraphEdge(
        from: json['from'] as String,
        to: json['to'] as String,
        weight: (json['weight'] as num?)?.toDouble(),
        directed: (json['directed'] as bool?) ?? false,
        color: (json['color'] as String?) ?? '#64748B',
        highlighted: (json['highlighted'] as bool?) ?? false,
      );
}

/// Interactive network / graph visualization output (e.g. shortest paths, MST,
/// dependency graphs) with SVG export.
class QudsGraphOutput extends QudsOutput {
  const QudsGraphOutput({
    required this.nodes,
    required this.edges,
    this.directed = false,
    this.title,
    this.interactiveInputs = const [],
    this.animation,
  });

  final List<QudsGraphNode> nodes;
  final List<QudsGraphEdge> edges;
  final bool directed;
  final String? title;
  final List<QudsInteractiveInput> interactiveInputs;
  final QudsAnimationSpec? animation;

  @override
  String get kind => 'graph';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        if (title != null) 'title': title,
        'directed': directed,
        'nodes': [for (final n in nodes) n.toJson()],
        'edges': [for (final e in edges) e.toJson()],
        if (animation != null) 'animation': animation!.toJson(),
        'interactiveInputs': [for (final i in interactiveInputs) i.toJson()],
      };

  static QudsGraphOutput fromJson(Map<String, Object?> json) => QudsGraphOutput(
        title: json['title'] as String?,
        directed: (json['directed'] as bool?) ?? false,
        nodes: [
          for (final n in (json['nodes'] as List? ?? const []))
            QudsGraphNode.fromJson((n as Map).cast<String, Object?>()),
        ],
        edges: [
          for (final e in (json['edges'] as List? ?? const []))
            QudsGraphEdge.fromJson((e as Map).cast<String, Object?>()),
        ],
        animation: json['animation'] is Map
            ? QudsAnimationSpec.fromJson(
                (json['animation'] as Map).cast<String, Object?>())
            : null,
        interactiveInputs: [
          for (final raw in (json['interactiveInputs'] as List? ?? const []))
            QudsInteractiveInput.fromJson((raw as Map).cast<String, Object?>()),
        ],
      );

  /// Renders this graph as a clean standalone SVG.
  String toSvg({int width = 640, int height = 400}) {
    final buf = StringBuffer()
      ..writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">')
      ..writeln('<rect width="100%" height="100%" fill="#0F172A"/>');
    if (title != null && title!.isNotEmpty) {
      buf.writeln(
          '<text x="${width / 2}" y="22" text-anchor="middle" fill="#F8FAFC" font-family="sans-serif" font-size="14" font-weight="600">${_esc(title!)}</text>');
    }
    if (nodes.isEmpty) {
      buf.writeln('</svg>');
      return buf.toString();
    }
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final n in nodes) {
      if (n.x < minX) minX = n.x;
      if (n.x > maxX) maxX = n.x;
      if (n.y < minY) minY = n.y;
      if (n.y > maxY) maxY = n.y;
    }
    if ((maxX - minX).abs() < 1e-6) {
      minX -= 1;
      maxX += 1;
    }
    if ((maxY - minY).abs() < 1e-6) {
      minY -= 1;
      maxY += 1;
    }
    const pad = 56.0;
    final scale = math.min(
        (width - pad * 2) / (maxX - minX), (height - pad * 2) / (maxY - minY));
    final midX = (minX + maxX) / 2;
    final midY = (minY + maxY) / 2;
    double sx(double x) => width / 2 + (x - midX) * scale;
    double sy(double y) => height / 2 - (y - midY) * scale;

    final byId = {for (final n in nodes) n.id: n};
    for (final e in edges) {
      final a = byId[e.from];
      final b = byId[e.to];
      if (a == null || b == null) continue;
      final x1 = sx(a.x), y1 = sy(a.y), x2 = sx(b.x), y2 = sy(b.y);
      final stroke = e.highlighted ? '#F59E0B' : e.color;
      final sw = e.highlighted ? 3.2 : 1.6;
      buf.writeln(
          '<line x1="${x1.toStringAsFixed(1)}" y1="${y1.toStringAsFixed(1)}" x2="${x2.toStringAsFixed(1)}" y2="${y2.toStringAsFixed(1)}" stroke="${_esc(stroke)}" stroke-width="$sw"/>');
      if (e.weight != null) {
        final mx = (x1 + x2) / 2;
        final my = (y1 + y2) / 2 - 5;
        buf.writeln(
            '<text x="${mx.toStringAsFixed(1)}" y="${my.toStringAsFixed(1)}" text-anchor="middle" fill="#CBD5E1" font-family="sans-serif" font-size="11">${e.weight!.toStringAsFixed(e.weight! == e.weight!.roundToDouble() ? 0 : 1)}</text>');
      }
    }
    for (final n in nodes) {
      final cx = sx(n.x), cy = sy(n.y);
      final fill = n.highlighted ? '#F59E0B' : n.color;
      buf.writeln(
          '<circle cx="${cx.toStringAsFixed(1)}" cy="${cy.toStringAsFixed(1)}" r="15" fill="${_esc(fill)}" stroke="#FFFFFF" stroke-width="${n.highlighted ? 2.5 : 1.4}"/>');
      buf.writeln(
          '<text x="${cx.toStringAsFixed(1)}" y="${(cy + 4).toStringAsFixed(1)}" text-anchor="middle" fill="#FFFFFF" font-family="sans-serif" font-size="11.5" font-weight="700">${_esc(n.label ?? n.id)}</text>');
    }
    buf.writeln('</svg>');
    return buf.toString();
  }
}

/// Interactive Micro-App / Form card output pairing declared controls
/// (`viz.input`, `viz.number`, `viz.select`, `viz.color`, `viz.button`,
/// `viz.slider`, `viz.toggle`) with live computed key-value outputs.
class QudsFormOutput extends QudsOutput {
  const QudsFormOutput({
    required this.entries,
    this.interactiveInputs = const [],
    this.title,
    this.summary,
  });

  final Map<String, Object?> entries;
  final List<QudsInteractiveInput> interactiveInputs;
  final String? title;
  final String? summary;

  @override
  String get kind => 'form';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        if (title != null) 'title': title,
        if (summary != null) 'summary': summary,
        'entries': entries,
        'interactiveInputs': [for (final i in interactiveInputs) i.toJson()],
      };

  static QudsFormOutput fromJson(Map<String, Object?> json) => QudsFormOutput(
        title: json['title'] as String?,
        summary: json['summary'] as String?,
        entries: (json['entries'] as Map? ?? const {}).cast<String, Object?>(),
        interactiveInputs: [
          for (final raw in (json['interactiveInputs'] as List? ?? const []))
            QudsInteractiveInput.fromJson((raw as Map).cast<String, Object?>()),
        ],
      );
}

/// Structured binary image output emitted by `quds:assets` (`renderImage`,
/// `renderPixelGrid`) and rendered directly in Flutter via `Image.memory`.
class QudsImageOutput extends QudsOutput {
  const QudsImageOutput({
    required this.bytes,
    this.mimeType = 'image/bmp',
    this.title,
    this.caption,
    this.assetPath,
    this.width,
    this.height,
  });

  final List<int> bytes;
  final String mimeType;
  final String? title;
  final String? caption;
  final String? assetPath;
  final int? width;
  final int? height;

  @override
  String get kind => 'image';

  @override
  Map<String, Object?> toJson() => {
        'kind': kind,
        'mimeType': mimeType,
        'byteLength': bytes.length,
        if (title != null) 'title': title,
        if (caption != null) 'caption': caption,
        if (assetPath != null) 'assetPath': assetPath,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };
}

String _colorMapHex(String mapName, double t) {
  final v = t.clamp(0.0, 1.0);
  int r, g, b;
  if (mapName == 'plasma') {
    r = (50 + 205 * v).round();
    g = (20 + 180 * math.sin(v * math.pi * 0.85)).round();
    b = (165 * (1 - v) + 40).round();
  } else if (mapName == 'emerald') {
    r = (16 + 110 * v).round();
    g = (90 + 150 * v).round();
    b = (95 + 75 * (1 - v)).round();
  } else {
    // viridis-inspired perceptually uniform gradient
    r = (68 + 185 * math.pow(v, 1.6)).round();
    g = (30 + 200 * math.pow(v, 0.75)).round();
    b = (110 + 100 * math.sin(v * math.pi) - 65 * v).round();
  }
  String hex(int c) => c.clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${hex(r)}${hex(g)}${hex(b)}';
}

String _esc(String raw) => raw
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
