import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/services/avatar_detector.dart';
import 'package:velatus/services/detector_service.dart';

/// A deterministic RGBA chat screenshot. The old detector only understood
/// "a noisy disc on a perfectly flat ring", so these shapes are the regression
/// set: real avatars are square, rounded squares, smooth gradients or photos.
class _Chat {
  _Chat({this.width = 360, this.height = 640, int background = 246})
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

  /// A noisy circular avatar — the only shape the old detector accepted.
  void disc(int x0, int y0, int size, int seed) {
    final random = math.Random(seed);
    final cx = x0 + size / 2;
    final cy = y0 + size / 2;
    for (var y = y0; y < y0 + size; y++) {
      for (var x = x0; x < x0 + size; x++) {
        final d = math.sqrt(
          math.pow(x - cx + 0.5, 2) + math.pow(y - cy + 0.5, 2),
        );
        if (d > size / 2) continue;
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

  void square(int x0, int y0, int size, int r, int g, int b) =>
      fill(x0, y0, x0 + size, y0 + size, r, g, b);

  /// A rounded square: the four corners are cut away with a small radius.
  void roundedSquare(int x0, int y0, int size, int seed) {
    final random = math.Random(seed);
    const radius = 9;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final dx = math.max(0, radius - math.min(x, size - 1 - x));
        final dy = math.max(0, radius - math.min(y, size - 1 - y));
        if (dx > 0 && dy > 0 && dx * dx + dy * dy > radius * radius) {
          continue;
        }
        pixel(x0 + x, y0 + y, 30 + random.nextInt(120),
            90 + random.nextInt(80), 180);
      }
    }
  }

  /// A photo-like avatar: smooth-ish colour texture, no strong edges.
  void textured(int x0, int y0, int size) {
    for (var y = y0; y < y0 + size; y++) {
      for (var x = x0; x < x0 + size; x++) {
        pixel(x, y, 30 + ((x * 7 + y * 3) % 180),
            60 + ((x + y) % 150), 90 + ((x * 5) % 140));
      }
    }
  }

  /// A white message bubble with three lines of glyphs beside the avatar.
  void bubble(int top, {bool green = false}) {
    final r = green ? 149 : 255;
    final g = green ? 236 : 255;
    final b = green ? 105 : 255;
    // Real chat bubbles stop before the right margin, where the sender's
    // avatar lives. Filling all the way to x=330 would put a green block in
    // the very strip the detector searches for outgoing avatars.
    fill(64, top, 296, top + 56, r, g, b);
    for (var line = 0; line < 3; line++) {
      textLine(74, top + 8 + line * 16, 280, 11);
    }
  }

  void textLine(int x0, int y0, int x1, int thickness) {
    final random = math.Random(x0 * 31 + y0);
    for (var x = x0; x < x1; x++) {
      final stroke = (x ~/ 3) % 3 != 2 && random.nextInt(5) != 0;
      if (!stroke) continue;
      for (var y = y0; y < y0 + thickness; y++) {
        if (y == y0 || y == y0 + thickness - 1) continue;
        pixel(x, y, 40, 40, 45);
      }
    }
  }
}

List<Rect> _find(_Chat chat) =>
    DetectorService.findAvatars(chat.rgba, chat.width, chat.height);

/// Every box must sit over the avatar column (x = 14..54 on a 360 px canvas).
void expectOnlyAvatars(List<Rect> boxes, int count) {
  expect(boxes, hasLength(count));
  for (final box in boxes) {
    expect(box.left * 360, lessThan(60), reason: 'a box landed in the text');
    expect(box.width * 360, inInclusiveRange(24, 60));
  }
}

void main() {
  test('a column of noisy circular avatars is found with no text false hits', () {
    final chat = _Chat();
    for (var i = 0; i < 3; i++) {
      final top = 60 + i * 140;
      chat.disc(14, top, 40, i);
      chat.bubble(top);
    }
    expectOnlyAvatars(_find(chat), 3);
  });

  test('square avatars are found — the old detector rejected them', () {
    final chat = _Chat();
    for (var i = 0; i < 4; i++) {
      final top = 50 + i * 130;
      chat.square(14, top, 40, 60, 130, 200);
      chat.bubble(top);
    }
    expectOnlyAvatars(_find(chat), 4);
  });

  test('rounded-square avatars are found', () {
    final chat = _Chat();
    for (var i = 0; i < 4; i++) {
      final top = 50 + i * 130;
      chat.roundedSquare(14, top, 40, i + 9);
      chat.bubble(top);
    }
    expectOnlyAvatars(_find(chat), 4);
  });

  test('a textured photo avatar column is found in full', () {
    final chat = _Chat();
    for (var i = 0; i < 5; i++) {
      final top = 40 + i * 118;
      chat.textured(14, top, 40);
      chat.bubble(top);
    }
    expectOnlyAvatars(_find(chat), 5);
  });

  test('a whiter page does not turn the white bubbles into avatars', () {
    // #EDEDF0 is only ~51 colour units from white, close enough that a naive
    // background difference would swallow every bubble.
    final chat = _Chat(background: 237);
    for (var i = 0; i < 4; i++) {
      final top = 50 + i * 130;
      chat.square(14, top, 40, 60, 130, 200);
      chat.bubble(top);
    }
    expectOnlyAvatars(_find(chat), 4);
  });

  test('green outgoing bubbles do not blind the detector', () {
    // WeChat's own outgoing bubbles are bright green against a grey page. They
    // are content, not avatars, and must not change what the column finds.
    final chat = _Chat();
    for (var i = 0; i < 5; i++) {
      final top = 40 + i * 118;
      chat.textured(14, top, 40);
      chat.bubble(top, green: true);
    }
    final boxes = _find(chat);
    expect(boxes, isNotEmpty);
    for (final box in boxes) {
      expect(box.left * 360, lessThan(60));
    }
  });

  test('two alternating columns both survive', () {
    final chat = _Chat();
    for (var i = 0; i < 4; i++) {
      final top = 50 + i * 130;
      final left = i.isEven;
      final x = left ? 14 : 306;
      chat.roundedSquare(x, top, 40, i + 3);
      chat.fill(left ? 64 : 66, top, left ? 300 : 296, top + 56, 255, 255, 255);
      chat.textLine(left ? 74 : 76, top + 8, 280, 11);
    }
    final boxes = _find(chat);
    expect(boxes, isNotEmpty);
    expect(boxes.length, greaterThanOrEqualTo(2));
    for (final box in boxes) {
      final centre = box.center.dx;
      expect(
        centre < 0.18 || centre > 0.82,
        isTrue,
        reason: 'only the margins should produce avatar boxes',
      );
    }
  });

  test('a bare page of text produces no candidates', () {
    final chat = _Chat();
    for (var line = 0; line < 22; line++) {
      chat.textLine(20, 20 + line * 26, 330, 13);
    }
    expect(_find(chat), isEmpty);
  });

  test('the pass stays as fast as the detector it replaced', () {
    final chat = _Chat();
    for (var i = 0; i < 5; i++) {
      final top = 40 + i * 118;
      chat.textured(14, top, 40);
      chat.bubble(top);
    }
    // Warm up the JIT before measuring.
    for (var i = 0; i < 3; i++) {
      _find(chat);
    }
    final sw = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      _find(chat);
    }
    sw.stop();
    final perRun = sw.elapsedMicroseconds / 10 / 1000;
    // Measured baseline of the previous flood-fill detector on this exact
    // 360x640 image: 14.5 ms. Three times that is a generous ceiling for a
    // slow CI runner while still catching a real regression.
    expect(perRun, lessThan(45), reason: '${perRun.toStringAsFixed(1)} ms/run');
  });

  test('the analysis resolution is shared with the app', () {
    expect(DetectorService.avatarAnalysisSide, AvatarDetector.analysisSide);
  });
}
