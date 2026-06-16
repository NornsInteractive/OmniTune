import 'dart:typed_data';
import 'dart:async';

import '../../../../core/models/playback_cache_settings.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/models/remote_entry.dart';
import 'webdav_remote_client.dart';

class WebDavCachedRange {
  const WebDavCachedRange({
    required this.start,
    required this.endExclusive,
    required this.bytes,
  });

  final int start;
  final int endExclusive;
  final Uint8List bytes;
}

class PlaybackCacheSegment {
  const PlaybackCacheSegment({required this.start, required this.endExclusive});

  final int start;
  final int endExclusive;
}

class PlaybackCacheSnapshot {
  const PlaybackCacheSnapshot({
    required this.trackId,
    required this.segments,
    this.totalLength,
  });

  final String trackId;
  final List<PlaybackCacheSegment> segments;
  final int? totalLength;
}

class PlaybackCacheInventoryItem {
  const PlaybackCacheInventoryItem({
    required this.trackId,
    required this.sourceId,
    required this.title,
    required this.fileName,
    required this.remotePath,
    required this.cachedBytes,
    required this.totalBytes,
    required this.hasPersistentCopy,
    required this.hasMemoryData,
    required this.updatedAt,
  });

  final String trackId;
  final String sourceId;
  final String title;
  final String fileName;
  final String remotePath;
  final int cachedBytes;
  final int? totalBytes;
  final bool hasPersistentCopy;
  final bool hasMemoryData;
  final DateTime updatedAt;

  bool get isFullyCached => totalBytes != null && cachedBytes >= totalBytes!;
}

abstract class WebDavPlaybackCache {
  void applySettings(PlaybackCacheSettings settings);

  Stream<PlaybackCacheSnapshot> get snapshotStream;

  PlaybackCacheSnapshot? snapshotForTrack(String trackId);

  Stream<List<PlaybackCacheInventoryItem>> watchCachedTracks();

  Future<List<PlaybackCacheInventoryItem>> listCachedTracks();

  Future<AudioSource?> createCachedAudioSource({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  });

  Future<void> prefetchEntry({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  });

  Future<WebDavCachedRange?> readCachedRange({
    required RemoteEntry entry,
    required int start,
    int? end,
  });

  Future<String?> persistentFilePathForEntry(RemoteEntry entry);

  Stream<List<int>> wrapPlaybackStream({
    required RemoteEntry entry,
    required Stream<List<int>> stream,
    required int offset,
    required int? requestedEnd,
    required int? expectedLength,
  });

  Future<void> clearAllCachedData();

  Future<void> clearMemoryCachedData();

  Future<void> removeCachedTracks(Set<String> trackIds);

  Future<void> dispose();
}
