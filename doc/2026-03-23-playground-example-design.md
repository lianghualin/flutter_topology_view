# TopologyView Playground Example — Design Spec

**Date:** 2026-03-23
**Status:** Approved
**Goal:** Replace the current two-tab example app with an interactive playground that exposes all configurable parameters of the TopologyView widget.

---

## Overview

A developer-focused playground for testing TopologyView parameter combinations. Fixed left sidebar with controls, main area shows the live TopologyView. Single-file implementation in `example/lib/main.dart`.

---

## Layout

Fixed left sidebar (280px width) + main TopologyView area filling remaining space.

```
┌──────────────────┬──────────────────────────────────┐
│   Left Sidebar   │                                  │
│   (280px fixed)  │      TopologyView                │
│                  │      (fills remaining space)      │
│  - Presets       │                                  │
│  - Widget Config │      (or placeholder message     │
│  - Data Info     │       when data is empty)        │
│  - Data Tweaks   │                                  │
│                  │                                  │
└──────────────────┴──────────────────────────────────┘
```

The sidebar is scrollable if content exceeds viewport height. When data is empty, the main area shows a centered placeholder: "No topology data — use presets or add nodes".

---

## Sidebar Sections

### 1. Data Presets

Three buttons that load pre-built datasets and auto-configure widget toggles.

| Preset | Nodes | Connections | Auto-config |
|--------|-------|-------------|-------------|
| **Domain** | 5 network clouds in 3 domains (with `iconAsset: 'assets/images/network_cloud_normal.svg'`, `errorIconAsset: 'assets/images/network_cloud_abnormal.svg'`) | 3 cross-domain connections (with `lineColor: Color(0xFF5B8DEF)`) | `enableGrouping: true`, `showFlowDots: true`, `enableHighlight: false`, `showHoverInfo: false`, `enableHoverAnimation: true` |
| **Switch** | 7 switches (1 core, 2 agg, 3 access, 1 external) with `iconAsset: 'assets/images/switch_float.svg'`, `errorIconAsset: 'assets/images/switch_float_err.svg'`. Include `hoverInfo` (e.g. `{"IP": "10.0.x.x"}`) and `tooltip` on each node. | 6 connections: 3 normal (`status: 1`), 1 error (`status: -1`), 1 offline (`status: 0`), 1 dashed cross-domain (`isDashed: true`) | `enableGrouping: false`, `showFlowDots: false`, `enableHighlight: true`, `showHoverInfo: true`, `enableHoverAnimation: true` |
| **Empty** | 0 nodes | 0 connections | All toggles off |

Active preset is visually highlighted. Selecting a preset replaces all data, resets widget config to the preset's defaults, and resets the viewport via `GlobalKey<TopologyViewState>.currentState?.resetView()`.

### 2. Widget Config

Seven `Switch` toggles plus one action button. Each toggle calls `setState` to update the widget immediately.

| Control | Type | Default (Domain) | Default (Switch) |
|---------|------|-------------------|-------------------|
| `enableGrouping` | Switch toggle | on | off |
| `showFlowDots` | Switch toggle | on | off |
| `enableHighlight` | Switch toggle | off | on |
| `showHoverInfo` | Switch toggle | off | on |
| `enableHoverAnimation` | Switch toggle | on | on |
| `showFitViewButton` | Switch toggle | on | on |
| `isConfigMode` | Switch toggle | off | off |
| **Fit View** | `IconButton` | — | — |

**`isInFitView` is NOT a simple toggle** — the widget manages fit-view state internally. Instead, the playground exposes a "Fit View" action button that calls `_topoViewKey.currentState?.toggleFitView()` via a `GlobalKey<TopologyViewState>`.

Toggles can be freely changed after a preset is loaded — the preset just sets initial values.

### 3. Data Info (read-only)

Live counters reflecting current data state:

