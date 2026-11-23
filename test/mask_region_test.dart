import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/domain/mask_region.dart';

void main() {
  const rect = Rect.fromLTWH(0, 0, 1000, 500);

  MaskRegion region({
    required MaskShape shape,
    required List<Offset> points,
    double size = 0.05,
  }) {
    return MaskRegion(
      id: 'test',
      style: MaskStyle.mosaic,
      shape: shape,
      points: points,
      size: size,
    );
  }

  group('MaskRegion geometry', () {
    test('rectangle maps normalized points into the image rect', () {
      final mask = region(
        shape: MaskShape.rect,
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

    test('lasso closes the polygon', () {
      final mask = region(
        shape: MaskShape.lasso,
        points: const [
          Offset(0.2, 0.2),
          Offset(0.8, 0.2),
          Offset(0.5, 0.8),
        ],
      );
      final path = mask.toPath(rect);
      expect(path.contains(const Offset(500, 250)), isTrue);
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

    test('rect hit test includes the interior', () {
      final mask = region(
        shape: MaskShape.rect,
        points: const [Offset(0.2, 0.2), Offset(0.6, 0.6)],
      );
      expect(mask.hitTest(const Offset(0.4, 0.4), 0), isTrue);
      expect(mask.hitTest(const Offset(0.9, 0.9), 0), isFalse);
    });

    test('ellipse hit test excludes the bounding box corners', () {
      final mask = region(
        shape: MaskShape.ellipse,
        points: const [Offset(0.2, 0.2), Offset(0.8, 0.8)],
      );
      expect(mask.hitTest(const Offset(0.5, 0.5), 0), isTrue);
      expect(mask.hitTest(const Offset(0.21, 0.21), 0), isFalse);
    });

    test('lasso hit test uses the closed polygon', () {
      final mask = region(
        shape: MaskShape.lasso,
        points: const [
          Offset(0.1, 0.1),
          Offset(0.9, 0.1),
          Offset(0.9, 0.9),
          Offset(0.1, 0.9),
        ],
      );
      expect(mask.hitTest(const Offset(0.5, 0.5), 0), isTrue);
      expect(mask.hitTest(const Offset(0.95, 0.95), 0), isFalse);
    });
  });

  test('normalizedBounds covers all points', () {
    final mask = region(
      shape: MaskShape.lasso,
      points: const [
        Offset(0.3, 0.1),
        Offset(0.7, 0.2),
        Offset(0.4, 0.9),
      ],
    );
    expect(mask.normalizedBounds, const Rect.fromLTRB(0.3, 0.1, 0.7, 0.9));
  });

  test('copyWith keeps identity and updates requested fields', () {
    final mask = region(
      shape: MaskShape.rect,
      points: const [Offset(0.1, 0.1), Offset(0.2, 0.2)],
    );
    final updated = mask.copyWith(strength: 0.9, visible: false);
    expect(updated.id, mask.id);
    expect(updated.strength, 0.9);
    expect(updated.visible, isFalse);
    expect(updated.style, mask.style);
  });
}
