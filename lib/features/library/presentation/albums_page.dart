import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/library_album.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/storage/cover_art_cache_manager.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../../core/widgets/top_snackbar.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/generated_cover_art.dart';
import '../../player/presentation/widgets/track_cover_thumbnail.dart';
import '../../scraper/presentation/manual_scraping_sheet.dart';
import '../../settings/application/app_settings_controller.dart';
import '../../settings/presentation/add_source_page.dart';
import '../../sources/application/source_session_manager.dart';
import '../../sources/application/sources_controller.dart';
import '../application/library_catalog_controller.dart';
import '../application/library_controller.dart';

enum _AlbumViewMode { grid, list }

class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key});

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  String? _selectedSourceId;
  _AlbumViewMode _viewMode = _AlbumViewMode.list;
  int _pageIndex = 0;
  bool _hydratedViewMode = false;

  @override
  Widget build(BuildContext context) {
    _GlacierPalette.sync(context);
    final l10n = AppLocalizations.of(context)!;
    final preferences = ref.watch(appSettingsControllerProvider).valueOrNull;
    final browserAsync = ref.watch(libraryControllerProvider);
    final catalogAsync = ref.watch(libraryCatalogControllerProvider);

    if (!_hydratedViewMode && preferences != null) {
      _viewMode = preferences.albumViewGrid
          ? _AlbumViewMode.grid
          : _AlbumViewMode.list;
      _hydratedViewMode = true;
    }

    void handleViewModeChanged(_AlbumViewMode value) {
      setState(() {
        _viewMode = value;
        _pageIndex = 0;
      });
      ref
          .read(appSettingsControllerProvider.notifier)
          .setAlbumViewGrid(value == _AlbumViewMode.grid);
    }

    return _GlacierScreen(
      child: browserAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: _GlacierPalette.primary),
        ),
        error: (error, _) => _GlacierCenteredMessage(message: error.toString()),
        data: (browser) {
          if (!browser.hasSources) {
            return _AlbumsEmptyState(
              pageTitle: l10n.albumsTabLabel,
              title: l10n.sourceManagementEmptyTitle,
              description: l10n.sourceManagementEmptySummary,
              onScan: () {
                ref
                    .read(libraryCatalogControllerProvider.notifier)
                    .scanAllSources();
              },
              onAddSource: () => showSourceTypePicker(context),
              onOpenSettings: () => context.push('/settings'),
            );
          }

          final selectedSource = _resolveSelectedSource(
            browser.sources,
            browser,
          );
          final groupingMode = LibraryAlbumGroupingMode.folder;

          return catalogAsync.when(
            loading: () => _AlbumsContent(
              sources: browser.sources,
              selectedSource: selectedSource,
              viewMode: _viewMode,
              pageIndex: _pageIndex,
              onViewModeChanged: handleViewModeChanged,
              onPageChanged: (value) {
                setState(() => _pageIndex = value);
              },
              onSourceSelected: (sourceId) {
                setState(() => _selectedSourceId = sourceId);
              },
            ),
            error: (error, _) =>
                _GlacierCenteredMessage(message: error.toString()),
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
                catalog: catalog,
                albums: albums,
                sourceTracks: sourceTracks,
                viewMode: _viewMode,
                pageIndex: _pageIndex,
                onViewModeChanged: handleViewModeChanged,
                onPageChanged: (value) {
                  setState(() => _pageIndex = value);
                },
                onSourceSelected: (sourceId) {
                  setState(() => _selectedSourceId = sourceId);
                },
              );
            },
          );
        },
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

    return browser.selectedSource ?? sources.first;
  }
}

class _AlbumsContent extends ConsumerWidget {
  const _AlbumsContent({
    required this.sources,
    required this.selectedSource,
    required this.viewMode,
    required this.pageIndex,
    required this.onViewModeChanged,
    required this.onPageChanged,
    this.catalog,
    this.albums = const [],
    this.sourceTracks = 0,
    this.onSourceSelected,
  });

