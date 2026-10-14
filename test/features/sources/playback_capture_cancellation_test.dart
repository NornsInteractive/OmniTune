import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/models/playback_cache_settings.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final supportDirectory = Directory.systemTemp.createTempSync(
    'omnitune_playback_capture_cancellation_test_',
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
    'capture cancellation keeps audio flowing while clearing cache',
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

      final firstChunk = const [102, 76, 97, 67];
      final remainingChunk = const [1, 2, 3, 4];
      final allBytes = [...firstChunk, ...remainingChunk];

      final controller = StreamController<List<int>>();
      final received = <int>[];
      final consumed = Completer<void>();
      final subscription = cache
          .wrapPlaybackStream(
            entry: entry,
            stream: controller.stream,
            offset: 0,
            requestedEnd: null,
            expectedLength: 8,
          )
          .listen((chunk) {
            received.addAll(chunk);
            if (received.length >= firstChunk.length && !consumed.isCompleted) {
              consumed.complete();
            }
          });
      final done = subscription.asFuture<void>();

      controller.add(firstChunk);
      await consumed.future;

      await cache.clearAllCachedData();

      controller.add(remainingChunk);
      await controller.close();
      await done;

      expect(received, allBytes);
      expect(cache.snapshotForTrack(entry.uniqueId), isNull);
      expect(await cache.listCachedTracks(), isEmpty);
      expect(cache.retainedMemoryBytes, 0);
      expect(await cacheFiles(), isEmpty);
    },
  );

  test(
    'removing A while capturing keeps A audio and persists B only',
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

      final firstA = const [102, 76, 97, 67];
      final restA = const [1, 2, 3, 4];
      final allA = [...firstA, ...restA];
      final firstB = const [102, 76, 97, 67];
      final restB = const [5, 6, 7, 8];
      final allB = [...firstB, ...restB];

      final controllerA = StreamController<List<int>>();
      final controllerB = StreamController<List<int>>();
      final receivedA = <int>[];
      final receivedB = <int>[];
      final consumedA = Completer<void>();
      final consumedB = Completer<void>();

      final subA = cache
          .wrapPlaybackStream(
            entry: entryA,
            stream: controllerA.stream,
            offset: 0,
            requestedEnd: null,
            expectedLength: 8,
          )
          .listen((chunk) {
            receivedA.addAll(chunk);
            if (receivedA.length >= firstA.length && !consumedA.isCompleted) {
              consumedA.complete();
            }
          });
      final doneA = subA.asFuture<void>();

      final subB = cache
          .wrapPlaybackStream(
            entry: entryB,
            stream: controllerB.stream,
            offset: 0,
            requestedEnd: null,
            expectedLength: 8,
          )
          .listen((chunk) {
            receivedB.addAll(chunk);
            if (receivedB.length >= firstB.length && !consumedB.isCompleted) {
              consumedB.complete();
            }
          });
      final doneB = subB.asFuture<void>();

      controllerA.add(firstA);
      controllerB.add(firstB);
      await Future.wait([consumedA.future, consumedB.future]);

      await cache.removeCachedTracks({entryA.uniqueId});

      controllerA.add(restA);
      controllerB.add(restB);
      await controllerA.close();
      await controllerB.close();
      await Future.wait([doneA, doneB]);

      expect(receivedA, allA);
      expect(receivedB, allB);
      expect(cache.snapshotForTrack(entryA.uniqueId), isNull);
      expect(
        (await cache.listCachedTracks()).any(
          (item) => item.trackId == entryA.uniqueId,
        ),
        isFalse,
      );
      expect(await cache.persistentFilePathForEntry(entryA), isNull);

      final bPath = await cache.persistentFilePathForEntry(entryB);
      expect(bPath, isNotNull);
      expect(await File(bPath!).length(), 8);
      final bItem = (await cache.listCachedTracks()).firstWhere(
        (item) => item.trackId == entryB.uniqueId,
      );
      expect(bItem.cachedBytes, 8);
      expect(bItem.hasPersistentCopy, isTrue);
      final files = await cacheFiles();
      expect(files.where((file) => file.path.endsWith('.part')), isEmpty);
      expect(
        files
            .where(
              (file) =>
                  !file.path.endsWith('.part') &&
                  file.path.endsWith('.flac') &&
                  file.lengthSync() == 8,
            )
            .length,
        1,
      );
    },
  );
}
