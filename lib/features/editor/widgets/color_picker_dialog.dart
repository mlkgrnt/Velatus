import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// A compact HSV picker.
///
/// The palette in the tool dock covers the common cases; this exists for the
/// ones it does not (brand colours, a specific PDF beige, whatever a screenshot
/// happens to sit on).
Future<Color?> showColorPickerDialog(
  BuildContext context, {
  required Color initial,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      title: Text(l10n.customColor),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 148,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _Pad(
                  hsv: _hsv,
                  onChanged: (s, v) => setState(
                    () => _hsv = _hsv.withSaturation(s).withValue(v),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 22,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _HueBar(
                  hue: _hsv.hue,
                  onChanged: (hue) => setState(() => _hsv = _hsv.withHue(hue)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _hex(_color),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: Text(l10n.done),
        ),
      ],
    );
  }

  static String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final void Function(double saturation, double value) onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        void report(Offset local) {
          onChanged(
            (local.dx / size.width).clamp(0.0, 1.0),
            1 - (local.dy / size.height).clamp(0.0, 1.0),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => report(details.localPosition),
          onPanUpdate: (details) => report(details.localPosition),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor(),
                    ],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xFF000000)],
                  ),
                ),
              ),
              Positioned(
                left: hsv.saturation * size.width - 8,
                top: (1 - hsv.value) * size.height - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    const stops = [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void report(Offset local) =>
            onChanged((local.dx / width).clamp(0.0, 0.999) * 360);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => report(details.localPosition),
          onPanUpdate: (details) => report(details.localPosition),
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: stops),
                  ),
                ),
              ),
              Positioned(
                left: (hue / 360 * width) - 3,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
