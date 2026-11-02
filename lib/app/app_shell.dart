import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/build_env.dart';
import '../core/router/app_router.dart';
import '../core/storage/library_preferences_repository.dart';
import '../core/widgets/studio_chrome.dart';
import '../core/widgets/top_snackbar.dart';
import '../features/player/application/player_controller.dart';
import '../features/player/presentation/widgets/mini_player.dart';
import '../features/settings/application/app_settings_controller.dart';
import '../features/updates/application/app_update_controller.dart';
import '../features/updates/presentation/auto_update_dialog.dart';

class MusicAppShell extends ConsumerStatefulWidget {
  const MusicAppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MusicAppShell> createState() => _MusicAppShellState();
}

class _MusicAppShellState extends ConsumerState<MusicAppShell> {
  StreamSubscription<bool>? _notificationClicks;

  @override
  void initState() {
    super.initState();
    _notificationClicks = AudioService.notificationClicked.listen((clicked) {
      if (!clicked ||
          !mounted ||
          !hasRecoverablePlayerState(ref.read(playerControllerProvider))) {
        return;
      }
      final router = ref.read(appRouterProvider);
      if (router.routeInformationProvider.value.uri.path != '/player') {
        router.push('/player');
      }
    });
    _triggerDailyUpdateCheck();
  }

  void _triggerDailyUpdateCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final prefsRepo = ref.read(libraryPreferencesRepositoryProvider);
        final prefs = await prefsRepo.load();
        final now = DateTime.now();
        final todayStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        if (prefs.lastDailyUpdateCheckDate != todayStr) {
          await prefsRepo.update(
            (p) => p.copyWith(lastDailyUpdateCheckDate: todayStr),
          );
          if (!mounted) return;
          ref.read(appUpdateControllerProvider.notifier).check(isAutomatic: true);
        }
      } catch (e) {
        debugPrint('[MusicAppShell] Daily update check failed: $e');
      }
    });
  }

  @override
  void dispose() {
    _notificationClicks?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppUpdateState>(appUpdateControllerProvider, (previous, next) {
      if (next.phase == AppUpdatePhase.available &&
          next.isAutomaticCheck &&
          (previous == null || previous.phase != AppUpdatePhase.available)) {
        AutoUpdateDialog.show(context);
      }
    });

    final navigationShell = widget.navigationShell;
    final preferences =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const LibraryPreferences();
    final debugModeEnabled = preferences.enableDebugMode;
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): () {
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null) {
            final ctx = focus.context;
            if (ctx != null &&
                (ctx.widget is EditableText ||
                    ctx.findAncestorWidgetOfExactType<EditableText>() !=
                        null)) {
              return;
            }
          }
          ref.read(playerControllerProvider.notifier).togglePlayPause();
        },
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () {
          ref.read(playerControllerProvider.notifier).togglePlayPause();
        },
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () {
          ref.read(playerControllerProvider.notifier).playNext();
        },
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () {
          ref.read(playerControllerProvider.notifier).playPrevious();
        },
      },
      child: Focus(
        autofocus: false,
        child: isWide
            ? _WideAppShell(
                navigationShell: navigationShell,
                debugModeEnabled: debugModeEnabled,
                colorScheme: colorScheme,
              )
            : _CompactAppShell(
                navigationShell: navigationShell,
                debugModeEnabled: debugModeEnabled,
                colorScheme: colorScheme,
              ),
      ),
    );
  }
}

class _WideAppShell extends StatelessWidget {
  const _WideAppShell({
    required this.navigationShell,
    required this.debugModeEnabled,
    required this.colorScheme,
  });

