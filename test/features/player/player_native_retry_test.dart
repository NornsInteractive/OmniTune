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
  @override
  Future<PlayerSessionSnapshot?> load() async => null;

  @override
  Future<void> save(PlayerSessionSnapshot snapshot) async {}

  @override
  Future<void> clear() async {}
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
}
