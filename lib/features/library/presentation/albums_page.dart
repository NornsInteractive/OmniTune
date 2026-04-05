import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/library_album.dart';
import '../../../core/models/source_profile.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final browserAsync = ref.watch(libraryControllerProvider);
    final catalogAsync = ref.watch(libraryCatalogControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: browserAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (browser) {
            if (!browser.hasSources) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: _AlbumsEmptyCard(
                  title: l10n.libraryEmptyTitle,
                  description: l10n.libraryEmptyDescription,
                  actionLabel: l10n.addSourceAction,
                  onPressed: () => context.push('/settings/add-source'),
                ),
              );
            }

            final sources = browser.sources;
            final selectedSource = _resolveSelectedSource(sources, browser);
            final groupingMode =
                _groupingBySourceId[selectedSource.id] ??
                LibraryAlbumGroupingMode.folder;

            return catalogAsync.when(
              loading: () => _AlbumsScaffold(
                sources: sources,
                selectedSource: selectedSource,
                groupingMode: groupingMode,
              ),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (catalog) {
                final albums = catalog.albumsForSource(
                  selectedSource.id,
                  groupingMode,
                );
                final sourceTracks = catalog.tracks
                    .where((track) => track.sourceId == selectedSource.id)
                    .length;

                return _AlbumsScaffold(
                  sources: sources,
                  selectedSource: selectedSource,
                  groupingMode: groupingMode,
                  catalog: catalog,
                  albums: albums,
                  sourceTracks: sourceTracks,
                  onSourceSelected: (sourceId) {
                    setState(() {
                      _selectedSourceId = sourceId;
                    });
                  },
                  onGroupingChanged: (value) {
                    setState(() {
                      _groupingBySourceId[selectedSource.id] = value;
                    });
                  },
                );
              },
            );
          },
        ),
      ),
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
    if (browser.selectedSource != null) {
      return browser.selectedSource!;
    }
    return sources.first;
  }
}

class _AlbumsScaffold extends ConsumerWidget {
  const _AlbumsScaffold({
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.surfaceContainerHighest,
                    colorScheme.secondaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.albumsHeadline,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.albumsDescriptionWithSource(selectedSource.name),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sources.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final source = sources[index];
                        final isSelected = source.id == selectedSource.id;
                        final albumCount =
                            catalog?.albumCountForSource(
                              source.id,
                              _groupingModeFor(source.id),
                            ) ??
                            0;

                        return _SourceFilterChip(
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
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          final controller = ref.read(
                            libraryCatalogControllerProvider.notifier,
                          );
                          if (catalog == null ||
                              catalog!.scannedSources
                                  .where(
                                    (source) => source.id == selectedSource.id,
                                  )
                                  .isEmpty) {
                            controller.scanAllSources();
                          } else {
                            controller.rescanSource(selectedSource.id);
                          }
                        },
                        icon: Icon(
                          catalog?.isScanning == true
                              ? Icons.sync_rounded
                              : Icons.radar_rounded,
                        ),
                        label: Text(
                          catalog?.isScanning == true
                              ? l10n.scanningAction
                              : l10n.scanLibraryAction,
                        ),
                      ),
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
                            : (selection) =>
                                  onGroupingChanged!(selection.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _AlbumMetaPill(
                        icon: Icons.album_rounded,
                        label: '${albums.length} ${l10n.albumsTabLabel}',
                      ),
                      _AlbumMetaPill(
                        icon: Icons.music_note_rounded,
                        label: '$sourceTracks ${l10n.allSongsCollectionTitle}',
                      ),
                    ],
                  ),
                  if (catalog?.isScanning == true) ...[
                    const SizedBox(height: 22),
                    LinearProgressIndicator(
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.scanningProgress(
                        catalog!.scannedDirectoryCount,
                        catalog!.discoveredTrackCount,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if ((catalog!.lastScanSourceName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.currentScanSourceLabel(
                          catalog!.lastScanSourceName!,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (albums.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: _AlbumsEmptyCard(
                title: l10n.albumsEmptyTitle,
                description: l10n.albumsEmptyDescription,
                actionLabel: l10n.scanLibraryAction,
                onPressed: () {
                  ref
                      .read(libraryCatalogControllerProvider.notifier)
                      .scanAllSources();
                },
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final album = albums[index];
                return _AlbumCard(
                  album: album,
                  onTap: () => _openAlbumSheet(context, ref, album),
                );
              }, childCount: albums.length),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent: 280,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
            ),
          ),
      ],
    );
  }

  LibraryAlbumGroupingMode _groupingModeFor(String sourceId) {
    if (sourceId == selectedSource.id) {
      return groupingMode;
    }
    return LibraryAlbumGroupingMode.folder;
  }

  Future<void> _openAlbumSheet(
    BuildContext context,
    WidgetRef ref,
    LibraryAlbum album,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final catalogState = ref.read(libraryCatalogControllerProvider).valueOrNull;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GeneratedCoverArt(
                      title: album.title,
                      subtitle: album.artistName,
                      size: 108,
                      borderRadius: 26,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${album.artistName} · ${album.sourceName}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${album.trackCount} ${l10n.tracksLabel}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: ListView.separated(
                    itemCount: album.tracks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = album.tracks[index];
                      final isFavorite =
                          catalogState?.favoriteTrackIds.contains(track.id) ??
                          false;
                      final isLiked =
                          catalogState?.likedTrackIds.contains(track.id) ??
                          false;
                      return Material(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(22),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          title: Text(track.title),
                          subtitle: Text(track.artistName),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () {
                                  ref
                                      .read(
                                        libraryCatalogControllerProvider
                                            .notifier,
                                      )
                                      .toggleFavorite(track.id);
                                },
                                icon: Icon(
                                  isFavorite
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  ref
                                      .read(
                                        libraryCatalogControllerProvider
                                            .notifier,
                                      )
                                      .toggleLiked(track.id);
                                },
                                icon: Icon(
                                  isLiked
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                ),
                              ),
                              IconButton.filledTonal(
                                onPressed: () {
                                  ref
                                      .read(playerControllerProvider.notifier)
                                      .playLibrarySong(track);
                                  Navigator.of(context).pop();
                                },
                                icon: const Icon(Icons.play_arrow_rounded),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SourceFilterChip extends StatelessWidget {
  const _SourceFilterChip({
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

    return Material(
      color: isSelected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                source.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$albumCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: GeneratedCoverArt(
                  title: album.title,
                  subtitle: album.artistName,
                  size: 168,
                  borderRadius: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${album.artistName} · ${album.sourceName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${album.trackCount} ${l10n.tracksLabel}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumMetaPill extends StatelessWidget {
  const _AlbumMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _AlbumsEmptyCard extends StatelessWidget {
  const _AlbumsEmptyCard({
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
