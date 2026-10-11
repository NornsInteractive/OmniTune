import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/database/library_scan_cache_repository_impl_io.dart';
import 'package:music/core/models/library_song.dart';

class _BackgroundSerializedSong extends LibrarySong {
  _BackgroundSerializedSong(String id, this.origin)
    : super(
        id: id,
        sourceId: 'source',
        sourceName: 'Source',
        title: 'Title',
        fileName: '$id.flac',
        remotePath: '/Music/$id.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/Music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
        manuallyScrapedTitle: 'Manual title',
        autoScrapedLyrics: '[00:01.00]Lyrics',
      );

  final Isolate origin;

  @override
  Map<String, dynamic> toJson() {
    if (Isolate.current == origin) {
      throw StateError('Song serialization blocked the calling isolate');
    }
    return super.toJson();
  }
}

void main() {
  late Directory directory;
  late JsonFileScanCacheRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('omnitune-cache-test-');
    repository = JsonFileScanCacheRepository(directory);
  });

  tearDown(() => directory.delete(recursive: true));

  test(
    'single-source save serializes off-thread and keeps other sources',
    () async {
      await repository.saveAllResults({
        'other': [_BackgroundSerializedSong('other', Isolate.current)],
      });
      await repository.saveScanResults('source', [
        _BackgroundSerializedSong('track', Isolate.current),
      ]);

      final restored = await repository.loadAllResults();
      expect(restored.keys, unorderedEquals(['source', 'other']));
      expect(restored['source']!.single.displayTitle, 'Manual title');
      expect(restored['source']!.single.autoScrapedLyrics, '[00:01.00]Lyrics');
      expect(restored['other']!.single.id, 'other');
    },
  );

  test('bulk save round trips 10000 songs and supports deletion', () async {
    final songs = List.generate(
      10000,
      (index) => _BackgroundSerializedSong('track-$index', Isolate.current),
    );
    await repository.saveAllResults({'source': songs});
    final restored = await repository.loadScanResults('source');
    expect(restored, hasLength(10000));
    expect(restored.last.id, 'track-9999');
    expect(restored.last.displayTitle, 'Manual title');
    await repository.deleteScanResults('source');
    expect(await repository.loadAllResults(), isEmpty);
    await repository.clearAll();
    expect(await repository.loadScanResults('source'), isEmpty);
  });
}
