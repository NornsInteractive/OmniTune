import 'dart:async';

import 'package:music/core/models/app_preferences.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/scraping_preferences.dart';
import 'package:music/core/utils/debug_logger.dart';
import 'package:music/core/storage/cover_art_cache_manager.dart';
import 'package:music/features/scraper/domain/metadata_scraper.dart';

import 'itunes_client.dart';
import 'lrclib_client.dart';
import 'musicbrainz_client.dart';

/// MusicBrainz 刮削器实现（改进版：使用 iTunes Search API 获取元数据，然后 MusicBrainz 查询）
class MusicBrainzScraper implements MetadataScraper {
  final MusicBrainzClient musicbrainzClient;
  final ITunesClient itunesClient;
  final LrclibClient lrclibClient;
  final AppLocalePreference localePreference;

  /// 优先级：100 表示高优先级
  @override
  int get priority => 100;

  MusicBrainzScraper({
    MusicBrainzClient? musicbrainzClient,
    ITunesClient? itunesClient,
    LrclibClient? lrclibClient,
    this.localePreference = AppLocalePreference.system,
  }) : musicbrainzClient = musicbrainzClient ?? MusicBrainzClient(),
       itunesClient = itunesClient ?? ITunesClient(),
       lrclibClient = lrclibClient ?? LrclibClient();

  /// 刮削元数据
  /// 从 RemoteEntry 中提取标题和艺术家，然后调用 searchMetadata
  @override
  Future<ScrapedMetadata?> scrape(RemoteEntry entry) async {
    DebugLogger.scraping(
      'MusicBrainzScraper.scrape',
      '开始刮削: ${entry.name} (类型: ${entry.isDirectory ? "文件夹" : "文件"})',
    );

    // 如果是文件夹，不刮削
    if (entry.isDirectory) {
      DebugLogger.info('MusicBrainzScraper.scrape', '跳过文件夹: ${entry.name}');
      return null;
    }

    try {
      // 使用 TrackMetadataExtractor 从文件名提取标题和艺术家
      // 支持的格式：\"艺术家 - 标题.flac\"、\"01. 艺术家 - 标题.flac\" 或 \"标题.flac\"
      final (artist, title) = TrackMetadataExtractor.extractFromFilename(
        entry.name,
      );

      DebugLogger.info(
        'MusicBrainzScraper.scrape',
        '提取的信息 - 标题: "$title", 艺术家: "$artist"',
      );

      if (title.isEmpty) {
        DebugLogger.warning('MusicBrainzScraper.scrape', '无法提取有效的标题');
        return null;
      }

      final metadata = await scrapeTrackInfo(title: title, artist: artist);
      if (metadata == null) {
        DebugLogger.warning('MusicBrainzScraper.scrape', '未找到匹配的元数据');
        return null;
      }

      DebugLogger.success(
        'MusicBrainzScraper.scrape',
        '成功刮削: ${metadata.title} by ${metadata.artist}',
      );
      return metadata;
    } catch (e, stack) {
      DebugLogger.error(
        'MusicBrainzScraper.scrape',
        '刮削异常',
        e.toString(),
        stack,
      );
      return null;
    }
  }

