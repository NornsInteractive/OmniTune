import 'dart:async';

import 'package:music/core/models/app_preferences.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/scraping_preferences.dart';
import 'package:music/core/utils/debug_logger.dart';
import 'package:music/core/storage/cover_art_cache_manager.dart';
import 'package:music/features/scraper/domain/metadata_scraper.dart';

import 'deezer_client.dart';
import 'itunes_client.dart';
import 'lrclib_client.dart';
import 'musicbrainz_client.dart';

/// MusicBrainz 刮削器实现（改进版：使用 iTunes Search API 获取元数据，然后 MusicBrainz 查询）
class MusicBrainzScraper implements MetadataScraper {
  final MusicBrainzClient musicbrainzClient;
  final ITunesClient itunesClient;
  final DeezerClient deezerClient;
  final LrclibClient lrclibClient;
  final AppLocalePreference localePreference;
  final bool enableLyricsScraping;
  final bool enableDeezerCoverScraping;
  final bool enableItunesMetadataScraping;
  final String? lyricsScrapingServiceBaseUrl;

  /// 优先级：100 表示高优先级
  @override
  int get priority => 100;

  MusicBrainzScraper({
    MusicBrainzClient? musicbrainzClient,
    ITunesClient? itunesClient,
    DeezerClient? deezerClient,
    LrclibClient? lrclibClient,
    this.localePreference = AppLocalePreference.system,
    this.enableLyricsScraping = false,
    this.enableDeezerCoverScraping = false,
    this.enableItunesMetadataScraping = false,
    this.lyricsScrapingServiceBaseUrl,
  }) : musicbrainzClient = musicbrainzClient ?? MusicBrainzClient(),
       itunesClient = itunesClient ?? ITunesClient(),
       deezerClient = deezerClient ?? DeezerClient(),
       lrclibClient =
           lrclibClient ?? LrclibClient(baseUrl: lyricsScrapingServiceBaseUrl);

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
      if (enableItunesMetadataScraping) {
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

        if (itunesTracks.isNotEmpty) {
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
                    duration: Duration(
                      milliseconds: itunesTrack.trackTimeMillis,
                    ),
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
        }

        DebugLogger.warning(
          'MusicBrainzScraper',
          '【第1步失败】iTunes 无法找到歌曲 - 回退到直接 MusicBrainz 搜索',
        );
      } else {
        DebugLogger.info(
          'MusicBrainzScraper',
          'iTunes 元数据刮削已关闭，直接使用 MusicBrainz 搜索',
        );
      }

