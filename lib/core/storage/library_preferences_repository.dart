import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/app_preferences.dart';
import '../models/custom_theme_colors.dart';
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
    this.enableDebugMode = false,
    this.customThemeColors = const CustomThemeColors(),
    this.backgroundImageSource,
    this.backgroundImageAlignmentX = 0,
    this.backgroundImageAlignmentY = 0,
  });

  final Set<String> favoriteTrackIds;
  final Set<String> likedTrackIds;
  final bool enablePersistentPlaybackCache;
  final int memoryPlaybackCacheTrackLimit;
  final AppThemePreference themePreference;
  final AppLocalePreference localePreference;
  final double interfaceScaleFactor;
  final double fontScaleFactor;
  final bool enableDebugMode;
  final CustomThemeColors customThemeColors;
  final String? backgroundImageSource;
  final double backgroundImageAlignmentX;
  final double backgroundImageAlignmentY;

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
    bool? enableDebugMode,
    CustomThemeColors? customThemeColors,
    String? backgroundImageSource,
    bool clearBackgroundImageSource = false,
    double? backgroundImageAlignmentX,
    double? backgroundImageAlignmentY,
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
      enableDebugMode: enableDebugMode ?? this.enableDebugMode,
      customThemeColors: customThemeColors ?? this.customThemeColors,
      backgroundImageSource: clearBackgroundImageSource
          ? null
          : backgroundImageSource ?? this.backgroundImageSource,
      backgroundImageAlignmentX:
          (backgroundImageAlignmentX ?? this.backgroundImageAlignmentX)
              .clamp(-1.0, 1.0)
              .toDouble(),
      backgroundImageAlignmentY:
          (backgroundImageAlignmentY ?? this.backgroundImageAlignmentY)
              .clamp(-1.0, 1.0)
              .toDouble(),
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
  static const _displayDefaultsVersion = 2;

  final FlutterSecureStorage _storage;

  @override
  Future<LibraryPreferences> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) {
      return const LibraryPreferences();
    }

    final json = jsonDecode(raw) as Map<String, dynamic>;
    final displayDefaultsVersion =
        (json['displayDefaultsVersion'] as num?)?.toInt() ?? 0;
    final shouldMigrateDisplayDefaults =
        displayDefaultsVersion < _displayDefaultsVersion;
    final fontScaleStorage = json['fontScaleFactor'] ?? json['fontScale'];
    final fontScaleFactor =
        shouldMigrateDisplayDefaults && _isStoredDefaultScale(fontScaleStorage)
        ? AppDisplayPreferences.defaultFontScale
        : AppDisplayPreferences.fontScaleFromStorage(fontScaleStorage);
    final customThemeColors = _customThemeColorsFromStorage(
      json['customThemeColors'],
      shouldMigrateDisplayDefaults: shouldMigrateDisplayDefaults,
    );

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
      fontScaleFactor: fontScaleFactor,
      enableDebugMode: json['enableDebugMode'] as bool? ?? false,
      customThemeColors: customThemeColors,
      backgroundImageSource: json['backgroundImageSource'] as String?,
      backgroundImageAlignmentX:
          ((json['backgroundImageAlignmentX'] as num?)?.toDouble() ?? 0)
              .clamp(-1.0, 1.0)
              .toDouble(),
      backgroundImageAlignmentY:
          ((json['backgroundImageAlignmentY'] as num?)?.toDouble() ?? 0)
              .clamp(-1.0, 1.0)
              .toDouble(),
    );
  }

  @override
  Future<void> save(LibraryPreferences preferences) {
    final normalizedCacheSettings = preferences.playbackCacheSettings;
    final raw = jsonEncode({
      'favoriteTrackIds': preferences.favoriteTrackIds.toList()..sort(),
      'displayDefaultsVersion': _displayDefaultsVersion,
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
      'enableDebugMode': preferences.enableDebugMode,
      'customThemeColors': preferences.customThemeColors.toJson(),
      'backgroundImageSource': preferences.backgroundImageSource,
      'backgroundImageAlignmentX': preferences.backgroundImageAlignmentX
          .clamp(-1.0, 1.0)
          .toDouble(),
      'backgroundImageAlignmentY': preferences.backgroundImageAlignmentY
          .clamp(-1.0, 1.0)
          .toDouble(),
    });
    return _storage.write(key: _key, value: raw);
  }

  CustomThemeColors _customThemeColorsFromStorage(
    Object? value, {
    required bool shouldMigrateDisplayDefaults,
  }) {
    if (value is! Map<String, dynamic>) {
      return const CustomThemeColors();
    }

    final colors = CustomThemeColors.fromJson(value);
    final compactnessStorage = value['interfaceCompactness'];
    if (shouldMigrateDisplayDefaults &&
        _isStoredDefaultScale(compactnessStorage)) {
      return colors.copyWith(
        interfaceCompactness: const CustomThemeColors().interfaceCompactness,
      );
    }

    return colors;
  }

  bool _isStoredDefaultScale(Object? value) {
    return value is num && (value.toDouble() - 1).abs() < 0.0001;
  }
}

@Riverpod(keepAlive: true)
LibraryPreferencesRepository libraryPreferencesRepository(Ref ref) {
  return SecureLibraryPreferencesRepository(const FlutterSecureStorage());
}
