import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../core/app_info.dart';
import '../../core/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/image_loader.dart';
import '../editor/editor_page.dart';
import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _dragging = false;
  bool _opening = false;

  AppLocalizations get l10n => AppLocalizations.of(context);

  Future<void> _pick() async {
    if (_opening) return;
    try {
      String? path;
      if (Platform.isAndroid || Platform.isIOS) {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          requestFullMetadata: false,
        );
        path = picked?.path;
      } else {
        const group = XTypeGroup(
          label: 'Images',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic'],
        );
        final file = await openFile(acceptedTypeGroups: const [group]);
        path = file?.path;
      }
      if (path == null) return;
      await _open(path);
    } catch (error) {
      _showMessage(l10n.openFailed);
    }
  }

  Future<void> _open(String path) async {
    if (_opening) return;
    setState(() => _opening = true);
    LoadedImage? loaded;
    try {
      loaded = await ImageLoader.fromPath(path);
      if (!mounted) {
        loaded.preview.dispose();
        return;
      }
      await widget.settings.addRecent(path: path, name: loaded.name);
      if (!mounted) {
        loaded.preview.dispose();
        return;
      }
      final image = loaded;
      loaded = null;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditorPage(image: image, settings: widget.settings),
        ),
      );
    } on ImageLoadException catch (error) {
      _showMessage('${l10n.openFailed}: ${error.message}');
    } catch (error) {
      _showMessage(l10n.openFailed);
    } finally {
      loaded?.preview.dispose();
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(settings: widget.settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      body: SafeArea(
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (details) {
            setState(() => _dragging = false);
            if (details.files.isNotEmpty) {
              _open(details.files.first.path);
            }
          },
          child: Stack(
            children: [
              Positioned.fill(child: _Backdrop(dragging: _dragging)),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 40 : 22,
                          vertical: 18,
                        ),
                        sliver: SliverList.list(
                          children: [
                            _Header(onSettings: _openSettings),
                            SizedBox(height: isWide ? 64 : 40),
                            _Hero(
                              opening: _opening,
                              isWide: isWide,
                              onPick: _pick,
                            ),
                            SizedBox(height: isWide ? 56 : 40),
                            _FeatureGrid(isWide: isWide),
                            if (widget.settings.recent.isNotEmpty) ...[
                              const SizedBox(height: 40),
                              _RecentSection(
                                settings: widget.settings,
                                onOpen: _open,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(22, 24, 22, 20),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _Footer(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_dragging)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                        color: theme.colorScheme.primary.withValues(alpha: 0.06),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        l10n.dropHint,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(),
        const Spacer(),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.tune_rounded),
          tooltip: AppLocalizations.of(context).settings,
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.opening,
    required this.isWide,
    required this.onPick,
  });

  final bool opening;
  final bool isWide;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final copy = Column(
      crossAxisAlignment:
          isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          l10n.appName,
          textAlign: isWide ? TextAlign.start : TextAlign.center,
          style: (isWide ? theme.textTheme.displayMedium : theme.textTheme.displaySmall)
              ?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.tagline,
          textAlign: isWide ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.taglineSub,
          textAlign: isWide ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: opening ? null : onPick,
              icon: opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: Text(
                Platform.isAndroid || Platform.isIOS
                    ? l10n.pickFromGallery
                    : l10n.openImage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 15,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                l10n.featureLocalTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (isWide) ...[
          const SizedBox(height: 32),
          Text(
            l10n.dropSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    if (!isWide) {
      return Column(
        children: [
          const VelatusBrand(size: 88, radius: 26),
          const SizedBox(height: 26),
          copy,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 6, child: copy),
        const SizedBox(width: 48),
        Expanded(
          flex: 4,
          child: Align(
            alignment: Alignment.centerRight,
            child: _PreviewStack(),
          ),
        ),
      ],
    );
  }
}

/// A miniature of the editor rather than a stock illustration: it tells you
/// what the app actually looks like before you open anything.
class _PreviewStack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.05,
            child: Container(
              width: 330,
              height: 236,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          _MiniEditor(isDark: isDark),
          Positioned(
            bottom: 4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).exifStripped,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniEditor extends StatelessWidget {
  const _MiniEditor({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = isDark ? const Color(0xFF1A2029) : Colors.white;
    final canvas = isDark ? const Color(0xFF0C0F15) : const Color(0xFF1B2130);

    return Container(
      width: 348,
      height: 252,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3140) : const Color(0xFFE6E9F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final color in [
                const Color(0xFFFF5F57),
                const Color(0xFFFEBC2E),
                const Color(0xFF28C840),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                'IMG_2048.png',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.more_horiz_rounded,
                size: 13,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: canvas,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF2C3A55),
                              const Color(0xFF12161F),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // A miniature screenshot caught mid-redaction: light card,
                    // chat bubbles, one pixelated band and one solid bar.
                    Center(
                      child: Container(
                        width: 204,
                        height: 138,
                        padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F8),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 11,
                                  height: 11,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFCBD1DD),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const _MiniLine(width: 30),
                                const Spacer(),
                                const _MiniLine(
                                  width: 12,
                                  height: 3,
                                  color: Color(0xFFDDE1E9),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const _MiniBubble(
                              width: 104,
                              color: Color(0xFFE2E6EF),
                            ),
                            const SizedBox(height: 5),
                            const _MiniBubble(
                              width: 68,
                              color: Color(0xFFAEEFA0),
                              alignEnd: true,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: SizedBox(
                                  width: 112,
                                  height: 13,
                                  child: Row(
                                    children: [
                                      for (var i = 0; i < 8; i++)
                                        Expanded(
                                          child: SizedBox.expand(
                                            child: ColoredBox(
                                              color: i.isEven
                                                  ? const Color(0xFF5B6B8C)
                                                  : const Color(0xFF9AA7C4),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const _MiniBubble(
                              width: 58,
                              color: Color(0xFFAEEFA0),
                              alignEnd: true,
                            ),
                            const Spacer(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 118,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF12141A),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 14,
                      child: Row(
                        children: [
                          Icon(
                            Icons.brush_outlined,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.crop_square,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.crop_square_rounded,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? theme.colorScheme.primary.withValues(alpha: 0.16)
                          : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      const [
                        Icons.brush_outlined,
                        Icons.crop_square,
                        Icons.crop_square_rounded,
                        Icons.touch_app_outlined,
                      ][i],
                      size: 12,
                      color: i == 0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                ),
              const Spacer(),
              Icon(
                Icons.undo_rounded,
                size: 12,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.redo_rounded,
                size: 12,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A 3 px tall grey bar standing in for text in the miniature screenshot.
class _MiniLine extends StatelessWidget {
  const _MiniLine({
    required this.width,
    this.height = 4,
    this.color = const Color(0xFFCBD1DD),
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// A chat bubble placeholder with two faint text lines inside.
class _MiniBubble extends StatelessWidget {
  const _MiniBubble({
    required this.width,
    required this.color,
    this.alignEnd = false,
  });

  final double width;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: 15,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MiniLine(
              width: width * 0.52,
              height: 2.5,
              color: Colors.black.withValues(alpha: 0.18),
            ),
            const Spacer(),
            _MiniLine(
              width: width * 0.3,
              height: 2.5,
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Feature = ({IconData icon, String title, String body});

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final features = <_Feature>[
      (
        icon: Icons.high_quality_outlined,
        title: l10n.featureExportTitle,
        body: l10n.featureExportBody,
      ),
      (
        icon: Icons.undo_rounded,
        title: l10n.featureLayersTitle,
        body: l10n.featureLayersBody,
      ),
      (
        icon: Icons.text_fields_rounded,
        title: l10n.featureOcrTitle,
        body: l10n.featureOcrBody,
      ),
    ];

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < features.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: _FeatureCard(feature: features[i])),
          ],
        ],
      );
    }
    // Three stacked cards wasted most of a phone screen on padding and gaps.
    // One card with hairline dividers fits the same information in a third of
    // the height and reads as a list instead of three competing boxes.
    return _FeatureList(features: features);
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.features});

  final List<_Feature> features;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < features.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 46,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      features[i].icon,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          features[i].title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          features[i].body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature.icon, size: 21, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            feature.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            feature.body,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.settings, required this.onOpen});

  final SettingsController settings;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.recent,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: settings.clearRecent,
              child: Text(l10n.clearRecent),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < settings.recent.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ListTile(
                  onTap: () => onOpen(settings.recent[i].path),
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    settings.recent[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    settings.recent[i].path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        settings.removeRecent(settings.recent[i].path),
                    tooltip: l10n.delete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Velatus $kAppVersion',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.of(context).footerNote,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.dragging});

  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.15, -0.75),
          radius: 1.15,
          colors: [
            theme.colorScheme.primary.withValues(
              alpha: dragging ? 0.16 : (isDark ? 0.10 : 0.075),
            ),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
    );
  }
}
