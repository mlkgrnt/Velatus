import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:zxing2/qrcode.dart';

import '../domain/mask_region.dart';
import 'image_loader.dart';

/// What produced a candidate box.
enum DetectKind { text, avatar, qr }

class DetectException implements Exception {
  DetectException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What one scan found, before the user decides what to keep.
class DetectOutcome {
  const DetectOutcome(this.candidates, this.counts);

  final List<MaskRegion> candidates;
  final Map<DetectKind, int> counts;

  int get total => candidates.length;
  bool get isEmpty => candidates.isEmpty;

  int of(DetectKind kind) => counts[kind] ?? 0;
}

/// Finds the things that usually need hiding.
///
/// Three detectors, deliberately different in nature:
///
///  * **text** — ML Kit's bundled Chinese recogniser. Android only, and there is
///    no way around that: the model is ~11 MB per ABI and its format is opaque.
///  * **avatars** — a pure-Dart geometric pass. Chat avatars are small, roughly
///    square, sit in the left or right margin and repeat down a column; that is
///    enough signal to find them without shipping another model.
///  * **QR codes** — zxing2, ~200 KB of Dart, which hands back the three finder
///    patterns so the resulting box is the real symbol, not a guess.
///
/// Nothing here decides anything. Every candidate is returned unapplied so the
/// user can pick, which is also what makes the heuristics acceptable: a false
/// positive costs one unchecked box, not a wrongly covered photo.
class DetectorService {
  const DetectorService._();

  /// Text recognition needs the Android ML Kit runtime. Avatars and QR codes
  /// are plain Dart and work everywhere, including the desktop build.
  static bool get supportsText => Platform.isAndroid;

