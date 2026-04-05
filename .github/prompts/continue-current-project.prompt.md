# Continue Current Project

Read these files first:

1. `AGENTS.md`
2. `.github/copilot-instructions.md`
3. `docs/COPILOT_HANDOFF.md`
4. `docs/PROJECT_PROGRESS.md`
5. `docs/NEXT_STEPS.md`

Then continue the Flutter music player project from its current state.

Requirements:
- Work with the current architecture instead of redesigning it from scratch.
- Keep WebDAV playback, OpenList redirect handling, and playback cache behavior working.
- Do not hardcode user-visible strings.
- Do not hardcode colors.
- Use existing dependencies before adding new ones.
- Treat current code as Android-first but keep multi-platform compatibility in mind.

When implementing a feature:
- identify the minimal affected files
- update both UI and state/data layers consistently
- update `app_en.arb` and `app_zh.arb` for any new strings
- run:
  - `dart run build_runner build --delete-conflicting-outputs` when needed
  - `flutter gen-l10n` when ARB changes
  - `dart analyze`
  - `flutter test`

If you need a next task and no user requirement is provided, pick the highest-priority item from `docs/NEXT_STEPS.md` and continue from there.
