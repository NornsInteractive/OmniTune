import 'dart:async';
import 'dart:math' as math;

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/player_service.dart';
import '../../../core/database/isar_manager.dart';
import '../../../core/database/scraping_metadata.dart';
import '../../../core/models/app_preferences.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/playable_track.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../../core/storage/player_session_repository.dart';
import '../../../core/utils/chinese_text_localizer.dart';
import '../../../core/utils/debug_logger.dart';
import '../../settings/application/app_settings_controller.dart';
import '../../scraper/application/scraper_chain.dart';
import '../../scraper/domain/metadata_scraper.dart';
import '../../sources/application/source_session_manager.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/data/webdav/webdav_playback_cache_base.dart';
import '../../sources/data/webdav/webdav_playback_cache_provider.dart';
import '../../sources/domain/music_source.dart';
import '../../library/application/library_catalog_controller.dart';

part 'player_controller.g.dart';

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

class CacheProgressSegment {
  const CacheProgressSegment({
    required this.startFraction,
    required this.endFraction,
  });

  final double startFraction;
  final double endFraction;
}

enum PlayerPlaybackMode { list, repeatOne, shuffle }

class PlayerViewState {
  const PlayerViewState({
    required this.currentTrack,
    required this.isPlaying,
    required this.processingState,
    required this.position,
    required this.bufferedPosition,
    required this.duration,
    required this.playlist,
    required this.currentIndex,
    required this.playbackMode,
    this.lyrics = const [],
    this.cacheSegments = const [],
    this.errorMessage,
  });

  final PlayableTrack? currentTrack;
  final bool isPlaying;
  final ProcessingState processingState;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
  final List<LibrarySong> playlist;
  final int currentIndex;
  final PlayerPlaybackMode playbackMode;
  final List<LyricLine> lyrics;
  final List<CacheProgressSegment> cacheSegments;
  final String? errorMessage;

  bool get hasTrack => currentTrack != null;

  bool get isBusy =>
      processingState == ProcessingState.loading ||
      processingState == ProcessingState.buffering;

  bool get hasPlaylist => playlist.isNotEmpty;

  int get playlistCount => playlist.length;

  bool get canPlayPrevious {
    if (playlist.isEmpty) {
      return false;
    }
    return switch (playbackMode) {
      PlayerPlaybackMode.list => currentIndex > 0,
      PlayerPlaybackMode.repeatOne => currentIndex >= 0,
      PlayerPlaybackMode.shuffle => playlist.length > 1,
    };
  }

  bool get canPlayNext {
    if (playlist.isEmpty) {
      return false;
    }
    return switch (playbackMode) {
      PlayerPlaybackMode.list => currentIndex < playlist.length - 1,
      PlayerPlaybackMode.repeatOne => currentIndex >= 0,
      PlayerPlaybackMode.shuffle => playlist.length > 1,
    };
  }

  int get activeLyricIndex {
    if (lyrics.isEmpty) {
      return -1;
    }
    if (!lyrics.any((line) => line.time > Duration.zero)) {
      return -1;
    }

    var activeIndex = -1;
    for (var index = 0; index < lyrics.length; index++) {
      if (position >= lyrics[index].time) {
        activeIndex = index;
      } else {
        break;
      }
    }
    return activeIndex;
  }

  factory PlayerViewState.fromService(
    PlayerService service, {
    List<LyricLine> lyrics = const [],
    List<CacheProgressSegment> cacheSegments = const [],
    List<LibrarySong> playlist = const [],
    int currentIndex = -1,
    PlayerPlaybackMode playbackMode = PlayerPlaybackMode.list,
    String? errorMessage,
  }) {
    return PlayerViewState(
      currentTrack: service.currentTrack,
      isPlaying: service.player.playing,
      processingState: service.player.processingState,
      position: service.player.position,
      bufferedPosition: service.player.bufferedPosition,
      duration: service.player.duration,
      playlist: List.unmodifiable(playlist),
      currentIndex: currentIndex,
      playbackMode: playbackMode,
      lyrics: lyrics,
      cacheSegments: cacheSegments,
      errorMessage: errorMessage,
    );
  }

  factory PlayerViewState.initial() {
    return const PlayerViewState(
      currentTrack: null,
      isPlaying: false,
      processingState: ProcessingState.idle,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      duration: null,
      playlist: [],
      currentIndex: -1,
      playbackMode: PlayerPlaybackMode.list,
      lyrics: [],
      cacheSegments: [],
    );
  }
}

@Riverpod(keepAlive: true)
class PlayerController extends _$PlayerController {
  late PlayerService _service;
  late WebDavPlaybackCache _playbackCache;
  late PlayerSessionRepository _sessionRepository;
  AppLocalePreference _localePreference = AppLocalePreference.system;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferedPositionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;
  StreamSubscription<PlaybackCacheSnapshot>? _cacheSubscription;
  List<LyricLine> _lyrics = const [];
  List<LibrarySong> _playlist = const [];
  int _currentIndex = -1;
  PlayerPlaybackMode _playbackMode = PlayerPlaybackMode.list;
  final math.Random _random = math.Random();
  bool _handlingCompletion = false;
  bool _restoreStarted = false;
  DateTime _lastPositionPersistedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _playRequestSerial = 0;

