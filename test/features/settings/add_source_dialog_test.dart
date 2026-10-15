import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/app/app.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/models/app_preferences.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/router/app_router.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/core/storage/source_profile_repository.dart';
import 'package:music/core/widgets/glacier_dialog.dart';
import 'package:music/features/library/application/library_catalog_controller.dart';
import 'package:music/features/library/application/library_controller.dart';
import 'package:music/features/library/presentation/albums_page.dart';
import 'package:music/features/library/presentation/folder_artwork_provider.dart';
import 'package:music/features/player/application/player_controller.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';
import 'package:music/features/player/presentation/widgets/mini_player.dart';
import 'package:music/features/sources/application/music_source_registry.dart';
import 'package:music/features/sources/domain/music_source.dart';

const Key _dialogKey = Key('add-source-dialog');
const Key _closeKey = Key('add-source-close');
const Key _backKey = Key('add-source-back');
const Key _typeStepKey = Key('source-type-step');
const Key _configStepKey = Key('source-config-step');

PlayableTrack _sampleTrack() => PlayableTrack(
  id: 'track-1',
  sourceId: 'source-1',
  title: 'Starfall',
  artistName: 'Stellar',
  albumTitle: 'Cosmos',
  sourceName: 'WebDAV Source',
  remotePath: '/music/starfall.flac',
  audioSource: AudioSource.uri(Uri.parse('https://example.com/audio.mp3')),
);

PlayerViewState _sampleState() => PlayerViewState(
  currentTrack: _sampleTrack(),
  isPlaying: true,
  processingState: ProcessingState.ready,
  position: Duration.zero,
  bufferedPosition: const Duration(seconds: 45),
  duration: const Duration(minutes: 3),
  playlist: const [],
  currentIndex: -1,
  playbackMode: PlayerPlaybackMode.list,
  lyrics: const [],
  lyricsSource: PlayerLyricsSource.none,
  cacheSegments: const [],
);

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initialState);

  final PlayerViewState _initialState;
  int playPauseCallCount = 0;

  @override
  PlayerViewState build() => _initialState;

  @override
  Future<void> togglePlayPause() async {
    playPauseCallCount++;
  }
}

class _CatalogController extends LibraryCatalogController {
  final List<String> rescans = <String>[];

  @override
  Future<LibraryCatalogState> build() async {
    return const LibraryCatalogState();
  }

  @override
  Future<void> rescanSource(String sourceId) async {
    rescans.add(sourceId);
  }
}

class _Harness {
  _Harness({
    required this.container,
    required this.repository,
    required this.catalog,
    required this.playerController,
    required this.prefs,
  });

  final ProviderContainer container;
  final _SourceRepository repository;
  final _CatalogController catalog;
  final _FakePlayerController playerController;
  final LibraryPreferences prefs;
}

class _SourceRepository implements SourceProfileRepository {
  _SourceRepository({
    List<SourceProfile> profiles = const [],
    String? activeSourceId,
  }) : _profiles = List.of(profiles),
       _activeSourceId = activeSourceId;

  List<SourceProfile> _profiles;
  String? _activeSourceId;

  Completer<void>? saveProfilesBlocker;
  Completer<void>? saveActiveSourceIdBlocker;
  Object? saveProfilesError;
  Object? saveActiveSourceIdError;

  final Completer<void> saveProfilesStarted = Completer<void>();
  final Completer<void> saveActiveSourceIdStarted = Completer<void>();

  final List<List<SourceProfile>> saveProfilesCalls = <List<SourceProfile>>[];
  final List<String?> saveActiveSourceIdCalls = <String?>[];

  List<SourceProfile> get storedProfiles => List.of(_profiles);
  String? get activeSourceId => _activeSourceId;

  @override
  Future<String?> loadActiveSourceId() async => _activeSourceId;

  @override
  Future<List<SourceProfile>> loadProfiles() async => List.of(_profiles);

  @override
  Future<void> saveActiveSourceId(String? sourceId) async {
    saveActiveSourceIdCalls.add(sourceId);
    if (!saveActiveSourceIdStarted.isCompleted) {
      saveActiveSourceIdStarted.complete();
    }
    final blocker = saveActiveSourceIdBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    final error = saveActiveSourceIdError;
    if (error != null) {
      throw error;
    }
    _activeSourceId = sourceId;
  }

