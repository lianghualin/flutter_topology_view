## 1.0.1

- Rename package from `topology_view` to `flutter_topology_view`
- Fix node label/icon spacing — Column-based layout replaces fragile Stack positioning
- Fix CanvasKit WASM crash — reduce canvas size and add RepaintBoundary per layer
- Unified info panel with accordion expand (name always visible, hover info slides in)
- Semi-transparent frosted background on labels for readability over connection lines
- Fix connection highlight dance — use static curve instead of animated bezier
- Remove highlight bend entirely — highlighted connections stay as straight lines
- Clean up auto-generated files from git tracking

## 1.0.0

- Initial release
- Unified topology visualization widget merging network and switch topology views
- BFS hierarchical layout engine (group-level and node-level)
- Three rendering layers: group ellipses, connection lines, node icons
- S-curve bezier connections for domain-level topology
- Animated flowing dots on connection lines
- Connection highlight on node hover
- Interactive pan/zoom via InteractiveViewer
- Fit-to-view toggle
- Painted device icons via `topology_view_icons` (network, switch, and more)
- Hover info panel with accordion expand animation
- `showAllInfo` toggle to expand all info panels at once
- Config mode for forcing normal status display
- External node rendering at 50% opacity
