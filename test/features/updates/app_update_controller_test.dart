import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/features/updates/application/app_update_controller.dart';
import 'package:music/features/updates/data/ygg_update_repository.dart';
import 'package:ota_update/ota_update.dart';

const _sha = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const _installed = AppVersion('1.0.307', 307);

Uri _trustedUri({int versionCode = 308, String platform = 'android'}) {
  return Uri.https('ygg.norns.cc.cd', '/api/v1/app/download', <String, String>{
    'app_id': YggUpdateRepository.appId,
    'version_code': '$versionCode',
    'channel': 'default',
    'platform': platform,
    'arch': 'arm64-v8a',
  });
}

AppUpdateRelease _release({
  int versionCode = 308,
  String platform = 'android',
  String? sha256 = _sha,
  Uri? downloadUri,
}) {
  return AppUpdateRelease(
    versionName: '1.0.308',
    versionCode: versionCode,
    changelog: 'changes',
    platform: platform,
    downloadUri: downloadUri ?? _trustedUri(versionCode: versionCode, platform: platform),
    fileSize: 1024,
    sha256: sha256,
  );
}

Future<void> _makeAvailable(_Harness harness, {AppUpdateRelease? release}) async {
  harness.repository.checkHandler = (_) async => release ?? _release();
  await harness.controller.check();
  expect(harness.controller.state.phase, AppUpdatePhase.available);
}

