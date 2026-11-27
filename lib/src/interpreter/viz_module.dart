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
  QudsAnimationSpec? activeAnimation;

  final builder = QudsHostModule.builder(
    'quds:viz',
    description:
        'Scientific plotting, 3D surfaces, vector fields, graphs, animations, micro-app controls, tables, matrices, LaTeX, and interactive 2D geometry scenes.',
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

  // Micro-App Form Controls: input, number, select, color, button
  builder.function(
    'input',
    (pos, named, ctx) {
      final id = '${pos[0]}';
      final defaultVal =
          (named['value'] ?? (pos.length > 1 ? pos[1] : '')).toString();
      final label = (named['label'] as String?) ?? id;
      final override = ctx.interactiveInputs[id];
      final current = override != null ? '$override' : defaultVal;
      interactiveRegistry[id] = QudsInteractiveInput(
        id: id,
        kind: 'textInput',
        label: label,
        value: current,
      );
      return current;
    },
    signature:
        'input(id: String, value: String = "", label: String?) -> String',
    documentation: 'Declares an interactive text input control for micro-apps.',
  );

  builder.function(
    'number',
    (pos, named, ctx) {
      final id = '${pos[0]}';
      final defaultVal = _toDouble(
          named['value'] ?? (pos.length > 1 ? pos[1] : 0.0), ctx.span);
      final minVal =
          named['min'] != null ? _toDouble(named['min'], ctx.span) : null;
      final maxVal =
          named['max'] != null ? _toDouble(named['max'], ctx.span) : null;
      final stepVal =
          named['step'] != null ? _toDouble(named['step'], ctx.span) : null;
      final label = (named['label'] as String?) ?? id;
      final override = ctx.interactiveInputs[id];
      var current = override is num
          ? override.toDouble()
          : (override is String
              ? (double.tryParse(override) ?? defaultVal)
              : defaultVal);
      if (minVal != null && current < minVal) current = minVal;
      if (maxVal != null && current > maxVal) current = maxVal;
      interactiveRegistry[id] = QudsInteractiveInput(
        id: id,
        kind: 'numberInput',
        label: label,
        value: current,
        min: minVal,
        max: maxVal,
        step: stepVal,
      );
      return current;
    },
    signature:
        'number(id: String, value: double = 0.0, min: double?, max: double?, step: double?, label: String?) -> double',
    documentation: 'Declares an interactive numeric field control.',
  );

  builder.function(
    'select',
    (pos, named, ctx) {
      final id = '${pos[0]}';
      final rawOptions = (named['options'] ??
          (pos.length > 1 ? pos[1] : const [])) as Iterable;
      final options = [for (final o in rawOptions) '$o'];
      final defaultVal = named['value'] != null
          ? '${named['value']}'
          : (pos.length > 2
              ? '${pos[2]}'
              : (options.isNotEmpty ? options.first : ''));
      final label = (named['label'] as String?) ?? id;
      final override = ctx.interactiveInputs[id];
      final current = (override != null && options.contains('$override'))
          ? '$override'
          : defaultVal;
      interactiveRegistry[id] = QudsInteractiveInput(
        id: id,
        kind: 'select',
        label: label,
        value: current,
        options: options,
      );
      return current;
    },
    signature:
        'select(id: String, options: List<String>, value: String?, label: String?) -> String',
    documentation:
        'Declares an interactive dropdown / choice selector control.',
  );

  builder.function(
    'color',
    (pos, named, ctx) {
      final id = '${pos[0]}';
      final defaultVal = (named['value'] as String?) ??
          (pos.length > 1 ? '${pos[1]}' : '#2563EB');
      final label = (named['label'] as String?) ?? id;
      final override = ctx.interactiveInputs[id];
      final current = override is String ? override : defaultVal;
      interactiveRegistry[id] = QudsInteractiveInput(
        id: id,
        kind: 'color',
        label: label,
        value: current,
      );
      return current;
    },
    signature:
        'color(id: String, value: String = "#2563EB", label: String?) -> String',
    documentation: 'Declares an interactive hex color picker control.',
  );

  builder.function(
    'button',
    (pos, named, ctx) {
      final id = '${pos[0]}';
      final label = (named['label'] as String?) ?? id;
      final override = ctx.interactiveInputs[id];
      final clicks = override is num ? override.toInt() : 0;
      interactiveRegistry[id] = QudsInteractiveInput(
        id: id,
        kind: 'button',
        label: label,
        value: clicks,
      );
      return clicks;
    },
    signature: 'button(id: String, label: String?) -> int',
    documentation:
        'Declares an interactive action button returning its tap count.',
  );

  // Frame-stepped animation loop: viz.animate(fps: 60, duration: 10.0, loop: true)
  builder.function(
    'animate',
    (pos, named, ctx) {
      final fps = ((named['fps'] ?? (pos.isNotEmpty ? pos[0] : 60)) as num)
          .toInt()
          .clamp(1, 120);
      final duration = named['duration'] != null
          ? _toDouble(named['duration'], ctx.span)
          : null;
      final loop = (named['loop'] as bool?) ?? true;
      var t =
          (ctx.interactiveInputs['__quds_anim_t'] as num?)?.toDouble() ?? 0.0;
      final dt =
          (ctx.interactiveInputs['__quds_anim_dt'] as num?)?.toDouble() ??
              (1.0 / fps);
      final frame =
          (ctx.interactiveInputs['__quds_anim_frame'] as num?)?.toInt() ?? 0;
      final playing =
          (ctx.interactiveInputs['__quds_anim_playing'] as bool?) ?? true;
      if (duration != null && duration > 0) {
        t = loop ? (t % duration) : t.clamp(0.0, duration);
      }
      activeAnimation = QudsAnimationSpec(
        fps: fps,
        duration: duration,
        loop: loop,
        playing: playing,
        time: t,
        dt: dt,
        frame: frame,
      );
      return QudsNamespace('AnimationClock', {
        't': t,
        'time': t,
        'dt': dt,
        'frame': frame,
        'fps': fps,
        'playing': playing,
      });
    },
    signature:
        'animate(fps: int = 60, duration: double?, loop: bool = true) -> AnimationClock',
    documentation:
        'Enables frame-stepped 60fps simulation/animation and returns {t, dt, frame, fps, playing}.',
  );

  builder.function(
    'time',
    (pos, named, ctx) =>
        (ctx.interactiveInputs['__quds_anim_t'] as num?)?.toDouble() ?? 0.0,
    signature: 'time() -> double',
    documentation: 'Returns the current animation clock time in seconds.',
  );

  builder.function(
    'dt',
    (pos, named, ctx) =>
        (ctx.interactiveInputs['__quds_anim_dt'] as num?)?.toDouble() ??
        (1.0 / 60.0),
    signature: 'dt() -> double',
    documentation: 'Returns the current animation delta time in seconds.',
  );

  builder.function(
    'frame',
    (pos, named, ctx) =>
        (ctx.interactiveInputs['__quds_anim_frame'] as num?)?.toInt() ?? 0,
    signature: 'frame() -> int',
    documentation: 'Returns the current 0-based animation frame index.',
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
        'trail': QudsNativeFunction('scene.trail', (p, n, c) {
          final id = '${p[0]}';
          final rawPts = p[1] as Iterable;
          final pts = [for (final item in rawPts) _extractPoint(item, c.span)];
          addPrim(
            QudsGeoCurve(
              id: id,
              points: pts,
              label: n['label'] as String?,
              color: (n['color'] as String?) ?? '#38BDF8',
              strokeWidth: (n['strokeWidth'] as num?)?.toDouble() ?? 1.8,
            ),
            c.span,
          );
          return sceneObj;
        }),
        'intersect': QudsNativeFunction('scene.intersect', (p, n, c) {
          final a1 = _extractPoint(p[0], c.span);
          final a2 = _extractPoint(p[1], c.span);
          final b1 = _extractPoint(p[2], c.span);
          final b2 = _extractPoint(p[3], c.span);
          final denom = (a1.$1 - a2.$1) * (b1.$2 - b2.$2) -
              (a1.$2 - a2.$2) * (b1.$1 - b2.$1);
          if (denom.abs() < 1e-12) return null;
          final detA = a1.$1 * a2.$2 - a1.$2 * a2.$1;
          final detB = b1.$1 * b2.$2 - b1.$2 * b2.$1;
          final ix = (detA * (b1.$1 - b2.$1) - (a1.$1 - a2.$1) * detB) / denom;
          final iy = (detA * (b1.$2 - b2.$2) - (a1.$2 - a2.$2) * detB) / denom;
          return [ix, iy];
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
            animation: activeAnimation,
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
        animation: activeAnimation,
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

  // 3D Surface plot: viz.surface3d(fn_or_grid, xMin: -3, xMax: 3, yMin: -3, yMax: 3, steps: 20)
  builder.function(
    'surface3d',
    (pos, named, ctx) async {
      checkOutputQuota(ctx.span);
      final source = pos[0];
      final xMin = _toDouble(named['xMin'] ?? -3.0, ctx.span);
      final xMax = _toDouble(named['xMax'] ?? 3.0, ctx.span);
      final yMin = _toDouble(named['yMin'] ?? -3.0, ctx.span);
      final yMax = _toDouble(named['yMax'] ?? 3.0, ctx.span);
      final colorMap = (named['colorMap'] as String?) ?? 'viridis';
      final wireframe = (named['wireframe'] as bool?) ?? true;
      final yaw = _toDouble(named['yaw'] ?? 0.68, ctx.span);
      final pitch = _toDouble(named['pitch'] ?? 0.54, ctx.span);
      final title = named['title'] as String?;

      late List<double> xs;
      late List<double> ys;
      late List<List<double>> zs;

      if (source is QudsCallable) {
        final steps = ((named['steps'] ?? 18) as num).toInt().clamp(2, 60);
        if (maxPrimitives != null &&
            (steps + 1) * (steps + 1) > maxPrimitives) {
          throw QudsPolicyViolationException(
            QudsPolicyViolationKind.primitiveLimit,
            '3D surface resolution exceeded maximum primitive limit ($maxPrimitives).',
            ctx.span,
          );
        }
        xs = [
          for (var i = 0; i <= steps; i++) xMin + (xMax - xMin) * (i / steps)
        ];
        ys = [
          for (var j = 0; j <= steps; j++) yMin + (yMax - yMin) * (j / steps)
        ];
        zs = <List<double>>[];
        for (final y in ys) {
          final row = <double>[];
          for (final x in xs) {
            final res = await ctx.invokeCallable(source, [x, y], {}, ctx.span);
            row.add(_toDouble(res, ctx.span));
          }
          zs.add(row);
        }
      } else if (source is Iterable) {
        zs = [for (final row in source) _toDoubleList(row, ctx.span)];
        final rows = zs.length;
        final cols = rows == 0 ? 0 : zs.first.length;
        xs = [
          for (var i = 0; i < cols; i++)
            cols <= 1 ? xMin : xMin + (xMax - xMin) * (i / (cols - 1))
        ];
        ys = [
          for (var j = 0; j < rows; j++)
            rows <= 1 ? yMin : yMin + (yMax - yMin) * (j / (rows - 1))
        ];
      } else {
        throw QudsRuntimeException(
          'viz.surface3d expects a function (x, y) -> num or a 2D numeric grid.',
          ctx.span,
        );
      }

      final out = QudsSurface3DOutput(
        xs: xs,
        ys: ys,
        zs: zs,
        title: title,
        colorMap: colorMap,
        wireframe: wireframe,
        yaw: yaw,
        pitch: pitch,
        interactiveInputs: List.unmodifiable(interactiveRegistry.values),
        animation: activeAnimation,
      );
      ctx.emitOutput(out);
      return out;
    },
    signature:
        'surface3d(fnOrGrid, xMin: double = -3.0, xMax: double = 3.0, yMin: double = -3.0, yMax: double = 3.0, steps: int = 18, title: String?, colorMap: String = "viridis", wireframe: bool = true)',
    documentation:
        'Emits an interactive 3D surface mesh z = f(x, y) supporting touch/mouse rotation and SVG export.',
  );

  // 2D Vector / Slope Field: viz.vectorField(fn, xMin: -4, xMax: 4, yMin: -4, yMax: 4, steps: 11)
  builder.function(
    'vectorField',
    (pos, named, ctx) async {
      checkOutputQuota(ctx.span);
      final fn = pos[0];
      if (fn is! QudsCallable) {
        throw QudsRuntimeException(
          'viz.vectorField expects a callable (x, y) -> [vx, vy].',
          ctx.span,
        );
      }
      final xMin = _toDouble(named['xMin'] ?? -4.0, ctx.span);
      final xMax = _toDouble(named['xMax'] ?? 4.0, ctx.span);
      final yMin = _toDouble(named['yMin'] ?? -4.0, ctx.span);
      final yMax = _toDouble(named['yMax'] ?? 4.0, ctx.span);
      final steps = ((named['steps'] ?? 11) as num).toInt().clamp(2, 40);
      if (maxPrimitives != null && (steps + 1) * (steps + 1) > maxPrimitives) {
        throw QudsPolicyViolationException(
          QudsPolicyViolationKind.primitiveLimit,
          'Vector field arrow count exceeded maximum primitive limit ($maxPrimitives).',
          ctx.span,
        );
      }
      final arrows = <QudsVectorFieldArrow>[];
      for (var j = 0; j <= steps; j++) {
        final y = yMin + (yMax - yMin) * (j / steps);
        for (var i = 0; i <= steps; i++) {
          final x = xMin + (xMax - xMin) * (i / steps);
          final res = await ctx.invokeCallable(fn, [x, y], {}, ctx.span);
          final vec = _extractPoint(res, ctx.span);
          arrows.add(QudsVectorFieldArrow(x: x, y: y, vx: vec.$1, vy: vec.$2));
        }
      }
      final out = QudsVectorFieldOutput(
        arrows: arrows,
        bounds: QudsGeoBounds(minX: xMin, maxX: xMax, minY: yMin, maxY: yMax),
        title: named['title'] as String?,
        color: (named['color'] as String?) ?? '#38BDF8',
        interactiveInputs: List.unmodifiable(interactiveRegistry.values),
        animation: activeAnimation,
      );
      ctx.emitOutput(out);
      return out;
    },
    signature:
        'vectorField(fn, xMin: double = -4.0, xMax: double = 4.0, yMin: double = -4.0, yMax: double = 4.0, steps: int = 11, title: String?)',
    documentation:
        'Evaluates a 2D vector/slope field (x, y) -> [vx, vy] and emits an interactive vector field.',
  );

  // Interactive Graph / Network builder: viz.graph(title: ..., directed: false)
  builder.function(
    'graph',
    (pos, named, ctx) {
      final title =
          (named['title'] as String?) ?? (pos.isNotEmpty ? '${pos[0]}' : null);
      final directed = (named['directed'] as bool?) ?? false;
      final nodes = <QudsGraphNode>[];
      final edges = <QudsGraphEdge>[];

      late QudsNamespace graphObj;
      graphObj = QudsNamespace('QudsGraph', {
        'node': QudsNativeFunction('graph.node', (p, n, c) {
          final id = '${p[0]}';
          final x = p.length > 1 ? _toDouble(p[1], c.span) : 0.0;
          final y = p.length > 2 ? _toDouble(p[2], c.span) : 0.0;
          nodes.removeWhere((existing) => existing.id == id);
          nodes.add(QudsGraphNode(
            id: id,
            x: x,
            y: y,
            label: (n['label'] as String?) ?? id,
            color: (n['color'] as String?) ?? '#2563EB',
            highlighted: (n['highlighted'] as bool?) ?? false,
          ));
          return graphObj;
        }),
        'circleLayout': QudsNativeFunction('graph.circleLayout', (p, n, c) {
          final ids = [for (final item in (p[0] as Iterable)) '$item'];
          final radius = _toDouble(n['radius'] ?? 4.0, c.span);
          final color = (n['color'] as String?) ?? '#2563EB';
          final count = ids.length;
          for (var i = 0; i < count; i++) {
            final angle = (2 * math.pi * i) / math.max(count, 1) - math.pi / 2;
            final id = ids[i];
            nodes.removeWhere((existing) => existing.id == id);
            nodes.add(QudsGraphNode(
              id: id,
              x: radius * math.cos(angle),
              y: radius * math.sin(angle),
              label: id,
              color: color,
            ));
          }
          return graphObj;
        }),
        'edge': QudsNativeFunction('graph.edge', (p, n, c) {
          final from = '${p[0]}';
          final to = '${p[1]}';
          final weight = n['weight'] != null
              ? _toDouble(n['weight'], c.span)
              : (p.length > 2 ? _toDouble(p[2], c.span) : null);
          edges.add(QudsGraphEdge(
            from: from,
            to: to,
            weight: weight,
            directed: (n['directed'] as bool?) ?? directed,
            color: (n['color'] as String?) ?? '#64748B',
            highlighted: (n['highlighted'] as bool?) ?? false,
          ));
          return graphObj;
        }),
        'highlightPath': QudsNativeFunction('graph.highlightPath', (p, n, c) {
          final path = [for (final item in (p[0] as Iterable)) '$item'];
          final pathSet = path.toSet();
          for (var i = 0; i < nodes.length; i++) {
            if (pathSet.contains(nodes[i].id)) {
              final cur = nodes[i];
              nodes[i] = QudsGraphNode(
                id: cur.id,
                x: cur.x,
                y: cur.y,
                label: cur.label,
                color: cur.color,
                highlighted: true,
              );
            }
          }
          final edgePairs = <(String, String)>{};
          for (var i = 0; i + 1 < path.length; i++) {
            edgePairs.add((path[i], path[i + 1]));
            if (!directed) edgePairs.add((path[i + 1], path[i]));
          }
          for (var i = 0; i < edges.length; i++) {
            final cur = edges[i];
            if (edgePairs.contains((cur.from, cur.to))) {
              edges[i] = QudsGraphEdge(
                from: cur.from,
                to: cur.to,
                weight: cur.weight,
                directed: cur.directed,
                color: cur.color,
                highlighted: true,
              );
            }
          }
          return graphObj;
        }),
        'render': QudsNativeFunction('graph.render', (p, n, c) {
          checkOutputQuota(c.span);
          final out = QudsGraphOutput(
            nodes: List.unmodifiable(nodes),
            edges: List.unmodifiable(edges),
            directed: directed,
            title: title,
            interactiveInputs: List.unmodifiable(interactiveRegistry.values),
            animation: activeAnimation,
          );
          c.emitOutput(out);
          return out;
        }),
      });
      return graphObj;
    },
    signature: 'graph(title: String?, directed: bool = false)',
    documentation:
        'Creates an interactive graph/network builder with circleLayout, node, edge, highlightPath, and render.',
  );

  // Micro-App Form output card: viz.form(entries, title: ..., summary: ...)
  builder.function(
    'form',
    (pos, named, ctx) {
      checkOutputQuota(ctx.span);
      final entries = <String, Object?>{};
      if (pos.isNotEmpty) {
        final raw = pos[0];
        if (raw is Map) {
          for (final e in raw.entries) {
            entries['${e.key}'] = e.value;
          }
        } else if (raw is Iterable) {
          for (final item in raw) {
            if (item is List && item.length >= 2) {
              entries['${item[0]}'] = item[1];
            } else if (item is QudsRecord && item.positional.length >= 2) {
              entries['${item.positional[0]}'] = item.positional[1];
            }
          }
        }
      }
      final out = QudsFormOutput(
        entries: entries,
        title: named['title'] as String?,
        summary: named['summary'] as String?,
        interactiveInputs: List.unmodifiable(interactiveRegistry.values),
      );
      ctx.emitOutput(out);
      return out;
    },
    signature:
        'form(entries: Map<String, Object?>, title: String?, summary: String?)',
    documentation:
        'Emits an interactive Micro-App form card displaying declared controls and live computed results.',
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
