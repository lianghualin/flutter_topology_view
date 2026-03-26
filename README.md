# flutter_topology_view

A unified Flutter topology visualization widget for rendering hierarchical network topologies with interactive pan/zoom, animated connections, and configurable node icons.

## Features

- **BFS hierarchical layout** — automatic node positioning using breadth-first search
- **Two modes** — domain-level (grouped nodes with ellipses) and switch-level (flat topology)
- **Painted device icons** — network clouds, switches, routers, and more via `topology_view_icons`
- **Animated connections** — S-curve bezier lines with flowing dots for domain-level, status-colored straight lines for switch-level
- **Interactive** — pan, zoom, fit-to-view, node tap callbacks
- **Hover info panels** — accordion-style expand with frosted glass background
- **Show all info** — toggle to expand all node info panels at once

## Getting started

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_topology_view: ^1.0.0
```

## Usage

```dart
import 'package:flutter_topology_view/topology_view.dart';

TopologyView(
  nodes: [
    TopoNode(
      id: 'sw1',
      label: 'Core Switch',
      deviceType: TopoDeviceType.switch_,
      isRoot: true,
      hoverInfo: {'IP': '10.0.0.1'},
    ),
    TopoNode(
      id: 'sw2',
      label: 'Access Switch',
      deviceType: TopoDeviceType.switch_,
      hoverInfo: {'IP': '10.0.1.1'},
    ),
  ],
  connections: [
    TopoConnection(fromId: 'sw1', toId: 'sw2', status: 1),
  ],
  enableHighlight: true,
  showHoverInfo: true,
  enableHoverAnimation: true,
  onNodeTap: (nodeId) => print('Tapped: $nodeId'),
)
```

### Domain-level topology (grouped networks)

```dart
TopologyView(
  nodes: [
    TopoNode(
      id: 'net1',
      label: 'Management',
      deviceType: TopoDeviceType.network,
      isRoot: true,
      group: 'Domain-Core',
    ),
    // ...
  ],
  connections: [...],
  enableGrouping: true,
  showFlowDots: true,
)
```

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `enableGrouping` | `false` | Draw ellipses around nodes sharing the same group |
| `showFlowDots` | `true` | Animated dots flowing along connection lines |
| `enableHighlight` | `true` | Highlight connections on node hover |
| `showHoverInfo` | `false` | Show hover info panel with node metadata |
| `showAllInfo` | `false` | Expand all info panels (no hover required) |
| `enableHoverAnimation` | `true` | Float-up effect on node hover |
| `showFitViewButton` | `true` | Show fit-to-view toggle button |
| `isConfigMode` | `false` | Force all nodes to normal status |

## Example

See the [example app](example/) for a full interactive playground.

```bash
cd example
flutter run -d chrome
```
