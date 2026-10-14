import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
import 'package:google_fonts/src/google_fonts_variant.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/app/app.dart';
import 'package:music/app/app_shell.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:music/core/models/app_preferences.dart';
import 'package:music/core/models/library_album.dart';
import 'package:music/core/models/library_song.dart';
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/core/storage/source_profile_repository.dart';
import 'package:music/features/library/application/library_catalog_controller.dart';
import 'package:music/features/library/presentation/albums_page.dart';
import 'package:music/features/library/presentation/folder_artwork_provider.dart';
import 'package:music/features/library/presentation/library_page.dart';
import 'package:music/features/library/presentation/library_search_page.dart';
import 'package:music/features/player/application/player_controller.dart';
import 'package:music/features/player/presentation/widgets/mini_player.dart';
import 'package:music/features/player/presentation/widgets/now_playing_panel.dart';
import 'package:music/features/player/presentation/widgets/track_cover_thumbnail.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';
import 'package:music/features/settings/presentation/add_source_page.dart';
import 'package:music/features/settings/presentation/settings_page.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initialState);

  PlayerViewState _initialState;
  int playPauseCallCount = 0;
  int playCallCount = 0;

  @override
  PlayerViewState build() => _initialState;

  @override
  Future<void> togglePlayPause() async {
    playPauseCallCount++;
  }

  @override
  Future<void> play() async {
    playCallCount++;
  }

  void emitState(PlayerViewState newState) {
    _initialState = newState;
    state = newState;
  }
}

class _FakeSourceProfileRepository implements SourceProfileRepository {
  _FakeSourceProfileRepository([this.profiles = const []]);

  final List<SourceProfile> profiles;

  @override
  Future<String?> loadActiveSourceId() async =>
      profiles.isEmpty ? null : profiles.first.id;

  @override
  Future<List<SourceProfile>> loadProfiles() async => profiles;

  @override
  Future<void> saveActiveSourceId(String? sourceId) async {}

  @override
  Future<void> saveProfiles(List<SourceProfile> profiles) async {}
}

