import 'dart:async';
import 'dart:collection';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/isar_manager.dart';
import '../../../core/database/library_scan_cache_repository.dart';
import '../../../core/database/scraping_metadata.dart';
import '../../../core/models/library_album.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/storage/cover_art_cache_manager.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../../core/utils/audio_embedded_metadata_reader.dart';
import '../../../core/utils/debug_logger.dart';
import '../../settings/application/app_settings_controller.dart';
import '../../sources/application/source_session_manager.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/domain/music_source.dart';

part 'library_catalog_controller.g.dart';

enum LibraryAlbumGroupingMode { folder, metadata }

class LibraryCatalogState {
  const LibraryCatalogState({
    this.currentSource,
    this.scannedSources = const [],
    this.tracks = const [],
    this.folderAlbums = const [],
    this.metadataAlbums = const [],
    this.favoriteTrackIds = const <String>{},
    this.likedTrackIds = const <String>{},
    this.isScanning = false,
    this.scannedDirectoryCount = 0,
    this.discoveredTrackCount = 0,
    this.lastScanPath = '/',
    this.lastScanSourceName,
    this.lastScanError,
    this.lastScannedAt,
  });

  final SourceProfile? currentSource;
  final List<SourceProfile> scannedSources;
  final List<LibrarySong> tracks;
  final List<LibraryAlbum> folderAlbums;
  final List<LibraryAlbum> metadataAlbums;
  final Set<String> favoriteTrackIds;
  final Set<String> likedTrackIds;
  final bool isScanning;
  final int scannedDirectoryCount;
  final int discoveredTrackCount;
  final String lastScanPath;
  final String? lastScanSourceName;
  final String? lastScanError;
  final DateTime? lastScannedAt;

  List<LibraryAlbum> get albums => metadataAlbums;

  bool get hasScanResult => tracks.isNotEmpty;

  List<LibrarySong> get favoriteTracks =>
      tracks.where((track) => favoriteTrackIds.contains(track.id)).toList();

  List<LibrarySong> get likedTracks =>
      tracks.where((track) => likedTrackIds.contains(track.id)).toList();

  List<LibraryAlbum> albumsForSource(
    String sourceId,
    LibraryAlbumGroupingMode mode,
  ) {
    final sourceAlbums = switch (mode) {
      LibraryAlbumGroupingMode.folder => folderAlbums,
      LibraryAlbumGroupingMode.metadata => metadataAlbums,
    };

    return sourceAlbums
        .where((album) => album.sourceId == sourceId)
        .toList(growable: false);
  }

  int albumCountForSource(String sourceId, LibraryAlbumGroupingMode mode) {
    return albumsForSource(sourceId, mode).length;
  }

  LibraryCatalogState copyWith({
    SourceProfile? currentSource,
    List<SourceProfile>? scannedSources,
    List<LibrarySong>? tracks,
    List<LibraryAlbum>? folderAlbums,
    List<LibraryAlbum>? metadataAlbums,
    Set<String>? favoriteTrackIds,
    Set<String>? likedTrackIds,
    bool? isScanning,
    int? scannedDirectoryCount,
    int? discoveredTrackCount,
    String? lastScanPath,
    String? lastScanSourceName,
    String? lastScanError,
    DateTime? lastScannedAt,
    bool clearLastScanError = false,
  }) {
    return LibraryCatalogState(
      currentSource: currentSource ?? this.currentSource,
      scannedSources: scannedSources ?? this.scannedSources,
      tracks: tracks ?? this.tracks,
      folderAlbums: folderAlbums ?? this.folderAlbums,
      metadataAlbums: metadataAlbums ?? this.metadataAlbums,
      favoriteTrackIds: favoriteTrackIds ?? this.favoriteTrackIds,
      likedTrackIds: likedTrackIds ?? this.likedTrackIds,
      isScanning: isScanning ?? this.isScanning,
      scannedDirectoryCount:
          scannedDirectoryCount ?? this.scannedDirectoryCount,
      discoveredTrackCount: discoveredTrackCount ?? this.discoveredTrackCount,
      lastScanPath: lastScanPath ?? this.lastScanPath,
      lastScanSourceName: lastScanSourceName ?? this.lastScanSourceName,
      lastScanError: clearLastScanError
          ? null
          : lastScanError ?? this.lastScanError,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
    );
  }
}

class _SourceScanResult {
  const _SourceScanResult({
    required this.tracks,
    required this.scannedDirectoryCount,
  });

  final List<LibrarySong> tracks;
  final int scannedDirectoryCount;
}

@Riverpod(keepAlive: true)
class LibraryCatalogController extends _$LibraryCatalogController {
  static const int _embeddedMetadataReadLength = 128 * 1024;
  static const int _embeddedMetadataHydrationConcurrency = 3;
  static const int _embeddedMetadataRefreshBatchSize = 8;

  int _metadataHydrationGeneration = 0;

