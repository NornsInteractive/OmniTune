import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
    'omnitune_webdav_cache_safety_test_',
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

  Future<void> waitFor(Future<bool> Function() predicate) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (DateTime.now().isBefore(deadline)) {
      if (await predicate()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    fail('Timed out waiting for playback cache prefetch.');
  }

  Future<List<File>> cacheFiles() async {
    final dir = Directory(
      '${supportDirectory.path}/flux_music_player/webdav_cache',
    );
    if (!await dir.exists()) {
      return [];
    }
    return dir.listSync().whereType<File>().toList();
  }

  test(
    'Case 1: unknown total - .part full 8 bytes, persistent path null, no persistent copy',
    () async {
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
        size: null,
      );

      final client = _UnknownTotalClient();

      cache.setActivePlaybackTrack(entry.uniqueId);
      await cache.prefetchEntry(entry: entry, client: client);

      await waitFor(() async {
        final files = await cacheFiles();
        final partFiles = files.where((f) => f.path.endsWith('.part')).toList();
        return partFiles.isNotEmpty && partFiles.first.lengthSync() == 8;
      });

      final persistent = await cache.persistentFilePathForEntry(entry);
      expect(persistent, isNull);

      final cachedTracks = await cache.listCachedTracks();
      expect(
        cachedTracks.any(
          (item) => item.trackId == entry.uniqueId && item.hasPersistentCopy,
        ),
        isFalse,
      );
    },
  );

  test(
    'Case 2: mismatched offset - stream canceled, no data appended/finalized',
    () async {
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

      final client = _MismatchedOffsetClient();

      cache.setActivePlaybackTrack(entry.uniqueId);
      await cache.prefetchEntry(entry: entry, client: client);

      await waitFor(() async => client.canceled.isCompleted);

      expect(client.openReadCount, 1);

      final files = await cacheFiles();
      final partFiles = files.where((f) => f.path.endsWith('.part')).toList();
      expect(partFiles, isEmpty);

      final flacFiles = files
          .where((f) => f.path.endsWith('.flac') && !f.path.endsWith('.part'))
          .toList();
      expect(flacFiles, isEmpty);

      final cachedTracks = await cache.listCachedTracks();
      expect(
        cachedTracks.any((item) => item.trackId == entry.uniqueId),
        isFalse,
      );
    },
  );

  test(
    'Case 3: switch target cancels previous prefetch - A canceled, B complete',
    () async {
      cache = createWebDavPlaybackCache(
        initialSettings: const PlaybackCacheSettings(
          enablePersistentCache: true,
          memoryCacheTrackLimit: 2,
        ),
      );
      const entryA = RemoteEntry(
        sourceId: 'source-a',
        name: 'songA.flac',
        path: '/Music/songA.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 8,
      );
      const entryB = RemoteEntry(
        sourceId: 'source-b',
        name: 'songB.flac',
        path: '/Music/songB.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 8,
      );

      final clientA = _ControlledSlowClient();
      final clientB = _FastClient();

      cache.setActivePlaybackTrack(entryA.uniqueId);
      await cache.prefetchEntry(entry: entryA, client: clientA);

      await waitFor(() async => clientA.subscribed.isCompleted);

      cache.setActivePlaybackTrack(entryB.uniqueId);
      await cache.prefetchEntry(entry: entryB, client: clientB);

      await waitFor(() async => clientA.canceled.isCompleted);

      await waitFor(() async {
        final cachedTracks = await cache.listCachedTracks();
        return cachedTracks.any(
          (item) =>
              item.trackId == entryB.uniqueId &&
              item.hasPersistentCopy &&
              item.cachedBytes == 8,
        );
      });

      final cachedTracks = await cache.listCachedTracks();
      final aTracks = cachedTracks.where(
        (item) => item.trackId == entryA.uniqueId,
      );
      if (aTracks.isNotEmpty) {
        expect(aTracks.first.hasPersistentCopy, isFalse);
      }

      final bTrack = cachedTracks.firstWhere(
        (item) => item.trackId == entryB.uniqueId,
      );
      expect(bTrack.hasPersistentCopy, isTrue);
      expect(bTrack.cachedBytes, 8);

      final files = await cacheFiles();
      final bFlac = files
          .where(
            (f) =>
                f.path.endsWith('.flac') &&
                !f.path.endsWith('.part') &&
                f.lengthSync() == 8,
          )
          .toList();
      expect(bFlac, isNotEmpty);
    },
  );

  test(
    'Case 4: removing unrelated track does not cancel current prefetch',
    () async {
      cache = createWebDavPlaybackCache(
        initialSettings: const PlaybackCacheSettings(
          enablePersistentCache: true,
          memoryCacheTrackLimit: 2,
        ),
      );
      const entryA = RemoteEntry(
        sourceId: 'source-a',
        name: 'songA.flac',
        path: '/Music/songA.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 8,
      );
      const entryB = RemoteEntry(
        sourceId: 'source-b',
        name: 'songB.flac',
        path: '/Music/songB.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 8,
      );

      final clientB = _ControlledSlowClient();

      cache.setActivePlaybackTrack(entryB.uniqueId);
      await cache.prefetchEntry(entry: entryB, client: clientB);

      await waitFor(() async => clientB.subscribed.isCompleted);

      await cache.removeCachedTracks({entryA.uniqueId});

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(clientB.canceled.isCompleted, isFalse);

      clientB.completeWith(
        Uint8List.fromList(const [102, 76, 97, 67, 49, 50, 51, 52]),
      );

      await waitFor(() async {
        final cachedTracks = await cache.listCachedTracks();
        return cachedTracks.any(
          (item) =>
              item.trackId == entryB.uniqueId &&
              item.hasPersistentCopy &&
              item.cachedBytes == 8,
        );
      });

      final cachedTracks = await cache.listCachedTracks();
      final bTrack = cachedTracks.firstWhere(
        (item) => item.trackId == entryB.uniqueId,
      );
      expect(bTrack.hasPersistentCopy, isTrue);
      expect(bTrack.cachedBytes, 8);

      final files = await cacheFiles();
      final bFlac = files
          .where(
            (f) =>
                f.path.endsWith('.flac') &&
                !f.path.endsWith('.part') &&
                f.lengthSync() == 8,
          )
          .toList();
      expect(bFlac, isNotEmpty);
    },
  );

  test(
    'Case 5: authoritative null with stale size5 writes all10 .part without finalizing',
    () async {
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
        size: 5,
      );

      final client = _AuthoritativeNullClient();

      cache.setActivePlaybackTrack(entry.uniqueId);
      await cache.prefetchEntry(entry: entry, client: client);

      await waitFor(() async {
        final files = await cacheFiles();
        final partFiles = files.where((f) => f.path.endsWith('.part')).toList();
        return partFiles.isNotEmpty && partFiles.first.lengthSync() == 10;
      });

      final persistent = await cache.persistentFilePathForEntry(entry);
      expect(persistent, isNull);

      final files = await cacheFiles();
      final flacFiles = files
          .where((f) => f.path.endsWith('.flac') && !f.path.endsWith('.part'))
          .toList();
      expect(flacFiles, isEmpty);
    },
  );

  test('Case 6: normal WebDAV null total with size10 finalizes', () async {
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
      size: 10,
    );

    final client = _TenByteWebDavClient();

    cache.setActivePlaybackTrack(entry.uniqueId);
    await cache.prefetchEntry(entry: entry, client: client);

    await waitFor(() async {
      final files = await cacheFiles();
      return files.any(
        (f) =>
            f.path.endsWith('.flac') &&
            !f.path.endsWith('.part') &&
            f.lengthSync() == 10,
      );
    });
  });

  test(
    'wrap preserves earlier valid total10 and finalizes with later null chunk',
    () async {
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
        size: null,
      );

      final first = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream.value(const [102, 76, 97, 67]),
        offset: 0,
        requestedEnd: null,
        expectedLength: 10,
      );
      await first.drain<void>();

      final second = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream.value(const [5, 6, 7, 8, 9, 10]),
        offset: 4,
        requestedEnd: null,
        expectedLength: null,
      );
      await second.drain<void>();

      await waitFor(() async {
        final files = await cacheFiles();
        return files.any(
          (f) =>
              f.path.endsWith('.flac') &&
              !f.path.endsWith('.part') &&
              f.lengthSync() == 10,
        );
      });

      final files = await cacheFiles();
      final flac = files.firstWhere(
        (f) => f.path.endsWith('.flac') && !f.path.endsWith('.part'),
      );
      expect(flac.lengthSync(), 10);
      final tracks = await cache.listCachedTracks();
      final track = tracks.firstWhere((item) => item.trackId == entry.uniqueId);
      expect(track.totalBytes, 10);
    },
  );

  test(
    'wrap invalid old total5 becomes unknown and does not persist truncated file',
    () async {
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
        size: 5,
      );

      final first = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream.value(const [1, 2, 3, 4]),
        offset: 0,
        requestedEnd: null,
        expectedLength: 5,
      );
      await first.drain<void>();

      final second = cache.wrapPlaybackStream(
        entry: entry,
        stream: Stream.value(const [5, 6, 7, 8, 9, 10]),
        offset: 4,
        requestedEnd: null,
        expectedLength: null,
      );
      await second.drain<void>();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final files = await cacheFiles();
      final flacFiles = files
          .where((f) => f.path.endsWith('.flac') && !f.path.endsWith('.part'))
          .toList();
      expect(flacFiles, isEmpty);

      final snapshot = cache.snapshotForTrack(entry.uniqueId);
      expect(snapshot, isNotNull);
      expect(snapshot!.totalLength, isNull);
      expect(snapshot.segments, isNotEmpty);
      expect(snapshot.segments.first.endExclusive, 10);
    },
  );
}

