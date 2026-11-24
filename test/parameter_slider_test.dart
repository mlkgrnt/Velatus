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

/// Regression tests for the parameter row.
///
/// The bug: before the first mask existed, the setters changed the controller
/// but never called `notifyListeners()`, so the dock kept rendering the old
/// values and the thumb looked frozen. On top of that the two sliders had no
/// keys, so switching tools/styles reused one `Slider` State for a different
/// parameter — dragging one bar appeared to move both.
Future<({EditorController controller, SettingsController settings})>
pumpEditor(WidgetTester tester, {EditorTool tool = EditorTool.box}) async {
  late LoadedImage image;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 200, 300),
      ui.Paint()..color = const ui.Color(0xFF3355AA),
    );
    final preview = await recorder.endRecording().toImage(200, 300);
    image = LoadedImage(
      preview: preview,
      width: 200,
      height: 300,
      name: 'shot.png',
    );
  });

  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsController();
  await settings.load();
  final controller = EditorController(
    image: image,
    preset: settings.preset.copyWith(tool: tool),
    onPresetChanged: settings.savePreset,
  );
  addTearDown(controller.dispose);
  addTearDown(settings.dispose);

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
  return (controller: controller, settings: settings);
}

double sliderValue(WidgetTester tester, int index) =>
    tester.widget<Slider>(find.byType(Slider).at(index)).value;

Future<void> dragSlider(WidgetTester tester, int index, double fraction) async {
  final finder = find.byType(Slider).at(index);
  final width = tester.getSize(finder).width;
  await tester.drag(finder, Offset(width * fraction, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sliders respond before any mask has been drawn', (tester) async {
    final editor = await pumpEditor(tester);

    // Box tool, empty document: strength + corner radius, both live.
    expect(find.byType(Slider), findsNWidgets(2));
    expect(editor.controller.hasMasks, isFalse);
    expect(editor.controller.hasSelection, isFalse);
    expect(editor.controller.hasPending, isFalse);

    final before = sliderValue(tester, 1);
    expect(before, editor.controller.radius);

    await dragSlider(tester, 1, 0.35);

    expect(editor.controller.radius, greaterThan(before));
    // The dock rebuilt with the new value — this is the part that used to fail.
    expect(sliderValue(tester, 1), closeTo(editor.controller.radius, 1e-6));
    expect(editor.settings.preset.radius, editor.controller.radius);
  });

  testWidgets('dragging one slider never moves the other parameter', (
    tester,
  ) async {
    final editor = await pumpEditor(tester);
    final c = editor.controller;

    final strengthBefore = c.strength;
    final radiusBefore = c.radius;

    await dragSlider(tester, 0, 0.2);
    expect(c.strength, isNot(strengthBefore));
    expect(c.radius, radiusBefore, reason: 'strength must not touch radius');
    expect(sliderValue(tester, 1), closeTo(radiusBefore, 1e-6));

    final strengthNow = c.strength;
    await dragSlider(tester, 1, 0.3);
    expect(c.radius, isNot(radiusBefore));
    expect(c.strength, strengthNow, reason: 'radius must not touch strength');
    expect(sliderValue(tester, 0), closeTo(strengthNow, 1e-6));
  });

  testWidgets('switching tools and styles keeps each slider on its own value', (
    tester,
  ) async {
    final editor = await pumpEditor(tester);
    final c = editor.controller;

    c.setStrength(0.8);
    c.setRadius(0.3);
    await tester.pumpAndSettle();

    // box -> brush: the second slider becomes brush width instead of radius.
    c.setTool(EditorTool.brush);
    await tester.pumpAndSettle();
    expect(sliderValue(tester, 0), closeTo(0.8, 1e-6));
    expect(sliderValue(tester, 1), closeTo(c.brushSize, 1e-6));
    expect(c.radius, 0.3);

    // solid -> mosaic changes the *number* of sliders, which is where the
    // unkeyed `Slider` States used to be recycled into each other.
    c.setStyle(MaskStyle.solid);
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    c.setStyle(MaskStyle.mosaic);
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(2));
    expect(sliderValue(tester, 0), closeTo(c.strength, 1e-6));
    expect(sliderValue(tester, 1), closeTo(c.brushSize, 1e-6));

    await dragSlider(tester, 0, -0.15);
    expect(c.strength, isNot(0.8));
    expect(c.brushSize, closeTo(0.055, 1e-6));
    expect(sliderValue(tester, 1), closeTo(c.brushSize, 1e-6));
  });

  testWidgets('a remembered preset does not overwrite live edits', (
    tester,
  ) async {
    final editor = await pumpEditor(tester);
    final c = editor.controller;

    c.setRadius(0.42);
    await tester.pumpAndSettle();
    expect(editor.settings.preset.radius, 0.42);
    expect(c.radius, 0.42);
    expect(sliderValue(tester, 1), closeTo(0.42, 1e-6));

    c.setStrength(0.27);
    await tester.pumpAndSettle();
    expect(editor.settings.preset.strength, 0.27);
    expect(c.radius, 0.42, reason: 'writing one field must not reset another');
  });
}
