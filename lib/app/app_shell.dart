import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../core/widgets/studio_chrome.dart';
import '../features/player/presentation/widgets/mini_player.dart';

class MusicAppShell extends StatelessWidget {
  const MusicAppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface.withValues(alpha: 0),
      body: StudioBackdrop(
        maxContentWidth: 1480,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: navigationShell),
                const StudioGap(height: 4),
                const MiniPlayer(),
                StudioPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  radius: 18,
                  tint: colorScheme.surfaceContainerLow,
                  child: SizedBox(
                    height: studioListSpacingOf(
                      context,
                      44,
                    ).clamp(42.0, 56.0).toDouble(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _ShellDestination(
                            label: l10n.albumsTabLabel,
                            selected: navigationShell.currentIndex == 0,
                            icon: navigationShell.currentIndex == 0
                                ? Icons.album_rounded
                                : Icons.album_outlined,
                            onTap: () {
                              navigationShell.goBranch(
                                0,
                                initialLocation:
                                    navigationShell.currentIndex == 0,
                              );
                            },
                          ),
                        ),
                        const StudioGap(width: 8),
                        Expanded(
                          child: _ShellDestination(
                            label: l10n.collectionTabLabel,
                            selected: navigationShell.currentIndex == 1,
                            icon: navigationShell.currentIndex == 1
                                ? Icons.library_music_rounded
                                : Icons.library_music_outlined,
                            onTap: () {
                              navigationShell.goBranch(
                                1,
                                initialLocation:
                                    navigationShell.currentIndex == 1,
                              );
                            },
                          ),
                        ),
                        const StudioGap(width: 8),
                        Expanded(
                          child: _ShellDestination(
                            label: l10n.browserTitle,
                            selected: navigationShell.currentIndex == 2,
                            icon: navigationShell.currentIndex == 2
                                ? Icons.folder_rounded
                                : Icons.folder_outlined,
                            onTap: () {
                              navigationShell.goBranch(
                                2,
                                initialLocation:
                                    navigationShell.currentIndex == 2,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const StudioGap(height: 4),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                minimum: studioPaddingOf(
                  context,
                  const EdgeInsets.only(top: 8, right: 4),
                ),
                child: StudioPanel(
                  padding: EdgeInsets.zero,
                  radius: 20,
                  tint: colorScheme.surfaceContainerLow,
                  child: IconButton(
                    tooltip: l10n.openSettingsAction,
                    onPressed: () => context.push('/settings'),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellDestination extends StatelessWidget {
  const _ShellDestination({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surface.withValues(alpha: 0),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: studioPaddingOf(
            context,
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const StudioGap(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
