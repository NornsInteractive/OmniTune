import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/core/models/scraping_preferences.dart';
import 'package:music/l10n/app_localizations.dart';
import 'package:path/path.dart' as p;

import '../../../core/widgets/top_snackbar.dart';
import '../../library/application/library_catalog_controller.dart';
import '../../player/application/player_controller.dart';
import '../application/scraping_provider.dart';
import '../data/lrclib_client.dart';
import '../data/musicbrainz_scraper.dart';

Future<void> showLyricsScrapingSheet({
  required BuildContext context,
  required String title,
  required String artist,
  required String album,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: false,
    builder: (_) =>
        _LyricsScrapingSheet(title: title, artist: artist, album: album),
  );
}

class _LyricsScrapingSheet extends ConsumerStatefulWidget {
  const _LyricsScrapingSheet({
    required this.title,
    required this.artist,
    required this.album,
  });

  final String title;
  final String artist;
  final String album;

  @override
  ConsumerState<_LyricsScrapingSheet> createState() =>
      _LyricsScrapingSheetState();
}

class _LyricsScrapingSheetState extends ConsumerState<_LyricsScrapingSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _artistController;
  bool _searching = false;
  bool _applying = false;
  String? _errorText;
  String? _applyingCandidateKey;
  String? _selectedCandidateKey;
  List<LrclibLyrics> _candidates = const [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _artistController = TextEditingController(text: widget.artist);
    if (_titleController.text.trim().isNotEmpty &&
        _artistController.text.trim().isNotEmpty) {
      _search();
    }
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
    if (title.isEmpty || artist.isEmpty) {
      setState(() {
        _errorText = AppLocalizations.of(context)!.scrapingNoResultsMessage;
        _candidates = const [];
      });
      return;
    }
    setState(() {
      _searching = true;
      _errorText = null;
      _selectedCandidateKey = null;
    });
    try {
      final results = <LrclibLyrics>[];
      final seenKeys = <String>{};
      final primaryTitle = _normalizedSearchTitle(title);
      final fallbackTitle = _fallbackSearchTitle(title);
      final queryTitles = <String>[
        primaryTitle,
        if (fallbackTitle != primaryTitle) fallbackTitle,
      ];
      for (final queryTitle in queryTitles) {
        final batch = await ref
            .read(musicBrainzScraperProvider)
            .searchLyricsCandidates(
              title: queryTitle,
              artist: artist,
              limit: 16,
            );
        for (final item in batch) {
          final key = '${item.id}_${item.trackName}_${item.artistName}';
          if (seenKeys.add(key)) {
            results.add(item);
          }
        }
        if (results.isNotEmpty) {
          break;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = results;
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

  Future<void> _applyLyrics(LrclibLyrics candidate) async {
    final track = ref.read(playerControllerProvider).currentTrack;
    if (track == null) {
      return;
    }
    final lyrics = candidate.bestLyrics.trim();
    if (lyrics.isEmpty) {
      return;
    }
    final key =
        '${candidate.id}_${candidate.trackName}_${candidate.artistName}';
    setState(() {
      _applying = true;
      _applyingCandidateKey = key;
    });
    final l10n = AppLocalizations.of(context)!;
    try {
      final existing = await ref.read(
        getScrapingMetadataProvider(track.id).future,
      );
      if (existing == null) {
        final filename = p.posix.basename(track.remotePath);
        await ref.read(
          createScrapingRecordProvider(
            track.sourceId,
            track.remotePath,
            filename,
            originalArtist: track.displayArtist,
          ).future,
        );
      }
      await ref.read(
        applyManualScrapingResultProvider(
          track.id,
          ScrapedMetadataResult(
            title: _firstNonEmpty(
              existing?.manuallyScrapedTitle,
              existing?.autoScrapedTitle,
              track.displayTitle,
              _titleController.text.trim(),
            ),
            artist: _firstNonEmpty(
              existing?.manuallyScrapedArtist,
              existing?.autoScrapedArtist,
              track.displayArtist,
              _artistController.text.trim(),
            ),
            album: _firstNonEmpty(
              existing?.manuallyScrapedAlbum,
              existing?.autoScrapedAlbum,
              track.displayAlbum,
              widget.album,
            ),
            coverUrl: _firstNonEmpty(
              existing?.manuallyScrapedCoverUrl,
              existing?.autoScrapedCoverUrl,
              track.autoScrapedCoverUrl,
              null,
            ),
            localCoverPath: _firstNonEmpty(
              existing?.manuallyScrapedLocalCoverPath,
              existing?.autoScrapedLocalCoverPath,
              track.localCoverPath,
              null,
            ),
            lyrics: lyrics,
            source: 'manual_lyrics',
            sourceId: 'manual_lyrics_${candidate.id}',
          ),
        ).future,
      );
      ref.read(playerControllerProvider.notifier).refreshSongMetadata(track.id);
      ref
          .read(libraryCatalogControllerProvider.notifier)
          .refreshSongMetadata(track.id);
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
        _applying = false;
        _applyingCandidateKey = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final positionBucket = ref.watch(
      playerControllerProvider.select(
        (state) => state.position.inMilliseconds ~/ 500,
      ),
    );
    final playbackPosition = Duration(milliseconds: positionBucket * 500);
    final colorScheme = Theme.of(context).colorScheme;
    final cardWidth = (MediaQuery.sizeOf(context).width * 0.28).clamp(
      86.0,
      104.0,
    );
    const resultHeight = 147.0;

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
                maxHeight: MediaQuery.sizeOf(context).height * 0.84,
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
                          l10n.scrapingUpdateLyricsAction,
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
                      onPressed: _searching || _applying ? null : _search,
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
                  SizedBox(
                    height: resultHeight,
                    child: _searching
                        ? const Center(child: CircularProgressIndicator())
                        : _candidates.isEmpty
                        ? Center(child: Text(l10n.scrapingNoResultsMessage))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _candidates.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final item = _candidates[index];
                              final key =
                                  '${item.id}_${item.trackName}_${item.artistName}';
                              return SizedBox(
                                width: cardWidth,
                                height: resultHeight,
                                child: _LyricsCandidateCard(
                                  candidate: item,
                                  currentPosition: playbackPosition,
                                  applying: _applyingCandidateKey == key,
                                  selected: _selectedCandidateKey == key,
                                  onSelect: _applying
                                      ? null
                                      : () => setState(() {
                                          _selectedCandidateKey = key;
                                        }),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _applying || _selectedCandidateKey == null
                          ? null
                          : () {
                              final candidate = _candidates.firstWhere(
                                (item) =>
                                    '${item.id}_${item.trackName}_${item.artistName}' ==
                                    _selectedCandidateKey,
                              );
                              _applyLyrics(candidate);
                            },
                      child: _applying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.scrapingSelectButtonLabel),
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

class _LyricsCandidateCard extends StatefulWidget {
  const _LyricsCandidateCard({
    required this.candidate,
    required this.currentPosition,
    required this.applying,
    required this.selected,
    required this.onSelect,
  });

  final LrclibLyrics candidate;
  final Duration currentPosition;
  final bool applying;
  final bool selected;
  final VoidCallback? onSelect;

  @override
  State<_LyricsCandidateCard> createState() => _LyricsCandidateCardState();
}

class _LyricsCandidateCardState extends State<_LyricsCandidateCard> {
  late final ScrollController _scrollController;
  late final List<LyricLine> _lines;
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _lines = _parseLyrics(widget.candidate.bestLyrics);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToActive(force: true, animated: false),
    );
  }

  @override
  void didUpdateWidget(covariant _LyricsCandidateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToActive();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = _activeIndex(_lines, widget.currentPosition);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
          decoration: BoxDecoration(
            color: widget.selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.48)
                : colorScheme.surfaceContainerHigh.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.selected
                  ? colorScheme.primary.withValues(alpha: 0.7)
                  : colorScheme.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.candidate.trackName} / ${widget.candidate.artistName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (widget.applying)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (widget.selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                ],
              ),
              if (widget.candidate.albumName?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.candidate.albumName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Expanded(
                child: _lines.isEmpty
                    ? Center(
                        child: Text(
                          '--',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        itemCount: _lines.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final line = _lines[index];
                          final isActive = index == active;
                          return Text(
                            line.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isActive
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: isActive ? 9.2 : 8.4,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToActive({
    bool force = false,
    bool animated = true,
    int remainingAttempts = 6,
  }) {
    final active = _activeIndex(_lines, widget.currentPosition);
    if (active < 0 || active >= _lines.length) {
      return;
    }
    if (!force && active == _lastActiveIndex) {
      return;
    }
    _lastActiveIndex = active;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) {
        if (remainingAttempts > 0) {
          Future<void>.delayed(const Duration(milliseconds: 60), () {
            _scrollToActive(
              force: true,
              animated: animated,
              remainingAttempts: remainingAttempts - 1,
            );
          });
        }
        return;
      }
      _scrollWithinCard(active, animated: animated);
    });
  }

  void _scrollWithinCard(int targetIndex, {required bool animated}) {
    if (!_scrollController.hasClients || _lines.length <= 1) {
      return;
    }
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (!maxExtent.isFinite || maxExtent <= 0) {
      return;
    }
    final visibleLines = (_scrollController.position.viewportDimension / 12.0)
        .clamp(1.0, 8.0);
    final centeredIndex = (targetIndex - (visibleLines / 2)).clamp(
      0.0,
      (_lines.length - 1).toDouble(),
    );
    final ratio = _lines.length <= 1
        ? 0.0
        : centeredIndex / (_lines.length - 1);
    final targetOffset = (maxExtent * ratio).clamp(0.0, maxExtent);
    if ((_scrollController.offset - targetOffset).abs() < 12) {
      return;
    }
    if (animated) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }
}

String _normalizedSearchTitle(String rawTitle) {
  final extracted = TrackMetadataExtractor.extractFromFilename(rawTitle).$2;
  return _stripSearchDecorators(extracted.isNotEmpty ? extracted : rawTitle);
}

String _fallbackSearchTitle(String rawTitle) {
  final normalized = _normalizedSearchTitle(rawTitle);
  final withoutVersion = normalized.replaceAll(
    RegExp(r'\s*[\(\[\{（【].*?[\)\]\}）】]\s*'),
    ' ',
  );
  return withoutVersion.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _stripSearchDecorators(String value) {
  var output = value.trim();
  output = output.replaceFirst(RegExp(r'^\d+\.\s*'), '');
  output = output.replaceAll(RegExp(r'\s+'), ' ').trim();
  return output;
}

String _firstNonEmpty(
  String? first,
  String? second,
  String? third,
  String? fourth,
) {
  for (final value in [first, second, third, fourth]) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

List<LyricLine> _parseLyrics(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }
  final result = <LyricLine>[];
  final unsynced = <String>[];
  final pattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final matches = pattern.allMatches(line).toList();
    if (matches.isEmpty) {
      final text = line.trim();
      if (text.isNotEmpty) {
        unsynced.add(text);
      }
      continue;
    }
    final text = line.replaceAll(pattern, '').trim();
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fractionRaw = match.group(3) ?? '';
      final milliseconds = switch (fractionRaw.length) {
        1 => (int.tryParse(fractionRaw) ?? 0) * 100,
        2 => (int.tryParse(fractionRaw) ?? 0) * 10,
        _ => int.tryParse(fractionRaw) ?? 0,
      };
      result.add(
        LyricLine(
          time: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
          text: text.isEmpty ? '...' : text,
        ),
      );
    }
  }
  if (result.isEmpty) {
    return unsynced
        .map((text) => LyricLine(time: Duration.zero, text: text))
        .toList(growable: false);
  }
  result.sort((a, b) => a.time.compareTo(b.time));
  return result;
}

int _activeIndex(List<LyricLine> lines, Duration position) {
  if (lines.isEmpty || !lines.any((line) => line.time > Duration.zero)) {
    return -1;
  }
  var active = -1;
  for (var i = 0; i < lines.length; i++) {
    if (position >= lines[i].time) {
      active = i;
    } else {
      break;
    }
  }
  return active;
}
