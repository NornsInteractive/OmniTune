import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:music/core/utils/debug_logger.dart';

/// iTunes Search API 客户端
/// 用于搜索歌曲并获取基本元数据（艺术家、标题、专辑、封面）
class ITunesClient {
  static const String baseUrl = 'https://itunes.apple.com';
  static const int timeoutMs = 10000;

  final Dio _dio;
  final String userAgent;

  ITunesClient({String? userAgent})
    : userAgent =
          userAgent ?? 'FlutterMusicPlayer/1.0.0 (contact: dev@example.com)',
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(milliseconds: timeoutMs),
          receiveTimeout: const Duration(milliseconds: timeoutMs),
          contentType: 'application/json',
          responseType: ResponseType.json, // 确保响应被解析为 JSON
        ),
      ) {
    _dio.options.headers['User-Agent'] = this.userAgent;
  }

  /// 搜索歌曲获取基本元数据
  /// 接口：https://itunes.apple.com/search?term={artist}+{title}&entity=song&limit=1
  /// 返回 ITunesTrack 或 null
  Future<ITunesTrack?> searchTrack({String? artist, String? title}) async {
    try {
      // 构建搜索词
      final searchTerm =
          artist != null &&
              artist.trim().isNotEmpty &&
              title != null &&
              title.trim().isNotEmpty
          ? '${artist.trim()} ${title.trim()}'
          : title ?? '';

      if (searchTerm.isEmpty) {
        DebugLogger.warning('iTunes', '搜索词为空');
        return null;
      }

      final fullUrl =
          '$baseUrl/search?term=${Uri.encodeComponent(searchTerm)}&entity=song&limit=1';
      final requestLog =
          '\n【第1步】iTunes Search API 获取元数据\n请求URL: $fullUrl\n艺术家: $artist\n歌曲: $title';
      DebugLogger.database('iTunes', '【搜索元数据】', requestLog);

      final response = await _dio.get(
        '/search',
        queryParameters: {'term': searchTerm, 'entity': 'song', 'limit': 1},
      );

      // 调试：打印响应数据类型
      DebugLogger.database(
        'iTunes',
        '【响应调试】',
        '状态码: ${response.statusCode}, 数据类型: ${response.data.runtimeType}',
      );

      if (response.statusCode != 200) {
        DebugLogger.warning('iTunes', '搜索失败: HTTP ${response.statusCode}');
        return null;
      }

      // 处理不同类型的响应数据
      Map<String, dynamic> data;

      if (response.data is Map) {
        data = response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        // 如果响应是字符串，手动解析 JSON
        try {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
          DebugLogger.database('iTunes', '【JSON 解析】', '从字符串手动解析 JSON 成功');
        } catch (e) {
          DebugLogger.error('iTunes', '【JSON 解析失败】', e.toString());
          return null;
        }
      } else {
        DebugLogger.error(
          'iTunes',
          '【响应数据类型异常】',
          '期望 Map 或 String，收到: ${response.data.runtimeType}',
        );
        return null;
      }

      final resultCount = data['resultCount'] as int? ?? 0;

      if (resultCount == 0) {
        DebugLogger.warning('iTunes', '搜索未返回结果 - 搜索词: "$searchTerm"');
        return null;
      }

      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) {
        DebugLogger.warning('iTunes', '结果列表为空');
        return null;
      }

      // 获取第一个结果
      final track = results[0] as Map<String, dynamic>;
      final itunesTrack = ITunesTrack.fromJson(track);

      DebugLogger.success(
        'iTunes',
        '【搜索成功✓】"${itunesTrack.trackName}" by "${itunesTrack.artistName}" from "${itunesTrack.collectionName}"',
      );
      return itunesTrack;
    } on DioException catch (e) {
      DebugLogger.error(
        'iTunes',
        '【搜歌】DioException - ${e.type}',
        '${e.message}',
        e.stackTrace,
      );
      return null;
    } catch (e, stack) {
      DebugLogger.error('iTunes', '【搜歌异常】', e.toString(), stack);
      return null;
    }
  }

  /// 搜索歌曲并指定国家代码
  /// 接口：https://itunes.apple.com/search?term={artist}+{title}&entity=song&limit=1&country={countryCode}
  /// country: ISO 3166-1 alpha-2 国家代码（如 'CN', 'US'）
  /// 返回 ITunesTrack 或 null
  Future<ITunesTrack?> searchTrackWithCountry({
    String? artist,
    String? title,
    required String country,
  }) async {
    try {
      // 构建搜索词
      final searchTerm =
          artist != null &&
              artist.trim().isNotEmpty &&
              title != null &&
              title.trim().isNotEmpty
          ? '${artist.trim()} ${title.trim()}'
          : title ?? '';

      if (searchTerm.isEmpty) {
        DebugLogger.warning('iTunes', '搜索词为空');
        return null;
      }

      final fullUrl =
          '$baseUrl/search?term=${Uri.encodeComponent(searchTerm)}&entity=song&limit=1&country=$country';
      final requestLog =
          '\n【iTunes 搜索】\n请求URL: $fullUrl\n艺术家: $artist\n歌曲: $title\n国家: $country';
      DebugLogger.database('iTunes', '【国家搜索】', requestLog);

      final response = await _dio.get(
        '/search',
        queryParameters: {
          'term': searchTerm,
          'entity': 'song',
          'limit': 1,
          'country': country,
        },
      );

      // 调试：打印响应数据类型
      DebugLogger.database(
        'iTunes',
        '【响应调试】',
        '状态码: ${response.statusCode}, 数据类型: ${response.data.runtimeType}',
      );

      if (response.statusCode != 200) {
        DebugLogger.warning('iTunes', '搜索失败: HTTP ${response.statusCode}');
        return null;
      }

      // 处理不同类型的响应数据
      Map<String, dynamic> data;

      if (response.data is Map) {
        data = response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        // 如果响应是字符串，手动解析 JSON
        try {
          data = jsonDecode(response.data as String) as Map<String, dynamic>;
          DebugLogger.database('iTunes', '【JSON 解析】', '从字符串手动解析 JSON 成功');
        } catch (e) {
          DebugLogger.error('iTunes', '【JSON 解析失败】', e.toString());
          return null;
        }
      } else {
        DebugLogger.error(
          'iTunes',
          '【响应数据类型异常】',
          '期望 Map 或 String，收到: ${response.data.runtimeType}',
        );
        return null;
      }

      final resultCount = data['resultCount'] as int? ?? 0;

      if (resultCount == 0) {
        DebugLogger.warning('iTunes', '搜索未返回结果 - 搜索词: "$searchTerm"');
        return null;
      }

      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) {
        DebugLogger.warning('iTunes', '结果列表为空');
        return null;
      }

      // 获取第一个结果
      final track = results[0] as Map<String, dynamic>;
      final itunesTrack = ITunesTrack.fromJson(track);

      DebugLogger.success(
        'iTunes',
        '【搜索成功✓】"${itunesTrack.trackName}" by "${itunesTrack.artistName}" from "${itunesTrack.collectionName}" (国家: $country)',
      );
      return itunesTrack;
    } on DioException catch (e) {
      DebugLogger.error(
        'iTunes',
        '【国家搜索】DioException - ${e.type}',
        '${e.message}',
        e.stackTrace,
      );
      return null;
    } catch (e, stack) {
      DebugLogger.error('iTunes', '【国家搜索异常】', e.toString(), stack);
      return null;
    }
  }

  Future<List<ITunesTrack>> searchTracksWithCountry({
    String? artist,
    String? title,
    required String country,
    int limit = 15,
  }) async {
    try {
      final searchTerm =
          artist != null &&
              artist.trim().isNotEmpty &&
              title != null &&
              title.trim().isNotEmpty
          ? '${artist.trim()} ${title.trim()}'
          : title ?? '';

      if (searchTerm.isEmpty) {
        DebugLogger.warning('iTunes', '搜索词为空');
        return const [];
      }

      final response = await _dio.get(
        '/search',
        queryParameters: {
          'term': searchTerm,
          'entity': 'song',
          'limit': limit.clamp(1, 40),
          'country': country,
        },
      );

      if (response.statusCode != 200) {
        DebugLogger.warning('iTunes', '搜索失败: HTTP ${response.statusCode}');
        return const [];
      }

      Map<String, dynamic> data;
      if (response.data is Map) {
        data = response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        data = jsonDecode(response.data as String) as Map<String, dynamic>;
      } else {
        return const [];
      }

      final results = data['results'] as List<dynamic>? ?? const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(ITunesTrack.fromJson)
          .where(
            (track) =>
                track.trackName.trim().isNotEmpty &&
                track.artistName.trim().isNotEmpty,
          )
          .toList(growable: false);
    } catch (e, stack) {
      DebugLogger.error('iTunes', '【国家多结果搜索异常】', e.toString(), stack);
      return const [];
    }
  }

  /// 关闭客户端
  void close() {
    _dio.close();
  }
}

