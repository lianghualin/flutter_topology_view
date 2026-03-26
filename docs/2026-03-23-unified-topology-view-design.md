# Unified TopologyView Widget — Design Spec

**Date:** 2026-03-23
**Status:** Draft
**Goal:** Merge `network_topoview` and `onenetwork_topoview` into a single standalone `topology_view` package with one configurable widget.

---

## Motivation

The app currently has two separate local packages for topology visualization:

- `network_topoview` — renders multi-domain network topology (domains as ellipses, networks as cloud icons, animated flowing dots on connections)
- `onenetwork_topoview` — renders single-network switch topology (switches as SVG icons, status-colored connections with highlight animation)

Both share ~70% of their logic (BFS layout, InteractiveViewer pan/zoom, SVG caching, connection rendering, fit-to-view toggle) but are maintained as independent packages. This creates duplication and maintenance burden.

**Primary goal:** Consolidate into one package with a cleaner API.
**Secondary goal (future):** Enable a seamless drill-down experience (zoom from domain-level to switch-level in one view).

---

## Package Location

Standalone package alongside the main project:

```
/Users/hualinliang/Project/
├── lnm_frontend/              # consumer app
│   └── pubspec.yaml           # path: ../topology_view
└── topology_view/             # new standalone package
    ├── lib/
    │   ├── topology_view.dart # barrel export
    │   └── src/
    │       ├── topology_view_widget.dart
    │       ├── models/
    │       │   ├── topo_node.dart
    │       │   └── topo_connection.dart
    │       ├── layout/
    │       │   └── bfs_layout_engine.dart
    │       ├── layers/
    │       │   ├── group_layer.dart
    │       │   ├── connection_layer.dart
    │       │   └── node_layer.dart
    │       └── utils/
    │           └── svg_cache.dart
    ├── assets/images/          # all SVGs merged from both packages
    └── pubspec.yaml
```

This departs from the current convention where local packages live inside `dependencies/`. The rationale:
- The package is intended to be reusable and potentially publishable to pub.dev in the future
- A sibling directory keeps it independent from the app's git history and build
- It can be consumed by other projects if needed

Note: If keeping everything in one git repo is preferred, it can alternatively be placed at `dependencies/topology_view/` with `path: dependencies/topology_view` in pubspec.yaml. The user has confirmed the sibling-directory approach.

Referenced from `lnm_frontend/pubspec.yaml`:

```yaml
topology_view:
  path: ../topology_view
```

---

## Data Model

### TopoNode

Represents any node in the topology — a network cloud, a switch, or a custom device.

```dart
class TopoNode {
  final String id;                      // unique identifier
  final String label;                   // display name
  final String? iconAsset;              // SVG/PNG path for normal state
  final String? errorIconAsset;         // SVG/PNG path for abnormal state
  final bool isRoot;                    // root node for BFS layout
  final bool isAbnormal;               // triggers error icon + color
  final bool isExternal;               // external/non-internal node (rendered at 50% opacity)
  final String? group;                  // group ID — nodes sharing a group get an ellipse
  final Map<String, String>? hoverInfo; // key-value pairs shown on hover (e.g. {"IP": "10.0.0.1"})
  final String? tooltip;               // tooltip text
}
```

### TopoConnection

Represents a connection line between two nodes.

```dart
class TopoConnection {
  final String fromId;    // source node ID
  final String toId;      // target node ID
  final int status;       // 1 = normal (green), 0 = offline (grey), -1 = error (red)
  final bool isDashed;    // dashed line style (e.g. cross-domain links)
  final Color? lineColor; // override status-based color (e.g. dark grey for domain-level lines)
}
```

### Mapping from current models

**Domain-level (was `network_topoview`):**

| Old | New |
|-----|-----|
| `NetworkInfo.name` | `TopoNode.id` + `TopoNode.label` |
| `NetworkInfo.isAbnormal` | `TopoNode.isAbnormal` |
| Cloud SVG path | `TopoNode.iconAsset` / `TopoNode.errorIconAsset` |
| `DomainInfo.name` | `TopoNode.group` |
| `DomainInfo.isRoot` | At least one node in the root domain has `isRoot: true` |
| `NetworkConnection(from, to)` | `TopoConnection(fromId, toId, status: 1, lineColor: Color(0xFF313131))` — domain-level lines use dark grey override |