  @override
  Future<void> saveProfiles(List<SourceProfile> profiles) async {
    saveProfilesCalls.add(List.of(profiles));
    if (!saveProfilesStarted.isCompleted) {
      saveProfilesStarted.complete();
    }
    final blocker = saveProfilesBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    final error = saveProfilesError;
    if (error != null) {
      throw error;
    }
    _profiles = List.of(profiles);
  }
}

class _ControlledSource implements MusicSource {
  _ControlledSource(this.profile);

  @override
  final SourceProfile profile;

  Completer<void>? connectCompleter;
  final Completer<void> connectStarted = Completer<void>();

  Completer<void>? listCompleter;
  final Completer<void> listStarted = Completer<void>();

  int connectCalls = 0;
  int listCalls = 0;

  @override
  Future<void> connect() async {
    connectCalls++;
    if (!connectStarted.isCompleted) connectStarted.complete();
    final blocker = connectCompleter;
    if (blocker != null) await blocker.future;
  }

  @override
  Future<DirectoryListing> listFiles(String path) async {
    listCalls++;
    if (!listStarted.isCompleted) listStarted.complete();
    final blocker = listCompleter;
    if (blocker != null) await blocker.future;
    return const DirectoryListing(entries: <RemoteEntry>[]);
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) {
    throw UnimplementedError();
  }

