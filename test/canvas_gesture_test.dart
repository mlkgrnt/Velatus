import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velatus/core/settings_controller.dart';
import 'package:velatus/domain/mask_region.dart';
import 'package:velatus/features/editor/editor_controller.dart';
import 'package:velatus/features/editor/editor_page.dart';
import 'package:velatus/features/editor/widgets/editor_canvas.dart';
import 'package:velatus/l10n/app_localizations.dart';
import 'package:velatus/services/image_loader.dart';

/// 200 × 300 is portrait, so the picture is height-limited inside the canvas —
/// the same situation as a phone screenshot in the editor.
const _imageSize = Size(200, 300);

Future<LoadedImage> _image(WidgetTester tester) async {
  late LoadedImage image;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _imageSize.width, _imageSize.height),
      Paint()..color = const Color(0xFF3355AA),
    );
    final preview = await recorder.endRecording().toImage(
      _imageSize.width.toInt(),
      _imageSize.height.toInt(),
    );
    image = LoadedImage(
      preview: preview,
      width: _imageSize.width.toInt(),
      height: _imageSize.height.toInt(),
      name: 'shot.png',
    );
  });
  return image;
}

void main() {
  /// The canvas fits the picture with a 20 px pad and starts at scale 1, so the
  /// same maths gives the screen rectangle the gestures use.
  Rect displayRect(WidgetTester tester) {
    final size = tester.getSize(find.byType(EditorCanvas));
    final available = Size(size.width - 40, size.height - 40);
    final scale = math.min(
      available.width / _imageSize.width,
      available.height / _imageSize.height,
    );
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: _imageSize.width * scale,
      height: _imageSize.height * scale,
    );
  }

  Offset globalOf(WidgetTester tester, Offset norm) {
    final origin = tester.getTopLeft(find.byType(EditorCanvas));
    final rect = displayRect(tester);
    return origin +
        Offset(
          rect.left + norm.dx * rect.width,
          rect.top + norm.dy * rect.height,
        );
  }

  Future<EditorController> pump(
    WidgetTester tester,
    void Function(EditorController) prepare,
  ) async {
    tester.view.physicalSize = const Size(400, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    final image = await _image(tester);
    final controller = EditorController(image: image);
    prepare(controller);
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

  MaskRegion box(String id, Rect bounds) {
    return MaskRegion(
      id: id,
      style: MaskStyle.mosaic,
      shape: MaskShape.box,
      points: [bounds.topLeft, bounds.bottomRight],
    );
  }

  testWidgets('a corner dragged past the opposite corner flips the box', (
    tester,
  ) async {
    final controller = await pump(tester, (controller) {
      controller.addRegions([box('a', const Rect.fromLTRB(0.1, 0.1, 0.4, 0.4))]);
      controller.selectAt(const Offset(0.2, 0.2));
    });
    expect(controller.selectionCount, 1);

    // Grab the top-left handle and pull it past the bottom-right corner.
    final start = globalOf(tester, const Offset(0.1, 0.1));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveTo(globalOf(tester, const Offset(0.55, 0.55)));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    // The anchor stayed at the old bottom-right corner and the box now lives in
    // the quadrant the finger reached, instead of collapsing into a line.
    final bounds = controller.regions.single.normalizedBounds;
    expect(bounds.left, closeTo(0.4, 2e-3));
    expect(bounds.top, closeTo(0.4, 2e-3));
    expect(bounds.right, closeTo(0.55, 2e-3));
    expect(bounds.bottom, closeTo(0.55, 2e-3));
  });

  testWidgets('dragging one box of a multi-selection moves only that box', (
    tester,
  ) async {
    final controller = await pump(tester, (controller) {
      controller.addRegions([
        box('a', const Rect.fromLTRB(0.1, 0.1, 0.3, 0.25)),
        box('b', const Rect.fromLTRB(0.5, 0.5, 0.9, 0.7)),
      ]);
      controller.selectAt(const Offset(0.2, 0.2));
      controller.selectAt(const Offset(0.7, 0.6));
    });
    expect(controller.selectionCount, 2);
    expect(controller.primaryId, 'b');

    final rect = displayRect(tester);
    final start = globalOf(tester, const Offset(0.2, 0.18));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 16));
    // Past the touch slop, otherwise the scale recogniser never takes over.
    await gesture.moveTo(start + Offset(rect.width * 0.15, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();

    final a = controller.regions.firstWhere((region) => region.id == 'a');
    final b = controller.regions.firstWhere((region) => region.id == 'b');
    expect(a.normalizedBounds.left, closeTo(0.25, 5e-3));
    expect(a.normalizedBounds.top, closeTo(0.1, 5e-3));
    expect(b.normalizedBounds, const Rect.fromLTRB(0.5, 0.5, 0.9, 0.7));
    // Both are still selected, so the sliders keep applying to the pair.
    expect(controller.selectionCount, 2);
  });
}
