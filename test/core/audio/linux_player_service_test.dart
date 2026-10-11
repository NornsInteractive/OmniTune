import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/audio/player_service.dart';
import 'package:music/core/models/playable_track.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Linux backend loads, plays and seeks a PCM file', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final directory = await Directory.systemTemp.createTemp('omnitune-audio-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/silence.wav');
    final wav = ByteData(44 + 32000);
    final bytes = wav.buffer.asUint8List();
    bytes.setRange(0, 4, 'RIFF'.codeUnits);
    wav.setUint32(4, bytes.length - 8, Endian.little);
    bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
    wav.setUint32(16, 16, Endian.little);
    wav.setUint16(20, 1, Endian.little);
    wav.setUint16(22, 1, Endian.little);
    wav.setUint32(24, 8000, Endian.little);
    wav.setUint32(28, 16000, Endian.little);
    wav.setUint16(32, 2, Endian.little);
    wav.setUint16(34, 16, Endian.little);
    bytes.setRange(36, 40, 'data'.codeUnits);
    wav.setUint32(40, 32000, Endian.little);
    await file.writeAsBytes(bytes);

    final service = PlayerService();
    addTearDown(service.dispose);
    final errors = <PlayerException>[];
    final errorSubscription = service.errorStream.listen(errors.add);
    addTearDown(errorSubscription.cancel);
    await service
        .loadTrack(
          PlayableTrack(
            id: 'linux-smoke',
            sourceId: 'local',
            title: 'Linux smoke',
            sourceName: 'Local',
            remotePath: file.path,
            audioSource: AudioSource.uri(file.uri),
          ),
        )
        .timeout(const Duration(seconds: 10));
    final duration = await service.durationStream
        .firstWhere((value) => value != null)
        .timeout(const Duration(seconds: 5));
    expect(duration!.inMilliseconds, closeTo(2000, 50));
    unawaited(service.play());
    await service.positionStream
        .firstWhere((value) => value.inMilliseconds >= 200)
        .timeout(const Duration(seconds: 5));
    await service.pause();
    expect(service.isPlaying, isFalse);
    await service.seek(const Duration(seconds: 1));
    final position = await service.positionStream
        .firstWhere((value) => value.inMilliseconds >= 950)
        .timeout(const Duration(seconds: 5));
    expect(position.inMilliseconds, closeTo(1000, 100));
    await service.stop();
    expect(service.currentTrack, isNull);
    expect(errors, isEmpty);
  }, skip: !Platform.isLinux);
}
