import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:velatus/domain/mask_region.dart';
import 'package:velatus/services/image_exporter.dart';
import 'package:velatus/services/image_loader.dart';

/// A 240×320 PNG with a white background and a red block, as raw bytes.
Uint8List _sourcePng() {
  final frame = img.Image(width: 240, height: 320);
  img.fill(frame, color: img.ColorRgb8(255, 255, 255));
  img.fillRect(
    frame,
    x1: 20,
    y1: 40,
    x2: 220,
    y2: 90,
    color: img.ColorRgb8(220, 40, 40),
  );
  return Uint8List.fromList(img.encodePng(frame));
}

void main() {
  testWidgets('export bakes the masks and returns a real JPEG', (tester) async {
    late ExportResult result;
    await tester.runAsync(() async {
      final source = await ImageLoader.fromBytes(
        _sourcePng(),
        name: 'test.png',
      );
      result = await ImageExporter.render(
        source: source,
        regions: const [
          MaskRegion(
            id: 'a',
            style: MaskStyle.solid,
            shape: MaskShape.rect,
            points: [Offset(0.1, 0.1), Offset(0.9, 0.2)],
            color: Color(0xFF12141A),
          ),
          MaskRegion(
            id: 'b',
            style: MaskStyle.mosaic,
            shape: MaskShape.rect,
            points: [Offset(0.1, 0.3), Offset(0.9, 0.45)],
            strength: 0.8,
          ),
        ],
      );
    });

    // Full-resolution output, not the preview.
    expect(result.width, 240);
    expect(result.height, 320);
    // A JPEG starts with SOI, and the encoder never returns a tiny stub.
    expect(result.bytes[0], 0xFF);
    expect(result.bytes[1], 0xD8);
    expect(result.bytes.length, greaterThan(1000));

    // The bytes have to decode back to an image of the same size.
    final decoded = img.decodeImage(result.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, 240);
    expect(decoded.height, 320);
  });

  testWidgets('export writes PNG when asked', (tester) async {
    late ExportResult result;
    await tester.runAsync(() async {
      final source = await ImageLoader.fromBytes(_sourcePng(), name: 't.png');
      result = await ImageExporter.render(
        source: source,
        regions: const [
          MaskRegion(
            id: 'a',
            style: MaskStyle.blur,
            shape: MaskShape.rect,
            points: [Offset(0.2, 0.2), Offset(0.8, 0.4)],
          ),
        ],
        format: ExportFormat.png,
      );
    });

    expect(result.bytes.sublist(1, 4), [0x50, 0x4E, 0x47]); // PNG
    expect(img.decodeImage(result.bytes)!.width, 240);
  });

  testWidgets('exported pixels contain the redaction', (tester) async {
    late ExportResult result;
    await tester.runAsync(() async {
      final source = await ImageLoader.fromBytes(_sourcePng(), name: 't.png');
      result = await ImageExporter.render(
        source: source,
        regions: const [
          MaskRegion(
            id: 'a',
            style: MaskStyle.solid,
            shape: MaskShape.rect,
            points: [Offset(0.0, 0.0), Offset(1.0, 0.25)],
            color: Color(0xFF12141A),
          ),
        ],
        format: ExportFormat.png,
      );
    });

    final decoded = img.decodeImage(result.bytes)!;
    // Top band: the solid colour. Middle: untouched white.
    final top = decoded.getPixel(120, 20);
    final middle = decoded.getPixel(120, 200);
    expect(top.r, closeTo(0x12, 6));
    expect(top.g, closeTo(0x14, 6));
    expect(top.b, closeTo(0x1A, 6));
    expect(middle.r, 255);
    expect(middle.g, 255);
    expect(middle.b, 255);
  });
}
