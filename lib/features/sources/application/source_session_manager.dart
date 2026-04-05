import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/source_profile.dart';
import '../domain/music_source.dart';
import 'music_source_registry.dart';

part 'source_session_manager.g.dart';

class MusicSourceSessionManager {
  MusicSourceSessionManager(this._registry);

  final MusicSourceRegistry _registry;
  final Map<String, MusicSource> _sessions = {};

  Future<MusicSource> get(SourceProfile profile) async {
    final cached = _sessions[profile.id];
    if (cached != null) {
      return cached;
    }

    final source = _registry.create(profile);
    await source.connect();
    _sessions[profile.id] = source;
    return source;
  }

  Future<void> invalidate(String sourceId) async {
    final source = _sessions.remove(sourceId);
    if (source != null) {
      await source.disconnect();
    }
  }

  Future<void> dispose() async {
    for (final source in _sessions.values) {
      await source.disconnect();
    }
    _sessions.clear();
  }
}

@Riverpod(keepAlive: true)
MusicSourceSessionManager musicSourceSessionManager(Ref ref) {
  final manager = MusicSourceSessionManager(
    ref.watch(musicSourceRegistryProvider),
  );
  ref.onDispose(() {
    unawaited(manager.dispose());
  });
  return manager;
}
