import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/mask_region.dart';
import 'image_loader.dart';

class OcrException implements Exception {
  OcrException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// On-device text detection.
///
/// Uses ML Kit's bundled Chinese + Latin model on Android. The model is fully
/// offline: no image ever leaves the device. Other platforms report
/// [isSupported] as false and the UI hides the action.
class OcrService {
  const OcrService._();

  static bool get isSupported => Platform.isAndroid;

  /// Returns rectangle masks for every detected text block, in normalized
  /// image coordinates.
  static Future<List<MaskRegion>> detect(
    LoadedImage image, {
    required MaskStyle style,
    required double strength,
  }) async {
    final path = image.path;
    if (path == null || !File(path).existsSync()) {
      throw OcrException('The source file is no longer available');
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      final regions = <MaskRegion>[];
      var index = 0;
      for (final block in recognized.blocks) {
        if (block.text.trim().isEmpty) continue;
        final box = block.boundingBox;
        if (box.width <= 1 || box.height <= 1) continue;

        // A small margin keeps descenders and anti-aliased edges covered.
        final padX = box.width * 0.02 + 2;
        final padY = box.height * 0.08 + 2;
        final left = ((box.left - padX) / image.width).clamp(0.0, 1.0);
        final top = ((box.top - padY) / image.height).clamp(0.0, 1.0);
        final right = ((box.right + padX) / image.width).clamp(0.0, 1.0);
        final bottom = ((box.bottom + padY) / image.height).clamp(0.0, 1.0);
        if (right - left < 0.005 || bottom - top < 0.005) continue;

        regions.add(
          MaskRegion(
            id: 'ocr_${DateTime.now().microsecondsSinceEpoch}_$index',
            style: style,
            shape: MaskShape.rect,
            points: [Offset(left, top), Offset(right, bottom)],
            strength: strength,
            color: const Color(0xFF14161C),
          ),
        );
        index++;
      }
      return regions;
    } catch (error) {
      throw OcrException('$error');
    } finally {
      await recognizer.close();
    }
  }
}
