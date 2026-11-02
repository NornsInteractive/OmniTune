import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_preferences.dart';
import '../../../core/models/custom_theme_colors.dart';
import '../../../core/models/library_album.dart';
import '../../../core/models/widget_style_config.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../core/widgets/widget_sync_service.dart';

class AppSettingsController extends AsyncNotifier<LibraryPreferences> {
  @override
  Future<LibraryPreferences> build() async {
    final preferences = await ref
        .read(libraryPreferencesRepositoryProvider)
        .load();
    DebugLogger.setDebugEnabled(preferences.enableDebugMode);
    WidgetSyncService.instance.syncWidgetStyleConfigs(
      small: preferences.widgetSmallConfig,
      medium: preferences.widgetMediumConfig,
      large: preferences.widgetLargeConfig,
    );
    return preferences;
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    await _save((preferences) => preferences.copyWith(themePreference: value));
  }

  Future<void> setLocalePreference(AppLocalePreference value) async {
    await _save((preferences) => preferences.copyWith(localePreference: value));
  }

  Future<void> setInterfaceScale(double value) async {
    await _save(
      (preferences) => preferences.copyWith(interfaceScaleFactor: value),
    );
  }

  Future<void> setFontScale(double value) async {
    await _save((preferences) => preferences.copyWith(fontScaleFactor: value));
  }

  Future<void> setAlbumPageSize(int value) async {
    await _save((preferences) => preferences.copyWith(albumPageSize: value));
  }

  Future<void> setAlbumViewGrid(bool value) async {
    await _save((preferences) => preferences.copyWith(albumViewGrid: value));
  }

  Future<void> setAlbumGroupingMode(LibraryAlbumGroupingMode value) async {
    await _save(
      (preferences) => preferences.copyWith(albumGroupingMode: value),
    );
  }

  Future<void> setDebugMode(bool value) async {
    await _save((preferences) => preferences.copyWith(enableDebugMode: value));
  }

  Future<void> setLyricsScrapingServiceBaseUrl(String? value) async {
    final normalized = _normalizeServiceUrl(value);
    await _save(
      (preferences) => preferences.copyWith(
        lyricsScrapingServiceBaseUrl: normalized.isEmpty ? null : normalized,
        clearLyricsScrapingServiceBaseUrl: normalized.isEmpty,
      ),
    );
  }

  Future<void> setEnableLyricsScraping(bool value) async {
    await _save(
      (preferences) => preferences.copyWith(enableLyricsScraping: value),
    );
  }

  Future<void> setEnableFolderArtworkForSongs(bool value) async {
    await _save(
      (preferences) => preferences.copyWith(enableFolderArtworkForSongs: value),
    );
  }

  Future<void> setGroupMetadataAlbumsByArtist(bool value) async {
    await _save(
      (preferences) => preferences.copyWith(groupMetadataAlbumsByArtist: value),
    );
  }

  Future<void> setEnableDeezerCoverScraping(bool value) async {
    await _save(
      (preferences) => preferences.copyWith(enableDeezerCoverScraping: value),
    );
  }

  Future<void> setEnableItunesMetadataScraping(bool value) async {
    await _save(
      (preferences) =>
          preferences.copyWith(enableItunesMetadataScraping: value),
    );
  }

  Future<void> setCustomThemeColors(CustomThemeColors value) async {
    await _save(
      (preferences) => preferences.copyWith(customThemeColors: value),
    );
  }

  Future<void> setBackgroundImage({
    required String source,
    required double alignmentX,
    required double alignmentY,
  }) async {
    await _save(
      (preferences) => preferences.copyWith(
        backgroundImageSource: source,
        backgroundImageAlignmentX: alignmentX,
        backgroundImageAlignmentY: alignmentY,
      ),
    );
  }

  Future<void> setBackgroundImagePosition({
    required double alignmentX,
    required double alignmentY,
  }) async {
    await _save(
      (preferences) => preferences.copyWith(
        backgroundImageAlignmentX: alignmentX,
        backgroundImageAlignmentY: alignmentY,
      ),
    );
  }

  Future<void> clearBackgroundImage() async {
    await _save(
      (preferences) => preferences.copyWith(clearBackgroundImageSource: true),
    );
  }

  Future<void> updateWidgetConfig(
    int sizeIndex,
    WidgetStyleConfig config,
  ) async {
    await _save(
      (preferences) => preferences.copyWithWidgetConfig(sizeIndex, config),
    );
    _syncWidgets();
  }

  Future<void> setWidgetCoverPosition(String value) async {
    await _save(
      (preferences) => preferences.copyWith(widgetCoverPosition: value),
    );
    _syncWidgets();
  }

  Future<void> setWidgetCoverFill(bool value) async {
    await _save(
      (preferences) => preferences.copyWith(widgetCoverFill: value),
    );
    _syncWidgets();
  }

  Future<void> setWidgetThemeColor(String value) async {
    await _save(
      (preferences) => preferences.copyWith(widgetThemeColor: value),
    );
    _syncWidgets();
  }

  Future<void> setWidgetBackgroundColor(String value) async {
    await _save(
      (preferences) => preferences.copyWith(widgetBackgroundColor: value),
    );
    _syncWidgets();
  }

  void _syncWidgets() {
    final prefs = state.valueOrNull;
    if (prefs == null) return;
    WidgetSyncService.instance.syncWidgetStyleConfigs(
      small: prefs.widgetSmallConfig,
      medium: prefs.widgetMediumConfig,
      large: prefs.widgetLargeConfig,
    );
  }

  Future<void> _save(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async {
    final repository = ref.read(libraryPreferencesRepositoryProvider);
    final next = await repository.update(transform);
    state = AsyncData(next);
    DebugLogger.setDebugEnabled(next.enableDebugMode);
  }

  String _normalizeServiceUrl(String? value) {
    var normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return '';
    }
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    if (normalized.startsWith('https//')) {
      normalized = normalized.replaceFirst('https//', 'https://');
    } else if (normalized.startsWith('http//')) {
      normalized = normalized.replaceFirst('http//', 'http://');
    } else if (!normalized.contains('://')) {
      normalized = 'https://$normalized';
    }
    return normalized;
  }
}

final appSettingsControllerProvider =
    AsyncNotifierProvider<AppSettingsController, LibraryPreferences>(
      AppSettingsController.new,
    );
