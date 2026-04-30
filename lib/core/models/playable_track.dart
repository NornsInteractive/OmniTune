import 'package:just_audio/just_audio.dart';

class PlayableTrack {
  const PlayableTrack({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.sourceName,
    required this.remotePath,
    required this.audioSource,
    this.sourceSizeBytes,
    this.artistName,
    this.albumTitle,
    // 刮削字段
    this.autoScrapedTitle,
    this.autoScrapedArtist,
    this.autoScrapedAlbum,
    this.autoScrapedCoverUrl,
    this.localCoverPath,
    this.lyrics,
  });

  final String id;
  final String sourceId;
  final String title;
  final String sourceName;
  final String remotePath;
  final AudioSource audioSource;
  final int? sourceSizeBytes;
  final String? artistName;
  final String? albumTitle;

  // 自动刮削字段
  final String? autoScrapedTitle;
  final String? autoScrapedArtist;
  final String? autoScrapedAlbum;
  final String? autoScrapedCoverUrl;
  final String? localCoverPath; // 本地缓存的封面文件路径
  final String? lyrics;

  /// 获取显示标题（优先级：自动刮削 > 原始）
  String get displayTitle {
    if (autoScrapedTitle?.isNotEmpty == true) return autoScrapedTitle!;
    return title;
  }

  /// 获取显示艺术家（优先级：自动刮削 > 原始）
  String get displayArtist {
    if (autoScrapedArtist?.isNotEmpty == true) return autoScrapedArtist!;
    return artistName ?? '';
  }

  /// 获取显示专辑（优先级：自动刮削 > 原始）
  String get displayAlbum {
    if (autoScrapedAlbum?.isNotEmpty == true) return autoScrapedAlbum!;
    return albumTitle ?? '';
  }

  /// 获取显示歌词 
  String? get displayLyrics => lyrics;
}
