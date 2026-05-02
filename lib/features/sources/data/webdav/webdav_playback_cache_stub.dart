import '../../../../core/models/playback_cache_settings.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/models/remote_entry.dart';
import 'webdav_playback_cache_base.dart';
import 'webdav_remote_client.dart';

class _UnsupportedWebDavPlaybackCache implements WebDavPlaybackCache {
  @override
  void applySettings(PlaybackCacheSettings settings) {}

  @override
  Stream<PlaybackCacheSnapshot> get snapshotStream =>
      const Stream<PlaybackCacheSnapshot>.empty();

  @override
  PlaybackCacheSnapshot? snapshotForTrack(String trackId) => null;

  @override
  Stream<List<PlaybackCacheInventoryItem>> watchCachedTracks() =>
      const Stream<List<PlaybackCacheInventoryItem>>.empty();

  @override
  Future<List<PlaybackCacheInventoryItem>> listCachedTracks() async =>
      const <PlaybackCacheInventoryItem>[];

  @override
  Future<AudioSource?> createCachedAudioSource({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  }) async {
    return null;
  }

  @override
  Future<WebDavCachedRange?> readCachedRange({
    required RemoteEntry entry,
    required int start,
    int? end,
  }) async {
    return null;
  }

  @override
  Future<String?> persistentFilePathForEntry(RemoteEntry entry) async {
    return null;
  }

  @override
  Stream<List<int>> wrapPlaybackStream({
    required RemoteEntry entry,
    required Stream<List<int>> stream,
    required int offset,
    required int? requestedEnd,
    required int? expectedLength,
  }) {
    return stream;
  }

  @override
  Future<void> clearAllCachedData() async {}

  @override
  Future<void> clearMemoryCachedData() async {}

  @override
  Future<void> removeCachedTracks(Set<String> trackIds) async {}

  @override
  Future<void> dispose() async {}
}

WebDavPlaybackCache createWebDavPlaybackCache({
  required PlaybackCacheSettings initialSettings,
}) => _UnsupportedWebDavPlaybackCache();
