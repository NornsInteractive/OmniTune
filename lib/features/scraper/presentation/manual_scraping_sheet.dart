import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/core/i18n/localizations.dart';

import '../../../core/models/library_song.dart';
import '../../../core/widgets/top_snackbar.dart';
import '../../library/application/library_catalog_controller.dart';
import '../../player/application/player_controller.dart';
import '../../player/presentation/widgets/track_cover_thumbnail.dart';
import '../application/scraping_provider.dart';
import '../data/musicbrainz_scraper.dart';

Future<void> showManualScrapingSheet({
  required BuildContext context,
  required LibrarySong song,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: false,
    builder: (_) => _ManualScrapingSheet(song: song),
  );
}

class _ManualScrapingSheet extends ConsumerStatefulWidget {
  const _ManualScrapingSheet({required this.song});

  final LibrarySong song;

  @override
  ConsumerState<_ManualScrapingSheet> createState() =>
      _ManualScrapingSheetState();
}

class _ManualScrapingSheetState extends ConsumerState<_ManualScrapingSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  bool _searching = false;
  String? _errorText;
  List<ScrapedMetadataResult> _results = const [];
  String? _applyingSourceId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.displayTitle);
    _artistController = TextEditingController(text: widget.song.displayArtist);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final title = _titleController.text.trim();
    final artist = _artistController.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() {
      _searching = true;
      _errorText = null;
    });
    try {
      final results = await ref
          .read(musicBrainzScraperProvider)
          .searchMetadata(
            title,
            artist: artist.isEmpty ? null : artist,
            includeLyrics: false,
            limit: 18,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = AppLocalizations.of(context)!.scrapingErrorMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  Future<void> _applyResult(ScrapedMetadataResult result) async {
    setState(() {
      _applyingSourceId = result.sourceId;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final existing = await ref.read(
        getScrapingMetadataProvider(widget.song.id).future,
      );
      if (existing == null) {
        await ref.read(
          createScrapingRecordProvider(
            widget.song.sourceId,
            widget.song.remotePath,
            widget.song.fileName,
            originalArtist: widget.song.artistName,
          ).future,
        );
      }
      await ref.read(
        applyManualScrapingResultProvider(
          widget.song.id,
          ScrapedMetadataResult(
            title: result.title,
            artist: result.artist,
            album: result.album,
            coverUrl: result.coverUrl,
            localCoverPath: result.localCoverPath,
            lyrics: null,
            source: result.source,
            sourceId: result.sourceId,
            score: result.score,
          ),
        ).future,
      );
      ref
          .read(libraryCatalogControllerProvider.notifier)
          .refreshSongMetadata(widget.song.id);
      ref
          .read(playerControllerProvider.notifier)
          .refreshSongMetadata(widget.song.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      showTopSnackBar(context, l10n.scrapingResultApplied);
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTopSnackBar(context, l10n.scrapingErrorMessage);
      setState(() {
        _applyingSourceId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.manualScrapingTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.scrapingSongName,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _artistController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      labelText: l10n.scrapingArtistName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _searching ? null : _search,
                      icon: _searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                      label: Text(
                        _searching
                            ? l10n.scrapingSearchingLabel
                            : l10n.scrapingSearchButton,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.scrapingSearchResultsTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _errorText!,
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                  Flexible(
                    child: _results.isEmpty && !_searching
                        ? Center(
                            child: Text(
                              l10n.scrapingNoResultsMessage,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              final hasCover =
                                  (item.localCoverPath?.isNotEmpty ?? false) ||
                                  (item.coverUrl?.isNotEmpty ?? false);
                              final applying =
                                  _applyingSourceId == item.sourceId;
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHigh
                                      .withValues(alpha: 0.62),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TrackCoverThumbnail(
                                          title: item.title,
                                          subtitle: item.artist ?? '-',
                                          size: 50,
                                          borderRadius: 12,
                                          localCoverPath: item.localCoverPath,
                                          coverUrl: item.coverUrl,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${item.title} / ${item.artist ?? '-'}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                              if (item.album
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                  child: Text(
                                                    item.album!,
                                                    style: TextStyle(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              _MetaChip(
                                                label: l10n
                                                    .scrapingMatchScoreLabel(
                                                      (item.score * 100)
                                                          .round(),
                                                    ),
                                              ),
                                              if (hasCover)
                                                _MetaChip(
                                                  label:
                                                      l10n.scrapingCoverLabel,
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton(
                                          onPressed: applying
                                              ? null
                                              : () => _applyResult(item),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(0, 34),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: applying
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Text(
                                                  l10n.scrapingSelectButtonLabel,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
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
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
