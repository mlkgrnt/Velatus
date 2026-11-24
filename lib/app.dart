import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'core/settings_controller.dart';
import 'core/theme.dart';
import 'features/home/home_page.dart';
import 'l10n/app_localizations.dart';

class VelatusApp extends StatelessWidget {
  const VelatusApp({super.key, required this.settings});

  final SettingsController settings;

  static const _delegates = <LocalizationsDelegate<dynamic>>[
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: settings.themeMode,
          locale: settings.locale,
          localizationsDelegates: _delegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomePage(settings: settings),
        );
      },
    );
  }
}

class VelatusBrand extends StatelessWidget {
  const VelatusBrand({super.key, this.size = 72, this.radius = 22});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/branding/velatus_icon_1024.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.grid_view_rounded,
            size: size * 0.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = BorderRadius.all(Radius.circular(24));
    // The card is a `Material`, not a painted box: `ListTile` and `InkWell`
    // paint their ripples on the nearest Material ancestor, and a plain
    // coloured `Container` hides them (which also trips an assertion in debug
    // builds, turning the whole settings page red).
    return Material(
      color: isDark ? const Color(0xFF171B23) : Colors.white,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: isDark ? const Color(0xFF232833) : const Color(0xFFE9ECF2),
          ),
        ),
        child: child,
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const VelatusBrand(size: 34, radius: 10),
        const SizedBox(width: 12),
        Text(
          'Velatus',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
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
          '隐格',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

const double kContentMaxWidth = 1080;
