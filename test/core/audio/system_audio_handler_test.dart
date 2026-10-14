import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/audio/system_audio_handler.dart';

void main() {
  group('OmniSystemAudioHandler', () {
    late OmniSystemAudioHandler handler;

    setUp(() {
      handler = OmniSystemAudioHandler();
    });

    test('initial state has no callbacks bound', () {
      expect(handler.queue.value, isEmpty);
      expect(handler.mediaItem.value, isNull);
      expect(handler.playbackState.value.playing, isFalse);
    });

    test('callback dispatch', () async {
      var play = 0;
      var pause = 0;
      var stop = 0;
      var next = 0;
      var prev = 0;
      Duration? seek;
      int? skip;

      handler.bindCallbacks(
        onPlay: () async => play++,
        onPause: () async => pause++,
        onStop: () async => stop++,
        onSkipToNext: () async => next++,
        onSkipToPrevious: () async => prev++,
        onSeek: (pos) async => seek = pos,
        onSkipToQueueItem: (index) async => skip = index,
        onSetRepeatMode: (_) async {},
        onSetShuffleMode: (_) async {},
        onSetFavorite: (_) async {},
        onCyclePlaybackMode: () async {},
      );

      await handler.play();
      await handler.pause();
      await handler.stop();
      await handler.skipToNext();
      await handler.skipToPrevious();
      await handler.seek(const Duration(seconds: 30));
      await handler.skipToQueueItem(5);

      expect(play, 1);
      expect(pause, 1);
      expect(stop, 1);
      expect(next, 1);
      expect(prev, 1);
      expect(seek, const Duration(seconds: 30));
      expect(skip, 5);
    });

    test('setRepeatMode and shuffleMode callbacks dispatch', () async {
      AudioServiceRepeatMode? repeat;
      AudioServiceShuffleMode? shuffle;
      bool? favorite;

      handler.bindCallbacks(
        onSetRepeatMode: (mode) async => repeat = mode,
        onSetShuffleMode: (mode) async => shuffle = mode,
        onSetFavorite: (value) async => favorite = value,
        onCyclePlaybackMode: () async {},
      );

      await handler.setRepeatMode(AudioServiceRepeatMode.all);
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      await handler.setRating(Rating.newHeartRating(true));

      expect(repeat, AudioServiceRepeatMode.all);
      expect(shuffle, AudioServiceShuffleMode.all);
      expect(favorite, isTrue);
    });

    test('cyclePlaybackMode custom action dispatches', () async {
      var cycled = false;
      handler.bindCallbacks(onCyclePlaybackMode: () async => cycled = true);
      await handler.customAction('cyclePlaybackMode');
      expect(cycled, isTrue);
    });

    test('updateState publishes state through BehaviorSubject value', () {
      handler.updateState(
        playing: true,
        processingState: AudioProcessingState.ready,
        position: const Duration(seconds: 10),
        bufferedPosition: const Duration(seconds: 15),
        speed: 1.0,
        queueIndex: 2,
        canSkipToPrevious: true,
        canSkipToNext: true,
        canSeek: true,
        hasQueue: true,
      );

      final state = handler.playbackState.value;
      expect(state.playing, isTrue);
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.updatePosition, const Duration(seconds: 10));
      expect(state.bufferedPosition, const Duration(seconds: 15));
      expect(state.speed, 1.0);
      expect(state.queueIndex, 2);
      expect(state.controls, contains(MediaControl.skipToPrevious));
      expect(state.controls, contains(MediaControl.pause));
      expect(state.controls, contains(MediaControl.skipToNext));
      expect(state.systemActions, contains(MediaAction.seek));
    });

    test('updateState dedupes identical state within one second', () {
      handler.updateState(
        playing: true,
        processingState: AudioProcessingState.ready,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: 0,
        canSkipToPrevious: true,
        canSkipToNext: true,
        canSeek: true,
        hasQueue: true,
      );
      final before = handler.playbackState.value;

      handler.updateState(
        playing: true,
        processingState: AudioProcessingState.ready,
        position: const Duration(milliseconds: 100),
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: 0,
        canSkipToPrevious: true,
        canSkipToNext: true,
        canSeek: true,
        hasQueue: true,
      );

      expect(handler.playbackState.value, same(before));
    });

    test('force bypasses dedupe throttle', () {
      handler.updateState(
        playing: true,
        processingState: AudioProcessingState.ready,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: 0,
        canSkipToPrevious: true,
        canSkipToNext: true,
        canSeek: true,
        hasQueue: true,
      );

      handler.updateState(
        playing: true,
        processingState: AudioProcessingState.ready,
        position: const Duration(seconds: 5),
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: 0,
        canSkipToPrevious: true,
        canSkipToNext: true,
        canSeek: true,
        hasQueue: true,
        force: true,
      );

      expect(
        handler.playbackState.value.updatePosition,
        const Duration(seconds: 5),
      );
    });

    test('immediate state changes emit when key changes', () {
      handler.updateState(
        playing: false,
        processingState: AudioProcessingState.idle,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: null,
        canSkipToPrevious: false,
        canSkipToNext: false,
        canSeek: false,
        hasQueue: false,
      );
      expect(handler.playbackState.value.playing, isFalse);

      handler.updateState(
        playing: true,
        processingState: AudioProcessingState.ready,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
        queueIndex: 0,
        canSkipToPrevious: true,
        canSkipToNext: true,
        canSeek: true,
        hasQueue: true,
      );
      expect(handler.playbackState.value.playing, isTrue);
    });

    test(
      'androidCompactActionIndices is populated from non-custom controls',
      () {
        handler.updateState(
          playing: true,
          processingState: AudioProcessingState.ready,
          position: Duration.zero,
          bufferedPosition: Duration.zero,
          speed: 1.0,
          queueIndex: 0,
          canSkipToPrevious: true,
          canSkipToNext: true,
          canSeek: true,
          hasQueue: true,
        );

        final compactIndices =
            handler.playbackState.value.androidCompactActionIndices;
        expect(compactIndices, isNotNull);
        expect(compactIndices!, isNotEmpty);
      },
    );

    test('updateCurrentItem and updateQueue behave', () async {
      handler.updateCurrentItem(const MediaItem(id: '1', title: 'Track'));
      expect(handler.mediaItem.value?.id, '1');
      handler.updateCurrentItem(null);
      expect(handler.mediaItem.value, isNull);

      final queue = [
        const MediaItem(id: '1', title: 'Track 1'),
        const MediaItem(id: '2', title: 'Track 2'),
      ];
      await handler.updateQueue(queue);
      expect(handler.queue.value, hasLength(2));
    });

    test('minor missing callbacks do not throw', () async {
      handler.bindCallbacks(onPlay: null);
      await expectLater(handler.play(), completes);
    });
  });
}
