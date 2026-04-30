import 'package:dio/dio.dart';
import 'package:music/core/utils/debug_logger.dart';

/// Deezer API 客户端
/// 用于搜索歌曲并获取 ISRC 码
class DeezerClient {
  static const String baseUrl = 'https://api.deezer.com';
  static const int timeoutMs = 10000;

  final Dio _dio;
  final String userAgent;

  DeezerClient({String? userAgent})
      : userAgent = userAgent ?? 'FlutterMusicPlayer/1.0.0 (contact: dev@example.com)',
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(milliseconds: timeoutMs),
          receiveTimeout: const Duration(milliseconds: timeoutMs),
          contentType: 'application/json',
        )) {
    _dio.options.headers['User-Agent'] = this.userAgent;
  }

  /// 搜索歌曲并获取 ISRC
  /// 接口：GET https://api.deezer.com/search/track?q={artist}+{track}&limit=10
  /// 返回 ISRC 码或 null
  Future<String?> searchAndGetIsrc(
    String query, {
    String? artist,
    String? title,
  }) async {
    try {
      // 使用标准的 Deezer 搜索格式：艺术家名 + 歌曲名
      final searchQuery = artist != null && title != null
          ? '$artist+$title'
          : query;

      final fullUrl = '$baseUrl/search/track?q=${Uri.encodeComponent(searchQuery)}&limit=10';
      final requestLog = '\n【第1步】Deezer ISRC 搜索\n请求URL: $fullUrl\n艺术家: $artist\n歌曲: $title';
      DebugLogger.database('Deezer', '【ISRC搜索】', requestLog);

      final response = await _dio.get(
        '/search/track',
        queryParameters: {
          'q': searchQuery,
          'limit': 10,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final tracks = data['data'] as List<dynamic>? ?? [];

        if (tracks.isEmpty) {
          DebugLogger.warning('Deezer',
              '搜索未返回结果 - 查询: "$searchQuery"');
          return null;
        }

        // 获取第一个结果的 ISRC
        final firstTrack = tracks[0] as Map<String, dynamic>;
        final isrc = firstTrack['isrc'] as String?;

        if (isrc != null && isrc.isNotEmpty) {
          DebugLogger.success('Deezer',
              '成功获取 ISRC: $isrc (歌曲: ${firstTrack['title']})');
          return isrc;
        } else {
          DebugLogger.warning('Deezer',
              '第一个搜索结果没有 ISRC - 查询: "$searchQuery"');
          
          // 尝试从其他结果获取 ISRC
          for (int i = 1; i < tracks.length; i++) {
            final track = tracks[i] as Map<String, dynamic>;
            final trackIsrc = track['isrc'] as String?;
            if (trackIsrc != null && trackIsrc.isNotEmpty) {
              DebugLogger.success('Deezer',
                  '从第 ${i + 1} 个结果获取 ISRC: $trackIsrc');
              return trackIsrc;
            }
          }
          
          return null;
        }
      } else {
        DebugLogger.warning('Deezer',
            '搜索失败: HTTP ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      DebugLogger.error('Deezer', 'DioException - ${e.type}',
          '${e.message}', e.stackTrace);
      return null;
    } catch (e, stack) {
      DebugLogger.error('Deezer', '搜索歌曲异常', e.toString(), stack);
      return null;
    }
  }

  /// 关闭客户端
  void close() {
    _dio.close();
  }
}
