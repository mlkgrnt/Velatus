import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/domain/mask_region.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 1000, 500);

  MaskRegion region({
    required MaskShape shape,
    required List<Offset> points,
    double size = 0.05,
    double radius = 0.0,
    String id = 'test',
  }) {
    return MaskRegion(
      id: id,
      style: MaskStyle.mosaic,
      shape: shape,
      points: points,
      size: size,
      radius: radius,
    );
  }

  group('MaskRegion geometry', () {
    test('a box maps normalized points into the image rect', () {
      final mask = region(
        shape: MaskShape.box,
        points: const [Offset(0.25, 0.2), Offset(0.75, 0.8)],
      );
      final path = mask.toPath(rect);
      expect(path.getBounds(), const Rect.fromLTWH(250, 100, 500, 300));
    });

    test('stroke path follows every sample', () {
      final mask = region(
        shape: MaskShape.stroke,
        points: const [Offset(0.1, 0.1), Offset(0.5, 0.5), Offset(0.9, 0.1)],
      );
      final bounds = mask.toPath(rect).getBounds();
      expect(bounds.left, closeTo(100, 0.001));
      expect(bounds.right, closeTo(900, 0.001));
      expect(bounds.top, closeTo(50, 0.001));
    });

    test('a radius rounds the corners of the same box', () {
      final mask = region(
        shape: MaskShape.box,
        points: const [Offset(0.2, 0.2), Offset(0.8, 0.8)],
        radius: 0.5,
      );
      final path = mask.toPath(rect);
      // 600 x 300 in the image rect, so the corner radius is 150.
      expect(path.contains(const Offset(500, 200)), isTrue);
      expect(path.contains(const Offset(215, 115)), isFalse);
      // The bounding box is unchanged: turning up the radius must never move
      // the mask, only soften it.
      expect(path.getBounds(), const Rect.fromLTWH(200, 100, 600, 300));
    });

    test('radius 0 is a plain rectangle', () {
      final mask = region(
        shape: MaskShape.box,
        points: const [Offset(0.2, 0.2), Offset(0.8, 0.8)],
      );
      expect(mask.radius, 0);
      expect(mask.toPath(rect).contains(const Offset(205, 105)), isTrue);
    });

    test('radius is capped so it cannot invert the box', () {
      final mask = region(
        shape: MaskShape.box,
        points: const [Offset(0.2, 0.2), Offset(0.8, 0.8)],
        radius: 4.0,
      );
      expect(mask.toPath(rect).getBounds(), const Rect.fromLTWH(200, 100, 600, 300));
    });
  });

  group('hit testing', () {
    test('stroke hit test respects brush width', () {
      final mask = region(
        shape: MaskShape.stroke,
        points: const [Offset(0.0, 0.5), Offset(1.0, 0.5)],
        size: 0.1,
      );
      expect(mask.hitTest(const Offset(0.5, 0.52), 0), isTrue);
      expect(mask.hitTest(const Offset(0.5, 0.8), 0), isFalse);
    });

    test('box hit test includes the interior', () {
      final mask = region(
        shape: MaskShape.box,
        points: const [Offset(0.2, 0.2), Offset(0.6, 0.6)],
      );
      expect(mask.hitTest(const Offset(0.4, 0.4), 0), isTrue);
      expect(mask.hitTest(const Offset(0.9, 0.9), 0), isFalse);
    });

    test('a rounded box is still hit by its bounding box', () {
      final mask = region(
        shape: MaskShape.box,
        points: const [Offset(0.2, 0.2), Offset(0.8, 0.8)],
        radius: 0.5,
      );
      expect(mask.hitTest(const Offset(0.5, 0.5), 0), isTrue);
      expect(mask.hitTest(const Offset(0.95, 0.95), 0), isFalse);
    });
  });

  test('normalizedBounds covers all points', () {
    final mask = region(
      shape: MaskShape.stroke,
      points: const [
        Offset(0.3, 0.1),
        Offset(0.7, 0.2),
        Offset(0.4, 0.9),
      ],
    );
    expect(
      mask.normalizedBounds,
      rectMoreOrLessEquals(const Rect.fromLTRB(0.3, 0.1, 0.7, 0.9)),
    );
  });

  group('editing an existing mask', () {
    test('translated keeps the shape and moves every point', () {
      final mask = region(
        shape: MaskShape.box,
        points: const [Offset(0.1, 0.1), Offset(0.3, 0.3)],
      );
      final moved = mask.translated(const Offset(0.2, -0.05));
      expect(
        moved.normalizedBounds,
        rectMoreOrLessEquals(const Rect.fromLTRB(0.3, 0.05, 0.5, 0.25)),
      );
      expect(moved.id, mask.id);
      expect(moved.shape, mask.shape);
      expect(moved.radius, mask.radius);
    });

    test('scaledTo stretches the box and everything inside it', () {
      final mask = region(
        shape: MaskShape.box,
        points: const [Offset(0.2, 0.2), Offset(0.6, 0.4)],
      );
      final resized = mask.scaledTo(const Rect.fromLTRB(0, 0, 1, 1));
      expect(
        resized.normalizedBounds,
        rectMoreOrLessEquals(const Rect.fromLTRB(0, 0, 1, 1)),
      );
      // The two stored corners were the corners of the old box.
      expect(resized.points.first.dx, closeTo(0, 1e-9));
      expect(resized.points.last.dy, closeTo(1, 1e-9));
    });

    test('scaledTo on a stroke keeps the silhouette, not a rectangle', () {
      final mask = region(
        shape: MaskShape.stroke,
        points: const [
          Offset(0.0, 0.5),
          Offset(0.5, 0.0),
          Offset(1.0, 0.5),
        ],
        size: 0.1,
      );
      final resized = mask.scaledTo(const Rect.fromLTRB(0.4, 0.4, 0.6, 0.5));
      expect(resized.points.length, 3);
      expect(resized.points[1].dy, closeTo(0.4, 1e-9));
      expect(resized.size, lessThan(0.1));
    });
  });

  test('copyWith keeps identity and updates requested fields', () {
    final mask = region(
      shape: MaskShape.box,
      points: const [Offset(0.1, 0.1), Offset(0.2, 0.2)],
    );
    final updated = mask.copyWith(strength: 0.9, visible: false);
    expect(updated.id, mask.id);
    expect(updated.strength, 0.9);
    expect(updated.visible, isFalse);
    expect(updated.style, mask.style);
  });

  group('detected regions', () {
    test('every detector prefix is recognised as replaceable', () {
      for (final kind in ['text', 'avatar', 'qr']) {
        final detected = region(
          id: '${MaskRegion.detectedIdPrefix}${kind}_1_0',
          shape: MaskShape.box,
          points: const [Offset(0.1, 0.1), Offset(0.2, 0.2)],
        );
        expect(detected.isDetected, isTrue, reason: kind);
        expect(detected.isFill, isTrue);
      }
    });

    test('hand-drawn masks are not replaced by a later scan', () {
      final drawn = region(
        shape: MaskShape.stroke,
        points: const [Offset(0.1, 0.1)],
      );
      expect(drawn.isDetected, isFalse);
    });
  });
}