  /// 搜索歌曲元数据
  /// 流程：
  /// 1. 先尝试 iTunes 搜索（成功直接返回）
  /// 2. iTunes 失败时回退到 MusicBrainz 搜索
  ///
  /// [localePreference] 可选，用于覆盖构造时传入的语言偏好。如果为 null，使用构造时的值。
  Future<List<ScrapedMetadataResult>> searchMetadata(
    String title, {
    String? artist,
    AppLocalePreference? localePreference,
    bool includeLyrics = true,
    int limit = 15,
  }) async {
    final actualLocale = localePreference ?? this.localePreference;

    DebugLogger.scraping(
      'MusicBrainzScraper',
      '【刮削流程开始】标题="$title", 艺术家="$artist", 语言偏好=$actualLocale',
    );

    try {
      // 步骤 1：通过 iTunes Search API 获取基本元数据（带 country 参数）
      DebugLogger.info(
        'MusicBrainzScraper',
        '【第1步】iTunes Search API 搜索 (country=${actualLocale.itunesCountryCode})...',
      );
      final itunesTracks = await itunesClient.searchTracksWithCountry(
        artist: artist,
        title: title,
        country: actualLocale.itunesCountryCode,
        limit: limit,
      );

      if (itunesTracks.isEmpty) {
        DebugLogger.warning(
          'MusicBrainzScraper',
          '【第1步失败】iTunes 无法找到歌曲 - 回退到直接 MusicBrainz 搜索',
        );
        return _searchDirectFromMusicBrainz(
          title,
          artist: artist,
          localePreference: actualLocale,
          includeLyrics: includeLyrics,
          limit: limit,
        );
      }
      DebugLogger.success(
        'MusicBrainzScraper',
        '【第1步成功✓】iTunes 返回 ${itunesTracks.length} 条结果',
      );

      final results = <ScrapedMetadataResult>[];
      for (var index = 0; index < itunesTracks.length; index++) {
        final itunesTrack = itunesTracks[index];
        final coverUrl = _upgradeItunesArtworkUrl(itunesTrack.artworkUrl);
        final localCoverPath = await _cacheCover(coverUrl);
        final lyrics = includeLyrics
            ? await _fetchLyrics(
                title: itunesTrack.trackName,
                artist: itunesTrack.artistName,
                album: itunesTrack.collectionName,
                duration: Duration(milliseconds: itunesTrack.trackTimeMillis),
              )
            : null;
        final rankPenalty = (index * 0.03).clamp(0.0, 0.35);
        results.add(
          ScrapedMetadataResult(
            title: itunesTrack.trackName,
            artist: itunesTrack.artistName,
            album: itunesTrack.collectionName,
            coverUrl: coverUrl,
            localCoverPath: localCoverPath,
            lyrics: lyrics,
            source: 'itunes',
            sourceId: itunesTrack.trackId,
            score: (1.0 - rankPenalty).clamp(0.0, 1.0),
          ),
        );
      }
      return results;
    } catch (e, stack) {
      DebugLogger.error('MusicBrainzScraper', '【刮削流程异常】', e.toString(), stack);
      return [];
    }
  }

  /// 直接从 MusicBrainz 搜索（备用方案）
  /// 当 Deezer 不可用或 ISRC 失败时使用
  Future<List<ScrapedMetadataResult>> _searchDirectFromMusicBrainz(
    String title, {
    String? artist,
    AppLocalePreference? localePreference,
    bool includeLyrics = true,
    int limit = 20,
  }) async {
    final actualLocale = localePreference ?? this.localePreference;

    DebugLogger.warning(
      'MusicBrainzScraper',
      '【⚠️ 备用流程】回退到直接 MusicBrainz 搜索: 标题="$title", 艺术家="$artist", 语言偏好=$actualLocale',
    );

    try {
      List<MusicBrainzRecording> recordings = [];

      // 如果有艺术家，使用精确搜索
      if (artist != null && artist.trim().isNotEmpty) {
        DebugLogger.info('MusicBrainzScraper', '【备用方案】使用精确搜索 (艺术家 + 标题)');
        recordings = await musicbrainzClient.searchByArtistAndTitle(
          artist.trim(),
          title.trim(),
          limit: limit,
          localePreference: actualLocale,
        );
      } else {
        // 否则按标题搜索
        DebugLogger.info('MusicBrainzScraper', '【备用方案】使用标题搜索');
        recordings = await musicbrainzClient.searchRecordings(
          title.trim(),
          limit: limit,
          localePreference: actualLocale,
        );
      }

      if (recordings.isEmpty) {
        DebugLogger.warning('MusicBrainzScraper', '【备用方案】无结果');
        return [];
      }

      final results = <ScrapedMetadataResult>[];
      for (final recording in recordings) {
        DebugLogger.scraping(
          'MusicBrainzScraper',
          '转换结果: ${recording.title} (匹配度: ${(recording.score ?? 0) / 100}%)',
        );
        final localCoverPath = await _cacheCover(recording.coverArtUrl);
        final lyrics = includeLyrics
            ? await _fetchLyrics(
                title: recording.title,
                artist: recording.artistName,
                album: recording.albumTitle,
                duration: recording.duration,
              )
            : null;
        results.add(
          ScrapedMetadataResult(
            title: recording.title,
            artist: recording.artistName,
            album: recording.albumTitle,
            coverUrl: recording.coverArtUrl,
            localCoverPath: localCoverPath,
            lyrics: lyrics,
            source: 'musicbrainz',
            sourceId: recording.id,
            score: (recording.score ?? 0) / 100, // 归一化到 0-1
          ),
        );
      }

      DebugLogger.success(
        'MusicBrainzScraper',
        '【备用方案】搜索完成: ${results.length} 个结果',
      );

      return results;
    } catch (e, stack) {
      DebugLogger.error('MusicBrainzScraper', '【备用方案】异常', e.toString(), stack);
      return [];
    }
  }

