import '../utils/debug_logger.dart';

/// Web 等非 dart:io 平台不落地缓存封面，播放器会直接使用远程封面 URL。
class CoverArtCacheManager {
  factory CoverArtCacheManager() {
    return _instance;
  }

  CoverArtCacheManager._internal();

  static final CoverArtCacheManager _instance =
      CoverArtCacheManager._internal();

  Future<String?> downloadAndCache(String coverUrl) async {
    DebugLogger.info('CoverArtCache', '当前平台跳过本地封面缓存: $coverUrl');
    return null;
  }

  Future<void> clearCache() async {}

  Future<int> getCacheSizeBytes() async => 0;
}
