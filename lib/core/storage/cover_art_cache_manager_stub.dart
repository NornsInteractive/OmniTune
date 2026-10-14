import 'dart:typed_data';

import '../utils/debug_logger.dart';

/// Web 等非 dart:io 平台不落地缓存封面，播放器会直接使用远程封面 URL。
class CoverArtCacheManager {
  factory CoverArtCacheManager() {
    return _instance;
  }

  CoverArtCacheManager._internal();

  static final CoverArtCacheManager _instance =
      CoverArtCacheManager._internal();

  Future<bool> isUsableLocalPath(String path) async => false;

  Future<String?> downloadAndCache(String coverUrl) async {
    DebugLogger.info('CoverArtCache', '当前平台跳过本地封面缓存: $coverUrl');
    return null;
  }

  Future<String?> cachedPathForUrl(String coverUrl) async => null;

  Future<String?> cachedPathForKey(
    String cacheKey, {
    String extension = '.jpg',
  }) async => null;

  Future<String?> cacheBytes(
    String cacheKey,
    Uint8List bytes, {
    String extension = '.jpg',
  }) async => null;

  Future<void> clearCache() async {}

  Future<int> getCacheSizeBytes() async => 0;
}
