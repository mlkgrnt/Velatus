import 'package:url_launcher/url_launcher.dart';

/// Single source of truth for the version string shown in the UI.
///
/// It is duplicated in `pubspec.yaml`; the CI workflow is the only thing that
/// reads both, so a mismatch shows up as a stale label rather than a build
/// failure. Keep them in sync when releasing.
const String kAppVersion = '0.2.0';

const String kRepoUrl = 'https://github.com/mlkgrnt/Velatus';
const String kReleasesUrl = '$kRepoUrl/releases/latest';

/// Outbound links.
///
/// Velatus has no network permission of its own, so "check for updates" hands
/// the URL to the system browser instead of polling GitHub from inside the app.
class AppLinks {
  const AppLinks._();

  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openRepository() => open(kRepoUrl);

  static Future<bool> openReleases() => open(kReleasesUrl);
}
