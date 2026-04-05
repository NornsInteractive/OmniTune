# Copilot Handoff

## Purpose
This file captures the current development context so GitHub Copilot or another developer can continue the project without re-discovering the recent architecture decisions.

## Project Identity
- App type: cross-platform Flutter music player
- Current release version: `1.0.18+19`
- Main delivery target so far: Android APK
- Current implemented protocol: WebDAV

## Current Product Shape

### Navigation
- Bottom navigation now contains only:
  - Albums
  - Collection
- Settings is opened from the top-right gear icon in the app shell.
- Current routes:
  - `/albums`
  - `/collection`
  - `/collection/list/:section`
  - `/collection/browser`
  - `/settings`
  - `/settings/add-source`
  - `/settings/source/:sourceId`
  - `/player`

### Settings
The settings page is a dialog-driven settings center.

Implemented settings:
- language
- theme
- interface scale
- font scale
- source management
- playback cache settings
- cache inventory management

Important behavior:
- source management supports multiple saved sources
- sources can be edited, not just added/deleted
- cache management can list cached tracks and selectively delete them

Key files:
- `lib/features/settings/presentation/settings_page.dart`
- `lib/features/settings/presentation/add_source_page.dart`
- `lib/features/settings/application/add_source_controller.dart`
- `lib/features/settings/application/app_settings_controller.dart`

## Music Source Model

### Current source capabilities
Each `SourceProfile` now supports:
- `rootPath`
- `scanDirectories`
- `excludedScanDirectories`

Rules:
- if `scanDirectories` is empty, scanning starts from `effectiveRootPath`
- scan/excluded directories are normalized relative to the source root
- multiple directories are supported for both include and exclude lists

Key file:
- `lib/core/models/source_profile.dart`

Persistence:
- source profiles are stored via `flutter_secure_storage`
- repository file: `lib/core/storage/source_profile_repository.dart`

## Scanning And Catalog

### Current scan flow
The library scan now walks every saved source and aggregates discovered tracks into one in-memory catalog.

Implementation details:
- remote browser uses one selected source
- library scan uses all saved sources
- rescan can target one source without deleting the others
- excluded directories are skipped during BFS traversal

Key file:
- `lib/features/library/application/library_catalog_controller.dart`

### Track model
`LibrarySong` now carries both:
- folder-derived metadata
- optional scraped metadata fields

This allows the UI to switch album grouping modes without rescanning.

Key file:
- `lib/core/models/library_song.dart`

## Albums Page

### Current UI behavior
Albums are no longer shown as one merged wall without context.

The page now supports:
- top horizontal source selector
- current source-specific album list
- two grouping modes per source:
  - folder grouping: one folder = one album
  - scraped grouping: based on enriched metadata when available

Important limitation:
- the scraper chain exists, but there is no real registered scraper yet
- because of that, "scraped grouping" is wired architecturally, but still often falls back to existing metadata/path-based values

Key file:
- `lib/features/library/presentation/albums_page.dart`

## Collection Page

### Current UI behavior
The collection page is now a home page, not an in-page segmented switcher.

It shows entry tiles for:
- all songs
- liked
- favorites
- remote browser

Tapping an entry opens a separate page:
- song list page for all songs / liked / favorites
- dedicated remote browser page

Key file:
- `lib/features/library/presentation/library_page.dart`

## Player And Cache

### Player
Player state is managed by:
- `lib/features/player/application/player_controller.dart`
- `lib/core/audio/player_service.dart`

The player currently supports:
- immediate remote playback
- lyrics loading from `.lrc`
- cache progress visualization in the timeline

### Cache
The WebDAV playback cache supports:
- memory caching
- optional local file caching
- cached range reuse
- cache inventory listing
- selective cache deletion

Key files:
- `lib/features/sources/data/webdav/webdav_playback_cache_io.dart`
- `lib/features/sources/data/webdav/webdav_playback_cache_base.dart`
- `lib/features/sources/data/webdav/webdav_playback_cache_provider.dart`

## WebDAV Status

### Current behavior
WebDAV is the only implemented production path right now.

It already supports:
- directory listing
- file playback
- FLAC playback
- OpenList 302 redirect handling
- playback cache integration

Key files:
- `lib/features/sources/data/webdav/webdav_music_source.dart`
- `lib/features/sources/data/webdav/webdav_remote_client.dart`

## What Is Not Done Yet
- no real scraper implementation is registered in `scraper_chain.dart`
- no SFTP implementation yet
- no persisted music library database yet
- no advanced search/sort/filter for albums and songs yet
- no real queue/playlist management yet
- no polished metadata/cover scraping pipeline yet

## Validation Commands
Use these after meaningful code changes:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
dart analyze
flutter test
bash scripts/build_apk.sh
```

## Practical Continuation Advice
- When changing source settings, update both model and add/edit source UI together.
- When changing library scan logic, verify both albums and collection pages still agree on the same catalog.
- When changing playback behavior, do not regress:
  - FLAC playback
  - OpenList 302 redirect support
  - cache visualization
  - cache inventory
- If implementing real scraping next, start in:
  - `lib/features/scraper/`
  - then wire it into `lib/features/library/application/library_catalog_controller.dart`
