import 'package:material_ui/material_ui.dart';

import '../../../domain/mask_region.dart';
import '../../../l10n/app_localizations.dart';
import '../editor_controller.dart';
import 'color_picker_dialog.dart';

/// The bottom bar.
///
/// Two layers only: tools on top, and a single context row underneath that
/// swaps its contents for whatever the current tool actually needs. Keeping the
/// brush size and the strength on their own stacked sliders frees the
/// horizontal room the colour swatches were missing.
class ToolDock extends StatelessWidget {
  const ToolDock({
    super.key,
    required this.controller,
    this.onOcr,
    this.ocrBusy = false,
  });

  final EditorController controller;
  final VoidCallback? onOcr;
  final bool ocrBusy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tools = <(EditorTool, IconData, String)>[
      (EditorTool.brush, Icons.brush_outlined, l10n.toolBrush),
      (EditorTool.rect, Icons.crop_square, l10n.toolRect),
      (
        EditorTool.roundedRect,
        Icons.crop_square_rounded,
        l10n.toolRoundedRect,
      ),
      (EditorTool.select, Icons.touch_app_outlined, l10n.toolSelect),
    ];

    return Material(
      color: isDark ? const Color(0xFF161A22) : Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF242A35)
                    : const Color(0xFFE8EBF1),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      for (final tool in tools)
                        Expanded(
                          child: _ToolButton(
                            icon: tool.$2,
                            label: tool.$3,
                            selected: controller.tool == tool.$1,
                            onTap: () => controller.setTool(tool.$1),
                          ),
                        ),
                      const SizedBox(width: 2),
                      _CompactAction(
                        icon: Icons.undo_rounded,
                        tooltip: l10n.undo,
                        onTap: controller.canUndo ? controller.undo : null,
                      ),
                      _CompactAction(
                        icon: Icons.redo_rounded,
                        tooltip: l10n.redo,
                        onTap: controller.canRedo ? controller.redo : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _StyleChip(
                        icon: Icons.grid_on_rounded,
                        label: l10n.maskMosaic,
                        selected: controller.style == MaskStyle.mosaic,
                        onTap: () => controller.setStyle(MaskStyle.mosaic),
                      ),
                      const SizedBox(width: 4),
                      _StyleChip(
                        icon: Icons.blur_on_rounded,
                        label: l10n.maskBlur,
                        selected: controller.style == MaskStyle.blur,
                        onTap: () => controller.setStyle(MaskStyle.blur),
                      ),
                      const SizedBox(width: 4),
                      _StyleChip(
                        icon: Icons.square,
                        label: l10n.maskSolid,
                        selected: controller.style == MaskStyle.solid,
                        onTap: () => controller.setStyle(MaskStyle.solid),
                      ),
                      if (controller.style != MaskStyle.solid) ...[
                        const SizedBox(width: 10),
                        Container(
                          width: 1,
                          height: 26,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _ContextRow(controller: controller)),
                      ] else
                        const Spacer(),
                      if (onOcr != null) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: ocrBusy ? null : onOcr,
                          icon: ocrBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.document_scanner_outlined,
                                  size: 19,
                                ),
                          tooltip: l10n.ocrAction,
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(34, 34),
                          ),
                        ),
                      ],
                      if (controller.hasSelection) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: controller.deleteSelected,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
                          tooltip: l10n.deleteMask,
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(34, 34),
                            foregroundColor: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (controller.style == MaskStyle.solid) ...[
                    const SizedBox(height: 6),
                    // Colours get their own full-width row. Sharing the line
                    // with the style chips left only four of eight swatches
                    // visible on a 360 dp phone, which is exactly the "显示不全"
                    // the colour picker was meant to fix.
                    _ColorRow(controller: controller),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedRegion;
    final showSize = controller.tool == EditorTool.brush ||
        (selected?.isStroke ?? false);
    final showRadius = (controller.tool == EditorTool.roundedRect &&
            selected == null) ||
        selected?.shape == MaskShape.roundedRect;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniSlider(
          icon: Icons.opacity_rounded,
          tooltip: AppLocalizations.of(context).strength,
          value: controller.strength,
          min: 0.05,
          max: 1,
          onStart: controller.beginScrub,
          onEnd: controller.endScrub,
          onChanged: controller.setStrength,
        ),
        if (showSize)
          _MiniSlider(
            icon: Icons.line_weight_rounded,
            tooltip: AppLocalizations.of(context).brushSize,
            value: controller.brushSize,
            min: 0.01,
            max: 0.2,
            onStart: controller.beginScrub,
            onEnd: controller.endScrub,
            onChanged: controller.setBrushSize,
          ),
        if (showRadius)
          _MiniSlider(
            icon: Icons.rounded_corner,
            tooltip: AppLocalizations.of(context).cornerRadius,
            value: controller.radius,
            min: 0,
            max: 0.5,
            onStart: controller.beginScrub,
            onEnd: controller.endScrub,
            onChanged: controller.setRadius,
          ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.controller});

  final EditorController controller;

  static const _colors = [
    Color(0xFF14161C),
    Color(0xFFFFFFFF),
    Color(0xFF3D4A63),
    Color(0xFFB3261E),
    Color(0xFF1B5E20),
    Color(0xFF4A63D8),
    Color(0xFFE0A106),
    Color(0xFF7B1FA2),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final color in _colors)
                    _Swatch(
                      color: color,
                      selected:
                          controller.solidColor.toARGB32() == color.toARGB32(),
                      onTap: () => controller.setSolidColor(color),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: l10n.customColor,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final picked = await showColorPickerDialog(
                  context,
                  initial: controller.solidColor,
                );
                if (picked != null) controller.setSolidColor(picked);
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Icon(
                  Icons.colorize_rounded,
                  size: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                // A dark swatch on a dark bar (or white on white) needs an edge
                // of its own, otherwise it reads as a hole.
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.9,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.secondaryContainer : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(minimumSize: const Size(34, 34)),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color:
                selected ? theme.colorScheme.primary.withValues(alpha: 0.13) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.6)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MiniSlider extends StatelessWidget {
  const _MiniSlider({
    required this.icon,
    required this.tooltip,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.onStart,
    required this.onEnd,
  });

  final IconData icon;
  final String tooltip;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 30,
      child: Tooltip(
        message: tooltip,
        child: Row(
          children: [
            Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 2),
            Expanded(
              child: SliderTheme(
                data: theme.sliderTheme.copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
                ),
                child: Slider(
                  value: value.clamp(min, max),
                  min: min,
                  max: max,
                  onChanged: onChanged,
                  onChangeStart: (_) => onStart(),
                  onChangeEnd: (_) => onEnd(),
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '${(value * 100).round()}%',
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
