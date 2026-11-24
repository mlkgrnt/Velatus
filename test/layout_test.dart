import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velatus/core/settings_controller.dart';
import 'package:velatus/domain/mask_region.dart';
import 'package:velatus/features/editor/editor_controller.dart';
import 'package:velatus/features/editor/editor_page.dart';
import 'package:velatus/features/editor/widgets/tool_dock.dart';
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
    expect(find.text('框'), findsOneWidget);
    expect(find.text('选择'), findsOneWidget);
  });

  testWidgets('the dock is the same height in every tool state', (
    tester,
  ) async {
    // The complaint this guards: the bar used to stack a variable number of
    // sliders, so switching tools resized the canvas underneath the photo.
    final heights = <String, double>{};
    Future<void> measure(String name) async {
      heights[name] = tester.getSize(find.byType(ToolDock)).height;
    }

    await pumpEditor(tester);
    await measure('brush');

    await tester.tap(find.text('框'));
    await tester.pumpAndSettle();
    await measure('box');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    await measure('select');

    await tester.tap(find.byTooltip('色块'));
    await tester.pumpAndSettle();
    await measure('solid');
    expect(tester.takeException(), isNull);

    expect(heights.values.toSet(), hasLength(1), reason: '$heights');
  });

  testWidgets('a selected mask offers the delete action and a hint', (
    tester,
  ) async {
    final controller = await pumpEditor(
      tester,
      prepare: (controller) {
        controller.addRegions([
          const MaskRegion(
            id: 'm1',
            style: MaskStyle.mosaic,
            shape: MaskShape.box,
            points: [Offset(0.2, 0.2), Offset(0.8, 0.4)],
          ),
        ]);
        controller.selectAt(const Offset(0.5, 0.3));
      },
    );
    expect(tester.takeException(), isNull);
    expect(controller.hasSelection, isTrue);
    expect(find.text('拖动移动 · 四角缩放'), findsOneWidget);
    // Always present, enabled only with a selection: a button that appears and
    // disappears would move the others around.
    expect(find.byTooltip('删除这处打码'), findsOneWidget);
  });

  testWidgets('a multi-selection reports its size and keeps the dock height', (
    tester,
  ) async {
    final controller = await pumpEditor(
      tester,
      prepare: (controller) {
        controller.addRegions([
          const MaskRegion(
            id: 'm1',
            style: MaskStyle.mosaic,
            shape: MaskShape.box,
            points: [Offset(0.1, 0.1), Offset(0.4, 0.3)],
          ),
          const MaskRegion(
            id: 'm2',
            style: MaskStyle.mosaic,
            shape: MaskShape.box,
            points: [Offset(0.5, 0.5), Offset(0.9, 0.7)],
          ),
        ]);
        controller.selectAt(const Offset(0.2, 0.2));
        controller.selectAt(const Offset(0.7, 0.6));
      },
    );
    expect(tester.takeException(), isNull);
    expect(controller.selectionCount, 2);
    expect(find.text('已选 2 处 · 拖动和缩放都只作用在你碰到的那个'), findsOneWidget);
  });

  testWidgets('the scan confirmation bar fits a small phone', (tester) async {
    final controller = await pumpEditor(tester);
    controller.setPending([
      const MaskRegion(
        id: 'det_text_1_0',
        style: MaskStyle.mosaic,
        shape: MaskShape.box,
        points: [Offset(0.1, 0.1), Offset(0.5, 0.2)],
      ),
      const MaskRegion(
        id: 'det_avatar_1_1',
        style: MaskStyle.mosaic,
        shape: MaskShape.box,
        points: [Offset(0.06, 0.4), Offset(0.2, 0.55)],
      ),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('点选要盖住的框'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.text('全不选'));
    await tester.pumpAndSettle();
    expect(controller.pendingSelectedCount, 0);
    expect(find.text('0/2'), findsOneWidget);

    await tester.tap(find.text('全选'));
    await tester.pumpAndSettle();
    expect(controller.pendingSelectedCount, 2);
  });
}
