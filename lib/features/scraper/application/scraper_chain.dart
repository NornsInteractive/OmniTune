import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/metadata_scraper.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/app_preferences.dart';
import '../data/musicbrainz_scraper.dart';
import '../../../core/utils/debug_logger.dart';
import '../../settings/application/app_settings_controller.dart';

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

@riverpod
ScraperChain scraperChain(Ref ref) {
  // Watch appSettingsControllerProvider to get latest language preference
  // This ensures scraper chain is recreated when language changes
  final appSettings = ref.watch(appSettingsControllerProvider);
  
  final localePreference = appSettings.maybeWhen(
    data: (prefs) => prefs.localePreference,
    orElse: () => AppLocalePreference.system,
  );
  
  DebugLogger.info('ScraperChain', 
    '初始化刮削器链，注册 MusicBrainzScraper，当前语言偏好: $localePreference');
  
  return ScraperChain([
    MusicBrainzScraper(localePreference: localePreference),
  ]);
}
