import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../domain/mask_region.dart';
import '../../services/image_exporter.dart';
import '../../services/image_loader.dart';
import '../../services/mask_renderer.dart';
import '../../services/mask_texture_cache.dart';

enum EditorTool { brush, rect, roundedRect, select }

class EditorController extends ChangeNotifier {
  EditorController({required this.image}) {
    _textureCache.attach(image.preview);
    _warmTextures(immediate: true);
  }

  final LoadedImage image;
  final MaskTextureCache _textureCache = MaskTextureCache();

  final List<MaskRegion> _regions = <MaskRegion>[];
  final List<List<MaskRegion>> _undoStack = <List<MaskRegion>>[];
  final List<List<MaskRegion>> _redoStack = <List<MaskRegion>>[];
  MaskRegion? _draft;
  String? _selectedId;
  List<MaskRegion>? _scrubSnapshot;
  Timer? _textureTimer;
  bool _disposed = false;

  EditorTool _tool = EditorTool.brush;
  MaskStyle _style = MaskStyle.mosaic;
  double _brushSize = 0.055;
  double _strength = 0.65;
  double _radius = 0.24;
  Color _solidColor = const Color(0xFF14161C);
  bool _showOriginal = false;
  bool _busy = false;
  double? _exportProgress;

  List<MaskRegion> get regions => List.unmodifiable(_regions);
  MaskRegion? get draft => _draft;
  String? get selectedId => _selectedId;
  EditorTool get tool => _tool;
  MaskStyle get style => _style;
  double get brushSize => _brushSize;
  double get strength => _strength;
  double get radius => _radius;
  Color get solidColor => _solidColor;
  bool get showOriginal => _showOriginal;
  bool get busy => _busy;
  double? get exportProgress => _exportProgress;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get hasMasks => _regions.isNotEmpty;
  bool get hasSelection => _selectedId != null;

  int get maskCount => _regions.length;

