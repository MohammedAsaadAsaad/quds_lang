/// Built-in `quds:viz` scientific visualization & interactive geometry module
/// for the embedded Quds interpreter (zero `dart:io` imports).
///
/// Connects seamlessly with `quds:math::vector` (`Vec2`), `quds:math::geometry`
/// (`polygonCentroid`, `triangulatePolygon`), numeric lists, and interactive
/// host controls (draggable points, sliders, toggles).
library;

import 'dart:math' as math;

import '../source.dart';
import 'exceptions.dart';
import 'host_bridge.dart';
import 'outputs.dart';
import 'values.dart';

/// Builds the `quds:viz` [QudsHostModule] honoring [maxPrimitives] and
/// [maxOutputs] from the active [QudsExecutionPolicy].
QudsHostModule buildQudsVizModule({
  int? maxPrimitives,
  int? maxOutputs,
}) {
  var outputCounter = 0;

  void checkOutputQuota(SourceSpan span) {
    outputCounter++;
    if (maxOutputs != null && outputCounter > maxOutputs) {
      throw QudsPolicyViolationException(
        QudsPolicyViolationKind.outputLimit,
        'Exceeded maximum rich output limit ($maxOutputs).',
        span,
      );
    }
  }

  final interactiveRegistry = <String, QudsInteractiveInput>{};

  final builder = QudsHostModule.builder(
    'quds:viz',
    description:
        'Scientific plotting, tables, matrices, LaTeX, and interactive 2D geometry scenes.',
  );

  // Interactive draggable point handle: viz.point("A", 0.0, 0.0, draggable: true)
  builder.function(
    'point',
    (pos, named, ctx) {
      final id = '${pos[0]}';
      var x = _toDouble(pos[1], ctx.span);
      var y = _toDouble(pos[2], ctx.span);
      final draggable = (named['draggable'] as bool?) ?? false;
      final label = (named['label'] as String?) ?? id;
      final color = (named['color'] as String?) ?? '#2563EB';

      final override = ctx.interactiveInputs[id];
      if (override is Map) {
        if (override['x'] is num) x = (override['x'] as num).toDouble();
        if (override['y'] is num) y = (override['y'] as num).toDouble();
      } else if (override is List && override.length >= 2) {
        x = (override[0] as num).toDouble();
        y = (override[1] as num).toDouble();
      }

      if (draggable) {
        interactiveRegistry[id] = QudsInteractiveInput(
          id: id,
          kind: 'draggablePoint',
          label: label,
          value: {'x': x, 'y': y},
        );
      }

      return QudsNamespace('GeoHandle($id)', {
        'id': id,
        'x': x,
        'y': y,
        'draggable': draggable,
        'label': label,
        'color': color,
      });
    },
    signature:
        'point(id: String, x: double, y: double, draggable: bool = false, label: String?, color: String?)',
    documentation:
        'Declares a 2D point (optionally draggable in interactive geometry scenes).',
  );

  // Interactive numeric slider: viz.slider("radius", min: 1.0, max: 10.0, value: 3.0)
  builder.function(
    'slider',
    (pos, named, ctx) {
      final id = '${pos[0]}';
      final minVal =
          _toDouble(named['min'] ?? (pos.length > 1 ? pos[1] : 0.0), ctx.span);
      final maxVal =
          _toDouble(named['max'] ?? (pos.length > 2 ? pos[2] : 10.0), ctx.span);
      final defaultVal = _toDouble(
          named['value'] ?? (pos.length > 3 ? pos[3] : minVal), ctx.span);
      final stepVal =
          named['step'] != null ? _toDouble(named['step'], ctx.span) : null;
      final label = (named['label'] as String?) ?? id;

      var current = defaultVal;
      final override = ctx.interactiveInputs[id];
      if (override is num) {
        current = override.toDouble().clamp(minVal, maxVal);
      }

      interactiveRegistry[id] = QudsInteractiveInput(
        id: id,
        kind: 'slider',
        label: label,
        value: current,
        min: minVal,
        max: maxVal,
        step: stepVal,
      );
      return current;
    },
    signature:
        'slider(id: String, min: double = 0.0, max: double = 10.0, value: double = 0.0, step: double?) -> double',
    documentation: 'Declares an interactive numeric slider parameter.',
  );

  // Interactive boolean toggle: viz.toggle("showMesh", value: true)
  builder.function(
    'toggle',
    (pos, named, ctx) {
      final id = '${pos[0]}';
      final defaultVal = (named['value'] as bool?) ??
          (pos.length > 1 ? pos[1] as bool : false);
      final label = (named['label'] as String?) ?? id;
      final override = ctx.interactiveInputs[id];
      final current = override is bool ? override : defaultVal;
      interactiveRegistry[id] = QudsInteractiveInput(
        id: id,
        kind: 'toggle',
        label: label,
        value: current,
      );
      return current;
    },
    signature:
        'toggle(id: String, value: bool = false, label: String?) -> bool',
    documentation: 'Declares an interactive boolean toggle control.',
  );

  // Interactive 2D geometry scene builder: viz.scene(title: ..., grid: true)
  builder.function(
    'scene',
    (pos, named, ctx) {
      final title =
          (named['title'] as String?) ?? (pos.isNotEmpty ? '${pos[0]}' : null);
      final showGrid = (named['grid'] as bool?) ?? true;
      final showAxes = (named['axes'] as bool?) ?? true;
      final interactive = (named['interactive'] as bool?) ?? true;
      final primitives = <QudsGeoPrimitive>[];

      void addPrim(QudsGeoPrimitive prim, SourceSpan span) {
        if (maxPrimitives != null && primitives.length >= maxPrimitives) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.primitiveLimit,
            'Geometry scene exceeded maximum primitive limit ($maxPrimitives).',
            span,
          );
        }
        primitives.add(prim);
      }

      late QudsNamespace sceneObj;
      sceneObj = QudsNamespace('QudsScene', {
        'point': QudsNativeFunction('scene.point', (p, n, c) {
          final id = '${p[0]}';
          final double x;
          final double y;
          var draggable = (n['draggable'] as bool?) ?? false;
          var label = n['label'] as String?;
          var color = (n['color'] as String?) ?? '#2563EB';
          if (p.length == 2) {
            final pt = _extractPoint(p[1], c.span);
            x = pt.$1;
            y = pt.$2;
            if (p[1] is QudsNamespace) {
              final ns = p[1] as QudsNamespace;
              draggable = (n['draggable'] as bool?) ??
                  (ns.members['draggable'] as bool? ?? false);
              label ??= ns.members['label'] as String?;
              color = (n['color'] as String?) ??
                  (ns.members['color'] as String? ?? color);
            }
          } else {
            x = _toDouble(p[1], c.span);
            y = _toDouble(p[2], c.span);
          }
          addPrim(
            QudsGeoPoint(
              id: id,
              x: x,
              y: y,
              label: label ?? id,
              color: color,
              radius: (n['radius'] as num?)?.toDouble() ?? 5.0,
              draggable: draggable,
            ),
            c.span,
          );
          return sceneObj;
        }),
        'segment': QudsNativeFunction('scene.segment', (p, n, c) {
          final id = '${p[0]}';
          final a = _extractPoint(p[1], c.span);
          final b = _extractPoint(p[2], c.span);
          addPrim(
            QudsGeoSegment(
              id: id,
              x1: a.$1,
              y1: a.$2,
              x2: b.$1,
              y2: b.$2,
              label: n['label'] as String?,
              color: (n['color'] as String?) ?? '#64748B',
              dashed: (n['dashed'] as bool?) ?? false,
              strokeWidth: (n['strokeWidth'] as num?)?.toDouble() ?? 2.0,
            ),
            c.span,
          );
          return sceneObj;
        }),
        'line': QudsNativeFunction('scene.line', (p, n, c) {
          final id = '${p[0]}';
          final a = _extractPoint(p[1], c.span);
          final b = _extractPoint(p[2], c.span);
          addPrim(
            QudsGeoLine(
              id: id,
              x1: a.$1,
              y1: a.$2,
              x2: b.$1,
              y2: b.$2,
              label: n['label'] as String?,
              color: (n['color'] as String?) ?? '#94A3B8',
              dashed: (n['dashed'] as bool?) ?? false,
            ),
            c.span,
          );
          return sceneObj;
        }),
        'circle': QudsNativeFunction('scene.circle', (p, n, c) {
          final id = '${p[0]}';
          final center = _extractPoint(p[1], c.span);
          final r = _toDouble(p[2], c.span);
          addPrim(
            QudsGeoCircle(
              id: id,
              cx: center.$1,
              cy: center.$2,
              radius: r,
              label: n['label'] as String?,
              stroke: (n['stroke'] as String?) ?? '#2563EB',
              fill: n['fill'] as String?,
              dashed: (n['dashed'] as bool?) ?? false,
            ),
            c.span,
          );
          return sceneObj;
        }),
        'arc': QudsNativeFunction('scene.arc', (p, n, c) {
          final id = '${p[0]}';
          final center = _extractPoint(p[1], c.span);
          final r = _toDouble(p[2], c.span);
          final start = _toDouble(p[3], c.span);
          final end = _toDouble(p[4], c.span);
          addPrim(
            QudsGeoArc(
              id: id,
              cx: center.$1,
              cy: center.$2,
              radius: r,
              startAngle: start,
              endAngle: end,
              label: n['label'] as String?,
              color: (n['color'] as String?) ?? '#10B981',
            ),
            c.span,
          );
          return sceneObj;
        }),
        'polygon': QudsNativeFunction('scene.polygon', (p, n, c) {
          final id = '${p[0]}';
          final rawPts = p[1] as Iterable;
          final pts = [for (final item in rawPts) _extractPoint(item, c.span)];
          addPrim(
            QudsGeoPolygon(
              id: id,
              points: pts,
              label: n['label'] as String?,
              stroke: (n['stroke'] as String?) ?? '#2563EB',
              fill: n['fill'] as String?,
              closed: (n['closed'] as bool?) ?? true,
            ),
            c.span,
          );
          return sceneObj;
        }),
        'mesh': QudsNativeFunction('scene.mesh', (p, n, c) {
          final prefix = '${p[0]}';
          final triangles = p[1] as Iterable;
          final rawVerts = n['vertices'] ?? (p.length > 2 ? p[2] : null);
          final vertices = rawVerts is Iterable
              ? [for (final v in rawVerts) _extractPoint(v, c.span)]
              : null;
          var idx = 0;
          for (final tri in triangles) {
            final pts = [
              for (final pt in (tri as Iterable))
                if (pt is int &&
                    vertices != null &&
                    pt >= 0 &&
                    pt < vertices.length)
                  vertices[pt]
                else
                  _extractPoint(pt, c.span),
            ];
            addPrim(
              QudsGeoPolygon(
                id: '${prefix}_$idx',
                points: pts,
                stroke: (n['stroke'] as String?) ?? '#38BDF8',
                fill: (n['fill'] as String?) ?? '#38BDF822',
              ),
              c.span,
            );
            idx++;
          }
          return sceneObj;
        }),
        'vector': QudsNativeFunction('scene.vector', (p, n, c) {
          final id = '${p[0]}';
          final a = _extractPoint(p[1], c.span);
          final b = _extractPoint(p[2], c.span);
          addPrim(
            QudsGeoVector(
              id: id,
              x1: a.$1,
              y1: a.$2,
              x2: b.$1,
              y2: b.$2,
              label: n['label'] as String?,
              color: (n['color'] as String?) ?? '#F59E0B',
            ),
            c.span,
          );
          return sceneObj;
        }),
        'angle': QudsNativeFunction('scene.angle', (p, n, c) {
          final id = '${p[0]}';
          final a = _extractPoint(p[1], c.span);
          final v = _extractPoint(p[2], c.span);
          final b = _extractPoint(p[3], c.span);
          final ux = a.$1 - v.$1;
          final uy = a.$2 - v.$2;
          final wx = b.$1 - v.$1;
          final wy = b.$2 - v.$2;
          final mag =
              math.sqrt(ux * ux + uy * uy) * math.sqrt(wx * wx + wy * wy);
          var degrees = 0.0;
          if (mag > 1e-12) {
            final cosTheta = ((ux * wx + uy * wy) / mag).clamp(-1.0, 1.0);
            degrees = math.acos(cosTheta) * 180.0 / math.pi;
          }
          addPrim(
            QudsGeoAngle(
              id: id,
              ax: a.$1,
              ay: a.$2,
              vx: v.$1,
              vy: v.$2,
              bx: b.$1,
              by: b.$2,
              degrees: degrees,
              label: n['label'] as String?,
              color: (n['color'] as String?) ?? '#10B981',
              showDegrees: (n['showDegrees'] as bool?) ?? true,
            ),
            c.span,
          );
          return sceneObj;
        }),
        'curve': QudsNativeFunction('scene.curve', (p, n, c) {
          final id = '${p[0]}';
          final rawPts = p[1] as Iterable;
          final pts = [for (final item in rawPts) _extractPoint(item, c.span)];
          addPrim(
            QudsGeoCurve(
              id: id,
              points: pts,
              label: n['label'] as String?,
              color: (n['color'] as String?) ?? '#8B5CF6',
              strokeWidth: (n['strokeWidth'] as num?)?.toDouble() ?? 2.0,
            ),
            c.span,
          );
          return sceneObj;
        }),
        'label': QudsNativeFunction('scene.label', (p, n, c) {
          final id = '${p[0]}';
          final pt = _extractPoint(p[1], c.span);
          final text = '${p[2]}';
          addPrim(
            QudsGeoLabel(
              id: id,
              x: pt.$1,
              y: pt.$2,
              text: text,
              color: (n['color'] as String?) ?? '#F8FAFC',
            ),
            c.span,
          );
          return sceneObj;
        }),
        'render': QudsNativeFunction('scene.render', (p, n, c) {
          checkOutputQuota(c.span);
          final output = QudsGeometrySceneOutput(
            primitives: List.unmodifiable(primitives),
            bounds: _computeBounds(primitives),
            interactiveInputs: List.unmodifiable(interactiveRegistry.values),
            title: title,
            showGrid: showGrid,
            showAxes: showAxes,
            interactive: interactive,
          );
          c.emitOutput(output);
          return output;
        }),
      });
      return sceneObj;
    },
    signature:
        'scene(title: String?, grid: bool = true, axes: bool = true, interactive: bool = true)',
    documentation: 'Creates an interactive 2D geometry scene builder.',
  );

  // Quick 2D plot: viz.plot(xs, ys, title: ..., kind: "line")
  builder.function(
    'plot',
    (pos, named, ctx) {
      checkOutputQuota(ctx.span);
      final xs = _toDoubleList(pos[0], ctx.span);
      final ys = _toDoubleList(pos[1], ctx.span);
      if (maxPrimitives != null && xs.length > maxPrimitives) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.primitiveLimit,
          'Plot point count (${xs.length}) exceeded maximum primitive limit ($maxPrimitives).',
          ctx.span,
        );
      }
      final out = QudsPlot2DOutput(
        interactiveInputs: List.unmodifiable(interactiveRegistry.values),
        title: named['title'] as String?,
        xLabel: named['xLabel'] as String?,
        yLabel: named['yLabel'] as String?,
        showGrid: (named['grid'] as bool?) ?? true,
        showLegend: (named['legend'] as bool?) ?? true,
        series: [
          QudsPlotSeries(
            xs: xs,
            ys: ys,
            name: (named['name'] as String?) ?? '',
            kind: (named['kind'] as String?) ?? 'line',
            color: (named['color'] as String?) ?? '#2563EB',
          ),
        ],
      );
      ctx.emitOutput(out);
      return out;
    },
    signature:
        'plot(xs: List<num>, ys: List<num>, title: String?, xLabel: String?, yLabel: String?, kind: String = "line", color: String?)',
    documentation: 'Emits a structured 2D plot (line, scatter, bar, or area).',
  );

  // Structured table: viz.table(["x", "y"], [[1, 2], [3, 4]], title: ...)
  builder.function(
    'table',
    (pos, named, ctx) {
      checkOutputQuota(ctx.span);
      final cols = [for (final c in (pos[0] as Iterable)) '$c'];
      final rows = [
        for (final r in (pos[1] as Iterable)) (r as Iterable).toList()
      ];
      final out = QudsTableOutput(
        columns: cols,
        rows: rows,
        title: named['title'] as String?,
      );
      ctx.emitOutput(out);
      return out;
    },
    signature:
        'table(columns: List<String>, rows: List<List<Object?>>, title: String?)',
    documentation: 'Emits a structured tabular data view.',
  );

  // Numeric matrix display: viz.matrix([[1.0, 2.0], [3.0, 4.0]], title: ...)
  builder.function(
    'matrix',
    (pos, named, ctx) {
      checkOutputQuota(ctx.span);
      final raw = pos[0] as Iterable;
      final values = [
        for (final row in raw) _toDoubleList(row, ctx.span),
      ];
      final out = QudsMatrixOutput(values, title: named['title'] as String?);
      ctx.emitOutput(out);
      return out;
    },
    signature: 'matrix(values: List<List<num>>, title: String?)',
    documentation: 'Emits a structured 2D numeric matrix view.',
  );

  // LaTeX & Markdown outputs
  builder.function(
    'latex',
    (pos, named, ctx) {
      checkOutputQuota(ctx.span);
      final out = QudsTextOutput('${pos[0]}',
          format: 'latex', title: named['title'] as String?);
      ctx.emitOutput(out);
      return out;
    },
    signature: 'latex(expression: String, title: String?)',
    documentation: 'Emits a LaTeX math block.',
  );

  builder.function(
    'markdown',
    (pos, named, ctx) {
      checkOutputQuota(ctx.span);
      final out = QudsTextOutput('${pos[0]}',
          format: 'markdown', title: named['title'] as String?);
      ctx.emitOutput(out);
      return out;
    },
    signature: 'markdown(content: String, title: String?)',
    documentation: 'Emits a formatted Markdown block.',
  );

  return builder.build();
}

