import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';
import '../../../domain/mask_region.dart';
import '../../../services/mask_renderer.dart';
import '../editor_controller.dart';

/// What the current pointer gesture is doing.
enum _Gesture { none, draw, move, resize, zoom }

class EditorCanvas extends StatefulWidget {
  const EditorCanvas({
    super.key,
    required this.controller,
    this.padding = const EdgeInsets.all(20),
  });

  final EditorController controller;
  final EdgeInsets padding;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  double _scale = 1;
  Offset _offset = Offset.zero;
  Size? _canvasSize;

  _Gesture _gesture = _Gesture.none;
  Offset _downPoint = Offset.zero;

  /// Where the finger actually landed.
  ///
  /// `onScaleStart` reports the focal point *after* the gesture has travelled
  /// past the touch slop, which on a phone is already 30-odd pixels away. Hit
  /// testing a 22 px corner handle against that point misses almost every time,
  /// so grabbing a corner degraded into dragging the whole box.
  Offset? _pressPoint;
  Offset _lastNorm = Offset.zero;
  bool _moved = false;

  /// The corner opposite to the dragged handle, captured once when the gesture
  /// starts. Deriving it from the live frame every update was what made a box
  /// collapse into a line and then get shoved around: as the box shrank, its
  /// "opposite" corner moved with it, so the anchor chased the finger.
  Offset _resizeAnchor = Offset.zero;

  double _startScale = 1;
  double _gestureBaseScale = 1;
  Offset _startNorm = const Offset(0.5, 0.5);

  Offset? _panStart;
  Offset _panOrigin = Offset.zero;

  EditorController get c => widget.controller;

  static const double _minScale = 0.3;
  static const double _maxScale = 12;

  // ------------------------------------------------------------------ mapping

  Rect _fitRect(Size canvas) {
    final image = c.image;
    final available = Size(
      math.max(32, canvas.width - widget.padding.horizontal),
      math.max(32, canvas.height - widget.padding.vertical),
    );
    final scale = math.min(
      available.width / image.width,
      available.height / image.height,
    );
    final width = image.width * scale;
    final height = image.height * scale;
    return Rect.fromCenter(
      center: Offset(canvas.width / 2, canvas.height / 2),
      width: width,
      height: height,
    );
  }

  Rect _displayRect(Size canvas) {
    final base = _fitRect(canvas);
    final center = Offset(canvas.width / 2, canvas.height / 2) + _offset;
    return Rect.fromCenter(
      center: center,
      width: base.width * _scale,
      height: base.height * _scale,
    );
  }

  /// Clamped normalization, used for painting coordinates.
  Offset _normalize(Offset local, Rect rect) {
    final raw = _rawNormalize(local, rect);
    return Offset(raw.dx.clamp(0.0, 1.0), raw.dy.clamp(0.0, 1.0));
  }

  /// Unclamped normalization, used for transforms so a handle can be dragged
  /// past the opposite corner without the maths collapsing.
  Offset _rawNormalize(Offset local, Rect rect) {
    return Offset(
      (local.dx - rect.left) / rect.width,
      (local.dy - rect.top) / rect.height,
    );
  }

  /// Screen-space frame around [region].
  Rect _frameFor(MaskRegion region, Rect imageRect) {
    final bounds = region.toPath(imageRect).getBounds();
    final pad = region.isStroke
        ? region.size * imageRect.shortestSide / 2
        : 0.0;
    return bounds.inflate(pad);
  }

  /// Index of the corner handle under [local]: 0 tl, 1 tr, 2 bl, 3 br, or -1.
  int _cornerAt(Rect frame, Offset local) {
    const reach = 22.0;
    final corners = [
      frame.topLeft,
      frame.topRight,
      frame.bottomLeft,
      frame.bottomRight,
    ];
    for (var i = 0; i < corners.length; i++) {
      if ((corners[i] - local).distance <= reach) return i;
    }
    return -1;
  }

  /// The normalized point that stays put while corner [index] is dragged.
  ///
  /// It is read from the region's own bounds — the same space `resizeSelected`
  /// works in — and never recomputed mid-gesture, which is what allows the
  /// dragged corner to pass the anchor and land in any of the four quadrants.
  Offset _anchorFor(MaskRegion region, int index) {
    final b = region.normalizedBounds;
    return switch (index) {
      0 => Offset(b.right, b.bottom),
      1 => Offset(b.left, b.bottom),
      2 => Offset(b.right, b.top),
      _ => Offset(b.left, b.top),
    };
  }

  // ---------------------------------------------------------------- transform

  void _startZoom(Offset focal, double gestureScale, Rect rect) {
    _gesture = _Gesture.zoom;
    _startScale = _scale;
    _gestureBaseScale = gestureScale;
    _startNorm = _rawNormalize(focal, rect);
  }

