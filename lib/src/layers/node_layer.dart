import 'package:flutter/material.dart';
import 'package:topology_view_icons/topology_view_icons.dart';

import '../models/topo_node.dart';
import '../utils/svg_cache.dart';

/// Layer 3 (top): Renders all nodes as positioned widgets in a [Stack].
///
/// Each node displays:
/// - SVG icon (normal or error based on [TopoNode.isAbnormal])
/// - Label text below the icon
/// - 50% opacity if [TopoNode.isExternal]
/// - Hover float-up animation (if [enableHoverAnimation])
/// - Hover info panel with [TopoNode.hoverInfo] (if [showHoverInfo])
/// - Tap → [onNodeTap]
class TopoNodeLayer extends StatelessWidget {
  final List<TopoNode> nodes;
  final Map<String, Offset> positions;
  final void Function(String nodeId)? onNodeTap;
  final bool enableHoverAnimation;
  final bool showHoverInfo;
  final bool showAllInfo;
  final bool isConfigMode;

  /// Whether nodes use cloud-style SVG clipping (for domain-level).
  final bool useCloudClip;

  /// Callback to notify parent when a node is hovered (for connection highlight).
  final void Function(String? nodeId)? onNodeHover;

  const TopoNodeLayer({
    super.key,
    required this.nodes,
    required this.positions,
    this.onNodeTap,
    this.enableHoverAnimation = true,
    this.showHoverInfo = false,
    this.showAllInfo = false,
    this.isConfigMode = false,
    this.useCloudClip = false,
    this.onNodeHover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final node in nodes)
          if (positions.containsKey(node.id))
            _NodeWidget(
              node: node,
              position: positions[node.id]!,
              onTap: onNodeTap,
              enableHoverAnimation: enableHoverAnimation,
              showHoverInfo: showHoverInfo,
              showAllInfo: showAllInfo,
              isConfigMode: isConfigMode,
              useCloudClip: useCloudClip,
              onHover: onNodeHover,
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual node widget with hover animation.
// ---------------------------------------------------------------------------

class _NodeWidget extends StatefulWidget {
  final TopoNode node;
  final Offset position;
  final void Function(String nodeId)? onTap;
  final bool enableHoverAnimation;
  final bool showHoverInfo;
  final bool showAllInfo;
  final bool isConfigMode;
  final bool useCloudClip;
  final void Function(String? nodeId)? onHover;

  const _NodeWidget({
    required this.node,
    required this.position,
    this.onTap,
    required this.enableHoverAnimation,
    required this.showHoverInfo,
    required this.showAllInfo,
    required this.isConfigMode,
    required this.useCloudClip,
    this.onHover,
  });

  @override
  State<_NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<_NodeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _nodeSize => widget.useCloudClip ? 100.0 : 80.0;

  bool get _isAbnormal =>
      widget.isConfigMode ? false : widget.node.isAbnormal;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double hoverOffset =
            widget.enableHoverAnimation ? _controller.value * 2 : 0.0;

        final double size = _nodeSize;
        final double outerWidth = size < 120 ? 120.0 : size;

        Widget inner = MouseRegion(
          onEnter: widget.enableHoverAnimation
              ? (_) {
                  _controller.forward();
                  widget.onHover?.call(widget.node.id);
                }
              : (_) {
                  widget.onHover?.call(widget.node.id);
                },
          onExit: widget.enableHoverAnimation
              ? (_) {
                  _controller.reverse();
                  widget.onHover?.call(null);
                }
              : (_) {
                  widget.onHover?.call(null);
                },
          child: GestureDetector(
            onTap: () => widget.onTap?.call(widget.node.id),
            child: SizedBox(
              width: outerWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  _buildIcon(size),
                  // Name + hover info unified panel, pulled closer to icon.
                  Transform.translate(
                    offset: Offset(0, widget.useCloudClip ? -30 : -20),
                    child: _buildInfoPanel(size),
                  ),
                ],
              ),
            ),
          ),
        );

        // External nodes at 50% opacity — applied inside Positioned.
        if (widget.node.isExternal) {
          inner = Opacity(opacity: 0.5, child: inner);
        }

        return Positioned(
          left: widget.position.dx - outerWidth / 2,
          top: widget.position.dy - size / 2 - hoverOffset,
          child: inner,
        );
      },
    );
  }

  Widget _buildIcon(double size) {
    // Priority: deviceType (painted icon) > iconAsset (SVG) > fallback circle.
    final deviceType = widget.node.deviceType;
    if (deviceType != null) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: TopoIconPainter(
            deviceType: deviceType,
            isError: _isAbnormal,
            style: widget.node.iconStyle,
          ),
        ),
      );
    }

    final String? assetPath =
        _isAbnormal ? widget.node.errorIconAsset : widget.node.iconAsset;

    if (assetPath == null) {
      // Fallback: simple colored circle.
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isAbnormal ? Colors.red[100] : Colors.blue[100],
          border: Border.all(
            color: _isAbnormal ? Colors.red : Colors.blueAccent,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            widget.node.label.isNotEmpty ? widget.node.label[0] : '?',
            style: TextStyle(
              fontSize: size * 0.35,
              fontWeight: FontWeight.bold,
              color: _isAbnormal ? Colors.red : Colors.blueAccent,
            ),
          ),
        ),
      );
    }

    final double elevation = widget.enableHoverAnimation
        ? (2 + _controller.value * 5)
        : 2.0;

    if (widget.useCloudClip) {
      return SizedBox(
        width: size,
        height: size,
        child: SvgClip(
          path: assetPath,
          clipScale: 0.6,
          mX: 4,
          mY: 0,
          elevation: elevation,
          width: 200,
          height: 200,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: SvgClip(
        path: assetPath,
        elevation: elevation,
        width: 200,
        height: 200,
      ),
    );
  }

  /// Unified info panel: name always visible, hover info expands below on hover.
  /// Transparent when idle, semi-transparent frosted white when hovered.
  Widget _buildInfoPanel(double size) {
    final String label = widget.node.label;
    final bool isExpanded = widget.showAllInfo || _controller.value > 0;
    final double t = widget.showAllInfo ? 1.0 : _controller.value;

    double fontSize;
    double panelWidth;
    if (widget.useCloudClip) {
      fontSize = label.length > 14 ? 9.0 : (label.length > 10 ? 10.0 : 12.0);
      panelWidth = 140;
    } else {
      fontSize = 11.0;
      panelWidth = 120;
    }

    final String text = _formatLabel(label);
    final hoverInfo = widget.node.hoverInfo;
    final bool hasHoverInfo =
        widget.showHoverInfo && hoverInfo != null && hoverInfo.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: BoxConstraints(maxWidth: panelWidth),
      padding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: isExpanded ? 6 : 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isExpanded ? 0.75 : 0.45),
        borderRadius: BorderRadius.circular(6),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name — always visible.
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.black,
              fontWeight: t > 0.5 ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Hover info — expands below name on hover.
          if (hasHoverInfo)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: SizedBox(
                height: isExpanded ? null : 0,
                child: isExpanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final entry in hoverInfo.entries)
                              Text(
                                '${entry.key}: ${entry.value}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Colors.black87.withValues(alpha: t),
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  /// Intelligent label wrapping — splits long labels at separators.
  String _formatLabel(String label) {
    if (label.length <= 10) return label;

    // Try splitting at common separators.
    for (final sep in ['-', ':', '_', ' ']) {
      final idx = label.indexOf(sep, label.length ~/ 5);
      if (idx > 0 && idx < label.length - 1) {
        return '${label.substring(0, idx + 1)}\n${label.substring(idx + 1)}';
      }
    }

    // Split at middle.
    final mid = label.length ~/ 2;
    return '${label.substring(0, mid)}\n${label.substring(mid)}';
  }
}
