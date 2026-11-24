import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velatus/core/settings_controller.dart';
import 'package:velatus/domain/mask_region.dart';
import 'package:velatus/features/editor/editor_controller.dart';
import 'package:velatus/features/editor/editor_page.dart';
import 'package:velatus/l10n/app_localizations.dart';
import 'package:velatus/services/image_loader.dart';

/// 360 × 640 is a small Android phone. The tool bar is the tightest spot in the
/// app, so every parameter state gets rendered at that width and any overflow
/// shows up as a thrown exception.
const _small = Size(360, 640);

Future<LoadedImage> _image(WidgetTester tester) async {
  late LoadedImage image;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 300),
      Paint()..color = const Color(0xFF3355AA),
    );
    final preview = await recorder.endRecording().toImage(200, 300);
    image = LoadedImage(
      preview: preview,
      width: 200,
      height: 300,
      name: 'shot.png',
    );
  });
  return image;
}

void main() {
  Future<EditorController> pumpEditor(
    WidgetTester tester, {
    void Function(EditorController)? prepare,
  }) async {
    tester.view.physicalSize = _small;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    final image = await _image(tester);
    final controller = EditorController(image: image);
    prepare?.call(controller);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditorPage(
          image: image,
          settings: settings,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('brush state fits a small phone', (tester) async {
    await pumpEditor(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('涂抹'), findsOneWidget);
    expect(find.text('圆角框'), findsOneWidget);
  });

  testWidgets('solid colour row fits a small phone', (tester) async {
    await pumpEditor(
      tester,
      prepare: (controller) => controller.setStyle(MaskStyle.solid),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a selected mask offers delete and keeps the tool bar intact', (
    tester,
  ) async {
    final controller = await pumpEditor(
      tester,
      prepare: (controller) {
        controller.addRegions([
          const MaskRegion(
            id: 'm1',
            style: MaskStyle.mosaic,
            shape: MaskShape.rect,
            points: [Offset(0.2, 0.2), Offset(0.8, 0.4)],
          ),
        ]);
        controller.selectAt(const Offset(0.5, 0.3));
      },
    );
    expect(tester.takeException(), isNull);
    expect(controller.hasSelection, isTrue);
    expect(find.text('拖动移动 · 四角缩放'), findsOneWidget);
  });

  testWidgets('the rounded rect tool exposes a corner radius slider', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      prepare: (controller) => controller.setTool(EditorTool.roundedRect),
    );
    expect(tester.takeException(), isNull);
  });
}
