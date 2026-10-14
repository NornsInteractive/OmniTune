import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/models/library_song.dart';
import 'package:music/features/library/application/library_query.dart';

void main() {
  group('queryLibrarySongs', () {
    LibrarySong createSong({
      required String id,
      required String sourceId,
      required String title,
      required String artistName,
      required String albumTitle,
      String? manuallyScrapedTitle,
      String? manuallyScrapedArtist,
      String? manuallyScrapedAlbum,
      String? autoScrapedTitle,
      String? autoScrapedArtist,
      String? autoScrapedAlbum,
    }) {
      return LibrarySong(
        id: id,
        sourceId: sourceId,
        sourceName: 'Test Source',
        title: title,
        fileName: '$title.flac',
        remotePath: '/music/$title.flac',
        albumTitle: albumTitle,
        artistName: artistName,
        directoryPath: '/music',
        folderAlbumTitle: albumTitle,
        folderArtistName: artistName,
        manuallyScrapedTitle: manuallyScrapedTitle,
        manuallyScrapedArtist: manuallyScrapedArtist,
        manuallyScrapedAlbum: manuallyScrapedAlbum,
        autoScrapedTitle: autoScrapedTitle,
        autoScrapedArtist: autoScrapedArtist,
        autoScrapedAlbum: autoScrapedAlbum,
      );
    }

    final songs = [
      createSong(
        id: '1',
        sourceId: 'src-1',
        title: 'Alpha',
        artistName: 'Artist A',
        albumTitle: 'Album X',
      ),
      createSong(
        id: '2',
        sourceId: 'src-1',
        title: 'Beta',
        artistName: 'Artist B',
        albumTitle: 'Album Y',
      ),
      createSong(
        id: '3',
        sourceId: 'src-2',
        title: 'Gamma',
        artistName: 'Artist C',
        albumTitle: 'Album Z',
      ),
      createSong(
        id: '4',
        sourceId: 'src-1',
        title: 'Delta',
        artistName: 'Artist A',
        albumTitle: 'Album X',
        manuallyScrapedTitle: 'Delta (Remastered)',
        manuallyScrapedArtist: 'Artist A',
        manuallyScrapedAlbum: 'Album X (Deluxe)',
      ),
    ];

    test('returns all songs when query is empty', () {
      final result = queryLibrarySongs(songs);
      expect(result.length, 4);
      expect(result.map((s) => s.id).toList(), ['1', '2', '4', '3']);
    });

    test('returns all songs when query is whitespace', () {
      final result = queryLibrarySongs(songs, query: '   ');
      expect(result.length, 4);
    });

    test('filters by title case-insensitive', () {
      final result = queryLibrarySongs(songs, query: 'alpha');
      expect(result.length, 1);
      expect(result.first.id, '1');

      final result2 = queryLibrarySongs(songs, query: 'ALPHA');
      expect(result2.length, 1);
      expect(result2.first.id, '1');
    });

    test('filters by artist case-insensitive', () {
      final result = queryLibrarySongs(songs, query: 'artist a');
      expect(result.length, 2);
      expect(result.map((s) => s.id).toList(), ['1', '4']);
    });

    test('filters by album case-insensitive', () {
      final result = queryLibrarySongs(songs, query: 'album x');
      expect(result.length, 2);
      expect(result.map((s) => s.id).toList(), ['1', '4']);
    });

    test('filters by partial match', () {
      final result = queryLibrarySongs(songs, query: 'bet');
      expect(result.length, 1);
      expect(result.first.id, '2');
    });

    test('uses displayTitle (manual scraped) for matching', () {
      final result = queryLibrarySongs(songs, query: 'remastered');
      expect(result.length, 1);
      expect(result.first.id, '4');
    });

    test('uses displayArtist (manual scraped) for matching', () {
      final result = queryLibrarySongs(songs, query: 'artist a');
      expect(result.length, 2);
      expect(result.map((s) => s.id).toList(), ['1', '4']);
    });

    test('uses displayAlbum (manual scraped) for matching', () {
      final result = queryLibrarySongs(songs, query: 'deluxe');
      expect(result.length, 1);
      expect(result.first.id, '4');
    });

    test('filters by sourceId', () {
      final result = queryLibrarySongs(songs, sourceId: 'src-1');
      expect(result.length, 3);
      expect(result.every((s) => s.sourceId == 'src-1'), isTrue);
    });

    test('combines query and sourceId filters', () {
      final result = queryLibrarySongs(
        songs,
        query: 'artist',
        sourceId: 'src-2',
      );
      expect(result.length, 1);
      expect(result.first.id, '3');
    });

    test('sorts by title by default (case-insensitive, stable)', () {
      final result = queryLibrarySongs(songs, query: '');
      final titles = result.map((s) => s.displayTitle).toList();
      expect(titles, ['Alpha', 'Beta', 'Delta (Remastered)', 'Gamma']);
    });

    test('sorts by title case-insensitive', () {
      final mixedCaseSongs = [
        createSong(
          id: '1',
          sourceId: 's',
          title: 'zeta',
          artistName: 'A',
          albumTitle: 'X',
        ),
        createSong(
          id: '2',
          sourceId: 's',
          title: 'Alpha',
          artistName: 'B',
          albumTitle: 'Y',
        ),
        createSong(
          id: '3',
          sourceId: 's',
          title: 'beta',
          artistName: 'C',
          albumTitle: 'Z',
        ),
      ];
      final result = queryLibrarySongs(mixedCaseSongs, sort: LibrarySort.title);
      expect(result.map((s) => s.displayTitle).toList(), [
        'Alpha',
        'beta',
        'zeta',
      ]);
    });

    test('sorts by artist case-insensitive', () {
      final result = queryLibrarySongs(songs, sort: LibrarySort.artist);
      final artists = result.map((s) => s.displayArtist).toList();
      expect(artists, ['Artist A', 'Artist A', 'Artist B', 'Artist C']);
    });

    test('sorts by album case-insensitive', () {
      final result = queryLibrarySongs(songs, sort: LibrarySort.album);
      final albums = result.map((s) => s.displayAlbum).toList();
      expect(albums, ['Album X', 'Album X (Deluxe)', 'Album Y', 'Album Z']);
    });

    test('stable sort preserves original order for equal keys', () {
      final songsSameTitle = [
        createSong(
          id: '1',
          sourceId: 's',
          title: 'Same',
          artistName: 'A',
          albumTitle: 'X',
        ),
        createSong(
          id: '2',
          sourceId: 's',
          title: 'Same',
          artistName: 'B',
          albumTitle: 'Y',
        ),
        createSong(
          id: '3',
          sourceId: 's',
          title: 'Same',
          artistName: 'C',
          albumTitle: 'Z',
        ),
      ];
      final result = queryLibrarySongs(songsSameTitle, sort: LibrarySort.title);
      expect(result.map((s) => s.id).toList(), ['1', '2', '3']);
    });

    test('does not mutate input iterable', () {
      final input = List<LibrarySong>.from(songs);
      queryLibrarySongs(input, query: 'alpha');
      expect(input.length, 4);
      expect(input.first.id, '1');
    });

    test('returns empty list when no matches', () {
      final result = queryLibrarySongs(songs, query: 'nonexistent');
      expect(result, isEmpty);
    });

    test('returns empty list when sourceId has no matches', () {
      final result = queryLibrarySongs(songs, sourceId: 'nonexistent');
      expect(result, isEmpty);
    });

    test('handles songs with null scraped fields', () {
      final songWithNulls = createSong(
        id: '5',
        sourceId: 'src-1',
        title: 'Test',
        artistName: 'Artist',
        albumTitle: 'Album',
      );
      final result = queryLibrarySongs([
        ...songs,
        songWithNulls,
      ], query: 'test');
      expect(result.length, 1);
      expect(result.first.id, '5');
    });

    test('handles empty songs list', () {
      final result = queryLibrarySongs(<LibrarySong>[], query: 'anything');
      expect(result, isEmpty);
    });

    test('returns unmodifiable list', () {
      final result = queryLibrarySongs(songs);
      expect(() => result.add(songs.first), throwsUnsupportedError);
    });

    test('sourceId filter is case-sensitive', () {
      final result = queryLibrarySongs(songs, sourceId: 'SRC-1');
      expect(result, isEmpty);
    });

    test('query trims whitespace before matching', () {
      final result = queryLibrarySongs(songs, query: '  alpha  ');
      expect(result.length, 1);
      expect(result.first.id, '1');
    });
  });
}