  @override
  Future<LibraryCatalogState> build() async {
    DebugLogger.info('LibraryCatalogController.build', '开始加载库');
    ref.listen<AsyncValue<LibraryPreferences>>(appSettingsControllerProvider, (
      previous,
      next,
    ) {
      final previousValue = previous?.valueOrNull;
      final nextValue = next.valueOrNull;
      if (previousValue == null || nextValue == null) {
        return;
      }
      if (previousValue.groupMetadataAlbumsByArtist ==
          nextValue.groupMetadataAlbumsByArtist) {
        return;
      }

      final current = state.valueOrNull;
      if (current == null) {
        return;
      }

      state = AsyncData(
        current.copyWith(metadataAlbums: _buildMetadataAlbums(current.tracks)),
      );
    });
    final preferences = await ref
        .watch(libraryPreferencesRepositoryProvider)
        .load();

    // 加载缓存的扫描结果
    LibraryCatalogState cachedState;
    try {
      final cacheRepo = await createScanCacheRepository();
      final allResults = await cacheRepo.loadAllResults();

      DebugLogger.info(
        'LibraryCatalogController.build',
        '加载缓存结果: ${allResults.length} 个源',
      );

      if (allResults.isNotEmpty) {
        var allTracks = <LibrarySong>[];
        for (final source in allResults.entries) {
          DebugLogger.info(
            'LibraryCatalogController.build',
            '源 ${source.key}: ${source.value.length} 首歌曲',
          );
          allTracks.addAll(source.value);
        }
        allTracks.sort(
          (left, right) =>
              left.title.toLowerCase().compareTo(right.title.toLowerCase()),
        );

        DebugLogger.info(
          'LibraryCatalogController.build',
          '总共 ${allTracks.length} 首歌曲，应用刮削数据中...',
        );

        // 应用已缓存的刮削数据到歌曲
        allTracks = _applyCachedScrapingMetadata(allTracks);

        DebugLogger.success(
          'LibraryCatalogController.build',
          '库加载完成：${allTracks.length} 首歌曲',
        );

        cachedState = LibraryCatalogState(
          tracks: allTracks,
          folderAlbums: _buildFolderAlbums(allTracks),
          metadataAlbums: _buildMetadataAlbums(allTracks),
          favoriteTrackIds: preferences.favoriteTrackIds,
          likedTrackIds: preferences.likedTrackIds,
          lastScannedAt: DateTime.now(),
        );
      } else {
        DebugLogger.warning('LibraryCatalogController.build', '缓存中没有扫描结果');
        cachedState = LibraryCatalogState(
          favoriteTrackIds: preferences.favoriteTrackIds,
          likedTrackIds: preferences.likedTrackIds,
        );
      }
    } catch (e) {
      DebugLogger.error('LibraryCatalogController.build', '加载缓存失败', e);
      // 忽略加载失败，使用空状态
      cachedState = LibraryCatalogState(
        favoriteTrackIds: preferences.favoriteTrackIds,
        likedTrackIds: preferences.likedTrackIds,
      );
    }

    return cachedState;
  }

  Future<void> scanActiveSource() async {
    await scanAllSources();
  }

