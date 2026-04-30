import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/debug_logger.dart';
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
    DebugLogger.info('JsonFileScanCacheRepository.saveScanResults', '开始保存扫描结果: sourceId=$sourceId, 歌曲数=${songs.length}');
    try {
      DebugLogger.info('JsonFileScanCacheRepository.saveScanResults', '缓存文件路径: ${_cacheFile.path}');
      
      // 加载现有数据
      final allData = <String, dynamic>{};
      final file = _cacheFile;

      if (await file.exists()) {
        DebugLogger.info('JsonFileScanCacheRepository.saveScanResults', '缓存文件已存在，读取现有数据');
        final content = await file.readAsString();
        allData.addAll(jsonDecode(content) as Map<String, dynamic>);
        DebugLogger.info('JsonFileScanCacheRepository.saveScanResults', '已读取现有数据，现有源数: ${allData.length}');
      } else {
        DebugLogger.info('JsonFileScanCacheRepository.saveScanResults', '缓存文件不存在，创建新文件');
      }

      // 更新该源的数据
      DebugLogger.info('JsonFileScanCacheRepository.saveScanResults', '开始序列化 ${songs.length} 首歌曲为 JSON');
      allData[sourceId] = songs.map((song) => song.toJson()).toList();
      DebugLogger.info('JsonFileScanCacheRepository.saveScanResults', '序列化完成，现在有 ${allData.length} 个源');

      // 写入文件
      DebugLogger.info('JsonFileScanCacheRepository.saveScanResults', '开始写入文件: ${_cacheFile.path}');
      await file.writeAsString(jsonEncode(allData), flush: true);
      DebugLogger.success('JsonFileScanCacheRepository.saveScanResults', '✅ 保存成功: sourceId=$sourceId, 歌曲数=${songs.length}');
    } catch (e, stack) {
      DebugLogger.error('JsonFileScanCacheRepository.saveScanResults', '保存失败: $e', stack.toString());
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
    DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '开始加载所有缓存结果');
    try {
      final file = _cacheFile;
      DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '缓存文件路径: ${file.path}');
      
      final exists = await file.exists();
      DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '文件是否存在: $exists');
      
      if (!exists) {
        DebugLogger.warning('JsonFileScanCacheRepository.loadAllResults', '⚠️ 缓存文件不存在，返回空 map');
        return {};
      }

      DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '读取文件内容');
      String content;
      try {
        content = await file.readAsString();
      } catch (e) {
        DebugLogger.error('JsonFileScanCacheRepository.loadAllResults', '❌ 文件读取异常（可能编码问题）: $e');
        DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '尝试删除损坏的文件并返回空结果');
        try {
          await file.delete();
          DebugLogger.success('JsonFileScanCacheRepository.loadAllResults', '✅ 已删除损坏的缓存文件');
        } catch (deleteE) {
          DebugLogger.error('JsonFileScanCacheRepository.loadAllResults', '无法删除文件: $deleteE');
        }
        return {};
      }
      
      if (content.isEmpty) {
        DebugLogger.warning('JsonFileScanCacheRepository.loadAllResults', '⚠️ 文件为空，返回空 map');
        return {};
      }

      DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '解析 JSON，文件大小: ${content.length} 字符');
      Map<String, dynamic> allData;
      try {
        allData = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        DebugLogger.error('JsonFileScanCacheRepository.loadAllResults', '❌ JSON 解析失败: $e');
        DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '文件内容（前 200 字符）: ${content.substring(0, content.length > 200 ? 200 : content.length)}');
        DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '尝试删除损坏的文件并返回空结果');
        try {
          await file.delete();
          DebugLogger.success('JsonFileScanCacheRepository.loadAllResults', '✅ 已删除包含非法 JSON 的缓存文件');
        } catch (deleteE) {
          DebugLogger.error('JsonFileScanCacheRepository.loadAllResults', '无法删除文件: $deleteE');
        }
        return {};
      }

      DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '解析完成，找到 ${allData.length} 个源');

      final result = <String, List<LibrarySong>>{};
      for (final entry in allData.entries) {
        try {
          DebugLogger.info('JsonFileScanCacheRepository.loadAllResults', '加载源: ${entry.key}, 歌曲数: ${(entry.value as List).length}');
          final songs = (entry.value as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map((item) => LibrarySong.fromJson(item))
              .toList();
          result[entry.key] = songs;
        } catch (e) {
          DebugLogger.error('JsonFileScanCacheRepository.loadAllResults', '加载源 ${entry.key} 失败: $e');
        }
      }

      DebugLogger.success('JsonFileScanCacheRepository.loadAllResults', '✅ 成功加载 ${result.length} 个源的缓存');
      return result;
    } catch (e, stack) {
      DebugLogger.error('JsonFileScanCacheRepository.loadAllResults', '加载缓存失败（未预期异常）: $e', stack.toString());
      return {};
    }
  }
}

/// 创建并初始化缓存存储库
Future<LibraryScanCacheRepository> createScanCacheRepository() async {
  DebugLogger.info('createScanCacheRepository', '开始创建缓存仓库');
  try {
    final cacheDir = await getApplicationCacheDirectory();
    DebugLogger.info('createScanCacheRepository', '应用缓存目录: ${cacheDir.path}');
    
    final exists = await cacheDir.exists();
    DebugLogger.info('createScanCacheRepository', '缓存目录是否存在: $exists');
    
    if (!exists) {
      DebugLogger.info('createScanCacheRepository', '缓存目录不存在，尝试创建');
      await cacheDir.create(recursive: true);
      DebugLogger.success('createScanCacheRepository', '✅ 缓存目录创建成功');
    }
    
    DebugLogger.success('createScanCacheRepository', '✅ 缓存仓库创建成功');
    return JsonFileScanCacheRepository(cacheDir);
  } catch (e, stack) {
    DebugLogger.error('createScanCacheRepository', '创建缓存仓库失败: $e', stack.toString());
    rethrow;
  }
}