/// iTunes 歌曲数据模型
class ITunesTrack {
  final String trackId; // iTunes Track ID
  final String trackName; // 歌曲名
  final String artistName; // 艺术家名
  final String collectionName; // 专辑名
  final String? artworkUrl; // 封面 URL (100x100)
  final int trackTimeMillis; // 歌曲时长 (毫秒)
  final String? releaseDate; // 发布日期
  final String? primaryGenreName; // 主要流派

  ITunesTrack({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    required this.collectionName,
    this.artworkUrl,
    required this.trackTimeMillis,
    this.releaseDate,
    this.primaryGenreName,
  });

  /// 从 JSON 解析
  factory ITunesTrack.fromJson(Map<String, dynamic> json) {
    final artworkUrl = json['artworkUrl100'] as String?;
    final trackTimeMillis = json['trackTimeMillis'] as int? ?? 0;
    final releaseDate = json['releaseDate'] as String?;

    return ITunesTrack(
      trackId: json['trackId']?.toString() ?? '',
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      collectionName: json['collectionName'] as String? ?? '',
      artworkUrl: artworkUrl,
      trackTimeMillis: trackTimeMillis,
      releaseDate: releaseDate,
      primaryGenreName: json['primaryGenreName'] as String?,
    );
  }

  @override
  String toString() =>
      '''
ITunesTrack(
  trackName: $trackName,
  artist: $artistName,
  album: $collectionName,
  duration: ${Duration(milliseconds: trackTimeMillis).inSeconds}s,
)
  ''';
}
