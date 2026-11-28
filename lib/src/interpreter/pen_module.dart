/// Built-in `quds:pen` vector & turtle-style pen graphics library for the
/// embedded Quds interpreter (100% pure Dart, zero `dart:io` imports).
///
/// Offers classic imperative pen-drawing commands (`forward`, `backward`,
/// `right`, `left`, `up`, `down`, `goto`, `circle`, `arc`, `polygon`, `star`,
/// `beginFill`/`endFill`, `dot`, `stamp`, `color`, `hsl`, `width`) backed by
/// [QudsGeometrySceneOutput] with automatic bounding-box framing, live vector
/// pen-nib cursor rendering, and smooth 60fps progressive stroke animation.
library;

import 'dart:math' as math;

import '../source.dart';
import 'exceptions.dart';
import 'host_bridge.dart';
import 'outputs.dart';

class _PenStroke {
  const _PenStroke({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.color,
    required this.width,
    required this.length,
    required this.headingDeg,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final String color;
  final double width;
  final double length;
  final double headingDeg;
}

class _PenPolygon {
  const _PenPolygon({
    required this.vertices,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    required this.atDistance,
  });

  final List<List<double>> vertices;
  final String fillColor;
  final String strokeColor;
  final double strokeWidth;
  final double atDistance;
}

class _PenDot {
  const _PenDot({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.atDistance,
  });

  final double x;
  final double y;
  final double radius;
  final String color;
  final double atDistance;
}

class _PenStamp {
  const _PenStamp({
    required this.x,
    required this.y,
    required this.headingDeg,
    required this.color,
    required this.atDistance,
  });

  final double x;
  final double y;
  final double headingDeg;
  final String color;
  final double atDistance;
}

class _PenLabel {
  const _PenLabel({
    required this.x,
    required this.y,
    required this.text,
    required this.color,
    required this.atDistance,
  });

  final double x;
  final double y;
  final String text;
  final String color;
  final double atDistance;
}

/// Builds the built-in `quds:pen` [QudsHostModule].
QudsHostModule buildQudsPenModule({
  int? maxPrimitives,
  int? maxOutputs,
  Map<String, QudsInteractiveInput>? sharedInteractiveRegistry,
}) {
  var outputCounter = 0;

  var curX = 0.0;
  var curY = 0.0;
  var headingDeg = 0.0; // 0° = +x (East), 90° = +y (North)
  var penDown = true;
  var penColor = '#38BDF8';
  var fillHex = '#38BDF844';
  var penWidth = 2.2;
  var filling = false;
  final fillPoints = <List<double>>[];

  final strokes = <_PenStroke>[];
  final polygons = <_PenPolygon>[];
  final dots = <_PenDot>[];
  final stamps = <_PenStamp>[];
  final labels = <_PenLabel>[];
  final customReadouts = <QudsTelemetryReading>[];
  var totalDistance = 0.0;

  // Bounding box tracking across all drawn geometry
  var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
  var hasGeometry = false;

  void recordBounds(double x, double y) {
    if (!hasGeometry) {
      minX = maxX = x;
      minY = maxY = y;
      hasGeometry = true;
    } else {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }

  void checkPrimitiveBudget(SourceSpan span) {
    if (maxPrimitives != null &&
        (strokes.length + polygons.length + dots.length + stamps.length) >=
            maxPrimitives) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.outputLimit,
        'Exceeded maximum pen drawing primitives ($maxPrimitives).',
        span,
      );
    }
  }

  void moveToPoint(double nx, double ny, SourceSpan span) {
    final dx = nx - curX;
    final dy = ny - curY;
    final segLen = math.sqrt(dx * dx + dy * dy);
    if (penDown && segLen > 1e-9) {
      checkPrimitiveBudget(span);
      recordBounds(curX, curY);
      recordBounds(nx, ny);
      final segHeading = math.atan2(dy, dx) * 180.0 / math.pi;
      strokes.add(_PenStroke(
        x1: curX,
        y1: curY,
        x2: nx,
        y2: ny,
        color: penColor,
        width: penWidth,
        length: segLen,
        headingDeg: segHeading,
      ));
      totalDistance += segLen;
    }
    curX = nx;
    curY = ny;
    if (filling) {
      fillPoints.add([curX, curY]);
    }
  }

  void moveBy(double dist, SourceSpan span) {
    final rad = headingDeg * math.pi / 180.0;
    moveToPoint(curX + dist * math.cos(rad), curY + dist * math.sin(rad), span);
  }

  void resetAll() {
    curX = 0.0;
    curY = 0.0;
    headingDeg = 0.0;
    penDown = true;
    penColor = '#38BDF8';
    fillHex = '#38BDF844';
    penWidth = 2.2;
    filling = false;
    fillPoints.clear();
    strokes.clear();
    polygons.clear();
    dots.clear();
    stamps.clear();
    labels.clear();
    customReadouts.clear();
    totalDistance = 0.0;
    minX = maxX = minY = maxY = 0.0;
    hasGeometry = false;
  }

  final builder = QudsHostModule.builder(
    'quds:pen',
    description:
        'Imperative vector pen-drawing library (`forward`, `right`, `left`, `up`, `down`, `circle`, `polygon`, `star`, `beginFill`/`endFill`) with auto-framing and live 60fps stroke animation.',
  );

  // Movement
  void registerForward(String name) {
    builder.function(
      name,
      (pos, named, ctx) {
        final d = _toDouble(pos[0], ctx.span);
        moveBy(d, ctx.span);
        return null;
      },
      signature: '$name(distance: double) -> void',
      documentation: 'Moves the pen forward by `distance` units.',
    );
  }

  registerForward('forward');
  registerForward('fd');

  void registerBackward(String name) {
    builder.function(
      name,
      (pos, named, ctx) {
        final d = _toDouble(pos[0], ctx.span);
        moveBy(-d, ctx.span);
        return null;
      },
      signature: '$name(distance: double) -> void',
      documentation: 'Moves the pen backward by `distance` units.',
    );
  }

  registerBackward('backward');
  registerBackward('bk');

  void registerRight(String name) {
    builder.function(
      name,
      (pos, named, ctx) {
        headingDeg = (headingDeg - _toDouble(pos[0], ctx.span)) % 360.0;
        return null;
      },
      signature: '$name(degrees: double) -> void',
      documentation: 'Turns the pen clockwise by `degrees`.',
    );
  }

  registerRight('right');
  registerRight('rt');

  void registerLeft(String name) {
    builder.function(
      name,
      (pos, named, ctx) {
        headingDeg = (headingDeg + _toDouble(pos[0], ctx.span)) % 360.0;
        return null;
      },
      signature: '$name(degrees: double) -> void',
      documentation: 'Turns the pen counter-clockwise by `degrees`.',
    );
  }

  registerLeft('left');
  registerLeft('lt');

  void registerGoto(String name) {
    builder.function(
      name,
      (pos, named, ctx) {
        final nx = _toDouble(pos[0], ctx.span);
        final ny = _toDouble(pos[1], ctx.span);
        moveToPoint(nx, ny, ctx.span);
        return null;
      },
      signature: '$name(x: double, y: double) -> void',
      documentation: 'Moves the pen directly to `(x, y)`.',
    );
  }

  registerGoto('goto');
  registerGoto('moveTo');

  void registerSetHeading(String name) {
    builder.function(
      name,
      (pos, named, ctx) {
        headingDeg = _toDouble(pos[0], ctx.span) % 360.0;
        return null;
      },
      signature: '$name(degrees: double) -> void',
      documentation:
          'Sets the absolute heading angle in degrees (0°=East, 90°=North).',
    );
  }

  registerSetHeading('setHeading');
  registerSetHeading('seth');

  builder.function(
    'home',
    (pos, named, ctx) {
      moveToPoint(0.0, 0.0, ctx.span);
      headingDeg = 0.0;
      return null;
    },
    signature: 'home() -> void',
    documentation: 'Moves the pen to `(0, 0)` and resets heading to `0°`.',
  );

  // Queries
  builder.function('x', (pos, named, ctx) => curX,
      signature: 'x() -> double',
      documentation: 'Returns current X coordinate.');
  builder.function('y', (pos, named, ctx) => curY,
      signature: 'y() -> double',
      documentation: 'Returns current Y coordinate.');
  builder.function('position', (pos, named, ctx) => <double>[curX, curY],
      signature: 'position() -> List<double>',
      documentation: 'Returns `[x, y]` current pen position.');
  builder.function(
      'heading', (pos, named, ctx) => ((headingDeg % 360.0) + 360.0) % 360.0,
      signature: 'heading() -> double',
      documentation: 'Returns current heading in degrees `[0, 360)`.');
  builder.function('isDown', (pos, named, ctx) => penDown,
      signature: 'isDown() -> bool',
      documentation: 'Returns true if the pen is currently drawing.');
  builder.function(
    'distance',
    (pos, named, ctx) {
      final tx = _toDouble(pos[0], ctx.span);
      final ty = _toDouble(pos[1], ctx.span);
      return math.sqrt((tx - curX) * (tx - curX) + (ty - curY) * (ty - curY));
    },
    signature: 'distance(x: double, y: double) -> double',
    documentation: 'Returns Euclidean distance from the pen to `(x, y)`.',
  );

  // Pen state
  builder.function('up', (pos, named, ctx) {
    penDown = false;
    return null;
  },
      signature: 'up() -> void',
      documentation: 'Lifts the pen (moves without drawing).');
  builder.function('penUp', (pos, named, ctx) {
    penDown = false;
    return null;
  }, signature: 'penUp() -> void', documentation: 'Alias for `up()`.');

  builder.function('down', (pos, named, ctx) {
    penDown = true;
    return null;
  },
      signature: 'down() -> void',
      documentation: 'Lowers the pen to resume drawing.');
  builder.function('penDown', (pos, named, ctx) {
    penDown = true;
    return null;
  }, signature: 'penDown() -> void', documentation: 'Alias for `down()`.');

  void registerColor(String name) {
    builder.function(
      name,
      (pos, named, ctx) {
        penColor = _resolvePenColor('${pos[0]}');
        if (pos.length > 1) {
          fillHex = _resolveFillColor('${pos[1]}');
        }
        return penColor;
      },
      signature: '$name(color: String, fill: String?) -> String',
      documentation: 'Sets the pen stroke color (hex or named color).',
    );
  }

  registerColor('color');
  registerColor('penColor');

  builder.function(
    'fillColor',
    (pos, named, ctx) {
      fillHex = _resolveFillColor('${pos[0]}');
      return fillHex;
    },
    signature: 'fillColor(color: String) -> String',
    documentation:
        'Sets the polygon fill color used by `beginFill()`/`endFill()`.',
  );

  builder.function(
    'hsl',
    (pos, named, ctx) {
      final h = _toDouble(pos[0], ctx.span);
      final s = pos.length > 1 ? _toDouble(pos[1], ctx.span) : 0.85;
      final l = pos.length > 2 ? _toDouble(pos[2], ctx.span) : 0.58;
      return _hslToHex(h, s, l);
    },
    signature: 'hsl(h: double, s: double = 0.85, l: double = 0.58) -> String',
    documentation:
        'Converts HSL `(0..360, 0..1, 0..1)` to a `#RRGGBB` hex color.',
  );

  void registerWidth(String name) {
    builder.function(
      name,
      (pos, named, ctx) {
        penWidth = _toDouble(pos[0], ctx.span).clamp(0.4, 24.0);
        return penWidth;
      },
      signature: '$name(px: double) -> double',
      documentation: 'Sets the stroke thickness in pixels.',
    );
  }

  registerWidth('width');
  registerWidth('penSize');

  builder.function(
    'beginFill',
    (pos, named, ctx) {
      if (pos.isNotEmpty) {
        fillHex = _resolveFillColor('${pos[0]}');
      } else if (named['color'] != null) {
        fillHex = _resolveFillColor('${named['color']}');
      }
      filling = true;
      fillPoints
        ..clear()
        ..add([curX, curY]);
      return null;
    },
    signature: 'beginFill(color: String?) -> void',
    documentation: 'Starts recording vertices for a filled polygon.',
  );

  builder.function(
    'endFill',
    (pos, named, ctx) {
      if (filling && fillPoints.length >= 3) {
        checkPrimitiveBudget(ctx.span);
        for (final pt in fillPoints) {
          recordBounds(pt[0], pt[1]);
        }
        polygons.add(_PenPolygon(
          vertices: fillPoints.map((p) => [p[0], p[1]]).toList(),
          fillColor: fillHex,
          strokeColor: penColor,
          strokeWidth: penWidth,
          atDistance: totalDistance,
        ));
      }
      filling = false;
      fillPoints.clear();
      return null;
    },
    signature: 'endFill() -> void',
    documentation: 'Closes and fills the polygon recorded since `beginFill()`.',
  );

  builder.function(
    'clear',
    (pos, named, ctx) {
      strokes.clear();
      polygons.clear();
      dots.clear();
      stamps.clear();
      labels.clear();
      totalDistance = 0.0;
      minX = maxX = minY = maxY = 0.0;
      hasGeometry = false;
      return null;
    },
    signature: 'clear() -> void',
    documentation:
        'Clears drawn artwork while preserving current pen position & heading.',
  );

  builder.function(
    'reset',
    (pos, named, ctx) {
      resetAll();
      return null;
    },
    signature: 'reset() -> void',
    documentation:
        'Clears all drawings and resets the pen to `(0, 0)` facing `0°`.',
  );

  // High-level shape helpers
  void drawArc(double radius, double extent, int steps, SourceSpan span) {
    final safeSteps = steps.clamp(3, 360);
    final sign = radius >= 0 ? 1.0 : -1.0;
    final r = radius.abs();
    if (r < 1e-9) return;
    final stepAngle = (extent / safeSteps) * sign;
    final radStep = (extent.abs() * math.pi / 180.0) / safeSteps;
    final chord = 2.0 * r * math.sin(radStep / 2.0);
    for (var i = 0; i < safeSteps; i++) {
      headingDeg = (headingDeg + stepAngle / 2.0) % 360.0;
      moveBy(chord, span);
      headingDeg = (headingDeg + stepAngle / 2.0) % 360.0;
    }
  }

  builder.function(
    'circle',
    (pos, named, ctx) {
      final radius = _toDouble(pos[0], ctx.span);
      final extent = named['extent'] != null
          ? _toDouble(named['extent'], ctx.span)
          : (pos.length > 1 ? _toDouble(pos[1], ctx.span) : 360.0);
      final steps = named['steps'] != null
          ? (named['steps'] as num).toInt()
          : (pos.length > 2 ? (pos[2] as num).toInt() : 48);
      drawArc(radius, extent, steps, ctx.span);
      return null;
    },
    signature:
        'circle(radius: double, extent: double = 360.0, steps: int = 48) -> void',
    documentation:
        'Draws a circle or arc of the given `radius` turning left (or right if negative).',
  );

  builder.function(
    'arc',
    (pos, named, ctx) {
      final radius = _toDouble(pos[0], ctx.span);
      final angle = pos.length > 1 ? _toDouble(pos[1], ctx.span) : 90.0;
      final steps = named['steps'] != null
          ? (named['steps'] as num).toInt()
          : math.max(8, (angle.abs() / 5.0).round());
      drawArc(radius, angle, steps, ctx.span);
      return null;
    },
    signature: 'arc(radius: double, angle: double = 90.0, steps: int?) -> void',
    documentation: 'Draws a smooth circular arc.',
  );

  builder.function(
    'polygon',
    (pos, named, ctx) {
      final sides = (pos[0] as num).toInt().clamp(3, 64);
      final sideLen = _toDouble(pos[1], ctx.span);
      final turn = 360.0 / sides;
      for (var i = 0; i < sides; i++) {
        moveBy(sideLen, ctx.span);
        headingDeg = (headingDeg + turn) % 360.0;
      }
      return null;
    },
    signature: 'polygon(sides: int, sideLength: double) -> void',
    documentation:
        'Draws a regular polygon with `sides` edges of `sideLength`.',
  );

  builder.function(
    'star',
    (pos, named, ctx) {
      final points = (pos[0] as num).toInt().clamp(5, 31);
      final size = _toDouble(pos[1], ctx.span);
      final step = named['step'] != null
          ? (named['step'] as num).toInt().clamp(2, points - 1)
          : ((points - 1) ~/ 2).clamp(2, points - 1);
      final turn = 360.0 * step / points;
      for (var i = 0; i < points; i++) {
        moveBy(size, ctx.span);
        headingDeg = (headingDeg - turn) % 360.0;
      }
      return null;
    },
    signature: 'star(points: int, size: double, step: int?) -> void',
    documentation: 'Draws a geometric star polygon.',
  );

  builder.function(
    'dot',
    (pos, named, ctx) {
      checkPrimitiveBudget(ctx.span);
      final radius = pos.isNotEmpty
          ? _toDouble(pos[0], ctx.span).clamp(1.5, 24.0)
          : (named['size'] != null ? _toDouble(named['size'], ctx.span) : 5.0);
      final col = pos.length > 1
          ? _resolvePenColor('${pos[1]}')
          : (named['color'] != null
              ? _resolvePenColor('${named['color']}')
              : penColor);
      recordBounds(curX, curY);
      dots.add(_PenDot(
        x: curX,
        y: curY,
        radius: radius,
        color: col,
        atDistance: totalDistance,
      ));
      return null;
    },
    signature: 'dot(size: double = 5.0, color: String?) -> void',
    documentation: 'Draws a dot at the current pen position.',
  );

  builder.function(
    'stamp',
    (pos, named, ctx) {
      checkPrimitiveBudget(ctx.span);
      final col = pos.isNotEmpty
          ? _resolvePenColor('${pos[0]}')
          : (named['color'] != null
              ? _resolvePenColor('${named['color']}')
              : penColor);
      recordBounds(curX, curY);
      stamps.add(_PenStamp(
        x: curX,
        y: curY,
        headingDeg: headingDeg,
        color: col,
        atDistance: totalDistance,
      ));
      return null;
    },
    signature: 'stamp(color: String?) -> void',
    documentation:
        'Stamps the pen nib arrow at the current position and heading.',
  );

  builder.function(
    'text',
    (pos, named, ctx) {
      final txt = '${pos[0]}';
      final col = pos.length > 1
          ? _resolvePenColor('${pos[1]}')
          : (named['color'] != null
              ? _resolvePenColor('${named['color']}')
              : penColor);
      recordBounds(curX, curY);
      labels.add(_PenLabel(
        x: curX,
        y: curY,
        text: txt,
        color: col,
        atDistance: totalDistance,
      ));
      return null;
    },
    signature: 'text(content: String, color: String?) -> void',
    documentation: 'Places a text label at the current pen position.',
  );

  builder.function(
    'readout',
    (pos, named, ctx) {
      final label = '${pos[0]}';
      final val = pos.length > 1 ? '${pos[1]}' : '';
      final unit = named['unit'] as String?;
      final col = named['color'] != null
          ? _resolvePenColor('${named['color']}')
          : '#38BDF8';
      customReadouts.add(QudsTelemetryReading(
        label: label,
        value: val,
        unit: unit,
        color: col,
      ));
      return null;
    },
    signature:
        'readout(label: String, value: Object?, unit: String?, color: String?) -> void',
    documentation: 'Adds a live telemetry badge to the pen canvas HUD.',
  );

  // Render scene
  builder.function(
    'render',
    (pos, named, ctx) {
      outputCounter++;
      if (maxOutputs != null && outputCounter > maxOutputs) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.outputLimit,
          'Exceeded maximum rich output limit ($maxOutputs).',
          ctx.span,
        );
      }

      final title = (named['title'] as String?) ??
          (pos.isNotEmpty ? '${pos[0]}' : 'Quds Pen Canvas');
      final animate = (named['animate'] as bool?) ?? false;
      final duration = named['duration'] != null
          ? _toDouble(named['duration'], ctx.span).clamp(0.5, 60.0)
          : 5.0;
      final loop = (named['loop'] as bool?) ?? true;
      final autoPlay = (named['autoPlay'] as bool?) ?? true;
      final showPen = (named['showPen'] as bool?) ?? true;
      final showGrid = (named['showGrid'] as bool?) ?? false;
      final showAxes = (named['showAxes'] as bool?) ?? false;
      final padding = named['padding'] != null
          ? _toDouble(named['padding'], ctx.span).clamp(1.02, 2.5)
          : 1.18;

      // Compute bounds (explicit or auto-framed square around full artwork)
      QudsGeoBounds bounds;
      if (named['bounds'] is List && (named['bounds'] as List).length == 4) {
        final b = named['bounds'] as List;
        bounds = QudsGeoBounds(
          minX: _toDouble(b[0], ctx.span),
          maxX: _toDouble(b[1], ctx.span),
          minY: _toDouble(b[2], ctx.span),
          maxY: _toDouble(b[3], ctx.span),
        );
      } else {
        final cx = hasGeometry ? (minX + maxX) / 2.0 : 0.0;
        final cy = hasGeometry ? (minY + maxY) / 2.0 : 0.0;
        final spanW = hasGeometry ? (maxX - minX) : 200.0;
        final spanH = hasGeometry ? (maxY - minY) : 200.0;
        final half = math.max(math.max(spanW, spanH) * 0.5 * padding, 25.0);
        bounds = QudsGeoBounds(
          minX: cx - half,
          maxX: cx + half,
          minY: cy - half,
          maxY: cy + half,
        );
      }

      QudsAnimationSpec? animSpec;
      var maxDrawDist = totalDistance;
      var progress = 1.0;

      if (animate) {
        var t =
            (ctx.interactiveInputs['__quds_anim_t'] as num?)?.toDouble() ?? 0.0;
        final dt =
            (ctx.interactiveInputs['__quds_anim_dt'] as num?)?.toDouble() ??
                (1.0 / 60.0);
        final frame =
            (ctx.interactiveInputs['__quds_anim_frame'] as num?)?.toInt() ?? 0;
        final playing =
            (ctx.interactiveInputs['__quds_anim_playing'] as bool?) ?? autoPlay;
        // On frame 0 with t=0, show full artwork if paused? No — show smooth 12% starter or live progress
        final effectiveT = loop ? (t % duration) : t.clamp(0.0, duration);
        // Pause briefly at 100% at the end of each loop cycle (last 12% of duration)
        final rawFrac = (effectiveT / duration).clamp(0.0, 1.0);
        progress =
            frame == 0 && t == 0.0 ? 1.0 : (rawFrac / 0.88).clamp(0.0, 1.0);
        maxDrawDist = totalDistance * progress;
        animSpec = QudsAnimationSpec(
          fps: 60,
          duration: duration,
          loop: loop,
          autoPlay: autoPlay,
          playing: playing,
          time: effectiveT,
          dt: dt,
          frame: frame,
        );
      }

      final primitives = <QudsGeoPrimitive>[];
      var primId = 0;

      // 1. Filled polygons reached so far
      for (final poly in polygons) {
        if (poly.atDistance <= maxDrawDist + 1e-6) {
          primitives.add(QudsGeoPolygon(
            id: 'pen_poly_${primId++}',
            points: [for (final v in poly.vertices) (v[0], v[1])],
            stroke: poly.strokeColor,
            fill: poly.fillColor,
          ));
        }
      }

      // 2. Strokes up to maxDrawDist, tracking live pen nib tip & heading
      var accum = 0.0;
      var tipX = curX;
      var tipY = curY;
      var tipHeading = headingDeg;
      var drawnStrokes = 0;

      for (final s in strokes) {
        if (accum >= maxDrawDist && animate) break;
        if (!animate || accum + s.length <= maxDrawDist + 1e-9) {
          primitives.add(QudsGeoSegment(
            id: 'pen_s_${primId++}',
            x1: s.x1,
            y1: s.y1,
            x2: s.x2,
            y2: s.y2,
            color: s.color,
            strokeWidth: s.width,
          ));
          accum += s.length;
          tipX = s.x2;
          tipY = s.y2;
          tipHeading = s.headingDeg;
          drawnStrokes++;
        } else {
          final rem = (maxDrawDist - accum).clamp(0.0, s.length);
          final frac = s.length > 0 ? (rem / s.length) : 1.0;
          final px = s.x1 + (s.x2 - s.x1) * frac;
          final py = s.y1 + (s.y2 - s.y1) * frac;
          primitives.add(QudsGeoSegment(
            id: 'pen_s_${primId++}',
            x1: s.x1,
            y1: s.y1,
            x2: px,
            y2: py,
            color: s.color,
            strokeWidth: s.width,
          ));
          accum += rem;
          tipX = px;
          tipY = py;
          tipHeading = s.headingDeg;
          drawnStrokes++;
          break;
        }
      }

      // 3. Dots, stamps, and text labels reached so far
      for (final d in dots) {
        if (d.atDistance <= maxDrawDist + 1e-6) {
          primitives.add(QudsGeoPoint(
            id: 'pen_dot_${primId++}',
            x: d.x,
            y: d.y,
            color: d.color,
            radius: d.radius,
          ));
        }
      }

      final nibSize = (bounds.maxX - bounds.minX) * 0.032;

      void addNibPrimitive(
        String id,
        double x,
        double y,
        double deg,
        String color,
      ) {
        final rad = deg * math.pi / 180.0;
        final cosA = math.cos(rad);
        final sinA = math.sin(rad);
        final front = (x + nibSize * cosA, y + nibSize * sinA);
        final backL = (
          x - nibSize * 0.65 * cosA - nibSize * 0.45 * sinA,
          y - nibSize * 0.65 * sinA + nibSize * 0.45 * cosA,
        );
        final notch = (x - nibSize * 0.25 * cosA, y - nibSize * 0.25 * sinA);
        final backR = (
          x - nibSize * 0.65 * cosA + nibSize * 0.45 * sinA,
          y - nibSize * 0.65 * sinA - nibSize * 0.45 * cosA,
        );
        primitives.add(QudsGeoPolygon(
          id: id,
          points: [front, backL, notch, backR],
          stroke: '#FFFFFF',
          fill: color,
        ));
      }

      for (final st in stamps) {
        if (st.atDistance <= maxDrawDist + 1e-6) {
          addNibPrimitive(
              'pen_stamp_${primId++}', st.x, st.y, st.headingDeg, st.color);
        }
      }

      for (final lbl in labels) {
        if (lbl.atDistance <= maxDrawDist + 1e-6) {
          primitives.add(QudsGeoLabel(
            id: 'pen_lbl_${primId++}',
            x: lbl.x,
            y: lbl.y,
            text: lbl.text,
            color: lbl.color,
          ));
        }
      }

      // 4. Live Pen Nib Cursor at the active tip
      if (showPen) {
        addNibPrimitive(
          'pen_cursor_nib',
          tipX,
          tipY,
          tipHeading,
          '#F59E0B',
        );
        primitives.add(QudsGeoPoint(
          id: 'pen_cursor_tip',
          x: tipX,
          y: tipY,
          color: '#FFFFFF',
          radius: 3.0,
        ));
      }

      final normalizedAngle = ((tipHeading % 360.0) + 360.0) % 360.0;
      final readings = <QudsTelemetryReading>[
        ...customReadouts,
        QudsTelemetryReading(
          label: 'الخطوط',
          value: '$drawnStrokes/${strokes.length}',
          color: '#38BDF8',
        ),
        QudsTelemetryReading(
          label: 'المسافة',
          value: accum.toStringAsFixed(0),
          unit: 'px',
          color: '#10B981',
        ),
        QudsTelemetryReading(
          label: 'الاتجاه',
          value: normalizedAngle.toStringAsFixed(0),
          unit: '°',
          color: '#F59E0B',
        ),
        if (animate)
          QudsTelemetryReading(
            label: 'التقدم',
            value: (progress * 100.0).toStringAsFixed(0),
            unit: '%',
            color: '#EC4899',
          ),
      ];

      final scene = QudsGeometrySceneOutput(
        title: title,
        bounds: bounds,
        primitives: primitives,
        interactiveInputs:
            sharedInteractiveRegistry?.values.toList() ?? const [],
        showGrid: showGrid,
        showAxes: showAxes,
        animation: animSpec,
        readings: readings,
      );
      ctx.emitOutput(scene);
      return scene;
    },
    signature:
        'render(title: String = "Quds Pen Canvas", bounds: List<double>?, animate: bool = false, duration: double = 5.0, loop: bool = true, autoPlay: bool = true, showPen: bool = true, showGrid: bool = false, showAxes: bool = false) -> QudsGeometrySceneOutput',
    documentation:
        'Renders the pen canvas as an interactive (and optionally animated) 2D geometry scene.',
  );

  return builder.build();
}

