import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/domain/mask_region.dart';
import 'package:velatus/services/mask_renderer.dart';

/// Renders [regions] over a flat white 200×200 canvas and hands back the raw
/// RGBA bytes.
///
/// The renderer is a pure `Canvas` consumer, so this is the cheapest way to
/// assert what actually lands on screen — and it is the same code path the
/// interactive preview and the full-resolution export share.
Future<ByteData> _render(
  WidgetTester tester,
  List<MaskRegion> regions,
) async {
  late ByteData data;
  await tester.runAsync(() async {
    final sourceRecorder = ui.PictureRecorder();
    final sourceCanvas = Canvas(sourceRecorder);
    sourceCanvas.drawRect(
      const Rect.fromLTWH(0, 0, 120, 120),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final source = await sourceRecorder.endRecording().toImage(120, 120);

    const imageRect = Rect.fromLTWH(0, 0, 200, 200);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(imageRect, Paint()..color = const Color(0xFFFFFFFF));
    MaskRenderer.paintRegions(canvas, imageRect, source, regions);
    final picture = recorder.endRecording();
    final output = await picture.toImage(200, 200);
    data = (await output.toByteData(format: ui.ImageByteFormat.rawRgba))!;
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
        color: Color(0xFF12141A),
      ),
    ]);

    // Inside: the redaction colour.
    expect(_pixel(data, 60, 60), (r: 0x12, g: 0x14, b: 0x1A));
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
        color: Color(0xFF12141A),
      ),
    ]);

    // On the stroke.
    expect(_pixel(data, 100, 100), (r: 0x12, g: 0x14, b: 0x1A));
    // Well above and below the stroke.
    expect(_pixel(data, 100, 20), (r: 0xFF, g: 0xFF, b: 0xFF));
    expect(_pixel(data, 100, 180), (r: 0xFF, g: 0xFF, b: 0xFF));
  });

  testWidgets('mosaic and blur regions stay inside their bounds', (
    tester,
  ) async {
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

    expect(_pixel(data, 180, 180), (r: 0xFF, g: 0xFF, b: 0xFF));
    expect(_pixel(data, 120, 40), (r: 0xFF, g: 0xFF, b: 0xFF));
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
