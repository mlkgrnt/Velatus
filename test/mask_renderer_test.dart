import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/domain/mask_region.dart';
import 'package:velatus/services/mask_renderer.dart';
import 'package:velatus/services/mask_texture_cache.dart';

const _imageRect = Rect.fromLTWH(0, 0, 200, 200);

/// Renders [regions] over a white 200×200 canvas with a black 120×120 source,
/// then hands back the raw RGBA bytes.
///
/// The renderer is a pure `Canvas` consumer, so this is the cheapest way to
/// assert what actually lands on screen — and it is the same code path the
/// interactive preview and the full-resolution export share.
Future<ByteData> _render(
  WidgetTester tester,
  List<MaskRegion> regions, {
  bool withTextures = true,
}) async {
  late ByteData data;
  await tester.runAsync(() async {
    final sourceRecorder = ui.PictureRecorder();
    final sourceCanvas = Canvas(sourceRecorder);
    sourceCanvas.drawRect(
      const Rect.fromLTWH(0, 0, 120, 120),
      Paint()..color = const Color(0xFF000000),
    );
    final source = await sourceRecorder.endRecording().toImage(120, 120);

    // Textures are asynchronous in production too; build them up front so the
    // painted frame is the steady state rather than the fallback.
    final cache = MaskTextureCache()..attach(source);
    const shortSide = 120.0;
    for (final region in regions) {
      switch (region.style) {
        case MaskStyle.mosaic:
          await cache.ensureMosaic(
            MaskRenderer.mosaicBlockPx(region.strength, shortSide),
          );
        case MaskStyle.blur:
          await cache.ensureBlur(
            MaskRenderer.blurSigmaPx(region.strength, shortSide).round(),
          );
        case MaskStyle.solid:
          break;
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(_imageRect, Paint()..color = const Color(0xFFFFFFFF));
    MaskRenderer.paintRegions(
      canvas,
      _imageRect,
      source,
      regions,
      textures: withTextures
          ? MaskTextures(mosaic: cache.mosaic, blur: cache.blur)
          : MaskTextures.none,
    );
    final picture = recorder.endRecording();
    final output = await picture.toImage(200, 200);
    data = (await output.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    cache.dispose();
    source.dispose();
  });
  return data;
}

({int r, int g, int b}) _pixel(ByteData data, int x, int y) {
  final i = (y * 200 + x) * 4;
  return (
    r: data.getUint8(i),
    g: data.getUint8(i + 1),
    b: data.getUint8(i + 2),
  );
}

void main() {
  testWidgets('a solid region paints only its own bounds', (tester) async {
    final data = await _render(tester, const [
      MaskRegion(
        id: 'solid',
        style: MaskStyle.solid,
        shape: MaskShape.rect,
        points: [Offset(0.2, 0.2), Offset(0.4, 0.4)],
        color: Color(0xFFB3261E),
      ),
    ]);

    // Inside: the redaction colour.
    expect(_pixel(data, 60, 60), (r: 0xB3, g: 0x26, b: 0x1E));
    // A regression guard: a flat `drawRect` blended with `dstIn` inside a
    // layer used to wipe the entire photo, not just the mask.
    expect(_pixel(data, 150, 150), (r: 0xFF, g: 0xFF, b: 0xFF));
    expect(_pixel(data, 10, 190), (r: 0xFF, g: 0xFF, b: 0xFF));
  });

  testWidgets('a solid brush stroke keeps the rest of the photo', (
    tester,
  ) async {
    final data = await _render(tester, const [
      MaskRegion(
        id: 'stroke',
        style: MaskStyle.solid,
        shape: MaskShape.stroke,
        points: [Offset(0.2, 0.5), Offset(0.8, 0.5)],
        size: 0.1,
        color: Color(0xFFB3261E),
      ),
    ]);

    // On the stroke.
    expect(_pixel(data, 100, 100), (r: 0xB3, g: 0x26, b: 0x1E));
    // Well above and below the stroke.
    expect(_pixel(data, 100, 20), (r: 0xFF, g: 0xFF, b: 0xFF));
    expect(_pixel(data, 100, 180), (r: 0xFF, g: 0xFF, b: 0xFF));
  });

  testWidgets('mosaic and blur stay inside a rectangle', (tester) async {
    final data = await _render(tester, const [
      MaskRegion(
        id: 'mosaic',
        style: MaskStyle.mosaic,
        shape: MaskShape.rect,
        points: [Offset(0.05, 0.05), Offset(0.35, 0.2)],
        strength: 0.8,
      ),
      MaskRegion(
        id: 'blur',
        style: MaskStyle.blur,
        shape: MaskShape.rect,
        points: [Offset(0.05, 0.3), Offset(0.35, 0.45)],
        strength: 0.8,
      ),
    ]);

    // Masked areas show (darkened) photo, everything else stays white.
    expect(_pixel(data, 40, 25).r, lessThan(0x60));
    expect(_pixel(data, 40, 75).r, lessThan(0x60));
    expect(_pixel(data, 180, 180), (r: 0xFF, g: 0xFF, b: 0xFF));
    expect(_pixel(data, 120, 40), (r: 0xFF, g: 0xFF, b: 0xFF));
  });

  testWidgets('a blurred brush stroke does not become a rectangle', (
    tester,
  ) async {
    // The bounds of this stroke are 40..160 × 90..110. If the blur leaked into
    // its bounding rectangle, the pixel at (100, 30) would be darkened too.
    const region = MaskRegion(
      id: 'blur-stroke',
      style: MaskStyle.blur,
      shape: MaskShape.stroke,
      points: [Offset(0.2, 0.5), Offset(0.8, 0.5)],
      size: 0.1,
      strength: 0.9,
    );

    final data = await _render(tester, const [region]);

    expect(_pixel(data, 100, 100).r, lessThan(0x60));
    expect(_pixel(data, 100, 30), (r: 0xFF, g: 0xFF, b: 0xFF));
    expect(_pixel(data, 100, 170), (r: 0xFF, g: 0xFF, b: 0xFF));
    // The round cap reaches x = 30, so probe well before it.
    expect(_pixel(data, 10, 100), (r: 0xFF, g: 0xFF, b: 0xFF));
  });

  testWidgets('changing the strength never changes the masked area', (
    tester,
  ) async {
    // Stroke geometry is fixed: centre line at y = 100 and 20 px wide, so the
    // mask covers y 90..110 whatever the blur strength is.
    Future<({int inside, int edge, int far})> probe(double strength) async {
      final data = await _render(tester, [
        MaskRegion(
          id: 'blur',
          style: MaskStyle.blur,
          shape: MaskShape.stroke,
          points: const [Offset(0.2, 0.5), Offset(0.8, 0.5)],
          size: 0.1,
          strength: strength,
        ),
      ]);
      return (
        inside: _pixel(data, 100, 100).r,
        edge: _pixel(data, 100, 70).r,
        far: _pixel(data, 100, 20).r,
      );
    }

    final low = await probe(0.05);
    final high = await probe(1.0);

    // Covered at both ends of the slider, untouched just outside it.
    expect(low.inside, lessThan(0x60));
    expect(high.inside, lessThan(0x60));
    expect(low.edge, 0xFF);
    expect(high.edge, 0xFF);
    expect(low.far, 0xFF);
    expect(high.far, 0xFF);
  });

  testWidgets('a region paints its shape even before its texture is ready', (
    tester,
  ) async {
    // The old renderer clipped the effect to the mask's bounding rectangle, so
    // a stroke turned into a box for as long as the offscreen layer lived. The
    // shape must come from the path alone.
    final data = await _render(
      tester,
      const [
        MaskRegion(
          id: 'stroke',
          style: MaskStyle.mosaic,
          shape: MaskShape.stroke,
          points: [Offset(0.2, 0.5), Offset(0.8, 0.5)],
          size: 0.1,
        ),
      ],
      withTextures: false,
    );

    expect(_pixel(data, 100, 100).r, lessThan(0x60));
    expect(_pixel(data, 100, 40), (r: 0xFF, g: 0xFF, b: 0xFF));
    expect(_pixel(data, 100, 160), (r: 0xFF, g: 0xFF, b: 0xFF));
  });

  testWidgets('hidden regions are skipped', (tester) async {
    final data = await _render(tester, const [
      MaskRegion(
        id: 'hidden',
        style: MaskStyle.solid,
        shape: MaskShape.rect,
        points: [Offset(0.2, 0.2), Offset(0.8, 0.8)],
        visible: false,
      ),
    ]);

    expect(_pixel(data, 100, 100), (r: 0xFF, g: 0xFF, b: 0xFF));
  });
}
