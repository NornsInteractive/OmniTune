import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music/core/database/isar_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music/core/audio/player_service.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/core/models/library_song.dart';
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/player_session_repository.dart';
import 'package:music/features/player/application/player_controller.dart';
import 'package:music/features/scraper/data/musicbrainz_scraper.dart';
import 'package:music/features/scraper/domain/metadata_scraper.dart';
import 'package:music/core/models/app_preferences.dart';
import 'package:music/features/scraper/application/scraping_provider.dart' as scraping;
import 'package:music/features/sources/application/source_session_manager.dart';
import 'package:music/features/sources/application/music_source_registry.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_provider.dart';
import 'package:music/features/sources/application/sources_controller.dart';
import 'package:music/core/models/playback_cache_settings.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';
import 'package:music/features/sources/domain/music_source.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakePlaybackCache implements WebDavPlaybackCache {
  @override
  int retainedMemoryBytes = 0;
  String? controlledTrackId;
  Completer<void>? readCompleter;
  Uint8List? controlledBytes;
  int controlledCallCount = 0;
  int controlledBlockCount = 1;
  Object? readError;
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
  Future<List<PlaybackCacheInventoryItem>> listCachedTracks() async => const [];

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
  }) async {
    if (readError != null) {
      throw readError!;
    }
    if (controlledTrackId == null) {
      return null;
    }
    if (entry.uniqueId != controlledTrackId) {
      return null;
    }
    controlledCallCount++;
    if (controlledCallCount <= controlledBlockCount) {
      final completer = readCompleter;
      if (completer != null) {
        await completer.future;
      }
      final bytes = controlledBytes;
      if (bytes != null) {
        return WebDavCachedRange(
          start: start,
          endExclusive: (end ?? start + bytes.length),
          bytes: bytes,
        );
      }
      return null;
    }
    throw StateError('no cached range');
  }

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

// NOTE: WebDavCachedTrack and WebDavPlaybackCache type aliases live under base.
class _FakeSessionRepository implements PlayerSessionRepository {
  int clearCount = 0;
  int saveCount = 0;
  PlayerSessionSnapshot? restoredSnapshot;
  PlayerSessionSnapshot? savedSnapshot;
  final List<PlayerSessionSnapshot> savedSnapshots = [];
  Completer<PlayerSessionSnapshot?>? loadCompleter;
  Duration loadDelay = Duration.zero;

  @override
  Future<PlayerSessionSnapshot?> load() async {
    if (loadCompleter != null) {
      return loadCompleter!.future;
    }
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    return restoredSnapshot;
  }

  @override
  Future<void> save(PlayerSessionSnapshot snapshot) async {
    saveCount++;
    savedSnapshot = snapshot;
    savedSnapshots.add(snapshot);
  }

  @override
  Future<void> clear() async {
    clearCount++;
  }
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

class _PendingSourcesController extends SourcesController {
  _PendingSourcesController(this.profilesCompleter);
  final Completer<List<SourceProfile>> profilesCompleter;

  @override
  Future<List<SourceProfile>> build() async =>
      profilesCompleter.future;
}

class _FakeMusicSource extends MusicSource {
  _FakeMusicSource(this.profile);

  @override
  final SourceProfile profile;
  final List<String> buildCalls = <String>[];
  final Map<String, Duration> buildDelays = <String, Duration>{};
  final Set<String> failPaths = <String>{};
  bool failFirstForPath = false;
  String? failFirstPath;
  int readTextFileCalls = 0;

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
    final delay = buildDelays[entry.path] ?? Duration.zero;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
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
  Future<String?> readTextFile(String path) async {
    readTextFileCalls++;
    return null;
  }

  @override
  Future<Uint8List?> readBinaryFile(String path) async => null;
}

class _FakeSessionManager extends MusicSourceSessionManager {
  _FakeSessionManager(this.source)
      : super(MusicSourceRegistry(const []));

  final _FakeMusicSource source;
  Duration firstGetDelay = Duration.zero;
  int getCallCount = 0;

  @override
  Future<MusicSource> get(SourceProfile profile) async {
    getCallCount++;
    if (getCallCount == 1 && firstGetDelay > Duration.zero) {
      await Future<void>.delayed(firstGetDelay);
    }
    return source;
  }

