import 'dart:math' as math;
import 'dart:ui' as ui;

/// Caches pixelated versions of the source image, one per block size.
///
/// Rendering a mosaic is just "shrink with averaging, then draw back with
/// nearest-neighbour filtering". The shrink has to happen in an offscreen
/// image, so we keep a small cache keyed by the integer block size in pixels.
class MosaicTextureCache {
  final Map<int, ui.Image> _cache = <int, ui.Image>{};
  final Set<int> _building = <int>{};
  ui.Image? _source;

  ui.Image? operator [](int block) => _cache[block];

  bool get isEmpty => _cache.isEmpty;

  void attach(ui.Image source) {
    if (identical(_source, source)) return;
    clear();
    _source = source;
  }

  Future<ui.Image?> ensure(int block) async {
    final source = _source;
    if (source == null) return null;
    final cached = _cache[block];
    if (cached != null) return cached;
    if (!_building.add(block)) return null;
    try {
      final width = math.max(1, (source.width / block).round());
      final height = math.max(1, (source.height / block).round());
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(
          0,
          0,
          source.width.toDouble(),
          source.height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      _cache[block] = image;
      return image;
    } finally {
      _building.remove(block);
    }
  }

  void clear() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _building.clear();
  }

  void dispose() {
    clear();
    _source = null;
  }
}
