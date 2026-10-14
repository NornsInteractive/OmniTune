import 'library_song.dart';

enum LibraryAlbumGroupingMode { folder, metadata }

class LibraryAlbum {
  const LibraryAlbum({
    required this.id,
    required this.title,
    required this.artistName,
    required this.sourceId,
    required this.sourceName,
    required this.tracks,
  });

  final String id;
  final String title;
  final String artistName;
  final String sourceId;
  final String sourceName;
  final List<LibrarySong> tracks;

  int get trackCount => tracks.length;
}