  Future<List<LrclibLyrics>> searchLyricsCandidates({
    required String title,
    String? artist,
    String? album,
    int limit = 12,
  }) {
    return lrclibClient.searchLyricsCandidates(
      trackName: title,
      artistName: artist,
      albumName: album,
      limit: limit,
    );
  }

  Future<ScrapedMetadata?> scrapeTrackInfo({
    required String title,
    String? artist,
    AppLocalePreference? localePreference,
    FutureOr<void> Function(ScrapedMetadata metadata)? onUpdate,
  }) async {
    final actualLocale = localePreference ?? this.localePreference;
    final normalizedArtist = _normalizedArtistQuery(artist);

    DebugLogger.scraping(
      'MusicBrainzScraper',
      '【快速刮削开始】标题="$title", 艺术家="$normalizedArtist", 语言偏好=$actualLocale',
    );

    DebugLogger.info(
      'MusicBrainzScraper',
      '【第1步】iTunes Search API 搜索 (country=${actualLocale.itunesCountryCode})...',
    );
    final itunesTrack = await itunesClient.searchTrackWithCountry(
      artist: normalizedArtist,
      title: title,
      country: actualLocale.itunesCountryCode,
    );

    final candidate = itunesTrack != null
        ? _ResolvedScrapeCandidate(
            title: itunesTrack.trackName,
            artist: itunesTrack.artistName,
            album: itunesTrack.collectionName,
            coverUrl: _upgradeItunesArtworkUrl(itunesTrack.artworkUrl),
            duration: Duration(milliseconds: itunesTrack.trackTimeMillis),
          )
        : await _searchBestFromMusicBrainz(
            _buildTitleVariants(title),
            artist: normalizedArtist,
            localePreference: actualLocale,
          );

    if (itunesTrack == null) {
      DebugLogger.warning(
        'MusicBrainzScraper',
        '【第1步失败】iTunes 无法找到歌曲 - 回退到直接 MusicBrainz 搜索',
      );
    } else {
      DebugLogger.success(
        'MusicBrainzScraper',
        '【第1步成功✓】iTunes 元数据 - 标题: "${itunesTrack.trackName}", 艺术家: "${itunesTrack.artistName}", 专辑: "${itunesTrack.collectionName}"',
      );
    }

    if (candidate == null) {
      return null;
    }

    var metadata = ScrapedMetadata(
      title: candidate.title,
      artist: candidate.artist,
      album: candidate.album,
      coverUrl: candidate.coverUrl,
    );
    if (onUpdate != null) {
      await onUpdate(metadata);
    }

    final coverFuture = _cacheCover(candidate.coverUrl);
    final lyricsFuture = _fetchLyrics(
      title: candidate.title,
      artist: candidate.artist,
      album: candidate.album,
      duration: candidate.duration,
    );

    final localCoverPath = await coverFuture;
    if (localCoverPath != null && localCoverPath.isNotEmpty) {
      metadata = ScrapedMetadata(
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        coverUrl: metadata.coverUrl,
        localCoverPath: localCoverPath,
        lyrics: metadata.lyrics,
      );
      if (onUpdate != null) {
        await onUpdate(metadata);
      }
    }

    final lyrics = await lyricsFuture;
    if (lyrics != null && lyrics.trim().isNotEmpty) {
      metadata = ScrapedMetadata(
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        coverUrl: metadata.coverUrl,
        localCoverPath: metadata.localCoverPath,
        lyrics: lyrics,
      );
      if (onUpdate != null) {
        await onUpdate(metadata);
      }
    }

    DebugLogger.success('MusicBrainzScraper', '【刮削完成✓】使用快速自动刮削路径返回');

    return metadata;
  }

