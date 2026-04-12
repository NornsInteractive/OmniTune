import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/library_song.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/generated_cover_art.dart';
import '../application/library_catalog_controller.dart';
import '../application/library_controller.dart';

enum LibraryCollectionSection { favorites, liked, allSongs }

extension LibraryCollectionSectionX on LibraryCollectionSection {
  static LibraryCollectionSection fromRouteValue(String value) {
    return switch (value) {
      'favorites' => LibraryCollectionSection.favorites,
      'liked' => LibraryCollectionSection.liked,
      _ => LibraryCollectionSection.allSongs,
    };
  }

  String get routeValue => switch (this) {
    LibraryCollectionSection.favorites => 'favorites',
    LibraryCollectionSection.liked => 'liked',
    LibraryCollectionSection.allSongs => 'all',
  };

  String title(AppLocalizations l10n) => switch (this) {
    LibraryCollectionSection.favorites => l10n.favoritesCollectionTitle,
    LibraryCollectionSection.liked => l10n.likedCollectionTitle,
    LibraryCollectionSection.allSongs => l10n.allSongsCollectionTitle,
  };

  String emptyTitle(AppLocalizations l10n) => switch (this) {
    LibraryCollectionSection.favorites => l10n.favoritesEmptyTitle,
    LibraryCollectionSection.liked => l10n.likedEmptyTitle,
    LibraryCollectionSection.allSongs => l10n.allSongsEmptyTitle,
  };

  IconData get icon => switch (this) {
    LibraryCollectionSection.favorites => Icons.bookmark_rounded,
    LibraryCollectionSection.liked => Icons.favorite_rounded,
    LibraryCollectionSection.allSongs => Icons.queue_music_rounded,
  };
}

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryControllerProvider);
    final catalogAsync = ref.watch(libraryCatalogControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0),
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LibraryFeedback(message: error.toString()),
        data: (browser) {
          return catalogAsync.when(
            loading: () => _CollectionHome(browser: browser),
            error: (_, _) => _CollectionHome(browser: browser),
            data: (catalog) =>
                _CollectionHome(browser: browser, catalog: catalog),
          );
        },
      ),
      floatingActionButton: libraryAsync.valueOrNull?.hasSources == true
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push('/settings/add-source'),
              icon: const Icon(Icons.add_link_rounded),
              label: Text(l10n.addSourceAction),
            ),
    );
  }
}

class LibrarySongsPage extends ConsumerWidget {
  const LibrarySongsPage({super.key, required this.section});

  final LibraryCollectionSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(libraryCatalogControllerProvider);
    final libraryAsync = ref.watch(libraryControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LibraryFeedback(message: error.toString()),
        data: (catalog) {
          final tracks = _tracksForSection(catalog);
          final hasSources = libraryAsync.valueOrNull?.hasSources ?? false;
          final playerState = ref.watch(playerControllerProvider);

          return RefreshIndicator(
            onRefresh: () {
              return ref
                  .read(libraryCatalogControllerProvider.notifier)
                  .scanAllSources();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _SongsHeader(
                    section: section,
                    trackCount: tracks.length,
                    catalog: catalog,
                  ),
                ),
                const StudioSliverGap(height: 18),
                if (!hasSources)
                  SliverToBoxAdapter(
                    child: _CollectionEmptyState(
                      title: AppLocalizations.of(context)!.libraryEmptyTitle,
                      description: AppLocalizations.of(
                        context,
                      )!.libraryEmptyDescription,
                      actionLabel: AppLocalizations.of(
                        context,
                      )!.addSourceAction,
                      onPressed: () => context.push('/settings/add-source'),
                    ),
                  )
                else if (tracks.isEmpty)
                  SliverToBoxAdapter(
                    child: _CollectionEmptyState(
                      title: section.emptyTitle(AppLocalizations.of(context)!),
                      description: catalog.hasScanResult
                          ? AppLocalizations.of(
                              context,
                            )!.collectionEmptyDescription
                          : AppLocalizations.of(context)!.scanLibraryHint,
                      actionLabel: AppLocalizations.of(
                        context,
                      )!.scanLibraryAction,
                      onPressed: () {
                        ref
                            .read(libraryCatalogControllerProvider.notifier)
                            .scanAllSources();
                      },
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: tracks.length,
                    separatorBuilder: (_, _) => const StudioGap(height: 10),
                    itemBuilder: (context, index) {
                      final song = tracks[index];
                      final isFavorite = catalog.favoriteTrackIds.contains(
                        song.id,
                      );
                      final isLiked = catalog.likedTrackIds.contains(song.id);
                      final isCurrentTrack =
                          playerState.currentTrack?.id == song.id;

                      return _SongRow(
                        song: song,
                        isFavorite: isFavorite,
                        isLiked: isLiked,
                        isCurrentTrack: isCurrentTrack,
                        onFavorite: () {
                          ref
                              .read(libraryCatalogControllerProvider.notifier)
                              .toggleFavorite(song.id);
                        },
                        onLiked: () {
                          ref
                              .read(libraryCatalogControllerProvider.notifier)
                              .toggleLiked(song.id);
                        },
                        onTap: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .playLibrarySong(song, playlist: tracks);
                        },
                        onPlayNext: () {
                          _addSongToPlayNext(context, ref, song);
                        },
                        onShowDetails: () {
                          _showSongDetailsSheet(
                            context,
                            ref,
                            song: song,
                            isFavorite: isFavorite,
                            isLiked: isLiked,
                            playlist: tracks,
                          );
                        },
                      );
                    },
                  ),
                const StudioSliverGap(height: 18),
              ],
            ),
          );
        },
      ),
    );
  }

  List<LibrarySong> _tracksForSection(LibraryCatalogState catalog) {
    return switch (section) {
      LibraryCollectionSection.favorites => catalog.favoriteTracks,
      LibraryCollectionSection.liked => catalog.likedTracks,
      LibraryCollectionSection.allSongs => catalog.tracks,
    };
  }
}

