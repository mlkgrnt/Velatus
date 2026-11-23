import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'core/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  await settings.load();
  runApp(VelatusApp(settings: settings));
}
