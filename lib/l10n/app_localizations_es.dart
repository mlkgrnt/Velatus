// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Velatus';

  @override
  String get tagline => 'Tapa lo que debe quedar privado.';

  @override
  String get taglineSub =>
      'Censura capturas y fotos sin enviarlas a ninguna parte.';

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Borrar';

  @override
  String get done => 'Listo';

  @override
  String get close => 'Cerrar';

  @override
  String get save => 'Guardar';

  @override
  String get share => 'Compartir';

  @override
  String get settings => 'Ajustes';

  @override
  String get about => 'Acerca de';

  @override
  String get retry => 'Reintentar';

  @override
  String get openImage => 'Abrir una imagen';

  @override
  String get pickFromGallery => 'Galería';

  @override
  String get pickFromFiles => 'Elegir un archivo';

  @override
  String get dropHint => 'Suelta una imagen aquí';

  @override
  String get dropSubtitle => 'o haz clic para buscar · JPG, PNG, WebP, BMP';

  @override
  String get featureLocalTitle => 'Nunca sale de tu dispositivo';

  @override
  String get featureLocalBody =>
      'No se sube nada y no se mide nada. La única razón para conectarse es buscar actualizaciones, y puedes desactivarlo.';

  @override
  String get featureLayersTitle => 'Máscaras que puedes cambiar';

  @override
  String get featureLayersBody =>
      'Toca un bloque para seleccionarlo y luego cámbialo de tamaño o bórralo. Nada queda fijado.';

  @override
  String get featureOcrTitle => 'Encuentra qué tapar';

  @override
  String get featureOcrBody =>
      'El texto, los avatares del chat y los códigos QR aparecen como recuadros. Tú eliges cuáles aplicar, todo en el dispositivo.';

  @override
  String get recent => 'Recientes';

  @override
  String get clearRecent => 'Vaciar';

  @override
  String get untitled => 'Sin título';

  @override
  String get editorTitle => 'Editor';

  @override
  String get undo => 'Deshacer';

  @override
  String get redo => 'Rehacer';

  @override
  String get compare => 'Comparar';

  @override
  String get export => 'Exportar';

  @override
  String get fitToScreen => 'Ajustar a la pantalla';

  @override
  String get toolBrush => 'Pincel';

  @override
  String get toolBox => 'Recuadro';

  @override
  String get toolSelect => 'Seleccionar';

  @override
  String get maskMosaic => 'Mosaico';

  @override
  String get maskBlur => 'Desenfoque';

  @override
  String get maskSolid => 'Color';

  @override
  String get strength => 'Intensidad';

  @override
  String get size => 'Tamaño';

  @override
  String get color => 'Color';

  @override
  String get brushHint => 'Pinta encima de lo que quieras ocultar';

  @override
  String get boxHint =>
      'Arrastra para encuadrar · el control de esquina redondea';

  @override
  String get selectHint => 'Toca una máscara para ajustarla o borrarla';

  @override
  String get deleteMask => 'Borrar máscara';

  @override
  String maskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count máscaras',
      one: '1 máscara',
      zero: 'Sin máscaras',
    );
    return '$_temp0';
  }

  @override
  String get scanAction => 'Escanear';

  @override
  String scanFoundText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bloques de texto',
      one: '1 bloque de texto',
    );
    return '$_temp0';
  }

  @override
  String scanFoundAvatar(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avatares',
      one: '1 avatar',
    );
    return '$_temp0';
  }

  @override
  String scanFoundQr(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count códigos QR',
      one: '1 código QR',
    );
    return '$_temp0';
  }

  @override
  String get scanNone => 'No se encontró nada que valga la pena tapar';

  @override
  String get scanFailed => 'El escaneo falló';

  @override
  String get pendingHint => 'Toca los recuadros que quieras tapar';

  @override
  String pendingCount(int selected, int total) {
    return '$selected/$total';
  }

  @override
  String get pendingAll => 'Todos';

  @override
  String get pendingClear => 'Ninguno';

  @override
  String get compareHint => 'Toca para comparar, mantén para ver';

  @override
  String get compareOriginal => 'Original';

  @override
  String get compareBack => 'Toca de nuevo para volver';

  @override
  String get resetView => 'Restablecer vista';

  @override
  String get exportTitle => 'Exportar';

  @override
  String get format => 'Formato';

  @override
  String get quality => 'Calidad';

  @override
  String get metadata => 'Metadatos';

  @override
  String get metadataNote =>
      'Los datos EXIF (GPS, dispositivo, fecha) se eliminan siempre.';

  @override
  String get resolution => 'Resolución';

  @override
  String get originalSize => 'Original';

  @override
  String get exportSave => 'Guardar en el dispositivo';

  @override
  String get exportGallery => 'Guardar en la galería';

  @override
  String get exported => 'Imagen guardada';

  @override
  String exportedTo(String path) {
    return 'Guardada en $path';
  }

  @override
  String get exportFailed => 'No se pudo guardar la imagen';

  @override
  String get exporting => 'Procesando…';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Igual que el sistema';

  @override
  String get privacy => 'Privacidad';

  @override
  String get privacyBody =>
      'Velatus hace todo el trabajo en este dispositivo y nunca sube una imagen. No se mide nada. La aplicación se conecta por una sola cosa: buscar y descargar actualizaciones.';

  @override
  String get openSource => 'Código abierto';

  @override
  String get licenses => 'Licencias de código abierto';

  @override
  String get aboutBody =>
      'Una herramienta discreta para tapar lo que no debería verse.';

  @override
  String get openFailed => 'No se pudo abrir esta imagen';

  @override
  String get unsupportedFormat => 'Formato no compatible';

  @override
  String get storageDenied => 'Se denegó el permiso de almacenamiento';

  @override
  String imageInfo(int width, int height) {
    return '$width × $height';
  }

  @override
  String get apply => 'Confirmar';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get clearAllConfirm => '¿Quitar todas las máscaras de esta imagen?';

  @override
  String get maskStyle => 'Estilo';

  @override
  String get brushSize => 'Grosor del pincel';

  @override
  String get blurNote =>
      'La intensidad del desenfoque se ajusta a la imagen, así que el archivo exportado se ve igual que la vista previa.';

  @override
  String get exifStripped => 'EXIF eliminado';

  @override
  String get footerNote => 'MIT · funciona sin conexión';

  @override
  String get leaveTitle => '¿Salir sin exportar?';

  @override
  String get leaveBody =>
      'Este trabajo aún no está guardado en ninguna parte. Exporta la imagen primero si quieres conservarlo.';

  @override
  String get leave => 'Salir';

  @override
  String get cornerRadius => 'Radio de esquina';

  @override
  String get customColor => 'Color';

  @override
  String get selectionHint =>
      'Arrastra para mover · las esquinas cambian el tamaño';

  @override
  String selectionHintMulti(int count) {
    return '$count máscaras seleccionadas · arrastrar y redimensionar solo afectan a la que tocas';
  }

  @override
  String get moreActions => 'Más';

  @override
  String get checkUpdate => 'Buscar actualizaciones';

  @override
  String get checkUpdateNote => 'Se descarga e instala dentro de la app';

  @override
  String get updateChecking => 'Buscando actualizaciones…';

  @override
  String updateLatest(String version) {
    return 'Ya tienes la última versión ($version).';
  }

  @override
  String updateAvailable(String version) {
    return 'La versión $version ya está disponible';
  }

  @override
  String get updateDownload => 'Descargar e instalar';

  @override
  String get updateLater => 'Más tarde';

  @override
  String updateDownloading(int percent) {
    return 'Descargando… $percent%';
  }

  @override
  String get updateInstallHint =>
      'Android te pedirá permiso para instalar aplicaciones desde Velatus y luego mostrará su propia pantalla de instalación. Tu edición no se ve afectada.';

  @override
  String updateDownloaded(String path) {
    return 'Guardado en $path';
  }

  @override
  String get updateShowFile => 'Mostrar archivo';

  @override
  String get updateFailedCheck =>
      'No se pudo conectar con ningún servidor de actualizaciones';

  @override
  String get updateFailedDownload => 'La descarga falló';

  @override
  String get updateOpenReleases => 'Abrir la página de versiones';

  @override
  String updateSource(String host) {
    return 'vía $host';
  }

  @override
  String get repository => 'Código fuente';

  @override
  String get featureExportTitle => 'Salida a resolución completa';

  @override
  String get featureExportBody =>
      'Las máscaras se redibujan sobre los píxeles originales, no se amplían desde la vista previa.';
}
