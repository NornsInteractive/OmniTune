import 'dart:async';
import 'dart:math' as math;

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/player_service.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/playable_track.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/storage/player_session_repository.dart';
import '../../sources/application/source_session_manager.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/data/webdav/webdav_playback_cache_base.dart';
import '../../sources/data/webdav/webdav_playback_cache_provider.dart';
import '../../sources/domain/music_source.dart';

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
  late final PlayerService _service;
  late final WebDavPlaybackCache _playbackCache;
  late final PlayerSessionRepository _sessionRepository;
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
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _bufferedPositionSubscription?.cancel();
    _durationSubscription?.cancel();
    _errorSubscription?.cancel();
    _cacheSubscription?.cancel();
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
    final track = await trackFuture;
    if (requestSerial != _playRequestSerial) {
      return;
    }

    // 立即播放，不等待歌词加载
    await _service.playTrack(track);
    _syncState();
    unawaited(_persistSession(positionOverride: Duration.zero));

    // 在后台加载歌词
    final lyrics = await lyricsFuture;
    if (requestSerial == _playRequestSerial &&
        _service.currentTrack?.id == track.id) {
      _lyrics = lyrics;
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
    final profile = await _profileForSong(song);
    final source = await ref
        .read(musicSourceSessionManagerProvider)
        .get(profile);
    final lyricsFuture = _loadLyrics(source, song.remotePath);
    final track = await source.buildPlayableTrack(song.toRemoteEntry());
    if (requestSerial != _playRequestSerial) {
      return;
    }

    await _service.loadTrack(track, initialPosition: initialPosition);
    _syncState();
    unawaited(_persistSession(positionOverride: initialPosition));

    final lyrics = await lyricsFuture;
    if (requestSerial == _playRequestSerial &&
        _service.currentTrack?.id == track.id) {
      _lyrics = lyrics;
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
      if (raw == null || raw.trim().isEmpty) {
        return const [];
      }

      final result = <LyricLine>[];
      final timestampPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
      for (final line in raw.split(RegExp(r'\r?\n'))) {
        final matches = timestampPattern.allMatches(line).toList();
        if (matches.isEmpty) {
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

      result.sort((left, right) => left.time.compareTo(right.time));
      return result;
    } catch (_) {
      return const [];
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
}
