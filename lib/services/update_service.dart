import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_info.dart';

/// A release newer than the running build.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.assetName,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.source,
  });

  final String version;
  final String notes;
  final String assetName;
  final String downloadUrl;
  final int sizeBytes;

  /// The host that answered, so the UI can say where it came from.
  final String source;

  String get sizeLabel =>
      sizeBytes > 0 ? '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB' : '';
}

class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// In-app update checking and downloading.
///
/// Velatus is distributed as a GitHub release, so "check for updates" used to
/// mean "open a browser and hope". This does the whole job inside the app and
/// only reaches for the browser when every endpoint has failed.
///
/// It also has to survive the network it is most likely to run on. GitHub's API
/// is frequently unreachable from mainland China while the release CDN is not,
/// so both the metadata lookup and the download walk a list of endpoints, and
/// the first one that answers wins. Nothing is hard-coded to a single mirror:
/// mirrors rot, and a stale mirror should cost a retry, not the feature.
class UpdateService {
  const UpdateService._();

  static const MethodChannel _installer = MethodChannel(
    'app.velatus/installer',
  );

  static const String _repo = 'mlkgrnt/Velatus';

  /// Tried in order until one returns usable JSON.
  ///
  /// `gh-proxy.com` also proxies the API, and it answered from a network where
  /// GitHub's API itself was rate-limited, so it earns the second slot rather
  /// than the usual "try the mirror last" arrangement.
  static const List<String> _apiEndpoints = [
    'https://api.github.com/repos/$_repo/releases/latest',
    'https://gh-proxy.com/https://api.github.com/repos/$_repo/releases/latest',
    'https://api.kkgithub.com/repos/$_repo/releases/latest',
  ];

  /// Prefixes that mirror release downloads. A bare URL means "direct".
  static const List<String> _downloadMirrors = [
    '',
    'https://gh-proxy.com/',
    'https://ghfast.top/',
    'https://hub.gitmirror.com/',
  ];

  /// Short on purpose: a blocked host tends to hang rather than refuse, and
  /// three hung attempts would look like a frozen button.
  static const Duration _apiTimeout = Duration(seconds: 6);

  // ------------------------------------------------------------------- check

  /// Returns the newer release, or null when this build is already current.
  ///
  /// Throws [UpdateException] only when no endpoint could be reached — "no
  /// update" and "could not ask" are different answers and the UI says so.
  static Future<UpdateInfo?> check({String? currentVersion}) async {
    final current = currentVersion ?? _currentVersion;
    final failures = <String>[];
    for (final endpoint in _apiEndpoints) {
      try {
        final json = await _getJson(endpoint);
        final info = _parse(json, endpoint);
        if (info == null) continue;
        if (compareVersions(info.version, current) <= 0) return null;
        return info;
      } catch (error) {
        failures.add('$error');
      }
    }
    throw UpdateException(
      failures.isEmpty ? 'No release information available' : failures.last,
    );
  }

