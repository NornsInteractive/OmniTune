/// 文件名解析器
/// 支持多种命名格式，高效提取歌曲信息
class FileNameParser {
  /// 解析文件名，返回提取的信息
  static ParsedFilename parse(String filename) {
    // 移除文件扩展名
    final withoutExt = _removeExtension(filename);

    // 尝试各种解析模式，按优先级排列
    ParsedFilename? result;

    // 模式优先级（从最具体到最通用）
    result ??= _parseArtistDashSong(withoutExt);        // 周杰伦 - 青花瓷
    result ??= _parseArtistUnderscoreSong(withoutExt);  // 周杰伦_青花瓷
    result ??= _parseArtistBracketSong(withoutExt);     // 青花瓷【周杰伦】
    result ??= _parseTrackDashSong(withoutExt);         // 01 - 青花瓷
    result ??= _parsePrefixSong(withoutExt);            // [专辑] 01 青花瓷
    result ??= _parseSimpleSong(withoutExt);            // 01.青花瓷 或 01 青花瓷

    // 最后的回退方案：整个字符串作为歌曲名
    result ??= ParsedFilename(
      title: withoutExt.trim(),
      artist: null,
      trackNumber: null,
      prefix: null,
    );

    return result;
  }

  /// 模式：周杰伦 - 青花瓷
  static ParsedFilename? _parseArtistDashSong(String text) {
    final dash = text.lastIndexOf(' - ');
    if (dash > 0 && dash < text.length - 3) {
      final left = text.substring(0, dash).trim();
      final right = text.substring(dash + 3).trim();

      // 左侧看起来像艺术家（不含数字在最前面）
      if (left.isNotEmpty && !_startsWithDigits(left) && right.isNotEmpty) {
        return ParsedFilename(
          title: _cleanTitle(right),
          artist: _cleanArtist(left),
          trackNumber: null,
          prefix: null,
        );
      }
    }
    return null;
  }

  /// 模式：周杰伦_青花瓷
  static ParsedFilename? _parseArtistUnderscoreSong(String text) {
    final underscore = text.lastIndexOf('_');
    if (underscore > 0 && underscore < text.length - 1) {
      final left = text.substring(0, underscore).trim();
      final right = text.substring(underscore + 1).trim();

      if (left.isNotEmpty && !_startsWithDigits(left) && right.isNotEmpty) {
        return ParsedFilename(
          title: _cleanTitle(right),
          artist: _cleanArtist(left),
          trackNumber: null,
          prefix: null,
        );
      }
    }
    return null;
  }

  /// 模式：青花瓷【周杰伦】
  static ParsedFilename? _parseArtistBracketSong(String text) {
    final match = RegExp(r'(.+?)【(.+?)】\s*$').firstMatch(text);
    if (match != null) {
      final title = _cleanTitle(match.group(1) ?? '');
      final artist = _cleanArtist(match.group(2) ?? '');
      if (title.isNotEmpty && artist.isNotEmpty) {
        return ParsedFilename(
          title: title,
          artist: artist,
          trackNumber: null,
          prefix: null,
        );
      }
    }
    return null;
  }

  /// 模式：01 - 青花瓷
  static ParsedFilename? _parseTrackDashSong(String text) {
    final match = RegExp(r'^(\d+)\s*[-_]\s*(.+?)(?:\s*\(Live.*?\))?\s*$').firstMatch(text);
    if (match != null) {
      final track = match.group(1);
      final title = _cleanTitle(match.group(2) ?? '');
      if (title.isNotEmpty) {
        return ParsedFilename(
          title: title,
          artist: null,
          trackNumber: track,
          prefix: null,
        );
      }
    }
    return null;
  }

  /// 模式：[专辑] 01 青花瓷
  static ParsedFilename? _parsePrefixSong(String text) {
    final match = RegExp(r'^\[(.+?)\]\s*(\d+)?\s*(.+?)(?:\s*\(Live.*?\))?\s*$').firstMatch(text);
    if (match != null) {
      final prefix = match.group(1);
      final track = match.group(2);
      final title = _cleanTitle(match.group(3) ?? '');
      if (title.isNotEmpty) {
        return ParsedFilename(
          title: title,
          artist: null,
          trackNumber: track,
          prefix: prefix,
        );
      }
    }
    return null;
  }

  /// 模式：01.青花瓷 或 01 青花瓷
  static ParsedFilename? _parseSimpleSong(String text) {
    final match = RegExp(r'^(\d+)[.·\s]+(.+?)(?:\s*\(Live.*?\))?\s*$').firstMatch(text);
    if (match != null) {
      final track = match.group(1);
      final title = _cleanTitle(match.group(2) ?? '');
      if (title.isNotEmpty) {
        return ParsedFilename(
          title: title,
          artist: null,
          trackNumber: track,
          prefix: null,
        );
      }
    }
    return null;
  }

  /// 移除文件扩展名
  static String _removeExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1 || lastDot == 0) return filename;
    return filename.substring(0, lastDot);
  }

  /// 检查字符串是否以数字开头
  static bool _startsWithDigits(String text) {
    if (text.isEmpty) return false;
    return RegExp(r'^\d').hasMatch(text);
  }

  /// 清理歌曲名（移除特殊标记和括号内容）
  static String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ')    // 移除 (Live版) 等
        .replaceAll(RegExp(r'\s*【.*?】\s*'), ' ')     // 移除【】括号
        .replaceAll(RegExp(r'\s*\[.*?\]\s*'), ' ')     // 移除 [] 括号
        .replaceAll(RegExp(r'\s+'), ' ')               // 多个空格改为单个
        .trim();
  }

  /// 清理艺术家名
  static String _cleanArtist(String artist) {
    return artist
        .replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ')
        .replaceAll(RegExp(r'\s*【.*?】\s*'), ' ')
        .replaceAll(RegExp(r'\s*\[.*?\]\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// 解析结果
class ParsedFilename {
  final String title;           // 提取的歌曲名
  final String? artist;         // 提取的艺术家（可能为 null）
  final String? trackNumber;    // 提取的曲号（如"01"）
  final String? prefix;         // 识别的前缀（如"[专辑]"）

  ParsedFilename({
    required this.title,
    required this.artist,
    required this.trackNumber,
    required this.prefix,
  });

  @override
  String toString() => '''
ParsedFilename(
  title: $title,
  artist: $artist,
  trackNumber: $trackNumber,
  prefix: $prefix,
)
  ''';
}
