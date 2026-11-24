import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velatus/core/settings_controller.dart';
import 'package:velatus/features/editor/editor_controller.dart';
import 'package:velatus/features/editor/editor_page.dart';
import 'package:velatus/features/editor/widgets/editor_canvas.dart';
import 'package:velatus/l10n/app_localizations.dart';
import 'package:velatus/services/image_loader.dart';

/// The eye used to be press-and-hold only: a normal tap did nothing, and with
/// no masks drawn even holding it changed no pixels. These tests pin down the
/// two modes it has now — tap to pin, hold to peek at the other side.
Future<EditorController> pumpEditor(WidgetTester tester) async {
  late LoadedImage image;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
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
  final controller = EditorController(image: image);
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
  return controller;
}

Finder get eye => find.byIcon(Icons.visibility_outlined);
Finder get pinnedEye => find.byIcon(Icons.visibility_rounded);

void main() {
  testWidgets('a tap pins the original until the next tap', (tester) async {
    final c = await pumpEditor(tester);
    expect(c.showOriginal, isFalse);
    expect(c.compareMode, isFalse);
    expect(find.textContaining('原图'), findsNothing);

    await tester.tap(eye);
    await tester.pumpAndSettle();
    expect(c.compareMode, isTrue);
    expect(c.showOriginal, isTrue);
    expect(find.textContaining('原图'), findsOneWidget);
    expect(find.textContaining('再点一次返回'), findsOneWidget);

    await tester.tap(pinnedEye);
    await tester.pumpAndSettle();
    expect(c.compareMode, isFalse);
    expect(c.showOriginal, isFalse);
    expect(find.textContaining('原图'), findsNothing);
  });

  testWidgets('a long press peeks at the masks without moving the pin', (
    tester,
  ) async {
    final c = await pumpEditor(tester);

    final gesture = await tester.startGesture(tester.getCenter(eye));
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.showOriginal, isTrue, reason: 'holding shows the original');
    expect(c.compareMode, isFalse, reason: 'holding does not pin it');
    expect(find.text('原图'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.showOriginal, isFalse);
    expect(find.text('原图'), findsNothing);

    // Once pinned, a long press shows the *other* side: the masks.
    await tester.tap(eye);
    await tester.pumpAndSettle();
    expect(c.showOriginal, isTrue);

    final second = await tester.startGesture(tester.getCenter(pinnedEye));
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.showOriginal, isFalse);
    expect(c.compareMode, isTrue, reason: 'the pin survives the peek');

    await second.up();
    await tester.pumpAndSettle();
    expect(c.showOriginal, isTrue);
  });

  testWidgets('touching the canvas drops out of the original view', (
    tester,
  ) async {
    final c = await pumpEditor(tester);
    await tester.tap(eye);
    await tester.pumpAndSettle();
    expect(c.compareMode, isTrue);

    // Editing while every handle and outline is hidden would be blind.
    await tester.tapAt(tester.getCenter(find.byType(EditorCanvas)));
    await tester.pumpAndSettle();
    expect(c.compareMode, isFalse);
    expect(c.showOriginal, isFalse);
  });
}
