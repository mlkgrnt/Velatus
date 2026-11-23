import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How a region is masked.
enum MaskStyle { mosaic, blur, solid }

/// The geometry used to describe a region.
enum MaskShape { stroke, rect, ellipse, lasso }

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
    this.strength = 0.55,
    this.color = const Color(0xFF12141A),
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

  /// Used by [MaskStyle.solid].
  final Color color;

  final bool visible;

  bool get isStroke => shape == MaskShape.stroke;

  MaskRegion copyWith({
    MaskStyle? style,
    MaskShape? shape,
    List<Offset>? points,
    double? size,
    double? strength,
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
      case MaskShape.ellipse:
        if (points.length < 2) {
          return path;
        }
        path.addOval(Rect.fromPoints(p(points.first), p(points.last)));
      case MaskShape.lasso:
        if (points.length < 3) {
          return path;
        }
        path.addPolygon(points.map(p).toList(growable: false), true);
    }
    return path;
  }

  /// Axis-aligned bounds in normalized space, used for hit testing and for
  /// framing layer thumbnails.
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
        if (points.length < 2) {
          return false;
        }
        return Rect.fromPoints(points.first, points.last)
            .inflate(tolerance)
            .contains(point);
      case MaskShape.ellipse:
        if (points.length < 2) {
          return false;
        }
        final r = Rect.fromPoints(points.first, points.last).inflate(tolerance);
        if (r.width <= 0 || r.height <= 0) {
          return false;
        }
        final nx = (point.dx - r.center.dx) / (r.width / 2);
        final ny = (point.dy - r.center.dy) / (r.height / 2);
        return nx * nx + ny * ny <= 1;
      case MaskShape.lasso:
        if (points.length < 3) {
          return false;
        }
        return toPath(const Rect.fromLTWH(0, 0, 1, 1)).contains(point);
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
