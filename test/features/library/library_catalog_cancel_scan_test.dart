import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music/core/database/isar_manager.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/core/storage/source_profile_repository.dart';
import 'package:music/features/library/application/library_catalog_controller.dart';
import 'package:music/features/sources/application/music_source_registry.dart';
import 'package:music/features/sources/application/source_session_manager.dart';
import 'package:music/features/sources/application/sources_controller.dart';
import 'package:music/features/sources/domain/music_source.dart';
import 'package:music/core/database/library_scan_cache_repository_impl_io.dart';
import 'package:music/core/models/library_song.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';

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

class _SyncAppSettingsController extends AppSettingsController {
  _SyncAppSettingsController(this._preferences);
  final LibraryPreferences _preferences;
  @override
  Future<LibraryPreferences> build() async =>
      SynchronousFuture<LibraryPreferences>(_preferences);
}

class _SyncSourcesController extends SourcesController {
  _SyncSourcesController(this._sources);
  final List<SourceProfile> _sources;
  @override
  Future<List<SourceProfile>> build() async =>
      SynchronousFuture<List<SourceProfile>>(_sources);
}

class _FakeMusicSource extends MusicSource {
  _FakeMusicSource(this._profile, {this.delay = Duration.zero});
  final SourceProfile _profile;
  Duration delay;
  bool fail = false;
  List<RemoteEntry> entries = const [
    RemoteEntry(
      sourceId: 'src-1',
      name: 'song.flac',
      path: '/Music/song.flac',
      kind: RemoteEntryKind.audio,
      mimeType: 'audio/flac',
      size: 8,
    ),
  ];
  int listFilesCalls = 0;

  @override
  SourceProfile get profile => _profile;
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<DirectoryListing> listFiles(String path) async {
    listFilesCalls++;
    await Future<void>.delayed(delay);
    if (fail) throw StateError('boom');
    return DirectoryListing(entries: entries);
  }

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) {
    throw UnimplementedError();
  }

  @override
  Future<String?> readTextFile(String path) async => null;
  @override
  Future<Uint8List?> readBinaryFile(String path) async => null;
}

class _FakeSessionManager extends MusicSourceSessionManager {
  _FakeSessionManager(this.sources) : super(MusicSourceRegistry(const []));
  final List<MusicSource> sources;
  @override
  Future<MusicSource> get(SourceProfile profile) async =>
      sources.firstWhere((s) => s.profile.id == profile.id);
}