**Switch-level (was `onenetwork_topoview`):**

| Old | New |
|-----|-----|
| `SwitchInfo.label` | `TopoNode.id` + `TopoNode.label` |
| `SwitchInfo.status` | `TopoNode.isAbnormal` (status != 1) |
| `SwitchInfo.isRoot` | `TopoNode.isRoot` |
| `SwitchInfo.tooltip` | `TopoNode.tooltip` |
| `SwitchInfo.isInternal` | `TopoNode.isExternal` (inverted: `!isInternal`). Rendered at 50% opacity internally. |
| `SwitchInfo.switchIp` | `TopoNode.hoverInfo: {"IP": switchIp}` |
| Switch SVG path | `TopoNode.iconAsset` / `TopoNode.errorIconAsset` |
| `ConnectionInfo(from, to)` | `TopoConnection(fromId, toId, status, isDashed: isCrossDomainLink)` |

---

## Widget API

```dart
class TopologyView extends StatefulWidget {
  // --- Required ---
  final List<TopoNode> nodes;
  final List<TopoConnection> connections;

  // --- Callbacks ---
  final void Function(String nodeId)? onNodeTap;
  final VoidCallback? onResetView;    // called after resetView() completes

  // --- Modes ---
  final bool isConfigMode;            // forces all nodes to normal status (for config screens)

  // --- Grouping ---
  final bool enableGrouping;        // draw ellipses around nodes with same group

  // --- View controls ---
  final bool showFitViewButton;
  final bool isInFitView;           // start in fit-to-view mode

  // --- Node behavior ---
  final bool enableHoverAnimation;  // float-up effect on hover
  final bool showHoverInfo;         // show hoverInfo map on hover

  // --- Connection behavior ---
  final bool showFlowDots;          // animated flowing dots on lines
  final bool enableHighlight;       // bezier highlight animation on hover

  const TopologyView({
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
    this.showFlowDots = true,
    this.enableHighlight = true,
  });
}
```

### TopologyViewState (public API via GlobalKey)

```dart
class TopologyViewState extends State<TopologyView> {
  void toggleFitView();   // toggle between fit-to-view and original scale
  void resetView();       // reset to initial view, then calls onResetView callback
  bool get isInFitView;   // current fit-view state
}
```

Note: The existing packages use different names (`toggleView()` in `network_topoview` vs `toggleFitView()` in `onenetwork_topoview`). The unified API standardizes on `toggleFitView()`. Consumer code using `toggleView()` must be updated.

---

## Internal Architecture

### Rendering Stack

The widget renders as a `Stack` inside an `InteractiveViewer`, with three layers painted bottom-to-top:

```
TopologyView (StatefulWidget)
│
├── TopoLayoutEngine          — BFS root-finding, level calculation, position assignment
│                                Input: nodes + connections → Map<String, Offset>
│
├── InteractiveViewer         — pan/zoom, boundary margin, min/max scale
│
└── Rendering Stack:
    │
    ├── Layer 1: TopoGroupLayer        (if enableGrouping)
    │   - CustomPaint draws ellipses around nodes sharing same group ID
    │   - Ellipse size computed from child node positions
    │   - Group label painted above ellipse
    │   - Color: blue (normal) or red (any child isAbnormal)
    │
    ├── Layer 2: TopoConnectionLayer
    │   - CustomPaint draws all connection lines
    │   - **Line shape:**
    │     - Domain-level (when lineColor is set): smooth S-curve via cubic bezier
    │       (cubicTo with control points offset from midpoint), soft blue color
    │       (#5B8DEF, opacity 0.7), stroke width 2.5
    │     - Switch-level (status-based): straight lines with status coloring
    │       green (1), grey (0), red (-1), stroke width 3
    │   - Dashed pattern for isDashed connections
    │   - Animated flowing dots along lines (if showFlowDots)
    │     - Dots travel along the curve path (not straight line)
    │     - Bidirectional: dots flow both directions simultaneously
    │     - 2-3 dots per direction, phase-offset
    │     - Dot color: #165DFF, opacity fades near endpoints
    │   - Bezier curve highlight on hover (if enableHighlight)
    │     - Trigger: hovering a node highlights all its adjacent connections
    │     - Highlighted connections animate to curved bezier paths
    │   - Single AnimationController drives both effects
    │
    └── Layer 3: TopoNodeLayer
        - Stack of positioned widgets, one per node
        - Each node renders:
          - iconAsset SVG (or errorIconAsset if isAbnormal)
          - Label text below icon (cloud-mode labels should use smaller font
            or multi-line wrapping for names longer than 10 characters)
          - Opacity: 50% if node.isExternal, 100% otherwise
          - Hover: float-up animation (if enableHoverAnimation)
          - Hover: info panel with hoverInfo map (if showHoverInfo)
          - GestureDetector → onNodeTap(node.id)
```