  static Future<Map<String, dynamic>> _getJson(String url) async {
    final client = HttpClient()..connectionTimeout = _apiTimeout;
    try {
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(_apiTimeout);
      // GitHub rejects API requests without a user agent.
      request.headers
        ..set(HttpHeaders.userAgentHeader, 'Velatus-Updater')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(_apiTimeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw UpdateException('HTTP ${response.statusCode} from $url');
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_apiTimeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw UpdateException('Unexpected response from $url');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static UpdateInfo? _parse(Map<String, dynamic> json, String endpoint) =>
      parseRelease(json, source: Uri.parse(endpoint).host);

  /// Pulls the fields the UI needs out of a GitHub release payload.
  @visibleForTesting
  static UpdateInfo? parseRelease(
    Map<String, dynamic> json, {
    String source = 'github.com',
  }) {
    final tag = (json['tag_name'] ?? json['name'] ?? '') as String;
    final version = normalizeVersion(tag);
    if (version == null) return null;

    final assets = (json['assets'] as List?) ?? const [];
    final candidates = <Map<String, dynamic>>[
      for (final asset in assets)
        if (asset is Map<String, dynamic>) asset,
    ];
    final wanted = _pickAssetName(candidates);
    final preferred = candidates.where((asset) {
      final name = (asset['name'] ?? '') as String;
      return name == wanted;
    }).toList();
    final pool = preferred.isNotEmpty ? preferred : candidates;
    if (pool.isEmpty) return null;

    final asset = pool.first;
    final url = (asset['browser_download_url'] ?? '') as String;
    if (url.isEmpty) return null;

    return UpdateInfo(
      version: version,
      notes: ((json['body'] ?? '') as String).trim(),
      assetName: (asset['name'] ?? '') as String,
      downloadUrl: url,
      sizeBytes: ((asset['size'] ?? 0) as num).toInt(),
      source: source,
    );
  }

  /// Chooses the asset that matches this device.
  ///
  /// Release builds are split per ABI, so an arm64 phone downloading the
  /// armeabi-v7a package would "work" but look twice as large as it should.
  static String? _pickAssetName(List<Map<String, dynamic>> assets) {
    final names = [
      for (final asset in assets) (asset['name'] ?? '') as String,
    ];
    if (Platform.isAndroid) {
      final abi = switch (Abi.current()) {
        Abi.androidArm64 => 'arm64-v8a',
        Abi.androidArm => 'armeabi-v7a',
        Abi.androidX64 => 'x86_64',
        _ => null,
      };
      final apks = names.where((name) => name.endsWith('.apk')).toList();
      if (apks.isEmpty) return null;
      if (abi != null) {
        for (final name in apks) {
          if (name.contains(abi)) return name;
        }
      }
      // A universal APK has no ABI in its name; take the first one.
      return apks.first;
    }
    if (Platform.isWindows) {
      for (final name in names) {
        if (name.endsWith('.zip')) return name;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- download

  /// Downloads [info] and reports progress in 0..1.
  static Future<File> download(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final directory = await _downloadDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}${info.assetName}');
    if (await file.exists()) await file.delete();
    await file.create(recursive: true);

    final errors = <String>[];
    for (final mirror in _downloadMirrors) {
      final url = mirror.isEmpty ? info.downloadUrl : '$mirror${info.downloadUrl}';
      try {
        await _downloadFrom(url, file, onProgress, isCancelled);
        if (await file.length() > 0) return file;
      } catch (error) {
        errors.add('$error');
        if (isCancelled?.call() ?? false) rethrow;
      }
    }
    throw UpdateException(errors.isEmpty ? 'Download failed' : errors.first);
  }

  static Future<void> _downloadFrom(
    String url,
    File file,
    void Function(double)? onProgress,
    bool Function()? isCancelled,
  ) async {
    final client = HttpClient()..connectionTimeout = _apiTimeout;
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(_apiTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'Velatus-Updater');
      final response = await request.close().timeout(_apiTimeout);
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw UpdateException('HTTP ${response.statusCode}');
      }
      final total = response.contentLength;
      var received = 0;
      sink = file.openWrite();
      await for (final chunk in response) {
        if (isCancelled?.call() ?? false) {
          throw UpdateException('cancelled');
        }
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
      onProgress?.call(1);
    } finally {
      await sink?.close();
      client.close(force: true);
    }
  }

  static Future<Directory> _downloadDirectory() async {
    final base = Platform.isAndroid
        ? await getTemporaryDirectory()
        : (await getDownloadsDirectory()) ?? await getTemporaryDirectory();
    // The Android FileProvider only exposes `<cache>/updates/`.
    final directory = Directory(
      Platform.isAndroid
          ? '${base.path}${Platform.pathSeparator}updates'
          : '${base.path}${Platform.pathSeparator}Velatus',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  /// Hands the APK to the system installer. Android shows its own prompt.
  static Future<bool> install(File file) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _installer.invokeMethod<bool>('install', {
        'path': file.path,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the folder containing a downloaded file (desktop only).
  static Future<bool> revealInExplorer(File file) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', file.path]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', ['-R', file.path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [file.parent.path]);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ----------------------------------------------------------------- helpers

  static String get _currentVersion => kAppVersion;

  /// `v0.3.0` → `0.3.0`; anything unparsable → null.
  @visibleForTesting
  static String? normalizeVersion(String tag) {
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(tag);
    if (match == null) return null;
    return '${match.group(1)}.${match.group(2)}.${match.group(3)}';
  }

  @visibleForTesting
  static int compareVersions(String a, String b) {
    List<int> parts(String value) => [
      for (final piece in value.split('.')) int.tryParse(piece) ?? 0,
    ];
    final left = parts(a);
    final right = parts(b);
    for (var i = 0; i < 3; i++) {
      final diff =
          (left.elementAtOrNull(i) ?? 0) - (right.elementAtOrNull(i) ?? 0);
      if (diff != 0) return diff;
    }
    return 0;
  }
}
