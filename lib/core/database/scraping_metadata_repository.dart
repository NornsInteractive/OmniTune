import 'package:music/core/utils/debug_logger.dart';

import 'isar_manager.dart';
import 'scraping_metadata.dart';

/// 刮削元数据仓储类
class ScrapingMetadataRepository {
  /// 创建或更新元数据
  Future<void> upsert(ScrapingMetadata metadata) async {
    metadata.updatedAt = DateTime.now();
    DebugLogger.database(
      'ScrapingMetadataRepository',
      'UPSERT',
      'id=${metadata.id}, status=${metadata.status}',
    );
    try {
      await IsarManager.saveMetadata(metadata);
      DebugLogger.success('ScrapingMetadataRepository', 'UPSERT 成功');
    } catch (e, stack) {
      DebugLogger.error(
        'ScrapingMetadataRepository',
        'UPSERT 失败',
        e.toString(),
        stack,
      );
      rethrow;
    }
  }

  /// 按 ID 获取元数据
  Future<ScrapingMetadata?> getById(String id) async {
    DebugLogger.database('ScrapingMetadataRepository', 'GET', 'id=$id');
    try {
      final result = IsarManager.getMetadata(id);
      if (result != null) {
        DebugLogger.success('ScrapingMetadataRepository', '找到记录: $id');
      } else {
        DebugLogger.warning('ScrapingMetadataRepository', '记录不存在: $id');
      }
      return result;
    } catch (e, stack) {
      DebugLogger.error(
        'ScrapingMetadataRepository',
        'GET 失败',
        e.toString(),
        stack,
      );
      return null;
    }
  }

  /// 按 filePath 获取元数据
  Future<ScrapingMetadata?> getByFilePath(
    String sourceId,
    String filePath,
  ) async {
    final id = '$sourceId::$filePath';
    return getById(id);
  }

  /// 获取待刮削的元数据（status == pending）
  Future<List<ScrapingMetadata>> getPending({int limit = 100}) async {
    DebugLogger.database(
      'ScrapingMetadataRepository',
      'GET_PENDING',
      'limit=$limit',
    );
    try {
      final all = IsarManager.getAllMetadata();
      final pending = all
          .where((m) => m.status == ScrapingStatus.pending)
          .toList(growable: false);

      if (pending.isEmpty) {
        DebugLogger.warning('ScrapingMetadataRepository', '没有待刮削的记录');
      } else {
        DebugLogger.success(
          'ScrapingMetadataRepository',
          '找到 ${pending.length} 个待刮削的记录',
        );
      }

      return pending.sublist(
        0,
        pending.length > limit ? limit : pending.length,
      );
    } catch (e, stack) {
      DebugLogger.error(
        'ScrapingMetadataRepository',
        'GET_PENDING 失败',
        e.toString(),
        stack,
      );
      return [];
    }
  }

  /// 获取失败且可以重试的元数据
  Future<List<ScrapingMetadata>> getFailedForRetry({int maxRetries = 3}) async {
    DebugLogger.database(
      'ScrapingMetadataRepository',
      'GET_FAILED_FOR_RETRY',
      'maxRetries=$maxRetries',
    );
    try {
      final all = IsarManager.getAllMetadata();
      final failed =
          all
              .where(
                (m) =>
                    m.status == ScrapingStatus.failed &&
                    m.retryCount < maxRetries,
              )
              .toList()
            ..sort(
              (a, b) => (a.lastAttemptAt ?? DateTime.now()).compareTo(
                b.lastAttemptAt ?? DateTime.now(),
              ),
            );

      if (failed.isEmpty) {
        DebugLogger.info('ScrapingMetadataRepository', '没有可重试的失败记录');
      } else {
        DebugLogger.success(
          'ScrapingMetadataRepository',
          '找到 ${failed.length} 个可重试的失败记录',
        );
      }
      return failed;
    } catch (e, stack) {
      DebugLogger.error(
        'ScrapingMetadataRepository',
        'GET_FAILED_FOR_RETRY 失败',
        e.toString(),
        stack,
      );
      return [];
    }
  }