### Layout Engine (BFS)

Unified from both existing implementations. **The layout algorithm differs based on `enableGrouping`:**

#### When `enableGrouping = true` (domain-level): Group-Level BFS

The engine must do BFS at the **group (domain) level** first, then position nodes within each group. This keeps same-group nodes together on the same row, matching the original `network_topoview` behavior.

1. **Collapse nodes into groups** — aggregate nodes by `TopoNode.group`. Each group becomes a single BFS vertex.
2. **Build group adjacency list** — a connection between two nodes in different groups creates a group-level edge.
3. **Find root group** — the group containing the node with `isRoot: true`.
4. **BFS on groups** — assign layer levels to groups (root group = level 0).
5. **Position groups per layer** — Y = 200 + groupLevel * 350px, X = centered distribution.
6. **Position nodes within each group** — nodes within the same group are laid out horizontally around the group center, with 180px spacing between nodes.
7. **Compute group bounds** — bounding ellipse from child node positions.
8. Disconnected groups placed in bottom row.

#### When `enableGrouping = false` (switch-level): Node-Level BFS

1. **Build adjacency list** from `connections`
2. **Find root node** — first node with `isRoot: true` (if multiple, use the first encountered). Fallback: most-connected node. Fallback: first node in list.
3. **BFS traversal** — assign layer levels (root = 0, neighbors = 1, etc.)
4. **Position calculation:**
   - Y = 60 + level * 100px
   - X = centered distribution within each level
   - For >3 nodes per level: fixed 500px horizontal spacing
   - For <=3 nodes per level: adaptive spacing based on available width
   - Disconnected nodes placed in bottom row

#### Spacing rules (internal, not exposed)

- When `enableGrouping = true` (domain-level): 350px vertical spacing between group rows, Y start at 200px. Groups contain their child nodes with ellipse boundaries.
- When `enableGrouping = false` (switch-level): 100px vertical spacing between node rows, Y start at 60px. Flat node layout.
- Horizontal spacing: 120px minimum, adaptive based on node count
- Margins: 60px top/bottom, 60px left/right

### SVG Cache & Rendering

Merged `SvgCacheManager` from both packages:
- In-memory cache for SVG strings and parsed Path objects
- `preloadAssets(List<String>)` — async preload
- `loadSvg(String path)` — lazy load with duplicate prevention
- `getPath(String svg)` — regex-based SVG path extraction
- `clearCache()` — cleanup on dispose
- Retry mechanism with exponential backoff (up to 3 retries)

`SvgClip` widget (StatefulWidget) renders SVG assets with:
- `PhysicalShape` clipper for elevation/shadow effects
- Cloud icons use clip scaling (`clipScale: 0.6, mX: 4, mY: 0`) — these parameters are baked into the node layer's rendering logic based on icon type
- Switch icons use standard `BoxFit.contain` rendering
- Error state with retry button on load failure
- Loading spinner placeholder during async load

---

## Consumer Migration

### Files to update in `lnm_frontend`

| File | Change |
|------|--------|
| `pubspec.yaml` | Remove `network_topoview` and `onenetwork_topoview` deps, add `topology_view: path: ../topology_view` |
| `features/monitoring/.../network_topology_view.dart` | Replace `network_topoview` imports. Map API response to `TopoNode`/`TopoConnection`. Use `TopologyView(enableGrouping: true, showFlowDots: true)` |
| `features/monitoring/.../onenetwork_draw.dart` | Replace `onenetwork_topoview` imports. Map API response to `TopoNode`/`TopoConnection`. Use `TopologyView(showHoverInfo: true, enableHighlight: true)` |
| `features/monitoring/.../hostdpu_legend_dialog.dart` | Update SVG asset paths from `packages/onenetwork_topoview/...` to `packages/topology_view/...` |
| `features/monitoring/.../onenet_legend_dialog.dart` | Update 4 SVG asset path references from `packages/onenetwork_topoview/...` to `packages/topology_view/...` (lines 327, 333, 349, 358) |

