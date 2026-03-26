import 'dart:math';

import 'package:flutter/material.dart';

import 'models/topo_node.dart';
import 'models/topo_connection.dart';
import 'layout/bfs_layout_engine.dart';
import 'layers/group_layer.dart';
import 'layers/connection_layer.dart';
import 'layers/node_layer.dart';
import 'utils/svg_cache.dart';

/// A configurable topology visualization widget.
///
/// Renders a hierarchical node-and-connection graph using BFS layout.
/// Supports two main modes:
/// - **Domain-level** (`enableGrouping: true, showFlowDots: true`): networks
///   grouped inside domain ellipses with animated flowing dots on connections.
/// - **Switch-level** (`showHoverInfo: true, enableHighlight: true`): flat
///   switch topology with hover info and bezier highlight animation.
class TopologyView extends StatefulWidget {
  // --- Required ---
  final List<TopoNode> nodes;
  final List<TopoConnection> connections;

  // --- Callbacks ---
  final void Function(String nodeId)? onNodeTap;
  final VoidCallback? onResetView;

  // --- Modes ---
  /// Forces all nodes to normal status (for config screens).
  final bool isConfigMode;

  // --- Grouping ---
  /// Draw ellipses around nodes that share the same [TopoNode.group].
  final bool enableGrouping;

  // --- View controls ---
  /// Show the fit-to-view floating action button.
  final bool showFitViewButton;

  /// Start in fit-to-view mode.
  final bool isInFitView;

  // --- Node behavior ---
  /// Float-up effect on hover.
  final bool enableHoverAnimation;

  /// Show [TopoNode.hoverInfo] map on hover.
  final bool showHoverInfo;

  /// Show all node info panels expanded (no hover required).
  final bool showAllInfo;

  // --- Connection behavior ---
  /// Animated flowing dots along connection lines.
  final bool showFlowDots;

  /// Bezier highlight animation on hover.
  final bool enableHighlight;

  const TopologyView({
    super.key,
    required this.nodes,
    required this.connections,
    this.onNodeTap,
    this.onResetView,
    this.isConfigMode = false,
    this.enableGrouping = false,
    this.showFitViewButton = true,
    this.isInFitView = false,
    this.enableHoverAnimation = true,
    this.showHoverInfo = false,
    this.showAllInfo = false,
    this.showFlowDots = true,
    this.enableHighlight = true,
  });

  @override
  State<TopologyView> createState() => TopologyViewState();
}

class TopologyViewState extends State<TopologyView> {
  final TransformationController _transformationController =
      TransformationController();

  bool _isInFitView = false;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  double _originalScale = 1.0;
  Offset _originalOffset = Offset.zero;
  bool _hasInitialFitViewBeenCalled = false;
  bool _isDisposed = false;

  // Layout state.
  LayoutResult? _layoutResult;
  List<ResolvedConnection> _resolvedConnections = [];

  // Hover tracking for connection highlight.
  String? _hoveredNodeId;

  static const double _minScale = 0.1;
  static const double _maxScale = 1.5;

  @override
  void initState() {
    super.initState();
    _isInFitView = widget.isInFitView;
    _preloadSvgAssets();
  }

