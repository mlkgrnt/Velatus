import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/domain/editor_preset.dart';
import 'package:velatus/domain/mask_region.dart';

/// The preset is what makes the editor open with the same brush you used last
/// time, so it has to survive both the JSON round-trip and junk on disk.
void main() {
  test('a preset survives the trip through JSON', () {
    const preset = EditorPreset(
      tool: EditorTool.box,
      style: MaskStyle.blur,
      brushSize: 0.08,
      strength: 0.85,
      radius: 0.35,
      color: Color(0xFFFF0055),
    );
    final restored = EditorPreset.fromJson(preset.toJson());
    expect(restored, preset);
  });

  test('unknown values fall back to the defaults instead of throwing', () {
    final restored = EditorPreset.fromJson({
      'tool': 'lasso',
      'style': 'pixelate',
      'brushSize': 'wide',
      'color': null,
    });
    const fallback = EditorPreset();
    expect(restored.tool, fallback.tool);
    expect(restored.style, fallback.style);
    expect(restored.brushSize, fallback.brushSize);
    expect(restored.color, fallback.color);
  });

  test('select is never restored as the starting tool', () {
    final restored = EditorPreset.fromJson({'tool': 'select'});
    expect(restored.tool, EditorTool.brush);
  });

  test('out-of-range stored numbers are clamped to the slider ranges', () {
    final restored = EditorPreset.fromJson({
      'brushSize': 9.0,
      'strength': -3.0,
      'radius': 42.0,
    });
    expect(restored.brushSize, 0.4);
    expect(restored.strength, 0.0);
    expect(restored.radius, 0.5);
  });

  test('zero strength is a real setting, not clamped away', () {
    const preset = EditorPreset(strength: 0);
    expect(preset.strength, 0);
    expect(EditorPreset.fromJson(preset.toJson()), preset);
    expect(EditorPreset.fromJson({'strength': -8}).strength, 0);
  });
}
