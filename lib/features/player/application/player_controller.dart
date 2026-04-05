import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/audio/player_service.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/playable_track.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
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

class PlayerViewState {
  const PlayerViewState({
    required this.currentTrack,
    required this.isPlaying,
    required this.processingState,
    required this.position,
    required this.bufferedPosition,
    required this.duration,
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
  final List<LyricLine> lyrics;
  final List<CacheProgressSegment> cacheSegments;
  final String? errorMessage;

  bool get hasTrack => currentTrack != null;

  bool get isBusy =>
      processingState == ProcessingState.loading ||
      processingState == ProcessingState.buffering;

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
    String? errorMessage,
  }) {
    return PlayerViewState(
      currentTrack: service.currentTrack,
      isPlaying: service.player.playing,
      processingState: service.player.processingState,
      position: service.player.position,
      bufferedPosition: service.player.bufferedPosition,
      duration: service.player.duration,
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
      lyrics: [],
      cacheSegments: [],
    );
  }
}

@Riverpod(keepAlive: true)
class PlayerController extends _$PlayerController {
  late final PlayerService _service;
  late final WebDavPlaybackCache _playbackCache;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _bufferedPositionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;
  StreamSubscription<PlaybackCacheSnapshot>? _cacheSubscription;
  List<LyricLine> _lyrics = const [];

  @override
  PlayerViewState build() {
    _service = ref.watch(playerServiceProvider);
    _playbackCache = ref.watch(webDavPlaybackCacheProvider);
    _bindStreams();
    ref.onDispose(_disposeSubscriptions);
    return PlayerViewState.fromService(_service);
  }

  Future<void> playEntry({
    required SourceProfile profile,
    required RemoteEntry entry,
  }) async {
    try {
      await _playRemoteEntry(profile: profile, entry: entry);
    } catch (error) {
      _syncState(errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> playLibrarySong(LibrarySong song) async {
    final profiles = await ref.read(sourcesControllerProvider.future);
    final profile = profiles.firstWhere((item) => item.id == song.sourceId);
    await _playRemoteEntry(profile: profile, entry: song.toRemoteEntry());
  }

  Future<void> togglePlayPause() async {
    await _service.togglePlayPause();
    _syncState();
  }

  Future<void> seek(Duration position) async {
    await _service.seek(position);
    _syncState();
  }

  Future<void> stop() async {
    await _service.stop();
    _syncState();
  }

  void _bindStreams() {
    _playerStateSubscription ??= _service.playerStateStream.listen((_) {
      _syncState();
    });
    _positionSubscription ??= _service.positionStream.listen((_) {
      _syncState();
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
      errorMessage: errorMessage,
    );
  }

  void _disposeSubscriptions() {
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
    final source = await ref
        .read(musicSourceSessionManagerProvider)
        .get(profile);
    final track = await source.buildPlayableTrack(entry);
    _lyrics = await _loadLyrics(source, entry.path);
    await _service.playTrack(track);
    _syncState();
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
