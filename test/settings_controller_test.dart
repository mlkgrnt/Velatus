import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velatus/core/settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads persisted theme and locale', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'locale': 'zh',
      'recent_files':
          '[{"path":"/tmp/a.jpg","name":"a.jpg","openedAt":1700000000000}]',
    });
    final settings = SettingsController();
    await settings.load();

    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.locale?.languageCode, 'zh');
    expect(settings.recent, hasLength(1));
    expect(settings.recent.first.name, 'a.jpg');
  });

  test('persists theme changes', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    await settings.setThemeMode(ThemeMode.light);
    expect(settings.themeMode, ThemeMode.light);

    final reloaded = SettingsController();
    await reloaded.load();
    expect(reloaded.themeMode, ThemeMode.light);
  });

  test('recent files are deduplicated and capped', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    for (var i = 0; i < 12; i++) {
      await settings.addRecent(path: '/tmp/$i.jpg', name: '$i.jpg');
    }
    expect(settings.recent, hasLength(8));
    expect(settings.recent.first.name, '11.jpg');

    await settings.addRecent(path: '/tmp/5.jpg', name: '5.jpg');
    expect(settings.recent, hasLength(8));
    expect(settings.recent.first.name, '5.jpg');
    expect(
      settings.recent.where((entry) => entry.path == '/tmp/5.jpg'),
      hasLength(1),
    );
  });

  test('clearRecent empties the list', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();
    await settings.addRecent(path: '/tmp/a.jpg', name: 'a.jpg');
    await settings.clearRecent();
    expect(settings.recent, isEmpty);
  });
}