  @override
  Future<String?> readTextFile(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> readBinaryFile(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> readBinaryFileHead(String path, {int length = 131072}) {
    throw UnimplementedError();
  }
}

class _QueueMusicSourceFactory implements MusicSourceFactory {
  _QueueMusicSourceFactory(this._sources);

  final List<MusicSource> _sources;
  int _index = 0;

  @override
  SourceProtocol get protocol => SourceProtocol.webdav;

  @override
  MusicSource create(SourceProfile profile) {
    return _sources[_index++];
  }
}

class _StubLibraryController extends LibraryController {
  @override
  Future<LibraryViewState> build() async {
    return const LibraryViewState(
      sources: <SourceProfile>[],
      selectedSource: null,
      currentPath: '/',
      entries: <RemoteEntry>[],
    );
  }
}

class _SyncAppSettingsController extends AppSettingsController {
  _SyncAppSettingsController(this._preferences);

  final LibraryPreferences _preferences;

  @override
  Future<LibraryPreferences> build() {
    return SynchronousFuture<LibraryPreferences>(_preferences);
  }
}

class _PrefsRepo implements LibraryPreferencesRepository {
  _PrefsRepo(this._preferences);

  final LibraryPreferences _preferences;

  @override
  Future<LibraryPreferences> load() async => _preferences;

  @override
  Future<void> save(LibraryPreferences preferences) async {}

  @override
  Future<LibraryPreferences> update(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async {
    return transform(_preferences);
  }
}

Future<_Harness> _pumpHarness(
  WidgetTester tester, {
  required Size size,
  LibraryPreferences? prefs,
  List<MusicSourceFactory> factories = const [],
  _SourceRepository? repository,
  _CatalogController? catalog,
  _FakePlayerController? playerController,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  final repositoryValue = repository ?? _SourceRepository();
  final catalogValue = catalog ?? _CatalogController();
  final playerValue = playerController ?? _FakePlayerController(_sampleState());
  final prefsValue =
      prefs ??
      const LibraryPreferences(localePreference: AppLocalePreference.english);

  final container = ProviderContainer(
    overrides: [
      sourceProfileRepositoryProvider.overrideWithValue(repositoryValue),
      libraryPreferencesRepositoryProvider.overrideWithValue(
        _PrefsRepo(prefsValue),
      ),
      appSettingsControllerProvider.overrideWith(
        () => _SyncAppSettingsController(prefsValue),
      ),
      playerControllerProvider.overrideWith(() => playerValue),
      libraryCatalogControllerProvider.overrideWith(() => catalogValue),
      folderArtworkProvider.overrideWith((ref, request) async => null),
      libraryControllerProvider.overrideWith(_StubLibraryController.new),
      musicSourceRegistryProvider.overrideWithValue(
        MusicSourceRegistry(factories),
      ),
    ],
  );

  addTearDown(() {
    container.dispose();
    tester.view.reset();
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MusicApp()),
  );
  await tester.pumpAndSettle();

  return _Harness(
    container: container,
    repository: repositoryValue,
    catalog: catalogValue,
    playerController: playerValue,
    prefs: prefsValue,
  );
}

Finder _formField(String labelText) {
  final labelFinder = find.text(labelText);
  expect(labelFinder, findsOneWidget);
  final fieldFinder = find.ancestor(
    of: labelFinder,
    matching: find.byType(TextFormField),
  );
  expect(fieldFinder, findsOneWidget);
  return fieldFinder;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int max = 100,
}) async {
  for (var i = 0; i < max; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  throw TestFailure('Condition was not met within $max pump iterations.');
}

void _expectVisibleDialogPanelFits(WidgetTester tester) {
  final panelRect = tester.getRect(
    find
        .descendant(of: find.byKey(_dialogKey), matching: find.byType(Material))
        .first,
  );
  final view = tester.view;
  final dpr = view.devicePixelRatio;
  final logicalSize = view.physicalSize / dpr;
  final padding = view.padding;
  final insets = view.viewInsets;
  final availableHeight =
      logicalSize.height -
      padding.top / dpr -
      padding.bottom / dpr -
      insets.bottom / dpr;
  final maxWidth = math.min(
    640.0,
    logicalSize.width - padding.left / dpr - padding.right / dpr - 32.0,
  );
  expect(
    panelRect.height,
    lessThanOrEqualTo(0.85 * availableHeight + 1.0),
    reason:
        'visible dialog panel height must stay within 85% of available height',
  );
  expect(
    panelRect.width,
    lessThanOrEqualTo(maxWidth + 1.0),
    reason: 'visible dialog panel width must stay within capped maxWidth',
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('add source root dialog', () {
    testWidgets(
      'root overlay blocks playback and navigation at barrier coordinates',
      (tester) async {
        final harness = await _pumpHarness(tester, size: const Size(390, 844));
        final router = harness.container.read(appRouterProvider);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        )!;
        final routeBefore = router.routeInformationProvider.value.uri
            .toString();
        final playPauseBefore = harness.playerController.playPauseCallCount;

        final miniPlayPauseFinder = find.descendant(
          of: find.byType(MiniPlayer),
          matching: find.byIcon(Icons.pause_rounded),
        );
        expect(miniPlayPauseFinder, findsOneWidget);
        final miniPlayPauseCenter = tester.getCenter(miniPlayPauseFinder);

        final navTargetFinder = find.byIcon(Icons.library_music_outlined);
        expect(navTargetFinder, findsOneWidget);
        final navTargetCenter = tester.getCenter(navTargetFinder);

        await tester.tap(find.byIcon(Icons.add_link_rounded).first);
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsOneWidget);
        final routeAfterOpen = router.routeInformationProvider.value.uri
            .toString();
        expect(routeAfterOpen, routeBefore);

        final barrierFinder = find.byType(ModalBarrier);
        expect(barrierFinder, findsWidgets);
        final barrierRect = tester.getRect(barrierFinder.first);
        final screenSize =
            tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(barrierRect.width, closeTo(screenSize.width, 1.0));
        expect(barrierRect.height, closeTo(screenSize.height, 1.0));
        final dialogPanelRect = tester.getRect(
          find
              .descendant(
                of: find.byKey(_dialogKey),
                matching: find.byType(Material),
              )
              .first,
        );

        await tester.tapAt(miniPlayPauseCenter);
        await tester.pump();
        expect(harness.playerController.playPauseCallCount, playPauseBefore);
        expect(find.byKey(_dialogKey), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          routeAfterOpen,
        );

        await tester.tapAt(navTargetCenter);
        await tester.pump();
        expect(find.byKey(_dialogKey), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          routeAfterOpen,
        );

        const outsideDialogPoint = Offset(8.0, 8.0);
        expect(dialogPanelRect.contains(outsideDialogPoint), isFalse);
        await tester.tapAt(outsideDialogPoint);
        await tester.pump();
        expect(find.byKey(_dialogKey), findsOneWidget);

        await tester.tap(find.byKey(_closeKey).first);
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsNothing);

        await tester.tap(find.byIcon(Icons.add_link_rounded).first);
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsOneWidget);

        await tester.tap(find.text(l10n.webdavSourceTypeTitle));
        await tester.pumpAndSettle();
        expect(find.byKey(_configStepKey), findsAtLeastNWidgets(1));
        expect(find.byKey(_dialogKey), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          routeAfterOpen,
        );

        await tester.tap(find.byKey(_closeKey).first);
        await tester.pumpAndSettle();
        expect(find.byKey(_dialogKey), findsNothing);
      },
    );

    testWidgets('config back key returns chooser and preserves pending text', (
      tester,
    ) async {
      await _pumpHarness(tester, size: const Size(390, 844));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();

      await tester.enterText(_formField(l10n.sourceNameLabel), 'dirty-name');
      await tester.pump();
      await tester.tap(find.byKey(_backKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.continueEditingAction), findsOneWidget);
      await tester.tap(find.text(l10n.continueEditingAction));
      await tester.pumpAndSettle();
      expect(find.byKey(_configStepKey), findsAtLeastNWidgets(1));
      expect(find.text('dirty-name'), findsOneWidget);

      await tester.tap(find.byKey(_backKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.discardChangesAction));
      await tester.pumpAndSettle();
      expect(find.byKey(_typeStepKey), findsOneWidget);

      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_backKey));
      await tester.pumpAndSettle();
      expect(find.byKey(_typeStepKey), findsOneWidget);
      expect(find.byKey(_dialogKey), findsOneWidget);
    });

    testWidgets('dirty X exits the whole dialog after confirmation', (
      tester,
    ) async {
      await _pumpHarness(tester, size: const Size(390, 844));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        _formField(l10n.serverUrlLabel),
        'http://example.com',
      );
      await tester.pump();

      await tester.tap(find.byKey(_closeKey).first);
      await tester.pumpAndSettle();
      expect(find.text(l10n.continueEditingAction), findsOneWidget);
      expect(find.text(l10n.discardChangesAction), findsOneWidget);
      await tester.tap(find.text(l10n.discardChangesAction));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
    });

