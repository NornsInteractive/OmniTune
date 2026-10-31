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
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/features/library/application/library_catalog_controller.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';
import 'package:music/features/sources/application/music_source_registry.dart';
import 'package:music/features/sources/application/sources_controller.dart';
import 'package:music/features/sources/domain/music_source.dart';

/// Isolated contract tests for the cached-startup embedded-metadata reread.
///
/// Scope: this file only. No product code, device, network or shared workspace
/// is touched. The fake source records every head read so the tests can assert
/// *how many* reads happen, *how large* they are, and whether the versioned
/// cache suppresses them.
///
/// Behaviours under test (library_catalog_controller.dart):
///  - build() schedules one bounded background reread for cached M4A tracks;
///  - embeddedMetadataReadVersion == 1 makes later startups read nothing;
///  - persisting embedded tags never overwrites manual scraped fields;
///  - a scan already running when the cached hydration timer fires is honoured
///    (no duplicate read) and the scan performs the single reread instead;
///  - a failed head read (null) or a truncated expanded prefix never records
///    `embeddedMetadataReadVersion == 1`, so the next startup retries;
///  - a valid prefix that simply carries no tags may be marked attempted once.

const int _libraryHeadBytes = 128 * 1024;

const _source = SourceProfile(
  id: 'src-a',
  name: 'Source A',
  protocol: SourceProtocol.webdav,
  baseUrl: 'http://a.example.com/dav/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

// ---------------------------------------------------------------------------
// MP4/M4A fixture: moov before mdat so the 128 KiB head read is sufficient.
// ---------------------------------------------------------------------------

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.big);

Uint8List _atom(String type, List<int> payload) {
  final header = <int>[..._u32(8 + payload.length), ...latin1.encode(type)];
  return Uint8List.fromList([...header, ...payload]);
}

Uint8List _concat(List<List<int>> parts) =>
    Uint8List.fromList([for (final part in parts) ...part]);

Uint8List _dataAtom(List<int> payload) =>
    _atom('data', [..._u32(0), ..._u32(1), ...payload]);

Uint8List _textAtom(String name, String value) =>
    _atom(name, _dataAtom(utf8.encode(value)));

/// ftyp + moov(udta/meta/ilst with title/artist/album/lyrics) + 300 KiB mdat.
Uint8List _m4aFixture() {
  final ilst = _atom(
    'ilst',
    _concat([
      _textAtom('\u00a9nam', 'Embedded Title'),
      _textAtom('\u00a9ART', 'Embedded Artist'),
      _textAtom('\u00a9alb', 'Embedded Album'),
      _textAtom('\u00a9lyr', 'Embedded Lyrics'),
    ]),
  );
  final meta = _atom('meta', [..._u32(0), ...ilst]);
  final moov = _atom('moov', _atom('udta', meta));
  final ftyp = _atom('ftyp', [
    ...ascii.encode('M4A '),
    ..._u32(0),
    ...ascii.encode('M4A '),
    ...ascii.encode('isom'),
  ]);
  return _concat([ftyp, moov, _atom('mdat', Uint8List(300 * 1024))]);
}

Uint8List _ftypAtom() => _atom('ftyp', [
  ...ascii.encode('M4A '),
  ..._u32(0),
  ...ascii.encode('M4A '),
  ...ascii.encode('isom'),
]);

/// Legacy/unoptimised M4A: `moov` starts at offset 24 but is ~200 KiB, so it
/// straddles the 128 KiB head window. The controller must ask for one expanded
/// prefix before the tags become parseable.
Uint8List _legacyM4aFixture() {
  final ilst = _atom(
    'ilst',
    _concat([
      _textAtom('\u00a9nam', 'Embedded Title'),
      _textAtom('\u00a9ART', 'Embedded Artist'),
      _textAtom('\u00a9alb', 'Embedded Album'),
      _textAtom('\u00a9lyr', 'Embedded Lyrics'),
    ]),
  );
  final meta = _atom('meta', [..._u32(0), ...ilst]);
  final moov = _atom(
    'moov',
    _concat([
      _atom('udta', meta),
      _atom('free', Uint8List(200 * 1024)),
    ]),
  );
  return _concat([_ftypAtom(), moov, _atom('mdat', Uint8List(300 * 1024))]);
}

