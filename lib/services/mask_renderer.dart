import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../domain/mask_region.dart';

typedef MosaicTextureLookup = ui.Image? Function(int blockPx);

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
    MosaicTextureLookup? texture,
  }) {
    for (final region in regions) {
      paintRegion(canvas, imageRect, source, region, texture: texture);
    }
  }

  static void paintRegion(
    ui.Canvas canvas,
    ui.Rect imageRect,
    ui.Image source,
    MaskRegion region, {
    MosaicTextureLookup? texture,
  }) {
    if (!region.visible || region.points.isEmpty) return;
    final path = region.toPath(imageRect);
    final bounds = path.getBounds();
    // A perfectly horizontal or vertical brush stroke has a zero-height (or
    // zero-width) bounding box, which `Rect.isEmpty` treats as empty even
    // though there is a stroke to draw. Only fill shapes are truly degenerate.
    if (bounds.isEmpty && !region.isStroke) return;

    // Mosaic block size is derived from the source pixels because the cached
    // texture is built at source resolution. Blur sigma is derived from the
    // destination rect because the filter runs in destination space.
    final sourceShortSide = math.min(
      source.width.toDouble(),
      source.height.toDouble(),
    );
    final sigma = region.style == MaskStyle.blur
        ? blurSigmaPx(region.strength, imageRect.shortestSide)
        : 0.0;
    final strokeWidth = region.isStroke
        ? region.size * imageRect.shortestSide
        : 0.0;

    if (region.style == MaskStyle.solid) {
      // A flat colour needs no offscreen buffer: clipping is both exact and
      // cheap. Blending a solid rect through `dstIn` inside a layer is not
      // reliable (the whole layer gets flattened to the fill colour), so this
      // path deliberately avoids `saveLayer`.
      canvas.save();
      canvas.clipRect(imageRect);
      final paint = ui.Paint()
        ..color = region.color
        ..isAntiAlias = true;
      if (region.isStroke) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, paint);
      } else {
        canvas.clipPath(path);
        canvas.drawRect(imageRect, paint);
      }
      canvas.restore();
      return;
    }

    // The offscreen layer only needs to cover the mask (plus the blur halo and
    // the half stroke width), not the whole photo.
    final pad = math.max(sigma * 2 + 2, strokeWidth / 2 + 2);
    final layerRect = bounds.inflate(pad).intersect(imageRect);
    if (layerRect.isEmpty) return;

    canvas.saveLayer(layerRect, ui.Paint());
    canvas.clipRect(layerRect);

    switch (region.style) {
      case MaskStyle.mosaic:
        final block = mosaicBlockPx(region.strength, sourceShortSide);
        final tex = texture?.call(block);
        if (tex != null) {
          canvas.drawImageRect(
            tex,
            ui.Rect.fromLTWH(0, 0, tex.width.toDouble(), tex.height.toDouble()),
            imageRect,
            ui.Paint()..filterQuality = ui.FilterQuality.none,
          );
        } else {
          // Fallback while the texture is still rendering.
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(
              0,
              0,
              source.width.toDouble(),
              source.height.toDouble(),
            ),
            imageRect,
            ui.Paint()..filterQuality = ui.FilterQuality.low,
          );
        }
      case MaskStyle.blur:
        canvas.drawImageRect(
          source,
          ui.Rect.fromLTWH(
            0,
            0,
            source.width.toDouble(),
            source.height.toDouble(),
          ),
          imageRect,
          ui.Paint()
            ..filterQuality = ui.FilterQuality.low
            ..imageFilter = ui.ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: ui.TileMode.clamp,
            ),
        );
      case MaskStyle.solid:
        break;
    }

    final maskPaint = ui.Paint()
      ..blendMode = ui.BlendMode.dstIn
      ..color = const Color(0xFFFFFFFF)
      ..style = region.isStroke ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.drawPath(path, maskPaint);
    canvas.restore();
  }

  /// Outline for the currently selected region.
  static void paintSelection(
    ui.Canvas canvas,
    ui.Rect imageRect,
    MaskRegion region, {
    required Color accent,
  }) {
    if (region.points.isEmpty) return;
    final path = region.toPath(imageRect);
    if (path.getBounds().isEmpty && !region.isStroke) return;

    // A brush stroke is already as wide as the mask itself. Outlining it at
    // that width would paint over the mosaic the user is trying to inspect, so
    // strokes get a thin centreline instead of a fat ring.
    final baseWidth = region.isStroke ? 1.5 : 2.5;

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
  }
}
