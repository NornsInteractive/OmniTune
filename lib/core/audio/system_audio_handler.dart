import 'package:audio_service/audio_service.dart';

class OmniSystemAudioHandler extends BaseAudioHandler {
  Future<void> Function()? _onPlay;
  Future<void> Function()? _onPause;
  Future<void> Function()? _onStop;
  Future<void> Function()? _onSkipToNext;
  Future<void> Function()? _onSkipToPrevious;
  Future<void> Function(Duration position)? _onSeek;
  Future<void> Function(int index)? _onSkipToQueueItem;

  void bindCallbacks({
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
    Future<void> Function()? onStop,
    Future<void> Function()? onSkipToNext,
    Future<void> Function()? onSkipToPrevious,
    Future<void> Function(Duration position)? onSeek,
    Future<void> Function(int index)? onSkipToQueueItem,
  }) {
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
  }) {
    final controls = <MediaControl>[
      if (canSkipToPrevious) MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      if (canSkipToNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.playPause,
          if (canSeek) MediaAction.seek,
          if (hasQueue) MediaAction.skipToQueueItem,
          if (canSkipToPrevious) MediaAction.skipToPrevious,
          if (canSkipToNext) MediaAction.skipToNext,
        },
        androidCompactActionIndices: <int>[
          for (var index = 0; index < controls.length && index < 3; index++)
            index,
        ],
        processingState: processingState,
        playing: playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: speed,
        queueIndex: queueIndex,
      ),
    );
  }

  void updateCurrentItem(MediaItem? currentItem) {
    mediaItem.add(currentItem);
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
  await AudioService.init(
    builder: () {
      _systemAudioHandler = OmniSystemAudioHandler();
      _systemAudioHandlerInitialized = true;
      return _systemAudioHandler;
    },
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.norns.omnitune.channel.playback',
      androidNotificationChannelName: 'OmniTune Playback',
      androidStopForegroundOnPause: false,
    ),
  );
  _systemAudioHandler.updateState(
    playing: false,
    processingState: AudioProcessingState.ready,
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
