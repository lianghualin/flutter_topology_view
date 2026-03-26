import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/topo_node.dart';
import '../models/topo_connection.dart';

/// Result of the BFS layout engine.
class LayoutResult {
  /// Computed center position for each node, keyed by [TopoNode.id].
  final Map<String, Offset> positions;

  /// Bounding rect for each group (keyed by group ID).
  /// Only populated when [enableGrouping] is true.
  final Map<String, Rect> groupBounds;

  /// Total content size (width, height) needed to contain all nodes.
  final Size contentSize;

  const LayoutResult({
    required this.positions,
    required this.groupBounds,
    required this.contentSize,
  });
}

/// Unified BFS layout engine.
///
/// 1. Builds an adjacency list from [connections].
/// 2. Finds the root node (first [TopoNode.isRoot], or most-connected, or first).
/// 3. BFS traversal assigns layer levels.
/// 4. Positions nodes per layer, centering horizontally.
/// 5. Optionally computes group bounding ellipses.
class BfsLayoutEngine {
  const BfsLayoutEngine._();

  /// Perform layout and return a [LayoutResult].
  static LayoutResult layout({
    required List<TopoNode> nodes,
    required List<TopoConnection> connections,
    required bool enableGrouping,
    required Size viewportSize,
  }) {
    if (nodes.isEmpty) {
      return const LayoutResult(
        positions: {},
        groupBounds: {},
        contentSize: Size.zero,
      );
    }

    if (enableGrouping) {
      return _layoutGroupLevel(nodes, connections, viewportSize);
    } else {
      return _layoutNodeLevel(nodes, connections, viewportSize);
    }
  }

  // =========================================================================
  // Group-level BFS (enableGrouping = true, domain-level)
  // =========================================================================

