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
      (scrapedAlbumTitle?.trim().isNotEmpty ?? false) ? scrapedAlbumTitle!.trim() : albumTitle;

  String get metadataArtistName =>
      (scrapedArtistName?.trim().isNotEmpty ?? false) ? scrapedArtistName!.trim() : artistName;

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

  /// 转换为 JSON 用于存储
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'title': title,
      'fileName': fileName,
      'remotePath': remotePath,
      'albumTitle': albumTitle,
      'artistName': artistName,
      'directoryPath': directoryPath,
      'folderAlbumTitle': folderAlbumTitle,
      'folderArtistName': folderArtistName,
      'scrapedAlbumTitle': scrapedAlbumTitle,
      'scrapedArtistName': scrapedArtistName,
      'mimeType': mimeType,
      'size': size,
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  /// 从 JSON 恢复
  factory LibrarySong.fromJson(Map<String, dynamic> json) {
    return LibrarySong(
      id: json['id'] as String,
      sourceId: json['sourceId'] as String,
      sourceName: json['sourceName'] as String,
      title: json['title'] as String,
      fileName: json['fileName'] as String,
      remotePath: json['remotePath'] as String,
      albumTitle: json['albumTitle'] as String,
      artistName: json['artistName'] as String,
      directoryPath: json['directoryPath'] as String,
      folderAlbumTitle: json['folderAlbumTitle'] as String,
      folderArtistName: json['folderArtistName'] as String,
      scrapedAlbumTitle: json['scrapedAlbumTitle'] as String?,
      scrapedArtistName: json['scrapedArtistName'] as String?,
      mimeType: json['mimeType'] as String?,
      size: json['size'] as int?,
      modifiedAt: json['modifiedAt'] != null ? DateTime.parse(json['modifiedAt'] as String) : null,
    );
  }
}
