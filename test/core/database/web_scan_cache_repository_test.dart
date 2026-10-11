import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music/core/database/library_scan_cache_repository_impl_web.dart';
import 'package:music/core/models/library_song.dart';

LibrarySong _song(String id) => LibrarySong(
  id: id,
  sourceId: 'source',
  sourceName: 'Source',
  title: 'A "quoted" song',
  fileName: '$id.flac',
  remotePath: '/Music/$id.flac',
  albumTitle: 'Album',
  artistName: 'Artist',
  directoryPath: '/Music',
  folderAlbumTitle: 'Album',
  folderArtistName: 'Artist',
  manuallyScrapedTitle: '手动标题',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late SharedPreferencesScanCacheRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = SharedPreferencesScanCacheRepository(prefs);
  });

  test(
    'large Web saves yield and round trip escaped strings and metadata',
    () async {
      var eventLoopTurns = 0;
      final timer = Timer.periodic(Duration.zero, (_) => eventLoopTurns++);
      try {
        await repository.saveAllResults({
          'source': List.generate(10000, (index) => _song('song-$index')),
          'empty': [],
          'quoted"source': [_song('quoted')],
        });
      } finally {
        timer.cancel();
      }
      expect(eventLoopTurns, greaterThan(1));
      final raw = jsonDecode(prefs.getString('library_scan_cache_v1')!) as Map;
      expect(raw['source'], hasLength(10000));
      expect(raw['empty'], isEmpty);
      expect(raw['quoted"source'], hasLength(1));
      final restored = await repository.loadScanResults('source');
      expect(restored.last.id, 'song-9999');
      expect(restored.last.displayTitle, '手动标题');
      expect(restored.first.title, 'A "quoted" song');
    },
  );

  test('single source update and delete keep other sources', () async {
    await repository.saveAllResults({
      'other': [_song('other')],
    });
    await repository.saveScanResults('source', [_song('new')]);
    final restored = await repository.loadAllResults();
    expect(restored.keys, unorderedEquals(['other', 'source']));
    expect(restored['other']!.single.id, 'other');
    await repository.deleteScanResults('source');
    expect((await repository.loadAllResults()).keys, ['other']);
    await repository.saveAllResults({});
    expect(prefs.containsKey('library_scan_cache_v1'), isFalse);
  });

  test(
    'an invalid cached source does not prevent saving another source',
    () async {
      await prefs.setString(
        'library_scan_cache_v1',
        jsonEncode({
          'invalid': 'legacy malformed entry',
          'other': [_song('old').toJson()],
        }),
      );
      await repository.saveScanResults('source', [_song('new')]);
      final raw = jsonDecode(prefs.getString('library_scan_cache_v1')!) as Map;
      expect(raw['invalid'], 'legacy malformed entry');
      final restored = await repository.loadAllResults();
      expect(restored.keys, unorderedEquals(['other', 'source']));
      expect(restored['source']!.single.id, 'new');
    },
  );
}