void main() {
  group('check', () {
    test('publishes available with installed version and release', () async {
      final harness = _harness();
      final release = _release();
      harness.repository.checkHandler = (_) async => release;

      await harness.controller.check();

      expect(harness.repository.versionCalls, 1);
      expect(harness.repository.checkCalls, <int>[_installed.code]);
      expect(harness.controller.state.phase, AppUpdatePhase.available);
      expect(harness.controller.state.installedVersion, _installed.name);
      expect(harness.controller.state.installedBuild, _installed.code);
      expect(harness.controller.state.release, same(release));
      expect(harness.controller.state.failure, isNull);
    });

    test('publishes upToDate when no release is offered', () async {
      final harness = _harness();

      await harness.controller.check();

      expect(harness.controller.state.phase, AppUpdatePhase.upToDate);
      expect(harness.controller.state.installedVersion, _installed.name);
      expect(harness.controller.state.installedBuild, _installed.code);
      expect(harness.controller.state.release, isNull);
      expect(harness.controller.state.failure, isNull);
    });

    test('maps noPackage to unsupported and other failures to error', () async {
      final harness = _harness();

      harness.repository.checkHandler = (_) async =>
          throw const AppUpdateException(AppUpdateFailure.noPackage);
      await harness.controller.check();
      expect(harness.controller.state.phase, AppUpdatePhase.unsupported);
      expect(harness.controller.state.failure, AppUpdateFailure.noPackage);
      expect(harness.controller.state.installedVersion, _installed.name);

      harness.repository.checkHandler = (_) async =>
          throw const AppUpdateException(AppUpdateFailure.network);
      await harness.controller.check();
      expect(harness.controller.state.phase, AppUpdatePhase.error);
      expect(harness.controller.state.failure, AppUpdateFailure.network);
      expect(harness.controller.state.installedVersion, _installed.name);

      harness.repository.checkHandler = (_) async => throw StateError('unexpected');
      await harness.controller.check();
      expect(harness.controller.state.phase, AppUpdatePhase.error);
      expect(harness.controller.state.failure, AppUpdateFailure.unknown);
    });

    test('duplicate check while checking is ignored', () async {
      final harness = _harness();
      final blocker = Completer<AppVersion>();
      harness.repository.versionHandler = () => blocker.future;

      final first = harness.controller.check();
      await pumpEventQueue();
      expect(harness.controller.state.phase, AppUpdatePhase.checking);
      expect(harness.controller.state.isBusy, isTrue);

      final second = harness.controller.check();
      await pumpEventQueue();
      expect(harness.repository.versionCalls, 1);

      blocker.complete(_installed);
      await Future.wait(<Future<void>>[first, second]);

      expect(harness.repository.versionCalls, 1);
      expect(harness.repository.checkCalls, <int>[_installed.code]);
      expect(harness.controller.state.phase, AppUpdatePhase.upToDate);
    });
  });

  group('download guards', () {
    test('duplicate download while downloading executes OTA only once', () async {
      final harness = _harness();
      await _makeAvailable(harness);

      final first = harness.controller.downloadAndInstall();
      await pumpEventQueue();
      expect(harness.controller.state.phase, AppUpdatePhase.downloading);
      expect(harness.otas, hasLength(1));

      final second = harness.controller.downloadAndInstall();
      await second;
      await first;

      expect(harness.otas, hasLength(1));
      expect(harness.otas.single.calls, hasLength(1));
      expect(harness.controller.state.phase, AppUpdatePhase.downloading);
    });

    test('check is ignored while downloading', () async {
      final harness = _harness();
      await _makeAvailable(harness);
      final callsBefore = harness.repository.versionCalls;

      await harness.controller.downloadAndInstall();
      await pumpEventQueue();

      await harness.controller.check();

      expect(harness.repository.versionCalls, callsBefore);
      expect(harness.controller.state.phase, AppUpdatePhase.downloading);
    });
  });

  group('progress', () {
    test('parses, clamps and rejects non-finite progress values', () async {
      final harness = _harness();
      await _makeAvailable(harness);
      await harness.controller.downloadAndInstall();
      await pumpEventQueue();
      final ota = harness.otas.single;

      ota.emit(OtaStatus.DOWNLOADING, '50');
      await pumpEventQueue();
      expect(harness.controller.state.phase, AppUpdatePhase.downloading);
      expect(harness.controller.state.progress, 0.5);

      ota.emit(OtaStatus.DOWNLOADING, '150');
      await pumpEventQueue();
      expect(harness.controller.state.progress, 1.0);

      ota.emit(OtaStatus.DOWNLOADING, '-25');
      await pumpEventQueue();
      expect(harness.controller.state.progress, 0.0);

      ota.emit(OtaStatus.DOWNLOADING, 'not-a-number');
      await pumpEventQueue();
      expect(harness.controller.state.progress, isNull);

      ota.emit(OtaStatus.DOWNLOADING, 'NaN');
      await pumpEventQueue();
      expect(harness.controller.state.progress, isNull);

      ota.emit(OtaStatus.DOWNLOADING, 'Infinity');
      await pumpEventQueue();
      expect(harness.controller.state.progress, isNull);
    });
  });

  group('checksum', () {
    test('rejects missing or malformed checksums before touching OTA', () async {
      for (final sha in <String?>[null, '', 'abc', 'A' * 63]) {
        final harness = _harness();
        await _makeAvailable(harness, release: _release(sha256: sha));

        await harness.controller.downloadAndInstall();
        await pumpEventQueue();

        expect(harness.controller.state.phase, AppUpdatePhase.error);
        expect(
          harness.controller.state.failure,
          AppUpdateFailure.checksumMissing,
        );
        expect(harness.otas, isEmpty);
      }
    });

    test('passes the checksum and trusted URL to the OTA plugin', () async {
      final harness = _harness();
      final release = _release();
      await _makeAvailable(harness, release: release);

      await harness.controller.downloadAndInstall();
      await pumpEventQueue();

      final call = harness.otas.single.calls.single;
      expect(call.url, release.downloadUri.toString());
      expect(call.url, 'https://ygg.norns.cc.cd/api/v1/app/download?app_id=com.norns.omnitune&version_code=308&channel=default&platform=android&arch=arm64-v8a');
      expect(call.destinationFilename, 'OmniTune-update.apk');
      expect(call.sha256checksum, _sha);
      expect(call.headers, <String, String>{'User-Agent': 'OmniTune-Updater'});
    });
  });

  group('OTA events', () {
    test('checksum, permission, install and download errors map correctly', () async {
      final cases = <(OtaStatus, AppUpdateFailure)>[
        (OtaStatus.CHECKSUM_ERROR, AppUpdateFailure.checksum),
        (OtaStatus.PERMISSION_NOT_GRANTED_ERROR, AppUpdateFailure.permission),
        (OtaStatus.INSTALLATION_ERROR, AppUpdateFailure.installation),
        (OtaStatus.DOWNLOAD_ERROR, AppUpdateFailure.download),
        (OtaStatus.ALREADY_RUNNING_ERROR, AppUpdateFailure.download),
        (OtaStatus.INTERNAL_ERROR, AppUpdateFailure.download),
      ];

      for (final (status, failure) in cases) {
        final harness = _harness();
        await _makeAvailable(harness);
        await harness.controller.downloadAndInstall();
        await pumpEventQueue();

        harness.otas.single.emit(status, 'error');
        await pumpEventQueue();

        expect(harness.controller.state.phase, AppUpdatePhase.error, reason: '$status');
        expect(harness.controller.state.failure, failure, reason: '$status');
      }
    });

    test('stream errors become download failures', () async {
      final harness = _harness();
      await _makeAvailable(harness);
      await harness.controller.downloadAndInstall();
      await pumpEventQueue();

      harness.otas.single.fail(StateError('stream failed'));
      await pumpEventQueue();

      expect(harness.controller.state.phase, AppUpdatePhase.error);
      expect(harness.controller.state.failure, AppUpdateFailure.download);
    });

    test('a stream ending mid-download becomes a download failure', () async {
      final harness = _harness();
      await _makeAvailable(harness);
      await harness.controller.downloadAndInstall();
      await pumpEventQueue();

      await harness.otas.single.close();
      await pumpEventQueue();

      expect(harness.controller.state.phase, AppUpdatePhase.error);
      expect(harness.controller.state.failure, AppUpdateFailure.download);
    });

    test('installer launch is awaitingInstall, never success', () async {
      final harness = _harness();
      await _makeAvailable(harness);
      await harness.controller.downloadAndInstall();
      await pumpEventQueue();
      final ota = harness.otas.single;

      ota.emit(OtaStatus.INSTALLING, null);
      await pumpEventQueue();
      expect(harness.controller.state.phase, AppUpdatePhase.awaitingInstall);
      expect(harness.controller.state.failure, isNull);

      ota.emit(OtaStatus.INSTALLATION_DONE, null);
      await pumpEventQueue();
      expect(harness.controller.state.phase, AppUpdatePhase.awaitingInstall);
      expect(harness.controller.state.failure, isNull);
      expect(harness.controller.state.phase, isNot(AppUpdatePhase.error));
      expect(harness.controller.state.phase, isNot(AppUpdatePhase.downloading));
    });

    test('canceled old stream events cannot regain state', () async {
      final harness = _harness();
      await _makeAvailable(harness);
      await harness.controller.downloadAndInstall();
      await pumpEventQueue();
      final ota = harness.otas.single;

      ota.emit(OtaStatus.DOWNLOADING, '30');
      await pumpEventQueue();
      expect(harness.controller.state.progress, 0.3);

      await harness.controller.cancel();
      expect(harness.controller.state.phase, AppUpdatePhase.canceled);
      expect(harness.controller.state.progress, isNull);
      expect(ota.cancelCalls, 1);
      final canceledState = harness.controller.state;

      ota.emit(OtaStatus.DOWNLOADING, '90');
      ota.emit(OtaStatus.INSTALLING, null);
      ota.fail(StateError('late error'));
      await pumpEventQueue();

      expect(harness.controller.state, same(canceledState));
      expect(harness.controller.state.phase, AppUpdatePhase.canceled);
    });

    test('retry after an error starts a fresh OTA operation', () async {
      final harness = _harness();
      await _makeAvailable(harness);

      await harness.controller.downloadAndInstall();
      await pumpEventQueue();
      harness.otas.single.emit(OtaStatus.DOWNLOAD_ERROR, 'offline');
      await pumpEventQueue();

      expect(harness.controller.state.phase, AppUpdatePhase.error);
      expect(harness.controller.state.failure, AppUpdateFailure.download);
      expect(harness.otas, hasLength(1));

      await harness.controller.downloadAndInstall();
      await pumpEventQueue();

      expect(harness.otas, hasLength(2));
      expect(harness.otas[1].calls, hasLength(1));
      expect(harness.controller.state.phase, AppUpdatePhase.downloading);

      harness.otas[1].emit(OtaStatus.INSTALLING, null);
      await pumpEventQueue();
      expect(harness.controller.state.phase, AppUpdatePhase.awaitingInstall);
    });
  });

  group('dispose safety', () {
    test('check completion after dispose is ignored', () async {
      final harness = _harness();
      final blocker = Completer<AppVersion>();
      harness.repository.versionHandler = () => blocker.future;

      final pending = harness.controller.check();
      await pumpEventQueue();
      expect(harness.controller.state.phase, AppUpdatePhase.checking);

      harness.disposeController();
      blocker.complete(_installed);
      await pending;

      expect(harness.repository.checkCalls, isEmpty);
    });

    test('download disposed before OTA setup never starts OTA', () async {
      final harness = _harness();
      await _makeAvailable(harness);

      final pending = harness.controller.downloadAndInstall();
      harness.disposeController();
      await pending;
      await pumpEventQueue();

      expect(harness.otas, isEmpty);
    });

    test('late OTA events after dispose are safely ignored', () async {
      final harness = _harness();
      await _makeAvailable(harness);
      await harness.controller.downloadAndInstall();
      await pumpEventQueue();
      final ota = harness.otas.single;

      harness.disposeController();
      expect(ota.cancelCalls, 1);
      ota.emit(OtaStatus.INSTALLING, null);
      ota.emit(OtaStatus.DOWNLOADING, '80');
      ota.fail(StateError('late'));
      await pumpEventQueue();
    });
  });

  group('desktop', () {
    test('opens the trusted Ygg URI and never invokes OTA', () async {
      final harness = _harness();
      final release = _release(platform: 'linux', sha256: null);
      await _makeAvailable(harness, release: release);

      await harness.controller.downloadAndInstall();
      await pumpEventQueue();

      expect(harness.opened, <Uri>[release.downloadUri]);
      expect(harness.opened.single.host, 'ygg.norns.cc.cd');
      expect(harness.otas, isEmpty);
      expect(harness.controller.state.phase, AppUpdatePhase.available);
      expect(harness.controller.state.failure, isNull);
      expect(harness.controller.state.release, same(release));
    });

    test('reports a download failure when the launch is refused', () async {
      final harness = _harness();
      harness.openResult = false;
      final release = _release(platform: 'linux', sha256: null);
      await _makeAvailable(harness, release: release);

      await harness.controller.downloadAndInstall();
      await pumpEventQueue();

      expect(harness.opened, <Uri>[release.downloadUri]);
      expect(harness.otas, isEmpty);
      expect(harness.controller.state.phase, AppUpdatePhase.error);
      expect(harness.controller.state.failure, AppUpdateFailure.download);
    });
  });
}

