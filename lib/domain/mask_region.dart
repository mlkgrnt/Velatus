import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How a region is masked.
enum MaskStyle { mosaic, blur, solid }

/// The geometry used to describe a region.
///
/// Ellipse and lasso used to live here as well. In practice both were rarely
/// the right shape for a redaction and they made "select a block and adjust it"
/// much harder to reason about, so the set is now deliberately small: a free
/// hand stroke plus two rectangles that differ only in their corners.
enum MaskShape { stroke, rect, roundedRect }

/// A single, non-destructive redaction object.
///
/// Points are stored in normalized image space (0..1 on both axes), so the
/// exact same description renders identically at preview and export
/// resolution.
@immutable
class MaskRegion {
  const MaskRegion({
    required this.id,
    required this.style,
    required this.shape,
    required this.points,
    this.size = 0.05,
    this.strength = 0.65,
    this.radius = 0.24,
    this.color = const Color(0xFF14161C),
    this.visible = true,
  });

  final String id;
  final MaskStyle style;
  final MaskShape shape;
  final List<Offset> points;

  /// Brush width / stroke width as a fraction of the image's shorter side.
  final double size;

  /// 0..1. Mapped to pixel block size or blur sigma by the renderer.
  final double strength;

  /// Corner radius of a [MaskShape.roundedRect], as a fraction of the shorter
  /// side of its own bounding box. 0 is a square corner, 0.5 is a stadium.
  final double radius;

  /// Used by [MaskStyle.solid].
  final Color color;

  final bool visible;

  bool get isStroke => shape == MaskShape.stroke;

  /// True for shapes that enclose an area, i.e. everything that is not a
  /// brush stroke. Only these expose corner handles for resizing.
  bool get isFill => shape != MaskShape.stroke;

  MaskRegion copyWith({
    MaskStyle? style,
    MaskShape? shape,
    List<Offset>? points,
    double? size,
    double? strength,
    double? radius,
    Color? color,
    bool? visible,
  }) {
    return MaskRegion(
      id: id,
      style: style ?? this.style,
      shape: shape ?? this.shape,
      points: points ?? this.points,
      size: size ?? this.size,
      strength: strength ?? this.strength,
      radius: radius ?? this.radius,
      color: color ?? this.color,
      visible: visible ?? this.visible,
    );
  }

  /// Builds the path for this region inside [imageRect].
  Path toPath(Rect imageRect) {
    Offset p(Offset n) => Offset(
      imageRect.left + n.dx * imageRect.width,
      imageRect.top + n.dy * imageRect.height,
    );

    final path = Path();
    switch (shape) {
      case MaskShape.stroke:
        if (points.isEmpty) {
          return path;
        }
        if (points.length == 1) {
          final c = p(points.first);
          path.addOval(Rect.fromCircle(center: c, radius: 0.5));
          return path;
        }
        path.moveTo(p(points.first).dx, p(points.first).dy);
        for (var i = 1; i < points.length; i++) {
          final pt = p(points[i]);
          path.lineTo(pt.dx, pt.dy);
        }
      case MaskShape.rect:
        if (points.length < 2) {
          return path;
        }
        path.addRect(Rect.fromPoints(p(points.first), p(points.last)));
      case MaskShape.roundedRect:
        if (points.length < 2) {
          return path;
        }
        final rect = Rect.fromPoints(p(points.first), p(points.last));
        if (rect.isEmpty) {
          return path;
        }
        final corner =
            radius.clamp(0.0, 0.5) * math.min(rect.width, rect.height);
        path.addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(corner)),
        );
    }
    return path;
  }

  /// Axis-aligned bounds in normalized space, used for hit testing, for the
  /// resize frame and for export-time bookkeeping.
  Rect get normalizedBounds {
    if (points.isEmpty) {
      return Rect.zero;
    }
    var minX = points.first.dx, maxX = points.first.dx;
    var minY = points.first.dy, maxY = points.first.dy;
    for (final pt in points) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Moves the whole region by [delta], in normalized space.
  MaskRegion translated(Offset delta) {
    return copyWith(
      points: [for (final point in points) point + delta],
    );
  }

  /// Stretches the region so that its bounding box becomes [target].
  ///
  /// This is what the corner handles call. It is uniform across shapes: a brush
  /// stroke is remapped point by point, which keeps its silhouette instead of
  /// degrading into a rectangle.
  MaskRegion scaledTo(Rect target) {
    final from = normalizedBounds;
    if (from.width <= 0 || from.height <= 0) {
      // A single dot or a perfectly straight line: there is no box to map, so
      // keep the points together and let the caller's bounds guard handle it.
      final center = target.center;
      return copyWith(
        points: List<Offset>.filled(points.length, center),
      );
    }
    final scaleX = target.width / from.width;
    final scaleY = target.height / from.height;
    return copyWith(
      points: [
        for (final point in points)
          Offset(
            target.left + (point.dx - from.left) * scaleX,
            target.top + (point.dy - from.top) * scaleY,
          ),
      ],
      // A stretched stroke should stay visually proportional to its box.
      size: isStroke
          ? (size * math.sqrt(scaleX * scaleY)).clamp(0.004, 0.4)
          : size,
    );
  }

  /// Hit test in normalized space. [tolerance] is normalized too.
  bool hitTest(Offset point, double tolerance) {
    if (points.isEmpty) {
      return false;
    }
    switch (shape) {
      case MaskShape.stroke:
        final threshold = size / 2 + tolerance;
        if (points.length == 1) {
          return (points.first - point).distance <= threshold;
        }
        for (var i = 0; i < points.length - 1; i++) {
          if (_distanceToSegment(point, points[i], points[i + 1]) <= threshold) {
            return true;
          }
        }
        return false;
      case MaskShape.rect:
      case MaskShape.roundedRect:
        if (points.length < 2) {
          return false;
        }
        // The rounded corners are close enough to square at the tolerance scale
        // that testing the box keeps taps predictable.
        return Rect.fromPoints(
          points.first,
          points.last,
        ).inflate(tolerance).contains(point);
    }
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx == 0 && dy == 0) {
      return (p - a).distance;
    }
    final t = (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / (dx * dx + dy * dy))
        .clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }
}