double _toDouble(Object? v, SourceSpan span) {
  if (v is num) return v.toDouble();
  throw QudsRuntimeException(
    'Expected a number in quds:pen, got ${v.runtimeType}.',
    span,
  );
}

String _resolvePenColor(String raw) {
  final clean = raw.trim().toLowerCase();
  if (clean.startsWith('#')) return raw.trim();
  return _namedColors[clean] ?? '#38BDF8';
}

String _resolveFillColor(String raw) {
  final hex = _resolvePenColor(raw);
  if (hex.startsWith('#') && hex.length == 7) {
    return '${hex}55';
  }
  return hex;
}

const Map<String, String> _namedColors = {
  'red': '#EF4444',
  'blue': '#3B82F6',
  'sky': '#38BDF8',
  'cyan': '#06B6D4',
  'green': '#22C55E',
  'emerald': '#10B981',
  'teal': '#14B8A6',
  'yellow': '#EAB308',
  'gold': '#F59E0B',
  'amber': '#F59E0B',
  'orange': '#F97316',
  'purple': '#A855F7',
  'violet': '#8B5CF6',
  'indigo': '#6366F1',
  'pink': '#EC4899',
  'rose': '#F43F5E',
  'white': '#F8FAFC',
  'slate': '#94A3B8',
  'black': '#0F172A',
};

String _hslToHex(double hDeg, double s, double l) {
  final h = ((hDeg % 360.0) + 360.0) % 360.0;
  final sat = s.clamp(0.0, 1.0);
  final lig = l.clamp(0.0, 1.0);
  final c = (1.0 - (2.0 * lig - 1.0).abs()) * sat;
  final x = c * (1.0 - (((h / 60.0) % 2.0) - 1.0).abs());
  final m = lig - c / 2.0;
  double r = 0, g = 0, b = 0;
  if (h < 60) {
    r = c;
    g = x;
  } else if (h < 120) {
    r = x;
    g = c;
  } else if (h < 180) {
    g = c;
    b = x;
  } else if (h < 240) {
    g = x;
    b = c;
  } else if (h < 300) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  String toHex(double v) =>
      ((v + m) * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${toHex(r)}${toHex(g)}${toHex(b)}'.toUpperCase();
}
