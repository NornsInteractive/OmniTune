import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/playable_track.dart';

part 'player_service.g.dart';

class PlayerService {
  PlayerService({AudioPlayer? player})
    : _player = player ?? _createAudioPlayer() {
    _errorSubscription = _player.errorStream.listen((error) {
      // Load errors belong to loadTrack's request; it reports only current errors.
      if (!_loading && _currentTrack != null) _errors.add(error);
    });
  }

  static AudioPlayer _createAudioPlayer() {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      JustAudioMediaKit.ensureInitialized(
        linux: defaultTargetPlatform == TargetPlatform.linux,
        windows: defaultTargetPlatform == TargetPlatform.windows,
      );
    }
    return AudioPlayer(userAgent: 'OmniTune/1.0');
  }

  final AudioPlayer _player;
  final _errors = StreamController<PlayerException>.broadcast(sync: true);
  late final StreamSubscription<PlayerException> _errorSubscription;
  PlayableTrack? _currentTrack;
  int _requestSerial = 0;
  bool _loading = false;
  bool _disposed = false;

  AudioPlayer get player => _player;

  bool get isPlaying => _player.playing;

  Duration get position => _player.position;

  PlayableTrack? get currentTrack => _currentTrack;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  Stream<PlayerException> get errorStream => _errors.stream;

  void updateCurrentTrack(PlayableTrack track) {
    if (_currentTrack?.id != track.id) {
      return;
    }
    _currentTrack = track;
  }

  Future<void> playTrack(PlayableTrack track) async {
    final load = loadTrack(track);
    final requestSerial = _requestSerial;
    await load;
    if (!_disposed && requestSerial == _requestSerial) await play();
  }

  Future<void> loadTrack(
    PlayableTrack track, {
    Duration initialPosition = Duration.zero,
  }) async {
    final requestSerial = ++_requestSerial;
    _loading = true;
    _currentTrack = track;
    try {
      await _player.setAudioSource(
        track.audioSource,
        initialPosition: initialPosition,
      );
    } catch (_) {
      if (_disposed || requestSerial != _requestSerial) return;
      _currentTrack = null;
      rethrow;
    } finally {
      if (requestSerial == _requestSerial) _loading = false;
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
      return;
    }
    await play();
  }

  Future<void> play() async {
    if (_disposed || _currentTrack == null) return;
    final requestSerial = _requestSerial;
    // just_audio's play future spans the entire playback lifetime.
    unawaited(
      _player.play().catchError((Object error) {
        if (_disposed || requestSerial != _requestSerial) return;
        _errors.add(
          error is PlayerException
              ? error
              : PlayerException(-1, error.toString(), null),
        );
      }),
    );
  }

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> replayCurrent() async {
    final requestSerial = _requestSerial;
    await _player.seek(Duration.zero);
    if (!_disposed && requestSerial == _requestSerial) await play();
  }

  Future<void> stop() async {
    ++_requestSerial;
    _loading = false;
    _currentTrack = null;
    await _player.stop();
  }

  Future<void> dispose() async {
    _disposed = true;
    ++_requestSerial;
    await _errorSubscription.cancel();
    await _player.dispose();
    await _errors.close();
  }
}

@Riverpod(keepAlive: true)
PlayerService playerService(Ref ref) {
  final service = PlayerService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
}
