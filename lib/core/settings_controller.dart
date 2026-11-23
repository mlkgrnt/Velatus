import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _maxRecent = 8;

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  List<RecentEntry> _recent = <RecentEntry>[];
  SharedPreferences? _prefs;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  List<RecentEntry> get recent => List.unmodifiable(_recent);

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final theme = _prefs?.getString(_themeKey);
      _themeMode = switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      final locale = _prefs?.getString(_localeKey);
      _locale = (locale == null || locale.isEmpty) ? null : Locale(locale);
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
    if (_locale?.languageCode == locale?.languageCode) return;
    _locale = locale;
    notifyListeners();
    await _prefs?.setString(_localeKey, locale?.languageCode ?? '');
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
