import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/features/settings/presentation/add_source_page.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/library_song.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../../core/widgets/top_snackbar.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/track_cover_thumbnail.dart';
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

  IconData get icon => switch (this) {
    LibraryCollectionSection.favorites => Icons.favorite_rounded,
    LibraryCollectionSection.liked => Icons.history_rounded,
    LibraryCollectionSection.allSongs => Icons.library_music_rounded,
  };
}

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _GlacierPalette.sync(context);
    final l10n = AppLocalizations.of(context)!;
    final browserAsync = ref.watch(libraryControllerProvider);
    final catalog = ref.watch(libraryCatalogControllerProvider).valueOrNull;

    return _GlacierScreen(
      child: browserAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: _GlacierPalette.primary),
        ),
        error: (error, _) => _GlacierCenteredMessage(message: error.toString()),
        data: (browser) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: studioListPaddingOf(
              context,
              const EdgeInsets.fromLTRB(28, 12, 28, 144),
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.libraryTitle,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurface,
                        size: 34,
                        weight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ),
                  _TopIconButton(
                    icon: Icons.radar_rounded,
                    onTap: () {
                      ref
                          .read(libraryCatalogControllerProvider.notifier)
                          .scanAllSources();
                    },
                  ),
                  const SizedBox(width: 8),
                  _TopIconButton(
                    icon: Icons.add_link_rounded,
                    onTap: () => showSourceTypePicker(context),
                  ),
                  const SizedBox(width: 8),
                  _TopIconButton(
                    icon: Icons.settings_rounded,
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                browser.hasSources
                    ? l10n.collectionDescriptionAllSources(
                        browser.selectedSource?.name ?? '-',
                        browser.sources.length,
                      )
                    : l10n.sourceManagementEmptySummary,
                style: _glacierTextStyle(
                  color: _GlacierPalette.onSurfaceVariant,
                  size: 15,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              if (!browser.hasSources)
                _EmptyGlassCard(
                  title: l10n.sourceManagementEmptyTitle,
                  description: l10n.libraryEmptyDescription,
                )
              else
                Column(
                  children: [
                    _LibraryCategoryCard(
                      icon: Icons.library_music_rounded,
                      accent: _GlacierPalette.primary,
                      title: l10n.allSongsCollectionTitle,
                      subtitle:
                          '${catalog?.tracks.length ?? 0} ${l10n.tracksLabel}',
                      onTap: () => context.push('/collection/list/all'),
                    ),
                    const SizedBox(height: 12),
                    _LibraryCategoryCard(
                      icon: Icons.favorite_rounded,
                      accent: _GlacierPalette.tertiary,
                      title: l10n.favoritesCollectionTitle,
                      subtitle:
                          '${catalog?.favoriteTracks.length ?? 0} ${l10n.tracksLabel}',
                      onTap: () => context.push('/collection/list/favorites'),
                    ),
                    const SizedBox(height: 12),
                    _LibraryCategoryCard(
                      icon: Icons.history_rounded,
                      accent: _GlacierPalette.secondary,
                      title: l10n.likedCollectionTitle,
                      subtitle:
                          '${catalog?.likedTracks.length ?? 0} ${l10n.tracksLabel}',
                      onTap: () => context.push('/collection/list/liked'),
                    ),
                    const SizedBox(height: 12),
                    _LibraryCategoryCard(
                      icon: Icons.queue_music_rounded,
                      accent: _GlacierPalette.primary,
                      title: l10n.albumsTabLabel,
                      subtitle:
                          '${catalog?.albums.length ?? 0} ${l10n.albumsTabLabel}',
                      onTap: () => context.go('/albums'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class LibrarySongsPage extends ConsumerWidget {
  const LibrarySongsPage({super.key, required this.section});

  final LibraryCollectionSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _GlacierPalette.sync(context);
    final l10n = AppLocalizations.of(context)!;
    final catalogAsync = ref.watch(libraryCatalogControllerProvider);

    return _GlacierScreen(
      child: catalogAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: _GlacierPalette.primary),
        ),
        error: (error, _) => _GlacierCenteredMessage(message: error.toString()),
        data: (catalog) {
          final tracks = switch (section) {
            LibraryCollectionSection.favorites => catalog.favoriteTracks,
            LibraryCollectionSection.liked => catalog.likedTracks,
            LibraryCollectionSection.allSongs => catalog.tracks,
          };

          final collectionSubtitle = switch (section) {
            LibraryCollectionSection.favorites =>
              '${tracks.length} ${l10n.tracksLabel} · ${l10n.favoritesCollectionDescription}',
            LibraryCollectionSection.liked =>
              '${tracks.length} ${l10n.tracksLabel} · ${l10n.likedCollectionDescription}',
            LibraryCollectionSection.allSongs =>
              '${tracks.length} ${l10n.tracksLabel}',
          };

          final emptyTitle = switch (section) {
            LibraryCollectionSection.favorites => l10n.favoritesEmptyTitle,
            LibraryCollectionSection.liked => l10n.likedEmptyTitle,
            LibraryCollectionSection.allSongs => l10n.allSongsEmptyTitle,
          };

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SongsPinnedHeaderDelegate(
                  title: section.title(l10n),
                  subtitle: collectionSubtitle,
                  onBack: () => context.pop(),
                  actions: [
                    _TopIconButton(
                      icon: Icons.radar_rounded,
                      onTap: () {
                        ref
                            .read(libraryCatalogControllerProvider.notifier)
                            .scanAllSources();
                      },
                    ),
                    const SizedBox(width: 8),
                    _TopIconButton(
                      icon: Icons.add_link_rounded,
                      onTap: () => showSourceTypePicker(context),
                    ),
                    const SizedBox(width: 8),
                    _TopIconButton(
                      icon: Icons.settings_rounded,
                      onTap: () => context.push('/settings'),
                    ),
                  ],
                ),
              ),
              if (tracks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: studioListPaddingOf(
                      context,
                      const EdgeInsets.fromLTRB(28, 18, 28, 144),
                    ),
                    child: _EmptyGlassCard(
                      title: emptyTitle,
                      description: l10n.collectionEmptyDescription,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: studioListPaddingOf(
                    context,
                    const EdgeInsets.fromLTRB(28, 18, 28, 144),
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index.isOdd) {
                        return const SizedBox(height: 8);
                      }
                      final trackIndex = index ~/ 2;
                      return _SongCard(
                        key: ValueKey('song:${tracks[trackIndex].id}'),
                        song: tracks[trackIndex],
                        isFavorite: catalog.favoriteTrackIds.contains(
                          tracks[trackIndex].id,
                        ),
                        isLiked: catalog.likedTrackIds.contains(
                          tracks[trackIndex].id,
                        ),
                        onTap: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .playLibrarySong(
                                tracks[trackIndex],
                                playlist: tracks,
                              );
                        },
                        onFavorite: () {
                          ref
                              .read(libraryCatalogControllerProvider.notifier)
                              .toggleFavorite(tracks[trackIndex].id);
                        },
                        onLiked: () {
                          ref
                              .read(libraryCatalogControllerProvider.notifier)
                              .toggleLiked(tracks[trackIndex].id);
                        },
                        onMore: () {
                          _showSongActionsSheet(
                            context,
                            ref,
                            tracks[trackIndex],
                            tracks,
                            catalog,
                          );
                        },
                      );
                    }, childCount: tracks.length * 2 - 1),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class LibraryBrowserPage extends ConsumerWidget {
  const LibraryBrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _GlacierPalette.sync(context);
    final browserAsync = ref.watch(libraryControllerProvider);
    final catalog = ref.watch(libraryCatalogControllerProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;

    return _GlacierScreen(
      child: browserAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: _GlacierPalette.primary),
        ),
        error: (error, _) => _GlacierCenteredMessage(message: error.toString()),
        data: (browser) {
          final controller = ref.read(libraryControllerProvider.notifier);
          final tracksByKey = _tracksByVisibleEntryKey(
            catalog?.tracks ?? const <LibrarySong>[],
            browser.entries,
          );

          return RefreshIndicator(
            color: _GlacierPalette.primary,
            backgroundColor: _GlacierPalette.surface,
            onRefresh: controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: studioListPaddingOf(
                      context,
                      const EdgeInsets.fromLTRB(28, 12, 28, 0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.browserTitle,
                                style: _glacierTextStyle(
                                  color: _GlacierPalette.onSurface,
                                  size: 32,
                                  weight: FontWeight.w700,
                                  height: 1.05,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _TopIconButton(
                              icon: Icons.radar_rounded,
                              onTap: () {
                                ref
                                    .read(
                                      libraryCatalogControllerProvider.notifier,
                                    )
                                    .scanAllSources();
                              },
                            ),
                            const SizedBox(width: 8),
                            _TopIconButton(
                              icon: Icons.add_link_rounded,
                              onTap: () => showSourceTypePicker(context),
                            ),
                            const SizedBox(width: 8),
                            _TopIconButton(
                              icon: Icons.settings_rounded,
                              onTap: () => context.push('/settings'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          browser.selectedSource?.name ??
                              _noActiveSourceLabel(context),
                          style: _glacierTextStyle(
                            color: _GlacierPalette.onSurfaceVariant,
                            size: 15,
                            weight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!browser.hasSources)
                          _EmptyGlassCard(
                            title: l10n.sourceManagementEmptyTitle,
                            description: l10n.sourceManagementEmptySummary,
                          )
                        else ...[
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: browser.sources.length,
                              separatorBuilder: (context, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final source = browser.sources[index];
                                final selected =
                                    source.id == browser.selectedSource?.id;
                                return _SourceChip(
                                  key: ValueKey('browser-source:${source.id}'),
                                  label: source.name,
                                  selected: selected,
                                  onTap: () =>
                                      controller.selectSource(source.id),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PathToolbar(
                            path: browser.displayPath,
                            canGoUp: browser.canGoUp,
                            onUp: browser.canGoUp ? controller.goUp : null,
                            onRefresh: controller.refresh,
                          ),
                          const SizedBox(height: 20),
                          if (browser.hasError)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _EmptyGlassCard(
                                title: l10n.loadFailedMessage,
                                description: browser.errorMessage ?? '',
                                compact: true,
                              ),
                            ),
                          if (browser.entries.isEmpty)
                            _EmptyGlassCard(
                              title: l10n.noFilesTitle,
                              description: l10n.noFilesDescription,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (browser.hasSources && browser.entries.isNotEmpty)
                  SliverPadding(
                    padding: studioListPaddingOf(
                      context,
                      const EdgeInsets.fromLTRB(28, 0, 28, 144),
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index.isOdd) {
                          return const SizedBox(height: 12);
                        }
                        final entryIndex = index ~/ 2;
                        final entry = browser.entries[entryIndex];
                        return _BrowserEntryCard(
                          key: ValueKey(
                            'browser-entry:${entry.sourceId}:${entry.path}',
                          ),
                          entry: entry,
                          track:
                              tracksByKey['${entry.sourceId}::${entry.path}'],
                          onTap: () async {
                            try {
                              await controller.openEntry(entry);
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }
                              showTopSnackBar(context, error.toString());
                            }
                          },
                        );
                      }, childCount: browser.entries.length * 2 - 1),
                    ),
                  ),
                if (!browser.hasSources || browser.entries.isEmpty)
                  SliverToBoxAdapter(child: const SizedBox(height: 144)),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _noActiveSourceLabel(BuildContext context) {
  return _isChineseLocale(context) ? '暂无活动音源' : 'No active source';
}

String _folderOrFileLabel(BuildContext context, bool isDirectory) {
  if (_isChineseLocale(context)) {
    return isDirectory ? '文件夹' : '文件';
  }
  return isDirectory ? 'Folder' : 'File';
}

Map<String, LibrarySong> _tracksByVisibleEntryKey(
  List<LibrarySong> tracks,
  List<RemoteEntry> entries,
) {
  final visibleAudioKeys = <String>{
    for (final entry in entries)
      if (entry.kind == RemoteEntryKind.audio)
        '${entry.sourceId}::${entry.path}',
  };
  if (visibleAudioKeys.isEmpty || tracks.isEmpty) {
    return const <String, LibrarySong>{};
  }

  final indexedTracks = <String, LibrarySong>{};
  for (final track in tracks) {
    final key = '${track.sourceId}::${track.remotePath}';
    if (!visibleAudioKeys.contains(key)) {
      continue;
    }
    indexedTracks[key] = track;
    if (indexedTracks.length == visibleAudioKeys.length) {
      break;
    }
  }
  return indexedTracks;
}

bool _isChineseLocale(BuildContext context) {
  return Localizations.localeOf(context).languageCode.toLowerCase() == 'zh';
}

Future<void> _showSongActionsSheet(
  BuildContext context,
  WidgetRef ref,
  LibrarySong song,
  List<LibrarySong> playlist,
  LibraryCatalogState catalog,
) {
  final isFavorite = catalog.favoriteTrackIds.contains(song.id);
  final isLiked = catalog.likedTrackIds.contains(song.id);
  final l10n = AppLocalizations.of(context)!;

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(studioRadiusOf(context, 28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                decoration: BoxDecoration(
                  color: _GlacierPalette.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(
                    studioRadiusOf(context, 28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TrackActionHeader(track: song),
                    const SizedBox(height: 10),
                    _TrackActionTile(
                      icon: Icons.play_arrow_rounded,
                      label: l10n.playAction,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await ref
                            .read(playerControllerProvider.notifier)
                            .playLibrarySong(song, playlist: playlist);
                      },
                    ),
                    _TrackActionTile(
                      icon: Icons.queue_play_next_rounded,
                      label: l10n.playNextAction,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await ref
                            .read(playerControllerProvider.notifier)
                            .addToPlayNext(song);
                      },
                    ),
                    _TrackActionTile(
                      icon: isFavorite
                          ? Icons.bookmark_remove_rounded
                          : Icons.bookmark_add_rounded,
                      label: isFavorite
                          ? l10n.removeFromFavoritesAction
                          : l10n.addToFavoritesAction,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await ref
                            .read(libraryCatalogControllerProvider.notifier)
                            .toggleFavorite(song.id);
                      },
                    ),
                    _TrackActionTile(
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: isLiked
                          ? l10n.removeFromLikedAction
                          : l10n.addToLikedAction,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        await ref
                            .read(libraryCatalogControllerProvider.notifier)
                            .toggleLiked(song.id);
                      },
                    ),
                    _TrackActionTile(
                      icon: Icons.info_outline_rounded,
                      label: l10n.songDetailsTitle,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showTrackDetailsSheet(context, song);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _showTrackDetailsSheet(BuildContext context, LibrarySong song) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final radius = studioRadiusOf(sheetContext, 24);
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _GlacierPalette.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.displayTitle,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurface,
                        size: 22,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      label: l10n.artistLabel,
                      value: song.displayArtist,
                    ),
                    _DetailRow(
                      label: l10n.albumLabel,
                      value: song.displayAlbum,
                    ),
                    _DetailRow(label: l10n.sourceLabel, value: song.sourceName),
                    _DetailRow(
                      label: l10n.filePathLabel,
                      value: song.remotePath,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _GlacierScreen extends StatelessWidget {
  const _GlacierScreen({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _GlacierPalette.background,
      child: SafeArea(bottom: false, child: child),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final buttonRadius = studioRadiusOf(context, 14);
    return InkWell(
      borderRadius: BorderRadius.circular(buttonRadius),
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, color: _GlacierPalette.primary, size: 22),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final buttonRadius = studioRadiusOf(context, 14);
    return Material(
      color: _GlacierPalette.surface.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(buttonRadius),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: _GlacierPalette.primary),
        ),
      ),
    );
  }
}

class _AccentPillButton extends StatelessWidget {
  const _AccentPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final pillRadius = studioRadiusOf(context, 16);
    final background = outlined
        ? Colors.transparent
        : _GlacierPalette.primary.withValues(alpha: 0.12);
    final border = outlined
        ? _GlacierPalette.primary.withValues(alpha: 0.22)
        : _GlacierPalette.primary.withValues(alpha: 0.14);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(pillRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(pillRadius),
        onTap: onTap,
        child: Container(
          padding: studioPaddingOf(
            context,
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(pillRadius),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _GlacierPalette.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: _glacierTextStyle(
                  color: _GlacierPalette.primary,
                  size: 13,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryCategoryCard extends StatelessWidget {
  const _LibraryCategoryCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardRadius = studioRadiusOf(context, 20);
    final iconRadius = studioRadiusOf(context, 14);
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: _GlacierPalette.surface.withValues(alpha: 0.62),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: studioListPaddingOf(
                context,
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cardRadius),
                border: Border.all(
                  color: _GlacierPalette.outline.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(iconRadius),
                      color: accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(icon, size: 22, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: _glacierTextStyle(
                            color: _GlacierPalette.onSurface,
                            size: 16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: _glacierTextStyle(
                            color: _GlacierPalette.onSurfaceVariant,
                            size: 12,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _GlacierPalette.onSurfaceVariant,
                    size: 20,
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

class _SongsPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SongsPinnedHeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  double get minExtent => 92;

  @override
  double get maxExtent => 110;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: _GlacierPalette.background.withValues(alpha: 0.96),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: studioListPaddingOf(
            context,
            const EdgeInsets.fromLTRB(28, 14, 28, 10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurface,
                        size: 27,
                        weight: FontWeight.w700,
                        height: 1.06,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurfaceVariant,
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(mainAxisSize: MainAxisSize.min, children: actions),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SongsPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.title != title || oldDelegate.subtitle != subtitle;
  }
}

class _SongCard extends ConsumerWidget {
  const _SongCard({
    super.key,
    required this.song,
    required this.isFavorite,
    required this.isLiked,
    required this.onTap,
    required this.onFavorite,
    required this.onLiked,
    required this.onMore,
  });

  final LibrarySong song;
  final bool isFavorite;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onLiked;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardRadius = studioRadiusOf(context, 22);
    final coverSize = studioListIconBoxSizeOf(context).clamp(36.0, 46.0);
    final isCurrentTrack = ref.watch(isCurrentTrackIdProvider(song.id));
    return Material(
      color: _GlacierPalette.surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        child: Container(
          padding: studioListPaddingOf(context, const EdgeInsets.all(8)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          child: Row(
            children: [
              _LibraryTrackThumbnail(
                song: song,
                subtitle: '${song.displayArtist} · ${song.displayAlbum}',
                size: coverSize,
                borderRadius: 12,
                isCurrentTrack: isCurrentTrack,
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
                        color: _GlacierPalette.onSurface,
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.displayArtist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurfaceVariant,
                        size: 11,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _CompactIconButton(
                icon: isFavorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                onTap: onFavorite,
                active: isFavorite,
              ),
              _CompactIconButton(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                onTap: onLiked,
                active: isLiked,
              ),
              _CompactIconButton(icon: Icons.more_horiz_rounded, onTap: onMore),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryTrackThumbnail extends StatelessWidget {
  const _LibraryTrackThumbnail({
    required this.song,
    required this.subtitle,
    required this.size,
    required this.borderRadius,
    this.isCurrentTrack = false,
  });

  final LibrarySong song;
  final String subtitle;
  final double size;
  final double borderRadius;
  final bool isCurrentTrack;

  @override
  Widget build(BuildContext context) {
    return TrackCoverThumbnail(
      title: song.displayTitle,
      subtitle: subtitle,
      size: size,
      borderRadius: borderRadius,
      localCoverPath: song.displayLocalCoverPath,
      coverUrl: song.displayCoverUrl,
      isCurrentTrack: isCurrentTrack,
      trackId: song.id,
      sourceId: song.sourceId,
      directoryPath: song.directoryPath,
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final buttonRadius = studioRadiusOf(context, 16);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(buttonRadius),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 20,
            color: active
                ? _GlacierPalette.primary
                : _GlacierPalette.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipRadius = studioRadiusOf(context, 16);
    return Material(
      color: selected
          ? _GlacierPalette.primary.withValues(alpha: 0.12)
          : _GlacierPalette.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(chipRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(chipRadius),
        onTap: onTap,
        child: Container(
          padding: studioPaddingOf(
            context,
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(chipRadius),
          ),
          child: Text(
            label,
            style: _glacierTextStyle(
              color: selected
                  ? _GlacierPalette.primary
                  : _GlacierPalette.onSurfaceVariant,
              size: 13,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PathToolbar extends StatelessWidget {
  const _PathToolbar({
    required this.path,
    required this.canGoUp,
    required this.onRefresh,
    this.onUp,
  });

  final String path;
  final bool canGoUp;
  final VoidCallback? onUp;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _GlacierPalette.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _GlacierPalette.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _glacierTextStyle(
                  color: _GlacierPalette.onSurface,
                  size: 15,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _AccentPillButton(
                    label: l10n.upAction,
                    icon: Icons.arrow_upward_rounded,
                    outlined: true,
                    onTap: onUp ?? () {},
                  ),
                  _AccentPillButton(
                    label: l10n.refreshAction,
                    icon: Icons.refresh_rounded,
                    outlined: true,
                    onTap: onRefresh,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserEntryCard extends ConsumerWidget {
  const _BrowserEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.track,
  });

  final RemoteEntry entry;
  final LibrarySong? track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardRadius = studioRadiusOf(context, 22);
    final isAudio = entry.kind == RemoteEntryKind.audio;
    final isCurrentTrack =
        isAudio &&
        ref.watch(
          isCurrentRemoteTrackProvider(
            CurrentRemoteTrackKey(
              sourceId: entry.sourceId,
              remotePath: entry.path,
            ),
          ),
        );
    final title = track?.displayTitle ?? entry.title;
    final subtitle = isAudio
        ? [track?.displayArtist, track?.displayAlbum]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .join(' · ')
        : entry.path;

    return Material(
      color: isCurrentTrack
          ? _GlacierPalette.primary.withValues(alpha: 0.14)
          : _GlacierPalette.surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: studioListPaddingOf(context, const EdgeInsets.all(14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          child: Row(
            children: [
              _EntryLeading(
                entry: entry,
                track: track,
                isCurrentTrack: isCurrentTrack,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurface,
                        size: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle.isEmpty
                          ? _folderOrFileLabel(context, entry.isDirectory)
                          : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurfaceVariant,
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                entry.isDirectory
                    ? Icons.chevron_right_rounded
                    : Icons.play_arrow_rounded,
                color: _GlacierPalette.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryLeading extends StatelessWidget {
  const _EntryLeading({
    required this.entry,
    required this.track,
    required this.isCurrentTrack,
  });

  final RemoteEntry entry;
  final LibrarySong? track;
  final bool isCurrentTrack;

  @override
  Widget build(BuildContext context) {
    if (entry.kind == RemoteEntryKind.audio) {
      if (track != null) {
        return _LibraryTrackThumbnail(
          song: track!,
          subtitle: track!.displayArtist,
          size: 56,
          borderRadius: 18,
          isCurrentTrack: isCurrentTrack,
        );
      }
      return TrackCoverThumbnail(
        title: entry.title,
        subtitle: entry.path,
        size: 56,
        borderRadius: 18,
        isCurrentTrack: isCurrentTrack,
      );
    }

    final icon = entry.kind == RemoteEntryKind.directory
        ? Icons.folder_rounded
        : Icons.description_rounded;
    final iconRadius = studioRadiusOf(context, 18);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(iconRadius),
        color: _GlacierPalette.primary.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: _GlacierPalette.primary),
    );
  }
}

class _TrackActionHeader extends StatelessWidget {
  const _TrackActionHeader({required this.track});

  final LibrarySong track;

  @override
  Widget build(BuildContext context) {
    final cardRadius = studioRadiusOf(context, 22);
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: studioListPaddingOf(context, const EdgeInsets.all(16)),
          decoration: BoxDecoration(
            color: _GlacierPalette.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: _GlacierPalette.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              _LibraryTrackThumbnail(
                song: track,
                subtitle: track.displayArtist,
                size: 56,
                borderRadius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurface,
                        size: 16,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${track.displayArtist} · ${track.displayAlbum}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurfaceVariant,
                        size: 12,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackActionTile extends StatelessWidget {
  const _TrackActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _GlacierPalette.primary),
      title: Text(
        label,
        style: _glacierTextStyle(
          color: _GlacierPalette.onSurface,
          size: 15,
          weight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _glacierTextStyle(
              color: _GlacierPalette.onSurfaceVariant,
              size: 12,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: _glacierTextStyle(
              color: _GlacierPalette.onSurface,
              size: 14,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGlassCard extends StatelessWidget {
  const _EmptyGlassCard({
    required this.title,
    required this.description,
    this.compact = false,
  });

  final String title;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 24 : 32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.all(compact ? 18 : 24),
          decoration: BoxDecoration(
            color: _GlacierPalette.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(compact ? 24 : 32),
            border: Border.all(
              color: _GlacierPalette.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: _glacierTextStyle(
                  color: _GlacierPalette.onSurface,
                  size: compact ? 20 : 24,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: _glacierTextStyle(
                  color: _GlacierPalette.onSurfaceVariant,
                  size: 14,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlacierCenteredMessage extends StatelessWidget {
  const _GlacierCenteredMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: _glacierTextStyle(
            color: _GlacierPalette.onSurface,
            size: 15,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _GlacierPalette {
  static Color background = const Color(0xFF0A0E1A);
  static Color surface = const Color(0xFF0F1524);
  static Color primary = const Color(0xFF7DD3FC);
  static Color secondary = const Color(0xFF88B4CC);
  static Color tertiary = const Color(0xFFC8A0F0);
  static Color onSurface = const Color(0xFFE0E8F0);
  static Color onSurfaceVariant = const Color(0xFFA0B4C4);
  static Color outline = const Color(0xFF4A6070);

  static void sync(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    background = scheme.surface;
    surface = scheme.surfaceContainer;
    primary = scheme.primary;
    secondary = scheme.secondary;
    tertiary = scheme.tertiary;
    onSurface = scheme.onSurface;
    onSurfaceVariant = scheme.onSurfaceVariant;
    outline = scheme.outline;
  }
}

TextStyle _glacierTextStyle({
  required Color color,
  required double size,
  required FontWeight weight,
  double height = 1.2,
}) {
  return GoogleFonts.inter(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
  );
}
