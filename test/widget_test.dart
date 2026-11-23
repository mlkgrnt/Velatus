import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velatus/app.dart';
import 'package:velatus/core/settings_controller.dart';

void main() {
  testWidgets('home screen renders brand, hero and open action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    await tester.pumpWidget(VelatusApp(settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Velatus'), findsWidgets);
    expect(find.text('Open an image'), findsWidgets);
    expect(find.text('Never leaves your device'), findsWidgets);
  });

  testWidgets('switching locale updates the whole app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsController();
    await settings.load();

    await tester.pumpWidget(VelatusApp(settings: settings));
    await tester.pumpAndSettle();

    await settings.setLocale(const Locale('zh'));
    await tester.pumpAndSettle();

    expect(find.text('隐格'), findsWidgets);
    expect(find.text('打开图片'), findsWidgets);
  });
}
