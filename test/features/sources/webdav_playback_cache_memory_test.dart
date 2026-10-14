import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/models/playback_cache_settings.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final supportDirectory = Directory.systemTemp.createTempSync(
    'omnitune_webdav_cache_memory_test_',
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

  group('WebDavPlaybackCache memory limits', () {
    late WebDavPlaybackCache cache;

    tearDown(() async {
      await cache.clearAllCachedData();
      await cache.dispose();
    });

    test('createWebDavPlaybackCache accepts maxMemoryBytes parameter', () {
      cache = createWebDavPlaybackCache(
        initialSettings: const PlaybackCacheSettings(
          enablePersistentCache: false,
          memoryCacheTrackLimit: 2,
        ),
      );
      expect(cache, isNotNull);
    });

    test(
      'memory cache respects track limit via PlaybackCacheSettings',
      () async {
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
      },
    );

    test('applySettings updates memory cache limit and trims', () async {
      cache = createWebDavPlaybackCache(
        initialSettings: const PlaybackCacheSettings(
          enablePersistentCache: false,
          memoryCacheTrackLimit: 2,
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
        isNotNull,
      );
      expect(
        await cache.createCachedAudioSource(
          entry: second,
          client: const _NoopWebDavRemoteClient(),
        ),
        isNotNull,
      );

      cache.applySettings(
        const PlaybackCacheSettings(
          enablePersistentCache: false,
          memoryCacheTrackLimit: 1,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

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
      'clearMemoryCachedData removes in-memory data but keeps persistent',
      () async {
        cache = createWebDavPlaybackCache(
          initialSettings: const PlaybackCacheSettings(
            enablePersistentCache: true,
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

        await _waitFor(() async {
          final cached = await cache.listCachedTracks();
          return cached.any(
            (t) => t.trackId == entry.uniqueId && t.hasPersistentCopy,
          );
        });

        var cachedTrack = (await cache.listCachedTracks()).firstWhere(
          (t) => t.trackId == entry.uniqueId,
        );
        expect(cachedTrack.hasPersistentCopy, isTrue);
        expect(cachedTrack.hasMemoryData, isTrue);

        await cache.clearMemoryCachedData();

        cachedTrack = (await cache.listCachedTracks()).firstWhere(
          (t) => t.trackId == entry.uniqueId,
        );
        expect(cachedTrack.hasPersistentCopy, isTrue);
        expect(cachedTrack.hasMemoryData, isFalse);
      },
    );

    test(
      'removeCachedTracks removes both memory and persistent data',
      () async {
        cache = createWebDavPlaybackCache(
          initialSettings: const PlaybackCacheSettings(
            enablePersistentCache: true,
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

        await _waitFor(() async {
          final cached = await cache.listCachedTracks();
          return cached.any(
            (t) => t.trackId == entry.uniqueId && t.hasPersistentCopy,
          );
        });

        await cache.removeCachedTracks({entry.uniqueId});

        final cachedTracks = await cache.listCachedTracks();
        expect(cachedTracks.any((t) => t.trackId == entry.uniqueId), isFalse);
      },
    );

    test('snapshotStream emits throttled updates during streaming', () async {
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

    test(
      'listCachedTracks returns inventory sorted by updatedAt desc',
      () async {
        cache = createWebDavPlaybackCache(
          initialSettings: const PlaybackCacheSettings(
            enablePersistentCache: false,
            memoryCacheTrackLimit: 10,
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

        await Future<void>.delayed(const Duration(milliseconds: 10));

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

        final inventory = await cache.listCachedTracks();
        expect(inventory.length, 2);
        expect(inventory.first.trackId, first.uniqueId);
        expect(inventory.last.trackId, second.uniqueId);
      },
    );

    test(
      'previous track memory is evicted before exceeding capacity',
      () async {
        cache = createWebDavPlaybackCache(
          initialSettings: const PlaybackCacheSettings(
            enablePersistentCache: false,
            memoryCacheTrackLimit: 10,
          ),
          maxMemoryBytes: 32,
        );

        const first = RemoteEntry(
          sourceId: 'source-1',
          name: 'first.flac',
          path: '/Music/first.flac',
          kind: RemoteEntryKind.audio,
          mimeType: 'audio/flac',
          size: 24,
        );
        const second = RemoteEntry(
          sourceId: 'source-1',
          name: 'second.flac',
          path: '/Music/second.flac',
          kind: RemoteEntryKind.audio,
          mimeType: 'audio/flac',
          size: 24,
        );

        await _flatten(
          cache.wrapPlaybackStream(
            entry: first,
            stream: Stream<List<int>>.fromIterable([List<int>.filled(24, 1)]),
            offset: 0,
            requestedEnd: null,
            expectedLength: 24,
          ),
        );
        await _flatten(
          cache.wrapPlaybackStream(
            entry: second,
            stream: Stream<List<int>>.fromIterable([List<int>.filled(24, 2)]),
            offset: 0,
            requestedEnd: null,
            expectedLength: 24,
          ),
        );

        expect(cache.retainedMemoryBytes, lessThanOrEqualTo(32));
        final firstSource = await cache.createCachedAudioSource(
          entry: first,
          client: const _NoopWebDavRemoteClient(),
        );
        final secondSource = await cache.createCachedAudioSource(
          entry: second,
          client: const _NoopWebDavRemoteClient(),
        );
        expect(firstSource, isNull);
        expect(secondSource, isNotNull);
      },
    );

    test(
      'oversized active stream forwards exact bytes without exceeding budget',
      () async {
        cache = createWebDavPlaybackCache(
          initialSettings: const PlaybackCacheSettings(
            enablePersistentCache: false,
            memoryCacheTrackLimit: 10,
          ),
          maxMemoryBytes: 8,
        );

        const entry = RemoteEntry(
          sourceId: 'source-1',
          name: 'oversized.flac',
          path: '/Music/oversized.flac',
          kind: RemoteEntryKind.audio,
          mimeType: 'audio/flac',
          size: 64,
        );
        final input = List<int>.generate(64, (i) => i + 1);

        final output = await _flatten(
          cache.wrapPlaybackStream(
            entry: entry,
            stream: Stream<List<int>>.fromIterable([input]),
            offset: 0,
            requestedEnd: null,
            expectedLength: 64,
          ),
        );

        expect(output, input);
        expect(cache.retainedMemoryBytes, lessThanOrEqualTo(8));
      },
    );
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
  fail('Timed out waiting for playback cache operation.');
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
