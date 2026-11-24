import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/services/detector_service.dart';
import 'package:zxing2/qrcode.dart';

/// A tiny RGBA canvas, enough to feed the detectors deterministic input.
class _Canvas {
  _Canvas(this.width, this.height, {int background = 0xF3})
    : rgba = Uint8List(width * height * 4) {
    fill(0, 0, width, height, background, background, background + 4);
  }

  final int width;
  final int height;
  final Uint8List rgba;

  void pixel(int x, int y, int r, int g, int b) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final p = (y * width + x) * 4;
    rgba[p] = r;
    rgba[p + 1] = g;
    rgba[p + 2] = b;
    rgba[p + 3] = 255;
  }

  void fill(int x0, int y0, int x1, int y1, int r, int g, int b) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        pixel(x, y, r, g, b);
      }
    }
  }

  /// A photo-like avatar: a disc of noisy colour.
  void avatar(int x0, int y0, int size, int seed) {
    final random = math.Random(seed);
    final cx = x0 + size / 2;
    final cy = y0 + size / 2;
    final radius = size / 2;
    for (var y = y0; y < y0 + size; y++) {
      for (var x = x0; x < x0 + size; x++) {
        final d = math.sqrt(
          math.pow(x - cx + 0.5, 2) + math.pow(y - cy + 0.5, 2),
        );
        if (d > radius) continue;
        final tone = 40 + random.nextInt(190);
        pixel(
          x,
          y,
          tone,
          (tone + random.nextInt(60)).clamp(0, 255),
          (255 - tone + random.nextInt(40)).clamp(0, 255),
        );
      }
    }
  }

  /// Emulates a line of glyphs: strokes are thin, with white between them.
  void textLine(int x0, int y0, int x1, int height) {
    final random = math.Random(x0 * 31 + y0);
    for (var x = x0; x < x1; x++) {
      final isStroke = (x ~/ 3) % 3 != 2 && random.nextInt(5) != 0;
      if (!isStroke) continue;
      for (var y = y0; y < y0 + height; y++) {
        if (y == y0 || y == y0 + height - 1) continue;
        pixel(x, y, 40, 40, 45);
      }
    }
  }
}

void main() {
  const width = 360;
  const height = 640;

  group('avatar detection', () {
    test('finds a repeating column of avatars and ignores the text beside it', () {
      final canvas = _Canvas(width, height, background: 246);
      // Three incoming messages: avatar on the left, bubble of text to its right.
      for (var i = 0; i < 3; i++) {
        final top = 60 + i * 140;
        canvas.avatar(14, top, 40, i);
        canvas.fill(64, top, 330, top + 56, 255, 255, 255);
        for (var line = 0; line < 3; line++) {
          canvas.textLine(74, top + 8 + line * 16, 300, 11);
        }
      }

      final found = DetectorService.findAvatars(
        canvas.rgba,
        canvas.width,
        canvas.height,
      );

      expect(found, isNotEmpty, reason: 'three aligned avatars should be found');
      // Every avatar sits at x = 14..54, i.e. 0.039..0.15 normalized.
      for (final rect in found) {
        expect(rect.left, closeTo(14 / width, 0.035));
        expect(rect.width, closeTo(40 / width, 0.03));
      }
      expect(found.length, greaterThanOrEqualTo(3));
    });

    test('a lone blob is not an avatar', () {
      final canvas = _Canvas(width, height, background: 246);
      canvas.avatar(14, 60, 40, 7);
      expect(
        DetectorService.findAvatars(canvas.rgba, canvas.width, canvas.height),
        isEmpty,
        reason: 'chat avatars repeat; a single blob is just content',
      );
    });

    test('a page of plain text produces nothing', () {
      final canvas = _Canvas(width, height, background: 250);
      for (var line = 0; line < 22; line++) {
        canvas.textLine(20, 20 + line * 26, 330, 13);
      }
      expect(
        DetectorService.findAvatars(canvas.rgba, canvas.width, canvas.height),
        isEmpty,
      );
    });
  });

  group('QR detection', () {
    test('locates a symbol and returns a box around it', () {
      final canvas = _Canvas(width, height, background: 255);
      final code = Encoder.encode(
        'https://github.com/mlkgrnt/Velatus',
        ErrorCorrectionLevel.m,
      );
      final matrix = code.matrix!;
      const scale = 8;
      const quiet = 4;
      final originX = 40;
      final originY = 380;
      final side = (matrix.width + quiet * 2) * scale;
      canvas.fill(originX, originY, originX + side, originY + side, 255, 255, 255);
      for (var y = 0; y < matrix.height; y++) {
        for (var x = 0; x < matrix.width; x++) {
          if (matrix.get(x, y) != 1) continue;
          canvas.fill(
            originX + (x + quiet) * scale,
            originY + (y + quiet) * scale,
            originX + (x + quiet + 1) * scale,
            originY + (y + quiet + 1) * scale,
            0,
            0,
            0,
          );
        }
      }

      final found = DetectorService.findQrCodes(
        canvas.rgba,
        canvas.width,
        canvas.height,
      );

      expect(found, hasLength(1));
      final box = found.single;
      // The detector boxes the symbol itself, not the white quiet zone around
      // it, so the expectation starts after the quiet zone too.
      final symbolLeft = originX + quiet * scale;
      final symbolTop = originY + quiet * scale;
      final symbolSide = matrix.width * scale;
      // A few modules of slack: the box is derived from the three finder
      // patterns, not from the exact symbol edge.
      expect(box.left, closeTo(symbolLeft / width, 0.035));
      expect(box.top, closeTo(symbolTop / height, 0.035));
      expect(box.right, closeTo((symbolLeft + symbolSide) / width, 0.05));
      expect(
        box.bottom,
        closeTo((symbolTop + symbolSide) / height, 0.05),
      );
    });

    test('an image without a code returns nothing', () {
      final canvas = _Canvas(width, height, background: 240);
      for (var line = 0; line < 18; line++) {
        canvas.textLine(20, 30 + line * 30, 330, 14);
      }
      expect(
        DetectorService.findQrCodes(canvas.rgba, canvas.width, canvas.height),
        isEmpty,
      );
    });
  });
}
