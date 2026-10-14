import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:path/path.dart' as p;

import '../../../../core/models/library_song.dart';
import '../../../../core/widgets/studio_chrome.dart';
import '../../../library/application/library_catalog_controller.dart';
import '../../../scraper/presentation/lyrics_scraping_sheet.dart';
import '../../application/player_controller.dart';
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
  bool _showLyrics = false;

  IconData _playbackModeIcon(PlayerPlaybackMode mode) {
    return switch (mode) {
      PlayerPlaybackMode.list => Icons.format_list_bulleted_rounded,
      PlayerPlaybackMode.shuffle => Icons.shuffle_rounded,
      PlayerPlaybackMode.repeatOne => Icons.repeat_one_rounded,
      PlayerPlaybackMode.repeatAll => Icons.repeat_rounded,
    };
  }

  String _playbackModeLabel(AppLocalizations l10n, PlayerPlaybackMode mode) {
    return switch (mode) {
      PlayerPlaybackMode.list => l10n.playbackModeList,
      PlayerPlaybackMode.shuffle => l10n.playbackModeShuffle,
      PlayerPlaybackMode.repeatOne => l10n.playbackModeRepeatOne,
      PlayerPlaybackMode.repeatAll => l10n.playbackModeRepeatAll,
    };
  }

  String? _lyricsSourceLabel(AppLocalizations l10n, PlayerLyricsSource source) {
    return switch (source) {
      PlayerLyricsSource.none => null,
      PlayerLyricsSource.sidecarFile => l10n.lyricsSourceSidecarLabel,
      PlayerLyricsSource.embeddedTag => l10n.lyricsSourceEmbeddedLabel,
      PlayerLyricsSource.scraped => l10n.lyricsSourceScrapedLabel,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final controller = ref.read(playerControllerProvider.notifier);

    final hasTrack = ref.watch(
      playerControllerProvider.select((state) => state.hasTrack),
    );
    final currentTrack = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final requestedInfo = ref.watch(
      playerControllerProvider.select(
        (state) => (
          title: state.requestedTitle,
          artist: state.requestedArtist,
          sourceName: state.requestedSourceName,
          errorMessage: state.errorMessage,
          canRetry: state.canRetry,
          isResolving: state.isResolvingTrack,
        ),
      ),
    );

    final hasResolvingOrTarget =
        hasTrack ||
        currentTrack != null ||
        requestedInfo.title != null ||
        requestedInfo.errorMessage != null ||
        requestedInfo.canRetry ||
        requestedInfo.isResolving;

    if (!hasResolvingOrTarget) {
      return _EmptyNowPlayingState(
        title: l10n.playerEmptyTitle,
        description: l10n.playerEmptyDescription,
      );
    }

    ref.watch(
      playerControllerProvider.select(
        (state) => (
          currentTrack: state.currentTrack,
          playlist: state.playlist,
          currentIndex: state.currentIndex,
          isPlaying: state.isPlaying,
          processingState: state.processingState,
          duration: state.duration,
          playbackMode: state.playbackMode,
          lyrics: state.lyrics,
          lyricsSource: state.lyricsSource,
          errorMessage: state.errorMessage,
        ),
      ),
    );

    final playerState = ref.read(playerControllerProvider);
    final track = playerState.currentTrack ?? currentTrack;
    final currentSong =
        playerState.hasPlaylist &&
            playerState.currentIndex >= 0 &&
            playerState.currentIndex < playerState.playlistCount
        ? playerState.playlist[playerState.currentIndex]
        : null;

    final currentSongId = currentSong?.id;
    final isFavorite = ref.watch(
      libraryCatalogControllerProvider.select(
        (s) =>
            currentSongId != null &&
            (s.valueOrNull?.favoriteTrackIds.contains(currentSongId) ?? false),
      ),
    );

    final displayTitle =
        currentSong?.displayTitle ??
        track?.displayTitle ??
        playerState.requestedTitle ??
        (playerState.errorMessage != null
            ? l10n.playbackFailedMessage
            : l10n.playerTitle);
    final displayArtist =
        currentSong?.displayArtist ??
        track?.displayArtist ??
        playerState.requestedArtist ??
        playerState.requestedSourceName ??
        '';
    final displayAlbum = currentSong?.displayAlbum ?? track?.displayAlbum ?? '';
    final displayLocalCoverPath =
        currentSong?.displayLocalCoverPath ?? track?.localCoverPath;
    final displayCoverUrl =
        currentSong?.displayCoverUrl ?? track?.autoScrapedCoverUrl;
    final directoryPath =
        currentSong?.directoryPath ??
        (track != null ? _directoryPath(track.remotePath) : '/');
    final sourceName = (currentSong?.sourceName.isNotEmpty == true)
        ? currentSong!.sourceName
        : (track?.sourceName ?? playerState.requestedSourceName ?? '');
    final albumAndSource = [
      displayAlbum,
      sourceName,
    ].where((value) => value.isNotEmpty).join(' · ');

    final lyricsSourceLabel = _lyricsSourceLabel(
      l10n,
      playerState.lyricsSource,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelRadius = studioRadiusOf(context, 32);
        final isWide = !widget.compact && constraints.maxWidth >= 800;
        final maxPanelWidth = widget.compact
            ? constraints.maxWidth
            : math.min(constraints.maxWidth - 20, isWide ? 920.0 : 480.0);
        final canFillHeight = !widget.compact && constraints.hasBoundedHeight;
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final isShortOrLargeText = availableHeight < 620 || textScale > 1.15;
        final fallbackArtworkSize = math.min(
          maxPanelWidth - 40,
          math.max(160.0, availableHeight * 0.38),
        );

        final headerWidget = _PlayerHeader(
          title: displayAlbum.isEmpty ? displayTitle : displayAlbum,
          nowPlayingLabel: l10n.playerTitle,
          lyricsScrapeTooltip: l10n.scrapingUpdateLyricsAction,
          onCollapse: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
          },
          onLyricsScrape: () {
            showLyricsScrapingSheet(
              context: context,
              title: displayTitle,
              artist: displayArtist,
              album: displayAlbum,
            );
          },
          onMore: () => _showTrackDetailsSheet(
            context,
            title: displayTitle,
            artist: displayArtist,
            album: displayAlbum,
            sourceName: sourceName,
            path: track?.remotePath ?? '',
          ),
        );

        final trackInfoAndErrorWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _glacierTextStyle(
                          color: colorScheme.onSurface,
                          size: 24,
                          weight: FontWeight.w700,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayArtist.isEmpty ? sourceName : displayArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _glacierTextStyle(
                          color: colorScheme.onSurfaceVariant,
                          size: 16,
                          weight: FontWeight.w500,
                        ),
                      ),
                      if (albumAndSource.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          albumAndSource,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _glacierTextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                            size: 12,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ],
                      if (lyricsSourceLabel != null) ...[
                        const SizedBox(height: 8),
                        _NowPlayingMetaChip(
                          icon: Icons.lyrics_rounded,
                          label: lyricsSourceLabel,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _HeaderCircleButton(
                  tooltip: currentSong == null
                      ? l10n.playlistTitle
                      : isFavorite
                      ? l10n.removeFromFavoritesAction
                      : l10n.addToFavoritesAction,
                  icon: currentSong != null
                      ? (isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded)
                      : Icons.queue_music_rounded,
                  iconColor: currentSong != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  filled: currentSong != null && isFavorite,
                  onTap: currentSong == null
                      ? () => _showPlaylistSheet(context)
                      : () {
                          ref
                              .read(libraryCatalogControllerProvider.notifier)
                              .toggleFavorite(currentSong.id);
                        },
                ),
              ],
            ),
            if (playerState.errorMessage != null || playerState.canRetry) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      playerState.errorMessage ?? l10n.playbackFailedMessage,
                      style: _glacierTextStyle(
                        color: colorScheme.error,
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: controller.play,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.standard,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: Text(l10n.retryAction),
                  ),
                ],
              ),
            ],
          ],
        );

        final bottomControlsWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: studioSpacingOf(context, 14).clamp(8.0, 18.0)),
            const _NowPlayingTimelineDeck(),
            SizedBox(height: studioSpacingOf(context, 16).clamp(10.0, 20.0)),
            LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final defaultActionSize = studioListSpacingOf(
                  context,
                  56,
                ).clamp(48.0, 64.0);
                final isTight =
                    availableWidth < defaultActionSize * 4 + 64.0 + 8.0;

                final actionSize = isTight ? 48.0 : defaultActionSize;
                final primarySize = isTight
                    ? math.max(
                        48.0,
                        math.min(56.0, availableWidth - actionSize * 4 - 8.0),
                      )
                    : 64.0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PlayerActionButton(
                      icon: _playbackModeIcon(playerState.playbackMode),
                      active:
                          playerState.playbackMode != PlayerPlaybackMode.list,
                      tooltip: _playbackModeLabel(
                        l10n,
                        playerState.playbackMode,
                      ),
                      onTap: controller.cyclePlaybackMode,
                      size: actionSize,
                    ),
                    _PlayerActionButton(
                      icon: Icons.skip_previous_rounded,
                      tooltip: l10n.previousTrackAction,
                      prominentIcon: true,
                      onTap: playerState.canPlayPrevious
                          ? controller.playPrevious
                          : null,
                      size: actionSize,
                    ),
                    _PrimaryPlayerButton(
                      isBusy: playerState.isBusy,
                      isPlaying: playerState.isPlaying,
                      size: primarySize,
                      onTap: () {
                        if (track == null && playerState.canRetry) {
                          controller.play();
                        } else {
                          controller.togglePlayPause();
                        }
                      },
                    ),
                    _PlayerActionButton(
                      icon: Icons.skip_next_rounded,
                      tooltip: l10n.nextTrackAction,
                      prominentIcon: true,
                      onTap: playerState.canPlayNext
                          ? controller.playNext
                          : null,
                      size: actionSize,
                    ),
                    _PlayerActionButton(
                      icon: Icons.playlist_play_rounded,
                      tooltip: l10n.playlistTitle,
                      onTap: () => _showPlaylistSheet(context),
                      size: actionSize,
                    ),
                  ],
                );
              },
            ),
          ],
        );

        Widget buildPortraitArtwork({double? fixedSize}) {
          final stage = _ArtworkStage(
            showLyrics: _showLyrics,
            tapLyricsLabel: l10n.showLyricsAction,
            title: displayTitle,
            subtitle: displayArtist,
            localCoverPath: displayLocalCoverPath,
            coverUrl: displayCoverUrl,
            trackId: currentSong?.id ?? track?.id ?? '',
            sourceId: currentSong?.sourceId ?? track?.sourceId ?? '',
            directoryPath: directoryPath,
            lyrics: playerState.lyrics,
            lyricsEmptyLabel: l10n.lyricsEmptyLabel,
            scrubPlayTooltip: l10n.playAction,
            onToggleLyrics: () {
              setState(() => _showLyrics = !_showLyrics);
            },
            onSeekToLine: controller.seekAndPlay,
          );
          if (fixedSize != null) {
            return Center(
              child: SizedBox(
                width: fixedSize,
                height: fixedSize,
                child: stage,
              ),
            );
          }
          return Center(child: stage);
        }

        Widget buildWideStage({double? fixedHeight}) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _ArtworkStage(
                      showLyrics: false,
                      tapLyricsLabel: l10n.showLyricsAction,
                      title: displayTitle,
                      subtitle: displayArtist,
                      localCoverPath: displayLocalCoverPath,
                      coverUrl: displayCoverUrl,
                      trackId: currentSong?.id ?? track?.id ?? '',
                      sourceId: currentSong?.sourceId ?? track?.sourceId ?? '',
                      directoryPath: directoryPath,
                      lyrics: playerState.lyrics,
                      lyricsEmptyLabel: l10n.lyricsEmptyLabel,
                      scrubPlayTooltip: l10n.playAction,
                      onToggleLyrics: null,
                      onSeekToLine: controller.seekAndPlay,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: SizedBox(
                  height: fixedHeight,
                  child: RepaintBoundary(
                    child: Consumer(
                      builder: (context, ref, _) => _LyricsPanel(
                        lyrics: playerState.lyrics,
                        activeIndex: ref.watch(
                          playerControllerProvider.select(
                            (state) => state.activeLyricIndex,
                          ),
                        ),
                        emptyLabel: l10n.lyricsEmptyLabel,
                        scrubPlayTooltip: l10n.playAction,
                        onSeekToLine: controller.seekAndPlay,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (!canFillHeight) {
          final cardContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerWidget,
              const SizedBox(height: 12),
              isWide
                  ? SizedBox(
                      height: fallbackArtworkSize,
                      child: buildWideStage(fixedHeight: fallbackArtworkSize),
                    )
                  : buildPortraitArtwork(fixedSize: fallbackArtworkSize),
              const SizedBox(height: 12),
              trackInfoAndErrorWidget,
              bottomControlsWidget,
            ],
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxPanelWidth),
                child: Material(
                  color: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.94,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(panelRadius),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: cardContent,
                  ),
                ),
              ),
            ),
          );
        }

        final Widget cardContent;
        if (isShortOrLargeText) {
          cardContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      headerWidget,
                      const SizedBox(height: 10),
                      isWide
                          ? SizedBox(
                              height: fallbackArtworkSize,
                              child: buildWideStage(
                                fixedHeight: fallbackArtworkSize,
                              ),
                            )
                          : buildPortraitArtwork(
                              fixedSize: math.min(
                                maxPanelWidth - 40,
                                math.max(140.0, availableHeight * 0.32),
                              ),
                            ),
                      const SizedBox(height: 10),
                      trackInfoAndErrorWidget,
                    ],
                  ),
                ),
              ),
              bottomControlsWidget,
            ],
          );
        } else {
          cardContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              headerWidget,
              const SizedBox(height: 12),
              Expanded(
                child: isWide ? buildWideStage() : buildPortraitArtwork(),
              ),
              const SizedBox(height: 12),
              trackInfoAndErrorWidget,
              bottomControlsWidget,
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxPanelWidth,
                minHeight: constraints.maxHeight - 16,
                maxHeight: constraints.maxHeight - 16,
              ),
              child: Material(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(panelRadius),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: cardContent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _directoryPath(String remotePath) {
    final resolved = p.posix.dirname(remotePath);
    return resolved == '.' ? '/' : resolved;
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.title,
    required this.nowPlayingLabel,
    required this.lyricsScrapeTooltip,
    required this.onCollapse,
    required this.onLyricsScrape,
    required this.onMore,
  });

  final String title;
  final String nowPlayingLabel;
  final String lyricsScrapeTooltip;
  final VoidCallback onCollapse;
  final VoidCallback onLyricsScrape;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderCircleButton(
              icon: Icons.expand_more_rounded,
              tooltip: AppLocalizations.of(context)!.closeAction,
              iconColor: colorScheme.onSurfaceVariant,
              onTap: onCollapse,
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: lyricsScrapeTooltip,
              child: _HeaderCircleButton(
                icon: Icons.lyrics_rounded,
                iconColor: colorScheme.onSurfaceVariant,
                onTap: onLyricsScrape,
              ),
            ),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                nowPlayingLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _glacierTextStyle(
                  color: colorScheme.primary,
                  size: 11,
                  weight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _glacierTextStyle(
                  color: colorScheme.onSurface,
                  size: 14,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _HeaderCircleButton(
          icon: Icons.info_outline_rounded,
          tooltip: AppLocalizations.of(context)!.songDetailsTitle,
          iconColor: colorScheme.onSurfaceVariant,
          onTap: onMore,
        ),
      ],
    );
  }
}

