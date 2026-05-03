/// 刮削状态枚举
enum ScrapingStatus {
  pending, // 待刮削
  scraping, // 刮削中
  completed, // 已完成
  failed, // 失败
}

/// 刮削优先级枚举
enum ScrapingPriority {
  low, // 背景队列
  high, // 播放优先
}

/// 刮削结果来源枚举
enum ScrapingSource {
  manual, // 手动刮削
  automatic, // 自动刮削
}

/// 刮削元数据模型（使用 JSON 序列化，不依赖 Isar）
class ScrapingMetadata {
  String id; // 唯一标识符

  // ===== 标识字段 =====
  /// 音源 ID（唯一标识符的一部分）
  String sourceId;

  /// 完整文件路径（remote path，唯一标识符）
  String filePath;

  /// 文件名不含扩展名（用于搜索）
  String filenameWithoutExt;

  // ===== 手动刮削结果（最高优先级）=====
  String? manuallyScrapedTitle;
  String? manuallyScrapedArtist;
  String? manuallyScrapedAlbum;
  String? manuallyScrapedCoverUrl;
  String? manuallyScrapedLocalCoverPath; // 本地缓存的手动刮削封面路径
  String? manuallyScrapedLyrics;
  DateTime? manualScrapedAt;

  // ===== 自动刮削结果 =====
  String? autoScrapedTitle;
  String? autoScrapedArtist;
  String? autoScrapedAlbum;
  String? autoScrapedAlbumArtist;
  String? autoScrapedGenre;
  String? autoScrapedYear;
  String? autoScrapedComposer;
  String? autoScrapedComment;
  String? autoScrapedCoverUrl;
  String? autoScrapedLocalCoverPath; // 本地缓存的自动刮削封面路径
  String? autoScrapedCoverSource;
  String? autoScrapedLyrics;
  String? autoScrapedLyricsSource;
  int? autoScrapedTrackNumber;
  int? autoScrapedTrackTotal;
  int? autoScrapedDiscNumber;
  int? autoScrapedDiscTotal;
  DateTime? autoScrapedAt;
  DateTime? embeddedMetadataReadAt;

  // ===== 刮削状态 =====
  /// 当前刮削状态
  ScrapingStatus status;

  /// 错误消息（仅在 status=failed 时有效）
  String? errorMessage;

  /// 重试次数
  int retryCount;

  /// 上次优先级（用于判断是否需要再次处理）
  ScrapingPriority lastPriority;

  // ===== 时间戳 =====
  /// 记录创建时间
  DateTime createdAt;

  /// 记录最后更新时间
  DateTime updatedAt;

  /// 最后一次尝试刮削的时间
  DateTime? lastAttemptAt;

  // ===== 元数据 =====
  /// 原始文件名（保留）
  String originalFileName;

  /// 原始艺术家名（来自文件名解析）
  String? originalArtist;

  /// 匹配度分数（用于auto scraping）
  double matchScore;

