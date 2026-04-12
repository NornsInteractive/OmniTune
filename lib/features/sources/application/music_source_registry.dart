import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../data/cloud189/cloud189_music_source.dart';
import '../data/webdav/webdav_music_source.dart';
import '../data/webdav/webdav_playback_cache_provider.dart';
import '../domain/music_source.dart';

part 'music_source_registry.g.dart';

class MusicSourceRegistry {
  MusicSourceRegistry(List<MusicSourceFactory> factories)
    : _factories = {for (final factory in factories) factory.protocol: factory};

  final Map<SourceProtocol, MusicSourceFactory> _factories;

  MusicSource create(SourceProfile profile) {
    final factory = _factories[profile.protocol];
    if (factory == null) {
      throw UnsupportedError(
        'No music source factory registered for ${profile.protocol.storageValue}.',
      );
    }
    return factory.create(profile);
  }
}

@Riverpod(keepAlive: true)
MusicSourceRegistry musicSourceRegistry(Ref ref) {
  final playbackCache = ref.watch(webDavPlaybackCacheProvider);
  return MusicSourceRegistry([
    WebDavMusicSourceFactory(playbackCacheFactory: () => playbackCache),
    const Cloud189MusicSourceFactory(),
  ]);
}
