import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../../core/models/library_song.dart';
import '../../../../core/widgets/studio_chrome.dart';
import '../../application/player_controller.dart';
import 'generated_cover_art.dart';
import 'playback_timeline.dart';

class NowPlayingPanel extends ConsumerStatefulWidget {
  const NowPlayingPanel({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<NowPlayingPanel> createState() => _NowPlayingPanelState();
}

class _NowPlayingPanelState extends ConsumerState<NowPlayingPanel> {
  double? _dragValue;
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    if (!playerState.hasTrack) {
      return Center(
        child: StudioPanel(
          radius: 32,
          tint: colorScheme.surfaceContainerLow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GeneratedCoverArt(
                title: l10n.playerTitle,
                subtitle: l10n.playerEmptyDescription,
                size: studioSpacingOf(
                  context,
                  220,
                ).clamp(160.0, 260.0).toDouble(),
                borderRadius: 30,
              ),
              const StudioGap(height: 20),
              Text(
                l10n.playerEmptyTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const StudioGap(height: 8),
              Text(
                l10n.playerEmptyDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final track = playerState.currentTrack!;
    final subtitle = [
      track.artistName,
      track.albumTitle,
      track.sourceName,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');
    final duration = playerState.duration;
    final maxPosition = duration?.inMilliseconds.toDouble() ?? 1.0;
    final isSeekEnabled = maxPosition > 1;
    final positionValue =
        (_dragValue ?? playerState.position.inMilliseconds.toDouble()).clamp(
          0.0,
          maxPosition,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860 && !widget.compact;

        return SingleChildScrollView(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _CoverStage(
                        playerState: playerState,
                        subtitle: subtitle,
                        showLyrics: _showLyrics,
                        onToggleLyrics: () {
                          setState(() => _showLyrics = !_showLyrics);
                        },
                      ),
                    ),
                    const StudioGap(width: 20),
                    Expanded(
                      flex: 10,
                      child: _ControlStage(
                        playerState: playerState,
                        subtitle: subtitle,
                        positionValue: positionValue,
                        maxPosition: maxPosition,
                        isSeekEnabled: isSeekEnabled,
                        onSeekChanged: (value) =>
                            setState(() => _dragValue = value),
                        onSeekEnd: (value) async {
                          setState(() => _dragValue = null);
                          await controller.seek(
                            Duration(milliseconds: value.round()),
                          );
                        },
                        onPrevious: controller.playPrevious,
                        onTogglePlayback: controller.togglePlayPause,
                        onNext: controller.playNext,
                        onCyclePlaybackMode: controller.cyclePlaybackMode,
                        onShowPlaylist: () => _showPlaylistSheet(context, ref),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _CoverStage(
                      playerState: playerState,
                      subtitle: subtitle,
                      showLyrics: _showLyrics,
                      onToggleLyrics: () {
                        setState(() => _showLyrics = !_showLyrics);
                      },
                    ),
                    const StudioGap(height: 20),
                    _ControlStage(
                      playerState: playerState,
                      subtitle: subtitle,
                      positionValue: positionValue,
                      maxPosition: maxPosition,
                      isSeekEnabled: isSeekEnabled,
                      onSeekChanged: (value) =>
                          setState(() => _dragValue = value),
                      onSeekEnd: (value) async {
                        setState(() => _dragValue = null);
                        await controller.seek(
                          Duration(milliseconds: value.round()),
                        );
                      },
                      onPrevious: controller.playPrevious,
                      onTogglePlayback: controller.togglePlayPause,
                      onNext: controller.playNext,
                      onCyclePlaybackMode: controller.cyclePlaybackMode,
                      onShowPlaylist: () => _showPlaylistSheet(context, ref),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CoverStage extends StatelessWidget {
  const _CoverStage({
    required this.playerState,
    required this.subtitle,
    required this.showLyrics,
    required this.onToggleLyrics,
  });

  final PlayerViewState playerState;
  final String subtitle;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final track = playerState.currentTrack!;

    return StudioPanel(
      radius: 32,
      tint: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioSectionTitle(
            eyebrow: l10n.playerTitle.toUpperCase(),
            title: track.title,
            description: subtitle,
          ),
          const StudioGap(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(
                constraints.maxWidth,
                studioSpacingOf(context, 420).clamp(320.0, 520.0).toDouble(),
              );

              return Center(
                child: Material(
                  color: colorScheme.surface.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onToggleLyrics,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: showLyrics
                          ? Container(
                              key: const ValueKey('lyrics'),
                              width: size,
                              height: size,
                              padding: studioPaddingOf(
                                context,
                                const EdgeInsets.all(24),
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: _LyricsPanel(
                                lyrics: playerState.lyrics,
                                activeIndex: playerState.activeLyricIndex,
                                emptyLabel: l10n.lyricsEmptyLabel,
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('cover'),
                              width: size,
                              height: size,
                              child: GeneratedCoverArt(
                                title: track.title,
                                subtitle: subtitle,
                                size: size,
                                borderRadius: 28,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ControlStage extends StatelessWidget {
  const _ControlStage({
    required this.playerState,
    required this.subtitle,
    required this.positionValue,
    required this.maxPosition,
    required this.isSeekEnabled,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.onPrevious,
    required this.onTogglePlayback,
    required this.onNext,
    required this.onCyclePlaybackMode,
    required this.onShowPlaylist,
  });

  final PlayerViewState playerState;
  final String subtitle;
  final double positionValue;
  final double maxPosition;
  final bool isSeekEnabled;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePlayback;
  final VoidCallback onNext;
  final VoidCallback onCyclePlaybackMode;
  final VoidCallback onShowPlaylist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StudioPanel(
      radius: 32,
      tint: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: studioSpacingOf(context, 10),
            runSpacing: studioSpacingOf(context, 10),
            children: [
              StudioPill(
                icon: Icons.music_note_rounded,
                label: playerState.currentTrack!.sourceName,
                prominent: true,
              ),
              StudioPill(
                icon: Icons.access_time_rounded,
                label: _formatDuration(playerState.duration ?? Duration.zero),
              ),
              if (playerState.hasPlaylist)
                StudioPill(
                  icon: Icons.queue_music_rounded,
                  label: l10n.playlistCountLabel(playerState.playlistCount),
                ),
              StudioPill(
                icon: _playbackModeIcon(playerState.playbackMode),
                label: _playbackModeLabel(l10n, playerState.playbackMode),
              ),
            ],
          ),
          if (playerState.errorMessage != null) ...[
            const StudioGap(height: 18),
            Text(
              playerState.errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
          const StudioGap(height: 24),
          SeekablePlaybackTimeline(
            value: positionValue,
            max: maxPosition,
            cacheSegments: playerState.cacheSegments,
            enabled: isSeekEnabled,
            onChanged: onSeekChanged,
            onChangeEnd: onSeekEnd,
          ),
          const StudioGap(height: 12),
          Row(
            children: [
              Text(
                _formatDuration(playerState.position),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                _formatDuration(playerState.duration ?? Duration.zero),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const StudioGap(height: 28),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoundControlButton(
                    tooltip: _playbackModeLabel(l10n, playerState.playbackMode),
                    icon: _playbackModeIcon(playerState.playbackMode),
                    onPressed: onCyclePlaybackMode,
                  ),
                  const StudioGap(width: 10),
                  _RoundControlButton(
                    tooltip: l10n.previousTrackAction,
                    icon: Icons.skip_previous_rounded,
                    onPressed: playerState.canPlayPrevious ? onPrevious : null,
                  ),
                  const StudioGap(width: 10),
                  _RoundControlButton(
                    tooltip: playerState.isPlaying
                        ? l10n.pauseAction
                        : l10n.playAction,
                    icon: playerState.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onPressed: onTogglePlayback,
                    prominent: true,
                  ),
                  const StudioGap(width: 10),
                  _RoundControlButton(
                    tooltip: l10n.nextTrackAction,
                    icon: Icons.skip_next_rounded,
                    onPressed: playerState.canPlayNext ? onNext : null,
                  ),
                  const StudioGap(width: 10),
                  _RoundControlButton(
                    tooltip: l10n.playlistTitle,
                    icon: Icons.queue_music_rounded,
                    onPressed: onShowPlaylist,
                  ),
                ],
              ),
            ),
          ),
          const StudioGap(height: 24),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

void _showPlaylistSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.66;

      return SafeArea(
        top: false,
        child: Padding(
          padding: studioPaddingOf(
            sheetContext,
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Consumer(
              builder: (context, sheetRef, _) {
                final l10n = AppLocalizations.of(context)!;
                final playerState = sheetRef.watch(playerControllerProvider);
                final controller = sheetRef.read(
                  playerControllerProvider.notifier,
                );

                return StudioPanel(
                  padding: const EdgeInsets.all(14),
                  radius: 24,
                  tint: colorScheme.surfaceContainerLow,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StudioSectionTitle(
                              eyebrow: l10n.playlistCountLabel(
                                playerState.playlistCount,
                              ),
                              title: l10n.playlistTitle,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.closeAction,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const StudioGap(height: 12),
                      if (playerState.playlist.isEmpty)
                        Padding(
                          padding: studioPaddingOf(
                            context,
                            const EdgeInsets.symmetric(vertical: 24),
                          ),
                          child: Center(
                            child: Text(
                              l10n.playlistEmptyTitle,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: playerState.playlist.length,
                            separatorBuilder: (_, _) =>
                                const StudioGap(height: 8),
                            itemBuilder: (context, index) {
                              final song = playerState.playlist[index];
                              final isCurrent =
                                  index == playerState.currentIndex;

                              return _PlaylistRow(
                                song: song,
                                isCurrent: isCurrent,
                                currentLabel: l10n.currentTrackLabel,
                                removeTooltip: l10n.removeFromPlaylistAction,
                                onTap: () =>
                                    controller.playPlaylistIndex(index),
                                onRemove: () =>
                                    controller.removePlaylistItemAt(index),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.song,
    required this.isCurrent,
    required this.currentLabel,
    required this.removeTooltip,
    required this.onTap,
    required this.onRemove,
  });

  final LibrarySong song;
  final bool isCurrent;
  final String currentLabel;
  final String removeTooltip;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = studioRadiusOf(context, 18);
    final leadingSize = studioSpacingOf(
      context,
      38,
    ).clamp(32.0, 48.0).toDouble();

    return Material(
      color: isCurrent
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Padding(
          padding: studioPaddingOf(
            context,
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: Row(
            children: [
              Container(
                width: leadingSize,
                height: leadingSize,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? colorScheme.surface
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCurrent
                      ? Icons.graphic_eq_rounded
                      : Icons.music_note_rounded,
                  size: 19,
                  color: isCurrent
                      ? colorScheme.primary
                      : colorScheme.onPrimaryContainer,
                ),
              ),
              const StudioGap(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isCurrent
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                    const StudioGap(height: 3),
                    Text(
                      isCurrent
                          ? currentLabel
                          : '${song.artistName} · ${song.albumTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isCurrent
                            ? colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.74,
                              )
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: removeTooltip,
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.prominent = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;
    final radius = studioRadiusOf(context, prominent ? 28 : 22);

    return Container(
      decoration: BoxDecoration(
        color: !isEnabled
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.62)
            : prominent
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: prominent ? 28 : 22,
        padding: studioPaddingOf(context, EdgeInsets.all(prominent ? 14 : 11)),
        icon: Icon(
          icon,
          color: !isEnabled
              ? colorScheme.onSurface.withValues(alpha: 0.38)
              : prominent
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({
    required this.lyrics,
    required this.activeIndex,
    required this.emptyLabel,
  });

  final List<LyricLine> lyrics;
  final int activeIndex;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return lyrics.isEmpty
        ? Center(
            child: Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          )
        : ListView.separated(
            itemCount: lyrics.length,
            separatorBuilder: (_, _) => const StudioGap(height: 10),
            itemBuilder: (context, index) {
              final isActive = index == activeIndex;
              final line = lyrics[index];

              return AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style:
                    (isActive
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.bodyLarge)
                        ?.copyWith(
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ) ??
                    const TextStyle(),
                child: Text(line.text, textAlign: TextAlign.center),
              );
            },
          );
  }
}

IconData _playbackModeIcon(PlayerPlaybackMode mode) {
  return switch (mode) {
    PlayerPlaybackMode.list => Icons.repeat_rounded,
    PlayerPlaybackMode.repeatOne => Icons.repeat_one_rounded,
    PlayerPlaybackMode.shuffle => Icons.shuffle_rounded,
  };
}

String _playbackModeLabel(AppLocalizations l10n, PlayerPlaybackMode mode) {
  return switch (mode) {
    PlayerPlaybackMode.list => l10n.playbackModeList,
    PlayerPlaybackMode.repeatOne => l10n.playbackModeRepeatOne,
    PlayerPlaybackMode.shuffle => l10n.playbackModeShuffle,
  };
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final hours = totalSeconds ~/ 3600;

  if (hours > 0) {
    final remainingMinutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(
      2,
      '0',
    );
    return '${hours.toString().padLeft(2, '0')}:$remainingMinutes:$seconds';
  }

  return '$minutes:$seconds';
}
