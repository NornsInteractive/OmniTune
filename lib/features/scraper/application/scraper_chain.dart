import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/metadata_scraper.dart';
import '../../../core/models/remote_entry.dart';

part 'scraper_chain.g.dart';

class ScraperChain {
  const ScraperChain(this._scrapers);

  final List<MetadataScraper> _scrapers;

  Future<ScrapedMetadata?> scrape(RemoteEntry entry) async {
    final sorted = [..._scrapers]
      ..sort((left, right) => right.priority.compareTo(left.priority));

    for (final scraper in sorted) {
      final metadata = await scraper.scrape(entry);
      if (metadata != null) {
        return metadata;
      }
    }
    return null;
  }
}

@Riverpod(keepAlive: true)
ScraperChain scraperChain(Ref ref) {
  return const ScraperChain([]);
}