(double, double) _extractPoint(Object? value, SourceSpan span) {
  if (value is QudsInstance) {
    final x = value.fields['x'];
    final y = value.fields['y'];
    if (x is num && y is num) return (x.toDouble(), y.toDouble());
  }
  if (value is QudsNamespace) {
    final x = value.members['x'];
    final y = value.members['y'];
    if (x is num && y is num) return (x.toDouble(), y.toDouble());
  }
  if (value is QudsRecord && value.positional.length >= 2) {
    return (
      _toDouble(value.positional[0], span),
      _toDouble(value.positional[1], span)
    );
  }
  if (value is List && value.length >= 2) {
    return (_toDouble(value[0], span), _toDouble(value[1], span));
  }
  if (value is Map && value.containsKey('x') && value.containsKey('y')) {
    return (_toDouble(value['x'], span), _toDouble(value['y'], span));
  }
  throw QudsRuntimeException(
    'Expected a 2D point (Vec2, viz.point, [x, y], or (x, y)), got `${qudsTypeName(value)}`.',
    span,
  );
}

double _toDouble(Object? v, SourceSpan span) {
  if (v is num) return v.toDouble();
  throw QudsRuntimeException(
      'Expected numeric value, got `${qudsTypeName(v)}`.', span);
}

List<double> _toDoubleList(Object? v, SourceSpan span) {
  if (v is! Iterable) {
    throw QudsRuntimeException(
        'Expected numeric list, got `${qudsTypeName(v)}`.', span);
  }
  return [for (final item in v) _toDouble(item, span)];
}

