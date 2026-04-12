import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../../core/widgets/studio_chrome.dart';
import '../../application/player_controller.dart';
import 'generated_cover_art.dart';
import 'playback_timeline.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final panelRadius = studioRadiusOf(context, 24);
    final coverSize = studioSpacingOf(context, 56).clamp(44.0, 72.0).toDouble();
    final controlSize = studioSpacingOf(
      context,
      36,
    ).clamp(32.0, 44.0).toDouble();
    final playSize = studioSpacingOf(context, 40).clamp(36.0, 48.0).toDouble();

    if (!playerState.hasTrack) {
      return const SizedBox.shrink();
    }

    final track = playerState.currentTrack!;
    final duration = playerState.duration ?? Duration.zero;
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : playerState.position.inMilliseconds / duration.inMilliseconds;
    final subtitle = [
      track.artistName,
      track.albumTitle,
      track.sourceName,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');

    return Padding(
      padding: studioPaddingOf(context, const EdgeInsets.fromLTRB(0, 0, 0, 10)),
      child: StudioPanel(
        padding: EdgeInsets.zero,
        radius: 24,
        tint: colorScheme.surfaceContainerLow,
        child: Material(
          color: colorScheme.surface.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(panelRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(panelRadius),
            onTap: () => context.push('/player'),
            child: Padding(
              padding: studioPaddingOf(
                context,
                const EdgeInsets.fromLTRB(14, 12, 14, 12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      GeneratedCoverArt(
                        title: track.title,
                        subtitle: subtitle,
                        size: coverSize,
                        borderRadius: 18,
                      ),
                      const StudioGap(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            const StudioGap(height: 3),
                            Text(
                              subtitle.isEmpty ? track.sourceName : subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const StudioGap(width: 8),
                      IconButton(
                        tooltip: l10n.previousTrackAction,
                        onPressed: playerState.canPlayPrevious
                            ? controller.playPrevious
                            : null,
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        padding: studioPaddingOf(
                          context,
                          const EdgeInsets.all(6),
                        ),
                        constraints: BoxConstraints(
                          minWidth: controlSize,
                          minHeight: controlSize,
                        ),
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          tooltip: playerState.isPlaying
                              ? l10n.pauseAction
                              : l10n.playAction,
                          onPressed: controller.togglePlayPause,
                          iconSize: 24,
                          padding: studioPaddingOf(
                            context,
                            const EdgeInsets.all(8),
                          ),
                          constraints: BoxConstraints(
                            minWidth: playSize,
                            minHeight: playSize,
                          ),
                          icon: Icon(
                            playerState.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.nextTrackAction,
                        onPressed: playerState.canPlayNext
                            ? controller.playNext
                            : null,
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        padding: studioPaddingOf(
                          context,
                          const EdgeInsets.all(6),
                        ),
                        constraints: BoxConstraints(
                          minWidth: controlSize,
                          minHeight: controlSize,
                        ),
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      IconButton(
                        tooltip: l10n.openPlayerAction,
                        onPressed: () => context.push('/player'),
                        iconSize: 22,
                        visualDensity: VisualDensity.compact,
                        padding: studioPaddingOf(
                          context,
                          const EdgeInsets.all(6),
                        ),
                        constraints: BoxConstraints(
                          minWidth: controlSize,
                          minHeight: controlSize,
                        ),
                        icon: const Icon(Icons.expand_less_rounded),
                      ),
                    ],
                  ),
                  const StudioGap(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: PlaybackTimeline(
                      progress: progress.isNaN ? 0 : progress.clamp(0, 1),
                      cacheSegments: playerState.cacheSegments,
                      height: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