  static LayoutResult _layoutGroupLevel(
    List<TopoNode> nodes,
    List<TopoConnection> connections,
    Size viewportSize,
  ) {
    const double verticalSpacing = 350.0;
    const double yStart = 200.0;

    // 1. Collapse nodes into groups.
    final Map<String, List<TopoNode>> groupNodes = {};
    for (final node in nodes) {
      final g = node.group ?? node.id; // ungrouped nodes form their own group
      groupNodes.putIfAbsent(g, () => []).add(node);
    }
    // Map each node ID to its group ID for fast lookup.
    final Map<String, String> nodeToGroup = {};
    for (final entry in groupNodes.entries) {
      for (final node in entry.value) {
        nodeToGroup[node.id] = entry.key;
      }
    }

    // 2. Build group-level adjacency list.
    final Map<String, Set<String>> groupAdj = {};
    for (final g in groupNodes.keys) {
      groupAdj.putIfAbsent(g, () => {});
    }
    for (final conn in connections) {
      final gFrom = nodeToGroup[conn.fromId];
      final gTo = nodeToGroup[conn.toId];
      if (gFrom != null && gTo != null && gFrom != gTo) {
        groupAdj[gFrom]!.add(gTo);
        groupAdj[gTo]!.add(gFrom);
      }
    }

    // 3. Find root group — the group containing a node with isRoot.
    String? rootGroup;
    for (final node in nodes) {
      if (node.isRoot) {
        rootGroup = nodeToGroup[node.id];
        break;
      }
    }
    // Fallback: most-connected group.
    if (rootGroup == null) {
      int bestCount = -1;
      for (final entry in groupAdj.entries) {
        if (entry.value.length > bestCount) {
          bestCount = entry.value.length;
          rootGroup = entry.key;
        }
      }
    }
    rootGroup ??= groupNodes.keys.first;

    // 4. BFS on groups.
    final Map<String, int> groupLevels = {};
    final Queue<String> queue = Queue();
    groupLevels[rootGroup] = 0;
    queue.add(rootGroup);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final neighbor in groupAdj[current] ?? <String>{}) {
        if (!groupLevels.containsKey(neighbor)) {
          groupLevels[neighbor] = groupLevels[current]! + 1;
          queue.add(neighbor);
        }
      }
    }

    // 8. Disconnected groups placed in bottom row.
    final int maxGroupLevel =
        groupLevels.values.isEmpty ? 0 : groupLevels.values.reduce(max);
    for (final g in groupNodes.keys) {
      if (!groupLevels.containsKey(g)) {
        groupLevels[g] = maxGroupLevel + 1;
      }
    }

    // 5. Position groups per layer.
    final Map<int, List<String>> groupsByLevel = {};
    for (final entry in groupLevels.entries) {
      groupsByLevel.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    // Compute chunk widths to determine max layer width.
    double maxLayerWidth = 0;
    for (final groups in groupsByLevel.values) {
      double layerWidth = 0;
      for (final g in groups) {
        layerWidth += _GroupChunk(group: g, nodes: groupNodes[g]!).width;
      }
      if (groups.length > 1) layerWidth += (groups.length - 1) * 250.0;
      maxLayerWidth = max(maxLayerWidth, layerWidth);
    }
    maxLayerWidth = max(maxLayerWidth, viewportSize.width);

    final double contentCenterX =
        max(viewportSize.width / 2, maxLayerWidth / 2 + 200);

    // 6. Position nodes within each group.
    final Map<String, Offset> positions = {};
    final sortedLevels = groupsByLevel.keys.toList()..sort();

    for (final level in sortedLevels) {
      final groups = groupsByLevel[level]!;
      final double y = yStart + level * verticalSpacing;

      // Build chunks for this layer.
      final List<_GroupChunk> chunks = [];
      for (final g in groups) {
        chunks.add(_GroupChunk(group: g, nodes: groupNodes[g]!));
      }

      double totalWidth = 0;
      for (final chunk in chunks) {
        totalWidth += chunk.width;
      }
      if (chunks.length > 1) totalWidth += (chunks.length - 1) * 250.0;

      double cursorX = contentCenterX - totalWidth / 2;
      for (final chunk in chunks) {
        final chunkCenterX = cursorX + chunk.width / 2;
        final count = chunk.nodes.length;
        const double nodeSpacing = 180.0;
        final double nodesWidth = (count - 1) * nodeSpacing;
        final double nodeStartX = chunkCenterX - nodesWidth / 2;
        for (int i = 0; i < count; i++) {
          positions[chunk.nodes[i].id] = Offset(nodeStartX + i * nodeSpacing, y);
        }
        cursorX += chunk.width + 250.0;
      }
    }

    // 7. Compute group bounds.
    final Map<String, Rect> groupBounds = {};
    _computeGroupBounds(nodes, positions, groupBounds);

    // Compute content size — keep moderate margins to avoid
    // CanvasKit WASM memory limits on large canvases.
    double maxX = 0, maxY = 0;
    for (final offset in positions.values) {
      maxX = max(maxX, offset.dx);
      maxY = max(maxY, offset.dy);
    }
    final double contentWidth = max(maxX + 400, viewportSize.width * 1.5);
    final double contentHeight = max(maxY + 400, viewportSize.height * 1.5);

    return LayoutResult(
      positions: positions,
      groupBounds: groupBounds,
      contentSize: Size(contentWidth, contentHeight),
    );
  }

  // =========================================================================
  // Node-level BFS (enableGrouping = false, switch-level)
  // =========================================================================

  static LayoutResult _layoutNodeLevel(
    List<TopoNode> nodes,
    List<TopoConnection> connections,
    Size viewportSize,
  ) {
    const double verticalSpacing = 100.0;
    const double yStart = 60.0;

    // 1. Build adjacency list.
    final Map<String, Set<String>> adjacency = {};
    for (final node in nodes) {
      adjacency.putIfAbsent(node.id, () => {});
    }
    for (final conn in connections) {
      if (adjacency.containsKey(conn.fromId) &&
          adjacency.containsKey(conn.toId)) {
        adjacency[conn.fromId]!.add(conn.toId);
        adjacency[conn.toId]!.add(conn.fromId);
      }
    }

    // 2. Find root node.
    final String rootId = _findRoot(nodes, adjacency);

    // 3. BFS to assign levels.
    final Map<String, int> levels = {};
    final Queue<String> queue = Queue();
    levels[rootId] = 0;
    queue.add(rootId);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final neighbors = adjacency[current] ?? {};
      for (final neighbor in neighbors) {
        if (!levels.containsKey(neighbor)) {
          levels[neighbor] = levels[current]! + 1;
          queue.add(neighbor);
        }
      }
    }

    // Disconnected nodes get a level one beyond the deepest.
    final int maxLevel =
        levels.values.isEmpty ? 0 : levels.values.reduce(max);
    for (final node in nodes) {
      if (!levels.containsKey(node.id)) {
        levels[node.id] = maxLevel + 1;
      }
    }

    // 4. Group nodes by level.
    final Map<int, List<TopoNode>> byLevel = {};
    for (final node in nodes) {
      final level = levels[node.id]!;
      byLevel.putIfAbsent(level, () => []).add(node);
    }

    // Determine maximum layer width.
    double maxLayerWidth = 0;
    for (final entry in byLevel.entries) {
      final count = entry.value.length;
      if (count > 3) {
        maxLayerWidth = max(maxLayerWidth, (count - 1) * 500.0);
      } else {
        maxLayerWidth = max(maxLayerWidth, viewportSize.width);
      }
    }

    final double contentCenterX =
        max(viewportSize.width / 2, maxLayerWidth / 2 + 60);

    // 5. Calculate positions.
    final Map<String, Offset> positions = {};
    final sortedLevels = byLevel.keys.toList()..sort();

    for (final level in sortedLevels) {
      final layerNodes = byLevel[level]!;
      final count = layerNodes.length;
      final double y = yStart + level * verticalSpacing;

      double spacing;
      if (count > 3) {
        spacing = 500.0;
      } else {
        spacing = maxLayerWidth / (count + 1);
      }

      for (int j = 0; j < count; j++) {
        double x;
        if (count > 3) {
          final startX = contentCenterX - (count - 1) * spacing / 2;
          x = startX + j * spacing;
        } else {
          x = contentCenterX - maxLayerWidth / 2 + spacing * (j + 1);
        }
        positions[layerNodes[j].id] = Offset(x, y);
      }
    }

    // Compute content size.
    double maxX = 0, maxY = 0;
    for (final offset in positions.values) {
      maxX = max(maxX, offset.dx);
      maxY = max(maxY, offset.dy);
    }
    final double contentWidth = max(maxX + 200, viewportSize.width * 1.5);
    final double contentHeight = max(maxY + 200, viewportSize.height * 1.5);

    return LayoutResult(
      positions: positions,
      groupBounds: const {},
      contentSize: Size(contentWidth, contentHeight),
    );
  }

  // -------------------------------------------------------------------------
  // Root finding
  // -------------------------------------------------------------------------

  static String _findRoot(
      List<TopoNode> nodes, Map<String, Set<String>> adjacency) {
    // 1. Explicit isRoot flag.
    for (final node in nodes) {
      if (node.isRoot) return node.id;
    }
    // 2. Most-connected node.
    String? best;
    int bestCount = -1;
    for (final entry in adjacency.entries) {
      if (entry.value.length > bestCount) {
        bestCount = entry.value.length;
        best = entry.key;
      }
    }
    if (best != null) return best;
    // 3. First node.
    return nodes.first.id;
  }

  // -------------------------------------------------------------------------
  // Group bounds calculation
  // -------------------------------------------------------------------------

  static void _computeGroupBounds(
    List<TopoNode> nodes,
    Map<String, Offset> positions,
    Map<String, Rect> groupBounds,
  ) {
    final Map<String, List<Offset>> groupPositions = {};
    for (final node in nodes) {
      if (node.group != null && positions.containsKey(node.id)) {
        groupPositions
            .putIfAbsent(node.group!, () => [])
            .add(positions[node.id]!);
      }
    }

    for (final entry in groupPositions.entries) {
      final offsets = entry.value;
      if (offsets.isEmpty) continue;

      double minX = double.infinity;
      double maxX = -double.infinity;
      double minY = double.infinity;
      double maxY = -double.infinity;

      for (final o in offsets) {
        minX = min(minX, o.dx);
        maxX = max(maxX, o.dx);
        minY = min(minY, o.dy);
        maxY = max(maxY, o.dy);
      }

      // Expand bounds to form an ellipse around nodes.
      const double hPad = 120.0;
      const double vPad = 100.0;
      // For a single node, use a fixed minimum size.
      final double w = max((maxX - minX) + hPad * 2, 300.0);
      final double h = max((maxY - minY) + vPad * 2, 200.0);
      final double cx = (minX + maxX) / 2;
      final double cy = (minY + maxY) / 2;

      groupBounds[entry.key] = Rect.fromCenter(
        center: Offset(cx, cy),
        width: w,
        height: h,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Internal helper for grouping nodes in a layer.
// ---------------------------------------------------------------------------

class _GroupChunk {
  final String? group;
  final List<TopoNode> nodes;

  _GroupChunk({required this.group, required this.nodes});

  double get width {
    if (nodes.length == 1) return 300.0;
    return nodes.length * 180.0 + (nodes.length - 1) * 10 + 40;
  }
}