  final List<SourceProfile> sources;
  final SourceProfile selectedSource;
  final _AlbumViewMode viewMode;
  final int pageIndex;
  final ValueChanged<_AlbumViewMode> onViewModeChanged;
  final ValueChanged<int> onPageChanged;
  final LibraryCatalogState? catalog;
  final List<LibraryAlbum> albums;
  final int sourceTracks;
  final ValueChanged<String>? onSourceSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final width = MediaQuery.sizeOf(context).width;
    final preferences = ref.watch(appSettingsControllerProvider).valueOrNull;
    final itemsPerPage = _itemsPerPage(width, preferences?.albumPageSize ?? 9);
    final totalPages = (albums.length / itemsPerPage).ceil().clamp(1, 999);
    final currentPage = pageIndex.clamp(0, totalPages - 1);
    final visibleAlbums = albums
        .skip(currentPage * itemsPerPage)
        .take(itemsPerPage)
        .toList(growable: false);
    final albumCountBySource = <String, int>{};
    final trackCountBySource = <String, int>{};
    for (final source in sources) {
      albumCountBySource[source.id] =
          catalog
              ?.albumsForSource(source.id, LibraryAlbumGroupingMode.folder)
              .length ??
          (source.id == selectedSource.id ? albums.length : 0);
      trackCountBySource[source.id] =
          catalog?.tracks
              .where((track) => track.sourceId == source.id)
              .length ??
          (source.id == selectedSource.id ? sourceTracks : 0);
    }

    Future<void> refreshAlbums() {
      if (catalog == null) {
        return ref
            .read(libraryCatalogControllerProvider.notifier)
            .scanAllSources();
      }
      return ref
          .read(libraryCatalogControllerProvider.notifier)
          .rescanSource(selectedSource.id);
    }