class _FakeLibraryPreferencesRepository
    implements LibraryPreferencesRepository {
  _FakeLibraryPreferencesRepository([
    LibraryPreferences initialPreferences = const LibraryPreferences(),
  ]) : _preferences = initialPreferences;

  LibraryPreferences _preferences;

  @override
  Future<LibraryPreferences> load() async => _preferences;

  @override
  Future<void> save(LibraryPreferences preferences) async {
    _preferences = preferences;
  }

  @override
  Future<LibraryPreferences> update(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async {
    _preferences = transform(_preferences);
    return _preferences;
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

PlayableTrack _createSampleTrack({
  String id = 'track-1',
  String title = 'Starfall',
  String artist = 'Stellar',
}) {
  return PlayableTrack(
    id: id,
    sourceId: 'source-1',
    title: title,
    artistName: artist,
    albumTitle: 'Cosmos',
    sourceName: 'WebDAV Source',
    remotePath: '/music/starfall.flac',
    audioSource: AudioSource.uri(Uri.parse('https://example.com/audio.mp3')),
  );
}

PlayerViewState _createSampleState({
  PlayableTrack? track,
  Duration position = Duration.zero,
  Duration duration = const Duration(minutes: 3),
  bool isPlaying = true,
  List<LyricLine> lyrics = const [],
}) {
  return PlayerViewState(
    currentTrack: track,
    isPlaying: isPlaying,
    processingState: ProcessingState.ready,
    position: position,
    bufferedPosition: const Duration(seconds: 45),
    duration: duration,
    playlist: const [],
    currentIndex: -1,
    playbackMode: PlayerPlaybackMode.list,
    lyrics: lyrics,
    lyricsSource: lyrics.isNotEmpty
        ? PlayerLyricsSource.embeddedTag
        : PlayerLyricsSource.none,
    cacheSegments: const [],
  );
}

LibrarySong _createSampleLibrarySong(int index) {
  return LibrarySong(
    id: 'song-$index',
    sourceId: 'src-1',
    sourceName: 'WebDAV',
    title: 'Song $index',
    fileName: 'song-$index.flac',
    remotePath: '/music/song-$index.flac',
    albumTitle: 'Album',
    artistName: 'Artist $index',
    directoryPath: '/music',
    folderAlbumTitle: 'Album',
    folderArtistName: 'Artist $index',
  );
}

class _SyncCatalogController extends LibraryCatalogController {
  _SyncCatalogController(this._catalog);

  final LibraryCatalogState _catalog;

  @override
  Future<LibraryCatalogState> build() {
    return SynchronousFuture<LibraryCatalogState>(_catalog);
  }
}

class _FakeGoogleAssetManifest implements AssetManifest {
  _FakeGoogleAssetManifest(this.assets);

  final List<String> assets;

  @override
  List<String> listAssets() => assets;

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

class _FailingLibraryPreferencesRepository
    implements LibraryPreferencesRepository {
  final void Function(bool) onSaveFail;
  bool shouldFailSave;
  LibraryPreferences _current;

  _FailingLibraryPreferencesRepository(
    LibraryPreferences initialPreferences,
    this.onSaveFail,
    this.shouldFailSave,
  ) : _current = initialPreferences;

  @override
  Future<LibraryPreferences> load() async => _current;

  @override
  Future<void> save(LibraryPreferences preferences) async {
    if (shouldFailSave) {
      onSaveFail(true);
      throw Exception('Simulated save failure');
    }
    onSaveFail(false);
    _current = preferences;
  }

  @override
  Future<LibraryPreferences> update(
    LibraryPreferences Function(LibraryPreferences) transform,
  ) async {
    if (shouldFailSave) {
      onSaveFail(true);
      throw Exception('Simulated save failure');
    }
    onSaveFail(false);
    _current = transform(_current);
    return _current;
  }
}

class _DelayedLoadRepository implements LibraryPreferencesRepository {
  final Completer<LibraryPreferences> _completer;
  LibraryPreferences _saved;

  _DelayedLoadRepository(this._completer, this._saved);

  @override
  Future<LibraryPreferences> load() => _completer.future;

  @override
  Future<void> save(LibraryPreferences preferences) async {
    _saved = preferences;
  }

  @override
  Future<LibraryPreferences> update(
    LibraryPreferences Function(LibraryPreferences) transform,
  ) async {
    _saved = transform(_saved);
    return _saved;
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('OmniTune UI Regressions & Visual Acceptance', () {
    testWidgets(
      '1. Light and Dark theme render with distinct context ColorScheme and brightness',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        const lightPrefs = LibraryPreferences(
          themePreference: AppThemePreference.light,
        );

        // Light theme
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(lightPrefs),
              ),
              appSettingsControllerProvider.overrideWith(
                () => _SyncAppSettingsController(lightPrefs),
              ),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();

        final lightScaffoldContext = tester.element(
          find.byType(Scaffold).first,
        );
        final lightTheme = Theme.of(lightScaffoldContext);
        expect(lightTheme.brightness, Brightness.light);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        const darkPrefs = LibraryPreferences(
          themePreference: AppThemePreference.dark,
        );

        // Dark theme
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(darkPrefs),
              ),
              appSettingsControllerProvider.overrideWith(
                () => _SyncAppSettingsController(darkPrefs),
              ),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();

        final darkScaffoldContext = tester.element(find.byType(Scaffold).first);
        final darkTheme = Theme.of(darkScaffoldContext);
        expect(darkTheme.brightness, Brightness.dark);
        expect(
          darkTheme.colorScheme.surface,
          isNot(equals(lightTheme.colorScheme.surface)),
        );
      },
    );

    testWidgets(
      '2. 412px narrow and 1280px wide layouts render cleanly without overflow',
      (tester) async {
        addTearDown(() => tester.view.reset());

        // Narrow 412px
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.album_rounded), findsOneWidget);

        // Wide 1280px
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationRail), findsOneWidget);
      },
    );

    testWidgets('3. zh and en locales apply properly to UI elements', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      const enPrefs = LibraryPreferences(
        localePreference: AppLocalePreference.english,
      );

      // English
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('en_scope'),
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(
              _FakeSourceProfileRepository(),
            ),
            libraryPreferencesRepositoryProvider.overrideWithValue(
              _FakeLibraryPreferencesRepository(enPrefs),
            ),
            appSettingsControllerProvider.overrideWith(
              () => _SyncAppSettingsController(enPrefs),
            ),
          ],
          child: const MusicApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Albums'), findsAtLeastNWidgets(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      const zhPrefs = LibraryPreferences(
        localePreference: AppLocalePreference.chinese,
      );

      // Chinese
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('zh_scope'),
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(
              _FakeSourceProfileRepository(),
            ),
            libraryPreferencesRepositoryProvider.overrideWithValue(
              _FakeLibraryPreferencesRepository(zhPrefs),
            ),
            appSettingsControllerProvider.overrideWith(
              () => _SyncAppSettingsController(zhPrefs),
            ),
          ],
          child: const MusicApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('专辑'), findsAtLeastNWidgets(1));
    });

    testWidgets(
      '4. Reduced motion (disableAnimations) on /player route sets duration to 0 and jumps cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final sampleLyrics = [
          const LyricLine(time: Duration(seconds: 0), text: 'Line 1'),
          const LyricLine(time: Duration(seconds: 10), text: 'Line 2'),
        ];

        final sampleTrack = _createSampleTrack();
        final fakeController = _FakePlayerController(
          _createSampleState(
            track: sampleTrack,
            lyrics: sampleLyrics,
            position: const Duration(seconds: 5),
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
              playerControllerProvider.overrideWith(() => fakeController),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: const MusicApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // MiniPlayer is displayed
        expect(find.byType(MiniPlayer), findsOneWidget);

        // Find the open player button in MiniPlayer
        final openPlayerButton = find.byIcon(Icons.expand_less_rounded);
        expect(openPlayerButton, findsOneWidget);
        await tester.tap(openPlayerButton);

        // With reduced motion, transitionDuration is Duration.zero, so 1 pump presents NowPlayingPanel immediately
        await tester.pump();
        expect(find.byType(NowPlayingPanel), findsOneWidget);

        // Verify route transition duration is Duration.zero with reduced motion
        final nowPlayingRoute = ModalRoute.of(
          tester.element(find.byType(NowPlayingPanel)),
        );
        expect(nowPlayingRoute?.transitionDuration, Duration.zero);
        expect(nowPlayingRoute?.reverseTransitionDuration, Duration.zero);

        // Switch to lyrics view and advance position - scrolling with disableAnimations must not throw
        await tester.tap(find.byType(AspectRatio).first, warnIfMissed: false);
        await tester.pump();

        fakeController.emitState(
          _createSampleState(
            track: sampleTrack,
            lyrics: sampleLyrics,
            position: const Duration(seconds: 12),
            isPlaying: true,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '5. Spacebar keyboard shortcut using real MusicAppShell respects EditableText focus',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final fakeController = _FakePlayerController(
          _createSampleState(isPlaying: false),
        );

        final textController = TextEditingController();
        final focusNode = FocusNode();

        // Create a minimal real GoRouter with StatefulShellRoute using real MusicAppShell
        final testRouter = GoRouter(
          initialLocation: '/test',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (context, state, navigationShell) {
                return MusicAppShell(navigationShell: navigationShell);
              },
              branches: [
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/test',
                      builder: (context, state) => Scaffold(
                        body: Column(
                          children: [
                            TextField(
                              controller: textController,
                              focusNode: focusNode,
                            ),
                            const Focus(
                              autofocus: false,
                              child: Text('Non-editable item'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playerControllerProvider.overrideWith(() => fakeController),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
            ],
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: testRouter,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Focus TextField
        focusNode.requestFocus();
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);

        // Press spacebar while editing: should NOT toggle playback
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(fakeController.playPauseCallCount, 0);

        // Unfocus TextField and press spacebar
        focusNode.unfocus();
        await tester.pump();
        expect(focusNode.hasFocus, isFalse);

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(fakeController.playPauseCallCount, 1);
      },
    );

    testWidgets(
      '6. Cloud 189 entrypoints from Albums and Settings route to password and app auth forms, hiding unfinished TV modes',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        // Path A: From Albums Page via Add Link icon
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(Navigator).first),
        )!;

        // Tap Add Source icon on Albums page
        final addSourceIconFinder = find.byIcon(Icons.add_link_rounded).first;
        await tester.tap(addSourceIconFinder);
        await tester.pumpAndSettle();

        // 189 Cloud option is visible
        final cloud189OptionFinder = find.text(l10n.cloud189Protocol);
        await tester.scrollUntilVisible(
          cloud189OptionFinder,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(cloud189OptionFinder, findsOneWidget);

        // Tap 189 Cloud to navigate to AddSourcePage
        await tester.tap(cloud189OptionFinder);
        await tester.pumpAndSettle();

        // Verify SegmentedButton<Cloud189AuthMode> specifically contains openListPassword and appAuthorization
        final segmentedButtonFinder = find.byType(
          SegmentedButton<Cloud189AuthMode>,
        );
        expect(segmentedButtonFinder, findsOneWidget);
        final segmentedButton = tester
            .widget<SegmentedButton<Cloud189AuthMode>>(segmentedButtonFinder);
        final segmentValues = segmentedButton.segments
            .map((s) => s.value)
            .toSet();
        expect(
          segmentValues,
          equals({
            Cloud189AuthMode.openListPassword,
            Cloud189AuthMode.appAuthorization,
          }),
        );
        expect(segmentValues.contains(Cloud189AuthMode.cloudTV), isFalse);

        // Verify OpenList and App Authorization modes exist in UI
        expect(find.text(l10n.cloud189OpenListModeLabel), findsOneWidget);
        expect(
          find.text(l10n.cloud189AppAuthorizationModeLabel),
          findsOneWidget,
        );

        // Switch to App Authorization mode
        await tester.tap(find.text(l10n.cloud189AppAuthorizationModeLabel));
        await tester.pumpAndSettle();
        expect(find.text(l10n.cloud189AppKeyLabel), findsOneWidget);

        // Switch back to OpenList mode
        await tester.tap(find.text(l10n.cloud189OpenListModeLabel));
        await tester.pumpAndSettle();
        expect(find.text(l10n.cloud189OpenListUsernameLabel), findsOneWidget);

        // Path B: From Settings Page
        final context = tester.element(find.byType(AddSourcePage));
        GoRouter.of(context).go('/settings');
        await tester.pumpAndSettle();

        expect(find.byType(SettingsPage), findsOneWidget);
        final sourceGroup = find.text(l10n.sourceManagementSettingTitle);
        await tester.scrollUntilVisible(
          sourceGroup,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(sourceGroup.first);
        await tester.pumpAndSettle();
        final addSourceBtn = find.text(l10n.addSourceAction);
        await tester.scrollUntilVisible(
          addSourceBtn,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(addSourceBtn, findsAtLeastNWidgets(1));
        await tester.tap(addSourceBtn.first);
        await tester.pumpAndSettle();

        // Cloud 189 option present from settings picker too
        final cloud189FromSettings = find.text(l10n.cloud189Protocol);
        expect(cloud189FromSettings, findsOneWidget);

        // Tap 189 Cloud to navigate to AddSourcePage from settings
        await tester.tap(cloud189FromSettings);
        await tester.pumpAndSettle();

        expect(find.byType(AddSourcePage), findsOneWidget);
        final addSourcePageFromSettings = tester.widget<AddSourcePage>(
          find.byType(AddSourcePage),
        );
        expect(
          addSourcePageFromSettings.initialProtocol,
          SourceProtocol.cloudDrive,
        );
        expect(find.text(l10n.cloud189OpenListUsernameLabel), findsOneWidget);
        await tester.tap(find.text(l10n.cloud189AppAuthorizationModeLabel));
        await tester.pumpAndSettle();
        expect(find.text(l10n.cloud189AppKeyLabel), findsOneWidget);
      },
    );

    testWidgets(
      '7. Song list lazy builder with 0, 1000, 10000 items and Album pagination',
      (tester) async {
        tester.view.physicalSize = const Size(412, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        // Fixture A: 0 items empty state
        final zeroCatalog = const LibraryCatalogState(tracks: []);
        final containerZero = ProviderContainer(
          overrides: [
            libraryCatalogControllerProvider.overrideWith(
              () => _SyncCatalogController(zeroCatalog),
            ),
            folderArtworkProvider.overrideWith((ref, request) async => null),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: containerZero,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: LibrarySongsPage(
                  section: LibraryCollectionSection.allSongs,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(LibrarySongsPage)),
        )!;
        expect(find.text(l10n.allSongsEmptyTitle), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));

        // Fixture B: 1000 items lazy loading
        final thousandTracks = List.generate(
          1000,
          (i) => _createSampleLibrarySong(i),
        );
        final thousandCatalog = LibraryCatalogState(tracks: thousandTracks);

        final containerThousand = ProviderContainer(
          overrides: [
            libraryCatalogControllerProvider.overrideWith(
              () => _SyncCatalogController(thousandCatalog),
            ),
            folderArtworkProvider.overrideWith((ref, request) async => null),
            playerControllerProvider.overrideWith(
              () => _FakePlayerController(_createSampleState()),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: containerThousand,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: LibrarySongsPage(
                  section: LibraryCollectionSection.allSongs,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // First song exists in viewport
        expect(find.text('Song 0'), findsOneWidget);
        // Far-away songs do NOT exist in viewport
        expect(find.text('Song 500'), findsNothing);
        expect(find.text('Song 999'), findsNothing);

        // Verifiable constraint: rendered thumbnails / cards count < 100
        final renderedThumbnails = find.byType(TrackCoverThumbnail);
        expect(renderedThumbnails.evaluate().length, lessThan(100));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));

        // Fixture C: 10,000 items
        final tenThousandTracks = List.generate(
          10000,
          (i) => _createSampleLibrarySong(i),
        );
        final massiveCatalog = LibraryCatalogState(tracks: tenThousandTracks);

        final containerMassive = ProviderContainer(
          overrides: [
            libraryCatalogControllerProvider.overrideWith(
              () => _SyncCatalogController(massiveCatalog),
            ),
            folderArtworkProvider.overrideWith((ref, request) async => null),
            playerControllerProvider.overrideWith(
              () => _FakePlayerController(_createSampleState()),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: containerMassive,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: LibrarySongsPage(
                  section: LibraryCollectionSection.allSongs,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Song 0'), findsOneWidget);
        expect(find.text('Song 9999'), findsNothing);
        expect(
          find.byType(TrackCoverThumbnail).evaluate().length,
          lessThan(100),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));

        // Album pagination verification (default page size 9)
        final sampleSource = const SourceProfile(
          id: 'src-1',
          name: 'WebDAV',
          protocol: SourceProtocol.webdav,
          baseUrl: 'http://example.com',
          username: 'user',
          password: 'pwd',
          rootPath: '/',
        );
        final sampleAlbums = List.generate(
          20,
          (i) => LibraryAlbum(
            id: 'album-$i',
            sourceId: 'src-1',
            sourceName: 'WebDAV',
            title: 'Album $i',
            artistName: 'Artist $i',
            tracks: [_createSampleLibrarySong(i)],
          ),
        );
        final albumCatalog = LibraryCatalogState(
          tracks: thousandTracks,
          folderAlbums: sampleAlbums,
          folderAlbumsBySource: {'src-1': sampleAlbums},
        );

        final containerAlbums = ProviderContainer(
          overrides: [
            libraryCatalogControllerProvider.overrideWith(
              () => _SyncCatalogController(albumCatalog),
            ),
            sourceProfileRepositoryProvider.overrideWithValue(
              _FakeSourceProfileRepository([sampleSource]),
            ),
            libraryPreferencesRepositoryProvider.overrideWithValue(
              _FakeLibraryPreferencesRepository(
                const LibraryPreferences(albumPageSize: 9),
              ),
            ),
            folderArtworkProvider.overrideWith((ref, request) async => null),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: containerAlbums,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: AlbumsPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Page 1 contains Album 0, does not contain Album 15
        expect(find.text('Album 0'), findsOneWidget);
        expect(find.text('Album 15'), findsNothing);

        // Cleanly unmount widget tree before containers are disposed
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));

        // Dispose all containers synchronously and drain pump queue
        containerZero.dispose();
        containerThousand.dispose();
        containerMassive.dispose();
        containerAlbums.dispose();
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      '8. Lyrics style transition from 0s (line 1 active) to 15s (line 2 active, line 1 normal)',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final sampleLyrics = [
          const LyricLine(time: Duration(seconds: 0), text: 'First line intro'),
          const LyricLine(
            time: Duration(seconds: 10),
            text: 'Second line chorus',
          ),
          const LyricLine(
            time: Duration(seconds: 20),
            text: 'Third line outro',
          ),
        ];

        final sampleTrack = _createSampleTrack();
        final fakeController = _FakePlayerController(
          _createSampleState(
            track: sampleTrack,
            lyrics: sampleLyrics,
            position: Duration.zero,
            duration: const Duration(minutes: 3),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
              playerControllerProvider.overrideWith(() => fakeController),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: NowPlayingPanel()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to lyrics mode
        await tester.tap(find.byType(AspectRatio).first, warnIfMissed: false);
        await tester.pumpAndSettle();

        // At position 0s: line 1 ('First line intro') is active (fontSize 23, w800)
        final line1Finder = find.text('First line intro');
        expect(line1Finder, findsOneWidget);
        final line1TextStyle = tester.widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: line1Finder,
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        );
        expect(line1TextStyle.style.fontSize, 23.0);
        expect(line1TextStyle.style.fontWeight, FontWeight.w800);

        // Line 2 ('Second line chorus') is inactive (fontSize 17, w500)
        final line2Finder = find.text('Second line chorus');
        expect(line2Finder, findsOneWidget);
        final line2TextStyleBefore = tester.widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: line2Finder,
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        );
        expect(line2TextStyleBefore.style.fontSize, 17.0);
        expect(line2TextStyleBefore.style.fontWeight, FontWeight.w500);

        // Advance position to 15s
        fakeController.emitState(
          _createSampleState(
            track: sampleTrack,
            lyrics: sampleLyrics,
            position: const Duration(seconds: 15),
            duration: const Duration(minutes: 3),
          ),
        );
        await tester.pumpAndSettle();

        // Line 2 now becomes active (fontSize 23, w800)
        final line2TextStyleAfter = tester.widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: line2Finder,
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        );
        expect(line2TextStyleAfter.style.fontSize, 23.0);
        expect(line2TextStyleAfter.style.fontWeight, FontWeight.w800);

        // Line 1 reverts to inactive (fontSize 17, w500)
        final line1TextStyleAfter = tester.widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: line1Finder,
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        );
        expect(line1TextStyleAfter.style.fontSize, 17.0);
        expect(line1TextStyleAfter.style.fontWeight, FontWeight.w500);
      },
    );

    testWidgets(
      '9. Directional navigation mode enforces minimum 18sp font size on small text',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(
                  const LibraryPreferences(fontScaleFactor: 1.0),
                ),
              ),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                navigationMode: NavigationMode.directional,
              ),
              child: const MusicApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(Scaffold).first);
        final textScaler = MediaQuery.textScalerOf(context);

        // A small font size (e.g. 10sp, 14sp) must scale to at least 18sp
        expect(textScaler.scale(10.0), greaterThanOrEqualTo(18.0));
        expect(textScaler.scale(14.0), greaterThanOrEqualTo(18.0));
        // Larger fonts scale proportionally without being artificially blown up
        expect(textScaler.scale(24.0), equals(24.0));
      },
    );

    testWidgets(
      '10. Max font scale (2.0) on narrow 412px renders without RenderFlex overflow in Albums, Settings and Cloud189 form',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(
                  const LibraryPreferences(fontScaleFactor: 2.0),
                ),
              ),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Navigate to Settings
        final albumsContext = tester.element(find.byType(AlbumsPage));
        GoRouter.of(albumsContext).go('/settings');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(SettingsPage), findsOneWidget);

        // Navigate to Cloud189 form via cloudDrive protocol route
        final settingsContext = tester.element(find.byType(SettingsPage));
        GoRouter.of(settingsContext).go('/settings/add-source/cloudDrive');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(AddSourcePage), findsOneWidget);

        final addSourceWidget = tester.widget<AddSourcePage>(
          find.byType(AddSourcePage),
        );
        expect(addSourceWidget.initialProtocol, SourceProtocol.cloudDrive);

        // Verify openListPassword form renders without overflow
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AddSourcePage)),
        )!;
        expect(find.text(l10n.cloud189OpenListUsernameLabel), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch to appAuthorization form and verify it renders without overflow
        await tester.tap(find.text(l10n.cloud189AppAuthorizationModeLabel));
        await tester.pumpAndSettle();
        expect(find.text(l10n.cloud189AppKeyLabel), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '11. D-pad directional focus on NavigationRail, Enter activation, and platform back route popping',
      (tester) async {
        tester.view.physicalSize = const Size(960, 540);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial wide layout: AlbumsPage is displayed with NavigationRail at index 0
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(AlbumsPage), findsOneWidget);
        expect(find.byType(LibraryPage), findsNothing);

        final railFinder = find.byType(NavigationRail);
        final initialRail = tester.widget<NavigationRail>(railFinder);
        expect(initialRail.selectedIndex, 0);

        // 2. Request focus on the Albums destination icon in NavigationRail
        final albumIconFinder = find.byIcon(Icons.album_rounded);
        expect(albumIconFinder, findsOneWidget);
        final albumFocus = Focus.of(tester.element(albumIconFinder));
        albumFocus.requestFocus();
        await tester.pumpAndSettle();
        expect(albumFocus.hasFocus, isTrue);

        // 3. Press arrowDown to traverse focus to the Collection destination icon
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        final collectionIconFinder = find.byIcon(Icons.library_music_outlined);
        expect(collectionIconFinder, findsOneWidget);
        final collectionFocus = Focus.of(tester.element(collectionIconFinder));
        expect(collectionFocus.hasFocus, isTrue);

        // 4. Press Enter to activate the Collection destination
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        // Route changes to LibraryPage and NavigationRail selectedIndex becomes 1
        expect(find.byType(LibraryPage), findsOneWidget);
        final updatedRail = tester.widget<NavigationRail>(railFinder);
        expect(updatedRail.selectedIndex, 1);

        // 5. Navigate back to Albums destination in NavigationRail and activate with Enter
        final activeAlbumIconFinder = find.byIcon(Icons.album_outlined);
        expect(activeAlbumIconFinder, findsOneWidget);
        final activeAlbumFocus = Focus.of(
          tester.element(activeAlbumIconFinder),
        );
        activeAlbumFocus.requestFocus();
        await tester.pumpAndSettle();
        expect(activeAlbumFocus.hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(AlbumsPage), findsOneWidget);
        final returnedRail = tester.widget<NavigationRail>(railFinder);
        expect(returnedRail.selectedIndex, 0);

        // 6. Focus the add source button on AlbumsPage and activate using select
        final addSourceIconFinder = find.byIcon(Icons.add_link_rounded);
        expect(addSourceIconFinder, findsOneWidget);
        final addSourceFocus = Focus.of(tester.element(addSourceIconFinder));
        addSourceFocus.requestFocus();
        await tester.pumpAndSettle();
        expect(addSourceFocus.hasFocus, isTrue);

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        // Authentic source type selection modal bottom sheet opens
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        )!;
        expect(find.text(l10n.sourceTypeSelectionTitle), findsOneWidget);

        // 7. Verify platform Back (handlePopRoute) dismisses the modal sheet
        final handled = await tester.binding.handlePopRoute();
        expect(handled, isTrue);
        await tester.pumpAndSettle();

        // Modal sheet is dismissed, AlbumsPage is restored
        expect(find.text(l10n.sourceTypeSelectionTitle), findsNothing);
        expect(find.byType(AlbumsPage), findsOneWidget);
      },
    );

    testWidgets('settings grouped root shows five groups and back navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(
              _FakeSourceProfileRepository(),
            ),
            libraryPreferencesRepositoryProvider.overrideWithValue(
              _FakeLibraryPreferencesRepository(),
            ),
            appSettingsControllerProvider.overrideWith(
              () => _SyncAppSettingsController(LibraryPreferences()),
            ),
          ],
          child: const MusicApp(),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Navigator).first);
      GoRouter.of(context).go('/settings');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsAtLeastNWidgets(5));
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right_rounded), findsAtLeastNWidgets(5));
    });

    testWidgets('search page filters by query and clears input', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.reset());

      final song = _createSampleLibrarySong(1);
      final catalog = LibraryCatalogState(tracks: [song]);
      final fakeController = _FakePlayerController(
        _createSampleState(track: _createSampleTrack(id: song.id)),
      );

      // Deterministic Google Fonts fixture (no network, no suppressed exceptions).
      GoogleFonts.config.allowRuntimeFetching = false;
      google_fonts_base.clearCache();
      final ahemBytes = File('test/fixtures/Ahem.ttf').readAsBytesSync();
      final ahemByteData = ByteData.sublistView(Uint8List.fromList(ahemBytes));
      final fontAssets = <String>{};
      for (final family in const <String>['Inter', 'NotoSans']) {
        for (final weight in FontWeight.values) {
          for (final italic in const <bool>[false, true]) {
            final variant = GoogleFontsVariant(
              fontWeight: weight,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            );
            fontAssets.add(
              'google_fonts/$family-${variant.toApiFilenamePart()}.ttf',
            );
          }
        }
      }
      final fontAssetList = fontAssets.toList(growable: false);
      google_fonts_base.assetManifest = _FakeGoogleAssetManifest(fontAssetList);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler('flutter/assets', (message) {
        final key = Uri.decodeFull(utf8.decode(message!.buffer.asUint8List()));
        if (fontAssetList.contains(key)) {
          return Future<ByteData?>.value(ahemByteData);
        }
        return Future<ByteData?>.value(null);
      });
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        google_fonts_base.assetManifest = null;
        google_fonts_base.clearCache();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
              appSettingsControllerProvider.overrideWith(
                () => _SyncAppSettingsController(const LibraryPreferences()),
              ),
              libraryCatalogControllerProvider.overrideWith(
                () => _SyncCatalogController(catalog),
              ),
              playerControllerProvider.overrideWith(() => fakeController),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
            break;
          }
        }

        final context = tester.element(find.byType(Navigator).first);

        // Navigate to search page
        GoRouter.of(context).go('/search');
        await tester.pump();

        // Wait for initial spinner to disappear (bounded loop, max 100 iterations)
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Verify initial result: ListTile with correct title and selected state
        // Use descendant finder to avoid MiniPlayer's Song1
        final listTileFinder = find.descendant(
          of: find.byType(LibrarySearchPage),
          matching: find.byType(ListTile),
        );
        expect(listTileFinder, findsOneWidget);
        final tile = tester.widget<ListTile>(listTileFinder);
        expect(tile.title, isA<Text>().having((t) => t.data, 'data', 'Song 1'));
        expect(tile.selected, isTrue);

        // Type non-matching query - debounce and compute need pump inside runAsync
        await tester.enterText(find.byType(TextField), 'not-a-match');
        await tester.pump(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();

        // Wait for spinner to disappear after filtering
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
        }

        // Assert no results for non-match - localized no-results text appears
        final l10n = AppLocalizations.of(
          tester.element(find.byType(LibrarySearchPage)),
        )!;
        expect(find.byType(ListTile), findsNothing);
        expect(find.text(l10n.searchNoResults), findsOneWidget);

        // Clear restores query and results
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump(const Duration(milliseconds: 50));
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await tester.pump();

        // Wait for results to restore
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
          if (find.byType(ListTile).evaluate().isNotEmpty) break;
        }

        // Verify results restored
        final restoredTileFinder = find.descendant(
          of: find.byType(LibrarySearchPage),
          matching: find.byType(ListTile),
        );
        expect(restoredTileFinder, findsOneWidget);
        expect(
          find.descendant(
            of: restoredTileFinder,
            matching: find.text('Song 1'),
          ),
          findsOneWidget,
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, isEmpty);
      });
    });

    testWidgets(
      'player portrait narrow reduced-motion layout presents NowPlayingPanel',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final sampleTrack = _createSampleTrack();
        final fakeController = _FakePlayerController(
          _createSampleState(track: sampleTrack, isPlaying: true),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
              playerControllerProvider.overrideWith(() => fakeController),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: const MusicApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.expand_less_rounded));
        await tester.pump();
        expect(find.byType(NowPlayingPanel), findsOneWidget);
      },
    );

    testWidgets(
      'player wide layout with reduced animations presents NowPlayingPanel',
      (tester) async {
        tester.view.physicalSize = const Size(900, 500);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final sampleTrack = _createSampleTrack();
        final fakeController = _FakePlayerController(
          _createSampleState(track: sampleTrack, isPlaying: true),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
              playerControllerProvider.overrideWith(() => fakeController),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: const MusicApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.expand_less_rounded));
        await tester.pump();
        expect(find.byType(NowPlayingPanel), findsOneWidget);
      },
    );

    testWidgets(
      '12. NowPlayingPage SafeArea card bottom padding 8dp on regular and narrow screens',
      (tester) async {
        addTearDown(() => tester.view.reset());
        tester.view.padding = const FakeViewPadding(bottom: 24);

        final sampleTrack = _createSampleTrack();
        final sampleLyrics = [
          const LyricLine(time: Duration(seconds: 0), text: 'Line 1'),
          const LyricLine(time: Duration(seconds: 10), text: 'Line 2'),
        ];

        for (final size in [
          const Size(360, 760),
          const Size(412, 915),
          const Size(900, 500),
          const Size(320, 568),
          const Size(800, 400),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;

          final fakeController = _FakePlayerController(
            _createSampleState(
              track: sampleTrack,
              lyrics: sampleLyrics,
              isPlaying: true,
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sourceProfileRepositoryProvider.overrideWithValue(
                  _FakeSourceProfileRepository(),
                ),
                libraryPreferencesRepositoryProvider.overrideWithValue(
                  _FakeLibraryPreferencesRepository(),
                ),
                playerControllerProvider.overrideWith(() => fakeController),
                folderArtworkProvider.overrideWith(
                  (ref, request) async => null,
                ),
              ],
              child: MediaQuery(
                data: MediaQueryData.fromView(
                  tester.view,
                ).copyWith(disableAnimations: true),
                child: const MusicApp(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.expand_less_rounded));
          await tester.pump();

          expect(find.byType(NowPlayingPanel), findsOneWidget);

          final panel = tester.widget<NowPlayingPanel>(
            find.byType(NowPlayingPanel),
          );
          expect(panel, isA<NowPlayingPanel>());

          final cardFinder = find
              .descendant(
                of: find.byType(NowPlayingPanel),
                matching: find.byType(ConstrainedBox),
              )
              .first;
          final constrainedBox = tester.widget<ConstrainedBox>(cardFinder);
          final cardWidget = constrainedBox.child as Material;
          final container = cardWidget.child as Container;
          expect(
            container.padding?.resolve(TextDirection.ltr).bottom ?? 0.0,
            equals(16.0),
          );

          final cardBottom = tester.getBottomRight(cardFinder).dy;
          final viewBottom =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          final safeBottomInset =
              tester.view.padding.bottom / tester.view.devicePixelRatio;
          expect(viewBottom - safeBottomInset - cardBottom, equals(8.0));

          final playButton = find
              .byWidgetPredicate(
                (widget) => widget.runtimeType.toString().contains(
                  'PrimaryPlayerButton',
                ),
              )
              .first;
          expect(playButton, findsOneWidget);
          final playButtonRect = tester.getRect(playButton);
          expect(playButtonRect.bottom, lessThan(viewBottom));
          expect(playButtonRect.height, greaterThanOrEqualTo(48.0));

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );

    testWidgets(
      '13. NowPlayingPage text scaler 1.3 and 2.0 no overflow play button visible and hittable',
      (tester) async {
        addTearDown(() => tester.view.reset());

        final sampleTrack = _createSampleTrack();
        final sampleLyrics = [
          const LyricLine(
            time: Duration(seconds: 0),
            text:
                'Very long line that should test text scaling and wrapping behavior',
          ),
          const LyricLine(
            time: Duration(seconds: 10),
            text: 'Another long lyric line for testing',
          ),
        ];

        const scaleCases = [
          (size: Size(412, 915), scale: 1.3),
          (size: Size(412, 915), scale: 2.0),
          (size: Size(320, 480), scale: 2.0),
        ];

        for (final scaleCase in scaleCases) {
          tester.view.physicalSize = scaleCase.size;
          tester.view.devicePixelRatio = 1.0;

          final fakeController = _FakePlayerController(
            _createSampleState(
              track: sampleTrack,
              lyrics: sampleLyrics,
              isPlaying: true,
            ),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sourceProfileRepositoryProvider.overrideWithValue(
                  _FakeSourceProfileRepository(),
                ),
                libraryPreferencesRepositoryProvider.overrideWithValue(
                  _FakeLibraryPreferencesRepository(
                    LibraryPreferences(fontScaleFactor: scaleCase.scale),
                  ),
                ),
                playerControllerProvider.overrideWith(() => fakeController),
                folderArtworkProvider.overrideWith(
                  (ref, request) async => null,
                ),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(scaleCase.scale),
                ),
                child: const MusicApp(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(Icons.expand_less_rounded));
          await tester.pump();

          expect(find.byType(NowPlayingPanel), findsOneWidget);
          expect(tester.takeException(), isNull);

          final panelContext = tester.element(find.byType(NowPlayingPanel));
          final actualScale = MediaQuery.textScalerOf(panelContext).scale(1.0);
          expect(
            actualScale,
            moreOrLessEquals(scaleCase.scale, epsilon: 0.01),
            reason: 'NowPlayingPanel text scale for case $scaleCase',
          );

          final playButton = find
              .byWidgetPredicate(
                (widget) => widget.runtimeType.toString().contains(
                  'PrimaryPlayerButton',
                ),
              )
              .first;
          expect(playButton, findsOneWidget);
          final playButtonSize = tester.getSize(playButton);
          expect(
            playButtonSize.width,
            greaterThanOrEqualTo(48.0),
            reason: 'play button width for case $scaleCase',
          );
          expect(
            playButtonSize.height,
            greaterThanOrEqualTo(48.0),
            reason: 'play button height for case $scaleCase',
          );

          final playButtonRect = tester.getRect(playButton);
          final viewBottom =
              tester.view.physicalSize.height / tester.view.devicePixelRatio;
          expect(playButtonRect.bottom, lessThan(viewBottom));

          final callsBefore = fakeController.playPauseCallCount;
          expect(
            playButton.hitTestable(),
            findsOneWidget,
            reason: 'play button hittable for case $scaleCase',
          );
          await tester.tap(playButton);
          await tester.pump();
          expect(
            fakeController.playPauseCallCount,
            callsBefore + 1,
            reason:
                'play button tap increments playPauseCallCount for case $scaleCase',
          );

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      },
    );

    testWidgets(
      '14. NowPlayingPage lyrics toggle reduce motion and cover/error retry non-blank',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final sampleTrack = _createSampleTrack();
        final sampleLyrics = [
          const LyricLine(time: Duration(seconds: 0), text: 'First lyric line'),
          const LyricLine(
            time: Duration(seconds: 10),
            text: 'Second lyric line',
          ),
        ];

        final fakeController = _FakePlayerController(
          _createSampleState(
            track: sampleTrack,
            lyrics: sampleLyrics,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository(),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(
                _FakeLibraryPreferencesRepository(),
              ),
              playerControllerProvider.overrideWith(() => fakeController),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: const MusicApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.expand_less_rounded));
        await tester.pump();

        expect(find.byType(NowPlayingPanel), findsOneWidget);

        final coverFinder = find.byType(TrackCoverThumbnail);
        expect(coverFinder, findsOneWidget);
        final coverWidget = tester.widget<TrackCoverThumbnail>(
          coverFinder.first,
        );
        expect(coverWidget.title, isNotEmpty);
        expect(coverWidget.subtitle, isNotEmpty);

        final artworkStage = find
            .byWidgetPredicate(
              (widget) =>
                  widget.runtimeType.toString().contains('ArtworkStage'),
            )
            .first;
        await tester.tap(artworkStage);
        await tester.pump();

        expect(
          find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString().contains('LyricsPanel'),
          ),
          findsOneWidget,
        );

        fakeController.emitState(
          _createSampleState(
            track: sampleTrack,
            lyrics: sampleLyrics,
            position: const Duration(seconds: 12),
            isPlaying: true,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        fakeController.emitState(
          PlayerViewState(
            currentTrack: _createSampleState(
              track: sampleTrack,
              lyrics: [],
              position: Duration.zero,
              isPlaying: false,
              duration: const Duration(minutes: 3),
            ).currentTrack,
            isPlaying: false,
            processingState: ProcessingState.ready,
            position: Duration.zero,
            bufferedPosition: const Duration(seconds: 45),
            duration: const Duration(minutes: 3),
            playlist: const [],
            currentIndex: -1,
            playbackMode: PlayerPlaybackMode.list,
            lyrics: [],
            lyricsSource: PlayerLyricsSource.none,
            cacheSegments: const [],
            errorMessage: 'Playback failed',
            canRetry: true,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(NowPlayingPanel)),
        )!;
        final retryButton = find.ancestor(
          of: find.text(l10n.retryAction),
          matching: find.byType(FilledButton),
        );
        expect(retryButton, findsOneWidget);
        final retryRect = tester.getRect(retryButton);
        expect(retryRect.width, greaterThanOrEqualTo(48.0));
        expect(retryRect.height, greaterThanOrEqualTo(48.0));

        await tester.tap(retryButton);
        await tester.pump();
        expect(fakeController.playCallCount, greaterThan(0));
      },
    );

    testWidgets(
      '15. Song lists (all/favorites/liked) padding, cover size, tap targets, narrow screen more menu, font scaling',
      (tester) async {
        addTearDown(() => tester.view.reset());

        final songs = List.generate(
          50,
          (i) => LibrarySong(
            id: 'song-$i',
            sourceId: 'src-1',
            sourceName: 'WebDAV',
            title: 'Song Title $i with a very long name to test overflow',
            fileName: 'song-$i.flac',
            remotePath: '/music/song-$i.flac',
            albumTitle: 'Album $i',
            artistName: 'Artist $i',
            directoryPath: '/music',
            folderAlbumTitle: 'Album $i',
            folderArtistName: 'Artist $i',
          ),
        );
        final catalog = LibraryCatalogState(
          tracks: songs,
          favoriteTrackIds: {'song-0', 'song-1'},
          likedTrackIds: {'song-2', 'song-3'},
        );

        for (final section in [
          LibraryCollectionSection.allSongs,
          LibraryCollectionSection.favorites,
          LibraryCollectionSection.liked,
        ]) {
          for (final size in [
            const Size(360, 760),
            const Size(412, 915),
            const Size(900, 600),
            const Size(320, 568),
          ]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;

            final container = ProviderContainer(
              overrides: [
                libraryCatalogControllerProvider.overrideWith(
                  () => _SyncCatalogController(catalog),
                ),
                folderArtworkProvider.overrideWith(
                  (ref, request) async => null,
                ),
                playerControllerProvider.overrideWith(
                  () => _FakePlayerController(_createSampleState()),
                ),
              ],
            );

            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(body: LibrarySongsPage(section: section)),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final cardFinders = find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString().contains('SongCard'),
            );
            expect(cardFinders.evaluate().isNotEmpty, isTrue);

            final cardCount = cardFinders.evaluate().length;
            for (var index = 0; index < cardCount && index < 3; index++) {
              final cardFinder = cardFinders.at(index);

              final thumbnailFinder = find.descendant(
                of: cardFinder,
                matching: find.byType(TrackCoverThumbnail),
              );
              final thumbnailWidget = tester.widget<TrackCoverThumbnail>(
                thumbnailFinder,
              );
              expect(thumbnailWidget.size, greaterThanOrEqualTo(48.0));

              final cardRect = tester.getRect(cardFinder);
              expect(cardRect.height, greaterThanOrEqualTo(72.0 - 1e-6));
              expect(
                tester.getRect(thumbnailFinder).left - cardRect.left,
                equals(12.0),
              );

              for (final actionIcon in const [
                Icons.more_horiz_rounded,
                Icons.bookmark_rounded,
                Icons.bookmark_border_rounded,
                Icons.favorite_rounded,
                Icons.favorite_border_rounded,
              ]) {
                final actionIconFinder = find.descendant(
                  of: cardFinder,
                  matching: find.byIcon(actionIcon),
                );
                if (actionIconFinder.evaluate().isEmpty) {
                  continue;
                }
                final actionRect = tester.getRect(
                  find
                      .ancestor(
                        of: actionIconFinder.first,
                        matching: find.byType(InkWell),
                      )
                      .first,
                );
                expect(actionRect.width, greaterThanOrEqualTo(48.0 - 1e-6));
                expect(actionRect.height, greaterThanOrEqualTo(48.0 - 1e-6));
              }
            }

            if (size.width < 340) {
              final songCard = cardFinders.evaluate().first.widget;
              expect(songCard.key, isNotNull);
            }

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 50));
            container.dispose();
          }

          for (final textScale in [1.3, 2.0]) {
            tester.view.physicalSize = const Size(412, 915);
            tester.view.devicePixelRatio = 1.0;

            final container = ProviderContainer(
              overrides: [
                libraryCatalogControllerProvider.overrideWith(
                  () => _SyncCatalogController(catalog),
                ),
                folderArtworkProvider.overrideWith(
                  (ref, request) async => null,
                ),
                playerControllerProvider.overrideWith(
                  () => _FakePlayerController(_createSampleState()),
                ),
              ],
            );

            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: MaterialApp(
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Scaffold(body: LibrarySongsPage(section: section)),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            final cardFinders = find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString().contains('SongCard'),
            );
            expect(cardFinders.evaluate().isNotEmpty, isTrue);

            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 50));
            container.dispose();
          }
        }
      },
    );

    testWidgets(
      '16. AlbumsPage grouping mode persists across rebuild and survives loading preference race',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final sampleSource = const SourceProfile(
          id: 'src-1',
          name: 'Test Source',
          protocol: SourceProtocol.webdav,
          baseUrl: 'http://example.com',
          username: 'user',
          password: 'pwd',
          rootPath: '/',
        );
        final sampleAlbums = List.generate(
          5,
          (i) => LibraryAlbum(
            id: 'album-$i',
            sourceId: 'src-1',
            sourceName: 'Test Source',
            title: 'Album $i',
            artistName: 'Artist $i',
            tracks: [_createSampleLibrarySong(i)],
          ),
        );
        final catalog = LibraryCatalogState(
          tracks: List.generate(5, _createSampleLibrarySong),
          folderAlbums: sampleAlbums,
          folderAlbumsBySource: {'src-1': sampleAlbums},
        );

        final prefsWithMetadata = LibraryPreferences(
          albumGroupingMode: LibraryAlbumGroupingMode.metadata,
        );

        final repo = _FailingLibraryPreferencesRepository(
          prefsWithMetadata,
          (failed) {},
          false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository([sampleSource]),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(repo),
              libraryCatalogControllerProvider.overrideWith(
                () => _SyncCatalogController(catalog),
              ),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AlbumsPage), findsOneWidget);

        final groupingButtonFinder = find.byType(
          SegmentedButton<LibraryAlbumGroupingMode>,
        );
        expect(groupingButtonFinder, findsOneWidget);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlbumsPage)),
        )!;
        await tester.tap(find.text(l10n.folderAlbumsModeLabel));
        await tester.pumpAndSettle();

        var updatedPrefs = await repo.load();
        expect(updatedPrefs.albumGroupingMode, LibraryAlbumGroupingMode.folder);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository([sampleSource]),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(repo),
              libraryCatalogControllerProvider.overrideWith(
                () => _SyncCatalogController(catalog),
              ),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: const MusicApp(),
          ),
        );
        await tester.pumpAndSettle();

        updatedPrefs = await repo.load();
        expect(updatedPrefs.albumGroupingMode, LibraryAlbumGroupingMode.folder);

        final groupingSegment = tester
            .widget<SegmentedButton<LibraryAlbumGroupingMode>>(
              groupingButtonFinder,
            );
        expect(groupingSegment.selected, {LibraryAlbumGroupingMode.folder});

        repo.shouldFailSave = true;
        await tester.tap(find.text(l10n.scrapedAlbumsModeLabel));
        await tester.pumpAndSettle();

        final snackBarFinder = find.byType(SnackBar);
        expect(snackBarFinder, findsOneWidget);

        final snackBar = tester.widget<SnackBar>(snackBarFinder);
        expect(snackBar.content, isA<Text>());
        expect(
          (snackBar.content as Text).data,
          contains('Simulated save failure'),
        );

        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        updatedPrefs = await repo.load();
        expect(updatedPrefs.albumGroupingMode, LibraryAlbumGroupingMode.folder);

        final recheckedGrouping = tester
            .widget<SegmentedButton<LibraryAlbumGroupingMode>>(
              find.byType(SegmentedButton<LibraryAlbumGroupingMode>),
            );
        expect(recheckedGrouping.selected, {LibraryAlbumGroupingMode.folder});
      },
    );

    testWidgets(
      '17. AlbumsPage grouping mode loading preference does not override saved value during async init',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.reset());

        final sampleSource = const SourceProfile(
          id: 'src-1',
          name: 'Test Source',
          protocol: SourceProtocol.webdav,
          baseUrl: 'http://example.com',
          username: 'user',
          password: 'pwd',
          rootPath: '/',
        );
        final sampleAlbums = List.generate(
          5,
          (i) => LibraryAlbum(
            id: 'album-$i',
            sourceId: 'src-1',
            sourceName: 'Test Source',
            title: 'Album $i',
            artistName: 'Artist $i',
            tracks: [_createSampleLibrarySong(i)],
          ),
        );
        final catalog = LibraryCatalogState(
          tracks: List.generate(5, _createSampleLibrarySong),
          folderAlbums: sampleAlbums,
          folderAlbumsBySource: {'src-1': sampleAlbums},
        );

        final savedPrefs = LibraryPreferences(
          albumGroupingMode: LibraryAlbumGroupingMode.metadata,
        );
        var loadCompleter = Completer<LibraryPreferences>();

        final repo = _DelayedLoadRepository(loadCompleter, savedPrefs);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sourceProfileRepositoryProvider.overrideWithValue(
                _FakeSourceProfileRepository([sampleSource]),
              ),
              libraryPreferencesRepositoryProvider.overrideWithValue(repo),
              libraryCatalogControllerProvider.overrideWith(
                () => _SyncCatalogController(catalog),
              ),
              folderArtworkProvider.overrideWith((ref, request) async => null),
            ],
            child: const MusicApp(),
          ),
        );

        await tester.pump();

        expect(find.byType(AlbumsPage), findsOneWidget);

        final groupingButtonFinder = find.byType(
          SegmentedButton<LibraryAlbumGroupingMode>,
        );
        expect(groupingButtonFinder, findsOneWidget);
        var groupingSegment = tester
            .widget<SegmentedButton<LibraryAlbumGroupingMode>>(
              groupingButtonFinder,
            );
        expect(groupingSegment.onSelectionChanged, isNull);

        loadCompleter.complete(savedPrefs);
        await tester.pumpAndSettle();

        groupingSegment = tester
            .widget<SegmentedButton<LibraryAlbumGroupingMode>>(
              groupingButtonFinder,
            );
        expect(groupingSegment.onSelectionChanged, isNotNull);
        expect(groupingSegment.selected, {LibraryAlbumGroupingMode.metadata});
      },
    );
  });
}
