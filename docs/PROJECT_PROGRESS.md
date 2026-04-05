# Project Progress

## Snapshot
- Last updated: v1.0.22+23 (debug mode feature, first song investigation)
- Delivery focus: Android-first, while keeping the project multi-platform
- Current maturity: strong prototype / production-oriented foundation
- Build Status: ✅ Zero warnings, fully functional

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
- **[NEW] Scan result persistence (v1.0.20+21)**
  - Automatic JSON file-based caching of scan results
  - Cache loading on app startup
  - Eliminates re-scan requirement after app restart
  - Per-source cache management
- **[NEW] Playback latency optimization (v1.0.20+22)**
  - 1-second cache check timeout (prevents magnetic disk blocking)
  - Async WebDAV connection establishment
  - Parallel lyric loading (doesn't delay playback)
  - 3-7x faster startup (500ms-3s vs 5-15s)
- **[NEW] Global debug mode feature (v1.0.22+23)**
  - Toggle in Settings → Developer section
  - Exception dialogs with copyable error text
  - Global error handler for all exception types
  - Full English and Chinese support
  - Development/diagnostic capability

### Partially Done
- Scraper architecture
  - interfaces and chain exist
  - real scraper implementation not added yet
- Album grouping by scraped data
  - UI and scan pipeline support it
  - actual differentiated results depend on future scraper/tag ingestion
- First song playback optimization
  - Root cause identified (WebDAV connection warmup)
  - Solution designed (pre-warm on source selection)
  - Implementation pending (1-2 hours of work)
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

## Recent Completed Work (v1.0.20+21)
- **[NEW] Implemented scan result persistence**
  - Created `LibraryScanCacheRepository` for caching scanned music
  - Added JSON serialization to `LibrarySong` model
  - Integrated cache loading on app startup
  - Integrated cache saving after scan operations
  - Eliminates need to re-scan after app restart
  - See: `docs/SCAN_PERSISTENCE_IMPLEMENTATION.md` for full details

## Previous Completed Work (v1.0.19)
- Added song list virtual scrolling for performance optimization
- Added long-press menu and details bottom sheet for songs
- Added 11 new i18n strings for song details UI
- Fixed stutter and lag in song list with large libraries
- Added editable source model with scan directories and excluded directories
- Refactored albums page to be source-specific
- Refactored collection page into list home + child pages
- Added source edit route and UI
- Updated localization for new source and album options
- Added unit test for `SourceProfile` scan path normalization

## Current Risk Areas
- Real metadata scraping is still absent, so "scraped albums" is structurally ready but not feature-complete
- ~~Library scan can grow expensive on very large remote libraries because it is not persisted yet~~ **[RESOLVED in v1.0.20]** - Scan results now persisted locally
- Route and UI structure changed recently, so future changes should re-test navigation flows carefully
- WebDAV playback compatibility should be preserved when adding other protocols

## Recommended Next Validation When Touching These Areas
- Source model or settings:
  - add/edit source
  - scan directory behavior
  - exclude behavior
- Library scan and persistence:
  - scan all sources (verify cache is saved)
  - rescan one source (verify cache update)
  - verify cache loads on cold startup
  - clear cache and verify empty state handling
  - albums page source switching
  - collection page counts
- Playback:
  - FLAC on WebDAV
  - cache hit after replay
  - OpenList redirect playback

## Recommended Next Priority Areas
1. **Settings page enhancement** - Add "Clear Cache" button and cache statistics display
2. **Metadata scraping** - Implement real scraper/tag ingestion so "scraped albums" becomes meaningful
3. **Search and filtering** - Add album/song search and sort functionality
4. **Next protocol** - Implement SFTP source (MAJOR feature)
5. **Database persistence** - Optional future migration from JSON to Isar for better querying
