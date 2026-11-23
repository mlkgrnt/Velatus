import 'package:material_ui/material_ui.dart';

import '../../../domain/mask_region.dart';
import '../../../l10n/app_localizations.dart';
import '../editor_controller.dart';

class LayerPanel extends StatelessWidget {
  const LayerPanel({
    super.key,
    required this.controller,
    this.embedded = false,
  });

  final EditorController controller;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final regions = controller.regions.reversed.toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
          child: Row(
            children: [
              Text(
                l10n.layers,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${regions.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Spacer(),
              if (regions.isNotEmpty)
                IconButton(
                  onPressed: () => _confirmClear(context),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 19),
                  tooltip: l10n.clearAll,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        if (regions.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.layers_clear_outlined,
                      size: 34,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.emptyLayers,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.emptyLayersBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              itemCount: regions.length,
              itemBuilder: (context, index) {
                final region = regions[index];
                return _LayerTile(
                  region: region,
                  selected: controller.selectedId == region.id,
                  onTap: () => controller.selectRegion(region.id),
                  onToggle: () => controller.toggleVisibility(region.id),
                  onDelete: () => controller.deleteRegion(region.id),
                );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.layersHint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!embedded) return content;

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF12161D)
            : const Color(0xFFFBFBFD),
        border: Border(
          left: BorderSide(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF232833)
                : const Color(0xFFE9ECF2),
          ),
        ),
      ),
      child: content,
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
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
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.clearAll();
  }
}

class _LayerTile extends StatelessWidget {
  const _LayerTile({
    required this.region,
    required this.selected,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final MaskRegion region;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final icon = switch (region.style) {
      MaskStyle.mosaic => Icons.grid_on_rounded,
      MaskStyle.blur => Icons.blur_on_rounded,
      MaskStyle.solid => Icons.square_rounded,
    };
    final styleLabel = switch (region.style) {
      MaskStyle.mosaic => l10n.maskMosaic,
      MaskStyle.blur => l10n.maskBlur,
      MaskStyle.solid => l10n.maskSolid,
    };
    final shapeLabel = switch (region.shape) {
      MaskShape.stroke => l10n.toolBrush,
      MaskShape.rect => l10n.toolRect,
      MaskShape.ellipse => l10n.toolEllipse,
      MaskShape.lasso => l10n.toolLasso,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: region.visible
                        ? theme.colorScheme.surfaceContainerHighest
                        : theme.colorScheme.surfaceContainerHigh.withValues(
                            alpha: 0.4,
                          ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: region.visible
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$styleLabel · $shapeLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: region.visible
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(region.strength * 100).round()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    region.visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 17,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: region.visible ? l10n.hide : l10n.show,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.deleteMask,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
