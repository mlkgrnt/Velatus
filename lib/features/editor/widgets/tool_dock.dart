import 'package:material_ui/material_ui.dart';

import '../../../domain/mask_region.dart';
import '../../../l10n/app_localizations.dart';
import '../editor_controller.dart';

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
      (EditorTool.rect, Icons.crop_square_rounded, l10n.toolRect),
      (EditorTool.ellipse, Icons.circle_outlined, l10n.toolEllipse),
      (EditorTool.lasso, Icons.gesture_rounded, l10n.toolLasso),
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
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                      const SizedBox(width: 4),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StyleChip(
                        icon: Icons.grid_on_rounded,
                        label: l10n.maskMosaic,
                        selected: controller.style == MaskStyle.mosaic,
                        onTap: () => controller.setStyle(MaskStyle.mosaic),
                      ),
                      const SizedBox(width: 6),
                      _StyleChip(
                        icon: Icons.blur_on_rounded,
                        label: l10n.maskBlur,
                        selected: controller.style == MaskStyle.blur,
                        onTap: () => controller.setStyle(MaskStyle.blur),
                      ),
                      const SizedBox(width: 6),
                      _StyleChip(
                        icon: Icons.square_rounded,
                        label: l10n.maskSolid,
                        selected: controller.style == MaskStyle.solid,
                        onTap: () => controller.setStyle(MaskStyle.solid),
                      ),
                      const Spacer(),
                      if (onOcr != null)
                        TextButton.icon(
                          onPressed: ocrBusy ? null : onOcr,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: ocrBusy
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.document_scanner_outlined, size: 17),
                          label: Text(
                            l10n.ocrAction,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _ParameterRow(controller: controller),
                ],
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
      style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : null,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.55)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParameterRow extends StatelessWidget {
  const _ParameterRow({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showSize = controller.tool == EditorTool.brush ||
        (controller.selectedRegion?.isStroke ?? false);

    return Row(
      children: [
        if (showSize) ...[
          Expanded(
            child: _MiniSlider(
              icon: Icons.line_weight_rounded,
              tooltip: l10n.brushSize,
              value: controller.brushSize,
              min: 0.01,
              max: 0.2,
              onStart: controller.beginScrub,
              onEnd: controller.endScrub,
              onChanged: controller.setBrushSize,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: controller.style == MaskStyle.solid
              ? _ColorPicker(controller: controller)
              : _MiniSlider(
                  icon: Icons.opacity_rounded,
                  tooltip: l10n.strength,
                  value: controller.strength,
                  min: 0.05,
                  max: 1,
                  onStart: controller.beginScrub,
                  onEnd: controller.endScrub,
                  onChanged: controller.setStrength,
                ),
        ),
      ],
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
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          Expanded(
            child: SliderTheme(
              data: theme.sliderTheme.copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
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
            width: 36,
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
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.controller});

  final EditorController controller;

  static const _colors = [
    Color(0xFF14161C),
    Color(0xFFFFFFFF),
    Color(0xFF3D4A63),
    Color(0xFFB3261E),
    Color(0xFF1B5E20),
    Color(0xFF4A63D8),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final color in _colors)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => controller.setSolidColor(color),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: controller.solidColor.toARGB32() == color.toARGB32()
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: controller.solidColor.toARGB32() == color.toARGB32()
                        ? 2.5
                        : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