  /// 关闭客户端
  void dispose() {
    musicbrainzClient.close();
    itunesClient.close();
    lrclibClient.close();
  }

  Future<String?> _fetchLyrics({
    required String title,
    String? artist,
    String? album,
    Duration? duration,
  }) async {
    try {
      final lyrics = await lrclibClient.findLyrics(
        trackName: title,
        artistName: artist,
        albumName: album,
        duration: duration,
      );
      final raw = lyrics?.bestLyrics;
      if (raw == null || raw.trim().isEmpty) {
        DebugLogger.warning('MusicBrainzScraper', '未找到歌词: $title');
        return null;
      }
      DebugLogger.success('MusicBrainzScraper', '歌词刮削成功: $title');
      return raw.trim();
    } catch (e, stack) {
      DebugLogger.error('MusicBrainzScraper', '歌词刮削异常', e.toString(), stack);
      return null;
    }
  }

  Future<String?> _cacheCover(String? coverUrl) async {
    if (coverUrl == null || coverUrl.trim().isEmpty) {
      return null;
    }
    try {
      DebugLogger.info('MusicBrainzScraper', '下载封面: $coverUrl');
      final localCoverPath = await CoverArtCacheManager().downloadAndCache(
        coverUrl,
      );
      if (localCoverPath?.isNotEmpty == true) {
        DebugLogger.success('MusicBrainzScraper', '封面缓存成功: $localCoverPath');
      }
      return localCoverPath;
    } catch (e, stack) {
      DebugLogger.error('MusicBrainzScraper', '封面缓存失败', e.toString(), stack);
      return null;
    }
  }

