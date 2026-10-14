import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import '../i18n/localizations.dart';

class OmniSystemAudioHandler extends BaseAudioHandler {
  DateTime? _lastStateSentAt;
  String? _lastStateKey;
  bool _isFavorite = false;
  Future<void> Function(AudioServiceRepeatMode)? _onSetRepeatMode;
  Future<void> Function(AudioServiceShuffleMode)? _onSetShuffleMode;
  Future<void> Function(bool)? _onSetFavorite;
  Future<void> Function()? _onCyclePlaybackMode;
  Future<void> Function()? _onPlay;
  Future<void> Function()? _onPause;
  Future<void> Function()? _onStop;
  Future<void> Function()? _onSkipToNext;
  Future<void> Function()? _onSkipToPrevious;
  Future<void> Function(Duration position)? _onSeek;
  Future<void> Function(int index)? _onSkipToQueueItem;

  void bindCallbacks({
    Future<void> Function(AudioServiceRepeatMode)? onSetRepeatMode,
    Future<void> Function(AudioServiceShuffleMode)? onSetShuffleMode,
    Future<void> Function(bool)? onSetFavorite,
    Future<void> Function()? onCyclePlaybackMode,
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
    Future<void> Function()? onStop,
    Future<void> Function()? onSkipToNext,
    Future<void> Function()? onSkipToPrevious,
    Future<void> Function(Duration position)? onSeek,
    Future<void> Function(int index)? onSkipToQueueItem,
  }) {
    _onSetRepeatMode = onSetRepeatMode;
    _onSetShuffleMode = onSetShuffleMode;
    _onSetFavorite = onSetFavorite;
    _onCyclePlaybackMode = onCyclePlaybackMode;
    ratingStyle.add(RatingStyle.heart);
    _onPlay = onPlay;
    _onPause = onPause;
    _onStop = onStop;
    _onSkipToNext = onSkipToNext;
    _onSkipToPrevious = onSkipToPrevious;
    _onSeek = onSeek;
    _onSkipToQueueItem = onSkipToQueueItem;
  }

