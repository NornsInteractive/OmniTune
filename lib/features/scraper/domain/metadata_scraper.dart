import '../../../core/models/remote_entry.dart';

class ScrapedMetadata {
  const ScrapedMetadata({required this.title, this.artist, this.album});

  final String title;
  final String? artist;
  final String? album;
}

abstract class MetadataScraper {
  int get priority;

  Future<ScrapedMetadata?> scrape(RemoteEntry entry);
}
