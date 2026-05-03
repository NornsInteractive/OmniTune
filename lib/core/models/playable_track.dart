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

  /// 获取显示标题（使用本地标签结果）
  String get displayTitle => autoScrapedTitle ?? title;

  /// 获取显示艺术家（使用本地标签结果）
  String get displayArtist => autoScrapedArtist ?? artistName ?? '';

  /// 获取显示专辑（使用本地标签结果）
  String get displayAlbum => autoScrapedAlbum ?? albumTitle ?? '';

  /// 获取显示歌词
  String? get displayLyrics => lyrics;
}
