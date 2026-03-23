import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const PlaygroundPage(),
    );
  }
}

// =============================================================================
// Preset enum
// =============================================================================

enum Preset { domain, switchLevel, empty }

// =============================================================================
// PlaygroundPage — single StatefulWidget holding all state
// =============================================================================

class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState extends State<PlaygroundPage> {
  final GlobalKey<TopologyViewState> _topoKey = GlobalKey<TopologyViewState>();
  final Random _rng = Random();

  // ---- data ----
  List<TopoNode> _nodes = [];
  List<TopoConnection> _connections = [];

  // ---- config toggles ----
  bool _enableGrouping = false;
  bool _showFlowDots = false;
  bool _enableHighlight = false;
  bool _showHoverInfo = false;
  bool _enableHoverAnimation = false;
  bool _showFitViewButton = true;
  bool _isConfigMode = false;

  // ---- tracking ----
  Preset? _activePreset;
  String? _lastTappedNodeId;

  // ---- counter helpers ----
  int _nodeCounter = 0;

  // ===========================================================================
  // Presets
  // ===========================================================================

  void _loadPreset(Preset preset) {
    switch (preset) {
      case Preset.domain:
        _loadDomainPreset();
      case Preset.switchLevel:
        _loadSwitchPreset();
      case Preset.empty:
        _loadEmptyPreset();
    }
  }

  void _loadDomainPreset() {
    setState(() {
      _activePreset = Preset.domain;
      _lastTappedNodeId = null;
      _nodeCounter = 5;

      _nodes = [
        const TopoNode(
          id: 'net-mgmt',
          label: 'Management',
          iconAsset: 'assets/images/network_cloud_normal.svg',
          errorIconAsset: 'assets/images/network_cloud_abnormal.svg',
          isRoot: true,
          group: 'Domain-Core',
        ),
        const TopoNode(
          id: 'net-data',
          label: 'DataCenter',
          iconAsset: 'assets/images/network_cloud_normal.svg',
          errorIconAsset: 'assets/images/network_cloud_abnormal.svg',
          group: 'Domain-Core',
        ),
        const TopoNode(
          id: 'net-east',
          label: 'East-Prod',
          iconAsset: 'assets/images/network_cloud_normal.svg',
          errorIconAsset: 'assets/images/network_cloud_abnormal.svg',
          group: 'Domain-East',
        ),
        const TopoNode(
          id: 'net-east-dev',
          label: 'East-Dev',
          iconAsset: 'assets/images/network_cloud_normal.svg',
          errorIconAsset: 'assets/images/network_cloud_abnormal.svg',
          group: 'Domain-East',
        ),
        const TopoNode(
          id: 'net-west',
          label: 'West-Prod',
          iconAsset: 'assets/images/network_cloud_normal.svg',
          errorIconAsset: 'assets/images/network_cloud_abnormal.svg',
          group: 'Domain-West',
        ),
      ];

      _connections = [
        const TopoConnection(
          fromId: 'net-data',
          toId: 'net-east',
          lineColor: Color(0xFF5B8DEF),
        ),
        const TopoConnection(
          fromId: 'net-data',
          toId: 'net-west',
          lineColor: Color(0xFF5B8DEF),
        ),
        const TopoConnection(
          fromId: 'net-east',
          toId: 'net-east-dev',
          lineColor: Color(0xFF5B8DEF),
        ),
      ];

      _enableGrouping = true;
      _showFlowDots = true;
      _enableHighlight = false;
      _showHoverInfo = false;
      _enableHoverAnimation = false;
      _showFitViewButton = true;
      _isConfigMode = false;
    });

    _postFrameFitView();
  }

