/// 缓存的单个搜索结果
class CacheResult {
  final String title;
  final String? artist;
  final String? album;
  final String? coverUrl;
  final String? localCoverPath;
  final String? lyrics;
  final String? sourceId;

  CacheResult({
    required this.title,
    this.artist,
    this.album,
    this.coverUrl,
    this.localCoverPath,
    this.lyrics,
    this.sourceId,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'album': album,
    'coverUrl': coverUrl,
    'localCoverPath': localCoverPath,
    'lyrics': lyrics,
    'sourceId': sourceId,
  };

  factory CacheResult.fromJson(Map<String, dynamic> json) => CacheResult(
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String?,
    album: json['album'] as String?,
    coverUrl: json['coverUrl'] as String?,
    localCoverPath: json['localCoverPath'] as String?,
    lyrics: json['lyrics'] as String?,
    sourceId: json['sourceId'] as String?,
  );
}

/// 缓存搜索结果（使用 JSON 序列化，不依赖 Isar）
class ScrapingCache {
  String id;

  // ===== 搜索键 =====
  /// 完整查询字符串（title + artist 的组合）
  String queryKey;

  /// 搜索的标题/歌曲名
  String query;

  /// 搜索的艺术家（可选）
  String? artist;

  // ===== 缓存数据 =====
  /// 缓存的搜索结果
  List<CacheResult> results;

  // ===== 时间戳 =====
  /// 缓存创建时间
  DateTime cachedAt;

  /// 缓存过期时间（用于 TTL）
  DateTime expiresAt;

  /// 是否应刷新（用于用户主动重新搜索）
  bool isValid;

  // ===== 元数据 =====
  /// 来源（如 musicbrainz、spotify）
  String source;

  ScrapingCache({
    this.id = '',
    required this.queryKey,
    required this.query,
    this.artist,
    this.results = const [],
    DateTime? cachedAt,
    DateTime? expiresAt,
    this.isValid = true,
    this.source = 'musicbrainz',
  }) : cachedAt = cachedAt ?? DateTime.now(),
       expiresAt = expiresAt ?? DateTime.now().add(const Duration(hours: 24)) {
    if (id.isEmpty) {
      id = queryKey;
    }
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'queryKey': queryKey,
    'query': query,
    'artist': artist,
    'results': results.map((r) => r.toJson()).toList(),
    'cachedAt': cachedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'isValid': isValid,
    'source': source,
  };

  /// 从 JSON 创建
  factory ScrapingCache.fromJson(Map<String, dynamic> json) {
    final resultsList = json['results'] as List<dynamic>? ?? [];
    return ScrapingCache(
      id: json['id'] as String? ?? '',
      queryKey: json['queryKey'] as String? ?? '',
      query: json['query'] as String? ?? '',
      artist: json['artist'] as String?,
      results: resultsList
          .map((r) => CacheResult.fromJson(r as Map<String, dynamic>))
          .toList(),
      cachedAt: json['cachedAt'] != null
          ? DateTime.parse(json['cachedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : DateTime.now().add(const Duration(hours: 24)),
      isValid: json['isValid'] as bool? ?? true,
      source: json['source'] as String? ?? 'musicbrainz',
    );
  }

  @override
  String toString() =>
      '''
ScrapingCache(
  queryKey: $queryKey,
  resultCount: ${results.length},
  cachedAt: $cachedAt,
  isValid: $isValid,
)
  ''';
}
