import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_song.dart';

part 'player_session_repository.g.dart';

class PlayerSessionSnapshot {
  const PlayerSessionSnapshot({
    this.playlist = const [],
    this.currentIndex = -1,
    this.playbackMode = 'list',
    this.position = Duration.zero,
  });

  final List<LibrarySong> playlist;
  final int currentIndex;
  final String playbackMode;
  final Duration position;

  bool get hasCurrentSong =>
      playlist.isNotEmpty &&
      currentIndex >= 0 &&
      currentIndex < playlist.length;

  Map<String, dynamic> toJson() {
    return {
      'playlist': playlist.map((song) => song.toJson()).toList(),
      'currentIndex': currentIndex,
      'playbackMode': playbackMode,
      'positionMs': position.inMilliseconds,
    };
  }

  factory PlayerSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final playlist = (json['playlist'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LibrarySong.fromJson)
        .toList(growable: false);
    final currentIndex = json['currentIndex'] as int? ?? -1;

    return PlayerSessionSnapshot(
      playlist: playlist,
      currentIndex: currentIndex >= 0 && currentIndex < playlist.length
          ? currentIndex
          : -1,
      playbackMode: json['playbackMode'] as String? ?? 'list',
      position: Duration(milliseconds: json['positionMs'] as int? ?? 0),
    );
  }
}

abstract class PlayerSessionRepository {
  Future<PlayerSessionSnapshot?> load();

  Future<void> save(PlayerSessionSnapshot snapshot);

  Future<void> clear();
}

Future<String> _encodePlayerSession(PlayerSessionSnapshot snapshot) async {
  final songs = <Map<String, dynamic>>[];
  for (var index = 0; index < snapshot.playlist.length; index++) {
    songs.add(snapshot.playlist[index].toJson());
    if (kIsWeb && (index + 1) % 128 == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }
  return jsonEncode({
    'playlist': songs,
    'currentIndex': snapshot.currentIndex,
    'playbackMode': snapshot.playbackMode,
    'positionMs': snapshot.position.inMilliseconds,
  });
}

Future<PlayerSessionSnapshot> _decodePlayerSession(String raw) async {
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final playlist = <LibrarySong>[];
  final songs = json['playlist'] as List<dynamic>? ?? const [];
  for (var index = 0; index < songs.length; index++) {
    final song = songs[index];
    if (song is Map<String, dynamic>) {
      playlist.add(LibrarySong.fromJson(song));
    }
    if (kIsWeb && (index + 1) % 128 == 0) {
      await Future<void>.delayed(Duration.zero);
    }
  }
  final currentIndex = json['currentIndex'] as int? ?? -1;
  return PlayerSessionSnapshot(
    playlist: playlist,
    currentIndex: currentIndex >= 0 && currentIndex < playlist.length
        ? currentIndex
        : -1,
    playbackMode: json['playbackMode'] as String? ?? 'list',
    position: Duration(milliseconds: json['positionMs'] as int? ?? 0),
  );
}

class SharedPreferencesPlayerSessionRepository
    implements PlayerSessionRepository {
  static const _key = 'player_session_v1';
  Future<void> _pendingWrite = Future<void>.value();

  Future<void> _enqueueWrite(Future<void> Function() write) {
    final operation = _pendingWrite.then((_) => write());
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  @override
  Future<PlayerSessionSnapshot?> load() async {
    await _pendingWrite;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      return await compute(_decodePlayerSession, raw);
    } catch (_) {
      await _enqueueWrite(() async {
        if (preferences.getString(_key) == raw) {
          await preferences.remove(_key);
        }
      });
      return null;
    }
  }

  @override
  Future<void> save(PlayerSessionSnapshot snapshot) => _enqueueWrite(() async {
    final encoded = await compute(_encodePlayerSession, snapshot);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, encoded);
  });

  @override
  Future<void> clear() => _enqueueWrite(() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  });
}

@Riverpod(keepAlive: true)
PlayerSessionRepository playerSessionRepository(Ref ref) {
  return SharedPreferencesPlayerSessionRepository();
}
