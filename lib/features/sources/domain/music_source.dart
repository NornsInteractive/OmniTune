import '../../../core/models/playable_track.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';

class DirectoryDiagnostics {
  const DirectoryDiagnostics({
    required this.protocolLabel,
    required this.requestedPath,
    required this.attemptedPaths,
    required this.entryCount,
    this.summary,
    this.details = const [],
  });

  final String protocolLabel;
  final String requestedPath;
  final List<String> attemptedPaths;
  final int entryCount;
  final String? summary;
  final List<String> details;
}

class DirectoryListing {
  const DirectoryListing({required this.entries, this.diagnostics});

  final List<RemoteEntry> entries;
  final DirectoryDiagnostics? diagnostics;
}

class DirectoryReadFailure implements Exception {
  const DirectoryReadFailure({
    required this.message,
    this.diagnostics,
    this.cause,
  });

  final String message;
  final DirectoryDiagnostics? diagnostics;
  final Object? cause;

  @override
  String toString() => message;
}

abstract class MusicSource {
  SourceProfile get profile;

  Future<void> connect();

  Future<void> disconnect();

  Future<DirectoryListing> listFiles(String path);

  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry);

  Future<String?> readTextFile(String path);
}

abstract class MusicSourceFactory {
  SourceProtocol get protocol;

  MusicSource create(SourceProfile profile);
}

extension RemoteEntryAudioSourceGuard on RemoteEntry {
  void ensurePlayable() {
    if (!isPlayable) {
      throw ArgumentError.value(path, 'entry', 'Entry is not an audio file.');
    }
  }
}
