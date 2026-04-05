import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/playback_cache_settings.dart';
import '../../../core/storage/library_preferences_repository.dart';

class PlaybackCacheSettingsController
    extends AsyncNotifier<PlaybackCacheSettings> {
  @override
  Future<PlaybackCacheSettings> build() async {
    final preferences = await ref
        .read(libraryPreferencesRepositoryProvider)
        .load();
    return preferences.playbackCacheSettings;
  }

  Future<void> setPersistentCacheEnabled(bool enabled) async {
    await _save(
      (preferences) =>
          preferences.copyWith(enablePersistentPlaybackCache: enabled),
    );
  }

  Future<void> setMemoryCacheTrackLimit(int trackLimit) async {
    await _save(
      (preferences) =>
          preferences.copyWith(memoryPlaybackCacheTrackLimit: trackLimit),
    );
  }

  Future<void> _save(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async {
    final repository = ref.read(libraryPreferencesRepositoryProvider);
    final current = await repository.load();
    final next = transform(current);
    await repository.save(next);
    state = AsyncData(next.playbackCacheSettings);
  }
}

final playbackCacheSettingsControllerProvider =
    AsyncNotifierProvider<
      PlaybackCacheSettingsController,
      PlaybackCacheSettings
    >(PlaybackCacheSettingsController.new);
