import '../../../core/models/library_song.dart';

enum LibrarySort { title, artist, album }

List<LibrarySong> queryLibrarySongs(
  Iterable<LibrarySong> songs, {
  String query = '',
  String? sourceId,
  LibrarySort sort = LibrarySort.title,
}) {
  final needle = query.trim().toLowerCase();
  final matches = songs.indexed.where((item) {
    final song = item.$2;
    return (sourceId == null || song.sourceId == sourceId) &&
        (needle.isEmpty ||
            [
              song.displayTitle,
              song.displayArtist,
              song.displayAlbum,
            ].any((text) => text.toLowerCase().contains(needle)));
  }).toList();
  String key(LibrarySong song) => switch (sort) {
    LibrarySort.title => song.displayTitle,
    LibrarySort.artist => song.displayArtist,
    LibrarySort.album => song.displayAlbum,
  };
  matches.sort((a, b) {
    final comparison = key(
      a.$2,
    ).toLowerCase().compareTo(key(b.$2).toLowerCase());
    return comparison == 0 ? a.$1.compareTo(b.$1) : comparison;
  });
  return matches.map((item) => item.$2).toList(growable: false);
}