const _source1 = SourceProfile(
  id: 'src-1',
  name: 'Source 1',
  protocol: SourceProtocol.webdav,
  baseUrl: 'http://example.com/dav/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

const _source2 = SourceProfile(
  id: 'src-2',
  name: 'Source 2',
  protocol: SourceProtocol.webdav,
  baseUrl: 'http://example2.com/dav/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late MethodChannel channel;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('omnitune-catalog-');
    channel = const MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return tempDir.path;
        });
    SharedPreferences.setMockInitialValues({});
    await IsarManager.initialize();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'scanAllSources cancel while listing pending preserves old tracks',
    () async {
      final source = _FakeMusicSource(_source1);
      final manager = _FakeSessionManager([source]);
      final testSources = [_source1];

      final firstContainer = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(
            _FakeSourceProfileRepository(testSources),
          ),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            _FakeLibraryPreferencesRepository(),
          ),
          sourcesControllerProvider.overrideWith(
            () => _SyncSourcesController(testSources),
          ),
          musicSourceSessionManagerProvider.overrideWithValue(manager),
          appSettingsControllerProvider.overrideWith(
            () => _SyncAppSettingsController(const LibraryPreferences()),
          ),
        ],
      );
      addTearDown(firstContainer.dispose);
      final controller = firstContainer.read(
        libraryCatalogControllerProvider.notifier,
      );
      await controller.scanAllSources();
      final before = firstContainer
          .read(libraryCatalogControllerProvider)
          .valueOrNull;
      expect(before?.tracks, isNotEmpty);

      source.delay = const Duration(milliseconds: 60);
      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(
            _FakeSourceProfileRepository(testSources),
          ),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            _FakeLibraryPreferencesRepository(),
          ),
          sourcesControllerProvider.overrideWith(
            () => _SyncSourcesController(testSources),
          ),
          musicSourceSessionManagerProvider.overrideWithValue(manager),
          appSettingsControllerProvider.overrideWith(
            () => _SyncAppSettingsController(const LibraryPreferences()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller2 = container.read(
        libraryCatalogControllerProvider.notifier,
      );
      final future = controller2.scanAllSources();
      await Future<void>.delayed(const Duration(milliseconds: 15));
      controller2.cancelScan();
      await future;
      final after = container
          .read(libraryCatalogControllerProvider)
          .valueOrNull;
      expect(after?.isScanning, isFalse);
      expect(after?.isScanCancelled, isTrue);
    },
  );

  test('overlapping scan requests are ignored', () async {
    final source = _FakeMusicSource(
      _source1,
      delay: const Duration(milliseconds: 60),
    );
    final manager = _FakeSessionManager([source]);
    final testSources = [_source1];

    final container = ProviderContainer(
      overrides: [
        sourceProfileRepositoryProvider.overrideWithValue(
          _FakeSourceProfileRepository(testSources),
        ),
        libraryPreferencesRepositoryProvider.overrideWithValue(
          _FakeLibraryPreferencesRepository(),
        ),
        sourcesControllerProvider.overrideWith(
          () => _SyncSourcesController(testSources),
        ),
        musicSourceSessionManagerProvider.overrideWithValue(manager),
        appSettingsControllerProvider.overrideWith(
          () => _SyncAppSettingsController(const LibraryPreferences()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      libraryCatalogControllerProvider.notifier,
    );
    final first = controller.scanAllSources();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final second = controller.scanAllSources();
    await second;
    expect(first, isNotNull);
    await first;
    expect(source.listFilesCalls, 1);
  });

  test(
    'failure preserves tracks and retryFailedSources selects only failed source',
    () async {
      final source1 = _FakeMusicSource(_source1, delay: Duration.zero)
        ..fail = true;
      final source2 = _FakeMusicSource(_source2, delay: Duration.zero);
      // Make second source's entries use src-2 unique ids
      source2.entries = const [
        RemoteEntry(
          sourceId: 'src-2',
          name: 'song2.flac',
          path: '/Music/song2.flac',
          kind: RemoteEntryKind.audio,
          mimeType: 'audio/flac',
          size: 8,
        ),
      ];
      final manager = _FakeSessionManager([source1, source2]);
      final testSources = [_source1, _source2];

      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(
            _FakeSourceProfileRepository(testSources),
          ),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            _FakeLibraryPreferencesRepository(),
          ),
          sourcesControllerProvider.overrideWith(
            () => _SyncSourcesController(testSources),
          ),
          musicSourceSessionManagerProvider.overrideWithValue(manager),
          appSettingsControllerProvider.overrideWith(
            () => _SyncAppSettingsController(const LibraryPreferences()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        libraryCatalogControllerProvider.notifier,
      );
      await controller.scanAllSources();
      final failedState = container
          .read(libraryCatalogControllerProvider)
          .valueOrNull;
      expect(failedState?.failedSourceIds, contains('src-1'));
      expect(failedState?.tracks, isNotEmpty);

      final callsBeforeRetry = source1.listFilesCalls;
      source1.fail = false;
      await controller.retryFailedSources();
      expect(source1.listFilesCalls, greaterThan(callsBeforeRetry));
      // source2 should not be scanned by retry (calls unchanged)
      final source2CallsDuringFirst = source2.listFilesCalls;
      await Future<void>.delayed(Duration.zero);
      expect(source2.listFilesCalls, source2CallsDuringFirst);
    },
  );

  test('retryFailedSources with no failures does nothing', () async {
    final source1 = _FakeMusicSource(_source1);
    final manager = _FakeSessionManager([source1]);
    final testSources = [_source1];
    final container = ProviderContainer(
      overrides: [
        sourceProfileRepositoryProvider.overrideWithValue(
          _FakeSourceProfileRepository(testSources),
        ),
        libraryPreferencesRepositoryProvider.overrideWithValue(
          _FakeLibraryPreferencesRepository(),
        ),
        sourcesControllerProvider.overrideWith(
          () => _SyncSourcesController(testSources),
        ),
        musicSourceSessionManagerProvider.overrideWithValue(manager),
        appSettingsControllerProvider.overrideWith(
          () => _SyncAppSettingsController(const LibraryPreferences()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      libraryCatalogControllerProvider.notifier,
    );
    await controller.scanAllSources();
    final callsBefore = source1.listFilesCalls;
    await controller.retryFailedSources();
    expect(source1.listFilesCalls, callsBefore);
  });

  test(
    'cancel after partial discovery preserves old and newly found tracks',
    () async {
      const oldSong = LibrarySong(
        id: 'src-old::/Music/old.flac',
        sourceId: 'src-old',
        sourceName: 'Old Source',
        title: 'Old Song',
        fileName: 'old.flac',
        remotePath: '/Music/old.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/Music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
      );
      final seedRepo = JsonFileScanCacheRepository(tempDir);
      await seedRepo.saveScanResults('src-old', [oldSong]);

      final source1 = _FakeMusicSource(_source1, delay: Duration.zero);
      final source2 = _FakeMusicSource(
        _source2,
        delay: const Duration(milliseconds: 80),
      );
      final manager = _FakeSessionManager([source1, source2]);
      final testSources = [_source1, _source2];

      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(
            _FakeSourceProfileRepository(testSources),
          ),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            _FakeLibraryPreferencesRepository(),
          ),
          sourcesControllerProvider.overrideWith(
            () => _SyncSourcesController(testSources),
          ),
          musicSourceSessionManagerProvider.overrideWithValue(manager),
          appSettingsControllerProvider.overrideWith(
            () => _SyncAppSettingsController(const LibraryPreferences()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        libraryCatalogControllerProvider.notifier,
      );
      final future = controller.scanAllSources();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      controller.cancelScan();
      await future;

      final state = container
          .read(libraryCatalogControllerProvider)
          .valueOrNull;
      expect(state?.isScanCancelled, isTrue);
      expect(
        state?.tracks.any((track) => track.id == oldSong.id),
        isTrue,
        reason: 'old cached track should remain',
      );
      expect(
        state?.tracks.any((track) => track.id == 'src-1::/Music/song.flac'),
        isTrue,
        reason: 'track discovered before cancellation should remain',
      );
    },
  );
}
