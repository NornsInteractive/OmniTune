import 'dart:async';
import 'dart:collection';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/library_album.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../scraper/application/scraper_chain.dart';
import '../../scraper/domain/metadata_scraper.dart';
import '../../sources/application/source_session_manager.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/domain/music_source.dart';

part 'library_catalog_controller.g.dart';

enum LibraryAlbumGroupingMode { folder, scraped }

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
      LibraryAlbumGroupingMode.scraped => metadataAlbums,
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
  @override
  Future<LibraryCatalogState> build() async {
    final preferences = await ref
        .watch(libraryPreferencesRepositoryProvider)
        .load();

    return LibraryCatalogState(
      favoriteTrackIds: preferences.favoriteTrackIds,
      likedTrackIds: preferences.likedTrackIds,
    );
  }

  Future<void> scanActiveSource() async {
    await scanAllSources();
  }

  Future<void> scanAllSources() async {
    final sources = await ref.read(sourcesControllerProvider.future);
    if (sources.isEmpty) {
      return;
    }

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
          final result = await _scanSourceTracks(
            source,
            progressOffsetDirectories: scannedDirectoryCount,
            progressOffsetTracks: discovered.length,
            onProgress: (directories, tracks, path) {
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
        } on DirectoryReadFailure catch (error) {
          scanErrors.add('${source.name}: ${error.message}');
        } catch (error) {
          scanErrors.add('${source.name}: $error');
        }
      }

      discovered.sort(
        (left, right) =>
            left.title.toLowerCase().compareTo(right.title.toLowerCase()),
      );

      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          scannedSources: sources,
          currentSource: sources.last,
          tracks: discovered,
          folderAlbums: _buildFolderAlbums(discovered),
          metadataAlbums: _buildMetadataAlbums(discovered),
          isScanning: false,
          scannedDirectoryCount: scannedDirectoryCount,
          discoveredTrackCount: discovered.length,
          lastScanPath: '/',
          lastScanSourceName: sources.last.name,
          lastScannedAt: DateTime.now(),
          clearLastScanError: scanErrors.isEmpty,
          lastScanError: scanErrors.isEmpty ? null : scanErrors.join('\n'),
        ),
      );
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

      state = AsyncData(
        (state.valueOrNull ?? current).copyWith(
          scannedSources: allSources,
          currentSource: source,
          tracks: retained,
          folderAlbums: _buildFolderAlbums(retained),
          metadataAlbums: _buildMetadataAlbums(retained),
          isScanning: false,
          scannedDirectoryCount: result.scannedDirectoryCount,
          discoveredTrackCount: retained.length,
          lastScanPath: source.effectiveScanDirectories.first,
          lastScanSourceName: source.name,
          lastScannedAt: DateTime.now(),
          clearLastScanError: true,
        ),
      );
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

        discovered.add(await _mapSong(source, entry));
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

  Future<LibrarySong> _mapSong(SourceProfile source, RemoteEntry entry) async {
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
    final scrapedMetadata = await _scrapeMetadata(entry);
    final albumTitle = _normalizeMetadataValue(scrapedMetadata?.album);
    final artistName = _normalizeMetadataValue(scrapedMetadata?.artist);
    final title = _normalizeMetadataValue(scrapedMetadata?.title);

    return LibrarySong(
      id: entry.uniqueId,
      sourceId: source.id,
      sourceName: source.name,
      title: title ?? entry.title,
      fileName: entry.name,
      remotePath: entry.path,
      albumTitle: albumTitle ?? folderAlbumTitle,
      artistName: artistName ?? folderArtistName,
      directoryPath: directory,
      folderAlbumTitle: folderAlbumTitle,
      folderArtistName: folderArtistName,
      scrapedAlbumTitle: albumTitle,
      scrapedArtistName: artistName,
      mimeType: entry.mimeType,
      size: entry.size,
      modifiedAt: entry.modifiedAt,
    );
  }

  Future<ScrapedMetadata?> _scrapeMetadata(RemoteEntry entry) {
    return ref.read(scraperChainProvider).scrape(entry);
  }

  String? _normalizeMetadataValue(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
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
    for (final track in tracks) {
      final key =
          '${track.sourceId}::${track.metadataArtistName.toLowerCase()}::${track.metadataAlbumTitle.toLowerCase()}';
      grouped.putIfAbsent(key, () => []).add(track);
    }
    return _toAlbums(
      grouped,
      titleOf: (track) => track.metadataAlbumTitle,
      artistOf: (track) => track.metadataArtistName,
    );
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
