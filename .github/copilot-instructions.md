# Flutter Music Player — GitHub Copilot Instructions

## Read This First
When continuing work in this repository, read files in this order:

1. `AGENTS.md`
2. `.github/copilot-instructions.md`
3. `STAGE_4_HANDOFF.md` — **[NEW - Stage 4 完成总结]**
4. `docs/DOCUMENTATION_INDEX.md` — **[NEW - 文档导航]**
5. `docs/PROJECT_PROGRESS.md`
6. `docs/NEXT_STEPS.md`

The newer docs are the source of truth. If an older document conflicts with the current code, trust the current code and the handoff docs.

## Current Project Snapshot
- Flutter cross-platform music player skeleton focused on Android-first delivery.
- Current version: `1.0.23+24` **(Updated: Stage 4 完成)**
- State management: Riverpod with code generation
- Routing: `go_router`
- Playback: `just_audio`
- Credentials storage: `flutter_secure_storage`
- Remote protocol currently implemented: `WebDAV`
- Current APK build command with auto version bump: `bash scripts/build_apk.sh`
- **[NEW] UI Redesign: Stage 4 (80% complete) - Custom Theme System**

## What Already Works
- Multiple WebDAV music sources can be added and edited.
- Each source supports:
  - one root path
  - multiple scan directories
  - multiple excluded scan directories
  - default scan-from-root behavior when scan directories are empty
- Remote WebDAV browsing works, including OpenList 302 redirect playback handling.
- FLAC playback works.
- Playback cache supports:
  - memory caching
  - optional local file caching
  - cache inventory management
  - cache visualization in the timeline
- Albums page supports:
  - source switching via top horizontal list
  - folder-based album grouping
  - scraped-data grouping mode
- Library page supports:
  - collection home page
  - separate song list pages for all songs, liked, favorites
  - separate remote browser page
- Settings page is entered from the top-right gear icon, not from bottom navigation.
- **[NEW - Stage 4] Custom Theme System:**
  - Custom color selection (8 presets + hex input)
  - Dynamic border radius control (12-32px)
  - Interface compactness adjustment (50%-150%)
  - Material Design 3 ColorScheme.fromSeed() integration
  - Real-time theme application across entire app
  - Persistent theme preferences

## Important Current Limitations
- Only WebDAV is fully implemented. SFTP/cloud drives are not started.
- The scraper pipeline exists, but no real scraper is registered yet.
- The "scraped albums" mode is wired, but currently falls back to existing metadata/path-derived values when no scraper result exists.
- Library scan results are currently kept in app state, not in a persistent music database.
- Android is the most validated target. Multi-platform structure exists, but not every feature has been deeply verified on every platform.

## Non-Negotiable Rules
- Prefer existing dependencies first. Do not re-implement something already covered by current packages.
- Do not hardcode user-visible strings. Add/update both:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_zh.arb`
- Do not hardcode colors. Use `Theme.of(context).colorScheme`.
- Do not perform network requests in widget `build()`.
- Do not store credentials outside `flutter_secure_storage`.
- Do not use `setState` except for local ephemeral UI state inside a page/dialog.
- Do not break WebDAV/OpenList compatibility while adding new features.
- Route playback operations through:
  - `lib/features/player/application/player_controller.dart`
  - `lib/core/audio/player_service.dart`
- New source protocols must implement:
  - `lib/features/sources/domain/music_source.dart`
  - and be registered in `lib/features/sources/application/music_source_registry.dart`

## Current Architecture Map
- App shell and global theming:
  - `lib/app/app.dart`
  - `lib/app/app_shell.dart`
- Routing:
  - `lib/core/router/app_router.dart`
- Source model and storage:
  - `lib/core/models/source_profile.dart`
  - `lib/core/storage/source_profile_repository.dart`
- Settings:
  - `lib/features/settings/presentation/settings_page.dart`
  - `lib/features/settings/presentation/add_source_page.dart`
- Library scan/catalog state:
  - `lib/features/library/application/library_catalog_controller.dart`
- Remote browser state:
  - `lib/features/library/application/library_controller.dart`
- Albums UI:
  - `lib/features/library/presentation/albums_page.dart`
- Library UI:
  - `lib/features/library/presentation/library_page.dart`
- Player state/UI:
  - `lib/features/player/application/player_controller.dart`
  - `lib/features/player/presentation/widgets/mini_player.dart`
  - `lib/features/player/presentation/widgets/now_playing_panel.dart`
  - `lib/features/player/presentation/widgets/playback_timeline.dart`
- WebDAV source and cache:
  - `lib/features/sources/data/webdav/webdav_music_source.dart`
  - `lib/features/sources/data/webdav/webdav_remote_client.dart`
  - `lib/features/sources/data/webdav/webdav_playback_cache_io.dart`
  - `lib/features/sources/data/webdav/webdav_playback_cache_base.dart`

## Build And Validation Workflow
- Get packages:
  - `flutter pub get`
- Regenerate Riverpod code after changing `@riverpod` files:
  - `dart run build_runner build --delete-conflicting-outputs`
- Regenerate localization after changing ARB files:
  - `flutter gen-l10n`
- Static analysis:
  - `dart analyze`
- Tests:
  - `flutter test`
- Android APK with auto version bump:
  - `bash scripts/build_apk.sh`

## Current Routes
- `/albums`
- `/collection`
- `/collection/list/:section`
- `/collection/browser`
- `/settings`
- `/settings/add-source`
- `/settings/source/:sourceId`
- `/player`

## Recommended Continuation Priorities
1. Implement a real scraper/tag ingestion pipeline so "scraped albums" becomes meaningfully different from folder grouping.
2. Improve queue/playlist behavior in the player.
3. Add search/sort/filter to albums and song list pages.
4. Add the next protocol, likely SFTP.
5. Persist library scan results if the project needs true production-scale libraries.