  void updateState({
    required bool playing,
    required AudioProcessingState processingState,
    required Duration position,
    required Duration bufferedPosition,
    required double speed,
    required int? queueIndex,
    required bool canSkipToPrevious,
    required bool canSkipToNext,
    required bool canSeek,
    required bool hasQueue,
    AudioServiceRepeatMode repeatMode = AudioServiceRepeatMode.none,
    AudioServiceShuffleMode shuffleMode = AudioServiceShuffleMode.none,
    bool isFavorite = false,
    String? favoriteLabel,
    String? playbackModeLabel,
    String? errorMessage,
    bool force = false,
  }) {
    if (_isFavorite != isFavorite && mediaItem.value != null) {
      mediaItem.add(
        mediaItem.value!.copyWith(rating: Rating.newHeartRating(isFavorite)),
      );
    }
    _isFavorite = isFavorite;
    final now = DateTime.now();
    final stateKey = [
      playing,
      processingState,
      speed,
      queueIndex,
      canSkipToPrevious,
      canSkipToNext,
      canSeek,
      hasQueue,
      repeatMode,
      shuffleMode,
      isFavorite,
      favoriteLabel,
      playbackModeLabel,
      errorMessage,
    ].join('|');
    if (!force &&
        stateKey == _lastStateKey &&
        _lastStateSentAt != null &&
        now.difference(_lastStateSentAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastStateKey = stateKey;
    _lastStateSentAt = now;
    final controls = <MediaControl>[
      if (hasQueue) ...[
        if (canSkipToPrevious) MediaControl.skipToPrevious,
        if (playing && errorMessage == null)
          MediaControl.pause
        else
          MediaControl.play,
        if (canSkipToNext) MediaControl.skipToNext,
        if (favoriteLabel != null)
          MediaControl.custom(
            androidIcon: isFavorite
                ? 'drawable/ic_favorite'
                : 'drawable/ic_favorite_border',
            label: favoriteLabel,
            name: 'toggleFavorite',
          ),
        if (playbackModeLabel != null)
          MediaControl.custom(
            androidIcon: 'drawable/ic_playback_mode',
            label: playbackModeLabel,
            name: 'cyclePlaybackMode',
          ),
      ],
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: {
          if (hasQueue) ...{
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
            MediaAction.playPause,
            if (canSeek) MediaAction.seek,
            if (hasQueue) MediaAction.skipToQueueItem,
            if (canSkipToPrevious) MediaAction.skipToPrevious,
            if (canSkipToNext) MediaAction.skipToNext,
            MediaAction.setRepeatMode,
            MediaAction.setShuffleMode,
            MediaAction.setRating,
          },
        },
        androidCompactActionIndices: <int>[
          for (var index = 0; index < controls.length; index++)
            if (controls[index].action != MediaAction.custom) index,
        ],
        repeatMode: repeatMode,
        shuffleMode: shuffleMode,
        errorCode: errorMessage == null ? null : 1,
        errorMessage: errorMessage,
        processingState: errorMessage != null
            ? AudioProcessingState.error
            : processingState,
        playing: playing && errorMessage == null,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: speed,
        queueIndex: queueIndex,
      ),
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async =>
      _onSetRepeatMode?.call(repeatMode);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async =>
      _onSetShuffleMode?.call(shuffleMode);

  @override
  Future<void> setRating(Rating rating, [Map<String, dynamic>? extras]) async {
    if (rating.getRatingStyle() == RatingStyle.heart && rating.isRated()) {
      await _onSetFavorite?.call(rating.hasHeart());
    }
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'toggleFavorite') await _onSetFavorite?.call(!_isFavorite);
    if (name == 'cyclePlaybackMode') await _onCyclePlaybackMode?.call();
  }

  void updateCurrentItem(MediaItem? currentItem) {
    mediaItem.add(
      currentItem?.copyWith(rating: Rating.newHeartRating(_isFavorite)),
    );
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    this.queue.add(List<MediaItem>.unmodifiable(queue));
  }

  @override
  Future<void> play() async => _onPlay?.call();

  @override
  Future<void> pause() async => _onPause?.call();

  @override
  Future<void> stop() async => _onStop?.call();

  @override
  Future<void> skipToNext() async => _onSkipToNext?.call();

  @override
  Future<void> skipToPrevious() async => _onSkipToPrevious?.call();

  @override
  Future<void> seek(Duration position) async => _onSeek?.call(position);

  @override
  Future<void> skipToQueueItem(int index) async =>
      _onSkipToQueueItem?.call(index);
}

late final OmniSystemAudioHandler _systemAudioHandler;
var _systemAudioHandlerInitialized = false;

Future<void> initializeSystemAudioHandler() async {
  if (_systemAudioHandlerInitialized) {
    return;
  }
  final language =
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l10n = lookupAppLocalizations(Locale(language == 'zh' ? 'zh' : 'en'));
  await AudioService.init(
    builder: () {
      _systemAudioHandler = OmniSystemAudioHandler();
      return _systemAudioHandler;
    },
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.norns.omnitune.channel.playback',
      androidNotificationChannelName: l10n.systemPlaybackChannel,
      androidNotificationIcon: 'drawable/ic_notification',
      androidStopForegroundOnPause: false,
    ),
  );
  _systemAudioHandlerInitialized = true;
  _systemAudioHandler.updateState(
    playing: false,
    processingState: AudioProcessingState.idle,
    position: Duration.zero,
    bufferedPosition: Duration.zero,
    speed: 1,
    queueIndex: null,
    canSkipToPrevious: false,
    canSkipToNext: false,
    canSeek: false,
    hasQueue: false,
  );
}

OmniSystemAudioHandler get systemAudioHandler => _systemAudioHandler;

bool get isSystemAudioHandlerInitialized => _systemAudioHandlerInitialized;