  Future<void> scanAllSources() async {
    DebugLogger.scraping('LibraryCatalogController', '开始扫描所有音乐源');
    final sources = await ref.read(sourcesControllerProvider.future);
    if (sources.isEmpty) {
      DebugLogger.warning('LibraryCatalogController', '没有配置音乐源');
      return;
    }

    DebugLogger.info(
      'LibraryCatalogController',
      '找到 ${sources.length} 个音乐源: ${sources.map((s) => s.name).join(", ")}',
    );

    final current = state.valueOrNull ?? const LibraryCatalogState();
    state = AsyncData(
      current.copyWith(
        currentSource: sources.first,
        scannedSources: sources,
        isScanning: true,
        scannedDirectoryCount: 0,
        discoveredTrackCount: 0,
        lastScanPath: sources.first.effectiveScanDirectories.first,
        lastScanSourceName: sources.first.name,
        clearLastScanError: true,
      ),
    );

    try {
      final discovered = <LibrarySong>[];
      final scanErrors = <String>[];
      var scannedDirectoryCount = 0;

      for (final source in sources) {
        try {
          DebugLogger.info('LibraryCatalogController', '开始扫描源: ${source.name}');
          final result = await _scanSourceTracks(
            source,
            progressOffsetDirectories: scannedDirectoryCount,
            progressOffsetTracks: discovered.length,
            onProgress: (directories, tracks, path) {
              DebugLogger.info(
                'LibraryCatalogController',
                '扫描进度 [${source.name}]: $directories 目录, $tracks 歌曲 - $path',
              );
              state = AsyncData(
                (state.valueOrNull ?? current).copyWith(
                  scannedSources: sources,
                  currentSource: source,
                  isScanning: true,
                  scannedDirectoryCount: directories,
                  discoveredTrackCount: tracks,
                  lastScanPath: path,
                  lastScanSourceName: source.name,
                  lastScanError: scanErrors.isEmpty
                      ? null
                      : scanErrors.join('\n'),
                ),
              );
            },
          );

          discovered.addAll(result.tracks);
          scannedDirectoryCount += result.scannedDirectoryCount;
          DebugLogger.success(
            'LibraryCatalogController',
            '源 ${source.name} 扫描完成: ${result.tracks.length} 首歌曲',
          );
        } on DirectoryReadFailure catch (error) {
          final msg = '${source.name}: ${error.message}';
          scanErrors.add(msg);
          DebugLogger.error('LibraryCatalogController', '目录读取失败', error);
        } catch (error) {
          final msg = '${source.name}: $error';
          scanErrors.add(msg);
          DebugLogger.error('LibraryCatalogController', '扫描异常', error);
        }
      }

      discovered.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );

      DebugLogger.info(
        'LibraryCatalogController',
        '所有源扫描完成，总共 ${discovered.length} 首歌曲',
      );

      // 保存扫描结果到缓存
      try {
        DebugLogger.info(
          'LibraryCatalogController.scanAllSources',
          '开始保存扫描结果到缓存',
        );
        final cacheRepo = await createScanCacheRepository();
        DebugLogger.info('LibraryCatalogController.scanAllSources', '缓存仓库创建成功');
        for (final source in sources) {
          final sourceSongs = discovered
              .where((song) => song.sourceId == source.id)
              .toList();
          if (sourceSongs.isNotEmpty) {
            DebugLogger.info(
              'LibraryCatalogController.scanAllSources',
              '保存源 ${source.name}: ${sourceSongs.length} 首歌曲',
            );
            await cacheRepo.saveScanResults(source.id, sourceSongs);
            DebugLogger.success(
              'LibraryCatalogController.scanAllSources',
              '源 ${source.name}: ${sourceSongs.length} 首歌曲已保存到缓存',
            );
          }
        }
        DebugLogger.success(
          'LibraryCatalogController.scanAllSources',
          '所有扫描结果已保存到缓存',
        );
      } catch (e, stack) {
        DebugLogger.error(
          'LibraryCatalogController.scanAllSources',
          '缓存保存失败',
          e.toString(),
          stack,
        );
      }

      // 在展示前应用已缓存的刮削数据
      final displayTracks = _applyCachedScrapingMetadata(discovered);

      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          scannedSources: sources,
          currentSource: sources.last,
          tracks: displayTracks,
          folderAlbums: _buildFolderAlbums(displayTracks),
          metadataAlbums: _buildMetadataAlbums(displayTracks),
          isScanning: false,
          scannedDirectoryCount: scannedDirectoryCount,
          discoveredTrackCount: displayTracks.length,
          lastScanPath: '/',
          lastScanSourceName: sources.last.name,
          lastScannedAt: DateTime.now(),
          clearLastScanError: scanErrors.isEmpty,
          lastScanError: scanErrors.isEmpty ? null : scanErrors.join('\n'),
        ),
      );
      unawaited(_hydrateEmbeddedMetadataInBackground(sources, discovered));
    } catch (error) {
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          scannedSources: sources,
          currentSource: sources.last,
          isScanning: false,
          lastScanError: error.toString(),
        ),
      );
    }
  }

  Future<void> rescanSource(String sourceId) async {
    final allSources = await ref.read(sourcesControllerProvider.future);
    final source = allSources.firstWhere((item) => item.id == sourceId);
    final current = state.valueOrNull ?? const LibraryCatalogState();
    final retained = current.tracks
        .where((track) => track.sourceId != sourceId)
        .toList(growable: true);

    state = AsyncData(
      current.copyWith(
        scannedSources: allSources,
        currentSource: source,
        isScanning: true,
        scannedDirectoryCount: 0,
        discoveredTrackCount: retained.length,
        lastScanPath: source.effectiveScanDirectories.first,
        lastScanSourceName: source.name,
        clearLastScanError: true,
      ),
    );

    try {
      final result = await _scanSourceTracks(
        source,
        progressOffsetDirectories: 0,
        progressOffsetTracks: retained.length,
        onProgress: (directories, tracks, path) {
          state = AsyncData(
            (state.valueOrNull ?? current).copyWith(
              scannedSources: allSources,
              currentSource: source,
              isScanning: true,
              scannedDirectoryCount: directories,
              discoveredTrackCount: tracks,
              lastScanPath: path,
              lastScanSourceName: source.name,
            ),
          );
        },
      );

      retained.addAll(result.tracks);
      retained.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );

      // 保存扫描结果到缓存
      try {
        final cacheRepo = await createScanCacheRepository();
        await cacheRepo.saveScanResults(source.id, retained);
      } catch (e) {
        // 忽略保存失败
      }

      // 应用已缓存的刮削数据
      final displayTracks = _applyCachedScrapingMetadata(retained);

      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          scannedSources: allSources,
          currentSource: source,
          tracks: displayTracks,
          folderAlbums: _buildFolderAlbums(displayTracks),
          metadataAlbums: _buildMetadataAlbums(displayTracks),
          isScanning: false,
          scannedDirectoryCount: result.scannedDirectoryCount,
          discoveredTrackCount: displayTracks.length,
          lastScanPath: source.effectiveScanDirectories.first,
          lastScanSourceName: source.name,
          lastScannedAt: DateTime.now(),
          clearLastScanError: true,
        ),
      );
      unawaited(_hydrateEmbeddedMetadataInBackground([source], result.tracks));
    } on DirectoryReadFailure catch (error) {
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          scannedSources: allSources,
          currentSource: source,
          isScanning: false,
          lastScanError: error.message,
        ),
      );
    } catch (error) {
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          scannedSources: allSources,
          currentSource: source,
          isScanning: false,
          lastScanError: error.toString(),
        ),
      );
    }
  }

  Future<void> toggleFavorite(String trackId) async {
    final current = state.valueOrNull ?? const LibraryCatalogState();
    final updated = {...current.favoriteTrackIds};
    if (updated.contains(trackId)) {
      updated.remove(trackId);
    } else {
      updated.add(trackId);
    }
    await _savePreferences(current.copyWith(favoriteTrackIds: updated));
  }

  Future<void> toggleLiked(String trackId) async {
    final current = state.valueOrNull ?? const LibraryCatalogState();
    final updated = {...current.likedTrackIds};
    if (updated.contains(trackId)) {
      updated.remove(trackId);
    } else {
      updated.add(trackId);
    }
    await _savePreferences(current.copyWith(likedTrackIds: updated));
  }

  Future<void> _savePreferences(LibraryCatalogState nextState) async {
    state = AsyncData(nextState);
    final repository = ref.read(libraryPreferencesRepositoryProvider);
    final currentPreferences = await repository.load();
    await repository.save(
      currentPreferences.copyWith(
        favoriteTrackIds: nextState.favoriteTrackIds,
        likedTrackIds: nextState.likedTrackIds,
      ),
    );
  }

  Future<_SourceScanResult> _scanSourceTracks(
    SourceProfile source, {
    required int progressOffsetDirectories,
    required int progressOffsetTracks,
    required void Function(int directories, int tracks, String path) onProgress,
  }) async {
    final session = await ref
        .read(musicSourceSessionManagerProvider)
        .get(source);
    final queue = Queue<String>()..addAll(source.effectiveScanDirectories);
    final visited = <String>{};
    final excludedDirectories = source.effectiveExcludedScanDirectories;
    final discovered = <LibrarySong>[];
    var scannedDirectoryCount = 0;

    while (queue.isNotEmpty) {
      final path = _normalizeDirectoryPath(queue.removeFirst());
      if (!visited.add(path) || _isExcludedPath(path, excludedDirectories)) {
        continue;
      }

      final listing = await session.listFiles(path);
      scannedDirectoryCount++;

      for (final entry in listing.entries) {
        if (entry.isDirectory) {
          final directoryPath = _normalizeDirectoryPath(entry.path);
          if (_isExcludedPath(directoryPath, excludedDirectories)) {
            continue;
          }
          queue.add(directoryPath);
          continue;
        }

        if (!entry.isPlayable ||
            _isExcludedPath(entry.path, excludedDirectories)) {
          continue;
        }

        discovered.add(await _mapSong(source, entry, session: session));
      }

      if (scannedDirectoryCount % 4 == 0) {
        onProgress(
          progressOffsetDirectories + scannedDirectoryCount,
          progressOffsetTracks + discovered.length,
          path,
        );
      }
    }

    return _SourceScanResult(
      tracks: discovered,
      scannedDirectoryCount: scannedDirectoryCount,
    );
  }

  Future<LibrarySong> _mapSong(
    SourceProfile source,
    RemoteEntry entry, {
    required MusicSource session,
  }) async {
    final directory = p.posix.dirname(entry.path);
    final folderSegments = directory
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();
    final folderAlbumTitle = folderSegments.isEmpty
        ? source.name
        : folderSegments.last;
    final folderArtistName = folderSegments.length >= 2
        ? folderSegments[folderSegments.length - 2]
        : source.name;

    // 从数据库中查找是否有此歌曲的刮削数据
    final scrapingMetadata = IsarManager.getMetadata(entry.uniqueId);

    // 应用刮削数据（如果存在）
    String? manuallyScrapedCoverUrl;
    String? manuallyScrapedLocalCoverPath;
    String? manuallyScrapedLyrics;
    String? autoScrapedCoverUrl;
    String? autoScrapedLocalCoverPath;
    String? autoScrapedLyrics;

    if (scrapingMetadata != null && _hasSavedScrapingData(scrapingMetadata)) {
      DebugLogger.success(
        'LibraryCatalogController._mapSong',
        '应用刮削数据到歌曲: ${entry.name}',
      );
      manuallyScrapedCoverUrl = scrapingMetadata.manuallyScrapedCoverUrl;
      manuallyScrapedLocalCoverPath =
          scrapingMetadata.manuallyScrapedLocalCoverPath;
      manuallyScrapedLyrics = scrapingMetadata.manuallyScrapedLyrics;
      autoScrapedCoverUrl = scrapingMetadata.autoScrapedCoverUrl;
      autoScrapedLocalCoverPath = scrapingMetadata.autoScrapedLocalCoverPath;
      autoScrapedLyrics = scrapingMetadata.autoScrapedLyrics;
    } else {
      DebugLogger.scraping(
        'LibraryCatalogController._mapSong',
        '创建歌曲: ${entry.name}（标签将在后台异步读取）',
      );
    }

    return LibrarySong(
      id: entry.uniqueId,
      sourceId: source.id,
      sourceName: source.name,
      title: entry.title,
      fileName: entry.name,
      remotePath: entry.path,
      albumTitle: folderAlbumTitle,
      artistName: folderArtistName,
      directoryPath: directory,
      folderAlbumTitle: folderAlbumTitle,
      folderArtistName: folderArtistName,
      scrapedAlbumTitle: null,
      scrapedArtistName: null,
      mimeType: entry.mimeType,
      size: entry.size,
      modifiedAt: entry.modifiedAt,
      manuallyScrapedTitle: scrapingMetadata?.manuallyScrapedTitle,
      manuallyScrapedArtist: scrapingMetadata?.manuallyScrapedArtist,
      manuallyScrapedAlbum: scrapingMetadata?.manuallyScrapedAlbum,
      manuallyScrapedCoverUrl: manuallyScrapedCoverUrl,
      manuallyScrapedLocalCoverPath: manuallyScrapedLocalCoverPath,
      manuallyScrapedLyrics: manuallyScrapedLyrics,
      autoScrapedTitle: scrapingMetadata?.autoScrapedTitle,
      autoScrapedArtist: scrapingMetadata?.autoScrapedArtist,
      autoScrapedAlbum: scrapingMetadata?.autoScrapedAlbum,
      autoScrapedCoverUrl: autoScrapedCoverUrl,
      autoScrapedLocalCoverPath: autoScrapedLocalCoverPath,
      autoScrapedLyrics: autoScrapedLyrics,
    );
  }

  /// 对歌曲列表应用已缓存的刮削数据（app 初始化或扫描时调用）
  List<LibrarySong> _applyCachedScrapingMetadata(List<LibrarySong> tracks) {
    var appliedCount = 0;
    final result = tracks.map((track) {
      final cachedMetadata = IsarManager.getMetadata(track.id);
      if (cachedMetadata != null && _hasSavedScrapingData(cachedMetadata)) {
        appliedCount++;
        return _mergeCachedMetadataIntoSong(track, cachedMetadata);
      }
      return track;
    }).toList();

    if (appliedCount > 0) {
      DebugLogger.success(
        'LibraryCatalogController._applyCachedScrapingMetadata',
        '已应用 $appliedCount 个刮削缓存',
      );
    }
    return result;
  }

  List<LibraryAlbum> _buildFolderAlbums(List<LibrarySong> tracks) {
    final grouped = <String, List<LibrarySong>>{};
    for (final track in tracks) {
      final key = '${track.sourceId}::${track.directoryPath.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(track);
    }
    return _toAlbums(
      grouped,
      titleOf: (track) => track.folderAlbumTitle,
      artistOf: (track) => track.folderArtistName,
    );
  }

  List<LibraryAlbum> _buildMetadataAlbums(List<LibrarySong> tracks) {
    final grouped = <String, List<LibrarySong>>{};
    final groupByArtist =
        ref
            .read(appSettingsControllerProvider)
            .valueOrNull
            ?.groupMetadataAlbumsByArtist ??
        false;
    for (final track in tracks) {
      final key = groupByArtist
          ? '${track.sourceId}::${track.metadataArtistName.toLowerCase()}::${track.metadataAlbumTitle.toLowerCase()}'
          : '${track.sourceId}::${track.metadataAlbumTitle.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(track);
    }
    return _toAlbums(
      grouped,
      titleOf: (track) => track.metadataAlbumTitle,
      artistOf: (track) => track.metadataArtistName,
    );
  }

  Future<EmbeddedAudioMetadata?> _readEmbeddedMetadata(
    MusicSource session,
    RemoteEntry entry,
  ) async {
    try {
      final bytes = await session.readBinaryFileHead(
        entry.path,
        length: _embeddedMetadataReadLength,
      );
      if (bytes == null || bytes.isEmpty) {
        return null;
      }
      return AudioEmbeddedMetadataReader.parse(bytes, fileName: entry.name);
    } catch (e, stack) {
      DebugLogger.error(
        'LibraryCatalogController._readEmbeddedMetadata',
        '读取标签失败: ${entry.path}',
        e.toString(),
        stack,
      );
      return null;
    }
  }

  List<LibraryAlbum> _toAlbums(
    Map<String, List<LibrarySong>> grouped, {
    required String Function(LibrarySong track) titleOf,
    required String Function(LibrarySong track) artistOf,
  }) {
    final albums =
        grouped.entries
            .map(
              (entry) => LibraryAlbum(
                id: entry.key,
                title: titleOf(entry.value.first),
                artistName: artistOf(entry.value.first),
                sourceId: entry.value.first.sourceId,
                sourceName: entry.value.first.sourceName,
                tracks: [...entry.value]
                  ..sort(
                    (left, right) => left.title.toLowerCase().compareTo(
                      right.title.toLowerCase(),
                    ),
                  ),
              ),
            )
            .toList()
          ..sort(
            (left, right) =>
                left.title.toLowerCase().compareTo(right.title.toLowerCase()),
          );

    return albums;
  }

  /// 刷新单个歌曲的元数据（用于刮削完成后的增量更新，避免全列表重新加载）
  void refreshSongMetadata(String songId) {
    DebugLogger.info(
      'LibraryCatalogController.refreshSongMetadata',
      '开始刷新歌曲元数据: $songId',
    );
    try {
      final currentState = state.valueOrNull;
      DebugLogger.info(
        'LibraryCatalogController.refreshSongMetadata',
        '当前状态是否为空: ${currentState == null}',
      );
      if (currentState == null) {
        DebugLogger.warning(
          'LibraryCatalogController.refreshSongMetadata',
          '⚠️ 当前状态为空，无法更新库列表（但会被缓存到数据库）',
        );
        return;
      }

      final cachedMetadata = IsarManager.getMetadata(songId);
      DebugLogger.info(
        'LibraryCatalogController.refreshSongMetadata',
        '查询缓存元数据: 找到=${cachedMetadata != null}',
      );
      if (cachedMetadata != null) {
        DebugLogger.info(
          'LibraryCatalogController.refreshSongMetadata',
          '元数据状态: ${cachedMetadata.status}, 是否有可展示字段: ${_hasSavedScrapingData(cachedMetadata)}',
        );
      }

      if (cachedMetadata == null || !_hasSavedScrapingData(cachedMetadata)) {
        DebugLogger.warning(
          'LibraryCatalogController.refreshSongMetadata',
          '缓存元数据不存在或暂无可展示字段',
        );
        return;
      }

      // 仅更新该歌曲，不重新加载整个列表
      final updatedTracks = currentState.tracks.map((track) {
        if (track.id != songId) {
          return track;
        }
        DebugLogger.info(
          'LibraryCatalogController.refreshSongMetadata',
          '找到要更新的歌曲: ${track.title} -> ${cachedMetadata.autoScrapedTitle}',
        );
        return _mergeCachedMetadataIntoSong(track, cachedMetadata);
      }).toList();

      DebugLogger.success(
        'LibraryCatalogController.refreshSongMetadata',
        '构建新状态并触发 UI 更新',
      );

      state = AsyncData(
        currentState.copyWith(
          tracks: updatedTracks,
          folderAlbums: _buildFolderAlbums(updatedTracks),
          metadataAlbums: _buildMetadataAlbums(updatedTracks),
        ),
      );

      DebugLogger.success(
        'LibraryCatalogController.refreshSongMetadata',
        '✅ 已刷新单个歌曲的元数据显示: $songId',
      );
    } catch (e, stack) {
      DebugLogger.error(
        'LibraryCatalogController.refreshSongMetadata',
        '刷新歌曲元数据失败: $e',
        stack.toString(),
      );
    }
  }

  void refreshSongsMetadata(Iterable<String> songIds) {
    final targetIds = songIds.toSet();
    if (targetIds.isEmpty) {
      return;
    }

    final currentState = state.valueOrNull;
    if (currentState == null) {
      return;
    }

    var changed = false;
    final updatedTracks = currentState.tracks
        .map((track) {
          if (!targetIds.contains(track.id)) {
            return track;
          }
          final cachedMetadata = IsarManager.getMetadata(track.id);
          if (cachedMetadata == null ||
              !_hasSavedScrapingData(cachedMetadata)) {
            return track;
          }
          changed = true;
          return _mergeCachedMetadataIntoSong(track, cachedMetadata);
        })
        .toList(growable: false);

    if (!changed) {
      return;
    }

    state = AsyncData(
      currentState.copyWith(
        tracks: updatedTracks,
        folderAlbums: _buildFolderAlbums(updatedTracks),
        metadataAlbums: _buildMetadataAlbums(updatedTracks),
      ),
    );
  }

  Future<void> _hydrateEmbeddedMetadataInBackground(
    List<SourceProfile> sources,
    List<LibrarySong> tracks,
  ) async {
    final generation = ++_metadataHydrationGeneration;
    final sourceById = {for (final source in sources) source.id: source};
    final queue = Queue<LibrarySong>()
      ..addAll(tracks.where(_shouldHydrateEmbeddedMetadata));
    if (queue.isEmpty) {
      return;
    }

    final sessions = <String, MusicSource>{};
    final updatedSongIds = <String>{};
    final workerCount = queue.length < _embeddedMetadataHydrationConcurrency
        ? queue.length
        : _embeddedMetadataHydrationConcurrency;

    Future<void> flushUpdates() async {
      if (updatedSongIds.isEmpty ||
          generation != _metadataHydrationGeneration) {
        return;
      }
      refreshSongsMetadata(updatedSongIds.toList(growable: false));
      updatedSongIds.clear();
    }

    Future<void> worker() async {
      while (generation == _metadataHydrationGeneration) {
        if (queue.isEmpty) {
          return;
        }
        final track = queue.removeFirst();
        final source = sourceById[track.sourceId];
        if (source == null) {
          continue;
        }

        try {
          final session = sessions[source.id] ??= await ref
              .read(musicSourceSessionManagerProvider)
              .get(source);
          final metadata = await _readEmbeddedMetadata(
            session,
            track.toRemoteEntry(),
          );
          if (generation != _metadataHydrationGeneration) {
            continue;
          }
          if (metadata == null) {
            await _markEmbeddedMetadataAttempted(track);
            continue;
          }

          final changed = await _persistEmbeddedMetadata(track, metadata);
          if (!changed) {
            continue;
          }

          updatedSongIds.add(track.id);
          if (updatedSongIds.length >= _embeddedMetadataRefreshBatchSize) {
            await flushUpdates();
          }
        } catch (e, stack) {
          DebugLogger.error(
            'LibraryCatalogController._hydrateEmbeddedMetadataInBackground',
            '后台读取标签失败: ${track.remotePath}',
            e.toString(),
            stack,
          );
        }
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    await flushUpdates();
  }

  bool _shouldHydrateEmbeddedMetadata(LibrarySong track) {
    final cachedMetadata = IsarManager.getMetadata(track.id);
    if (cachedMetadata == null) {
      return true;
    }
    return cachedMetadata.embeddedMetadataReadAt == null;
  }

  Future<void> _markEmbeddedMetadataAttempted(LibrarySong track) async {
    final existing =
        IsarManager.getMetadata(track.id) ??
        ScrapingMetadata(
          id: track.id,
          sourceId: track.sourceId,
          filePath: track.remotePath,
          filenameWithoutExt: p.posix.basenameWithoutExtension(track.fileName),
          originalFileName: track.fileName,
          originalArtist: track.artistName,
        );
    if (existing.embeddedMetadataReadAt != null) {
      return;
    }
    existing.embeddedMetadataReadAt = DateTime.now();
    existing.updatedAt = DateTime.now();
    existing.lastAttemptAt = existing.embeddedMetadataReadAt;
    await IsarManager.saveMetadata(existing);
  }

  Future<bool> _persistEmbeddedMetadata(
    LibrarySong track,
    EmbeddedAudioMetadata metadata,
  ) async {
    final existing =
        IsarManager.getMetadata(track.id) ??
        ScrapingMetadata(
          id: track.id,
          sourceId: track.sourceId,
          filePath: track.remotePath,
          filenameWithoutExt: p.posix.basenameWithoutExtension(track.fileName),
          originalFileName: track.fileName,
          originalArtist: track.artistName,
        );

    var changed = false;

    void updateText(
      String? value,
      String? current,
      void Function(String value) assign,
    ) {
      final trimmed = value?.trim();
      if (trimmed?.isNotEmpty != true || current == trimmed) {
        return;
      }
      assign(trimmed!);
      changed = true;
    }

    void updateInt(int? value, int? current, void Function(int value) assign) {
      if (value == null || current == value) {
        return;
      }
      assign(value);
      changed = true;
    }

    updateText(
      metadata.title,
      existing.autoScrapedTitle,
      (value) => existing.autoScrapedTitle = value,
    );
    updateText(
      metadata.artist,
      existing.autoScrapedArtist,
      (value) => existing.autoScrapedArtist = value,
    );
    updateText(
      metadata.album,
      existing.autoScrapedAlbum,
      (value) => existing.autoScrapedAlbum = value,
    );
    updateText(
      metadata.albumArtist,
      existing.autoScrapedAlbumArtist,
      (value) => existing.autoScrapedAlbumArtist = value,
    );
    updateText(
      metadata.genre,
      existing.autoScrapedGenre,
      (value) => existing.autoScrapedGenre = value,
    );
    updateText(
      metadata.year,
      existing.autoScrapedYear,
      (value) => existing.autoScrapedYear = value,
    );
    updateText(
      metadata.composer,
      existing.autoScrapedComposer,
      (value) => existing.autoScrapedComposer = value,
    );
    updateText(
      metadata.comment,
      existing.autoScrapedComment,
      (value) => existing.autoScrapedComment = value,
    );
    updateText(metadata.lyrics, existing.autoScrapedLyrics, (value) {
      existing.autoScrapedLyrics = value;
      existing.autoScrapedLyricsSource = 'embedded';
    });
    if (metadata.lyrics?.trim().isNotEmpty == true &&
        existing.autoScrapedLyricsSource != 'embedded') {
      existing.autoScrapedLyricsSource = 'embedded';
      changed = true;
    }
    updateInt(
      metadata.trackNumber,
      existing.autoScrapedTrackNumber,
      (value) => existing.autoScrapedTrackNumber = value,
    );
    updateInt(
      metadata.trackTotal,
      existing.autoScrapedTrackTotal,
      (value) => existing.autoScrapedTrackTotal = value,
    );
    updateInt(
      metadata.discNumber,
      existing.autoScrapedDiscNumber,
      (value) => existing.autoScrapedDiscNumber = value,
    );
    updateInt(
      metadata.discTotal,
      existing.autoScrapedDiscTotal,
      (value) => existing.autoScrapedDiscTotal = value,
    );

    if (metadata.hasCover) {
      final localCoverPath = await CoverArtCacheManager().cacheBytes(
        'embedded_cover_${track.id}',
        metadata.coverBytes!,
        extension: metadata.coverExtension ?? '.jpg',
      );
      if (localCoverPath?.trim().isNotEmpty == true &&
          existing.autoScrapedLocalCoverPath != localCoverPath) {
        existing.autoScrapedLocalCoverPath = localCoverPath;
        existing.autoScrapedCoverSource = 'embedded';
        changed = true;
      }
      if (existing.autoScrapedCoverSource != 'embedded') {
        existing.autoScrapedCoverSource = 'embedded';
        changed = true;
      }
    }

    if (!changed) {
      return false;
    }

    existing.autoScrapedAt = DateTime.now();
    existing.embeddedMetadataReadAt = DateTime.now();
    existing.updatedAt = DateTime.now();
    existing.lastAttemptAt = DateTime.now();
    if (!_needsAdditionalAutoScrape(existing)) {
      existing.status = ScrapingStatus.completed;
    }
    await IsarManager.saveMetadata(existing);
    return true;
  }

  LibrarySong _mergeCachedMetadataIntoSong(
    LibrarySong track,
    ScrapingMetadata metadata,
  ) {
    return LibrarySong(
      id: track.id,
      sourceId: track.sourceId,
      sourceName: track.sourceName,
      title: track.title,
      fileName: track.fileName,
      remotePath: track.remotePath,
      albumTitle: track.albumTitle,
      artistName: track.artistName,
      directoryPath: track.directoryPath,
      folderAlbumTitle: track.folderAlbumTitle,
      folderArtistName: track.folderArtistName,
      scrapedAlbumTitle: track.scrapedAlbumTitle,
      scrapedArtistName: track.scrapedArtistName,
      mimeType: track.mimeType,
      size: track.size,
      modifiedAt: track.modifiedAt,
      manuallyScrapedTitle:
          metadata.manuallyScrapedTitle ?? track.manuallyScrapedTitle,
      manuallyScrapedArtist:
          metadata.manuallyScrapedArtist ?? track.manuallyScrapedArtist,
      manuallyScrapedAlbum:
          metadata.manuallyScrapedAlbum ?? track.manuallyScrapedAlbum,
      manuallyScrapedCoverUrl:
          metadata.manuallyScrapedCoverUrl ?? track.manuallyScrapedCoverUrl,
      manuallyScrapedLocalCoverPath:
          metadata.manuallyScrapedLocalCoverPath ??
          track.manuallyScrapedLocalCoverPath,
      manuallyScrapedLyrics:
          metadata.manuallyScrapedLyrics ?? track.manuallyScrapedLyrics,
      autoScrapedTitle: metadata.autoScrapedTitle ?? track.autoScrapedTitle,
      autoScrapedArtist: metadata.autoScrapedArtist ?? track.autoScrapedArtist,
      autoScrapedAlbum: metadata.autoScrapedAlbum ?? track.autoScrapedAlbum,
      autoScrapedCoverUrl:
          metadata.autoScrapedCoverUrl ?? track.autoScrapedCoverUrl,
      autoScrapedLocalCoverPath:
          metadata.autoScrapedLocalCoverPath ?? track.autoScrapedLocalCoverPath,
      autoScrapedLyrics: metadata.autoScrapedLyrics ?? track.autoScrapedLyrics,
    );
  }

  bool _needsAdditionalAutoScrape(ScrapingMetadata metadata) {
    final preferences = ref.read(appSettingsControllerProvider).valueOrNull;
    final needsLyrics = preferences?.enableLyricsScraping ?? false;
    final hasLyrics =
        metadata.manuallyScrapedLyrics?.trim().isNotEmpty == true ||
        metadata.autoScrapedLyrics?.trim().isNotEmpty == true;
    return needsLyrics && !hasLyrics;
  }

  String _normalizeDirectoryPath(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) {
      return '/';
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return normalized;
  }

  bool _hasSavedScrapingData(ScrapingMetadata metadata) {
    bool hasText(String? value) => value?.trim().isNotEmpty == true;
    return hasText(metadata.manuallyScrapedTitle) ||
        hasText(metadata.manuallyScrapedArtist) ||
        hasText(metadata.manuallyScrapedAlbum) ||
        hasText(metadata.manuallyScrapedCoverUrl) ||
        hasText(metadata.manuallyScrapedLocalCoverPath) ||
        hasText(metadata.manuallyScrapedLyrics) ||
        hasText(metadata.autoScrapedTitle) ||
        hasText(metadata.autoScrapedArtist) ||
        hasText(metadata.autoScrapedAlbum) ||
        hasText(metadata.autoScrapedAlbumArtist) ||
        hasText(metadata.autoScrapedGenre) ||
        hasText(metadata.autoScrapedYear) ||
        hasText(metadata.autoScrapedComposer) ||
        hasText(metadata.autoScrapedComment) ||
        hasText(metadata.autoScrapedCoverUrl) ||
        hasText(metadata.autoScrapedLocalCoverPath) ||
        hasText(metadata.autoScrapedLyrics) ||
        metadata.autoScrapedTrackNumber != null ||
        metadata.autoScrapedTrackTotal != null ||
        metadata.autoScrapedDiscNumber != null ||
        metadata.autoScrapedDiscTotal != null;
  }

  bool _isExcludedPath(String path, List<String> excludedDirectories) {
    var normalized = path.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    for (final directory in excludedDirectories) {
      if (normalized == directory || normalized.startsWith(directory)) {
        return true;
      }
    }
    return false;
  }
}
