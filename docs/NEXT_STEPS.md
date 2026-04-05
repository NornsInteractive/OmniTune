# Next Steps

## Highest Priority

### 1. Implement Real Metadata Scraping
Goal:
- Make "scraped album grouping" meaningfully different from folder grouping.

Recommended approach:
- Start with local tag extraction first.
- Then add one remote metadata source such as MusicBrainz.
- Keep scraper failures non-fatal.

Likely files:
- `lib/features/scraper/`
- `lib/features/scraper/application/scraper_chain.dart`
- `lib/features/library/application/library_catalog_controller.dart`

Acceptance criteria:
- scanned tracks can populate album/artist/title from real metadata
- albums page in scraped mode produces visibly different grouping on suitable libraries
- failures do not block scan completion

### 2. Improve Queue And Playback Experience
Goal:
- Move beyond single-track playback into a real player flow.

Suggested scope:
- album play
- collection page play-all
- next/previous track
- play queue state

Likely files:
- `lib/features/player/application/player_controller.dart`
- `lib/core/audio/player_service.dart`
- player UI widgets

Acceptance criteria:
- can play an album or collection as a queue
- player supports next/previous
- current mini player and now playing panel stay in sync

### 3. Add Search And Sorting
Goal:
- Make albums and songs easier to use at scale.

Suggested scope:
- albums search
- songs search
- sort by title / artist / modified time
- source-specific filtering where useful

Likely files:
- `lib/features/library/presentation/albums_page.dart`
- `lib/features/library/presentation/library_page.dart`

## Medium Priority

### 4. Add SFTP As The Next Protocol
Goal:
- Prove the extensible source architecture with a second real protocol.

Suggested scope:
- implement `MusicSource`
- register in source registry
- add settings form and validation
- add tests with mocked transport layer

Likely files:
- `lib/features/sources/`
- `lib/features/settings/`
- `lib/features/sources/application/music_source_registry.dart`

### 5. Persist Library Scan Results
Goal:
- Improve startup and large-library performance.

Suggested scope:
- introduce a persistent catalog layer
- cache scan results by source
- support incremental rescan

Important note:
- do not add a persistence layer casually; first confirm the schema and migration plan

## Lower Priority

### 6. Cover Art And Lyrics Upgrades
Ideas:
- read embedded artwork where possible
- cache remote artwork
- improve `.lrc` parsing and display
- add lyrics empty/loading/error states with better polish

### 7. Desktop / TV / Web Polish
Ideas:
- desktop layout refinements
- Android TV focus handling
- web/platform guards for unsupported protocol features

## Guardrails For Future Work
- Update `app_en.arb` and `app_zh.arb` for every new visible string.
- Run `dart run build_runner build --delete-conflicting-outputs` after `@riverpod` changes.
- Run `flutter gen-l10n` after ARB edits.
- Use `bash scripts/build_apk.sh` when producing an Android test package.
- Preserve WebDAV FLAC playback and OpenList redirect compatibility while extending features.