  void _loadSwitchPreset() {
    setState(() {
      _activePreset = Preset.switchLevel;
      _lastTappedNodeId = null;
      _nodeCounter = 7;

      _nodes = [
        const TopoNode(
          id: 'sw-core-01',
          label: 'Core-SW-01',
          iconAsset: 'assets/images/switch_float.svg',
          errorIconAsset: 'assets/images/switch_float_err.svg',
          isRoot: true,
          hoverInfo: {'IP': '10.0.0.1'},
          tooltip: 'Core switch',
        ),
        const TopoNode(
          id: 'sw-agg-01',
          label: 'Agg-SW-01',
          iconAsset: 'assets/images/switch_float.svg',
          errorIconAsset: 'assets/images/switch_float_err.svg',
          hoverInfo: {'IP': '10.0.1.1'},
          tooltip: 'Aggregation switch',
        ),
        const TopoNode(
          id: 'sw-agg-02',
          label: 'Agg-SW-02',
          iconAsset: 'assets/images/switch_float.svg',
          errorIconAsset: 'assets/images/switch_float_err.svg',
          hoverInfo: {'IP': '10.0.1.2'},
          tooltip: 'Aggregation switch',
        ),
        const TopoNode(
          id: 'sw-access-01',
          label: 'Access-SW-01',
          iconAsset: 'assets/images/switch_float.svg',
          errorIconAsset: 'assets/images/switch_float_err.svg',
          hoverInfo: {'IP': '10.0.2.1'},
        ),
        const TopoNode(
          id: 'sw-access-02',
          label: 'Access-SW-02',
          iconAsset: 'assets/images/switch_float.svg',
          errorIconAsset: 'assets/images/switch_float_err.svg',
          isAbnormal: true,
          hoverInfo: {'IP': '10.0.2.2'},
        ),
        const TopoNode(
          id: 'sw-access-03',
          label: 'Access-SW-03',
          iconAsset: 'assets/images/switch_float.svg',
          errorIconAsset: 'assets/images/switch_float_err.svg',
          hoverInfo: {'IP': '10.0.2.3'},
        ),
        const TopoNode(
          id: 'sw-external',
          label: 'External-SW',
          iconAsset: 'assets/images/switch_float.svg',
          errorIconAsset: 'assets/images/switch_float_err.svg',
          isExternal: true,
          hoverInfo: {'IP': '10.1.0.1'},
        ),
      ];

      _connections = [
        const TopoConnection(
            fromId: 'sw-core-01', toId: 'sw-agg-01', status: 1),
        const TopoConnection(
            fromId: 'sw-core-01', toId: 'sw-agg-02', status: 1),
        const TopoConnection(
            fromId: 'sw-agg-01', toId: 'sw-access-01', status: 1),
        const TopoConnection(
            fromId: 'sw-agg-01', toId: 'sw-access-02', status: -1),
        const TopoConnection(
            fromId: 'sw-agg-02', toId: 'sw-access-03', status: 0),
        const TopoConnection(
          fromId: 'sw-core-01',
          toId: 'sw-external',
          status: 1,
          isDashed: true,
        ),
      ];

      _enableGrouping = false;
      _showFlowDots = false;
      _enableHighlight = true;
      _showHoverInfo = true;
      _enableHoverAnimation = true;
      _showFitViewButton = true;
      _isConfigMode = false;
    });

    _postFrameFitView();
  }

  void _loadEmptyPreset() {
    setState(() {
      _activePreset = Preset.empty;
      _lastTappedNodeId = null;
      _nodeCounter = 0;

      _nodes = [];
      _connections = [];

      _enableGrouping = false;
      _showFlowDots = false;
      _enableHighlight = false;
      _showHoverInfo = false;
      _enableHoverAnimation = false;
      _showFitViewButton = true;
      _isConfigMode = false;
    });
  }