  @override
  void didUpdateWidget(TopologyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-layout when data changes.
    if (oldWidget.nodes != widget.nodes ||
        oldWidget.connections != widget.connections ||
        oldWidget.enableGrouping != widget.enableGrouping) {
      _layoutResult = null;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _transformationController.dispose();
    SvgCacheManager.clearCache();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Public API (accessible via GlobalKey<TopologyViewState>).
  // -----------------------------------------------------------------------

  /// Toggle between fit-to-view and original scale.
  void toggleFitView() {
    if (_isInFitView) {
      _restoreOriginalView();
    } else {
      _fitToView();
    }
  }

  /// Reset to initial view, then call [TopologyView.onResetView].
  void resetView() {
    _transformationController.value = Matrix4.identity();
    _scale = 1.0;
    _offset = Offset.zero;
    setState(() {
      _isInFitView = false;
    });
    widget.onResetView?.call();
  }

  /// Current fit-view state.
  bool get isInFitView => _isInFitView;

  // -----------------------------------------------------------------------
  // SVG preloading
  // -----------------------------------------------------------------------

  void _preloadSvgAssets() async {
    final Set<String> paths = {};
    for (final node in widget.nodes) {
      if (node.iconAsset != null) {
        paths.add('packages/flutter_topology_view/${node.iconAsset}');
      }
      if (node.errorIconAsset != null) {
        paths.add('packages/flutter_topology_view/${node.errorIconAsset}');
      }
    }
    if (paths.isNotEmpty) {
      try {
        await SvgCacheManager.preloadAssets(paths.toList());
      } catch (e) {
        debugPrint('Error preloading SVG assets: $e');
      }
    }
  }

  // -----------------------------------------------------------------------
  // Layout
  // -----------------------------------------------------------------------

  void _ensureLayout(Size viewportSize) {
    if (_layoutResult != null) return;
    if (widget.nodes.isEmpty) return;

    _layoutResult = BfsLayoutEngine.layout(
      nodes: widget.nodes,
      connections: widget.connections,
      enableGrouping: widget.enableGrouping,
      viewportSize: viewportSize,
    );

    // Resolve connections to pixel positions.
    _resolvedConnections = widget.connections
        .where((c) =>
            _layoutResult!.positions.containsKey(c.fromId) &&
            _layoutResult!.positions.containsKey(c.toId))
        .map((c) => ResolvedConnection.from(c, _layoutResult!.positions))
        .toList();

    // Initial fit-to-view if requested.
    if (widget.isInFitView && !_hasInitialFitViewBeenCalled) {
      _hasInitialFitViewBeenCalled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _fitToView();
        }
      });
    }
  }

  // -----------------------------------------------------------------------
  // Fit-to-view
  // -----------------------------------------------------------------------

  void _fitToView() {
    final layout = _layoutResult;
    if (layout == null || layout.positions.isEmpty) return;

    if (!_isInFitView) {
      _originalScale = _scale;
      _originalOffset = _offset;
    }

    // Calculate bounds of all positioned elements.
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final offset in layout.positions.values) {
      minX = min(minX, offset.dx);
      minY = min(minY, offset.dy);
      maxX = max(maxX, offset.dx);
      maxY = max(maxY, offset.dy);
    }

    for (final conn in _resolvedConnections) {
      for (final o in [conn.source, conn.target]) {
        minX = min(minX, o.dx);
        minY = min(minY, o.dy);
        maxX = max(maxX, o.dx);
        maxY = max(maxY, o.dy);
      }
    }

    if (minX.isInfinite) return;

    const double margin = 100.0;
    final contentBounds = Rect.fromLTRB(
      minX - margin,
      minY - margin,
      maxX + margin,
      maxY + margin,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;
      try {
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) return;

        final viewportSize = renderBox.size;
        if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

        final double scaleX = viewportSize.width / contentBounds.width;
        final double scaleY = viewportSize.height / contentBounds.height;
        final double baseScale = min(scaleX, scaleY) * 0.9; // 10% padding

        final double cx = contentBounds.left + contentBounds.width / 2;
        final double cy = contentBounds.top + contentBounds.height / 2;
        final double vx = viewportSize.width / 2;
        final double vy = viewportSize.height / 2;

        final double offsetX = vx - cx * baseScale;
        final double offsetY = vy - cy * baseScale;

        if (mounted && !_isDisposed) {
          final matrix = Matrix4.identity()
            ..translateByDouble(offsetX, offsetY, 0, 1)
            ..scaleByDouble(baseScale, baseScale, 1, 1);

          _transformationController.value = matrix;
          _scale = baseScale.clamp(_minScale, _maxScale);
          _offset = Offset(offsetX, offsetY);

          setState(() {
            _isInFitView = true;
          });
        }
      } catch (e) {
        debugPrint('Fit view error: $e');
      }
    });
  }

  void _restoreOriginalView() {
    final matrix = Matrix4.identity()
      ..translateByDouble(_originalOffset.dx, _originalOffset.dy, 0, 1)
      ..scaleByDouble(_originalScale, _originalScale, 1, 1);

    _transformationController.value = matrix;
    _scale = _originalScale;
    _offset = _originalOffset;
    setState(() {
      _isInFitView = false;
    });
  }

  // -----------------------------------------------------------------------
  // Hover highlight
  // -----------------------------------------------------------------------

  void _onNodeHover(String? nodeId) {
    if (nodeId == _hoveredNodeId) return;
    setState(() {
      _hoveredNodeId = nodeId;
      final positions = _layoutResult?.positions;
      for (final conn in _resolvedConnections) {
        if (nodeId == null || positions == null) {
          conn.isHighlighted = false;
          continue;
        }
        // A connection is highlighted when the hovered node is one of its endpoints.
        conn.isHighlighted = widget.connections.any((c) =>
            (c.fromId == nodeId || c.toId == nodeId) &&
            positions[c.fromId] == conn.source &&
            positions[c.toId] == conn.target);
      }
    });
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureLayout(viewportSize);

        final layout = _layoutResult;
        if (layout == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(500),
              minScale: _minScale,
              maxScale: _maxScale,
              panEnabled: true,
              scaleEnabled: true,
              onInteractionEnd: (details) {
                final matrix = _transformationController.value;
                _scale = matrix.getMaxScaleOnAxis();
                _offset = Offset(
                  matrix.getTranslation().x,
                  matrix.getTranslation().y,
                );
                if (_isInFitView) {
                  setState(() {
                    _isInFitView = false;
                  });
                }
              },
              child: SizedBox(
                width: layout.contentSize.width > 0
                    ? layout.contentSize.width
                    : 1000,
                height: layout.contentSize.height > 0
                    ? layout.contentSize.height
                    : 1000,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Layer 1: Group ellipses (if enabled).
                    if (widget.enableGrouping && layout.groupBounds.isNotEmpty)
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: TopoGroupLayer(
                            groupBounds: layout.groupBounds,
                            nodes: widget.nodes,
                          ),
                        ),
                      ),

                    // Layer 2: Connection lines (animates — isolated
                    // via RepaintBoundary so repaints don't cascade).
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: TopoConnectionLayer(
                          connections: _resolvedConnections,
                          showFlowDots: widget.showFlowDots,
                          enableHighlight: widget.enableHighlight,
                        ),
                      ),
                    ),

                    // Layer 3: Node widgets (isolated so icon
                    // CustomPainters don't re-rasterize with connections).
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: TopoNodeLayer(
                          nodes: widget.nodes,
                          positions: layout.positions,
                          onNodeTap: widget.onNodeTap,
                          enableHoverAnimation: widget.enableHoverAnimation,
                          showHoverInfo: widget.showHoverInfo,
                          showAllInfo: widget.showAllInfo,
                          isConfigMode: widget.isConfigMode,
                          useCloudClip: widget.enableGrouping,
                          onNodeHover: widget.enableHighlight
                              ? _onNodeHover
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Fit-to-view button.
            if (widget.showFitViewButton)
              Positioned(
                top: 8,
                right: 8,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: toggleFitView,
                  tooltip: _isInFitView ? 'Original view' : 'Fit to view',
                  child: Icon(
                    _isInFitView ? Icons.zoom_out_map : Icons.fit_screen,
                    size: 20,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