### After migration verified

- Delete `dependencies/network_topoview/`
- Delete `dependencies/onenetwork_topoview/`

---

## Assets

All SVG assets merged into `topology_view/assets/images/`:

| Source | Asset | Purpose |
|--------|-------|---------|
| `network_topoview` | `network_cloud_normal.svg` | Normal network cloud icon |
| `network_topoview` | `network_cloud_abnormal.svg` | Abnormal network cloud icon |
| `onenetwork_topoview` | `switch_float.svg` | Normal switch icon |
| `onenetwork_topoview` | `switch_float_err.svg` | Error switch icon |

---

## Dependencies

```yaml
# topology_view/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_svg: ^2.0.9
  path_drawing: ^1.0.0
```

Same dependencies as the existing packages — no new dependencies introduced.

---

## Future Consideration: Drill-Down Experience

The composition-based architecture is designed to support a future enhancement where the user can tap a domain-level node and seamlessly zoom into the switch-level detail within the same widget. This would involve:

- Nested `TopoNode` support (nodes containing child nodes)
- Zoom-triggered level-of-detail rendering
- Animated transition between levels

This is explicitly **out of scope** for the initial merge but the architecture does not prevent it.

---

## Intentionally Omitted Parameters

These parameters exist in the current packages but are dropped in the unified widget:

| Parameter | Source | Reason |
|-----------|--------|--------|
| `showlegend` | `network_topoview` | Unused by consumers. Legend display is handled by the consumer page, not the topology widget. |
| `showrefresh` | `network_topoview` | Unused by consumers. Refresh controls belong to the consumer page. |
| `showresize` | `network_topoview` | Unused by consumers. |
| `isColorful` | `onenetwork_topoview` | Present in widget API but unused in current code. |
| `disableIntraDomainConnections` | `onenetwork_topoview` | Present in widget API but unused in current code. |
| `connectedPortNum` | `onenetwork_topoview` | Computed internally from connection data during layout. Not needed as input — the layout engine derives it. |

---

## Post-Implementation Fixes (2026-03-23)

Issues discovered during initial visual testing of the example app:

### Fix 1: Layout engine — group-level BFS (Critical)

**Problem:** When `enableGrouping = true`, the current BFS operates on individual nodes. Nodes in the same group (domain) can land at different BFS levels, causing the group ellipse to stretch across the entire canvas vertically.

**Fix:** When `enableGrouping = true`, perform BFS at the group level first (collapse nodes into groups → BFS on groups → position groups → position nodes within groups). See updated "Layout Engine" section above.

### Fix 2: Connection lines — straight to S-curve (Visual)

**Problem:** Domain-level connections use plain straight dark grey lines that look stiff and basic.

**Fix:** Replace straight `lineTo` with a smooth cubic bezier (`cubicTo`) S-curve for connections that have a `lineColor` override (domain-level). The curve uses two control points offset from the midpoint to create a natural S-shape. Line color: soft blue `#5B8DEF` at 0.7 opacity, stroke width 2.5. Flow dots travel along the curved path bidirectionally (dots in both directions simultaneously).

Switch-level connections (status-based, no `lineColor` override) remain as straight lines with status coloring.

### Fix 3: Cloud-mode label truncation (Visual)

**Problem:** Long network names like "East-Production" get truncated to "East-Pr" because the cloud node size (100px) is too small for the label area.

**Fix:** Cloud-mode labels should use smaller font size for long names, or apply the existing multi-line wrapping logic (split at separators like `-`, `:`, `_`) more aggressively. The label width should allow at least the split result to display fully.

---

## Out of Scope

- Force-directed layout (only BFS hierarchical layout)
- Drill-down / nested zoom (future consideration)
- Publishing to pub.dev
- Unit tests for the new package (can be added incrementally)