  ScrapingMetadata({
    this.id = '',
    required this.sourceId,
    required this.filePath,
    required this.filenameWithoutExt,
    required this.originalFileName,
    this.originalArtist,
    this.manuallyScrapedTitle,
    this.manuallyScrapedArtist,
    this.manuallyScrapedAlbum,
    this.manuallyScrapedCoverUrl,
    this.manuallyScrapedLocalCoverPath,
    this.manuallyScrapedLyrics,
    this.manualScrapedAt,
    this.autoScrapedTitle,
    this.autoScrapedArtist,
    this.autoScrapedAlbum,
    this.autoScrapedAlbumArtist,
    this.autoScrapedGenre,
    this.autoScrapedYear,
    this.autoScrapedComposer,
    this.autoScrapedComment,
    this.autoScrapedCoverUrl,
    this.autoScrapedLocalCoverPath,
    this.autoScrapedCoverSource,
    this.autoScrapedLyrics,
    this.autoScrapedLyricsSource,
    this.autoScrapedTrackNumber,
    this.autoScrapedTrackTotal,
    this.autoScrapedDiscNumber,
    this.autoScrapedDiscTotal,
    this.autoScrapedAt,
    this.embeddedMetadataReadAt,
    this.status = ScrapingStatus.pending,
    this.errorMessage,
    this.retryCount = 0,
    this.lastPriority = ScrapingPriority.low,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastAttemptAt,
    this.matchScore = 0.0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now() {
    if (id.isEmpty) {
      id = '$sourceId::$filePath';
    }
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceId': sourceId,
    'filePath': filePath,
    'filenameWithoutExt': filenameWithoutExt,
    'originalFileName': originalFileName,
    'originalArtist': originalArtist,
    'manuallyScrapedTitle': manuallyScrapedTitle,
    'manuallyScrapedArtist': manuallyScrapedArtist,
    'manuallyScrapedAlbum': manuallyScrapedAlbum,
    'manuallyScrapedCoverUrl': manuallyScrapedCoverUrl,
    'manuallyScrapedLocalCoverPath': manuallyScrapedLocalCoverPath,
    'manuallyScrapedLyrics': manuallyScrapedLyrics,
    'manualScrapedAt': manualScrapedAt?.toIso8601String(),
    'autoScrapedTitle': autoScrapedTitle,
    'autoScrapedArtist': autoScrapedArtist,
    'autoScrapedAlbum': autoScrapedAlbum,
    'autoScrapedAlbumArtist': autoScrapedAlbumArtist,
    'autoScrapedGenre': autoScrapedGenre,
    'autoScrapedYear': autoScrapedYear,
    'autoScrapedComposer': autoScrapedComposer,
    'autoScrapedComment': autoScrapedComment,
    'autoScrapedCoverUrl': autoScrapedCoverUrl,
    'autoScrapedLocalCoverPath': autoScrapedLocalCoverPath,
    'autoScrapedCoverSource': autoScrapedCoverSource,
    'autoScrapedLyrics': autoScrapedLyrics,
    'autoScrapedLyricsSource': autoScrapedLyricsSource,
    'autoScrapedTrackNumber': autoScrapedTrackNumber,
    'autoScrapedTrackTotal': autoScrapedTrackTotal,
    'autoScrapedDiscNumber': autoScrapedDiscNumber,
    'autoScrapedDiscTotal': autoScrapedDiscTotal,
    'autoScrapedAt': autoScrapedAt?.toIso8601String(),
    'embeddedMetadataReadAt': embeddedMetadataReadAt?.toIso8601String(),
    'status': status.toString().split('.').last,
    'errorMessage': errorMessage,
    'retryCount': retryCount,
    'lastPriority': lastPriority.toString().split('.').last,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    'matchScore': matchScore,
  };

  /// 从 JSON 创建
  factory ScrapingMetadata.fromJson(Map<String, dynamic> json) {
    return ScrapingMetadata(
      id: json['id'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      filenameWithoutExt: json['filenameWithoutExt'] as String? ?? '',
      originalFileName: json['originalFileName'] as String? ?? '',
      originalArtist: json['originalArtist'] as String?,
      manuallyScrapedTitle: json['manuallyScrapedTitle'] as String?,
      manuallyScrapedArtist: json['manuallyScrapedArtist'] as String?,
      manuallyScrapedAlbum: json['manuallyScrapedAlbum'] as String?,
      manuallyScrapedCoverUrl: json['manuallyScrapedCoverUrl'] as String?,
      manuallyScrapedLocalCoverPath:
          json['manuallyScrapedLocalCoverPath'] as String?,
      manuallyScrapedLyrics: json['manuallyScrapedLyrics'] as String?,
      manualScrapedAt: json['manualScrapedAt'] != null
          ? DateTime.parse(json['manualScrapedAt'] as String)
          : null,
      autoScrapedTitle: json['autoScrapedTitle'] as String?,
      autoScrapedArtist: json['autoScrapedArtist'] as String?,
      autoScrapedAlbum: json['autoScrapedAlbum'] as String?,
      autoScrapedAlbumArtist: json['autoScrapedAlbumArtist'] as String?,
      autoScrapedGenre: json['autoScrapedGenre'] as String?,
      autoScrapedYear: json['autoScrapedYear'] as String?,
      autoScrapedComposer: json['autoScrapedComposer'] as String?,
      autoScrapedComment: json['autoScrapedComment'] as String?,
      autoScrapedCoverUrl: json['autoScrapedCoverUrl'] as String?,
      autoScrapedLocalCoverPath: json['autoScrapedLocalCoverPath'] as String?,
      autoScrapedCoverSource: json['autoScrapedCoverSource'] as String?,
      autoScrapedLyrics: json['autoScrapedLyrics'] as String?,
      autoScrapedLyricsSource: json['autoScrapedLyricsSource'] as String?,
      autoScrapedTrackNumber: json['autoScrapedTrackNumber'] as int?,
      autoScrapedTrackTotal: json['autoScrapedTrackTotal'] as int?,
      autoScrapedDiscNumber: json['autoScrapedDiscNumber'] as int?,
      autoScrapedDiscTotal: json['autoScrapedDiscTotal'] as int?,
      autoScrapedAt: json['autoScrapedAt'] != null
          ? DateTime.parse(json['autoScrapedAt'] as String)
          : null,
      embeddedMetadataReadAt: json['embeddedMetadataReadAt'] != null
          ? DateTime.parse(json['embeddedMetadataReadAt'] as String)
          : null,
      status: _parseScrapingStatus(json['status'] as String?),
      errorMessage: json['errorMessage'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      lastPriority: _parseScrapingPriority(json['lastPriority'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
      matchScore: json['matchScore'] as double? ?? 0.0,
    );
  }

  static ScrapingStatus _parseScrapingStatus(String? value) {
    switch (value) {
      case 'scraping':
        return ScrapingStatus.scraping;
      case 'completed':
        return ScrapingStatus.completed;
      case 'failed':
        return ScrapingStatus.failed;
      default:
        return ScrapingStatus.pending;
    }
  }

  static ScrapingPriority _parseScrapingPriority(String? value) {
    return value == 'high' ? ScrapingPriority.high : ScrapingPriority.low;
  }

  @override
  String toString() =>
      '''
ScrapingMetadata(
  id: $id,
  filePath: $filePath,
  status: $status,
  manualTitle: $manuallyScrapedTitle,
  autoTitle: $autoScrapedTitle,
  retryCount: $retryCount,
  createdAt: $createdAt,
)
  ''';
}
