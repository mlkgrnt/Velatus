import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/editor_preset.dart';
import '../domain/export_prefs.dart';

class RecentEntry {
  const RecentEntry({
    required this.path,
    required this.name,
    required this.openedAt,
  });

  final String path;
  final String name;
  final DateTime openedAt;

  Map<String, Object?> toJson() => {
        'path': path,
        'name': name,
        'openedAt': openedAt.millisecondsSinceEpoch,
      };

  static RecentEntry? fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final name = json['name'];
    if (path is! String || name is! String) return null;
    final stamp = json['openedAt'];
    return RecentEntry(
      path: path,
      name: name,
      openedAt: DateTime.fromMillisecondsSinceEpoch(
        stamp is int ? stamp : 0,
      ),
    );
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController();

  static const _themeKey = 'theme_mode';
  static const _localeKey = 'locale';
  static const _recentKey = 'recent_files';
  static const _presetKey = 'editor_preset';
  static const _exportKey = 'export_prefs';
  static const _maxRecent = 8;

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  List<RecentEntry> _recent = <RecentEntry>[];
  EditorPreset _preset = const EditorPreset();
  ExportPrefs _exportPrefs = const ExportPrefs();
  Timer? _presetTimer;
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  List<RecentEntry> get recent => List.unmodifiable(_recent);

  /// The tool and parameters the editor starts with.
  EditorPreset get preset => _preset;

  /// Format, quality and destination of the last export.
  ExportPrefs get exportPrefs => _exportPrefs;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final theme = _prefs?.getString(_themeKey);
      _themeMode = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _locale = _decodeLocale(_prefs?.getString(_localeKey));
      final preset = _prefs?.getString(_presetKey);
      if (preset != null && preset.isNotEmpty) {
        final decoded = jsonDecode(preset);
        if (decoded is Map<String, Object?>) {
          _preset = EditorPreset.fromJson(decoded);
        }
      }
      final export = _prefs?.getString(_exportKey);
      if (export != null && export.isNotEmpty) {
        final decoded = jsonDecode(export);
        if (decoded is Map<String, Object?>) {
          _exportPrefs = ExportPrefs.fromJson(decoded);
        }
      }
      final raw = _prefs?.getString(_recentKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _recent = decoded
              .whereType<Map<String, Object?>>()
              .map(RecentEntry.fromJson)
              .whereType<RecentEntry>()
              .toList();
        }
      }
    } catch (_) {
      // Settings are a convenience; failing to read them must never block the
      // app from starting.
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs?.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  Future<void> setLocale(Locale? locale) async {
    if (_encodeLocale(_locale) == _encodeLocale(locale)) return;
    _locale = locale;
    notifyListeners();
    await _prefs?.setString(_localeKey, _encodeLocale(locale) ?? '');
  }

  /// Simplified and Traditional Chinese share a language code, so the script
  /// has to travel with it — otherwise picking 繁體中文 would quietly store
  /// plain `zh` and reopen as 简体.
  static String? _encodeLocale(Locale? locale) {
    if (locale == null) return null;
    final script = locale.scriptCode;
    return script == null || script.isEmpty
        ? locale.languageCode
        : '${locale.languageCode}_$script';
  }

  static Locale? _decodeLocale(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('_');
    if (parts.length >= 2) {
      return Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]);
    }
    return Locale(raw);
  }

  /// Remembers the editor's tool choice.
  ///
  /// Sliders emit on every pixel of movement, so the write is coalesced: the
  /// value is live in memory at once and hits disk only after the hand stops.
  void savePreset(EditorPreset preset) {
    if (_preset == preset) return;
    _preset = preset;
    _presetTimer?.cancel();
    _presetTimer = Timer(const Duration(milliseconds: 400), _flushPreset);
  }

  /// Remembers the export sheet's answer. Called once per export, so no
  /// debounce is needed here.
  Future<void> saveExportPrefs(ExportPrefs prefs) async {
    if (_exportPrefs == prefs) return;
    _exportPrefs = prefs;
    await _prefs?.setString(_exportKey, jsonEncode(prefs.toJson()));
  }

  void _flushPreset() {
    _prefs?.setString(_presetKey, jsonEncode(_preset.toJson()));
  }

  @override
  void dispose() {
    if (_presetTimer?.isActive ?? false) _flushPreset();
    _presetTimer?.cancel();
    super.dispose();
  }

  Future<void> addRecent({required String path, required String name}) async {
    _recent.removeWhere((entry) => entry.path == path);
    _recent.insert(
      0,
      RecentEntry(path: path, name: name, openedAt: DateTime.now()),
    );
    if (_recent.length > _maxRecent) {
      _recent = _recent.sublist(0, _maxRecent);
    }
    notifyListeners();
    await _persistRecent();
  }

  Future<void> removeRecent(String path) async {
    _recent.removeWhere((entry) => entry.path == path);
    notifyListeners();
    await _persistRecent();
  }

  Future<void> clearRecent() async {
    _recent.clear();
    notifyListeners();
    await _persistRecent();
  }

  Future<void> _persistRecent() async {
    final raw = jsonEncode(_recent.map((entry) => entry.toJson()).toList());
    await _prefs?.setString(_recentKey, raw);
  }
}
