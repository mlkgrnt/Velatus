import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// An image loaded for editing.
///
/// Only a downscaled preview is kept in memory; the full-resolution image is
/// re-decoded on export. This keeps large photos from exhausting memory on
/// phones while exports still use every pixel.
class LoadedImage {
  LoadedImage({
    required this.preview,
    required this.width,
    required this.height,
    required this.name,
    this.path,
    this.bytes,
    this.byteLength,
  });

  final ui.Image preview;
  final int width;
  final int height;
  final String name;
  final String? path;
  final Uint8List? bytes;
  final int? byteLength;

  double get aspectRatio => width / height;
  int get previewWidth => preview.width;
  int get previewHeight => preview.height;
  double get previewScale => preview.width / width;
}

class ImageLoadException implements Exception {
  ImageLoadException(this.message);
  final String message;
  @override
  String toString() => message;
}

const int kMaxPreviewSide = 2400;
// Keeps peak memory sane on phones while leaving 12 MP photos untouched.
const int kMaxExportSide = 5120;
const int kMaxSourceBytes = 96 * 1024 * 1024;

class ImageLoader {
  const ImageLoader._();

  static Future<LoadedImage> fromPath(String path) async {
    final file = File(path);
    final length = await file.length();
    if (length > kMaxSourceBytes) {
      throw ImageLoadException(
        'Image is too large (${(length / 1024 / 1024).round()} MB)',
      );
    }
    final bytes = await file.readAsBytes();
    final name = path.split(RegExp(r'[\\/]')).last;
    return _decode(bytes, name: name, path: path);
  }

  static Future<LoadedImage> fromBytes(
    Uint8List bytes, {
    String name = 'image',
  }) {
    return _decode(bytes, name: name);
  }

  static Future<LoadedImage> _decode(
    Uint8List bytes, {
    required String name,
    String? path,
  }) async {
    if (bytes.lengthInBytes > kMaxSourceBytes) {
      throw ImageLoadException('Image is too large');
    }

    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      if (width <= 0 || height <= 0) {
        throw ImageLoadException('Invalid image');
      }

      final previewScale =
          math.min(1.0, kMaxPreviewSide / math.max(width, height));
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (width * previewScale).round()),
        targetHeight: math.max(1, (height * previewScale).round()),
      );
      final frame = await codec.getNextFrame();
      return LoadedImage(
        preview: frame.image,
        width: width,
        height: height,
        name: name,
        path: path,
        bytes: path == null ? bytes : null,
        byteLength: bytes.lengthInBytes,
      );
    } on ImageLoadException {
      rethrow;
    } catch (error) {
      throw ImageLoadException('Unsupported or corrupted image: $error');
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Re-decodes the original file at full resolution for export.
  static Future<ui.Image> decodeFull(LoadedImage image) async {
    final bytes = image.bytes ?? await File(image.path!).readAsBytes();
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      final scale = math.min(1.0, kMaxExportSide / math.max(width, height));
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (width * scale).round()),
        targetHeight: math.max(1, (height * scale).round()),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
