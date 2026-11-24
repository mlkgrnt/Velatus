import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
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
    Locale('es'),
    Locale('fr'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Velatus'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Cover what should stay private.'**
  String get tagline;

  /// No description provided for @taglineSub.
  ///
  /// In en, this message translates to:
  /// **'Redact screenshots and photos without sending them anywhere.'**
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
  /// **'Nothing is uploaded and nothing is tracked. The only reason it ever goes online is to check for updates, and you can switch that off.'**
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
  /// **'Finds what to cover'**
  String get featureOcrTitle;

  /// No description provided for @featureOcrBody.
  ///
  /// In en, this message translates to:
  /// **'Text, chat avatars and QR codes are suggested as boxes. You pick which ones to apply, all on this device.'**
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
  /// **'Compare'**
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

  /// No description provided for @toolBox.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get toolBox;

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
  /// **'Colour'**
  String get color;

  /// No description provided for @brushHint.
  ///
  /// In en, this message translates to:
  /// **'Paint over anything private'**
  String get brushHint;

  /// No description provided for @boxHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to frame an area · the corner slider rounds it'**
  String get boxHint;

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

  /// No description provided for @scanAction.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanAction;

  /// No description provided for @scanFoundText.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 text block} other{{count} text blocks}}'**
  String scanFoundText(int count);

  /// No description provided for @scanFoundAvatar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 avatar} other{{count} avatars}}'**
  String scanFoundAvatar(int count);

  /// No description provided for @scanFoundQr.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 QR code} other{{count} QR codes}}'**
  String scanFoundQr(int count);

  /// No description provided for @scanNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing worth covering was found'**
  String get scanNone;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get scanFailed;

  /// No description provided for @pendingHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the boxes you want to cover'**
  String get pendingHint;

  /// No description provided for @pendingCount.
  ///
  /// In en, this message translates to:
  /// **'{selected}/{total}'**
  String pendingCount(int selected, int total);

  /// No description provided for @pendingAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get pendingAll;

  /// No description provided for @pendingClear.
  ///
  /// In en, this message translates to:
  /// **'Select none'**
  String get pendingClear;

  /// No description provided for @compareHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to compare, hold to peek'**
  String get compareHint;

  /// No description provided for @compareOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get compareOriginal;

  /// No description provided for @compareBack.
  ///
  /// In en, this message translates to:
  /// **'Tap again to go back'**
  String get compareBack;

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
  /// **'System'**
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
  /// **'Same as system'**
  String get languageSystem;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Velatus does all its work on this device and never uploads an image. Nothing is tracked. The app goes online for one thing only: checking for and downloading updates.'**
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

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
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
  /// **'MIT · works offline'**
  String get footerNote;

  /// No description provided for @leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without exporting?'**
  String get leaveTitle;

  /// No description provided for @leaveBody.
  ///
  /// In en, this message translates to:
  /// **'This edit is not saved anywhere yet. Export the image first if you want to keep it.'**
  String get leaveBody;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @cornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get cornerRadius;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get customColor;

  /// No description provided for @selectionHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to move · corners resize'**
  String get selectionHint;

  /// No description provided for @selectionHintMulti.
  ///
  /// In en, this message translates to:
  /// **'{count} masks selected · dragging and resizing only touch the one under your finger'**
  String selectionHintMulti(int count);

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
  /// **'Downloads and installs inside the app'**
  String get checkUpdateNote;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get updateChecking;

  /// No description provided for @updateLatest.
  ///
  /// In en, this message translates to:
  /// **'You are on the latest version ({version}).'**
  String updateLatest(String version);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String updateAvailable(String version);

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get updateDownload;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @updateInstallHint.
  ///
  /// In en, this message translates to:
  /// **'Android will ask you to allow installs from Velatus, then show its own install screen. Your edits are not affected.'**
  String get updateInstallHint;

  /// No description provided for @updateDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String updateDownloaded(String path);

  /// No description provided for @updateShowFile.
  ///
  /// In en, this message translates to:
  /// **'Show file'**
  String get updateShowFile;

  /// No description provided for @updateFailedCheck.
  ///
  /// In en, this message translates to:
  /// **'No update source could be reached'**
  String get updateFailedCheck;

  /// No description provided for @updateFailedDownload.
  ///
  /// In en, this message translates to:
  /// **'The download failed'**
  String get updateFailedDownload;

  /// No description provided for @updateOpenReleases.
  ///
  /// In en, this message translates to:
  /// **'Open the release page'**
  String get updateOpenReleases;

  /// No description provided for @updateSource.
  ///
  /// In en, this message translates to:
  /// **'via {host}'**
  String updateSource(String host);

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
      <String>['en', 'es', 'fr', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
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
