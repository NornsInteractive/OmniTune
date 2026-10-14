import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:audio_service/audio_service.dart';

import 'package:music/core/audio/system_audio_handler.dart';
import 'package:music/features/player/application/player_controller.dart';
import 'package:music/core/models/library_song.dart';

void main() {
  group('PlayerViewState repeatAll', () {
    test('canPlayNext returns true for repeatAll', () {
      final playlist = List<LibrarySong>.generate(
        3,
        (i) => LibrarySong(
          id: 'song-$i',
          sourceId: 'src-1',
          sourceName: 'WebDAV',
          title: 'Song $i',
          fileName: 'song-$i.flac',
          remotePath: '/music/song-$i.flac',
          albumTitle: 'Album',
          artistName: 'Artist',
          directoryPath: '/music',
          folderAlbumTitle: 'Album',
          folderArtistName: 'Artist',
        ),
      );
      final state = PlayerViewState(
        currentTrack: null,
        isPlaying: false,
        processingState: ProcessingState.idle,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: null,
        playlist: playlist,
        currentIndex: 2,
        playbackMode: PlayerPlaybackMode.repeatAll,
      );
      expect(state.canPlayNext, isTrue);
    });

    test('canPlayPrevious returns true for repeatAll', () {
      final playlist = List<LibrarySong>.generate(
        3,
        (i) => LibrarySong(
          id: 'song-$i',
          sourceId: 'src-1',
          sourceName: 'WebDAV',
          title: 'Song $i',
          fileName: 'song-$i.flac',
          remotePath: '/music/song-$i.flac',
          albumTitle: 'Album',
          artistName: 'Artist',
          directoryPath: '/music',
          folderAlbumTitle: 'Album',
          folderArtistName: 'Artist',
        ),
      );
      final state = PlayerViewState(
        currentTrack: null,
        isPlaying: false,
        processingState: ProcessingState.idle,
        position: Duration.zero,
        bufferedPosition: Duration.zero,
        duration: null,
        playlist: playlist,
        currentIndex: 0,
        playbackMode: PlayerPlaybackMode.repeatAll,
      );
      expect(state.canPlayPrevious, isTrue);
    });
  });

  group('SystemAudioHandler repeat mode callbacks', () {
    late OmniSystemAudioHandler handler;

    setUp(() {
      handler = OmniSystemAudioHandler();
    });

    test('updateState with repeatAll shows correct controls', () {
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
        repeatMode: AudioServiceRepeatMode.all,
      );

      final state = handler.playbackState.value;
      expect(state.controls, contains(MediaControl.skipToPrevious));
      expect(state.controls, contains(MediaControl.skipToNext));
      expect(state.systemActions, contains(MediaAction.skipToPrevious));
      expect(state.systemActions, contains(MediaAction.skipToNext));
      expect(state.repeatMode, AudioServiceRepeatMode.all);
    });
  });
}
