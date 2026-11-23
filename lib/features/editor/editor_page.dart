import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export_saver.dart';
import '../../services/image_loader.dart';
import '../../services/ocr_service.dart';
import 'editor_controller.dart';
import 'widgets/editor_canvas.dart';
import 'widgets/export_sheet.dart';
import 'widgets/layer_panel.dart';
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
  bool _ocrRunning = false;
  bool _allowPop = false;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? EditorController(image: widget.image);
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

  Future<void> _runOcr() async {
    if (_ocrRunning) return;
    if (!OcrService.isSupported) {
      _showMessage(l10n.ocrUnavailable);
      return;
    }
    setState(() => _ocrRunning = true);
    try {
      final regions = await OcrService.detect(
        widget.image,
        style: _controller.style,
        strength: _controller.strength,
      );
      if (!mounted) return;
      if (regions.isEmpty) {
        _showMessage(l10n.ocrNone);
      } else {
        _controller.addRegions(regions);
        _showMessage(l10n.ocrFound(regions.length));
      }
    } catch (error) {
      _showMessage(l10n.ocrFailed);
    } finally {
      if (mounted) setState(() => _ocrRunning = false);
    }
  }

  Future<void> _export() async {
    if (_controller.busy) return;
    final selection = await showExportSheet(
      context,
      image: widget.image,
      canGallery: ExportSaver.canSaveToGallery,
    );
    if (selection == null || !mounted) return;

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
        return;
      }

      final saved = await ExportSaver.save(
        result,
        toGallery: selection.toGallery,
      );
      if (!mounted) return;
      if (saved.ok) {
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

  Future<void> _showLayers() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => LayerPanel(controller: _controller),
        ),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    if (_allowPop) return;
    if (!_controller.hasMasks) {
      _popNow();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: _allowPop || !_controller.hasMasks,
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
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (_controller.selectedId != null) {
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
                    if (!wide)
                      IconButton(
                        onPressed: _showLayers,
                        icon: const Icon(Icons.layers_outlined),
                        tooltip: l10n.layers,
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
                body: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: EditorCanvas(
                                    controller: _controller,
                                    padding: EdgeInsets.fromLTRB(
                                      wide ? 32 : 12,
                                      12,
                                      wide ? 32 : 12,
                                      12,
                                    ),
                                  ),
                                ),
                                if (!_controller.hasMasks &&
                                    _controller.draft == null &&
                                    !_controller.busy)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 18,
                                    child: IgnorePointer(
                                      child: Center(
                                        child: _ToolHint(
                                          tool: _controller.tool,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ToolDock(
                            controller: _controller,
                            onOcr: OcrService.isSupported ? _runOcr : null,
                            ocrBusy: _ocrRunning,
                          ),
                        ],
                      ),
                    ),
                    if (wide)
                      LayerPanel(controller: _controller, embedded: true),
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
    return Listener(
      onPointerDown: (_) => controller.setShowOriginal(true),
      onPointerUp: (_) => controller.setShowOriginal(false),
      onPointerCancel: (_) => controller.setShowOriginal(false),
      child: IconButton(
        onPressed: () {},
        icon: Icon(
          controller.showOriginal
              ? Icons.visibility_rounded
              : Icons.visibility_outlined,
        ),
        tooltip: l10n.compare,
      ),
    );
  }
}

class _ToolHint extends StatelessWidget {
  const _ToolHint({required this.tool});

  final EditorTool tool;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = switch (tool) {
      EditorTool.brush => l10n.brushHint,
      EditorTool.rect => l10n.rectHint,
      EditorTool.ellipse => l10n.ellipseHint,
      EditorTool.lasso => l10n.lassoHint,
      EditorTool.select => l10n.selectHint,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(tool),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.inverseSurface.withValues(alpha: 0.88),
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
