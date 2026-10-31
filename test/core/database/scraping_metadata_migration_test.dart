// Migration contract for ScrapingMetadata.embeddedMetadataReadVersion.
//
// The library scan decides whether to re-read embedded tags for an M4A with
// `cachedMetadata.embeddedMetadataReadVersion != 1` (library_catalog_controller
// `_shouldHydrateEmbeddedMetadata`). The version is written only after a read
// that actually completed: tags parsed (`_persistEmbeddedMetadata`) or prefix
// confirmed tagless (`_markEmbeddedMetadataAttempted`). A failed read rethrows
// and leaves the record unversioned, so the next scan retries it.
//
// These tests pin the data contract that gate depends on: legacy entries carry
// no version, a completed attempt carries 1, and user manual/auto fields are
// never lost across a save/load cycle. Retry-on-failure is covered by the
// provider-level tests in library_catalog_embedded_metadata_hydration_test.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/database/isar_manager.dart';
import 'package:music/core/database/scraping_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyId = 'cloud189_1::/music/AppleMusic版本/02. 西西里.m4a';
const _versionedId = 'cloud189_1::/music/AppleMusic版本/03. 太阳之子.m4a';

/// Metadata as written before the embedded-metadata version existed: no
/// `embeddedMetadataReadVersion` and no `embeddedMetadataReadAt` keys at all.
Map<String, dynamic> _legacyJson({String id = _legacyId}) => <String, dynamic>{
  'id': id,
  'sourceId': 'cloud189_1',
  'filePath': '/music/AppleMusic版本/02. 西西里.m4a',
  'filenameWithoutExt': '02. 西西里',
  'originalFileName': '02. 西西里.m4a',
  'originalArtist': 'Jay Chou',
  'manuallyScrapedTitle': 'Manual Title',
  'manuallyScrapedArtist': 'Manual Artist',
  'manuallyScrapedAlbum': 'Manual Album',
  'manuallyScrapedLyrics': 'manual lyrics',
  'autoScrapedTitle': null,
  'autoScrapedArtist': null,
  'autoScrapedAlbum': null,
  'autoScrapedLyrics': null,
  'status': 'pending',
  'retryCount': 0,
  'lastPriority': 'low',
  'createdAt': '2026-03-01T00:00:00.000',
  'updatedAt': '2026-03-01T00:00:00.000',
  'matchScore': 0.0,
};

Map<String, dynamic> _newJson({String id = _legacyId}) => <String, dynamic>{
  ..._legacyJson(id: id),
  'autoScrapedTitle': 'Sicily',
  'autoScrapedArtist': 'Jay Chou',
  'autoScrapedAlbum': 'Children of the Sun',
  'autoScrapedAlbumArtist': 'Jay Chou',
  'autoScrapedLyrics': 'auto lyrics',
  'autoScrapedCoverUrl': 'https://example.com/auto.jpg',
  'embeddedMetadataReadAt': '2026-03-02T10:00:00.000',
  'embeddedMetadataReadVersion': 1,
};

void main() {
  group('ScrapingMetadata legacy JSON', () {
    test('missing version deserialises as null and keeps manual fields', () {
      final metadata = ScrapingMetadata.fromJson(_legacyJson());

      expect(metadata.embeddedMetadataReadVersion, isNull);
      expect(metadata.embeddedMetadataReadAt, isNull);
      // User data survives the legacy load.
      expect(metadata.manuallyScrapedTitle, 'Manual Title');
      expect(metadata.manuallyScrapedArtist, 'Manual Artist');
      expect(metadata.manuallyScrapedAlbum, 'Manual Album');
      expect(metadata.manuallyScrapedLyrics, 'manual lyrics');
    });

    test('legacy entry keeps its manual fields through a save/load cycle', () {
      final first = ScrapingMetadata.fromJson(_legacyJson());
      final second = ScrapingMetadata.fromJson(first.toJson());

      expect(second.manuallyScrapedTitle, 'Manual Title');
      expect(second.manuallyScrapedLyrics, 'manual lyrics');
      expect(second.embeddedMetadataReadVersion, isNull);
      expect(second.toJson()['embeddedMetadataReadVersion'], isNull);
    });
  });

  group('ScrapingMetadata with version', () {
    test('version 1 roundtrips together with manual and auto fields', () {
      final restored = ScrapingMetadata.fromJson(_newJson());

      expect(restored.embeddedMetadataReadVersion, 1);
      expect(restored.embeddedMetadataReadAt, isNotNull);

      expect(restored.manuallyScrapedTitle, 'Manual Title');
      expect(restored.autoScrapedTitle, 'Sicily');
      expect(restored.autoScrapedAlbum, 'Children of the Sun');
      expect(restored.autoScrapedLyrics, 'auto lyrics');

      final again = ScrapingMetadata.fromJson(restored.toJson());
      expect(again.embeddedMetadataReadVersion, 1);
      expect(again.manuallyScrapedTitle, 'Manual Title');
      expect(again.autoScrapedTitle, 'Sicily');
      expect(again.autoScrapedAlbumArtist, 'Jay Chou');
    });

    test('a completed attempt with no tags keeps version 1 and manual fields', () {
      final empty = ScrapingMetadata.fromJson({
        ..._newJson(),
        'autoScrapedTitle': null,
        'autoScrapedAlbum': null,
        'autoScrapedLyrics': null,
      });

      expect(empty.embeddedMetadataReadVersion, 1);
      expect(empty.manuallyScrapedTitle, 'Manual Title');
    });
  });

  group('IsarManager persistence of the version', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'scraping_metadata_$_legacyId': jsonEncode(_legacyJson()),
        'scraping_metadata_list': <String>[_legacyId],
      });
      await IsarManager.initialize();
    });

    test('stored legacy entry loads unversioned and persists a completed attempt',
        () async {
      final loaded = IsarManager.getMetadata(_legacyId);
      expect(loaded, isNotNull);
      expect(loaded!.embeddedMetadataReadVersion, isNull);

      // Simulate the attempt marking the version without finding tags.
      loaded.embeddedMetadataReadAt = DateTime.parse('2026-03-02T10:00:00.000');
      loaded.embeddedMetadataReadVersion = 1;
      await IsarManager.saveMetadata(loaded);

      final reloaded = IsarManager.getMetadata(_legacyId);
      expect(reloaded!.embeddedMetadataReadVersion, 1);
      expect(reloaded.manuallyScrapedTitle, 'Manual Title');
    });

    test('version 1 written by an earlier scan loads from SharedPreferences',
        () async {
      // A distinct id: IsarManager keeps a static per-id cache across tests.
      SharedPreferences.setMockInitialValues({
        'scraping_metadata_$_versionedId': jsonEncode(_newJson(id: _versionedId)),
        'scraping_metadata_list': <String>[_versionedId],
      });
      await IsarManager.initialize();

      final loaded = IsarManager.getMetadata(_versionedId);
      expect(loaded!.embeddedMetadataReadVersion, 1);
      expect(loaded.autoScrapedTitle, 'Sicily');
    });
  });
}
