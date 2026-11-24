import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../../core/app_info.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/update_service.dart';

/// The whole update flow, in one dialog.
///
/// Splitting check → download → install across three dialogs means three places
/// for the user to get stuck. One dialog with a small state machine keeps every
/// outcome (up to date, offline, failed, handed to the installer) on the same
/// surface, and closing it is never ambiguous.
Future<void> showUpdateFlow(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const UpdateDialog(),
  );
}

enum _Stage { checking, latest, available, downloading, done, failed }

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _Stage _stage = _Stage.checking;
  UpdateInfo? _info;
  String? _error;
  double _progress = 0;
  bool _cancelled = false;
  File? _file;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _stage = _Stage.checking;
      _error = null;
    });
    try {
      final info = await UpdateService.check();
      if (!mounted) return;
      setState(() {
        _info = info;
        _stage = info == null ? _Stage.latest : _Stage.available;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _stage = _Stage.failed;
      });
    }
  }

  Future<void> _download() async {
    final info = _info;
    if (info == null) return;
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
      _cancelled = false;
      _error = null;
    });
    try {
      final file = await UpdateService.download(
        info,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _progress = value);
        },
        isCancelled: () => _cancelled,
      );
      if (!mounted) return;
      _file = file;
      if (Platform.isAndroid) {
        final started = await UpdateService.install(file);
        if (!mounted) return;
        setState(() {
          _stage = _Stage.done;
          _savedPath = started ? null : file.path;
        });
      } else {
        setState(() {
          _stage = _Stage.done;
          _savedPath = file.parent.path;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = _cancelled ? null : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.checkUpdate),
      content: SizedBox(
        width: 320,
        child: switch (_stage) {
          _Stage.checking => Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(l10n.updateChecking)),
            ],
          ),
          _Stage.latest => Text(l10n.updateLatest(kAppVersion)),
          _Stage.available => _AvailableBody(info: _info!),
          _Stage.downloading => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.updateDownloading((_progress * 100).round()),
                    ),
                  ),
                  Text(
                    _info?.sizeLabel ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 6,
                ),
              ),
            ],
          ),
          _Stage.done => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _savedPath == null
                    ? l10n.updateInstallHint
                    : l10n.updateDownloaded(_savedPath!),
              ),
              if (_savedPath != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = _file;
                    if (file != null) {
                      await UpdateService.revealInExplorer(file);
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(l10n.updateShowFile),
                ),
              ],
            ],
          ),
          _Stage.failed => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _info == null
                    ? l10n.updateFailedCheck
                    : l10n.updateFailedDownload,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        },
      ),
      actions: switch (_stage) {
        _Stage.latest => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.done),
          ),
        ],
        _Stage.available => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.updateLater),
          ),
          FilledButton(
            onPressed: _download,
            child: Text(l10n.updateDownload),
          ),
        ],
        _Stage.downloading => [
          TextButton(
            onPressed: () {
              _cancelled = true;
              Navigator.of(context).pop();
            },
            child: Text(l10n.cancel),
          ),
        ],
        _Stage.done => [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.done),
          ),
        ],
        _Stage.failed => [
          TextButton(
            onPressed: () => AppLinks.openReleases(),
            child: Text(l10n.updateOpenReleases),
          ),
          if (_info == null)
            FilledButton(
              onPressed: _check,
              child: Text(l10n.retry),
            )
          else
            FilledButton(
              onPressed: _download,
              child: Text(l10n.retry),
            ),
        ],
        _Stage.checking => const [],
      },
    );
  }
}

class _AvailableBody extends StatelessWidget {
  const _AvailableBody({required this.info});

  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Release notes are markdown. Showing them raw is honest and cheap; the
    // only thing worth trimming is how much of them we show.
    final notes = info.notes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.updateAvailable(info.version),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(
          [
            info.assetName,
            if (info.sizeLabel.isNotEmpty) info.sizeLabel,
            l10n.updateSource(info.source),
          ].join(' · '),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: Text(
                notes,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
