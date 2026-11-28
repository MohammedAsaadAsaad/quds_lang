/// Rich Flutter widgets for `quds:viz` 2.0 outputs:
/// - Touch-rotatable 3D Surface Canvas (`QudsSurface3DCanvas`)
/// - 2D Vector / Slope Field Canvas (`QudsVectorFieldCanvas`)
/// - Interactive Graph / Network Canvas (`QudsGraphCanvas`)
/// - Micro-App Form & Controls Card (`QudsFormOutputCard`)
/// - 60fps Animation Transport Bar (`QudsAnimationControlsBar`)
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quds/interpreter.dart';

// ---------------------------------------------------------------------------
// 1. Touch-Rotatable 3D Surface Canvas
// ---------------------------------------------------------------------------

class QudsSurface3DCanvas extends StatefulWidget {
  const QudsSurface3DCanvas({
    super.key,
    required this.surface,
    required this.isDark,
  });

  final QudsSurface3DOutput surface;
  final bool isDark;

  @override
  State<QudsSurface3DCanvas> createState() => _QudsSurface3DCanvasState();
}

class _QudsSurface3DCanvasState extends State<QudsSurface3DCanvas> {
  late double _yaw;
  late double _pitch;

  @override
  void initState() {
    super.initState();
    _yaw = widget.surface.yaw;
    _pitch = widget.surface.pitch;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quds_surface3d_canvas'),
      decoration: BoxDecoration(
        color:
            widget.isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _yaw += details.delta.dx * 0.012;
                _pitch = (_pitch + details.delta.dy * 0.012).clamp(0.15, 1.45);
              });
            },
            child: CustomPaint(
              painter: _Surface3DPainter(
                surface: widget.surface,
                yaw: _yaw,
                pitch: _pitch,
                isDark: widget.isDark,
              ),
              size: Size.infinite,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '3D · اسحب للتدوير',
                    style: TextStyle(color: Colors.white70, fontSize: 10.5),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filledTonal(
                  onPressed: () => setState(() {
                    _yaw = widget.surface.yaw;
                    _pitch = widget.surface.pitch;
                  }),
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Surface3DPainter extends CustomPainter {
  const _Surface3DPainter({
    required this.surface,
    required this.yaw,
    required this.pitch,
    required this.isDark,
  });

  final QudsSurface3DOutput surface;
  final double yaw;
  final double pitch;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rows = surface.zs.length;
    final cols = rows == 0 ? 0 : surface.zs.first.length;
    if (rows < 2 || cols < 2) return;

    if (surface.title != null && surface.title!.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: surface.title!,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: size.width - 24);
      tp.paint(canvas, Offset(12, 10));
    }

    var minZ = double.infinity;
    var maxZ = double.negativeInfinity;
    for (final r in surface.zs) {
      for (final z in r) {
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

    final minX = surface.xs.first;
    final maxX = surface.xs.last == minX ? minX + 1 : surface.xs.last;
    final minY = surface.ys.first;
    final maxY = surface.ys.last == minY ? minY + 1 : surface.ys.last;
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final scale = math.min(size.width, size.height) * 0.34;

    (Offset, double) project(int r, int c) {
      final nx = ((surface.xs[c] - minX) / (maxX - minX)) * 2 - 1;
      final ny = ((surface.ys[r] - minY) / (maxY - minY)) * 2 - 1;
      final nz = ((surface.zs[r][c] - minZ) / (maxZ - minZ)) * 1.3 - 0.65;
      final rx = nx * cosY - ny * sinY;
      final ry = nx * sinY + ny * cosY;
      final py = ry * cosP - nz * sinP;
      final pz = ry * sinP + nz * cosP;
      return (
        Offset(size.width * 0.5 + rx * scale, size.height * 0.56 - py * scale),
        pz,
      );
    }

    final quads = <(double depth, List<Offset> pts, double t)>[];
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final p0 = project(r, c);
        final p1 = project(r, c + 1);
        final p2 = project(r + 1, c + 1);
        final p3 = project(r + 1, c);
        final depth = (p0.$2 + p1.$2 + p2.$2 + p3.$2) * 0.25;
        final avgZ = (surface.zs[r][c] +
                surface.zs[r][c + 1] +
                surface.zs[r + 1][c + 1] +
                surface.zs[r + 1][c]) *
            0.25;
        final t = ((avgZ - minZ) / (maxZ - minZ)).clamp(0.0, 1.0);
        quads.add((depth, [p0.$1, p1.$1, p2.$1, p3.$1], t));
      }
    }
    quads.sort((a, b) => a.$1.compareTo(b.$1));

    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = isDark ? const Color(0x660F172A) : const Color(0x44334155);

    for (final q in quads) {
      final path = Path()
        ..moveTo(q.$2[0].dx, q.$2[0].dy)
        ..lineTo(q.$2[1].dx, q.$2[1].dy)
        ..lineTo(q.$2[2].dx, q.$2[2].dy)
        ..lineTo(q.$2[3].dx, q.$2[3].dy)
        ..close();
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = _gradientColor(surface.colorMap, q.$3).withValues(alpha: 0.9);
      canvas.drawPath(path, fillPaint);
      if (surface.wireframe) {
        canvas.drawPath(path, wirePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Surface3DPainter old) =>
      old.surface != surface ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.isDark != isDark;
}

// ---------------------------------------------------------------------------
// 2. 2D Vector / Slope Field Canvas
// ---------------------------------------------------------------------------

class QudsVectorFieldCanvas extends StatelessWidget {
  const QudsVectorFieldCanvas({
    super.key,
    required this.field,
    required this.isDark,
  });

  final QudsVectorFieldOutput field;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quds_vector_field_canvas'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _VectorFieldPainter(field: field, isDark: isDark),
        size: Size.infinite,
      ),
    );
  }
}

