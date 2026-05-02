import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:music/core/database/scraping_cache.dart';
import 'package:music/core/database/scraping_cache_repository.dart';
import 'package:music/core/database/scraping_metadata.dart';
import 'package:music/core/database/scraping_metadata_repository.dart';
import 'package:music/core/models/app_preferences.dart';
import 'package:music/core/utils/debug_logger.dart';
import 'package:music/features/scraper/data/musicbrainz_scraper.dart';
import 'package:music/features/settings/application/app_settings_controller.dart';

part 'scraping_provider.g.dart';

// ===== REPOSITORIES =====

/// 获取刮削元数据 Repository
@riverpod
ScrapingMetadataRepository scrapingMetadataRepository(Ref ref) {
  return ScrapingMetadataRepository();
}

/// 获取刮削缓存 Repository
@riverpod
ScrapingCacheRepository scrapingCacheRepository(Ref ref) {
  return ScrapingCacheRepository();
}

/// 获取 MusicBrainz 刮削器
@riverpod
MusicBrainzScraper musicBrainzScraper(Ref ref) {
  final appSettings = ref.watch(appSettingsControllerProvider);
  final preferences = appSettings.valueOrNull;
  final localePreference =
      preferences?.localePreference ?? AppLocalePreference.system;
  final lyricsServiceBaseUrl = preferences?.lyricsScrapingServiceBaseUrl;
  final enableLyricsScraping = preferences?.enableLyricsScraping ?? false;
  final enableItunes = preferences?.enableItunesMetadataScraping ?? false;

  DebugLogger.info(
    'musicBrainzScraper Provider',
    '创建 MusicBrainzScraper，语言偏好: $localePreference',
  );

  return MusicBrainzScraper(
    localePreference: localePreference,
    enableLyricsScraping: enableLyricsScraping,
    enableDeezerCoverScraping: false,
    enableItunesMetadataScraping: enableItunes,
    lyricsScrapingServiceBaseUrl: lyricsServiceBaseUrl,
  );
}

// ===== 搜索接口 =====

/// 搜索歌曲元数据
/// 返回多个可能的匹配结果
@riverpod
Future<List<ScrapedMetadataResult>> searchMetadata(
  Ref ref,
  String title, {
  String? artist,
}) async {
  DebugLogger.scraping(
    'searchMetadata Provider',
    '查询开始: title="$title", artist="$artist"',
  );

  try {
    final scraper = ref.watch(musicBrainzScraperProvider);
    final cacheRepo = ref.watch(scrapingCacheRepositoryProvider);

    // 获取最新的语言偏好，确保每次搜索都使用当前设置
    final appSettings = ref.watch(appSettingsControllerProvider);
    final currentLocale = appSettings.maybeWhen(
      data: (prefs) => prefs.localePreference,
      orElse: () => AppLocalePreference.system,
    );

    DebugLogger.info('searchMetadata Provider', '使用最新的语言偏好: $currentLocale');

    // 尝试从缓存获取
    final cached = await cacheRepo.getSearchResult(title, artist: artist);
    if (cached != null) {
      DebugLogger.success(
        'searchMetadata Provider',
        '从缓存返回 ${cached.length} 个结果',
      );
      return cached
          .map(
            (r) => ScrapedMetadataResult(
              title: r.title,
              artist: r.artist,
              album: r.album,
              coverUrl: r.coverUrl,
              localCoverPath: r.localCoverPath,
              lyrics: r.lyrics,
              source: 'musicbrainz',
              sourceId: r.sourceId ?? r.title,
            ),
          )
          .toList();
    }

    DebugLogger.info('searchMetadata Provider', '缓存未命中，执行搜索');

    // 执行搜索，传入最新的语言偏好
    final results = await scraper.searchMetadata(
      title,
      artist: artist,
      localePreference: currentLocale,
    );

    DebugLogger.info('searchMetadata Provider', '搜索返回 ${results.length} 个结果');

    // 保存到缓存
    if (results.isNotEmpty) {
      DebugLogger.info('searchMetadata Provider', '保存结果到缓存');
      final cacheResults = results
          .map(
            (r) => CacheResult(
              title: r.title,
              artist: r.artist,
              album: r.album,
              coverUrl: r.coverUrl,
              localCoverPath: r.localCoverPath,
              lyrics: r.lyrics,
              sourceId: r.sourceId,
            ),
          )
          .toList();

      await cacheRepo.saveSearchResult(
        query: title,
        artist: artist,
        results: cacheResults,
      );
      DebugLogger.success('searchMetadata Provider', '缓存保存成功');
    } else {
      DebugLogger.warning('searchMetadata Provider', '没有结果可保存');
    }

    return results;
  } catch (e, stack) {
    DebugLogger.error('searchMetadata Provider', '查询异常', e.toString(), stack);
    return [];
  }
}

