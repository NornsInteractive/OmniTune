import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/library_song.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../player/application/player_controller.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final libraryState = ref.watch(libraryControllerProvider);
    final catalogState = ref.watch(libraryCatalogControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: libraryState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (browser) {
            return catalogState.when(
              loading: () => _CollectionHomeBody(browser: browser),
              error: (_, _) => _CollectionHomeBody(browser: browser),
              data: (catalog) => _CollectionHomeBody(browser: browser, catalog: catalog),
            );
          },
        ),
      ),
      floatingActionButton: libraryState.valueOrNull?.hasSources == true
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final catalogAsync = ref.watch(libraryCatalogControllerProvider);
    final libraryAsync = ref.watch(libraryControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (catalog) {
            final tracks = _tracksForSection(catalog);
            final playerState = ref.watch(playerControllerProvider);
            final hasSources = libraryAsync.valueOrNull?.hasSources ?? false;

            return RefreshIndicator(
              onRefresh: () {
                return ref.read(libraryCatalogControllerProvider.notifier).scanAllSources();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Padding(
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
                          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => context.pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(height: 20),
                            Text(section.title(l10n), style: theme.textTheme.headlineMedium),
                            const SizedBox(height: 10),
                            Text(
                              '${tracks.length} ${l10n.tracksLabel}',
                              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                            if (catalog.isScanning) ...[
                              const SizedBox(height: 18),
                              LinearProgressIndicator(minHeight: 6, borderRadius: BorderRadius.circular(999)),
                              const SizedBox(height: 10),
                              Text(
                                l10n.scanningProgress(catalog.scannedDirectoryCount, catalog.discoveredTrackCount),
                                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!hasSources)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: _LibraryEmptyState(onAddSource: () => context.push('/settings/add-source')),
                      )
                    else if (tracks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: _TrackEmptyState(
                          title: section.emptyTitle(l10n),
                          description: catalog.hasScanResult ? l10n.collectionEmptyDescription : l10n.scanLibraryHint,
                          actionLabel: l10n.scanLibraryAction,
                          onPressed: () {
                            ref.read(libraryCatalogControllerProvider.notifier).scanAllSources();
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tracks.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final song = tracks[index];
                            final isFavorite = catalog.favoriteTrackIds.contains(song.id);
                            final isLiked = catalog.likedTrackIds.contains(song.id);
                            final isCurrentTrack = playerState.currentTrack?.id == song.id;

                            return _SongTile(
                              song: song,
                              isFavorite: isFavorite,
                              isLiked: isLiked,
                              isCurrentTrack: isCurrentTrack,
                              onFavorite: () {
                                ref.read(libraryCatalogControllerProvider.notifier).toggleFavorite(song.id);
                              },
                              onLiked: () {
                                ref.read(libraryCatalogControllerProvider.notifier).toggleLiked(song.id);
                              },
                              onTap: () {
                                ref.read(playerControllerProvider.notifier).playLibrarySong(song);
                              },
                              onShowDetails: () {
                                _showSongDetailsBottomSheet(
                                  context,
                                  song: song,
                                  isFavorite: isFavorite,
                                  isLiked: isLiked,
                                  onToggleFavorite: () {
                                    ref.read(libraryCatalogControllerProvider.notifier).toggleFavorite(song.id);
                                  },
                                  onToggleLiked: () {
                                    ref.read(libraryCatalogControllerProvider.notifier).toggleLiked(song.id);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final libraryState = ref.watch(libraryControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: libraryState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text(error.toString())),
          data: (browser) {
            if (!browser.hasSources) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: _LibraryEmptyState(onAddSource: () => context.push('/settings/add-source')),
              );
            }

            return RefreshIndicator(
              onRefresh: () {
                return ref.read(libraryControllerProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: _BrowserHero(browser: browser),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      child: _BrowserPanel(state: browser),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/add-source'),
        icon: const Icon(Icons.add_link_rounded),
        label: Text(l10n.addSourceAction),
      ),
    );
  }
}

class _CollectionHomeBody extends ConsumerWidget {
  const _CollectionHomeBody({required this.browser, this.catalog});

  final LibraryViewState browser;
  final LibraryCatalogState? catalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!browser.hasSources) {
      return _LibraryEmptyState(onAddSource: () => context.push('/settings/add-source'));
    }

    return RefreshIndicator(
      onRefresh: () {
        return ref.read(libraryCatalogControllerProvider.notifier).scanAllSources();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      colorScheme.surface.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.collectionHeadline,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                browser.sources.length > 1
                                    ? l10n.collectionDescriptionAllSources(
                                        browser.selectedSource?.name ?? '',
                                        browser.sources.length,
                                      )
                                    : l10n.collectionDescription(browser.selectedSource?.name ?? ''),
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FilledButton.icon(
                            onPressed: () {
                              ref.read(libraryCatalogControllerProvider.notifier).scanAllSources();
                            },
                            icon: Icon(
                              catalog?.isScanning == true ? Icons.sync_rounded : Icons.radar_rounded,
                              size: 18,
                            ),
                            label: Text(
                              catalog?.isScanning == true ? l10n.scanningAction : l10n.scanLibraryAction,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: browser.sources.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          if (index == browser.sources.length) {
                            return _AddSourceCardCompact(onTap: () => context.push('/settings/add-source'));
                          }

                          final source = browser.sources[index];
                          return _SourceCardCompact(
                            source: source,
                            isSelected: source.id == browser.selectedSource?.id,
                            onTap: () {
                              ref.read(libraryControllerProvider.notifier).selectSource(source.id);
                            },
                          );
                        },
                      ),
                    ),
                    if (catalog?.isScanning == true) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(minHeight: 4, borderRadius: BorderRadius.circular(999)),
                      const SizedBox(height: 6),
                      Text(
                        l10n.scanningProgress(catalog!.scannedDirectoryCount, catalog!.discoveredTrackCount),
                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      if ((catalog!.lastScanSourceName ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          l10n.currentScanSourceLabel(catalog!.lastScanSourceName!),
                          style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
                ),
                child: Column(
                  children: [
                    _CollectionEntryTile(
                      icon: LibraryCollectionSection.allSongs.icon,
                      title: l10n.allSongsCollectionTitle,
                      subtitle: '${catalog?.tracks.length ?? 0} ${l10n.tracksLabel}',
                      onTap: () => context.push('/collection/list/all'),
                      compact: true,
                    ),
                    const SizedBox(height: 8),
                    _CollectionEntryTile(
                      icon: LibraryCollectionSection.liked.icon,
                      title: l10n.likedCollectionTitle,
                      subtitle: '${catalog?.likedTracks.length ?? 0} ${l10n.tracksLabel}',
                      onTap: () => context.push('/collection/list/liked'),
                      compact: true,
                    ),
                    const SizedBox(height: 8),
                    _CollectionEntryTile(
                      icon: LibraryCollectionSection.favorites.icon,
                      title: l10n.favoritesCollectionTitle,
                      subtitle: '${catalog?.favoriteTracks.length ?? 0} ${l10n.tracksLabel}',
                      onTap: () => context.push('/collection/list/favorites'),
                      compact: true,
                    ),
                    const SizedBox(height: 8),
                    _CollectionEntryTile(
                      icon: Icons.folder_open_rounded,
                      title: l10n.browserTitle,
                      subtitle: browser.selectedSource?.name ?? l10n.sourceManagementEmptySummary,
                      onTap: () => context.push('/collection/browser'),
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserHero extends ConsumerWidget {
  const _BrowserHero({required this.browser});

  final LibraryViewState browser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colorScheme.primaryContainer, colorScheme.surfaceContainerHighest, colorScheme.secondaryContainer],
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filledTonal(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
          const SizedBox(height: 20),
          Text(l10n.browserTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(
            browser.selectedSource == null
                ? l10n.sourceManagementEmptySummary
                : l10n.collectionDescription(browser.selectedSource!.name),
            style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: browser.sources.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (index == browser.sources.length) {
                  return _AddSourceCard(onTap: () => context.push('/settings/add-source'));
                }

                final source = browser.sources[index];
                return _SourceCard(
                  source: source,
                  isSelected: source.id == browser.selectedSource?.id,
                  onTap: () {
                    ref.read(libraryControllerProvider.notifier).selectSource(source.id);
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

class _CollectionEntryTile extends StatelessWidget {
  const _CollectionEntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (compact) {
      return Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 18, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// 移除 _CollectionStatCard - 已在 UI 重设计中移除

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.isFavorite,
    required this.isLiked,
    required this.isCurrentTrack,
    required this.onFavorite,
    required this.onLiked,
    required this.onTap,
    required this.onShowDetails,
  });

  final LibrarySong song;
  final bool isFavorite;
  final bool isLiked;
  final bool isCurrentTrack;
  final VoidCallback onFavorite;
  final VoidCallback onLiked;
  final VoidCallback onTap;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isCurrentTrack ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        onLongPress: onShowDetails,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.primary,
                child: Icon(isCurrentTrack ? Icons.graphic_eq_rounded : Icons.music_note_rounded),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${song.artistName} · ${song.albumTitle} · ${song.sourceName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                icon: Icon(isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              ),
              IconButton(
                onPressed: onLiked,
                icon: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              ),
              IconButton(onPressed: onShowDetails, icon: const Icon(Icons.more_vert_rounded)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserPanel extends ConsumerWidget {
  const _BrowserPanel({required this.state});

  final LibraryViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = ref.read(libraryControllerProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.browserTitle, style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.currentPathLabel}: ${state.displayPath}',
                            style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
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
                  const SizedBox(height: 16),
                  _DiagnosticsCard(state: state),
                ],
                const SizedBox(height: 18),
                if (state.entries.isEmpty)
                  _TrackEmptyState(
                    title: l10n.noFilesTitle,
                    description: state.hasError ? state.errorMessage! : l10n.noFilesDescription,
                    actionLabel: l10n.refreshAction,
                    onPressed: controller.refresh,
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = state.entries[index];
                      final isCurrentTrack =
                          playerState.currentTrack?.remotePath == entry.path &&
                          playerState.currentTrack?.sourceId == state.selectedSource?.id;
                      return _EntryTile(
                        entry: entry,
                        isCurrentTrack: isCurrentTrack,
                        onTap: () async {
                          try {
                            await controller.openEntry(entry);
                          } catch (error) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                          }

                          if (!entry.isDirectory && !entry.isPlayable) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(l10n.unsupportedFileMessage)));
                          }
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
          if (state.isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: colorScheme.surface.withValues(alpha: 0.75),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.state});

  final LibraryViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final diagnostics = state.diagnostics;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.browserDiagnosticsTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (state.errorMessage != null)
            Text(state.errorMessage!, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
          if (diagnostics != null) ...[
            const SizedBox(height: 10),
            Text(
              '${diagnostics.protocolLabel} · ${diagnostics.requestedPath}',
              style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 10),
            ...diagnostics.details.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.isCurrentTrack, required this.onTap});

  final RemoteEntry entry;
  final bool isCurrentTrack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final icon = switch (entry.kind) {
      RemoteEntryKind.directory => Icons.folder_rounded,
      RemoteEntryKind.audio => isCurrentTrack ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
      RemoteEntryKind.file => Icons.description_rounded,
    };

    return Material(
      color: isCurrentTrack ? colorScheme.secondaryContainer : colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
          foregroundColor: colorScheme.primary,
          child: Icon(icon),
        ),
        title: Text(entry.name),
        subtitle: Text(entry.path),
        trailing: Icon(entry.isDirectory ? Icons.chevron_right_rounded : Icons.play_arrow_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _TrackEmptyState extends StatelessWidget {
  const _TrackEmptyState({
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
      width: double.infinity,
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
          Text(description, style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({required this.onAddSource});

  final VoidCallback onAddSource;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _TrackEmptyState(
      title: l10n.libraryEmptyTitle,
      description: l10n.libraryEmptyDescription,
      actionLabel: l10n.addSourceAction,
      onPressed: onAddSource,
    );
  }
}

class _SourceCardCompact extends StatelessWidget {
  const _SourceCardCompact({required this.source, required this.isSelected, required this.onTap});

  final SourceProfile source;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colorScheme.surface,
                      foregroundColor: colorScheme.primary,
                      radius: 14,
                      child: const Icon(Icons.cloud_circle_rounded, size: 18),
                    ),
                    const Spacer(),
                    if (isSelected) Icon(Icons.check_circle_rounded, size: 16, color: colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    source.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    source.hostLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
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

class _AddSourceCardCompact extends StatelessWidget {
  const _AddSourceCardCompact({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 140,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.primary,
                  radius: 14,
                  child: const Icon(Icons.add_rounded, size: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.addSourceAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.isSelected, required this.onTap});

  final SourceProfile source;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isSelected ? colorScheme.secondaryContainer : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: SizedBox(
          width: 220,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colorScheme.surface,
                      foregroundColor: colorScheme.primary,
                      child: const Icon(Icons.cloud_circle_rounded),
                    ),
                    const Spacer(),
                    if (isSelected) Icon(Icons.check_circle_rounded, color: colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  source.hostLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: SizedBox(
          width: 168,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.primary,
                  radius: 24,
                  child: const Icon(Icons.add_link_rounded),
                ),
                const SizedBox(height: 16),
                Text(l10n.addSourceAction, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showSongDetailsBottomSheet(
  BuildContext context, {
  required LibrarySong song,
  required bool isFavorite,
  required bool isLiked,
  required VoidCallback onToggleFavorite,
  required VoidCallback onToggleLiked,
}) {
  showModalBottomSheet(
    context: context,
    builder: (context) => _SongDetailsBottomSheet(
      song: song,
      isFavorite: isFavorite,
      isLiked: isLiked,
      onToggleFavorite: onToggleFavorite,
      onToggleLiked: onToggleLiked,
    ),
  );
}

class _SongDetailsBottomSheet extends StatelessWidget {
  const _SongDetailsBottomSheet({
    required this.song,
    required this.isFavorite,
    required this.isLiked,
    required this.onToggleFavorite,
    required this.onToggleLiked,
  });

  final LibrarySong song;
  final bool isFavorite;
  final bool isLiked;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleLiked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title
            Text(l10n.songDetailsTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),

            // Song details
            _SongDetailRow(label: l10n.filePathLabel, value: song.remotePath),
            const SizedBox(height: 16),
            _SongDetailRow(label: l10n.sourceLabel, value: song.sourceName),
            const SizedBox(height: 16),
            _SongDetailRow(label: l10n.artistLabel, value: song.artistName),
            const SizedBox(height: 16),
            _SongDetailRow(label: l10n.albumLabel, value: song.albumTitle),
            const SizedBox(height: 28),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onToggleFavorite,
                    icon: Icon(isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                    label: Text(isFavorite ? l10n.removeFromFavoritesAction : l10n.addToFavoritesAction),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onToggleLiked,
                    icon: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                    label: Text(isLiked ? l10n.removeFromLikedAction : l10n.addToLikedAction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SongDetailRow extends StatelessWidget {
  const _SongDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: colorScheme.onSurface),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
