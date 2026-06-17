import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/build_env.dart';
import '../core/storage/library_preferences_repository.dart';
import '../core/widgets/studio_chrome.dart';
import '../core/widgets/top_snackbar.dart';
import '../features/settings/application/app_settings_controller.dart';
import '../features/player/presentation/widgets/mini_player.dart';

class MusicAppShell extends ConsumerWidget {
  const MusicAppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const LibraryPreferences();
    final debugModeEnabled = preferences.enableDebugMode;
    _GlacierPalette.sync(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: _GlacierPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _AmbientGlow(
            alignment: Alignment(-0.72, -0.88),
            size: 420,
            color: _GlacierPalette.primary.withValues(alpha: 0.3),
          ),
          _AmbientGlow(
            alignment: Alignment(0.9, -0.16),
            size: 360,
            color: _GlacierPalette.tertiary.withValues(alpha: 0.22),
          ),
          Column(
            children: [
              if (kIsWeb) const _WebApkDownloadBanner(),
              Expanded(child: navigationShell),
              const MiniPlayer(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  studioSpacingOf(context, 4).clamp(2.0, 8.0),
                ),
                child: _GlacierNavigationBar(
                  navigationShell: navigationShell,
                  debugModeEnabled: debugModeEnabled,
                ),
              ),
            ],
          ),
        ],
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
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(studioRadiusOf(context, 18)),
            border: Border.all(
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
                final button = FilledButton.tonalIcon(
                  onPressed: hasApkUrl
                      ? () => _launchApk(context, apkUri)
                      : null,
                  icon: const Icon(Icons.download_rounded),
                  label: Text(l10n.webApkBannerDownloadAction),
                );

                final icon = Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(
                      studioRadiusOf(context, 14),
                    ),
                  ),
                  child: Icon(
                    Icons.android_rounded,
                    color: colorScheme.secondary,
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          icon,
                          const SizedBox(width: 12),
                          Expanded(child: message),
                        ],
                      ),
                      const SizedBox(height: 12),
                      button,
                    ],
                  );
                }

                return Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: message),
                    const SizedBox(width: 12),
                    button,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Uri? get _apkUri {
    if (!BuildEnv.hasWebApkUrl) {
      return null;
    }

    final uri = Uri.tryParse(BuildEnv.webApkUrl.trim());
    if (uri == null || !uri.hasScheme) {
      return null;
    }
    return uri;
  }

  Future<void> _launchApk(BuildContext context, Uri? uri) async {
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!context.mounted || launched) {
      return;
    }
    showTopSnackBar(
      context,
      AppLocalizations.of(context)!.webApkBannerLaunchFailedMessage,
    );
  }
}

class _GlacierNavigationBar extends StatelessWidget {
  const _GlacierNavigationBar({
    required this.navigationShell,
    required this.debugModeEnabled,
  });

  final StatefulNavigationShell navigationShell;
  final bool debugModeEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shellRadius = studioRadiusOf(context, 22);
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
        icon: Icons.search_rounded,
        selectedIcon: Icons.search_rounded,
        selected: navigationShell.currentIndex == 2,
        onTap: () => _goBranch(2),
      ),
      if (debugModeEnabled)
        _NavDestination(
          label: 'Logs',
          icon: Icons.terminal_outlined,
          selectedIcon: Icons.terminal_rounded,
          selected: navigationShell.currentIndex == 3,
          onTap: () => _goBranch(3),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(shellRadius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            verticalPadding,
            12,
            verticalPadding + MediaQuery.paddingOf(context).bottom * 0.2,
          ),
          decoration: BoxDecoration(
            color: _GlacierPalette.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(shellRadius),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++) ...[
                Expanded(
                  child: _NavButton(
                    destination: destinations[index],
                    buttonRadius: buttonRadius,
                  ),
                ),
                if (index != destinations.length - 1) const SizedBox(width: 6),
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
    final foreground = destination.selected
        ? _GlacierPalette.primary
        : _GlacierPalette.onSurfaceVariant;

    return Material(
      color: destination.selected
          ? _GlacierPalette.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(buttonRadius),
        onTap: destination.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                style: GoogleFonts.inter(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: destination.selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlacierPalette {
  static Color background = const Color(0xFF0A0E1A);
  static Color surface = const Color(0xFF0F1524);
  static Color primary = const Color(0xFF7DD3FC);
  static Color tertiary = const Color(0xFFC8A0F0);
  static Color onSurfaceVariant = const Color(0xFFA0B4C4);

  static void sync(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    background = scheme.surface;
    surface = scheme.surfaceContainer;
    primary = scheme.primary;
    tertiary = scheme.tertiary;
    onSurfaceVariant = scheme.onSurfaceVariant;
  }
}
