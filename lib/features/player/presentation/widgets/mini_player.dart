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
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    if (track == null) {
      return const SizedBox.shrink();
    }
    final displaySong = ref.watch(
      playerControllerProvider.select((state) {
        if (state.hasPlaylist &&
            state.currentIndex >= 0 &&
            state.currentIndex < state.playlistCount) {
          return state.playlist[state.currentIndex];
        }
        return null;
      }),
    );
    final isPlaying = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    final canPlayPrevious = ref.watch(
      playerControllerProvider.select((state) => state.canPlayPrevious),
    );
    final canPlayNext = ref.watch(
      playerControllerProvider.select((state) => state.canPlayNext),
    );

    final status = ref.watch(
      playerControllerProvider.select(
        (state) => (state.isBusy, state.errorMessage),
      ),
    );
    final controller = ref.read(playerControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

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

    final cardRadius = studioRadiusOf(context, 18);
    final coverRadius = studioRadiusOf(context, 12);
    final coverSize = studioListSpacingOf(context, 44).clamp(40.0, 52.0);
    final outerBottom = studioSpacingOf(context, 4).clamp(2.0, 8.0);
    final innerVertical = studioSpacingOf(context, 8).clamp(6.0, 10.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, outerBottom),
      child: Material(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/player'),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, innerVertical, 10, innerVertical),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    RepaintBoundary(
                      child: TrackCoverThumbnail(
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
                            style: GoogleFonts.notoSans(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            status.$2 != null
                                ? l10n.retryAction
                                : status.$1
                                ? l10n.playbackBufferingLabel
                                : !isPlaying
                                ? l10n.playbackPausedLabel
                                : subtitle.isEmpty
                                ? track.sourceName
                                : subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSans(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _MiniControlButton(
                      tooltip: l10n.previousTrackAction,
                      icon: Icons.skip_previous_rounded,
                      onPressed: canPlayPrevious
                          ? controller.playPrevious
                          : null,
                    ),
                    const SizedBox(width: 4),
                    _MiniPlayButton(
                      tooltip: isPlaying ? l10n.pauseAction : l10n.playAction,
                      icon: status.$2 != null
                          ? Icons.refresh_rounded
                          : isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: controller.togglePlayPause,
                    ),
                    const SizedBox(width: 4),
                    _MiniControlButton(
                      tooltip: l10n.nextTrackAction,
                      icon: Icons.skip_next_rounded,
                      onPressed: canPlayNext ? controller.playNext : null,
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
                const _MiniPlayerProgressBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _directoryPath(String remotePath) {
    final resolved = p.posix.dirname(remotePath);
    return resolved == '.' ? '/' : resolved;
  }
}

class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressData = ref.watch(
      playerControllerProvider.select((state) {
        final duration = state.duration ?? Duration.zero;
        final progress = duration.inMilliseconds <= 0
            ? 0.0
            : state.position.inMilliseconds / duration.inMilliseconds;
        return (
          progress: progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0),
          cacheSegments: state.cacheSegments,
        );
      }),
    );

    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: RepaintBoundary(
        child: PlaybackTimeline(
          progress: progressData.progress,
          cacheSegments: progressData.cacheSegments,
          height: 3,
          backgroundColor: colorScheme.surfaceContainerHighest,
          cacheColor: colorScheme.outlineVariant.withValues(alpha: 0.5),
          progressColor: colorScheme.primary,
        ),
      ),
    );
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
    final colorScheme = Theme.of(context).colorScheme;
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
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
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
    final colorScheme = Theme.of(context).colorScheme;
    final itemRadius = studioRadiusOf(context, 16);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(itemRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(itemRadius),
          onTap: onPressed,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 22, color: colorScheme.onPrimaryContainer),
          ),
        ),
      ),
    );
  }
}
