import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/library_album.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/generated_cover_art.dart';
import '../application/library_catalog_controller.dart';
import '../application/library_controller.dart';

class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key});

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  String? _selectedSourceId;
  final Map<String, LibraryAlbumGroupingMode> _groupingBySourceId = {};

  @override
  Widget build(BuildContext context) {
    final browserAsync = ref.watch(libraryControllerProvider);
    final catalogAsync = ref.watch(libraryCatalogControllerProvider);

    return browserAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _AlbumsFeedback(message: error.toString()),
      data: (browser) {
        if (!browser.hasSources) {
          final l10n = AppLocalizations.of(context)!;
          return _AlbumsEmptyState(
            title: l10n.libraryEmptyTitle,
            description: l10n.libraryEmptyDescription,
            actionLabel: l10n.addSourceAction,
            onPressed: () => context.push('/settings/add-source'),
          );
        }

        final selectedSource = _resolveSelectedSource(browser.sources, browser);
        final groupingMode =
            _groupingBySourceId[selectedSource.id] ??
            LibraryAlbumGroupingMode.folder;

        return catalogAsync.when(
          loading: () => _AlbumsContent(
            sources: browser.sources,
            selectedSource: selectedSource,
            groupingMode: groupingMode,
            onSourceSelected: (sourceId) {
              setState(() => _selectedSourceId = sourceId);
            },
            onGroupingChanged: (value) {
              setState(() => _groupingBySourceId[selectedSource.id] = value);
            },
          ),
          error: (error, _) => _AlbumsFeedback(message: error.toString()),
          data: (catalog) {
            final albums = catalog.albumsForSource(
              selectedSource.id,
              groupingMode,
            );
            final sourceTracks = catalog.tracks
                .where((track) => track.sourceId == selectedSource.id)
                .length;

            return _AlbumsContent(
              sources: browser.sources,
              selectedSource: selectedSource,
              groupingMode: groupingMode,
              catalog: catalog,
              albums: albums,
              sourceTracks: sourceTracks,
              onSourceSelected: (sourceId) {
                setState(() => _selectedSourceId = sourceId);
              },
              onGroupingChanged: (value) {
                setState(() => _groupingBySourceId[selectedSource.id] = value);
              },
            );
          },
        );
      },
    );
  }

  SourceProfile _resolveSelectedSource(
    List<SourceProfile> sources,
    LibraryViewState browser,
  ) {
    for (final source in sources) {
      if (source.id == _selectedSourceId) {
        return source;
      }
    }

    return browser.selectedSource ?? sources.first;
  }
}

class _AlbumsContent extends ConsumerWidget {
  const _AlbumsContent({
    required this.sources,
    required this.selectedSource,
    required this.groupingMode,
    this.catalog,
    this.albums = const [],
    this.sourceTracks = 0,
    this.onSourceSelected,
    this.onGroupingChanged,
  });