  MaskRegion? get selectedRegion {
    final id = _selectedId;
    if (id == null) return null;
    for (final region in _regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  /// Textures resolved against the preview-sized source.
  MaskTextures get textures =>
      MaskTextures(mosaic: _textureCache.mosaic, blur: _textureCache.blur);

  // ---------------------------------------------------------------- parameters

  void setTool(EditorTool value) {
    if (_tool == value) {
      if (value != EditorTool.select) clearSelection();
      return;
    }
    _tool = value;
    _draft = null;
    // Picking a drawing tool means you are done with the current block.
    if (value != EditorTool.select) _selectedId = null;
    notifyListeners();
  }

  void setStyle(MaskStyle value) {
    _style = value;
    final selected = selectedRegion;
    if (selected != null) {
      _replace(
        selected.copyWith(
          style: value,
          strength: value == MaskStyle.solid ? selected.strength : _strength,
          color: value == MaskStyle.solid ? _solidColor : selected.color,
        ),
        recordHistory: true,
      );
      _warmTextures();
    }
    notifyListeners();
  }

  void setBrushSize(double value) {
    _brushSize = value.clamp(0.005, 0.4);
    final selected = selectedRegion;
    if (selected != null && selected.isStroke) {
      _replace(selected.copyWith(size: _brushSize), recordHistory: false);
    }
    notifyListeners();
  }

  void setStrength(double value) {
    _strength = value.clamp(0.02, 1.0);
    final selected = selectedRegion;
    if (selected != null && selected.style != MaskStyle.solid) {
      _replace(selected.copyWith(strength: _strength), recordHistory: false);
      _warmTextures();
    }
    notifyListeners();
  }

  void setRadius(double value) {
    _radius = value.clamp(0.0, 0.5);
    final selected = selectedRegion;
    if (selected != null && selected.shape == MaskShape.roundedRect) {
      _replace(selected.copyWith(radius: _radius), recordHistory: false);
    }
    notifyListeners();
  }

  void setSolidColor(Color value) {
    _solidColor = value;
    final selected = selectedRegion;
    if (selected != null && selected.style == MaskStyle.solid) {
      _replace(selected.copyWith(color: value), recordHistory: true);
    }
    notifyListeners();
  }

  /// Starts a drag that changes a parameter or the geometry of the selected
  /// region continuously. Only one history entry is recorded for the whole
  /// gesture, and tapping without moving records nothing.
  void beginScrub() {
    _scrubSnapshot ??= List<MaskRegion>.of(_regions);
  }

  void endScrub() {
    final snapshot = _scrubSnapshot;
    _scrubSnapshot = null;
    if (snapshot == null) return;
    var changed = snapshot.length != _regions.length;
    if (!changed) {
      for (var i = 0; i < snapshot.length; i++) {
        if (!identical(snapshot[i], _regions[i])) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      _undoStack.add(snapshot);
      _redoStack.clear();
      _trimHistory();
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------- drawing

  void beginAt(Offset point) {
    if (_busy) return;
    if (_tool == EditorTool.select) {
      selectAt(point);
      return;
    }
    // A new stroke means the user is done adjusting the previous block.
    _selectedId = null;
    final shape = switch (_tool) {
      EditorTool.brush => MaskShape.stroke,
      EditorTool.rect => MaskShape.rect,
      EditorTool.roundedRect => MaskShape.roundedRect,
      EditorTool.select => MaskShape.stroke,
    };
    _draft = MaskRegion(
      id: _newId(),
      style: _style,
      shape: shape,
      points: [point, if (shape != MaskShape.stroke) point],
      size: _brushSize,
      strength: _strength,
      radius: _radius,
      color: _solidColor,
    );
    // Build the texture for the very first frame of the stroke instead of
    // waiting for the debounce, otherwise the stroke briefly shows the
    // untouched photo.
    _warmTextures(immediate: true);
    notifyListeners();
  }

  void updateAt(Offset point) {
    var draft = _draft;
    if (draft == null || _busy) return;
    switch (draft.shape) {
      case MaskShape.stroke:
        final last = draft.points.last;
        final minDistance = math.max(0.0015, _brushSize * 0.12);
        if ((point - last).distance < minDistance) return;
        draft = draft.copyWith(points: [...draft.points, point]);
      case MaskShape.rect:
      case MaskShape.roundedRect:
        draft = draft.copyWith(points: [draft.points.first, point]);
    }
    _draft = draft;
    notifyListeners();
  }

  void endAt() {
    final draft = _draft;
    _draft = null;
    if (draft == null) {
      notifyListeners();
      return;
    }
    final preview = _validDraft(draft);
    if (preview == null) {
      notifyListeners();
      return;
    }
    _pushHistory();
    _regions.add(preview);
    notifyListeners();
    _warmTextures();
  }

  /// Discards the in-progress region, e.g. when a second finger lands and the
  /// gesture turns into a pinch.
  void cancelDraft() {
    if (_draft == null) return;
    _draft = null;
    notifyListeners();
  }

  MaskRegion? _validDraft(MaskRegion draft) {
    switch (draft.shape) {
      case MaskShape.stroke:
        if (draft.points.isEmpty) return null;
        return draft;
      case MaskShape.rect:
      case MaskShape.roundedRect:
        if (draft.points.length < 2) return null;
        final bounds = draft.normalizedBounds;
        if (bounds.width < 0.004 || bounds.height < 0.004) return null;
        return draft;
    }
  }

  // ---------------------------------------------------------------- selection

  /// Selects the topmost mask under [point]. Returns true when something was
  /// hit, which lets the canvas start a drag in the same gesture.
  bool selectAt(Offset point) {
    const tolerance = 0.012;
    for (var i = _regions.length - 1; i >= 0; i--) {
      final region = _regions[i];
      if (region.visible && region.hitTest(point, tolerance)) {
        _selectedId = region.id;
        _tool = EditorTool.select;
        _style = region.style;
        _strength = region.strength;
        _radius = region.radius;
        if (region.isStroke) _brushSize = region.size;
        _solidColor = region.color;
        notifyListeners();
        return true;
      }
    }
    if (_selectedId != null) {
      _selectedId = null;
      notifyListeners();
    }
    return false;
  }

  void clearSelection() {
    if (_selectedId == null) return;
    _selectedId = null;
    notifyListeners();
  }

  /// Moves the selected region, keeping it inside the picture.
  void translateSelected(Offset delta) {
    final region = selectedRegion;
    if (region == null) return;
    final bounds = region.normalizedBounds;
    final dx = delta.dx.clamp(-bounds.left, 1 - bounds.right);
    final dy = delta.dy.clamp(-bounds.top, 1 - bounds.bottom);
    if (dx == 0 && dy == 0) return;
    _replace(region.translated(Offset(dx, dy)), recordHistory: false);
    notifyListeners();
  }

  /// Stretches the selected region into [target] (normalized space).
  void resizeSelected(Rect target) {
    final region = selectedRegion;
    if (region == null) return;
    final clamped = Rect.fromLTRB(
      target.left.clamp(0.0, 1.0),
      target.top.clamp(0.0, 1.0),
      target.right.clamp(0.0, 1.0),
      target.bottom.clamp(0.0, 1.0),
    );
    if (clamped.width < 0.004 || clamped.height < 0.004) return;
    _replace(region.scaledTo(clamped), recordHistory: false);
    notifyListeners();
  }

  void deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    _pushHistory();
    _regions.removeWhere((region) => region.id == id);
    _selectedId = null;
    notifyListeners();
  }

  void deleteRegion(String id) {
    _pushHistory();
    _regions.removeWhere((region) => region.id == id);
    if (_selectedId == id) _selectedId = null;
    notifyListeners();
  }

  void clearAll() {
    if (_regions.isEmpty) return;
    _pushHistory();
    _regions.clear();
    _selectedId = null;
    notifyListeners();
  }

  void addRegions(Iterable<MaskRegion> regions) {
    final list = regions.where((region) => region.points.isNotEmpty).toList();
    if (list.isEmpty) return;
    _pushHistory();
    _regions.addAll(list);
    _selectedId = null;
    notifyListeners();
    _warmTextures();
  }

  // ------------------------------------------------------------------- state

  void setShowOriginal(bool value) {
    if (_showOriginal == value) return;
    _showOriginal = value;
    notifyListeners();
  }

  void setBusy(bool value, {double? progress}) {
    _busy = value;
    _exportProgress = progress;
    notifyListeners();
  }

  void setExportProgress(double? value) {
    _exportProgress = value;
    notifyListeners();
  }

  Future<ExportResult> export({
    required ExportFormat format,
    required int quality,
  }) async {
    final result = await ImageExporter.render(
      source: image,
      regions: List<MaskRegion>.of(_regions),
      format: format,
      quality: quality,
    );
    return result;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List<MaskRegion>.of(_regions));
    _regions
      ..clear()
      ..addAll(_undoStack.removeLast());
    _selectedId = null;
    notifyListeners();
    _warmTextures();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List<MaskRegion>.of(_regions));
    _regions
      ..clear()
      ..addAll(_redoStack.removeLast());
    _selectedId = null;
    notifyListeners();
    _warmTextures();
  }

  void _replace(MaskRegion region, {required bool recordHistory}) {
    final index = _regions.indexWhere((item) => item.id == region.id);
    if (index < 0) return;
    if (recordHistory) _pushHistory();
    _regions[index] = region;
  }

  void _pushHistory() {
    _undoStack.add(List<MaskRegion>.of(_regions));
    _redoStack.clear();
    _trimHistory();
  }

  void _trimHistory() {
    while (_undoStack.length > 60) {
      _undoStack.removeAt(0);
    }
  }

  void _warmTextures({bool immediate = false}) {
    _textureTimer?.cancel();
    Future<void> build() async {
      final shortSide = math.min(
        image.preview.width.toDouble(),
        image.preview.height.toDouble(),
      );
      final blocks = <int>{};
      final sigmas = <int>{};
      void collect(MaskStyle style, double strength, bool visible) {
        if (!visible) return;
        switch (style) {
          case MaskStyle.mosaic:
            blocks.add(MaskRenderer.mosaicBlockPx(strength, shortSide));
          case MaskStyle.blur:
            sigmas.add(MaskRenderer.blurSigmaPx(strength, shortSide).round());
          case MaskStyle.solid:
            break;
        }
      }

      for (final region in _regions) {
        collect(region.style, region.strength, region.visible);
      }
      final draft = _draft;
      if (draft != null) collect(draft.style, draft.strength, true);
      collect(_style, _strength, true);

      var changed = false;
      for (final block in blocks) {
        if (await _textureCache.ensureMosaic(block) != null) changed = true;
        if (_disposed) return;
      }
      for (final sigma in sigmas) {
        if (await _textureCache.ensureBlur(sigma) != null) changed = true;
        if (_disposed) return;
      }
      if (changed && !_disposed) notifyListeners();
    }

    if (immediate) {
      unawaited(build());
    } else {
      _textureTimer = Timer(const Duration(milliseconds: 60), build);
    }
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_regions.length}';

  @override
  void dispose() {
    _disposed = true;
    _textureTimer?.cancel();
    _textureCache.dispose();
    image.preview.dispose();
    super.dispose();
  }
}
