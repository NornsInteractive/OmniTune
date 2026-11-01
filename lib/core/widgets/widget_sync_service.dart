import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

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
      await HomeWidget.updateWidget(
        name: widgetSmallAndroid,
        androidName: widgetSmallAndroid,
        iOSName: widgetSmallIOS,
      );
      await HomeWidget.updateWidget(
        name: widgetMediumAndroid,
        androidName: widgetMediumAndroid,
        iOSName: widgetMediumIOS,
      );
      await HomeWidget.updateWidget(
        name: widgetLargeAndroid,
        androidName: widgetLargeAndroid,
        iOSName: widgetLargeIOS,
      );
    } catch (e) {
      debugPrint('[WidgetSyncService] Error syncing widget state: $e');
    }
  }
}
