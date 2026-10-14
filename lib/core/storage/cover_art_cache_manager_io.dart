import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/debug_logger.dart';

/// 封面艺术缓存管理器
/// 负责下载并缓存音乐封面到本地应用沙盒。
class CoverArtCacheManager {
  factory CoverArtCacheManager() {
    return _instance;
  }

  CoverArtCacheManager._internal()
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.bytes,
        ),
      ) {
    _dio.options.headers['User-Agent'] =
        'FlutterMusicPlayer/1.0.0 (cover-cache)';
  }

  static final CoverArtCacheManager _instance =
      CoverArtCacheManager._internal();

  final Dio _dio;

  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/cover_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  String _generateFileName(String url) {
    final hash = md5.convert(url.codeUnits).toString();
    final extension = _extensionForUrl(url);
    return '$hash$extension';
  }

  String _generateKeyFileName(String cacheKey, String extension) {
    final hash = md5.convert(cacheKey.codeUnits).toString();
    return '$hash${_normalizeExtension(extension)}';
  }

  Future<bool> isUsableLocalPath(String path) async {
    try {
      return await File(path).exists() && await File(path).length() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> downloadAndCache(String coverUrl) async {
    if (coverUrl.trim().isEmpty) {
      return null;
    }

    try {
      final cacheDir = await _getCacheDir();
      final fileName = _generateFileName(coverUrl);
      final filePath = '${cacheDir.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        DebugLogger.success('CoverArtCache', '本地缓存命中');
        return filePath;
      }

      DebugLogger.info('CoverArtCache', '下载封面');
      final response = await _dio.get<List<int>>(coverUrl);
      final statusCode = response.statusCode ?? 0;
      final bytes = response.data;
      if (statusCode >= 200 && statusCode < 300 && bytes != null) {
        await file.writeAsBytes(bytes, flush: true);
        DebugLogger.success(
          'CoverArtCache',
          '封面已缓存 (${bytes.length} bytes): $filePath',
        );
        return filePath;
      }

      DebugLogger.warning(
        'CoverArtCache',
        '下载失败 (HTTP ${response.statusCode})',
      );
      return null;
    } catch (e, stack) {
      DebugLogger.error('CoverArtCache', '缓存异常', e.runtimeType.toString(), stack);
      return null;
    }
  }

  Future<String?> cachedPathForUrl(String coverUrl) async {
    if (coverUrl.trim().isEmpty) {
      return null;
    }
    final cacheDir = await _getCacheDir();
    final file = File('${cacheDir.path}/${_generateFileName(coverUrl)}');
    return await file.exists() ? file.path : null;
  }

  Future<String?> cachedPathForKey(
    String cacheKey, {
    String extension = '.jpg',
  }) async {
    if (cacheKey.trim().isEmpty) {
      return null;
    }
    final cacheDir = await _getCacheDir();
    final file = File(
      '${cacheDir.path}/${_generateKeyFileName(cacheKey, extension)}',
    );
    return await file.exists() ? file.path : null;
  }

  Future<String?> cacheBytes(
    String cacheKey,
    Uint8List bytes, {
    String extension = '.jpg',
  }) async {
    if (cacheKey.trim().isEmpty || bytes.isEmpty) {
      return null;
    }

    try {
      final cacheDir = await _getCacheDir();
      final file = File(
        '${cacheDir.path}/${_generateKeyFileName(cacheKey, extension)}',
      );
      if (!await file.exists()) {
        await file.writeAsBytes(bytes, flush: true);
      }
      return file.path;
    } catch (e, stack) {
      DebugLogger.error('CoverArtCache', '写入封面缓存失败', e.toString(), stack);
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        DebugLogger.success('CoverArtCache', '缓存已清空');
      }
    } catch (e, stack) {
      DebugLogger.error('CoverArtCache', '清空缓存失败', e.toString(), stack);
    }
  }

  Future<int> getCacheSizeBytes() async {
    try {
      final cacheDir = await _getCacheDir();
      var totalSize = 0;

      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }

      return totalSize;
    } catch (e, stack) {
      DebugLogger.error('CoverArtCache', '获取缓存大小失败', e.toString(), stack);
      return 0;
    }
  }

  String _extensionForUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.png')) {
      return '.png';
    }
    if (path.endsWith('.webp')) {
      return '.webp';
    }
    if (path.endsWith('.jpeg')) {
      return '.jpeg';
    }
    return '.jpg';
  }

  String _normalizeExtension(String extension) {
    final normalized = extension.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '.jpg';
    }
    return normalized.startsWith('.') ? normalized : '.$normalized';
  }
}