  final StatefulNavigationShell navigationShell;
  final bool debugModeEnabled;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Row(
        children: [
          _StudioNavigationRail(
            navigationShell: navigationShell,
            debugModeEnabled: debugModeEnabled,
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          Expanded(
            child: Column(
              children: [
                if (kIsWeb) const _WebApkDownloadBanner(),
                Expanded(
                  child: _NavShellTransition(
                    currentIndex: navigationShell.currentIndex,
                    child: navigationShell,
                  ),
                ),
                const MiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactAppShell extends StatelessWidget {
  const _CompactAppShell({
    required this.navigationShell,
    required this.debugModeEnabled,
    required this.colorScheme,
  });

  final StatefulNavigationShell navigationShell;
  final bool debugModeEnabled;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          if (kIsWeb) const _WebApkDownloadBanner(),
          Expanded(
            child: _NavShellTransition(
              currentIndex: navigationShell.currentIndex,
              child: navigationShell,
            ),
          ),
          const MiniPlayer(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              0,
              12,
              studioSpacingOf(context, 4).clamp(2.0, 8.0),
            ),
            child: _StudioNavigationBar(
              navigationShell: navigationShell,
              debugModeEnabled: debugModeEnabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioNavigationRail extends StatelessWidget {
  const _StudioNavigationRail({
    required this.navigationShell,
    required this.debugModeEnabled,
  });

  final StatefulNavigationShell navigationShell;
  final bool debugModeEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 88,
      color: colorScheme.surfaceContainer,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.graphic_eq_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: NavigationRail(
                backgroundColor: Colors.transparent,
                selectedIndex: navigationShell.currentIndex.clamp(
                  0,
                  debugModeEnabled ? 3 : 2,
                ),
                onDestinationSelected: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: navigationShell.currentIndex == index,
                  );
                },
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.2,
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.album_outlined),
                    selectedIcon: const Icon(Icons.album_rounded),
                    label: Text(l10n.albumsTabLabel),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.library_music_outlined),
                    selectedIcon: const Icon(Icons.library_music_rounded),
                    label: Text(l10n.collectionTabLabel),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.folder_open_rounded),
                    selectedIcon: const Icon(Icons.folder_open_rounded),
                    label: Text(l10n.browserTitle),
                  ),
                  if (debugModeEnabled)
                    NavigationRailDestination(
                      icon: const Icon(Icons.terminal_outlined),
                      selectedIcon: const Icon(Icons.terminal_rounded),
                      label: Text(l10n.debugLogsTabLabel),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: l10n.settingsTabLabel,
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => context.push('/settings'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _StudioNavigationBar extends StatelessWidget {
  const _StudioNavigationBar({
    required this.navigationShell,
    required this.debugModeEnabled,
  });

  final StatefulNavigationShell navigationShell;
  final bool debugModeEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final shellRadius = studioRadiusOf(context, 20);
    final buttonRadius = studioRadiusOf(context, 14);
    final verticalPadding = studioSpacingOf(context, 7).clamp(5.0, 11.0);

    final destinations = <_NavDestination>[
      _NavDestination(
        label: l10n.albumsTabLabel,
        icon: Icons.album_outlined,
        selectedIcon: Icons.album_rounded,
        selected: navigationShell.currentIndex == 0,
        onTap: () => _goBranch(0),
      ),
      _NavDestination(
        label: l10n.collectionTabLabel,
        icon: Icons.library_music_outlined,
        selectedIcon: Icons.library_music_rounded,
        selected: navigationShell.currentIndex == 1,
        onTap: () => _goBranch(1),
      ),
      _NavDestination(
        label: l10n.browserTitle,
        icon: Icons.folder_open_rounded,
        selectedIcon: Icons.folder_open_rounded,
        selected: navigationShell.currentIndex == 2,
        onTap: () => _goBranch(2),
      ),
      if (debugModeEnabled)
        _NavDestination(
          label: l10n.debugLogsTabLabel,
          icon: Icons.terminal_outlined,
          selectedIcon: Icons.terminal_rounded,
          selected: navigationShell.currentIndex == 3,
          onTap: () => _goBranch(3),
        ),
    ];

    return Material(
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(shellRadius),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          10,
          verticalPadding,
          10,
          verticalPadding + MediaQuery.paddingOf(context).bottom * 0.1,
        ),
        child: FocusTraversalGroup(
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++) ...[
                Expanded(
                  child: _NavButton(
                    destination: destinations[index],
                    buttonRadius: buttonRadius,
                  ),
                ),
                if (index != destinations.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: navigationShell.currentIndex == index,
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.destination, required this.buttonRadius});

  final _NavDestination destination;
  final double buttonRadius;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = destination.selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: destination.selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(buttonRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: StudioPressable(
          borderRadius: BorderRadius.circular(buttonRadius),
          onTap: destination.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  destination.selected
                      ? destination.selectedIcon
                      : destination.icon,
                  size: 21,
                  color: foreground,
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSans(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: destination.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
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

class _WebApkDownloadBanner extends StatelessWidget {
  const _WebApkDownloadBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final apkUri = _apkUri;
    final hasApkUrl = apkUri != null;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Material(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(studioRadiusOf(context, 18)),
            side: BorderSide(
              color: colorScheme.secondary.withValues(alpha: 0.24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final message = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.webApkBannerTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasApkUrl
                          ? l10n.webApkBannerDescription
                          : l10n.webApkBannerUnavailableLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer.withValues(
                          alpha: 0.86,
                        ),
                      ),
                    ),
                  ],
                );

                final action = FilledButton.tonalIcon(
                  onPressed: hasApkUrl
                      ? () => _launchApkDownload(context, apkUri)
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l10n.webApkBannerDownloadAction),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      message,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: action),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: message),
                    const SizedBox(width: 16),
                    action,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static Uri? get _apkUri {
    final rawUrl = BuildEnv.webApkUrl.trim();
    if (rawUrl.isEmpty) {
      return null;
    }
    return Uri.tryParse(rawUrl);
  }

  static Future<void> _launchApkDownload(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) {
      return;
    }
    showTopSnackBar(
      context,
      AppLocalizations.of(context)!.webApkBannerLaunchFailedMessage,
    );
  }
}

class _NavShellTransition extends StatefulWidget {
  const _NavShellTransition({required this.currentIndex, required this.child});

  final int currentIndex;
  final Widget child;

  @override
  State<_NavShellTransition> createState() => _NavShellTransitionState();
}

class _NavShellTransitionState extends State<_NavShellTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.2, 0.0, 0.0, 1.0),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 10), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Cubic(0.2, 0.0, 0.0, 1.0),
          ),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_NavShellTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.stop();
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: disableAnimations ? 1.0 : _fade.value,
          child: Transform.translate(
            offset: disableAnimations ? Offset.zero : _slide.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