  @override
  Future<void> invalidate(String sourceId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await IsarManager.initialize();
    registerFallbackValue(
      AudioSource.uri(Uri.parse('https://example.com/audio.mp3')),
    );
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

  test('play Future that never completes still finishes playTrack and sidecar', () async {
    final player = _MockAudioPlayer();
    var playCalls = 0;
    final playCompleter = Completer<void>();
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
    when(() => player.play()).thenAnswer((_) {
      playCalls++;
      return playCompleter.future;
    });

    final service = PlayerService(player: player);
    final source = _FakeMusicSource(profile);
    final cache = _FakePlaybackCache();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    final entry = RemoteEntry(
      sourceId: profile.id,
      name: 'track-a.flac',
      path: '/track-a.flac',
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.playEntry(profile: profile, entry: entry);

    expect(controller.state.currentTrack?.id, entry.uniqueId);
    expect(controller.state.isResolvingTrack, false);
    expect(playCalls, 1);
    expect(source.readTextFileCalls, greaterThanOrEqualTo(1));

    playCompleter.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('A slow then B fast leaves B playing', () async {
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
    source.buildDelays['/a.flac'] = const Duration(milliseconds: 60);
    final cache = _FakePlaybackCache();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    final entryA = RemoteEntry(
      sourceId: profile.id,
      name: 'a.flac',
      path: '/a.flac',
      kind: RemoteEntryKind.audio,
    );
    final entryB = RemoteEntry(
      sourceId: profile.id,
      name: 'b.flac',
      path: '/b.flac',
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    final futureA = controller.playEntry(profile: profile, entry: entryA);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final futureB = controller.playEntry(profile: profile, entry: entryB);
    await futureB;
    await futureA;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(controller.state.currentTrack?.id, entryB.uniqueId);
  });

  test('old load failure does not stop the newer source', () async {
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
    source.buildDelays['/a.flac'] = const Duration(milliseconds: 50);
    source.failPaths.add('/a.flac');
    final cache = _FakePlaybackCache();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    final entryA = RemoteEntry(
      sourceId: profile.id,
      name: 'a.flac',
      path: '/a.flac',
      kind: RemoteEntryKind.audio,
    );
    final entryB = RemoteEntry(
      sourceId: profile.id,
      name: 'b.flac',
      path: '/b.flac',
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    final futureA = controller.playEntry(profile: profile, entry: entryA);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final futureB = controller.playEntry(profile: profile, entry: entryB);
    await futureB;
    await futureA;
    await Future<void>.delayed(const Duration(milliseconds: 70));

    expect(controller.state.currentTrack?.id, entryB.uniqueId);
    expect(controller.state.errorMessage, isNull);
  });

  test('stopping during loading avoids autoplay', () async {
    final player = _MockAudioPlayer();
    var playCalls = 0;
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
    when(() => player.play()).thenAnswer((_) {
      playCalls++;
      return Future<void>.value();
    });

    final service = PlayerService(player: player);
    final source = _FakeMusicSource(profile);
    source.buildDelays['/a.flac'] = const Duration(milliseconds: 50);
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    final future = controller.playEntry(profile: profile, entry: entry);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await controller.stop();
    await future;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(playCalls, 0);
    expect(controller.state.currentTrack, isNull);
    expect(controller.state.isResolvingTrack, false);
  });

  test('build failure then play retries successfully', () async {
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.playEntry(profile: profile, entry: entry);
    expect(controller.state.currentTrack, isNull);
    expect(controller.state.canRetry, isTrue);

    source.failFirstForPath = false;
    await controller.play();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.currentTrack?.id, entry.uniqueId);
    expect(controller.state.canRetry, false);
  });

  test('async playback error is recorded and retryable', () async {
    final player = _MockAudioPlayer();
    final playCompleter = Completer<void>();
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
    when(() => player.play()).thenAnswer((_) => playCompleter.future);

    final service = PlayerService(player: player);
    final source = _FakeMusicSource(profile);
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.playEntry(profile: profile, entry: entry);
    expect(controller.state.currentTrack?.id, entry.uniqueId);

    playCompleter.completeError(StateError('play exploded'));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.state.errorMessage, contains('play exploded'));
    expect(controller.state.canRetry, isTrue);
  });

  test('old service source load failure after B succeeds leaves B playing', () async {
    final player = _MockAudioPlayer();
    final firstSetCompleter = Completer<Duration?>();
    var setCalls = 0;
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
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) {
      setCalls++;
      return setCalls == 1
          ? firstSetCompleter.future
          : Future<Duration?>.value(const Duration(seconds: 1));
    });
    when(() => player.play()).thenAnswer((_) async {});

    final service = PlayerService(player: player);
    final source = _FakeMusicSource(profile);
    final cache = _FakePlaybackCache();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    final entryA = RemoteEntry(
      sourceId: profile.id,
      name: 'a.flac',
      path: '/a.flac',
      kind: RemoteEntryKind.audio,
    );
    final entryB = RemoteEntry(
      sourceId: profile.id,
      name: 'b.flac',
      path: '/b.flac',
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    final futureA = controller.playEntry(profile: profile, entry: entryA);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final futureB = controller.playEntry(profile: profile, entry: entryB);
    await futureB;

    firstSetCompleter.completeError(StateError('late setAudioSource failure'));
    await futureA;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.currentTrack?.id, entryB.uniqueId);
    expect(controller.state.errorMessage, isNull);
  });

  test('slow source session get does not let stale A override B', () async {
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
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) async => const Duration(seconds: 1));
    when(() => player.play()).thenAnswer((_) async {});

    final service = PlayerService(player: player);
    final source = _FakeMusicSource(profile);
    final cache = _FakePlaybackCache();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    sessionManager.firstGetDelay = const Duration(milliseconds: 60);

    final entryA = RemoteEntry(
      sourceId: profile.id,
      name: 'a.flac',
      path: '/a.flac',
      kind: RemoteEntryKind.audio,
    );
    final entryB = RemoteEntry(
      sourceId: profile.id,
      name: 'b.flac',
      path: '/b.flac',
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    final futureA = controller.playEntry(profile: profile, entry: entryA);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    final futureB = controller.playEntry(profile: profile, entry: entryB);
    await futureB;
    await futureA;
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(controller.state.currentTrack?.id, entryB.uniqueId);
  });

  test('delayed session restore cannot override manual play', () async {
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
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) async => const Duration(seconds: 1));
    when(() => player.play()).thenAnswer((_) async {});

    final service = PlayerService(player: player);
    final source = _FakeMusicSource(profile);
    final cache = _FakePlaybackCache();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);