  void _postFrameFitView() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _topoKey.currentState?.toggleFitView();
    });
  }

  // ===========================================================================
  // Data tweaks
  // ===========================================================================

  void _addRandomNode() {
    _nodeCounter++;
    final id = 'node-$_nodeCounter';
    final newNode = TopoNode(
      id: id,
      label: 'Node $_nodeCounter',
      iconAsset: 'assets/images/switch_float.svg',
      errorIconAsset: 'assets/images/switch_float_err.svg',
    );

    if (_nodes.isEmpty) {
      // Standalone root with no connection.
      final rootNode = TopoNode(
        id: id,
        label: 'Node $_nodeCounter',
        iconAsset: 'assets/images/switch_float.svg',
        errorIconAsset: 'assets/images/switch_float_err.svg',
        isRoot: true,
      );
      setState(() {
        _nodes = [..._nodes, rootNode];
        _activePreset = null;
      });
      return;
    }

    // Connect to a random existing node.
    final target = _nodes[_rng.nextInt(_nodes.length)];
    setState(() {
      _nodes = [..._nodes, newNode];
      _connections = [
        ..._connections,
        TopoConnection(fromId: target.id, toId: id),
      ];
      _activePreset = null;
    });
  }

  List<(String, String)> _allUnconnectedPairs() {
    final pairs = <(String, String)>[];
    final connected = <String>{};
    for (final c in _connections) {
      connected.add('${c.fromId}|${c.toId}');
      connected.add('${c.toId}|${c.fromId}');
    }
    for (int i = 0; i < _nodes.length; i++) {
      for (int j = i + 1; j < _nodes.length; j++) {
        final a = _nodes[i].id;
        final b = _nodes[j].id;
        if (!connected.contains('$a|$b')) {
          pairs.add((a, b));
        }
      }
    }
    return pairs;
  }

  (String, String)? _findUnconnectedPair() {
    final pairs = _allUnconnectedPairs();
    if (pairs.isEmpty) return null;
    return pairs[_rng.nextInt(pairs.length)];
  }

  void _addRandomConnection() {
    final pair = _findUnconnectedPair();
    if (pair == null) return;
    setState(() {
      _connections = [
        ..._connections,
        TopoConnection(fromId: pair.$1, toId: pair.$2),
      ];
      _activePreset = null;
    });
  }

  void _toggleAbnormal() {
    if (_nodes.isEmpty) return;
    final idx = _rng.nextInt(_nodes.length);
    final old = _nodes[idx];
    final updated = TopoNode(
      id: old.id,
      label: old.label,
      iconAsset: old.iconAsset,
      errorIconAsset: old.errorIconAsset,
      isRoot: old.isRoot,
      isAbnormal: !old.isAbnormal,
      isExternal: old.isExternal,
      group: old.group,
      hoverInfo: old.hoverInfo,
      tooltip: old.tooltip,
    );
    setState(() {
      _nodes = [
        for (int i = 0; i < _nodes.length; i++)
          if (i == idx) updated else _nodes[i],
      ];
      _activePreset = null;
    });
  }

  void _toggleExternal() {
    if (_nodes.isEmpty) return;
    final idx = _rng.nextInt(_nodes.length);
    final old = _nodes[idx];
    final updated = TopoNode(
      id: old.id,
      label: old.label,
      iconAsset: old.iconAsset,
      errorIconAsset: old.errorIconAsset,
      isRoot: old.isRoot,
      isAbnormal: old.isAbnormal,
      isExternal: !old.isExternal,
      group: old.group,
      hoverInfo: old.hoverInfo,
      tooltip: old.tooltip,
    );
    setState(() {
      _nodes = [
        for (int i = 0; i < _nodes.length; i++)
          if (i == idx) updated else _nodes[i],
      ];
      _activePreset = null;
    });
  }

  void _resetData() {
    setState(() {
      _nodes = [];
      _connections = [];
      _nodeCounter = 0;
      _lastTappedNodeId = null;
      _activePreset = null;
    });
  }

  // ===========================================================================
  // Computed counters
  // ===========================================================================

  int get _groupCount {
    final groups = <String>{};
    for (final n in _nodes) {
      if (n.group != null) groups.add(n.group!);
    }
    return groups.length;
  }

  int get _abnormalCount => _nodes.where((n) => n.isAbnormal).length;

  int get _externalCount => _nodes.where((n) => n.isExternal).length;

  bool get _isFullyConnected => _allUnconnectedPairs().isEmpty;

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TopologyView Playground'),
      ),
      body: Row(
        children: [
          // ---------- Sidebar ----------
          SizedBox(
            width: 280,
            child: _buildSidebar(),
          ),
          const VerticalDivider(width: 1),
          // ---------- Main area ----------
          Expanded(child: _buildMainArea()),
        ],
      ),
    );
  }

  // ===========================================================================
  // Sidebar
  // ===========================================================================

  Widget _buildSidebar() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ---- PRESETS ----
          const _SectionHeader('PRESETS'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Domain'),
                selected: _activePreset == Preset.domain,
                onSelected: (_) => _loadPreset(Preset.domain),
              ),
              ChoiceChip(
                label: const Text('Switch'),
                selected: _activePreset == Preset.switchLevel,
                onSelected: (_) => _loadPreset(Preset.switchLevel),
              ),
              ChoiceChip(
                label: const Text('Empty'),
                selected: _activePreset == Preset.empty,
                onSelected: (_) => _loadPreset(Preset.empty),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---- WIDGET CONFIG ----
          const _SectionHeader('WIDGET CONFIG'),
          _buildToggle('enableGrouping', _enableGrouping, (v) {
            setState(() {
              _enableGrouping = v;
              _activePreset = null;
            });
          }),
          _buildToggle('showFlowDots', _showFlowDots, (v) {
            setState(() {
              _showFlowDots = v;
              _activePreset = null;
            });
          }),
          _buildToggle('enableHighlight', _enableHighlight, (v) {
            setState(() {
              _enableHighlight = v;
              _activePreset = null;
            });
          }),
          _buildToggle('showHoverInfo', _showHoverInfo, (v) {
            setState(() {
              _showHoverInfo = v;
              _activePreset = null;
            });
          }),
          _buildToggle('enableHoverAnimation', _enableHoverAnimation, (v) {
            setState(() {
              _enableHoverAnimation = v;
              _activePreset = null;
            });
          }),
          _buildToggle('showFitViewButton', _showFitViewButton, (v) {
            setState(() {
              _showFitViewButton = v;
              _activePreset = null;
            });
          }),
          _buildToggle('isConfigMode', _isConfigMode, (v) {
            setState(() {
              _isConfigMode = v;
              _activePreset = null;
            });
          }),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton.filled(
              icon: const Icon(Icons.fit_screen, size: 18),
              tooltip: 'Fit View',
              onPressed: () => _topoKey.currentState?.toggleFitView(),
            ),
          ),
          const SizedBox(height: 20),

          // ---- DATA INFO ----
          const _SectionHeader('DATA INFO'),
          _buildInfoRow('Nodes', '${_nodes.length}'),
          _buildInfoRow('Connections', '${_connections.length}'),
          _buildInfoRow('Groups', '$_groupCount'),
          _buildInfoRow('Abnormal', '$_abnormalCount'),
          _buildInfoRow('External', '$_externalCount'),
          _buildInfoRow('Last tapped', _lastTappedNodeId ?? '—'),
          const SizedBox(height: 20),

          // ---- DATA TWEAKS ----
          const _SectionHeader('DATA TWEAKS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tweakButton('Add node', _addRandomNode),
              _tweakButton(
                'Add connection',
                (_nodes.length < 2 || _isFullyConnected)
                    ? null
                    : _addRandomConnection,
              ),
              _tweakButton(
                'Toggle abnormal',
                _nodes.isEmpty ? null : _toggleAbnormal,
              ),
              _tweakButton(
                'Toggle external',
                _nodes.isEmpty ? null : _toggleExternal,
              ),
              _tweakButton('Reset', _resetData),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
        ),
      ),
      value: value,
      dense: true,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _tweakButton(String label, VoidCallback? onPressed) {
    return FilledButton.tonal(
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // ===========================================================================
  // Main area
  // ===========================================================================

  Widget _buildMainArea() {
    if (_nodes.isEmpty) {
      return const Center(
        child: Text(
          'Select a preset or add nodes to begin.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return TopologyView(
      key: _topoKey,
      nodes: _nodes,
      connections: _connections,
      enableGrouping: _enableGrouping,
      showFlowDots: _showFlowDots,
      enableHighlight: _enableHighlight,
      showHoverInfo: _showHoverInfo,
      enableHoverAnimation: _enableHoverAnimation,
      showFitViewButton: _showFitViewButton,
      isConfigMode: _isConfigMode,
      onNodeTap: (nodeId) {
        setState(() {
          _lastTappedNodeId = nodeId;
        });
      },
      onResetView: () {
        debugPrint('onResetView called');
      },
    );
  }
}

// =============================================================================
// _SectionHeader — small, bold, uppercase label for sidebar sections
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
