import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:music/core/models/playback_cache_settings.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final supportDirectory = Directory.systemTemp.createTempSync(
    'omnitune_webdav_cache_test_',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async {
          return switch (call.method) {
            'getApplicationSupportDirectory' => supportDirectory.path,
            'getTemporaryDirectory' => supportDirectory.path,
            _ => null,
          };
        },
      );

  late WebDavPlaybackCache cache;

  tearDown(() async {
    await cache.clearAllCachedData();
    await cache.dispose();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
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
      // Disk writes can take longer under load; wait for persistence itself.
      final cachedTrack =
          await Stream.periodic(const Duration(milliseconds: 10), (_) => null)
              .asyncMap((_) => cache.listCachedTracks())
              .expand((tracks) => tracks)
              .firstWhere(
                (item) =>
                    item.trackId == entry.uniqueId && item.hasPersistentCopy,
              )
              .timeout(const Duration(seconds: 5));

      expect(cachedTrack.hasPersistentCopy, isTrue);
      expect(cachedTrack.cachedBytes, 8);

      final source = await cache.createCachedAudioSource(
        entry: entry,
        client: const _NoopWebDavRemoteClient(),
      );
      expect(source, isA<UriAudioSource>());
    },
  );

  test('prefetches an entire track into the persistent cache', () async {
    cache = createWebDavPlaybackCache(
      initialSettings: const PlaybackCacheSettings(
        enablePersistentCache: true,
        memoryCacheTrackLimit: 1,
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
    final client = _StreamWebDavRemoteClient(
      Uint8List.fromList(const [102, 76, 97, 67, 49, 50, 51, 52]),
    );

    await cache.prefetchEntry(entry: entry, client: client);
    await _waitFor(() async {
      final cachedTracks = await cache.listCachedTracks();
      return cachedTracks.any(
        (item) =>
            item.trackId == entry.uniqueId &&
            item.hasPersistentCopy &&
            item.cachedBytes == 8,
      );
    });

    expect(client.openReadCount, 1);
    final source = await cache.createCachedAudioSource(
      entry: entry,
      client: client,
    );
    expect(source, isA<UriAudioSource>());
  });

  test(
    'prefetches an entire track while persistent cache is disabled',
    () async {
      cache = createWebDavPlaybackCache(
        initialSettings: const PlaybackCacheSettings(
          enablePersistentCache: false,
          memoryCacheTrackLimit: 1,
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
      final client = _StreamWebDavRemoteClient(
        Uint8List.fromList(const [102, 76, 97, 67, 49, 50, 51, 52]),
      );

      await cache.prefetchEntry(entry: entry, client: client);
      await _waitFor(() async {
        final range = await cache.readCachedRange(
          entry: entry,
          start: 0,
          end: 8,
        );
        return range?.bytes.length == 8;
      });

      final cachedTracks = await cache.listCachedTracks();
      final cachedTrack = cachedTracks.singleWhere(
        (item) => item.trackId == entry.uniqueId,
      );
      expect(cachedTrack.hasPersistentCopy, isFalse);
      expect(cachedTrack.hasMemoryData, isTrue);
      expect(cachedTrack.cachedBytes, 8);
      expect(await cache.persistentFilePathForEntry(entry), isNull);
      expect(client.openReadCount, 1);

      final source = await cache.createCachedAudioSource(
        entry: entry,
        client: client,
      );
      expect(source, isA<UriAudioSource>());
      expect(source, isNot(isA<StreamAudioSource>()));
    },
  );

  test('deduplicates overlapping prefetches for the same track', () async {
    cache = createWebDavPlaybackCache(
      initialSettings: const PlaybackCacheSettings(
        enablePersistentCache: true,
        memoryCacheTrackLimit: 1,
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
    final client = _BlockingWebDavRemoteClient(
      Uint8List.fromList(const [102, 76, 97, 67, 49, 50, 51, 52]),
    );

    await cache.prefetchEntry(entry: entry, client: client);
    await cache.prefetchEntry(entry: entry, client: client);
    await _waitFor(() async => client.openReadCount == 1);

    client.release();
    await _waitFor(() async {
      final cachedTracks = await cache.listCachedTracks();
      return cachedTracks.any(
        (item) =>
            item.trackId == entry.uniqueId &&
            item.hasPersistentCopy &&
            item.cachedBytes == 8,
      );
    });

    expect(client.openReadCount, 1);
  });

  test('limits full-track prefetches to one active download', () async {
    cache = createWebDavPlaybackCache(
      initialSettings: const PlaybackCacheSettings(
        enablePersistentCache: true,
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
    final client = _BlockingWebDavRemoteClient(
      Uint8List.fromList(const [102, 76, 97, 67, 49, 50, 51, 52]),
    );

    await cache.prefetchEntry(entry: first, client: client);
    await cache.prefetchEntry(entry: second, client: client);
    await _waitFor(() async => client.openReadCount == 1);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(client.openReadCount, 1);

    client.release();
    await _waitFor(() async {
      final cachedTracks = await cache.listCachedTracks();
      return cachedTracks.any((item) => item.trackId == first.uniqueId) &&
          cachedTracks.any((item) => item.trackId == second.uniqueId);
    });

    expect(client.openReadCount, 2);
  });
}

Future<List<int>> _flatten(Stream<List<int>> stream) async {
  final bytes = <int>[];
  await for (final chunk in stream) {
    bytes.addAll(chunk);
  }
  return bytes;
}

Future<void> _waitFor(Future<bool> Function() predicate) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  fail('Timed out waiting for playback cache prefetch.');
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

class _StreamWebDavRemoteClient implements WebDavRemoteClient {
  _StreamWebDavRemoteClient(this.bytes);

  final Uint8List bytes;
  int openReadCount = 0;

  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    openReadCount++;
    final normalizedStart = start ?? 0;
    final normalizedEnd = end == null || end > bytes.length
        ? bytes.length
        : end;
    final slice = bytes.sublist(normalizedStart, normalizedEnd);
    return WebDavReadResult(
      stream: Stream<List<int>>.value(slice),
      offset: normalizedStart,
      contentLength: slice.length,
      contentType: 'audio/flac',
      sourceLength: bytes.length,
    );
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

class _BlockingWebDavRemoteClient implements WebDavRemoteClient {
  _BlockingWebDavRemoteClient(this.bytes);

  final Uint8List bytes;
  final Completer<void> _releaseCompleter = Completer<void>();
  int openReadCount = 0;

  void release() {
    if (!_releaseCompleter.isCompleted) {
      _releaseCompleter.complete();
    }
  }

  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    openReadCount++;
    final normalizedStart = start ?? 0;
    final normalizedEnd = end == null || end > bytes.length
        ? bytes.length
        : end;
    final slice = bytes.sublist(normalizedStart, normalizedEnd);
    return WebDavReadResult(
      stream: _delayedSingleChunk(slice),
      offset: normalizedStart,
      contentLength: slice.length,
      contentType: 'audio/flac',
      sourceLength: bytes.length,
    );
  }

  Stream<List<int>> _delayedSingleChunk(Uint8List slice) async* {
    await _releaseCompleter.future;
    yield slice;
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