/// 获取统计信息
@riverpod
Future<ScrapingStatsResult> scrapingStats(Ref ref) async {
  final repo = ref.watch(scrapingMetadataRepositoryProvider);
  final stats = await repo.getStats();
  return ScrapingStatsResult(
    total: stats.total,
    pending: stats.pending,
    scraping: stats.scraping,
    completed: stats.completed,
    failed: stats.failed,
    manual: stats.manual,
  );
}

/// 获取待刮削的元数据列表
@riverpod
Future<List<ScrapedMetadata>> pendingScrapings(Ref ref) async {
  final repo = ref.watch(scrapingMetadataRepositoryProvider);
  return repo.getPending();
}

/// 获取指定文件的刮削状态
@riverpod
Future<ScrapedMetadata?> getScrapingMetadata(Ref ref, String id) async {
  final repo = ref.watch(scrapingMetadataRepositoryProvider);
  return repo.getById(id);
}

// ===== 状态修改接口 =====

/// 应用手动刮削结果
@riverpod
Future<void> applyManualScrapingResult(
  Ref ref,
  String fileId,
  ScrapedMetadataResult result,
) async {
  DebugLogger.scraping('applyManualScrapingResult', '应用手动刮削: fileId=$fileId');
  DebugLogger.info(
    'applyManualScrapingResult',
    '结果: title="${result.title}", artist="${result.artist}"',
  );

  try {
    final repo = ref.watch(scrapingMetadataRepositoryProvider);

    await repo.updateManualScrapingResult(
      fileId,
      title: result.title,
      artist: result.artist,
      album: result.album,
      coverUrl: result.coverUrl,
      localCoverPath: result.localCoverPath,
      lyrics: result.lyrics,
    );

    DebugLogger.success('applyManualScrapingResult', '数据库更新成功');

    // 刷新统计信息
    ref.invalidate(scrapingStatsProvider);
    ref.invalidate(pendingScrapingsProvider);
    ref.invalidate(getScrapingMetadataProvider);

    DebugLogger.success('applyManualScrapingResult', '已刷新相关 providers');
  } catch (e, stack) {
    DebugLogger.error('applyManualScrapingResult', '应用异常', e.toString(), stack);
    rethrow;
  }
}

/// 应用自动刮削结果
@riverpod
Future<void> applyAutoScrapingResult(
  Ref ref,
  String fileId,
  ScrapedMetadataResult result,
) async {
  final repo = ref.watch(scrapingMetadataRepositoryProvider);

  await repo.updateAutoScrapingResult(
    fileId,
    title: result.title,
    artist: result.artist,
    album: result.album,
    coverUrl: result.coverUrl,
    localCoverPath: result.localCoverPath,
    lyrics: result.lyrics,
    matchScore: result.score,
  );

  // 刷新相关 providers
  ref.invalidate(scrapingStatsProvider);
  ref.invalidate(pendingScrapingsProvider);
}

/// 创建初始刮削记录
@riverpod
Future<ScrapedMetadata> createScrapingRecord(
  Ref ref,
  String sourceId,
  String filePath,
  String filename, {
  String? originalArtist,
}) async {
  final repo = ref.watch(scrapingMetadataRepositoryProvider);

  final metadata = await repo.createInitialMetadata(
    sourceId: sourceId,
    filePath: filePath,
    filename: filename,
    originalArtist: originalArtist,
  );

  // 刷新统计信息
  ref.invalidate(scrapingStatsProvider);
  ref.invalidate(pendingScrapingsProvider);

  return metadata;
}

/// 删除刮削记录
@riverpod
Future<void> deleteScrapingRecord(Ref ref, List<String> ids) async {
  final repo = ref.watch(scrapingMetadataRepositoryProvider);

  await repo.deleteByIds(ids);

  // 刷新统计信息
  ref.invalidate(scrapingStatsProvider);
  ref.invalidate(pendingScrapingsProvider);
}

/// 清除搜索缓存
@riverpod
Future<void> clearScrapingCache(Ref ref) async {
  final cacheRepo = ref.watch(scrapingCacheRepositoryProvider);
  await cacheRepo.clearAll();
}

// ===== 缓存清理 =====

/// 清除过期缓存
@riverpod
Future<void> clearExpiredCache(Ref ref) async {
  final cacheRepo = ref.watch(scrapingCacheRepositoryProvider);
  await cacheRepo.clearExpired();
}

/// 刮削统计信息结果
class ScrapingStatsResult {
  final int total;
  final int pending;
  final int scraping;
  final int completed;
  final int failed;
  final int manual;

  ScrapingStatsResult({
    required this.total,
    required this.pending,
    required this.scraping,
    required this.completed,
    required this.failed,
    required this.manual,
  });

  @override
  String toString() =>
      '''
ScrapingStatsResult(
  total: $total,
  pending: $pending,
  completed: $completed,
  manual: $manual,
)
  ''';
}

/// 使用导入的 ScrapingMetadata 类型
typedef ScrapedMetadata = ScrapingMetadata;
