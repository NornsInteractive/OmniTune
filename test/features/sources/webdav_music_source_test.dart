import 'package:music/core/models/playback_cache_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/features/sources/data/webdav/webdav_music_source.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';

class _MockWebDavRemoteClient extends Mock implements WebDavRemoteClient {}

class _FakePlaybackCache implements WebDavPlaybackCache {
  AudioSource? cachedSource;

  @override
  int get retainedMemoryBytes => 0;

  @override
  void applySettings(PlaybackCacheSettings settings) {}

  @override
  void setActivePlaybackTrack(String? trackId) {}

  @override
  Stream<PlaybackCacheSnapshot> get snapshotStream =>
      const Stream<PlaybackCacheSnapshot>.empty();

  @override
  PlaybackCacheSnapshot? snapshotForTrack(String trackId) => null;

  @override
  Stream<List<PlaybackCacheInventoryItem>> watchCachedTracks() =>
      const Stream<List<PlaybackCacheInventoryItem>>.empty();

  @override
  Future<List<PlaybackCacheInventoryItem>> listCachedTracks() async =>
      const <PlaybackCacheInventoryItem>[];

  @override
  Future<AudioSource?> createCachedAudioSource({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  }) async {
    return cachedSource;
  }

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
    return null;
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
  }) {
    return stream;
  }

  @override
  Future<void> clearAllCachedData() async {}

  @override
  Future<void> clearMemoryCachedData() async {}

  @override
  Future<void> removeCachedTracks(Set<String> trackIds) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late _MockWebDavRemoteClient client;
  late _FakePlaybackCache playbackCache;
  late SourceProfile profile;

  setUp(() {
    client = _MockWebDavRemoteClient();
    playbackCache = _FakePlaybackCache();
    profile = const SourceProfile(
      id: 'source-1',
      name: 'Home DAV',
      protocol: SourceProtocol.webdav,
      baseUrl: 'https://dav.example.com/files/',
      username: 'demo',
      password: 'secret',
      rootPath: '/Music/',
    );

    when(() => client.ping()).thenAnswer((_) async {});
    when(() => client.dispose()).thenAnswer((_) async {});
    when(() => client.readText(any())).thenAnswer((_) async => null);
    when(() => client.lastDirectoryDebugInfo).thenReturn(null);
  });

  test('sorts directories before audio and other files', () async {
    when(() => client.readDirectory('/Music/')).thenAnswer(
      (_) async => const [
        WebDavRemoteFile(
          path: '/Music/notes.txt',
          name: 'notes.txt',
          isDirectory: false,
          mimeType: 'text/plain',
        ),
        WebDavRemoteFile(
          path: '/Music/Album/',
          name: 'Album',
          isDirectory: true,
        ),
        WebDavRemoteFile(
          path: '/Music/song.flac',
          name: 'song.flac',
          isDirectory: false,
          mimeType: 'audio/flac',
        ),
      ],
    );

    final source = WebDavMusicSource(
      profile,
      clientFactory: (_) => client,
      playbackCacheFactory: () => playbackCache,
    );

    final listing = await source.listFiles('/Music/');
    final entries = listing.entries;

    expect(entries.map((entry) => entry.kind), [
      RemoteEntryKind.directory,
      RemoteEntryKind.audio,
      RemoteEntryKind.file,
    ]);
    expect(entries.first.path, '/Music/Album/');
    expect(entries[1].path, '/Music/song.flac');
  });

  test('builds playable track metadata for audio file', () async {
    when(
      () => client.openRead(
        '/Music/song.flac',
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer(
      (_) async => WebDavReadResult(
        stream: Stream.value(const [1, 2, 3]),
        offset: 0,
        contentLength: 3,
        contentType: 'application/octet-stream',
        sourceLength: 3,
      ),
    );

    final source = WebDavMusicSource(
      profile,
      clientFactory: (_) => client,
      playbackCacheFactory: () => playbackCache,
    );

    final track = await source.buildPlayableTrack(
      const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 1024,
      ),
    );

    expect(track.id, 'source-1::/Music/song.flac');
    expect(track.sourceId, 'source-1');
    expect(track.title, 'song');
    expect(track.sourceName, 'Home DAV');
    expect(track.audioSource, isA<StreamAudioSource>());

    final response = await (track.audioSource as StreamAudioSource).request(
      0,
      null,
    );
    expect(response.contentType, 'audio/flac');
  });

  test('uses cached audio source without reconnecting to WebDAV', () async {
    playbackCache.cachedSource = AudioSource.uri(
      Uri.parse('file:///tmp/cached-song.flac'),
    );

    final source = WebDavMusicSource(
      profile,
      clientFactory: (_) => client,
      playbackCacheFactory: () => playbackCache,
    );

    final track = await source.buildPlayableTrack(
      const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 1024,
      ),
    );

    expect(track.audioSource, same(playbackCache.cachedSource));
    verifyNever(() => client.ping());
    verifyNever(
      () => client.openRead(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    );
  });

  test('caches remote lyric reads within the same source session', () async {
    when(
      () => client.readText('/Music/song.lrc'),
    ).thenAnswer((_) async => '[00:00.00]Hello');

    final source = WebDavMusicSource(
      profile,
      clientFactory: (_) => client,
      playbackCacheFactory: () => playbackCache,
    );

    final first = await source.readTextFile('/Music/song.lrc');
    final second = await source.readTextFile('/Music/song.lrc');

    expect(first, '[00:00.00]Hello');
    expect(second, '[00:00.00]Hello');
    verify(() => client.ping()).called(1);
    verify(() => client.readText('/Music/song.lrc')).called(1);
  });

  test('deduplicates root path when base url already points to folder', () {
    const profile = SourceProfile(
      id: 'source-2',
      name: 'Nested DAV',
      protocol: SourceProtocol.webdav,
      baseUrl: 'https://dav.example.com/files/Music/',
      username: 'demo',
      password: 'secret',
      rootPath: '/Music/',
    );

    expect(profile.effectiveRootPath, '/');
  });
}
