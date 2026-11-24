import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../domain/editor_preset.dart';
import '../../domain/mask_region.dart';
import '../../services/image_exporter.dart';
import '../../services/image_loader.dart';
import '../../services/mask_renderer.dart';
import '../../services/mask_texture_cache.dart';

export '../../domain/editor_preset.dart' show EditorTool;

class EditorController extends ChangeNotifier {
  EditorController({
    required this.image,
    EditorPreset preset = const EditorPreset(),
    this.onPresetChanged,
  }) {
    _tool = preset.tool;
    _lastDrawTool = preset.tool == EditorTool.select
        ? EditorTool.brush
        : preset.tool;
    _style = preset.style;
    _brushSize = preset.brushSize;
    _strength = preset.strength;
    _radius = preset.radius;
    _solidColor = preset.color;
    _textureCache.attach(image.preview);
    _warmTextures(immediate: true);
  }

  final LoadedImage image;

  /// Called whenever the user changes tool or parameters, so the choice can be
  /// remembered for the next picture.
  final ValueChanged<EditorPreset>? onPresetChanged;
  final MaskTextureCache _textureCache = MaskTextureCache();

  final List<MaskRegion> _regions = <MaskRegion>[];
  final List<List<MaskRegion>> _undoStack = <List<MaskRegion>>[];
  final List<List<MaskRegion>> _redoStack = <List<MaskRegion>>[];
  MaskRegion? _draft;
  final Set<String> _selectedIds = <String>{};
  String? _primaryId;
  List<MaskRegion>? _scrubSnapshot;
  Timer? _textureTimer;
  bool _disposed = false;

  /// Candidates produced by detection, waiting for the user to pick which ones
  /// are actually worth hiding. They are not part of the document yet.
  List<MaskRegion> _pending = <MaskRegion>[];
  final Set<String> _pendingIds = <String>{};

  EditorTool _tool = EditorTool.brush;
  EditorTool _lastDrawTool = EditorTool.brush;
  MaskStyle _style = MaskStyle.mosaic;
  double _brushSize = 0.055;
  double _strength = 0.65;
  double _radius = 0.0;
  Color _solidColor = const Color(0xFF14161C);
  bool _showOriginal = false;
  bool _busy = false;
  double? _exportProgress;

  List<MaskRegion> get regions => List.unmodifiable(_regions);
  MaskRegion? get draft => _draft;
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

  /// A cheap fingerprint of what is currently masked.
  ///
  /// The editor compares it against the fingerprint captured at the last
  /// successful export, so leaving right after saving does not nag with
  /// "you have not exported yet" — while editing again afterwards correctly
  /// brings the warning back.
  int get contentSignature {
    var hash = 0x811c9dc5;
    void mix(int value) {
      hash = ((hash ^ value) * 0x01000193) & 0x3fffffff;
    }

    for (final region in _regions) {
      mix(region.style.index + 1);
      mix(region.shape.index + 1);
      mix((region.strength * 1000).round());
      mix((region.radius * 1000).round());
      mix(region.color.toARGB32());
      mix(region.points.length);
      for (final point in region.points) {
        mix((point.dx * 1e6).round());
        mix((point.dy * 1e6).round());
      }
    }
    return hash;
  }

  int get maskCount => _regions.length;

  /// The current tool and parameters, ready to be stored.
  EditorPreset get preset => EditorPreset(
    tool: _tool == EditorTool.select ? _lastDrawTool : _tool,
    style: _style,
    brushSize: _brushSize,
    strength: _strength,
    radius: _radius,
    color: _solidColor,
  );

  void _persistPreset() => onPresetChanged?.call(preset);

  // ---------------------------------------------------------------- selection

  Set<String> get selectedIds => Set<String>.unmodifiable(_selectedIds);
  bool get hasSelection => _selectedIds.isNotEmpty;
  int get selectionCount => _selectedIds.length;

  List<MaskRegion> get selectedRegions => [
    for (final region in _regions)
      if (_selectedIds.contains(region.id)) region,
  ];

