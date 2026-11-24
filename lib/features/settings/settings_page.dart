import 'package:material_ui/material_ui.dart';

import '../../app.dart';
import '../../core/app_info.dart';
import '../../core/settings_controller.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/update_dialog.dart';

/// One entry of the language picker.
///
/// Languages are listed in their own words — someone who needs 繁體中文 should
/// not have to find it under an English label.
class _LanguageOption {
  const _LanguageOption(this.tag, this.label, this.locale);

  final String tag;
  final String label;
  final Locale? locale;
}

final List<_LanguageOption> _languageOptions = <_LanguageOption>[
  const _LanguageOption('zh', '简体中文', Locale('zh')),
  _LanguageOption(
    'zh_Hant',
    '繁體中文',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ),
  const _LanguageOption('en', 'English', Locale('en')),
  const _LanguageOption('es', 'Español', Locale('es')),
  const _LanguageOption('fr', 'Français', Locale('fr')),
];

String _tagOf(Locale locale) {
  final script = locale.scriptCode;
  return script == null || script.isEmpty
      ? locale.languageCode
      : '${locale.languageCode}_$script';
}

String _labelOf(Locale locale) {
  final tag = _tagOf(locale);
  for (final option in _languageOptions) {
    if (option.tag == tag) return option.label;
  }
  return locale.languageCode;
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          // Read inside the builder: the row has to follow the picker, and the
          // outer build does not run again when a setting changes.
          final locale = settings.locale;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _SectionLabel(l10n.appearance),
              SoftCard(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    _ThemeTile(
                      icon: Icons.brightness_auto_outlined,
                      label: l10n.themeSystem,
                      selected: settings.themeMode == ThemeMode.system,
                      onTap: () => settings.setThemeMode(ThemeMode.system),
                    ),
                    const SizedBox(width: 8),
                    _ThemeTile(
                      icon: Icons.light_mode_outlined,
                      label: l10n.themeLight,
                      selected: settings.themeMode == ThemeMode.light,
                      onTap: () => settings.setThemeMode(ThemeMode.light),
                    ),
                    const SizedBox(width: 8),
                    _ThemeTile(
                      icon: Icons.dark_mode_outlined,
                      label: l10n.themeDark,
                      selected: settings.themeMode == ThemeMode.dark,
                      onTap: () => settings.setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionLabel(l10n.language),
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _LinkRow(
                  icon: Icons.translate_rounded,
                  title: l10n.language,
                  subtitle: locale == null
                      ? l10n.languageSystem
                      : _labelOf(locale),
                  external: false,
                  onTap: () => _pickLanguage(context, l10n, settings),
                ),
              ),
              const SizedBox(height: 24),
              _SectionLabel(l10n.about),
              SoftCard(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const VelatusBrand(size: 52, radius: 15),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _appTitle(l10n.appName),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$kAppVersion · MIT',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.aboutBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    _LinkRow(
                      icon: Icons.system_update_alt_rounded,
                      title: l10n.checkUpdate,
                      subtitle: l10n.checkUpdateNote,
                      external: false,
                      onTap: () => showUpdateFlow(context),
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    _LinkRow(
                      icon: Icons.code_rounded,
                      title: l10n.repository,
                      subtitle: 'github.com/mlkgrnt/Velatus',
                      onTap: () async {
                        final opened = await AppLinks.openRepository();
                        if (!opened && context.mounted) {
                          _toast(context, kRepoUrl);
                        }
                      },
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => showLicensePage(
                            context: context,
                            applicationName: l10n.appName,
                            applicationVersion: kAppVersion,
                          ),
                          icon: const Icon(Icons.article_outlined, size: 18),
                          label: Text(l10n.licenses),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Last, and deliberately so: this is a statement, not a setting.
              const SizedBox(height: 24),
              _SectionLabel(l10n.privacy),
              SoftCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        l10n.privacyBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// "Velatus" on its own outside Chinese, "隐格 · Velatus" inside it.
  static String _appTitle(String name) =>
      name == 'Velatus' ? 'Velatus' : '$name · Velatus';

  Future<void> _pickLanguage(
    BuildContext context,
    AppLocalizations l10n,
    SettingsController settings,
  ) async {
    final current = settings.locale;
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.language),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          content: RadioGroup<String>(
            groupValue: current == null ? 'system' : _tagOf(current),
            onChanged: (value) {
              if (value != null) Navigator.of(dialogContext).pop(value);
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'system',
                    title: Text(l10n.languageSystem),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  for (final option in _languageOptions)
                    RadioListTile<String>(
                      value: option.tag,
                      title: Text(option.label),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    if (selected == 'system') {
      await settings.setLocale(null);
      return;
    }
    for (final option in _languageOptions) {
      if (option.tag == selected) {
        await settings.setLocale(option.locale);
        return;
      }
    }
  }

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: SelectableText(text)));
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
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
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.external = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Whether the row leaves the app. The update check and the language picker
  /// do not, so they get a chevron instead of the "opens a browser" arrow.
  final bool external;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              external
                  ? Icons.open_in_new_rounded
                  : Icons.chevron_right_rounded,
              size: 16,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
