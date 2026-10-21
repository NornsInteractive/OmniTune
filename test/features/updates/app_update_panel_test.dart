import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:music/features/updates/application/app_update_controller.dart';
import 'package:music/features/updates/data/ygg_update_repository.dart';
import 'package:music/features/updates/presentation/app_update_panel.dart';

const _sha =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

const _installedVersion = '1.0.307';
const _installedBuild = 307;

AppUpdateRelease _release({
  String versionName = '1.0.308',
  int versionCode = 308,
  String platform = 'android',
  int fileSize = 5 * 1024 * 1024,
  String changelog = 'Bug fixes\nPerformance improvements',
  String? sha256 = _sha,
}) {
  return AppUpdateRelease(
    versionName: versionName,
    versionCode: versionCode,
    changelog: changelog,
    platform: platform,
    downloadUri: Uri.https('ygg.norns.cc.cd', '/api/v1/app/download'),
    fileSize: fileSize,
    sha256: sha256,
  );
}

AppUpdateState _state({
  required AppUpdatePhase phase,
  AppUpdateRelease? release,
  double? progress,
  AppUpdateFailure? failure,
}) {
  return AppUpdateState(
    phase: phase,
    installedVersion: _installedVersion,
    installedBuild: _installedBuild,
    release: release,
    progress: progress,
    failure: failure,
  );
}

class _FakeRepository extends YggUpdateRepository {
  _FakeRepository()
    : super(target: const UpdateTarget('android', 'arm64-v8a'));

  @override
  Future<AppVersion> installedVersion() async {
    return const AppVersion(_installedVersion, _installedBuild);
  }

  @override
  Future<AppUpdateRelease?> check(int currentCode) async {
    return _release();
  }
}

class _FakeAppUpdateController extends AppUpdateController {
  _FakeAppUpdateController(
    YggUpdateRepository repository,
    AppUpdateState initialState,
  ) : super(repository: repository) {
    state = initialState;
  }

  int checkCalls = 0;
  int downloadCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> check() async {
    checkCalls++;
  }

  @override
  Future<void> downloadAndInstall() async {
    downloadCalls++;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    state = AppUpdateState(
      phase: AppUpdatePhase.canceled,
      installedVersion: state.installedVersion,
      installedBuild: state.installedBuild,
      release: state.release,
    );
  }

  void emit(AppUpdateState value) {
    state = value;
  }
}

class _Harness {
  _Harness._(this.container, this.controller);

  factory _Harness.create(AppUpdateState initialState) {
    final repository = _FakeRepository();
    final controller = _FakeAppUpdateController(repository, initialState);
    final container = ProviderContainer(
      overrides: [
        appUpdateRepositoryProvider.overrideWithValue(repository),
        appUpdateControllerProvider.overrideWith((ref) => controller),
      ],
    );
    return _Harness._(container, controller);
  }

  final ProviderContainer container;
  final _FakeAppUpdateController controller;

