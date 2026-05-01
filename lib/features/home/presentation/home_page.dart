import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/library_album.dart';
import '../../../core/models/library_song.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../library/application/library_catalog_controller.dart';
import '../../library/application/library_controller.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/cover_art_image.dart';
import '../../settings/presentation/add_source_page.dart';

enum _AlbumViewMode { grid, list }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  _AlbumViewMode _viewMode = _AlbumViewMode.grid;
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    _HomePalette.sync(context);
    final browserAsync = ref.watch(libraryControllerProvider);
    final catalog = ref.watch(libraryCatalogControllerProvider).valueOrNull;
    final browser = browserAsync.valueOrNull;
    final isLoading = browser == null && browserAsync.isLoading;
    final error = browser == null ? browserAsync.error : null;

    return ColoredBox(
      color: _HomePalette.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _HomeContent(
                    browser: browser,
                    catalog: catalog,
                    viewMode: _viewMode,
                    pageIndex: _pageIndex,
                    onViewModeChanged: (value) {
                      setState(() {
                        _viewMode = value;
                        _pageIndex = 0;
                      });
                    },
                    onPageChanged: (value) {
                      setState(() => _pageIndex = value);
                    },
                    onSelectSource: (sourceId) {
                      ref
                          .read(libraryControllerProvider.notifier)
                          .selectSource(sourceId);
                    },
                    onPlayAlbum: (album) async {
                      if (album == null || album.tracks.isEmpty) {
                        return;
                      }
                      await ref
                          .read(playerControllerProvider.notifier)
                          .playLibrarySong(
                            album.tracks.first,
                            playlist: album.tracks,
                          );
                    },
                    onOpenAlbum: (album) {
                      if (album == null) {
                        return;
                      }
                      _showAlbumSheet(album);
                    },
                    onOpenMenu: _openMenuSheet,
                    onOpenSearch: () => context.go('/browser'),
                    onOpenSettings: () => context.push('/settings'),
                    onScanPressed: () {
                      ref
                          .read(libraryCatalogControllerProvider.notifier)
                          .scanAllSources();
                    },
                    onAddSourcePressed: () => showSourceTypePicker(context),
                  ),
                  if (isLoading)
                    Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _HomePalette.primary,
                        ),
                      ),
                    ),
                  if (error != null)
                    Positioned.fill(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: _textStyle(
                              color: _HomePalette.onSurface,
                              size: 14,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMenuSheet() {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final actions = <_HomeMenuAction>[
          _HomeMenuAction(
            icon: Icons.add_link_rounded,
            label: l10n.addSourceAction,
            onTap: () {
              Navigator.of(sheetContext).pop();
              showSourceTypePicker(context);
            },
          ),
          _HomeMenuAction(
            icon: Icons.radar_rounded,
            label: l10n.scanLibraryAction,
            onTap: () {
              Navigator.of(sheetContext).pop();
              ref
                  .read(libraryCatalogControllerProvider.notifier)
                  .scanAllSources();
            },
          ),
          _HomeMenuAction(
            icon: Icons.library_music_rounded,
            label: l10n.libraryTitle,
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.go('/collection');
            },
          ),
          _HomeMenuAction(
            icon: Icons.tune_rounded,
            label: l10n.settingsPageTitle,
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push('/settings');
            },
          ),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: _HomePalette.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _HomePalette.outline.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      for (final action in actions)
                        ListTile(
                          leading: Icon(
                            action.icon,
                            color: _HomePalette.primary,
                          ),
                          title: Text(
                            action.label,
                            style: _textStyle(
                              color: _HomePalette.onSurface,
                              size: 16,
                              weight: FontWeight.w500,
                            ),
                          ),
                          onTap: action.onTap,
                        ),
                      const SizedBox(height: 8),
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

  Future<void> _showAlbumSheet(LibraryAlbum album) {
    final playerState = ref.read(playerControllerProvider);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final coverTrack = album.tracks.first;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: _HomePalette.surface.withValues(alpha: 0.95),
                    border: Border.all(
                      color: _HomePalette.outline.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 86,
                              height: 86,
                              child: _AlbumArtwork(
                                title: album.title,
                                artist: album.artistName,
                                localCoverPath:
                                    coverTrack.displayLocalCoverPath,
                                coverUrl: coverTrack.displayCoverUrl,
                                borderRadius: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    album.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: _textStyle(
                                      color: _HomePalette.onSurface,
                                      size: 24,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    album.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _textStyle(
                                      color: _HomePalette.onSurfaceVariant,
                                      size: 15,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${album.trackCount} tracks',
                                    style: _textStyle(
                                      color: _HomePalette.onSurfaceVariant,
                                      size: 13,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _HomePalette.primary,
                            foregroundColor: _HomePalette.onPrimary,
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () async {
                            await ref
                                .read(playerControllerProvider.notifier)
                                .playLibrarySong(
                                  album.tracks.first,
                                  playlist: album.tracks,
                                );
                            if (!sheetContext.mounted) {
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            'Play album',
                            style: _textStyle(
                              color: _HomePalette.onPrimary,
                              size: 15,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: album.tracks.length,
                          separatorBuilder: (context, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final track = album.tracks[index];
                            final isCurrentTrack =
                                playerState.currentTrack?.id == track.id;

                            return Material(
                              color: isCurrentTrack
                                  ? _HomePalette.primary.withValues(alpha: 0.12)
                                  : _HomePalette.surfaceContainerLow.withValues(
                                      alpha: 0.92,
                                    ),
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () async {
                                  await ref
                                      .read(playerControllerProvider.notifier)
                                      .playLibrarySong(
                                        track,
                                        playlist: album.tracks,
                                      );
                                  if (!sheetContext.mounted) {
                                    return;
                                  }
                                  Navigator.of(sheetContext).pop();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 52,
                                        height: 52,
                                        child: _AlbumArtwork(
                                          title: track.displayTitle,
                                          artist: track.displayArtist,
                                          localCoverPath:
                                              track.displayLocalCoverPath,
                                          coverUrl: track.displayCoverUrl,
                                          borderRadius: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              track.displayTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: _textStyle(
                                                color: _HomePalette.onSurface,
                                                size: 15,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              track.displayArtist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: _textStyle(
                                                color: _HomePalette
                                                    .onSurfaceVariant,
                                                size: 13,
                                                weight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.play_arrow_rounded,
                                        color: _HomePalette.onSurfaceVariant,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({
    required this.browser,
    required this.catalog,
    required this.viewMode,
    required this.pageIndex,
    required this.onViewModeChanged,
    required this.onPageChanged,
    required this.onSelectSource,
    required this.onPlayAlbum,
    required this.onOpenAlbum,
    required this.onOpenMenu,
    required this.onOpenSearch,
    required this.onOpenSettings,
    required this.onScanPressed,
    required this.onAddSourcePressed,
  });

  final LibraryViewState? browser;
  final LibraryCatalogState? catalog;
  final _AlbumViewMode viewMode;
  final int pageIndex;
  final ValueChanged<_AlbumViewMode> onViewModeChanged;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onSelectSource;
  final ValueChanged<LibraryAlbum?> onPlayAlbum;
  final ValueChanged<LibraryAlbum?> onOpenAlbum;
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenSettings;
  final VoidCallback onScanPressed;
  final VoidCallback onAddSourcePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceCards = _buildSourceCards();
    final recentAlbums = _buildRecentAlbums();
    final width = MediaQuery.sizeOf(context).width;
    final itemsPerPage = _itemsPerPage(width);
    final totalPages = (recentAlbums.length / itemsPerPage).ceil().clamp(
      1,
      999,
    );
    final currentPage = pageIndex.clamp(0, totalPages - 1);
    final visibleAlbums = recentAlbums
        .skip(currentPage * itemsPerPage)
        .take(itemsPerPage)
        .toList(growable: false);

    return RefreshIndicator(
      color: _HomePalette.primary,
      backgroundColor: _HomePalette.surface,
      onRefresh: () async => onScanPressed(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          width >= 1024 ? 40 : 24,
          26,
          width >= 1024 ? 40 : 24,
          144,
        ),
        children: [
          Row(
            children: [
              _TopBarIconButton(icon: Icons.menu_rounded, onTap: onOpenMenu),
              const Spacer(),
              _TopBarIconButton(
                icon: Icons.search_rounded,
                onTap: onOpenSearch,
              ),
              const SizedBox(width: 8),
              _TopBarIconButton(
                icon: Icons.settings_rounded,
                onTap: onOpenSettings,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _greeting(),
            style: _textStyle(
              color: _HomePalette.onSurface,
              size: width >= 1024 ? 54 : 44,
              weight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your cloud library is synced and ready.',
            style: _textStyle(
              color: _HomePalette.onSurfaceVariant,
              size: 16,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 54),
          _SectionHeader(title: 'Cloud Sources'),
          const SizedBox(height: 22),
          SizedBox(
            height: 214,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sourceCards.length,
              separatorBuilder: (context, _) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final card = sourceCards[index];
                return SizedBox(
                  width: width >= 1024 ? 320 : 280,
                  child: _SourceCard(
                    model: card,
                    onTap: card.source == null
                        ? onAddSourcePressed
                        : () => onSelectSource(card.source!.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 66),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: _SectionHeader(title: 'Recently Added')),
              const SizedBox(width: 12),
              _ViewModeButton(
                icon: Icons.grid_view_rounded,
                selected: viewMode == _AlbumViewMode.grid,
                onTap: () => onViewModeChanged(_AlbumViewMode.grid),
              ),
              const SizedBox(width: 8),
              _ViewModeButton(
                icon: Icons.view_list_rounded,
                selected: viewMode == _AlbumViewMode.list,
                onTap: () => onViewModeChanged(_AlbumViewMode.list),
              ),
            ],
          ),
          const SizedBox(height: 26),
          if (viewMode == _AlbumViewMode.list)
            _AlbumList(
              albums: visibleAlbums,
              onPlayAlbum: onPlayAlbum,
              onOpenAlbum: onOpenAlbum,
            )
          else
            _AlbumGrid(
              albums: visibleAlbums,
              maxWidth: width - (width >= 1024 ? 80 : 48),
              onPlayAlbum: onPlayAlbum,
              onOpenAlbum: onOpenAlbum,
            ),
          if (totalPages > 1) ...[
            const SizedBox(height: 42),
            _PaginationRow(
              currentPage: currentPage,
              totalPages: totalPages,
              onPageChanged: onPageChanged,
            ),
          ],
        ],
      ),
    );
  }

  List<_SourceCardModel> _buildSourceCards() {
    final sources = browser?.sources ?? const <SourceProfile>[];
    if (sources.isEmpty) {
      return [_SourceCardModel.addSource()];
    }

    final selectedSourceId = browser?.selectedSource?.id;
    final trackCountBySource = <String, int>{};
    final albumCountBySource = <String, int>{};
    for (final track in catalog?.tracks ?? const <LibrarySong>[]) {
      trackCountBySource.update(
        track.sourceId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    for (final album in catalog?.albums ?? const <LibraryAlbum>[]) {
      albumCountBySource.update(
        album.sourceId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final totalTracks = trackCountBySource.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    return [
      for (var index = 0; index < sources.length; index++)
        _SourceCardModel(
          source: sources[index],
          title: sources[index].name,
          subtitle: _sourceSubtitle(
            trackCountBySource[sources[index].id] ?? 0,
            albumCountBySource[sources[index].id] ?? 0,
            index,
          ),
          status: _sourceStatus(sources[index]),
          progress: _sourceProgress(
            trackCountBySource[sources[index].id] ?? 0,
            totalTracks,
            index,
          ),
          icon: _sourceIcon(sources[index].protocol),
          accent: _HomePalette.accentAt(index),
          highlighted:
              sources[index].id == selectedSourceId ||
              (selectedSourceId == null && index == 0),
        ),
    ];
  }

  String _sourceSubtitle(int trackCount, int albumCount, int index) {
    if (trackCount > 0 || albumCount > 0) {
      return '$trackCount tracks / $albumCount albums';
    }

    const fallback = ['45 GB / 100 GB', '12 GB / 50 GB', '2 GB / 5 GB'];
    return fallback[index % fallback.length];
  }

  String _sourceStatus(SourceProfile source) {
    if (catalog?.isScanning == true &&
        catalog?.currentSource?.id == source.id) {
      return 'Scanning now';
    }

    final lastScannedAt = catalog?.lastScannedAt;
    if (lastScannedAt != null) {
      return 'Updated ${_relativeTime(lastScannedAt)}';
    }

    return 'Ready to sync';
  }

  double _sourceProgress(int trackCount, int totalTracks, int index) {
    if (totalTracks > 0 && trackCount > 0) {
      return (trackCount / totalTracks).clamp(0.12, 1).toDouble();
    }

    const fallback = [0.45, 0.24, 0.40, 0.32];
    return fallback[index % fallback.length];
  }

  List<_AlbumModel> _buildRecentAlbums() {
    final albums = List<LibraryAlbum>.of(catalog?.albums ?? const []);
    if (albums.isEmpty) {
      return _fallbackAlbums;
    }

    albums.sort((left, right) {
      final leftDate = _albumModifiedAt(left);
      final rightDate = _albumModifiedAt(right);
      final byDate = rightDate.compareTo(leftDate);
      if (byDate != 0) {
        return byDate;
      }
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });

    return albums
        .map(
          (album) => _AlbumModel(
            album: album,
            title: album.title,
            artist: album.artistName,
            localCoverPath: album.tracks.first.displayLocalCoverPath,
            coverUrl: album.tracks.first.displayCoverUrl,
          ),
        )
        .toList(growable: false);
  }

  DateTime _albumModifiedAt(LibraryAlbum album) {
    var latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final track in album.tracks) {
      final modifiedAt = track.modifiedAt;
      if (modifiedAt != null && modifiedAt.isAfter(latest)) {
        latest = modifiedAt;
      }
    }
    return latest;
  }

  int _itemsPerPage(double width) {
    if (viewMode == _AlbumViewMode.list) {
      return width >= 1024 ? 6 : 4;
    }

    if (width >= 1200) {
      return 10;
    }
    if (width >= 900) {
      return 8;
    }
    if (width >= 680) {
      return 6;
    }
    return 4;
  }

  String _relativeTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes.clamp(1, 59);
      return '${minutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: _HomePalette.primary, size: 30),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: _textStyle(
        color: _HomePalette.onSurface,
        size: 26,
        weight: FontWeight.w500,
        height: 1.1,
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.model, required this.onTap});

  final _SourceCardModel model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = model.highlighted
        ? _HomePalette.surface.withValues(alpha: 0.75)
        : _HomePalette.surface.withValues(alpha: 0.6);
    final borderColor = model.highlighted
        ? model.accent.withValues(alpha: 0.18)
        : _HomePalette.outline.withValues(alpha: 0.45);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: model.highlighted ? 24 : 18,
          sigmaY: model.highlighted ? 24 : 18,
        ),
        child: Material(
          color: background,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor),
                boxShadow: model.highlighted
                    ? [
                        BoxShadow(
                          color: model.accent.withValues(alpha: 0.06),
                          blurRadius: 30,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: model.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(model.icon, color: model.accent, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _textStyle(
                                color: _HomePalette.onSurface,
                                size: 17,
                                weight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              model.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _textStyle(
                                color: _HomePalette.onSurfaceVariant,
                                size: 12,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: model.progress,
                      minHeight: 7,
                      backgroundColor: _HomePalette.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(model.accent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      model.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _textStyle(
                        color: _HomePalette.onSurfaceVariant,
                        size: 12,
                        weight: FontWeight.w500,
                      ),
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

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _HomePalette.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: selected
                ? _HomePalette.primary
                : _HomePalette.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({
    required this.albums,
    required this.maxWidth,
    required this.onPlayAlbum,
    required this.onOpenAlbum,
  });

  final List<_AlbumModel> albums;
  final double maxWidth;
  final ValueChanged<LibraryAlbum?> onPlayAlbum;
  final ValueChanged<LibraryAlbum?> onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = maxWidth >= 1200
        ? 5
        : maxWidth >= 900
        ? 4
        : 3;
    const gap = 24.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: albums.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: gap,
        mainAxisSpacing: 28,
        childAspectRatio: 0.64,
      ),
      itemBuilder: (context, index) {
        final album = albums[index];
        return _AlbumGridCard(
          model: album,
          onPlayAlbum: () => onPlayAlbum(album.album),
          onOpenAlbum: () => onOpenAlbum(album.album),
        );
      },
    );
  }
}

class _AlbumGridCard extends StatelessWidget {
  const _AlbumGridCard({
    required this.model,
    required this.onPlayAlbum,
    required this.onOpenAlbum,
  });

  final _AlbumModel model;
  final VoidCallback onPlayAlbum;
  final VoidCallback onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final canInteract = model.album != null;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: canInteract ? onOpenAlbum : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox.expand(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _HomePalette.outline.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(0.5),
                        child: _AlbumArtwork(
                          title: model.title,
                          artist: model.artist,
                          localCoverPath: model.localCoverPath,
                          coverUrl: model.coverUrl,
                          fallbackImageUrl: model.fallbackImageUrl,
                          borderRadius: 23.5,
                        ),
                      ),
                    ),
                  ),
                  if (canInteract)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Material(
                        color: _HomePalette.primary.withValues(alpha: 0.96),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onPlayAlbum,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: _HomePalette.onPrimary,
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
            model.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _textStyle(
              color: _HomePalette.onSurface,
              size: 16,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            model.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _textStyle(
              color: _HomePalette.onSurfaceVariant,
              size: 12,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumList extends StatelessWidget {
  const _AlbumList({
    required this.albums,
    required this.onPlayAlbum,
    required this.onOpenAlbum,
  });

  final List<_AlbumModel> albums;
  final ValueChanged<LibraryAlbum?> onPlayAlbum;
  final ValueChanged<LibraryAlbum?> onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < albums.length; index++) ...[
          _AlbumListRow(
            model: albums[index],
            onPlayAlbum: () => onPlayAlbum(albums[index].album),
            onOpenAlbum: () => onOpenAlbum(albums[index].album),
          ),
          if (index != albums.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _AlbumListRow extends StatelessWidget {
  const _AlbumListRow({
    required this.model,
    required this.onPlayAlbum,
    required this.onOpenAlbum,
  });

  final _AlbumModel model;
  final VoidCallback onPlayAlbum;
  final VoidCallback onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final canInteract = model.album != null;

    return Material(
      color: _HomePalette.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: canInteract ? onOpenAlbum : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: _AlbumArtwork(
                  title: model.title,
                  artist: model.artist,
                  localCoverPath: model.localCoverPath,
                  coverUrl: model.coverUrl,
                  fallbackImageUrl: model.fallbackImageUrl,
                  borderRadius: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _textStyle(
                        color: _HomePalette.onSurface,
                        size: 16,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      model.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _textStyle(
                        color: _HomePalette.onSurfaceVariant,
                        size: 13,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (canInteract)
                Material(
                  color: _HomePalette.primary.withValues(alpha: 0.12),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onPlayAlbum,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: _HomePalette.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    return Material(
      color: selected
          ? _HomePalette.primary.withValues(alpha: 0.2)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? Border.all(color: _HomePalette.primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Text(
            label,
            style: _textStyle(
              color: selected
                  ? _HomePalette.primary
                  : _HomePalette.onSurfaceVariant,
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
              ? _HomePalette.onSurfaceVariant
              : _HomePalette.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  const _AlbumArtwork({
    required this.title,
    required this.artist,
    required this.borderRadius,
    this.localCoverPath,
    this.coverUrl,
    this.fallbackImageUrl,
  });

  final String title;
  final String artist;
  final String? localCoverPath;
  final String? coverUrl;
  final String? fallbackImageUrl;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = studioRadiusOf(context, borderRadius);
    if (fallbackImageUrl != null && fallbackImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: Image.network(
          fallbackImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _generatedArtwork(context, 200);
          },
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return CoverArtImage(
          title: title,
          subtitle: artist,
          size: size <= 0 ? 120 : size,
          borderRadius: borderRadius,
          localCoverPath: localCoverPath,
          coverUrl: coverUrl,
        );
      },
    );
  }

  Widget _generatedArtwork(BuildContext context, double size) {
    return CoverArtImage(
      title: title,
      subtitle: artist,
      size: size,
      borderRadius: borderRadius,
      localCoverPath: localCoverPath,
      coverUrl: coverUrl,
    );
  }
}

class _HomeMenuAction {
  const _HomeMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _SourceCardModel {
  const _SourceCardModel({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.progress,
    required this.icon,
    required this.accent,
    required this.highlighted,
    this.source,
  });

  factory _SourceCardModel.addSource() {
    return _SourceCardModel(
      title: 'Add source',
      subtitle: 'Connect a cloud library',
      status: 'Open source picker',
      progress: 0.22,
      icon: Icons.add_link_rounded,
      accent: _HomePalette.primary,
      highlighted: true,
    );
  }

  final SourceProfile? source;
  final String title;
  final String subtitle;
  final String status;
  final double progress;
  final IconData icon;
  final Color accent;
  final bool highlighted;
}

class _AlbumModel {
  const _AlbumModel({
    required this.title,
    required this.artist,
    this.album,
    this.localCoverPath,
    this.coverUrl,
    this.fallbackImageUrl,
  });

  final LibraryAlbum? album;
  final String title;
  final String artist;
  final String? localCoverPath;
  final String? coverUrl;
  final String? fallbackImageUrl;
}

class _HomePalette {
  static Color background = const Color(0xFF0A0E1A);
  static Color surface = const Color(0xFF0F1524);
  static Color surfaceContainerLow = const Color(0xFF111828);
  static Color surfaceContainerHighest = const Color(0xFF202C42);
  static Color primary = const Color(0xFF7DD3FC);
  static Color onPrimary = const Color(0xFF001F2E);
  static Color secondary = const Color(0xFF88B4CC);
  static Color tertiary = const Color(0xFFC8A0F0);
  static Color onSurface = const Color(0xFFE0E8F0);
  static Color onSurfaceVariant = const Color(0xFFA0B4C4);
  static Color outline = const Color(0xFF4A6070);

  static void sync(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    background = scheme.surface;
    surface = scheme.surfaceContainer;
    surfaceContainerLow = scheme.surfaceContainerLow;
    surfaceContainerHighest = scheme.surfaceContainerHighest;
    primary = scheme.primary;
    onPrimary = scheme.onPrimary;
    secondary = scheme.secondary;
    tertiary = scheme.tertiary;
    onSurface = scheme.onSurface;
    onSurfaceVariant = scheme.onSurfaceVariant;
    outline = scheme.outline;
  }

  static Color accentAt(int index) {
    final accents = [primary, tertiary, secondary];
    return accents[index % accents.length];
  }
}

TextStyle _textStyle({
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

IconData _sourceIcon(SourceProtocol protocol) {
  return switch (protocol) {
    SourceProtocol.webdav => Icons.cloud_queue_rounded,
    SourceProtocol.sftp => Icons.folder_shared_rounded,
    SourceProtocol.ftp => Icons.cloud_download_rounded,
    SourceProtocol.samba => Icons.storage_rounded,
    SourceProtocol.cloudDrive => Icons.headset_rounded,
  };
}

const List<_AlbumModel> _fallbackAlbums = [
  _AlbumModel(
    title: 'Midnight Synthesis',
    artist: 'Various Artists',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBLBGnc3B6_cpK4X2dfnJZwaQ_M46TK7bnaIifz2Ht6BszKhI0wt6uWcCC1lnGpL3Kg_bVXfioukQB7c3QyJfP__SYbKb2qiJsv8FuURR6U8-vsRPcih3WQyFTEM-CoSj6tf8F6SrtoxCjrUrMcLKr8zJ207ups41ey-vJV1xqA7iY_ptjeWQWlIgohAJ3SSXtjxk-Zi-I8agDdz7KTbM2aXrPSpOOkFTm1_8q9oSnq7T9G853wSdsz8n1lUqA2OTLjW4RaG3oJHFg',
  ),
  _AlbumModel(
    title: 'Echoes of Ice',
    artist: 'Nordic Soundscapes',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCb4MlCYAhMOIH8gEcYf2hGORXrNh5SfkTkZda7aiuLGqqxE1nOTnnncDC5HenvRykKiyVUxHXL64--mzDIA9c3hmdm_0alekZjS72g-t_xhJ_W_7DnLhTUpzjUAbDteUyHgAPddWGof18D1W85msz0Q7VOkMl10-XBiDadSIb9AhJZob8-JRbQk6TtBB49OyNo38rrqkT73GGY7Lf4EBh4KiNBP1qNUBFtcTcL-KIIHVCa_T4qivs8jY4P1AlPh7HcDAnRzKzKXfo',
  ),
  _AlbumModel(
    title: 'Luminous Tides',
    artist: 'Ambient Collective',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuAyPinIwLER_lPnxOYSXN1-d4rr1beqNPILVsCB7Jmgevio0nKv1-VaxfmA2hHK4INQ1RR37xrBUu58gySBlYIj5S1HDZy4-2WkRs2AGrZMFRdmZF0yjU6M9TF0NGz05XkHm_Sv2RzPiQzkJVzZdOUjgnaafW41aHwzSBmr7Lnu0FtVZiK6FWumu0FHEoSgG_IpsUFRQKtVYHONRWzJk1hiDfLDFBAEbXVis8JFo_B1W4zaYhDO5VCUPsY88W5a0vXyi9IctyprYCY',
  ),
  _AlbumModel(
    title: 'Deep State',
    artist: 'Electronic Sessions',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuA0drEiSJPzI4qiUJ3ObCxuxvlb_SVTfNaZGIB6J36Pa5xWx8_Hdall5y5ncnucTyBbLXX6tdBaL8JpYJzxxR-veBQkX6ouew9w0CEdSxurBh2yu3RvWdURuucv2D2Xa59GbDUI1-EqRebt25clAyIaJyBlqNUSi1NrKL-HjiTpLz6ipVOkHcpnj37hmt9DIvhcSTiPHsJiDCkBYs5zx6m187WALs7_3GhDS1nTiyRIlKRsG7HT_xMgFNItaB5Nisqv_vUHbPon0II',
  ),
  _AlbumModel(
    title: 'Midnight Synthesis',
    artist: 'Various Artists',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBLBGnc3B6_cpK4X2dfnJZwaQ_M46TK7bnaIifz2Ht6BszKhI0wt6uWcCC1lnGpL3Kg_bVXfioukQB7c3QyJfP__SYbKb2qiJsv8FuURR6U8-vsRPcih3WQyFTEM-CoSj6tf8F6SrtoxCjrUrMcLKr8zJ207ups41ey-vJV1xqA7iY_ptjeWQWlIgohAJ3SSXtjxk-Zi-I8agDdz7KTbM2aXrPSpOOkFTm1_8q9oSnq7T9G853wSdsz8n1lUqA2OTLjW4RaG3oJHFg',
  ),
  _AlbumModel(
    title: 'Echoes of Ice',
    artist: 'Nordic Soundscapes',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCb4MlCYAhMOIH8gEcYf2hGORXrNh5SfkTkZda7aiuLGqqxE1nOTnnncDC5HenvRykKiyVUxHXL64--mzDIA9c3hmdm_0alekZjS72g-t_xhJ_W_7DnLhTUpzjUAbDteUyHgAPddWGof18D1W85msz0Q7VOkMl10-XBiDadSIb9AhJZob8-JRbQk6TtBB49OyNo38rrqkT73GGY7Lf4EBh4KiNBP1qNUBFtcTcL-KIIHVCa_T4qivs8jY4P1AlPh7HcDAnRzKzKXfo',
  ),
  _AlbumModel(
    title: 'Luminous Tides',
    artist: 'Ambient Collective',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuAyPinIwLER_lPnxOYSXN1-d4rr1beqNPILVsCB7Jmgevio0nKv1-VaxfmA2hHK4INQ1RR37xrBUu58gySBlYIj5S1HDZy4-2WkRs2AGrZMFRdmZF0yjU6M9TF0NGz05XkHm_Sv2RzPiQzkJVzZdOUjgnaafW41aHwzSBmr7Lnu0FtVZiK6FWumu0FHEoSgG_IpsUFRQKtVYHONRWzJk1hiDfLDFBAEbXVis8JFo_B1W4zaYhDO5VCUPsY88W5a0vXyi9IctyprYCY',
  ),
  _AlbumModel(
    title: 'Deep State',
    artist: 'Electronic Sessions',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuA0drEiSJPzI4qiUJ3ObCxuxvlb_SVTfNaZGIB6J36Pa5xWx8_Hdall5y5ncnucTyBbLXX6tdBaL8JpYJzxxR-veBQkX6ouew9w0CEdSxurBh2yu3RvWdURuucv2D2Xa59GbDUI1-EqRebt25clAyIaJyBlqNUSi1NrKL-HjiTpLz6ipVOkHcpnj37hmt9DIvhcSTiPHsJiDCkBYs5zx6m187WALs7_3GhDS1nTiyRIlKRsG7HT_xMgFNItaB5Nisqv_vUHbPon0II',
  ),
  _AlbumModel(
    title: 'Midnight Synthesis',
    artist: 'Various Artists',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBLBGnc3B6_cpK4X2dfnJZwaQ_M46TK7bnaIifz2Ht6BszKhI0wt6uWcCC1lnGpL3Kg_bVXfioukQB7c3QyJfP__SYbKb2qiJsv8FuURR6U8-vsRPcih3WQyFTEM-CoSj6tf8F6SrtoxCjrUrMcLKr8zJ207ups41ey-vJV1xqA7iY_ptjeWQWlIgohAJ3SSXtjxk-Zi-I8agDdz7KTbM2aXrPSpOOkFTm1_8q9oSnq7T9G853wSdsz8n1lUqA2OTLjW4RaG3oJHFg',
  ),
  _AlbumModel(
    title: 'Echoes of Ice',
    artist: 'Nordic Soundscapes',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCb4MlCYAhMOIH8gEcYf2hGORXrNh5SfkTkZda7aiuLGqqxE1nOTnnncDC5HenvRykKiyVUxHXL64--mzDIA9c3hmdm_0alekZjS72g-t_xhJ_W_7DnLhTUpzjUAbDteUyHgAPddWGof18D1W85msz0Q7VOkMl10-XBiDadSIb9AhJZob8-JRbQk6TtBB49OyNo38rrqkT73GGY7Lf4EBh4KiNBP1qNUBFtcTcL-KIIHVCa_T4qivs8jY4P1AlPh7HcDAnRzKzKXfo',
  ),
  _AlbumModel(
    title: 'Luminous Tides',
    artist: 'Ambient Collective',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuAyPinIwLER_lPnxOYSXN1-d4rr1beqNPILVsCB7Jmgevio0nKv1-VaxfmA2hHK4INQ1RR37xrBUu58gySBlYIj5S1HDZy4-2WkRs2AGrZMFRdmZF0yjU6M9TF0NGz05XkHm_Sv2RzPiQzkJVzZdOUjgnaafW41aHwzSBmr7Lnu0FtVZiK6FWumu0FHEoSgG_IpsUFRQKtVYHONRWzJk1hiDfLDFBAEbXVis8JFo_B1W4zaYhDO5VCUPsY88W5a0vXyi9IctyprYCY',
  ),
  _AlbumModel(
    title: 'Deep State',
    artist: 'Electronic Sessions',
    fallbackImageUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuA0drEiSJPzI4qiUJ3ObCxuxvlb_SVTfNaZGIB6J36Pa5xWx8_Hdall5y5ncnucTyBbLXX6tdBaL8JpYJzxxR-veBQkX6ouew9w0CEdSxurBh2yu3RvWdURuucv2D2Xa59GbDUI1-EqRebt25clAyIaJyBlqNUSi1NrKL-HjiTpLz6ipVOkHcpnj37hmt9DIvhcSTiPHsJiDCkBYs5zx6m187WALs7_3GhDS1nTiyRIlKRsG7HT_xMgFNItaB5Nisqv_vUHbPon0II',
  ),
];
