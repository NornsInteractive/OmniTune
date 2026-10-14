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

    cache.setActivePlaybackTrack(entry.uniqueId);
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
    'prefetch does nothing when persistent cache is disabled',
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

      cache.setActivePlaybackTrack(entry.uniqueId);
      await cache.prefetchEntry(entry: entry, client: client);

      // Prefetch should not run when persistent cache is disabled
      expect(client.openReadCount, 0);

      final cachedTracks = await cache.listCachedTracks();
      expect(cachedTracks.any((item) => item.trackId == entry.uniqueId), isFalse);
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

    cache.setActivePlaybackTrack(entry.uniqueId);
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

    cache.setActivePlaybackTrack(entry.uniqueId);
    await cache.prefetchEntry(entry: entry, client: client);
    // Second prefetch for same track should be deduplicated
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

  test(
    'sequential many chunks stores exact bytes via wrapPlaybackStream',
    () async {
      cache = createWebDavPlaybackCache(
        initialSettings: const PlaybackCacheSettings(
          enablePersistentCache: false,
          memoryCacheTrackLimit: 10,
        ),
      );
      const entry = RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 2 * 1024 * 1024,
      );

      const chunkSize = 4096;
      const numChunks = 512;
      final chunks = List.generate(
        numChunks,
        (i) => List<int>.generate(chunkSize, (j) => (i * chunkSize + j) & 0xFF),
      );
      final flattenedChunks = chunks.expand((c) => c).toList();

      await _flatten(
        cache.wrapPlaybackStream(
          entry: entry,
          stream: Stream<List<int>>.fromIterable(chunks),
          offset: 0,
          requestedEnd: null,
          expectedLength: 2 * 1024 * 1024,
        ),
      );

      final range = await cache.readCachedRange(
        entry: entry,
        start: 0,
        end: 2 * 1024 * 1024,
      );
      expect(range, isNotNull);
      expect(range!.start, 0);
      expect(range.endExclusive, 2 * 1024 * 1024);
      expect(range.bytes, Uint8List.fromList(flattenedChunks));
    },
  );

  test(
    'out of order overlap newest wins and holes remain until bridged',
    () async {
      cache = createWebDavPlaybackCache(
        initialSettings: const PlaybackCacheSettings(
          enablePersistentCache: false,
          memoryCacheTrackLimit: 10,
        ),
      );
      const entry = RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 100,
      );

      final stream1 = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream<List<int>>.fromIterable([
          [1, 2, 3, 4, 5],
        ]),
        offset: 0,
        requestedEnd: 5,
        expectedLength: 100,
      );

      final stream2 = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream<List<int>>.fromIterable([
          [10, 20, 30, 40, 50],
        ]),
        offset: 50,
        requestedEnd: 55,
        expectedLength: 100,
      );

      final stream3 = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream<List<int>>.fromIterable([
          [100, 200, 300, 400, 500],
        ]),
        offset: 20,
        requestedEnd: 25,
        expectedLength: 100,
      );

      await _flatten(stream1);
      await _flatten(stream2);
      await _flatten(stream3);

      final range1 = await cache.readCachedRange(
        entry: entry,
        start: 0,
        end: 10,
      );
      expect(range1, isNotNull);
      expect(range1!.bytes, Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(range1.endExclusive, 5);

      final range2 = await cache.readCachedRange(
        entry: entry,
        start: 20,
        end: 30,
      );
      expect(range2, isNotNull);
      expect(range2!.bytes, Uint8List.fromList([100, 200, 300, 400, 500]));

      final range3 = await cache.readCachedRange(
        entry: entry,
        start: 50,
        end: 60,
      );
      expect(range3, isNotNull);
      expect(range3!.bytes, Uint8List.fromList([10, 20, 30, 40, 50]));

      final hole = await cache.readCachedRange(entry: entry, start: 5, end: 20);
      expect(hole, isNull);

      await _flatten(
        cache.wrapPlaybackStream(
          entry: entry,
          stream: Stream<List<int>>.fromIterable([
            List<int>.generate(15, (i) => 99),
          ]),
          offset: 5,
          requestedEnd: 20,
          expectedLength: 100,
        ),
      );

      final bridged = await cache.readCachedRange(
        entry: entry,
        start: 0,
        end: 25,
      );
      expect(bridged, isNotNull);
      expect(bridged!.bytes.length, 25);
      expect(bridged.bytes.sublist(0, 5), Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(
        bridged.bytes.sublist(5, 20),
        Uint8List.fromList(List<int>.filled(15, 99)),
      );
      expect(
        bridged.bytes.sublist(20, 25),
        Uint8List.fromList([100, 200, 300, 400, 500]),
      );

      final overwrite = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream<List<int>>.fromIterable([
          [7, 8, 9, 10, 11],
        ]),
        offset: 3,
        requestedEnd: 8,
        expectedLength: 100,
      );
      await _flatten(overwrite);

      final afterOverwrite = await cache.readCachedRange(
        entry: entry,
        start: 0,
        end: 10,
      );
      expect(afterOverwrite, isNotNull);
      expect(
        afterOverwrite!.bytes,
        Uint8List.fromList([1, 2, 3, 7, 8, 9, 10, 11, 99, 99]),
      );
      expect(afterOverwrite.endExclusive, 10);

      final hole2 = await cache.readCachedRange(
        entry: entry,
        start: 8,
        end: 20,
      );
      expect(hole2, isNotNull);
      expect(hole2!.bytes, Uint8List.fromList(List<int>.filled(12, 99)));

      await _flatten(
        cache.wrapPlaybackStream(
          entry: entry,
          stream: Stream<List<int>>.fromIterable([
            List<int>.generate(47, (i) => i + 200),
          ]),
          offset: 8,
          requestedEnd: 55,
          expectedLength: 100,
        ),
      );

      final full = await cache.readCachedRange(entry: entry, start: 0, end: 55);
      expect(full, isNotNull);
      expect(full!.bytes.length, 55);
      expect(full.bytes.sublist(0, 3), Uint8List.fromList([1, 2, 3]));
      expect(full.bytes.sublist(3, 8), Uint8List.fromList([7, 8, 9, 10, 11]));
      expect(
        full.bytes.sublist(8, 20),
        Uint8List.fromList(List<int>.generate(12, (i) => i + 200)),
      );
      expect(
        full.bytes.sublist(20, 25),
        Uint8List.fromList(List<int>.generate(5, (i) => i + 212)),
      );
      expect(
        full.bytes.sublist(25, 50),
        Uint8List.fromList(List<int>.generate(25, (i) => i + 217)),
      );
      expect(
        full.bytes.sublist(50, 55),
        Uint8List.fromList(List<int>.generate(5, (i) => i + 242)),
      );

      final prepend = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream<List<int>>.fromIterable([
          [0, 0],
        ]),
        offset: 0,
        requestedEnd: 2,
        expectedLength: 100,
      );
      await _flatten(prepend);
      final prepended = await cache.readCachedRange(
        entry: entry,
        start: 0,
        end: 2,
      );
      expect(prepended, isNotNull);
      expect(prepended!.bytes, Uint8List.fromList([0, 0]));
    },
  );

  test('many chunks notifications throttled and final bytes emitted', () async {
    cache = createWebDavPlaybackCache(
      initialSettings: const PlaybackCacheSettings(
        enablePersistentCache: false,
        memoryCacheTrackLimit: 10,
      ),
    );
    const entry = RemoteEntry(
      sourceId: 'source-1',
      name: 'song.flac',
      path: '/Music/song.flac',
      kind: RemoteEntryKind.audio,
      mimeType: 'audio/flac',
      size: 1000,
    );

    final snapshots = <PlaybackCacheSnapshot>[];
    final sub = cache.snapshotStream
        .where((s) => s.trackId == entry.uniqueId)
        .listen(snapshots.add);

    final chunks = List.generate(50, (i) => List<int>.filled(20, i));
    await _flatten(
      cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream<List<int>>.fromIterable(chunks),
        offset: 0,
        requestedEnd: null,
        expectedLength: 1000,
      ),
    );

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(
      snapshots.length,
      lessThanOrEqualTo(3),
      reason:
          'snapshots should be throttled to first + final + optional pending timer',
    );
    final lastSnapshot = snapshots.last;
    expect(lastSnapshot.totalLength, 1000);
    expect(lastSnapshot.segments.length, 1);
    expect(lastSnapshot.segments.single.endExclusive, 1000);
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
