/// Albums Page - 现代卡片风格 + 响应式布局
/// 基于 example.html 设计
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';
import 'package:music/shared/widgets/cards/cards.dart';
import 'package:music/shared/widgets/cards/card_styles.dart' as card_styles_lib;

import '../../../core/models/library_album.dart';
import '../../../core/models/source_profile.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/generated_cover_art.dart';
import '../application/library_catalog_controller.dart';
import '../application/library_controller.dart';

class AlbumsPageModern extends ConsumerStatefulWidget {
  const AlbumsPageModern({super.key});

  @override
  ConsumerState<AlbumsPageModern> createState() => _AlbumsPageModernState();
}

class _AlbumsPageModernState extends ConsumerState<AlbumsPageModern> {
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
              loading: () => const SizedBox.expand(),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (catalog) {
                final albums = catalog.albumsForSource(
                  selectedSource.id,
                  groupingMode,
                );
                final sourceTracks = catalog.tracks
                    .where((track) => track.sourceId == selectedSource.id)
                    .length;

                return _AlbumsScaffoldModern(
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

class _AlbumsScaffoldModern extends ConsumerWidget {
  const _AlbumsScaffoldModern({
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
    final gridColumns = getGridColumns(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          // 标题和过滤器
          Padding(
            padding: const EdgeInsets.all(CardStyles.contentPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Text(
                  l10n.albumsHeadline,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: CardStyles.sectionSpacing),

                // 音源选择横卷
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(sources.length, (index) {
                      final source = sources[index];
                      final isSelected = source.id == selectedSource.id;
                      final albumCount =
                          catalog?.albumCountForSource(
                            source.id,
                            _groupingModeFor(source.id),
                          ) ??
                          0;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: index < sources.length - 1
                              ? CardStyles.gapXL
                              : 0,
                        ),
                        child: FilterChip(
                          label: Text('${source.name} ($albumCount)'),
                          selected: isSelected,
                          onSelected: onSourceSelected == null
                              ? null
                              : (_) => onSourceSelected!(source.id),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(height: CardStyles.sectionSpacing),

                // 操作按钮行
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
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
                    ),
                    SizedBox(width: CardStyles.gapLarge),
                    Expanded(
                      flex: 2,
                      child: SegmentedButton<LibraryAlbumGroupingMode>(
                        segments: [
                          ButtonSegment(
                            value: LibraryAlbumGroupingMode.folder,
                            label: Text(l10n.folderAlbumsModeLabel),
                            icon: const Icon(Icons.folder_copy_rounded),
                          ),
                          ButtonSegment(
                            value: LibraryAlbumGroupingMode.metadata,
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
                    ),
                  ],
                ),
                SizedBox(height: CardStyles.sectionSpacing),

                // 元信息
                Row(
                  children: [
                    Text(
                      '${albums.length} ${l10n.albumsTabLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(width: CardStyles.gapXL),
                    Text(
                      '$sourceTracks ${l10n.allSongsCollectionTitle}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),

                // 扫描进度
                if (catalog?.isScanning == true) ...[
                  SizedBox(height: CardStyles.sectionSpacing),
                  LinearProgressIndicator(
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  SizedBox(height: CardStyles.gapBase),
                  Text(
                    l10n.scanningProgress(
                      catalog!.scannedDirectoryCount,
                      catalog!.discoveredTrackCount,
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),

          // 相册网格
          if (albums.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CardStyles.contentPadding,
                CardStyles.gapBase,
                CardStyles.contentPadding,
                CardStyles.contentPadding,
              ),
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
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CardStyles.contentPadding,
                vertical: CardStyles.gapBase,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  mainAxisSpacing: CardStyles.gridGap,
                  crossAxisSpacing: CardStyles.gridGap,
                  childAspectRatio: 0.85,
                ),
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final album = albums[index];
                  return ModernAlbumCard(
                    title: album.title,
                    artist: album.artistName,
                    onTap: () => _openAlbumSheet(context, ref, album),
                    coverImage: GeneratedCoverArt(
                      title: album.title,
                      subtitle: album.artistName,
                      size: double.infinity,
                      borderRadius: CardStyles.borderRadiusLarge,
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: CardStyles.contentPadding),
        ],
      ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CardStyles.contentPadding,
              CardStyles.gapXL,
              CardStyles.contentPadding,
              CardStyles.contentPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 专辑头部信息
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AlbumThumbnail(
                      size: 90,
                      backgroundColor: colorScheme.secondaryContainer,
                      borderRadius: CardStyles.borderRadiusXL,
                    ),
                    SizedBox(width: CardStyles.gapXL),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          SizedBox(height: CardStyles.gapSmall),
                          Text(
                            album.artistName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          SizedBox(height: CardStyles.gapSmall),
                          Text(
                            '${album.trackCount} ${l10n.tracksLabel}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: CardStyles.sectionSpacing),

                // 播放和操作按钮
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: PlayButton(
                        onPressed: () {
                          // TODO: 播放整个专辑
                        },
                      ),
                    ),
                    SizedBox(width: CardStyles.gapLarge),
                    CircleIconButton(
                      icon: Icons.bookmark_border_rounded,
                      onPressed: () {},
                    ),
                    SizedBox(width: CardStyles.gapBase),
                    CircleIconButton(
                      icon: Icons.more_vert_rounded,
                      onPressed: () {},
                    ),
                  ],
                ),
                SizedBox(height: CardStyles.sectionSpacing),

                // 曲目列表
                Text(
                  l10n.tracksLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: CardStyles.gapXL),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: ListView.separated(
                    itemCount: album.tracks.length,
                    separatorBuilder: (_, _) =>
                        SizedBox(height: CardStyles.gapSmall),
                    itemBuilder: (context, index) {
                      final track = album.tracks[index];

                      return TrackRowCard(
                        trackNumber: index + 1,
                        title: track.title,
                        artist: track.artistName,
                        onTap: () {
                          ref
                              .read(playerControllerProvider.notifier)
                              .playLibrarySong(track);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: CardStyles.contentPadding),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlbumsEmptyCard extends StatelessWidget {
  const _AlbumsEmptyCard({
    required this.title,
    required this.description,
    required this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: buildCardDecoration(Theme.of(context).colorScheme),
      padding: const EdgeInsets.all(CardStyles.paddingXXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          SizedBox(height: CardStyles.gapLarge),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          SizedBox(height: CardStyles.sectionSpacing),
          FilledButton(onPressed: onPressed, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
