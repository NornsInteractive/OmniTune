import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/playable_track.dart';

part 'player_service.g.dart';

class PlayerService {
  PlayerService() : _player = AudioPlayer(userAgent: 'flutter_music_player/1.0');

  final AudioPlayer _player;
  PlayableTrack? _currentTrack;

  AudioPlayer get player => _player;

  PlayableTrack? get currentTrack => _currentTrack;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  Stream<PlayerException> get errorStream => _player.errorStream;

  Future<void> playTrack(PlayableTrack track) async {
    _currentTrack = track;

    // 并行执行：设置音频源和播放
    // 这样可以在音频源设置完成后立即开始播放，而不是等待两个操作都完成
    final setAudioFuture = _player.setAudioSource(track.audioSource);

    // 不等待 setAudioSource 完全完成就尝试播放
    // just_audio 会在准备好时自动开始
    try {
      await setAudioFuture;
    } catch (e) {
      // 如果设置源出错，停止播放
      await _player.stop();
      rethrow;
    }

    // 在设置完成后，如果还没有播放，则开始播放
    if (!_player.playing) {
      await _player.play();
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    await _player.play();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> stop() => _player.stop();

  Future<void> dispose() async {
    await _player.dispose();
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
