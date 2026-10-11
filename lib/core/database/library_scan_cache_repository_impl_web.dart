import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_song.dart';
import '../utils/debug_logger.dart';
import 'library_scan_cache_repository_contract.dart';

const _scanCacheBatchSize = 128;

// Web has no Dart isolates; yield between batches so input and painting can run.
Future<String> _encodeScanCache(Map<String, dynamic> sources) async {
  final encoded = StringBuffer('{');
  var firstSource = true;
  for (final entry in sources.entries) {
    if (!firstSource) encoded.write(',');
    firstSource = false;
    encoded.write('${jsonEncode(entry.key)}:');
    if (entry.value is! List) {
      encoded.write(jsonEncode(entry.value));
      continue;
    }
    encoded.write('[');
    final songs = entry.value as List;
    for (var start = 0; start < songs.length; start += _scanCacheBatchSize) {
      if (start > 0) encoded.write(',');
      final end = (start + _scanCacheBatchSize).clamp(0, songs.length);
      final batch = jsonEncode(
        songs.sublist(start, end),
        toEncodable: (value) => (value as LibrarySong).toJson(),
      );
      encoded.write(batch.substring(1, batch.length - 1));
      await Future<void>.delayed(Duration.zero);
    }
    encoded.write(']');
  }
  encoded.write('}');
  return encoded.toString();
}

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
    allData[sourceId] = songs;
    await _prefs.setString(_cacheKey, await _encodeScanCache(allData));
  }

  @override
  Future<void> saveAllResults(Map<String, List<LibrarySong>> results) async {
    if (results.isEmpty) {
      await _prefs.remove(_cacheKey);
      return;
    }
    await _prefs.setString(_cacheKey, await _encodeScanCache(results));
  }

  @override
  Future<void> deleteScanResults(String sourceId) async {
    final allData = await _loadRawData();
    allData.remove(sourceId);
    if (allData.isEmpty) {
      await _prefs.remove(_cacheKey);
      return;
    }
    await _prefs.setString(_cacheKey, await _encodeScanCache(allData));
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
        final rawSongs = entry.value as List<dynamic>;
        final songs = <LibrarySong>[];
        for (var index = 0; index < rawSongs.length; index++) {
          songs.add(
            LibrarySong.fromJson(rawSongs[index] as Map<String, dynamic>),
          );
          if ((index + 1) % _scanCacheBatchSize == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
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
