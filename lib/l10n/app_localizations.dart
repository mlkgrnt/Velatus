import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Velatus'**
  String get appName;

  /// No description provided for @appNameZh.
  ///
  /// In en, this message translates to:
  /// **'隐格'**
  String get appNameZh;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Cover what should stay private.'**
  String get tagline;

  /// No description provided for @taglineSub.
  ///
  /// In en, this message translates to:
  /// **'A local-first redaction tool for screenshots and photos.'**
  String get taglineSub;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @openImage.
  ///
  /// In en, this message translates to:
  /// **'Open an image'**
  String get openImage;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get pickFromGallery;

  /// No description provided for @pickFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get pickFromFiles;

  /// No description provided for @dropHint.
  ///
  /// In en, this message translates to:
  /// **'Drop an image here'**
  String get dropHint;

  /// No description provided for @dropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'or click to browse · JPG, PNG, WebP, BMP'**
  String get dropSubtitle;

  /// No description provided for @featureLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Never leaves your device'**
  String get featureLocalTitle;

  /// No description provided for @featureLocalBody.
  ///
  /// In en, this message translates to:
  /// **'No upload, no account, no tracking. The app has no network permission.'**
  String get featureLocalBody;

  /// No description provided for @featureLayersTitle.
  ///
  /// In en, this message translates to:
  /// **'Masks you can revise'**
  String get featureLayersTitle;

  /// No description provided for @featureLayersBody.
  ///
  /// In en, this message translates to:
  /// **'Tap a block to select it, then resize it or delete it. Nothing is baked in.'**
  String get featureLayersBody;

  /// No description provided for @featureOcrTitle.
  ///
  /// In en, this message translates to:
  /// **'Finds text offline'**
  String get featureOcrTitle;

  /// No description provided for @featureOcrBody.
  ///
  /// In en, this message translates to:
  /// **'Detect sensitive text and cover it in one tap. Everything runs on-device.'**
  String get featureOcrBody;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @clearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearRecent;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @editorTitle.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editorTitle;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @compare.
  ///
  /// In en, this message translates to:
  /// **'Hold to compare'**
  String get compare;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @fitToScreen.
  ///
  /// In en, this message translates to:
  /// **'Fit to screen'**
  String get fitToScreen;

  /// No description provided for @toolBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get toolBrush;

  /// No description provided for @toolRect.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get toolRect;

  /// No description provided for @toolSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get toolSelect;

  /// No description provided for @maskMosaic.
  ///
  /// In en, this message translates to:
  /// **'Mosaic'**
  String get maskMosaic;

  /// No description provided for @maskBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get maskBlur;

  /// No description provided for @maskSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get maskSolid;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @brushHint.
  ///
  /// In en, this message translates to:
  /// **'Paint over anything private'**
  String get brushHint;

  /// No description provided for @rectHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to draw a box'**
  String get rectHint;

  /// No description provided for @selectHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a mask to adjust or delete it'**
  String get selectHint;

  /// No description provided for @deleteMask.
  ///
  /// In en, this message translates to:
  /// **'Delete mask'**
  String get deleteMask;

  /// No description provided for @maskCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No masks} =1{1 mask} other{{count} masks}}'**
  String maskCount(int count);

  /// No description provided for @ocrAction.
  ///
  /// In en, this message translates to:
  /// **'Find text'**
  String get ocrAction;

  /// No description provided for @ocrScanning.
  ///
  /// In en, this message translates to:
  /// **'Reading text…'**
  String get ocrScanning;

  /// No description provided for @ocrFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 text block found} other{{count} text blocks found}}'**
  String ocrFound(int count);

  /// No description provided for @ocrNone.
  ///
  /// In en, this message translates to:
  /// **'No text found'**
  String get ocrNone;

  /// No description provided for @ocrApplyAll.
  ///
  /// In en, this message translates to:
  /// **'Cover all'**
  String get ocrApplyAll;

  /// No description provided for @ocrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Text detection is available on Android only for now.'**
  String get ocrUnavailable;

  /// No description provided for @ocrFailed.
  ///
  /// In en, this message translates to:
  /// **'Text detection failed'**
  String get ocrFailed;

  /// No description provided for @compareHint.
  ///
  /// In en, this message translates to:
  /// **'Hold to see the original'**
  String get compareHint;

  /// No description provided for @resetView.
  ///
  /// In en, this message translates to:
  /// **'Reset view'**
  String get resetView;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportTitle;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @metadata.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get metadata;

  /// No description provided for @metadataNote.
  ///
  /// In en, this message translates to:
  /// **'EXIF data (GPS, device, time) is always stripped.'**
  String get metadataNote;

  /// No description provided for @resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// No description provided for @originalSize.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get originalSize;

  /// No description provided for @exportSave.
  ///
  /// In en, this message translates to:
  /// **'Save to device'**
  String get exportSave;

  /// No description provided for @exportGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to gallery'**
  String get exportGallery;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Image saved'**
  String get exported;

  /// No description provided for @exportedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String exportedTo(String path);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the image'**
  String get exportFailed;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Rendering…'**
  String get exporting;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Velatus processes everything on your device. There is no account system and the release build requests no network permission.'**
  String get privacyBody;

  /// No description provided for @openSource.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get openSource;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'A quiet little tool for covering the things that should not be seen.'**
  String get aboutBody;

  /// No description provided for @openFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this image'**
  String get openFailed;

  /// No description provided for @unsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format'**
  String get unsupportedFormat;

  /// No description provided for @storageDenied.
  ///
  /// In en, this message translates to:
  /// **'Storage permission was denied'**
  String get storageDenied;

  /// No description provided for @imageInfo.
  ///
  /// In en, this message translates to:
  /// **'{width} × {height}'**
  String imageInfo(int width, int height);

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @clearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove every mask from this image?'**
  String get clearAllConfirm;

  /// No description provided for @maskStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get maskStyle;

  /// No description provided for @brushSize.
  ///
  /// In en, this message translates to:
  /// **'Brush size'**
  String get brushSize;

  /// No description provided for @blurNote.
  ///
  /// In en, this message translates to:
  /// **'Blur strength scales with the image, so exports match the preview.'**
  String get blurNote;

  /// No description provided for @exifStripped.
  ///
  /// In en, this message translates to:
  /// **'EXIF stripped'**
  String get exifStripped;

  /// No description provided for @footerNote.
  ///
  /// In en, this message translates to:
  /// **'MIT · no network · no account'**
  String get footerNote;

  /// No description provided for @leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without exporting?'**
  String get leaveTitle;

  /// No description provided for @leaveBody.
  ///
  /// In en, this message translates to:
  /// **'Masks are not stored in a project file. Export the image first if you want to keep the result.'**
  String get leaveBody;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @toolRoundedRect.
  ///
  /// In en, this message translates to:
  /// **'Rounded box'**
  String get toolRoundedRect;

  /// No description provided for @roundedRectHint.
  ///
  /// In en, this message translates to:
  /// **'Drag a frame with soft corners'**
  String get roundedRectHint;

  /// No description provided for @cornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get cornerRadius;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom colour'**
  String get customColor;

  /// No description provided for @selectionHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move · corners to resize'**
  String get selectionHint;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

  /// No description provided for @checkUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdate;

  /// No description provided for @checkUpdateNote.
  ///
  /// In en, this message translates to:
  /// **'Opens the releases page in your browser'**
  String get checkUpdateNote;

  /// No description provided for @repository.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get repository;

  /// No description provided for @featureExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Full-resolution output'**
  String get featureExportTitle;

  /// No description provided for @featureExportBody.
  ///
  /// In en, this message translates to:
  /// **'Masks are redrawn at the source pixel grid, not upscaled from the preview.'**
  String get featureExportBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
