import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import '../../../core/i18n/localizations.dart';
import '../../../core/audio/system_artwork.dart';
import '../../library/presentation/folder_artwork_provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/player_service.dart';
import '../../../core/audio/system_audio_handler.dart';
import '../../../core/database/isar_manager.dart';
import '../../../core/database/scraping_metadata.dart';
import '../../../core/models/app_preferences.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/playable_track.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/scraping_preferences.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/storage/cover_art_cache_manager.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../../core/storage/player_session_repository.dart';
import '../../../core/utils/audio_embedded_metadata_reader.dart';
import '../../../core/utils/chinese_text_localizer.dart';
import '../../../core/utils/debug_logger.dart';
import '../../settings/application/app_settings_controller.dart';
import '../../scraper/application/scraping_provider.dart' as scraping;
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

enum PlayerPlaybackMode { list, repeatOne, shuffle, repeatAll }

enum PlayerLyricsSource { none, sidecarFile, embeddedTag, scraped }

class CurrentRemoteTrackKey {
  const CurrentRemoteTrackKey({
    required this.sourceId,
    required this.remotePath,
  });

  final String sourceId;
  final String remotePath;

  @override
  bool operator ==(Object other) {
    return other is CurrentRemoteTrackKey &&
        other.sourceId == sourceId &&
        other.remotePath == remotePath;
  }

  @override
  int get hashCode => Object.hash(sourceId, remotePath);
}

final currentTrackIdProvider = Provider<String?>((ref) {
  return ref.watch(
    playerControllerProvider.select((state) => state.currentTrack?.id),
  );
});

final currentRemoteTrackKeyProvider = Provider<CurrentRemoteTrackKey?>((ref) {
  return ref.watch(
    playerControllerProvider.select((state) {
      final track = state.currentTrack;
      if (track == null) {
        return null;
      }
      return CurrentRemoteTrackKey(
        sourceId: track.sourceId,
        remotePath: track.remotePath,
      );
    }),
  );
});

final isCurrentTrackIdProvider = Provider.family<bool, String>((ref, trackId) {
  return ref.watch(currentTrackIdProvider) == trackId;
});

