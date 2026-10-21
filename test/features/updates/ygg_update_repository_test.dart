import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/features/updates/data/ygg_update_repository.dart';
import 'package:music/features/updates/domain/app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _sha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _otherSha =
    'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

void main() {
  group('installedVersion', () {
    test('parses the package build number', () async {
      final adapter = _FakeAdapter((_) async => _jsonResponse(<String, Object?>{}));
      final repository = _repository(adapter, buildNumber: '308');

      final version = await repository.installedVersion();

      expect(version.name, '1.0.307');
      expect(version.code, 308);
    });

    test('rejects missing, non-numeric and non-positive builds', () async {
      for (final buildNumber in <String>['', 'abc', '0', '-3']) {
        final adapter = _FakeAdapter(
          (_) async => _jsonResponse(<String, Object?>{}),
        );
        final repository = _repository(adapter, buildNumber: buildNumber);

        await _expectFailure(
          repository.installedVersion(),
          AppUpdateFailure.invalidResponse,
        );
      }
    });
  });

  group('check request', () {
    test('queries app id, version code, channel, platform and arch', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(packages: <Map<String, Object?>>[_package()]),
        ),
      );
      final repository = _repository(
        adapter,
        target: const UpdateTarget('android', 'arm64-v8a'),
      );

      final release = await repository.check(107);

      expect(release, isNotNull);
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.scheme, 'https');
      expect(request.uri.host, 'ygg.norns.cc.cd');
      expect(request.uri.path, '/api/v1/app/latest');
      expect(request.uri.queryParameters, <String, String>{
        'app_id': YggUpdateRepository.appId,
        'version_code': '107',
        'channel': 'default',
        'platform': 'android',
        'arch': 'arm64-v8a',
      });
    });

    test('has_update=true never overrides an equal or older version code', () async {
      for (final currentCode in <int>[200, 201, 999]) {
        final adapter = _FakeAdapter(
          (_) async => _jsonResponse(
            _body(
              versionCode: 200,
              hasUpdate: true,
              packages: <Map<String, Object?>>[_package()],
            ),
          ),
        );
        final repository = _repository(adapter);

        final release = await repository.check(currentCode);

        expect(release, isNull, reason: 'currentCode=$currentCode');
      }
    });

    test('returns a strictly newer numeric version code', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(
            versionCode: 201,
            hasUpdate: false,
            packages: <Map<String, Object?>>[_package()],
          ),
        ),
      );
      final repository = _repository(adapter);

      final release = await repository.check(200);

      expect(release, isNotNull);
      expect(release!.versionCode, 201);
    });

    test('rejects a non-numeric or non-positive latest version code', () async {
      for (final code in <Object?>['200', 0, -1, null, 2.5]) {
        final adapter = _FakeAdapter(
          (_) async => _jsonResponse(
            _body(
              versionCode: code,
              packages: <Map<String, Object?>>[_package()],
            ),
          ),
        );
        final repository = _repository(adapter);

        await _expectFailure(
          repository.check(100),
          AppUpdateFailure.invalidResponse,
        );
      }
    });
  });

  group('package selection', () {
    test('prefers the exact architecture over universal', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(
            packages: <Map<String, Object?>>[
              _package(
                id: 'pkg-universal',
                arch: 'universal',
                size: 10,
                sha: _otherSha,
              ),
              _package(id: 'pkg-exact', arch: 'arm64-v8a', size: 20, sha: _sha),
            ],
          ),
        ),
      );
      final repository = _repository(
        adapter,
        target: const UpdateTarget('android', 'arm64-v8a'),
      );

      final release = await repository.check(100);

      expect(release, isNotNull);
      expect(release!.fileSize, 20);
      expect(release.sha256, _sha);
      expect(
        release.downloadUri.queryParameters['package_id'],
        'pkg-exact',
      );
    });

    test('falls back to universal when no exact package exists', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(
            packages: <Map<String, Object?>>[
              _package(
                id: 'pkg-universal',
                arch: 'universal',
                size: 77,
                sha: _otherSha,
              ),
            ],
          ),
        ),
      );
      final repository = _repository(
        adapter,
        target: const UpdateTarget('android', 'arm64-v8a'),
      );

      final release = await repository.check(100);

      expect(release, isNotNull);
      expect(release!.fileSize, 77);
      expect(release.sha256, _otherSha);
      expect(
        release.downloadUri.queryParameters['package_id'],
        'pkg-universal',
      );
    });

    test('never selects an Android package on Linux', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(
            packages: <Map<String, Object?>>[
              _package(
                id: 'pkg-android',
                platform: 'android',
                arch: 'arm64-v8a',
              ),
              _package(
                id: 'pkg-android-x64',
                platform: 'android',
                arch: 'x86_64',
              ),
            ],
          ),
        ),
      );
      final repository = _repository(
        adapter,
        target: const UpdateTarget('linux', 'x86_64'),
      );

      await _expectFailure(
        repository.check(100),
        AppUpdateFailure.noPackage,
      );
    });

    test('uses top-level data when the package list is absent', () async {
      final body = <String, Object?>{
        'code': 0,
        'data': <String, Object?>{
          'app_id': YggUpdateRepository.appId,
          'latest_version_code': 200,
          'latest_version_name': '2.0.0',
          'changelog': 'changelog',
          'platform': 'linux',
          'arch': 'x86_64',
          'file_size': 55,
          'id': 'top-level-package',
        },
      };
      final adapter = _FakeAdapter((_) async => _jsonResponse(body));
      final repository = _repository(
        adapter,
        target: const UpdateTarget('linux', 'x86_64'),
      );

      final release = await repository.check(100);

      expect(release, isNotNull);
      expect(release!.fileSize, 55);
      expect(release.sha256, isNull);
      expect(
        release.downloadUri.queryParameters['package_id'],
        'top-level-package',
      );
    });
  });

  group('transport and malformed responses', () {
    test('maps HTTP 404 to noPackage', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(<String, Object?>{'error': 'missing'}, 404),
      );
      final repository = _repository(adapter);

      await _expectFailure(
        repository.check(100),
        AppUpdateFailure.noPackage,
      );
    });

    test('maps network and server failures to network', () async {
      final failures = <Future<ResponseBody> Function(RequestOptions)>[
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
        (_) async => _jsonResponse(<String, Object?>{'error': 'boom'}, 500),
      ];

      for (final failure in failures) {
        final adapter = _FakeAdapter(failure);
        final repository = _repository(adapter);

        await _expectFailure(repository.check(100), AppUpdateFailure.network);
      }
    });

    test('rejects malformed response envelopes and data', () async {
      final malformedBodies = <Map<String, Object?>>[
        <String, Object?>{'code': 0, 'data': 'not-a-map'},
        <String, Object?>{'code': 1, 'data': <String, Object?>{}},
        <String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'app_id': YggUpdateRepository.appId,
            'latest_version_code': '200',
            'latest_version_name': '2.0.0',
          },
        },
        <String, Object?>{
          'code': 0,
          'data': <String, Object?>{
            'app_id': 'com.example.other',
            'latest_version_code': 200,
            'latest_version_name': '2.0.0',
          },
        },
      ];

      for (final body in malformedBodies) {
        final adapter = _FakeAdapter((_) async => _jsonResponse(body));
        final repository = _repository(adapter);

        await _expectFailure(
          repository.check(100),
          AppUpdateFailure.invalidResponse,
        );
      }
    });
  });

  group('checksum handling', () {
    test('fails Android when the checksum is missing or malformed', () async {
      for (final digest in <Object?>[null, '', 'abc', 'g' * 64]) {
        final adapter = _FakeAdapter(
          (_) async => _jsonResponse(
            _body(
              packages: <Map<String, Object?>>[_package(sha: digest)],
            ),
          ),
        );
        final repository = _repository(adapter);

        await _expectFailure(
          repository.check(100),
          AppUpdateFailure.checksumMissing,
        );
      }
    });

    test('accepts a valid checksum and normalizes it to lowercase', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(
            packages: <Map<String, Object?>>[
              _package(sha: _sha.toUpperCase()),
            ],
          ),
        ),
      );
      final repository = _repository(adapter);

      final release = await repository.check(100);

      expect(release, isNotNull);
      expect(release!.sha256, _sha);
    });

    test('does not require a checksum on desktop', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(
            platform: 'linux',
            arch: 'x86_64',
            packages: <Map<String, Object?>>[
              _package(platform: 'linux', arch: 'x86_64', sha: null),
            ],
          ),
        ),
      );
      final repository = _repository(
        adapter,
        target: const UpdateTarget('linux', 'x86_64'),
      );

      final release = await repository.check(100);

      expect(release, isNotNull);
      expect(release!.sha256, isNull);
    });
  });

  group('download URI', () {
    test('ignores a server supplied download_url and builds only the Ygg URI', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(
            versionCode: 200,
            versionName: '2.0.0',
            packageId: 'pkg-42',
            downloadUrl: 'https://evil.example/pwn.apk?steal=1',
            packages: <Map<String, Object?>>[
              _package(
                id: 'pkg-42',
                downloadUrl: 'https://evil.example/pkg.apk',
              ),
            ],
          ),
        ),
      );
      final repository = _repository(
        adapter,
        target: const UpdateTarget('android', 'arm64-v8a'),
      );

      final release = await repository.check(100);

      expect(release, isNotNull);
      expect(release!.versionName, '2.0.0');
      expect(release.versionCode, 200);
      expect(release.changelog, 'changelog');
      expect(release.platform, 'android');

      final uri = release.downloadUri;
      expect(uri.scheme, 'https');
      expect(uri.host, 'ygg.norns.cc.cd');
      expect(uri.path, '/api/v1/app/download');
      expect(uri.queryParameters, <String, String>{
        'app_id': YggUpdateRepository.appId,
        'version_code': '200',
        'channel': 'default',
        'platform': 'android',
        'arch': 'arm64-v8a',
        'package_id': 'pkg-42',
      });
      expect(uri.toString(), isNot(contains('evil.example')));
      expect(uri.queryParameters.containsKey('download_url'), isFalse);
    });

    test('omits a blank package id from the Ygg URI', () async {
      final adapter = _FakeAdapter(
        (_) async => _jsonResponse(
          _body(
            packages: <Map<String, Object?>>[_package(id: '')],
          ),
        ),
      );
      final repository = _repository(adapter);

      final release = await repository.check(100);

      expect(release, isNotNull);
      expect(release!.downloadUri.queryParameters.containsKey('package_id'), isFalse);
    });
  });

  group('metadata validation', () {
    test('rejects invalid or missing file sizes and version names', () async {
      final invalidPackages = <String, Map<String, Object?>>{
        'missing size': _package(size: null),
        'zero size': _package(size: 0),
        'negative size': _package(size: -1),
        'string size': _package(size: '1234'),
        'fractional size': _package(size: 1.5),
      };

      for (final entry in invalidPackages.entries) {
        final adapter = _FakeAdapter(
          (_) async => _jsonResponse(
            _body(packages: <Map<String, Object?>>[entry.value]),
          ),
        );
        final repository = _repository(adapter);

        await _expectFailure(
          repository.check(100),
          AppUpdateFailure.invalidResponse,
        );
      }

      for (final name in <Object?>['', '   ', null, 42]) {
        final adapter = _FakeAdapter(
          (_) async => _jsonResponse(
            _body(
              versionName: name,
              packages: <Map<String, Object?>>[_package()],
            ),
          ),
        );
        final repository = _repository(adapter);

        await _expectFailure(
          repository.check(100),
          AppUpdateFailure.invalidResponse,
        );
      }
    });
  });
}

