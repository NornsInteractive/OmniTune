import 'package:dio/dio.dart';

import '../../../core/utils/debug_logger.dart';

class LrclibClient {
  LrclibClient({String? userAgent, String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: (baseUrl == null || _normalizeBaseUrl(baseUrl).isEmpty)
              ? _defaultBaseUrl
              : _normalizeBaseUrl(baseUrl),
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.json,
        ),
      ) {
    _dio.options.headers['User-Agent'] =
        userAgent ?? 'FlutterMusicPlayer/1.0.0 (lyrics)';
  }

  static const String _defaultBaseUrl = 'https://lrclib.net/api';
  static DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);
  static Future<void> _requestQueue = Future<void>.value();

  final Dio _dio;

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.startsWith('https//')) {
      normalized = normalized.replaceFirst('https//', 'https://');
    } else if (normalized.startsWith('http//')) {
      normalized = normalized.replaceFirst('http//', 'http://');
    } else if (!normalized.contains('://')) {
      normalized = 'https://$normalized';
    }
    return normalized;
  }

  Future<LrclibLyrics?> findLyrics({
    required String trackName,
    String? artistName,
    String? albumName,
    Duration? duration,
  }) async {
    if (trackName.trim().isEmpty) {
      return null;
    }

    final exact = await _getExactLyrics(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      duration: duration,
    );
    if (exact?.bestLyrics.trim().isNotEmpty == true) {
      return exact;
    }

    return _searchLyrics(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
    );
  }

  Future<List<LrclibLyrics>> searchLyricsCandidates({
    required String trackName,
    String? artistName,
    String? albumName,
    int limit = 12,
  }) async {
    if (trackName.trim().isEmpty) {
      return const [];
    }
    try {
      final response = await _get(
        '/search',
        queryParameters: {
          'track_name': trackName.trim(),
          if (artistName?.trim().isNotEmpty == true)
            'artist_name': artistName!.trim(),
          if (albumName?.trim().isNotEmpty == true)
            'album_name': albumName!.trim(),
        },
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 16),
        ),
        maxTimeoutRetries: 1,
      );
      if (response?.data is! List<dynamic>) {
        return const [];
      }
      return _rankLyricsCandidates(
        response!.data as List<dynamic>,
        trackName: trackName,
        artistName: artistName,
        albumName: albumName,
        limit: limit,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const [];
      }
      if (_isTimeoutLike(e) && artistName?.trim().isNotEmpty == true) {
        final fallback = await _searchLyricsCandidatesByTitleOnly(
          trackName: trackName,
          limit: limit,
        );
        if (fallback.isNotEmpty) {
          return fallback;
        }
      }
      DebugLogger.warning(
        'LRCLIB',
        '歌词候选搜索失败: ${e.response?.statusCode ?? e.type}',
      );
      return const [];
    } catch (e, stack) {
      DebugLogger.error('LRCLIB', '歌词候选搜索异常', e.toString(), stack);
      return const [];
    }
  }

  Future<LrclibLyrics?> _getExactLyrics({
    required String trackName,
    String? artistName,
    String? albumName,
    Duration? duration,
  }) async {
    final artist = artistName?.trim();
    final album = albumName?.trim();
    final seconds = duration?.inSeconds;
    if (artist == null ||
        artist.isEmpty ||
        album == null ||
        album.isEmpty ||
        seconds == null ||
        seconds <= 0) {
      return null;
    }

    try {
      final response = await _get(
        '/get',
        queryParameters: {
          'track_name': trackName.trim(),
          'artist_name': artist,
          'album_name': album,
          'duration': seconds,
        },
      );
      if (response?.data is Map<String, dynamic>) {
        return LrclibLyrics.fromJson(response!.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404 && e.response?.statusCode != 400) {
        DebugLogger.warning(
          'LRCLIB',
          '精确歌词查询失败: ${e.response?.statusCode ?? e.type}',
        );
      }
    } catch (e, stack) {
      DebugLogger.error('LRCLIB', '精确歌词查询异常', e.toString(), stack);
    }
    return null;
  }

  Future<LrclibLyrics?> _searchLyrics({
    required String trackName,
    String? artistName,
    String? albumName,
  }) async {
    try {
      final response = await _get(
        '/search',
        queryParameters: {
          'track_name': trackName.trim(),
          if (artistName?.trim().isNotEmpty == true)
            'artist_name': artistName!.trim(),
          if (albumName?.trim().isNotEmpty == true)
            'album_name': albumName!.trim(),
        },
      );
      if (response?.data is! List<dynamic>) {
        return null;
      }

      final results = (response!.data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(LrclibLyrics.fromJson)
          .where((lyrics) => lyrics.bestLyrics.trim().isNotEmpty)
          .toList();
      if (results.isEmpty) {
        DebugLogger.warning('LRCLIB', '搜索无歌词结果: $trackName');
        return null;
      }

      results.sort((left, right) {
        final leftScore = _scoreLyrics(left, trackName, artistName, albumName);
        final rightScore = _scoreLyrics(
          right,
          trackName,
          artistName,
          albumName,
        );
        return rightScore.compareTo(leftScore);
      });
      final best = results.first;
      DebugLogger.success(
        'LRCLIB',
        '歌词命中: ${best.trackName} - ${best.artistName}',
      );
      return best;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      DebugLogger.warning(
        'LRCLIB',
        '歌词搜索失败: ${e.response?.statusCode ?? e.type}',
      );
    } catch (e, stack) {
      DebugLogger.error('LRCLIB', '歌词搜索异常', e.toString(), stack);
    }
    return null;
  }

  Future<List<LrclibLyrics>> _searchLyricsCandidatesByTitleOnly({
    required String trackName,
    required int limit,
  }) async {
    try {
      final response = await _get(
        '/search',
        queryParameters: {'track_name': trackName.trim()},
        options: Options(
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 16),
        ),
        maxTimeoutRetries: 0,
      );
      if (response?.data is! List<dynamic>) {
        return const [];
      }
      return _rankLyricsCandidates(
        response!.data as List<dynamic>,
        trackName: trackName,
        limit: limit,
      );
    } catch (e, stack) {
      DebugLogger.warning('LRCLIB', '歌词候选标题兜底搜索失败: $e');
      DebugLogger.info('LRCLIB', '歌词候选标题兜底堆栈: $stack');
      return const [];
    }
  }

  List<LrclibLyrics> _rankLyricsCandidates(
    List<dynamic> data, {
    required String trackName,
    String? artistName,
    String? albumName,
    required int limit,
  }) {
    final results = data
        .whereType<Map<String, dynamic>>()
        .map(LrclibLyrics.fromJson)
        .where((lyrics) => lyrics.bestLyrics.trim().isNotEmpty)
        .toList();
    results.sort((left, right) {
      final leftScore = _scoreLyrics(left, trackName, artistName, albumName);
      final rightScore = _scoreLyrics(right, trackName, artistName, albumName);
      return rightScore.compareTo(leftScore);
    });
    if (results.length <= limit) {
      return results;
    }
    return results.take(limit).toList(growable: false);
  }

  Future<Response<dynamic>?> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    int retryCount = 0,
    int maxTimeoutRetries = 0,
    Options? options,
  }) async {
    await _throttleRequests();
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        final retryAfter = _retryAfterDuration(e.response);
        DebugLogger.warning(
          'LRCLIB',
          '触发限流，${retryAfter.inMilliseconds}ms 后重试',
        );
        await Future.delayed(retryAfter);
        await _throttleRequests();
        return _dio.get(
          path,
          queryParameters: queryParameters,
          options: options,
        );
      }
      final timeoutLike =
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError;
      if (timeoutLike && retryCount < maxTimeoutRetries) {
        final delay = Duration(milliseconds: 500 * (retryCount + 1));
        DebugLogger.warning(
          'LRCLIB',
          '请求超时/连接异常，${delay.inMilliseconds}ms 后重试 (${retryCount + 1}/$maxTimeoutRetries)',
        );
        await Future.delayed(delay);
        return _get(
          path,
          queryParameters: queryParameters,
          retryCount: retryCount + 1,
          maxTimeoutRetries: maxTimeoutRetries,
          options: options,
        );
      }
      rethrow;
    }
  }

  bool _isTimeoutLike(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  Future<void> _throttleRequests() {
    _requestQueue = _requestQueue.then((_) async {
      final now = DateTime.now();
      final elapsed = now.difference(_lastRequestAt);
      const minimumSpacing = Duration(milliseconds: 350);
      if (elapsed < minimumSpacing) {
        await Future.delayed(minimumSpacing - elapsed);
      }
      _lastRequestAt = DateTime.now();
    });
    return _requestQueue;
  }

  Duration _retryAfterDuration(Response<dynamic>? response) {
    final headerValue = response?.headers.value('retry-after');
    final seconds = int.tryParse(headerValue ?? '');
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    return const Duration(seconds: 2);
  }

  int _scoreLyrics(
    LrclibLyrics lyrics,
    String trackName,
    String? artistName,
    String? albumName,
  ) {
    var score = lyrics.syncedLyrics?.trim().isNotEmpty == true ? 20 : 0;
    if (_sameNormalized(lyrics.trackName, trackName)) {
      score += 50;
    }
    if (_sameNormalized(lyrics.artistName, artistName)) {
      score += 20;
    }
    if (_sameNormalized(lyrics.albumName, albumName)) {
      score += 10;
    }
    return score;
  }

  bool _sameNormalized(String? left, String? right) {
    final normalizedLeft = _normalize(left);
    final normalizedRight = _normalize(right);
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
  }

  String _normalize(String? value) {
    return (value ?? '').toLowerCase().replaceAll(
      RegExp(r'[\s\-_.,:;!?()\[\]{}]+'),
      '',
    );
  }

  void close() {
    _dio.close();
  }
}