  void dispose() {
    container.dispose();
  }
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _Harness harness, {
  required Size logicalSize,
  double textScale = 1.0,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(brightness: brightness, useMaterial3: true),
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: child!,
          );
        },
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(8),
            child: AppUpdatePanel(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<_Harness> _pumpFresh(
  WidgetTester tester, {
  required AppUpdateState initialState,
  required Size logicalSize,
  double textScale = 1.0,
  bool disableAnimations = false,
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
}) async {
  final harness = _Harness.create(initialState);
  addTearDown(harness.dispose);
  await _pumpPanel(
    tester,
    harness,
    logicalSize: logicalSize,
    textScale: textScale,
    disableAnimations: disableAnimations,
    locale: locale,
    brightness: brightness,
  );
  return harness;
}

AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(AppUpdatePanel)))!;
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('header and entry', () {
    testWidgets('shows installed version and performs one entry check', (
      tester,
    ) async {
      final harness = await _pumpFresh(
        tester,
        initialState: _state(phase: AppUpdatePhase.idle),
        logicalSize: const Size(390, 844),
      );
      final l10n = _l10n(tester);

      final expectedVersion = l10n.appUpdateVersionFormat(
        _installedVersion,
        _installedBuild,
      );
      expect(
        find.text('${l10n.appUpdateCurrentVersionLabel}: $expectedVersion'),
        findsOneWidget,
      );
      expect(find.text(l10n.appUpdateCheckAction), findsOneWidget);
      expect(harness.controller.checkCalls, 1);

      await tester.tap(find.text(l10n.appUpdateCheckAction));
      await tester.pump();

      expect(harness.controller.checkCalls, 2);
    });
  });

  group('available release', () {
    testWidgets('renders localized version, notes, size and install action', (
      tester,
    ) async {
      final release = _release();
      await _pumpFresh(
        tester,
        initialState: _state(
          phase: AppUpdatePhase.available,
          release: release,
        ),
        logicalSize: const Size(390, 844),
      );
      final l10n = _l10n(tester);

      final releaseVersion = l10n.appUpdateVersionFormat(
        release.versionName,
        release.versionCode,
      );
      expect(
        find.text('${l10n.appUpdateAvailableTitle}: $releaseVersion'),
        findsOneWidget,
      );
      expect(find.text(l10n.appUpdateReleaseNotesTitle), findsOneWidget);
      final notes = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(notes.data, release.changelog);
      expect(find.text(l10n.appUpdateSizeMB('5.0')), findsOneWidget);
      expect(
        find.text(l10n.appUpdateActionDownloadAndInstall),
        findsOneWidget,
      );
      expect(find.text(l10n.appUpdateActionDownloadLatest), findsNothing);
    });

    testWidgets('desktop release uses the download latest label', (
      tester,
    ) async {
      await _pumpFresh(
        tester,
        initialState: _state(
          phase: AppUpdatePhase.available,
          release: _release(platform: 'linux', fileSize: 1024, sha256: null),
        ),
        logicalSize: const Size(390, 844),
      );
      final l10n = _l10n(tester);

      expect(find.text(l10n.appUpdateActionDownloadLatest), findsOneWidget);
      expect(find.text(l10n.appUpdateActionDownloadAndInstall), findsNothing);
      expect(find.text(l10n.appUpdateSizeKB('1.0')), findsOneWidget);
    });
  });

  group('narrow layout', () {
    testWidgets('320dp with 2x text has no layout exceptions', (tester) async {
      final phases = <(String, AppUpdateState)>[
        (
          'available',
          _state(phase: AppUpdatePhase.available, release: _release()),
        ),
        (
          'error',
          _state(
            phase: AppUpdatePhase.error,
            failure: AppUpdateFailure.checksum,
            release: _release(),
          ),
        ),
        (
          'awaitingInstall',
          _state(phase: AppUpdatePhase.awaitingInstall, release: _release()),
        ),
        (
          'downloading',
          _state(
            phase: AppUpdatePhase.downloading,
            release: _release(),
            progress: 0.42,
          ),
        ),
      ];

      for (final (name, state) in phases) {
        await _pumpFresh(
          tester,
          initialState: state,
          logicalSize: const Size(320, 568),
          textScale: 2.0,
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          find.byType(AppUpdatePanel),
          findsOneWidget,
          reason: '$name should remain mounted',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '$name must not throw a layout exception at 320dp/2x text',
        );
      }
    });
  });

  group('download flow', () {
    testWidgets('download action, progress and cancel route correctly', (
      tester,
    ) async {
      final release = _release();
      final harness = await _pumpFresh(
        tester,
        initialState: _state(
          phase: AppUpdatePhase.available,
          release: release,
        ),
        logicalSize: const Size(390, 844),
      );
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.appUpdateActionDownloadAndInstall));
      await tester.pump();
      expect(harness.controller.downloadCalls, 1);

      harness.controller.emit(
        _state(
          phase: AppUpdatePhase.downloading,
          release: release,
          progress: 0.42,
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text(l10n.appUpdateDownloadingLabel), findsOneWidget);
      expect(find.text(l10n.appUpdateProgressPercent(42)), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, closeTo(0.42, 0.001));

      await tester.tap(find.text(l10n.appUpdateCancelAction));
      await tester.pump(const Duration(milliseconds: 250));

      expect(harness.controller.cancelCalls, 1);
      expect(find.text(l10n.appUpdateCanceledStatus), findsOneWidget);
    });
  });

  group('failure states', () {
    testWidgets('checksum failure shows mismatch error with retry actions', (
      tester,
    ) async {
      final harness = await _pumpFresh(
        tester,
        initialState: _state(
          phase: AppUpdatePhase.error,
          failure: AppUpdateFailure.checksum,
          release: _release(),
        ),
        logicalSize: const Size(390, 844),
      );
      final l10n = _l10n(tester);
      final checksAfterEntry = harness.controller.checkCalls;

      expect(
        find.text(l10n.appUpdateErrorChecksumMismatch),
        findsOneWidget,
      );
      expect(
        find.text(l10n.appUpdateErrorChecksumMissing),
        findsNothing,
      );
      expect(find.text(l10n.appUpdateUpToDateStatus), findsNothing);
      expect(find.text(l10n.appUpdateCheckAgainAction), findsOneWidget);
      expect(find.text(l10n.appUpdateRetryDownloadAction), findsOneWidget);

      await tester.tap(find.text(l10n.appUpdateRetryDownloadAction));
      await tester.pump();
      expect(harness.controller.downloadCalls, 1);

      await tester.tap(find.text(l10n.appUpdateCheckAgainAction));
      await tester.pump();
      expect(harness.controller.checkCalls, checksAfterEntry + 1);
      expect(find.text(l10n.appUpdateUpToDateStatus), findsNothing);
    });

    testWidgets('awaiting install requests system confirmation, not success', (
      tester,
    ) async {
      final harness = await _pumpFresh(
        tester,
        initialState: _state(
          phase: AppUpdatePhase.awaitingInstall,
          release: _release(),
        ),
        logicalSize: const Size(390, 844),
      );
      final l10n = _l10n(tester);

      expect(
        find.text(l10n.appUpdateAwaitingInstallTitle),
        findsOneWidget,
      );
      expect(
        find.text(l10n.appUpdateAwaitingInstallDescription),
        findsOneWidget,
      );
      expect(find.text(l10n.appUpdateRetryDownloadAction), findsOneWidget);
      expect(find.text(l10n.appUpdateUpToDateStatus), findsNothing);
      expect(harness.controller.checkCalls, 0);
      expect(harness.controller.downloadCalls, 0);

      await tester.tap(find.text(l10n.appUpdateRetryDownloadAction));
      await tester.pump();

      expect(harness.controller.downloadCalls, 1);
      expect(find.text(l10n.appUpdateUpToDateStatus), findsNothing);
    });
  });

  group('reentry', () {
    testWidgets('downloading and awaiting install do not check or reset', (
      tester,
    ) async {
      for (final phase in <AppUpdatePhase>[
        AppUpdatePhase.downloading,
        AppUpdatePhase.awaitingInstall,
      ]) {
        final release = _release();
        final harness = _Harness.create(
          _state(
            phase: phase,
            release: release,
            progress: phase == AppUpdatePhase.downloading ? 0.42 : null,
          ),
        );
        addTearDown(harness.dispose);

        await _pumpPanel(
          tester,
          harness,
          logicalSize: const Size(390, 844),
        );
        expect(
          harness.controller.checkCalls,
          0,
          reason: 'entering $phase must not trigger a check',
        );
        final stateBefore = harness.controller.state;

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        await _pumpPanel(
          tester,
          harness,
          logicalSize: const Size(390, 844),
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          harness.controller.checkCalls,
          0,
          reason: 're-entering $phase must not trigger a check',
        );
        expect(harness.controller.state.phase, phase);
        expect(harness.controller.state.release, same(release));
        expect(harness.controller.state.progress, stateBefore.progress);
      }
    });
  });

  group('reduced motion', () {
    for (final locale in <Locale>[const Locale('en'), const Locale('zh')]) {
      testWidgets(
        '${locale.languageCode} dark theme uses static progress indicators',
        (tester) async {
          final looping = await _pumpFresh(
            tester,
            initialState: _state(phase: AppUpdatePhase.checking),
            logicalSize: const Size(390, 844),
            disableAnimations: true,
            locale: locale,
            brightness: Brightness.dark,
          );
          final l10n = _l10n(tester);

          expect(
            find.text(l10n.appUpdateCheckingStatus),
            findsOneWidget,
          );
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
          expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
          final tickerMode = tester.widget<TickerMode>(
            find
                .descendant(
                  of: find.byType(AppUpdatePanel),
                  matching: find.byType(TickerMode),
                )
                .first,
          );
          expect(tickerMode.enabled, isFalse);
          await tester.pump(const Duration(milliseconds: 300));
          expect(looping.controller.checkCalls, 0);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();

          await _pumpFresh(
            tester,
            initialState: _state(
              phase: AppUpdatePhase.downloading,
              release: _release(),
            ),
            logicalSize: const Size(390, 844),
            disableAnimations: true,
            locale: locale,
            brightness: Brightness.dark,
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text(l10n.appUpdateDownloadingLabel), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          final progress = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(progress.value, 0.0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
