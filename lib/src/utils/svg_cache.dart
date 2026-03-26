import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';

final _pathRegex = RegExp(r'<path\s+d="([^"]+)"');

/// In-memory cache for SVG strings and parsed Path objects.
class SvgCacheManager {
  static final Map<String, String> _svgCache = {};
  static final Map<String, Path> _pathCache = {};
  static final Set<String> _loadingPaths = {};
  static bool _isPreloading = false;

  /// Async preload a list of SVG asset paths.
  static Future<void> preloadAssets(List<String> paths) async {
    if (_isPreloading) return;
    _isPreloading = true;

    try {
      final futures = paths.map((path) => loadSvg(path));
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error preloading SVG assets: $e');
    } finally {
      _isPreloading = false;
    }
  }

  /// Load a single SVG string from assets with duplicate-load prevention.
  static Future<String> loadSvg(String path) async {
    if (_svgCache.containsKey(path)) {
      return _svgCache[path]!;
    }

    // Wait if another caller is already loading this path.
    if (_loadingPaths.contains(path)) {
      while (_loadingPaths.contains(path)) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (_svgCache.containsKey(path)) {
        return _svgCache[path]!;
      }
    }

    _loadingPaths.add(path);

    int retryCount = 0;
    const maxRetries = 3;

    while (true) {
      try {
        final svg = await rootBundle.loadString(path);
        _svgCache[path] = svg;
        return svg;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          debugPrint('Error loading SVG after $maxRetries retries: $path - $e');
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      } finally {
        if (retryCount >= maxRetries || _svgCache.containsKey(path)) {
          _loadingPaths.remove(path);
        }
      }
    }
  }

  /// Extract and combine all <path d="..."> data from an SVG string into one [Path].
  static Path getPath(String svg) {
    if (_pathCache.containsKey(svg)) {
      return _pathCache[svg]!;
    }

    final matches = _pathRegex.allMatches(svg);
    final List<Path> paths = [];
    for (final RegExpMatch match in matches) {
      final String data = match.group(1)!;
      final path = parseSvgPathData(data);
      paths.add(path);
    }

    if (paths.isEmpty) {
      final empty = Path();
      _pathCache[svg] = empty;
      return empty;
    }

    final combinedPath =
        paths.reduce((p, e) => Path.combine(PathOperation.union, p, e));
    _pathCache[svg] = combinedPath;
    return combinedPath;
  }

  /// Preload both SVG strings and parsed paths.
  static Future<void> preloadPaths(List<String> paths) async {
    for (final path in paths) {
      try {
        final svg = await loadSvg(path);
        getPath(svg);
      } catch (e) {
        debugPrint('Error preloading path for $path: $e');
      }
    }
  }

  /// Check whether a path is already cached.
  static bool isCached(String path) => _svgCache.containsKey(path);

  /// Clear all caches.
  static void clearCache() {
    _svgCache.clear();
    _pathCache.clear();
    _loadingPaths.clear();
  }
}

// ---------------------------------------------------------------------------
// Helper extension used by [_SvgClipper].
// ---------------------------------------------------------------------------

extension _BoxFitSize on Size {
  Size getBoxFitSize(Size sourceSize) {
    if (sourceSize.width == 0 || sourceSize.height == 0) return this;
    final double scaleW = width / sourceSize.width;
    final double scaleH = height / sourceSize.height;
    final double scale = min(scaleW, scaleH);
    return Size(sourceSize.width * scale, sourceSize.height * scale);
  }
}

// ---------------------------------------------------------------------------
// SvgClip widget — renders an SVG asset with PhysicalShape clipping.
// ---------------------------------------------------------------------------

/// Renders an SVG asset clipped to its own path outline with optional
/// elevation/shadow. Supports both cloud-style (clipScale/mX/mY) and
/// standard box-fit rendering.
class SvgClip extends StatefulWidget {
  final String path;
  final double clipScale;
  final double mX;
  final double mY;
  final double elevation;
  final double width;
  final double height;
  final BoxFit fit;

  const SvgClip({
    super.key,
    required this.path,
    this.clipScale = 1.0,
    this.mX = 0,
    this.mY = 0,
    this.elevation = 0,
    this.width = 200,
    this.height = 200,
    this.fit = BoxFit.contain,
  });

  @override
  State<SvgClip> createState() => _SvgClipState();
}

class _SvgClipState extends State<SvgClip> {
  Future<Path>? _pathFuture;
  Path? _cachedPath;
  bool _hasError = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _initializePath();
  }

  @override
  void didUpdateWidget(SvgClip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _resetState();
      _initializePath();
    }
  }

  void _resetState() {
    _cachedPath = null;
    _hasError = false;
    _retryCount = 0;
  }

  void _initializePath() {
    _pathFuture = _loadPath();
  }

  Future<Path> _loadPath() async {
    if (_cachedPath != null) return _cachedPath!;

    try {
      _hasError = false;
      final fullPath = 'packages/topology_view/${widget.path}';
      final svg = await SvgCacheManager.loadSvg(fullPath);
      _cachedPath = SvgCacheManager.getPath(svg);
      return _cachedPath!;
    } catch (e) {
      _hasError = true;
      if (_retryCount < _maxRetries) {
        _retryCount++;
        await Future.delayed(Duration(milliseconds: 500 * _retryCount));
        return _loadPath();
      }
      rethrow;
    }
  }

  void _retryLoad() {
    setState(() {
      _resetState();
      _initializePath();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Path>(
      future: _pathFuture,
      builder: (BuildContext context, AsyncSnapshot<Path> snapshot) {
        if (snapshot.hasData && !_hasError) {
          return PhysicalShape(
            clipper: _SvgClipper(
              snapshot.data!,
              widget.clipScale,
              widget.mX,
              widget.mY,
            ),
            color: Theme.of(context).colorScheme.surface,
            elevation: widget.elevation,
            shadowColor: Colors.black,
            child: SvgPicture.asset(
              widget.path,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              package: 'topology_view',
              placeholderBuilder: (_) => _buildLoading(),
            ),
          );
        } else if (_hasError) {
          return _buildError();
        } else {
          return _buildLoading();
        }
      },
    );
  }

  Widget _buildLoading() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 20),
            const SizedBox(height: 4),
            const Text(
              'Load failed',
              style: TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            GestureDetector(
              onTap: _retryLoad,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom clipper that clips to the SVG's own path outline.
// ---------------------------------------------------------------------------

class _SvgClipper extends CustomClipper<Path> {
  final Path path;
  final double clipScale;
  final double mX;
  final double mY;

  const _SvgClipper(this.path, this.clipScale, this.mX, this.mY);

  @override
  Path getClip(Size size) {
    final bounds = path.getBounds();
    final targetMaskSize =
        size.getBoxFitSize(Size(bounds.width, bounds.height));
    final scale = targetMaskSize.width / bounds.width * clipScale;
    final moveX = max(0.0, (size.width - targetMaskSize.width) / 2 + mX);
    final moveY = max(0.0, (size.height - targetMaskSize.height) / 2 + mY);
    return path
        .transform(Float64List.fromList(
            [scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]))
        .shift(Offset(moveX, moveY));
  }

  @override
  bool shouldReclip(_SvgClipper oldClipper) =>
      oldClipper.path != path ||
      oldClipper.clipScale != clipScale ||
      oldClipper.mX != mX ||
      oldClipper.mY != mY;
}