  void _updateZoom(ScaleUpdateDetails details, Size canvas) {
    if (_gesture != _Gesture.zoom) return;
    final base = _fitRect(canvas);
    final relative = _gestureBaseScale == 0
        ? 1.0
        : details.scale / _gestureBaseScale;
    final newScale = (_startScale * relative).clamp(_minScale, _maxScale);
    final width = base.width * newScale;
    final height = base.height * newScale;
    final center = details.localFocalPoint -
        Offset((_startNorm.dx - 0.5) * width, (_startNorm.dy - 0.5) * height);
    final canvasCenter = Offset(canvas.width / 2, canvas.height / 2);
    setState(() {
      _scale = newScale;
      _offset = center - canvasCenter;
    });
  }

  void _zoomAt(double factor, Offset focal, Size canvas) {
    final rect = _displayRect(canvas);
    final norm = _rawNormalize(focal, rect);
    final newScale = (_scale * factor).clamp(_minScale, _maxScale);
    if (newScale == _scale) return;
    final base = _fitRect(canvas);
    final width = base.width * newScale;
    final height = base.height * newScale;
    final center =
        focal - Offset((norm.dx - 0.5) * width, (norm.dy - 0.5) * height);
    setState(() {
      _scale = newScale;
      _offset = center - Offset(canvas.width / 2, canvas.height / 2);
    });
  }

  // ------------------------------------------------------------------ gestures

  /// A tap is the primary way of selecting a block, so it is handled here and
  /// not in `onScaleStart` — the scale recogniser only wins after the pointer
  /// has moved past the touch slop, which is why tapping used to do nothing.
  void _handleTap(Offset local, Size canvas) {
    if (c.busy) return;
    final rect = _displayRect(canvas);
    final norm = _rawNormalize(local, rect);

    if (c.hasPending) {
      for (var i = c.pending.length - 1; i >= 0; i--) {
        final candidate = c.pending[i];
        if (candidate.hitTest(norm, 0.01)) {
          c.togglePending(candidate.id);
          return;
        }
      }
      return;
    }
    if (c.tool == EditorTool.select) {
      c.selectAt(norm);
      return;
    }
    // With a drawing tool a tap on an existing block means "pick this one".
    if (!rect.inflate(24).contains(local)) return;
    c.selectAt(norm);
  }

  void _handleScaleStart(ScaleStartDetails details, Size canvas) {
    final rect = _displayRect(canvas);
    final local = details.pointerCount >= 2
        ? details.localFocalPoint
        : (_pressPoint ?? details.localFocalPoint);

    if (details.pointerCount >= 2) {
      if (_gesture == _Gesture.draw) c.cancelDraft();
      _startZoom(local, 1.0, rect);
      return;
    }
    if (c.busy || c.hasPending) return;

    _downPoint = local;
    _lastNorm = _rawNormalize(local, rect);
    _moved = false;

    if (c.hasSelection) {
      // Corner handles first: they sit on top of the masks.
      for (final region in c.selectedRegions.reversed) {
        final frame = _frameFor(region, rect);
        final corner = _cornerAt(frame, local);
        if (corner >= 0) {
          c.focusSelection(region.id);
          _gesture = _Gesture.resize;
          _resizeAnchor = _anchorFor(region, corner);
          c.beginScrub();
          return;
        }
      }
      // Dragging a block moves that block only. The rest of the selection stays
      // put but remains selected, so a following slider still hits all of them.
      for (final region in c.selectedRegions.reversed) {
        if (region.hitTest(_lastNorm, 0.012)) {
          c.focusSelection(region.id);
          _gesture = _Gesture.move;
          c.beginScrub();
          return;
        }
      }
    }

    if (c.tool == EditorTool.select) return;
    if (!rect.inflate(24).contains(local)) {
      c.clearSelection();
      return;
    }
    _gesture = _Gesture.draw;
    c.beginAt(_normalize(local, rect));
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size canvas) {
    final rect = _displayRect(canvas);
    final local = details.localFocalPoint;

    if (_gesture == _Gesture.draw && details.pointerCount >= 2) {
      c.cancelDraft();
      _startZoom(local, details.scale, rect);
      return;
    }
    if ((local - _downPoint).distance > 5) _moved = true;

    switch (_gesture) {
      case _Gesture.draw:
        _lastNorm = _normalize(local, rect);
        c.updateAt(_lastNorm);
      case _Gesture.move:
        final norm = _rawNormalize(local, rect);
        c.translatePrimary(norm - _lastNorm);
        _lastNorm = norm;
      case _Gesture.resize:
        final region = c.primaryRegion;
        if (region == null) return;
        final pointer = _rawNormalize(local, rect);
        // A brush stroke is drawn as a wide line, so its handles sit half a
        // stroke outside the centre line. Inset the finger by that much on the
        // side being dragged, towards the anchor.
        final pad = region.isStroke
            ? region.size * rect.shortestSide / 2
            : 0.0;
        final padX = rect.width == 0 ? 0.0 : pad / rect.width;
        final padY = rect.height == 0 ? 0.0 : pad / rect.height;
        final toAnchor = _resizeAnchor - pointer;
        final dragged = Offset(
          pointer.dx + toAnchor.dx.sign * padX,
          pointer.dy + toAnchor.dy.sign * padY,
        );
        // `Rect.fromPoints` normalises, so dragging past the anchor simply puts
        // the box in the opposite quadrant instead of flattening it.
        c.resizeSelected(Rect.fromPoints(_resizeAnchor, dragged));
      case _Gesture.zoom:
        _updateZoom(details, canvas);
      case _Gesture.none:
        break;
    }
  }