    final loadCompleter = Completer<PlayerSessionSnapshot?>();
    sessionRepo.loadCompleter = loadCompleter;
    sessionRepo.restoredSnapshot = PlayerSessionSnapshot(
      playlist: [
        LibrarySong(
          id: 'old-track',
          sourceId: profile.id,
          sourceName: profile.name,
          title: 'Old Track',
          fileName: 'old.flac',
          remotePath: '/old.flac',
          albumTitle: 'Album',
          artistName: 'Artist',
          directoryPath: '/',
          folderAlbumTitle: '',
          folderArtistName: '',
        ),
      ],
      currentIndex: 0,
      playbackMode: 'list',
      position: const Duration(seconds: 3),
    );

    final manualEntry = RemoteEntry(
      sourceId: profile.id,
      name: 'manual.flac',
      path: '/manual.flac',
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final manualFuture = controller.playEntry(profile: profile, entry: manualEntry);
    await manualFuture;

    loadCompleter.complete(sessionRepo.restoredSnapshot);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.state.currentTrack?.id, manualEntry.uniqueId);
  });

  test('delayed profile lookup before source.get: playLibrarySong starts before _profileForSong awaits', () async {
    // 1. Set up profiles
    final profile = SourceProfile(
      id: 'source-1',
      name: 'Source One',
      protocol: SourceProtocol.webdav,
      baseUrl: 'http://example.com/dav/',
      username: 'user',
      password: 'pass',
      rootPath: '/',
    );

    final knownProfile = SourceProfile(
      id: 'source-2',
      name: 'Source Two',
      protocol: SourceProtocol.webdav,
      baseUrl: 'http://example.com/dav/',
      username: 'user',
      password: 'pass',
      rootPath: '/',
    );

    // 2. Create a pending completer for profiles (simulates delayed source build)
    final profilesCompleter = Completer<List<SourceProfile>>();

    // 3. Create fake source that tracks build calls
    final source = _FakeMusicSource(knownProfile);

    // 4. Create session manager with the source
    final sessionManager = _FakeSessionManager(source);

    // 5. Set up mock AudioPlayer
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

// 6. Create entries
    final entryB = RemoteEntry(
      sourceId: knownProfile.id,
      name: 'b.flac',
      path: '/b.flac',
      kind: RemoteEntryKind.audio,
    );

    // 6. Create LibrarySong for playLibrarySong
    final librarySongA = LibrarySong(
      id: '${profile.id}::/a.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'A',
      fileName: 'a.flac',
      remotePath: '/a.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
    );

// 7. Set up the provider container with pending SourcesController build
    // Create a subclass that returns a pending Completer from build()
    final pendingSourcesController = _PendingSourcesController(profilesCompleter);

    final container = ProviderContainer(
      overrides: [
        sourcesControllerProvider.overrideWith(
          () => pendingSourcesController,
        ),
        playerServiceProvider.overrideWithValue(
          PlayerService(player: player),
        ),
        webDavPlaybackCacheProvider.overrideWithValue(_FakePlaybackCache()),
        playerSessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
        musicSourceSessionManagerProvider.overrideWithValue(sessionManager),
        appSettingsControllerProvider.overrideWith(
          () => _SyncAppSettingsController(const LibraryPreferences()),
        ),
      ],
    );
    addTearDown(container.dispose);

    // 8. Get the controller
    final controller = container.read(playerControllerProvider.notifier);

    // 9. Start controller.playLibrarySong(A); ensure it is waiting for profiles
    // (source.buildCalls still empty because _profileForSong awaits the pending future)
    final playLibrarySongFuture = controller.playLibrarySong(librarySongA, playlist: [librarySongA]);
    await Future<void>.delayed(Duration.zero); // yield event loop so A reaches pending profile lookup
    expect(source.buildCalls, isEmpty);

    // 10. While profiles remain pending, await controller.playEntry(profile: known profile, entry:B);
    // this direct call can finish without reading profiles (goes through musicSourceSessionManager.get,
    // not _profileForSong which awaits sourcesControllerProvider.future).
    // Assert current B.
    await controller.playEntry(profile: knownProfile, entry: entryB);
    expect(controller.state.currentTrack?.id, entryB.uniqueId);

    // 11. Complete profiles with valid profile list (both source-1 and source-2)
    // so old A lookup can succeed; without profile, A's build would merely fail.
    profilesCompleter.complete([profile, knownProfile]);
    await Future<void>.delayed(Duration.zero);

    // 12. Assert still B, source.buildCalls contains ONLY B path, noerror.
    // This proves serial starts before _profileForSong awaits;
    // existing delayed source.get test does NOT cover it.
    // The old playLibrarySong operation will now complete because _isCurrentRequest
    // check fails (playEntry set a newer request serial), discarding A's results.
    await playLibrarySongFuture;
    expect(controller.state.currentTrack?.id, entryB.uniqueId);
    expect(source.buildCalls, equals(['/b.flac']));
  });
  test('old pending source play does not overwrite newly persisted session', () async {
    final player = _MockAudioPlayer();
    final oldPlayCompleter = Completer<void>();
    var playCalls = 0;
    when(() => player.errorStream)
        .thenAnswer((_) => const Stream<PlayerException>.empty());
    when(() => player.playing).thenReturn(false);
    when(() => player.position).thenReturn(Duration(milliseconds: 38000));
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
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) async => const Duration(seconds: 1));
    when(() => player.play()).thenAnswer((_) {
      playCalls++;
      return playCalls == 1 ? oldPlayCompleter.future : Future<void>.value();
    });

    final service = PlayerService(player: player);
    final source = _FakeMusicSource(profile);
    final cache = _FakePlaybackCache();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);

    final songA = LibrarySong(
      id: 'source-1::/a.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'A',
      fileName: 'a.flac',
      remotePath: '/a.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
    );
    final songB = LibrarySong(
      id: 'source-1::/b.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'B',
      fileName: 'b.flac',
      remotePath: '/b.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
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
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.playLibrarySong(songA, playlist: [songA, songB]);

    final savedBefore = sessionRepo.saveCount;

    final futureB = controller.playLibrarySong(songB, playlist: [songA, songB]);
    await futureB;

    expect(controller.state.currentTrack?.id, songB.id);
    expect(
      sessionRepo.savedSnapshot!.playlist.map((song) => song.id),
      ['source-1::/a.flac', 'source-1::/b.flac'],
    );
    expect(sessionRepo.savedSnapshot!.currentIndex, 1);
    expect(sessionRepo.savedSnapshot!.position, Duration(milliseconds: 38000));

    oldPlayCompleter.complete();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(
      sessionRepo.savedSnapshot!.playlist.map((song) => song.id),
      ['source-1::/a.flac', 'source-1::/b.flac'],
    );
    expect(sessionRepo.savedSnapshot!.currentIndex, 1);
    expect(sessionRepo.savedSnapshot!.position, Duration(milliseconds: 38000));

    expect(sessionRepo.saveCount, savedBefore + 1);
    expect(sessionRepo.savedSnapshot?.playlist, isNotEmpty);
    expect(
      sessionRepo.savedSnapshot!.playlist[sessionRepo.savedSnapshot!.currentIndex].id,
      songB.id,
    );
    // Position persisted as 38s should remain unchanged after old play future completes.
    expect(
      sessionRepo.savedSnapshot!.position,
      Duration(milliseconds: 38000),
    );
  });
  test('old A embedded metadata does not overwrite B', () async {
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
    final cache = _FakePlaybackCache()
      ..controlledTrackId = 'source-1::/track-a.flac'
      ..readCompleter = Completer<void>()
      ..controlledBytes = _id3WithLyrics('OLD A LYRICS');
    await IsarManager.clearAllMetadata();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    final songA = LibrarySong(
      id: 'source-1::/track-a.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'A',
      fileName: 'track-a.flac',
      remotePath: '/track-a.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
    );
    final songB = LibrarySong(
      id: 'source-1::/track-b.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'B',
      fileName: 'track-b.flac',
      remotePath: '/track-b.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
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
        scraping.musicBrainzScraperProvider.overrideWithValue(
          _FakeMusicBrainzScraper(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.playLibrarySong(songA, playlist: [songA, songB]);
    for (var i = 0; i < 50 && cache.controlledCallCount < 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cache.controlledCallCount, 1);

    final futureB = controller.playLibrarySong(songB, playlist: [songA, songB]);
    await futureB;
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.state.currentTrack?.id, songB.id);
    expect(
      controller.state.lyrics.map((line) => line.text).join(' '),
      isNot(contains('OLD A LYRICS')),
    );

    cache.readCompleter!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(controller.state.currentTrack?.id, songB.id);
    expect(
      controller.state.lyrics.map((line) => line.text).join(' '),
      isNot(contains('OLD A LYRICS')),
    );
    final metadataA = IsarManager.getMetadata(songA.id);
    expect(metadataA?.autoScrapedLyrics, 'OLD A LYRICS');
  });

  test('old A embedded metadata after stop stays cleared', () async {
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
    final cache = _FakePlaybackCache()
      ..controlledTrackId = 'source-1::/track-a.flac'
      ..readCompleter = Completer<void>()
      ..controlledBytes = _id3WithLyrics('OLD A LYRICS');
    await IsarManager.clearAllMetadata();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    final songA = LibrarySong(
      id: 'source-1::/track-a.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'A',
      fileName: 'track-a.flac',
      remotePath: '/track-a.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
    );
    final songB = LibrarySong(
      id: 'source-1::/track-b.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'B',
      fileName: 'track-b.flac',
      remotePath: '/track-b.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
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
        scraping.musicBrainzScraperProvider.overrideWithValue(
          _FakeMusicBrainzScraper(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.playLibrarySong(songA, playlist: [songA, songB]);
    for (var i = 0; i < 50 && cache.controlledCallCount < 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cache.controlledCallCount, 1);

    await controller.stop();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.currentTrack, isNull);
    expect(controller.state.lyrics, isEmpty);

    cache.readCompleter!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(controller.state.currentTrack, isNull);
    expect(controller.state.lyrics, isEmpty);
    final metadataA = IsarManager.getMetadata(songA.id);
    expect(metadataA?.autoScrapedLyrics, 'OLD A LYRICS');
  });

  test('old A embedded metadata does not win after A-B-A', () async {
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
    final cache = _FakePlaybackCache()
      ..controlledTrackId = 'source-1::/track-a.flac'
      ..readCompleter = Completer<void>()
      ..controlledBytes = _id3WithLyrics('OLD A LYRICS')
      ..controlledBlockCount = 1;
    await IsarManager.clearAllMetadata();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    final songA = LibrarySong(
      id: 'source-1::/track-a.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'A',
      fileName: 'track-a.flac',
      remotePath: '/track-a.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
    );
    final songB = LibrarySong(
      id: 'source-1::/track-b.flac',
      sourceId: profile.id,
      sourceName: profile.name,
      title: 'B',
      fileName: 'track-b.flac',
      remotePath: '/track-b.flac',
      albumTitle: 'Album',
      artistName: 'Artist',
      directoryPath: '/',
      folderAlbumTitle: '',
      folderArtistName: '',
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
        scraping.musicBrainzScraperProvider.overrideWithValue(
          _FakeMusicBrainzScraper(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.playLibrarySong(songA, playlist: [songA, songB]);
    for (var i = 0; i < 50 && cache.controlledCallCount < 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cache.controlledCallCount, 1);

    final futureB = controller.playLibrarySong(songB, playlist: [songA, songB]);
    await futureB;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final futureA2 = controller.playLibrarySong(songA, playlist: [songA, songB]);
    await futureA2;
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.state.currentTrack?.id, songA.id);
    expect(controller.state.lyrics, isEmpty);

    cache.readCompleter!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(controller.state.currentTrack?.id, songA.id);
    expect(controller.state.lyrics, isEmpty);
    final metadataA = IsarManager.getMetadata(songA.id);
    expect(metadataA?.autoScrapedLyrics, 'OLD A LYRICS');
  });

  test('seekAndPlay does not play after explicit pause', () async {
    final player = _MockAudioPlayer();
    var playerPlaying = true;
    var playCalls = 0;
    final seekCompleter = Completer<void>();
    when(() => player.errorStream)
        .thenAnswer((_) => const Stream<PlayerException>.empty());
    when(() => player.playing).thenAnswer((_) => playerPlaying);
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
    when(() => player.pause()).thenAnswer((_) async {
      playerPlaying = false;
    });
    when(() => player.dispose()).thenAnswer((_) async {});
    when(() => player.setAudioSource(
          any(),
          initialPosition: any(named: 'initialPosition'),
        )).thenAnswer((_) async => const Duration(seconds: 1));
    when(() => player.play()).thenAnswer((_) async {
      playCalls++;
    });
    when(() => player.seek(any())).thenAnswer((_) => seekCompleter.future);

    final service = PlayerService(player: player);
    final source = _FakeMusicSource(profile);
    final cache = _FakePlaybackCache();
    await IsarManager.clearAllMetadata();
    final sessionRepo = _FakeSessionRepository();
    final sessionManager = _FakeSessionManager(source);
    final entryA = RemoteEntry(
      sourceId: profile.id,
      name: 'track-a.flac',
      path: '/track-a.flac',
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
        scraping.musicBrainzScraperProvider.overrideWithValue(
          _FakeMusicBrainzScraper(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(service.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.playEntry(profile: profile, entry: entryA);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final initialPlayCalls = playCalls;

    final seekFuture = controller.seekAndPlay(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await controller.pause();
    seekCompleter.complete();
    await seekFuture;
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(playCalls, initialPlayCalls);
    expect(playerPlaying, isFalse);
    expect(controller.state.currentTrack?.id, entryA.uniqueId);
  });


}

Uint8List _id3WithLyrics(String lyrics) {
  final frameContent = <int>[
    0,
    ...'eng'.codeUnits,
    0,
    ...lyrics.codeUnits,
  ];
  final sizeBytes = frameContent.length;
  final frame = <int>[
    ...'USLT'.codeUnits,
    (sizeBytes >> 24) & 0xff,
    (sizeBytes >> 16) & 0xff,
    (sizeBytes >> 8) & 0xff,
    sizeBytes & 0xff,
    0,
    0,
    ...frameContent,
  ];
  final tagSize = frame.length;
  var size = tagSize;
  final synchsafe = <int>[];
  for (var i = 0; i < 4; i++) {
    synchsafe.insert(0, size & 0x7f);
    size >>= 7;
  }
  final header = <int>[
    ...'ID3'.codeUnits,
    3,
    0,
    0,
    ...synchsafe,
  ];
  return Uint8List.fromList(header + frame);
}

class _FakeMusicBrainzScraper extends MusicBrainzScraper {
  _FakeMusicBrainzScraper() : super(enableLyricsScraping: false);

  @override
  Future<ScrapedMetadata?> scrapeTrackInfo({
    required String title,
    String? artist,
    String? album,
    AppLocalePreference? localePreference,
    FutureOr<void> Function(ScrapedMetadata metadata)? onUpdate,
  }) async {
    return null;
  }
}
