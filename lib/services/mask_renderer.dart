import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../domain/mask_region.dart';

/// Resolved offscreen textures for one paint pass.
///
/// The renderer never builds them itself; the caller owns the cache so that
/// preview and export can share the exact same drawing code while using
/// differently sized sources.
class MaskTextures {
  const MaskTextures({this.mosaic, this.blur});

  /// Returns the pixelated copy for a block size, or null while it renders.
  final ui.Image? Function(int blockPx)? mosaic;

  /// Returns the pre-blurred copy for a sigma, or null while it renders.
  final ui.Image? Function(int sigmaPx)? blur;

  static const MaskTextures none = MaskTextures();
}

/// Draws mask effects. The same code path is used for the interactive preview
/// and for the full-resolution export, which is what keeps "what you see" and
/// "what you get" identical.
class MaskRenderer {
  const MaskRenderer._();

  /// Block edge in pixels for a given strength, relative to the shorter side of
  /// the image.
  ///
  /// The curve is deliberately aggressive: a redaction has to dissolve glyphs,
  /// not merely roughen them. At the default 0.65 strength a 1080 px screenshot
  /// gets ~29 px blocks, which is wider than a line of body text and therefore
  /// unreadable; the old, gentler curve left phone numbers legible.
  static int mosaicBlockPx(double strength, double shortSide) {
    final relative = 0.007 + 0.030 * strength.clamp(0.0, 1.0);
    return math.max(3, (shortSide * relative).round());
  }

  /// Gaussian sigma in pixels for a given strength.
  static double blurSigmaPx(double strength, double shortSide) {
    final relative = 0.003 + 0.018 * strength.clamp(0.0, 1.0);
    return math.max(1.0, shortSide * relative);
  }

  static void paintRegions(
    ui.Canvas canvas,
    ui.Rect imageRect,
    ui.Image source,
    List<MaskRegion> regions, {
    MaskTextures textures = MaskTextures.none,
  }) {
    for (final region in regions) {
      paintRegion(canvas, imageRect, source, region, textures: textures);
    }
  }

  static void paintRegion(
    ui.Canvas canvas,
    ui.Rect imageRect,
    ui.Image source,
    MaskRegion region, {
    MaskTextures textures = MaskTextures.none,
  }) {
    if (!region.visible || region.points.isEmpty) return;
    final path = region.toPath(imageRect);
    final bounds = path.getBounds();
    // A perfectly horizontal or vertical brush stroke has a zero-height (or
    // zero-width) bounding box, which `Rect.isEmpty` treats as empty even
    // though there is a stroke to draw. Only fill shapes are truly degenerate.
    if (bounds.isEmpty && !region.isStroke) return;

    // Every effect is resolved against the *image*, never against the mask's
    // own rectangle. That is what allows the strength slider to change how
    // coarse the mask looks without also changing how much of the photo it
    // covers.
    final sourceShortSide = math.min(
      source.width.toDouble(),
      source.height.toDouble(),
    );
    final strokeWidth = region.isStroke
        ? region.size * imageRect.shortestSide
        : 0.0;

    final paint = ui.Paint()..isAntiAlias = true;
    switch (region.style) {
      case MaskStyle.solid:
        paint.color = region.color;
      case MaskStyle.mosaic:
        final block = mosaicBlockPx(region.strength, sourceShortSide);
        final texture = textures.mosaic?.call(block);
        paint.shader = texture != null
            ? ui.ImageShader(
                texture,
                ui.TileMode.clamp,
                ui.TileMode.clamp,
                _matrixFor(texture, imageRect),
                filterQuality: ui.FilterQuality.none,
              )
            : _coarseSampler(source, imageRect, block.toDouble());
      case MaskStyle.blur:
        final sigma = blurSigmaPx(region.strength, sourceShortSide);
        final texture = textures.blur?.call(sigma.round());
        paint.shader = texture != null
            ? ui.ImageShader(
                texture,
                ui.TileMode.clamp,
                ui.TileMode.clamp,
                _matrixFor(texture, imageRect),
                filterQuality: ui.FilterQuality.medium,
              )
            // Until the blurred copy is ready, sample the photo coarsely so a
            // freshly drawn region never shows the original pixels.
            : _coarseSampler(source, imageRect, sigma);
    }

    if (region.isStroke) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }

    canvas.save();
    canvas.clipRect(imageRect);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  /// Outline, bounding frame and corner handles for the selected region.
  static void paintSelection(
    ui.Canvas canvas,
    ui.Rect imageRect,
    MaskRegion region, {
    required Color accent,
    bool handles = true,
  }) {
    if (region.points.isEmpty) return;
    final path = region.toPath(imageRect);
    final bounds = path.getBounds();
    if (bounds.isEmpty && !region.isStroke) return;

    // A brush stroke is already as wide as the mask itself. Outlining it at
    // that width would paint over the mosaic the user is trying to inspect, so
    // strokes get a thin centreline instead of a fat ring.
    final baseWidth = region.isStroke ? 1.5 : 2.0;

    // Halo, so the outline survives on both light and dark photos.
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseWidth + 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xE6FFFFFF)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 1.2),
    );
    canvas.drawPath(
      path,
      ui.Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = baseWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );

    if (!handles) return;

    final strokePad = region.isStroke
        ? region.size * imageRect.shortestSide / 2
        : 0.0;
    final frame = bounds.inflate(strokePad);
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(3));
    canvas.drawRRect(
      rrect,
      ui.Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = accent.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      rrect,
      ui.Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..color = const Color(0x66FFFFFF),
    );
    for (final corner in [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight,
    ]) {
      canvas.drawCircle(
        corner,
        5.4,
        ui.Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawCircle(
        corner,
        5.4,
        ui.Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = accent,
      );
    }
  }

  /// Maps the texture onto [rect] in local canvas coordinates.
  static Float64List _matrixFor(ui.Image texture, Rect rect) {
    final scaleX = rect.width / texture.width;
    final scaleY = rect.height / texture.height;
    // Column-major, i.e. translate * scale.
    return Float64List.fromList(<double>[
      scaleX, 0, 0, 0, //
      0, scaleY, 0, 0, //
      0, 0, 1, 0, //
      rect.left, rect.top, 0, 1,
    ]);
  }

  /// Nearest-neighbour sampling of the source at [stride] destination pixels
  /// per sample. Used only as an instant stand-in while a real texture renders.
  static ImageShader _coarseSampler(
    ui.Image source,
    Rect imageRect,
    double stride,
  ) {
    final step = math.max(1.0, stride);
    // `ImageShader` maps texture pixels to local coordinates, so a texture
    // pixel covers `step` destination pixels and nearest sampling quantises
    // every block to its first source pixel.
    return ui.ImageShader(
      source,
      ui.TileMode.clamp,
      ui.TileMode.clamp,
      Float64List.fromList(<double>[
        imageRect.width * step / source.width, 0, 0, 0, //
        0, imageRect.height * step / source.height, 0, 0, //
        0, 0, 1, 0, //
        imageRect.left, imageRect.top, 0, 1,
      ]),
      filterQuality: ui.FilterQuality.none,
    );
  }
}
