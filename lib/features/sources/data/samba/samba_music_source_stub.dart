import 'dart:typed_data';

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';

class SambaMusicSource implements MusicSource {
  const SambaMusicSource(this.profile);

  @override
  final SourceProfile profile;

  @override
  Future<void> connect() => throw UnsupportedError(
    'Samba sources are not available on this platform.',
  );

  @override
  Future<void> disconnect() async {}

  @override
  Future<DirectoryListing> listFiles(String path) => throw UnsupportedError(
    'Samba sources are not available on this platform.',
  );

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) =>
      throw UnsupportedError(
        'Samba sources are not available on this platform.',
      );

  @override
  Future<String?> readTextFile(String path) async => null;

  @override
  Future<Uint8List?> readBinaryFile(String path) async => null;
}

class SambaMusicSourceFactory implements MusicSourceFactory {
  const SambaMusicSourceFactory();

  @override
  SourceProtocol get protocol => SourceProtocol.samba;

  @override
  MusicSource create(SourceProfile profile) {
    return SambaMusicSource(profile);
  }
}
