import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:velatus/domain/export_prefs.dart';
import 'package:velatus/features/editor/widgets/export_sheet.dart';
import 'package:velatus/l10n/app_localizations.dart';
import 'package:velatus/services/image_loader.dart';

void main() {
  testWidgets('the sheet opens on the remembered answer, not on defaults', (
    tester,
  ) async {
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

    ExportSelection? picked;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showExportSheet(
                  context,
                  image: image,
                  canGallery: true,
                  prefs: const ExportPrefs(quality: 88, toGallery: false),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Quality 88 is last time's value; the default would be 100.
    expect(find.text('88'), findsOneWidget);
    expect(find.text('100'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '保存到本机'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.quality, 88);
    expect(picked!.toGallery, isFalse);
  });
}
