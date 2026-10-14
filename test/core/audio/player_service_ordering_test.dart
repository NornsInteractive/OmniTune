import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:music/core/audio/player_service.dart';
import 'package:music/core/models/playable_track.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      AudioSource.uri(Uri.parse('https://example.com/audio.mp3')),
    );
  });

  late _MockAudioPlayer player;
  late StreamController<PlayerException> errors;

  setUp(() {
    player = _MockAudioPlayer();
    errors = StreamController<PlayerException>.broadcast();
    when(() => player.errorStream).thenAnswer((_) => errors.stream);
    when(() => player.playing).thenReturn(false);
    when(() => player.position).thenReturn(Duration.zero);
    when(() => player.processingState)
        .thenReturn(ProcessingState.idle);
    when(() => player.bufferedPosition).thenReturn(Duration.zero);
    when(() => player.duration).thenReturn(null);
    when(() => player.playerStateStream)
        .thenAnswer((_) => const Stream<PlayerState>.empty());
    when(() => player.positionStream)
        .thenAnswer((_) => const Stream<Duration>.empty());
    when(() => player.durationStream)
        .thenAnswer((_) => const Stream<Duration?>.empty());
    when(() => player.bufferedPositionStream)
        .thenAnswer((_) => const Stream<Duration>.empty());
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.pause()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) async => const Duration(seconds: 1));
  });

  tearDown(() async {
    await errors.close();
  });

  PlayableTrack track(String id) {
    return PlayableTrack(
      id: id,
      sourceId: 'source-1',
      title: 'Track $id',
      sourceName: 'Source',
      remotePath: '/$id.mp3',
      audioSource: AudioSource.uri(Uri.parse('https://example.com/$id.mp3')),
    );
  }

  test('playTrack completes while underlying play stays pending', () async {
    var playCalls = 0;
    final playCompleter = Completer<void>();
    when(() => player.play()).thenAnswer((_) {
      playCalls++;
      return playCompleter.future;
    });

    final service = PlayerService(player: player);
    addTearDown(service.dispose);

    await expectLater(service.playTrack(track('a')), completes);
    expect(playCalls, 1);
    expect(service.currentTrack?.id, 'a');

    playCompleter.complete();
    await Future<void>.delayed(Duration.zero);
  });

  test('A slow then B fast leaves B as current track', () async {
    final firstCompleter = Completer<Duration?>();
    var setCalls = 0;
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) {
      setCalls++;
      return setCalls == 1
          ? firstCompleter.future
          : Future<Duration?>.value(const Duration(seconds: 1));
    });

    final service = PlayerService(player: player);
    addTearDown(service.dispose);

    final trackA = track('a');
    final trackB = track('b');
    final firstLoad = service.loadTrack(trackA);
    final secondLoad = service.loadTrack(trackB);
    await secondLoad;
    expect(service.currentTrack?.id, 'b');

    firstCompleter.complete(const Duration(seconds: 1));
    await firstLoad;
    expect(service.currentTrack?.id, 'b');
  });

  test('stop during pending load keeps playback stopped', () async {
    final loadCompleter = Completer<Duration?>();
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) => loadCompleter.future);

    final service = PlayerService(player: player);
    addTearDown(service.dispose);

    final pendingLoad = service.loadTrack(track('a'));
    await service.stop();
    loadCompleter.complete(const Duration(seconds: 1));
    await pendingLoad;

    expect(service.currentTrack, isNull);
  });

  test('play reports async player errors without unhandled futures', () async {
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) async => const Duration(seconds: 1));

    final playCompleter = Completer<void>();
    when(() => player.play()).thenAnswer((_) => playCompleter.future);

    final service = PlayerService(player: player);
    addTearDown(service.dispose);

    await service.playTrack(track('a'));

    final errorsFuture = service.errorStream.first.timeout(
      const Duration(seconds: 1),
    );
    playCompleter.completeError(StateError('play exploded'));
    final error = await errorsFuture;
    expect(error.message, contains('play exploded'));
  });

  test('late setAudioSource error from superseded request does not stop newer track', () async {
    final firstCompleter = Completer<Duration?>();
    var callCount = 0;
    when(
      () => player.setAudioSource(
        any(),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) {
      callCount++;
      return callCount == 1
          ? firstCompleter.future
          : Future<Duration?>.value(const Duration(seconds: 1));
    });

    final service = PlayerService(player: player);
    addTearDown(service.dispose);

    final firstLoad = service.loadTrack(track('a'));
    final secondLoad = service.loadTrack(track('b'));
    await secondLoad;
    expect(service.currentTrack?.id, 'b');

    firstCompleter.completeError(StateError('late source error'));
    await firstLoad;
    expect(service.currentTrack?.id, 'b');
    verifyNever(() => player.stop());
  });
}
