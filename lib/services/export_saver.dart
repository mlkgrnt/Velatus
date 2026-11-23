import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

import 'image_exporter.dart';

class ExportSaveResult {
  const ExportSaveResult({required this.ok, this.location, this.error});

  final bool ok;
  final String? location;
  final String? error;
}

class ExportSaver {
  const ExportSaver._();

  /// Android: write into the system gallery so the result shows up in Photos.
  /// Desktop: ask the user where to put it.
  static Future<ExportSaveResult> save(
    ExportResult result, {
    required bool toGallery,
  }) async {
    final name = ImageExporter.suggestedName(result.format);
    try {
      if (Platform.isAndroid && toGallery) {
        final allowed =
            await Gal.hasPermission() || await Gal.requestPermission();
        if (!allowed) {
          return const ExportSaveResult(
            ok: false,
            error: 'Gallery permission denied',
          );
        }
        await Gal.putImageBytes(result.bytes, name: name);
        return const ExportSaveResult(ok: true, location: 'Gallery');
      }
      if (Platform.isAndroid) {
        final dir = await _androidOutputDir();
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(result.bytes, flush: true);
        return ExportSaveResult(ok: true, location: file.path);
      }

      final typeGroup = XTypeGroup(
        label: result.format.label,
        extensions: [result.extension],
      );
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: [typeGroup],
      );
      if (location == null) {
        return const ExportSaveResult(ok: false);
      }
      var path = location.path;
      if (!path.toLowerCase().endsWith('.${result.extension}')) {
        path = '$path.${result.extension}';
      }
      await File(path).writeAsBytes(result.bytes, flush: true);
      return ExportSaveResult(ok: true, location: path);
    } catch (error) {
      return ExportSaveResult(ok: false, error: error.toString());
    }
  }

  static Future<Directory> _androidOutputDir() async {
    final candidates = [
      Directory('/storage/emulated/0/Download'),
      Directory('/storage/emulated/0/Pictures'),
    ];
    for (final dir in candidates) {
      if (await dir.exists()) return dir;
    }
    return Directory.systemTemp;
  }

  /// Writes a temporary copy for the system share sheet.
  static Future<File> temporaryFile(ExportResult result) async {
    final dir = await Directory.systemTemp.createTemp('velatus_share');
    final file = File(
      '${dir.path}/${ImageExporter.suggestedName(result.format)}',
    );
    await file.writeAsBytes(result.bytes, flush: true);
    return file;
  }

  static bool get canSaveToGallery => !kIsWeb && Platform.isAndroid;
}
