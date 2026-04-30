import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:music/core/utils/debug_logger.dart';

import 'scraping_cache.dart';
import 'scraping_metadata.dart';

/// 简单的内存/持久化数据管理器（使用 SharedPreferences + JSON）
class IsarManager {
  static late SharedPreferences _prefs;
  static final Map<String, ScrapingMetadata> _metadataCache = {};
  static final Map<String, ScrapingCache> _cacheCache = {};

  static const String _metadataPrefix = 'scraping_metadata_';
  static const String _cachePrefix = 'scraping_cache_';
  static const String _metadataListKey = 'scraping_metadata_list';
  static const String _cacheListKey = 'scraping_cache_list';

  /// 初始化管理器（加载 SharedPreferences）
  static Future<void> initialize() async {
    DebugLogger.database('IsarManager', 'INIT', '初始化中...');
    try {
      _prefs = await SharedPreferences.getInstance();
      DebugLogger.success('IsarManager', 'SharedPreferences 初始化成功');
      // 可以在这里加载所有缓存到内存（如果需要）
    } catch (e, stack) {
      DebugLogger.error('IsarManager', 'INIT 失败', e.toString(), stack);
      rethrow;
    }
  }

  /// 获取 SharedPreferences 实例
  static SharedPreferences get prefs => _prefs;

  /// 保存元数据
  static Future<void> saveMetadata(ScrapingMetadata metadata) async {
    DebugLogger.info('IsarManager', '保存元数据: id=${metadata.id}');
    _metadataCache[metadata.id] = metadata;
    final key = '$_metadataPrefix${metadata.id}';
    try {
      await _prefs.setString(key, jsonEncode(metadata.toJson()));
      DebugLogger.success('IsarManager', '元数据保存成功');

      // 更新索引列表
      final list = _prefs.getStringList(_metadataListKey) ?? [];
      if (!list.contains(metadata.id)) {
        list.add(metadata.id);
        await _prefs.setStringList(_metadataListKey, list);
        DebugLogger.info('IsarManager', '已添加到索引列表, 总数: ${list.length}');
      }
    } catch (e, stack) {
      DebugLogger.error('IsarManager', '保存元数据失败', e.toString(), stack);
      rethrow;
    }
  }

  /// 获取元数据
  static ScrapingMetadata? getMetadata(String id) {
    if (_metadataCache.containsKey(id)) {
      DebugLogger.info('IsarManager', '从缓存获取: id=$id');
      return _metadataCache[id];
    }

    final key = '$_metadataPrefix$id';
    final json = _prefs.getString(key);
    if (json != null) {
      try {
        final metadata = ScrapingMetadata.fromJson(jsonDecode(json));
        _metadataCache[id] = metadata;
        DebugLogger.success('IsarManager', '从存储加载: id=$id');
        return metadata;
      } catch (e, stack) {
        DebugLogger.error('IsarManager', '解析 JSON 失败', e.toString(), stack);
        return null;
      }
    }
    DebugLogger.warning('IsarManager', '元数据不存在: id=$id');
    return null;
  }

  /// 获取所有元数据
  static List<ScrapingMetadata> getAllMetadata() {
    final list = _prefs.getStringList(_metadataListKey) ?? [];
    DebugLogger.info('IsarManager', '获取所有元数据, 总数: ${list.length}');
    return list.map((id) => getMetadata(id)).whereType<ScrapingMetadata>().toList();
  }

  /// 删除元数据
  static Future<void> deleteMetadata(String id) async {
    DebugLogger.info('IsarManager', '删除元数据: id=$id');
    try {
      _metadataCache.remove(id);
      final key = '$_metadataPrefix$id';
      await _prefs.remove(key);

      final list = _prefs.getStringList(_metadataListKey) ?? [];
      list.remove(id);
      await _prefs.setStringList(_metadataListKey, list);
      DebugLogger.success('IsarManager', '元数据删除成功');
    } catch (e, stack) {
      DebugLogger.error('IsarManager', '删除失败', e.toString(), stack);
      rethrow;
    }
  }