  final List<SourceProfile> sources;
  final SourceProfile selectedSource;
  final LibraryAlbumGroupingMode groupingMode;
  final LibraryCatalogState? catalog;
  final List<LibraryAlbum> albums;
  final int sourceTracks;
  final ValueChanged<String>? onSourceSelected;
  final ValueChanged<LibraryAlbumGroupingMode>? onGroupingChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: () {
        if (catalog == null) {
          return ref
              .read(libraryCatalogControllerProvider.notifier)
              .scanAllSources();
        }
        return ref
            .read(libraryCatalogControllerProvider.notifier)
            .rescanSource(selectedSource.id);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _AlbumsHeaderCard(
              sources: sources,
              selectedSource: selectedSource,
              groupingMode: groupingMode,
              catalog: catalog,
              onSourceSelected: onSourceSelected,
              onGroupingChanged: onGroupingChanged,
              onScanPressed: () {
                if (catalog == null ||
                    catalog!.scannedSources
                        .where((source) => source.id == selectedSource.id)
                        .isEmpty) {
                  ref
                      .read(libraryCatalogControllerProvider.notifier)
                      .scanAllSources();
                } else {
                  ref
                      .read(libraryCatalogControllerProvider.notifier)
                      .rescanSource(selectedSource.id);
                }
              },
            ),
          ),
          const StudioSliverGap(height: 16),
          if (catalog != null && catalog!.isScanning)
            SliverToBoxAdapter(
              child: Padding(
                padding: studioPaddingOf(
                  context,
                  const EdgeInsets.only(bottom: 16),
                ),
                child: const LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ),
            ),
          if (albums.isEmpty)
            SliverToBoxAdapter(
              child: _AlbumsEmptyState(
                title: l10n.albumsEmptyTitle,
                description: l10n.albumsEmptyDescription,
                actionLabel: l10n.scanLibraryAction,
                onPressed: () {
                  ref
                      .read(libraryCatalogControllerProvider.notifier)
                      .scanAllSources();
                },
              ),
            )
          else
            SliverPadding(
              padding: studioPaddingOf(
                context,
                const EdgeInsets.only(bottom: 20),
              ),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.crossAxisExtent >= 1320
                      ? 5
                      : constraints.crossAxisExtent >= 900
                      ? 4
                      : constraints.crossAxisExtent >= 320
                      ? 3
                      : 2;

                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final album = albums[index];
                      return _AlbumCard(
                        album: album,
                        onTap: () => _openAlbumSheet(context, ref, album),
                      );
                    }, childCount: albums.length),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: studioSpacingOf(context, 12),
                      crossAxisSpacing: studioSpacingOf(context, 12),
                      childAspectRatio: 0.62,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openAlbumSheet(
    BuildContext context,
    WidgetRef ref,
    LibraryAlbum album,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.58;

        return SafeArea(
          top: false,
          child: Padding(
            padding: studioPaddingOf(
              sheetContext,
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: Consumer(
                builder: (context, sheetRef, _) {
                  final l10n = AppLocalizations.of(context)!;
                  final catalogState = sheetRef
                      .watch(libraryCatalogControllerProvider)
                      .valueOrNull;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StudioPanel(
                        padding: const EdgeInsets.all(12),
                        radius: 22,
                        tint: colorScheme.primaryContainer,
                        child: Row(
                          children: [
                            GeneratedCoverArt(
                              title: album.title,
                              subtitle: album.artistName,
                              size: 64,
                              borderRadius: 18,
                            ),
                            const StudioGap(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    album.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const StudioGap(height: 4),
                                  Text(
                                    album.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const StudioGap(height: 8),
                                  StudioPill(
                                    icon: Icons.music_note_rounded,
                                    label:
                                        '${album.trackCount} ${l10n.tracksLabel}',
                                    prominent: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const StudioGap(height: 12),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: album.tracks.length,
                          separatorBuilder: (_, _) =>
                              const StudioGap(height: 8),
                          itemBuilder: (context, index) {
                            final track = album.tracks[index];
                            final isFavorite =
                                catalogState?.favoriteTrackIds.contains(
                                  track.id,
                                ) ??
                                false;
                            final isLiked =
                                catalogState?.likedTrackIds.contains(
                                  track.id,
                                ) ??
                                false;

                            return _AlbumTrackRow(
                              track: track,
                              isFavorite: isFavorite,
                              isLiked: isLiked,
                              onFavorite: () {
                                sheetRef
                                    .read(
                                      libraryCatalogControllerProvider.notifier,
                                    )
                                    .toggleFavorite(track.id);
                              },
                              onLiked: () {
                                sheetRef
                                    .read(
                                      libraryCatalogControllerProvider.notifier,
                                    )
                                    .toggleLiked(track.id);
                              },
                              onTap: () {
                                sheetRef
                                    .read(playerControllerProvider.notifier)
                                    .playLibrarySong(
                                      track,
                                      playlist: album.tracks,
                                    );
                                Navigator.of(sheetContext).pop();
                              },
                              onPlayNext: () {
                                _addAlbumTrackToPlayNext(
                                  sheetContext,
                                  sheetRef,
                                  track,
                                );
                              },
                              onMoreOptions: () {
                                _showAlbumTrackActionsSheet(
                                  sheetContext,
                                  sheetRef,
                                  track: track,
                                  isFavorite: isFavorite,
                                  isLiked: isLiked,
                                  playlist: album.tracks,
                                );
                              },
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
        );
      },
    );
  }
}

class _AlbumTrackRow extends StatelessWidget {
  const _AlbumTrackRow({
    required this.track,
    required this.isFavorite,
    required this.isLiked,
    required this.onFavorite,
    required this.onLiked,
    required this.onTap,
    required this.onPlayNext,
    required this.onMoreOptions,
  });

  final LibrarySong track;
  final bool isFavorite;
  final bool isLiked;
  final VoidCallback onFavorite;
  final VoidCallback onLiked;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;
  final VoidCallback onMoreOptions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = studioRadiusOf(context, 18);
    final leadingSize = studioSpacingOf(
      context,
      36,
    ).clamp(30.0, 44.0).toDouble();

    return StudioPanel(
      padding: EdgeInsets.zero,
      radius: 18,
      tint: colorScheme.surfaceContainerLow,
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          onLongPress: onPlayNext,
          child: Padding(
            padding: studioPaddingOf(
              context,
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
            child: Row(
              children: [
                Container(
                  width: leadingSize,
                  height: leadingSize,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
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
                        style: theme.textTheme.titleSmall,
                      ),
                      const StudioGap(height: 2),
                      Text(
                        track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _CompactTrackButton(
                  tooltip: l10n.favoritesCollectionTitle,
                  onPressed: onFavorite,
                  icon: isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                _CompactTrackButton(
                  tooltip: l10n.likedCollectionTitle,
                  onPressed: onLiked,
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                _CompactTrackButton(
                  tooltip: l10n.playAction,
                  onPressed: onTap,
                  icon: Icons.play_arrow_rounded,
                ),
                _CompactTrackButton(
                  tooltip: l10n.moreOptionsAction,
                  onPressed: onMoreOptions,
                  icon: Icons.more_horiz_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactTrackButton extends StatelessWidget {
  const _CompactTrackButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      padding: studioPaddingOf(context, const EdgeInsets.all(4)),
      constraints: BoxConstraints(
        minWidth: studioSpacingOf(context, 32).clamp(28.0, 40.0).toDouble(),
        minHeight: studioSpacingOf(context, 32).clamp(28.0, 40.0).toDouble(),
      ),
    );
  }
}

void _showAlbumTrackActionsSheet(
  BuildContext albumSheetContext,
  WidgetRef ref, {
  required LibrarySong track,
  required bool isFavorite,
  required bool isLiked,
  required List<LibrarySong> playlist,
}) {
  showModalBottomSheet<void>(
    context: albumSheetContext,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final colorScheme = Theme.of(context).colorScheme;

      return SafeArea(
        top: false,
        child: Padding(
          padding: studioPaddingOf(
            context,
            const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioPanel(
                padding: const EdgeInsets.all(16),
                radius: 22,
                tint: colorScheme.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const StudioGap(height: 6),
                    Text(
                      '${track.artistName} · ${track.albumTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const StudioGap(height: 12),
              StudioPanel(
                padding: const EdgeInsets.all(14),
                radius: 22,
                tint: colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(playerControllerProvider.notifier)
                            .playLibrarySong(track, playlist: playlist);
                        Navigator.of(context).pop();
                        if (albumSheetContext.mounted) {
                          Navigator.of(albumSheetContext).pop();
                        }
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(l10n.playAction),
                    ),
                    const StudioGap(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _addAlbumTrackToPlayNext(albumSheetContext, ref, track);
                      },
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: Text(l10n.playNextAction),
                    ),
                    const StudioGap(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(
                                    libraryCatalogControllerProvider.notifier,
                                  )
                                  .toggleFavorite(track.id);
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              isFavorite
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                            ),
                            label: Text(l10n.favoritesCollectionTitle),
                          ),
                        ),
                        const StudioGap(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(
                                    libraryCatalogControllerProvider.notifier,
                                  )
                                  .toggleLiked(track.id);
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                            ),
                            label: Text(l10n.likedCollectionTitle),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _addAlbumTrackToPlayNext(
  BuildContext context,
  WidgetRef ref,
  LibrarySong track,
) async {
  final l10n = AppLocalizations.of(context)!;

  try {
    await ref.read(playerControllerProvider.notifier).addToPlayNext(track);
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
    return;
  }

  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.addedToPlayNextMessage(track.title))),
  );
}

class _AlbumsHeaderCard extends StatelessWidget {
  const _AlbumsHeaderCard({
    required this.sources,
    required this.selectedSource,
    required this.groupingMode,
    required this.catalog,
    required this.onSourceSelected,
    required this.onGroupingChanged,
    required this.onScanPressed,
  });

  final List<SourceProfile> sources;
  final SourceProfile selectedSource;
  final LibraryAlbumGroupingMode groupingMode;
  final LibraryCatalogState? catalog;
  final ValueChanged<String>? onSourceSelected;
  final ValueChanged<LibraryAlbumGroupingMode>? onGroupingChanged;
  final VoidCallback onScanPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return StudioPanel(
      radius: 24,
      tint: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.albumsTabLabel,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: catalog?.isScanning == true
                    ? l10n.scanningAction
                    : l10n.scanLibraryAction,
                onPressed: onScanPressed,
                icon: Icon(
                  catalog?.isScanning == true
                      ? Icons.sync_rounded
                      : Icons.radar_rounded,
                ),
              ),
            ],
          ),
          const StudioGap(height: 12),
          SizedBox(
            height: studioSpacingOf(context, 72).clamp(58.0, 88.0).toDouble(),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sources.length,
              separatorBuilder: (_, _) => const StudioGap(width: 10),
              itemBuilder: (context, index) {
                final source = sources[index];
                final isSelected = source.id == selectedSource.id;
                final albumCount =
                    catalog?.albumCountForSource(source.id, groupingMode) ?? 0;

                return _SourceCard(
                  source: source,
                  albumCount: albumCount,
                  isSelected: isSelected,
                  onTap: onSourceSelected == null
                      ? null
                      : () => onSourceSelected!(source.id),
                );
              },
            ),
          ),
          const StudioGap(height: 12),
          SegmentedButton<LibraryAlbumGroupingMode>(
            segments: [
              ButtonSegment(
                value: LibraryAlbumGroupingMode.folder,
                label: Text(l10n.folderAlbumsModeLabel),
                icon: const Icon(Icons.folder_copy_rounded),
              ),
              ButtonSegment(
                value: LibraryAlbumGroupingMode.scraped,
                label: Text(l10n.scrapedAlbumsModeLabel),
                icon: const Icon(Icons.auto_awesome_rounded),
              ),
            ],
            selected: {groupingMode},
            onSelectionChanged: onGroupingChanged == null
                ? null
                : (selection) => onGroupingChanged!(selection.first),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.albumCount,
    required this.isSelected,
    this.onTap,
  });

  final SourceProfile source;
  final int albumCount;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = studioRadiusOf(context, 22);

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: SizedBox(
          width: studioSpacingOf(context, 168).clamp(136.0, 204.0).toDouble(),
          child: Padding(
            padding: studioPaddingOf(context, const EdgeInsets.all(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '$albumCount ${AppLocalizations.of(context)!.albumsTabLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.78)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final LibraryAlbum album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = studioRadiusOf(context, 20);

    return StudioPanel(
      padding: EdgeInsets.zero,
      radius: 20,
      tint: colorScheme.surfaceContainerLow,
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: studioPaddingOf(context, const EdgeInsets.all(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final artSize = constraints.maxWidth;

                    return Stack(
                      children: [
                        GeneratedCoverArt(
                          title: album.title,
                          subtitle: album.artistName,
                          size: artSize,
                          borderRadius: 16,
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              onPressed: onTap,
                              iconSize: 18,
                              padding: studioPaddingOf(
                                context,
                                const EdgeInsets.all(8),
                              ),
                              constraints: BoxConstraints(
                                minWidth: studioSpacingOf(
                                  context,
                                  32,
                                ).clamp(28.0, 40.0).toDouble(),
                                minHeight: studioSpacingOf(
                                  context,
                                  32,
                                ).clamp(28.0, 40.0).toDouble(),
                              ),
                              icon: Icon(
                                Icons.play_arrow_rounded,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const StudioGap(height: 8),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const StudioGap(height: 2),
                Text(
                  album.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${album.trackCount} ${AppLocalizations.of(context)!.tracksLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlbumsFeedback extends StatelessWidget {
  const _AlbumsFeedback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: StudioPanel(
        radius: 28,
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _AlbumsEmptyState extends StatelessWidget {
  const _AlbumsEmptyState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: StudioPanel(
          radius: 28,
          tint: colorScheme.surfaceContainerLow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GeneratedCoverArt(
                title: title,
                subtitle: description,
                size: studioSpacingOf(
                  context,
                  180,
                ).clamp(132.0, 220.0).toDouble(),
                borderRadius: 26,
              ),
              const StudioGap(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const StudioGap(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const StudioGap(height: 20),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add_link_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
