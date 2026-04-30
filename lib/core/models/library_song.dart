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
    // 新字段：手动刮削
    this.manuallyScrapedTitle,
    this.manuallyScrapedArtist,
    this.manuallyScrapedAlbum,
    this.manuallyScrapedCoverUrl,
    this.manuallyScrapedLocalCoverPath,
    this.manuallyScrapedLyrics,
    // 新字段：自动刮削
    this.autoScrapedTitle,
    this.autoScrapedArtist,
    this.autoScrapedAlbum,
    this.autoScrapedCoverUrl,
    this.autoScrapedLocalCoverPath,
    this.autoScrapedLyrics,
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

  // 手动刮削字段（最高优先级）
  final String? manuallyScrapedTitle;
  final String? manuallyScrapedArtist;
  final String? manuallyScrapedAlbum;
  final String? manuallyScrapedCoverUrl;
  final String? manuallyScrapedLocalCoverPath; // 本地缓存的手动刮削封面路径
  final String? manuallyScrapedLyrics;

  // 自动刮削字段
  final String? autoScrapedTitle;
  final String? autoScrapedArtist;
  final String? autoScrapedAlbum;
  final String? autoScrapedCoverUrl;
  final String? autoScrapedLocalCoverPath; // 本地缓存的自动刮削封面路径
  final String? autoScrapedLyrics;

  String get metadataAlbumTitle =>
      (scrapedAlbumTitle?.trim().isNotEmpty ?? false)
      ? scrapedAlbumTitle!.trim()
      : albumTitle;

  String get metadataArtistName =>
      (scrapedArtistName?.trim().isNotEmpty ?? false)
      ? scrapedArtistName!.trim()
      : artistName;

  /// 获取显示标题（优先级：手动刮削 > 自动刮削 > 原始）
  String get displayTitle {
    if (manuallyScrapedTitle?.isNotEmpty == true) return manuallyScrapedTitle!;
    if (autoScrapedTitle?.isNotEmpty == true) return autoScrapedTitle!;
    return title;
  }

  /// 获取显示艺术家（优先级：手动刮削 > 自动刮削 > 原始）
  String get displayArtist {
    if (manuallyScrapedArtist?.isNotEmpty == true) {
      return manuallyScrapedArtist!;
    }
    if (autoScrapedArtist?.isNotEmpty == true) return autoScrapedArtist!;
    if (scrapedArtistName?.isNotEmpty == true) return scrapedArtistName!;
    return artistName;
  }

  /// 获取显示专辑（优先级：手动刮削 > 自动刮削 > 原始）
  String get displayAlbum {
    if (manuallyScrapedAlbum?.isNotEmpty == true) return manuallyScrapedAlbum!;
    if (autoScrapedAlbum?.isNotEmpty == true) return autoScrapedAlbum!;
    if (scrapedAlbumTitle?.isNotEmpty == true) return scrapedAlbumTitle!;
    return albumTitle;
  }

  /// 获取显示封面图（优先级：手动 > 自动）
  String? get displayCoverUrl => manuallyScrapedCoverUrl ?? autoScrapedCoverUrl;

  /// 获取显示封面本地缓存路径（优先级：手动 > 自动）
  String? get displayLocalCoverPath =>
      manuallyScrapedLocalCoverPath ?? autoScrapedLocalCoverPath;

  /// 获取显示歌词（优先级：手动 > 自动）
  String? get displayLyrics => manuallyScrapedLyrics ?? autoScrapedLyrics;

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
      // 手动刮削字段
      'manuallyScrapedTitle': manuallyScrapedTitle,
      'manuallyScrapedArtist': manuallyScrapedArtist,
      'manuallyScrapedAlbum': manuallyScrapedAlbum,
      'manuallyScrapedCoverUrl': manuallyScrapedCoverUrl,
      'manuallyScrapedLocalCoverPath': manuallyScrapedLocalCoverPath,
      'manuallyScrapedLyrics': manuallyScrapedLyrics,
      // 自动刮削字段
      'autoScrapedTitle': autoScrapedTitle,
      'autoScrapedArtist': autoScrapedArtist,
      'autoScrapedAlbum': autoScrapedAlbum,
      'autoScrapedCoverUrl': autoScrapedCoverUrl,
      'autoScrapedLocalCoverPath': autoScrapedLocalCoverPath,
      'autoScrapedLyrics': autoScrapedLyrics,
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
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
      // 手动刮削字段
      manuallyScrapedTitle: json['manuallyScrapedTitle'] as String?,
      manuallyScrapedArtist: json['manuallyScrapedArtist'] as String?,
      manuallyScrapedAlbum: json['manuallyScrapedAlbum'] as String?,
      manuallyScrapedCoverUrl: json['manuallyScrapedCoverUrl'] as String?,
      manuallyScrapedLocalCoverPath:
          json['manuallyScrapedLocalCoverPath'] as String?,
      manuallyScrapedLyrics: json['manuallyScrapedLyrics'] as String?,
      // 自动刮削字段
      autoScrapedTitle: json['autoScrapedTitle'] as String?,
      autoScrapedArtist: json['autoScrapedArtist'] as String?,
      autoScrapedAlbum: json['autoScrapedAlbum'] as String?,
      autoScrapedCoverUrl: json['autoScrapedCoverUrl'] as String?,
      autoScrapedLocalCoverPath: json['autoScrapedLocalCoverPath'] as String?,
      autoScrapedLyrics: json['autoScrapedLyrics'] as String?,
    );
  }
}