class LrclibLyrics {
  const LrclibLyrics({
    required this.id,
    required this.trackName,
    required this.artistName,
    this.albumName,
    this.duration,
    this.instrumental = false,
    this.plainLyrics,
    this.syncedLyrics,
  });

  final int id;
  final String trackName;
  final String artistName;
  final String? albumName;
  final Duration? duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  String get bestLyrics {
    if (syncedLyrics?.trim().isNotEmpty == true) {
      return syncedLyrics!.trim();
    }
    if (plainLyrics?.trim().isNotEmpty == true) {
      return plainLyrics!.trim();
    }
    return '';
  }

  factory LrclibLyrics.fromJson(Map<String, dynamic> json) {
    final durationSeconds = (json['duration'] as num?)?.toInt();
    return LrclibLyrics(
      id: (json['id'] as num?)?.toInt() ?? 0,
      trackName:
          (json['trackName'] as String?) ?? (json['name'] as String?) ?? '',
      artistName: json['artistName'] as String? ?? '',
      albumName: json['albumName'] as String?,
      duration: durationSeconds != null && durationSeconds > 0
          ? Duration(seconds: durationSeconds)
          : null,
      instrumental: json['instrumental'] as bool? ?? false,
      plainLyrics: json['plainLyrics'] as String?,
      syncedLyrics: json['syncedLyrics'] as String?,
    );
  }
}
