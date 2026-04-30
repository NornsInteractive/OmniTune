import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/library_song.dart';
import '../utils/debug_logger.dart';

part 'scraped_metadata_repository.g.dart';

/// 单个歌曲的刮削结果
class ScrapedSongMetadata {
  const ScrapedSongMetadata({
    required this.songId,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverUrl,
    required this.lyrics,
    required this.scrapedAt,
  });

  final String songId;
  final String title;
  final String artist;
  final String album;
  final String? coverUrl;
  final String? lyrics;
  final DateTime scrapedAt;

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'title': title,
    'artist': artist,
    'album': album,
    'coverUrl': coverUrl,
    'lyrics': lyrics,
    'scrapedAt': scrapedAt.toIso8601String(),
  };

  factory ScrapedSongMetadata.fromJson(Map<String, dynamic> json) =>
      ScrapedSongMetadata(
        songId: json['songId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String? ?? '',
        coverUrl: json['coverUrl'] as String?,
        lyrics: json['lyrics'] as String?,
        scrapedAt: json['scrapedAt'] != null
            ? DateTime.parse(json['scrapedAt'] as String)
            : DateTime.now(),
      );

  /// 应用到 LibrarySong 的 copyWithAutoScraped
  LibrarySong applyToSong(LibrarySong song) => LibrarySong(
    id: song.id,
    sourceId: song.sourceId,
    sourceName: song.sourceName,
    title: song.title,
    fileName: song.fileName,
    remotePath: song.remotePath,
    albumTitle: song.albumTitle,
    artistName: song.artistName,
    directoryPath: song.directoryPath,
    folderAlbumTitle: song.folderAlbumTitle,
    folderArtistName: song.folderArtistName,
    scrapedAlbumTitle: song.scrapedAlbumTitle,
    scrapedArtistName: song.scrapedArtistName,
    mimeType: song.mimeType,
    size: song.size,
    modifiedAt: song.modifiedAt,
    manuallyScrapedTitle: song.manuallyScrapedTitle,
    manuallyScrapedArtist: song.manuallyScrapedArtist,
    manuallyScrapedAlbum: song.manuallyScrapedAlbum,
    manuallyScrapedCoverUrl: song.manuallyScrapedCoverUrl,
    manuallyScrapedLyrics: song.manuallyScrapedLyrics,
    autoScrapedTitle: title.isEmpty ? song.autoScrapedTitle : title,
    autoScrapedArtist: artist.isEmpty ? song.autoScrapedArtist : artist,
    autoScrapedAlbum: album.isEmpty ? song.autoScrapedAlbum : album,
    autoScrapedCoverUrl: coverUrl ?? song.autoScrapedCoverUrl,
    autoScrapedLyrics: lyrics ?? song.autoScrapedLyrics,
  );
}

/// 刮削结果缓存仓库 - 使用 JSON 文件存储
class ScrapedMetadataRepository {
  ScrapedMetadataRepository._();

  static const String _fileName = 'scraped_metadata_cache.json';

  /// 获取仓库实例
  static Future<ScrapedMetadataRepository> create() async {
    return ScrapedMetadataRepository._();
  }

  /// 保存单个歌曲的刮削结果
  Future<void> saveMetadata(ScrapedSongMetadata metadata) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = _getFile(dir);

      // 读取现有数据
      final data = await _loadJson(file);

      // 更新或添加
      data[metadata.songId] = metadata.toJson();

      // 写回
      await file.writeAsString(jsonEncode(data));

