import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/l10n/app_localizations.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    if (!playerState.hasTrack) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.compact ? 20 : 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.queue_music_rounded,
                size: widget.compact ? 56 : 84,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.playerEmptyTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.playerEmptyDescription,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currentTrack = playerState.currentTrack!;
    final duration = playerState.duration ?? Duration.zero;
    final maxPosition = duration.inMilliseconds <= 0
        ? 1.0
        : duration.inMilliseconds.toDouble();
    final positionValue =
        _dragValue ??
        playerState.position.inMilliseconds.toDouble().clamp(0.0, maxPosition);
    final subtitle = [
      currentTrack.artistName,
      currentTrack.albumTitle,
      currentTrack.sourceName,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 860 || widget.compact;

        final cover = GeneratedCoverArt(
          title: currentTrack.title,
          subtitle: subtitle,
          size: widget.compact ? 220 : 320,
          borderRadius: widget.compact ? 32 : 42,
        );

        final controls = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              currentTrack.title,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 22),
            SeekablePlaybackTimeline(
              value: positionValue,
              max: maxPosition,
              cacheSegments: playerState.cacheSegments,
              enabled: duration != Duration.zero,
              onChanged: (value) {
                setState(() {
                  _dragValue = value;
                });
              },
              onChangeEnd: (value) async {
                setState(() {
                  _dragValue = null;
                });
                await controller.seek(Duration(milliseconds: value.round()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(playerState.position)),
                Text(_formatDuration(duration)),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: l10n.stopAction,
                  onPressed: controller.stop,
                  icon: const Icon(Icons.stop_rounded),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  tooltip: playerState.isPlaying
                      ? l10n.pauseAction
                      : l10n.playAction,
                  onPressed: controller.togglePlayPause,
                  icon: Icon(
                    playerState.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _LyricsPanel(
                lyrics: playerState.lyrics,
                activeIndex: playerState.activeLyricIndex,
                emptyLabel: l10n.lyricsEmptyLabel,
              ),
            ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surfaceContainerHighest,
                colorScheme.surface,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? 20 : 28),
              child: vertical
                  ? Column(
                      children: [
                        cover,
                        SizedBox(height: widget.compact ? 20 : 28),
                        Expanded(child: controls),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 5, child: Center(child: cover)),
                        const SizedBox(width: 28),
                        Expanded(flex: 6, child: controls),
                      ],
                    ),
            ),
          ),
        );
      },
    );
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: lyrics.isEmpty
          ? Center(
              child: Text(
                emptyLabel,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              itemCount: lyrics.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final line = lyrics[index];
                final isActive = index == activeIndex;
                return AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
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
                  child: Text(line.text),
                );
              },
            ),
    );
  }
}
