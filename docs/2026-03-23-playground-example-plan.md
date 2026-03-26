# TopologyView Playground Example — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current two-tab example app with an interactive playground exposing all TopologyView parameters.

**Architecture:** Single-file Flutter app (`example/lib/main.dart`). Fixed left sidebar (280px) with preset buttons, toggle switches, data info, and data tweak buttons. Main area renders the live `TopologyView`. All state managed in one `StatefulWidget` with `setState`.

**Tech Stack:** Flutter (web), `topology_view` package (local dependency)

**Spec:** `docs/2026-03-23-playground-example-design.md`

---

### Task 1: Scaffold the playground layout

**Files:**
- Rewrite: `example/lib/main.dart`

- [ ] **Step 1: Replace main.dart with the playground skeleton**

Replace the entire file with the app shell: `MaterialApp` → `PlaygroundPage` (StatefulWidget) → `Row` with fixed-width sidebar + `Expanded` main area. No TopologyView yet — just the layout with placeholder containers.

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:topology_view/topology_view.dart';

void main() {
  runApp(const TopologyViewExampleApp());
}

class TopologyViewExampleApp extends StatelessWidget {
  const TopologyViewExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TopologyView Playground',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PlaygroundPage(),
    );
  }
}

class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  // GlobalKey for public API access
  final GlobalKey<TopologyViewState> _topoViewKey = GlobalKey();

  // Active preset
  String _activePreset = 'domain';

  // Widget config
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

  @override
  void initState() {
    super.initState();
    _loadPreset('domain');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TopologyView Playground')),
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: 280,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const Center(child: Text('Sidebar placeholder')),
            ),
          ),
          // Main area
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(child: Text('TopologyView placeholder')),
            ),
          ),
        ],
      ),
    );
  }

  void _loadPreset(String preset) {
    // TODO: implement in Task 2
  }
}
```

- [ ] **Step 2: Verify it runs**

Run: `cd /Users/hualinliang/Project/topology_view/example && flutter run -d chrome`
Expected: App shows with a left sidebar placeholder and main area placeholder.

- [ ] **Step 3: Commit**

```bash
cd /Users/hualinliang/Project/topology_view
git add example/lib/main.dart
git commit -m "feat(example): scaffold playground layout"
```

---

### Task 2: Implement preset data and config loading

**Files:**
- Modify: `example/lib/main.dart`

- [ ] **Step 1: Add `_loadPreset` and `_buildPresetData` methods**

Add these methods to `_PlaygroundPageState`:

```dart
void _loadPreset(String preset) {
  final (nodes, connections) = _buildPresetData(preset);
  final defaults = _presetDefaults(preset);
  setState(() {
    _activePreset = preset;
    _nodes = nodes;
    _connections = connections;
    _enableGrouping = defaults['enableGrouping']!;
    _showFlowDots = defaults['showFlowDots']!;
    _enableHighlight = defaults['enableHighlight']!;
    _showHoverInfo = defaults['showHoverInfo']!;
    _enableHoverAnimation = defaults['enableHoverAnimation']!;
    _showFitViewButton = defaults['showFitViewButton']!;
    _isConfigMode = defaults['isConfigMode']!;
    _lastTappedNodeId = '—';
  });
  // Fit-to-view after data loads (resetView resets transform, then toggleFitView triggers fit)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _topoViewKey.currentState?.toggleFitView();
  });
}

(List<TopoNode>, List<TopoConnection>) _buildPresetData(String preset) {
  switch (preset) {
    case 'domain':
      return _buildDomainPreset();
    case 'switch':
      return _buildSwitchPreset();
    default:
      return ([], []);
  }
}

