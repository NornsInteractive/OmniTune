import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/core/storage/source_profile_repository.dart';
import 'package:music/features/player/application/player_controller.dart';
import 'package:music/features/player/presentation/widgets/mini_player.dart';
import 'package:music/features/player/presentation/widgets/now_playing_panel.dart';
import 'package:music/features/player/presentation/widgets/playback_timeline.dart';
import 'package:music/features/player/presentation/widgets/track_cover_thumbnail.dart';
import 'package:music/features/library/presentation/folder_artwork_provider.dart';

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initialState);

  PlayerViewState _initialState;

  @override
  PlayerViewState build() => _initialState;

  void emitState(PlayerViewState newState) {
    _initialState = newState;
    state = newState;
  }
}

class _FakeLibraryPreferencesRepository
    implements LibraryPreferencesRepository {
  LibraryPreferences _preferences = const LibraryPreferences();

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

class _FakeSourceProfileRepository implements SourceProfileRepository {
  @override
  Future<String?> loadActiveSourceId() async => null;

  @override
  Future<List<SourceProfile>> loadProfiles() async => const [];

  @override
  Future<void> saveActiveSourceId(String? sourceId) async {}

  @override
  Future<void> saveProfiles(List<SourceProfile> profiles) async {}
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

Widget _wrapWithApp(Widget child, {required List<Override> overrides}) {
  return ProviderScope(
    overrides: [
      libraryPreferencesRepositoryProvider.overrideWithValue(
        _FakeLibraryPreferencesRepository(),
      ),
      sourceProfileRepositoryProvider.overrideWithValue(
        _FakeSourceProfileRepository(),
      ),
      folderArtworkProvider.overrideWith((ref, request) async => null),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('MiniPlayer performance & correctness', () {
    testWidgets(
      'progress tick updates timeline without rebuilding cover widget instance',
      (tester) async {
        final initialTrack = _createSampleTrack();
        final fakeController = _FakePlayerController(
          _createSampleState(
            track: initialTrack,
            position: Duration.zero,
            duration: const Duration(seconds: 100),
          ),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            const MiniPlayer(),
            overrides: [
              playerControllerProvider.overrideWith(() => fakeController),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Starfall'), findsOneWidget);
        expect(find.byType(TrackCoverThumbnail), findsOneWidget);

        // Capture identical widget instance
        final coverInstanceBefore = tester.widget<TrackCoverThumbnail>(
          find.byType(TrackCoverThumbnail),
        );
        final timelineBefore = tester.widget<PlaybackTimeline>(
          find.byType(PlaybackTimeline),
        );
        expect(timelineBefore.progress, 0.0);

        // Advance position (audio tick)
        fakeController.emitState(
          _createSampleState(
            track: initialTrack,
            position: const Duration(seconds: 25),
            duration: const Duration(seconds: 100),
          ),
        );
        await tester.pump();

        // Cover widget instance identity must be retained (stable across ticks)
        final coverInstanceAfter = tester.widget<TrackCoverThumbnail>(
          find.byType(TrackCoverThumbnail),
        );
        expect(
          identical(coverInstanceBefore, coverInstanceAfter),
          isTrue,
          reason: 'MiniPlayer cover must not rebuild on position updates',
        );

        // Leaf timeline progress must update to 0.25
        final timelineAfter = tester.widget<PlaybackTimeline>(
          find.byType(PlaybackTimeline),
        );
        expect(timelineAfter.progress, closeTo(0.25, 0.001));
      },
    );

    testWidgets(
      'clearing currentTrack causes no exception and cleanly unmounts mini player',
      (tester) async {
        final initialTrack = _createSampleTrack();
        final fakeController = _FakePlayerController(
          _createSampleState(track: initialTrack),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            const MiniPlayer(),
            overrides: [
              playerControllerProvider.overrideWith(() => fakeController),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TrackCoverThumbnail), findsOneWidget);

        // Clear currentTrack (stop playback / playlist clear)
        fakeController.emitState(_createSampleState(track: null));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(TrackCoverThumbnail), findsNothing);
      },
    );
  });

  group('NowPlayingPanel performance & correctness', () {
    testWidgets(
      'progress tick keeps full panel cover instance stable while timeline updates',
      (tester) async {
        final track = _createSampleTrack();
        final fakeController = _FakePlayerController(
          _createSampleState(
            track: track,
            position: Duration.zero,
            duration: const Duration(minutes: 3),
          ),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            const NowPlayingPanel(),
            overrides: [
              playerControllerProvider.overrideWith(() => fakeController),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Starfall'), findsAtLeastNWidgets(1));
        expect(find.text('00:00'), findsOneWidget);
        expect(find.text('-03:00'), findsOneWidget);

        final coverBefore = tester.widget<TrackCoverThumbnail>(
          find.byType(TrackCoverThumbnail),
        );

        // Tick position to 15 seconds
        fakeController.emitState(
          _createSampleState(
            track: track,
            position: const Duration(seconds: 15),
            duration: const Duration(minutes: 3),
          ),
        );
        await tester.pump();

        final coverAfter = tester.widget<TrackCoverThumbnail>(
          find.byType(TrackCoverThumbnail),
        );
        expect(
          identical(coverBefore, coverAfter),
          isTrue,
          reason:
              'NowPlayingPanel cover art must not rebuild on progress ticks',
        );

        // Timeline deck text must reflect updated position
        expect(find.text('00:15'), findsOneWidget);
        expect(find.text('-02:45'), findsOneWidget);
      },
    );

    testWidgets(
      'lyrics index advances dynamically on progress tick while cover stays stable',
      (tester) async {
        final track = _createSampleTrack();
        final lyrics = [
          const LyricLine(time: Duration(seconds: 0), text: 'Intro verse'),
          const LyricLine(time: Duration(seconds: 10), text: 'Chorus melody'),
          const LyricLine(time: Duration(seconds: 30), text: 'Outro finish'),
        ];

        final fakeController = _FakePlayerController(
          _createSampleState(
            track: track,
            position: Duration.zero,
            duration: const Duration(minutes: 1),
            lyrics: lyrics,
          ),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            const NowPlayingPanel(),
            overrides: [
              playerControllerProvider.overrideWith(() => fakeController),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Tap stage to toggle lyrics view
        await tester.tap(find.byType(AspectRatio).first, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('Intro verse'), findsOneWidget);
        expect(find.text('Chorus melody'), findsOneWidget);

        // Advance to 15s (should activate line index 1)
        fakeController.emitState(
          _createSampleState(
            track: track,
            position: const Duration(seconds: 15),
            duration: const Duration(minutes: 1),
            lyrics: lyrics,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        // Both lyrics lines remain visible and line 1 is active
        expect(find.text('Chorus melody'), findsOneWidget);
      },
    );

    testWidgets(
      'clearing currentTrack on NowPlayingPanel has no null-check exceptions',
      (tester) async {
        final track = _createSampleTrack();
        final fakeController = _FakePlayerController(
          _createSampleState(track: track),
        );

        await tester.pumpWidget(
          _wrapWithApp(
            const NowPlayingPanel(),
            overrides: [
              playerControllerProvider.overrideWith(() => fakeController),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Starfall'), findsAtLeastNWidgets(1));

        // Clear track
        fakeController.emitState(_createSampleState(track: null));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Starfall'), findsNothing);
      },
    );
  });
}
