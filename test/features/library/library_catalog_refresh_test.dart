import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music/core/database/isar_manager.dart';
import 'package:music/core/database/library_scan_cache_repository_impl_io.dart';
import 'package:music/core/database/scraping_metadata.dart';
import 'package:music/core/models/library_song.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/features/library/application/library_catalog_controller.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';
import 'package:music/features/sources/application/sources_controller.dart';

class _FakeLibraryPreferencesRepository
    implements LibraryPreferencesRepository {
  _FakeLibraryPreferencesRepository([
    this._preferences = const LibraryPreferences(),
  ]);
  LibraryPreferences _preferences;
  @override
  Future<LibraryPreferences> load() async => _preferences;
  @override
  Future<void> save(LibraryPreferences preferences) async =>
      _preferences = preferences;
  @override
  Future<LibraryPreferences> update(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async => _preferences = transform(_preferences);
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

const _sourceA = SourceProfile(
  id: 'src-a',
  name: 'Source A',
  protocol: SourceProtocol.webdav,
  baseUrl: 'http://a.example.com/dav/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

ScrapingMetadata _meta(
  String id, {
  String? album,
  String? artist,
  String? title,
}) => ScrapingMetadata(
  id: id,
  sourceId: 'src-a',
  filePath: '/Music/$id.flac',
  filenameWithoutExt: id,
  originalFileName: '$id.flac',
  autoScrapedAlbum: album,
  autoScrapedArtist: artist,
  autoScrapedTitle: title,
);

LibrarySong _song({
  required String id,
  String sourceId = 'src-a',
  String sourceName = 'Source A',
  String? title,
  String? album,
  String? artist,
  String? directory,
}) => LibrarySong(
  id: id,
  sourceId: sourceId,
  sourceName: sourceName,
  title: title ?? id,
  fileName: '$id.flac',
  remotePath: '/Music/$id.flac',
  albumTitle: album ?? 'Album',
  artistName: artist ?? 'Artist',
  directoryPath: directory ?? '/Music/Album',
  folderAlbumTitle: album ?? 'Album',
  folderArtistName: artist ?? 'Artist',
);

ProviderContainer _container({
  required List<SourceProfile> sources,
  LibraryPreferences preferences = const LibraryPreferences(),
}) => ProviderContainer(
  overrides: [
    libraryPreferencesRepositoryProvider.overrideWithValue(
      _FakeLibraryPreferencesRepository(preferences),
    ),
    sourcesControllerProvider.overrideWith(
      () => _SyncSourcesController(sources),
    ),
    appSettingsControllerProvider.overrideWith(
      () => _SyncAppSettingsController(preferences),
    ),
  ],
);

Future<void> _waitFor(
  ProviderContainer container,
  bool Function(LibraryCatalogState state) predicate, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final state = container.read(libraryCatalogControllerProvider).valueOrNull;
    if (state != null && predicate(state)) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  final state = container.read(libraryCatalogControllerProvider).valueOrNull;
  throw StateError('condition not met before $timeout; last=$state');
}

Future<void> _nextEventLoopTurn() {
  final completer = Completer<void>();
  Timer.run(completer.complete);
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late MethodChannel channel;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('omnitune-refresh-');
    channel = const MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    SharedPreferences.setMockInitialValues({});
    await IsarManager.initialize();
    await IsarManager.clearAll();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'build only shows configured sources while cache keeps deleted source',
    () async {
      final repo = JsonFileScanCacheRepository(tempDir);
      await repo.saveScanResults('src-a', [_song(id: 'a1')]);
      await repo.saveScanResults('src-b', [_song(id: 'b1', sourceId: 'src-b')]);

      final container = _container(
        sources: const [_sourceA],
        preferences: const LibraryPreferences(favoriteTrackIds: {'fav-1'}),
      );
      addTearDown(container.dispose);
      final state = await container.read(
        libraryCatalogControllerProvider.future,
      );

      expect(state.tracks.map((t) => t.id), ['a1']);
      expect(state.tracks.any((t) => t.sourceId == 'src-b'), isFalse);
      expect(state.favoriteTrackIds, contains('fav-1'));

      final reloaded = await JsonFileScanCacheRepository(
        tempDir,
      ).loadAllResults();
      expect(reloaded.keys, containsAll(<String>['src-a', 'src-b']));
      expect(reloaded['src-b']!.single.id, 'b1');
    },
  );

  test('no configured sources shows empty library but keeps cache', () async {
    await JsonFileScanCacheRepository(
      tempDir,
    ).saveScanResults('src-b', [_song(id: 'b1', sourceId: 'src-b')]);

    final container = _container(sources: const []);
    addTearDown(container.dispose);
    final state = await container.read(libraryCatalogControllerProvider.future);

    expect(state.tracks, isEmpty);
    final reloaded = await JsonFileScanCacheRepository(
      tempDir,
    ).loadAllResults();
    expect(reloaded['src-b']!.single.id, 'b1');
  });

  test(
    'refreshSongMetadata updates song fields immediately but albums async',
    () async {
      await JsonFileScanCacheRepository(tempDir).saveScanResults('src-a', [
        _song(id: 'a1', album: 'Old Album', directory: '/Music/old'),
      ]);
      final container = _container(sources: const [_sourceA]);
      addTearDown(container.dispose);
      final controller = container.read(
        libraryCatalogControllerProvider.notifier,
      );
      final before = await container.read(
        libraryCatalogControllerProvider.future,
      );
      expect(before.metadataAlbums.map((a) => a.title), ['Old Album']);

      await IsarManager.saveMetadata(
        _meta('a1', album: 'New Album', title: 'New Title'),
      );

      controller.refreshSongMetadata('a1');
      final immediate = container
          .read(libraryCatalogControllerProvider)
          .valueOrNull!;
      expect(
        immediate.tracks.single.metadataAlbumTitle,
        'New Album',
        reason: 'track fields update synchronously',
      );
      expect(
        immediate.metadataAlbums.map((a) => a.title),
        ['Old Album'],
        reason: 'albums are rebuilt asynchronously',
      );

      await _waitFor(
        container,
        (s) => s.metadataAlbums.map((a) => a.title).contains('New Album'),
      );
      final finalState = container
          .read(libraryCatalogControllerProvider)
          .valueOrNull!;
      final album = finalState.metadataAlbums.single;
      expect(album.title, 'New Album');
      expect(album.tracks.single.id, 'a1');
      expect(
        finalState.metadataAlbums.map((a) => a.title.toLowerCase()),
        List<String>.of(
          finalState.metadataAlbums.map((a) => a.title.toLowerCase()),
        )..sort(),
      );
    },
  );

  test('rebuildAlbums:false keeps existing album indexes', () async {
    await JsonFileScanCacheRepository(tempDir).saveScanResults('src-a', [
      _song(id: 'a1', album: 'Old Album', directory: '/Music/old'),
    ]);
    final container = _container(sources: const [_sourceA]);
    addTearDown(container.dispose);
    final controller = container.read(
      libraryCatalogControllerProvider.notifier,
    );
    await container.read(libraryCatalogControllerProvider.future);

    await IsarManager.saveMetadata(_meta('a1', album: 'New Album'));

    final changed = controller.refreshSongsMetadata([
      'a1',
    ], rebuildAlbums: false);
    expect(changed, isTrue);
    final state = container.read(libraryCatalogControllerProvider).valueOrNull!;
    expect(state.tracks.single.metadataAlbumTitle, 'New Album');
    expect(state.metadataAlbums.map((a) => a.title), ['Old Album']);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
      container
          .read(libraryCatalogControllerProvider)
          .valueOrNull!
          .metadataAlbums
          .map((a) => a.title),
      ['Old Album'],
      reason: 'rebuildAlbums:false must not start grouping',
    );
  });

  test(
    'favorite and liked toggles are not overwritten by in-flight refresh',
    () async {
      final songs = List.generate(
        150,
        (i) => _song(id: 'a$i', album: 'Album', directory: '/Music/a'),
      );
      await JsonFileScanCacheRepository(
        tempDir,
      ).saveScanResults('src-a', songs);
      final container = _container(sources: const [_sourceA]);
      addTearDown(container.dispose);
      final controller = container.read(
        libraryCatalogControllerProvider.notifier,
      );
      await container.read(libraryCatalogControllerProvider.future);

      await IsarManager.saveMetadata(_meta('a0', album: 'Refreshed Album'));

      controller.refreshSongMetadata('a0');
      await _nextEventLoopTurn();
      await controller.toggleFavorite('fav-new');
      await controller.toggleLiked('liked-new');

      await _waitFor(
        container,
        (s) => s.metadataAlbums.any((a) => a.title == 'Refreshed Album'),
      );
      final state = container
          .read(libraryCatalogControllerProvider)
          .valueOrNull!;
      expect(state.favoriteTrackIds, contains('fav-new'));
      expect(state.likedTrackIds, contains('liked-new'));
    },
  );

  test(
    'rapid refreshes and artist grouping switch settle to latest state',
    () async {
      await JsonFileScanCacheRepository(tempDir).saveScanResults('src-a', [
        _song(id: 'a1', album: 'Scanned', directory: '/Music/x'),
        _song(id: 'a2', album: 'Scanned', directory: '/Music/x'),
      ]);
      final container = _container(sources: const [_sourceA]);
      addTearDown(container.dispose);
      final controller = container.read(
        libraryCatalogControllerProvider.notifier,
      );
      await container.read(libraryCatalogControllerProvider.future);

      for (final entry in {'a1': 'Artist One', 'a2': 'Artist Two'}.entries) {
        await IsarManager.saveMetadata(
          _meta(entry.key, album: 'Shared Album', artist: entry.value),
        );
      }

      controller.refreshSongMetadata('a1');
      controller.refreshSongMetadata('a2');
      await _waitFor(
        container,
        (s) =>
            s.tracks.every((t) => t.metadataAlbumTitle == 'Shared Album') &&
            s.metadataAlbums.length == 1,
      );

      await container
          .read(appSettingsControllerProvider.notifier)
          .setGroupMetadataAlbumsByArtist(true);
      await _waitFor(container, (s) => s.metadataAlbums.length == 2);
      final state = container
          .read(libraryCatalogControllerProvider)
          .valueOrNull!;
      expect(
        state.metadataAlbums.map((a) => a.title),
        everyElement('Shared Album'),
      );
      expect(state.metadataAlbums.map((a) => a.artistName).toSet(), {
        'Artist One',
        'Artist Two',
      });
    },
  );

  test('dispose while a refresh is queued or running does not throw', () async {
    for (final immediate in [true, false]) {
      await IsarManager.clearAll();
      final songs = List.generate(
        200,
        (i) => _song(id: 'a$i', album: 'Album', directory: '/Music/a'),
      );
      await JsonFileScanCacheRepository(
        tempDir,
      ).saveScanResults('src-a', songs);
      final container = _container(sources: const [_sourceA]);
      final controller = container.read(
        libraryCatalogControllerProvider.notifier,
      );
      await container.read(libraryCatalogControllerProvider.future);
      await IsarManager.saveMetadata(_meta('a0', album: 'Refreshed Album'));

      controller.refreshSongMetadata('a0');
      if (!immediate) await _nextEventLoopTurn();
      container.dispose();
      for (var turn = 0; turn < 5; turn++) {
        await _nextEventLoopTurn();
      }
    }
  });

  List<LibrarySong> generate(int count, int albumSize) =>
      List.generate(count, (i) {
        final albumIndex = albumSize <= 0 ? 0 : i ~/ albumSize;
        final album = 'Album $albumIndex';
        return _song(
          id: 'song-$i',
          title: 'Song $i',
          album: album,
          directory: '/Music/$album',
        );
      });

  Future<void> runMeasure(String label, int count, int albumSize) async {
    final songs = generate(count, albumSize);
    await JsonFileScanCacheRepository(tempDir).saveScanResults('src-a', songs);
    final container = _container(sources: const [_sourceA]);
    addTearDown(container.dispose);
    final controller = container.read(
      libraryCatalogControllerProvider.notifier,
    );
    await container.read(libraryCatalogControllerProvider.future);

    final target = songs.first;
    await IsarManager.saveMetadata(
      _meta(
        target.id,
        album: 'Measured Album',
        artist: 'Measured Artist',
        title: 'Measured Title',
      ),
    );

    final clock = Stopwatch()..start();
    var lastHeartbeatUs = 0;
    var maxGapUs = 0;
    final heartbeat = Timer.periodic(const Duration(milliseconds: 2), (_) {
      final now = clock.elapsedMicroseconds;
      final gap = now - lastHeartbeatUs;
      if (gap > maxGapUs) maxGapUs = gap;
      lastHeartbeatUs = now;
    });
    addTearDown(heartbeat.cancel);

    controller.refreshSongMetadata(target.id);
    final syncUs = clock.elapsedMicroseconds;

    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (DateTime.now().isBefore(deadline)) {
      final s = container.read(libraryCatalogControllerProvider).valueOrNull;
      if (s != null &&
          s.metadataAlbums.any((a) => a.title == 'Measured Album')) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final totalUs = clock.elapsedMicroseconds;
    clock.stop();
    final tailGap = totalUs - lastHeartbeatUs;
    if (tailGap > maxGapUs) maxGapUs = tailGap;
    heartbeat.cancel();

    final state = container.read(libraryCatalogControllerProvider).valueOrNull!;
    final refreshed = state.tracks.firstWhere((t) => t.id == target.id);
    final metadataOk =
        refreshed.metadataAlbumTitle == 'Measured Album' &&
        refreshed.metadataArtistName == 'Measured Artist' &&
        refreshed.displayTitle == 'Measured Title';
    expect(metadataOk, isTrue, reason: '$label metadata');

    final expectedIds = songs.map((s) => s.id).toSet();
    for (final albums in [state.folderAlbums, state.metadataAlbums]) {
      final ids = <String>[];
      for (final album in albums) {
        ids.addAll(album.tracks.map((t) => t.id));
        final titles = album.tracks.map((t) => t.title.toLowerCase()).toList();
        expect(
          titles,
          List<String>.of(titles)..sort(),
          reason: '$label per-album track order',
        );
      }
      expect(ids.length, count, reason: '$label album track total');
      expect(ids.toSet().length, count, reason: '$label unique track ids');
      expect(ids.toSet(), expectedIds, reason: '$label all track ids');
      expect(
        albums.map((a) => a.title.toLowerCase()).toList(),
        List<String>.of(albums.map((a) => a.title.toLowerCase()))..sort(),
        reason: '$label album title order',
      );
    }

    debugPrintSynchronously(
      'CATALOG_MEASURE ${jsonEncode({'label': label, 'trackCount': count, 'albumSize': albumSize, 'syncReturnUs': syncUs, 'totalUs': totalUs, 'maxHeartbeatGapUs': maxGapUs, 'metadataOk': metadataOk})}',
    );
  }

  for (final count in [1000, 10000]) {
    for (final albumSize in [50, 0]) {
      final kind = albumSize <= 0 ? 'single' : 'per50';
      test(
        'CATALOG_MEASURE refreshSongMetadata $kind $count',
        () => runMeasure('$kind-$count', count, albumSize),
        timeout: const Timeout(Duration(minutes: 5)),
      );
    }
  }
}
