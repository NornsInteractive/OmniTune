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
import '../../../core/models/source_protocol.dart';
import '../../../core/storage/cover_art_cache_manager.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../../core/utils/audio_embedded_metadata_reader.dart';
import '../../../core/utils/debug_logger.dart';
import '../../settings/application/app_settings_controller.dart';
import '../../sources/application/source_session_manager.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/domain/music_source.dart';

export '../../../core/models/library_album.dart' show LibraryAlbumGroupingMode;

part 'library_catalog_controller.g.dart';

class LibraryCatalogState {
  const LibraryCatalogState({
    this.currentSource,
    this.scannedSources = const [],
    this.tracks = const [],
    this.folderAlbums = const [],
    this.metadataAlbums = const [],
    this.folderAlbumsBySource = const {},
    this.metadataAlbumsBySource = const {},
    this.trackCountBySource = const {},
    this.favoriteTrackIds = const <String>{},
    this.likedTrackIds = const <String>{},
    this.isScanning = false,
    this.isScanCancelled = false,
    this.failedSourceIds = const [],
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
  final Map<String, List<LibraryAlbum>> folderAlbumsBySource;
  final Map<String, List<LibraryAlbum>> metadataAlbumsBySource;
  final Map<String, int> trackCountBySource;
  final Set<String> favoriteTrackIds;
  final Set<String> likedTrackIds;
  final bool isScanning;
  final bool isScanCancelled;
  final List<String> failedSourceIds;
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
    final indexedAlbums = switch (mode) {
      LibraryAlbumGroupingMode.folder => folderAlbumsBySource[sourceId],
      LibraryAlbumGroupingMode.metadata => metadataAlbumsBySource[sourceId],
    };
    if (indexedAlbums != null) {
      return indexedAlbums;
    }

    return sourceAlbums
        .where((album) => album.sourceId == sourceId)
        .toList(growable: false);
  }

  int albumCountForSource(String sourceId, LibraryAlbumGroupingMode mode) {
    final indexedAlbums = switch (mode) {
      LibraryAlbumGroupingMode.folder => folderAlbumsBySource[sourceId],
      LibraryAlbumGroupingMode.metadata => metadataAlbumsBySource[sourceId],
    };
    return indexedAlbums?.length ?? albumsForSource(sourceId, mode).length;
  }

  int trackCountForSource(String sourceId) {
    return trackCountBySource[sourceId] ??
        tracks.where((track) => track.sourceId == sourceId).length;
  }

  LibraryCatalogState copyWith({
    SourceProfile? currentSource,
    List<SourceProfile>? scannedSources,
    List<LibrarySong>? tracks,
    List<LibraryAlbum>? folderAlbums,
    List<LibraryAlbum>? metadataAlbums,
    Map<String, List<LibraryAlbum>>? folderAlbumsBySource,
    Map<String, List<LibraryAlbum>>? metadataAlbumsBySource,
    Map<String, int>? trackCountBySource,
    Set<String>? favoriteTrackIds,
    Set<String>? likedTrackIds,
    bool? isScanning,
    bool? isScanCancelled,
    List<String>? failedSourceIds,
    int? scannedDirectoryCount,
    int? discoveredTrackCount,
    String? lastScanPath,
    String? lastScanSourceName,
    String? lastScanError,
    DateTime? lastScannedAt,
    bool clearLastScanError = false,
  }) {
    final nextTracks = tracks ?? this.tracks;
    final nextFolderAlbums = folderAlbums ?? this.folderAlbums;
    final nextMetadataAlbums = metadataAlbums ?? this.metadataAlbums;
    return LibraryCatalogState(
      currentSource: currentSource ?? this.currentSource,
      scannedSources: scannedSources ?? this.scannedSources,
      tracks: nextTracks,
      folderAlbums: nextFolderAlbums,
      metadataAlbums: nextMetadataAlbums,
      folderAlbumsBySource:
          folderAlbumsBySource ??
          (folderAlbums == null
              ? this.folderAlbumsBySource
              : _albumsBySource(nextFolderAlbums)),
      metadataAlbumsBySource:
          metadataAlbumsBySource ??
          (metadataAlbums == null
              ? this.metadataAlbumsBySource
              : _albumsBySource(nextMetadataAlbums)),
      trackCountBySource:
          trackCountBySource ??
          (tracks == null
              ? this.trackCountBySource
              : _trackCountBySource(nextTracks)),
      favoriteTrackIds: favoriteTrackIds ?? this.favoriteTrackIds,
      likedTrackIds: likedTrackIds ?? this.likedTrackIds,
      isScanning: isScanning ?? this.isScanning,
      isScanCancelled: isScanCancelled ?? this.isScanCancelled,
      failedSourceIds: failedSourceIds ?? this.failedSourceIds,
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

  static Map<String, List<LibraryAlbum>> _albumsBySource(
    List<LibraryAlbum> albums,
  ) {
    final grouped = <String, List<LibraryAlbum>>{};
    for (final album in albums) {
      grouped.putIfAbsent(album.sourceId, () => <LibraryAlbum>[]).add(album);
    }
    return Map.unmodifiable({
      for (final entry in grouped.entries)
        entry.key: List<LibraryAlbum>.unmodifiable(entry.value),
    });
  }

  static Map<String, int> _trackCountBySource(List<LibrarySong> tracks) {
    final counts = <String, int>{};
    for (final track in tracks) {
      counts.update(track.sourceId, (value) => value + 1, ifAbsent: () => 1);
    }
    return Map.unmodifiable(counts);
  }
}

class _ScanCancelled implements Exception {}

class _SourceScanResult {
  const _SourceScanResult({
    required this.tracks,
    required this.scannedDirectoryCount,
  });

  final List<LibrarySong> tracks;
  final int scannedDirectoryCount;
}

class _IncrementalTrackPublisher {
  _IncrementalTrackPublisher({
    required List<LibrarySong> initialTracks,
    required int batchSize,
    required Duration interval,
    required void Function(List<LibrarySong> tracks) onPublish,
  }) : _publishedTracks = List<LibrarySong>.of(initialTracks),
       _batchSize = batchSize,
       _interval = interval,
       _onPublish = onPublish;

  final List<LibrarySong> _publishedTracks;
  final List<LibrarySong> _pendingTracks = [];
  final int _batchSize;
  final Duration _interval;
  final void Function(List<LibrarySong> tracks) _onPublish;
  Timer? _timer;
  DateTime _lastPublishedAt = DateTime.fromMillisecondsSinceEpoch(0);

  void add(LibrarySong track) {
    _pendingTracks.add(track);
    final now = DateTime.now();
    if (_pendingTracks.length >= _batchSize ||
        now.difference(_lastPublishedAt) >= _interval) {
      flush();
      return;
    }
    _timer ??= Timer(_interval, flush);
  }

  void flush() {
    if (_pendingTracks.isEmpty) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    _timer?.cancel();
    _timer = null;
    _publishedTracks.addAll(_pendingTracks);
    _pendingTracks.clear();
    _lastPublishedAt = DateTime.now();
    _onPublish(List<LibrarySong>.of(_publishedTracks, growable: false));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

@Riverpod(keepAlive: true)
class LibraryCatalogController extends _$LibraryCatalogController {
  static const int _embeddedMetadataReadLength = 128 * 1024;
  static const int _embeddedMetadataHydrationConcurrency = 3;
  static const int _embeddedMetadataRefreshBatchSize = 8;
  static const int _scanTrackPublishBatchSize = 12;
  static const int _libraryProcessingYieldBatchSize = 64;
  static const Duration _scanTrackPublishInterval = Duration(milliseconds: 250);

  int _metadataHydrationGeneration = 0;
  int _albumIndexGeneration = 0;
  bool _scanRunning = false;
  bool _scanCancelled = false;

  @override
  Future<LibraryCatalogState> build() async {
    ref.onDispose(() => _albumIndexGeneration++);
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

      _refreshAlbumIndexesFromCurrentTracks();
    });
    final preferences = await ref
        .watch(libraryPreferencesRepositoryProvider)
        .load();
    final sourceIds = (await ref.read(
      sourcesControllerProvider.future,
    )).map((source) => source.id).toSet();

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
          if (!sourceIds.contains(source.key)) continue;
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
        allTracks = await _applyCachedScrapingMetadataAsync(allTracks);

        DebugLogger.success(
          'LibraryCatalogController.build',
          '库加载完成：${allTracks.length} 首歌曲',
        );

        final folderAlbums = await _buildFolderAlbumsAsync(allTracks);
        final metadataAlbums = await _buildMetadataAlbumsAsync(allTracks);

        cachedState = LibraryCatalogState(
          tracks: allTracks,
          folderAlbums: folderAlbums,
          metadataAlbums: metadataAlbums,
          folderAlbumsBySource: LibraryCatalogState._albumsBySource(
            folderAlbums,
          ),
          metadataAlbumsBySource: LibraryCatalogState._albumsBySource(
            metadataAlbums,
          ),
          trackCountBySource: LibraryCatalogState._trackCountBySource(
            allTracks,
          ),
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

  Future<void> scanAllSources() => _scanSources();

  Future<void> rescanSource(String sourceId) =>
      _scanSources(sourceIds: {sourceId});

  void cancelScan() {
    if (!_scanRunning) return;
    _scanCancelled = true;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(isScanCancelled: true));
    }
  }

  Future<void> retryFailedSources() async {
    final ids = state.valueOrNull?.failedSourceIds.toSet() ?? <String>{};
    if (ids.isNotEmpty) await _scanSources(sourceIds: ids);
  }

  Future<void> _scanSources({Set<String>? sourceIds}) async {
    if (_scanRunning) return;
    _scanRunning = true;
    _scanCancelled = false;
    _metadataHydrationGeneration++;
    _IncrementalTrackPublisher? publisher;
    try {
      // Preserve cached tracks even when a scan starts during initial loading.
      await future;
      final allSources = await ref.read(sourcesControllerProvider.future);
      final sources = allSources
          .where((s) => sourceIds == null || sourceIds.contains(s.id))
          .toList();
      if (sources.isEmpty) return;
      final current = state.valueOrNull ?? const LibraryCatalogState();
      // Keep prior tracks until a source has completed successfully.
      final tracksById = {for (final song in current.tracks) song.id: song};
      final failures = current.failedSourceIds.toSet();
      final errors = <String>[];
      var directoryCount = 0;
      var discoveredCount = 0;
      var activeSource = sources.first;
      var activePath = activeSource.effectiveScanDirectories.first;
      state = AsyncData(
        current.copyWith(
          isScanning: true,
          isScanCancelled: false,
          scannedSources: allSources,
          scannedDirectoryCount: 0,
          discoveredTrackCount: 0,
          lastScanSourceName: activeSource.name,
          lastScanPath: activePath,
          clearLastScanError: true,
        ),
      );
      publisher = _IncrementalTrackPublisher(
        initialTracks: const [],
        batchSize: _scanTrackPublishBatchSize,
        interval: _scanTrackPublishInterval,
        onPublish: (_) {
          state = AsyncData(
            (state.valueOrNull ?? current).copyWith(
              tracks: tracksById.values.toList(growable: false),
              currentSource: activeSource,
              scannedDirectoryCount: directoryCount,
              discoveredTrackCount: discoveredCount,
              lastScanSourceName: activeSource.name,
              lastScanPath: activePath,
            ),
          );
        },
      );
      for (final source in sources) {
        if (_scanCancelled) break;
        activeSource = source;
        final found = <LibrarySong>[];
        var completed = false;
        final offset = directoryCount;
        try {
          final result = await _scanSourceTracks(
            source,
            progressOffsetDirectories: offset,
            progressOffsetTracks: discoveredCount,
            onSongDiscovered: (song, count, path) {
              found.add(song);
              tracksById[song.id] = song;
              discoveredCount++;
              directoryCount = offset + count;
              activePath = path;
              publisher!.add(song);
            },
            onProgress: (count, _, path) {
              directoryCount = count;
              activePath = path;
              state = AsyncData(
                (state.valueOrNull ?? current).copyWith(
                  currentSource: source,
                  scannedDirectoryCount: count,
                  discoveredTrackCount: discoveredCount,
                  lastScanSourceName: source.name,
                  lastScanPath: path,
                ),
              );
            },
          );
          directoryCount = offset + result.scannedDirectoryCount;
          completed = true;
          failures.remove(source.id);
          final foundIds = found.map((song) => song.id).toSet();
          tracksById.removeWhere(
            (id, song) => song.sourceId == source.id && !foundIds.contains(id),
          );
        } on _ScanCancelled {
          // Persist discovered songs together with previously known songs.
        } catch (error) {
          failures.add(source.id);
          errors.add('${source.name}: $error');
        }
        publisher.flush();
        final sourceTracks = tracksById.values
            .where((song) => song.sourceId == source.id)
            .toList();
        try {
          final cache = await createScanCacheRepository();
          await cache.saveScanResults(source.id, sourceTracks);
        } catch (error) {
          failures.add(source.id);
          errors.add('${source.name}: $error');
        }
        state = AsyncData(
          (state.valueOrNull ?? current).copyWith(
            failedSourceIds: failures.toList(growable: false),
            lastScanError: errors.isEmpty ? null : errors.join('\n'),
            clearLastScanError: errors.isEmpty,
          ),
        );
        if (!completed && _scanCancelled) break;
      }
      publisher.flush();
      final tracks = tracksById.values.toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      final displayTracks = await _applyCachedScrapingMetadataAsync(tracks);
      final folderAlbums = await _buildFolderAlbumsAsync(displayTracks);
      final metadataAlbums = await _buildMetadataAlbumsAsync(displayTracks);
      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          tracks: displayTracks,
          folderAlbums: folderAlbums,
          metadataAlbums: metadataAlbums,
          isScanning: false,
          isScanCancelled: _scanCancelled,
          failedSourceIds: failures.toList(growable: false),
          scannedDirectoryCount: directoryCount,
          discoveredTrackCount: discoveredCount,
          lastScannedAt: DateTime.now(),
          lastScanError: errors.isEmpty ? null : errors.join('\n'),
          clearLastScanError: errors.isEmpty,
        ),
      );
      if (!_scanCancelled) {
        unawaited(_hydrateEmbeddedMetadataInBackground(sources, displayTracks));
      }
    } catch (error) {
      final current = state.valueOrNull ?? const LibraryCatalogState();
      state = AsyncData(
        current.copyWith(isScanning: false, lastScanError: error.toString()),
      );
    } finally {
      publisher?.dispose();
      _scanRunning = false;
    }
  }

  Future<void> toggleFavorite(String trackId) async {
    await _savePreferences((preferences) {
      final updated = {...preferences.favoriteTrackIds};
      if (!updated.remove(trackId)) {
        updated.add(trackId);
      }
      return preferences.copyWith(favoriteTrackIds: updated);
    });
  }

  Future<void> toggleLiked(String trackId) async {
    await _savePreferences((preferences) {
      final updated = {...preferences.likedTrackIds};
      if (!updated.remove(trackId)) {
        updated.add(trackId);
      }
      return preferences.copyWith(likedTrackIds: updated);
    });
  }

  Future<void> _savePreferences(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async {
    final repository = ref.read(libraryPreferencesRepositoryProvider);
    final preferences = await repository.update(transform);
    final current = state.valueOrNull ?? const LibraryCatalogState();
    state = AsyncData(
      current.copyWith(
        favoriteTrackIds: preferences.favoriteTrackIds,
        likedTrackIds: preferences.likedTrackIds,
      ),
    );
  }

  Future<_SourceScanResult> _scanSourceTracks(
    SourceProfile source, {
    required int progressOffsetDirectories,
    required int progressOffsetTracks,
    required void Function(int directories, int tracks, String path) onProgress,
    void Function(LibrarySong song, int directories, String path)?
    onSongDiscovered,
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
      if (_scanCancelled) throw _ScanCancelled();
      final path = _normalizeDirectoryPath(queue.removeFirst());
      if (!visited.add(path) || _isExcludedPath(path, excludedDirectories)) {
        continue;
      }

      final listing = await session.listFiles(path);
      if (_scanCancelled) throw _ScanCancelled();
      scannedDirectoryCount++;

      for (final entry in listing.entries) {
        if (_scanCancelled) throw _ScanCancelled();
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

        final song = await _mapSong(source, entry, session: session);
        if (_scanCancelled) throw _ScanCancelled();
        discovered.add(song);
        onSongDiscovered?.call(song, scannedDirectoryCount, path);
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

  Future<List<LibrarySong>> _applyCachedScrapingMetadataAsync(
    List<LibrarySong> tracks,
  ) async {
    if (tracks.isEmpty) {
      return tracks;
    }

    final stopwatch = Stopwatch()..start();
    final metadataById = await IsarManager.getMetadataByIds(
      tracks.map((track) => track.id),
      batchSize: _libraryProcessingYieldBatchSize,
    );
    if (metadataById.isEmpty) {
      DebugLogger.performance(
        'LibraryCatalogController._applyCachedScrapingMetadataAsync',
        '批量读取刮削缓存（0/${tracks.length}）',
        stopwatch.elapsed,
      );
      return tracks;
    }

    var appliedCount = 0;
    var changed = false;
    final result = <LibrarySong>[];
    for (var index = 0; index < tracks.length; index++) {
      final track = tracks[index];
      final cachedMetadata = metadataById[track.id];
      if (cachedMetadata != null && _hasSavedScrapingData(cachedMetadata)) {
        appliedCount++;
        changed = true;
        result.add(_mergeCachedMetadataIntoSong(track, cachedMetadata));
      } else {
        result.add(track);
      }

      if ((index + 1) % _libraryProcessingYieldBatchSize == 0) {
        await _yieldToUi();
      }
    }

    DebugLogger.performance(
      'LibraryCatalogController._applyCachedScrapingMetadataAsync',
      '批量应用刮削缓存（$appliedCount/${tracks.length}）',
      stopwatch.elapsed,
    );
    return changed ? result : tracks;
  }

  Future<List<LibraryAlbum>> _buildFolderAlbumsAsync(
    List<LibrarySong> tracks,
  ) async {
    final grouped = <String, List<LibrarySong>>{};
    for (var index = 0; index < tracks.length; index++) {
      final track = tracks[index];
      final key = '${track.sourceId}::${track.directoryPath.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(track);

      if ((index + 1) % _libraryProcessingYieldBatchSize == 0) {
        await _yieldToUi();
      }
    }
    return _toAlbumsAsync(
      grouped,
      titleOf: (track) => track.folderAlbumTitle,
      artistOf: (track) => track.folderArtistName,
    );
  }

  Future<List<LibraryAlbum>> _buildMetadataAlbumsAsync(
    List<LibrarySong> tracks,
  ) async {
    final grouped = <String, List<LibrarySong>>{};
    final groupByArtist =
        ref
            .read(appSettingsControllerProvider)
            .valueOrNull
            ?.groupMetadataAlbumsByArtist ??
        false;
    for (var index = 0; index < tracks.length; index++) {
      final track = tracks[index];
      final key = groupByArtist
          ? '${track.sourceId}::${track.metadataArtistName.toLowerCase()}::${track.metadataAlbumTitle.toLowerCase()}'
          : '${track.sourceId}::${track.metadataAlbumTitle.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(track);

      if ((index + 1) % _libraryProcessingYieldBatchSize == 0) {
        await _yieldToUi();
      }
    }
    return _toAlbumsAsync(
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

  Future<List<LibraryAlbum>> _toAlbumsAsync(
    Map<String, List<LibrarySong>> grouped, {
    required String Function(LibrarySong track) titleOf,
    required String Function(LibrarySong track) artistOf,
  }) async {
    final albums = <LibraryAlbum>[];
    var processed = 0;

    for (final entry in grouped.entries) {
      albums.add(
        LibraryAlbum(
          id: entry.key,
          title: titleOf(entry.value.first),
          artistName: artistOf(entry.value.first),
          sourceId: entry.value.first.sourceId,
          sourceName: entry.value.first.sourceName,
          tracks: [...entry.value]
            ..sort(
              (left, right) =>
                  left.title.toLowerCase().compareTo(right.title.toLowerCase()),
            ),
        ),
      );

      processed++;
      if (processed % _libraryProcessingYieldBatchSize == 0) {
        await _yieldToUi();
      }
    }

    albums.sort(
      (left, right) =>
          left.title.toLowerCase().compareTo(right.title.toLowerCase()),
    );
    return albums;
  }

  Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);

  /// 刷新单个歌曲的元数据（用于刮削完成后的增量更新，避免全列表重新加载）
  void refreshSongMetadata(String songId) {
    try {
      refreshSongsMetadata([songId]);
    } catch (e, stack) {
      DebugLogger.error(
        'LibraryCatalogController.refreshSongMetadata',
        '刷新歌曲元数据失败: $e',
        stack.toString(),
      );
    }
  }

  bool refreshSongsMetadata(
    Iterable<String> songIds, {
    bool rebuildAlbums = true,
  }) {
    final targetIds = songIds.toSet();
    if (targetIds.isEmpty) {
      return false;
    }

    final currentState = state.valueOrNull;
    if (currentState == null) {
      return false;
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
      return false;
    }

    state = AsyncData(currentState.copyWith(tracks: updatedTracks));
    if (rebuildAlbums) _refreshAlbumIndexesFromCurrentTracks();
    return true;
  }

  void _refreshAlbumIndexesFromCurrentTracks() {
    final generation = ++_albumIndexGeneration;
    unawaited(
      Future<void>(() async {
        if (generation != _albumIndexGeneration) return;
        await _refreshAlbumIndexesFromCurrentTracksAsync(generation);
      }).catchError((Object error, StackTrace stack) {
        DebugLogger.error(
          'LibraryCatalogController._refreshAlbumIndexesFromCurrentTracks',
          '刷新专辑索引失败',
          error.toString(),
          stack,
        );
      }),
    );
  }

  Future<void> _refreshAlbumIndexesFromCurrentTracksAsync(
    int generation,
  ) async {
    final currentState = state.valueOrNull;
    if (currentState == null) {
      return;
    }
    final tracks = currentState.tracks;
    final folderAlbums = await _buildFolderAlbumsAsync(tracks);
    if (generation != _albumIndexGeneration) return;
    final metadataAlbums = await _buildMetadataAlbumsAsync(tracks);
    if (generation != _albumIndexGeneration) return;
    final latest = state.valueOrNull;
    if (latest == null || !identical(latest.tracks, tracks)) {
      return;
    }
    state = AsyncData(
      latest.copyWith(
        folderAlbums: folderAlbums,
        metadataAlbums: metadataAlbums,
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
      ..addAll(
        tracks.where(
          (track) =>
              _supportsEmbeddedMetadataHydration(sourceById[track.sourceId]) &&
              _shouldHydrateEmbeddedMetadata(track),
        ),
      );
    if (queue.isEmpty) {
      return;
    }

    final sessions = <String, MusicSource>{};
    final updatedSongIds = <String>{};
    var needsAlbumRefresh = false;
    final workerCount = queue.length < _embeddedMetadataHydrationConcurrency
        ? queue.length
        : _embeddedMetadataHydrationConcurrency;

    Future<void> flushUpdates({required bool rebuildAlbums}) async {
      if (updatedSongIds.isEmpty ||
          generation != _metadataHydrationGeneration) {
        return;
      }
      final changed = refreshSongsMetadata(
        updatedSongIds.toList(growable: false),
        rebuildAlbums: rebuildAlbums,
      );
      if (changed && !rebuildAlbums) {
        needsAlbumRefresh = true;
      }
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
            await flushUpdates(rebuildAlbums: false);
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
    await flushUpdates(rebuildAlbums: false);
    if (needsAlbumRefresh && generation == _metadataHydrationGeneration) {
      _refreshAlbumIndexesFromCurrentTracks();
    }
  }

  bool _shouldHydrateEmbeddedMetadata(LibrarySong track) {
    final cachedMetadata = IsarManager.getMetadata(track.id);
    if (cachedMetadata == null) {
      return true;
    }
    return cachedMetadata.embeddedMetadataReadAt == null;
  }

  bool _supportsEmbeddedMetadataHydration(SourceProfile? source) {
    if (source == null) {
      return false;
    }
    // ftpconnect does not expose range/head reads, and the FTP source must not
    // download whole audio files just to hydrate embedded tags during scans.
    return source.protocol != SourceProtocol.ftp;
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