      return _searchDirectFromMusicBrainz(
        title,
        artist: artist,
        localePreference: actualLocale,
        includeLyrics: includeLyrics,
        limit: limit,
      );
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
    if (!_canScrapeLyrics) {
      return Future.value(const <LrclibLyrics>[]);
    }
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
    String? album,
    AppLocalePreference? localePreference,
    FutureOr<void> Function(ScrapedMetadata metadata)? onUpdate,
  }) async {
    final normalizedArtist = _normalizedArtistQuery(artist);
    final normalizedAlbum = album?.trim();

    DebugLogger.scraping(
      'MusicBrainzScraper',
      '【快速刮削开始】标题="$title", 艺术家="$normalizedArtist", 封面=${enableDeezerCoverScraping ? "开" : "关"}, 歌词=${_canScrapeLyrics ? "开" : "关"}',
    );
    if (!enableDeezerCoverScraping && !_canScrapeLyrics) {
      DebugLogger.info('MusicBrainzScraper', '自动封面/歌词刮削均未启用，跳过');
      return null;
    }

    var coverUrl = '';
    var localCoverPath = '';
    var lyrics = '';
    var updated = false;

    if (enableDeezerCoverScraping) {
      final resolvedCoverUrl = await _fetchDeezerCover(
        title: title,
        artist: normalizedArtist,
      );
      if (resolvedCoverUrl != null && resolvedCoverUrl.isNotEmpty) {
        coverUrl = resolvedCoverUrl;
        final cachedCoverPath = await _cacheCover(resolvedCoverUrl);
        if (cachedCoverPath != null && cachedCoverPath.isNotEmpty) {
          localCoverPath = cachedCoverPath;
        }
        updated = true;
        if (onUpdate != null) {
          await onUpdate(
            ScrapedMetadata(
              title: title,
              artist: normalizedArtist,
              album: normalizedAlbum,
              coverUrl: coverUrl.isEmpty ? null : coverUrl,
              localCoverPath: localCoverPath.isEmpty ? null : localCoverPath,
            ),
          );
        }
      }
    }

    if (_canScrapeLyrics) {
      final resolvedLyrics = await _fetchLyrics(
        title: title,
        artist: normalizedArtist,
        album: normalizedAlbum,
      );
      if (resolvedLyrics != null && resolvedLyrics.trim().isNotEmpty) {
        lyrics = resolvedLyrics.trim();
        updated = true;
        if (onUpdate != null) {
          await onUpdate(
            ScrapedMetadata(
              title: title,
              artist: normalizedArtist,
              album: normalizedAlbum,
              coverUrl: coverUrl.isEmpty ? null : coverUrl,
              localCoverPath: localCoverPath.isEmpty ? null : localCoverPath,
              lyrics: lyrics,
            ),
          );
        }
      }
    }

    if (!updated) {
      DebugLogger.warning('MusicBrainzScraper', '未获得新的封面或歌词');
      return null;
    }

    DebugLogger.success('MusicBrainzScraper', '【刮削完成✓】已按新策略返回封面/歌词');
    return ScrapedMetadata(
      title: title,
      artist: normalizedArtist,
      album: normalizedAlbum,
      coverUrl: coverUrl.isEmpty ? null : coverUrl,
      localCoverPath: localCoverPath.isEmpty ? null : localCoverPath,
      lyrics: lyrics.isEmpty ? null : lyrics,
    );
  }

  /// 关闭客户端
  void dispose() {
    musicbrainzClient.close();
    itunesClient.close();
    deezerClient.close();
    lrclibClient.close();
  }

  Future<String?> _fetchLyrics({
    required String title,
    String? artist,
    String? album,
    Duration? duration,
  }) async {
    if (!_canScrapeLyrics) {
      return null;
    }
    try {
      final titleVariants = _buildTitleVariants(title);
      for (final queryTitle in titleVariants) {
        final lyrics = await lrclibClient.findLyrics(
          trackName: queryTitle,
          artistName: artist,
          albumName: album,
          duration: duration,
        );
        final raw = lyrics?.bestLyrics;
        if (raw == null || raw.trim().isEmpty) {
          continue;
        }
        DebugLogger.success('MusicBrainzScraper', '歌词刮削成功: $queryTitle');
        return raw.trim();
      }
      DebugLogger.warning('MusicBrainzScraper', '未找到歌词: $title');
      return null;
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

  Future<String?> _fetchDeezerCover({
    required String title,
    String? artist,
  }) async {
    try {
      return await deezerClient.searchBestCoverUrl(
        title: title,
        artist: artist,
      );
    } catch (e, stack) {
      DebugLogger.error(
        'MusicBrainzScraper',
        'Deezer 封面刮削异常',
        e.toString(),
        stack,
      );
      return null;
    }
  }

  bool get _canScrapeLyrics =>
      enableLyricsScraping &&
      lyricsScrapingServiceBaseUrl != null &&
      lyricsScrapingServiceBaseUrl!.trim().isNotEmpty;

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

  String _stripTitleDecorators(String value) {
    var output = value.trim();
    output = output.replaceFirst(RegExp(r'^\d+\.\s*'), '');
    output = output.replaceAll(RegExp(r'\s*[\(\[\{（【].*?[\)\]\}）】]\s*'), ' ');
    output = output.replaceAll(RegExp(r'\s+'), ' ').trim();
    return output;
  }
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