class _AuthoritativeNullClient implements WebDavRemoteClient {
  int openReadCount = 0;
  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;
  @override
  Future<void> dispose() async {}
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

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    openReadCount++;
    final bytes = Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    return WebDavReadResult(
      stream: Stream<List<int>>.value(bytes),
      offset: 0,
      contentLength: 10,
      contentType: 'audio/flac',
      sourceLength: null,
      sourceLengthIsAuthoritative: true,
    );
  }
}

class _TenByteWebDavClient implements WebDavRemoteClient {
  int openReadCount = 0;
  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;
  @override
  Future<void> dispose() async {}
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

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    openReadCount++;
    final bytes = Uint8List.fromList(const [
      102,
      76,
      97,
      67,
      5,
      6,
      7,
      8,
      9,
      10,
    ]);
    return WebDavReadResult(
      stream: Stream<List<int>>.value(bytes),
      offset: 0,
      contentLength: bytes.length,
      contentType: 'audio/flac',
      sourceLength: null,
    );
  }
}

class _UnknownTotalClient implements WebDavRemoteClient {
  int openReadCount = 0;

  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    openReadCount++;
    final bytes = Uint8List.fromList(const [102, 76, 97, 67, 49, 50, 51, 52]);
    return WebDavReadResult(
      stream: Stream<List<int>>.value(bytes),
      offset: 0,
      contentLength: 8,
      contentType: 'audio/flac',
      sourceLength: null,
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

class _MismatchedOffsetClient implements WebDavRemoteClient {
  int openReadCount = 0;
  final Completer<void> canceled = Completer<void>();

  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    openReadCount++;
    final controller = StreamController<List<int>>(
      onCancel: () {
        if (!canceled.isCompleted) {
          canceled.complete();
        }
      },
    );
    controller.onListen = () {
      controller.add(const [49, 50, 51, 52]);
      controller.close();
    };
    return WebDavReadResult(
      stream: controller.stream,
      offset: 4,
      contentLength: 4,
      contentType: 'audio/flac',
      sourceLength: 8,
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

class _ControlledSlowClient implements WebDavRemoteClient {
  int openReadCount = 0;
  late StreamController<List<int>> controller;
  final Completer<void> subscribed = Completer<void>();
  final Completer<void> canceled = Completer<void>();

  void completeWith(Uint8List bytes) {
    controller.add(bytes);
    controller.close();
  }

  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    openReadCount++;
    controller = StreamController<List<int>>(
      onListen: () {
        if (!subscribed.isCompleted) {
          subscribed.complete();
        }
      },
      onCancel: () {
        if (!canceled.isCompleted) {
          canceled.complete();
        }
      },
    );
    return WebDavReadResult(
      stream: controller.stream,
      offset: 0,
      contentLength: 8,
      contentType: 'audio/flac',
      sourceLength: 8,
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

class _FastClient implements WebDavRemoteClient {
  int openReadCount = 0;

  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    openReadCount++;
    final bytes = Uint8List.fromList(const [102, 76, 97, 67, 49, 50, 51, 52]);
    return WebDavReadResult(
      stream: Stream<List<int>>.value(bytes),
      offset: 0,
      contentLength: bytes.length,
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
