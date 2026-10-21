import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/ygg_update_repository.dart';
import '../domain/app_update.dart';

export '../domain/app_update.dart';

enum AppUpdatePhase {
  idle,
  checking,
  available,
  upToDate,
  downloading,
  awaitingInstall,
  canceled,
  unsupported,
  error,
}

class AppUpdateState {
  const AppUpdateState({
    this.phase = AppUpdatePhase.idle,
    this.installedVersion,
    this.installedBuild,
    this.release,
    this.progress,
    this.failure,
  });
  final AppUpdatePhase phase;
  final String? installedVersion;
  final int? installedBuild;
  final AppUpdateRelease? release;
  final double? progress;
  final AppUpdateFailure? failure;
  bool get isBusy =>
      phase == AppUpdatePhase.checking || phase == AppUpdatePhase.downloading;
}

final appUpdateRepositoryProvider = Provider<YggUpdateRepository>(
  (ref) => YggUpdateRepository(),
);
final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>(
      (ref) => AppUpdateController(
        repository: ref.watch(appUpdateRepositoryProvider),
      ),
    );

class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController({
    required YggUpdateRepository repository,
    OtaUpdate Function()? otaFactory,
    Future<bool> Function(Uri)? openDownload,
  }) : _repository = repository,
       _otaFactory = otaFactory ?? OtaUpdate.new,
       _openDownload =
           openDownload ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       super(const AppUpdateState());

  final YggUpdateRepository _repository;
  final OtaUpdate Function() _otaFactory;
  final Future<bool> Function(Uri) _openDownload;
  StreamSubscription<OtaEvent>? _subscription;
  OtaUpdate? _ota;
  int _operation = 0;

  void _phase(
    AppUpdatePhase phase, {
    double? progress,
    AppUpdateFailure? failure,
  }) {
    state = AppUpdateState(
      phase: phase,
      installedVersion: state.installedVersion,
      installedBuild: state.installedBuild,
      release: state.release,
      progress: progress,
      failure: failure,
    );
  }

  Future<void> check() async {
    if (state.isBusy) return;
    final operation = ++_operation;
    state = AppUpdateState(
      phase: AppUpdatePhase.checking,
      installedVersion: state.installedVersion,
      installedBuild: state.installedBuild,
    );
    try {
      final version = await _repository.installedVersion();
      if (!mounted || operation != _operation) return;
      state = AppUpdateState(
        phase: AppUpdatePhase.checking,
        installedVersion: version.name,
        installedBuild: version.code,
      );
      final release = await _repository.check(version.code);
      if (!mounted || operation != _operation) return;
      state = AppUpdateState(
        phase: release == null
            ? AppUpdatePhase.upToDate
            : AppUpdatePhase.available,
        installedVersion: version.name,
        installedBuild: version.code,
        release: release,
      );
    } catch (error) {
      if (!mounted || operation != _operation) return;
      final failure = error is AppUpdateException
          ? error.failure
          : AppUpdateFailure.unknown;
      _phase(
        failure == AppUpdateFailure.noPackage
            ? AppUpdatePhase.unsupported
            : AppUpdatePhase.error,
        failure: failure,
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final release = state.release;
    if (state.isBusy || release == null) return;
    final operation = ++_operation;
    _phase(AppUpdatePhase.downloading);
    try {
      if (release.platform != 'android') {
        final opened = await _openDownload(release.downloadUri);
        if (!mounted || operation != _operation) return;
        _phase(
          opened ? AppUpdatePhase.available : AppUpdatePhase.error,
          failure: opened ? null : AppUpdateFailure.download,
        );
        return;
      }
      if (release.sha256 == null ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(release.sha256!)) {
        throw const AppUpdateException(AppUpdateFailure.checksumMissing);
      }
      await _subscription?.cancel();
      if (!mounted || operation != _operation) return;
      final ota = _otaFactory();
      _ota = ota;
      _subscription = ota
          .execute(
            release.downloadUri.toString(),
            // Reuse one APK slot instead of retaining every downloaded version.
            destinationFilename: 'OmniTune-update.apk',
            sha256checksum: release.sha256,
            headers: {'User-Agent': 'OmniTune-Updater'},
          )
          .listen(
            (event) {
              if (!mounted || operation != _operation) return;
              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  final percent = double.tryParse(event.value ?? '');
                  _phase(
                    AppUpdatePhase.downloading,
                    progress: percent != null && percent.isFinite
                        ? (percent / 100).clamp(0.0, 1.0)
                        : null,
                  );
                case OtaStatus.INSTALLING:
                case OtaStatus.INSTALLATION_DONE:
                  // Launching the installer is not proof that installation succeeded.
                  _phase(AppUpdatePhase.awaitingInstall);
                case OtaStatus.CANCELED:
                  _phase(AppUpdatePhase.canceled);
                case OtaStatus.CHECKSUM_ERROR:
                  _phase(
                    AppUpdatePhase.error,
                    failure: AppUpdateFailure.checksum,
                  );
                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                  _phase(
                    AppUpdatePhase.error,
                    failure: AppUpdateFailure.permission,
                  );
                case OtaStatus.INSTALLATION_ERROR:
                  _phase(
                    AppUpdatePhase.error,
                    failure: AppUpdateFailure.installation,
                  );
                default:
                  _phase(
                    AppUpdatePhase.error,
                    failure: AppUpdateFailure.download,
                  );
              }
            },
            onError: (_) {
              if (mounted && operation == _operation) {
                _phase(
                  AppUpdatePhase.error,
                  failure: AppUpdateFailure.download,
                );
              }
            },
            onDone: () {
              if (mounted &&
                  operation == _operation &&
                  state.phase == AppUpdatePhase.downloading) {
                _phase(
                  AppUpdatePhase.error,
                  failure: AppUpdateFailure.download,
                );
              }
            },
          );
    } catch (error) {
      if (mounted && operation == _operation) {
        _phase(
          AppUpdatePhase.error,
          failure: error is AppUpdateException
              ? error.failure
              : AppUpdateFailure.download,
        );
      }
    }
  }

  Future<void> cancel() async {
    if (state.phase != AppUpdatePhase.downloading) return;
    ++_operation;
    _phase(AppUpdatePhase.canceled);
    await _ota?.cancel();
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    ++_operation;
    if (state.phase == AppUpdatePhase.downloading) unawaited(_ota?.cancel());
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