    testWidgets('dirty Escape exits the whole dialog after confirmation', (
      tester,
    ) async {
      await _pumpHarness(tester, size: const Size(390, 844));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        _formField(l10n.serverUrlLabel),
        'http://example.com',
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _pumpUntil(
        tester,
        () => find.text(l10n.continueEditingAction).evaluate().isNotEmpty,
      );
      expect(find.text(l10n.continueEditingAction), findsOneWidget);
      expect(find.text(l10n.discardChangesAction), findsOneWidget);
      await tester.tap(find.text(l10n.discardChangesAction));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
    });

    testWidgets('dirty Cancel exits the whole dialog after confirmation', (
      tester,
    ) async {
      await _pumpHarness(tester, size: const Size(390, 844));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        _formField(l10n.serverUrlLabel),
        'http://example.com',
      );
      await tester.pump();

      final dirtyCancelFinder = find.text(
        MaterialLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        ).cancelButtonLabel,
      );
      await tester.ensureVisible(dirtyCancelFinder);
      await tester.pump();
      await tester.tap(dirtyCancelFinder);
      await tester.pumpAndSettle();
      expect(find.text(l10n.continueEditingAction), findsOneWidget);
      expect(find.text(l10n.discardChangesAction), findsOneWidget);
      await tester.tap(find.text(l10n.discardChangesAction));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
    });

    testWidgets('dirty system back confirms then chooser and second exits', (
      tester,
    ) async {
      await _pumpHarness(tester, size: const Size(390, 844));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        _formField(l10n.serverUrlLabel),
        'http://example.com',
      );
      await tester.pump();

      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();
      expect(find.text(l10n.continueEditingAction), findsOneWidget);
      expect(find.text(l10n.discardChangesAction), findsOneWidget);
      await tester.tap(find.text(l10n.discardChangesAction));
      await tester.pumpAndSettle();
      expect(find.byKey(_typeStepKey), findsOneWidget);
      expect(find.byKey(_dialogKey), findsOneWidget);

      final secondHandled = await tester.binding.handlePopRoute();
      expect(secondHandled, isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
    });

    testWidgets('rapid second system back exits clean config without waiting', (
      tester,
    ) async {
      await _pumpHarness(tester, size: const Size(390, 844));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      expect(find.byKey(_configStepKey), findsAtLeastNWidgets(1));
      expect(find.byKey(_dialogKey), findsOneWidget);

      final firstHandled = await tester.binding.handlePopRoute();
      expect(firstHandled, isTrue);
      await tester.pump();
      expect(find.byKey(_dialogKey), findsOneWidget);

      final secondHandled = await tester.binding.handlePopRoute();
      expect(secondHandled, isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
    });

    testWidgets(
      'preflight footer cancel discards and releases without writes',
      (tester) async {
        final source = _ControlledSource(
          SourceProfile(
            id: 'preflight-source',
            name: 'Preflight',
            protocol: SourceProtocol.webdav,
            baseUrl: 'http://example.com',
            username: 'user',
            password: 'pass',
            rootPath: '/',
          ),
        );
        source.connectCompleter = Completer<void>();
        addTearDown(() {
          if (!source.connectCompleter!.isCompleted) {
            source.connectCompleter!.complete();
          }
        });
        final repository = _SourceRepository();
        final catalog = _CatalogController();
        await _pumpHarness(
          tester,
          size: const Size(390, 844),
          repository: repository,
          catalog: catalog,
          factories: [
            _QueueMusicSourceFactory([source]),
          ],
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        )!;

        await tester.tap(find.byIcon(Icons.add_link_rounded).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.webdavSourceTypeTitle));
        await tester.pumpAndSettle();
        await tester.enterText(
          _formField(l10n.serverUrlLabel),
          'http://example.com/webdav',
        );
        await tester.pump();

        await tester.ensureVisible(find.text(l10n.saveSourceAction));
        await tester.pump();
        await tester.tap(find.text(l10n.saveSourceAction));
        await _pumpUntil(tester, () => source.connectStarted.isCompleted);
        expect(source.connectStarted.isCompleted, isTrue);

        final busyConfigFields = find.descendant(
          of: find.byKey(_configStepKey),
          matching: find.byType(TextFormField),
        );
        expect(busyConfigFields, findsWidgets);
        for (final element in busyConfigFields.evaluate()) {
          expect((element.widget as TextFormField).enabled, isFalse);
        }

        final footerCancelFinder = find.text(
          MaterialLocalizations.of(
            tester.element(find.byType(AlbumsPage)),
          ).cancelButtonLabel,
        );
        expect(footerCancelFinder, findsOneWidget);
        final footerCancelButton = tester.widget<TextButton>(
          find
              .ancestor(
                of: footerCancelFinder,
                matching: find.byType(TextButton),
              )
              .first,
        );
        expect(footerCancelButton.onPressed, isNotNull);
        await tester.ensureVisible(footerCancelFinder);
        await tester.pump();
        await tester.tap(footerCancelFinder);
        await _pumpUntil(
          tester,
          () => find.text(l10n.continueEditingAction).evaluate().isNotEmpty,
        );
        expect(find.text(l10n.continueEditingAction), findsOneWidget);
        expect(find.text(l10n.discardChangesAction), findsOneWidget);
        await tester.tap(find.text(l10n.discardChangesAction));
        await _pumpUntil(
          tester,
          () => find.byKey(_dialogKey).evaluate().isEmpty,
        );
        expect(find.byKey(_dialogKey), findsNothing);

        if (!source.connectCompleter!.isCompleted) {
          source.connectCompleter!.complete();
        }
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byKey(_dialogKey), findsNothing);
        expect(repository.saveProfilesCalls, isEmpty);
        expect(repository.saveActiveSourceIdCalls, isEmpty);
        expect(catalog.rescans, isEmpty);
        expect(find.text(l10n.sourceSavedSuccess), findsNothing);
        expect(find.text(l10n.connectionFailedMessage), findsNothing);
      },
    );

    testWidgets('commit close and back do not exit during blocked save', (
      tester,
    ) async {
      final source = _ControlledSource(
        SourceProfile(
          id: 'commit-source',
          name: 'Commit',
          protocol: SourceProtocol.webdav,
          baseUrl: 'http://example.com',
          username: 'user',
          password: 'pass',
          rootPath: '/',
        ),
      );
      final repository = _SourceRepository();
      final profilesBlocker = Completer<void>();
      repository.saveProfilesBlocker = profilesBlocker;
      addTearDown(() {
        if (!profilesBlocker.isCompleted) {
          profilesBlocker.complete();
        }
      });
      final catalog = _CatalogController();
      await _pumpHarness(
        tester,
        size: const Size(390, 844),
        repository: repository,
        catalog: catalog,
        factories: [
          _QueueMusicSourceFactory([source]),
        ],
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        _formField(l10n.sourceNameLabel),
        'Committed Source',
      );
      await tester.enterText(
        _formField(l10n.serverUrlLabel),
        'http://example.com/webdav',
      );
      await tester.pump();

      await tester.ensureVisible(find.text(l10n.saveSourceAction));
      await tester.pump();
      await tester.tap(find.text(l10n.saveSourceAction));
      await _pumpUntil(
        tester,
        () => repository.saveProfilesStarted.isCompleted,
      );
      expect(repository.saveProfilesStarted.isCompleted, isTrue);

      final busyConfigFields = find.descendant(
        of: find.byKey(_configStepKey),
        matching: find.byType(TextFormField),
      );
      expect(busyConfigFields, findsWidgets);
      for (final element in busyConfigFields.evaluate()) {
        expect((element.widget as TextFormField).enabled, isFalse);
      }

      await tester.tap(find.byKey(_closeKey).first, warnIfMissed: false);
      await tester.pump();
      expect(find.text(l10n.continueEditingAction), findsNothing);
      expect(find.text(l10n.discardChangesAction), findsNothing);
      expect(find.byKey(_configStepKey), findsAtLeastNWidgets(1));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text(l10n.continueEditingAction), findsNothing);
      expect(find.text(l10n.discardChangesAction), findsNothing);
      expect(find.byKey(_configStepKey), findsAtLeastNWidgets(1));

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text(l10n.continueEditingAction), findsNothing);
      expect(find.text(l10n.discardChangesAction), findsNothing);
      expect(find.byKey(_configStepKey), findsAtLeastNWidgets(1));
      expect(repository.saveActiveSourceIdCalls, isEmpty);
      expect(catalog.rescans, isEmpty);

      final blockedFooterCancelFinder = find.text(
        MaterialLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        ).cancelButtonLabel,
      );
      expect(blockedFooterCancelFinder, findsOneWidget);
      final blockedFooterCancelButton = tester.widget<TextButton>(
        find
            .ancestor(
              of: blockedFooterCancelFinder,
              matching: find.byType(TextButton),
            )
            .first,
      );
      expect(blockedFooterCancelButton.onPressed, isNull);

      profilesBlocker.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(_dialogKey), findsNothing);
      expect(find.text(l10n.sourceSavedSuccess), findsOneWidget);
      expect(repository.storedProfiles, hasLength(1));
      final savedId = repository.storedProfiles.single.id;
      expect(savedId, isNotEmpty);
      expect(repository.activeSourceId, savedId);
      expect(repository.saveActiveSourceIdCalls, [savedId]);
      expect(catalog.rescans, [savedId]);
    });

    testWidgets('stable retry after partial save failure keeps one source id', (
      tester,
    ) async {
      final firstSource = _ControlledSource(
        SourceProfile(
          id: 'retry-source-one',
          name: 'Retry',
          protocol: SourceProtocol.webdav,
          baseUrl: 'http://example.com',
          username: 'user',
          password: 'pass',
          rootPath: '/',
        ),
      );
      final secondSource = _ControlledSource(
        SourceProfile(
          id: 'retry-source-two',
          name: 'Retry',
          protocol: SourceProtocol.webdav,
          baseUrl: 'http://example.com',
          username: 'user',
          password: 'pass',
          rootPath: '/',
        ),
      );
      final repository = _SourceRepository()
        ..saveActiveSourceIdError = StateError('active source id save failed');
      final catalog = _CatalogController();
      await _pumpHarness(
        tester,
        size: const Size(390, 844),
        repository: repository,
        catalog: catalog,
        factories: [
          _QueueMusicSourceFactory([firstSource, secondSource]),
        ],
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      await tester.enterText(_formField(l10n.sourceNameLabel), 'Retry Source');
      await tester.enterText(
        _formField(l10n.serverUrlLabel),
        'http://example.com/webdav',
      );
      await tester.pump();

      await tester.ensureVisible(find.text(l10n.saveSourceAction));
      await tester.pump();
      await tester.tap(find.text(l10n.saveSourceAction));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsOneWidget);
      expect(find.byKey(_configStepKey), findsAtLeastNWidgets(1));
      expect(repository.saveProfilesCalls, hasLength(1));
      expect(repository.saveActiveSourceIdCalls, hasLength(1));
      expect(repository.storedProfiles, hasLength(1));
      final firstId = repository.storedProfiles.single.id;
      expect(firstId, isNotEmpty);
      expect(catalog.rescans, isEmpty);
      expect(find.text(l10n.connectionFailedMessage), findsOneWidget);

      repository.saveActiveSourceIdError = null;
      await tester.ensureVisible(find.text(l10n.saveSourceAction));
      await tester.pump();
      await tester.tap(find.text(l10n.saveSourceAction));
      await tester.pumpAndSettle();
      expect(find.byKey(_dialogKey), findsNothing);
      expect(repository.saveProfilesCalls, hasLength(2));
      expect(repository.saveActiveSourceIdCalls, hasLength(2));
      expect(repository.storedProfiles, hasLength(1));
      expect(repository.storedProfiles.single.id, firstId);
      expect(repository.activeSourceId, firstId);
      expect(repository.saveActiveSourceIdCalls.last, firstId);
      expect(catalog.rescans, [firstId]);
    });

    testWidgets(
      'forced tree unmount during pending connect releases without writes',
      (tester) async {
        final source = _ControlledSource(
          SourceProfile(
            id: 'unmount-source',
            name: 'Unmount',
            protocol: SourceProtocol.webdav,
            baseUrl: 'http://example.com',
            username: 'user',
            password: 'pass',
            rootPath: '/',
          ),
        );
        source.connectCompleter = Completer<void>();
        addTearDown(() {
          if (!source.connectCompleter!.isCompleted) {
            source.connectCompleter!.complete();
          }
        });
        final repository = _SourceRepository();
        final catalog = _CatalogController();
        await _pumpHarness(
          tester,
          size: const Size(390, 844),
          repository: repository,
          catalog: catalog,
          factories: [
            _QueueMusicSourceFactory([source]),
          ],
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        )!;

        await tester.tap(find.byIcon(Icons.add_link_rounded).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.webdavSourceTypeTitle));
        await tester.pumpAndSettle();
        await tester.enterText(
          _formField(l10n.serverUrlLabel),
          'http://example.com/webdav',
        );
        await tester.pump();

        await tester.ensureVisible(find.text(l10n.saveSourceAction));
        await tester.pump();
        await tester.tap(find.text(l10n.saveSourceAction));
        await _pumpUntil(tester, () => source.connectStarted.isCompleted);
        expect(source.connectStarted.isCompleted, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        if (!source.connectCompleter!.isCompleted) {
          source.connectCompleter!.complete();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(repository.saveProfilesCalls, isEmpty);
        expect(repository.saveActiveSourceIdCalls, isEmpty);
        expect(catalog.rescans, isEmpty);
      },
    );

    testWidgets(
      'directory overlap during blocked save closes both layers and scans once',
      (tester) async {
        final source = _ControlledSource(
          SourceProfile(
            id: 'overlap-source',
            name: 'Overlap',
            protocol: SourceProtocol.webdav,
            baseUrl: 'http://example.com',
            username: 'user',
            password: 'pass',
            rootPath: '/',
          ),
        );
        source.connectCompleter = Completer<void>();
        addTearDown(() {
          if (!source.connectCompleter!.isCompleted) {
            source.connectCompleter!.complete();
          }
        });
        final spareSource = _ControlledSource(
          SourceProfile(
            id: 'overlap-spare',
            name: 'Overlap Spare',
            protocol: SourceProtocol.webdav,
            baseUrl: 'http://example.com',
            username: 'user',
            password: 'pass',
            rootPath: '/',
          ),
        );
        final repository = _SourceRepository();
        final catalog = _CatalogController();
        await _pumpHarness(
          tester,
          size: const Size(390, 844),
          repository: repository,
          catalog: catalog,
          factories: [
            _QueueMusicSourceFactory([source, spareSource]),
          ],
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        )!;

        await tester.tap(find.byIcon(Icons.add_link_rounded).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.webdavSourceTypeTitle));
        await tester.pumpAndSettle();
        await tester.enterText(
          _formField(l10n.serverUrlLabel),
          'http://example.com/webdav',
        );
        await tester.pump();

        await tester.ensureVisible(find.text(l10n.saveSourceAction));
        await tester.pump();
        await tester.tap(find.text(l10n.saveSourceAction));
        await _pumpUntil(tester, () => source.connectStarted.isCompleted);
        expect(source.connectStarted.isCompleted, isTrue);

        final addScanDirFinder = find.text(l10n.addScanDirectoryAction);
        expect(addScanDirFinder, findsOneWidget);
        await tester.ensureVisible(addScanDirFinder);
        await tester.pump();
        final addScanDirButton = tester.widget<FilledButton>(
          find
              .ancestor(
                of: addScanDirFinder,
                matching: find.byType(FilledButton),
              )
              .first,
        );
        final directoryPickerEnabled = addScanDirButton.onPressed != null;

        Finder auxDialogTitleFinder() => find.descendant(
          of: find.byType(GlacierDialog),
          matching: find.text(l10n.addScanDirectoryDialogTitle),
        );

        if (directoryPickerEnabled) {
          await tester.tap(addScanDirFinder);
          await _pumpUntil(
            tester,
            () => auxDialogTitleFinder().evaluate().isNotEmpty,
          );
          expect(auxDialogTitleFinder(), findsOneWidget);
          expect(find.byKey(_dialogKey), findsOneWidget);
        } else {
          expect(addScanDirButton.onPressed, isNull);
          await tester.tap(addScanDirFinder, warnIfMissed: false);
          await tester.pump();
          expect(auxDialogTitleFinder(), findsNothing);
          expect(find.byKey(_dialogKey), findsOneWidget);
        }

        if (!source.connectCompleter!.isCompleted) {
          source.connectCompleter!.complete();
        }
        await _pumpUntil(
          tester,
          () => find.byKey(_dialogKey).evaluate().isEmpty,
        );
        await tester.pump();
        expect(auxDialogTitleFinder(), findsNothing);
        expect(find.byKey(_dialogKey), findsNothing);
        expect(repository.saveProfilesCalls, hasLength(1));
        expect(repository.storedProfiles, hasLength(1));
        final savedId = repository.storedProfiles.single.id;
        expect(repository.activeSourceId, savedId);
        expect(repository.saveActiveSourceIdCalls, [savedId]);
        expect(catalog.rescans, [savedId]);
        expect(find.text(l10n.sourceSavedSuccess), findsOneWidget);
      },
    );

    testWidgets(
      'compact 320x568 font scale 2 keyboard 250 keeps controls reachable',
      (tester) async {
        final prefs = LibraryPreferences(
          localePreference: AppLocalePreference.english,
          fontScaleFactor: 2.0,
        );
        await _pumpHarness(tester, size: const Size(320, 568), prefs: prefs);
        tester.view.viewInsets = FakeViewPadding(bottom: 250.0);
        await tester.pump();

        final scalableContext = tester.element(find.byType(AlbumsPage));
        final scaler = MediaQuery.textScalerOf(scalableContext);
        expect(scaler.scale(14.0), 28.0);

        await tester.tap(find.byIcon(Icons.add_link_rounded).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(_closeKey).first);
        expect(tester.takeException(), isNull);
        final closeRect = tester.getRect(find.byKey(_closeKey).first);
        expect(closeRect.bottom, lessThanOrEqualTo(568.0 - 250.0));
        _expectVisibleDialogPanelFits(tester);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        )!;
        final typeStepScrollable = find.descendant(
          of: find.byKey(_typeStepKey),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text(l10n.webdavSourceTypeTitle),
          48.0,
          scrollable: typeStepScrollable,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.webdavSourceTypeTitle));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(_backKey));
        await tester.ensureVisible(find.byKey(_closeKey).first);
        await tester.ensureVisible(find.text(l10n.saveSourceAction));
        final saveRect = tester.getRect(find.text(l10n.saveSourceAction));
        expect(saveRect.bottom, lessThanOrEqualTo(568.0 - 250.0));
        _expectVisibleDialogPanelFits(tester);
        await tester.ensureVisible(_formField(l10n.serverUrlLabel));
        await tester.pump();
        await tester.tap(_formField(l10n.serverUrlLabel));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('normal 390x844 dialog controls stay reachable', (
      tester,
    ) async {
      final prefs = LibraryPreferences(
        localePreference: AppLocalePreference.english,
        fontScaleFactor: 1.0,
      );
      await _pumpHarness(tester, size: const Size(390, 844), prefs: prefs);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AlbumsPage)),
      )!;

      await tester.tap(find.byIcon(Icons.add_link_rounded).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(_closeKey).first);
      expect(tester.takeException(), isNull);
      _expectVisibleDialogPanelFits(tester);

      await tester.tap(find.text(l10n.webdavSourceTypeTitle));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      _expectVisibleDialogPanelFits(tester);
      await tester.ensureVisible(find.byKey(_backKey));
      await tester.ensureVisible(find.byKey(_closeKey).first);
      await tester.ensureVisible(find.text(l10n.saveSourceAction));
      expect(tester.takeException(), isNull);
      await tester.tap(_formField(l10n.serverUrlLabel));
      await tester.pump();
      await tester.ensureVisible(_formField(l10n.serverUrlLabel));
      expect(tester.takeException(), isNull);
    });
  });
}
