// Generates the screenshots used in docs/. Not part of the normal test suite;
// run it explicitly:
//
//   flutter test --update-goldens tool/screenshots_test.dart
//
// The Chinese UI font is loaded from the host so the rendered text matches a
// real device instead of the test-only Ahem placeholder.
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velatus/core/settings_controller.dart';
import 'package:velatus/core/theme.dart';
import 'package:velatus/domain/mask_region.dart';
import 'package:velatus/features/editor/editor_controller.dart';
import 'package:velatus/features/editor/editor_page.dart';
import 'package:velatus/features/home/home_page.dart';
import 'package:velatus/l10n/app_localizations.dart';
import 'package:velatus/services/image_loader.dart';

const _fontFamily = 'VelatusScreenshotFont';

Future<void> _loadFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _loadFonts() async {
  const cjk = r'C:\Windows\Fonts\Deng.ttf';
  await _loadFont(_fontFamily, cjk);
  // Filled buttons and other components fall back to the default family.
  await _loadFont('Roboto', cjk);
  await _loadFont(
    'MaterialIcons',
    r'E:\_tooling\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
  );
}

ThemeData _theme(Brightness brightness) {
  final base = buildTheme(brightness);
  final themed = base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: _fontFamily),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _fontFamily),
  );
  const buttonText = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );
  return themed.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: (themed.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: const WidgetStatePropertyAll(buttonText),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: (themed.textButtonTheme.style ?? const ButtonStyle()).copyWith(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: _fontFamily, fontSize: 14),
        ),
      ),
    ),
  );
}

Widget _app({required Widget home, required Brightness brightness}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme(brightness),
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('home desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    await tester.pumpWidget(
      _app(home: HomePage(settings: settings), brightness: Brightness.light),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/home_light.png'),
    );
  });

  testWidgets('home mobile dark', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    await tester.pumpWidget(
      _app(home: HomePage(settings: settings), brightness: Brightness.dark),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/home_dark.png'),
    );
  });

  testWidgets('editor mobile', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    late LoadedImage image;
    late EditorController controller;
    await tester.runAsync(() async {
      final bytes = await File('docs/sample_chat.png').readAsBytes();
      image = await ImageLoader.fromBytes(bytes, name: 'chat_with_zhang.png');
      controller = EditorController(image: image)
        ..addRegions([
          const MaskRegion(
            id: 'm1',
            style: MaskStyle.blur,
            shape: MaskShape.rect,
            points: [Offset(0.21, 0.264), Offset(0.78, 0.316)],
            strength: 0.75,
          ),
          const MaskRegion(
            id: 'm2',
            style: MaskStyle.mosaic,
            shape: MaskShape.rect,
            points: [Offset(0.04, 0.362), Offset(0.86, 0.448)],
            strength: 0.6,
          ),
        ]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        home: EditorPage(image: image, settings: settings, controller: controller),
        brightness: Brightness.light,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/editor_mobile.png'),
    );
  });

  testWidgets('editor desktop dark', (tester) async {
    tester.view.physicalSize = const Size(1280, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    late LoadedImage image;
    late EditorController controller;
    await tester.runAsync(() async {
      final bytes = await File('docs/sample_chat.png').readAsBytes();
      image = await ImageLoader.fromBytes(bytes, name: 'chat_with_zhang.png');
      controller = EditorController(image: image)
        ..addRegions([
          const MaskRegion(
            id: 'm1',
            style: MaskStyle.blur,
            shape: MaskShape.rect,
            points: [Offset(0.21, 0.264), Offset(0.78, 0.316)],
            strength: 0.75,
          ),
          const MaskRegion(
            id: 'm2',
            style: MaskStyle.mosaic,
            shape: MaskShape.rect,
            points: [Offset(0.04, 0.362), Offset(0.86, 0.448)],
            strength: 0.6,
          ),
          const MaskRegion(
            id: 'm3',
            style: MaskStyle.solid,
            shape: MaskShape.rect,
            points: [Offset(0.04, 0.548), Offset(0.82, 0.616)],
            strength: 0.5,
          ),
        ])
        ..selectRegion('m2');
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        home: EditorPage(image: image, settings: settings, controller: controller),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/editor_desktop.png'),
    );
  });
}
