import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_preferences.dart';
import '../models/playback_cache_settings.dart';

part 'library_preferences_repository.g.dart';

class LibraryPreferences {
  const LibraryPreferences({
    this.favoriteTrackIds = const <String>{},
    this.likedTrackIds = const <String>{},
    this.enablePersistentPlaybackCache = false,
    this.memoryPlaybackCacheTrackLimit = 3,
    this.themePreference = AppThemePreference.system,
    this.localePreference = AppLocalePreference.system,
    this.interfaceScaleFactor = AppDisplayPreferences.defaultInterfaceScale,
    this.fontScaleFactor = AppDisplayPreferences.defaultFontScale,
  });

  final Set<String> favoriteTrackIds;
  final Set<String> likedTrackIds;
  final bool enablePersistentPlaybackCache;
  final int memoryPlaybackCacheTrackLimit;
  final AppThemePreference themePreference;
  final AppLocalePreference localePreference;
  final double interfaceScaleFactor;
  final double fontScaleFactor;

  PlaybackCacheSettings get playbackCacheSettings {
    return PlaybackCacheSettings(
      enablePersistentCache: enablePersistentPlaybackCache,
      memoryCacheTrackLimit: memoryPlaybackCacheTrackLimit,
    ).normalized;
  }

  LibraryPreferences copyWith({
    Set<String>? favoriteTrackIds,
    Set<String>? likedTrackIds,
    bool? enablePersistentPlaybackCache,
    int? memoryPlaybackCacheTrackLimit,
    AppThemePreference? themePreference,
    AppLocalePreference? localePreference,
    double? interfaceScaleFactor,
    double? fontScaleFactor,
  }) {
    return LibraryPreferences(
      favoriteTrackIds: favoriteTrackIds ?? this.favoriteTrackIds,
      likedTrackIds: likedTrackIds ?? this.likedTrackIds,
      enablePersistentPlaybackCache:
          enablePersistentPlaybackCache ?? this.enablePersistentPlaybackCache,
      memoryPlaybackCacheTrackLimit:
          memoryPlaybackCacheTrackLimit ?? this.memoryPlaybackCacheTrackLimit,
      themePreference: themePreference ?? this.themePreference,
      localePreference: localePreference ?? this.localePreference,
      interfaceScaleFactor: AppDisplayPreferences.normalizeInterfaceScale(
        interfaceScaleFactor ?? this.interfaceScaleFactor,
      ),
      fontScaleFactor: AppDisplayPreferences.normalizeFontScale(
        fontScaleFactor ?? this.fontScaleFactor,
      ),
    );
  }
}

abstract class LibraryPreferencesRepository {
  Future<LibraryPreferences> load();

  Future<void> save(LibraryPreferences preferences);
}

class SecureLibraryPreferencesRepository
    implements LibraryPreferencesRepository {
  SecureLibraryPreferencesRepository(this._storage);

  static const _key = 'library_preferences_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<LibraryPreferences> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) {
      return const LibraryPreferences();
    }

    final json = jsonDecode(raw) as Map<String, dynamic>;
    return LibraryPreferences(
      favoriteTrackIds: (json['favoriteTrackIds'] as List<dynamic>? ?? const [])
          .cast<String>()
          .toSet(),
      likedTrackIds: (json['likedTrackIds'] as List<dynamic>? ?? const [])
          .cast<String>()
          .toSet(),
      enablePersistentPlaybackCache:
          json['enablePersistentPlaybackCache'] as bool? ?? false,
      memoryPlaybackCacheTrackLimit:
          json['memoryPlaybackCacheTrackLimit'] as int? ?? 3,
      themePreference: AppDisplayPreferences.themePreferenceFromStorage(
        json['themePreference'] as String?,
      ),
      localePreference: AppDisplayPreferences.localePreferenceFromStorage(
        json['localePreference'] as String?,
      ),
      interfaceScaleFactor: AppDisplayPreferences.interfaceScaleFromStorage(
        json['interfaceScaleFactor'] ?? json['interfaceDensity'],
      ),
      fontScaleFactor: AppDisplayPreferences.fontScaleFromStorage(
        json['fontScaleFactor'] ?? json['fontScale'],
      ),
    );
  }

  @override
  Future<void> save(LibraryPreferences preferences) {
    final normalizedCacheSettings = preferences.playbackCacheSettings;
    final raw = jsonEncode({
      'favoriteTrackIds': preferences.favoriteTrackIds.toList()..sort(),
      'likedTrackIds': preferences.likedTrackIds.toList()..sort(),
      'enablePersistentPlaybackCache':
          normalizedCacheSettings.enablePersistentCache,
      'memoryPlaybackCacheTrackLimit':
          normalizedCacheSettings.memoryCacheTrackLimit,
      'themePreference': preferences.themePreference.name,
      'localePreference': preferences.localePreference.name,
      'interfaceScaleFactor': AppDisplayPreferences.normalizeInterfaceScale(
        preferences.interfaceScaleFactor,
      ),
      'fontScaleFactor': AppDisplayPreferences.normalizeFontScale(
        preferences.fontScaleFactor,
      ),
    });
    return _storage.write(key: _key, value: raw);
  }
}

@Riverpod(keepAlive: true)
LibraryPreferencesRepository libraryPreferencesRepository(Ref ref) {
  return SecureLibraryPreferencesRepository(const FlutterSecureStorage());
}
