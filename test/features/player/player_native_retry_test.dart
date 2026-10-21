// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_service_platform_interface/audio_service_platform_interface.dart';
import 'package:audio_service_platform_interface/method_channel_audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music/core/audio/player_service.dart';
import 'package:music/core/audio/system_audio_handler.dart';
import 'package:music/core/database/isar_manager.dart';
import 'package:music/core/models/app_preferences.dart';
import 'package:music/core/models/library_song.dart';
import 'package:music/core/models/playback_cache_settings.dart';
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/core/storage/player_session_repository.dart';
import 'package:music/features/library/application/library_catalog_controller.dart';
import 'package:music/features/player/application/player_controller.dart';
import 'package:music/features/scraper/application/scraping_provider.dart' as scraping;
import 'package:music/features/scraper/data/musicbrainz_scraper.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';
import 'package:music/features/sources/application/music_source_registry.dart';
import 'package:music/features/scraper/domain/metadata_scraper.dart';
import 'package:music/features/sources/application/source_session_manager.dart';
import 'package:music/features/sources/application/sources_controller.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_provider.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';
import 'package:music/features/sources/domain/music_source.dart';

const _clientChannelName = 'com.ryanheise.audio_service.client.methods';
const _handlerChannelName = 'com.ryanheise.audio_service.handler.methods';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeAudioPlayer extends Mock implements AudioPlayer {
  _FakeAudioPlayer() {
    when(() => errorStream).thenAnswer((_) => errorController.stream);
    when(() => playing).thenAnswer((_) => _playing);
    when(() => position).thenAnswer((_) => _position);
    when(() => bufferedPosition).thenReturn(Duration.zero);
    when(() => duration).thenReturn(_loadDuration);
    when(() => processingState).thenReturn(ProcessingState.ready);
    when(
      () => playerStateStream,
    ).thenAnswer((_) => const Stream<PlayerState>.empty());
    when(
      () => positionStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(
      () => durationStream,
    ).thenAnswer((_) => const Stream<Duration?>.empty());
    when(
      () => bufferedPositionStream,
    ).thenAnswer((_) => const Stream<Duration>.empty());
    when(() => stop()).thenAnswer((_) async {
      _position = Duration.zero;
      _playing = false;
    });
    when(() => pause()).thenAnswer((_) async {
      _playing = false;
    });
    when(() => play()).thenAnswer((_) async {
      playCount++;
      _playing = true;
    });
    when(() => dispose()).thenAnswer((_) async {});
    when(
      () =>
          setAudioSource(any(), initialPosition: any(named: 'initialPosition')),
    ).thenAnswer((invocation) {
      final initial = invocation.namedArguments[#initialPosition] as Duration?;
      final resolved = initial ?? Duration.zero;
      setAudioSourceInitialPositions.add(resolved);
      _position = resolved;
      final armed = _armedPendingLoad;
      if (armed != null) {
        _armedPendingLoad = null;
        _activePendingLoad = armed;
        return armed.future;
      }
      if (failNextLoad) {
        failNextLoad = false;
        return Future<Duration?>.error(
          PlayerException(-1, 'injected load failure', null),
        );
      }
      return Future<Duration?>.value(_loadDuration);
    });
    when(() => seek(any())).thenAnswer((invocation) async {
      _position =
          invocation.positionalArguments.first as Duration? ?? Duration.zero;
    });
  }

  static const Duration _loadDuration = Duration(minutes: 3);
  final StreamController<PlayerException> errorController =
      StreamController<PlayerException>.broadcast(sync: true);
  final List<Duration> setAudioSourceInitialPositions = <Duration>[];
  Duration _position = Duration.zero;
  bool _playing = false;
  int playCount = 0;
  bool failNextLoad = false;
  Completer<Duration?>? _armedPendingLoad;
  Completer<Duration?>? _activePendingLoad;

  void emitRuntimeError(PlayerException error) => errorController.add(error);

  void simulateBackendPosition(Duration position) => _position = position;

  void armPendingLoad() {
    _armedPendingLoad = Completer<Duration?>();
  }

  void completePendingLoad([Duration? value]) {
    final completer = _activePendingLoad ?? _armedPendingLoad;
    _armedPendingLoad = null;
    _activePendingLoad = null;
    completer?.complete(value);
  }

  void failPendingLoad(Object error) {
    final completer = _activePendingLoad ?? _armedPendingLoad;
    _armedPendingLoad = null;
    _activePendingLoad = null;
    completer?.completeError(error);
  }

  Future<void> close() => errorController.close();
}

class _FakePlaybackCache implements WebDavPlaybackCache {
  @override
  int retainedMemoryBytes = 0;
  final StreamController<PlaybackCacheSnapshot> _controller =
      StreamController<PlaybackCacheSnapshot>.broadcast();

  @override
  void applySettings(PlaybackCacheSettings settings) {}

  @override
  void setActivePlaybackTrack(String? trackId) {}

  @override
  Stream<PlaybackCacheSnapshot> get snapshotStream => _controller.stream;

  @override
  PlaybackCacheSnapshot? snapshotForTrack(String trackId) => null;

  @override
  Stream<List<PlaybackCacheInventoryItem>> watchCachedTracks() =>
      const Stream.empty();

  @override
  Future<List<PlaybackCacheInventoryItem>> listCachedTracks() async =>
      const [];

  @override
  Future<AudioSource?> createCachedAudioSource({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  }) async => null;

  @override
  Future<void> prefetchEntry({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  }) async {}

  @override
  Future<WebDavCachedRange?> readCachedRange({
    required RemoteEntry entry,
    required int start,
    int? end,
  }) async => null;

  @override
  Future<String?> persistentFilePathForEntry(RemoteEntry entry) async => null;

  @override
  Stream<List<int>> wrapPlaybackStream({
    required RemoteEntry entry,
    required Stream<List<int>> stream,
    required int offset,
    required int? requestedEnd,
    required int? expectedLength,
  }) =>
      stream;

  @override
  Future<void> clearAllCachedData() async {}

  @override
  Future<void> clearMemoryCachedData() async {}

  @override
  Future<void> removeCachedTracks(Set<String> trackIds) async {}

  @override
  Future<void> dispose() async => _controller.close();
}

class _FakeSessionRepository implements PlayerSessionRepository {
  _FakeSessionRepository({this.initialSnapshot});

  final PlayerSessionSnapshot? initialSnapshot;
  final List<PlayerSessionSnapshot> savedSnapshots = <PlayerSessionSnapshot>[];
  PlayerSessionSnapshot? lastSaved;

  @override
  Future<PlayerSessionSnapshot?> load() async => initialSnapshot;

  @override
  Future<void> save(PlayerSessionSnapshot snapshot) async {
    savedSnapshots.add(snapshot);
    lastSaved = snapshot;
  }

  @override
  Future<void> clear() async {}
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 5),
  String? describe,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(describe ?? 'Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

class _RetryHarness {
  _RetryHarness._({
    required this.player,
    required this.source,
    required this.cache,
    required this.sessionRepo,
    required this.service,
    required this.container,
    required this.controller,
  });

  final _FakeAudioPlayer player;
  final _FakeMusicSource source;
  final _FakePlaybackCache cache;
  final _FakeSessionRepository sessionRepo;
  final PlayerService service;
  final ProviderContainer container;
  final PlayerController controller;

  static _RetryHarness create(
    SourceProfile profile, {
    PlayerSessionSnapshot? snapshot,
  }) {
    final player = _FakeAudioPlayer();
    final source = _FakeMusicSource(profile);
    final cache = _FakePlaybackCache();
    final sessionRepo = _FakeSessionRepository(initialSnapshot: snapshot);
    final service = PlayerService(player: player);
    final sessionManager = _FakeSessionManager(source);

    final container = ProviderContainer(
      overrides: [
        playerServiceProvider.overrideWithValue(service),
        webDavPlaybackCacheProvider.overrideWithValue(cache),
        playerSessionRepositoryProvider.overrideWithValue(sessionRepo),
        sourcesControllerProvider.overrideWith(
          () => _SyncSourcesController([profile]),
        ),
        musicSourceSessionManagerProvider.overrideWithValue(sessionManager),
        appSettingsControllerProvider.overrideWith(
          () => _SyncAppSettingsController(const LibraryPreferences()),
        ),
        libraryCatalogControllerProvider.overrideWith(
          () => _FakeLibraryCatalogController(),
        ),
        scraping.musicBrainzScraperProvider.overrideWithValue(
          _NoNetworkScraper(),
        ),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await service.dispose();
      await player.close();
      await cache.dispose();
    });

    return _RetryHarness._(
      player: player,
      source: source,
      cache: cache,
      sessionRepo: sessionRepo,
      service: service,
      container: container,
      controller: container.read(playerControllerProvider.notifier),
    );
  }

  void emitRuntimeError() =>
      player.emitRuntimeError(PlayerException(-1, 'runtime failure', null));

  void simulateBackendPosition(Duration position) =>
      player.simulateBackendPosition(position);
}

class _SyncAppSettingsController extends AppSettingsController {
  _SyncAppSettingsController(this._preferences);
  final LibraryPreferences _preferences;

  @override
  Future<LibraryPreferences> build() async =>
      SynchronousFuture<LibraryPreferences>(_preferences);
}

class _SyncSourcesController extends SourcesController {
  _SyncSourcesController(this.profiles);
  final List<SourceProfile> profiles;

  @override
  Future<List<SourceProfile>> build() async =>
      SynchronousFuture<List<SourceProfile>>(profiles);
}

class _FakeLibraryCatalogController extends LibraryCatalogController {
  @override
  Future<LibraryCatalogState> build() async =>
      SynchronousFuture<LibraryCatalogState>(const LibraryCatalogState());
}

class _NoNetworkScraper extends MusicBrainzScraper {
  @override
  Future<ScrapedMetadata?> scrapeTrackInfo({
    required String title,
    String? artist,
    String? album,
    AppLocalePreference? localePreference,
    FutureOr<void> Function(ScrapedMetadata metadata)? onUpdate,
  }) async => null;
}

class _FakeMusicSource extends MusicSource {
  _FakeMusicSource(this.profile);

  @override
  final SourceProfile profile;
  final List<String> buildCalls = <String>[];
  final Set<String> failPaths = <String>{};
  bool failFirstForPath = false;
  String? failFirstPath;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<DirectoryListing> listFiles(String path) async =>
      const DirectoryListing(entries: []);

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) async {
    buildCalls.add(entry.path);
    final failThisCall = failPaths.contains(entry.path) ||
        (failFirstForPath &&
            failFirstPath == entry.path &&
            buildCalls.where((p) => p == entry.path).length == 1);
    if (failThisCall) {
      throw StateError('build failed for ${entry.path}');
    }
    return PlayableTrack(
      id: entry.uniqueId,
      sourceId: entry.sourceId,
      title: 'Built ${entry.title}',
      sourceName: profile.name,
      remotePath: entry.path,
      audioSource: AudioSource.uri(
        Uri.parse('https://example.com/${entry.path}'),
      ),
      artistName: 'Artist',
    );
  }

  @override
  Future<String?> readTextFile(String path) async => null;

  @override
  Future<Uint8List?> readBinaryFile(String path) async => null;
}

class _FakeSessionManager extends MusicSourceSessionManager {
  _FakeSessionManager(this.source)
      : super(MusicSourceRegistry(const []));

  final _FakeMusicSource source;

  @override
  Future<MusicSource> get(SourceProfile profile) async => source;

  @override
  Future<void> invalidate(String sourceId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final supportDirectory = Directory.systemTemp.createTempSync(
    'omnitune_native_retry_',
  );
  final clientChannel = const MethodChannel(_clientChannelName);
  final handlerChannel = const MethodChannel(_handlerChannelName);

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => supportDirectory.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clientChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(handlerChannel, (call) async => null);

    AudioServicePlatform.instance = MethodChannelAudioService();

    SharedPreferences.setMockInitialValues({});
    await IsarManager.initialize();
    registerFallbackValue(
      AudioSource.uri(Uri.parse('https://example.com/audio.mp3')),
    );
    registerFallbackValue(Duration.zero);

    await initializeSystemAudioHandler();
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clientChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(handlerChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (supportDirectory.existsSync()) {
      supportDirectory.deleteSync(recursive: true);
    }
  });

  final profile = SourceProfile(
    id: 'source-1',
    name: 'Source One',
    protocol: SourceProtocol.webdav,
    baseUrl: 'http://example.com/dav/',
    username: 'user',
    password: 'pass',
    rootPath: '/',
  );

  test(
    'native retry: build failure then handler.play retries and stop clears',
    () async {
      final player = _MockAudioPlayer();
      when(() => player.errorStream)
          .thenAnswer((_) => const Stream<PlayerException>.empty());
      when(() => player.playing).thenReturn(false);
      when(() => player.position).thenReturn(Duration.zero);
      when(() => player.processingState).thenReturn(ProcessingState.idle);
      when(() => player.bufferedPosition).thenReturn(Duration.zero);
      when(() => player.duration).thenReturn(null);
      when(() => player.playerStateStream)
          .thenAnswer((_) => const Stream<PlayerState>.empty());
      when(() => player.positionStream)
          .thenAnswer((_) => const Stream<Duration>.empty());
      when(() => player.durationStream)
          .thenAnswer((_) => const Stream<Duration?>.empty());
      when(() => player.bufferedPositionStream)
          .thenAnswer((_) => const Stream<Duration>.empty());
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.pause()).thenAnswer((_) async {});
      when(() => player.dispose()).thenAnswer((_) async {});
      when(() => player.setAudioSource(
            any(),
            initialPosition: any(named: 'initialPosition'),
          )).thenAnswer((_) async => const Duration(seconds: 1));
      when(() => player.play()).thenAnswer((_) async {});

      final service = PlayerService(player: player);
      final source = _FakeMusicSource(profile);
      source.failFirstForPath = true;
      source.failFirstPath = '/a.flac';
      final cache = _FakePlaybackCache();
      final sessionRepo = _FakeSessionRepository();
      final sessionManager = _FakeSessionManager(source);
      final entry = RemoteEntry(
        sourceId: profile.id,
        name: 'a.flac',
        path: '/a.flac',
        kind: RemoteEntryKind.audio,
      );

      final container = ProviderContainer(
        overrides: [
          playerServiceProvider.overrideWithValue(service),
          webDavPlaybackCacheProvider.overrideWithValue(cache),
          playerSessionRepositoryProvider.overrideWithValue(sessionRepo),
          sourcesControllerProvider.overrideWith(
            () => _SyncSourcesController([profile]),
          ),
          musicSourceSessionManagerProvider.overrideWithValue(sessionManager),
          appSettingsControllerProvider.overrideWith(
            () => _SyncAppSettingsController(const LibraryPreferences()),
          ),
          libraryCatalogControllerProvider.overrideWith(
            () => _FakeLibraryCatalogController(),
          ),
          scraping.musicBrainzScraperProvider.overrideWithValue(
            _NoNetworkScraper(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(service.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      await controller.playEntry(profile: profile, entry: entry);

      expect(controller.state.currentTrack, isNull);
      expect(controller.state.canRetry, isTrue);

      final mediaItem = systemAudioHandler.mediaItem.value;
      expect(mediaItem, isNotNull);
      expect(mediaItem!.id, entry.uniqueId);
      expect(mediaItem.title, entry.title);
      expect(mediaItem.extras?['sourceId'], profile.id);
      expect(mediaItem.extras?['sourceName'], profile.name);
      expect(mediaItem.displayDescription, profile.name);

      final playbackState = systemAudioHandler.playbackState.value;
      expect(playbackState.controls, contains(MediaControl.play));
      expect(playbackState.systemActions, isNot(contains(MediaAction.seek)));

      source.failFirstForPath = false;
      await systemAudioHandler.play();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.state.currentTrack?.id, entry.uniqueId);
      expect(controller.state.canRetry, isFalse);

      await systemAudioHandler.stop();

      expect(systemAudioHandler.mediaItem.value, isNull);
      expect(systemAudioHandler.playbackState.value.controls, isEmpty);
    },
  );

  test(
    'native retry: playEntry resumes confirmed progress after failure',
    () async {
      final harness = _RetryHarness.create(profile);
      final controller = harness.controller;
      final entry = RemoteEntry(
        sourceId: profile.id,
        name: 'a.flac',
        path: '/a.flac',
        kind: RemoteEntryKind.audio,
      );

      await controller.playEntry(profile: profile, entry: entry);
      final trackId = controller.state.currentTrack?.id;
      expect(trackId, isNotNull);

      await controller.seek(const Duration(seconds: 37));
      expect(controller.state.position, const Duration(seconds: 37));

      harness.emitRuntimeError();
      await _waitUntil(
        () => controller.state.canRetry,
        describe: 'canRetry was not set after runtime failure',
      );

      harness.simulateBackendPosition(Duration.zero);
      controller.setPlaybackMode(PlayerPlaybackMode.repeatAll);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.position, const Duration(seconds: 37));

      await controller.play();

      expect(
        harness.player.setAudioSourceInitialPositions.last,
        const Duration(seconds: 37),
      );
      expect(controller.state.currentTrack?.id, trackId);
      expect(controller.state.canRetry, isFalse);
      verify(() => harness.player.play()).called(2);
    },
  );

  test(
    'native retry: library playlist resumes confirmed progress via handler',
    () async {
      final harness = _RetryHarness.create(profile);
      final controller = harness.controller;
      final song = LibrarySong(
        id: '${profile.id}::/music/song.flac',
        sourceId: profile.id,
        sourceName: profile.name,
        title: 'Song One',
        fileName: 'song.flac',
        remotePath: '/music/song.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
      );

      await controller.playLibrarySong(song, playlist: [song]);
      final trackId = controller.state.currentTrack?.id;
      expect(trackId, isNotNull);

      await controller.seek(const Duration(seconds: 37));
      await _waitUntil(
        () =>
            harness.sessionRepo.lastSaved?.position ==
            const Duration(seconds: 37),
        describe: 'confirmed progress was not persisted after seek',
      );

      harness.emitRuntimeError();
      await _waitUntil(
        () => controller.state.canRetry,
        describe: 'canRetry was not set after runtime failure',
      );

      harness.simulateBackendPosition(Duration.zero);
      final savesBefore = harness.sessionRepo.savedSnapshots.length;
      controller.setPlaybackMode(PlayerPlaybackMode.repeatAll);
      await _waitUntil(
        () => harness.sessionRepo.savedSnapshots.length > savesBefore,
        describe: 'session was not persisted after playback mode sync',
      );
      expect(
        harness.sessionRepo.lastSaved?.position,
        const Duration(seconds: 37),
      );
      expect(controller.state.position, const Duration(seconds: 37));

      await systemAudioHandler.play();

      expect(
        harness.player.setAudioSourceInitialPositions.last,
        const Duration(seconds: 37),
      );
      expect(controller.state.currentTrack?.id, trackId);
      expect(controller.state.canRetry, isFalse);
      verify(() => harness.player.play()).called(2);
    },
  );

  test(
    'boundary A: failed reload keeps remembered position for next retry',
    () async {
      final harness = _RetryHarness.create(profile);
      final controller = harness.controller;
      final entry = RemoteEntry(
        sourceId: profile.id,
        name: 'a.flac',
        path: '/a.flac',
        kind: RemoteEntryKind.audio,
      );

      await controller.playEntry(profile: profile, entry: entry);
      final trackId = controller.state.currentTrack?.id;
      expect(trackId, isNotNull);

      await controller.seek(const Duration(seconds: 37));
      harness.emitRuntimeError();
      await _waitUntil(() => controller.state.canRetry);
      harness.simulateBackendPosition(Duration.zero);

      harness.player.failNextLoad = true;
      await controller.play();
      await _waitUntil(() => controller.state.canRetry);
      expect(controller.state.canRetry, isTrue);
      expect(controller.state.position, const Duration(seconds: 37));

      await controller.play();

      final attempts = harness.player.setAudioSourceInitialPositions;
      expect(attempts.length, greaterThanOrEqualTo(3));
      expect(attempts[attempts.length - 2], const Duration(seconds: 37));
      expect(attempts.last, const Duration(seconds: 37));
      expect(controller.state.currentTrack?.id, trackId);
      expect(controller.state.canRetry, isFalse);
    },
  );

  for (final seekBeforeError in [true, false]) {
    test('boundary B: backwards seek7 '
        '${seekBeforeError ? 'before' : 'after'} runtime error', () async {
      final harness = _RetryHarness.create(profile);
      final controller = harness.controller;
      final entry = RemoteEntry(
        sourceId: profile.id,
        name: 'b.flac',
        path: '/b.flac',
        kind: RemoteEntryKind.audio,
      );

      await controller.playEntry(profile: profile, entry: entry);
      final trackId = controller.state.currentTrack?.id;
      expect(trackId, isNotNull);

      await controller.seek(const Duration(seconds: 37));
      if (seekBeforeError) {
        await controller.seek(const Duration(seconds: 7));
      }

      harness.emitRuntimeError();
      await _waitUntil(() => controller.state.canRetry);
      harness.simulateBackendPosition(Duration.zero);

      if (!seekBeforeError) {
        await controller.seek(const Duration(seconds: 7));
      }

      await controller.play();

      expect(
        harness.player.setAudioSourceInitialPositions.last,
        const Duration(seconds: 7),
      );
      expect(controller.state.currentTrack?.id, trackId);
    });
  }

  for (final action in ['pause', 'stop']) {
    test('boundary C: $action during pending retry load', () async {
      final harness = _RetryHarness.create(profile);
      final controller = harness.controller;
      final entry = RemoteEntry(
        sourceId: profile.id,
        name: 'c.flac',
        path: '/c.flac',
        kind: RemoteEntryKind.audio,
      );

      await controller.playEntry(profile: profile, entry: entry);
      await controller.seek(const Duration(seconds: 37));
      harness.emitRuntimeError();
      await _waitUntil(() => controller.state.canRetry);
      harness.simulateBackendPosition(Duration.zero);

      final playBaseline = harness.player.playCount;
      final loadBaseline = harness.player.setAudioSourceInitialPositions.length;

      harness.player.armPendingLoad();
      final retryFuture = controller.play();
      await _waitUntil(
        () => harness.player.setAudioSourceInitialPositions.length >
            loadBaseline,
        describe: 'pending retry load was not invoked',
      );
      harness.simulateBackendPosition(Duration.zero);

      if (action == 'pause') {
        await controller.pause();
      } else {
        await controller.stop();
      }

      harness.player.completePendingLoad(const Duration(minutes: 3));
      await retryFuture;

      expect(harness.player.playCount, playBaseline);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.canRetry, isFalse);
      expect(controller.state.isPlaying, isFalse);
      expect(controller.state.currentTrack, isNull);

      if (action == 'pause') {
        await controller.play();
        expect(
          harness.player.setAudioSourceInitialPositions.last,
          const Duration(seconds: 37),
        );
        expect(harness.player.playCount, playBaseline + 1);
      }
    });
  }

  test(
    'boundary D: pending A retry does not clobber user-selected B',
    () async {
      final harness = _RetryHarness.create(profile);
      final controller = harness.controller;
      final songA = LibrarySong(
        id: '${profile.id}::/music/a.flac',
        sourceId: profile.id,
        sourceName: profile.name,
        title: 'A',
        fileName: 'a.flac',
        remotePath: '/music/a.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
      );
      final songB = LibrarySong(
        id: '${profile.id}::/music/b.flac',
        sourceId: profile.id,
        sourceName: profile.name,
        title: 'B',
        fileName: 'b.flac',
        remotePath: '/music/b.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
      );

      await controller.playLibrarySong(songA, playlist: [songA]);
      final trackAId = controller.state.currentTrack?.id;
      expect(trackAId, songA.id);

      await controller.seek(const Duration(seconds: 37));
      await _waitUntil(
        () =>
            harness.sessionRepo.lastSaved?.position ==
            const Duration(seconds: 37),
        describe: 'confirmed progress was not persisted for A',
      );

      harness.emitRuntimeError();
      await _waitUntil(() => controller.state.canRetry);
      harness.simulateBackendPosition(Duration.zero);

      final loadBaseline = harness.player.setAudioSourceInitialPositions.length;
      harness.player.armPendingLoad();
      final retryA = controller.play();
      await _waitUntil(
        () =>
            harness.player.setAudioSourceInitialPositions.length > loadBaseline,
        describe: 'pending A retry load was not invoked',
      );

      harness.simulateBackendPosition(Duration.zero);
      final aSavesBefore = harness.sessionRepo.savedSnapshots.length;
      controller.setPlaybackMode(PlayerPlaybackMode.repeatAll);
      await _waitUntil(
        () => harness.sessionRepo.savedSnapshots.length > aSavesBefore,
        describe: 'pending A session was not persisted after mode sync',
      );
      expect(
        harness.sessionRepo.lastSaved?.position,
        const Duration(seconds: 37),
      );

      await controller.playLibrarySong(songB, playlist: [songB]);
      await _waitUntil(
        () => controller.state.currentTrack?.id == songB.id,
        describe: 'B did not become the current track',
      );
      expect(harness.player.setAudioSourceInitialPositions.last, Duration.zero);

      await _waitUntil(
        () => harness.sessionRepo.lastSaved?.playlist.first.id == songB.id,
        describe: 'B session was not persisted',
      );
      expect(harness.sessionRepo.lastSaved?.position, Duration.zero);

      final playBaseline = harness.player.playCount;
      harness.player.failPendingLoad(PlayerException(-1, 'late A error', null));
      await retryA;

      expect(controller.state.currentTrack?.id, songB.id);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.canRetry, isFalse);
      expect(harness.player.playCount, playBaseline);
      expect(harness.sessionRepo.lastSaved?.playlist.first.id, songB.id);
    },
  );

  test(
    'native retry: pending retry load publishes playing/pause and media button cancels',
    () async {
      final harness = _RetryHarness.create(profile);
      final controller = harness.controller;
      final entry = RemoteEntry(
        sourceId: profile.id,
        name: 'd.flac',
        path: '/d.flac',
        kind: RemoteEntryKind.audio,
      );

      await controller.playEntry(profile: profile, entry: entry);
      await controller.seek(const Duration(seconds: 37));
      harness.emitRuntimeError();
      await _waitUntil(
        () => controller.state.canRetry,
        describe: 'canRetry was not set after runtime failure',
      );
      harness.simulateBackendPosition(Duration.zero);

      final playBaseline = harness.player.playCount;
      final loadBaseline = harness.player.setAudioSourceInitialPositions.length;

      harness.player.armPendingLoad();
      final retryFuture = controller.play();
      await _waitUntil(
        () =>
            harness.player.setAudioSourceInitialPositions.length > loadBaseline,
        describe: 'pending retry load was not invoked',
      );

      final pendingState = systemAudioHandler.playbackState.value;
      expect(pendingState.playing, isTrue);
      expect(pendingState.controls, contains(MediaControl.pause));

      await systemAudioHandler.click(MediaButton.media);
      await _waitUntil(
        () => !controller.state.isResolvingTrack,
        describe: 'media button pause did not cancel the pending load',
      );

      harness.player.completePendingLoad(const Duration(minutes: 3));
      await retryFuture;

      expect(harness.player.playCount, playBaseline);
      expect(controller.state.isPlaying, isFalse);
      expect(controller.state.currentTrack, isNull);
      expect(controller.state.canRetry, isFalse);

      await controller.play();
      expect(
        harness.player.setAudioSourceInitialPositions.last,
        const Duration(seconds: 37),
      );
    },
  );

  test(
    'native retry: pending library play load publishes playing/pause control',
    () async {
      final harness = _RetryHarness.create(profile);
      final controller = harness.controller;
      final song = LibrarySong(
        id: '${profile.id}::/music/d.flac',
        sourceId: profile.id,
        sourceName: profile.name,
        title: 'D',
        fileName: 'd.flac',
        remotePath: '/music/d.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
      );

      harness.player.armPendingLoad();
      final playFuture = controller.playLibrarySong(song, playlist: [song]);
      await _waitUntil(
        () => harness.player.setAudioSourceInitialPositions.isNotEmpty,
        describe: 'pending library play load was not invoked',
      );

      final pendingState = systemAudioHandler.playbackState.value;
      expect(pendingState.playing, isTrue);
      expect(pendingState.controls, contains(MediaControl.pause));

      harness.player.completePendingLoad(const Duration(minutes: 3));
      await playFuture;

      expect(controller.state.currentTrack?.id, song.id);
    },
  );

  test(
    'native retry: restored paused session keeps system playing false while loading',
    () async {
      final song = LibrarySong(
        id: '${profile.id}::/music/song.flac',
        sourceId: profile.id,
        sourceName: profile.name,
        title: 'Song One',
        fileName: 'song.flac',
        remotePath: '/music/song.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
      );
      final harness = _RetryHarness.create(
        profile,
        snapshot: PlayerSessionSnapshot(
          playlist: [song],
          currentIndex: 0,
          position: const Duration(seconds: 37),
        ),
      );
      final controller = harness.controller;

      harness.player.armPendingLoad();
      await _waitUntil(
        () => harness.player.setAudioSourceInitialPositions.isNotEmpty,
        describe: 'restored session load was not invoked',
      );
      expect(
        harness.player.setAudioSourceInitialPositions.last,
        const Duration(seconds: 37),
      );

      controller.setPlaybackMode(PlayerPlaybackMode.repeatAll);
      await Future<void>.delayed(Duration.zero);

      final loadingState = systemAudioHandler.playbackState.value;
      expect(loadingState.playing, isFalse);
      expect(loadingState.controls, isNot(contains(MediaControl.pause)));

      harness.player.completePendingLoad(const Duration(minutes: 3));
      await _waitUntil(
        () => !controller.state.isResolvingTrack,
        describe: 'restored load did not complete',
      );

      final settledState = systemAudioHandler.playbackState.value;
      expect(settledState.playing, isFalse);
      expect(settledState.controls, isNot(contains(MediaControl.pause)));
      expect(controller.state.isPlaying, isFalse);
      expect(harness.player.playCount, 0);
    },
  );
}
