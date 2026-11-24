import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'mask_region.dart';

/// What the next drag on the canvas will do.
enum EditorTool { brush, box, select }

/// The tool settings that survive closing the app.
///
/// Opening a fresh picture and having to re-pick "blur, medium brush, round
/// corners" every time is busywork, so the editor hands its last choices back
/// to [SettingsController] and starts from them next time.
@immutable
class EditorPreset {
  const EditorPreset({
    this.tool = EditorTool.brush,
    this.style = MaskStyle.mosaic,
    this.brushSize = 0.055,
    this.strength = 0.65,
    this.radius = 0.0,
    this.color = const Color(0xFF14161C),
  });

  final EditorTool tool;
  final MaskStyle style;
  final double brushSize;
  final double strength;
  final double radius;
  final Color color;

  EditorPreset copyWith({
    EditorTool? tool,
    MaskStyle? style,
    double? brushSize,
    double? strength,
    double? radius,
    Color? color,
  }) {
    return EditorPreset(
      tool: tool ?? this.tool,
      style: style ?? this.style,
      brushSize: brushSize ?? this.brushSize,
      strength: strength ?? this.strength,
      radius: radius ?? this.radius,
      color: color ?? this.color,
    );
  }

  Map<String, Object?> toJson() => {
    'tool': tool.name,
    'style': style.name,
    'brushSize': brushSize,
    'strength': strength,
    'radius': radius,
    'color': color.toARGB32(),
  };

  /// Tolerant on purpose: an unreadable or outdated preset falls back to the
  /// defaults field by field instead of throwing the whole thing away.
  static EditorPreset fromJson(Map<String, Object?> json) {
    const fallback = EditorPreset();
    double readDouble(String key, double or) {
      final value = json[key];
      return value is num ? value.toDouble() : or;
    }

    // A preset written by an older build (or a half-written one) can hold a
    // value outside what the sliders accept. Feed that straight back into the
    // controller and the thumb sits pinned at an end while the field keeps a
    // different number — the first drag then "jumps", which looks like two
    // sliders moving together. Clamp to the very same ranges the setters use.
    double readRanged(String key, double or, double min, double max) =>
        readDouble(key, or).clamp(min, max).toDouble();

    final tool = json['tool'];
    final style = json['style'];
    final color = json['color'];
    final preset = EditorPreset(
      tool: EditorTool.values.firstWhere(
        (value) => value.name == tool,
        orElse: () => fallback.tool,
      ),
      style: MaskStyle.values.firstWhere(
        (value) => value.name == style,
        orElse: () => fallback.style,
      ),
      brushSize: readRanged('brushSize', fallback.brushSize, 0.005, 0.4),
      strength: readRanged('strength', fallback.strength, 0.0, 1.0),
      radius: readRanged('radius', fallback.radius, 0.0, 0.5),
      color: Color(color is int ? color : fallback.color.toARGB32()),
    );
    // `select` is a state, not a tool you can start with: there is nothing to
    // select yet.
    return preset.tool == EditorTool.select
        ? preset.copyWith(tool: fallback.tool)
        : preset;
  }

  @override
  bool operator ==(Object other) {
    return other is EditorPreset &&
        other.tool == tool &&
        other.style == style &&
        other.brushSize == brushSize &&
        other.strength == strength &&
        other.radius == radius &&
        other.color == color;
  }

  @override
  int get hashCode =>
      Object.hash(tool, style, brushSize, strength, radius, color);
}
