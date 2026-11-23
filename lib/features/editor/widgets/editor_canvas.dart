import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme.dart';
import '../../../services/mask_renderer.dart';
import '../editor_controller.dart';

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
  Size _canvasSize = Size.zero;

  bool _drawing = false;
  bool _selecting = false;
  bool _transforming = false;

  double _startScale = 1;
  double _gestureBaseScale = 1;
  Offset _startNorm = const Offset(0.5, 0.5);

  Offset? _panStart;
  Offset _panOrigin = Offset.zero;

  EditorController get c => widget.controller;

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

  Offset _normalize(Offset local, Rect rect) {
    return Offset(
      ((local.dx - rect.left) / rect.width).clamp(0.0, 1.0),
      ((local.dy - rect.top) / rect.height).clamp(0.0, 1.0),
    );
  }

  void _startTransform(Offset focal, double gestureScale, Rect rect) {
    _transforming = true;
    _drawing = false;
    _startScale = _scale;
    _gestureBaseScale = gestureScale;
    _startNorm = _normalize(focal, rect);
  }

  void _updateTransform(ScaleUpdateDetails details, Size canvas) {
    if (!_transforming) return;
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
    final norm = _normalize(focal, rect);
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

  void _handleScaleStart(ScaleStartDetails details, Size canvas) {
    final rect = _displayRect(canvas);
    if (details.pointerCount >= 2) {
      _startTransform(details.localFocalPoint, 1.0, rect);
      return;
    }
    if (c.busy) return;
    if (c.tool == EditorTool.select) {
      _selecting = true;
      c.selectAt(_normalize(details.localFocalPoint, rect));
      return;
    }
    if (!rect.inflate(24).contains(details.localFocalPoint)) {
      c.clearSelection();
      return;
    }
    _drawing = true;
    c.beginAt(_normalize(details.localFocalPoint, rect));
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size canvas) {
    final rect = _displayRect(canvas);
    if (_drawing) {
      if (details.pointerCount >= 2) {
        c.cancelDraft();
        _drawing = false;
        _startTransform(details.localFocalPoint, details.scale, rect);
        return;
      }
      c.updateAt(_normalize(details.localFocalPoint, rect));
      return;
    }
    if (_transforming) {
      _updateTransform(details, canvas);
      return;
    }
    if (_selecting && details.pointerCount == 1) {
      // Dragging with the select tool simply updates the hit target; masks are
      // not movable yet, so this stays a tap-like interaction.
      return;
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_drawing) {
      _drawing = false;
      c.endAt();
    }
    _transforming = false;
    _selecting = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _canvasSize) {
          _canvasSize = size;
          _scale = 1;
          _offset = Offset.zero;
        }
        final rect = _displayRect(size);

        return MouseRegion(
          cursor: c.busy
              ? SystemMouseCursors.wait
              : (c.tool == EditorTool.select
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.precise),
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
              onScaleEnd: _handleScaleEnd,
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

    final regions = controller.regions;
    MaskRenderer.paintRegions(
      canvas,
      imageRect,
      controller.image.preview,
      regions,
      texture: controller.textureFor,
    );

    final draft = controller.draft;
    if (draft != null) {
      MaskRenderer.paintRegion(
        canvas,
        imageRect,
        controller.image.preview,
        draft,
        texture: controller.textureFor,
      );
      MaskRenderer.paintSelection(
        canvas,
        imageRect,
        draft,
        accent: accent,
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
  bool shouldRepaint(covariant _EditorPainter oldDelegate) {
    return true;
  }
}
