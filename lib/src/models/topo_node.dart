import 'package:topology_view_icons/topology_view_icons.dart';

/// Represents any node in the topology — a network cloud, a switch, or a custom device.
class TopoNode {
  /// Unique identifier for this node.
  final String id;

  /// Display name shown below the node icon.
  final String label;

  /// SVG/PNG asset path for the normal state icon.
  /// Ignored when [deviceType] is set.
  final String? iconAsset;

  /// SVG/PNG asset path for the abnormal/error state icon.
  /// Ignored when [deviceType] is set.
  final String? errorIconAsset;

  /// Device type for painted icons from `topology_view_icons`.
  /// When set, the node uses [TopoIconPainter] instead of SVG assets.
  final TopoDeviceType? deviceType;

  /// Icon style when using [deviceType]. Defaults to [TopoIconStyle.lnm].
  final TopoIconStyle iconStyle;

  /// Whether this node is the root for BFS layout.
  final bool isRoot;

  /// Whether this node is in an abnormal/error state.
  /// Triggers [errorIconAsset] / error icon color and error color in groups.
  final bool isAbnormal;

  /// Whether this node is external (non-internal).
  /// External nodes are rendered at 50% opacity.
  final bool isExternal;

  /// Group ID — nodes sharing the same group get an enclosing ellipse
  /// when [TopologyView.enableGrouping] is true.
  final String? group;

  /// Key-value pairs shown on hover (e.g. {"IP": "10.0.0.1"}).
  final Map<String, String>? hoverInfo;

  /// Tooltip text for this node.
  final String? tooltip;

  const TopoNode({
    required this.id,
    required this.label,
    this.iconAsset,
    this.errorIconAsset,
    this.deviceType,
    this.iconStyle = TopoIconStyle.lnm,
    this.isRoot = false,
    this.isAbnormal = false,
    this.isExternal = false,
    this.group,
    this.hoverInfo,
    this.tooltip,
  });
}