class _Harness {
  _Harness() {
    controller = AppUpdateController(
      repository: repository,
      otaFactory: () {
        final ota = _RecordingOta();
        otas.add(ota);
        return ota;
      },
      openDownload: (uri) async {
        opened.add(uri);
        return openResult;
      },
    );
  }

  final _FakeRepository repository = _FakeRepository();
  late final AppUpdateController controller;
  final List<_RecordingOta> otas = <_RecordingOta>[];
  final List<Uri> opened = <Uri>[];
  bool openResult = true;
  bool _disposed = false;

  void disposeController() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
  }

  void dispose() {
    disposeController();
    for (final ota in otas) {
      unawaited(ota.close());
    }
  }
}

_Harness _harness() {
  final harness = _Harness();
  addTearDown(harness.dispose);
  return harness;
}

class _FakeRepository extends YggUpdateRepository {
  _FakeRepository() : super(target: const UpdateTarget('android', 'arm64-v8a'));

  Future<AppVersion> Function()? versionHandler;
  Future<AppUpdateRelease?> Function(int code)? checkHandler;
  int versionCalls = 0;
  final List<int> checkCalls = <int>[];

  @override
  Future<AppVersion> installedVersion() {
    versionCalls++;
    final handler = versionHandler;
    return handler != null ? handler() : Future<AppVersion>.value(_installed);
  }

