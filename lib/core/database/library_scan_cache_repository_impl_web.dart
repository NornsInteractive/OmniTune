import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_song.dart';
import '../utils/debug_logger.dart';
import 'library_scan_cache_repository_contract.dart';

class SharedPreferencesScanCacheRepository
    implements LibraryScanCacheRepository {
  SharedPreferencesScanCacheRepository(this._prefs);

  static const _cacheKey = 'library_scan_cache_v1';

  final SharedPreferences _prefs;

  @override
  Future<List<LibrarySong>> loadScanResults(String sourceId) async {
    final allResults = await loadAllResults();
    return allResults[sourceId] ?? const [];
  }

  @override
  Future<void> saveScanResults(String sourceId, List<LibrarySong> songs) async {
    final allData = await _loadRawData();
    allData[sourceId] = songs.map((song) => song.toJson()).toList();
    await _prefs.setString(_cacheKey, jsonEncode(allData));
  }

  @override
  Future<void> deleteScanResults(String sourceId) async {
    final allData = await _loadRawData();
    allData.remove(sourceId);
    if (allData.isEmpty) {
      await _prefs.remove(_cacheKey);
      return;
    }
    await _prefs.setString(_cacheKey, jsonEncode(allData));
  }

  @override
  Future<void> clearAll() async {
    await _prefs.remove(_cacheKey);
  }

  @override
  Future<Map<String, List<LibrarySong>>> loadAllResults() async {
    final allData = await _loadRawData();
    final result = <String, List<LibrarySong>>{};

    for (final entry in allData.entries) {
      try {
        final songs = (entry.value as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map((item) => LibrarySong.fromJson(item))
            .toList();
        result[entry.key] = songs;
      } catch (error) {
        DebugLogger.error(
          'SharedPreferencesScanCacheRepository',
          '加载源 ${entry.key} 的缓存失败: $error',
        );
      }
    }

    return result;
  }

  Future<Map<String, dynamic>> _loadRawData() async {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (error) {
      DebugLogger.error(
        'SharedPreferencesScanCacheRepository',
        '解析扫描缓存失败，已重置缓存: $error',
      );
      await _prefs.remove(_cacheKey);
      return <String, dynamic>{};
    }
  }
}

Future<LibraryScanCacheRepository> createScanCacheRepository() async {
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesScanCacheRepository(prefs);
}