  @override
  PlayerViewState build() {
    _service = ref.watch(playerServiceProvider);
    _playbackCache = ref.watch(webDavPlaybackCacheProvider);
    _sessionRepository = ref.watch(playerSessionRepositoryProvider);
    _syncLocalePreference(ref.read(appSettingsControllerProvider));
    ref.listen<AsyncValue<LibraryPreferences>>(appSettingsControllerProvider, (
      _,
      next,
    ) {
      _syncLocalePreference(next);
    });
    _bindStreams();
    _restorePersistedSession();
    ref.onDispose(_disposeSubscriptions);
    return PlayerViewState.fromService(
      _service,
      playlist: _playlist,
      currentIndex: _currentIndex,
      playbackMode: _playbackMode,
    );
  }

  Future<void> playEntry({
    required SourceProfile profile,
    required RemoteEntry entry,
  }) async {
    try {
      _replacePlaylist(const [], currentIndex: -1);
      unawaited(_sessionRepository.clear());
      await _playRemoteEntry(profile: profile, entry: entry);
      unawaited(_scrapeCurrentEntryAsync(entry));
    } catch (error) {
      _syncState(errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> playLibrarySong(
    LibrarySong song, {
    List<LibrarySong>? playlist,
  }) async {
    try {
      final nextPlaylist = _playlistForSong(song, playlist);
      final nextIndex = nextPlaylist.indexWhere((item) => item.id == song.id);
      _replacePlaylist(nextPlaylist, currentIndex: nextIndex);
      await _playQueueIndex(nextIndex);
    } catch (error) {
      _syncState(errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> addToPlayNext(LibrarySong song) async {
    final nextPlaylist = List<LibrarySong>.of(_playlist);
    final rawInsertIndex = _currentIndex >= 0 ? _currentIndex + 1 : 0;
    final insertIndex = rawInsertIndex.clamp(0, nextPlaylist.length).toInt();
    nextPlaylist.insert(insertIndex, song);
    _replacePlaylist(nextPlaylist, currentIndex: _currentIndex);
    unawaited(_persistSession());
  }

  Future<void> playNext() async {
    final nextIndex = _resolveNextIndex();
    if (nextIndex == null) {
      return;
    }
    await _playQueueIndex(nextIndex);
  }

  Future<void> playPrevious() async {
    final previousIndex = _resolvePreviousIndex();
    if (previousIndex == null) {
      return;
    }
    await _playQueueIndex(previousIndex);
  }

  Future<void> playPlaylistIndex(int index) => _playQueueIndex(index);

  Future<void> removePlaylistItemAt(int index) async {
    if (index < 0 || index >= _playlist.length) {
      return;
    }

    final wasCurrentSong = index == _currentIndex;
    final wasPlaying = _service.isPlaying;
    final nextPlaylist = List<LibrarySong>.of(_playlist)..removeAt(index);

    if (nextPlaylist.isEmpty) {
      _lyrics = const [];
      _replacePlaylist(const [], currentIndex: -1);
      await _service.stop();
      await _sessionRepository.clear();
      _syncState();
      return;
    }

    if (index < _currentIndex) {
      _replacePlaylist(nextPlaylist, currentIndex: _currentIndex - 1);
      unawaited(_persistSession());
      return;
    }

    if (!wasCurrentSong) {
      _replacePlaylist(nextPlaylist, currentIndex: _currentIndex);
      unawaited(_persistSession());
      return;
    }

    final nextIndex = index >= nextPlaylist.length
        ? nextPlaylist.length - 1
        : index;
    _replacePlaylist(nextPlaylist, currentIndex: nextIndex);
    if (wasPlaying) {
      await _playQueueIndex(nextIndex);
    } else {
      await _loadQueueIndex(nextIndex);
    }
  }

  void cyclePlaybackMode() {
    _playbackMode = switch (_playbackMode) {
      PlayerPlaybackMode.list => PlayerPlaybackMode.shuffle,
      PlayerPlaybackMode.shuffle => PlayerPlaybackMode.repeatOne,
      PlayerPlaybackMode.repeatOne => PlayerPlaybackMode.list,
    };
    _syncState();
    unawaited(_persistSession());
  }

  void setPlaybackMode(PlayerPlaybackMode mode) {
    _playbackMode = mode;
    _syncState();
    unawaited(_persistSession());
  }

  Future<void> togglePlayPause() async {
    await _service.togglePlayPause();
    _syncState();
    unawaited(_persistSession());
  }

  Future<void> seek(Duration position) async {
    await _service.seek(position);
    _syncState();
    unawaited(_persistSession(positionOverride: position));
  }

  Future<void> seekAndPlay(Duration position) async {
    await _service.seek(position);
    if (!_service.isPlaying) {
      await _service.togglePlayPause();
    }
    _syncState();
    unawaited(_persistSession(positionOverride: position));
  }

  Future<void> stop() async {
    await _service.stop();
    _syncState();
    unawaited(_persistSession());
  }

  void _bindStreams() {
    _playerStateSubscription ??= _service.playerStateStream.listen((
      playerState,
    ) {
      if (playerState.processingState == ProcessingState.completed) {
        unawaited(_handleTrackCompleted());
        return;
      }
      _handlingCompletion = false;
      _syncState();
    });
    _positionSubscription ??= _service.positionStream.listen((_) {
      _syncState();
      _persistPositionThrottled();
    });
    _bufferedPositionSubscription ??= _service.bufferedPositionStream.listen((
      _,
    ) {
      _syncState();
    });
    _durationSubscription ??= _service.durationStream.listen((_) {
      _syncState();
    });
    _errorSubscription ??= _service.errorStream.listen((error) {
      _syncState(errorMessage: error.message);
    });
    _cacheSubscription ??= _playbackCache.snapshotStream.listen((snapshot) {
      final currentTrack = _service.currentTrack;
      if (currentTrack != null && currentTrack.id == snapshot.trackId) {
        _syncState();
      }
    });
  }

  void _syncState({String? errorMessage}) {
    state = PlayerViewState.fromService(
      _service,
      lyrics: _lyrics,
      cacheSegments: _resolveCacheSegments(_service.currentTrack),
      playlist: _playlist,
      currentIndex: _currentIndex,
      playbackMode: _playbackMode,
      errorMessage: errorMessage,
    );
  }

  void _disposeSubscriptions() {
    unawaited(_persistSession());
    final playerStateSubscription = _playerStateSubscription;
    final positionSubscription = _positionSubscription;
    final bufferedPositionSubscription = _bufferedPositionSubscription;
    final durationSubscription = _durationSubscription;
    final errorSubscription = _errorSubscription;
    final cacheSubscription = _cacheSubscription;

    _playerStateSubscription = null;
    _positionSubscription = null;
    _bufferedPositionSubscription = null;
    _durationSubscription = null;
    _errorSubscription = null;
    _cacheSubscription = null;

    if (playerStateSubscription != null) {
      unawaited(playerStateSubscription.cancel());
    }
    if (positionSubscription != null) {
      unawaited(positionSubscription.cancel());
    }
    if (bufferedPositionSubscription != null) {
      unawaited(bufferedPositionSubscription.cancel());
    }
    if (durationSubscription != null) {
      unawaited(durationSubscription.cancel());
    }
    if (errorSubscription != null) {
      unawaited(errorSubscription.cancel());
    }
    if (cacheSubscription != null) {
      unawaited(cacheSubscription.cancel());
    }
  }

  Future<void> _playRemoteEntry({
    required SourceProfile profile,
    required RemoteEntry entry,
  }) async {
    final requestSerial = ++_playRequestSerial;
    _lyrics = const [];
    _syncState();

    final source = await ref
        .read(musicSourceSessionManagerProvider)
        .get(profile);

    // 快速启动播放：并行加载歌词和构建音轨
    final lyricsFuture = _loadLyrics(source, entry.path);
    final trackFuture = source.buildPlayableTrack(entry);

    // 等待音轨准备就绪
    final builtTrack = await trackFuture;
    if (requestSerial != _playRequestSerial) {
      return;
    }
    final track = _enhanceTrackWithCachedScraping(
      builtTrack,
      metadataId: entry.uniqueId,
    );
    final scrapedLyrics = _parseLyrics(track.displayLyrics);
    if (scrapedLyrics.isNotEmpty) {
      _lyrics = scrapedLyrics;
    }

    // 立即播放，不等待歌词加载
    await _service.playTrack(track);
    _syncState();
    unawaited(_persistSession(positionOverride: Duration.zero));

    // 在后台加载歌词
    final lyrics = await lyricsFuture;
    if (requestSerial == _playRequestSerial &&
        _service.currentTrack?.id == track.id) {
      if (lyrics.isNotEmpty) {
        _lyrics = lyrics;
      } else if (_lyrics.isEmpty && scrapedLyrics.isNotEmpty) {
        _lyrics = scrapedLyrics;
      }
      _syncState();
    }
  }

  Future<void> _playQueueIndex(int index) async {
    if (index < 0 || index >= _playlist.length) {
      return;
    }

    _currentIndex = index;
    _syncState();

    final song = _playlist[index];
    final profile = await _profileForSong(song);
    await _playRemoteEntry(profile: profile, entry: song.toRemoteEntry());
    unawaited(_scrapeCurrentSongAsync(song));
  }

  Future<void> _loadQueueIndex(
    int index, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (index < 0 || index >= _playlist.length) {
      return;
    }

    final requestSerial = ++_playRequestSerial;
    _currentIndex = index;
    _lyrics = const [];
    _syncState();

    final song = _playlist[index];

    // 尝试从数据库加载已刮削的元数据
    var displaySong = song;
    try {
      final scrapingMetadata = IsarManager.getMetadata(song.id);
      if (scrapingMetadata != null &&
          scrapingMetadata.status == ScrapingStatus.completed) {
        // 应用刮削数据到显示
        displaySong = LibrarySong(
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
          manuallyScrapedTitle:
              scrapingMetadata.manuallyScrapedTitle ??
              song.manuallyScrapedTitle,
          manuallyScrapedArtist:
              scrapingMetadata.manuallyScrapedArtist ??
              song.manuallyScrapedArtist,
          manuallyScrapedAlbum:
              scrapingMetadata.manuallyScrapedAlbum ??
              song.manuallyScrapedAlbum,
          manuallyScrapedCoverUrl:
              scrapingMetadata.manuallyScrapedCoverUrl ??
              song.manuallyScrapedCoverUrl,
          manuallyScrapedLocalCoverPath:
              scrapingMetadata.manuallyScrapedLocalCoverPath ??
              song.manuallyScrapedLocalCoverPath,
          manuallyScrapedLyrics:
              scrapingMetadata.manuallyScrapedLyrics ??
              song.manuallyScrapedLyrics,
          autoScrapedTitle:
              scrapingMetadata.autoScrapedTitle ?? song.autoScrapedTitle,
          autoScrapedArtist:
              scrapingMetadata.autoScrapedArtist ?? song.autoScrapedArtist,
          autoScrapedAlbum:
              scrapingMetadata.autoScrapedAlbum ?? song.autoScrapedAlbum,
          autoScrapedCoverUrl:
              scrapingMetadata.autoScrapedCoverUrl ?? song.autoScrapedCoverUrl,
          autoScrapedLocalCoverPath:
              scrapingMetadata.autoScrapedLocalCoverPath ??
              song.autoScrapedLocalCoverPath,
          autoScrapedLyrics:
              scrapingMetadata.autoScrapedLyrics ?? song.autoScrapedLyrics,
        );
      }
    } catch (e) {
      DebugLogger.warning('PlayerController._loadQueueIndex', '加载刮削缓存失败: $e');
    }

    final profile = await _profileForSong(song);
    final source = await ref
        .read(musicSourceSessionManagerProvider)
        .get(profile);
    final lyricsFuture = _loadLyrics(source, song.remotePath);
    final track = await source.buildPlayableTrack(song.toRemoteEntry());
    if (requestSerial != _playRequestSerial) {
      return;
    }

    // 应用已刮削的元数据到播放轨道
    final enhancedTrack = PlayableTrack(
      id: track.id,
      sourceId: track.sourceId,
      title: track.title,
      sourceName: track.sourceName,
      remotePath: track.remotePath,
      audioSource: track.audioSource,
      sourceSizeBytes: track.sourceSizeBytes,
      artistName: displaySong.displayArtist,
      albumTitle: displaySong.displayAlbum,
      autoScrapedTitle:
          displaySong.manuallyScrapedTitle ?? displaySong.autoScrapedTitle,
      autoScrapedArtist:
          displaySong.manuallyScrapedArtist ?? displaySong.autoScrapedArtist,
      autoScrapedAlbum:
          displaySong.manuallyScrapedAlbum ?? displaySong.autoScrapedAlbum,
      autoScrapedCoverUrl:
          displaySong.manuallyScrapedCoverUrl ??
          displaySong.autoScrapedCoverUrl,
      localCoverPath:
          displaySong.manuallyScrapedLocalCoverPath ??
          displaySong.autoScrapedLocalCoverPath,
      lyrics:
          displaySong.manuallyScrapedLyrics ?? displaySong.autoScrapedLyrics,
    );
    final scrapedLyrics = _parseLyrics(enhancedTrack.displayLyrics);
    if (scrapedLyrics.isNotEmpty) {
      _lyrics = scrapedLyrics;
    }
    await _service.loadTrack(enhancedTrack, initialPosition: initialPosition);
    _syncState();
    unawaited(_persistSession(positionOverride: initialPosition));

    final lyrics = await lyricsFuture;
    if (requestSerial == _playRequestSerial &&
        _service.currentTrack?.id == enhancedTrack.id) {
      if (lyrics.isNotEmpty) {
        _lyrics = lyrics;
      } else if (_lyrics.isEmpty && scrapedLyrics.isNotEmpty) {
        _lyrics = scrapedLyrics;
      }
      _syncState();
    }
  }

  Future<SourceProfile> _profileForSong(LibrarySong song) async {
    final profiles = await ref.read(sourcesControllerProvider.future);
    return profiles.firstWhere((item) => item.id == song.sourceId);
  }

  void _restorePersistedSession() {
    if (_restoreStarted) {
      return;
    }
    _restoreStarted = true;
    unawaited(_loadPersistedSession());
  }

  Future<void> _loadPersistedSession() async {
    try {
      final snapshot = await _sessionRepository.load();
      if (snapshot == null ||
          !snapshot.hasCurrentSong ||
          _playlist.isNotEmpty) {
        return;
      }

      final restoreSerial = _playRequestSerial;
      _playlist = List<LibrarySong>.unmodifiable(snapshot.playlist);
      _currentIndex = snapshot.currentIndex;
      _playbackMode = _playbackModeFromStorage(snapshot.playbackMode);
      _syncState();

      if (restoreSerial != _playRequestSerial) {
        return;
      }
      await _loadQueueIndex(
        snapshot.currentIndex,
        initialPosition: snapshot.position,
      );
    } catch (error) {
      _syncState(errorMessage: error.toString());
    }
  }

  Future<void> _handleTrackCompleted() async {
    if (_handlingCompletion) {
      return;
    }

    _handlingCompletion = true;
    try {
      if (_playbackMode == PlayerPlaybackMode.repeatOne && _playlist.isEmpty) {
        await _service.replayCurrent();
        _syncState();
        return;
      }

      final nextIndex = _resolveNextIndex();
      if (nextIndex == null) {
        _syncState();
        return;
      }

      await _playQueueIndex(nextIndex);
    } catch (error) {
      _syncState(errorMessage: error.toString());
    }
  }

  List<LibrarySong> _playlistForSong(
    LibrarySong song,
    List<LibrarySong>? playlist,
  ) {
    final nextPlaylist = List<LibrarySong>.of(
      playlist == null || playlist.isEmpty ? [song] : playlist,
    );
    final songIndex = nextPlaylist.indexWhere((item) => item.id == song.id);
    if (songIndex == -1) {
      nextPlaylist.insert(0, song);
    }
    return nextPlaylist;
  }

  void _replacePlaylist(
    List<LibrarySong> playlist, {
    required int currentIndex,
  }) {
    _playlist = List<LibrarySong>.unmodifiable(playlist);
    _currentIndex = currentIndex >= 0 && currentIndex < _playlist.length
        ? currentIndex
        : -1;
    _syncState();
  }

  int? _resolveNextIndex() {
    if (_playlist.isEmpty) {
      return null;
    }

    return switch (_playbackMode) {
      PlayerPlaybackMode.repeatOne => _currentIndex >= 0 ? _currentIndex : 0,
      PlayerPlaybackMode.shuffle => _randomQueueIndex(),
      PlayerPlaybackMode.list =>
        _currentIndex < 0
            ? 0
            : _currentIndex + 1 < _playlist.length
            ? _currentIndex + 1
            : null,
    };
  }

  int? _resolvePreviousIndex() {
    if (_playlist.isEmpty) {
      return null;
    }

    return switch (_playbackMode) {
      PlayerPlaybackMode.repeatOne => _currentIndex >= 0 ? _currentIndex : 0,
      PlayerPlaybackMode.shuffle => _randomQueueIndex(),
      PlayerPlaybackMode.list => _currentIndex > 0 ? _currentIndex - 1 : null,
    };
  }

  int _randomQueueIndex() {
    if (_playlist.length <= 1) {
      return 0;
    }

    var nextIndex = _random.nextInt(_playlist.length);
    while (nextIndex == _currentIndex) {
      nextIndex = _random.nextInt(_playlist.length);
    }
    return nextIndex;
  }

  void _persistPositionThrottled() {
    if (_playlist.isEmpty || _currentIndex < 0) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastPositionPersistedAt) < const Duration(seconds: 5)) {
      return;
    }

    _lastPositionPersistedAt = now;
    unawaited(_persistSession());
  }

  Future<void> _persistSession({Duration? positionOverride}) async {
    if (_playlist.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _playlist.length) {
      await _sessionRepository.clear();
      return;
    }

    await _sessionRepository.save(
      PlayerSessionSnapshot(
        playlist: _playlist,
        currentIndex: _currentIndex,
        playbackMode: _playbackMode.name,
        position: positionOverride ?? _service.position,
      ),
    );
  }

  PlayerPlaybackMode _playbackModeFromStorage(String value) {
    for (final mode in PlayerPlaybackMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return PlayerPlaybackMode.list;
  }

  Future<List<LyricLine>> _loadLyrics(
    MusicSource source,
    String remotePath,
  ) async {
    try {
      final lyricPath = '${p.posix.withoutExtension(remotePath)}.lrc';
      final raw = await source.readTextFile(lyricPath);
      return _parseLyrics(raw);
    } catch (_) {
      return const [];
    }
  }

  List<LyricLine> _parseLyrics(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    final normalizedRaw = normalizeChineseTextForLocale(raw, _localePreference);

    final result = <LyricLine>[];
    final unsyncedLines = <String>[];
    final timestampPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    for (final line in normalizedRaw.split(RegExp(r'\r?\n'))) {
      final matches = timestampPattern.allMatches(line).toList();
      if (matches.isEmpty) {
        final text = line.trim();
        if (text.isNotEmpty) {
          unsyncedLines.add(text);
        }
        continue;
      }
      final text = line.replaceAll(timestampPattern, '').trim();
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fractionRaw = match.group(3) ?? '';
        final milliseconds = switch (fractionRaw.length) {
          1 => (int.tryParse(fractionRaw) ?? 0) * 100,
          2 => (int.tryParse(fractionRaw) ?? 0) * 10,
          _ => int.tryParse(fractionRaw) ?? 0,
        };
        result.add(
          LyricLine(
            time: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: milliseconds,
            ),
            text: text.isEmpty ? '...' : text,
          ),
        );
      }
    }

    if (result.isEmpty) {
      return unsyncedLines
          .map((text) => LyricLine(time: Duration.zero, text: text))
          .toList(growable: false);
    }

    result.sort((left, right) => left.time.compareTo(right.time));
    return result;
  }

  PlayableTrack _enhanceTrackWithCachedScraping(
    PlayableTrack track, {
    required String metadataId,
  }) {
    try {
      final metadata = IsarManager.getMetadata(metadataId);
      if (metadata == null || metadata.status != ScrapingStatus.completed) {
        return track;
      }

      return PlayableTrack(
        id: track.id,
        sourceId: track.sourceId,
        title: track.title,
        sourceName: track.sourceName,
        remotePath: track.remotePath,
        audioSource: track.audioSource,
        sourceSizeBytes: track.sourceSizeBytes,
        artistName: _firstNonEmpty(
          metadata.manuallyScrapedArtist,
          metadata.autoScrapedArtist,
          track.artistName,
        ),
        albumTitle: _firstNonEmpty(
          metadata.manuallyScrapedAlbum,
          metadata.autoScrapedAlbum,
          track.albumTitle,
        ),
        autoScrapedTitle: _firstNonEmpty(
          metadata.manuallyScrapedTitle,
          metadata.autoScrapedTitle,
          track.autoScrapedTitle,
        ),
        autoScrapedArtist: _firstNonEmpty(
          metadata.manuallyScrapedArtist,
          metadata.autoScrapedArtist,
          track.autoScrapedArtist,
        ),
        autoScrapedAlbum: _firstNonEmpty(
          metadata.manuallyScrapedAlbum,
          metadata.autoScrapedAlbum,
          track.autoScrapedAlbum,
        ),
        autoScrapedCoverUrl: _firstNonEmpty(
          metadata.manuallyScrapedCoverUrl,
          metadata.autoScrapedCoverUrl,
          track.autoScrapedCoverUrl,
        ),
        localCoverPath: _firstNonEmpty(
          metadata.manuallyScrapedLocalCoverPath,
          metadata.autoScrapedLocalCoverPath,
          track.localCoverPath,
        ),
        lyrics: _firstNonEmpty(
          metadata.manuallyScrapedLyrics,
          metadata.autoScrapedLyrics,
          track.lyrics,
        ),
      );
    } catch (e) {
      DebugLogger.warning(
        'PlayerController._enhanceTrackWithCachedScraping',
        '加载刮削缓存失败: $e',
      );
      return track;
    }
  }

  List<CacheProgressSegment> _resolveCacheSegments(PlayableTrack? track) {
    if (track == null) {
      return const [];
    }

    final snapshot = _playbackCache.snapshotForTrack(track.id);
    final totalLength = snapshot?.totalLength ?? track.sourceSizeBytes;
    if (snapshot == null || totalLength == null || totalLength <= 0) {
      return const [];
    }

    return snapshot.segments
        .map((segment) {
          final startFraction = segment.start / totalLength;
          final endFraction = segment.endExclusive / totalLength;
          return CacheProgressSegment(
            startFraction: startFraction.clamp(0, 1).toDouble(),
            endFraction: endFraction.clamp(0, 1).toDouble(),
          );
        })
        .where((segment) => segment.endFraction > segment.startFraction)
        .toList(growable: false);
  }

  String? _firstNonEmpty(String? first, String? second, [String? third]) {
    for (final value in [first, second, third]) {
      if (value?.trim().isNotEmpty == true) {
        return value!.trim();
      }
    }
    return null;
  }

  void _syncLocalePreference(AsyncValue<LibraryPreferences> appSettings) {
    _localePreference = appSettings.maybeWhen(
      data: (prefs) => prefs.localePreference,
      orElse: () => AppLocalePreference.system,
    );
  }

  void _applyScrapingMetadataToCurrentTrack(
    String trackId,
    ScrapingMetadata metadata, {
    bool syncState = true,
  }) {
    final currentTrack = _service.currentTrack;
    if (currentTrack == null || currentTrack.id != trackId) {
      return;
    }

    final updatedTrack = PlayableTrack(
      id: currentTrack.id,
      sourceId: currentTrack.sourceId,
      title: currentTrack.title,
      sourceName: currentTrack.sourceName,
      remotePath: currentTrack.remotePath,
      audioSource: currentTrack.audioSource,
      sourceSizeBytes: currentTrack.sourceSizeBytes,
      artistName: _firstNonEmpty(
        metadata.manuallyScrapedArtist,
        metadata.autoScrapedArtist,
        currentTrack.artistName,
      ),
      albumTitle: _firstNonEmpty(
        metadata.manuallyScrapedAlbum,
        metadata.autoScrapedAlbum,
        currentTrack.albumTitle,
      ),
      autoScrapedTitle: _firstNonEmpty(
        metadata.manuallyScrapedTitle,
        metadata.autoScrapedTitle,
        currentTrack.autoScrapedTitle,
      ),
      autoScrapedArtist: _firstNonEmpty(
        metadata.manuallyScrapedArtist,
        metadata.autoScrapedArtist,
        currentTrack.autoScrapedArtist,
      ),
      autoScrapedAlbum: _firstNonEmpty(
        metadata.manuallyScrapedAlbum,
        metadata.autoScrapedAlbum,
        currentTrack.autoScrapedAlbum,
      ),
      autoScrapedCoverUrl: _firstNonEmpty(
        metadata.manuallyScrapedCoverUrl,
        metadata.autoScrapedCoverUrl,
        currentTrack.autoScrapedCoverUrl,
      ),
      localCoverPath: _firstNonEmpty(
        metadata.manuallyScrapedLocalCoverPath,
        metadata.autoScrapedLocalCoverPath,
        currentTrack.localCoverPath,
      ),
      lyrics: _firstNonEmpty(
        metadata.manuallyScrapedLyrics,
        metadata.autoScrapedLyrics,
        currentTrack.lyrics,
      ),
    );

    _service.updateCurrentTrack(updatedTrack);

    final scrapedLyrics = _parseLyrics(updatedTrack.displayLyrics);
    if (_lyrics.isEmpty && scrapedLyrics.isNotEmpty) {
      _lyrics = scrapedLyrics;
    }

    if (syncState) {
      _syncState();
      unawaited(_persistSession());
    }
  }

  ScrapingMetadata _buildCompletedScrapingMetadata({
    required RemoteEntry entry,
    required ScrapedMetadata scrapedMetadata,
  }) {
    return ScrapingMetadata(
      id: entry.uniqueId,
      sourceId: entry.sourceId,
      filePath: entry.path,
      filenameWithoutExt: p.posix.basenameWithoutExtension(entry.name),
      originalFileName: entry.name,
      manuallyScrapedTitle: null,
      manuallyScrapedArtist: null,
      manuallyScrapedAlbum: null,
      manuallyScrapedCoverUrl: null,
      manuallyScrapedLocalCoverPath: null,
      manuallyScrapedLyrics: null,
      manualScrapedAt: null,
      autoScrapedTitle: scrapedMetadata.title,
      autoScrapedArtist: scrapedMetadata.artist,
      autoScrapedAlbum: scrapedMetadata.album,
      autoScrapedCoverUrl: scrapedMetadata.coverUrl,
      autoScrapedLocalCoverPath: scrapedMetadata.localCoverPath,
      autoScrapedLyrics: scrapedMetadata.lyrics,
      autoScrapedAt: DateTime.now(),
      status: ScrapingStatus.completed,
      errorMessage: null,
      retryCount: 0,
    );
  }

  void _applyScrapingMetadataToCurrentSong(
    String songId,
    ScrapingMetadata metadata,
  ) {
    if (_currentIndex < 0 || _currentIndex >= _playlist.length) {
      return;
    }

    final currentSong = _playlist[_currentIndex];
    if (currentSong.id != songId) {
      return;
    }

    final updatedSong = LibrarySong(
      id: currentSong.id,
      sourceId: currentSong.sourceId,
      sourceName: currentSong.sourceName,
      title: currentSong.title,
      fileName: currentSong.fileName,
      remotePath: currentSong.remotePath,
      albumTitle: currentSong.albumTitle,
      artistName: currentSong.artistName,
      directoryPath: currentSong.directoryPath,
      folderAlbumTitle: currentSong.folderAlbumTitle,
      folderArtistName: currentSong.folderArtistName,
      scrapedAlbumTitle: currentSong.scrapedAlbumTitle,
      scrapedArtistName: currentSong.scrapedArtistName,
      mimeType: currentSong.mimeType,
      size: currentSong.size,
      modifiedAt: currentSong.modifiedAt,
      manuallyScrapedTitle:
          metadata.manuallyScrapedTitle ?? currentSong.manuallyScrapedTitle,
      manuallyScrapedArtist:
          metadata.manuallyScrapedArtist ?? currentSong.manuallyScrapedArtist,
      manuallyScrapedAlbum:
          metadata.manuallyScrapedAlbum ?? currentSong.manuallyScrapedAlbum,
      manuallyScrapedCoverUrl:
          metadata.manuallyScrapedCoverUrl ??
          currentSong.manuallyScrapedCoverUrl,
      manuallyScrapedLocalCoverPath:
          metadata.manuallyScrapedLocalCoverPath ??
          currentSong.manuallyScrapedLocalCoverPath,
      manuallyScrapedLyrics:
          metadata.manuallyScrapedLyrics ?? currentSong.manuallyScrapedLyrics,
      autoScrapedTitle:
          metadata.autoScrapedTitle ?? currentSong.autoScrapedTitle,
      autoScrapedArtist:
          metadata.autoScrapedArtist ?? currentSong.autoScrapedArtist,
      autoScrapedAlbum:
          metadata.autoScrapedAlbum ?? currentSong.autoScrapedAlbum,
      autoScrapedCoverUrl:
          metadata.autoScrapedCoverUrl ?? currentSong.autoScrapedCoverUrl,
      autoScrapedLocalCoverPath:
          metadata.autoScrapedLocalCoverPath ??
          currentSong.autoScrapedLocalCoverPath,
      autoScrapedLyrics:
          metadata.autoScrapedLyrics ?? currentSong.autoScrapedLyrics,
    );

    _playlist = List<LibrarySong>.unmodifiable([
      ..._playlist.sublist(0, _currentIndex),
      updatedSong,
      if (_currentIndex + 1 < _playlist.length)
        ..._playlist.sublist(_currentIndex + 1),
    ]);

    _applyScrapingMetadataToCurrentTrack(songId, metadata, syncState: false);

    final scrapedLyrics = _parseLyrics(updatedSong.displayLyrics);
    if (_lyrics.isEmpty && scrapedLyrics.isNotEmpty) {
      _lyrics = scrapedLyrics;
    }

    _syncState();
    unawaited(_persistSession());
    DebugLogger.success(
      'PlayerController._applyScrapingMetadataToCurrentSong',
      '已更新播放列表中的歌曲元数据: ${updatedSong.displayTitle}',
    );
  }

  /// 异步刮削当前播放的歌曲
  /// 不会阻塞播放流程，在后台执行
  Future<void> _scrapeCurrentSongAsync(LibrarySong song) async {
    try {
      DebugLogger.scraping(
        'PlayerController._scrapeCurrentSongAsync',
        '开始刮削歌曲: ${song.displayTitle}',
      );

      // 1. 检查缓存中是否已有此歌曲的刮削结果
      final cachedMetadata = IsarManager.getMetadata(song.id);
      if (cachedMetadata != null &&
          cachedMetadata.status == ScrapingStatus.completed) {
        DebugLogger.success(
          'PlayerController._scrapeCurrentSongAsync',
          '使用缓存的刮削结果: ${song.id}',
        );
        _applyScrapingMetadataToCurrentSong(song.id, cachedMetadata);
        return;
      }

      // 2. 执行刮削
      final entry = song.toRemoteEntry();
      final scrapedMetadata = await ref
          .read(scraperChainProvider)
          .scrape(entry);

      if (scrapedMetadata == null) {
        DebugLogger.warning(
          'PlayerController._scrapeCurrentSongAsync',
          '未找到刮削结果: ${song.displayTitle}',
        );
        return;
      }

      // 3. 保存到数据库 (IsarManager)
      final metadata = ScrapingMetadata(
        id: song.id,
        sourceId: song.sourceId,
        filePath: song.remotePath,
        filenameWithoutExt: song.fileName,
        originalFileName: song.fileName,
        manuallyScrapedTitle: null,
        manuallyScrapedArtist: null,
        manuallyScrapedAlbum: null,
        manuallyScrapedCoverUrl: null,
        manuallyScrapedLocalCoverPath: null,
        manuallyScrapedLyrics: null,
        manualScrapedAt: null,
        autoScrapedTitle: scrapedMetadata.title,
        autoScrapedArtist: scrapedMetadata.artist,
        autoScrapedAlbum: scrapedMetadata.album,
        autoScrapedCoverUrl: scrapedMetadata.coverUrl,
        autoScrapedLocalCoverPath: scrapedMetadata.localCoverPath,
        autoScrapedLyrics: scrapedMetadata.lyrics,
        autoScrapedAt: DateTime.now(),
        status: ScrapingStatus.completed,
        errorMessage: null,
        retryCount: 0,
      );

      await IsarManager.saveMetadata(metadata);
      DebugLogger.success(
        'PlayerController._scrapeCurrentSongAsync',
        '刮削完成并已保存到数据库: ${song.displayTitle}',
      );

      // 4. 如果当前播放的就是这首歌，立即更新播放器显示的元数据
      _applyScrapingMetadataToCurrentSong(song.id, metadata);

      // 5. 异步更新库列表中的歌曲（不等待，避免阻塞）
      // 使用控制器的增量更新方法，而不是 invalidate，避免列表消失
      try {
        final libraryCatalogNotifier = ref.read(
          libraryCatalogControllerProvider.notifier,
        );
        libraryCatalogNotifier.refreshSongMetadata(song.id);
        DebugLogger.info(
          'PlayerController._scrapeCurrentSongAsync',
          '✅ 已触发库列表元数据刷新: ${song.id}',
        );
      } catch (e) {
        DebugLogger.warning(
          'PlayerController._scrapeCurrentSongAsync',
          '更新库列表失败: $e',
        );
      }
    } catch (e) {
      DebugLogger.warning(
        'PlayerController._scrapeCurrentSongAsync',
        '刮削失败: $e',
      );
      // 不抛出异常，继续播放
    }
  }

  Future<void> _scrapeCurrentEntryAsync(RemoteEntry entry) async {
    try {
      DebugLogger.scraping(
        'PlayerController._scrapeCurrentEntryAsync',
        '开始刮削文件浏览器播放项: ${entry.name}',
      );

      final cachedMetadata = IsarManager.getMetadata(entry.uniqueId);
      if (cachedMetadata != null &&
          cachedMetadata.status == ScrapingStatus.completed) {
        DebugLogger.success(
          'PlayerController._scrapeCurrentEntryAsync',
          '使用缓存的刮削结果: ${entry.uniqueId}',
        );
        _applyScrapingMetadataToCurrentTrack(entry.uniqueId, cachedMetadata);
        return;
      }

      final scrapedMetadata = await ref
          .read(scraperChainProvider)
          .scrape(entry);
      if (scrapedMetadata == null) {
        DebugLogger.warning(
          'PlayerController._scrapeCurrentEntryAsync',
          '未找到刮削结果: ${entry.name}',
        );
        return;
      }

      final metadata = _buildCompletedScrapingMetadata(
        entry: entry,
        scrapedMetadata: scrapedMetadata,
      );
      await IsarManager.saveMetadata(metadata);
      _applyScrapingMetadataToCurrentTrack(entry.uniqueId, metadata);

      DebugLogger.success(
        'PlayerController._scrapeCurrentEntryAsync',
        '文件浏览器播放项刮削完成: ${entry.name}',
      );
    } catch (e) {
      DebugLogger.warning(
        'PlayerController._scrapeCurrentEntryAsync',
        '文件浏览器播放项刮削失败: $e',
      );
    }
  }
}
