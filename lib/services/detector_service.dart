import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:zxing2/qrcode.dart';

import '../domain/mask_region.dart';
import 'avatar_detector.dart';
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
///  * **avatars** — a pure-Dart geometric pass in [AvatarDetector]: integral
///    images, edge/chroma contrast, projection-based shape checks, and a
///    frequency-domain check for the regular rhythm of a chat column. No model.
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

  /// The working resolution of the avatar pass. Screenshot tooling uses this
  /// so its demo scans exactly the same pixels the app does.
  static int get avatarAnalysisSide => AvatarDetector.analysisSide;

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
    final rgba = await _analysisPixels(image, maxSide: avatarAnalysisSide);
    if (rgba == null) return const [];
    return Isolate.run(() {
      final found = AvatarDetector.find(rgba.$1, rgba.$2, rgba.$3);
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

  /// Locates chat avatars. Kept as a thin forwarder so tests and the screenshot
  /// demo keep exercising exactly the function the app runs in its isolate.
  static List<Rect> findAvatars(Uint8List rgba, int width, int height) =>
      AvatarDetector.find(rgba, width, height);
}
