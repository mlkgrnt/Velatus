import 'package:flutter_test/flutter_test.dart';
import 'package:velatus/services/update_service.dart';

void main() {
  group('version parsing', () {
    test('strips the tag prefix', () {
      expect(UpdateService.normalizeVersion('v0.3.0'), '0.3.0');
      expect(UpdateService.normalizeVersion('release-1.12.4'), '1.12.4');
      expect(UpdateService.normalizeVersion('0.3.0'), '0.3.0');
    });

    test('rejects tags without a version', () {
      expect(UpdateService.normalizeVersion('latest'), isNull);
      expect(UpdateService.normalizeVersion(''), isNull);
    });

    test('compares numerically, not lexically', () {
      expect(UpdateService.compareVersions('0.10.0', '0.9.0'), greaterThan(0));
      expect(UpdateService.compareVersions('0.3.0', '0.3.0'), 0);
      expect(UpdateService.compareVersions('0.2.9', '0.3.0'), lessThan(0));
      expect(UpdateService.compareVersions('1.0.0', '0.99.99'), greaterThan(0));
    });
  });

  group('release payload', () {
    Map<String, dynamic> payload({String tag = 'v0.3.0'}) => {
      'tag_name': tag,
      'body': '  ## Fixes\n- dock height  ',
      'assets': [
        {
          'name': 'velatus-0.3.0-arm64-v8a.apk',
          'browser_download_url': 'https://example.com/a.apk',
          'size': 33 * 1024 * 1024,
        },
        {
          'name': 'velatus-0.3.0-windows.zip',
          'browser_download_url': 'https://example.com/w.zip',
          'size': 12 * 1024 * 1024,
        },
      ],
    };

    test('reads version, notes, size and source', () {
      final info = UpdateService.parseRelease(
        payload(),
        source: 'api.github.com',
      );
      expect(info, isNotNull);
      expect(info!.version, '0.3.0');
      expect(info.notes, startsWith('## Fixes'));
      expect(info.notes, endsWith('dock height'));
      expect(info.source, 'api.github.com');
      // Which asset wins depends on the host running the test: an APK on
      // Android, the zip on Windows. Both are legitimate; the download URL and
      // size must still describe the same asset.
      expect(
        info.assetName,
        anyOf('velatus-0.3.0-arm64-v8a.apk', 'velatus-0.3.0-windows.zip'),
      );
      expect(info.downloadUrl, isNotEmpty);
      expect(
        info.sizeBytes,
        info.assetName.endsWith('.apk') ? 33 * 1024 * 1024 : 12 * 1024 * 1024,
      );
      expect(info.sizeLabel, endsWith(' MB'));
    });

    test('a release without assets is not an update', () {
      final json = payload()..['assets'] = const [];
      expect(UpdateService.parseRelease(json), isNull);
    });

    test('a tag that is not a version is ignored', () {
      expect(
        UpdateService.parseRelease(payload(tag: 'nightly')),
        isNull,
        reason: 'a moving tag must never look like a newer release',
      );
    });

    test('a missing download url is ignored', () {
      final json = payload();
      for (final asset in (json['assets'] as List)) {
        asset['browser_download_url'] = '';
      }
      expect(UpdateService.parseRelease(json), isNull);
    });
  });
}