  void _handleScaleEnd() {
    if (_gesture == _Gesture.draw) {
      if (_moved) {
        c.endAt();
      } else {
        c.cancelDraft();
      }
    }
    if (_gesture == _Gesture.move || _gesture == _Gesture.resize) {
      c.endScrub();
    }
    _gesture = _Gesture.none;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_canvasSize == null) {
          _canvasSize = size;
        } else if (size != _canvasSize) {
          // The dock grows and shrinks as tools change. Keeping the zoom that
          // the user set is more important than re-fitting the photo, so only
          // the offset is nudged back into range.
          _canvasSize = size;
          final base = _fitRect(size);
          final maxDx = math.max(0.0, base.width * _scale / 2);
          final maxDy = math.max(0.0, base.height * _scale / 2);
          _offset = Offset(
            _offset.dx.clamp(-maxDx, maxDx),
            _offset.dy.clamp(-maxDy, maxDy),
          );
        }
        final rect = _displayRect(size);

        return MouseRegion(
          cursor: c.busy ? SystemMouseCursors.wait : SystemMouseCursors.precise,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                final factor = math.exp(-event.scrollDelta.dy * 0.0018);
                _zoomAt(factor, event.localPosition, size);
              }
            },
            onPointerDown: (event) {
              if (event.buttons == kMiddleMouseButton) {
                _panStart = event.localPosition;
                _panOrigin = _offset;
                return;
              }
              _pressPoint = event.localPosition;
            },
            onPointerMove: (event) {
              if (_panStart != null) {
                setState(() {
                  _offset = _panOrigin + (event.localPosition - _panStart!);
                });
              }
            },
            onPointerUp: (_) {
              _panStart = null;
              _pressPoint = null;
            },
            onPointerCancel: (_) {
              _panStart = null;
              _pressPoint = null;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleTap(details.localPosition, size),
              onScaleStart: (details) => _handleScaleStart(details, size),
              onScaleUpdate: (details) => _handleScaleUpdate(details, size),
              onScaleEnd: (_) => _handleScaleEnd(),
              child: Container(
                color: isDark
                    ? CanvasColors.darkBackdrop
                    : CanvasColors.lightBackdrop,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _EditorPainter(
                      controller: c,
                      imageRect: rect,
                      gridColor: theme.colorScheme.outlineVariant.withValues(
                        alpha: isDark ? 0.10 : 0.35,
                      ),
                      accent: theme.colorScheme.primary,
                      isDark: isDark,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditorPainter extends CustomPainter {
  _EditorPainter({
    required this.controller,
    required this.imageRect,
    required this.gridColor,
    required this.accent,
    required this.isDark,
  });

  final EditorController controller;
  final Rect imageRect;
  final Color gridColor;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // A very light dot grid keeps the empty space from feeling dead without
    // competing with the photo.
    final dotPaint = Paint()..color = gridColor;
    const spacing = 28.0;
    for (var x = spacing / 2; x < size.width; x += spacing) {
      for (var y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }

    if (imageRect.width <= 0 || imageRect.height <= 0) return;

    canvas.drawRect(
      imageRect.shift(const Offset(0, 8)).inflate(2),
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    canvas.drawImageRect(
      controller.image.preview,
      Rect.fromLTWH(
        0,
        0,
        controller.image.preview.width.toDouble(),
        controller.image.preview.height.toDouble(),
      ),
      imageRect,
      Paint()..filterQuality = FilterQuality.medium,
    );

    canvas.drawRect(
      imageRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = Colors.white.withValues(alpha: 0.25),
    );

    if (controller.showOriginal) return;

    MaskRenderer.paintRegions(
      canvas,
      imageRect,
      controller.image.preview,
      controller.regions,
      textures: controller.textures,
    );

    final draft = controller.draft;
    if (draft != null) {
      MaskRenderer.paintRegion(
        canvas,
        imageRect,
        controller.image.preview,
        draft,
        textures: controller.textures,
      );
    }

    for (final candidate in controller.pending) {
      MaskRenderer.paintCandidate(
        canvas,
        imageRect,
        candidate,
        accent: accent,
        selected: controller.isPendingSelected(candidate.id),
        muted: isDark ? const Color(0xFF9AA3B2) : const Color(0xFF6B7280),
      );
    }

    for (final region in controller.selectedRegions) {
      MaskRenderer.paintSelection(
        canvas,
        imageRect,
        region,
        accent: accent,
        handles: controller.pending.isEmpty,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter oldDelegate) => true;
}
