import 'package:flutter/foundation.dart';

import 'export_format.dart';

/// The export choices worth remembering between sessions.
///
/// Nobody wants to re-pick JPEG, drag quality back to 100 and hunt for their
/// folder every single time, so the sheet opens on last time's answer.
@immutable
class ExportPrefs {
  const ExportPrefs({
    this.format = ExportFormat.jpeg,
    this.quality = 100,
    this.toGallery = true,
    this.lastDirectory,
  });

  final ExportFormat format;

  /// 100 by default: the encoder is the last step and there is no reason to
  /// throw away detail before it. PNG ignores this value.
  final int quality;

  /// Android only: gallery versus the Download folder.
  final bool toGallery;

  /// Desktop only: the folder the last export landed in, used as the starting
  /// point of the save dialog.
  final String? lastDirectory;

  ExportPrefs copyWith({
    ExportFormat? format,
    int? quality,
    bool? toGallery,
    String? lastDirectory,
  }) {
    return ExportPrefs(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      toGallery: toGallery ?? this.toGallery,
      lastDirectory: lastDirectory ?? this.lastDirectory,
    );
  }

  Map<String, Object?> toJson() => {
    'format': format.name,
    'quality': quality,
    'toGallery': toGallery,
    if (lastDirectory != null) 'lastDirectory': lastDirectory,
  };

  /// Tolerant, like the editor preset: one bad field must not wipe the rest.
  static ExportPrefs fromJson(Map<String, Object?> json) {
    const fallback = ExportPrefs();
    final format = json['format'];
    final quality = json['quality'];
    final gallery = json['toGallery'];
    final directory = json['lastDirectory'];
    return ExportPrefs(
      format: ExportFormat.values.firstWhere(
        (value) => value.name == format,
        orElse: () => fallback.format,
      ),
      quality: quality is num ? quality.toInt().clamp(40, 100) : fallback.quality,
      toGallery: gallery is bool ? gallery : fallback.toGallery,
      lastDirectory: directory is String && directory.isNotEmpty
          ? directory
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExportPrefs &&
        other.format == format &&
        other.quality == quality &&
        other.toGallery == toGallery &&
        other.lastDirectory == lastDirectory;
  }

  @override
  int get hashCode => Object.hash(format, quality, toGallery, lastDirectory);
}