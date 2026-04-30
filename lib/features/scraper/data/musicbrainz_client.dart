import 'package:dio/dio.dart';
import 'package:music/core/models/app_preferences.dart';
import 'package:music/core/utils/debug_logger.dart';

/// MusicBrainz API 客户端
/// 用于搜索歌曲和获取元数据
class MusicBrainzClient {
  static const String baseUrl = 'https://musicbrainz.org/ws/2';
  static const int timeoutMs = 10000;
  static const int maxRetries = 3;
  static const int retryDelayMs = 1000;

  final Dio _dio;
  final String? userAgent;

  MusicBrainzClient({String? userAgent})
    : userAgent =
          userAgent ?? 'FlutterMusicPlayer/1.0.0 (contact: dev@example.com)',
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(milliseconds: timeoutMs),
          receiveTimeout: const Duration(milliseconds: timeoutMs),
          contentType: 'application/json',
        ),
      ) {
    _dio.options.headers['User-Agent'] = this.userAgent;
  }

  /// 带重试的API请求辅助方法
  Future<Response?> _makeRequest(
    String method,
    String path, {
    Map<String, dynamic>? queryParameters,
    data,
  }) async {
    int retryCount = 0;
    DioException? lastError;

    while (retryCount < maxRetries) {
      try {
        Response response;
        if (method.toUpperCase() == 'GET') {
          response = await _dio.get(path, queryParameters: queryParameters);
        } else if (method.toUpperCase() == 'POST') {
          response = await _dio.post(
            path,
            queryParameters: queryParameters,
            data: data,
          );
        } else {
          return null;
        }

        // 检查是否是503错误
        if (response.statusCode == 503 && retryCount < maxRetries - 1) {
          retryCount++;
          final delayMs = retryDelayMs * retryCount;
          DebugLogger.warning(
            'MusicBrainz',
            '服务暂时不可用 (503)，$delayMs ms 后重试... ($retryCount/$maxRetries)',
          );
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }

        return response;
      } on DioException catch (e) {
        lastError = e;

        // 记录错误详情
        _logDioException('请求失败', e, retryCount);

        // 可重试的错误类型
        final isRetryable =
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown || // 网络通用错误
            e.type == DioExceptionType.connectionError; // 连接错误

        if (isRetryable && retryCount < maxRetries - 1) {
          retryCount++;
          final delayMs = retryDelayMs * retryCount;
          DebugLogger.warning(
            'MusicBrainz',
            '[重试 $retryCount/$maxRetries] ${e.type.toString()}，$delayMs ms 后重试...',
          );
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }

        // 如果不可重试或已达到重试次数，抛出异常
        rethrow;
      }
    }

    // 所有重试都失败了
    if (lastError != null) {
      throw lastError;
    }

    return null;
  }

  /// 搜索录音（歌曲）
  /// query: 艺术家名 - 歌曲名 或 歌曲名
  /// limit: 最多返回多少结果
  /// localePreference: 用户的语言偏好，用于选择合适的别名
  Future<List<MusicBrainzRecording>> searchRecordings(
    String query, {
    int limit = 10,
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async {
    try {
      final queryParams = {
        'query': query,
        'limit': limit,
        'fmt': 'json',
        'inc': 'artists+releases+media+cover-art-front+aliases', // 添加 aliases
      };

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      final fullUrl = '$baseUrl/recording?$queryString';

      final requestLog =
          '请求URL: $fullUrl\n请求参数: ${queryParams.toString()}\n语言偏好: $localePreference';
      DebugLogger.database('MusicBrainz', '【API 请求】', requestLog);

      final response = await _makeRequest(
        'GET',
        '/recording',
        queryParameters: queryParams,
      );

      if (response?.statusCode == 200 && response?.data is Map) {
        final data = response!.data as Map<String, dynamic>;
        final recordings = data['recordings'] as List<dynamic>? ?? [];

        DebugLogger.success(
          'MusicBrainz',
          '搜索成功: 找到 ${recordings.length} 个结果 (查询: "$query")',
        );

        final results = recordings
            .whereType<Map<String, dynamic>>()
            .map((r) {
              try {
                return MusicBrainzRecording.fromJson(
                  r,
                  localePreference: localePreference,
                );
              } catch (e) {
                DebugLogger.warning(
                  'MusicBrainz',
                  '解析录音对象失败: ${r['title'] ?? "unknown"} - $e',
                );
                return null;
              }
            })
            .whereType<MusicBrainzRecording>()
            .toList();

        DebugLogger.database(
          'MusicBrainz',
          '已解析录音对象',
          '${results.length} 个有效结果',
        );
        return results;
      } else {
        DebugLogger.warning(
          'MusicBrainz',
          '不预期的响应状态码: ${response?.statusCode}',
        );
        return [];
      }
    } on DioException catch (e) {
      DebugLogger.error(
        'MusicBrainz',
        'DioException - ${e.type}',
        '${e.message}',
        e.stackTrace,
      );
      if (e.type == DioExceptionType.connectionTimeout) {
        DebugLogger.error(
          'MusicBrainz',
          '连接超时',
          'URL: ${e.requestOptions.path}',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        DebugLogger.error('MusicBrainz', '接收超时', '可能是网络太慢或 MusicBrainz 服务器响应慢');
      }
      return [];
    } catch (e, stack) {
      DebugLogger.error('MusicBrainz', '搜索录音异常', e.toString(), stack);
      return [];
    }
  }

  /// 搜索艺术家和歌曲组合
  /// 使用多个查询策略来提高成功率
  Future<List<MusicBrainzRecording>> searchByArtistAndTitle(
    String artist,
    String title, {
    int limit = 10,
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async {
    DebugLogger.network(
      'MusicBrainz',
      'searchByArtistAndTitle',
      '艺术家: "$artist", 标题: "$title", 语言偏好: $localePreference',
    );

    // 策略 1: 尝试 artist + recording 组合（Lucene 查询）
    final query1 = 'artist:"$artist" AND recording:"$title"';
    var results = await searchRecordings(
      query1,
      limit: limit,
      localePreference: localePreference,
    );
    if (results.isNotEmpty) {
      DebugLogger.success('MusicBrainz', '查询策略1成功: $query1');
      return results;
    }

    // 策略 2: 尝试不带引号的查询
    final query2 = 'artist:$artist AND recording:$title';
    results = await searchRecordings(
      query2,
      limit: limit,
      localePreference: localePreference,
    );
    if (results.isNotEmpty) {
      DebugLogger.success('MusicBrainz', '查询策略2成功: $query2');
      return results;
    }

    // 策略 3: 只用标题搜索（作为后备）
    results = await searchRecordings(
      title,
      limit: limit,
      localePreference: localePreference,
    );
    if (results.isNotEmpty) {
      DebugLogger.success('MusicBrainz', '查询策略3成功: 标题搜索');
      return results;
    }

    DebugLogger.warning(
      'MusicBrainz',
      '所有查询策略都未返回结果 - 标题: "$title", 艺术家: "$artist"',
    );
    return [];
  }

  /// 获取所有结果（用于前缀搜索）
  Future<List<MusicBrainzRecording>> searchWithPrefix(
    String prefix, {
    int limit = 20,
  }) async {
    // 先尝试精确搜索
    final recordings = await searchRecordings(prefix, limit: limit);

    // 如果结果太少，尝试前缀搜索
    if (recordings.isEmpty) {
      final prefixQuery = 'recording:$prefix';
      return searchRecordings(prefixQuery, limit: limit);
    }

    return recordings;
  }

  /// 通过 ISRC 码查询录音 ID
  /// 接口：GET https://musicbrainz.org/ws/2/isrc/{isrc}?fmt=json&inc=aliases+artist-credits+releases
  /// isrc: 国际标准录音代码 (e.g., "TWK970701302")
  /// 返回 MusicBrainzRecording 或 null
  Future<MusicBrainzRecording?> searchByIsrc(
    String isrc, {
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async {
    try {
      final queryParams = {
        'fmt': 'json',
        'inc': 'aliases+artist-credits+releases',
      };

      final fullUrl =
          '$baseUrl/isrc/$isrc?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&')}';
      final requestLog =
          '\n【第2步】MusicBrainz ISRC 查询\n请求URL: $fullUrl\nISRC: $isrc\n语言偏好: $localePreference';
      DebugLogger.database('MusicBrainz', '【ISRC查询】', requestLog);

      final response = await _makeRequest(
        'GET',
        '/isrc/$isrc',
        queryParameters: queryParams,
      );

      if (response?.statusCode == 200 && response?.data is Map) {
        final data = response!.data as Map<String, dynamic>;
        final recordings = data['recordings'] as List<dynamic>? ?? [];

        if (recordings.isEmpty) {
          DebugLogger.warning('MusicBrainz', '通过 ISRC 未找到录音: $isrc');
          return null;
        }

        // 获取第一个录音
        final recording = recordings[0] as Map<String, dynamic>;
        final result = MusicBrainzRecording.fromJson(
          recording,
          localePreference: localePreference,
        );

        DebugLogger.success(
          'MusicBrainz',
          '通过 ISRC 查询成功: $isrc -> ${result.title} by ${result.artistName}',
        );
        return result;
      } else {
        DebugLogger.warning(
          'MusicBrainz',
          '通过 ISRC 查询失败: HTTP ${response?.statusCode}',
        );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout) {
        DebugLogger.error('MusicBrainz', '通过 ISRC 查询超时', 'ISRC: $isrc');
      } else {
        DebugLogger.error(
          'MusicBrainz',
          '通过 ISRC 查询 DioException - ${e.type}',
          '${e.message}',
          e.stackTrace,
        );
      }
    } catch (e, stack) {
      DebugLogger.error('MusicBrainz', '通过 ISRC 查询异常', e.toString(), stack);
    }
    return null;
  }

  /// 获取单个录音的详细信息（包括别名）
  /// 接口：GET https://musicbrainz.org/ws/2/recording/{mbid}?inc=aliases+artist-credits+releases&fmt=json
  /// id: MusicBrainz recording ID (MBID)
  /// localePreference: 用户的语言偏好，用于选择合适的别名
  Future<MusicBrainzRecording?> getRecordingDetailsById(
    String id, {
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) async {
    try {
      final queryParams = {
        'inc': 'aliases+artist-credits+releases',
        'fmt': 'json',
      };

      final fullUrl =
          '$baseUrl/recording/$id?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&')}';
      final requestLog =
          '\n【第3步】MusicBrainz Recording 详情查询\n请求URL: $fullUrl\nRecording ID: $id\n语言偏好: $localePreference';
      DebugLogger.database('MusicBrainz', '【详情查询】', requestLog);

      final response = await _makeRequest(
        'GET',
        '/recording/$id',
        queryParameters: queryParams,
      );

      if (response?.statusCode == 200 && response?.data is Map) {
        DebugLogger.success('MusicBrainz', '获取录音详情成功: $id');
        return MusicBrainzRecording.fromJson(
          response!.data,
          localePreference: localePreference,
        );
      } else {
        DebugLogger.warning(
          'MusicBrainz',
          '获取录音详情失败: HTTP ${response?.statusCode}',
        );
      }
    } on DioException catch (e) {
      DebugLogger.error(
        'MusicBrainz',
        '获取录音详情 DioException - ${e.type}',
        '${e.message}',
        e.stackTrace,
      );
    } catch (e, stack) {
      DebugLogger.error('MusicBrainz', '获取录音详情异常', e.toString(), stack);
    }
    return null;
  }

  /// 记录 DioException 详情
  void _logDioException(String action, DioException e, int retryCount) {
    final errorTypeStr = _dioExceptionTypeToString(e.type);
    final errorDetails = [
      'Error type: $errorTypeStr',
      if (e.message case final String msg when msg.isNotEmpty) 'Message: $msg',
      if (e.requestOptions.path case final String path when path.isNotEmpty)
        'Path: $path',
      if (e.response?.statusCode case final int code) 'HTTP status: $code',
      'Attempt: $retryCount/${maxRetries - 1}',
    ].join(' | ');

    DebugLogger.warning('MusicBrainz', '$action - $errorDetails');
  }

  /// 将 DioExceptionType 转换为可读的字符串
  String _dioExceptionTypeToString(DioExceptionType type) {
    return switch (type) {
      DioExceptionType.badCertificate => '不安全的证书 (SSL/TLS)',
      DioExceptionType.badResponse => '无效响应',
      DioExceptionType.cancel => '请求被取消',
      DioExceptionType.connectionError => '连接错误',
      DioExceptionType.connectionTimeout => '连接超时',
      DioExceptionType.receiveTimeout => '接收超时',
      DioExceptionType.sendTimeout => '发送超时',
      DioExceptionType.unknown => '未知错误 (网络问题)',
    };
  }

  /// 关闭客户端
  void close() {
    _dio.close();
  }
}

/// MusicBrainz 录音模型
class MusicBrainzRecording {
  final String id; // MusicBrainz ID
  final String title; // 歌曲名
  final String? artistName; // 艺术家名
  final String? albumTitle; // 专辑名
  final Duration? duration; // 歌曲时长
  final String? coverArtUrl; // 封面 URL
  final int? releaseYear; // 发布年份
  final double? score; // 搜索匹配度（0-100）

  MusicBrainzRecording({
    required this.id,
    required this.title,
    this.artistName,
    this.albumTitle,
    this.duration,
    this.coverArtUrl,
    this.releaseYear,
    this.score,
  });

  /// 根据语言偏好选择合适的本地化名称
  /// primaryName: 主要名称（英文或默认）
  /// aliases: 别名列表
  /// localePreference: 用户的语言偏好
  static String? _selectLocalizedName(
    String? primaryName,
    List<dynamic>? aliases,
    AppLocalePreference localePreference,
  ) {
    if (primaryName == null || primaryName.isEmpty) {
      return primaryName;
    }

    // 打印别名详情用于调试
    if (aliases != null &&
        aliases.isNotEmpty &&
        localePreference == AppLocalePreference.chinese) {
      final aliasesList = aliases.whereType<Map<String, dynamic>>().toList();
      final aliasDetails = StringBuffer();
      for (int i = 0; i < aliasesList.length; i++) {
        final alias = aliasesList[i];
        aliasDetails.writeln(
          '  [$i] name="${alias['name']}", locale="${alias['locale']}"',
        );
      }
      DebugLogger.database(
        'MusicBrainz',
        '【别名列表详情】',
        '主名称: "$primaryName"\n语言偏好: $localePreference\n别名列表:\n$aliasDetails',
      );
    }

    // 如果没有别名或用户选择系统/英文，返回主要名称
    if (aliases == null ||
        aliases.isEmpty ||
        localePreference == AppLocalePreference.system ||
        localePreference == AppLocalePreference.english) {
      return primaryName;
    }

    // 用户选择中文，查找中文别名（优先简体中文）
    if (localePreference == AppLocalePreference.chinese) {
      // 第一轮：优先查找简体中文别名 (zh-CN 或 zh-Hans)
      for (final alias in aliases) {
        if (alias is Map<String, dynamic>) {
          final name = alias['name'] as String?;
          final locale = alias['locale'] as String?;

          if (name != null &&
              name.isNotEmpty &&
              locale != null &&
              (locale == 'zh-CN' || locale == 'zh-Hans')) {
            DebugLogger.scraping(
              'MusicBrainzRecording',
              '✓ 选择简体中文别名: "$primaryName" -> "$name" (locale: $locale)',
            );
            return name;
          }
        }
      }

      // 第二轮：如果没找到简体中文，查找其他中文别名
      for (final alias in aliases) {
        if (alias is Map<String, dynamic>) {
          final name = alias['name'] as String?;
          final locale = alias['locale'] as String?;

          if (name != null &&
              name.isNotEmpty &&
              locale != null &&
              locale.startsWith('zh')) {
            DebugLogger.warning(
              'MusicBrainz',
              '⚠ 选择其他中文别名（非zh-CN）: "$primaryName" -> "$name" (locale: $locale)',
            );
            return name;
          }
        }
      }

      DebugLogger.warning('MusicBrainz', '✗ 未找到中文别名，使用主要名称: "$primaryName"');
    }

    // 如果没找到匹配的别名，返回主要名称
    return primaryName;
  }

  /// 从 JSON 解析
  /// localePreference: 用户的语言偏好，用于选择合适的别名
  factory MusicBrainzRecording.fromJson(
    Map<String, dynamic> json, {
    AppLocalePreference localePreference = AppLocalePreference.system,
  }) {
    // 提取艺术家名（支持别名）
    String? artistName;
    final artistCredit = json['artist-credit'] as List<dynamic>?;
    if (artistCredit != null && artistCredit.isNotEmpty) {
      final credit = artistCredit[0] as Map<String, dynamic>;
      final artist = credit['artist'] as Map<String, dynamic>?;
      if (artist != null) {
        artistName = _selectLocalizedName(
          artist['name'] as String?,
          artist['aliases'] as List<dynamic>?,
          localePreference,
        );
      }
    }

    // 提取专辑名（从 releases，支持别名）
    String? albumTitle;
    final releases = json['releases'] as List<dynamic>?;
    if (releases != null && releases.isNotEmpty) {
      final release = releases[0] as Map<String, dynamic>;
      albumTitle = _selectLocalizedName(
        release['title'] as String?,
        release['aliases'] as List<dynamic>?,
        localePreference,
      );
    }

    // 提取歌曲标题（支持别名）
    final title =
        _selectLocalizedName(
          json['title'] as String?,
          json['aliases'] as List<dynamic>?,
          localePreference,
        ) ??
        '';

    // 提取时长
    Duration? duration;
    final durationMs = json['length'] as int?;
    if (durationMs != null && durationMs > 0) {
      duration = Duration(milliseconds: durationMs);
    }

    // 构建封面 URL
    String? coverArtUrl;
    final id = json['id'] as String?;
    String? releaseId;
    if (releases != null && releases.isNotEmpty) {
      final release = releases[0] as Map<String, dynamic>;
      releaseId = release['id'] as String?;
    }
    if (releaseId != null && releaseId.isNotEmpty) {
      coverArtUrl =
          'https://coverartarchive.org/release/$releaseId/front-500.jpg';
    }

    // 提取发布年份
    int? releaseYear;
    if (releases != null && releases.isNotEmpty) {
      final release = releases[0] as Map<String, dynamic>;
      final date = release['date'] as String?;
      if (date != null && date.contains('-')) {
        releaseYear = int.tryParse(date.split('-')[0]);
      }
    }

    return MusicBrainzRecording(
      id: id ?? '',
      title: title,
      artistName: artistName,
      albumTitle: albumTitle,
      duration: duration,
      coverArtUrl: coverArtUrl,
      releaseYear: releaseYear,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      '''
MusicBrainzRecording(
  title: $title,
  artist: $artistName,
  album: $albumTitle,
  score: $score,
)
  ''';
}