QudsGeoBounds _computeBounds(List<QudsGeoPrimitive> primitives) {
  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  var minY = double.infinity;
  var maxY = double.negativeInfinity;

  void include(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    if (x < minX) minX = x;
    if (x > maxX) maxX = x;
    if (y < minY) minY = y;
    if (y > maxY) maxY = y;
  }

  for (final p in primitives) {
    switch (p) {
      case QudsGeoPoint():
        include(p.x, p.y);
      case QudsGeoSegment():
        include(p.x1, p.y1);
        include(p.x2, p.y2);
      case QudsGeoLine():
        include(p.x1, p.y1);
        include(p.x2, p.y2);
      case QudsGeoVector():
        include(p.x1, p.y1);
        include(p.x2, p.y2);
      case QudsGeoCircle():
        include(p.cx - p.radius, p.cy - p.radius);
        include(p.cx + p.radius, p.cy + p.radius);
      case QudsGeoArc():
        include(p.cx - p.radius, p.cy - p.radius);
        include(p.cx + p.radius, p.cy + p.radius);
      case QudsGeoPolygon():
        for (final pt in p.points) {
          include(pt.$1, pt.$2);
        }
      case QudsGeoCurve():
        for (final pt in p.points) {
          include(pt.$1, pt.$2);
        }
      case QudsGeoAngle():
        include(p.ax, p.ay);
        include(p.vx, p.vy);
        include(p.bx, p.by);
      case QudsGeoLabel():
        include(p.x, p.y);
    }
  }

  if (!minX.isFinite) {
    return const QudsGeoBounds(minX: -5, maxX: 5, minY: -5, maxY: 5);
  }
  final dx = math.max((maxX - minX) * 0.15, 0.5);
  final dy = math.max((maxY - minY) * 0.15, 0.5);
  return QudsGeoBounds(
    minX: minX - dx,
    maxX: maxX + dx,
    minY: minY - dy,
    maxY: maxY + dy,
  );
}