class _VectorFieldPainter extends CustomPainter {
  const _VectorFieldPainter({required this.field, required this.isDark});

  final QudsVectorFieldOutput field;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 34.0;
    final viewW = math.max(size.width - pad * 2, 10.0);
    final viewH = math.max(size.height - pad * 2, 10.0);
    final b = field.bounds;
    double sx(double x) =>
        pad + ((x - b.minX) / math.max(b.width, 1e-6)) * viewW;
    double sy(double y) =>
        pad + viewH - ((y - b.minY) / math.max(b.height, 1e-6)) * viewH;

    // Axes
    final axisPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;
    if (b.minY <= 0 && b.maxY >= 0) {
      final oy = sy(0);
      canvas.drawLine(Offset(pad, oy), Offset(size.width - pad, oy), axisPaint);
    }
    if (b.minX <= 0 && b.maxX >= 0) {
      final ox = sx(0);
      canvas.drawLine(
          Offset(ox, pad), Offset(ox, size.height - pad), axisPaint);
    }

    if (field.title != null && field.title!.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: field.title!,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: size.width - 24);
      tp.paint(canvas, const Offset(12, 8));
    }

    var maxMag = 0.0;
    for (final a in field.arrows) {
      if (a.magnitude > maxMag) maxMag = a.magnitude;
    }
    if (maxMag < 1e-12) maxMag = 1.0;

    final stepPx = math.min(viewW, viewH) /
        math.max(math.sqrt(field.arrows.length), 4) *
        0.72;

    for (final a in field.arrows) {
      final mag = a.magnitude;
      if (mag < 1e-12) continue;
      final t = (mag / maxMag).clamp(0.0, 1.0);
      final len = stepPx * (0.35 + 0.65 * t);
      final ux = a.vx / mag;
      final uy = a.vy / mag;
      final p1 = Offset(sx(a.x), sy(a.y));
      final p2 = Offset(p1.dx + ux * len, p1.dy - uy * len);
      final col = _gradientColor('viridis', t);
      final p = Paint()
        ..color = col
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p1, p2, p);
      // Arrowhead
      final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      const headLen = 5.5;
      canvas.drawLine(
        p2,
        Offset(
          p2.dx - headLen * math.cos(angle - 0.5),
          p2.dy - headLen * math.sin(angle - 0.5),
        ),
        p,
      );
      canvas.drawLine(
        p2,
        Offset(
          p2.dx - headLen * math.cos(angle + 0.5),
          p2.dy - headLen * math.sin(angle + 0.5),
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VectorFieldPainter old) =>
      old.field != field || old.isDark != isDark;
}

