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
    this.title,
    this.xLabel,
    this.yLabel,
    this.showGrid = true,
    this.showLegend = true,
  });

  final List<QudsPlotSeries> series;
  final List<QudsInteractiveInput> interactiveInputs;
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
  });

  final List<(double, double)> points;
  final String color;
  final double strokeWidth;

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

/// Interactive 2D geometry scene output supporting draggable points, parameter
/// sliders, auto-fitted world bounds, full JSON round-trip, and SVG rendering.
class QudsGeometrySceneOutput extends QudsOutput {
  const QudsGeometrySceneOutput({
    required this.primitives,
    required this.bounds,
    this.interactiveInputs = const [],
    this.title,
    this.showGrid = true,
    this.showAxes = true,
    this.interactive = true,
  });

  final List<QudsGeoPrimitive> primitives;
  final QudsGeoBounds bounds;
  final List<QudsInteractiveInput> interactiveInputs;
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
        'interactiveInputs': [for (final i in interactiveInputs) i.toJson()],
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
        interactiveInputs: [
          for (final raw in (json['interactiveInputs'] as List? ?? const []))
            QudsInteractiveInput.fromJson((raw as Map).cast<String, Object?>()),
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
          final pts = [
            for (final pt in p.points)
              '${sx(pt.$1).toStringAsFixed(2)},${sy(pt.$2).toStringAsFixed(2)}'
          ].join(' ');
          buf.writeln(
              '<polyline data-id="${_esc(p.id)}" fill="none" stroke="${_esc(p.color)}" stroke-width="${p.strokeWidth}" points="$pts"/>');
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

String _esc(String raw) => raw
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
