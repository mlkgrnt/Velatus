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
  String get tagline => 'Cover what should stay private.';

  @override
  String get taglineSub =>
      'Redact screenshots and photos without sending them anywhere.';

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
      'Nothing is uploaded and nothing is tracked. The only reason it ever goes online is to check for updates, and you can switch that off.';

  @override
  String get featureLayersTitle => 'Masks you can revise';

  @override
  String get featureLayersBody =>
      'Tap a block to select it, then resize it or delete it. Nothing is baked in.';

  @override
  String get featureOcrTitle => 'Finds what to cover';

  @override
  String get featureOcrBody =>
      'Text, chat avatars and QR codes are suggested as boxes. You pick which ones to apply, all on this device.';

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
  String get compare => 'Compare';

  @override
  String get export => 'Export';

  @override
  String get fitToScreen => 'Fit to screen';

  @override
  String get toolBrush => 'Brush';

  @override
  String get toolBox => 'Box';

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
  String get color => 'Colour';

  @override
  String get brushHint => 'Paint over anything private';

  @override
  String get boxHint => 'Drag to frame an area · the corner slider rounds it';

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
  String get scanAction => 'Scan';

  @override
  String scanFoundText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count text blocks',
      one: '1 text block',
    );
    return '$_temp0';
  }

  @override
  String scanFoundAvatar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avatars',
      one: '1 avatar',
    );
    return '$_temp0';
  }

  @override
  String scanFoundQr(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count QR codes',
      one: '1 QR code',
    );
    return '$_temp0';
  }

  @override
  String get scanNone => 'Nothing worth covering was found';

  @override
  String get scanFailed => 'Scan failed';

  @override
  String get pendingHint => 'Tap the boxes you want to cover';

  @override
  String pendingCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get pendingAll => 'Select all';

  @override
  String get pendingClear => 'Select none';

  @override
  String get compareHint => 'Tap to compare, hold to peek';

  @override
  String get compareOriginal => 'Original';

  @override
  String get compareBack => 'Tap again to go back';

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
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Same as system';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyBody =>
      'Velatus does all its work on this device and never uploads an image. Nothing is tracked. The app goes online for one thing only: checking for and downloading updates.';

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
  String get apply => 'Confirm';

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
  String get footerNote => 'MIT · works offline';

  @override
  String get leaveTitle => 'Leave without exporting?';

  @override
  String get leaveBody =>
      'This edit is not saved anywhere yet. Export the image first if you want to keep it.';

  @override
  String get leave => 'Leave';

  @override
  String get cornerRadius => 'Corner radius';

  @override
  String get customColor => 'Colour';

  @override
  String get selectionHint => 'Drag to move · corners resize';

  @override
  String selectionHintMulti(int count) {
    return '$count masks selected · dragging and resizing only touch the one under your finger';
  }

  @override
  String get moreActions => 'More';

  @override
  String get checkUpdate => 'Check for updates';

  @override
  String get checkUpdateNote => 'Downloads and installs inside the app';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String updateLatest(String version) {
    return 'You are on the latest version ($version).';
  }

  @override
  String updateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String get updateDownload => 'Download and install';

  @override
  String get updateLater => 'Later';

  @override
  String updateDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get updateInstallHint =>
      'Android will ask you to allow installs from Velatus, then show its own install screen. Your edits are not affected.';

  @override
  String updateDownloaded(String path) {
    return 'Saved to $path';
  }

  @override
  String get updateShowFile => 'Show file';

  @override
  String get updateFailedCheck => 'No update source could be reached';

  @override
  String get updateFailedDownload => 'The download failed';

  @override
  String get updateOpenReleases => 'Open the release page';

  @override
  String updateSource(String host) {
    return 'via $host';
  }

  @override
  String get repository => 'Source code';

  @override
  String get featureExportTitle => 'Full-resolution output';

  @override
  String get featureExportBody =>
      'Masks are redrawn at the source pixel grid, not upscaled from the preview.';
}