  /// 清空所有元数据
  static Future<void> clearAllMetadata() async {
    DebugLogger.info('IsarManager', '清空所有元数据');
    try {
      _metadataCache.clear();
      final list = _prefs.getStringList(_metadataListKey) ?? [];
      for (final id in list) {
        await _prefs.remove('$_metadataPrefix$id');
      }
      await _prefs.remove(_metadataListKey);
      DebugLogger.success('IsarManager', '已清空所有元数据');
    } catch (e, stack) {
      DebugLogger.error('IsarManager', '清空失败', e.toString(), stack);
      rethrow;
    }
  }

  /// 保存缓存
  static Future<void> saveCache(ScrapingCache cache) async {
    DebugLogger.info('IsarManager', '保存缓存: id=${cache.id}');
    try {
      _cacheCache[cache.id] = cache;
      final key = '$_cachePrefix${cache.id}';
      await _prefs.setString(key, jsonEncode(cache.toJson()));

      // 更新索引列表
      final list = _prefs.getStringList(_cacheListKey) ?? [];
      if (!list.contains(cache.id)) {
        list.add(cache.id);
        await _prefs.setStringList(_cacheListKey, list);
      }
      DebugLogger.success('IsarManager', '缓存保存成功');
    } catch (e, stack) {
      DebugLogger.error('IsarManager', '保存缓存失败', e.toString(), stack);
      rethrow;
    }
  }

  /// 获取缓存
  static ScrapingCache? getCache(String id) {
    if (_cacheCache.containsKey(id)) {
      DebugLogger.info('IsarManager', '从缓存获取: id=$id');
      return _cacheCache[id];
    }

    final key = '$_cachePrefix$id';
    final json = _prefs.getString(key);
    if (json != null) {
      try {
        final cache = ScrapingCache.fromJson(jsonDecode(json));
        _cacheCache[id] = cache;
        DebugLogger.success('IsarManager', '从存储加载缓存: id=$id');
        return cache;
      } catch (e, stack) {
        DebugLogger.error('IsarManager', '解析缓存 JSON 失败', e.toString(), stack);
        return null;
      }
    }
    DebugLogger.warning('IsarManager', '缓存不存在: id=$id');
    return null;
  }

  /// 删除缓存
  static Future<void> deleteCache(String id) async {
    DebugLogger.info('IsarManager', '删除缓存: id=$id');
    try {
      _cacheCache.remove(id);
      final key = '$_cachePrefix$id';
      await _prefs.remove(key);

      final list = _prefs.getStringList(_cacheListKey) ?? [];
      list.remove(id);
      await _prefs.setStringList(_cacheListKey, list);
      DebugLogger.success('IsarManager', '缓存删除成功');
    } catch (e, stack) {
      DebugLogger.error('IsarManager', '删除失败', e.toString(), stack);
      rethrow;
    }
  }

  /// 清空所有缓存
  static Future<void> clearAllCache() async {
    DebugLogger.info('IsarManager', '清空所有缓存');
    try {
      _cacheCache.clear();
      final list = _prefs.getStringList(_cacheListKey) ?? [];
      for (final id in list) {
        await _prefs.remove('$_cachePrefix$id');
      }
      await _prefs.remove(_cacheListKey);
      DebugLogger.success('IsarManager', '已清空所有缓存');
    } catch (e, stack) {
      DebugLogger.error('IsarManager', '清空缓存失败', e.toString(), stack);
      rethrow;
    }
  }

  /// 清空所有数据
  static Future<void> clearAll() async {
    DebugLogger.info('IsarManager', '清空所有数据');
    try {
      await clearAllMetadata();
      await clearAllCache();
      DebugLogger.success('IsarManager', '所有数据清空成功');
    } catch (e, stack) {
      DebugLogger.error('IsarManager', '清空所有数据失败', e.toString(), stack);
      rethrow;
    }
  }
}
