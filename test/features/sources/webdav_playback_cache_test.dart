import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:music/core/models/playback_cache_settings.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';

void main() {
  late WebDavPlaybackCache cache;

  tearDown(() async {
    await cache.clearAllCachedData();
    await cache.dispose();
  });

  test('stores a fully streamed track in memory for later playback', () async {
    cache = createWebDavPlaybackCache(
      initialSettings: const PlaybackCacheSettings(
        enablePersistentCache: false,
        memoryCacheTrackLimit: 2,
      ),
    );
    const entry = RemoteEntry(
      sourceId: 'source-1',
      name: 'song.flac',
      path: '/Music/song.flac',
      kind: RemoteEntryKind.audio,
      mimeType: 'audio/flac',
      size: 8,
    );

    final capturedStream = cache.wrapPlaybackStream(
      entry: entry,
      stream: Stream<List<int>>.fromIterable(const [
        [102, 76, 97, 67],
        [49, 50, 51, 52],
      ]),
      offset: 0,
      requestedEnd: null,
      expectedLength: 8,
    );

    expect(await _flatten(capturedStream), hasLength(8));

    final source = await cache.createCachedAudioSource(
      entry: entry,
      client: const _NoopWebDavRemoteClient(),
    );
    expect(source, isA<StreamAudioSource>());

    final response = await (source! as StreamAudioSource).request(0, null);
    expect(response.contentType, 'audio/flac');
    expect(
      Uint8List.fromList(await _flatten(response.stream)),
      Uint8List.fromList(const [102, 76, 97, 67, 49, 50, 51, 52]),
    );
  });

  test('keeps partially played byte ranges in memory', () async {
    cache = createWebDavPlaybackCache(
      initialSettings: const PlaybackCacheSettings(
        enablePersistentCache: false,
        memoryCacheTrackLimit: 2,
      ),
    );
    const entry = RemoteEntry(
      sourceId: 'source-1',
      name: 'song.flac',
      path: '/Music/song.flac',
      kind: RemoteEntryKind.audio,
      mimeType: 'audio/flac',
      size: 8,
    );

    await _flatten(
      cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream<List<int>>.fromIterable(const [
          [102, 76, 97, 67],
        ]),
        offset: 0,
        requestedEnd: 4,
        expectedLength: 8,
      ),
    );

    final cachedRange = await cache.readCachedRange(
      entry: entry,
      start: 0,
      end: 8,
    );

    expect(cachedRange, isNotNull);
    expect(cachedRange!.start, 0);
    expect(cachedRange.endExclusive, 4);
    expect(cachedRange.bytes, Uint8List.fromList(const [102, 76, 97, 67]));
    expect(
      await cache.createCachedAudioSource(
        entry: entry,
        client: const _NoopWebDavRemoteClient(),
      ),
      isNull,
    );
  });

  test('evicts older memory-cached tracks when the limit is reached', () async {
    cache = createWebDavPlaybackCache(
      initialSettings: const PlaybackCacheSettings(
        enablePersistentCache: false,
        memoryCacheTrackLimit: 1,
      ),
    );

    const first = RemoteEntry(
      sourceId: 'source-1',
      name: 'first.flac',
      path: '/Music/first.flac',
      kind: RemoteEntryKind.audio,
      mimeType: 'audio/flac',
      size: 8,
    );
    const second = RemoteEntry(
      sourceId: 'source-1',
      name: 'second.flac',
      path: '/Music/second.flac',
      kind: RemoteEntryKind.audio,
      mimeType: 'audio/flac',
      size: 8,
    );

    await _flatten(
      cache.wrapPlaybackStream(
        entry: first,
        stream: Stream<List<int>>.fromIterable(const [
          [102, 76, 97, 67],
          [49, 50, 51, 52],
        ]),
        offset: 0,
        requestedEnd: null,
        expectedLength: 8,
      ),
    );
    await _flatten(
      cache.wrapPlaybackStream(
        entry: second,
        stream: Stream<List<int>>.fromIterable(const [
          [102, 76, 97, 67],
          [53, 54, 55, 56],
        ]),
        offset: 0,
        requestedEnd: null,
        expectedLength: 8,
      ),
    );

    expect(
      await cache.createCachedAudioSource(
        entry: first,
        client: const _NoopWebDavRemoteClient(),
      ),
      isNull,
    );
    expect(
      await cache.createCachedAudioSource(
        entry: second,
        client: const _NoopWebDavRemoteClient(),
      ),
      isNotNull,
    );
  });

  test(
    'persists fully cached in-memory tracks after enabling local file cache',
    () async {
      cache = createWebDavPlaybackCache(
        initialSettings: const PlaybackCacheSettings(
          enablePersistentCache: false,
          memoryCacheTrackLimit: 2,
        ),
      );
      const entry = RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 8,
      );

      await _flatten(
        cache.wrapPlaybackStream(
          entry: entry,
          stream: Stream<List<int>>.fromIterable(const [
            [102, 76, 97, 67],
            [49, 50, 51, 52],
          ]),
          offset: 0,
          requestedEnd: null,
          expectedLength: 8,
        ),
      );

      cache.applySettings(
        const PlaybackCacheSettings(
          enablePersistentCache: true,
          memoryCacheTrackLimit: 2,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final cachedTracks = await cache.listCachedTracks();
      final cachedTrack = cachedTracks.singleWhere(
        (item) => item.trackId == entry.uniqueId,
      );

      expect(cachedTrack.hasPersistentCopy, isTrue);
      expect(cachedTrack.cachedBytes, 8);

      final source = await cache.createCachedAudioSource(
        entry: entry,
        client: const _NoopWebDavRemoteClient(),
      );
      expect(source, isA<UriAudioSource>());
    },
  );
}

Future<List<int>> _flatten(Stream<List<int>> stream) async {
  final bytes = <int>[];
  await for (final chunk in stream) {
    bytes.addAll(chunk);
  }
  return bytes;
}

class _NoopWebDavRemoteClient implements WebDavRemoteClient {
  const _NoopWebDavRemoteClient();

  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) {
    throw UnimplementedError();
  }

  @override
  Future<void> ping() async {}

  @override
  Future<List<WebDavRemoteFile>> readDirectory(String path) {
    throw UnimplementedError();
  }

  @override
  Future<String?> readText(String path) {
    throw UnimplementedError();
  }
}