- **Nodes** — total count
- **Connections** — total count
- **Groups** — number of distinct groups (0 if no grouping)
- **Abnormal** — count of nodes with `isAbnormal: true`
- **External** — count of nodes with `isExternal: true`
- **Last tapped** — ID of last node tapped via `onNodeTap` callback (initially "—")

Updates automatically when data changes via tweaks or callbacks.

### 4. Data Tweaks

Buttons to mutate data on the fly:

| Button | Action |
|--------|--------|
| **+ Add node** | Appends a node with random ID, label, and icon (cloud if Domain preset active, switch if Switch). If topology is empty, adds as standalone root node with no connection. Otherwise connects it to a random existing node. |
| **+ Add connection** | Picks two nodes that aren't already connected and adds a connection. **Disabled** when no unconnected pairs remain. |
| **Toggle abnormal** | Picks a random node, creates a new `TopoNode` copy with `isAbnormal` flipped (since `TopoNode` is immutable — all fields are `final`), and replaces it in a new list. |
| **Toggle external** | Same pattern — copies the node with `isExternal` flipped. |
| **Reset** | Reloads the currently active preset's data and config. Also resets the viewport via `GlobalKey<TopologyViewState>.currentState?.resetView()`. |

All mutations create new `List<TopoNode>` / `List<TopoConnection>` instances (required for `didUpdateWidget` to detect changes) and call `setState`.

---

## State Management

Single `StatefulWidget` with state variables:

```dart
// GlobalKey for public API access (toggleFitView, resetView)
final GlobalKey<TopologyViewState> _topoViewKey = GlobalKey();

// Active preset
String _activePreset = 'domain';

// Widget config (7 booleans — isInFitView managed via GlobalKey)
bool _enableGrouping = true;
bool _showFlowDots = true;
bool _enableHighlight = false;
bool _showHoverInfo = false;
bool _enableHoverAnimation = true;
bool _showFitViewButton = true;
bool _isConfigMode = false;

// Data
List<TopoNode> _nodes = [];
List<TopoConnection> _connections = [];

// Callback state
String _lastTappedNodeId = '—';
```

**Callbacks wired to TopologyView:**
- `onNodeTap: (id) => setState(() => _lastTappedNodeId = id)` — displays in Data Info section
- `onResetView: () => debugPrint('onResetView fired')` — logged to console for developer visibility

No Provider, no external state management. This is an example app — simplicity is the point.

---

## File Structure

Single file: `example/lib/main.dart`

Contains:
- `TopologyViewExampleApp` — MaterialApp wrapper
- `PlaygroundPage` — the main StatefulWidget with sidebar + TopologyView
- `_buildPresetData(String preset)` — returns (nodes, connections) for each preset
- `_presetDefaults(String preset)` — returns widget config defaults for each preset

No additional files needed. The `example/pubspec.yaml` already references the parent `topology_view` package.

---

## Visual Style

- Material 3 with `ColorScheme.fromSeed(seedColor: Colors.blue)`
- Sidebar background: `ColorScheme.surfaceContainerLow`
- Section headers: bold, small, uppercase label style
- Toggle labels: monospace font to match code parameter names
- Preset buttons: `ChoiceChip` or `FilterChip` style
- Data tweak buttons: `OutlinedButton.icon` with small icons
- Data info: simple `Text` rows with label + count

---

## Interaction Flow

1. App launches → Domain preset loaded → TopologyView renders with 5 clouds in 3 domains
2. User flips toggles → TopologyView updates instantly
3. User clicks "Fit View" button → calls `toggleFitView()` via GlobalKey
4. User clicks "Switch" preset → data, config, and viewport reset, TopologyView re-renders
5. User clicks "+ Add node" → new node appears in topology
6. User taps a node → "Last tapped" updates in Data Info
7. User clicks "Toggle abnormal" → random node turns red
8. User clicks "Reset" → back to clean preset state + viewport reset

---

## Out of Scope

- Editing individual node properties (name, icon, group)
- Drag-and-drop node placement
- Persisting configuration
- Responsive / mobile layout (web-first)
- Keyboard shortcuts / accessibility
