import 'dart:typed_data';

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';

class LocalMusicSource implements MusicSource {
  const LocalMusicSource(this.profile);

  @override
  final SourceProfile profile;

  @override
  Future<void> connect() => throw UnsupportedError(
    'Local sources are not supported on this platform.',
  );

  @override
  Future<void> disconnect() async {}

  @override
  Future<DirectoryListing> listFiles(String path) => throw UnsupportedError(
    'Local sources are not supported on this platform.',
  );

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) =>
      throw UnsupportedError(
        'Local sources are not supported on this platform.',
      );

  @override
  Future<String?> readTextFile(String path) async => null;

  @override
  Future<Uint8List?> readBinaryFile(String path) async => null;

  @override
  Future<Uint8List?> readBinaryFileHead(
    String path, {
    int length = 128 * 1024,
  }) async => null;
}

class LocalMusicSourceFactory implements MusicSourceFactory {
  const LocalMusicSourceFactory();

  @override
  SourceProtocol get protocol => SourceProtocol.local;

  @override
  MusicSource create(SourceProfile profile) {
    return LocalMusicSource(profile);
  }
}
