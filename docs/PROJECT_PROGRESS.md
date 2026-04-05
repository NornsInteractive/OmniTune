# Project Progress

## Snapshot
- Last updated: current repository state after version `1.0.18+19`
- Delivery focus: Android-first, while keeping the project multi-platform
- Current maturity: strong prototype / production-oriented foundation

## Milestones

### Done
- App shell with bottom navigation and mini player
- Standalone settings page opened from top-right gear icon
- Language, theme, interface scale, and font scale settings
- WebDAV source add/edit/delete
- Multiple saved music sources
- Multiple scan directories per source
- Multiple excluded scan directories per source
- Remote WebDAV browsing
- Music file listing and playback
- FLAC playback support
- OpenList 302 redirect compatibility
- Playback cache:
  - memory cache
  - optional local file cache
  - cache inventory listing
  - selective deletion
  - progress visualization in timeline
- Albums page with:
  - source switcher
  - folder grouping mode
  - scraped grouping mode wiring
- Collection page with:
  - all songs
  - liked
  - favorites
  - remote browser
  - dedicated secondary pages

### Partially Done
- Scraper architecture
  - interfaces and chain exist
  - real scraper implementation not added yet
- Album grouping by scraped data
  - UI and scan pipeline support it
  - actual differentiated results depend on future scraper/tag ingestion
- Multi-platform support
  - project structure is ready
  - Android validation is strongest

### Not Started
- SFTP source
- Cloud drive sources
- Persistent library database
- Full queue / playlist management
- Advanced album/song search and sorting
- Better cover art and metadata scraping
- Per-platform UI polish for desktop/TV/web

## Key Technical Decisions Already Made
- Source credentials are stored via `flutter_secure_storage`
- Library scan is currently in-memory state, not a persistent indexed database
- Source configuration supports root path + include/exclude scan rules
- Playback cache is source-aware and reused across playback
- APK builds should go through `scripts/build_apk.sh` so version is auto-incremented

## Recent Completed Work
- Added editable source model with scan directories and excluded directories
- Refactored albums page to be source-specific
- Refactored collection page into list home + child pages
- Added source edit route and UI
- Updated localization for new source and album options
- Added unit test for `SourceProfile` scan path normalization

## Current Risk Areas
- Real metadata scraping is still absent, so "scraped albums" is structurally ready but not feature-complete
- Library scan can grow expensive on very large remote libraries because it is not persisted yet
- Route and UI structure changed recently, so future changes should re-test navigation flows carefully
- WebDAV playback compatibility should be preserved when adding other protocols

## Recommended Next Validation When Touching These Areas
- Source model or settings:
  - add/edit source
  - scan directory behavior
  - exclude behavior
- Library scan:
  - scan all sources
  - rescan one source
  - albums page source switching
  - collection page counts
- Playback:
  - FLAC on WebDAV
  - cache hit after replay
  - OpenList redirect playback
