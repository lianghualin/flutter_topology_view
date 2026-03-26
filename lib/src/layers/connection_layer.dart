import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/topo_connection.dart';

/// A resolved connection line with absolute pixel positions.
class ResolvedConnection {
  final Offset source;
  final Offset target;
  final int status;
  final bool isDashed;
  final Color? lineColor;
  bool isHighlighted;

  ResolvedConnection({
    required this.source,
    required this.target,
    required this.status,
    this.isDashed = false,
    this.lineColor,
    this.isHighlighted = false,
  });

  /// Construct from a [TopoConnection] and pre-computed position map.
  factory ResolvedConnection.from(
    TopoConnection conn,
    Map<String, Offset> positions,
  ) {
    return ResolvedConnection(
      source: positions[conn.fromId] ?? Offset.zero,
      target: positions[conn.toId] ?? Offset.zero,
      status: conn.status,
      isDashed: conn.isDashed,
      lineColor: conn.lineColor,
    );
  }
}

// ---------------------------------------------------------------------------
// Layer 2: Connection rendering — lines, flowing dots, bezier highlights.
// ---------------------------------------------------------------------------

/// Layer 2 (middle): Draws all connection lines.
///
/// Supports:
/// - Status-based coloring (green / grey / red) or override [lineColor].
/// - Dashed lines for [isDashed] connections.
/// - Animated flowing dots along lines (when [showFlowDots] is true).
/// - Bezier highlight animation on hover (when [enableHighlight] is true).
class TopoConnectionLayer extends StatefulWidget {
  final List<ResolvedConnection> connections;
  final bool showFlowDots;
  final bool enableHighlight;

  const TopoConnectionLayer({
    super.key,
    required this.connections,
    this.showFlowDots = true,
    this.enableHighlight = true,
  });

  @override
  State<TopoConnectionLayer> createState() => _TopoConnectionLayerState();
}

class _TopoConnectionLayerState extends State<TopoConnectionLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void didUpdateWidget(TopoConnectionLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If highlight state changed, trigger a repaint via the controller.
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          painter: _ConnectionPainter(
            connections: widget.connections,
            animationValue: _controller.value,
            showFlowDots: widget.showFlowDots,
            enableHighlight: widget.enableHighlight,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// CustomPainter
// ---------------------------------------------------------------------------

class _ConnectionPainter extends CustomPainter {
  final List<ResolvedConnection> connections;
  final double animationValue;
  final bool showFlowDots;
  final bool enableHighlight;

  _ConnectionPainter({
    required this.connections,
    required this.animationValue,
    required this.showFlowDots,
    required this.enableHighlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    for (final conn in connections) {
      _paintConnection(canvas, conn);
    }
    canvas.restore();
  }

  void _paintConnection(Canvas canvas, ResolvedConnection conn) {
    final paint = Paint()..style = PaintingStyle.stroke;

    // Domain-level connections (lineColor set) use an S-curve.
    final bool useScurve = conn.lineColor != null;

    // Build path.
    final Path path = Path();
    path.moveTo(conn.source.dx, conn.source.dy);

    if (useScurve) {
      // Cubic bezier S-curve: control points offset in opposite perpendicular
      // directions to create the S-shape.
      final double dx = conn.target.dx - conn.source.dx;
      final double dy = conn.target.dy - conn.source.dy;
      // Perpendicular offset (scaled to ~20% of the connection length).
      final double len = (dx * dx + dy * dy);
      final double perpScale = len > 0 ? 0.2 : 0;
      // Perpendicular direction: rotate (dx, dy) by 90°.
      final double perpX = -dy * perpScale;
      final double perpY = dx * perpScale;
      final double cp1x = conn.source.dx + dx * 0.25 + perpX;
      final double cp1y = conn.source.dy + dy * 0.25 + perpY;
      final double cp2x = conn.source.dx + dx * 0.75 - perpX;
      final double cp2y = conn.source.dy + dy * 0.75 - perpY;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, conn.target.dx, conn.target.dy);
    } else {
      path.lineTo(conn.target.dx, conn.target.dy);
    }

    // Determine color.
    Color lineColor;
    if (useScurve) {
      // Domain-level: soft blue at 0.7 opacity.
      lineColor = const Color(0xFF5B8DEF).withValues(alpha: 0.7);
    } else if (conn.isHighlighted) {
      lineColor = conn.status == -1 ? Colors.deepOrange : Colors.blue;
    } else {
      switch (conn.status) {
        case 1:
          lineColor = Colors.green;
          break;
        case -1:
          lineColor = Colors.red;
          break;
        default:
          lineColor = Colors.grey;
      }
    }

    paint
      ..color = lineColor
      ..strokeWidth = useScurve ? 2.5 : (conn.isHighlighted ? 4 : 3);

    // Draw line (dashed or solid).
    if (conn.isDashed || conn.status == 0) {
      _drawDashedPath(canvas, path, paint);
    } else {
      canvas.drawPath(path, paint);
    }

    // Flowing dots — travel along the actual path.
    if (showFlowDots && !conn.isDashed) {
      _paintFlowDotsOnPath(canvas, path, conn);
    }
  }

  // -----------------------------------------------------------------------
  // Dashed line
  // -----------------------------------------------------------------------

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashLength = 5, double spaceLength = 4}) {
    final PathMetrics metrics = path.computeMetrics();
    for (final PathMetric metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        double next = distance + (draw ? dashLength : spaceLength);
        if (next > metric.length) next = metric.length;
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  // -----------------------------------------------------------------------
  // Flowing dots along the actual path (works for both straight and curved)
  // -----------------------------------------------------------------------

  void _paintFlowDotsOnPath(
      Canvas canvas, Path path, ResolvedConnection conn) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final PathMetric metric = metrics.first;
    final double totalLength = metric.length;
    if (totalLength == 0) return;

    const int dotCount = 3;

    // Domain-level (lineColor set): true bidirectional — dots flow in both
    // directions simultaneously. Switch-level: original bounce pattern.
    final bool trueBidirectional = conn.lineColor != null;

    for (int i = 0; i < dotCount; i++) {
      final double phaseOffset = (i * 2.0 / dotCount);

      if (trueBidirectional) {
        // Forward dot: source → target
        final double fwdT = (animationValue + i / dotCount) % 1.0;
        _drawDotAtT(canvas, metric, totalLength, fwdT);
        // Reverse dot: target → source
        final double revT = 1.0 - fwdT;
        _drawDotAtT(canvas, metric, totalLength, revT);
      } else {
        // Original bounce: 0→1→0
        final double animatedValue =
            (animationValue * 2.0 + phaseOffset) % 2.0;
        final double t =
            animatedValue <= 1.0 ? animatedValue : 2.0 - animatedValue;
        _drawDotAtT(canvas, metric, totalLength, t);
      }
    }
  }

  void _drawDotAtT(
      Canvas canvas, PathMetric metric, double totalLength, double t) {
    final tangent = metric.getTangentForOffset(t * totalLength);
    if (tangent != null) {
      final double opacity = _dotOpacity(t);
      final dotPaint = Paint()
        ..color = const Color(0xFF165DFF).withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(tangent.position, 4, dotPaint);
    }
  }

  double _dotOpacity(double position) {
    if (position < 0.1) return position / 0.1 * 0.8;
    if (position > 0.9) return (1.0 - position) / 0.1 * 0.8;
    return 0.8;
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.connections != connections;
  }
}
