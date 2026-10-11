import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  PlayerViewState build() => _initialState;

  @override
  Future<void> togglePlayPause() async {
    playPauseCallCount++;
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
    this._initialPreferences = const LibraryPreferences(),
  ]);

  final LibraryPreferences _initialPreferences;

  @override
  Future<LibraryPreferences> load() async => _initialPreferences;

  @override
  Future<void> save(LibraryPreferences preferences) async {}
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
  });
}