  @override
  Future<AppUpdateRelease?> check(int currentCode) {
    checkCalls.add(currentCode);
    final handler = checkHandler;
    return handler != null
        ? handler(currentCode)
        : Future<AppUpdateRelease?>.value();
  }
}

class _OtaCall {
  const _OtaCall({
    required this.url,
    required this.headers,
    required this.destinationFilename,
    required this.sha256checksum,
    required this.androidProviderAuthority,
    required this.usePackageInstaller,
  });

  final String url;
  final Map<String, String> headers;
  final String? destinationFilename;
  final String? sha256checksum;
  final String? androidProviderAuthority;
  final bool usePackageInstaller;
}

class _RecordingOta extends OtaUpdate {
  final StreamController<OtaEvent> _events =
      StreamController<OtaEvent>.broadcast();
  final List<_OtaCall> calls = <_OtaCall>[];
  int cancelCalls = 0;

  @override
  Stream<OtaEvent> execute(
    String url, {
    Map<String, String> headers = const <String, String>{},
    String? androidProviderAuthority,
    String? destinationFilename,
    String? sha256checksum,
    bool usePackageInstaller = false,
  }) {
    calls.add(
      _OtaCall(
        url: url,
        headers: Map<String, String>.unmodifiable(headers),
        destinationFilename: destinationFilename,
        sha256checksum: sha256checksum,
        androidProviderAuthority: androidProviderAuthority,
        usePackageInstaller: usePackageInstaller,
      ),
    );
    return _events.stream;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  void emit(OtaStatus status, String? value) {
    _events.add(OtaEvent(status, value));
  }

  void fail(Object error) {
    _events.addError(error);
  }

  Future<void> close() async {
    if (!_events.isClosed) {
      await _events.close();
    }
  }
}
