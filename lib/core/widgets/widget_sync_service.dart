import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/widget_style_config.dart';

/// Service responsible for syncing player metadata and playback state
/// to Android AppWidgets and iOS WidgetKit.
class WidgetSyncService {
  WidgetSyncService._();
  static final WidgetSyncService instance = WidgetSyncService._();

  static const String appGroupId = 'group.com.norns.omnitune';

  static const String widgetSmallAndroid = 'OmniTuneWidgetProviderSmall';
  static const String widgetMediumAndroid = 'OmniTuneWidgetProviderMedium';
  static const String widgetLargeAndroid = 'OmniTuneWidgetProviderLarge';

  static const String widgetSmallIOS = 'OmniTuneWidgetSmall';
  static const String widgetMediumIOS = 'OmniTuneWidgetMedium';
  static const String widgetLargeIOS = 'OmniTuneWidgetLarge';

  bool _initialized = false;
  String? _lastTrackId;
  bool? _lastIsPlaying;
  String? _lastLyric;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[WidgetSyncService] Failed to initialize: $e');
    }
  }

  /// Syncs player metadata and playback state to native home screen widgets.
  Future<void> syncPlayerState({
    required String? trackId,
    required String? title,
    required String? artist,
    required String? album,
    required bool isPlaying,
    required bool isFavorite,
    required int positionMs,
    required int durationMs,
    String? formatBadge,
    String? artworkPath,
    String? currentLyric,
    String? nextTrack1,
    String? nextTrack2,
  }) async {
    if (!isSupported) return;
    if (!_initialized) await initialize();

    // Avoid redundant expensive updates if nothing relevant changed
    final trackChanged = _lastTrackId != trackId;
    final playStateChanged = _lastIsPlaying != isPlaying;
    final lyricChanged = _lastLyric != currentLyric;

    if (!trackChanged && !playStateChanged && !lyricChanged) {
      return;
    }

    _lastTrackId = trackId;
    _lastIsPlaying = isPlaying;
    _lastLyric = currentLyric;

    try {
      await HomeWidget.saveWidgetData<String>(
        'widget_title',
        title?.trim().isNotEmpty == true ? title! : 'OmniTune',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_artist',
        artist?.trim().isNotEmpty == true ? artist! : 'Ready to play',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_album',
        album?.trim().isNotEmpty == true ? album! : '',
      );
      await HomeWidget.saveWidgetData<bool>('widget_is_playing', isPlaying);
      await HomeWidget.saveWidgetData<bool>('widget_is_favorite', isFavorite);
      await HomeWidget.saveWidgetData<int>('widget_position_ms', positionMs);
      await HomeWidget.saveWidgetData<int>('widget_duration_ms', durationMs);
      await HomeWidget.saveWidgetData<String>(
        'widget_format',
        formatBadge?.trim().isNotEmpty == true ? formatBadge! : 'Hi-Res',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_artwork_path',
        artworkPath ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_current_lyric',
        currentLyric?.trim().isNotEmpty == true ? currentLyric! : '',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_queue_next1',
        nextTrack1?.trim().isNotEmpty == true ? nextTrack1! : '',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_queue_next2',
        nextTrack2?.trim().isNotEmpty == true ? nextTrack2! : '',
      );

      // Trigger update on all registered widget sizes
      try {
        await HomeWidget.updateWidget(
          name: widgetSmallAndroid,
          androidName: widgetSmallAndroid,
          iOSName: widgetSmallIOS,
        );
      } catch (e) {
        debugPrint('[WidgetSyncService] updateWidget small error: $e');
      }
      try {
        await HomeWidget.updateWidget(
          name: widgetMediumAndroid,
          androidName: widgetMediumAndroid,
          iOSName: widgetMediumIOS,
        );
      } catch (e) {
        debugPrint('[WidgetSyncService] updateWidget medium error: $e');
      }
      try {
        await HomeWidget.updateWidget(
          name: widgetLargeAndroid,
          androidName: widgetLargeAndroid,
          iOSName: widgetLargeIOS,
        );
      } catch (e) {
        debugPrint('[WidgetSyncService] updateWidget large error: $e');
      }
    } catch (e) {
      debugPrint('[WidgetSyncService] Error syncing widget state: $e');
    }
  }

  /// Syncs appearance and style preferences for all widget sizes.
  Future<void> syncWidgetStyleConfigs({
    required WidgetStyleConfig small,
    required WidgetStyleConfig medium,
    required WidgetStyleConfig large,
  }) async {
    if (!isSupported) return;
    if (!_initialized) await initialize();

    try {
      // Small 2x2
      await HomeWidget.saveWidgetData<String>('widget_small_cover_pos', small.coverPosition);
      await HomeWidget.saveWidgetData<bool>('widget_small_cover_fill', small.coverFill);
      await HomeWidget.saveWidgetData<double>('widget_small_cover_opacity', small.coverOpacity);
      await HomeWidget.saveWidgetData<String>('widget_small_theme_color', small.themeColor);
      await HomeWidget.saveWidgetData<String>('widget_small_bg_color', small.backgroundColor);
      await HomeWidget.saveWidgetData<bool>('widget_small_show_lyrics', small.showLyrics);

      // Medium 4x2
      await HomeWidget.saveWidgetData<String>('widget_medium_cover_pos', medium.coverPosition);
      await HomeWidget.saveWidgetData<bool>('widget_medium_cover_fill', medium.coverFill);
      await HomeWidget.saveWidgetData<double>('widget_medium_cover_opacity', medium.coverOpacity);
      await HomeWidget.saveWidgetData<String>('widget_medium_theme_color', medium.themeColor);
      await HomeWidget.saveWidgetData<String>('widget_medium_bg_color', medium.backgroundColor);
      await HomeWidget.saveWidgetData<bool>('widget_medium_show_lyrics', medium.showLyrics);

      // Large 4x4
      await HomeWidget.saveWidgetData<String>('widget_large_cover_pos', large.coverPosition);
      await HomeWidget.saveWidgetData<bool>('widget_large_cover_fill', large.coverFill);
      await HomeWidget.saveWidgetData<double>('widget_large_cover_opacity', large.coverOpacity);
      await HomeWidget.saveWidgetData<String>('widget_large_theme_color', large.themeColor);
      await HomeWidget.saveWidgetData<String>('widget_large_bg_color', large.backgroundColor);
      await HomeWidget.saveWidgetData<bool>('widget_large_show_lyrics', large.showLyrics);

      // Fallback global keys
      await HomeWidget.saveWidgetData<String>('widget_cover_pos', medium.coverPosition);
      await HomeWidget.saveWidgetData<bool>('widget_cover_fill', medium.coverFill);
      await HomeWidget.saveWidgetData<double>('widget_cover_opacity', medium.coverOpacity);
      await HomeWidget.saveWidgetData<String>('widget_theme_color', medium.themeColor);
      await HomeWidget.saveWidgetData<String>('widget_bg_color', medium.backgroundColor);
      await HomeWidget.saveWidgetData<bool>('widget_show_lyrics', medium.showLyrics);

      try {
        await HomeWidget.updateWidget(
          name: widgetSmallAndroid,
          androidName: widgetSmallAndroid,
          iOSName: widgetSmallIOS,
        );
      } catch (_) {}
      try {
        await HomeWidget.updateWidget(
          name: widgetMediumAndroid,
          androidName: widgetMediumAndroid,
          iOSName: widgetMediumIOS,
        );
      } catch (_) {}
      try {
        await HomeWidget.updateWidget(
          name: widgetLargeAndroid,
          androidName: widgetLargeAndroid,
          iOSName: widgetLargeIOS,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('[WidgetSyncService] Error syncing widget style configs: $e');
    }
  }

  /// Legacy helper for syncing widget preferences.
  Future<void> syncWidgetPreferences({
    required String coverPosition,
    required bool coverFill,
    required String themeColor,
    required String backgroundColor,
  }) async {
    final config = WidgetStyleConfig(
      coverPosition: coverPosition,
      coverFill: coverFill,
      themeColor: themeColor,
      backgroundColor: backgroundColor,
    );
    await syncWidgetStyleConfigs(
      small: config,
      medium: config,
      large: config,
    );
  }
}