    return CustomScrollView(
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.albumsTabLabel,
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
                      onTap: refreshAlbums,
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
                  selectedSource.name,
                  style: _glacierTextStyle(
                    color: _GlacierPalette.onSurfaceVariant,
                    size: 15,
                    weight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sources.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final source = sources[index];
                      final countLabel =
                          '${albumCountBySource[source.id] ?? 0} ${l10n.albumsTabLabel} ${trackCountBySource[source.id] ?? 0} ${l10n.tracksLabel}';
                      return _SourceChip(
                        label: source.name,
                        subtitle: countLabel,
                        selected: source.id == selectedSource.id,
                        onTap: onSourceSelected == null
                            ? null
                            : () => onSourceSelected!(source.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    _ViewModeButton(
                      icon: Icons.grid_view_rounded,
                      selected: viewMode == _AlbumViewMode.grid,
                      size: 34,
                      iconSize: 17,
                      onTap: () => onViewModeChanged(_AlbumViewMode.grid),
                    ),
                    const SizedBox(width: 6),
                    _ViewModeButton(
                      icon: Icons.view_list_rounded,
                      selected: viewMode == _AlbumViewMode.list,
                      size: 34,
                      iconSize: 17,
                      onTap: () => onViewModeChanged(_AlbumViewMode.list),
                    ),
                  ],
                ),
                if (catalog?.isScanning == true) ...[
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: _GlacierPalette.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _GlacierPalette.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        if (albums.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: studioListPaddingOf(
                context,
                const EdgeInsets.fromLTRB(28, 0, 28, 140),
              ),
              child: _EmptyGlassCard(
                title: l10n.albumsEmptyTitle,
                description: l10n.albumsEmptyDescription,
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: studioListPaddingOf(
                context,
                const EdgeInsets.fromLTRB(28, 0, 28, 144),
              ),
              child: Column(
                children: [
                  if (viewMode == _AlbumViewMode.list)
                    _AlbumList(
                      albums: visibleAlbums,
                      onOpenAlbum: (album) =>
                          _openAlbumSheet(context, ref, album, l10n),
                      onPlayAlbum: (album) {
                        if (album.tracks.isEmpty) {
                          return;
                        }
                        ref
                            .read(playerControllerProvider.notifier)
                            .playLibrarySong(
                              album.tracks.first,
                              playlist: album.tracks,
                            );
                      },
                    )
                  else
                    _AlbumGrid(
                      albums: visibleAlbums,
                      maxWidth: width - 56,
                      onOpenAlbum: (album) =>
                          _openAlbumSheet(context, ref, album, l10n),
                      onPlayAlbum: (album) {
                        if (album.tracks.isEmpty) {
                          return;
                        }
                        ref
                            .read(playerControllerProvider.notifier)
                            .playLibrarySong(
                              album.tracks.first,
                              playlist: album.tracks,
                            );
                      },
                    ),
                  if (totalPages > 1) ...[
                    const SizedBox(height: 32),
                    _PaginationRow(
                      currentPage: currentPage,
                      totalPages: totalPages,
                      onPageChanged: onPageChanged,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  int _itemsPerPage(double width, int configuredPageSize) {
    return configuredPageSize.clamp(1, 60).toInt();
  }

  Future<void> _openAlbumSheet(
    BuildContext context,
    WidgetRef ref,
    LibraryAlbum album,
    AppLocalizations l10n,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.72;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                studioRadiusOf(sheetContext, 28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(
                    color: _GlacierPalette.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(
                      studioRadiusOf(sheetContext, 28),
                    ),
                  ),
                  child: Consumer(
                    builder: (context, sheetRef, _) {
                      final catalogState = sheetRef
                          .watch(libraryCatalogControllerProvider)
                          .valueOrNull;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AlbumSheetHeader(album: album),
                          const SizedBox(height: 14),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: album.tracks.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
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

                                return _AlbumTrackTile(
                                  track: track,
                                  isFavorite: isFavorite,
                                  isLiked: isLiked,
                                  onFavorite: () {
                                    sheetRef
                                        .read(
                                          libraryCatalogControllerProvider
                                              .notifier,
                                        )
                                        .toggleFavorite(track.id);
                                  },
                                  onLiked: () {
                                    sheetRef
                                        .read(
                                          libraryCatalogControllerProvider
                                              .notifier,
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
            ),
          ),
        );
      },
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
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;

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
                    _TrackActionHeader(track: track),
                    const SizedBox(height: 10),
                    _TrackActionTile(
                      icon: Icons.play_arrow_rounded,
                      label: l10n.playAction,
                      onTap: () {
                        ref
                            .read(playerControllerProvider.notifier)
                            .playLibrarySong(track, playlist: playlist);
                        Navigator.of(context).pop();
                        if (albumSheetContext.mounted) {
                          Navigator.of(albumSheetContext).pop();
                        }
                      },
                    ),
                    _TrackActionTile(
                      icon: Icons.queue_play_next_rounded,
                      label: l10n.playNextAction,
                      onTap: () {
                        Navigator.of(context).pop();
                        _addAlbumTrackToPlayNext(albumSheetContext, ref, track);
                      },
                    ),
                    _TrackActionTile(
                      icon: isFavorite
                          ? Icons.bookmark_remove_rounded
                          : Icons.bookmark_add_rounded,
                      label: isFavorite
                          ? l10n.removeFromFavoritesAction
                          : l10n.addToFavoritesAction,
                      onTap: () {
                        ref
                            .read(libraryCatalogControllerProvider.notifier)
                            .toggleFavorite(track.id);
                        Navigator.of(context).pop();
                      },
                    ),
                    _TrackActionTile(
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: isLiked
                          ? l10n.removeFromLikedAction
                          : l10n.addToLikedAction,
                      onTap: () {
                        ref
                            .read(libraryCatalogControllerProvider.notifier)
                            .toggleLiked(track.id);
                        Navigator.of(context).pop();
                      },
                    ),
                    _TrackActionTile(
                      icon: Icons.auto_fix_high_rounded,
                      label: l10n.manualScrapingActionLabel,
                      onTap: () {
                        Navigator.of(context).pop();
                        showManualScrapingSheet(
                          context: albumSheetContext,
                          song: track,
                        );
                      },
                    ),
                    _TrackActionTile(
                      icon: Icons.info_outline_rounded,
                      label: l10n.songDetailsTitle,
                      onTap: () {
                        Navigator.of(context).pop();
                        _showTrackDetailsSheet(albumSheetContext, track);
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
    showTopSnackBar(context, error.toString());
    return;
  }

  if (!context.mounted) {
    return;
  }
  showTopSnackBar(context, l10n.addedToPlayNextMessage(track.title));
}

Future<void> _showTrackDetailsSheet(BuildContext context, LibrarySong song) {
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
            borderRadius: BorderRadius.circular(
              studioRadiusOf(sheetContext, 28),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _GlacierPalette.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(
                    studioRadiusOf(sheetContext, 28),
                  ),
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
                    const SizedBox(height: 14),
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

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: _glacierTextStyle(
                  color: selected
                      ? _GlacierPalette.primary
                      : _GlacierPalette.onSurfaceVariant,
                  size: 13,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: _glacierTextStyle(
                  color: selected
                      ? _GlacierPalette.primary.withValues(alpha: 0.84)
                      : _GlacierPalette.onSurfaceVariant.withValues(
                          alpha: 0.84,
                        ),
                  size: 11,
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

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final buttonRadius = studioRadiusOf(context, 16);
    return Material(
      color: selected
          ? _GlacierPalette.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(buttonRadius),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: selected
                ? _GlacierPalette.primary
                : _GlacierPalette.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AlbumList extends StatelessWidget {
  const _AlbumList({
    required this.albums,
    required this.onOpenAlbum,
    required this.onPlayAlbum,
  });

  final List<LibraryAlbum> albums;
  final ValueChanged<LibraryAlbum> onOpenAlbum;
  final ValueChanged<LibraryAlbum> onPlayAlbum;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < albums.length; index++) ...[
          _AlbumListRow(
            album: albums[index],
            onTap: () => onOpenAlbum(albums[index]),
            onPlay: () => onPlayAlbum(albums[index]),
          ),
          if (index != albums.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({
    required this.albums,
    required this.maxWidth,
    required this.onOpenAlbum,
    required this.onPlayAlbum,
  });

  final List<LibraryAlbum> albums;
  final double maxWidth;
  final ValueChanged<LibraryAlbum> onOpenAlbum;
  final ValueChanged<LibraryAlbum> onPlayAlbum;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = maxWidth >= 1200
        ? 5
        : maxWidth >= 900
        ? 4
        : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: albums.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 28,
        childAspectRatio: 0.64,
      ),
      itemBuilder: (context, index) {
        return _AlbumGridCard(
          album: albums[index],
          onOpenAlbum: () => onOpenAlbum(albums[index]),
          onPlayAlbum: () => onPlayAlbum(albums[index]),
        );
      },
    );
  }
}

class _AlbumGridCard extends StatelessWidget {
  const _AlbumGridCard({
    required this.album,
    required this.onOpenAlbum,
    required this.onPlayAlbum,
  });

  final LibraryAlbum album;
  final VoidCallback onOpenAlbum;
  final VoidCallback onPlayAlbum;

  @override
  Widget build(BuildContext context) {
    final cardRadius = studioRadiusOf(context, 24);
    return InkWell(
      borderRadius: BorderRadius.circular(cardRadius),
      onTap: onOpenAlbum,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox.expand(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _AlbumArtwork(
                      album: album,
                      size: 200,
                      borderRadius: 24,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(cardRadius),
                          border: Border.all(
                            color: _GlacierPalette.outline.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Material(
                      color: _GlacierPalette.primary.withValues(alpha: 0.96),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onPlayAlbum,
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 18,
                            color: _GlacierPalette.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _glacierTextStyle(
              color: _GlacierPalette.onSurface,
              size: 16,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            album.artistName,
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
    );
  }
}

class _PaginationRow extends StatelessWidget {
  const _PaginationRow({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageArrowButton(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 0,
          onTap: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
        ),
        const SizedBox(width: 8),
        for (var index = 0; index < totalPages; index++) ...[
          _PageIndexButton(
            label: '${index + 1}',
            selected: index == currentPage,
            onTap: () => onPageChanged(index),
          ),
          if (index != totalPages - 1) const SizedBox(width: 6),
        ],
        const SizedBox(width: 8),
        _PageArrowButton(
          icon: Icons.chevron_right_rounded,
          enabled: currentPage < totalPages - 1,
          onTap: currentPage < totalPages - 1
              ? () => onPageChanged(currentPage + 1)
              : null,
        ),
      ],
    );
  }
}

class _PageIndexButton extends StatelessWidget {
  const _PageIndexButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pageRadius = studioRadiusOf(context, 14);
    return Material(
      color: selected
          ? _GlacierPalette.primary.withValues(alpha: 0.2)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(pageRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(pageRadius),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(pageRadius),
            border: selected
                ? Border.all(
                    color: _GlacierPalette.primary.withValues(alpha: 0.3),
                  )
                : null,
          ),
          child: Text(
            label,
            style: _glacierTextStyle(
              color: selected
                  ? _GlacierPalette.primary
                  : _GlacierPalette.onSurfaceVariant,
              size: 16,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageArrowButton extends StatelessWidget {
  const _PageArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        onPressed: onTap,
        iconSize: 18,
        padding: EdgeInsets.zero,
        splashRadius: 18,
        icon: Icon(
          icon,
          color: enabled
              ? _GlacierPalette.onSurfaceVariant
              : _GlacierPalette.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _AlbumListRow extends StatelessWidget {
  const _AlbumListRow({
    required this.album,
    required this.onTap,
    required this.onPlay,
  });

  final LibraryAlbum album;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final cardRadius = studioRadiusOf(context, 22);
    return Material(
      color: _GlacierPalette.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(cardRadius),
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: _AlbumArtwork(
                album: album,
                size: 84,
                borderRadius: 22,
                clipBorderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: studioListPaddingOf(
                  context,
                  const EdgeInsets.fromLTRB(14, 12, 8, 12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurface,
                        size: 16,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      album.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurfaceVariant,
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${album.trackCount} tracks',
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
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Material(
                color: _GlacierPalette.primary.withValues(alpha: 0.12),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPlay,
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: _GlacierPalette.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumFolderArtwork {
  const _AlbumFolderArtwork({required this.localPath});

  final String localPath;
}

class _AlbumFolderArtworkRequest {
  const _AlbumFolderArtworkRequest({
    required this.sourceId,
    required this.directoryPath,
  });

  final String sourceId;
  final String directoryPath;

  @override
  bool operator ==(Object other) {
    return other is _AlbumFolderArtworkRequest &&
        other.sourceId == sourceId &&
        other.directoryPath == directoryPath;
  }

  @override
  int get hashCode => Object.hash(sourceId, directoryPath);
}

final _albumFolderArtworkProvider =
    FutureProvider.family<_AlbumFolderArtwork?, _AlbumFolderArtworkRequest>((
      ref,
      request,
    ) async {
      final sources = await ref.read(sourcesControllerProvider.future);
      if (sources.isEmpty) {
        return null;
      }
      final source = sources.firstWhere(
        (item) => item.id == request.sourceId,
        orElse: () => sources.first,
      );
      if (source.id != request.sourceId) {
        return null;
      }
      final sessionManager = ref.read(musicSourceSessionManagerProvider);
      final musicSource = await sessionManager.get(source);
      final listing = await musicSource.listFiles(request.directoryPath);
      final imageFiles = listing.entries
          .where((entry) {
            if (entry.isDirectory) {
              return false;
            }
            final ext = p.extension(entry.name).toLowerCase();
            return ext == '.jpg' ||
                ext == '.jpeg' ||
                ext == '.png' ||
                ext == '.webp';
          })
          .toList(growable: false);
      if (imageFiles.isEmpty) {
        return null;
      }

      const preferredNames = ['cover', 'folder', 'front', 'album', 'artwork'];

      imageFiles.sort((left, right) {
        final leftName = p.basenameWithoutExtension(left.name).toLowerCase();
        final rightName = p.basenameWithoutExtension(right.name).toLowerCase();
        final leftPreferred = preferredNames.indexOf(leftName);
        final rightPreferred = preferredNames.indexOf(rightName);
        final leftOrder = leftPreferred == -1 ? 999 : leftPreferred;
        final rightOrder = rightPreferred == -1 ? 999 : rightPreferred;
        if (leftOrder != rightOrder) {
          return leftOrder.compareTo(rightOrder);
        }
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });

      for (final file in imageFiles) {
        final extension = p.extension(file.name).toLowerCase();
        final cacheKey = 'album-folder:${request.sourceId}:${file.path}';
        final cacheManager = CoverArtCacheManager();
        final cachedPath = await cacheManager.cachedPathForKey(
          cacheKey,
          extension: extension,
        );
        if (cachedPath?.isNotEmpty == true) {
          return _AlbumFolderArtwork(localPath: cachedPath!);
        }

        final bytes = await musicSource.readBinaryFile(file.path);
        if (bytes != null && bytes.isNotEmpty) {
          final localPath = await cacheManager.cacheBytes(
            cacheKey,
            bytes,
            extension: extension,
          );
          if (localPath?.isNotEmpty == true) {
            return _AlbumFolderArtwork(localPath: localPath!);
          }
        }
      }
      return null;
    });

class _AlbumArtwork extends ConsumerWidget {
  const _AlbumArtwork({
    required this.album,
    required this.size,
    this.borderRadius = 18,
    this.clipBorderRadius,
  });

  final LibraryAlbum album;
  final double size;
  final double borderRadius;
  final BorderRadiusGeometry? clipBorderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveBorderRadius = clipBorderRadius != null
        ? studioBorderRadiusOf(context, clipBorderRadius!)
        : BorderRadius.circular(studioRadiusOf(context, borderRadius));
    final leadTrack = album.tracks.isEmpty ? null : album.tracks.first;
    if (leadTrack != null) {
      final folderArtwork = ref.watch(
        _albumFolderArtworkProvider(
          _AlbumFolderArtworkRequest(
            sourceId: leadTrack.sourceId,
            directoryPath: leadTrack.directoryPath,
          ),
        ),
      );
      final folderData = folderArtwork.valueOrNull;
      if (folderData != null && folderData.localPath.isNotEmpty) {
        return ClipRRect(
          borderRadius: effectiveBorderRadius,
          child: Image.file(
            File(folderData.localPath),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => GeneratedCoverArt(
              title: album.title,
              subtitle: album.artistName,
              size: size,
              borderRadius: borderRadius,
              clipBorderRadius: clipBorderRadius,
              showFrame: false,
            ),
          ),
        );
      }
    }

    if (leadTrack != null &&
        ((leadTrack.displayLocalCoverPath?.isNotEmpty ?? false) ||
            (leadTrack.displayCoverUrl?.isNotEmpty ?? false))) {
      return TrackCoverThumbnail(
        title: leadTrack.displayTitle,
        subtitle: leadTrack.displayArtist,
        size: size,
        borderRadius: borderRadius,
        clipBorderRadius: clipBorderRadius,
        showFrame: false,
        localCoverPath: leadTrack.displayLocalCoverPath,
        coverUrl: leadTrack.displayCoverUrl,
      );
    }

    return GeneratedCoverArt(
      title: album.title,
      subtitle: album.artistName,
      size: size,
      borderRadius: borderRadius,
      clipBorderRadius: clipBorderRadius,
      showFrame: false,
    );
  }
}

class _AlbumSheetHeader extends StatelessWidget {
  const _AlbumSheetHeader({required this.album});

  final LibraryAlbum album;

  @override
  Widget build(BuildContext context) {
    final cardRadius = studioRadiusOf(context, 22);
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _GlacierPalette.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: _GlacierPalette.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: _AlbumArtwork(album: album, size: 64),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurface,
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      album.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _glacierTextStyle(
                        color: _GlacierPalette.onSurfaceVariant,
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _GlacierPalette.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(
                          studioRadiusOf(context, 14),
                        ),
                      ),
                      child: Text(
                        '${album.trackCount} tracks',
                        style: _glacierTextStyle(
                          color: _GlacierPalette.primary,
                          size: 12,
                          weight: FontWeight.w700,
                        ),
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

class _AlbumTrackTile extends StatelessWidget {
  const _AlbumTrackTile({
    required this.track,
    required this.isFavorite,
    required this.isLiked,
    required this.onFavorite,
    required this.onLiked,
    required this.onTap,
    required this.onMoreOptions,
  });

  final LibrarySong track;
  final bool isFavorite;
  final bool isLiked;
  final VoidCallback onFavorite;
  final VoidCallback onLiked;
  final VoidCallback onTap;
  final VoidCallback onMoreOptions;

  @override
  Widget build(BuildContext context) {
    final cardRadius = studioRadiusOf(context, 22);
    final coverSize = studioListIconBoxSizeOf(context).clamp(36.0, 46.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: _GlacierPalette.surface.withValues(alpha: 0.58),
          child: InkWell(
            onTap: onTap,
            onLongPress: onMoreOptions,
            child: Container(
              padding: studioListPaddingOf(context, const EdgeInsets.all(8)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(cardRadius),
              ),
              child: Row(
                children: [
                  TrackCoverThumbnail(
                    title: track.displayTitle,
                    subtitle: track.displayArtist,
                    size: coverSize,
                    borderRadius: 12,
                    localCoverPath: track.displayLocalCoverPath,
                    coverUrl: track.displayCoverUrl,
                  ),
                  const SizedBox(width: 8),
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
                            size: 14,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.displayArtist,
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
                  _CompactIconButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: onMoreOptions,
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
              TrackCoverThumbnail(
                title: track.displayTitle,
                subtitle: track.displayArtist,
                size: 56,
                borderRadius: 18,
                localCoverPath: track.displayLocalCoverPath,
                coverUrl: track.displayCoverUrl,
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

class _AlbumsEmptyState extends StatelessWidget {
  const _AlbumsEmptyState({
    required this.pageTitle,
    required this.title,
    required this.description,
    required this.onScan,
    required this.onAddSource,
    required this.onOpenSettings,
  });

  final String pageTitle;
  final String title;
  final String description;
  final VoidCallback onScan;
  final VoidCallback onAddSource;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cardRadius = studioRadiusOf(context, 32);
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
                pageTitle,
                style: _glacierTextStyle(
                  color: _GlacierPalette.onSurface,
                  size: 34,
                  weight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
            ),
            _TopIconButton(icon: Icons.radar_rounded, onTap: onScan),
            const SizedBox(width: 8),
            _TopIconButton(icon: Icons.add_link_rounded, onTap: onAddSource),
            const SizedBox(width: 8),
            _TopIconButton(icon: Icons.settings_rounded, onTap: onOpenSettings),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: _glacierTextStyle(
            color: _GlacierPalette.onSurfaceVariant,
            size: 15,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.all(0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cardRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: _GlacierPalette.surface.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(cardRadius),
                    border: Border.all(
                      color: _GlacierPalette.outline.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GeneratedCoverArt(
                        title: title,
                        subtitle: description,
                        size: 180,
                        borderRadius: 26,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: _glacierTextStyle(
                          color: _GlacierPalette.onSurface,
                          size: 26,
                          weight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: _glacierTextStyle(
                          color: _GlacierPalette.onSurfaceVariant,
                          size: 14,
                          weight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
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
}

class _EmptyGlassCard extends StatelessWidget {
  const _EmptyGlassCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final cardRadius = studioRadiusOf(context, 32);
    return ClipRRect(
      borderRadius: BorderRadius.circular(cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _GlacierPalette.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(cardRadius),
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
                  size: 24,
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
  static Color surfaceContainerHigh = const Color(0xFF1A2438);
  static Color primary = const Color(0xFF7DD3FC);
  static Color onPrimary = const Color(0xFF001F2E);
  static Color onSurface = const Color(0xFFE0E8F0);
  static Color onSurfaceVariant = const Color(0xFFA0B4C4);
  static Color outline = const Color(0xFF4A6070);

  static void sync(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    background = scheme.surface;
    surface = scheme.surfaceContainer;
    surfaceContainerHigh = scheme.surfaceContainerHigh;
    primary = scheme.primary;
    onPrimary = scheme.onPrimary;
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
