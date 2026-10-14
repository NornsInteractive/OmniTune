import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/localizations.dart';
import '../../../core/models/library_song.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/track_cover_thumbnail.dart';
import '../../player/presentation/widgets/mini_player.dart';
import '../application/library_catalog_controller.dart';
import '../application/library_query.dart';

typedef _SearchRequest = ({String query, String? sourceId, LibrarySort sort});

List<LibrarySong> _searchLibrary((List<LibrarySong>, _SearchRequest) input) =>
    queryLibrarySongs(
      input.$1,
      query: input.$2.query,
      sourceId: input.$2.sourceId,
      sort: input.$2.sort,
    );

final _searchResultsProvider = FutureProvider.autoDispose
    .family<List<LibrarySong>, _SearchRequest>((ref, request) async {
      final catalog = await ref.watch(libraryCatalogControllerProvider.future);
      return compute(_searchLibrary, (catalog.tracks, request));
    });

class LibrarySearchPage extends ConsumerStatefulWidget {
  const LibrarySearchPage({super.key});
  @override
  ConsumerState<LibrarySearchPage> createState() => _LibrarySearchPageState();
}

class _LibrarySearchPageState extends ConsumerState<LibrarySearchPage> {
  final _text = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _sourceId;
  LibrarySort _sort = LibrarySort.title;

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(libraryCatalogControllerProvider).valueOrNull;
    final sources = {
      for (final song in catalog?.tracks ?? <LibrarySong>[])
        song.sourceId: song.sourceName,
    };
    final selectedSource = sources.containsKey(_sourceId) ? _sourceId : null;
    final results = ref.watch(
      _searchResultsProvider((
        query: _query,
        sourceId: selectedSource,
        sort: _sort,
      )),
    );
    final currentId = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack?.id),
    );
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.librarySearchTitle)),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TextField(
                    controller: _text,
                    decoration: InputDecoration(
                      hintText: l10n.librarySearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: l10n.clearAction,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _debounce?.cancel();
                          _text.clear();
                          setState(() => _query = '');
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 200), () {
                        if (mounted) setState(() => _query = value);
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedSource,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: l10n.allSourcesLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.allSourcesLabel),
                            ),
                            for (final source in sources.entries)
                              DropdownMenuItem(
                                value: source.key,
                                child: Text(
                                  source.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _sourceId = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<LibrarySort>(
                          initialValue: _sort,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.sort_rounded),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final sort in LibrarySort.values)
                              DropdownMenuItem(
                                value: sort,
                                child: Text(switch (sort) {
                                  LibrarySort.title => l10n.sortTitleLabel,
                                  LibrarySort.artist => l10n.sortArtistLabel,
                                  LibrarySort.album => l10n.sortAlbumLabel,
                                }),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _sort = value);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: results.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(_searchResultsProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.retryAction),
                      ),
                    ),
                    data: (songs) => songs.isEmpty
                        ? Center(child: Text(l10n.searchNoResults))
                        : ListView.builder(
                            itemCount: songs.length,
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              return ListTile(
                                selected: currentId == song.id,
                                selectedTileColor: colors.secondaryContainer,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                leading: TrackCoverThumbnail(
                                  title: song.displayTitle,
                                  subtitle: song.displayArtist,
                                  size: 48,
                                  borderRadius: 10,
                                  localCoverPath: song.displayLocalCoverPath,
                                  coverUrl: song.displayCoverUrl,
                                  trackId: song.id,
                                  sourceId: song.sourceId,
                                  directoryPath: song.directoryPath,
                                  isCurrentTrack: currentId == song.id,
                                ),
                                title: Text(
                                  song.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${song.displayArtist} · ${song.displayAlbum}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  tooltip:
                                      catalog?.favoriteTrackIds.contains(
                                            song.id,
                                          ) ==
                                          true
                                      ? l10n.removeFromFavoritesAction
                                      : l10n.addToFavoritesAction,
                                  icon: Icon(
                                    catalog?.favoriteTrackIds.contains(
                                              song.id,
                                            ) ==
                                            true
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                  ),
                                  onPressed: () => ref
                                      .read(
                                        libraryCatalogControllerProvider
                                            .notifier,
                                      )
                                      .toggleFavorite(song.id),
                                ),
                                onTap: () async {
                                  try {
                                    await ref
                                        .read(playerControllerProvider.notifier)
                                        .playLibrarySong(song, playlist: songs);
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(l10n.retryAction)),
                                    );
                                  }
                                },
                              );
                            },
                          ),
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
