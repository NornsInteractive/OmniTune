import 'isar_manager.dart';
import 'scraping_cache.dart';

/// 缓存搜索结果仓储类
class ScrapingCacheRepository {
  /// 默认缓存持续时间（24小时）
  static const Duration defaultTTL = Duration(hours: 24);

  /// 创建查询键
  static String createQueryKey(String query, {String? artist}) {
    if (artist != null && artist.isNotEmpty) {
      return '${query.toLowerCase()}::${artist.toLowerCase()}';
    }
    return query.toLowerCase();
  }

  /// 保存搜索结果
  Future<void> saveSearchResult({
    required String query,
    required String? artist,
    required List<CacheResult> results,
    String source = 'musicbrainz',
    Duration ttl = defaultTTL,
  }) async {
    final queryKey = createQueryKey(query, artist: artist);

    final cache = ScrapingCache(
      id: queryKey,
      queryKey: queryKey,
      query: query,
      artist: artist,
      results: results,
      source: source,
      cachedAt: DateTime.now(),
      expiresAt: DateTime.now().add(ttl),
      isValid: true,
    );

    await IsarManager.saveCache(cache);
  }

  /// 获取缓存的搜索结果
  Future<List<CacheResult>?> getSearchResult(
    String query, {
    String? artist,
  }) async {
    final queryKey = createQueryKey(query, artist: artist);
    final cache = IsarManager.getCache(queryKey);

    if (cache == null || !cache.isValid) {
      return null;
    }

    // 检查是否过期
    if (DateTime.now().isAfter(cache.expiresAt)) {
      // 标记为无效但保留为历史
      cache.isValid = false;
      await IsarManager.saveCache(cache);
      return null;
    }

    return cache.results;
  }

  /// 清除特定查询的缓存
  Future<void> clearQuery(String query, {String? artist}) async {
    final queryKey = createQueryKey(query, artist: artist);
    await IsarManager.deleteCache(queryKey);
  }

  /// 清除所有过期缓存
  Future<void> clearExpired() async {
    final list = _getAllCaches();
    for (final cache in list) {
      if (DateTime.now().isAfter(cache.expiresAt)) {
        await IsarManager.deleteCache(cache.id);
      }
    }
  }

  /// 清除所有缓存
  Future<void> clearAll() async {
    await IsarManager.clearAllCache();
  }

  /// 获取缓存统计
  Future<CacheStats> getStats() async {
    final list = _getAllCaches();
    final now = DateTime.now();
    final valid = list.where((c) => c.isValid && !now.isAfter(c.expiresAt)).length;
    final expired = list.where((c) => now.isAfter(c.expiresAt)).length;

    return CacheStats(
      total: list.length,
      valid: valid,
      expired: expired,
    );
  }

  List<ScrapingCache> _getAllCaches() {
    // 从 SharedPreferences 获取所有缓存键
    final prefs = IsarManager.prefs;
    final cacheList = prefs.getStringList('scraping_cache_list') ?? [];
    return cacheList
        .map((id) => IsarManager.getCache(id))
        .whereType<ScrapingCache>()
        .toList();
  }
}

/// 缓存统计信息
class CacheStats {
  final int total;
  final int valid;
  final int expired;

  CacheStats({
    required this.total,
    required this.valid,
    required this.expired,
  });

  @override
  String toString() => '''
CacheStats(
  total: $total,
  valid: $valid,
  expired: $expired,
)
  ''';
}
