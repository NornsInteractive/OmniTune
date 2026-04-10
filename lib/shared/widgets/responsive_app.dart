import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

/// 响应式应用框架 (Responsive App Framework)
///
/// 根据屏幕宽度自动切换导航方式：
/// - < 600px:   BottomNavigationBar (Mobile)
/// - 600-900px: NavigationRail (Tablet)
/// - > 900px:   永久展开 NavigationDrawer (Desktop)
///
/// 特点：
/// - 卡片风格：白色背景 + 0.5px边框 + 圆角12-16px，无阴影
/// - 黑白灰配色 + Material Design 3 ColorScheme
/// - 所有页面自动路由
class ResponsiveApp extends ConsumerStatefulWidget {
  const ResponsiveApp({super.key});

  @override
  ConsumerState<ResponsiveApp> createState() => _ResponsiveAppState();
}

class _ResponsiveAppState extends ConsumerState<ResponsiveApp> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // 根据宽度确定导航类型
        if (width < 600) {
          // Mobile: BottomNavigationBar
          return _MobileLayout();
        } else if (width < 900) {
          // Tablet: NavigationRail
          return _TabletLayout();
        } else {
          // Desktop: Permanent NavigationDrawer
          return _DesktopLayout();
        }
      },
    );
  }
}

/// ============================================================================
/// Mobile Layout (< 600px)
/// ============================================================================
class _MobileLayout extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends ConsumerState<_MobileLayout> {
  int _selectedIndex = 0;

  static const List<String> _routeNames = ['home', 'search', 'library', 'player', 'settings'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: _buildContent(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // 导航到相应路由
          _navigateTo(context, _routeNames[index]);
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l10n.navigationHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search_outlined),
            activeIcon: const Icon(Icons.search),
            label: l10n.navigationSearch,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.library_music_outlined),
            activeIcon: const Icon(Icons.library_music),
            label: l10n.navigationLibrary,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.play_circle_outline),
            activeIcon: const Icon(Icons.play_circle),
            label: l10n.navigationPlayer,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: l10n.navigationSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int index) {
    final screens = [
      const _HomeScreen(),
      const _SearchScreen(),
      const _LibraryScreen(),
      const _PlayerScreen(),
      const _SettingsScreen(),
    ];
    return screens[index];
  }

  void _navigateTo(BuildContext context, String routeName) {
    // 使用 GoRouter 进行导航
    switch (routeName) {
      case 'home':
        context.go('/');
        break;
      case 'search':
        // TODO: 实现搜索页面路由
        break;
      case 'library':
        context.go('/collection');
        break;
      case 'player':
        context.go('/player');
        break;
      case 'settings':
        context.go('/settings');
        break;
    }
  }
}

/// ============================================================================
/// Tablet Layout (600-900px)
/// ============================================================================
class _TabletLayout extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TabletLayout> createState() => _TabletLayoutState();
}

class _TabletLayoutState extends ConsumerState<_TabletLayout> {
  int _selectedIndex = 0;

  static const List<String> _routeNames = ['home', 'search', 'library', 'player', 'settings'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // NavigationRail (仅图标)
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
              _navigateTo(context, _routeNames[index]);
            },
            groupAlignment: 0.0,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: SizedBox.shrink(),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: SizedBox.shrink(),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: SizedBox.shrink(),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.play_circle_outline),
                selectedIcon: Icon(Icons.play_circle),
                label: SizedBox.shrink(),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: SizedBox.shrink(),
              ),
            ],
          ),
          // 内容区域
          Expanded(child: _buildContent(_selectedIndex)),
        ],
      ),
      bottomNavigationBar: _buildMiniPlayer(context),
    );
  }

  Widget _buildContent(int index) {
    final screens = [
      const _HomeScreen(),
      const _SearchScreen(),
      const _LibraryScreen(),
      const _PlayerScreen(),
      const _SettingsScreen(),
    ];
    return screens[index];
  }

  void _navigateTo(BuildContext context, String routeName) {
    switch (routeName) {
      case 'home':
        context.go('/');
        break;
      case 'search':
        break;
      case 'library':
        context.go('/collection');
        break;
      case 'player':
        context.go('/player');
        break;
      case 'settings':
        context.go('/settings');
        break;
    }
  }

  Widget _buildMiniPlayer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outline, width: 0.5)),
      ),
      child: _MiniPlayerContent(),
    );
  }
}

