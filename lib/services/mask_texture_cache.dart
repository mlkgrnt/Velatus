import 'dart:math' as math;
import 'dart:ui' as ui;

/// Offscreen textures used by [MaskRenderer].
///
/// Both mosaic and blur are drawn through an image shader instead of an
/// offscreen `saveLayer` + `BlendMode.dstIn` mask. That matters: a layer mask
/// is clipped to the layer's own rectangle, so on some backends the visible
/// result was a rectangle larger than the mask (and the rectangle grew with the
/// blur strength). A shader is sampled through the path itself, so a brush
/// stroke stays round, a rectangle stays a rectangle, and changing the strength
/// can never change the masked area.
///
/// Textures are keyed by the property that actually changes the pixels:
/// the integer block size for mosaic, and the rounded sigma for blur.
class MaskTextureCache {
  /// Blur textures are capped at this side length. A blurred image has no
  /// detail above roughly `1 / sigma`, so capping costs nothing visually while
  /// keeping a 48 MP export from allocating another 190 MB buffer.
  static const int maxBlurSide = 2048;

  final Map<int, ui.Image> _mosaic = <int, ui.Image>{};
  final Map<int, ui.Image> _blur = <int, ui.Image>{};
  final Set<String> _building = <String>{};
  ui.Image? _source;

  ui.Image? mosaic(int blockPx) => _mosaic[blockPx];

  ui.Image? blur(int sigmaPx) => _blur[sigmaPx];

  ui.Image? get source => _source;

  bool get isEmpty => _mosaic.isEmpty && _blur.isEmpty;

  void attach(ui.Image source) {
    if (identical(_source, source)) return;
    clear();
    _source = source;
  }

  /// Shrinks the source so that each block becomes exactly one texel.
  Future<ui.Image?> ensureMosaic(int blockPx) async {
    final source = _source;
    if (source == null) return null;
    final cached = _mosaic[blockPx];
    if (cached != null) return cached;
    const key = 'mosaic';
    final tag = '$key$blockPx';
    if (!_building.add(tag)) return null;
    try {
      final width = math.max(1, (source.width / blockPx).round());
      final height = math.max(1, (source.height / blockPx).round());
      final image = await _record(
        width.toDouble(),
        height.toDouble(),
        (canvas) {
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
        },
      );
      _mosaic[blockPx] = image;
      return image;
    } finally {
      _building.remove(tag);
    }
  }

  /// Renders a pre-blurred copy of the source.
  ///
  /// Blurring once into a texture and then sampling it through the mask is both
  /// cheaper and more predictable than applying an `ImageFilter` to every mask
  /// draw: the sigma is resolved against the image, never against the mask's
  /// own bounds.
  Future<ui.Image?> ensureBlur(int sigmaPx) async {
    final source = _source;
    if (source == null) return null;
    final cached = _blur[sigmaPx];
    if (cached != null) return cached;
    final tag = 'blur$sigmaPx';
    if (!_building.add(tag)) return null;
    try {
      final longest = math.max(source.width, source.height).toDouble();
      final scale = math.min(1.0, maxBlurSide / longest);
      final width = math.max(1, (source.width * scale).round());
      final height = math.max(1, (source.height * scale).round());
      final sigma = math.max(0.5, sigmaPx * scale);
      final image = await _record(
        width.toDouble(),
        height.toDouble(),
        (canvas) {
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(
              0,
              0,
              source.width.toDouble(),
              source.height.toDouble(),
            ),
            ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
            ui.Paint()
              ..filterQuality = ui.FilterQuality.medium
              ..imageFilter = ui.ImageFilter.blur(
                sigmaX: sigma,
                sigmaY: sigma,
                tileMode: ui.TileMode.clamp,
              ),
          );
        },
      );
      _blur[sigmaPx] = image;
      return image;
    } finally {
      _building.remove(tag);
    }
  }

  Future<ui.Image> _record(
    double width,
    double height,
    void Function(ui.Canvas canvas) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    paint(canvas);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width.round(), height.round());
    } finally {
      picture.dispose();
    }
  }

  void clear() {
    for (final image in _mosaic.values) {
      image.dispose();
    }
    for (final image in _blur.values) {
      image.dispose();
    }
    _mosaic.clear();
    _blur.clear();
    _building.clear();
  }

  void dispose() {
    clear();
    _source = null;
  }
}