      DebugLogger.database(
        'ScrapedMetadataRepository',
        'saveMetadata',
        '已保存: ${metadata.songId}',
      );
    } catch (e) {
      DebugLogger.error('ScrapedMetadataRepository', 'saveMetadata 失败', e);
    }
  }

  /// 加载单个歌曲的刮削结果
  Future<ScrapedSongMetadata?> loadMetadata(String songId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = _getFile(dir);

      if (!await file.exists()) {
        return null;
      }

      final data = await _loadJson(file);
      final metadata = data[songId];

      if (metadata != null) {
        return ScrapedSongMetadata.fromJson(metadata as Map<String, dynamic>);
      }
    } catch (e) {
      DebugLogger.error('ScrapedMetadataRepository', 'loadMetadata 失败', e);
    }

    return null;
  }

  /// 批量加载刮削结果
  Future<Map<String, ScrapedSongMetadata>> loadAllMetadata() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = _getFile(dir);

      if (!await file.exists()) {
        return {};
      }

      final data = await _loadJson(file);
      final result = <String, ScrapedSongMetadata>{};

      for (final entry in data.entries) {
        try {
          result[entry.key] = ScrapedSongMetadata.fromJson(
            entry.value as Map<String, dynamic>,
          );
        } catch (e) {
          DebugLogger.warning(
            'ScrapedMetadataRepository',
            '加载 ${entry.key} 失败: $e',
          );
        }
      }

      DebugLogger.database(
        'ScrapedMetadataRepository',
        'loadAllMetadata',
        '已加载 ${result.length} 个刮削结果',
      );
      return result;
    } catch (e) {
      DebugLogger.error('ScrapedMetadataRepository', 'loadAllMetadata 失败', e);
      return {};
    }
  }

  /// 删除单个歌曲的刮削结果
  Future<void> deleteMetadata(String songId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = _getFile(dir);

      if (!await file.exists()) {
        return;
      }

      final data = await _loadJson(file);
      data.remove(songId);

      await file.writeAsString(jsonEncode(data));

      DebugLogger.database(
        'ScrapedMetadataRepository',
        'deleteMetadata',
        '已删除: $songId',
      );
    } catch (e) {
      DebugLogger.error('ScrapedMetadataRepository', 'deleteMetadata 失败', e);
    }
  }

  /// 清空所有刮削结果
  Future<void> clearAll() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = _getFile(dir);

      if (await file.exists()) {
        await file.delete();
      }

      DebugLogger.database(
        'ScrapedMetadataRepository',
        'clearAll',
        '已清空所有刮削缓存',
      );
    } catch (e) {
      DebugLogger.error('ScrapedMetadataRepository', 'clearAll 失败', e);
    }
  }

  /// 获取缓存文件路径
  static Future<String> getCacheFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  // ===== 私有方法 =====

  Future<Map<String, dynamic>> _loadJson(File file) async {
    if (!await file.exists()) {
      return {};
    }

    try {
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>? ?? {};
    } catch (e) {
      DebugLogger.warning('ScrapedMetadataRepository', 'JSON 解析失败，使用空映射');
      return {};
    }
  }

  File _getFile(Directory dir) {
    final path = '${dir.path}/$_fileName';
    return File(path);
  }
}

// ===== Riverpod 提供者 =====

@riverpod
Future<ScrapedMetadataRepository> scrapedMetadataRepository(Ref ref) async {
  return await ScrapedMetadataRepository.create();
}

/// 已加载的刮削结果缓存
@riverpod
class ScrapedMetadataCache extends _$ScrapedMetadataCache {
  @override
  Future<Map<String, ScrapedSongMetadata>> build() async {
    final repo = await ref.watch(scrapedMetadataRepositoryProvider.future);
    return await repo.loadAllMetadata();
  }

  /// 更新单个歌曲的刮削结果
  Future<void> updateMetadata(ScrapedSongMetadata metadata) async {
    final repo = await ref.read(scrapedMetadataRepositoryProvider.future);
    await repo.saveMetadata(metadata);

    // 刷新缓存
    state = AsyncData({
      ...(state.valueOrNull ?? {}),
      metadata.songId: metadata,
    });
  }

  /// 清空所有缓存
  Future<void> clearAll() async {
    final repo = await ref.read(scrapedMetadataRepositoryProvider.future);
    await repo.clearAll();
    state = const AsyncData(<String, ScrapedSongMetadata>{});
  }
}
