import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/detector_service.dart';
import '../../services/export_saver.dart';
import '../../services/image_loader.dart';
import 'editor_controller.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/export_sheet.dart';
import 'widgets/tool_dock.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.image,
    required this.settings,
    this.controller,
  });

  final LoadedImage image;
  final SettingsController settings;

  /// Lets tests and screenshot tooling start from a prepared session.
  final EditorController? controller;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final EditorController _controller;
  late final bool _ownsController;
  bool _scanRunning = false;
  bool _allowPop = false;

  /// Fingerprint of the masks at the last successful export. When it still
  /// matches, leaving needs no confirmation.
  int? _exportedSignature;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        EditorController(
          image: widget.image,
          preset: widget.settings.preset,
          onPresetChanged: widget.settings.savePreset,
        );
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runScan() async {
    if (_scanRunning) return;
    setState(() => _scanRunning = true);
    try {
      final outcome = await DetectorService.detect(
        widget.image,
        style: _controller.style,
        strength: _controller.strength,
        radius: _controller.radius,
        color: _controller.solidColor,
      );
      if (!mounted) return;
      if (outcome.isEmpty) {
        _showMessage(l10n.scanNone);
      } else {
        _controller.setPending(outcome.candidates);
        _showMessage(_describe(outcome));
      }
    } catch (error) {
      if (mounted) _showMessage('${l10n.scanFailed}: $error');
    } finally {
      if (mounted) setState(() => _scanRunning = false);
    }
  }

  /// "12 text · 3 avatars" — only the kinds that were actually found.
  String _describe(DetectOutcome outcome) {
    final parts = <String>[];
    for (final kind in DetectKind.values) {
      final count = outcome.of(kind);
      if (count == 0) continue;
      parts.add(switch (kind) {
        DetectKind.text => l10n.scanFoundText(count),
        DetectKind.avatar => l10n.scanFoundAvatar(count),
        DetectKind.qr => l10n.scanFoundQr(count),
      });
    }
    return parts.join(' · ');
  }

  Future<void> _clearAll() async {
    if (!_controller.hasMasks) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearAll),
        content: Text(l10n.clearAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.clearAll),
          ),
        ],
      ),
    );
    if (confirmed == true) _controller.clearAll();
  }

  Future<void> _export() async {
    if (_controller.busy) return;
    final prefs = widget.settings.exportPrefs;
    final selection = await showExportSheet(
      context,
      image: widget.image,
      canGallery: ExportSaver.canSaveToGallery,
      prefs: prefs,
    );
    if (selection == null || !mounted) return;
    // Remember the answer before the slow part, so a failed render still
    // leaves the sheet the way the user set it up.
    await widget.settings.saveExportPrefs(
      prefs.copyWith(
        format: selection.format,
        quality: selection.quality,
        toGallery: selection.toGallery,
      ),
    );
    if (!mounted) return;

    _controller.setBusy(true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(l10n.exporting)),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await _controller.export(
        format: selection.format,
        quality: selection.quality,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (selection.share) {
        final file = await ExportSaver.temporaryFile(result);
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
        _markExported();
        return;
      }

      final saved = await ExportSaver.save(
        result,
        toGallery: selection.toGallery,
        initialDirectory: prefs.lastDirectory,
      );
      if (!mounted) return;
      if (saved.ok) {
        _markExported();
        if (saved.directory != null) {
          await widget.settings.saveExportPrefs(
            widget.settings.exportPrefs.copyWith(
              lastDirectory: saved.directory,
            ),
          );
        }
        _showMessage(
          saved.location == null || saved.location == 'Gallery'
              ? l10n.exported
              : l10n.exportedTo(saved.location!),
        );
      } else if (saved.error != null) {
        _showMessage('${l10n.exportFailed}: ${saved.error}');
      }
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showMessage('${l10n.exportFailed}: $error');
      }
    } finally {
      _controller.setBusy(false);
    }
  }

  /// True when closing the editor loses nothing: no masks at all, or the masks
  /// are exactly what was exported last.
  bool get _nothingToLose =>
      !_controller.hasMasks ||
      _exportedSignature == _controller.contentSignature;

  /// Records that the current masks are safely in a file, so leaving no longer
  /// needs a warning. Editing afterwards changes the fingerprint and arms it
  /// again.
  void _markExported() {
    if (!mounted) return;
    setState(() => _exportedSignature = _controller.contentSignature);
  }

  Future<void> _confirmLeave() async {
    if (_allowPop) return;
    if (_nothingToLose) {
      _popNow();
      return;
    }
    final theme = Theme.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // Deliberately smaller than the default: this is a nudge, not a
        // headline, and the stock Material dialog shouts it.
        titleTextStyle: theme.textTheme.titleMedium,
        contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
        title: Text(l10n.leaveTitle),
        content: Text(l10n.leaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (leave == true && mounted) _popNow();
  }

  void _popNow() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: _allowPop || _nothingToLose,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _confirmLeave();
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
                  _controller.undo,
              const SingleActivator(
                LogicalKeyboardKey.keyZ,
                control: true,
                shift: true,
              ): _controller.redo,
              const SingleActivator(LogicalKeyboardKey.keyY, control: true):
                  _controller.redo,
              const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                  _export,
              const SingleActivator(LogicalKeyboardKey.delete):
                  _controller.deleteSelected,
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_controller.hasSelection) {
                  _controller.clearSelection();
                } else {
                  _confirmLeave();
                }
              },
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    onPressed: _confirmLeave,
                    icon: const BackButtonIcon(),
                    tooltip: l10n.close,
                  ),
                  titleSpacing: 0,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.image.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.imageInfo(
                          widget.image.width,
                          widget.image.height,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    _CompareButton(controller: _controller),
                    PopupMenuButton<String>(
                      tooltip: l10n.moreActions,
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (value) {
                        if (value == 'clear') _clearAll();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'clear',
                          enabled: _controller.hasMasks,
                          child: Row(
                            children: [
                              const Icon(Icons.layers_clear_rounded, size: 20),
                              const SizedBox(width: 12),
                              Text(l10n.clearAll),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
                      child: wide
                          ? FilledButton.icon(
                              onPressed: _controller.busy ? null : _export,
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text(l10n.export),
                            )
                          : IconButton.filled(
                              onPressed: _controller.busy ? null : _export,
                              icon: const Icon(Icons.download_rounded, size: 20),
                              tooltip: l10n.export,
                            ),
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: EditorCanvas(
                              controller: _controller,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                12,
                              ),
                            ),
                          ),
                          if (_controller.hasPending)
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: _PendingBar(controller: _controller),
                            )
                          else if (_controller.draft == null &&
                              !_controller.busy &&
                              (_controller.hasSelection ||
                                  !_controller.hasMasks))
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 14,
                              child: IgnorePointer(
                                child: Center(
                                  child: _ToolHint(
                                    tool: _controller.tool,
                                    selectionCount:
                                        _controller.selectionCount,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ToolDock(
                      controller: _controller,
                      onScan: _runScan,
                      scanBusy: _scanRunning,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompareButton extends StatelessWidget {
  const _CompareButton({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.compareHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => controller.setShowOriginal(true),
        onTapUp: (_) => controller.setShowOriginal(false),
        onTapCancel: () => controller.setShowOriginal(false),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            controller.showOriginal
                ? Icons.visibility_rounded
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }
}

class _ToolHint extends StatelessWidget {
  const _ToolHint({required this.tool, required this.selectionCount});

  final EditorTool tool;
  final int selectionCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = switch (selectionCount) {
      0 => switch (tool) {
        EditorTool.brush => l10n.brushHint,
        EditorTool.box => l10n.boxHint,
        EditorTool.select => l10n.selectHint,
      },
      1 => l10n.selectionHint,
      _ => l10n.selectionHintMulti(selectionCount),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey('$tool-$selectionCount'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.inverseSurface.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onInverseSurface,
          ),
        ),
      ),
    );
  }
}

/// The confirmation step for a scan.
///
/// Nothing a detector returns is applied automatically. The boxes stay as
/// outlines you can tap on and off, which is the only honest way to ship a
/// heuristic: you get to look at what it thought before it touches the picture.
class _PendingBar extends StatelessWidget {
  const _PendingBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = controller.pending.length;
    final chosen = controller.pendingSelectedCount;
    final all = chosen == total;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.pendingHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.pendingCount(chosen, total),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton(
                  onPressed: () => controller.setAllPending(!all),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(all ? l10n.pendingClear : l10n.pendingAll),
                ),
                const Spacer(),
                TextButton(
                  onPressed: controller.cancelPending,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: chosen == 0 ? null : controller.commitPending,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l10n.apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
