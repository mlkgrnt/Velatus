import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/domain/export_format.dart';
import 'package:velatus/domain/export_prefs.dart';

/// The export sheet should open on last time's answer — these are the pieces
/// that make that possible.
void main() {
  test('a fresh install exports JPEG at full quality', () {
    const prefs = ExportPrefs();
    expect(prefs.format, ExportFormat.jpeg);
    expect(prefs.quality, 100);
    expect(prefs.toGallery, isTrue);
    expect(prefs.lastDirectory, isNull);
  });

  test('prefs survive the trip through JSON', () {
    const prefs = ExportPrefs(
      format: ExportFormat.png,
      quality: 87,
      toGallery: false,
      lastDirectory: r'D:\截图',
    );
    expect(ExportPrefs.fromJson(prefs.toJson()), prefs);
  });

  test('junk falls back field by field', () {
    final prefs = ExportPrefs.fromJson({
      'format': 'webp',
      'quality': 400,
      'toGallery': 'yes',
      'lastDirectory': 42,
    });
    expect(prefs.format, ExportFormat.jpeg);
    expect(prefs.quality, 100, reason: 'out-of-range quality is clamped away');
    expect(prefs.toGallery, isTrue);
    expect(prefs.lastDirectory, isNull);
  });
}
