import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/library_song.dart';

/// 歌曲扫描结果的本地缓存存储库
/// 使用 JSON 文件存储，无需外部数据库依赖
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

/// 使用 JSON 文件的实现
class JsonFileScanCacheRepository implements LibraryScanCacheRepository {
  JsonFileScanCacheRepository(this._cacheDir) : _fileName = 'library_scan_cache.json';

  final Directory _cacheDir;
  final String _fileName;

  File get _cacheFile => File('${_cacheDir.path}/$_fileName');

  @override
  Future<List<LibrarySong>> loadScanResults(String sourceId) async {
    try {
      final file = _cacheFile;
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final sourceData = json[sourceId] as List<dynamic>?;

      if (sourceData == null) {
        return [];
      }

      return sourceData.cast<Map<String, dynamic>>().map((item) => LibrarySong.fromJson(item)).toList();
    } catch (e) {
      // 忽略加载失败，返回空列表
      return [];
    }
  }

  @override
  Future<void> saveScanResults(String sourceId, List<LibrarySong> songs) async {
    try {
      // 加载现有数据
      final allData = <String, dynamic>{};
      final file = _cacheFile;

      if (await file.exists()) {
        final content = await file.readAsString();
        allData.addAll(jsonDecode(content) as Map<String, dynamic>);
      }

      // 更新该源的数据
      allData[sourceId] = songs.map((song) => song.toJson()).toList();

      // 写入文件
      await file.writeAsString(jsonEncode(allData), flush: true);
    } catch (e) {
      // 忽略保存失败
      rethrow;
    }
  }

  @override
  Future<void> deleteScanResults(String sourceId) async {
    try {
      final file = _cacheFile;
      if (!await file.exists()) {
        return;
      }

      final content = await file.readAsString();
      final allData = jsonDecode(content) as Map<String, dynamic>;
      allData.remove(sourceId);

      await file.writeAsString(jsonEncode(allData), flush: true);
    } catch (e) {
      // 忽略删除失败
      rethrow;
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final file = _cacheFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略清空失败
      rethrow;
    }
  }

  @override
  Future<Map<String, List<LibrarySong>>> loadAllResults() async {
    try {
      final file = _cacheFile;
      if (!await file.exists()) {
        return {};
      }

      final content = await file.readAsString();
      final allData = jsonDecode(content) as Map<String, dynamic>;

      final result = <String, List<LibrarySong>>{};
      for (final entry in allData.entries) {
        final songs = (entry.value as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((item) => LibrarySong.fromJson(item))
            .toList();
        result[entry.key] = songs;
      }

      return result;
    } catch (e) {
      // 忽略加载失败，返回空 map
      return {};
    }
  }
}

/// 创建并初始化缓存存储库
Future<LibraryScanCacheRepository> createScanCacheRepository() async {
  final cacheDir = await getApplicationCacheDirectory();
  return JsonFileScanCacheRepository(cacheDir);
}