final isCurrentRemoteTrackProvider =
    Provider.family<bool, CurrentRemoteTrackKey>((ref, trackKey) {
      return ref.watch(currentRemoteTrackKeyProvider) == trackKey;
    });

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
    this.lyricsSource = PlayerLyricsSource.none,
    this.cacheSegments = const [],
    this.errorMessage,
    this.requestedTitle,
    this.requestedArtist,
    this.requestedSourceName,
    this.canRetry = false,
    this.isResolvingTrack = false,
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
  final PlayerLyricsSource lyricsSource;
  final List<CacheProgressSegment> cacheSegments;
  final String? errorMessage;
  final String? requestedTitle;
  final String? requestedArtist;
  final String? requestedSourceName;
  final bool canRetry;
  final bool isResolvingTrack;

  bool get hasTrack => currentTrack != null;

  bool get isBusy =>
      errorMessage == null &&
      (isResolvingTrack ||
          processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering);

  bool get hasPlaylist => playlist.isNotEmpty;

  int get playlistCount => playlist.length;

  bool get canPlayPrevious {
    if (playlist.isEmpty) {
      return false;
    }
    return switch (playbackMode) {
      PlayerPlaybackMode.list => currentIndex > 0,
      PlayerPlaybackMode.repeatOne ||
      PlayerPlaybackMode.repeatAll => currentIndex >= 0,
      PlayerPlaybackMode.shuffle => playlist.length > 1,
    };
  }

  bool get canPlayNext {
    if (playlist.isEmpty) {
      return false;
    }
    return switch (playbackMode) {
      PlayerPlaybackMode.list => currentIndex < playlist.length - 1,
      PlayerPlaybackMode.repeatOne ||
      PlayerPlaybackMode.repeatAll => currentIndex >= 0,
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
    PlayerLyricsSource lyricsSource = PlayerLyricsSource.none,
    String? errorMessage,
    String? requestedTitle,
    String? requestedArtist,
    String? requestedSourceName,
    bool canRetry = false,
    bool isResolvingTrack = false,
    Duration? positionOverride,
  }) {
    return PlayerViewState(
      currentTrack: service.currentTrack,
      isPlaying: service.player.playing,
      processingState: service.player.processingState,
      position: positionOverride ?? service.player.position,
      bufferedPosition: service.player.bufferedPosition,
      duration: service.player.duration,
      playlist: playlist,
      currentIndex: currentIndex,
      playbackMode: playbackMode,
      lyrics: lyrics,
      lyricsSource: lyricsSource,
      cacheSegments: cacheSegments,
      errorMessage: errorMessage,
      requestedTitle: requestedTitle,
      requestedArtist: requestedArtist,
      requestedSourceName: requestedSourceName,
      canRetry: canRetry,
      isResolvingTrack: isResolvingTrack,
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
      lyricsSource: PlayerLyricsSource.none,
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
  PlayerLyricsSource _lyricsSource = PlayerLyricsSource.none;
  List<LibrarySong> _playlist = const [];
  int _currentIndex = -1;
  PlayerPlaybackMode _playbackMode = PlayerPlaybackMode.list;
  final math.Random _random = math.Random();
  bool _handlingCompletion = false;
  bool _restoreStarted = false;
  DateTime _lastPositionPersistedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastProgressStateSyncedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _progressSyncTimer;
  int _playRequestSerial = 0;
  int _pauseSerial = 0;
  int _playlistRevision = 0;
  String? _lastSystemQueueKey;
  String? _systemArtworkKey;
  bool _disposed = false;
  String? _playbackError;
  LibrarySong? _requestedSong;
  SourceProfile? _requestedProfile;
  RemoteEntry? _requestedEntry;
  bool _isResolvingTrack = false;
  bool _playWhenReady = false;
  Duration _targetPosition = Duration.zero;
  String? _lastSystemCurrentItemKey = '__uninitialized__';
  final Set<String> _inFlightAutoScrapeSongIds = <String>{};

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
    if (isSystemAudioHandlerInitialized) {
      systemAudioHandler.bindCallbacks(
        onSetRepeatMode: (mode) async => setPlaybackMode(switch (mode) {
          AudioServiceRepeatMode.one => PlayerPlaybackMode.repeatOne,
          AudioServiceRepeatMode.all ||
          AudioServiceRepeatMode.group => PlayerPlaybackMode.repeatAll,
          _ => PlayerPlaybackMode.list,
        }),
        onSetShuffleMode: (mode) async => setPlaybackMode(
          mode == AudioServiceShuffleMode.none
              ? PlayerPlaybackMode.list
              : PlayerPlaybackMode.shuffle,
        ),
        onSetFavorite: _setSystemFavorite,
        onCyclePlaybackMode: () async => cyclePlaybackMode(),
        onPlay: play,
        onPause: pause,
        onStop: stop,
        onSkipToNext: playNext,
        onSkipToPrevious: playPrevious,
        onSeek: seek,
        onSkipToQueueItem: playPlaylistIndex,
      );
    }
    _bindStreams();
    _restorePersistedSession();
    ref.listen(
      libraryCatalogControllerProvider.select(
        (value) => value.valueOrNull?.favoriteTrackIds,
      ),
      (_, _) {
        _syncSystemAudioState(state, force: true);
      },
    );
    ref.onDispose(() {
      _disposed = true;
      ++_playRequestSerial;
      _playbackCache.setActivePlaybackTrack(null);
      _disposeSubscriptions();
    });
    return PlayerViewState.fromService(
      _service,
      playlist: _playlist,
      currentIndex: _currentIndex,
      playbackMode: _playbackMode,
      lyricsSource: _lyricsSource,
    );
  }

  Future<void> playEntry({
    required SourceProfile profile,
    required RemoteEntry entry,
    Duration initialPosition = Duration.zero,
  }) async {
    final requestSerial = _beginPlaybackRequest(
      profile: profile,
      entry: entry,
      initialPosition: initialPosition,
    );
    _replacePlaylist(const [], currentIndex: -1);
    try {
      unawaited(_sessionRepository.clear());
      final stopped = _service.stop();
      _syncState();
      await stopped;
      if (!_isCurrentRequest(requestSerial)) return;
      await _playRemoteEntry(
        profile: profile,
        entry: entry,
        requestSerial: requestSerial,
        onTrackStarted: () => _scheduleAutoScrapeForEntry(entry),
      );
    } catch (error) {
      _recordPlaybackFailure(requestSerial, error);
    }
  }

  Future<void> playLibrarySong(
    LibrarySong song, {
    List<LibrarySong>? playlist,
  }) async {
    final nextPlaylist = _playlistForSong(song, playlist);
    final nextIndex = nextPlaylist.indexWhere((item) => item.id == song.id);
    _replacePlaylist(nextPlaylist, currentIndex: nextIndex);
    await _playQueueIndex(nextIndex);
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
      final requestSerial = ++_playRequestSerial;
      _isResolvingTrack = false;
      _playbackError = null;
      _requestedSong = null;
      _requestedProfile = null;
      _requestedEntry = null;
      _playbackCache.setActivePlaybackTrack(null);
      _clearLyrics();
      _replacePlaylist(const [], currentIndex: -1);
      final stopped = _service.stop();
      final cleared = _sessionRepository.clear();
      await stopped;
      await cleared;
      if (!_isCurrentRequest(requestSerial)) return;
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

  Future<void> reorderPlaylist(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _playlist.length ||
        newIndex < 0 ||
        newIndex > _playlist.length) {
      return;
    }
    if (oldIndex == newIndex || oldIndex + 1 == newIndex) {
      return;
    }

    final currentSongId =
        (_currentIndex >= 0 && _currentIndex < _playlist.length)
        ? _playlist[_currentIndex].id
        : null;
    final nextPlaylist = List<LibrarySong>.of(_playlist);
    final moved = nextPlaylist.removeAt(oldIndex);
    final insertIndex = oldIndex < newIndex ? newIndex - 1 : newIndex;
    nextPlaylist.insert(insertIndex, moved);

    final nextCurrentIndex = currentSongId == null
        ? -1
        : nextPlaylist.indexWhere((song) => song.id == currentSongId);
    _replacePlaylist(nextPlaylist, currentIndex: nextCurrentIndex);
    unawaited(_persistSession());
  }

  void refreshSongMetadata(String songId) {
    if (songId.trim().isEmpty) {
      return;
    }
    final metadata = IsarManager.getMetadata(songId);
    if (metadata == null || !_hasSavedScrapingData(metadata)) {
      return;
    }
    _applyScrapingMetadataToCurrentSong(songId, metadata);
  }

  void cyclePlaybackMode() {
    _playbackMode = switch (_playbackMode) {
      PlayerPlaybackMode.list => PlayerPlaybackMode.shuffle,
      PlayerPlaybackMode.shuffle => PlayerPlaybackMode.repeatOne,
      PlayerPlaybackMode.repeatOne => PlayerPlaybackMode.repeatAll,
      PlayerPlaybackMode.repeatAll => PlayerPlaybackMode.list,
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
    if (_playbackError != null) {
      await play();
    } else if (_service.isPlaying || _isResolvingTrack) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (_isResolvingTrack) return;
    final retry = _playbackError != null;
    if (_service.currentTrack == null || retry) {
      final initialPosition = _targetPosition;
      final profile = _requestedProfile;
      final entry = _requestedEntry;
      if (_requestedSong == null && profile != null && entry != null) {
        await playEntry(
          profile: profile,
          entry: entry,
          initialPosition: initialPosition,
        );
        return;
      }
      if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
        await _playQueueIndex(_currentIndex, initialPosition: initialPosition);
      }
      return;
    }
    if (_service.isPlaying) return;
    final requestSerial = _playRequestSerial;
    try {
      await _service.play();
      if (!_isCurrentRequest(requestSerial)) return;
      _scheduleAutoScrapeForCurrentTrack();
      _syncState();
      unawaited(_persistSession());
    } catch (error) {
      _recordPlaybackFailure(requestSerial, error);
    }
  }

  Future<void> pause() async {
    ++_pauseSerial;
    if (_isResolvingTrack) {
      await stop();
      return;
    }
    if (!_service.isPlaying) {
      return;
    }
    final requestSerial = _playRequestSerial;
    try {
      await _service.pause();
      if (!_isCurrentRequest(requestSerial)) return;
      _syncState();
      unawaited(_persistSession());
    } catch (error) {
      _recordPlaybackFailure(requestSerial, error);
    }
  }

  Future<void> seek(Duration position) async {
    final requestSerial = _playRequestSerial;
    try {
      await _service.seek(position);
      if (!_isCurrentRequest(requestSerial)) return;
      _targetPosition = position;
      _syncState(forceSystem: true);
      unawaited(_persistSession(positionOverride: position));
    } catch (error) {
      _recordPlaybackFailure(requestSerial, error);
    }
  }

  Future<void> seekAndPlay(Duration position) async {
    final requestSerial = _playRequestSerial;
    final pauseSerial = _pauseSerial;
    try {
      await _service.seek(position);
      if (!_isCurrentRequest(requestSerial) || pauseSerial != _pauseSerial) {
        return;
      }
      _targetPosition = position;
      if (!_service.isPlaying) await _service.play();
      if (!_isCurrentRequest(requestSerial)) return;
      _scheduleAutoScrapeForCurrentTrack();
      _syncState(forceSystem: true);
      unawaited(_persistSession(positionOverride: position));
    } catch (error) {
      _recordPlaybackFailure(requestSerial, error);
    }
  }

  Future<void> stop() async {
    final requestSerial = ++_playRequestSerial;
    if (!_isResolvingTrack &&
        _playbackError == null &&
        _service.currentTrack != null) {
      _targetPosition = _service.position;
    }
    _isResolvingTrack = false;
    _playbackError = null;
    _playbackCache.setActivePlaybackTrack(null);
    _clearLyrics();
    try {
      final stopped = _service.stop();
      _syncState();
      await stopped;
      if (!_isCurrentRequest(requestSerial)) return;
      _syncState();
      unawaited(_persistSession());
    } catch (error) {
      _recordPlaybackFailure(requestSerial, error);
    }
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
      _syncProgressStateThrottled();
      _persistPositionThrottled();
    });
    _bufferedPositionSubscription ??= _service.bufferedPositionStream.listen((
      _,
    ) {
      _syncProgressStateThrottled();
    });
    _durationSubscription ??= _service.durationStream.listen((_) {
      _syncState();
    });
    _errorSubscription ??= _service.errorStream.listen((error) {
      if (_service.currentTrack == null) return;
      _recordPlaybackFailure(_playRequestSerial, error);
    });
    _cacheSubscription ??= _playbackCache.snapshotStream.listen((snapshot) {
      final currentTrack = _service.currentTrack;
      if (currentTrack != null && currentTrack.id == snapshot.trackId) {
        _syncState();
      }
    });
  }

  void _syncState({String? errorMessage, bool forceSystem = false}) {
    if (_disposed) return;
    _playbackError = errorMessage ?? _playbackError;
    // Loading and error events can reset the engine's reported position.
    if (_playbackError == null &&
        !_isResolvingTrack &&
        _service.currentTrack != null &&
        _service.currentTrack?.id == _requestedEntry?.uniqueId) {
      _targetPosition = _service.position;
    }
    _progressSyncTimer?.cancel();
    _progressSyncTimer = null;
    _lastProgressStateSyncedAt = DateTime.now();
    final nextState = PlayerViewState.fromService(
      _service,
      lyrics: _lyrics,
      lyricsSource: _lyricsSource,
      cacheSegments: _resolveCacheSegments(_service.currentTrack),
      playlist: _playlist,
      currentIndex: _currentIndex,
      playbackMode: _playbackMode,
      errorMessage: _playbackError,
      requestedTitle: _requestedSong?.displayTitle ?? _requestedEntry?.title,
      requestedArtist: _requestedSong?.displayArtist,
      requestedSourceName:
          _requestedSong?.sourceName ?? _requestedProfile?.name,
      canRetry:
          _playbackError != null &&
          (_requestedSong != null || _requestedEntry != null),
      isResolvingTrack: _isResolvingTrack,
      positionOverride: _isResolvingTrack || _playbackError != null
          ? _targetPosition
          : null,
    );
    state = nextState;
    _syncSystemAudioState(nextState, force: forceSystem);
  }

  void _syncProgressStateThrottled() {
    const minProgressSyncInterval = Duration(milliseconds: 250);
    final now = DateTime.now();
    final elapsed = now.difference(_lastProgressStateSyncedAt);
    if (elapsed >= minProgressSyncInterval) {
      _syncState();
      return;
    }

    _progressSyncTimer ??= Timer(minProgressSyncInterval - elapsed, () {
      _progressSyncTimer = null;
      _syncState();
    });
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
    _progressSyncTimer?.cancel();
    _progressSyncTimer = null;

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

  int _beginPlaybackRequest({
    LibrarySong? song,
    SourceProfile? profile,
    required RemoteEntry entry,
    Duration initialPosition = Duration.zero,
    bool playWhenReady = true,
  }) {
    final requestSerial = ++_playRequestSerial;
    _requestedSong = song;
    _requestedProfile = profile;
    _requestedEntry = entry;
    _isResolvingTrack = true;
    _playWhenReady = playWhenReady;
    _targetPosition = initialPosition;
    _playbackError = null;
    _handlingCompletion = false;
    _clearLyrics();
    _playbackCache.setActivePlaybackTrack(song?.id ?? entry.uniqueId);
    return requestSerial;
  }

  bool _isCurrentRequest(int requestSerial) =>
      !_disposed && requestSerial == _playRequestSerial;

  void _recordPlaybackFailure(int requestSerial, Object error) {
    if (!_isCurrentRequest(requestSerial)) return;
    _isResolvingTrack = false;
    _syncState(errorMessage: error.toString());
  }

  Future<void> _playRemoteEntry({
    required SourceProfile profile,
    required RemoteEntry entry,
    required int requestSerial,
    void Function()? onTrackStarted,
  }) async {
    if (!_isCurrentRequest(requestSerial)) return;
    _syncState();

    final source = await ref
        .read(musicSourceSessionManagerProvider)
        .get(profile);
    if (!_isCurrentRequest(requestSerial)) return;

    final builtTrack = await source.buildPlayableTrack(entry);
    if (!_isCurrentRequest(requestSerial)) return;
    final track = _enhanceTrackWithCachedScraping(
      builtTrack,
      metadataId: entry.uniqueId,
    );
    final scrapedLyrics = _parseLyrics(track.displayLyrics);
    if (scrapedLyrics.isNotEmpty) {
      _setLyrics(
        scrapedLyrics,
        _resolveStoredLyricsSource(
          entry.uniqueId,
          rawLyrics: track.displayLyrics,
        ),
      );
    }

    final playFuture = _service.playTrack(
      track,
      initialPosition: _targetPosition,
    );
    _syncState();
    onTrackStarted?.call();
    await playFuture;
    if (!_isCurrentRequest(requestSerial)) return;
    _isResolvingTrack = false;
    _syncState();
    unawaited(_persistSession());

    unawaited(_loadSidecarLyrics(source, entry.path, track.id, requestSerial));
  }

  Future<void> _playQueueIndex(
    int index, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (index < 0 || index >= _playlist.length) {
      return;
    }

    final song = _playlist[index];
    final entry = song.toRemoteEntry();
    final requestSerial = _beginPlaybackRequest(
      song: song,
      entry: entry,
      initialPosition: initialPosition,
    );
    _currentIndex = index;
    try {
      final stopped = _service.stop();
      _syncState();
      await stopped;
      if (!_isCurrentRequest(requestSerial)) return;
      final profile = await _profileForSong(song);
      if (!_isCurrentRequest(requestSerial)) return;
      _requestedProfile = profile;
      await _playRemoteEntry(
        profile: profile,
        entry: entry,
        requestSerial: requestSerial,
        onTrackStarted: () => _scheduleAutoScrapeForSong(song),
      );
    } catch (error) {
      _recordPlaybackFailure(requestSerial, error);
    }
  }

  Future<void> _loadQueueIndex(
    int index, {
    Duration initialPosition = Duration.zero,
  }) async {
    if (index < 0 || index >= _playlist.length) return;
    final song = _playlist[index];
    final requestSerial = _beginPlaybackRequest(
      song: song,
      entry: song.toRemoteEntry(),
      playWhenReady: false,
    );
    _targetPosition = initialPosition;
    _currentIndex = index;
    try {
      await _loadQueueSong(
        song,
        requestSerial,
        initialPosition: initialPosition,
      );
    } catch (error) {
      _recordPlaybackFailure(requestSerial, error);
    }
  }

  Future<void> _loadQueueSong(
    LibrarySong song,
    int requestSerial, {
    Duration initialPosition = Duration.zero,
  }) async {
    final stopped = _service.stop();
    _syncState();
    await stopped;
    if (!_isCurrentRequest(requestSerial)) return;
    _syncState();

    // 尝试从数据库加载已刮削的元数据
    var displaySong = song;
    try {
      final scrapingMetadata = IsarManager.getMetadata(song.id);
      if (scrapingMetadata != null && _hasSavedScrapingData(scrapingMetadata)) {
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
    if (!_isCurrentRequest(requestSerial)) return;
    _requestedProfile = profile;
    final source = await ref
        .read(musicSourceSessionManagerProvider)
        .get(profile);
    if (!_isCurrentRequest(requestSerial)) return;
    final track = await source.buildPlayableTrack(song.toRemoteEntry());
    if (!_isCurrentRequest(requestSerial)) return;

    // 应用已刮削的元数据到播放轨道
    final enhancedTrack = PlayableTrack(
      id: track.id,
      sourceId: track.sourceId,
      title: displaySong.title,
      sourceName: track.sourceName,
      remotePath: track.remotePath,
      audioSource: track.audioSource,
      sourceSizeBytes: track.sourceSizeBytes,
      artistName: displaySong.artistName,
      albumTitle: displaySong.albumTitle,
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
      _setLyrics(
        scrapedLyrics,
        _resolveStoredLyricsSource(
          song.id,
          rawLyrics: enhancedTrack.displayLyrics,
        ),
      );
    }
    await _service.loadTrack(enhancedTrack, initialPosition: initialPosition);
    if (!_isCurrentRequest(requestSerial)) return;
    _isResolvingTrack = false;
    _syncState();
    unawaited(_persistSession(positionOverride: initialPosition));

    unawaited(
      _loadSidecarLyrics(
        source,
        song.remotePath,
        enhancedTrack.id,
        requestSerial,
      ),
    );
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
    final restoreSerial = _playRequestSerial;
    try {
      final snapshot = await _sessionRepository.load();
      if (snapshot == null ||
          !snapshot.hasCurrentSong ||
          !_isCurrentRequest(restoreSerial) ||
          _playlist.isNotEmpty) {
        return;
      }

      _playlist = List<LibrarySong>.unmodifiable(snapshot.playlist);
      _playlistRevision++;
      _currentIndex = snapshot.currentIndex;
      _playbackMode = _playbackModeFromStorage(snapshot.playbackMode);
      _syncState();

      if (!_isCurrentRequest(restoreSerial)) {
        return;
      }
      await _loadQueueIndex(
        snapshot.currentIndex,
        initialPosition: snapshot.position,
      );
    } catch (error) {
      _recordPlaybackFailure(restoreSerial, error);
    }
  }

  Future<void> _handleTrackCompleted() async {
    if (_handlingCompletion ||
        _isResolvingTrack ||
        _service.currentTrack == null) {
      return;
    }

    _handlingCompletion = true;
    final requestSerial = _playRequestSerial;
    try {
      if (_playbackMode == PlayerPlaybackMode.repeatOne && _playlist.isEmpty) {
        await _service.replayCurrent();
        if (!_isCurrentRequest(requestSerial)) return;
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
      _recordPlaybackFailure(requestSerial, error);
    }
  }

  List<LibrarySong> _playlistForSong(
    LibrarySong song,
    List<LibrarySong>? playlist,
  ) {
    if (playlist == null || playlist.isEmpty) {
      return [song];
    }
    final songIndex = playlist.indexWhere((item) => item.id == song.id);
    if (songIndex != -1) {
      return playlist;
    }

    final nextPlaylist = List<LibrarySong>.of(playlist);
    nextPlaylist.insert(0, song);
    return nextPlaylist;
  }

  void _replacePlaylist(
    List<LibrarySong> playlist, {
    required int currentIndex,
  }) {
    _playlist = List<LibrarySong>.unmodifiable(playlist);
    _playlistRevision++;
    _currentIndex = currentIndex >= 0 && currentIndex < _playlist.length
        ? currentIndex
        : -1;
    _syncState();
  }

  void _syncSystemAudioState(PlayerViewState nextState, {bool force = false}) {
    if (!isSystemAudioHandlerInitialized) {
      return;
    }
    final retryEntry =
        nextState.currentTrack == null &&
            (nextState.canRetry || nextState.isResolvingTrack)
        ? _requestedEntry
        : null;
    final currentSong =
        nextState.currentTrack != null &&
            nextState.hasPlaylist &&
            nextState.currentIndex >= 0 &&
            nextState.currentIndex < nextState.playlistCount &&
            nextState.playlist[nextState.currentIndex].id ==
                nextState.currentTrack?.id
        ? nextState.playlist[nextState.currentIndex]
        : retryEntry != null
        ? _requestedSong
        : null;
    final currentTrack = nextState.currentTrack;
    final currentItemId =
        currentSong?.id ?? currentTrack?.id ?? retryEntry?.uniqueId;
    final currentItemTitle = _firstNonEmpty(
      currentSong?.displayTitle,
      currentTrack?.displayTitle,
      currentTrack?.title ?? retryEntry?.title,
    );
    final currentItemArtist = _firstNonEmpty(
      currentSong?.displayArtist,
      currentTrack?.displayArtist,
    );
    final currentItemAlbum = _firstNonEmpty(
      currentSong?.displayAlbum,
      currentTrack?.displayAlbum,
    );
    final currentItemLocalCover = _firstNonEmpty(
      currentSong?.displayLocalCoverPath,
      currentTrack?.localCoverPath,
    );
    final currentItemRemoteCover = _firstNonEmpty(
      currentSong?.displayCoverUrl,
      currentTrack?.autoScrapedCoverUrl,
    );
    final currentDuration = currentTrack == null ? null : nextState.duration;
    final currentItemDurationMs = currentDuration?.inMilliseconds;
    final queueKey = _playlistRevision.toString();
    final currentItemKey = currentItemId == null
        ? null
        : [
            currentItemId,
            currentItemTitle,
            currentItemArtist,
            currentItemAlbum,
            currentItemLocalCover,
            currentItemRemoteCover,
            currentItemDurationMs,
            nextState.currentIndex,
          ].join('|');
    if (_lastSystemQueueKey != queueKey) {
      _lastSystemQueueKey = queueKey;
      unawaited(_publishSystemQueue(nextState, queueKey));
    }
    if (_lastSystemCurrentItemKey != currentItemKey) {
      force = true;
      _lastSystemCurrentItemKey = currentItemKey;
      final mediaItem = currentItemId == null
          ? null
          : _mediaItemForCurrent(
              id: currentItemId,
              song: currentSong,
              track: currentTrack,
              duration: currentDuration,
              entry: retryEntry,
              profile: retryEntry == null ? null : _requestedProfile,
            );
      systemAudioHandler.updateCurrentItem(mediaItem);
      _systemArtworkKey = currentItemKey;
      if (mediaItem != null) {
        unawaited(
          _resolveSystemArtwork(
            currentItemKey!,
            mediaItem,
            currentSong,
            currentTrack,
          ),
        );
      }
    }

    final locale =
        AppDisplayPreferences.localeFor(_localePreference) ??
        WidgetsBinding.instance.platformDispatcher.locale;
    final l10n = lookupAppLocalizations(
      Locale(locale.languageCode == 'zh' ? 'zh' : 'en'),
    );
    final favorite =
        ref
            .read(libraryCatalogControllerProvider)
            .valueOrNull
            ?.favoriteTrackIds
            .contains(currentItemId) ??
        false;
    systemAudioHandler.updateState(
      favoriteLabel: favorite
          ? l10n.removeFromFavoritesAction
          : l10n.addToFavoritesAction,
      playbackModeLabel: switch (nextState.playbackMode) {
        PlayerPlaybackMode.list => l10n.playbackModeList,
        PlayerPlaybackMode.repeatOne => l10n.playbackModeRepeatOne,
        PlayerPlaybackMode.repeatAll => l10n.playbackModeRepeatAll,
        PlayerPlaybackMode.shuffle => l10n.playbackModeShuffle,
      },
      force: force,
      repeatMode: switch (nextState.playbackMode) {
        PlayerPlaybackMode.repeatOne => AudioServiceRepeatMode.one,
        PlayerPlaybackMode.repeatAll => AudioServiceRepeatMode.all,
        _ => AudioServiceRepeatMode.none,
      },
      shuffleMode: nextState.playbackMode == PlayerPlaybackMode.shuffle
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      isFavorite:
          ref
              .read(libraryCatalogControllerProvider)
              .valueOrNull
              ?.favoriteTrackIds
              .contains(currentItemId) ??
          false,
      errorMessage: nextState.errorMessage,
      // Keep hardware pause/click routed to a user-requested pending play.
      playing: nextState.isPlaying || (_isResolvingTrack && _playWhenReady),
      processingState: nextState.isResolvingTrack
          ? AudioProcessingState.loading
          : _audioProcessingState(nextState.processingState),
      position: currentTrack == null ? _targetPosition : nextState.position,
      bufferedPosition: currentTrack == null
          ? Duration.zero
          : nextState.bufferedPosition,
      speed: 1.0,
      queueIndex: nextState.currentIndex >= 0 ? nextState.currentIndex : null,
      canSkipToPrevious: nextState.canPlayPrevious,
      canSkipToNext: nextState.canPlayNext,
      canSeek: currentDuration != null && currentDuration > Duration.zero,
      hasQueue: currentItemId != null,
    );
  }

  Future<void> _publishSystemQueue(PlayerViewState snapshot, String key) async {
    final items = <MediaItem>[];
    for (var index = 0; index < snapshot.playlist.length; index++) {
      if (_disposed || _lastSystemQueueKey != key) return;
      items.add(
        _mediaItemForSong(
          snapshot.playlist[index],
          duration: index == snapshot.currentIndex ? snapshot.duration : null,
        ),
      );
      if (index % 64 == 63) await Future<void>.delayed(Duration.zero);
    }
    if (!_disposed && _lastSystemQueueKey == key) {
      await systemAudioHandler.updateQueue(items);
    }
  }

  MediaItem _mediaItemForSong(LibrarySong song, {Duration? duration}) {
    final title = _firstNonEmpty(song.displayTitle, song.title) ?? song.title;
    final artist = _firstNonEmpty(song.displayArtist, song.sourceName);
    final album = _firstNonEmpty(song.displayAlbum, song.folderAlbumTitle);
    final artUri = _artUriForSong(song);
    return MediaItem(
      id: song.id,
      title: title,
      album: album,
      artist: artist,
      duration: _positiveDuration(duration),
      artUri: artUri,
      displayTitle: title,
      displaySubtitle: _mediaSubtitle(artist: artist, album: album),
      displayDescription: song.sourceName,
      extras: _mediaExtras(
        sourceId: song.sourceId,
        sourceName: song.sourceName,
        remotePath: song.remotePath,
        fileName: song.fileName,
        sizeBytes: song.size,
        localCoverPath: song.displayLocalCoverPath,
        coverUrl: song.displayCoverUrl,
        artUri: artUri,
      ),
    );
  }

  MediaItem _mediaItemForCurrent({
    required String id,
    required LibrarySong? song,
    required PlayableTrack? track,
    required Duration? duration,
    RemoteEntry? entry,
    SourceProfile? profile,
  }) {
    final title =
        _firstNonEmpty(
          song?.displayTitle,
          track?.displayTitle,
          track?.title ?? entry?.title,
        ) ??
        '';
    final artist = _firstNonEmpty(song?.displayArtist, track?.displayArtist);
    final album = _firstNonEmpty(song?.displayAlbum, track?.displayAlbum);
    final sourceName = _firstNonEmpty(
      song?.sourceName,
      track?.sourceName,
      profile?.name,
    );
    final remotePath = _firstNonEmpty(
      song?.remotePath,
      track?.remotePath,
      entry?.path,
    );
    final localCoverPath = _firstNonEmpty(
      song?.displayLocalCoverPath,
      track?.localCoverPath,
    );
    final coverUrl = _firstNonEmpty(
      song?.displayCoverUrl,
      track?.autoScrapedCoverUrl,
    );
    const Uri? artUri = null;
    return MediaItem(
      id: id,
      title: title,
      album: album,
      artist: artist,
      duration: _positiveDuration(duration),
      artUri: artUri,
      displayTitle: title,
      displaySubtitle: _mediaSubtitle(artist: artist, album: album),
      displayDescription: sourceName,
      extras: _mediaExtras(
        sourceId: _firstNonEmpty(
          song?.sourceId,
          track?.sourceId,
          entry?.sourceId,
        ),
        sourceName: sourceName,
        remotePath: remotePath,
        fileName: song?.fileName ?? entry?.name,
        sizeBytes: song?.size ?? track?.sourceSizeBytes ?? entry?.size,
        localCoverPath: localCoverPath,
        coverUrl: coverUrl,
        artUri: artUri,
      ),
    );
  }

  Map<String, dynamic> _mediaExtras({
    String? sourceId,
    String? sourceName,
    String? remotePath,
    String? fileName,
    int? sizeBytes,
    String? localCoverPath,
    String? coverUrl,
    Uri? artUri,
  }) {
    final extras = <String, dynamic>{};
    void addText(String key, String? value) {
      if (_hasText(value)) {
        extras[key] = value!.trim();
      }
    }

    addText('sourceId', sourceId);
    addText('sourceName', sourceName);
    if (sizeBytes != null && sizeBytes > 0) {
      extras['sizeBytes'] = sizeBytes;
    }
    return extras;
  }

  String? _mediaSubtitle({String? artist, String? album}) {
    final cleanArtist = _firstNonEmpty(artist);
    final cleanAlbum = _firstNonEmpty(album);
    if (cleanArtist == null) {
      return cleanAlbum;
    }
    if (cleanAlbum == null || cleanAlbum == cleanArtist) {
      return cleanArtist;
    }
    return '$cleanArtist • $cleanAlbum';
  }

  Duration? _positiveDuration(Duration? duration) =>
      duration != null && duration > Duration.zero ? duration : null;

  AudioProcessingState _audioProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  Future<void> _setSystemFavorite(bool favorite) async {
    final song = _currentIndex >= 0 && _currentIndex < _playlist.length
        ? _playlist[_currentIndex]
        : null;
    if (song == null) return;
    final catalog = ref.read(libraryCatalogControllerProvider).valueOrNull;
    if (catalog != null &&
        catalog.favoriteTrackIds.contains(song.id) != favorite) {
      await ref
          .read(libraryCatalogControllerProvider.notifier)
          .toggleFavorite(song.id);
    }
  }

  Future<void> _resolveSystemArtwork(
    String key,
    MediaItem item,
    LibrarySong? song,
    PlayableTrack? track,
  ) async {
    final requestSerial = _playRequestSerial;
    Uri? artwork;
    try {
      artwork = await resolveSystemArtwork(
        localPath: _firstNonEmpty(
          song?.displayLocalCoverPath,
          track?.localCoverPath,
        ),
        remoteUrl: _firstNonEmpty(
          song?.displayCoverUrl,
          track?.autoScrapedCoverUrl,
        ),
      );
      if (!_isCurrentRequest(requestSerial) ||
          _systemArtworkKey != key ||
          systemAudioHandler.mediaItem.value?.id != item.id) {
        return;
      }
      if (artwork == null &&
          !_disposed &&
          ref
                  .read(appSettingsControllerProvider)
                  .valueOrNull
                  ?.enableFolderArtworkForSongs ==
              true &&
          song != null) {
        final folder = await resolveFolderArtwork(
          ref,
          FolderArtworkRequest(
            sourceId: song.sourceId,
            directoryPath: song.directoryPath,
          ),
        );
        artwork = await resolveSystemArtwork(localPath: folder?.localPath);
      }
    } catch (_) {
      // Network artwork failure must not interrupt playback.
    }
    artwork ??= await defaultSystemArtwork();
    if (_isCurrentRequest(requestSerial) &&
        _systemArtworkKey == key &&
        systemAudioHandler.mediaItem.value?.id == item.id &&
        artwork != null) {
      systemAudioHandler.updateCurrentItem(item.copyWith(artUri: artwork));
    }
  }

  Uri? _artUriForSong(LibrarySong song) {
    final localPath = _firstNonEmpty(song.displayLocalCoverPath);
    if (_hasText(localPath)) {
      return Uri.file(localPath!);
    }

    return null;
  }

  bool _hasText(String? value) => value?.trim().isNotEmpty == true;

  int? _resolveNextIndex() {
    if (_playlist.isEmpty) {
      return null;
    }

    return switch (_playbackMode) {
      PlayerPlaybackMode.repeatOne => _currentIndex >= 0 ? _currentIndex : 0,
      PlayerPlaybackMode.shuffle => _randomQueueIndex(),
      PlayerPlaybackMode.repeatAll => (_currentIndex + 1) % _playlist.length,
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
      PlayerPlaybackMode.repeatAll =>
        (_currentIndex - 1 + _playlist.length) % _playlist.length,
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
        position:
            positionOverride ??
            (!_isResolvingTrack &&
                    _playbackError == null &&
                    _service.currentTrack?.id == _playlist[_currentIndex].id
                ? _service.position
                : _targetPosition),
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

  Future<void> _loadSidecarLyrics(
    MusicSource source,
    String remotePath,
    String trackId,
    int requestSerial,
  ) async {
    final lyrics = await _loadLyrics(source, remotePath);
    if (!_isCurrentRequest(requestSerial) ||
        _service.currentTrack?.id != trackId ||
        lyrics.isEmpty) {
      return;
    }
    _setLyrics(lyrics, PlayerLyricsSource.sidecarFile);
    _syncState();
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
      if (metadata == null || !_hasSavedScrapingData(metadata)) {
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
        artistName: track.artistName,
        albumTitle: track.albumTitle,
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

  String? _firstNonEmpty(String? first, [String? second, String? third]) {
    for (final value in [first, second, third]) {
      if (value?.trim().isNotEmpty == true) {
        return value!.trim();
      }
    }
    return null;
  }

  void _clearLyrics() {
    _lyrics = const [];
    _lyricsSource = PlayerLyricsSource.none;
  }

  void _setLyrics(List<LyricLine> lyrics, PlayerLyricsSource source) {
    _lyrics = lyrics;
    _lyricsSource = lyrics.isEmpty ? PlayerLyricsSource.none : source;
  }

  PlayerLyricsSource _resolveStoredLyricsSource(
    String trackId, {
    String? rawLyrics,
  }) {
    final metadata = IsarManager.getMetadata(trackId);
    return _resolveLyricsSourceFromMetadata(metadata, rawLyrics: rawLyrics);
  }

  PlayerLyricsSource _resolveLyricsSourceFromMetadata(
    ScrapingMetadata? metadata, {
    String? rawLyrics,
  }) {
    final normalizedLyrics = rawLyrics?.trim();
    if (normalizedLyrics == null || normalizedLyrics.isEmpty) {
      return PlayerLyricsSource.none;
    }

    if (_sameNormalizedText(
      metadata?.manuallyScrapedLyrics,
      normalizedLyrics,
    )) {
      return PlayerLyricsSource.scraped;
    }

    if (_sameNormalizedText(metadata?.autoScrapedLyrics, normalizedLyrics)) {
      return switch (metadata?.autoScrapedLyricsSource) {
        'embedded' => PlayerLyricsSource.embeddedTag,
        'scraped' => PlayerLyricsSource.scraped,
        _ =>
          metadata?.embeddedMetadataReadAt != null
              ? PlayerLyricsSource.embeddedTag
              : PlayerLyricsSource.scraped,
      };
    }

    if (metadata?.embeddedMetadataReadAt != null) {
      return PlayerLyricsSource.embeddedTag;
    }
    return PlayerLyricsSource.scraped;
  }

  bool _sameNormalizedText(String? left, String? right) {
    final normalizedLeft = left?.trim();
    final normalizedRight = right?.trim();
    return normalizedLeft != null &&
        normalizedLeft.isNotEmpty &&
        normalizedLeft == normalizedRight;
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
      artistName: currentTrack.artistName,
      albumTitle: currentTrack.albumTitle,
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
    if (scrapedLyrics.isNotEmpty) {
      _setLyrics(
        scrapedLyrics,
        _resolveLyricsSourceFromMetadata(
          metadata,
          rawLyrics: updatedTrack.displayLyrics,
        ),
      );
    }

    if (syncState) {
      _syncState();
      unawaited(_persistSession());
    }
  }

  void _applyScrapingMetadataToCurrentSong(
    String songId,
    ScrapingMetadata metadata,
  ) {
    final songIndex = _playlist.indexWhere((song) => song.id == songId);
    if (songIndex < 0) {
      return;
    }

    final currentSong = _playlist[songIndex];

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

    final nextPlaylist = List<LibrarySong>.of(_playlist);
    nextPlaylist[songIndex] = updatedSong;
    _playlist = List<LibrarySong>.unmodifiable(nextPlaylist);
    _playlistRevision++;

    _applyScrapingMetadataToCurrentTrack(songId, metadata, syncState: false);

    final scrapedLyrics = _parseLyrics(updatedSong.displayLyrics);
    if (_service.currentTrack?.id == songId && scrapedLyrics.isNotEmpty) {
      _setLyrics(
        scrapedLyrics,
        _resolveLyricsSourceFromMetadata(
          metadata,
          rawLyrics: updatedSong.displayLyrics,
        ),
      );
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
    final requestSerial = _playRequestSerial;
    final currentTrackAtStart = _service.currentTrack;
    if (currentTrackAtStart == null || currentTrackAtStart.id != song.id) {
      DebugLogger.info(
        'PlayerController._scrapeCurrentSongAsync',
        '跳过非当前播放歌曲刮削: ${song.displayTitle}',
      );
      return;
    }
    if (!_inFlightAutoScrapeSongIds.add(song.id)) {
      DebugLogger.info(
        'PlayerController._scrapeCurrentSongAsync',
        '刮削已在进行中，跳过重复任务: ${song.displayTitle}',
      );
      return;
    }

    try {
      DebugLogger.scraping(
        'PlayerController._scrapeCurrentSongAsync',
        '开始刮削歌曲: ${song.displayTitle}',
      );

      if (requestSerial != _playRequestSerial ||
          _service.currentTrack?.id != song.id) {
        return;
      }

      // 1. 检查缓存中是否已有此歌曲的刮削结果
      final cachedMetadata = IsarManager.getMetadata(song.id);
      if (cachedMetadata != null &&
          cachedMetadata.status == ScrapingStatus.completed &&
          _hasSavedScrapingData(cachedMetadata)) {
        DebugLogger.success(
          'PlayerController._scrapeCurrentSongAsync',
          '使用缓存的刮削结果: ${song.id}',
        );
        _applyScrapingMetadataToCurrentSong(song.id, cachedMetadata);
        if (!_needsAdditionalAutoScrape(cachedMetadata)) {
          return;
        }
      }

      if (requestSerial != _playRequestSerial ||
          _service.currentTrack?.id != song.id) {
        return;
      }

      final localMetadata = await _hydrateLocalMetadataForSong(
        song,
        requestSerial,
      );
      if (!_isCurrentRequest(requestSerial)) return;

      // 2. 执行刮削
      final extracted = TrackMetadataExtractor.extractFromFilename(
        song.fileName,
      );
      final queryTitle = _firstNonEmpty(
        localMetadata?.title,
        song.title,
        extracted.$2,
      );
      final queryArtist = _firstNonEmpty(
        localMetadata?.artist,
        song.artistName == song.sourceName ? null : song.artistName,
        extracted.$1,
      );
      final queryAlbum = _firstNonEmpty(localMetadata?.album, song.albumTitle);
      final scrapedMetadata = await ref
          .read(scraping.musicBrainzScraperProvider)
          .scrapeTrackInfo(
            title: queryTitle ?? extracted.$2,
            artist: queryArtist,
            album: queryAlbum,
            onUpdate: (metadata) async {
              await _persistAutoScrapeUpdateForSong(
                requestSerial: requestSerial,
                song: song,
                scrapedMetadata: metadata,
                status: ScrapingStatus.scraping,
              );
            },
          );

      if (scrapedMetadata == null) {
        DebugLogger.warning(
          'PlayerController._scrapeCurrentSongAsync',
          '未找到刮削结果: ${song.displayTitle}',
        );
        return;
      }

      if (requestSerial != _playRequestSerial ||
          _service.currentTrack?.id != song.id) {
        return;
      }

      final metadata = _mergeAutoScrapingMetadata(
        id: song.id,
        sourceId: song.sourceId,
        remotePath: song.remotePath,
        fileName: song.fileName,
        originalArtist: song.artistName,
        scrapedMetadata: scrapedMetadata,
        status: ScrapingStatus.completed,
      );
      await IsarManager.saveMetadata(metadata);
      if (!_isCurrentRequest(requestSerial)) return;
      _applyScrapingMetadataToCurrentSong(song.id, metadata);
      _applyScrapingMetadataToCurrentTrack(song.id, metadata);
      _refreshLibrarySongMetadata(song.id);
      DebugLogger.success(
        'PlayerController._scrapeCurrentSongAsync',
        '刮削完成并已分阶段回显: ${song.displayTitle}',
      );
    } catch (e) {
      DebugLogger.warning(
        'PlayerController._scrapeCurrentSongAsync',
        '刮削失败: $e',
      );
      // 不抛出异常，继续播放
    } finally {
      _inFlightAutoScrapeSongIds.remove(song.id);
    }
  }

  Future<void> _scrapeCurrentEntryAsync(RemoteEntry entry) async {
    final requestSerial = _playRequestSerial;
    final currentTrackAtStart = _service.currentTrack;
    if (currentTrackAtStart == null ||
        currentTrackAtStart.id != entry.uniqueId) {
      DebugLogger.info(
        'PlayerController._scrapeCurrentEntryAsync',
        '跳过非当前播放文件刮削: ${entry.name}',
      );
      return;
    }
    if (!_inFlightAutoScrapeSongIds.add(entry.uniqueId)) {
      DebugLogger.info(
        'PlayerController._scrapeCurrentEntryAsync',
        '刮削已在进行中，跳过重复任务: ${entry.name}',
      );
      return;
    }

    try {
      DebugLogger.scraping(
        'PlayerController._scrapeCurrentEntryAsync',
        '开始刮削文件浏览器播放项: ${entry.name}',
      );

      final cachedMetadata = IsarManager.getMetadata(entry.uniqueId);
      if (cachedMetadata != null &&
          cachedMetadata.status == ScrapingStatus.completed &&
          _hasSavedScrapingData(cachedMetadata)) {
        DebugLogger.success(
          'PlayerController._scrapeCurrentEntryAsync',
          '使用缓存的刮削结果: ${entry.uniqueId}',
        );
        _applyScrapingMetadataToCurrentTrack(entry.uniqueId, cachedMetadata);
        if (!_needsAdditionalAutoScrape(cachedMetadata)) {
          return;
        }
      }

      if (requestSerial != _playRequestSerial ||
          _service.currentTrack?.id != entry.uniqueId) {
        return;
      }

      final localMetadata = await _hydrateLocalMetadataForEntry(
        entry,
        requestSerial,
      );
      if (!_isCurrentRequest(requestSerial)) return;
      final extracted = TrackMetadataExtractor.extractFromFilename(entry.name);
      final scrapedMetadata = await ref
          .read(scraping.musicBrainzScraperProvider)
          .scrapeTrackInfo(
            title:
                _firstNonEmpty(localMetadata?.title, extracted.$2) ??
                extracted.$2,
            artist: _firstNonEmpty(localMetadata?.artist, extracted.$1),
            album: localMetadata?.album,
            onUpdate: (metadata) async {
              await _persistAutoScrapeUpdateForEntry(
                requestSerial: requestSerial,
                entry: entry,
                scrapedMetadata: metadata,
                status: ScrapingStatus.scraping,
              );
            },
          );
      if (scrapedMetadata == null) {
        DebugLogger.warning(
          'PlayerController._scrapeCurrentEntryAsync',
          '未找到刮削结果: ${entry.name}',
        );
        return;
      }

      if (requestSerial != _playRequestSerial ||
          _service.currentTrack?.id != entry.uniqueId) {
        return;
      }

      final metadata = _mergeAutoScrapingMetadataForEntry(
        entry: entry,
        scrapedMetadata: scrapedMetadata,
        status: ScrapingStatus.completed,
      );
      await IsarManager.saveMetadata(metadata);
      if (!_isCurrentRequest(requestSerial)) return;
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
    } finally {
      _inFlightAutoScrapeSongIds.remove(entry.uniqueId);
    }
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

  void _scheduleAutoScrapeForSong(LibrarySong song) {
    unawaited(_scrapeSongWhenCurrent(song));
  }

  void _scheduleAutoScrapeForEntry(RemoteEntry entry) {
    unawaited(_scrapeEntryWhenCurrent(entry));
  }

  Future<void> _scrapeSongWhenCurrent(LibrarySong song) async {
    final requestSerial = _playRequestSerial;
    for (var attempt = 0; attempt < 24; attempt++) {
      if (!_isCurrentRequest(requestSerial)) return;
      if (_service.currentTrack?.id == song.id) {
        if (_shouldRetryAutoScrape(song.id)) {
          await _scrapeCurrentSongAsync(song);
        }
        return;
      }
      await Future<void>.delayed(_autoScrapeRetryDelay(attempt));
    }
    DebugLogger.info(
      'PlayerController._scrapeSongWhenCurrent',
      '等待当前播放歌曲切换超时，跳过自动刮削: ${song.displayTitle}',
    );
  }

  Future<void> _scrapeEntryWhenCurrent(RemoteEntry entry) async {
    final requestSerial = _playRequestSerial;
    for (var attempt = 0; attempt < 24; attempt++) {
      if (!_isCurrentRequest(requestSerial)) return;
      if (_service.currentTrack?.id == entry.uniqueId) {
        if (_shouldRetryAutoScrape(entry.uniqueId)) {
          await _scrapeCurrentEntryAsync(entry);
        }
        return;
      }
      await Future<void>.delayed(_autoScrapeRetryDelay(attempt));
    }
    DebugLogger.info(
      'PlayerController._scrapeEntryWhenCurrent',
      '等待当前播放文件切换超时，跳过自动刮削: ${entry.name}',
    );
  }

  Duration _autoScrapeRetryDelay(int attempt) {
    return attempt < 6
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 500);
  }

  void _scheduleAutoScrapeForCurrentTrack() {
    final currentTrack = _service.currentTrack;
    if (currentTrack == null) {
      return;
    }

    final currentSongIndex = _playlist.indexWhere(
      (song) => song.id == currentTrack.id,
    );
    if (currentSongIndex >= 0) {
      _scheduleAutoScrapeForSong(_playlist[currentSongIndex]);
      return;
    }

    final fileName = p.posix.basename(currentTrack.remotePath);
    if (fileName.trim().isEmpty) {
      return;
    }
    _scheduleAutoScrapeForEntry(
      RemoteEntry(
        sourceId: currentTrack.sourceId,
        name: fileName,
        path: currentTrack.remotePath,
        kind: RemoteEntryKind.audio,
        size: currentTrack.sourceSizeBytes,
      ),
    );
  }

  bool _shouldRetryAutoScrape(String trackId) {
    if (_service.currentTrack?.id != trackId) {
      return false;
    }
    if (_inFlightAutoScrapeSongIds.contains(trackId)) {
      return false;
    }
    final metadata = IsarManager.getMetadata(trackId);
    if (metadata == null) {
      return true;
    }
    if (metadata.status == ScrapingStatus.completed &&
        _hasSavedScrapingData(metadata) &&
        !_needsAdditionalAutoScrape(metadata)) {
      return false;
    }
    return true;
  }

  Future<void> _persistAutoScrapeUpdateForSong({
    required int requestSerial,
    required LibrarySong song,
    required ScrapedMetadata scrapedMetadata,
    required ScrapingStatus status,
  }) async {
    final metadata = _mergeAutoScrapingMetadata(
      id: song.id,
      sourceId: song.sourceId,
      remotePath: song.remotePath,
      fileName: song.fileName,
      originalArtist: song.artistName,
      scrapedMetadata: scrapedMetadata,
      status: status,
    );
    await IsarManager.saveMetadata(metadata);
    if (!_isCurrentRequest(requestSerial)) return;
    _applyScrapingMetadataToCurrentSong(song.id, metadata);
    _applyScrapingMetadataToCurrentTrack(song.id, metadata);
    _refreshLibrarySongMetadata(song.id);
  }

  Future<void> _persistAutoScrapeUpdateForEntry({
    required int requestSerial,
    required RemoteEntry entry,
    required ScrapedMetadata scrapedMetadata,
    required ScrapingStatus status,
  }) async {
    final metadata = _mergeAutoScrapingMetadataForEntry(
      entry: entry,
      scrapedMetadata: scrapedMetadata,
      status: status,
    );
    await IsarManager.saveMetadata(metadata);
    if (!_isCurrentRequest(requestSerial)) return;
    _applyScrapingMetadataToCurrentTrack(entry.uniqueId, metadata);
  }

  ScrapingMetadata _mergeAutoScrapingMetadata({
    required String id,
    required String sourceId,
    required String remotePath,
    required String fileName,
    required String? originalArtist,
    required ScrapedMetadata scrapedMetadata,
    required ScrapingStatus status,
  }) {
    final existing = IsarManager.getMetadata(id);
    final metadata =
        existing ??
        ScrapingMetadata(
          id: id,
          sourceId: sourceId,
          filePath: remotePath,
          filenameWithoutExt: p.posix.basenameWithoutExtension(fileName),
          originalFileName: fileName,
          originalArtist: originalArtist,
        );

    metadata.autoScrapedCoverUrl = _firstNonEmpty(
      scrapedMetadata.coverUrl,
      metadata.autoScrapedCoverUrl,
    );
    metadata.autoScrapedLocalCoverPath = _firstNonEmpty(
      scrapedMetadata.localCoverPath,
      metadata.autoScrapedLocalCoverPath,
    );
    if ((scrapedMetadata.coverUrl?.trim().isNotEmpty ?? false) ||
        (scrapedMetadata.localCoverPath?.trim().isNotEmpty ?? false)) {
      metadata.autoScrapedCoverSource = 'scraped';
    }
    metadata.autoScrapedLyrics = _firstNonEmpty(
      scrapedMetadata.lyrics,
      metadata.autoScrapedLyrics,
    );
    if (scrapedMetadata.lyrics?.trim().isNotEmpty == true) {
      metadata.autoScrapedLyricsSource = 'scraped';
    }
    metadata.autoScrapedAt = DateTime.now();
    metadata.status = status;
    metadata.errorMessage = null;
    metadata.updatedAt = DateTime.now();
    metadata.lastAttemptAt = DateTime.now();
    return metadata;
  }

  ScrapingMetadata _mergeAutoScrapingMetadataForEntry({
    required RemoteEntry entry,
    required ScrapedMetadata scrapedMetadata,
    required ScrapingStatus status,
  }) {
    return _mergeAutoScrapingMetadata(
      id: entry.uniqueId,
      sourceId: entry.sourceId,
      remotePath: entry.path,
      fileName: entry.name,
      originalArtist: null,
      scrapedMetadata: scrapedMetadata,
      status: status,
    );
  }

  Future<EmbeddedAudioMetadata?> _hydrateLocalMetadataForSong(
    LibrarySong song,
    int requestSerial,
  ) async {
    try {
      final metadata = await _readEmbeddedMetadata(song.toRemoteEntry());
      if (metadata == null) {
        return null;
      }
      await _persistLocalMetadata(
        requestSerial: requestSerial,
        id: song.id,
        sourceId: song.sourceId,
        remotePath: song.remotePath,
        fileName: song.fileName,
        originalArtist: song.artistName,
        metadata: metadata,
      );
      return metadata;
    } catch (e, stack) {
      DebugLogger.error(
        'PlayerController._hydrateLocalMetadataForSong',
        '读取音频内嵌标签失败',
        e.toString(),
        stack,
      );
      return null;
    }
  }

  Future<EmbeddedAudioMetadata?> _hydrateLocalMetadataForEntry(
    RemoteEntry entry,
    int requestSerial,
  ) async {
    try {
      final metadata = await _readEmbeddedMetadata(entry);
      if (metadata == null) {
        return null;
      }
      await _persistLocalMetadata(
        requestSerial: requestSerial,
        id: entry.uniqueId,
        sourceId: entry.sourceId,
        remotePath: entry.path,
        fileName: entry.name,
        originalArtist: null,
        metadata: metadata,
      );
      return metadata;
    } catch (e, stack) {
      DebugLogger.error(
        'PlayerController._hydrateLocalMetadataForEntry',
        '读取音频内嵌标签失败',
        e.toString(),
        stack,
      );
      return null;
    }
  }

  Future<EmbeddedAudioMetadata?> _readEmbeddedMetadata(
    RemoteEntry entry,
  ) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final range = await _playbackCache.readCachedRange(
        entry: entry,
        start: 0,
        end: 256 * 1024,
      );
      final bytes = range?.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        final parsed = AudioEmbeddedMetadataReader.parse(
          bytes,
          fileName: entry.name,
        );
        if (parsed != null) {
          return parsed;
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 180 * (attempt + 1)));
    }

    return null;
  }

  Future<void> _persistLocalMetadata({
    required int requestSerial,
    required String id,
    required String sourceId,
    required String remotePath,
    required String fileName,
    required String? originalArtist,
    required EmbeddedAudioMetadata metadata,
  }) async {
    final existing =
        IsarManager.getMetadata(id) ??
        ScrapingMetadata(
          id: id,
          sourceId: sourceId,
          filePath: remotePath,
          filenameWithoutExt: p.posix.basenameWithoutExtension(fileName),
          originalFileName: fileName,
          originalArtist: originalArtist,
        );

    var changed = false;
    if (metadata.title?.trim().isNotEmpty == true &&
        existing.autoScrapedTitle != metadata.title) {
      existing.autoScrapedTitle = metadata.title;
      changed = true;
    }
    if (metadata.artist?.trim().isNotEmpty == true &&
        existing.autoScrapedArtist != metadata.artist) {
      existing.autoScrapedArtist = metadata.artist;
      changed = true;
    }
    if (metadata.album?.trim().isNotEmpty == true &&
        existing.autoScrapedAlbum != metadata.album) {
      existing.autoScrapedAlbum = metadata.album;
      changed = true;
    }
    if (metadata.albumArtist?.trim().isNotEmpty == true &&
        existing.autoScrapedAlbumArtist != metadata.albumArtist) {
      existing.autoScrapedAlbumArtist = metadata.albumArtist;
      changed = true;
    }
    if (metadata.genre?.trim().isNotEmpty == true &&
        existing.autoScrapedGenre != metadata.genre) {
      existing.autoScrapedGenre = metadata.genre;
      changed = true;
    }
    if (metadata.year?.trim().isNotEmpty == true &&
        existing.autoScrapedYear != metadata.year) {
      existing.autoScrapedYear = metadata.year;
      changed = true;
    }
    if (metadata.composer?.trim().isNotEmpty == true &&
        existing.autoScrapedComposer != metadata.composer) {
      existing.autoScrapedComposer = metadata.composer;
      changed = true;
    }
    if (metadata.comment?.trim().isNotEmpty == true &&
        existing.autoScrapedComment != metadata.comment) {
      existing.autoScrapedComment = metadata.comment;
      changed = true;
    }
    if (metadata.lyrics?.trim().isNotEmpty == true &&
        existing.autoScrapedLyrics != metadata.lyrics) {
      existing.autoScrapedLyrics = metadata.lyrics;
      existing.autoScrapedLyricsSource = 'embedded';
      changed = true;
    }
    if (metadata.lyrics?.trim().isNotEmpty == true &&
        existing.autoScrapedLyricsSource != 'embedded') {
      existing.autoScrapedLyricsSource = 'embedded';
      changed = true;
    }
    if (metadata.trackNumber != null &&
        existing.autoScrapedTrackNumber != metadata.trackNumber) {
      existing.autoScrapedTrackNumber = metadata.trackNumber;
      changed = true;
    }
    if (metadata.trackTotal != null &&
        existing.autoScrapedTrackTotal != metadata.trackTotal) {
      existing.autoScrapedTrackTotal = metadata.trackTotal;
      changed = true;
    }
    if (metadata.discNumber != null &&
        existing.autoScrapedDiscNumber != metadata.discNumber) {
      existing.autoScrapedDiscNumber = metadata.discNumber;
      changed = true;
    }
    if (metadata.discTotal != null &&
        existing.autoScrapedDiscTotal != metadata.discTotal) {
      existing.autoScrapedDiscTotal = metadata.discTotal;
      changed = true;
    }
    if (metadata.hasCover) {
      final localCoverPath = await CoverArtCacheManager().cacheBytes(
        'embedded_cover_$id',
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
      return;
    }

    existing.autoScrapedAt = DateTime.now();
    existing.embeddedMetadataReadAt = DateTime.now();
    existing.updatedAt = DateTime.now();
    existing.lastAttemptAt = DateTime.now();
    if (!_needsAdditionalAutoScrape(existing)) {
      existing.status = ScrapingStatus.completed;
    }
    await IsarManager.saveMetadata(existing);
    if (!_isCurrentRequest(requestSerial)) return;
    _applyEmbeddedMetadataToCurrentPlayback(id, metadata);
    _applyScrapingMetadataToCurrentSong(id, existing);
    _applyScrapingMetadataToCurrentTrack(id, existing);
    _refreshLibrarySongMetadata(id);
  }

  void _applyEmbeddedMetadataToCurrentPlayback(
    String trackId,
    EmbeddedAudioMetadata metadata,
  ) {
    final songIndex = _playlist.indexWhere((song) => song.id == trackId);
    if (songIndex >= 0) {
      final currentSong = _playlist[songIndex];
      final updatedSong = LibrarySong(
        id: currentSong.id,
        sourceId: currentSong.sourceId,
        sourceName: currentSong.sourceName,
        title:
            _firstNonEmpty(metadata.title, currentSong.title) ??
            currentSong.title,
        fileName: currentSong.fileName,
        remotePath: currentSong.remotePath,
        albumTitle:
            _firstNonEmpty(metadata.album, currentSong.albumTitle) ??
            currentSong.albumTitle,
        artistName:
            _firstNonEmpty(metadata.artist, currentSong.artistName) ??
            currentSong.artistName,
        directoryPath: currentSong.directoryPath,
        folderAlbumTitle: currentSong.folderAlbumTitle,
        folderArtistName: currentSong.folderArtistName,
        scrapedAlbumTitle: currentSong.scrapedAlbumTitle,
        scrapedArtistName: currentSong.scrapedArtistName,
        mimeType: currentSong.mimeType,
        size: currentSong.size,
        modifiedAt: currentSong.modifiedAt,
        manuallyScrapedTitle: currentSong.manuallyScrapedTitle,
        manuallyScrapedArtist: currentSong.manuallyScrapedArtist,
        manuallyScrapedAlbum: currentSong.manuallyScrapedAlbum,
        manuallyScrapedCoverUrl: currentSong.manuallyScrapedCoverUrl,
        manuallyScrapedLocalCoverPath:
            currentSong.manuallyScrapedLocalCoverPath,
        manuallyScrapedLyrics: currentSong.manuallyScrapedLyrics,
        autoScrapedTitle: currentSong.autoScrapedTitle,
        autoScrapedArtist: currentSong.autoScrapedArtist,
        autoScrapedAlbum: currentSong.autoScrapedAlbum,
        autoScrapedCoverUrl: currentSong.autoScrapedCoverUrl,
        autoScrapedLocalCoverPath: currentSong.autoScrapedLocalCoverPath,
        autoScrapedLyrics: currentSong.autoScrapedLyrics,
      );
      final nextPlaylist = List<LibrarySong>.of(_playlist);
      nextPlaylist[songIndex] = updatedSong;
      _playlist = List<LibrarySong>.unmodifiable(nextPlaylist);
      _playlistRevision++;
    }

    final currentTrack = _service.currentTrack;
    if (currentTrack != null && currentTrack.id == trackId) {
      _service.updateCurrentTrack(
        PlayableTrack(
          id: currentTrack.id,
          sourceId: currentTrack.sourceId,
          title:
              _firstNonEmpty(metadata.title, currentTrack.title) ??
              currentTrack.title,
          sourceName: currentTrack.sourceName,
          remotePath: currentTrack.remotePath,
          audioSource: currentTrack.audioSource,
          sourceSizeBytes: currentTrack.sourceSizeBytes,
          artistName:
              _firstNonEmpty(metadata.artist, currentTrack.artistName) ??
              currentTrack.artistName,
          albumTitle:
              _firstNonEmpty(metadata.album, currentTrack.albumTitle) ??
              currentTrack.albumTitle,
          autoScrapedTitle: currentTrack.autoScrapedTitle,
          autoScrapedArtist: currentTrack.autoScrapedArtist,
          autoScrapedAlbum: currentTrack.autoScrapedAlbum,
          autoScrapedCoverUrl: currentTrack.autoScrapedCoverUrl,
          localCoverPath: currentTrack.localCoverPath,
          lyrics: currentTrack.lyrics,
        ),
      );
      _syncState();
      unawaited(_persistSession());
    }
  }

  bool _needsAdditionalAutoScrape(ScrapingMetadata metadata) {
    final preferences = ref.read(appSettingsControllerProvider).valueOrNull;
    final needsLyrics = preferences?.enableLyricsScraping ?? false;

    final hasLyrics =
        _firstNonEmpty(
          metadata.manuallyScrapedLyrics,
          metadata.autoScrapedLyrics,
        ) !=
        null;

    return needsLyrics && !hasLyrics;
  }

  void _refreshLibrarySongMetadata(String songId) {
    try {
      final libraryCatalogNotifier = ref.read(
        libraryCatalogControllerProvider.notifier,
      );
      libraryCatalogNotifier.refreshSongMetadata(songId);
      DebugLogger.info('PlayerController', '✅ 已触发库列表元数据刷新: $songId');
    } catch (e) {
      DebugLogger.warning('PlayerController', '更新库列表失败: $e');
    }
  }
}
