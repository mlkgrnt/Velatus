import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../domain/mask_region.dart';
import 'image_loader.dart';
import 'mask_renderer.dart';
import 'mask_texture_cache.dart';

enum ExportFormat { jpeg, png }

extension ExportFormatLabel on ExportFormat {
  String get extension => this == ExportFormat.jpeg ? 'jpg' : 'png';
  String get mime => this == ExportFormat.jpeg ? 'image/jpeg' : 'image/png';
  String get label => this == ExportFormat.jpeg ? 'JPEG' : 'PNG';
}

class ExportResult {
  ExportResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final ExportFormat format;

  String get extension => format.extension;
}

class ImageExporter {
  const ImageExporter._();

  /// Bakes every mask into the full-resolution image and encodes it.
  static Future<ExportResult> render({
    required LoadedImage source,
    required List<MaskRegion> regions,
    ExportFormat format = ExportFormat.jpeg,
    int quality = 92,
  }) async {
    final full = await ImageLoader.decodeFull(source);
    final cache = MaskTextureCache()..attach(full);
    final rect = Rect.fromLTWH(
      0,
      0,
      full.width.toDouble(),
      full.height.toDouble(),
    );

    try {
      // Build every texture the masks need before the picture is recorded:
      // `toImage` is asynchronous, so a lazily requested texture would miss the
      // export frame and silently bake the original pixels into the file.
      for (final region in regions) {
        if (!region.visible) continue;
        switch (region.style) {
          case MaskStyle.mosaic:
            await cache.ensureMosaic(
              MaskRenderer.mosaicBlockPx(region.strength, rect.shortestSide),
            );
          case MaskStyle.blur:
            await cache.ensureBlur(
              MaskRenderer.blurSigmaPx(
                region.strength,
                rect.shortestSide,
              ).round(),
            );
          case MaskStyle.solid:
            break;
        }
      }

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(full, Offset.zero, ui.Paint());
      canvas.save();
      canvas.clipRect(rect);
      MaskRenderer.paintRegions(
        canvas,
        rect,
        full,
        regions,
        textures: MaskTextures(mosaic: cache.mosaic, blur: cache.blur),
      );
      canvas.restore();
      final picture = recorder.endRecording();
      final output = await picture.toImage(full.width, full.height);
      picture.dispose();

      final raw = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = output.width;
      final height = output.height;
      output.dispose();
      if (raw == null) {
        throw StateError('Could not read rendered pixels');
      }

      final rgba = raw.buffer.asUint8List(
        raw.offsetInBytes,
        raw.lengthInBytes,
      );
      final encoded = await _encodeOffThread(rgba, width, height, format, quality);
      return ExportResult(
        bytes: encoded,
        width: width,
        height: height,
        format: format,
      );
    } finally {
      cache.dispose();
      full.dispose();
    }
  }

  /// Encodes on a worker isolate.
  ///
  /// This lives in its own method on purpose: `Isolate.run` sends the closure
  /// *and everything it captured* to the new isolate, and `dart:ui` objects are
  /// not sendable. Building the closure in a scope that holds the decoded image
  /// or the texture cache makes every export fail with "Illegal argument in
  /// isolate message". Here the captured context is just the pixel buffer and a
  /// few numbers.
  static Future<Uint8List> _encodeOffThread(
    Uint8List rgba,
    int width,
    int height,
    ExportFormat format,
    int quality,
  ) {
    return Isolate.run(() => _encode(rgba, width, height, format, quality));
  }

  static Uint8List _encode(
    Uint8List rgba,
    int width,
    int height,
    ExportFormat format,
    int quality,
  ) {
    final frame = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    if (format == ExportFormat.png) {
      return Uint8List.fromList(img.encodePng(frame, level: 6));
    }
    return Uint8List.fromList(
      img.encodeJpg(frame, quality: quality.clamp(40, 100)),
    );
  }

  /// File name without the extension. `gal` appends the extension itself and
  /// produces `photo.jpg.jpg` if it is already there.
  static String suggestedBaseName({DateTime? now}) {
    final t = now ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'velatus_${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  static String suggestedName(ExportFormat format, {DateTime? now}) {
    return '${suggestedBaseName(now: now)}.${format.extension}';
  }

  static String humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static int estimateMemory(int width, int height) {
    return width * height * 4 + math.max(0, width * height ~/ 2);
  }
}