Map<String, bool> _presetDefaults(String preset) {
  switch (preset) {
    case 'domain':
      return {
        'enableGrouping': true, 'showFlowDots': true,
        'enableHighlight': false, 'showHoverInfo': false,
        'enableHoverAnimation': true, 'showFitViewButton': true,
        'isConfigMode': false,
      };
    case 'switch':
      return {
        'enableGrouping': false, 'showFlowDots': false,
        'enableHighlight': true, 'showHoverInfo': true,
        'enableHoverAnimation': true, 'showFitViewButton': true,
        'isConfigMode': false,
      };
    default:
      return {
        'enableGrouping': false, 'showFlowDots': false,
        'enableHighlight': false, 'showHoverInfo': false,
        'enableHoverAnimation': false, 'showFitViewButton': false,
        'isConfigMode': false,
      };
  }
}
```

- [ ] **Step 2: Add Domain preset data builder**

```dart
(List<TopoNode>, List<TopoConnection>) _buildDomainPreset() {
  const cloud = 'assets/images/network_cloud_normal.svg';
  const cloudErr = 'assets/images/network_cloud_abnormal.svg';
  final nodes = <TopoNode>[
    const TopoNode(id: 'net-mgmt', label: 'Management', iconAsset: cloud, errorIconAsset: cloudErr, isRoot: true, group: 'Domain-Core'),
    const TopoNode(id: 'net-data', label: 'DataCenter', iconAsset: cloud, errorIconAsset: cloudErr, group: 'Domain-Core'),
    const TopoNode(id: 'net-east-prod', label: 'East-Production', iconAsset: cloud, errorIconAsset: cloudErr, group: 'Domain-East'),
    const TopoNode(id: 'net-east-dev', label: 'East-Dev', iconAsset: cloud, errorIconAsset: cloudErr, isAbnormal: true, group: 'Domain-East'),
    const TopoNode(id: 'net-west-prod', label: 'West-Production', iconAsset: cloud, errorIconAsset: cloudErr, group: 'Domain-West'),
  ];
  final connections = <TopoConnection>[
    const TopoConnection(fromId: 'net-data', toId: 'net-east-prod', lineColor: Color(0xFF5B8DEF)),
    const TopoConnection(fromId: 'net-data', toId: 'net-west-prod', lineColor: Color(0xFF5B8DEF)),
    const TopoConnection(fromId: 'net-east-prod', toId: 'net-east-dev', lineColor: Color(0xFF5B8DEF)),
  ];
  return (nodes, connections);
}
```

- [ ] **Step 3: Add Switch preset data builder**

```dart
(List<TopoNode>, List<TopoConnection>) _buildSwitchPreset() {
  const sw = 'assets/images/switch_float.svg';
  const swErr = 'assets/images/switch_float_err.svg';
  final nodes = <TopoNode>[
    const TopoNode(id: 'sw-core-01', label: 'Core-SW-01', iconAsset: sw, errorIconAsset: swErr, isRoot: true, hoverInfo: {'IP': '10.0.0.1'}, tooltip: 'Core switch'),
    const TopoNode(id: 'sw-agg-01', label: 'Agg-SW-01', iconAsset: sw, errorIconAsset: swErr, hoverInfo: {'IP': '10.0.1.1'}, tooltip: 'Aggregation switch'),
    const TopoNode(id: 'sw-agg-02', label: 'Agg-SW-02', iconAsset: sw, errorIconAsset: swErr, hoverInfo: {'IP': '10.0.1.2'}, tooltip: 'Aggregation switch'),
    const TopoNode(id: 'sw-access-01', label: 'Access-SW-01', iconAsset: sw, errorIconAsset: swErr, hoverInfo: {'IP': '10.0.2.1'}),
    const TopoNode(id: 'sw-access-02', label: 'Access-SW-02', iconAsset: sw, errorIconAsset: swErr, isAbnormal: true, hoverInfo: {'IP': '10.0.2.2'}),
    const TopoNode(id: 'sw-access-03', label: 'Access-SW-03', iconAsset: sw, errorIconAsset: swErr, hoverInfo: {'IP': '10.0.2.3'}),
    const TopoNode(id: 'sw-external', label: 'External-SW', iconAsset: sw, errorIconAsset: swErr, isExternal: true, hoverInfo: {'IP': '10.1.0.1'}),
  ];
  final connections = <TopoConnection>[
    const TopoConnection(fromId: 'sw-core-01', toId: 'sw-agg-01', status: 1),
    const TopoConnection(fromId: 'sw-core-01', toId: 'sw-agg-02', status: 1),
    const TopoConnection(fromId: 'sw-agg-01', toId: 'sw-access-01', status: 1),
    const TopoConnection(fromId: 'sw-agg-01', toId: 'sw-access-02', status: -1),
    const TopoConnection(fromId: 'sw-agg-02', toId: 'sw-access-03', status: 0),
    const TopoConnection(fromId: 'sw-core-01', toId: 'sw-external', status: 1, isDashed: true),
  ];
  return (nodes, connections);
}
```

- [ ] **Step 4: Verify presets load in initState**

Run: `flutter analyze` in the example directory.
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add example/lib/main.dart
git commit -m "feat(example): add preset data builders (domain, switch, empty)"
```

