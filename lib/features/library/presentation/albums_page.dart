import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';
import 'package:music/shared/widgets/modern_ui/modern_ui.dart';

import '../../../core/models/library_album.dart';
import '../../../core/models/source_profile.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/generated_cover_art.dart';
import '../application/library_catalog_controller.dart';
import '../application/library_controller.dart';

/// 现代化相册页面 - 按照 example.html 设计
/// 结构: 标题 + 源切换 + 响应式网格 (2/3/4 列)
class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key});

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  String? _selectedSourceId;
  final Map<String, LibraryAlbumGroupingMode> _groupingBySourceId = {};

  @override
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
              return _buildEmptyState(context, l10n);
            }

            final sources = browser.sources;
            final selectedSource = _resolveSelectedSource(sources, browser);
            final groupingMode = _groupingBySourceId[selectedSource.id] ?? LibraryAlbumGroupingMode.folder;

            return catalogAsync.when(
              loading: () => _buildLoading(sources, selectedSource),
              error: (error, _) => _buildError(error),
              data: (catalog) {
                final albums = catalog.albumsForSource(selectedSource.id, groupingMode);

                return Column(
                  children: [
                    // Header with title and source switcher
                    _buildHeader(
                      context,
                      l10n,
                      sources,
                      selectedSource,
                      onSourceChanged: (sourceId) {
                        setState(() => _selectedSourceId = sourceId);
                      },
                    ),

                    // Album Grid
                    Expanded(
                      child: albums.isEmpty
                          ? _buildNoAlbums(context, l10n)
                          : _buildAlbumGrid(context, albums),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Header with title and source switcher
  Widget _buildHeader(
    BuildContext context,
    AppLocalizations l10n,
    List<SourceProfile> sources,
    SourceProfile selectedSource, {
    required ValueChanged<String> onSourceChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            l10n.albumsTabLabel,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 10),

          // Source switcher (if multiple sources)
          if (sources.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sources
                    .map(
                      (source) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildSourceButton(
                          context,
                          source.name,
                          source.id == selectedSource.id,
                          () => onSourceChanged(source.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// Source button in header
  Widget _buildSourceButton(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant.withOpacity(0.5);
    final backgroundColor = isSelected ? colorScheme.primary.withOpacity(0.1) : null;
    final textColor = isSelected ? colorScheme.primary : colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  /// Album grid - responsive (2/3/4 columns)
  Widget _buildAlbumGrid(BuildContext context, List<LibraryAlbum> albums) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int columns;
        if (constraints.maxWidth < 600) {
          columns = 2; // Mobile
        } else if (constraints.maxWidth < 900) {
          columns = 3; // Tablet
        } else {
          columns = 4; // Desktop
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return ModernAlbumCard(
              thumbnail: GeneratedCoverArt(
                title: album.title,
                subtitle: album.artistName,
              ),
              title: album.title,
              artist: album.artistName,
              onTap: () => _showAlbumDetails(context, ref, album),
            );
          },
        );
      },
    );
  }

  /// Empty state
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 48,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.libraryEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.libraryEmptyDescription,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/settings/add-source'),
              child: Text(l10n.addSourceAction),
            ),
          ],
        ),
      ),
    );
  }

  /// No albums state
  Widget _buildNoAlbums(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.album,
            size: 48,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No albums',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Scan your library to find albums',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Loading state
  Widget _buildLoading(List<SourceProfile> sources, SourceProfile selectedSource) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Albums',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              if (sources.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: sources
                        .map((source) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildSourceButton(
                                context,
                                source.name,
                                source.id == selectedSource.id,
                                () {},
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }

  /// Error state
  Widget _buildError(Object error) {
    return Center(
      child: Text(error.toString()),
    );
  }

  /// Show album details in bottom sheet
  Future<void> _showAlbumDetails(
    BuildContext context,
    WidgetRef ref,
    LibraryAlbum album,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              children: [
                // Album header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GeneratedCoverArt(
                      title: album.title,
                      subtitle: album.artistName,
                      size: 90,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            album.artistName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${album.trackCount} tracks',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Track list
                ...album.tracks.asMap().entries.map((entry) {
                  final index = entry.key;
                  final track = entry.value;
                  return ModernTrackRow(
                    number: '${index + 1}',
                    title: track.title,
                    artist: track.artistName,
                    onTap: () {
                      ref.read(playerControllerProvider.notifier).playLibrarySong(track);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ],
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
    if (_selectedSourceId != null) {
      return sources.firstWhere(
        (s) => s.id == _selectedSourceId,
        orElse: () => sources.first,
      );
    }
    return browser.selectedSource ?? sources.first;
  }
}