class _NowPlayingMetaChip extends StatelessWidget {
  const _NowPlayingMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _glacierTextStyle(
                  color: colorScheme.onSurface,
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkStage extends StatelessWidget {
  const _ArtworkStage({
    required this.showLyrics,
    required this.tapLyricsLabel,
    required this.title,
    required this.subtitle,
    required this.localCoverPath,
    required this.coverUrl,
    required this.trackId,
    required this.sourceId,
    required this.directoryPath,
    required this.lyrics,
    required this.lyricsEmptyLabel,
    required this.scrubPlayTooltip,
    required this.onToggleLyrics,
    required this.onSeekToLine,
  });

  final bool showLyrics;
  final String tapLyricsLabel;
  final String title;
  final String subtitle;
  final String? localCoverPath;
  final String? coverUrl;
  final String trackId;
  final String sourceId;
  final String directoryPath;
  final List<LyricLine> lyrics;
  final String lyricsEmptyLabel;
  final String scrubPlayTooltip;
  final VoidCallback? onToggleLyrics;
  final Future<void> Function(Duration position) onSeekToLine;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final panelRadius = studioRadiusOf(context, 26);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(panelRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggleLyrics,
        child: Semantics(
          button: onToggleLyrics != null,
          label: onToggleLyrics == null
              ? title
              : showLyrics
              ? AppLocalizations.of(context)!.showCoverAction
              : tapLyricsLabel,
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.maxWidth;

                return AnimatedSwitcher(
                  duration: duration,
                  child: showLyrics
                      ? RepaintBoundary(
                          key: const ValueKey('lyrics'),
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh
                                  .withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(panelRadius),
                              border: Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                            ),
                            child: Consumer(
                              builder: (context, ref, _) {
                                final activeIndex = ref.watch(
                                  playerControllerProvider.select(
                                    (state) => state.activeLyricIndex,
                                  ),
                                );
                                return _LyricsPanel(
                                  lyrics: lyrics,
                                  activeIndex: activeIndex,
                                  emptyLabel: lyricsEmptyLabel,
                                  scrubPlayTooltip: scrubPlayTooltip,
                                  onSeekToLine: onSeekToLine,
                                );
                              },
                            ),
                          ),
                        )
                      : RepaintBoundary(
                          key: const ValueKey('cover'),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              TrackCoverThumbnail(
                                title: title,
                                subtitle: subtitle,
                                size: size,
                                borderRadius: 26,
                                localCoverPath: localCoverPath,
                                coverUrl: coverUrl,
                                trackId: trackId,
                                sourceId: sourceId,
                                directoryPath: directoryPath,
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    panelRadius,
                                  ),
                                  border: Border.all(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                              if (onToggleLyrics != null)
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      16,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface.withValues(
                                          alpha: 0.72,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: colorScheme.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lyrics_rounded,
                                            color: colorScheme.primary,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              tapLyricsLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: _glacierTextStyle(
                                                color: colorScheme.onSurface,
                                                size: 12,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNowPlayingState extends StatelessWidget {
  const _EmptyNowPlayingState({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final panelRadius = studioRadiusOf(context, 32);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(panelRadius),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GeneratedCoverArt(
                    title: title,
                    subtitle: description,
                    size: 220,
                    borderRadius: 28,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: _glacierTextStyle(
                      color: colorScheme.onSurface,
                      size: 24,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: _glacierTextStyle(
                      color: colorScheme.onSurfaceVariant,
                      size: 14,
                      weight: FontWeight.w500,
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

void _showPlaylistSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.68;
      final sheetColorScheme = Theme.of(sheetContext).colorScheme;

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: sheetColorScheme.surfaceContainerHigh.withValues(
              alpha: 0.96,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: sheetColorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Consumer(
                builder: (context, sheetRef, _) {
                  final l10n = AppLocalizations.of(context)!;
                  final itemColorScheme = Theme.of(context).colorScheme;
                  final playlist = sheetRef.watch(
                    playerControllerProvider.select((s) => s.playlist),
                  );
                  final currentIndex = sheetRef.watch(
                    playerControllerProvider.select((s) => s.currentIndex),
                  );
                  final controller = sheetRef.read(
                    playerControllerProvider.notifier,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.playlistTitle.toUpperCase(),
                                  style: _glacierTextStyle(
                                    color: itemColorScheme.primary,
                                    size: 11,
                                    weight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.playlistTitle,
                                  style: _glacierTextStyle(
                                    color: itemColorScheme.onSurface,
                                    size: 24,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HeaderCircleButton(
                            icon: Icons.close_rounded,
                            iconColor: itemColorScheme.onSurfaceVariant,
                            onTap: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.playlistCountLabel(playlist.length),
                        style: _glacierTextStyle(
                          color: itemColorScheme.onSurfaceVariant,
                          size: 13,
                          weight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (playlist.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              l10n.playlistEmptyTitle,
                              textAlign: TextAlign.center,
                              style: _glacierTextStyle(
                                color: itemColorScheme.onSurfaceVariant,
                                size: 14,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: playlist.length,
                            proxyDecorator: (child, _, _) => Material(
                              color: Colors.transparent,
                              child: child,
                            ),
                            onReorder: (oldIndex, newIndex) {
                              controller.reorderPlaylist(oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final song = playlist[index];
                              final isCurrent = index == currentIndex;

                              return Padding(
                                key: ValueKey('${song.id}__$index'),
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PlaylistRow(
                                  song: song,
                                  isCurrent: isCurrent,
                                  currentLabel: l10n.currentTrackLabel,
                                  removeTooltip: l10n.removeFromPlaylistAction,
                                  onTap: () =>
                                      controller.playPlaylistIndex(index),
                                  onRemove: () =>
                                      controller.removePlaylistItemAt(index),
                                  dragHandle:
                                      ReorderableDelayedDragStartListener(
                                        index: index,
                                        child: _HeaderCircleButton(
                                          icon: Icons.drag_handle_rounded,
                                          iconColor:
                                              itemColorScheme.onSurfaceVariant,
                                          compact: true,
                                          onTap: () {},
                                        ),
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showTrackDetailsSheet(
  BuildContext context, {
  required String title,
  required String artist,
  required String album,
  required String sourceName,
  required String path,
}) {
  final l10n = AppLocalizations.of(context)!;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final radius = studioRadiusOf(sheetContext, 28);
      final sheetColorScheme = Theme.of(sheetContext).colorScheme;

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: sheetColorScheme.surfaceContainerHigh.withValues(
              alpha: 0.96,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(
                color: sheetColorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: _glacierTextStyle(
                      color: sheetColorScheme.onSurface,
                      size: 22,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _NowPlayingDetailRow(label: l10n.artistLabel, value: artist),
                  _NowPlayingDetailRow(label: l10n.albumLabel, value: album),
                  _NowPlayingDetailRow(
                    label: l10n.sourceLabel,
                    value: sourceName,
                  ),
                  _NowPlayingDetailRow(label: l10n.filePathLabel, value: path),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _NowPlayingDetailRow extends StatelessWidget {
  const _NowPlayingDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _glacierTextStyle(
              color: colorScheme.onSurfaceVariant,
              size: 12,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: _glacierTextStyle(
              color: colorScheme.onSurface,
              size: 14,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.song,
    required this.isCurrent,
    required this.currentLabel,
    required this.removeTooltip,
    required this.onTap,
    required this.onRemove,
    required this.dragHandle,
  });

  final LibrarySong song;
  final bool isCurrent;
  final String currentLabel;
  final String removeTooltip;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: isCurrent
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCurrent
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outline.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              TrackCoverThumbnail(
                title: song.displayTitle,
                subtitle: '${song.displayArtist} · ${song.displayAlbum}',
                size: 38,
                borderRadius: 12,
                localCoverPath: song.displayLocalCoverPath,
                coverUrl: song.displayCoverUrl,
                isCurrentTrack: isCurrent,
                trackId: song.id,
                sourceId: song.sourceId,
                directoryPath: song.directoryPath,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: colorScheme.onSurface,
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isCurrent
                          ? currentLabel
                          : '${song.displayArtist} · ${song.displayAlbum}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: isCurrent
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 10.5,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              dragHandle,
              const SizedBox(width: 2),
              Tooltip(
                message: removeTooltip,
                child: _HeaderCircleButton(
                  icon: Icons.delete_outline_rounded,
                  iconColor: colorScheme.onSurfaceVariant,
                  onTap: onRemove,
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCircleButton extends StatelessWidget {
  const _HeaderCircleButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.filled = false,
    this.compact = false,
    this.tooltip,
  });

  final String? tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool filled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = 48.0;
    final colorScheme = Theme.of(context).colorScheme;

    final button = Material(
      color: filled
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
    return tooltip == null
        ? button
        : Tooltip(
            message: tooltip!,
            child: Semantics(button: true, label: tooltip, child: button),
          );
  }
}

class _PlayerActionButton extends StatelessWidget {
  const _PlayerActionButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.prominentIcon = false,
    this.tooltip,
    this.size,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool prominentIcon;
  final String? tooltip;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final buttonRadius = studioRadiusOf(context, 20);
    final buttonSize = (size ?? studioListSpacingOf(context, 56)).clamp(
      48.0,
      64.0,
    );
    final iconSize = size != null
        ? (prominentIcon
              ? (32.0 * (buttonSize / 56.0)).clamp(24.0, 36.0)
              : (22.0 * (buttonSize / 56.0)).clamp(18.0, 26.0))
        : (prominentIcon
              ? studioListSpacingOf(context, 32).clamp(26.0, 36.0)
              : studioListSpacingOf(context, 22).clamp(18.0, 26.0));

    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(buttonRadius),
        onTap: onTap,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: Icon(
            icon,
            size: iconSize,
            color: !enabled
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.34)
                : active
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

class _PrimaryPlayerButton extends StatelessWidget {
  const _PrimaryPlayerButton({
    required this.isBusy,
    required this.isPlaying,
    required this.onTap,
    this.size = 64.0,
  });

  final bool isBusy;
  final bool isPlaying;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final indicatorSize = (size <= 52.0 ? 22.0 : 26.0);
    final iconSize = (size * (36.0 / 64.0)).clamp(26.0, 36.0);
    return Tooltip(
      message: isPlaying ? l10n.pauseAction : l10n.playAction,
      child: Semantics(
        button: true,
        label: isPlaying ? l10n.pauseAction : l10n.playAction,
        child: Material(
          color: colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.13),
                    blurRadius: 22,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: isBusy
                    ? SizedBox(
                        width: indicatorSize,
                        height: indicatorSize,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: colorScheme.primary,
                        size: iconSize,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingTimelineDeck extends ConsumerStatefulWidget {
  const _NowPlayingTimelineDeck();

  @override
  ConsumerState<_NowPlayingTimelineDeck> createState() =>
      _NowPlayingTimelineDeckState();
}

class _NowPlayingTimelineDeckState
    extends ConsumerState<_NowPlayingTimelineDeck> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = ref.watch(
      playerControllerProvider.select(
        (state) => (
          position: state.position,
          duration: state.duration,
          cacheSegments: state.cacheSegments,
        ),
      ),
    );
    final controller = ref.read(playerControllerProvider.notifier);

    final duration = progress.duration;
    final maxPosition = math.max(
      1.0,
      (duration ?? Duration.zero).inMilliseconds.toDouble(),
    );
    final positionValue =
        (_dragValue ?? progress.position.inMilliseconds.toDouble()).clamp(
          0.0,
          maxPosition,
        );
    final remaining = (duration ?? Duration.zero) - progress.position;
    final isSeekEnabled = duration != null && duration > Duration.zero;
    final elapsedLabel = _formatDuration(
      Duration(milliseconds: positionValue.round()),
    );
    final remainingLabel =
        '-${_formatDuration(remaining.isNegative ? Duration.zero : remaining)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Seekbar(
          value: positionValue,
          max: maxPosition,
          cacheSegments: progress.cacheSegments,
          enabled: isSeekEnabled,
          onChanged: (value) {
            setState(() => _dragValue = value);
          },
          onChangeEnd: (value) async {
            setState(() => _dragValue = null);
            await controller.seek(Duration(milliseconds: value.round()));
          },
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 5,
              child: Tooltip(
                message: elapsedLabel,
                child: Text(
                  elapsedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _glacierTextStyle(
                    color: colorScheme.onSurfaceVariant,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              flex: 6,
              child: Tooltip(
                message: remainingLabel,
                child: Text(
                  remainingLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: _glacierTextStyle(
                    color: colorScheme.onSurfaceVariant,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Seekbar extends StatefulWidget {
  const _Seekbar({
    required this.value,
    required this.max,
    required this.cacheSegments,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double value;
  final double max;
  final List<CacheProgressSegment> cacheSegments;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_Seekbar> createState() => _SeekbarState();
}

class _SeekbarState extends State<_Seekbar> {
  double? _lastInteractionValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedMax = widget.max <= 0 ? 1.0 : widget.max;
    final progress = (widget.value / normalizedMax).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        double valueFromDx(double dx) {
          final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
          final fraction = (dx / width).clamp(0.0, 1.0);
          return fraction * normalizedMax;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (details) {
                  final value = valueFromDx(details.localPosition.dx);
                  _lastInteractionValue = value;
                  widget.onChanged(value);
                  widget.onChangeEnd(value);
                }
              : null,
          onHorizontalDragStart: widget.enabled
              ? (details) {
                  final value = valueFromDx(details.localPosition.dx);
                  _lastInteractionValue = value;
                  widget.onChanged(value);
                }
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (details) {
                  final value = valueFromDx(details.localPosition.dx);
                  _lastInteractionValue = value;
                  widget.onChanged(value);
                }
              : null,
          onHorizontalDragEnd: widget.enabled
              ? (_) {
                  final value = _lastInteractionValue;
                  if (value != null) {
                    widget.onChangeEnd(value);
                  }
                  _lastInteractionValue = null;
                }
              : null,
          child: RepaintBoundary(
            child: PlaybackTimeline(
              progress: progress,
              cacheSegments: widget.cacheSegments,
              showThumb: true,
              thumbFraction: progress,
              height: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              cacheColor: colorScheme.outline.withValues(alpha: 0.32),
              progressColor: colorScheme.primary,
              thumbColor: colorScheme.primary,
            ),
          ),
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final textDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final opacityDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return widget.lyrics.isEmpty
        ? Center(
            child: Text(
              widget.emptyLabel,
              textAlign: TextAlign.center,
              style: _glacierTextStyle(
                color: colorScheme.onSurfaceVariant,
                size: 14,
                weight: FontWeight.w500,
              ),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final isActive = index == widget.activeIndex;
                    final line = widget.lyrics[index];

                    return KeyedSubtree(
                      key: _lineKeys[index],
                      child: AnimatedDefaultTextStyle(
                        duration: textDuration,
                        style: _glacierTextStyle(
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          size: isActive ? 23 : 17,
                          weight: isActive ? FontWeight.w800 : FontWeight.w500,
                          height: isActive ? 1.24 : 1.38,
                        ),
                        child: AnimatedScale(
                          duration: textDuration,
                          scale: isActive ? 1.03 : 1,
                          child: Text(line.text, textAlign: TextAlign.center),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_isUserScrolling)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      _resumeAutoScrollTimer?.cancel();
                      setState(() {
                        _isUserScrolling = false;
                        _showScrubber = false;
                      });
                      _scheduleScrollToActive(force: true);
                    },
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(
                      AppLocalizations.of(context)!.resumeLyricsFollow,
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_showScrubber,
                  child: AnimatedOpacity(
                    duration: opacityDuration,
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
                                style: _glacierTextStyle(
                                  color: colorScheme.primary,
                                  size: 12,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: colorScheme.primary.withValues(
                                  alpha: 0.42,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: widget.scrubPlayTooltip,
                                visualDensity: VisualDensity.compact,
                                onPressed: _handleScrubberPlay,
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  color: colorScheme.primary,
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
        final disableAnimations = MediaQuery.disableAnimationsOf(context);
        if (disableAnimations) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scheduleScrollToActive(
                force: force,
                animated: animated,
                remainingAttempts: remainingAttempts - 1,
              );
            }
          });
        } else {
          Future<void>.delayed(const Duration(milliseconds: 60), () {
            _scheduleScrollToActive(
              force: force,
              animated: animated,
              remainingAttempts: remainingAttempts - 1,
            );
          });
        }
      }
      return;
    }

    if (!force && targetIndex == _lastAutoScrolledIndex) {
      return;
    }

    final targetContext = _lineKeys[targetIndex].currentContext;
    final renderObj = targetContext?.findRenderObject();
    if (targetContext == null || renderObj == null || !renderObj.attached) {
      _primeScrollNearIndex(targetIndex, animated: animated);
      if (remainingAttempts > 0) {
        final disableAnimations = MediaQuery.disableAnimationsOf(context);
        if (disableAnimations) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scheduleScrollToActive(
                force: force,
                animated: animated,
                remainingAttempts: remainingAttempts - 1,
              );
            }
          });
        } else {
          Future<void>.delayed(const Duration(milliseconds: 60), () {
            _scheduleScrollToActive(
              force: force,
              animated: animated,
              remainingAttempts: remainingAttempts - 1,
            );
          });
        }
      }
      return;
    }

    _lastAutoScrolledIndex = targetIndex;
    _isAutoScrolling = true;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    try {
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.5,
        duration: (animated && !disableAnimations)
            ? const Duration(milliseconds: 320)
            : Duration.zero,
        curve: Curves.easeOutCubic,
      );
    } finally {
      if (mounted) {
        if (disableAnimations) {
          _isAutoScrolling = false;
        } else {
          Future<void>.delayed(const Duration(milliseconds: 80), () {
            if (mounted) {
              _isAutoScrolling = false;
            }
          });
        }
      } else {
        _isAutoScrolling = false;
      }
    }
  }

  void _primeScrollNearIndex(int targetIndex, {required bool animated}) {
    if (!_scrollController.hasClients || widget.lyrics.length <= 1) {
      return;
    }
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (!maxExtent.isFinite || maxExtent <= 0) {
      return;
    }
    final ratio = targetIndex / (widget.lyrics.length - 1);
    final targetOffset = (maxExtent * ratio).clamp(0.0, maxExtent);
    final currentOffset = _scrollController.offset;
    if ((currentOffset - targetOffset).abs() < 24) {
      return;
    }
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (animated && !disableAnimations) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }
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

TextStyle _glacierTextStyle({
  required Color color,
  required double size,
  required FontWeight weight,
  double height = 1.2,
  double letterSpacing = 0,
}) {
  return GoogleFonts.inter(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
  );
}
