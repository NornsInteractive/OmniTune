import '../../../core/models/remote_entry.dart';

class ScrapedMetadata {
  const ScrapedMetadata({
    required this.title,
    this.artist,
    this.album,
    this.coverUrl,
    this.localCoverPath,
    this.lyrics,
  });

  final String title;
  final String? artist;
  final String? album;
  final String? coverUrl;
  final String? localCoverPath;
  final String? lyrics;
}

abstract class MetadataScraper {
  int get priority;

  Future<ScrapedMetadata?> scrape(RemoteEntry entry);
}
