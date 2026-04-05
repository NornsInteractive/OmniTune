import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/playback_cache_settings.dart';
import '../../../player/application/playback_cache_settings_controller.dart';
import 'webdav_playback_cache.dart';
import 'webdav_playback_cache_base.dart';

final webDavPlaybackCacheProvider = Provider<WebDavPlaybackCache>((ref) {
  final initialSettings =
      ref.read(playbackCacheSettingsControllerProvider).valueOrNull ??
      const PlaybackCacheSettings();
  final cache = createWebDavPlaybackCache(initialSettings: initialSettings);

  ref.listen<AsyncValue<PlaybackCacheSettings>>(
    playbackCacheSettingsControllerProvider,
    (_, next) {
      next.whenData(cache.applySettings);
    },
  );
  ref.onDispose(() {
    unawaited(cache.dispose());
  });

  return cache;
});
