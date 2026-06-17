import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/core/config/build_env.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 720 ? 20.0 : 40.0;
    final apkUri = _apkUri;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _LandingBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              24,
              horizontalPadding,
              48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LandingHeader(onEnterApp: () => context.go('/app')),
                    const SizedBox(height: 64),
                    _HeroSection(
                      apkUri: apkUri,
                      onEnterApp: () => context.go('/app'),
                      onDownloadApk: apkUri == null
                          ? null
                          : () => _launchApk(context, apkUri),
                    ),
                    const SizedBox(height: 72),
                    _DownloadSection(
                      apkUri: apkUri,
                      onEnterApp: () => context.go('/app'),
                      onDownloadApk: apkUri == null
                          ? null
                          : () => _launchApk(context, apkUri),
                    ),
                    const SizedBox(height: 72),
                    _FeatureSection(),
                    const SizedBox(height: 56),
                    _ClosingPanel(onEnterApp: () => context.go('/app')),
                    const SizedBox(height: 28),
                    Text(
                      l10n.landingFooterNote,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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

  Future<void> _launchApk(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!context.mounted || launched) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.webApkBannerLaunchFailedMessage,
        ),
      ),
    );
  }
}

class _LandingBackdrop extends StatelessWidget {
  const _LandingBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.38),
                colorScheme.surface,
                colorScheme.tertiaryContainer.withValues(alpha: 0.32),
              ],
            ),
          ),
        ),
        Positioned(
          left: -160,
          top: -180,
          child: _GlowOrb(
            size: 420,
            color: colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        Positioned(
          right: -140,
          top: 280,
          child: _GlowOrb(
            size: 360,
            color: colorScheme.secondary.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          left: 120,
          bottom: -220,
          child: _GlowOrb(
            size: 480,
            color: colorScheme.tertiary.withValues(alpha: 0.12),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color, blurRadius: size * 0.28, spreadRadius: 24),
          ],
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.onEnterApp});

  final VoidCallback onEnterApp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Icon(Icons.graphic_eq_rounded, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.appTitle,
            style: GoogleFonts.notoSans(
              textStyle: Theme.of(context).textTheme.titleLarge,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: onEnterApp,
          child: Text(l10n.landingPrimaryAction),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.apkUri,
    required this.onEnterApp,
    required this.onDownloadApk,
  });

  final Uri? apkUri;
  final VoidCallback onEnterApp;
  final VoidCallback? onDownloadApk;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroCopy(
            apkUri: apkUri,
            onEnterApp: onEnterApp,
            onDownloadApk: onDownloadApk,
          ),
          const SizedBox(height: 36),
          const _ProductPreview(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 11,
          child: _HeroCopy(
            apkUri: apkUri,
            onEnterApp: onEnterApp,
            onDownloadApk: onDownloadApk,
          ),
        ),
        const SizedBox(width: 44),
        const Expanded(flex: 9, child: _ProductPreview()),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.apkUri,
    required this.onEnterApp,
    required this.onDownloadApk,
  });

  final Uri? apkUri;
  final VoidCallback onEnterApp;
  final VoidCallback? onDownloadApk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Pill(
          icon: Icons.public_rounded,
          label: l10n.landingBadge,
          color: colorScheme.primary,
        ),
        const SizedBox(height: 22),
        Text(
          l10n.landingHeroTitle,
          style: GoogleFonts.notoSans(
            textStyle: textTheme.displayMedium,
            fontWeight: FontWeight.w900,
            height: 1.02,
            letterSpacing: -1.8,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Text(
            l10n.landingHeroSubtitle,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onEnterApp,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(l10n.landingPrimaryAction),
            ),
            OutlinedButton.icon(
              onPressed: onDownloadApk,
              icon: const Icon(Icons.android_rounded),
              label: Text(
                apkUri == null
                    ? l10n.landingApkUnavailableAction
                    : l10n.webApkBannerDownloadAction,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Pill(
              icon: Icons.cloud_queue_rounded,
              label: l10n.landingSignalSources,
              color: colorScheme.secondary,
            ),
            _Pill(
              icon: Icons.lyrics_rounded,
              label: l10n.landingSignalMetadata,
              color: colorScheme.tertiary,
            ),
            _Pill(
              icon: Icons.devices_rounded,
              label: l10n.landingSignalPlatforms,
              color: colorScheme.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPreview extends StatelessWidget {
  const _ProductPreview();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 38,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _WindowDot(color: colorScheme.error),
                  _WindowDot(color: colorScheme.tertiary),
                  _WindowDot(color: colorScheme.primary),
                  const Spacer(),
                  _Pill(
                    icon: Icons.radar_rounded,
                    label: l10n.landingPreviewScanStatus,
                    color: colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                l10n.landingPreviewKicker,
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.landingPreviewTitle,
                style: GoogleFonts.notoSans(
                  textStyle: textTheme.headlineSmall,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tight = constraints.maxWidth < 420;
                  final tiles = [
                    _MockAlbumTile(
                      title: l10n.landingPreviewAlbumOne,
                      subtitle: l10n.landingPreviewSourceWebDav,
                      icon: Icons.album_rounded,
                      color: colorScheme.primary,
                    ),
                    _MockAlbumTile(
                      title: l10n.landingPreviewAlbumTwo,
                      subtitle: l10n.landingPreviewSourceCloud,
                      icon: Icons.queue_music_rounded,
                      color: colorScheme.secondary,
                    ),
                    _MockAlbumTile(
                      title: l10n.landingPreviewAlbumThree,
                      subtitle: l10n.landingPreviewSourceLocal,
                      icon: Icons.library_music_rounded,
                      color: colorScheme.tertiary,
                    ),
                  ];

                  if (tight) {
                    return Column(
                      children: [
                        for (final tile in tiles) ...[
                          tile,
                          if (tile != tiles.last) const SizedBox(height: 10),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      for (final tile in tiles) ...[
                        Expanded(child: tile),
                        if (tile != tiles.last) const SizedBox(width: 10),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _PreviewPlayer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 7),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _MockAlbumTile extends StatelessWidget {
  const _MockAlbumTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: colorScheme.onPrimary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.landingPreviewNowPlaying,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.72,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.landingPreviewTrackTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.graphic_eq_rounded, color: colorScheme.primary),
        ],
      ),
    );
  }
}

class _DownloadSection extends StatelessWidget {
  const _DownloadSection({
    required this.apkUri,
    required this.onEnterApp,
    required this.onDownloadApk,
  });

  final Uri? apkUri;
  final VoidCallback onEnterApp;
  final VoidCallback? onDownloadApk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return _SectionShell(
      title: l10n.landingDownloadTitle,
      description: l10n.landingDownloadDescription,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final tiles = [
            _DownloadTile(
              icon: Icons.web_rounded,
              title: l10n.landingDownloadWebTitle,
              description: l10n.landingDownloadWebDescription,
              actionLabel: l10n.landingPrimaryAction,
              color: colorScheme.primary,
              onPressed: onEnterApp,
            ),
            _DownloadTile(
              icon: Icons.android_rounded,
              title: l10n.landingDownloadApkTitle,
              description: apkUri == null
                  ? l10n.webApkBannerUnavailableLabel
                  : l10n.landingDownloadApkDescription,
              actionLabel: apkUri == null
                  ? l10n.landingApkUnavailableAction
                  : l10n.webApkBannerDownloadAction,
              color: colorScheme.secondary,
              onPressed: onDownloadApk,
            ),
          ];

          if (compact) {
            return Column(
              children: [
                for (final tile in tiles) ...[
                  tile,
                  if (tile != tiles.last) const SizedBox(height: 14),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final tile in tiles) ...[
                Expanded(child: tile),
                if (tile != tiles.last) const SizedBox(width: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return _SectionShell(
      title: l10n.landingFeaturesTitle,
      description: l10n.landingFeaturesDescription,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final cards = [
            _FeatureCard(
              icon: Icons.storage_rounded,
              title: l10n.landingFeatureSourcesTitle,
              description: l10n.landingFeatureSourcesDescription,
              color: colorScheme.primary,
            ),
            _FeatureCard(
              icon: Icons.auto_awesome_rounded,
              title: l10n.landingFeatureLibraryTitle,
              description: l10n.landingFeatureLibraryDescription,
              color: colorScheme.secondary,
            ),
            _FeatureCard(
              icon: Icons.lyrics_rounded,
              title: l10n.landingFeatureMetadataTitle,
              description: l10n.landingFeatureMetadataDescription,
              color: colorScheme.tertiary,
            ),
            _FeatureCard(
              icon: Icons.offline_bolt_rounded,
              title: l10n.landingFeaturePlaybackTitle,
              description: l10n.landingFeaturePlaybackDescription,
              color: colorScheme.primary,
            ),
          ];

          if (compact) {
            return Column(
              children: [
                for (final card in cards) ...[
                  card,
                  if (card != cards.last) const SizedBox(height: 14),
                ],
              ],
            );
          }

          return GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2.35,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: cards,
          );
        },
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.notoSans(
                  textStyle: Theme.of(context).textTheme.headlineMedium,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _MarketingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon, color: color),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _MarketingCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketingCard extends StatelessWidget {
  const _MarketingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _ClosingPanel extends StatelessWidget {
  const _ClosingPanel({required this.onEnterApp});

  final VoidCallback onEnterApp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final copy = Column(
            crossAxisAlignment: compact
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              Text(
                l10n.landingClosingTitle,
                style: GoogleFonts.notoSans(
                  textStyle: Theme.of(context).textTheme.headlineSmall,
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.landingClosingDescription,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
                  height: 1.5,
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onEnterApp,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(l10n.landingPrimaryAction),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 18), button],
            );
          }

          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              button,
            ],
          );
        },
      ),
    );
  }
}