  static Future<DetectOutcome> detect(
    LoadedImage image, {
    required MaskStyle style,
    required double strength,
    required double radius,
    required Color color,
  }) async {
    final counts = <DetectKind, int>{};
    final found = <DetectKind, List<Rect>>{};

    // The two pixel passes want different working resolutions, so they
    // downsample independently and share nothing but the preview.
    final pixelPasses = await Future.wait([
      _runQr(image),
      _runAvatars(image),
    ]);
    found[DetectKind.qr] = pixelPasses[0];
    found[DetectKind.avatar] = pixelPasses[1];
    if (supportsText) {
      found[DetectKind.text] = await _detectText(image);
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final candidates = <MaskRegion>[];
    // Text first, then QR, then avatars: same order as the counts, and the
    // order the boxes stack on the canvas.
    for (final kind in DetectKind.values) {
      final rects = found[kind];
      if (rects == null || rects.isEmpty) continue;
      counts[kind] = rects.length;
      for (var i = 0; i < rects.length; i++) {
        final rect = rects[i];
        candidates.add(
          MaskRegion(
            id: '${MaskRegion.detectedIdPrefix}${kind.name}_${stamp}_$i',
            style: style,
            // Always a box: a detector returns an area, and the corner radius
            // comes straight from the tool so "what I picked" and "what gets
            // applied" agree.
            shape: MaskShape.box,
            points: [rect.topLeft, rect.bottomRight],
            strength: strength,
            radius: radius,
            color: color,
          ),
        );
      }
    }

    return DetectOutcome(candidates, counts);
  }

  // ------------------------------------------------------------------- text

  static Future<List<Rect>> _detectText(LoadedImage image) async {
    final path = image.path;
    if (path == null || !File(path).existsSync()) {
      throw DetectException('The source file is no longer available');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      final rects = <Rect>[];
      for (final block in recognized.blocks) {
        if (block.text.trim().isEmpty) continue;
        final box = block.boundingBox;
        if (box.width <= 1 || box.height <= 1) continue;

        // A small margin keeps descenders and anti-aliased edges covered.
        final padX = box.width * 0.02 + 2;
        final padY = box.height * 0.08 + 2;
        final rect = Rect.fromLTRB(
          ((box.left - padX) / image.width).clamp(0.0, 1.0),
          ((box.top - padY) / image.height).clamp(0.0, 1.0),
          ((box.right + padX) / image.width).clamp(0.0, 1.0),
          ((box.bottom + padY) / image.height).clamp(0.0, 1.0),
        );
        if (rect.width < 0.005 || rect.height < 0.005) continue;
        rects.add(rect);
      }
      return rects;
    } catch (error) {
      throw DetectException('$error');
    } finally {
      await recognizer.close();
    }
  }

  // ------------------------------------------------------------------ qr

  static Future<List<Rect>> _runQr(LoadedImage image) async {
    final rgba = await _analysisPixels(image, maxSide: 900);
    if (rgba == null) return const [];
    return Isolate.run(() {
      final found = findQrCodes(rgba.$1, rgba.$2, rgba.$3);
      return [for (final rect in found) [rect.left, rect.top, rect.right, rect.bottom]];
    }).then((boxes) => [
      for (final box in boxes)
        Rect.fromLTRB(box[0], box[1], box[2], box[3]),
    ]);
  }

  // -------------------------------------------------------------- avatars

  static Future<List<Rect>> _runAvatars(LoadedImage image) async {
    final rgba = await _analysisPixels(image, maxSide: 720);
    if (rgba == null) return const [];
    return Isolate.run(() {
      final found = findAvatars(rgba.$1, rgba.$2, rgba.$3);
      return [for (final rect in found) [rect.left, rect.top, rect.right, rect.bottom]];
    }).then((boxes) => [
      for (final box in boxes)
        Rect.fromLTRB(box[0], box[1], box[2], box[3]),
    ]);
  }

  /// Downscales the already-decoded preview and hands back straight RGBA.
  ///
  /// Going through the preview instead of re-reading the file keeps peak memory
  /// at one small bitmap: a 5000 px photo costs the same as a screenshot here.
  @visibleForTesting
  static Future<(Uint8List, int, int)?> analysisPixels(
    LoadedImage image, {
    required int maxSide,
  }) => _analysisPixels(image, maxSide: maxSide);

  static Future<(Uint8List, int, int)?> _analysisPixels(
    LoadedImage image, {
    required int maxSide,
  }) async {
    final source = image.preview;
    final scale = math.min(
      1.0,
      maxSide / math.max(source.width, source.height),
    );
    final width = math.max(1, (source.width * scale).round());
    final height = math.max(1, (source.height * scale).round());

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    Image? resized;
    try {
      resized = await picture.toImage(width, height);
      final data = await resized.toByteData(
        format: ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return null;
      return (data.buffer.asUint8List(), width, height);
    } finally {
      picture.dispose();
      resized?.dispose();
    }
  }

  // ------------------------------------------------------- pure algorithms

  /// Locates QR symbols and returns one box per symbol.
  ///
  /// Works on a small RGBA buffer so it can run in a background isolate.
  static List<Rect> findQrCodes(Uint8List rgba, int width, int height) {
    final pixels = Int32List(width * height);
    for (var i = 0, p = 0; i < pixels.length; i++, p += 4) {
      pixels[i] =
          (0xFF << 24) |
          (rgba[p] << 16) |
          (rgba[p + 1] << 8) |
          rgba[p + 2];
    }

    final source = RGBLuminanceSource(width, height, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final reader = QRCodeReader();
    try {
      final result = reader.decode(bitmap);
      final points = result.resultPoints;
      final rect = _qrBounds(points, result.version, width, height);
      return rect == null ? const [] : [rect];
    } on ReaderException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// The three finder patterns sit 3.5 modules inside the symbol, so the box
  /// around them is a known amount smaller than the code itself.
  static Rect? _qrBounds(
    List<ResultPoint> points,
    int? version,
    int width,
    int height,
  ) {
    if (points.isEmpty) return null;
    var minX = points.first.x, maxX = points.first.x;
    var minY = points.first.y, maxY = points.first.y;
    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    final span = math.max(maxX - minX, maxY - minY);
    if (span < 4) return null;

    // Finder centres span `dimension - 7` modules; the symbol itself is
    // `dimension` modules wide.
    final dimension = version == null ? null : 17 + 4 * version;
    final module = dimension == null
        ? span / 21
        : span / (dimension - 7).clamp(7, 200);
    // A little extra so a rounded, antialiased edge is covered.
    final margin = math.max(module * 4.0, span * 0.06);

    final rect = Rect.fromLTRB(
      ((minX - margin) / width).clamp(0.0, 1.0),
      ((minY - margin) / height).clamp(0.0, 1.0),
      ((maxX + margin) / width).clamp(0.0, 1.0),
      ((maxY + margin) / height).clamp(0.0, 1.0),
    );
    final minSpan = 24 / math.max(width, height);
    if (rect.width < minSpan || rect.height < minSpan) return null;
    return rect;
  }

  /// Finds chat avatars: small, roughly square, isolated from the surrounding
  /// layout, and repeated down a column.
  ///
  /// The signal is a window whose interior is busy but whose immediate ring is
  /// empty. Text inside a bubble fails that test — its ring is busy too — and a
  /// single isolated blob is discarded unless the same column repeats, which is
  /// exactly the property the user described.
  static List<Rect> findAvatars(Uint8List rgba, int width, int height) {
    if (width < 40 || height < 40) return const [];
    final lum = _luminance(rgba, width, height);
    final stride = width + 1;
    final integral = Int32List(stride * (height + 1));
    for (var y = 0; y < height; y++) {
      var rowSum = 0;
      final rowOffset = y * width;
      for (var x = 0; x < width; x++) {
        final left = x > 0 ? lum[rowOffset + x - 1] : lum[rowOffset + x];
        final right = x < width - 1
            ? lum[rowOffset + x + 1]
            : lum[rowOffset + x];
        final up = y > 0 ? lum[rowOffset - width + x] : lum[rowOffset + x];
        final down = y < height - 1
            ? lum[rowOffset + width + x]
            : lum[rowOffset + x];
        rowSum += (right - left).abs() + (down - up).abs();
        integral[(y + 1) * stride + x + 1] =
            integral[y * stride + x + 1] + rowSum;
      }
    }

    int areaSum(int x0, int y0, int x1, int y1) {
      if (x1 <= x0 || y1 <= y0) return 0;
      return integral[y1 * stride + x1] -
          integral[y0 * stride + x1] -
          integral[y1 * stride + x0] +
          integral[y0 * stride + x0];
    }

    // A phone screenshot spends ~9-13 % of its width on an avatar; the extra
    // scales cover tablets, contact lists and avatars inside forwarded images.
    final shortSide = math.min(width, height);
    final sizes = <int>{
      for (final fraction in const [0.05, 0.065, 0.08, 0.095, 0.115, 0.14])
        math.max(10, (shortSide * fraction).round()),
    };

    final candidates = <_Candidate>[];
    for (final size in sizes) {
      // A thin ring, deliberately: in a chat the avatar sits ~20 % of its own
      // width away from the bubble, so a ring of a fifth of the box would reach
      // into the text and disqualify every real avatar.
      const ring = 2;
      final step = math.max(2, size ~/ 5);
      // Avatars live at the edges of a chat: the whole point is that they line
      // up in a column, and columns of anything in the middle of a screenshot
      // are far more likely to be content.
      for (final strip in [
        (0, math.max(0, (width * 0.34).round() - size)),
        ((width * 0.62).round(), math.max(0, width - size)),
      ]) {
        if (strip.$2 <= strip.$1) continue;
        for (var y = 0; y + size < height; y += step) {
          for (var x = strip.$1; x <= strip.$2; x += step) {
            final innerSum = areaSum(x, y, x + size, y + size);
            final outerSum = areaSum(
              math.max(0, x - ring),
              math.max(0, y - ring),
              math.min(width, x + size + ring),
              math.min(height, y + size + ring),
            );
            final innerArea = size * size;
            final outerArea =
                (math.min(width, x + size + ring) -
                    math.max(0, x - ring)) *
                (math.min(height, y + size + ring) -
                    math.max(0, y - ring));
            final ringArea = math.max(1, outerArea - innerArea);
            final inner = innerSum / innerArea;
            final ringMean = (outerSum - innerSum) / ringArea;
            if (inner < 15) continue;
            if (inner < ringMean * 1.7 + 3) continue;
            candidates.add(
              _Candidate(
                Rect.fromLTWH(
                  x.toDouble(),
                  y.toDouble(),
                  size.toDouble(),
                  size.toDouble(),
                ),
                inner - ringMean * 1.4,
              ),
            );
          }
        }
      }
    }
    if (candidates.isEmpty) return const [];

    candidates.sort((a, b) => b.score.compareTo(a.score));
    final kept = <_Candidate>[];
    for (final candidate in candidates) {
      var clash = false;
      for (final other in kept) {
        final overlap = candidate.rect.intersect(other.rect);
        if (overlap.isEmpty) continue;
        final ratio =
            (overlap.width * overlap.height) /
            math.min(
              candidate.rect.width * candidate.rect.height,
              other.rect.width * other.rect.height,
            );
        if (ratio > 0.35) {
          clash = true;
          break;
        }
      }
      if (!clash) kept.add(candidate);
    }

    // Surviving boxes still have to look like an avatar: an opaque disc sitting
    // on a flat background.
    final blobs = [
      for (final candidate in kept)
        if (_looksLikeAvatar(lum, width, height, candidate.rect)) candidate,
    ];
    if (blobs.isEmpty) return const [];

    // Group into columns and keep only columns that actually repeat.
    final columns = <List<_Candidate>>[];
    for (final candidate in blobs) {
      var placed = false;
      for (final column in columns) {
        final head = column.first;
        final sameX = (candidate.rect.left - head.rect.left).abs() <
            head.rect.width * 0.35;
        final sameSize =
            (candidate.rect.width - head.rect.width).abs() <
            head.rect.width * 0.3;
        if (sameX && sameSize) {
          column.add(candidate);
          placed = true;
          break;
        }
      }
      if (!placed) columns.add([candidate]);
    }

    final found = <Rect>[];
    for (final column in columns) {
      if (column.length < 2) continue;
      final sorted = [...column]..sort((a, b) => a.rect.top.compareTo(b.rect.top));
      var repeats = false;
      for (var i = 1; i < sorted.length; i++) {
        final gap = sorted[i].rect.top - sorted[i - 1].rect.top;
        if (gap >= sorted[i].rect.height * 0.9 &&
            gap <= sorted[i].rect.height * 9) {
          repeats = true;
          break;
        }
      }
      if (!repeats) continue;
      for (final candidate in sorted) {
        found.add(
          Rect.fromLTRB(
            (candidate.rect.left / width).clamp(0.0, 1.0),
            (candidate.rect.top / height).clamp(0.0, 1.0),
            (candidate.rect.right / width).clamp(0.0, 1.0),
            (candidate.rect.bottom / height).clamp(0.0, 1.0),
          ),
        );
      }
    }
    return found;
  }

  /// True when the window looks like one opaque avatar on a flat background.
  ///
  /// The model is deliberately specific to chat screenshots, because that is
  /// what the feature is for: a uniform backdrop, and a disc of "something
  /// else" sitting on it with a margin of bare background all the way round.
  ///
  /// Three tests, all cheap:
  ///
  ///  * the ring around the box is one flat colour — a line of text has more
  ///    text above and below it, so its ring is not flat;
  ///  * the box's own colour differs from that backdrop;
  ///  * the non-backdrop pixels form a single, roughly square mass covering
  ///    more than half the box. Glyphs cover about a third, and they are wide.
  static bool _looksLikeAvatar(
    Uint8List lum,
    int width,
    int height,
    Rect rect,
  ) {
    final x0 = rect.left.round();
    final y0 = rect.top.round();
    final size = rect.width.round();
    if (size < 8) return false;

    // Median of the 2 px ring, which is the local background.
    final ring = <int>[];
    for (var i = -2; i < size + 2; i++) {
      for (var j = -2; j < size + 2; j++) {
        if (i >= 0 && i < size && j >= 0 && j < size) continue;
        ring.add(
          _lumAt(lum, width, height, x0 + i, y0 + j),
        );
      }
    }
    if (ring.length < 8) return false;
    ring.sort();
    final background = ring[ring.length ~/ 2];
    var flat = 0;
    for (final value in ring) {
      if ((value - background).abs() <= 12) flat++;
    }
    if (flat / ring.length < 0.78) return false;

    final mask = Uint8List(size * size);
    var covered = 0;
    var sum = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final value = _lumAt(lum, width, height, x0 + x, y0 + y);
        sum += value;
        if ((value - background).abs() > 12) {
          mask[y * size + x] = 1;
          covered++;
        }
      }
    }
    final coverage = covered / mask.length;
    // Empty, or the box is entirely inside one flat patch: either way there is
    // no separate object here.
    if (coverage < 0.45) return false;
    final average = sum / mask.length;
    if ((average - background).abs() < 14) return false;

    final seen = Uint8List(size * size);
    var best = 0;
    var left = 0, right = 0, top = 0, bottom = 0;
    final stack = <int>[];
    for (var start = 0; start < mask.length; start++) {
      if (seen[start] == 1 || mask[start] == 0) continue;
      var count = 0;
      var bLeft = size, bRight = 0, bTop = size, bBottom = 0;
      seen[start] = 1;
      stack
        ..clear()
        ..add(start);
      while (stack.isNotEmpty) {
        final index = stack.removeLast();
        count++;
        final x = index % size;
        final y = index ~/ size;
        if (x < bLeft) bLeft = x;
        if (x > bRight) bRight = x;
        if (y < bTop) bTop = y;
        if (y > bBottom) bBottom = y;
        if (x > 0) _visitMask(stack, seen, mask, index - 1);
        if (x < size - 1) _visitMask(stack, seen, mask, index + 1);
        if (y > 0) _visitMask(stack, seen, mask, index - size);
        if (y < size - 1) _visitMask(stack, seen, mask, index + size);
      }
      if (count > best) {
        best = count;
        left = bLeft;
        right = bRight;
        top = bTop;
        bottom = bBottom;
      }
    }
    if (best == 0) return false;

    final blobWidth = right - left + 1;
    final blobHeight = bottom - top + 1;
    final aspect = blobWidth / blobHeight;
    if (aspect < 0.68 || aspect > 1.5) return false;
    final fill = best / (blobWidth * blobHeight);
    if (fill < 0.6) return false;
    // The disc has to be the dominant thing in the box, not a stripe of it.
    return best / mask.length >= 0.42;
  }

  static void _visitMask(
    List<int> stack,
    Uint8List seen,
    Uint8List mask,
    int index,
  ) {
    if (seen[index] == 1 || mask[index] == 0) return;
    seen[index] = 1;
    stack.add(index);
  }

  static int _lumAt(Uint8List lum, int width, int height, int x, int y) {
    final cx = x.clamp(0, width - 1);
    final cy = y.clamp(0, height - 1);
    return lum[cy * width + cx];
  }

  static Uint8List _luminance(Uint8List rgba, int width, int height) {
    final lum = Uint8List(width * height);
    for (var i = 0, p = 0; i < lum.length; i++, p += 4) {
      lum[i] =
          (rgba[p] * 77 + rgba[p + 1] * 150 + rgba[p + 2] * 29) >> 8;
    }
    return lum;
  }
}

class _Candidate {
  _Candidate(this.rect, this.score);
  final Rect rect;
  final double score;
}
