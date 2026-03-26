import 'package:flutter/material.dart';

/// Represents a connection line between two nodes in the topology.
class TopoConnection {
  /// Source node ID.
  final String fromId;

  /// Target node ID.
  final String toId;

  /// Connection status: 1 = normal (green), 0 = offline (grey), -1 = error (red).
  final int status;

  /// Whether to draw the line as dashed (e.g. cross-domain links).
  final bool isDashed;

  /// Override color for the connection line. When set, takes precedence
  /// over [status]-based coloring.
  final Color? lineColor;

  const TopoConnection({
    required this.fromId,
    required this.toId,
    this.status = 1,
    this.isDashed = false,
    this.lineColor,
  });
}
