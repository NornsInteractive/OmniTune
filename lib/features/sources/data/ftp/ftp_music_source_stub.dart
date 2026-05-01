import 'dart:typed_data';

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';

class FtpMusicSource implements MusicSource {
  const FtpMusicSource(this.profile);

  @override
  final SourceProfile profile;

  @override
  Future<void> connect() =>
      throw UnsupportedError('FTP sources are not available on this platform.');

  @override
  Future<void> disconnect() async {}

  @override
  Future<DirectoryListing> listFiles(String path) =>
      throw UnsupportedError('FTP sources are not available on this platform.');

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) =>
      throw UnsupportedError('FTP sources are not available on this platform.');

  @override
  Future<String?> readTextFile(String path) async => null;

  @override
  Future<Uint8List?> readBinaryFile(String path) async => null;
}

class FtpMusicSourceFactory implements MusicSourceFactory {
  const FtpMusicSourceFactory();

  @override
  SourceProtocol get protocol => SourceProtocol.ftp;

  @override
  MusicSource create(SourceProfile profile) {
    return FtpMusicSource(profile);
  }
}
