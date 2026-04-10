import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../features/player/presentation/widgets/mini_player.dart';

/// 响应式应用壳 - 根据屏幕宽度自动切换导航方式
/// < 600px:    BottomNavigationBar (Mobile)
/// 600-900px:  NavigationRail (Tablet)
/// > 900px:    永久展开导航抽屉 (Desktop)
class MusicAppShell extends StatelessWidget {
  const MusicAppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final l10n = AppLocalizations.of(context)!;
        final colorScheme = Theme.of(context).colorScheme;

        // 响应式模式选择
        if (width < 600) {
          // ===== MOBILE (< 600px) =====
          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(child: navigationShell),
                // 右上角设置按钮
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Material(
                      color: colorScheme.surfaceContainerLow.withValues(alpha: 0.96),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Tooltip(
                        message: l10n.openSettingsAction,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => context.push('/settings'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Icon(Icons.settings_rounded, color: colorScheme.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
                  },
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.album_outlined),
                      selectedIcon: const Icon(Icons.album_rounded),
                      label: l10n.albumsTabLabel,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      selectedIcon: const Icon(Icons.library_music_rounded),
                      label: l10n.collectionTabLabel,
                    ),
                  ],
                ),
              ],
            ),
          );
        } else if (width < 900) {
          // ===== TABLET (600-900px) =====
          return Scaffold(
            body: Row(
              children: [
                // 左侧 NavigationRail (仅图标)
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (index) {
                    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
                  },
                  groupAlignment: 0.0,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.album_outlined),
                      selectedIcon: const Icon(Icons.album_rounded),
                      label: SizedBox.shrink(),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.library_music_outlined),
                      selectedIcon: const Icon(Icons.library_music_rounded),
                      label: SizedBox.shrink(),
                    ),
                  ],
                ),
                // 右侧内容区
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: navigationShell),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: SafeArea(
                          minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Material(
                            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.96),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(color: colorScheme.outlineVariant),
                            ),
                            child: Tooltip(
                              message: l10n.openSettingsAction,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => context.push('/settings'),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Icon(Icons.settings_rounded, color: colorScheme.onSurface),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: const MiniPlayer(),
          );
        } else {
          // ===== DESKTOP (> 900px) =====
          return Scaffold(
            body: Row(
              children: [
                // 左侧 NavigationDrawer (永久展开，图标+文字)
                SizedBox(
                  width: 240,
                  child: NavigationDrawer(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: (index) {
                      navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
                    },
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Wavely',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      NavigationDrawerDestination(
                        icon: const Icon(Icons.album_outlined),
                        selectedIcon: const Icon(Icons.album_rounded),
                        label: Text(l10n.albumsTabLabel),
                      ),
                      NavigationDrawerDestination(
                        icon: const Icon(Icons.library_music_outlined),
                        selectedIcon: const Icon(Icons.library_music_rounded),
                        label: Text(l10n.collectionTabLabel),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.push('/settings'),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Icon(Icons.settings_rounded, color: colorScheme.onSurface),
                                  const SizedBox(width: 16),
                                  Text(l10n.settingsTabLabel, style: Theme.of(context).textTheme.labelLarge),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 右侧内容区
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: navigationShell),
                      const MiniPlayer(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
