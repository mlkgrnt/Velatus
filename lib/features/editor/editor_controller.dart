import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../domain/mask_region.dart';
import '../../services/image_exporter.dart';
import '../../services/image_loader.dart';
import '../../services/mask_renderer.dart';
import '../../services/mosaic_texture_cache.dart';

enum EditorTool { brush, rect, ellipse, lasso, select }

class EditorController extends ChangeNotifier {
  EditorController({required this.image}) {
    _textureCache.attach(image.preview);
    _warmTextures();
  }

  final LoadedImage image;
  final MosaicTextureCache _textureCache = MosaicTextureCache();

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
  Color get solidColor => _solidColor;
  bool get showOriginal => _showOriginal;
  bool get busy => _busy;
  double? get exportProgress => _exportProgress;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get hasMasks => _regions.isNotEmpty;

  int get maskCount => _regions.length;

  MaskRegion? get selectedRegion {
    final id = _selectedId;
    if (id == null) return null;
    for (final region in _regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  Image? textureFor(int block) => _textureCache[block];

  // ---------------------------------------------------------------- parameters

  void setTool(EditorTool value) {
    if (_tool == value) return;
    _tool = value;
    _draft = null;
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

  void setSolidColor(Color value) {
    _solidColor = value;
    final selected = selectedRegion;
    if (selected != null && selected.style == MaskStyle.solid) {
      _replace(selected.copyWith(color: value), recordHistory: true);
    }
    notifyListeners();
  }

  /// Starts a drag that changes a parameter continuously. Only one history
  /// entry is recorded for the whole gesture.
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
    final shape = switch (_tool) {
      EditorTool.brush => MaskShape.stroke,
      EditorTool.rect => MaskShape.rect,
      EditorTool.ellipse => MaskShape.ellipse,
      EditorTool.lasso => MaskShape.lasso,
      EditorTool.select => MaskShape.stroke,
    };
    _draft = MaskRegion(
      id: _newId(),
      style: _style,
      shape: shape,
      points: [point, if (shape != MaskShape.stroke) point],
      size: _brushSize,
      strength: _strength,
      color: _solidColor,
    );
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
      case MaskShape.lasso:
        final last = draft.points.last;
        if ((point - last).distance < 0.002) return;
        draft = draft.copyWith(points: [...draft.points, point]);
      case MaskShape.rect:
      case MaskShape.ellipse:
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
    _selectedId = preview.id;
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
      case MaskShape.lasso:
        if (draft.points.isEmpty) return null;
        return draft;
      case MaskShape.rect:
      case MaskShape.ellipse:
        if (draft.points.length < 2) return null;
        final bounds = draft.normalizedBounds;
        if (bounds.width < 0.004 || bounds.height < 0.004) return null;
        return draft;
    }
  }

  // ---------------------------------------------------------------- selection

  void selectAt(Offset point) {
    const tolerance = 0.012;
    for (var i = _regions.length - 1; i >= 0; i--) {
      final region = _regions[i];
      if (region.visible && region.hitTest(point, tolerance)) {
        _selectedId = region.id;
        _tool = EditorTool.select;
        _style = region.style;
        _strength = region.strength;
        if (region.isStroke) _brushSize = region.size;
        _solidColor = region.color;
        notifyListeners();
        return;
      }
    }
    if (_selectedId != null) {
      _selectedId = null;
      notifyListeners();
    }
  }

  void clearSelection() {
    if (_selectedId == null) return;
    _selectedId = null;
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

  void toggleVisibility(String id) {
    final index = _regions.indexWhere((region) => region.id == id);
    if (index < 0) return;
    _pushHistory();
    _regions[index] = _regions[index].copyWith(
      visible: !_regions[index].visible,
    );
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
    _selectedId = list.last.id;
    notifyListeners();
    _warmTextures();
  }

  void selectRegion(String id) {
    _selectedId = id;
    _tool = EditorTool.select;
    final region = selectedRegion;
    if (region != null) {
      _style = region.style;
      _strength = region.strength;
      if (region.isStroke) _brushSize = region.size;
      _solidColor = region.color;
    }
    notifyListeners();
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

  void _warmTextures() {
    _textureTimer?.cancel();
    _textureTimer = Timer(const Duration(milliseconds: 60), () async {
      final blocks = <int>{};
      final shortSide = math.min(
        image.preview.width.toDouble(),
        image.preview.height.toDouble(),
      );
      for (final region in _regions) {
        if (region.style == MaskStyle.mosaic && region.visible) {
          blocks.add(MaskRenderer.mosaicBlockPx(region.strength, shortSide));
        }
      }
      if (_style == MaskStyle.mosaic) {
        blocks.add(MaskRenderer.mosaicBlockPx(_strength, shortSide));
      }
      var changed = false;
      for (final block in blocks) {
        if (await _textureCache.ensure(block) != null) changed = true;
        if (_disposed) return;
      }
      if (changed && !_disposed) notifyListeners();
    });
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
