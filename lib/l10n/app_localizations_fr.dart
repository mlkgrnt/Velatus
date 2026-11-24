// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Velatus';

  @override
  String get tagline => 'Cachez ce qui doit rester privé.';

  @override
  String get taglineSub =>
      'Masquez captures d\'écran et photos sans rien envoyer ailleurs.';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get done => 'Terminé';

  @override
  String get close => 'Fermer';

  @override
  String get save => 'Enregistrer';

  @override
  String get share => 'Partager';

  @override
  String get settings => 'Réglages';

  @override
  String get about => 'À propos';

  @override
  String get retry => 'Réessayer';

  @override
  String get openImage => 'Ouvrir une image';

  @override
  String get pickFromGallery => 'Galerie';

  @override
  String get pickFromFiles => 'Choisir un fichier';

  @override
  String get dropHint => 'Déposez une image ici';

  @override
  String get dropSubtitle => 'ou cliquez pour parcourir · JPG, PNG, WebP, BMP';

  @override
  String get featureLocalTitle => 'Ne quitte jamais l\'appareil';

  @override
  String get featureLocalBody =>
      'Rien n\'est envoyé et rien n\'est mesuré. La seule raison de se connecter est la recherche de mises à jour, et vous pouvez la couper.';

  @override
  String get featureLayersTitle => 'Des masques modifiables';

  @override
  String get featureLayersBody =>
      'Touchez un bloc pour le sélectionner, puis redimensionnez-le ou supprimez-le. Rien n\'est figé.';

  @override
  String get featureOcrTitle => 'Trouve quoi masquer';

  @override
  String get featureOcrBody =>
      'Le texte, les avatars de discussion et les QR codes sont proposés sous forme de cadres. Vous choisissez lesquels appliquer, entièrement sur l\'appareil.';

  @override
  String get recent => 'Récents';

  @override
  String get clearRecent => 'Vider';

  @override
  String get untitled => 'Sans titre';

  @override
  String get editorTitle => 'Éditeur';

  @override
  String get undo => 'Annuler';

  @override
  String get redo => 'Rétablir';

  @override
  String get compare => 'Maintenir pour comparer';

  @override
  String get export => 'Exporter';

  @override
  String get fitToScreen => 'Ajuster à l\'écran';

  @override
  String get toolBrush => 'Pinceau';

  @override
  String get toolBox => 'Cadre';

  @override
  String get toolSelect => 'Sélection';

  @override
  String get maskMosaic => 'Mosaïque';

  @override
  String get maskBlur => 'Flou';

  @override
  String get maskSolid => 'Aplat';

  @override
  String get strength => 'Intensité';

  @override
  String get size => 'Taille';

  @override
  String get color => 'Couleur';

  @override
  String get brushHint => 'Peignez sur ce qui doit être caché';

  @override
  String get boxHint =>
      'Faites glisser pour encadrer · le curseur arrondit les coins';

  @override
  String get selectHint => 'Touchez un masque pour l\'ajuster ou le supprimer';

  @override
  String get deleteMask => 'Supprimer le masque';

  @override
  String maskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count masques',
      one: '1 masque',
      zero: 'Aucun masque',
    );
    return '$_temp0';
  }

  @override
  String get scanAction => 'Analyser';

  @override
  String scanFoundText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count blocs de texte',
      one: '1 bloc de texte',
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
  String get scanNone => 'Rien à masquer n\'a été trouvé';

  @override
  String get scanFailed => 'L\'analyse a échoué';

  @override
  String get pendingHint => 'Touchez les cadres à masquer';

  @override
  String pendingCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get pendingAll => 'Tout';

  @override
  String get pendingClear => 'Aucun';

  @override
  String get compareHint => 'Maintenez pour voir l\'original';

  @override
  String get resetView => 'Réinitialiser la vue';

  @override
  String get exportTitle => 'Exporter';

  @override
  String get format => 'Format';

  @override
  String get quality => 'Qualité';

  @override
  String get metadata => 'Métadonnées';

  @override
  String get metadataNote =>
      'Les données EXIF (GPS, appareil, date) sont toujours supprimées.';

  @override
  String get resolution => 'Résolution';

  @override
  String get originalSize => 'Originale';

  @override
  String get exportSave => 'Enregistrer sur l\'appareil';

  @override
  String get exportGallery => 'Enregistrer dans la galerie';

  @override
  String get exported => 'Image enregistrée';

  @override
  String exportedTo(String path) {
    return 'Enregistrée dans $path';
  }

  @override
  String get exportFailed => 'Impossible d\'enregistrer l\'image';

  @override
  String get exporting => 'Rendu en cours…';

  @override
  String get appearance => 'Apparence';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get language => 'Langue';

  @override
  String get languageSystem => 'Comme le système';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get privacyBody =>
      'Velatus travaille entièrement sur cet appareil et n\'envoie jamais d\'image. Rien n\'est mesuré. L\'application se connecte pour une seule chose : chercher et télécharger les mises à jour.';

  @override
  String get openSource => 'Open source';

  @override
  String get licenses => 'Licences open source';

  @override
  String get aboutBody =>
      'Un petit outil discret pour cacher ce qui ne devrait pas être vu.';

  @override
  String get openFailed => 'Impossible d\'ouvrir cette image';

  @override
  String get unsupportedFormat => 'Format non pris en charge';

  @override
  String get storageDenied => 'L\'autorisation de stockage a été refusée';

  @override
  String imageInfo(int width, int height) {
    return '$width × $height';
  }

  @override
  String get apply => 'Confirmer';

  @override
  String get clearAll => 'Tout effacer';

  @override
  String get clearAllConfirm => 'Retirer tous les masques de cette image ?';

  @override
  String get maskStyle => 'Style';

  @override
  String get brushSize => 'Taille du pinceau';

  @override
  String get blurNote =>
      'L\'intensité du flou suit la taille de l\'image : l\'export est identique à l\'aperçu.';

  @override
  String get exifStripped => 'EXIF supprimé';

  @override
  String get footerNote => 'MIT · fonctionne hors ligne';

  @override
  String get leaveTitle => 'Quitter sans exporter ?';

  @override
  String get leaveBody =>
      'Ce travail n\'est encore enregistré nulle part. Exportez l\'image d\'abord si vous voulez le garder.';

  @override
  String get leave => 'Quitter';

  @override
  String get cornerRadius => 'Arrondi des coins';

  @override
  String get customColor => 'Couleur';

  @override
  String get selectionHint =>
      'Glisser pour déplacer · les coins redimensionnent';

  @override
  String selectionHintMulti(int count) {
    return '$count masques sélectionnés · le glissement et le redimensionnement ne touchent que celui sous le doigt';
  }

  @override
  String get moreActions => 'Plus';

  @override
  String get checkUpdate => 'Rechercher des mises à jour';

  @override
  String get checkUpdateNote =>
      'Téléchargement et installation dans l\'application';

  @override
  String get updateChecking => 'Recherche de mises à jour…';

  @override
  String updateLatest(String version) {
    return 'Vous avez la dernière version ($version).';
  }

  @override
  String updateAvailable(String version) {
    return 'La version $version est disponible';
  }

  @override
  String get updateDownload => 'Télécharger et installer';

  @override
  String get updateLater => 'Plus tard';

  @override
  String updateDownloading(int percent) {
    return 'Téléchargement… $percent %';
  }

  @override
  String get updateInstallHint =>
      'Android vous demandera d\'autoriser l\'installation depuis Velatus, puis affichera son propre écran d\'installation. Votre travail en cours n\'est pas affecté.';

  @override
  String updateDownloaded(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get updateShowFile => 'Afficher le fichier';

  @override
  String get updateFailedCheck => 'Aucune source de mise à jour n\'a répondu';

  @override
  String get updateFailedDownload => 'Le téléchargement a échoué';

  @override
  String get updateOpenReleases => 'Ouvrir la page des versions';

  @override
  String updateSource(String host) {
    return 'via $host';
  }

  @override
  String get repository => 'Code source';

  @override
  String get featureExportTitle => 'Rendu en pleine résolution';

  @override
  String get featureExportBody =>
      'Les masques sont redessinés sur les pixels d\'origine, sans agrandir l\'aperçu.';
}