class LibraryBrowserPage extends ConsumerWidget {
  const LibraryBrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0),
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LibraryFeedback(message: error.toString()),
        data: (browser) {
          if (!browser.hasSources) {
            final l10n = AppLocalizations.of(context)!;
            return _CollectionEmptyState(
              title: l10n.libraryEmptyTitle,
              description: l10n.libraryEmptyDescription,
              actionLabel: l10n.addSourceAction,
              onPressed: () => context.push('/settings/add-source'),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(libraryControllerProvider.notifier).refresh(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _BrowserHeader(browser: browser)),
                const StudioSliverGap(height: 18),
                SliverToBoxAdapter(child: _BrowserBody(state: browser)),
                const StudioSliverGap(height: 18),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CollectionHome extends ConsumerWidget {
  const _CollectionHome({required this.browser, this.catalog});

  final LibraryViewState browser;
  final LibraryCatalogState? catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    if (!browser.hasSources) {
      return _CollectionEmptyState(
        title: l10n.libraryEmptyTitle,
        description: l10n.libraryEmptyDescription,
        actionLabel: l10n.addSourceAction,
        onPressed: () => context.push('/settings/add-source'),
      );
    }

    return RefreshIndicator(
      onRefresh: () {
        return ref
            .read(libraryCatalogControllerProvider.notifier)
            .scanAllSources();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _CollectionHero(browser: browser, catalog: catalog),
          ),
          const StudioSliverGap(height: 14),
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 860
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;

                final cards = [
                  _QuickCard(
                    icon: LibraryCollectionSection.allSongs.icon,
                    title: l10n.allSongsCollectionTitle,
                    subtitle:
                        '${catalog?.tracks.length ?? 0} ${l10n.tracksLabel}',
                    onTap: () => context.push('/collection/list/all'),
                  ),
                  _QuickCard(
                    icon: LibraryCollectionSection.liked.icon,
                    title: l10n.likedCollectionTitle,
                    subtitle:
                        '${catalog?.likedTracks.length ?? 0} ${l10n.tracksLabel}',
                    onTap: () => context.push('/collection/list/liked'),
                  ),
                  _QuickCard(
                    icon: LibraryCollectionSection.favorites.icon,
                    title: l10n.favoritesCollectionTitle,
                    subtitle:
                        '${catalog?.favoriteTracks.length ?? 0} ${l10n.tracksLabel}',
                    onTap: () => context.push('/collection/list/favorites'),
                  ),
                  _QuickCard(
                    icon: Icons.folder_open_rounded,
                    title: l10n.browserTitle,
                    subtitle:
                        browser.selectedSource?.name ??
                        l10n.sourceManagementEmptySummary,
                    onTap: () => context.push('/collection/browser'),
                  ),
                ];

                return Wrap(
                  spacing: studioSpacingOf(context, 14),
                  runSpacing: studioSpacingOf(context, 14),
                  children: [
                    for (final card in cards)
                      SizedBox(width: width, child: card),
                  ],
                );
              },
            ),
          ),
          const StudioSliverGap(height: 14),
        ],
      ),
    );
  }
}

