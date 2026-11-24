import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/domain/mask_region.dart';
import 'package:velatus/features/editor/editor_controller.dart';
import 'package:velatus/services/image_loader.dart';

/// Multi-selection is the interesting half of the editor: everything the
/// parameter row does depends on getting the set right.
void main() {
  late LoadedImage image;

  Future<LoadedImage> makeImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 200, 300),
      ui.Paint()..color = const ui.Color(0xFF3355AA),
    );
    final preview = await recorder.endRecording().toImage(200, 300);
    return LoadedImage(
      preview: preview,
      width: 200,
      height: 300,
      name: 'shot.png',
    );
  }

  MaskRegion box(String id, ui.Rect rect, {MaskStyle style = MaskStyle.mosaic}) {
    return MaskRegion(
      id: id,
      style: style,
      shape: MaskShape.box,
      points: [rect.topLeft, rect.bottomRight],
      strength: 0.5,
    );
  }

  testWidgets('a tap selects, a second tap deselects', (tester) async {
    await tester.runAsync(() async {
      image = await makeImage();
      final controller = EditorController(image: image);
      addTearDown(controller.dispose);
      controller.addRegions([
        box('a', const ui.Rect.fromLTRB(0.1, 0.1, 0.4, 0.3)),
      ]);

      expect(controller.selectAt(const ui.Offset(0.2, 0.2)), isTrue);
      expect(controller.selectionCount, 1);
      expect(controller.primaryId, 'a');

      expect(controller.selectAt(const ui.Offset(0.2, 0.2)), isTrue);
      expect(controller.selectionCount, 0);
      expect(controller.primaryId, isNull);
    });
  });

  testWidgets('tapping two boxes keeps both selected', (tester) async {
    await tester.runAsync(() async {
      image = await makeImage();
      final controller = EditorController(image: image);
      addTearDown(controller.dispose);
      controller.addRegions([
        box('a', const ui.Rect.fromLTRB(0.1, 0.1, 0.3, 0.25)),
        box('b', const ui.Rect.fromLTRB(0.5, 0.5, 0.9, 0.7)),
      ]);

      controller.selectAt(const ui.Offset(0.2, 0.2));
      controller.selectAt(const ui.Offset(0.7, 0.6));

      expect(controller.selectionCount, 2);
      expect(controller.primaryId, 'b');
      expect(
        controller.selectedRegions.map((region) => region.id),
        containsAll(['a', 'b']),
      );
    });
  });

  testWidgets('a selection never mixes strokes and boxes', (tester) async {
    await tester.runAsync(() async {
      image = await makeImage();
      final controller = EditorController(image: image);
      addTearDown(controller.dispose);
      controller.addRegions([
        box('a', const ui.Rect.fromLTRB(0.1, 0.1, 0.3, 0.25)),
        const MaskRegion(
          id: 's',
          style: MaskStyle.mosaic,
          shape: MaskShape.stroke,
          points: [ui.Offset(0.5, 0.6), ui.Offset(0.9, 0.7)],
          size: 0.05,
        ),
      ]);

      controller.selectAt(const ui.Offset(0.2, 0.2));
      controller.selectAt(const ui.Offset(0.7, 0.65));

      expect(controller.selectionCount, 1);
      expect(controller.primaryId, 's');
      expect(controller.primaryRegion!.isStroke, isTrue);
    });
  });

  testWidgets('a parameter change reaches every selected mask', (tester) async {
    await tester.runAsync(() async {
      image = await makeImage();
      final controller = EditorController(image: image);
      addTearDown(controller.dispose);
      controller.addRegions([
        box('a', const ui.Rect.fromLTRB(0.1, 0.1, 0.3, 0.25)),
        box('b', const ui.Rect.fromLTRB(0.5, 0.5, 0.9, 0.7)),
        box('c', const ui.Rect.fromLTRB(0.1, 0.8, 0.3, 0.95)),
      ]);

      controller.selectAt(const ui.Offset(0.2, 0.2));
      controller.selectAt(const ui.Offset(0.7, 0.6));
      controller.setStrength(0.9);
      controller.setRadius(0.5);
      controller.setStyle(MaskStyle.blur);

      final touched = controller.regions.where((r) => r.id != 'c');
      for (final region in touched) {
        expect(region.strength, 0.9);
        expect(region.radius, 0.5);
        expect(region.style, MaskStyle.blur);
      }
      final untouched = controller.regions.firstWhere((r) => r.id == 'c');
      expect(untouched.strength, 0.5, reason: 'the new value wins only for the selected set');
      expect(untouched.style, MaskStyle.mosaic);
    });
  });

  testWidgets('a corner drag resizes only the mask it grabbed', (tester) async {
    await tester.runAsync(() async {
      image = await makeImage();
      final controller = EditorController(image: image);
      addTearDown(controller.dispose);
      controller.addRegions([
        box('a', const ui.Rect.fromLTRB(0.1, 0.1, 0.3, 0.25)),
        box('b', const ui.Rect.fromLTRB(0.5, 0.5, 0.9, 0.7)),
      ]);
      controller.selectAt(const ui.Offset(0.2, 0.2));
      controller.selectAt(const ui.Offset(0.7, 0.6));

      // The gesture layer focuses the grabbed mask before resizing it.
      controller.focusSelection('a');
      controller.resizeSelected(const ui.Rect.fromLTRB(0.05, 0.05, 0.4, 0.4));

      final a = controller.regions.firstWhere((r) => r.id == 'a');
      final b = controller.regions.firstWhere((r) => r.id == 'b');
      expect(a.normalizedBounds, const ui.Rect.fromLTRB(0.05, 0.05, 0.4, 0.4));
      expect(b.normalizedBounds, const ui.Rect.fromLTRB(0.5, 0.5, 0.9, 0.7));
      // Resizing must not quietly drop the rest of the selection.
      expect(controller.selectionCount, 2);
    });
  });

  testWidgets('moving one member of a multi-selection leaves the others alone', (
    tester,
  ) async {
    await tester.runAsync(() async {
      image = await makeImage();
      final controller = EditorController(image: image);
      addTearDown(controller.dispose);
      controller.addRegions([
        box('a', const ui.Rect.fromLTRB(0.1, 0.1, 0.3, 0.25)),
        box('b', const ui.Rect.fromLTRB(0.5, 0.5, 0.9, 0.7)),
      ]);
      controller.selectAt(const ui.Offset(0.2, 0.2));
      controller.selectAt(const ui.Offset(0.7, 0.6));

      // The finger landed on "b", which became primary; "a" is still selected
      // but must not move with it.
      controller.translatePrimary(const ui.Offset(0.5, 0.5));

      // "b" already touches x = 0.9, so it can only slide 0.1 sideways.
      expect(
        controller.regions[1].normalizedBounds,
        const ui.Rect.fromLTRB(0.6, 0.8, 1.0, 1.0),
      );
      expect(
        controller.regions[0].normalizedBounds,
        const ui.Rect.fromLTRB(0.1, 0.1, 0.3, 0.25),
      );
      expect(controller.selectionCount, 2);
    });
  });

  testWidgets('the content signature follows edits but not selection', (
    tester,
  ) async {
    await tester.runAsync(() async {
      image = await makeImage();
      final controller = EditorController(image: image);
      addTearDown(controller.dispose);
      controller.addRegions([
        box('a', const ui.Rect.fromLTRB(0.1, 0.1, 0.4, 0.3)),
      ]);
      final saved = controller.contentSignature;

      // Selecting, deselecting and hovering around must not look like an edit,
      // otherwise leaving right after an export would still nag.
      controller.selectAt(const ui.Offset(0.2, 0.2));
      expect(controller.contentSignature, saved);
      controller.clearSelection();
      expect(controller.contentSignature, saved);

      // Moving or restyling must.
      controller.selectOnly('a');
      controller.translatePrimary(const ui.Offset(0.05, 0));
      expect(controller.contentSignature, isNot(saved));

      final moved = controller.contentSignature;
      controller.setStyle(MaskStyle.blur);
      expect(controller.contentSignature, isNot(moved));
    });
  });

  group('detection candidates', () {
    testWidgets('applying replaces the previous detection but keeps hand work', (
      tester,
    ) async {
      await tester.runAsync(() async {
        image = await makeImage();
        final controller = EditorController(image: image);
        addTearDown(controller.dispose);
        controller.addRegions([
          box('hand', const ui.Rect.fromLTRB(0.1, 0.1, 0.3, 0.2)),
          box('${MaskRegion.detectedIdPrefix}text_1_0',
              const ui.Rect.fromLTRB(0.1, 0.3, 0.8, 0.4)),
        ]);

        controller.setPending([
          box('${MaskRegion.detectedIdPrefix}text_2_0',
              const ui.Rect.fromLTRB(0.1, 0.5, 0.8, 0.6)),
          box('${MaskRegion.detectedIdPrefix}avatar_2_1',
              const ui.Rect.fromLTRB(0.1, 0.7, 0.25, 0.8)),
        ]);
        expect(controller.hasPending, isTrue);
        expect(controller.selectionCount, 0, reason: 'handles would fight');

        controller.togglePending('${MaskRegion.detectedIdPrefix}avatar_2_1');
        final applied = controller.commitPending();

        expect(applied, 1);
        expect(controller.hasPending, isFalse);
        final ids = controller.regions.map((r) => r.id);
        expect(ids, contains('hand'));
        expect(ids, contains('${MaskRegion.detectedIdPrefix}text_2_0'));
        expect(
          ids,
          isNot(contains('${MaskRegion.detectedIdPrefix}text_1_0')),
          reason: 'a second scan is a replacement, not another layer',
        );
        expect(
          ids,
          isNot(contains('${MaskRegion.detectedIdPrefix}avatar_2_1')),
        );
      });
    });

    testWidgets('candidates follow the style controls until applied', (
      tester,
    ) async {
      await tester.runAsync(() async {
        image = await makeImage();
        final controller = EditorController(image: image);
        addTearDown(controller.dispose);
        controller.setPending([
          box('${MaskRegion.detectedIdPrefix}text_3_0',
              const ui.Rect.fromLTRB(0.1, 0.1, 0.8, 0.2)),
        ]);

        controller.setRadius(0.5);
        controller.setStyle(MaskStyle.solid);

        expect(controller.pending.single.radius, 0.5);
        expect(controller.pending.single.style, MaskStyle.solid);
      });
    });
  });
}
