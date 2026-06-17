import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:path/path.dart' as p;

import '../../../../core/widgets/studio_chrome.dart';
import '../../application/player_controller.dart';
import 'playback_timeline.dart';
import 'track_cover_thumbnail.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _GlacierPalette.sync(context);
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    if (!playerState.hasTrack) {
      return const SizedBox.shrink();
    }

    final track = playerState.currentTrack!;
    final displaySong =
        playerState.hasPlaylist &&
            playerState.currentIndex >= 0 &&
            playerState.currentIndex < playerState.playlistCount
        ? playerState.playlist[playerState.currentIndex]
        : null;

    final displayTitle = displaySong?.displayTitle ?? track.displayTitle;
    final displayArtist = displaySong?.displayArtist ?? track.displayArtist;
    final displayAlbum = displaySong?.displayAlbum ?? track.displayAlbum;
    final displayLocalCoverPath =
        displaySong?.displayLocalCoverPath ?? track.localCoverPath;
    final displayCoverUrl =
        displaySong?.displayCoverUrl ?? track.autoScrapedCoverUrl;
    final directoryPath =
        displaySong?.directoryPath ?? _directoryPath(track.remotePath);

    final subtitle = [
      displayArtist,
      displayAlbum,
      track.sourceName,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    final duration = playerState.duration ?? Duration.zero;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : playerState.position.inMilliseconds / duration.inMilliseconds;
    final cardRadius = studioRadiusOf(context, 20);
    final coverRadius = studioRadiusOf(context, 14);
    final coverSize = studioListSpacingOf(context, 44).clamp(40.0, 52.0);
    final outerBottom = studioSpacingOf(context, 4).clamp(2.0, 8.0);
    final innerVertical = studioSpacingOf(context, 8).clamp(6.0, 12.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, outerBottom),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: _GlacierPalette.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: _GlacierPalette.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/player'),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    10,
                    innerVertical,
                    10,
                    innerVertical,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          TrackCoverThumbnail(
                            title: displayTitle,
                            subtitle: subtitle,
                            size: coverSize,
                            borderRadius: coverRadius,
                            localCoverPath: displayLocalCoverPath,
                            coverUrl: displayCoverUrl,
                            trackId: displaySong?.id ?? track.id,
                            sourceId: displaySong?.sourceId ?? track.sourceId,
                            directoryPath: directoryPath,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: _GlacierPalette.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle.isEmpty
                                      ? track.sourceName
                                      : subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: _GlacierPalette.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _MiniControlButton(
                            tooltip: l10n.previousTrackAction,
                            icon: Icons.skip_previous_rounded,
                            onPressed: playerState.canPlayPrevious
                                ? controller.playPrevious
                                : null,
                          ),
                          const SizedBox(width: 4),
                          _MiniPlayButton(
                            tooltip: playerState.isPlaying
                                ? l10n.pauseAction
                                : l10n.playAction,
                            icon: playerState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            onPressed: controller.togglePlayPause,
                          ),
                          const SizedBox(width: 4),
                          _MiniControlButton(
                            tooltip: l10n.nextTrackAction,
                            icon: Icons.skip_next_rounded,
                            onPressed: playerState.canPlayNext
                                ? controller.playNext
                                : null,
                          ),
                          const SizedBox(width: 4),
                          _MiniControlButton(
                            tooltip: l10n.openPlayerAction,
                            icon: Icons.expand_less_rounded,
                            onPressed: () => context.push('/player'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: PlaybackTimeline(
                          progress: progress.isNaN ? 0 : progress.clamp(0, 1),
                          cacheSegments: playerState.cacheSegments,
                          height: 3,
                          backgroundColor: _GlacierPalette.surfaceContainerHigh,
                          cacheColor: _GlacierPalette.outline.withValues(
                            alpha: 0.4,
                          ),
                          progressColor: _GlacierPalette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _directoryPath(String remotePath) {
    final resolved = p.posix.dirname(remotePath);
    return resolved == '.' ? '/' : resolved;
  }
}

class _MiniControlButton extends StatelessWidget {
  const _MiniControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final itemRadius = studioRadiusOf(context, 16);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(itemRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(itemRadius),
          onTap: onPressed,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              icon,
              size: 18,
              color: enabled
                  ? _GlacierPalette.onSurface
                  : _GlacierPalette.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayButton extends StatelessWidget {
  const _MiniPlayButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final itemRadius = studioRadiusOf(context, 16);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _GlacierPalette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(itemRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(itemRadius),
          onTap: onPressed,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 21, color: _GlacierPalette.primary),
          ),
        ),
      ),
    );
  }
}

class _GlacierPalette {
  static Color surface = const Color(0xFF0F1524);
  static Color surfaceContainerHigh = const Color(0xFF1A2438);
  static Color primary = const Color(0xFF7DD3FC);
  static Color onSurface = const Color(0xFFE0E8F0);
  static Color onSurfaceVariant = const Color(0xFFA0B4C4);
  static Color outline = const Color(0xFF4A6070);

  static void sync(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    surface = scheme.surfaceContainer;
    surfaceContainerHigh = scheme.surfaceContainerHigh;
    primary = scheme.primary;
    onSurface = scheme.onSurface;
    onSurfaceVariant = scheme.onSurfaceVariant;
    outline = scheme.outline;
  }
}
