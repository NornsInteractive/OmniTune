# Flutter Music Player

Production-oriented Flutter music player project with an extensible source architecture.

## Current State
- Version: `1.0.18+19`
- Primary validated target: Android APK
- Implemented remote protocol: WebDAV
- Current major features:
  - multiple music sources
  - per-source scan directories and excluded directories
  - remote WebDAV file browsing
  - FLAC playback
  - memory/local playback cache
  - albums grouped by source
  - collection pages for all songs, liked, favorites
  - standalone settings center

## Start Here
If you are continuing development, read these files first:

1. [AGENTS.md](AGENTS.md)
2. [.github/copilot-instructions.md](.github/copilot-instructions.md)
3. [docs/COPILOT_HANDOFF.md](docs/COPILOT_HANDOFF.md)
4. [docs/PROJECT_PROGRESS.md](docs/PROJECT_PROGRESS.md)
5. [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md)

## Common Commands
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
dart analyze
flutter test
bash scripts/build_apk.sh
```

## Current Key Files
- App shell: `lib/app/app_shell.dart`
- Router: `lib/core/router/app_router.dart`
- Source model: `lib/core/models/source_profile.dart`
- Library scan: `lib/features/library/application/library_catalog_controller.dart`
- Albums page: `lib/features/library/presentation/albums_page.dart`
- Library page: `lib/features/library/presentation/library_page.dart`
- Settings page: `lib/features/settings/presentation/settings_page.dart`
- Add/Edit source page: `lib/features/settings/presentation/add_source_page.dart`
- Player controller: `lib/features/player/application/player_controller.dart`
- WebDAV source: `lib/features/sources/data/webdav/webdav_music_source.dart`
- WebDAV cache: `lib/features/sources/data/webdav/webdav_playback_cache_io.dart`

## Notes
- `scripts/build_apk.sh` automatically increments the version before building.
- Scraper infrastructure exists, but no real scraper is registered yet.
- The "scraped album" mode is wired but currently depends on future metadata enrichment.
