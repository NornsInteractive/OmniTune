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

bool hasRecoverablePlayerState(PlayerViewState state) {
  if (state.currentTrack != null) return true;
  if (state.canRetry) return true;
  return state.isResolvingTrack &&
      (state.requestedTitle?.trim().isNotEmpty == true);
}

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(
      playerControllerProvider.select(hasRecoverablePlayerState),
    );
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return AnimatedSwitcher(
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 200),
      switchInCurve: const Cubic(0.2, 0.0, 0.0, 1.0),
      switchOutCurve: const Cubic(0.2, 0.0, 0.0, 1.0),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1.0,
            child: child,
          ),
        );
      },
      child: isVisible
          ? const _MiniPlayerContent(key: ValueKey('mini-player-active'))
          : const SizedBox.shrink(key: ValueKey('mini-player-idle')),
    );
  }
}

class _MiniPlayerContent extends ConsumerWidget {
  const _MiniPlayerContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final recoveryInfo = ref.watch(
      playerControllerProvider.select(
        (state) => (
          requestedTitle: state.requestedTitle,
          requestedArtist: state.requestedArtist,
          requestedSourceName: state.requestedSourceName,
          canRetry: state.canRetry,
          isResolvingTrack: state.isResolvingTrack,
          isBusy: state.isBusy,
          errorMessage: state.errorMessage,
        ),
      ),
    );

    final isRecoverable =
        track != null ||
        recoveryInfo.canRetry ||
        (recoveryInfo.isResolvingTrack &&
            (recoveryInfo.requestedTitle?.trim().isNotEmpty == true));

    if (!isRecoverable) {
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

    final controller = ref.read(playerControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    final displayTitle =
        displaySong?.displayTitle ??
        track?.displayTitle ??
        (recoveryInfo.requestedTitle?.trim().isNotEmpty == true
            ? recoveryInfo.requestedTitle!.trim()
            : null) ??
        (recoveryInfo.errorMessage != null
            ? l10n.playbackFailedMessage
            : l10n.playerTitle);
    final displayArtist =
        displaySong?.displayArtist ??
        track?.displayArtist ??
        recoveryInfo.requestedArtist ??
        '';
    final displayAlbum = displaySong?.displayAlbum ?? track?.displayAlbum ?? '';
    final displayLocalCoverPath =
        displaySong?.displayLocalCoverPath ?? track?.localCoverPath;
    final displayCoverUrl =
        displaySong?.displayCoverUrl ?? track?.autoScrapedCoverUrl;
    final directoryPath =
        displaySong?.directoryPath ??
        (track != null ? _directoryPath(track.remotePath) : null);

    final sourceName = (displaySong?.sourceName.isNotEmpty == true)
        ? displaySong!.sourceName
        : (track?.sourceName ?? recoveryInfo.requestedSourceName ?? '');

    final subtitle = [
      displayArtist,
      displayAlbum,
      sourceName,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');

    final cardRadius = studioRadiusOf(context, 18);
    final coverRadius = studioRadiusOf(context, 12);
    final coverSize = studioListSpacingOf(context, 44).clamp(40.0, 52.0);
    final outerBottom = studioSpacingOf(context, 4).clamp(2.0, 8.0);
    final innerVertical = studioSpacingOf(context, 8).clamp(6.0, 10.0);

    final hasError = recoveryInfo.canRetry || recoveryInfo.errorMessage != null;
    final isBusyOrResolving =
        recoveryInfo.isBusy || recoveryInfo.isResolvingTrack;

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
        child: StudioPressable(
          borderRadius: BorderRadius.circular(cardRadius),
          onTap: () => context.push('/player'),
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, innerVertical, 10, innerVertical),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    RepaintBoundary(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: TrackCoverThumbnail(
                          key: ValueKey(
                            displaySong?.id ??
                                track?.id ??
                                'mini-cover-thumbnail',
                          ),
                          title: displayTitle,
                          subtitle: subtitle,
                          size: coverSize,
                          borderRadius: coverRadius,
                          localCoverPath: displayLocalCoverPath,
                          coverUrl: displayCoverUrl,
                          trackId: displaySong?.id ?? track?.id,
                          sourceId: displaySong?.sourceId ?? track?.sourceId,
                          directoryPath: directoryPath,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.centerLeft,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            ),
                        child: Column(
                          key: ValueKey(
                            displaySong?.id ?? track?.id ?? 'mini-title-column',
                          ),
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
                              hasError
                                  ? (recoveryInfo.errorMessage ??
                                        l10n.playbackFailedMessage)
                                  : isBusyOrResolving
                                  ? l10n.playbackBufferingLabel
                                  : !isPlaying
                                  ? l10n.playbackPausedLabel
                                  : subtitle.isEmpty
                                  ? sourceName
                                  : subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.notoSans(
                                color: hasError
                                    ? colorScheme.error
                                    : colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
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
                    const SizedBox(width: 2),
                    _MiniPlayButton(
                      tooltip: hasError
                          ? l10n.retryAction
                          : isBusyOrResolving
                          ? l10n.playbackBufferingLabel
                          : isPlaying
                          ? l10n.pauseAction
                          : l10n.playAction,
                      icon: hasError
                          ? Icons.refresh_rounded
                          : isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      isBusy: isBusyOrResolving && !hasError,
                      hasError: hasError,
                      onPressed: controller.togglePlayPause,
                    ),
                    const SizedBox(width: 2),
                    _MiniControlButton(
                      tooltip: l10n.nextTrackAction,
                      icon: Icons.skip_next_rounded,
                      onPressed: canPlayNext ? controller.playNext : null,
                    ),
                    const SizedBox(width: 2),
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
      child: Semantics(
        button: true,
        label: tooltip,
        enabled: enabled,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(itemRadius),
          child: StudioPressable(
            borderRadius: BorderRadius.circular(itemRadius),
            enabled: enabled,
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              child: Center(
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
    this.isBusy = false,
    this.hasError = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isBusy;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final itemRadius = studioRadiusOf(context, 16);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final containerColor = hasError
        ? colorScheme.errorContainer.withValues(alpha: 0.85)
        : colorScheme.primaryContainer;
    final iconColor = hasError
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(itemRadius),
          child: StudioPressable(
            borderRadius: BorderRadius.circular(itemRadius),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(itemRadius),
                  ),
                  child: Center(
                    child: isBusy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: disableAnimations
                                ? Icon(
                                    Icons.hourglass_empty_rounded,
                                    size: 18,
                                    color: iconColor,
                                  )
                                : CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      iconColor,
                                    ),
                                  ),
                          )
                        : AnimatedSwitcher(
                            duration: disableAnimations
                                ? Duration.zero
                                : const Duration(milliseconds: 160),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              icon,
                              key: ValueKey(icon),
                              size: 22,
                              color: iconColor,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
