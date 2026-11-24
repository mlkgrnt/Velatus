import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';
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
  Offset _lastNorm = Offset.zero;
  bool _moved = false;
  int _corner = -1;

  double _startScale = 1;
  double _gestureBaseScale = 1;
  Offset _startNorm = const Offset(0.5, 0.5);

  Offset? _panStart;
  Offset _panOrigin = Offset.zero;

  EditorController get c => widget.controller;

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

  /// Screen-space frame around the selected region, or null.
  Rect? _selectionFrame(Rect imageRect) {
    final region = c.selectedRegion;
    if (region == null || region.points.isEmpty) return null;
    final bounds = region.toPath(imageRect).getBounds();
    if (bounds.isEmpty && !region.isStroke) return null;
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

  Offset _cornerPoint(Rect rect, int index) {
    return switch (index) {
      0 => rect.topLeft,
      1 => rect.topRight,
      2 => rect.bottomLeft,
      _ => rect.bottomRight,
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
    final newScale = (_startScale * relative).clamp(1.0, 12.0);
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
    final newScale = (_scale * factor).clamp(1.0, 12.0);
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

  void _resetView() {
    setState(() {
      _scale = 1;
      _offset = Offset.zero;
    });
  }

  // ------------------------------------------------------------------ gestures

  void _handleScaleStart(ScaleStartDetails details, Size canvas) {
    final rect = _displayRect(canvas);
    final local = details.localFocalPoint;

    if (details.pointerCount >= 2) {
      if (_gesture == _Gesture.draw) c.cancelDraft();
      _startZoom(local, 1.0, rect);
      return;
    }
    if (c.busy) return;

    _downPoint = local;
    _lastNorm = _rawNormalize(local, rect);
    _moved = false;

    if (c.tool == EditorTool.select) {
      // Only the select tool moves things, so a brush stroke can still be
      // painted straight across an existing mask.
      final frame = _selectionFrame(rect);
      if (frame != null) {
        final corner = _cornerAt(frame, local);
        if (corner >= 0) {
          _gesture = _Gesture.resize;
          _corner = corner;
          c.beginScrub();
          return;
        }
        if (c.selectedRegion!.hitTest(_lastNorm, 0.012)) {
          _gesture = _Gesture.move;
          c.beginScrub();
          return;
        }
      }
      c.selectAt(_lastNorm);
      return;
    }

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
        c.translateSelected(norm - _lastNorm);
        _lastNorm = norm;
      case _Gesture.resize:
        final region = c.selectedRegion;
        final frame = _selectionFrame(rect);
        if (region == null || frame == null) return;
        final pad = region.isStroke
            ? region.size * rect.shortestSide / 2
            : 0.0;
        final anchorNorm = _rawNormalize(_cornerPoint(frame, switch (_corner) {
          0 => 3,
          1 => 2,
          2 => 1,
          _ => 0,
        }), rect);
        final box = Rect.fromPoints(
          anchorNorm,
          _rawNormalize(local, rect),
        );
        final padX = rect.width == 0 ? 0.0 : pad / rect.width;
        final padY = rect.height == 0 ? 0.0 : pad / rect.height;
        // `resizeSelected` works on the centre-line box, so the visual padding
        // of a brush stroke is removed again before handing it over.
        c.resizeSelected(
          Rect.fromLTRB(
            box.left + padX,
            box.top + padY,
            math.max(box.left + padX + 0.004, box.right - padX),
            math.max(box.top + padY + 0.004, box.bottom - padY),
          ),
        );
      case _Gesture.zoom:
        _updateZoom(details, canvas);
      case _Gesture.none:
        break;
    }
  }

  void _handleScaleEnd() {
    if (_gesture == _Gesture.draw) {
      if (!_moved) {
        // A tap with a drawing tool means "pick this block", not "draw a dot".
        c.cancelDraft();
        c.selectAt(_lastNorm);
      } else {
        c.endAt();
      }
    }
    if (_gesture == _Gesture.move || _gesture == _Gesture.resize) {
      c.endScrub();
    }
    _gesture = _Gesture.none;
    _corner = -1;
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
              }
            },
            onPointerMove: (event) {
              if (_panStart != null) {
                setState(() {
                  _offset = _panOrigin + (event.localPosition - _panStart!);
                });
              }
            },
            onPointerUp: (_) => _panStart = null,
            onPointerCancel: (_) => _panStart = null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) => _handleScaleStart(details, size),
              onScaleUpdate: (details) => _handleScaleUpdate(details, size),
              onScaleEnd: (_) => _handleScaleEnd(),
              onDoubleTap: () {
                if (_scale > 1.01) {
                  _resetView();
                } else {
                  _zoomAt(2.0, size.center(Offset.zero), size);
                }
              },
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

    final selected = controller.selectedRegion;
    if (selected != null && selected.visible) {
      MaskRenderer.paintSelection(
        canvas,
        imageRect,
        selected,
        accent: accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter oldDelegate) => true;
}
