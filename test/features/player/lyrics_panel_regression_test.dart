import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/features/library/application/library_catalog_controller.dart';
import 'package:music/features/library/presentation/folder_artwork_provider.dart';
import 'package:music/features/player/application/player_controller.dart';
import 'package:music/features/player/presentation/widgets/now_playing_panel.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';

class _FakePlayerController extends PlayerController {
  _FakePlayerController(this._initialState);

  final PlayerViewState _initialState;
  int seekAndPlayCallCount = 0;
  Duration? lastSeekPosition;

  @override
  PlayerViewState build() => _initialState;

  @override
  Future<void> seekAndPlay(Duration position) async {
    seekAndPlayCallCount++;
    lastSeekPosition = position;
  }
}

class _SyncCatalogController extends LibraryCatalogController {
  @override
  Future<LibraryCatalogState> build() {
    return SynchronousFuture(const LibraryCatalogState());
  }
}

class _SyncAppSettingsController extends AppSettingsController {
  @override
  Future<LibraryPreferences> build() {
    return SynchronousFuture(const LibraryPreferences());
  }
}

PlayableTrack _track() {
  return PlayableTrack(
    id: 'lyrics-track',
    sourceId: 'source-1',
    title: 'Lyrics Regression',
    artistName: 'Tester',
    albumTitle: 'Fixtures',
    sourceName: 'Local',
    remotePath: '/music/lyrics-regression.flac',
    audioSource: AudioSource.uri(Uri.parse('https://example.com/audio.mp3')),
  );
}

PlayerViewState _state(List<LyricLine> lyrics) {
  return PlayerViewState(
    currentTrack: _track(),
    isPlaying: false,
    processingState: ProcessingState.ready,
    position: Duration.zero,
    bufferedPosition: Duration.zero,
    duration: const Duration(minutes: 6),
    playlist: const [],
    currentIndex: -1,
    playbackMode: PlayerPlaybackMode.list,
    lyrics: lyrics,
    lyricsSource: lyrics.isEmpty
        ? PlayerLyricsSource.none
        : PlayerLyricsSource.embeddedTag,
    cacheSegments: const [],
  );
}

List<LyricLine> _allZeroLyrics() {
  return List<LyricLine>.generate(
    24,
    (index) => LyricLine(
      time: Duration.zero,
      text: 'Untimed line ${index + 1}',
    ),
  );
}

List<LyricLine> _timestampedLyrics() {
  const seconds = [
    0,
    15,
    30,
    45,
    60,
    75,
    90,
    105,
    120,
    135,
    150,
    165,
    180,
    195,
    210,
    225,
    240,
    255,
    270,
    285,
  ];
  return [
    for (var index = 0; index < seconds.length; index++)
      LyricLine(
        time: Duration(seconds: seconds[index]),
        text: 'Timed line ${index + 1}',
      ),
  ];
}