Future<void> _expectFailure(
  Future<Object?> future,
  AppUpdateFailure expected,
) async {
  await expectLater(
    future,
    throwsA(
      isA<AppUpdateException>().having(
        (error) => error.failure,
        'failure',
        expected,
      ),
    ),
  );
}

YggUpdateRepository _repository(
  _FakeAdapter adapter, {
  UpdateTarget target = const UpdateTarget('android', 'arm64-v8a'),
  String buildNumber = '100',
}) {
  final dio = Dio();
  dio.httpClientAdapter = adapter;
  return YggUpdateRepository(
    dio: dio,
    target: target,
    packageInfoLoader: () async => PackageInfo(
      appName: 'OmniTune',
      packageName: YggUpdateRepository.appId,
      version: '1.0.307',
      buildNumber: buildNumber,
      buildSignature: '',
    ),
  );
}

Map<String, Object?> _body({
  Object? versionCode = 200,
  Object? versionName = '2.0.0',
  Object? appId = YggUpdateRepository.appId,
  Object? hasUpdate = true,
  List<Map<String, Object?>>? packages,
  String platform = 'android',
  String arch = 'arm64-v8a',
  String? packageId = 'pkg-android-arm64',
  Object? size = 1234,
  Object? sha = _sha,
  String? downloadUrl,
}) {
  final data = <String, Object?>{
    'app_id': appId,
    'latest_version_code': versionCode,
    'latest_version_name': versionName,
    'changelog': 'changelog',
    'has_update': hasUpdate,
    'packages':
        packages ??
        <Map<String, Object?>>[
          _package(
            id: packageId,
            platform: platform,
            arch: arch,
            size: size,
            sha: sha,
            downloadUrl: downloadUrl,
          ),
        ],
  };
  return <String, Object?>{'code': 0, 'data': data};
}

Map<String, Object?> _package({
  String? id = 'pkg-android-arm64',
  String platform = 'android',
  String arch = 'arm64-v8a',
  Object? size = 1234,
  Object? sha = _sha,
  String? downloadUrl,
}) {
  final package = <String, Object?>{
    'platform': platform,
    'arch': arch,
  };
  if (id != null) package['id'] = id;
  if (size != null) package['file_size'] = size;
  if (sha != null) package['file_sha256'] = sha;
  if (downloadUrl != null) package['download_url'] = downloadUrl;
  return package;
}

ResponseBody _jsonResponse(Object? body, [int statusCode = 200]) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
