import 'package:just_audio/just_audio.dart';

class PlayableTrack {
  const PlayableTrack({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.sourceName,
    required this.remotePath,
    required this.audioSource,
    this.sourceSizeBytes,
    this.artistName,
    this.albumTitle,
  });

  final String id;
  final String sourceId;
  final String title;
  final String sourceName;
  final String remotePath;
  final AudioSource audioSource;
  final int? sourceSizeBytes;
  final String? artistName;
  final String? albumTitle;
}
