import '../models/library_song.dart';

/// 歌曲扫描结果的本地缓存存储库
abstract class LibraryScanCacheRepository {
  /// 加载扫描结果
  Future<List<LibrarySong>> loadScanResults(String sourceId);

  /// 保存扫描结果
  Future<void> saveScanResults(String sourceId, List<LibrarySong> songs);

  /// 删除扫描结果
  Future<void> deleteScanResults(String sourceId);

  /// 清空所有扫描结果
  Future<void> clearAll();

  /// 获取所有源的扫描结果
  Future<Map<String, List<LibrarySong>>> loadAllResults();
}
