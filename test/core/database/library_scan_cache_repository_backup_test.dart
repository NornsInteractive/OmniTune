import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/database/library_scan_cache_repository_impl_io.dart';
import 'package:music/core/models/library_song.dart';

LibrarySong _song(String id) => LibrarySong(
  id: id,
  sourceId: 'source',
  sourceName: 'Source',
  title: 'Title $id',
  fileName: '$id.flac',
  remotePath: '/Music/$id.flac',
  albumTitle: 'Album',
  artistName: 'Artist',
  directoryPath: '/Music',
  folderAlbumTitle: 'Album',
  folderArtistName: 'Artist',
);

void main() {
  late Directory directory;
  late JsonFileScanCacheRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('omnitune-scan-backup-test-');
    repository = JsonFileScanCacheRepository(directory);
  });

  tearDown(() => directory.delete(recursive: true));

  test('concurrent save and delete keep unrelated sources', () async {
    await repository.saveScanResults('source-a', [_song('a')]);
    await repository.saveScanResults('source-b', [_song('b')]);

    await Future.wait(<Future<void>>[
      repository.saveScanResults('source-a', [_song('a-updated')]),
      repository.saveScanResults('source-c', [_song('c')]),
      repository.deleteScanResults('source-b'),
    ]);

    final restored = await repository.loadAllResults();
    expect(restored.keys, unorderedEquals(<String>['source-a', 'source-c']));
    expect(restored['source-a']!.single.id, 'a-updated');
    expect(restored['source-c']!.single.id, 'c');
  });

  test('corrupted active file recovers from backup', () async {
    await repository.saveScanResults('source', [_song('original')]);

    final activeFile = File('${directory.path}/library_scan_cache.json');
    expect(File('${directory.path}/library_scan_cache.json.bak').existsSync(), isTrue);

    await activeFile.writeAsString('{not valid json', flush: true);

    final restored = await repository.loadAllResults();
    expect(restored['source']!.single.id, 'original');
  });

  test('clearAll removes active and backup files', () async {
    await repository.saveScanResults('source', [_song('original')]);

    final backupFile = File('${directory.path}/library_scan_cache.json.bak');
    expect(backupFile.existsSync(), isTrue);

    await repository.clearAll();

    final activeFile = File('${directory.path}/library_scan_cache.json');
    expect(activeFile.existsSync(), isFalse);
    expect(backupFile.existsSync(), isFalse);
    expect(await repository.loadAllResults(), isEmpty);
  });

  test('clearAll also removes backup created for corrupted active state', () async {
    await repository.saveScanResults('source', [_song('original')]);
    final activeFile = File('${directory.path}/library_scan_cache.json');
    await activeFile.writeAsString('{not valid json', flush: true);

    await repository.clearAll();

    final backupFile = File('${directory.path}/library_scan_cache.json.bak');
    expect(activeFile.existsSync(), isFalse);
    expect(backupFile.existsSync(), isFalse);
  });

  test('failed save leaves later queued saves working', () async {
    // Create a blocker file inside the unique test temp directory
    final blockerPath = '${directory.path}/omnitune-blocker';
    final blocker = File(blockerPath);
    await blocker.writeAsString('blocker');

    // Instantiate repository pointing to the blocker's path as a Directory.
    // _cacheDir.create(recursive: true) in _commit will throw FileSystemException
    // because a file already exists at that path.
    final repository = JsonFileScanCacheRepository(Directory(blockerPath));

    // Expect a real FileSystemException on saving
    await expectLater(
      repository.saveScanResults('source', [_song('failed')]),
      throwsA(isA<FileSystemException>()),
    );

    // Remove the blocker file so the directory can be created
    await blocker.delete();

    // SAVE and LOAD successfully through THE SAME previously failing repository instance
    await repository.saveScanResults('source', [_song('later')]);
    final restored = await repository.loadAllResults();
    expect(restored['source']!.single.id, 'later');

    // Assert failed data was not persisted and later data is recovered
    final allResults = await repository.loadAllResults();
    expect(allResults['source']!.single.id, 'later');
  });
}
