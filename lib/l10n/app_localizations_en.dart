// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Velatus';

  @override
  String get appNameZh => '隐格';

  @override
  String get tagline => 'Cover what should stay private.';

  @override
  String get taglineSub =>
      'A local-first redaction tool for screenshots and photos.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get retry => 'Try again';

  @override
  String get openImage => 'Open an image';

  @override
  String get pickFromGallery => 'Photo library';

  @override
  String get pickFromFiles => 'Choose a file';

  @override
  String get dropHint => 'Drop an image here';

  @override
  String get dropSubtitle => 'or click to browse · JPG, PNG, WebP, BMP';

  @override
  String get featureLocalTitle => 'Never leaves your device';

  @override
  String get featureLocalBody =>
      'No upload, no account, no tracking. The app has no network permission.';

  @override
  String get featureLayersTitle => 'Masks you can revise';

  @override
  String get featureLayersBody =>
      'Tap a block to select it, then resize it or delete it. Nothing is baked in.';

  @override
  String get featureOcrTitle => 'Finds text offline';

  @override
  String get featureOcrBody =>
      'Detect sensitive text and cover it in one tap. Everything runs on-device.';

  @override
  String get recent => 'Recent';

  @override
  String get clearRecent => 'Clear';

  @override
  String get untitled => 'Untitled';

  @override
  String get editorTitle => 'Editor';

  @override
  String get undo => 'Undo';

  @override
  String get redo => 'Redo';

  @override
  String get compare => 'Hold to compare';

  @override
  String get export => 'Export';

  @override
  String get fitToScreen => 'Fit to screen';

  @override
  String get toolBrush => 'Brush';

  @override
  String get toolRect => 'Rectangle';

  @override
  String get toolSelect => 'Select';

  @override
  String get maskMosaic => 'Mosaic';

  @override
  String get maskBlur => 'Blur';

  @override
  String get maskSolid => 'Solid';

  @override
  String get strength => 'Strength';

  @override
  String get size => 'Size';

  @override
  String get color => 'Color';

  @override
  String get brushHint => 'Paint over anything private';

  @override
  String get rectHint => 'Drag to draw a box';

  @override
  String get selectHint => 'Tap a mask to adjust or delete it';

  @override
  String get deleteMask => 'Delete mask';

  @override
  String maskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count masks',
      one: '1 mask',
      zero: 'No masks',
    );
    return '$_temp0';
  }

  @override
  String get ocrAction => 'Find text';

  @override
  String get ocrScanning => 'Reading text…';

  @override
  String ocrFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count text blocks found',
      one: '1 text block found',
    );
    return '$_temp0';
  }

  @override
  String get ocrNone => 'No text found';

  @override
  String get ocrApplyAll => 'Cover all';

  @override
  String get ocrUnavailable =>
      'Text detection is available on Android only for now.';

  @override
  String get ocrFailed => 'Text detection failed';

  @override
  String get compareHint => 'Hold to see the original';

  @override
  String get resetView => 'Reset view';

  @override
  String get exportTitle => 'Export';

  @override
  String get format => 'Format';

  @override
  String get quality => 'Quality';

  @override
  String get metadata => 'Metadata';

  @override
  String get metadataNote =>
      'EXIF data (GPS, device, time) is always stripped.';

  @override
  String get resolution => 'Resolution';

  @override
  String get originalSize => 'Original';

  @override
  String get exportSave => 'Save to device';

  @override
  String get exportGallery => 'Save to gallery';

  @override
  String get exported => 'Image saved';

  @override
  String exportedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get exportFailed => 'Could not save the image';

  @override
  String get exporting => 'Rendering…';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyBody =>
      'Velatus processes everything on your device. There is no account system and the release build requests no network permission.';

  @override
  String get openSource => 'Open source';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get aboutBody =>
      'A quiet little tool for covering the things that should not be seen.';

  @override
  String get openFailed => 'Could not open this image';

  @override
  String get unsupportedFormat => 'Unsupported format';

  @override
  String get storageDenied => 'Storage permission was denied';

  @override
  String imageInfo(int width, int height) {
    return '$width × $height';
  }

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get apply => 'Apply';

  @override
  String get clearAll => 'Clear all';

  @override
  String get clearAllConfirm => 'Remove every mask from this image?';

  @override
  String get maskStyle => 'Style';

  @override
  String get brushSize => 'Brush size';

  @override
  String get blurNote =>
      'Blur strength scales with the image, so exports match the preview.';

  @override
  String get exifStripped => 'EXIF stripped';

  @override
  String get footerNote => 'MIT · no network · no account';

  @override
  String get leaveTitle => 'Leave without exporting?';

  @override
  String get leaveBody =>
      'This edit is not saved anywhere. Export the image first if you want to keep it.';

  @override
  String get leave => 'Leave';

  @override
  String get toolRoundedRect => 'Rounded box';

  @override
  String get roundedRectHint => 'Drag a frame with soft corners';

  @override
  String get cornerRadius => 'Corner radius';

  @override
  String get customColor => 'Custom colour';

  @override
  String get selectionHint => 'Drag to move · corners to resize';

  @override
  String get moreActions => 'More';

  @override
  String get checkUpdate => 'Check for updates';

  @override
  String get checkUpdateNote => 'Opens the releases page in your browser';

  @override
  String get repository => 'Source code';

  @override
  String get featureExportTitle => 'Full-resolution output';

  @override
  String get featureExportBody =>
      'Masks are redrawn at the source pixel grid, not upscaled from the preview.';
}