---

### Task 3: Build the sidebar UI

**Files:**
- Modify: `example/lib/main.dart`

- [ ] **Step 1: Replace sidebar placeholder with sectioned layout**

Replace the sidebar `Container` in `build()` with a `ListView` containing 4 sections. Build each section as a helper method:

```dart
SizedBox(
  width: 280,
  child: Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildPresetsSection(),
        const Divider(),
        _buildWidgetConfigSection(),
        const Divider(),
        _buildDataInfoSection(),
        const Divider(),
        _buildDataTweaksSection(),
      ],
    ),
  ),
),
```

- [ ] **Step 2: Implement `_buildPresetsSection`**

```dart
Widget _buildPresetsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader('PRESETS'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          ChoiceChip(label: const Text('Domain'), selected: _activePreset == 'domain', onSelected: (_) => _loadPreset('domain')),
          ChoiceChip(label: const Text('Switch'), selected: _activePreset == 'switch', onSelected: (_) => _loadPreset('switch')),
          ChoiceChip(label: const Text('Empty'), selected: _activePreset == 'empty', onSelected: (_) => _loadPreset('empty')),
        ],
      ),
    ],
  );
}
```

- [ ] **Step 3: Implement `_buildWidgetConfigSection`**

```dart
Widget _buildWidgetConfigSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader('WIDGET CONFIG'),
      const SizedBox(height: 4),
      _configToggle('enableGrouping', _enableGrouping, (v) => setState(() => _enableGrouping = v)),
      _configToggle('showFlowDots', _showFlowDots, (v) => setState(() => _showFlowDots = v)),
      _configToggle('enableHighlight', _enableHighlight, (v) => setState(() => _enableHighlight = v)),
      _configToggle('showHoverInfo', _showHoverInfo, (v) => setState(() => _showHoverInfo = v)),
      _configToggle('enableHoverAnimation', _enableHoverAnimation, (v) => setState(() => _enableHoverAnimation = v)),
      _configToggle('showFitViewButton', _showFitViewButton, (v) => setState(() => _showFitViewButton = v)),
      _configToggle('isConfigMode', _isConfigMode, (v) => setState(() => _isConfigMode = v)),
      // Fit View action button
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('fitView', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
            IconButton(
              icon: const Icon(Icons.fit_screen, size: 20),
              tooltip: 'Toggle fit-to-view',
              onPressed: () => _topoViewKey.currentState?.toggleFitView(),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _configToggle(String label, bool value, ValueChanged<bool> onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        SizedBox(
          height: 28,
          child: FittedBox(child: Switch(value: value, onChanged: onChanged)),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Implement `_buildDataInfoSection`**

```dart
Widget _buildDataInfoSection() {
  final groupCount = _nodes.map((n) => n.group).where((g) => g != null).toSet().length;
  final abnormalCount = _nodes.where((n) => n.isAbnormal).length;
  final externalCount = _nodes.where((n) => n.isExternal).length;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader('DATA INFO'),
      const SizedBox(height: 4),
      _infoRow('Nodes', '${_nodes.length}'),
      _infoRow('Connections', '${_connections.length}'),
      _infoRow('Groups', '$groupCount'),
      _infoRow('Abnormal', '$abnormalCount'),
      _infoRow('External', '$externalCount'),
      _infoRow('Last tapped', _lastTappedNodeId),
    ],
  );
}

Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
      ],
    ),
  );
}
```

- [ ] **Step 5: Implement `_buildDataTweaksSection` (placeholder buttons)**

```dart
Widget _buildDataTweaksSection() {
  final bool canAddConnection = _findUnconnectedPair() != null;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader('DATA TWEAKS'),
      const SizedBox(height: 8),
      _tweakButton(Icons.add_circle_outline, 'Add node', _addRandomNode),
      _tweakButton(Icons.link, 'Add connection', canAddConnection ? _addRandomConnection : null),
      _tweakButton(Icons.warning_amber, 'Toggle abnormal', _nodes.isNotEmpty ? _toggleRandomAbnormal : null),
      _tweakButton(Icons.visibility_off, 'Toggle external', _nodes.isNotEmpty ? _toggleRandomExternal : null),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reset'),
          onPressed: () => _loadPreset(_activePreset),
        ),
      ),
    ],
  );
}

