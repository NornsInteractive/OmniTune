import 'dart:convert';

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

class SharedPreferencesPlayerSessionRepository
    implements PlayerSessionRepository {
  static const _key = 'player_session_v1';

  @override
  Future<PlayerSessionSnapshot?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PlayerSessionSnapshot.fromJson(json);
    } catch (_) {
      await preferences.remove(_key);
      return null;
    }
  }

  @override
  Future<void> save(PlayerSessionSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(snapshot.toJson()));
  }

  @override
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}

@Riverpod(keepAlive: true)
PlayerSessionRepository playerSessionRepository(Ref ref) {
  return SharedPreferencesPlayerSessionRepository();
}