// ---------------------------------------------------------------------------
// 3. Interactive Graph / Network Canvas
// ---------------------------------------------------------------------------

class QudsGraphCanvas extends StatelessWidget {
  const QudsGraphCanvas({
    super.key,
    required this.graph,
    required this.isDark,
  });

  final QudsGraphOutput graph;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('quds_graph_canvas'),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _GraphPainter(graph: graph, isDark: isDark),
        size: Size.infinite,
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  const _GraphPainter({required this.graph, required this.isDark});

  final QudsGraphOutput graph;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (graph.title != null && graph.title!.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: graph.title!,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: size.width - 24);
      tp.paint(canvas, const Offset(12, 10));
    }

    if (graph.nodes.isEmpty) return;

    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final n in graph.nodes) {
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
    const pad = 48.0;
    final scale = math.min((size.width - pad * 2) / (maxX - minX),
        (size.height - pad * 2) / (maxY - minY));
    final midX = (minX + maxX) / 2;
    final midY = (minY + maxY) / 2;
    Offset pos(QudsGraphNode n) => Offset(
          size.width / 2 + (n.x - midX) * scale,
          size.height / 2 + 8 - (n.y - midY) * scale,
        );

    final byId = {for (final n in graph.nodes) n.id: n};

    // Draw edges
    for (final e in graph.edges) {
      final a = byId[e.from];
      final b = byId[e.to];
      if (a == null || b == null) continue;
      final p1 = pos(a);
      final p2 = pos(b);
      final paint = Paint()
        ..color = e.highlighted
            ? const Color(0xFFF59E0B)
            : _parseHex(e.color, const Color(0xFF64748B))
        ..strokeWidth = e.highlighted ? 3.2 : 1.7;
      canvas.drawLine(p1, p2, paint);

      if (e.weight != null) {
        final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        final wText = e.weight! == e.weight!.roundToDouble()
            ? '${e.weight!.round()}'
            : e.weight!.toStringAsFixed(1);
        final tp = TextPainter(
          text: TextSpan(
            text: wText,
            style: TextStyle(
              color: e.highlighted
                  ? const Color(0xFFF59E0B)
                  : (isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF334155)),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              backgroundColor:
                  isDark ? const Color(0xCC0B1120) : const Color(0xCCF8FAFC),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Draw nodes
    for (final n in graph.nodes) {
      final center = pos(n);
      final fill = n.highlighted
          ? const Color(0xFFF59E0B)
          : _parseHex(n.color, const Color(0xFF2563EB));
      canvas.drawCircle(center, 18, Paint()..color = fill);
      canvas.drawCircle(
        center,
        18,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white
          ..strokeWidth = n.highlighted ? 2.6 : 1.4,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: n.label ?? n.id,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.graph != graph || old.isDark != isDark;
}

// ---------------------------------------------------------------------------
// 4. Micro-App Form Output Card & Interactive Controls
// ---------------------------------------------------------------------------

class QudsFormOutputCard extends StatelessWidget {
  const QudsFormOutputCard({
    super.key,
    required this.form,
    required this.isDark,
  });

  final QudsFormOutput form;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);
    final fg = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    return Container(
      key: const Key('quds_form_output_card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (form.title != null)
            Text(
              form.title!,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (form.summary != null) ...[
            const SizedBox(height: 4),
            Text(
              form.summary!,
              style: TextStyle(
                color: fg.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final entry in form.entries.entries)
                Container(
                  constraints: const BoxConstraints(minWidth: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        qudsFormatValue(entry.value),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4b. Binary Image & Pixel-Grid Asset Output Card (`quds:assets`)
// ---------------------------------------------------------------------------

class QudsImageOutputCard extends StatelessWidget {
  const QudsImageOutputCard({
    super.key,
    required this.image,
    required this.isDark,
  });

  final QudsImageOutput image;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1);
    final fg = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub = fg.withValues(alpha: 0.65);
    final dims = (image.width != null && image.height != null)
        ? '${image.width}×${image.height}px'
        : null;
    final kb = image.bytes.length >= 1024
        ? '${(image.bytes.length / 1024).toStringAsFixed(1)} KB'
        : '${image.bytes.length} B';

    return Container(
      key: Key('quds_image_card_${image.assetPath ?? image.title ?? 'img'}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.image_rounded,
                  size: 16, color: Color(0xFFEC4899)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  image.title ?? image.assetPath ?? 'Asset Image',
                  style: TextStyle(
                    color: fg,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    [if (dims != null) dims, image.mimeType, kb].join(' · '),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      color: Color(0xFFEC4899),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(maxHeight: 220, minHeight: 80),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF060B16) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border.withValues(alpha: 0.7)),
            ),
            child: Center(
              child: Image.memory(
                Uint8List.fromList(image.bytes),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, err, __) => Text(
                  'Unsupported image bytes (${image.mimeType})',
                  style: TextStyle(color: sub, fontSize: 11.5),
                ),
              ),
            ),
          ),
          if (image.caption != null && image.caption!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              image.caption!,
              style: TextStyle(color: sub, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. 60fps Animation Transport Controls Bar
// ---------------------------------------------------------------------------

class QudsAnimationControlsBar extends StatelessWidget {
  const QudsAnimationControlsBar({
    super.key,
    required this.spec,
    required this.playing,
    required this.speed,
    required this.isArabic,
    required this.onTogglePlay,
    required this.onStepFrame,
    required this.onReset,
    required this.onSpeedChanged,
    this.onSeekTime,
  });

  final QudsAnimationSpec spec;
  final bool playing;
  final double speed;
  final bool isArabic;
  final VoidCallback onTogglePlay;
  final VoidCallback onStepFrame;
  final VoidCallback onReset;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double>? onSeekTime;

  @override
  Widget build(BuildContext context) {
    final duration = spec.duration;
    return Container(
      key: const Key('quds_animation_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilledButton.icon(
                  key: const Key('btn_anim_play_pause'),
                  onPressed: onTogglePlay,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 15,
                  ),
                  label: Text(
                    playing
                        ? (isArabic ? 'إيقاف' : 'Pause')
                        : (isArabic ? 'تشغيل' : 'Play'),
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('btn_anim_step'),
                  onPressed: onStepFrame,
                  tooltip: isArabic ? 'إطار واحد (+1)' : 'Step +1 Frame',
                  icon: const Icon(Icons.skip_next_rounded, size: 17),
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  key: const Key('btn_anim_reset'),
                  onPressed: onReset,
                  tooltip: isArabic ? 'إعادة الزمن t=0' : 'Reset t=0',
                  icon: const Icon(Icons.replay_rounded, size: 15),
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 4),
                ActionChip(
                  label: Text(
                    '${speed}x',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onPressed: () {
                    final next = speed < 0.9 ? 1.0 : (speed < 1.5 ? 2.0 : 0.5);
                    onSpeedChanged(next);
                  },
                ),
                const SizedBox(width: 8),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    duration != null && duration > 0
                        ? 't=${spec.time.toStringAsFixed(2)}/${duration.toStringAsFixed(1)}s · #${spec.frame}'
                        : 't=${spec.time.toStringAsFixed(2)}s · #${spec.frame}',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (duration != null && duration > 0 && onSeekTime != null)
            SizedBox(
              height: 22,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 11),
                ),
                child: Slider(
                  key: const Key('anim_timeline_scrubber'),
                  value: spec.time.clamp(0.0, duration),
                  min: 0.0,
                  max: duration,
                  onChanged: onSeekTime,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _gradientColor(String mapName, double t) {
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
    r = (68 + 185 * math.pow(v, 1.6)).round();
    g = (30 + 200 * math.pow(v, 0.75)).round();
    b = (110 + 100 * math.sin(v * math.pi) - 65 * v).round();
  }
  return Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
}

Color _parseHex(String raw, Color fallback) {
  final clean = raw.replaceFirst('#', '');
  if (clean.length == 6) {
    final v = int.tryParse('FF$clean', radix: 16);
    if (v != null) return Color(v);
  }
  return fallback;
}
