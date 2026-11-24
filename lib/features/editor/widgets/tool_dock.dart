import 'package:material_ui/material_ui.dart';

import '../../../domain/mask_region.dart';
import '../../../l10n/app_localizations.dart';
import '../editor_controller.dart';
import 'color_picker_dialog.dart';

/// The bottom bar.
///
/// Exactly two rows, both with a fixed height:
///
///  1. *what* — the three tools, plus the actions that apply to the document.
///  2. *with what* — the style chips and the two numbers that describe the
///     current mask.
///
/// The earlier layout stacked a variable number of sliders and gave the colour
/// palette a row of its own, so the dock grew and shrank with every tool change
/// and the photo above it jumped. Fixing both row heights means the canvas size
/// is a constant, and the palette now lives one tap away inside the colour
/// dialog instead of stealing a whole row.
class ToolDock extends StatelessWidget {
  const ToolDock({
    super.key,
    required this.controller,
    this.onScan,
    this.scanBusy = false,
  });

  final EditorController controller;

  /// Runs the detectors. Null hides the action.
  final VoidCallback? onScan;
  final bool scanBusy;

  static const double _rowOneHeight = 48;
  static const double _rowTwoHeight = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tools = <(EditorTool, IconData, String)>[
      (EditorTool.brush, Icons.brush_outlined, l10n.toolBrush),
      (EditorTool.box, Icons.crop_square, l10n.toolBox),
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
                  SizedBox(
                    height: _rowOneHeight,
                    child: Row(
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
                        _DockAction(
                          icon: Icons.document_scanner_outlined,
                          tooltip: l10n.scanAction,
                          onTap: scanBusy ? null : onScan,
                          busy: scanBusy,
                        ),
                        _DockAction(
                          icon: Icons.undo_rounded,
                          tooltip: l10n.undo,
                          onTap: controller.canUndo ? controller.undo : null,
                        ),
                        _DockAction(
                          icon: Icons.redo_rounded,
                          tooltip: l10n.redo,
                          onTap: controller.canRedo ? controller.redo : null,
                        ),
                        _DockAction(
                          icon: Icons.delete_outline_rounded,
                          tooltip: l10n.deleteMask,
                          onTap: controller.hasSelection
                              ? controller.deleteSelected
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: _rowTwoHeight,
                    child: _ParametersRow(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Style chips on the left, then one or two parameter sliders.
class _ParametersRow extends StatelessWidget {
  const _ParametersRow({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // Which geometry slider makes sense right now. A brush stroke has a width;
    // a box has a corner radius; the select tool has whichever the primary
    // region happens to be, and nothing at all when nothing is selected.
    final bool? strokeGeometry = switch (controller.tool) {
      EditorTool.brush => true,
      EditorTool.box => false,
      EditorTool.select => controller.primaryRegion?.isStroke,
    };

    final solid = controller.style == MaskStyle.solid;

    return Row(
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
          selected: solid,
          onTap: () => controller.setStyle(MaskStyle.solid),
        ),
        const SizedBox(width: 10),
        _VerticalRule(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            // These keys are not decoration. The row is built with `if`s, so
            // switching to 色块 / back, or between brush width and corner
            // radius, changes the child count. Without keys Flutter reuses the
            // same `Slider` State for a different parameter — its drag state,
            // cached value and min/max then belong to the previous slider, which
            // is exactly how dragging one bar appeared to move both.
            children: [
              if (!solid)
                Expanded(
                  key: const ValueKey('slot-strength'),
                  child: _ParamSlider(
                    key: const ValueKey('param-strength'),
                    icon: Icons.opacity_rounded,
                    tooltip: l10n.strength,
                    value: controller.strength,
                    // Zero is a real choice: at the far left the mask leaves the
                    // pixels alone, so the whole range from "nothing" to "fully
                    // dissolved" is available without changing tools.
                    min: 0,
                    max: 1,
                    onStart: controller.beginScrub,
                    onEnd: controller.endScrub,
                    onChanged: controller.setStrength,
                  ),
                ),
              if (!solid && strokeGeometry != null)
                const SizedBox(key: ValueKey('slot-gap'), width: 10),
              if (strokeGeometry != null)
                Expanded(
                  key: const ValueKey('slot-geometry'),
                  child: strokeGeometry
                      ? _ParamSlider(
                          key: const ValueKey('param-brushSize'),
                          icon: Icons.line_weight_rounded,
                          tooltip: l10n.brushSize,
                          value: controller.brushSize,
                          min: 0.01,
                          max: 0.2,
                          onStart: controller.beginScrub,
                          onEnd: controller.endScrub,
                          onChanged: controller.setBrushSize,
                        )
                      : _ParamSlider(
                          key: const ValueKey('param-radius'),
                          icon: Icons.rounded_corner,
                          tooltip: l10n.cornerRadius,
                          value: controller.radius,
                          min: 0,
                          max: 0.5,
                          onStart: controller.beginScrub,
                          onEnd: controller.endScrub,
                          onChanged: controller.setRadius,
                        ),
                ),
            ],
          ),
        ),
        if (solid) ...[
          const SizedBox(width: 8),
          _ColorButton(controller: controller),
        ],
      ],
    );
  }
}

/// The single colour control: a swatch that opens the palette.
///
/// Presets used to sit inline, eight circles at a time, which cost a whole dock
/// row and still scrolled on a 360 dp phone. They are now the first thing the
/// dialog shows.
class _ColorButton extends StatelessWidget {
  const _ColorButton({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: AppLocalizations.of(context).color,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          final picked = await showColorPickerDialog(
            context,
            initial: controller.solidColor,
          );
          if (picked != null) controller.setSolidColor(picked);
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: controller.solidColor,
                borderRadius: BorderRadius.circular(7),
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

class _VerticalRule extends StatelessWidget {
  const _VerticalRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 22, color: color);
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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.secondaryContainer : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10.5,
                height: 1.1,
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

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 19),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(minimumSize: const Size(33, 38)),
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
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.13)
                : null,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.6)
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A slider with no numeric readout.
///
/// On a phone the track earns the space: two sliders have to share one row, and
/// a percentage label is worth less than 20 px of track when the whole point is
/// judging the effect on the picture itself.
class _ParamSlider extends StatelessWidget {
  const _ParamSlider({
    super.key,
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
    final percent = ((value.clamp(min, max) - min) / (max - min) * 100).round();
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 1),
          Expanded(
            child: Semantics(
              label: tooltip,
              value: '$percent%',
              child: SliderTheme(
                data: theme.sliderTheme.copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                  overlayColor: theme.colorScheme.primary.withValues(
                    alpha: 0.12,
                  ),
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
          ),
        ],
      ),
    );
  }
}
