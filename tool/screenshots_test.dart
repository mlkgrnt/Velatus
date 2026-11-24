// Generates the screenshots used in docs/. Not part of the normal test suite;
// run it explicitly:
//
//   flutter test --update-goldens tool/screenshots_test.dart
//
// The Chinese UI font is loaded from the host so the rendered text matches a
// real device instead of the test-only Ahem placeholder.
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
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
import 'package:velatus/features/settings/settings_page.dart';
import 'package:velatus/l10n/app_localizations.dart';
import 'package:velatus/services/detector_service.dart';
import 'package:velatus/services/image_loader.dart';
import 'package:zxing2/qrcode.dart';

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
            shape: MaskShape.box,
            points: [Offset(0.21, 0.264), Offset(0.78, 0.316)],
            strength: 0.75,
          ),
          const MaskRegion(
            id: 'm2',
            style: MaskStyle.mosaic,
            shape: MaskShape.box,
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
            shape: MaskShape.box,
            points: [Offset(0.21, 0.264), Offset(0.78, 0.316)],
            strength: 0.75,
          ),
          const MaskRegion(
            id: 'm2',
            style: MaskStyle.mosaic,
            shape: MaskShape.box,
            points: [Offset(0.04, 0.362), Offset(0.86, 0.448)],
            strength: 0.6,
          ),
          const MaskRegion(
            id: 'm3',
            style: MaskStyle.solid,
            shape: MaskShape.box,
            points: [Offset(0.04, 0.548), Offset(0.82, 0.616)],
            strength: 0.5,
          ),
        ])
        ..selectAt(const Offset(0.45, 0.405));
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

  testWidgets('settings mobile', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    await tester.pumpWidget(
      _app(home: SettingsPage(settings: settings), brightness: Brightness.light),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../docs/screenshots/settings_light.png'),
    );
  });

  testWidgets('editor solid colour row', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
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
        ..setStyle(MaskStyle.solid)
        ..addRegions([
          const MaskRegion(
            id: 'm1',
            style: MaskStyle.solid,
            shape: MaskShape.box,
            points: [Offset(0.06, 0.36), Offset(0.9, 0.45)],
            radius: 0.3,
          ),
        ])
        ..selectAt(const Offset(0.5, 0.4));
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
      matchesGoldenFile('../docs/screenshots/editor_solid.png'),
    );
  });

  testWidgets('editor scan candidates', (tester) async {
    // Renders a synthetic chat, then runs the *real* avatar and QR detectors on
    // it and shows the result. If the heuristics regress, this screenshot does
    // too — which is the point.
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    late LoadedImage image;
    late EditorController controller;
    late List<MaskRegion> candidates;
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        home: RepaintBoundary(key: boundaryKey, child: const _FakeChat()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final captured = await boundary.toImage(pixelRatio: 2);
      image = LoadedImage(
        preview: captured,
        width: captured.width,
        height: captured.height,
        name: 'group_chat.png',
      );

      // ignore: invalid_use_of_visible_for_testing_member
      final avatarPixels = await DetectorService.analysisPixels(
        image,
        maxSide: 720,
      );
      // ignore: invalid_use_of_visible_for_testing_member
      final qrPixels = await DetectorService.analysisPixels(image, maxSide: 900);
      final avatars = avatarPixels == null
          ? <Rect>[]
          : DetectorService.findAvatars(
              avatarPixels.$1,
              avatarPixels.$2,
              avatarPixels.$3,
            );
      final codes = qrPixels == null
          ? <Rect>[]
          : DetectorService.findQrCodes(qrPixels.$1, qrPixels.$2, qrPixels.$3);
      // ignore: avoid_print
      print('scan demo: ${avatars.length} avatars, ${codes.length} QR code(s)');

      candidates = [
        for (var i = 0; i < avatars.length; i++)
          MaskRegion(
            id: '${MaskRegion.detectedIdPrefix}avatar_0_$i',
            style: MaskStyle.mosaic,
            shape: MaskShape.box,
            points: [avatars[i].topLeft, avatars[i].bottomRight],
            radius: 0.5,
          ),
        for (var i = 0; i < codes.length; i++)
          MaskRegion(
            id: '${MaskRegion.detectedIdPrefix}qr_0_$i',
            style: MaskStyle.mosaic,
            shape: MaskShape.box,
            points: [codes[i].topLeft, codes[i].bottomRight],
          ),
      ];
      controller = EditorController(image: image)..setPending(candidates);
      await Future<void>.delayed(const Duration(milliseconds: 300));
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
      matchesGoldenFile('../docs/screenshots/editor_scan.png'),
    );
  });
}

/// A chat screenshot with the two things the pixel detectors look for: avatars
/// repeated down a column, and a QR code.
class _FakeChat extends StatelessWidget {
  const _FakeChat();

  @override
  Widget build(BuildContext context) {
    Widget avatar(int seed) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, (seed * 37.0) % 360, 0.55, 0.55).toColor(),
            HSLColor.fromAHSL(1, (seed * 71.0) % 360, 0.6, 0.38).toColor(),
          ],
        ),
      ),
      child: Center(
        child: Text(
          String.fromCharCode(0x4E00 + seed * 97 % 400),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    Widget bubble(String text, {required bool incoming}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: incoming ? Colors.white : const Color(0xFF95EC69),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4)),
    );

    Widget message(String text, {required bool incoming, required int seed}) {
      final row = <Widget>[
        avatar(seed),
        const SizedBox(width: 8),
        Expanded(child: Align(
          alignment: incoming ? Alignment.centerLeft : Alignment.centerRight,
          child: bubble(text, incoming: incoming),
        )),
        const SizedBox(width: 8),
      ];
      if (incoming) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: row);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: row.reversed.toList(),
      );
    }

    return Material(
      color: const Color(0xFFEDEDF0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 56, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 44,
              color: const Color(0xFFF6F6F8),
              alignment: Alignment.center,
              child: const Text(
                '产品讨论组',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  message('明天的评审几点开始？', incoming: true, seed: 3),
                  const SizedBox(height: 12),
                  message('十点，会议室在三楼。', incoming: false, seed: 5),
                  const SizedBox(height: 12),
                  message('好的，我提前把材料打印出来。', incoming: true, seed: 7),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar(11),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '会议纪要在这里：',
                              style: TextStyle(fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            _QrBlock(size: 132),
                            const SizedBox(height: 4),
                            const Text(
                              '长按识别',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8A8F99),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  message('收到，谢谢。', incoming: false, seed: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A real, well-formed QR symbol so the detector has something to find.
class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _QrPainter('https://github.com/mlkgrnt/Velatus')),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.data);

  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    final code = Encoder.encode(data, ErrorCorrectionLevel.m);
    final matrix = code.matrix;
    if (matrix == null) return;
    final modules = matrix.width;
    final module = size.width / modules;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white,
    );
    final paint = Paint()..color = Colors.black;
    for (var y = 0; y < modules; y++) {
      for (var x = 0; x < modules; x++) {
        if (matrix.get(x, y) != 1) continue;
        canvas.drawRect(
          Rect.fromLTWH(x * module, y * module, module + 0.5, module + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => oldDelegate.data != data;
}
