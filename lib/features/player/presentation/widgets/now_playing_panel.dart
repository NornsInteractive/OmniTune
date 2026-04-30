import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../../core/models/library_song.dart';
import '../../../../core/widgets/studio_chrome.dart';
import '../../application/player_controller.dart';
import 'cover_art_image.dart';
import 'generated_cover_art.dart';
import 'playback_timeline.dart';
import 'track_cover_thumbnail.dart';

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

    // 优先从播放列表中获取当前歌曲(包含最新的刮削数据)，否则使用 PlayableTrack
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

    final subtitle = [
      displayArtist,
      displayAlbum,
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
                        displayTitle: displayTitle,
                        subtitle: subtitle,
                        localCoverPath: displayLocalCoverPath,
                        coverUrl: displayCoverUrl,
                        showLyrics: _showLyrics,
                        onSeekToLine: controller.seekAndPlay,
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
                      displayTitle: displayTitle,
                      subtitle: subtitle,
                      localCoverPath: displayLocalCoverPath,
                      coverUrl: displayCoverUrl,
                      showLyrics: _showLyrics,
                      onSeekToLine: controller.seekAndPlay,
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
    required this.displayTitle,
    required this.subtitle,
    required this.localCoverPath,
    required this.coverUrl,
    required this.showLyrics,
    required this.onSeekToLine,
    required this.onToggleLyrics,
  });

  final PlayerViewState playerState;
  final String displayTitle;
  final String subtitle;
  final String? localCoverPath;
  final String? coverUrl;
  final bool showLyrics;
  final Future<void> Function(Duration position) onSeekToLine;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return StudioPanel(
      radius: 32,
      tint: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioSectionTitle(
            eyebrow: l10n.playerTitle.toUpperCase(),
            title: displayTitle,
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
                                scrubPlayTooltip: l10n.playAction,
                                onSeekToLine: onSeekToLine,
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('cover'),
                              width: size,
                              height: size,
                              child: CoverArtImage(
                                title: displayTitle,
                                subtitle: subtitle,
                                size: size,
                                borderRadius: 28,
                                localCoverPath: localCoverPath,
                                coverUrl: coverUrl,
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
              TrackCoverThumbnail(
                title: song.displayTitle,
                subtitle: '${song.displayArtist} · ${song.displayAlbum}',
                size: leadingSize,
                borderRadius: 14,
                localCoverPath: song.displayLocalCoverPath,
                coverUrl: song.displayCoverUrl,
                isCurrentTrack: isCurrent,
              ),
              const StudioGap(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.displayTitle,
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
                          : '${song.displayArtist} · ${song.displayAlbum}',
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

class _LyricsPanel extends StatefulWidget {
  const _LyricsPanel({
    required this.lyrics,
    required this.activeIndex,
    required this.emptyLabel,
    required this.scrubPlayTooltip,
    required this.onSeekToLine,
  });

  final List<LyricLine> lyrics;
  final int activeIndex;
  final String emptyLabel;
  final String scrubPlayTooltip;
  final Future<void> Function(Duration position) onSeekToLine;

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  static const _resumeDelay = Duration(seconds: 3);

  late final ScrollController _scrollController;
  Timer? _resumeAutoScrollTimer;
  late List<GlobalKey> _lineKeys;
  bool _isUserScrolling = false;
  bool _isAutoScrolling = false;
  bool _showScrubber = false;
  int _lastAutoScrolledIndex = -1;
  int? _scrubberLineIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lineKeys = _buildLineKeys(widget.lyrics.length);
    _scheduleScrollToActive(force: true, animated: false);
  }

  @override
  void didUpdateWidget(covariant _LyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics.length != widget.lyrics.length) {
      _lineKeys = _buildLineKeys(widget.lyrics.length);
      _lastAutoScrolledIndex = -1;
      _scrubberLineIndex = null;
    }

    if (oldWidget.activeIndex != widget.activeIndex ||
        oldWidget.lyrics != widget.lyrics) {
      _scheduleScrollToActive(force: oldWidget.lyrics != widget.lyrics);
    }
  }

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return widget.lyrics.isEmpty
        ? Center(
            child: Text(
              widget.emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          )
        : Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: _handleScrollNotification,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 88),
                  itemCount: widget.lyrics.length,
                  separatorBuilder: (_, _) => const StudioGap(height: 10),
                  itemBuilder: (context, index) {
                    final isActive = index == widget.activeIndex;
                    final line = widget.lyrics[index];

                    return KeyedSubtree(
                      key: _lineKeys[index],
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style:
                            (isActive
                                    ? theme.textTheme.headlineSmall
                                    : theme.textTheme.bodyLarge)
                                ?.copyWith(
                                  color: isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  height: isActive ? 1.25 : 1.4,
                                ) ??
                            const TextStyle(),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 180),
                          scale: isActive ? 1.08 : 1,
                          child: Text(line.text, textAlign: TextAlign.center),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showScrubber,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _showScrubber ? 1 : 0,
                    child: Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 52,
                              child: Text(
                                _scrubberTimestampLabel,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const StudioGap(width: 10),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                            ),
                            const StudioGap(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: widget.scrubPlayTooltip,
                                visualDensity: VisualDensity.compact,
                                onPressed: _handleScrubberPlay,
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isAutoScrolling) {
      return false;
    }

    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) {
        _scheduleAutoResumeIfNeeded();
      } else {
        _markUserScrolling();
        _updateScrubberLine();
      }
      return false;
    }

    final isUserDriven =
        notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification;

    if (isUserDriven) {
      _markUserScrolling();
      _updateScrubberLine();
      return false;
    }

    if (notification is ScrollEndNotification && _isUserScrolling) {
      _scheduleAutoResumeIfNeeded();
    }

    return false;
  }

  void _markUserScrolling() {
    final fallbackIndex = _resolvedActiveIndex;
    if (!_isUserScrolling || !_showScrubber || _scrubberLineIndex == null) {
      setState(() {
        _isUserScrolling = true;
        _showScrubber = true;
        _scrubberLineIndex ??= fallbackIndex;
      });
    } else {
      _isUserScrolling = true;
    }
    _resumeAutoScrollTimer?.cancel();
  }

  void _scheduleAutoResumeIfNeeded() {
    if (!_isUserScrolling) {
      return;
    }

    _resumeAutoScrollTimer?.cancel();
    _resumeAutoScrollTimer = Timer(_resumeDelay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUserScrolling = false;
        _showScrubber = false;
        _scrubberLineIndex = null;
      });
      _scheduleScrollToActive(force: true);
    });
  }

  List<GlobalKey> _buildLineKeys(int length) {
    return List<GlobalKey>.generate(length, (_) => GlobalKey());
  }

  int get _resolvedActiveIndex {
    if (widget.lyrics.isEmpty) {
      return -1;
    }
    if (widget.activeIndex >= 0 && widget.activeIndex < widget.lyrics.length) {
      return widget.activeIndex;
    }
    return 0;
  }

  String get _scrubberTimestampLabel {
    final index = _scrubberLineIndex;
    if (index == null || index < 0 || index >= widget.lyrics.length) {
      return _formatDuration(Duration.zero);
    }
    return _formatDuration(widget.lyrics[index].time);
  }

  void _scheduleScrollToActive({
    bool force = false,
    bool animated = true,
    int remainingAttempts = 8,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToActive(
        force: force,
        animated: animated,
        remainingAttempts: remainingAttempts,
      );
    });
  }

  void _updateScrubberLine() {
    if (!mounted || widget.lyrics.isEmpty) {
      return;
    }

    final containerBox = context.findRenderObject();
    if (containerBox is! RenderBox || !containerBox.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _updateScrubberLine(),
      );
      return;
    }

    final centerY = containerBox.size.height / 2;
    var bestIndex = _resolvedActiveIndex;
    var bestDistance = double.infinity;

    for (var index = 0; index < _lineKeys.length; index++) {
      final lineContext = _lineKeys[index].currentContext;
      if (lineContext == null) {
        continue;
      }
      final renderObject = lineContext.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }

      final lineCenter = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
        ancestor: containerBox,
      );
      final distance = (lineCenter.dy - centerY).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }

    if (_scrubberLineIndex == bestIndex) {
      return;
    }

    setState(() {
      _scrubberLineIndex = bestIndex;
    });
  }

  Future<void> _handleScrubberPlay() async {
    final index = _scrubberLineIndex;
    if (index == null || index < 0 || index >= widget.lyrics.length) {
      return;
    }

    _resumeAutoScrollTimer?.cancel();
    setState(() {
      _isUserScrolling = false;
      _showScrubber = false;
    });
    await widget.onSeekToLine(widget.lyrics[index].time);
    _scheduleScrollToActive(force: true);
  }

  Future<void> _scrollToActive({
    bool force = false,
    bool animated = true,
    int remainingAttempts = 0,
  }) async {
    if (!mounted || _isUserScrolling || widget.lyrics.isEmpty) {
      return;
    }

    final targetIndex = _resolvedActiveIndex;
    if (targetIndex < 0 || targetIndex >= _lineKeys.length) {
      return;
    }

    if (!_scrollController.hasClients) {
      if (remainingAttempts > 0) {
        Future<void>.delayed(const Duration(milliseconds: 60), () {
          _scheduleScrollToActive(
            force: force,
            animated: animated,
            remainingAttempts: remainingAttempts - 1,
          );
        });
      }
      return;
    }

    if (!force && targetIndex == _lastAutoScrolledIndex) {
      return;
    }

    final targetContext = _lineKeys[targetIndex].currentContext;
    if (targetContext == null) {
      if (remainingAttempts > 0) {
        Future<void>.delayed(const Duration(milliseconds: 60), () {
          _scheduleScrollToActive(
            force: force,
            animated: animated,
            remainingAttempts: remainingAttempts - 1,
          );
        });
      }
      return;
    }

    _lastAutoScrolledIndex = targetIndex;
    _isAutoScrolling = true;
    try {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: animated ? const Duration(milliseconds: 320) : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) {
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (mounted) {
            _isAutoScrolling = false;
          }
        });
      } else {
        _isAutoScrolling = false;
      }
    }
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