Widget _tweakButton(IconData icon, String label, VoidCallback? onPressed) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label),
        onPressed: onPressed,
      ),
    ),
  );
}
```

- [ ] **Step 6: Add `_SectionHeader` widget**

```dart
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
```

- [ ] **Step 7: Add stub methods so code compiles**

Add empty stubs to `_PlaygroundPageState` so the sidebar buttons have valid references:

```dart
void _addRandomNode() {} // Implemented in Task 4
void _addRandomConnection() {} // Implemented in Task 4
void _toggleRandomAbnormal() {} // Implemented in Task 4
void _toggleRandomExternal() {} // Implemented in Task 4
List<(String, String)> _allUnconnectedPairs() => []; // Implemented in Task 4
(String, String)? _findUnconnectedPair() => null; // Implemented in Task 4
```

- [ ] **Step 8: Run flutter analyze**

Run: `cd /Users/hualinliang/Project/topology_view/example && flutter analyze`
Expected: No issues found.

- [ ] **Step 9: Commit**

```bash
git add example/lib/main.dart
git commit -m "feat(example): build sidebar UI with presets, config, info, tweaks"
```

---

### Task 4: Wire up TopologyView and data tweak methods

**Files:**
- Modify: `example/lib/main.dart`

- [ ] **Step 1: Replace main area placeholder with TopologyView**

In `build()`, replace the main area `Expanded` child:

```dart
Expanded(
  child: _nodes.isEmpty
      ? Center(
          child: Text(
            'No topology data — use presets or add nodes',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        )
      : TopologyView(
          key: _topoViewKey,
          nodes: _nodes,
          connections: _connections,
          enableGrouping: _enableGrouping,
          showFlowDots: _showFlowDots,
          enableHighlight: _enableHighlight,
          showHoverInfo: _showHoverInfo,
          enableHoverAnimation: _enableHoverAnimation,
          showFitViewButton: _showFitViewButton,
          isConfigMode: _isConfigMode,
          onNodeTap: (id) => setState(() => _lastTappedNodeId = id),
          onResetView: () => debugPrint('onResetView fired'),
        ),
),
```

- [ ] **Step 2: Implement `_addRandomNode`**

```dart
void _addRandomNode() {
  final rng = Random();
  final int idx = _nodes.length + 1;
  final bool isDomain = _activePreset == 'domain';
  final String id = isDomain ? 'net-$idx' : 'sw-$idx';
  final String label = isDomain ? 'Network-$idx' : 'Switch-$idx';

  final newNode = TopoNode(
    id: id,
    label: label,
    iconAsset: isDomain ? 'assets/images/network_cloud_normal.svg' : 'assets/images/switch_float.svg',
    errorIconAsset: isDomain ? 'assets/images/network_cloud_abnormal.svg' : 'assets/images/switch_float_err.svg',
    isRoot: _nodes.isEmpty,
    group: isDomain ? 'Domain-New-$idx' : null,
    hoverInfo: isDomain ? null : {'IP': '10.0.${rng.nextInt(255)}.${rng.nextInt(255)}'},
  );

  final newNodes = List<TopoNode>.from(_nodes)..add(newNode);
  final newConnections = List<TopoConnection>.from(_connections);

  // Connect to a random existing node (if any exist)
  if (_nodes.isNotEmpty) {
    final target = _nodes[rng.nextInt(_nodes.length)];
    newConnections.add(TopoConnection(
      fromId: id,
      toId: target.id,
      lineColor: isDomain ? const Color(0xFF5B8DEF) : null,
    ));
  }

  setState(() {
    _nodes = newNodes;
    _connections = newConnections;
  });
}
```

- [ ] **Step 3: Implement `_addRandomConnection`**

```dart
List<(String, String)> _allUnconnectedPairs() {
  final pairs = <(String, String)>[];
  for (int i = 0; i < _nodes.length; i++) {
    for (int j = i + 1; j < _nodes.length; j++) {
      final a = _nodes[i].id;
      final b = _nodes[j].id;
      final connected = _connections.any(
        (c) => (c.fromId == a && c.toId == b) || (c.fromId == b && c.toId == a),
      );
      if (!connected) pairs.add((a, b));
    }
  }
  return pairs;
}

(String, String)? _findUnconnectedPair() {
  final pairs = _allUnconnectedPairs();
  return pairs.isEmpty ? null : pairs.first;
}

void _addRandomConnection() {
  final pairs = _allUnconnectedPairs();
  if (pairs.isEmpty) return;

  final rng = Random();
  final (fromId, toId) = pairs[rng.nextInt(pairs.length)];
  final isDomain = _activePreset == 'domain';

  setState(() {
    _connections = List<TopoConnection>.from(_connections)
      ..add(TopoConnection(
        fromId: fromId,
        toId: toId,
        lineColor: isDomain ? const Color(0xFF5B8DEF) : null,
      ));
  });
}
```

- [ ] **Step 4: Implement `_toggleRandomAbnormal` and `_toggleRandomExternal`**

```dart
void _toggleRandomAbnormal() {
  if (_nodes.isEmpty) return;
  final rng = Random();
  final idx = rng.nextInt(_nodes.length);
  final node = _nodes[idx];
  setState(() {
    _nodes = List<TopoNode>.from(_nodes)
      ..[idx] = TopoNode(
        id: node.id, label: node.label,
        iconAsset: node.iconAsset, errorIconAsset: node.errorIconAsset,
        isRoot: node.isRoot, isAbnormal: !node.isAbnormal,
        isExternal: node.isExternal, group: node.group,
        hoverInfo: node.hoverInfo, tooltip: node.tooltip,
      );
  });
}

void _toggleRandomExternal() {
  if (_nodes.isEmpty) return;
  final rng = Random();
  final idx = rng.nextInt(_nodes.length);
  final node = _nodes[idx];
  setState(() {
    _nodes = List<TopoNode>.from(_nodes)
      ..[idx] = TopoNode(
        id: node.id, label: node.label,
        iconAsset: node.iconAsset, errorIconAsset: node.errorIconAsset,
        isRoot: node.isRoot, isAbnormal: node.isAbnormal,
        isExternal: !node.isExternal, group: node.group,
        hoverInfo: node.hoverInfo, tooltip: node.tooltip,
      );
  });
}
```

- [ ] **Step 5: Run flutter analyze**

Run: `cd /Users/hualinliang/Project/topology_view/example && flutter analyze`
Expected: No issues found.

- [ ] **Step 6: Run the app and verify all interactions**

Run: `flutter run -d chrome`
Verify:
1. Domain preset loads on startup with clouds in ellipses
2. Flipping toggles updates the topology immediately
3. Switching presets swaps data and config
4. "+ Add node" adds a node and connection
5. "+ Add connection" adds a connection (button disabled when fully connected)
6. "Toggle abnormal" flips a random node red/normal
7. "Toggle external" changes a random node to 50% opacity
8. Tapping a node shows its ID in "Last tapped"
9. "Fit View" button triggers fit-to-view
10. "Reset" returns to clean preset state
11. Empty preset shows placeholder message

- [ ] **Step 7: Commit**

```bash
git add example/lib/main.dart
git commit -m "feat(example): wire up TopologyView and all data tweak methods"
```

---

### Task 5: Update test and final cleanup

**Files:**
- Modify: `example/test/widget_test.dart`

- [ ] **Step 1: Update the widget test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:topology_view_example/main.dart';

void main() {
  testWidgets('Playground renders with sidebar and presets', (WidgetTester tester) async {
    await tester.pumpWidget(const TopologyViewExampleApp());
    await tester.pumpAndSettle();

    // Sidebar preset buttons
    expect(find.text('Domain'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);

    // Section headers
    expect(find.text('PRESETS'), findsOneWidget);
    expect(find.text('WIDGET CONFIG'), findsOneWidget);
    expect(find.text('DATA INFO'), findsOneWidget);
    expect(find.text('DATA TWEAKS'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test**

Run: `cd /Users/hualinliang/Project/topology_view/example && flutter test`
Expected: All tests pass.

- [ ] **Step 3: Run flutter analyze on the whole package**

Run: `cd /Users/hualinliang/Project/topology_view && flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add example/test/widget_test.dart
git commit -m "test(example): update widget test for playground"
```
