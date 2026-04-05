class PlaybackCacheSettings {
  const PlaybackCacheSettings({
    this.enablePersistentCache = false,
    this.memoryCacheTrackLimit = 3,
  });

  final bool enablePersistentCache;
  final int memoryCacheTrackLimit;

  PlaybackCacheSettings copyWith({
    bool? enablePersistentCache,
    int? memoryCacheTrackLimit,
  }) {
    return PlaybackCacheSettings(
      enablePersistentCache:
          enablePersistentCache ?? this.enablePersistentCache,
      memoryCacheTrackLimit:
          memoryCacheTrackLimit ?? this.memoryCacheTrackLimit,
    ).normalized;
  }

  PlaybackCacheSettings get normalized {
    final normalizedLimit = switch (memoryCacheTrackLimit) {
      < 1 => 1,
      > 12 => 12,
      _ => memoryCacheTrackLimit,
    };

    return PlaybackCacheSettings(
      enablePersistentCache: enablePersistentCache,
      memoryCacheTrackLimit: normalizedLimit,
    );
  }
}
