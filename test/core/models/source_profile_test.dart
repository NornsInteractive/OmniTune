import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';

void main() {
  group('SourceProfile scan directories', () {
    test('defaults to effective root when scan directories are empty', () {
      const profile = SourceProfile(
        id: 'source',
        name: 'Library',
        protocol: SourceProtocol.webdav,
        baseUrl: 'https://example.com/dav/music/',
        username: 'user',
        password: 'pass',
        rootPath: '/music/',
      );

      expect(profile.effectiveRootPath, '/');
      expect(profile.effectiveScanDirectories, ['/']);
      expect(profile.effectiveExcludedScanDirectories, isEmpty);
    });

    test('resolves scan and excluded directories relative to source root', () {
      const profile = SourceProfile(
        id: 'source',
        name: 'Library',
        protocol: SourceProtocol.webdav,
        baseUrl: 'https://example.com/dav/',
        username: 'user',
        password: 'pass',
        rootPath: '/Music/',
        scanDirectories: ['/Music/Jazz/', 'Live'],
        excludedScanDirectories: ['/Music/Skip/', '/Trailers/'],
      );

      expect(profile.normalizedScanDirectories, ['/Jazz/', '/Live/']);
      expect(profile.normalizedExcludedScanDirectories, [
        '/Skip/',
        '/Trailers/',
      ]);
      expect(profile.effectiveScanDirectories, [
        '/Music/Jazz/',
        '/Music/Live/',
      ]);
      expect(profile.effectiveExcludedScanDirectories, [
        '/Music/Skip/',
        '/Music/Trailers/',
      ]);
    });
  });

  group('SourceProfile metadata', () {
    test('persists source-specific metadata through json', () {
      const profile = SourceProfile(
        id: 'cloud189',
        name: '189 Cloud',
        protocol: SourceProtocol.cloudDrive,
        baseUrl: 'https://api.cloud.189.cn',
        username: 'cloud189',
        password: 'refresh-token',
        rootPath: '/',
        metadata: {
          'cloud189.authMode': 'appAuthorization',
          'cloud189.appKey': 'app-key',
        },
      );

      final restored = SourceProfile.fromJson(profile.toJson());

      expect(restored.metadata, {
        'cloud189.authMode': 'appAuthorization',
        'cloud189.appKey': 'app-key',
      });
      expect(restored, profile);
    });
  });
}