  String? _upgradeItunesArtworkUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      return url;
    }
    return url.replaceFirst(RegExp(r'/100x100[^/]*\.jpg$'), '/600x600bb.jpg');
  }

  Future<_ResolvedScrapeCandidate?> _searchBestFromMusicBrainz(
    List<String> titleVariants, {
    String? artist,
    required AppLocalePreference localePreference,
  }) async {
    for (final queryTitle in titleVariants) {
      DebugLogger.info(
        'MusicBrainzScraper',
        '【快速刮削】MusicBrainz 搜索: "$queryTitle"',
      );
      final recordings = artist != null && artist.trim().isNotEmpty
          ? await musicbrainzClient.searchByArtistAndTitle(
              artist.trim(),
              queryTitle.trim(),
              limit: 8,
              localePreference: localePreference,
            )
          : await musicbrainzClient.searchRecordings(
              queryTitle.trim(),
              limit: 8,
              localePreference: localePreference,
            );
      if (recordings.isEmpty) {
        continue;
      }

      final rankedRecordings = [...recordings]
        ..sort(
          (left, right) =>
              _scoreMusicBrainzRecording(
                right,
                queryTitle: queryTitle,
                queryArtist: artist,
              ).compareTo(
                _scoreMusicBrainzRecording(
                  left,
                  queryTitle: queryTitle,
                  queryArtist: artist,
                ),
              ),
        );
      final best = rankedRecordings.first;
      return _ResolvedScrapeCandidate(
        title: best.title,
        artist: best.artistName,
        album: best.albumTitle,
        coverUrl: best.coverArtUrl,
        duration: best.duration,
      );
    }
    return null;
  }

  List<String> _buildTitleVariants(String rawTitle) {
    final variants = <String>[];

    void addVariant(String? value) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty) {
        return;
      }
      if (!variants.contains(normalized)) {
        variants.add(normalized);
      }
    }

    addVariant(rawTitle);
    final extracted = TrackMetadataExtractor.extractFromFilename(rawTitle).$2;
    addVariant(extracted);
    addVariant(_stripTitleDecorators(extracted));
    addVariant(_stripTitleDecorators(rawTitle));
    return variants;
  }

  String? _normalizedArtistQuery(String? artist) {
    final normalized = artist?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  int _scoreMusicBrainzRecording(
    MusicBrainzRecording recording, {
    required String queryTitle,
    String? queryArtist,
  }) {
    return _scoreCandidateText(
          candidateTitle: recording.title,
          candidateArtist: recording.artistName,
          queryTitle: queryTitle,
          queryArtist: queryArtist,
        ) +
        ((recording.score ?? 0) ~/ 8);
  }

  int _scoreCandidateText({
    required String candidateTitle,
    required String? candidateArtist,
    required String queryTitle,
    String? queryArtist,
  }) {
    final queryTitleNormalized = _normalizeMatchText(queryTitle);
    final queryTitleSimplified = _normalizeMatchText(
      _stripTitleDecorators(queryTitle),
    );
    final candidateTitleNormalized = _normalizeMatchText(candidateTitle);
    final candidateTitleSimplified = _normalizeMatchText(
      _stripTitleDecorators(candidateTitle),
    );

    var score = 0;
    if (candidateTitleNormalized == queryTitleNormalized) {
      score += 120;
    }
    if (candidateTitleSimplified == queryTitleSimplified) {
      score += 70;
    }
    if (candidateTitleSimplified.contains(queryTitleSimplified) ||
        queryTitleSimplified.contains(candidateTitleSimplified)) {
      score += 25;
    }

    final normalizedArtist = _normalizeMatchText(queryArtist);
    final normalizedCandidateArtist = _normalizeMatchText(candidateArtist);
    if (normalizedArtist.isNotEmpty && normalizedCandidateArtist.isNotEmpty) {
      if (normalizedArtist == normalizedCandidateArtist) {
        score += 35;
      } else if (normalizedCandidateArtist.contains(normalizedArtist) ||
          normalizedArtist.contains(normalizedCandidateArtist)) {
        score += 12;
      } else {
        score -= 10;
      }
    }

    if (_hasVersionMarker(candidateTitle) && !_hasVersionMarker(queryTitle)) {
      score -= 24;
    }
    return score;
  }

  String _stripTitleDecorators(String value) {
    var output = value.trim();
    output = output.replaceFirst(RegExp(r'^\d+\.\s*'), '');
    output = output.replaceAll(RegExp(r'\s*[\(\[\{（【].*?[\)\]\}）】]\s*'), ' ');
    output = output.replaceAll(RegExp(r'\s+'), ' ').trim();
    return output;
  }

  String _normalizeMatchText(String? value) {
    return _stripTitleDecorators(
      value ?? '',
    ).toLowerCase().replaceAll(RegExp(r'[\s\-_.,:;!?/\\&]+'), '');
  }

  bool _hasVersionMarker(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('live') ||
        normalized.contains('remix') ||
        normalized.contains('demo') ||
        normalized.contains('karaoke') ||
        normalized.contains('instrumental') ||
        normalized.contains('伴奏') ||
        normalized.contains('现场') ||
        normalized.contains('版');
  }
}

class _ResolvedScrapeCandidate {
  const _ResolvedScrapeCandidate({
    required this.title,
    this.artist,
    this.album,
    this.coverUrl,
    this.duration,
  });

  final String title;
  final String? artist;
  final String? album;
  final String? coverUrl;
  final Duration? duration;
}

/// 搜索结果
class ScrapedMetadataResult {
  final String title;
  final String? artist;
  final String? album;
  final String? coverUrl;
  final String? localCoverPath; // 本地缓存的封面文件路径
  final String? lyrics; // MusicBrainz 没有歌词，需要其他源
  final String source; // 来源名称
  final String sourceId; // 源的唯一 ID
  final double score; // 0-1 匹配度

  ScrapedMetadataResult({
    required this.title,
    this.artist,
    this.album,
    this.coverUrl,
    this.localCoverPath,
    this.lyrics,
    required this.source,
    required this.sourceId,
    this.score = 0.5,
  });

  /// 转换为 ScrapedMetadata（当用户确认选择这个结果时）
  ScrapedMetadata toScrapedMetadata() => ScrapedMetadata(
    title: title,
    artist: artist,
    album: album,
    coverUrl: coverUrl,
    lyrics: lyrics,
    localCoverPath: localCoverPath,
  );

  @override
  String toString() =>
      '''
ScrapedMetadataResult(
  title: $title,
  artist: $artist,
  album: $album,
  source: $source,
  score: ${(score * 100).toStringAsFixed(1)}%,
)
  ''';
}