Future<_FakePlayerController> _pumpPanel(
  WidgetTester tester, {
  required PlayerViewState state,
  required Locale locale,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = _FakePlayerController(state);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerControllerProvider.overrideWith(() => controller),
        libraryCatalogControllerProvider.overrideWith(
          _SyncCatalogController.new,
        ),
        appSettingsControllerProvider.overrideWith(
          _SyncAppSettingsController.new,
        ),
        folderArtworkProvider.overrideWith((ref, request) async => null),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: NowPlayingPanel()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Finder _lyricsRegion() => find.byKey(const Key('player-lyrics-region'));

Finder _lyricsList() {
  return find.descendant(of: _lyricsRegion(), matching: find.byType(ListView));
}

ScrollPosition _lyricsScrollPosition(WidgetTester tester) {
  final scrollable = find.descendant(
    of: _lyricsRegion(),
    matching: find.byType(Scrollable),
  );
  expect(scrollable, findsOneWidget);
  return tester.state<ScrollableState>(scrollable).position;
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

Finder _scrubberTimestamp() {
  return find.descendant(
    of: _lyricsRegion(),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data!),
    ),
  );
}

Future<void> _expectScrollsWithoutScrubber(
  WidgetTester tester, {
  required String notice,
}) async {
  final region = _lyricsRegion();
  expect(region, findsOneWidget);

  final noticeFinder = find.descendant(
    of: region,
    matching: find.text(notice),
  );
  expect(
    noticeFinder,
    findsOneWidget,
    reason: 'localized untimed notice must be visible',
  );
  expect(
    find.descendant(of: region, matching: find.text('00:00')),
    findsNothing,
    reason: 'untimed lyrics must not render a 00:00 seek scrubber',
  );
  expect(
    find.descendant(of: region, matching: find.byType(IconButton)),
    findsNothing,
    reason: 'untimed lyrics must not render the scrubber play button',
  );

  final position = _lyricsScrollPosition(tester);
  expect(
    position.maxScrollExtent,
    greaterThan(0),
    reason: 'untimed lyrics must remain vertically scrollable',
  );

  await tester.drag(_lyricsList(), const Offset(0, -320));
  await tester.pumpAndSettle();

  expect(
    position.pixels,
    greaterThan(0),
    reason: 'untimed lyrics must actually scroll on drag',
  );
  expect(
    noticeFinder,
    findsOneWidget,
    reason: 'the untimed notice stays pinned while the lyrics scroll',
  );
  expect(
    find.descendant(of: region, matching: find.text('00:00')),
    findsNothing,
    reason: 'scrolling untimed lyrics must never reveal a 00:00 scrubber',
  );
  expect(
    find.descendant(of: region, matching: find.byType(IconButton)),
    findsNothing,
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'all-zero untimed lyrics scroll without a 00:00 scrubber and show English notice',
    (tester) async {
      await _pumpPanel(
        tester,
        state: _state(_allZeroLyrics()),
        locale: const Locale('en'),
      );

      await _expectScrollsWithoutScrubber(
        tester,
        notice: 'Timed lyrics unavailable',
      );
    },
  );

  testWidgets(
    'all-zero untimed lyrics use the localized Chinese notice',
    (tester) async {
      await _pumpPanel(
        tester,
        state: _state(_allZeroLyrics()),
        locale: const Locale('zh'),
      );

      await _expectScrollsWithoutScrubber(tester, notice: '暂无时间轴歌词');
    },
  );

  testWidgets(
    'timestamped lyrics keep the scrubber and seek to the scrolled line',
    (tester) async {
      final controller = await _pumpPanel(
        tester,
        state: _state(_timestampedLyrics()),
        locale: const Locale('en'),
      );

      final region = _lyricsRegion();
      expect(region, findsOneWidget);

      final position = _lyricsScrollPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.drag(_lyricsList(), const Offset(0, -420));
      await tester.pumpAndSettle();

      expect(position.pixels, greaterThan(0));

      final opacityFinder = find.descendant(
        of: region,
        matching: find.byType(AnimatedOpacity),
      );
      expect(opacityFinder, findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(opacityFinder).opacity,
        1.0,
        reason: 'the scrubber must become visible after the user scrolls',
      );

      final timestampFinder = _scrubberTimestamp();
      expect(timestampFinder, findsOneWidget);
      final timestampLabel = tester.widget<Text>(timestampFinder).data!;
      expect(
        timestampLabel,
        isNot('00:00'),
        reason: 'the scrubber must track the scrolled line, not zero',
      );

      final playFinder = find.descendant(
        of: region,
        matching: find.byTooltip('Play'),
      );
      expect(playFinder, findsOneWidget);

      await tester.tap(playFinder);
      await tester.pump();

      expect(controller.seekAndPlayCallCount, 1);
      final seekPosition = controller.lastSeekPosition;
      expect(seekPosition, isNotNull);
      expect(
        seekPosition,
        greaterThan(Duration.zero),
        reason: 'timestamped lyrics must seek to the scrolled timestamp',
      );
      expect(
        _formatDuration(seekPosition!),
        timestampLabel,
        reason: 'seek target must match the visible scrubber timestamp',
      );
    },
  );
}
