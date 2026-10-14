import '../../../../core/models/playback_cache_settings.dart';
import 'webdav_playback_cache_base.dart';
import 'webdav_playback_cache_stub.dart'
    if (dart.library.io) 'webdav_playback_cache_io.dart'
    as impl;

WebDavPlaybackCache createWebDavPlaybackCache({
  required PlaybackCacheSettings initialSettings,
  int maxMemoryBytes = 64 * 1024 * 1024,
}) => impl.createWebDavPlaybackCache(
  initialSettings: initialSettings,
  maxMemoryBytes: maxMemoryBytes,
);
