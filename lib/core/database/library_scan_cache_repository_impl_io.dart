import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path_provider/path_provider.dart';

import '../models/library_song.dart';
import '../utils/debug_logger.dart';
import 'library_scan_cache_repository_contract.dart';

Map<String, dynamic> _decodeScanCacheJson(String content) {
  final data = jsonDecode(content) as Map<String, dynamic>;
  for (final source in data.values) {
    for (final song in source as List<dynamic>) {
      LibrarySong.fromJson(song as Map<String, dynamic>);
    }
  }
  return data;
}

String _encodeScanCacheJson(Map<String, dynamic> data) {
  return jsonEncode(data);
}

String _encodeSourceScanCache(
  (Map<String, dynamic>, String, List<LibrarySong>) input,
) {
  final (data, sourceId, songs) = input;
  data[sourceId] = songs.map((song) => song.toJson()).toList();
  return _encodeScanCacheJson(data);
}

String _encodeAllScanCache(Map<String, List<LibrarySong>> results) {
  return _encodeScanCacheJson({
    for (final entry in results.entries)
      entry.key: entry.value.map((song) => song.toJson()).toList(),
  });
}

List<LibrarySong> _decodeScanSongs(List<dynamic> source) {
  return source
      .map((song) => LibrarySong.fromJson(song as Map<String, dynamic>))
      .toList();
}

Map<String, List<LibrarySong>> _decodeAllScanSongs(Map<String, dynamic> data) {
  return {
    for (final entry in data.entries)
      entry.key: _decodeScanSongs(entry.value as List<dynamic>),
  };
}

/// 使用 JSON 文件的实现
class JsonFileScanCacheRepository implements LibraryScanCacheRepository {
  JsonFileScanCacheRepository(this._cacheDir);

  final Directory _cacheDir;
  Future<void> _pendingWrite = Future<void>.value();

  File get _cacheFile => File('${_cacheDir.path}/library_scan_cache.json');
  File get _backupFile => File('${_cacheFile.path}.bak');

  Future<void> _enqueueWrite(Future<void> Function() write) {
    final operation = _pendingWrite.then((_) => write());
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<({String content, Map<String, dynamic> data})?> _readLatest() async {
    Object? lastError;
    for (final file in [_cacheFile, _backupFile]) {
      try {
        if (!await file.exists()) {
          continue;
        }
        final content = await file.readAsString();
        final data = await compute(_decodeScanCacheJson, content);
        return (content: content, data: data);
      } catch (error) {
        lastError = error;
        DebugLogger.warning(
          'JsonFileScanCacheRepository',
          '扫描缓存无法读取，保留文件并尝试备份: $error',
        );
      }
    }
    if (lastError != null) {
      throw lastError;
    }
    return null;
  }

  Future<void> _commit(String encoded, String? previous) async {
    await _cacheDir.create(recursive: true);
    final temporary = File('${_cacheFile.path}.tmp');
    final backupTemporary = File('${_backupFile.path}.tmp');
    // Keep a complete old snapshot until the new snapshot is flushed and renamed.
    await temporary.writeAsString(encoded, flush: true);
    await backupTemporary.writeAsString(previous ?? encoded, flush: true);
    await backupTemporary.rename(_backupFile.path);
    await temporary.rename(_cacheFile.path);
  }

  @override
  Future<List<LibrarySong>> loadScanResults(String sourceId) async {
    await _pendingWrite;
    try {
      final snapshot = await _readLatest();
      final source = snapshot?.data[sourceId] as List<dynamic>?;
      if (source == null) {
        return [];
      }
      return await compute(_decodeScanSongs, source);
    } catch (error) {
      DebugLogger.warning(
        'JsonFileScanCacheRepository.loadScanResults',
        '扫描缓存加载失败，保留原文件: $error',
      );
      return [];
    }
  }

  @override
  Future<void> saveScanResults(String sourceId, List<LibrarySong> songs) {
    return _enqueueWrite(() async {
      final snapshot = await _readLatest();
      final data = snapshot?.data ?? <String, dynamic>{};
      final encoded = await compute(_encodeSourceScanCache, (
        data,
        sourceId,
        songs,
      ));
      await _commit(encoded, snapshot?.content);
    });
  }

  @override
  Future<void> saveAllResults(Map<String, List<LibrarySong>> results) {
    return _enqueueWrite(() async {
      final snapshot = await _readLatest();
      final encoded = await compute(_encodeAllScanCache, results);
      await _commit(encoded, snapshot?.content);
    });
  }

  @override
  Future<void> deleteScanResults(String sourceId) {
    return _enqueueWrite(() async {
      final snapshot = await _readLatest();
      if (snapshot == null || !snapshot.data.containsKey(sourceId)) {
        return;
      }
      final data = snapshot.data..remove(sourceId);
      final encoded = await compute(_encodeScanCacheJson, data);
      await _commit(encoded, snapshot.content);
    });
  }

  @override
  Future<void> clearAll() {
    return _enqueueWrite(() async {
      // Delete the fallback first so a successful clear cannot resurrect it.
      for (final file in [
        _backupFile,
        _cacheFile,
        File('${_backupFile.path}.tmp'),
        File('${_cacheFile.path}.tmp'),
      ]) {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
  }

  @override
  Future<Map<String, List<LibrarySong>>> loadAllResults() async {
    await _pendingWrite;
    try {
      final snapshot = await _readLatest();
      if (snapshot == null) {
        return {};
      }
      final data = snapshot.data;
      return await compute(_decodeAllScanSongs, data);
    } catch (error, stack) {
      DebugLogger.error(
        'JsonFileScanCacheRepository.loadAllResults',
        '扫描缓存加载失败，保留原文件: $error',
        stack.toString(),
      );
      return {};
    }
  }
}

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
    DebugLogger.error(
      'createScanCacheRepository',
      '创建缓存仓库失败: $e',
      stack.toString(),
    );
    rethrow;
  }
}
