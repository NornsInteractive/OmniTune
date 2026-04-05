import 'package:path/path.dart' as p;

import 'remote_entry.dart';

class LibrarySong {
  const LibrarySong({
    required this.id,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.fileName,
    required this.remotePath,
    required this.albumTitle,
    required this.artistName,
    required this.directoryPath,
    required this.folderAlbumTitle,
    required this.folderArtistName,
    this.scrapedAlbumTitle,
    this.scrapedArtistName,
    this.mimeType,
    this.size,
    this.modifiedAt,
  });

  final String id;
  final String sourceId;
  final String sourceName;
  final String title;
  final String fileName;
  final String remotePath;
  final String albumTitle;
  final String artistName;
  final String directoryPath;
  final String folderAlbumTitle;
  final String folderArtistName;
  final String? scrapedAlbumTitle;
  final String? scrapedArtistName;
  final String? mimeType;
  final int? size;
  final DateTime? modifiedAt;

  String get metadataAlbumTitle =>
      (scrapedAlbumTitle?.trim().isNotEmpty ?? false)
      ? scrapedAlbumTitle!.trim()
      : albumTitle;

  String get metadataArtistName =>
      (scrapedArtistName?.trim().isNotEmpty ?? false)
      ? scrapedArtistName!.trim()
      : artistName;

  String get lyricsPath {
    final withoutExtension = p.posix.withoutExtension(remotePath);
    return '$withoutExtension.lrc';
  }

  RemoteEntry toRemoteEntry() {
    return RemoteEntry(
      sourceId: sourceId,
      name: fileName,
      path: remotePath,
      kind: RemoteEntryKind.audio,
      mimeType: mimeType,
      size: size,
      modifiedAt: modifiedAt,
    );
  }
}
