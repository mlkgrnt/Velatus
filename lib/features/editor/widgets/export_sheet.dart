import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../domain/export_prefs.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/image_exporter.dart';
import '../../../services/image_loader.dart';

class ExportSelection {
  const ExportSelection({
    required this.format,
    required this.quality,
    required this.toGallery,
    required this.share,
  });

  final ExportFormat format;
  final int quality;
  final bool toGallery;
  final bool share;
}

Future<ExportSelection?> showExportSheet(
  BuildContext context, {
  required LoadedImage image,
  required bool canGallery,
  ExportPrefs prefs = const ExportPrefs(),
}) {
  return showModalBottomSheet<ExportSelection>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _ExportSheet(image: image, canGallery: canGallery, prefs: prefs),
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({
    required this.image,
    required this.canGallery,
    required this.prefs,
  });

  final LoadedImage image;
  final bool canGallery;
  final ExportPrefs prefs;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late ExportFormat _format = widget.prefs.format;
  late int _quality = widget.prefs.quality;
  late bool _toGallery = widget.prefs.toGallery && widget.canGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.exportTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.imageInfo(widget.image.width, widget.image.height),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _format.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.format,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ExportFormat>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ExportFormat.jpeg, label: Text('JPEG')),
                    ButtonSegment(value: ExportFormat.png, label: Text('PNG')),
                  ],
                  selected: {_format},
                  onSelectionChanged: (value) =>
                      setState(() => _format = value.first),
                ),
                if (_format == ExportFormat.jpeg) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        l10n.quality,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$_quality',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _quality.toDouble(),
                    min: 60,
                    max: 100,
                    divisions: 20,
                    onChanged: (value) =>
                        setState(() => _quality = value.round()),
                  ),
                ],
                if (widget.canGallery) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.exportSave,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text(l10n.exportGallery),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.folder_outlined, size: 18),
                        label: Text(l10n.exportSave),
                      ),
                    ],
                    selected: {_toGallery},
                    onSelectionChanged: (value) =>
                        setState(() => _toGallery = value.first),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.metadataNote,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(
                          context,
                          ExportSelection(
                            format: _format,
                            quality: _quality,
                            toGallery: _toGallery,
                            share: false,
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 19),
                        label: Text(
                          widget.canGallery && _toGallery
                              ? l10n.exportGallery
                              : l10n.exportSave,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.outlined(
                      onPressed: () => Navigator.pop(
                        context,
                        ExportSelection(
                          format: _format,
                          quality: _quality,
                          toGallery: _toGallery,
                          share: true,
                        ),
                      ),
                      icon: const Icon(Icons.ios_share_rounded, size: 19),
                      tooltip: l10n.share,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small helper used by the editor to describe where a file ended up without
/// leaking platform details into the UI layer.
String describeSaveLocation(ExportSelection selection) {
  if (Platform.isAndroid && selection.toGallery) return 'gallery';
  return 'file';
}