  /// The region whose handles are shown and whose box a corner drag changes.
  String? get primaryId => _primaryId;

  MaskRegion? get primaryRegion {
    final id = _primaryId;
    if (id == null) return null;
    for (final region in _regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  /// Single-selection alias, kept for call sites that only need one.
  MaskRegion? get selectedRegion => primaryRegion;

  bool isSelected(String id) => _selectedIds.contains(id);

  /// Textures resolved against the preview-sized source.
  MaskTextures get textures => MaskTextures(
    mosaic: _textureCache.mosaicNearest,
    blur: _textureCache.blurNearest,
  );

  // ---------------------------------------------------------------- parameters

  /// Applies to every selected region, so a multi-selection can be restyled in
  /// one go — "the new value wins" for the whole set.
  void _applyToSelection(MaskRegion Function(MaskRegion region) change) {
    if (_selectedIds.isEmpty) return;
    var touched = false;
    for (var i = 0; i < _regions.length; i++) {
      if (!_selectedIds.contains(_regions[i].id)) continue;
      final next = change(_regions[i]);
      if (!identical(next, _regions[i])) {
        _regions[i] = next;
        touched = true;
      }
    }
    if (touched) notifyListeners();
  }

  void setTool(EditorTool value) {
    // Switching tools means "I am done with this scan". Leaving the candidate
    // boxes up while the brush refuses to draw would feel broken.
    if (_pending.isNotEmpty) cancelPending();
    if (_tool == value) {
      if (value != EditorTool.select) clearSelection();
      return;
    }
    _tool = value;
    _draft = null;
    // Picking a drawing tool means you are done with the current block.
    if (value != EditorTool.select) {
      _lastDrawTool = value;
      clearSelection();
    }
    notifyListeners();
    _persistPreset();
  }

  void setStyle(MaskStyle value) {
    _style = value;
    _persistPreset();
    _applyToPending(
      (region) => region.copyWith(
        style: value,
        strength: value == MaskStyle.solid ? region.strength : _strength,
        color: value == MaskStyle.solid ? _solidColor : region.color,
      ),
    );
    if (_selectedIds.isEmpty) {
      notifyListeners();
      return;
    }
    _pushHistory();
    for (var i = 0; i < _regions.length; i++) {
      final region = _regions[i];
      if (!_selectedIds.contains(region.id)) continue;
      _regions[i] = region.copyWith(
        style: value,
        strength: value == MaskStyle.solid ? region.strength : _strength,
        color: value == MaskStyle.solid ? _solidColor : region.color,
      );
    }
    _warmTextures();
    notifyListeners();
  }

  void setBrushSize(double value) {
    _brushSize = value.clamp(0.005, 0.4);
    _persistPreset();
    _applyToPending(
      (region) => region.isStroke ? region.copyWith(size: _brushSize) : region,
    );
    _applyToSelection(
      (region) => region.isStroke ? region.copyWith(size: _brushSize) : region,
    );
  }

  void setStrength(double value) {
    _strength = value.clamp(0.02, 1.0);
    _persistPreset();
    _applyToPending(
      (region) => region.style == MaskStyle.solid
          ? region
          : region.copyWith(strength: _strength),
    );
    _applyToSelection(
      (region) => region.style == MaskStyle.solid
          ? region
          : region.copyWith(strength: _strength),
    );
    _warmTextures(immediate: true);
  }

  void setRadius(double value) {
    _radius = value.clamp(0.0, 0.5);
    _persistPreset();
    _applyToPending(
      (region) => region.isFill ? region.copyWith(radius: _radius) : region,
    );
    _applyToSelection(
      (region) => region.isFill ? region.copyWith(radius: _radius) : region,
    );
  }

  void setSolidColor(Color value) {
    _solidColor = value;
    _persistPreset();
    _applyToPending(
      (region) => region.style == MaskStyle.solid
          ? region.copyWith(color: value)
          : region,
    );
    _applyToSelection(
      (region) => region.style == MaskStyle.solid
          ? region.copyWith(color: value)
          : region,
    );
  }

  /// Candidates follow the style controls too.
  ///
  /// Without this the boxes you are about to accept would keep whatever radius
  /// the tool had when you pressed scan, and the only way to get a round avatar
  /// mask would be to guess beforehand. No history is recorded: nothing is in
  /// the document yet.
  void _applyToPending(MaskRegion Function(MaskRegion region) change) {
    if (_pending.isEmpty) return;
    var touched = false;
    for (var i = 0; i < _pending.length; i++) {
      final next = change(_pending[i]);
      if (!identical(next, _pending[i])) {
        _pending[i] = next;
        touched = true;
      }
    }
    if (touched) notifyListeners();
  }

  /// Starts a drag that changes a parameter or the geometry of the selection
  /// continuously. Only one history entry is recorded for the whole gesture,
  /// and tapping without moving records nothing.
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
    clearSelection();
    final shape = switch (_tool) {
      EditorTool.brush => MaskShape.stroke,
      EditorTool.box => MaskShape.box,
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
      case MaskShape.box:
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
      case MaskShape.box:
        if (draft.points.length < 2) return null;
        final bounds = draft.normalizedBounds;
        if (bounds.width < 0.004 || bounds.height < 0.004) return null;
        return draft;
    }
  }

  // ---------------------------------------------------------------- selection

  /// Selects the topmost mask under [point].
  ///
  /// Tapping an already selected mask removes it from the selection, which is
  /// how a multi-selection is built up one tap at a time. A selection is always
  /// homogeneous — all strokes or all boxes — because the parameter row has no
  /// sensible meaning for a mixed set.
  bool selectAt(Offset point, {bool toggle = true}) {
    const tolerance = 0.012;
    for (var i = _regions.length - 1; i >= 0; i--) {
      final region = _regions[i];
      if (!region.visible || !region.hitTest(point, tolerance)) continue;

      final current = primaryRegion;
      if (current != null && current.isStroke != region.isStroke) {
        // A different kind of mask: start a fresh selection instead of mixing.
        _selectedIds
          ..clear()
          ..add(region.id);
        _primaryId = region.id;
      } else if (toggle && _selectedIds.contains(region.id)) {
        _selectedIds.remove(region.id);
        if (_primaryId == region.id) {
          _primaryId = _selectedIds.isEmpty ? null : _selectedIds.last;
        }
      } else {
        _selectedIds.add(region.id);
        _primaryId = region.id;
      }

      _tool = EditorTool.select;
      _adoptParameters(region);
      notifyListeners();
      return true;
    }
    if (_selectedIds.isNotEmpty) {
      clearSelection();
    }
    return false;
  }

  /// Makes [id] the primary region (the one that owns the handles) without
  /// changing what is selected. Used when a corner drag starts on one member of
  /// a multi-selection.
  void focusSelection(String id) {
    final region = _find(id);
    if (region == null || _primaryId == id) return;
    _primaryId = id;
    _adoptParameters(region);
    notifyListeners();
  }

  /// Selection without toggling, used when a drag starts on a mask.
  void selectOnly(String id) {
    final region = _find(id);
    if (region == null) return;
    _selectedIds
      ..clear()
      ..add(id);
    _primaryId = id;
    _tool = EditorTool.select;
    _adoptParameters(region);
    notifyListeners();
  }

  void _adoptParameters(MaskRegion region) {
    _style = region.style;
    _strength = region.strength;
    _radius = region.radius;
    if (region.isStroke) _brushSize = region.size;
    _solidColor = region.color;
  }

  MaskRegion? _find(String id) {
    for (final region in _regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    _primaryId = null;
    notifyListeners();
  }

  /// Moves the region under the finger, and nothing else.
  ///
  /// Dragging used to shift the whole selection, which made a multi-selection
  /// impossible to nudge one block at a time — and left the neighbours as a
  /// rigid group you could never separate again. The selection is kept as it
  /// is, so a following parameter change still applies to every member.
  void translatePrimary(Offset delta) {
    final region = primaryRegion;
    if (region == null) return;
    final bounds = region.normalizedBounds;
    final dx = delta.dx.clamp(-bounds.left, 1 - bounds.right);
    final dy = delta.dy.clamp(-bounds.top, 1 - bounds.bottom);
    if (dx == 0 && dy == 0) return;
    final index = _regions.indexWhere((item) => item.id == region.id);
    if (index < 0) return;
    _regions[index] = region.translated(Offset(dx, dy));
    notifyListeners();
  }

  /// Stretches the primary region into [target] (normalized space). Other
  /// selected regions are deliberately untouched: in a multi-selection a handle
  /// resizes exactly the box you grabbed.
  void resizeSelected(Rect target) {
    final region = primaryRegion;
    if (region == null) return;
    final clamped = Rect.fromLTRB(
      target.left.clamp(0.0, 1.0),
      target.top.clamp(0.0, 1.0),
      target.right.clamp(0.0, 1.0),
      target.bottom.clamp(0.0, 1.0),
    );
    if (clamped.width < 0.004 || clamped.height < 0.004) return;
    final index = _regions.indexWhere((item) => item.id == region.id);
    if (index < 0) return;
    _regions[index] = region.scaledTo(clamped);
    notifyListeners();
  }

  void deleteSelected() {
    if (_selectedIds.isEmpty) return;
    _pushHistory();
    _regions.removeWhere((region) => _selectedIds.contains(region.id));
    _selectedIds.clear();
    _primaryId = null;
    notifyListeners();
  }

  void clearAll() {
    if (_regions.isEmpty) return;
    _pushHistory();
    _regions.clear();
    _selectedIds.clear();
    _primaryId = null;
    notifyListeners();
  }

  void addRegions(Iterable<MaskRegion> regions) {
    final list = regions.where((region) => region.points.isNotEmpty).toList();
    if (list.isEmpty) return;
    _pushHistory();
    _regions.addAll(list);
    notifyListeners();
    _warmTextures();
  }

  // ------------------------------------------------------- pending detection

  bool get hasPending => _pending.isNotEmpty;
  List<MaskRegion> get pending => List.unmodifiable(_pending);
  int get pendingSelectedCount => _pendingIds.length;

  bool isPendingSelected(String id) => _pendingIds.contains(id);

  /// Hands over the candidates produced by detection. Nothing is added to the
  /// document until [commitPending].
  void setPending(List<MaskRegion> candidates) {
    _pending = List<MaskRegion>.of(candidates);
    _pendingIds
      ..clear()
      ..addAll(candidates.map((region) => region.id));
    // Handles on an existing mask would fight with the candidate boxes.
    _selectedIds.clear();
    _primaryId = null;
    notifyListeners();
  }

  void togglePending(String id) {
    if (!_pendingIds.remove(id)) _pendingIds.add(id);
    notifyListeners();
  }

  void setAllPending(bool selected) {
    _pendingIds.clear();
    if (selected) {
      _pendingIds.addAll(_pending.map((region) => region.id));
    }
    notifyListeners();
  }

  void cancelPending() {
    if (_pending.isEmpty) return;
    _pending = <MaskRegion>[];
    _pendingIds.clear();
    notifyListeners();
  }

  /// Turns the chosen candidates into real masks, replacing any masks left over
  /// from an earlier detection pass.
  int commitPending() {
    final chosen = [
      for (final region in _pending)
        if (_pendingIds.contains(region.id)) region,
    ];
    _pending = <MaskRegion>[];
    _pendingIds.clear();
    if (chosen.isEmpty) {
      notifyListeners();
      return 0;
    }
    _pushHistory();
    _regions
      ..removeWhere((region) => region.isDetected)
      ..addAll(chosen);
    notifyListeners();
    _warmTextures();
    return chosen.length;
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
    _selectedIds.clear();
    _primaryId = null;
    notifyListeners();
    _warmTextures();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List<MaskRegion>.of(_regions));
    _regions
      ..clear()
      ..addAll(_redoStack.removeLast());
    _selectedIds.clear();
    _primaryId = null;
    notifyListeners();
    _warmTextures();
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