/// ============================================================================
/// Desktop Layout (> 900px)
/// ============================================================================
class _DesktopLayout extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends ConsumerState<_DesktopLayout> {
  int _selectedIndex = 0;

  static const List<String> _routeNames = ['home', 'search', 'library', 'player', 'settings'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // 永久展开的 NavigationDrawer
          SizedBox(
            width: 240,
            child: NavigationDrawer(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
                _navigateTo(context, _routeNames[index]);
              },
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Wavely',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    l10n.navigationLibrary.toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colorScheme.outline, letterSpacing: 0.05),
                  ),
                ),
                NavigationDrawerDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: Text(l10n.navigationHome),
                ),
                NavigationDrawerDestination(
                  icon: const Icon(Icons.search_outlined),
                  selectedIcon: const Icon(Icons.search),
                  label: Text(l10n.navigationSearch),
                ),
                NavigationDrawerDestination(
                  icon: const Icon(Icons.library_music_outlined),
                  selectedIcon: const Icon(Icons.library_music),
                  label: Text(l10n.navigationLibrary),
                ),
                NavigationDrawerDestination(
                  icon: const Icon(Icons.play_circle_outline),
                  selectedIcon: const Icon(Icons.play_circle),
                  label: Text(l10n.navigationPlayer),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    l10n.navigationSettings.toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: colorScheme.outline, letterSpacing: 0.05),
                  ),
                ),
                NavigationDrawerDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: Text(l10n.navigationSettings),
                ),
              ],
            ),
          ),
          // 内容区域 + 迷你播放器
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildContent(_selectedIndex)),
                _buildMiniPlayer(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(int index) {
    final screens = [
      const _HomeScreen(),
      const _SearchScreen(),
      const _LibraryScreen(),
      const _PlayerScreen(),
      const _SettingsScreen(),
    ];
    return screens[index];
  }

  void _navigateTo(BuildContext context, String routeName) {
    switch (routeName) {
      case 'home':
        context.go('/');
        break;
      case 'search':
        break;
      case 'library':
        context.go('/collection');
        break;
      case 'player':
        context.go('/player');
        break;
      case 'settings':
        context.go('/settings');
        break;
    }
  }

  Widget _buildMiniPlayer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outline, width: 0.5)),
      ),
      child: _MiniPlayerContent(),
    );
  }
}

/// ============================================================================
/// 迷你播放器组件（Tablet 和 Desktop 共用）
/// ============================================================================
class _MiniPlayerContent extends StatelessWidget {
  const _MiniPlayerContent();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // 专辑封面
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
              color: colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(width: 12),
          // 歌曲信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Midnight Drive',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Neon Echoes',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 控制按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous), iconSize: 20, onPressed: () {}),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: colorScheme.primary),
                child: IconButton(
                  icon: Icon(Icons.pause, color: colorScheme.onPrimary, size: 20),
                  onPressed: () {},
                ),
              ),
              IconButton(icon: const Icon(Icons.skip_next), iconSize: 20, onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// 页面屏幕组件
/// ============================================================================

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'What do you want to listen to?',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                // 快速访问卡片网格 (2 列)
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _QuickAccessCard('Liked Songs', colorScheme),
                    _QuickAccessCard('Recently Played', colorScheme),
                    _QuickAccessCard('Top Mixes', colorScheme),
                    _QuickAccessCard('My Playlist', colorScheme),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatelessWidget {
  final String title;
  final ColorScheme colorScheme;

  const _QuickAccessCard(this.title, this.colorScheme);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
                    color: colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchScreen extends StatelessWidget {
  const _SearchScreen();

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Search Screen', style: Theme.of(context).textTheme.headlineSmall));
  }
}

class _LibraryScreen extends StatelessWidget {
  const _LibraryScreen();

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Library Screen', style: Theme.of(context).textTheme.headlineSmall));
  }
}

class _PlayerScreen extends StatelessWidget {
  const _PlayerScreen();

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Player Screen', style: Theme.of(context).textTheme.headlineSmall));
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Settings Screen', style: Theme.of(context).textTheme.headlineSmall));
  }
}