class _CollectionHero extends ConsumerWidget {
  const _CollectionHero({required this.browser, this.catalog});

  final LibraryViewState browser;
  final LibraryCatalogState? catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedSource = browser.selectedSource;

    return StudioPanel(
      radius: 24,
      tint: colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.collectionTabLabel,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const StudioGap(height: 6),
                    Text(
                      browser.sources.length > 1
                          ? l10n.collectionDescriptionAllSources(
                              selectedSource?.name ?? '',
                              browser.sources.length,
                            )
                          : l10n.collectionDescription(
                              selectedSource?.name ?? '',
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const StudioGap(width: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  ref
                      .read(libraryCatalogControllerProvider.notifier)
                      .scanAllSources();
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
            ],
          ),
          const StudioGap(height: 14),
          Wrap(
            spacing: studioSpacingOf(context, 10),
            runSpacing: studioSpacingOf(context, 10),
            children: [
              StudioStatBlock(
                icon: Icons.queue_music_rounded,
                label: l10n.tracksLabel,
                value: '${catalog?.tracks.length ?? 0}',
              ),
              StudioStatBlock(
                icon: Icons.favorite_rounded,
                label: l10n.likedCollectionTitle,
                value: '${catalog?.likedTracks.length ?? 0}',
              ),
              StudioStatBlock(
                icon: Icons.bookmark_rounded,
                label: l10n.favoritesCollectionTitle,
                value: '${catalog?.favoriteTracks.length ?? 0}',
              ),
            ],
          ),
          const StudioGap(height: 14),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: browser.sources.length + 1,
              separatorBuilder: (_, _) => const StudioGap(width: 10),
              itemBuilder: (context, index) {
                if (index == browser.sources.length) {
                  return _AddSourceCard(
                    onTap: () => context.push('/settings/add-source'),
                  );
                }

                final source = browser.sources[index];
                return _SourceCard(
                  source: source,
                  isSelected: source.id == browser.selectedSource?.id,
                  onTap: () {
                    ref
                        .read(libraryControllerProvider.notifier)
                        .selectSource(source.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SongsHeader extends StatelessWidget {
  const _SongsHeader({
    required this.section,
    required this.trackCount,
    required this.catalog,
  });

  final LibraryCollectionSection section;
  final int trackCount;
  final LibraryCatalogState catalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return StudioPanel(
      radius: 28,
      tint: colorScheme.primaryContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioPanel(
            padding: EdgeInsets.zero,
            radius: 18,
            tint: colorScheme.surfaceContainerLow,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const StudioGap(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title(l10n),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const StudioGap(height: 6),
                Text(
                  '$trackCount ${l10n.tracksLabel}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (catalog.isScanning) ...[
                  const StudioGap(height: 12),
                  LinearProgressIndicator(
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserHeader extends ConsumerWidget {
  const _BrowserHeader({required this.browser});

  final LibraryViewState browser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return StudioPanel(
      radius: 28,
      tint: colorScheme.primaryContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioPanel(
            padding: EdgeInsets.zero,
            radius: 18,
            tint: colorScheme.surfaceContainerLow,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          const StudioGap(width: 14),
          Expanded(
            child: StudioSectionTitle(
              title: l10n.browserTitle,
              description: browser.selectedSource?.name ?? l10n.browserTitle,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.push('/settings/add-source'),
            icon: const Icon(Icons.add_link_rounded),
            label: Text(l10n.addSourceAction),
          ),
        ],
      ),
    );
  }
}

class _BrowserBody extends ConsumerWidget {
  const _BrowserBody({required this.state});

  final LibraryViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final controller = ref.read(libraryControllerProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);

    return StudioPanel(
      radius: 28,
      tint: colorScheme.surfaceContainerLow,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: StudioSectionTitle(
                      title: state.displayPath,
                      eyebrow: l10n.currentPathLabel,
                    ),
                  ),
                  const StudioGap(width: 8),
                  IconButton(
                    tooltip: l10n.upAction,
                    onPressed: state.canGoUp ? controller.goUp : null,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                  IconButton(
                    tooltip: l10n.refreshAction,
                    onPressed: controller.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (state.hasError || state.diagnostics != null) ...[
                const StudioGap(height: 16),
                _DiagnosticsCard(state: state),
              ],
              const StudioGap(height: 16),
              if (state.entries.isEmpty)
                _CollectionEmptyState(
                  title: l10n.noFilesTitle,
                  description: state.hasError
                      ? state.errorMessage!
                      : l10n.noFilesDescription,
                  actionLabel: l10n.refreshAction,
                  onPressed: controller.refresh,
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.entries.length,
                  separatorBuilder: (_, _) => const StudioGap(height: 10),
                  itemBuilder: (context, index) {
                    final entry = state.entries[index];
                    final isCurrentTrack =
                        playerState.currentTrack?.remotePath == entry.path &&
                        playerState.currentTrack?.sourceId ==
                            state.selectedSource?.id;

                    return _EntryRow(
                      entry: entry,
                      isCurrentTrack: isCurrentTrack,
                      onTap: () async {
                        try {
                          await controller.openEntry(entry);
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }

                        if (!entry.isDirectory && !entry.isPlayable) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.unsupportedFileMessage),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
            ],
          ),
          if (state.isLoading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = studioRadiusOf(context, 22);
    final iconSize = studioSpacingOf(context, 42).clamp(36.0, 52.0).toDouble();

    return StudioPanel(
      padding: EdgeInsets.zero,
      radius: 22,
      tint: colorScheme.surfaceContainerLow,
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: studioPaddingOf(
              context,
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
            child: Row(
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      studioRadiusOf(context, 15),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const StudioGap(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const StudioGap(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  const _SongRow({
    required this.song,
    required this.isFavorite,
    required this.isLiked,
    required this.isCurrentTrack,
    required this.onFavorite,
    required this.onLiked,
    required this.onTap,
    required this.onPlayNext,
    required this.onShowDetails,
  });

  final LibrarySong song;
  final bool isFavorite;
  final bool isLiked;
  final bool isCurrentTrack;
  final VoidCallback onFavorite;
  final VoidCallback onLiked;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = studioRadiusOf(context, 22);
    final leadingSize = studioSpacingOf(
      context,
      42,
    ).clamp(34.0, 52.0).toDouble();
    final buttonSize = studioSpacingOf(
      context,
      38,
    ).clamp(32.0, 46.0).toDouble();

    return StudioPanel(
      padding: EdgeInsets.zero,
      radius: 22,
      tint: isCurrentTrack
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
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
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
            child: Row(
              children: [
                Container(
                  width: leadingSize,
                  height: leadingSize,
                  decoration: BoxDecoration(
                    color: isCurrentTrack
                        ? colorScheme.surface
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      studioRadiusOf(context, 16),
                    ),
                  ),
                  child: Icon(
                    isCurrentTrack
                        ? Icons.graphic_eq_rounded
                        : Icons.music_note_rounded,
                    size: 20,
                    color: isCurrentTrack
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
                          color: isCurrentTrack
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                      const StudioGap(height: 4),
                      Text(
                        '${song.artistName} · ${song.albumTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isCurrentTrack
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
                  onPressed: onFavorite,
                  iconSize: 22,
                  visualDensity: VisualDensity.compact,
                  padding: studioPaddingOf(context, const EdgeInsets.all(6)),
                  constraints: BoxConstraints(
                    minWidth: buttonSize,
                    minHeight: buttonSize,
                  ),
                  icon: Icon(
                    isFavorite
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                  ),
                ),
                IconButton(
                  onPressed: onLiked,
                  iconSize: 22,
                  visualDensity: VisualDensity.compact,
                  padding: studioPaddingOf(context, const EdgeInsets.all(6)),
                  constraints: BoxConstraints(
                    minWidth: buttonSize,
                    minHeight: buttonSize,
                  ),
                  icon: Icon(
                    isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                ),
                IconButton(
                  tooltip: l10n.moreOptionsAction,
                  onPressed: onShowDetails,
                  iconSize: 22,
                  visualDensity: VisualDensity.compact,
                  padding: studioPaddingOf(context, const EdgeInsets.all(6)),
                  constraints: BoxConstraints(
                    minWidth: buttonSize,
                    minHeight: buttonSize,
                  ),
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.isCurrentTrack,
    required this.onTap,
  });

  final RemoteEntry entry;
  final bool isCurrentTrack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = studioRadiusOf(context, 18);
    final leadingSize = studioSpacingOf(
      context,
      34,
    ).clamp(30.0, 44.0).toDouble();

    final icon = switch (entry.kind) {
      RemoteEntryKind.directory => Icons.folder_rounded,
      RemoteEntryKind.audio =>
        isCurrentTrack ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
      RemoteEntryKind.file => Icons.description_rounded,
    };

    return StudioPanel(
      padding: EdgeInsets.zero,
      radius: 18,
      tint: isCurrentTrack
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          dense: true,
          visualDensity: VisualDensity.compact,
          minLeadingWidth: leadingSize,
          contentPadding: studioPaddingOf(
            context,
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          leading: Container(
            width: leadingSize,
            height: leadingSize,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
          ),
          title: Text(entry.name),
          subtitle: Text(entry.path),
          trailing: Icon(
            entry.isDirectory
                ? Icons.chevron_right_rounded
                : Icons.play_arrow_rounded,
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.state});

  final LibraryViewState state;

  @override
  Widget build(BuildContext context) {
    final diagnostics = state.diagnostics;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return StudioPanel(
      radius: 22,
      tint: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.browserDiagnosticsTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (state.errorMessage != null) ...[
            const StudioGap(height: 10),
            Text(
              state.errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colorScheme.error),
            ),
          ],
          if (diagnostics != null) ...[
            const StudioGap(height: 10),
            Text(
              '${diagnostics.protocolLabel} · ${diagnostics.requestedPath}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.isSelected,
    required this.onTap,
  });

  final SourceProfile source;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = studioRadiusOf(context, 20);

    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: SizedBox(
          width: studioSpacingOf(context, 160).clamp(132.0, 190.0).toDouble(),
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
                  source.hostLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.72)
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

class _AddSourceCard extends StatelessWidget {
  const _AddSourceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final radius = studioRadiusOf(context, 20);

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: SizedBox(
          width: studioSpacingOf(context, 160).clamp(132.0, 190.0).toDouble(),
          child: Padding(
            padding: studioPaddingOf(context, const EdgeInsets.all(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.add_link_rounded),
                const Spacer(),
                Text(
                  l10n.addSourceAction,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionEmptyState extends StatelessWidget {
  const _CollectionEmptyState({
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
                  160,
                ).clamp(120.0, 190.0).toDouble(),
                borderRadius: 24,
              ),
              const StudioGap(height: 18),
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
              const StudioGap(height: 18),
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.radar_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryFeedback extends StatelessWidget {
  const _LibraryFeedback({required this.message});

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

void _showSongDetailsSheet(
  BuildContext context,
  WidgetRef ref, {
  required LibrarySong song,
  required bool isFavorite,
  required bool isLiked,
  List<LibrarySong>? playlist,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: studioPaddingOf(
            sheetContext,
            const EdgeInsets.fromLTRB(20, 8, 20, 20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StudioPanel(
                radius: 24,
                tint: colorScheme.primaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: Theme.of(sheetContext).textTheme.headlineSmall,
                    ),
                    const StudioGap(height: 8),
                    Text(
                      '${song.artistName} · ${song.albumTitle}',
                      style: Theme.of(sheetContext).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const StudioGap(height: 14),
              StudioPanel(
                radius: 24,
                tint: colorScheme.surfaceContainerLow,
                child: Column(
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(playerControllerProvider.notifier)
                            .playLibrarySong(song, playlist: playlist);
                        Navigator.of(sheetContext).pop();
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(l10n.playAction),
                    ),
                    const StudioGap(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _addSongToPlayNext(context, ref, song);
                      },
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: Text(l10n.playNextAction),
                    ),
                    const StudioGap(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(
                                    libraryCatalogControllerProvider.notifier,
                                  )
                                  .toggleFavorite(song.id);
                              Navigator.of(sheetContext).pop();
                            },
                            icon: Icon(
                              isFavorite
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                            ),
                            label: Text(l10n.favoritesCollectionTitle),
                          ),
                        ),
                        const StudioGap(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              ref
                                  .read(
                                    libraryCatalogControllerProvider.notifier,
                                  )
                                  .toggleLiked(song.id);
                              Navigator.of(sheetContext).pop();
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

Future<void> _addSongToPlayNext(
  BuildContext context,
  WidgetRef ref,
  LibrarySong song,
) async {
  final l10n = AppLocalizations.of(context)!;

  try {
    await ref.read(playerControllerProvider.notifier).addToPlayNext(song);
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
    SnackBar(content: Text(l10n.addedToPlayNextMessage(song.title))),
  );
}