/// Faststart M4A whose `moov` fits inside the head window but holds no tags.
Uint8List _taglessM4aFixture() {
  final meta = _atom('meta', [..._u32(0), ..._atom('ilst', const [])]);
  final moov = _atom('moov', _atom('udta', meta));
  return _concat([_ftypAtom(), moov, _atom('mdat', Uint8List(64 * 1024))]);
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeLibraryPreferencesRepository implements LibraryPreferencesRepository {
  LibraryPreferences _preferences = const LibraryPreferences();
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

class _CountingMusicSource implements MusicSource {
  _CountingMusicSource(
    this.profile,
    this.bytes, {
    this.listFilesGate,
    this.entries = const [],
    this.headResponder,
  });

  @override
  final SourceProfile profile;
  final Uint8List bytes;
  final Completer<void>? listFilesGate;
  final List<RemoteEntry> entries;

  /// Optional per-call override of the head read. Receives the 1-based call
  /// index for the path, the requested length and the bytes the fake would
  /// otherwise return; returning null simulates a network failure.
  final Uint8List? Function(int call, int length, Uint8List head)? headResponder;

  final List<int> readLengths = [];
  final Map<String, int> readCounts = {};
  int connectCalls = 0;

  @override
  Future<void> connect() async {
    connectCalls++;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<DirectoryListing> listFiles(String path) async {
    final gate = listFilesGate;
    if (gate != null) await gate.future;
    return DirectoryListing(entries: entries);
  }

  @override
  Future<Uint8List?> readBinaryFileHead(
    String path, {
    int length = 128 * 1024,
  }) async {
    final call = (readCounts[path] ?? 0) + 1;
    readLengths.add(length);
    readCounts[path] = call;
    final take = length < bytes.length ? length : bytes.length;
    final head = Uint8List.sublistView(bytes, 0, take);
    final responder = headResponder;
    if (responder != null) return responder(call, length, head);
    return head;
  }

  @override
  Future<Uint8List?> readBinaryFile(String path) => throw UnimplementedError();

  @override
  Future<String?> readTextFile(String path) => throw UnimplementedError();

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) =>
      throw UnimplementedError();
}

class _FakeMusicSourceFactory implements MusicSourceFactory {
  _FakeMusicSourceFactory(this.source);
  final MusicSource source;
  @override
  SourceProtocol get protocol => SourceProtocol.webdav;
  @override
  MusicSource create(SourceProfile profile) => source;
}

LibrarySong _song(String id, {String extension = '.m4a'}) => LibrarySong(
  id: id,
  sourceId: _source.id,
  sourceName: _source.name,
  title: id,
  fileName: '$id$extension',
  remotePath: '/Music/$id$extension',
  albumTitle: 'Folder Album',
  artistName: 'Folder Artist',
  directoryPath: '/Music',
  folderAlbumTitle: 'Folder Album',
  folderArtistName: 'Folder Artist',
);

ScrapingMetadata _meta(String id, {String extension = '.m4a'}) =>
    ScrapingMetadata(
      id: id,
      sourceId: _source.id,
      filePath: '/Music/$id$extension',
      filenameWithoutExt: id,
      originalFileName: '$id$extension',
    );

ProviderContainer _container(_CountingMusicSource source) => ProviderContainer(
  overrides: [
    libraryPreferencesRepositoryProvider.overrideWithValue(
      _FakeLibraryPreferencesRepository(),
    ),
    sourcesControllerProvider.overrideWith(
      () => _SyncSourcesController(const [_source]),
    ),
    appSettingsControllerProvider.overrideWith(
      () => _SyncAppSettingsController(const LibraryPreferences()),
    ),
    musicSourceRegistryProvider.overrideWithValue(
      MusicSourceRegistry([_FakeMusicSourceFactory(source)]),
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
  throw StateError(
    'condition not met before $timeout; '
    'isScanning=${state?.isScanning} '
    'lastScanError=${state?.lastScanError} '
    'tracks=${state?.tracks.map((t) => '${t.id}:${t.autoScrapedTitle}').toList()}',
  );
}

Future<void> _waitForReads(
  _CountingMusicSource source,
  int count, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (source.readLengths.length >= count) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError(
    'expected $count head reads before $timeout; '
    'saw ${source.readLengths.length}',
  );
}

Future<void> _waitForMetadataVersion(
  String id,
  int version, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (IsarManager.getMetadata(id)?.embeddedMetadataReadVersion == version) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError(
    'metadata $id did not reach read version $version before $timeout',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late MethodChannel channel;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('omnitune-hydration-');
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
    'cached M4A startup performs exactly one bounded head read per track',
    () async {
      await JsonFileScanCacheRepository(
        tempDir,
      ).saveScanResults(_source.id, [_song('a1'), _song('a2')]);

      final source = _CountingMusicSource(_source, _m4aFixture());
      final container = _container(source);
      addTearDown(container.dispose);

      final initial = await container.read(
        libraryCatalogControllerProvider.future,
      );
      expect(initial.tracks.length, 2);
      expect(
        source.readLengths,
        isEmpty,
        reason: 'build must return before the background reread starts',
      );

      await _waitFor(
        container,
        (state) =>
            state.tracks.length == 2 &&
            state.tracks.every((t) => t.autoScrapedTitle == 'Embedded Title'),
      );

      expect(source.readCounts, {
        '/Music/a1.m4a': 1,
        '/Music/a2.m4a': 1,
      }, reason: 'one reread per cached M4A track, no duplicates');
      expect(source.readLengths.length, 2);
      expect(
        source.readLengths,
        everyElement(_libraryHeadBytes),
        reason: 'head read stays at the 128 KiB budget',
      );

      for (final id in ['a1', 'a2']) {
        final metadata = IsarManager.getMetadata(id);
        expect(metadata, isNotNull, reason: '$id metadata persisted');
        expect(metadata!.embeddedMetadataReadVersion, 1);
        expect(metadata.autoScrapedTitle, 'Embedded Title');
        expect(metadata.autoScrapedArtist, 'Embedded Artist');
        expect(metadata.autoScrapedAlbum, 'Embedded Album');
      }

      final state = container.read(libraryCatalogControllerProvider).valueOrNull!;
      expect(state.tracks.map((t) => t.displayTitle), everyElement('Embedded Title'));
    },
  );

  test(
    'versioned cache skips already-read tracks and avoids a second startup read',
    () async {
      await JsonFileScanCacheRepository(
        tempDir,
      ).saveScanResults(_source.id, [_song('a1'), _song('a2')]);

      // a2 is already version 1; a1 is still unread.
      final readMeta = _meta('a2')
        ..autoScrapedTitle = 'Cached Title'
        ..embeddedMetadataReadAt = DateTime.now()
        ..embeddedMetadataReadVersion = 1;
      await IsarManager.saveMetadata(readMeta);

      final firstSource = _CountingMusicSource(_source, _m4aFixture());
      final first = _container(firstSource);
      await first.read(libraryCatalogControllerProvider.future);
      await _waitFor(
        first,
        (state) =>
            state.tracks.any((t) => t.id == 'a1' && t.autoScrapedTitle != null),
      );

      expect(
        firstSource.readCounts,
        {'/Music/a1.m4a': 1},
        reason: 'only the unversioned track is reread',
      );
      expect(IsarManager.getMetadata('a2')!.embeddedMetadataReadVersion, 1);
      expect(IsarManager.getMetadata('a2')!.autoScrapedTitle, 'Cached Title');
      first.dispose();

      // Fresh startup: both tracks are version 1 now, so nothing is read.
      final secondSource = _CountingMusicSource(_source, _m4aFixture());
      final second = _container(secondSource);
      addTearDown(second.dispose);
      await second.read(libraryCatalogControllerProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        secondSource.readCounts,
        isEmpty,
        reason: 'versioned cache must suppress repeated rereads',
      );
      final state = second.read(libraryCatalogControllerProvider).valueOrNull!;
      expect(state.tracks.length, 2);
      expect(state.tracks.map((t) => t.autoScrapedTitle), everyElement(isNotNull));
    },
  );

  test('embedded reread preserves manual scraped fields', () async {
    await JsonFileScanCacheRepository(
      tempDir,
    ).saveScanResults(_source.id, [_song('a1')]);

    final manual = _meta('a1')
      ..manuallyScrapedTitle = 'Manual Title'
      ..manuallyScrapedArtist = 'Manual Artist'
      ..manuallyScrapedAlbum = 'Manual Album'
      ..manuallyScrapedLyrics = 'Manual Lyrics';
    await IsarManager.saveMetadata(manual);

    final source = _CountingMusicSource(_source, _m4aFixture());
    final container = _container(source);
    addTearDown(container.dispose);

    await container.read(libraryCatalogControllerProvider.future);
    await _waitFor(
      container,
      (state) =>
          state.tracks.single.autoScrapedTitle == 'Embedded Title',
    );

    final persisted = IsarManager.getMetadata('a1')!;
    expect(persisted.manuallyScrapedTitle, 'Manual Title');
    expect(persisted.manuallyScrapedArtist, 'Manual Artist');
    expect(persisted.manuallyScrapedAlbum, 'Manual Album');
    expect(persisted.manuallyScrapedLyrics, 'Manual Lyrics');
    expect(persisted.autoScrapedTitle, 'Embedded Title');
    expect(persisted.autoScrapedArtist, 'Embedded Artist');
    expect(persisted.autoScrapedAlbum, 'Embedded Album');
    expect(persisted.autoScrapedLyrics, 'Embedded Lyrics');
    expect(persisted.embeddedMetadataReadVersion, 1);

    final track = container
        .read(libraryCatalogControllerProvider)
        .valueOrNull!
        .tracks
        .single;
    expect(track.displayTitle, 'Manual Title');
    expect(track.displayArtist, 'Manual Artist');
    expect(track.displayAlbum, 'Manual Album');
    expect(track.displayLyrics, 'Manual Lyrics');
  });

  test('a scan already running when the cached reread timer fires is honoured',
      () async {
    await JsonFileScanCacheRepository(
      tempDir,
    ).saveScanResults(_source.id, [_song('a1')]);

    final gate = Completer<void>();
    final source = _CountingMusicSource(
      _source,
      _m4aFixture(),
      listFilesGate: gate,
      entries: const [
        RemoteEntry(
          sourceId: 'src-a',
          name: 'a1.m4a',
          path: '/Music/a1.m4a',
          kind: RemoteEntryKind.audio,
        ),
      ],
    );
    final container = _container(source);
    addTearDown(container.dispose);
    final controller = container.read(
      libraryCatalogControllerProvider.notifier,
    );

    final buildFuture = container.read(libraryCatalogControllerProvider.future);
    final built = await buildFuture;
    expect(built.tracks.length, 1);
    // The cached reread is queued as a Timer(Duration.zero); this continuation
    // runs as a microtask first, so the scan is running before the timer fires.
    unawaited(controller.scanAllSources());

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(
      source.readCounts,
      isEmpty,
      reason: 'cached hydration is skipped while a scan is running',
    );
    expect(
      container.read(libraryCatalogControllerProvider).valueOrNull!.isScanning,
      isTrue,
    );

    gate.complete();
    await _waitFor(
      container,
      (state) =>
          !state.isScanning &&
          state.tracks.length == 1 &&
          state.tracks.single.autoScrapedTitle == 'Embedded Title',
    );

    expect(
      source.readCounts,
      {'/Music/a1.m4a': 1},
      reason: 'the running scan performs the single reread, not both paths',
    );
    expect(source.readLengths, everyElement(_libraryHeadBytes));
  });

  test('null head read keeps a legacy M4A unversioned and retries next startup',
      () async {
    await JsonFileScanCacheRepository(
      tempDir,
    ).saveScanResults(_source.id, [_song('legacy-null')]);

    final failing = _CountingMusicSource(
      _source,
      _legacyM4aFixture(),
      headResponder: (call, length, head) => null,
    );
    final first = _container(failing);
    await first.read(libraryCatalogControllerProvider.future);
    await _waitForReads(failing, 1);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      failing.readCounts,
      {'/Music/legacy-null.m4a': 1},
      reason: 'a null head aborts the pass after the single attempt',
    );
    expect(
      IsarManager.getMetadata('legacy-null')?.embeddedMetadataReadVersion,
      isNot(1),
      reason: 'network failure must not be cached as a completed read',
    );
    expect(
      first
          .read(libraryCatalogControllerProvider)
          .valueOrNull!
          .tracks
          .single
          .autoScrapedTitle,
      isNull,
    );
    first.dispose();

    // Fresh provider startup: the unversioned legacy track must be retried.
    final retry = _CountingMusicSource(_source, _legacyM4aFixture());
    final second = _container(retry);
    addTearDown(second.dispose);
    await second.read(libraryCatalogControllerProvider.future);
    await _waitFor(
      second,
      (state) =>
          state.tracks.single.autoScrapedTitle == 'Embedded Title',
    );

    expect(
      retry.readCounts,
      {'/Music/legacy-null.m4a': 2},
      reason: 'one 128 KiB head plus one expanded prefix read',
    );
    expect(retry.readLengths.first, _libraryHeadBytes);
    expect(retry.readLengths.last, greaterThan(_libraryHeadBytes));

    final persisted = IsarManager.getMetadata('legacy-null')!;
    expect(persisted.embeddedMetadataReadVersion, 1);
    expect(persisted.autoScrapedTitle, 'Embedded Title');
    expect(persisted.autoScrapedArtist, 'Embedded Artist');
  });

  test('truncated expanded prefix stays unversioned and is retried', () async {
    await JsonFileScanCacheRepository(
      tempDir,
    ).saveScanResults(_source.id, [_song('legacy-truncated')]);

    final failing = _CountingMusicSource(
      _source,
      _legacyM4aFixture(),
      // The first 128 KiB read is fine; the expanded read comes back one byte
      // short, which is the network-truncation case the controller must reject.
      headResponder: (call, length, head) =>
          call == 1 ? head : Uint8List.sublistView(head, 0, head.length - 1),
    );
    final first = _container(failing);
    await first.read(libraryCatalogControllerProvider.future);
    await _waitForReads(failing, 2);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      failing.readLengths.last,
      greaterThan(_libraryHeadBytes),
      reason: 'the legacy layout forces an expanded prefix request',
    );
    expect(
      IsarManager.getMetadata('legacy-truncated')?.embeddedMetadataReadVersion,
      isNot(1),
      reason: 'a truncated prefix is a failure, not a tagless file',
    );
    expect(
      first
          .read(libraryCatalogControllerProvider)
          .valueOrNull!
          .tracks
          .single
          .autoScrapedTitle,
      isNull,
    );
    first.dispose();

    final retry = _CountingMusicSource(_source, _legacyM4aFixture());
    final second = _container(retry);
    addTearDown(second.dispose);
    await second.read(libraryCatalogControllerProvider.future);
    await _waitFor(
      second,
      (state) =>
          state.tracks.single.autoScrapedTitle == 'Embedded Title',
    );

    expect(retry.readCounts, {'/Music/legacy-truncated.m4a': 2});
    final persisted = IsarManager.getMetadata('legacy-truncated')!;
    expect(persisted.embeddedMetadataReadVersion, 1);
    expect(persisted.autoScrapedTitle, 'Embedded Title');
    expect(persisted.autoScrapedAlbum, 'Embedded Album');
  });

  test('valid prefix without tags marks the M4A attempted once', () async {
    await JsonFileScanCacheRepository(
      tempDir,
    ).saveScanResults(_source.id, [_song('plain')]);

    final firstSource = _CountingMusicSource(_source, _taglessM4aFixture());
    final first = _container(firstSource);
    await first.read(libraryCatalogControllerProvider.future);
    await _waitForMetadataVersion('plain', 1);

    expect(
      firstSource.readCounts,
      {'/Music/plain.m4a': 1},
      reason: 'a fully readable but tagless prefix is one bounded read',
    );
    expect(firstSource.readLengths, everyElement(_libraryHeadBytes));
    expect(IsarManager.getMetadata('plain')!.autoScrapedTitle, isNull);
    first.dispose();

    // Fresh startup must not reread a file that legitimately has no tags.
    final secondSource = _CountingMusicSource(_source, _taglessM4aFixture());
    final second = _container(secondSource);
    addTearDown(second.dispose);
    await second.read(libraryCatalogControllerProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(secondSource.readCounts, isEmpty);
    expect(IsarManager.getMetadata('plain')!.embeddedMetadataReadVersion, 1);
  });
}