  /// 获取指定源的所有元数据
  Future<List<ScrapingMetadata>> getBySourceId(String sourceId) async {
    DebugLogger.database(
      'ScrapingMetadataRepository',
      'GET_BY_SOURCE',
      'sourceId=$sourceId',
    );
    try {
      final all = IsarManager.getAllMetadata();
      final results = all.where((m) => m.sourceId == sourceId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      DebugLogger.success(
        'ScrapingMetadataRepository',
        '找到 ${results.length} 个属于源 "$sourceId" 的记录',
      );
      return results;
    } catch (e, stack) {
      DebugLogger.error(
        'ScrapingMetadataRepository',
        'GET_BY_SOURCE 失败',
        e.toString(),
        stack,
      );
      return [];
    }
  }

  /// 获取已手动刮削的元数据
  Future<List<ScrapingMetadata>> getManuallyScraped() async {
    final all = IsarManager.getAllMetadata();
    return all
        .where((m) => m.manuallyScrapedTitle?.isNotEmpty == true)
        .toList();
  }

  /// 获取已自动刮削的元数据
  Future<List<ScrapingMetadata>> getAutoScraped() async {
    final all = IsarManager.getAllMetadata();
    return all.where((m) => m.autoScrapedTitle?.isNotEmpty == true).toList();
  }

  /// 更新刮削状态
  Future<void> updateStatus(
    String id,
    ScrapingStatus status, {
    String? errorMessage,
  }) async {
    final metadata = await getById(id);
    if (metadata != null) {
      metadata.status = status;
      metadata.updatedAt = DateTime.now();
      metadata.lastAttemptAt = DateTime.now();
      if (errorMessage != null) {
        metadata.errorMessage = errorMessage;
      }
      if (status == ScrapingStatus.failed) {
        metadata.retryCount++;
      }
      await upsert(metadata);
    }
  }

  /// 更新手动刮削结果
  Future<void> updateManualScrapingResult(
    String id, {
    required String? title,
    required String? artist,
    required String? album,
    required String? coverUrl,
    String? localCoverPath,
    required String? lyrics,
  }) async {
    final metadata = await getById(id);
    if (metadata != null) {
      metadata.manuallyScrapedTitle = title;
      metadata.manuallyScrapedArtist = artist;
      metadata.manuallyScrapedAlbum = album;
      metadata.manuallyScrapedCoverUrl = coverUrl;
      metadata.manuallyScrapedLocalCoverPath = localCoverPath;
      metadata.manuallyScrapedLyrics = lyrics;
      metadata.manualScrapedAt = DateTime.now();
      metadata.status = ScrapingStatus.completed;
      metadata.updatedAt = DateTime.now();
      await upsert(metadata);
    }
  }

  /// 更新自动刮削结果
  Future<void> updateAutoScrapingResult(
    String id, {
    required String? title,
    required String? artist,
    required String? album,
    required String? coverUrl,
    String? localCoverPath,
    required String? lyrics,
    required double matchScore,
  }) async {
    final metadata = await getById(id);
    if (metadata != null) {
      metadata.autoScrapedTitle = title;
      metadata.autoScrapedArtist = artist;
      metadata.autoScrapedAlbum = album;
      metadata.autoScrapedCoverUrl = coverUrl;
      metadata.autoScrapedLocalCoverPath = localCoverPath;
      if ((coverUrl?.trim().isNotEmpty ?? false) ||
          (localCoverPath?.trim().isNotEmpty ?? false)) {
        metadata.autoScrapedCoverSource = 'scraped';
      }
      metadata.autoScrapedLyrics = lyrics;
      if (lyrics?.trim().isNotEmpty == true) {
        metadata.autoScrapedLyricsSource = 'scraped';
      }
      metadata.matchScore = matchScore;
      metadata.autoScrapedAt = DateTime.now();
      metadata.status = ScrapingStatus.completed;
      metadata.updatedAt = DateTime.now();
      await upsert(metadata);
    }
  }

  /// 创建初始元数据记录
  /// 在扫描新歌曲时调用
  Future<ScrapingMetadata> createInitialMetadata({
    required String sourceId,
    required String filePath,
    required String filename,
    String? originalArtist,
  }) async {
    final filenameWithoutExt = _removeExtension(filename);
    final id = '$sourceId::$filePath';
    final metadata = ScrapingMetadata(
      id: id,
      sourceId: sourceId,
      filePath: filePath,
      filenameWithoutExt: filenameWithoutExt,
      originalFileName: filename,
      originalArtist: originalArtist,
      status: ScrapingStatus.pending,
    );

    await upsert(metadata);
    return metadata;
  }

  /// 删除指定的元数据
  Future<void> deleteByIds(List<String> ids) async {
    for (final id in ids) {
      await IsarManager.deleteMetadata(id);
    }
  }

  /// 按源删除所有元数据
  Future<void> deleteBySourceId(String sourceId) async {
    final items = await getBySourceId(sourceId);
    await deleteByIds(items.map((m) => m.id).toList());
  }

  /// 获取统计信息
  Future<ScrapingStats> getStats() async {
    final all = IsarManager.getAllMetadata();
    final pending = all.where((m) => m.status == ScrapingStatus.pending).length;
    final scraping = all
        .where((m) => m.status == ScrapingStatus.scraping)
        .length;
    final completed = all
        .where((m) => m.status == ScrapingStatus.completed)
        .length;
    final failed = all.where((m) => m.status == ScrapingStatus.failed).length;
    final manual = all
        .where((m) => m.manuallyScrapedTitle?.isNotEmpty == true)
        .length;

    return ScrapingStats(
      total: all.length,
      pending: pending,
      scraping: scraping,
      completed: completed,
      failed: failed,
      manual: manual,
    );
  }

  /// 清空所有数据
  Future<void> clear() async {
    await IsarManager.clearAllMetadata();
  }

  String _removeExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1) return filename;
    return filename.substring(0, lastDot);
  }
}

/// 刮削统计信息
class ScrapingStats {
  final int total;
  final int pending;
  final int scraping;
  final int completed;
  final int failed;
  final int manual;

  ScrapingStats({
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
ScrapingStats(
  total: $total,
  pending: $pending,
  completed: $completed,
  manual: $manual,
  failed: $failed,
)
  ''';
}
