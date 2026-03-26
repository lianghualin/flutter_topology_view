import 'package:flutter/material.dart';

import '../models/topo_node.dart';

/// Layer 1 (bottom): Draws ellipses around grouped nodes.
///
/// Each group gets an outlined ellipse with the group name painted
/// above the ellipse center. Ellipse color is blue (normal) or
/// red (any child node is abnormal).
class TopoGroupLayer extends StatelessWidget {
  /// Bounding rect for each group, keyed by group ID.
  final Map<String, Rect> groupBounds;

  /// All nodes — used to determine abnormal state per group.
  final List<TopoNode> nodes;

  const TopoGroupLayer({
    super.key,
    required this.groupBounds,
    required this.nodes,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GroupPainter(
        groupBounds: groupBounds,
        nodes: nodes,
      ),
    );
  }
}

class _GroupPainter extends CustomPainter {
  final Map<String, Rect> groupBounds;
  final List<TopoNode> nodes;

  _GroupPainter({required this.groupBounds, required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    for (final entry in groupBounds.entries) {
      final groupId = entry.key;
      final rect = entry.value;

      // Determine if any node in this group is abnormal.
      final bool isAbnormal = nodes.any(
        (n) => n.group == groupId && n.isAbnormal,
      );

      // Draw ellipse outline.
      final paint = Paint()
        ..color = isAbnormal ? Colors.red : Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawOval(rect, paint);

      // Draw group label above the ellipse.
      final textPainter = TextPainter(
        text: TextSpan(
          text: groupId,
          style: const TextStyle(
            fontFamily: 'Schyler',
            color: Colors.black54,
            fontSize: 20,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          rect.center.dx - textPainter.width / 2,
          rect.center.dy - rect.height / 3,
        ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GroupPainter oldDelegate) {
    return oldDelegate.groupBounds != groupBounds ||
        oldDelegate.nodes != nodes;
  }
}
