import 'package:flutter/material.dart';
import 'package:music/core/models/app_preferences.dart';

// 刮削源优先级和翻译方式的设置
enum ScrapingTranslationMode {
  // 使用应用设置的语言进行翻译
  preferredLanguage,
  // 保持原始文件名的语言
  original,
}

/// 语言偏好到 iTunes 国家代码的映射
/// iTunes 使用 ISO 3166-1 alpha-2 国家代码
extension LocaleToCountryCode on AppLocalePreference {
  /// 获取对应的 iTunes 国家代码
  /// english → 'US' (United States)
  /// chinese → 'CN' (China)
  /// system → 根据系统语言检测（中文系统返回 CN，其他返回 US）
  String get itunesCountryCode {
    return switch (this) {
      AppLocalePreference.english => 'US',
      AppLocalePreference.chinese => 'CN',
      AppLocalePreference.system => _getSystemCountryCode(),
    };
  }
  
  /// 根据系统语言获取国家代码
  /// 支持多种系统语言，映射到对应的 ISO 3166-1 alpha-2 国家代码
  static String _getSystemCountryCode() {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final languageCode = systemLocale.languageCode.toLowerCase();
    final countryCode = systemLocale.countryCode?.toUpperCase();
    
    // 如果系统已有国家代码，优先使用
    if (countryCode != null && countryCode.length == 2) {
      return countryCode;
    }
    
    // 根据语言代码映射到常见的国家代码
    final languageToCountry = {
      'zh': 'CN',      // 中文 → 中国
      'en': 'US',      // 英文 → 美国
      'es': 'ES',      // 西班牙语 → 西班牙
      'fr': 'FR',      // 法语 → 法国
      'de': 'DE',      // 德语 → 德国
      'ja': 'JP',      // 日语 → 日本
      'ko': 'KR',      // 韩语 → 韩国
      'ru': 'RU',      // 俄语 → 俄罗斯
      'pt': 'PT',      // 葡萄牙语 → 葡萄牙
      'it': 'IT',      // 意大利语 → 意大利
      'ar': 'SA',      // 阿拉伯语 → 沙特阿拉伯
      'hi': 'IN',      // 印地语 → 印度
    };
    
    // 如果找到匹配的语言映射，使用它
    if (languageToCountry.containsKey(languageCode)) {
      return languageToCountry[languageCode]!;
    }
    
    // 默认返回 US
    return 'US';
  }

  /// 获取对应的语言代码用于 MusicBrainz
  /// english → 'en'
  /// chinese → 'zh'
  /// system → 'en' (default)
  String get languageCode {
    return switch (this) {
      AppLocalePreference.english => 'en',
      AppLocalePreference.chinese => 'zh',
      AppLocalePreference.system => 'en',
    };
  }
}

/// 从文件名提取艺术家、标题信息
/// 支持的格式：
/// - "艺术家 - 标题.ext"
/// - "01. 艺术家 - 标题.ext"
/// - "标题.ext"
class TrackMetadataExtractor {
  static const String trackSeparator = ' - '; // 艺术家和标题的分隔符

  /// 从文件名提取艺术家和标题
  /// 返回 (artist, title) 元组
  static (String? artist, String title) extractFromFilename(String filename) {
    // 移除文件扩展名
    String cleanFilename = filename;
    if (cleanFilename.contains('.')) {
      cleanFilename =
          cleanFilename.substring(0, cleanFilename.lastIndexOf('.'));
    }

    // 移除前导数字和点（如 "01. "）
    cleanFilename = cleanFilename.replaceFirst(RegExp(r'^\d+\.\s*'), '');

    // 尝试分解为 "艺术家 - 标题" 格式
    if (cleanFilename.contains(trackSeparator)) {
      final parts = cleanFilename.split(trackSeparator);
      if (parts.length >= 2) {
        final artist = parts[0].trim();
        final title = parts.sublist(1).join(trackSeparator).trim();
        return (artist.isEmpty ? null : artist, title);
      }
    }

    // 如果没有艺术家分隔符，整个就是标题
    return (null, cleanFilename.trim());
  }

  /// 检测原始文件名中的语言
  /// 返回 'zh' (中文), 'en' (英文), 或 null (未知)
  static String? detectLanguage(String filename) {
    // 检测中文字符（CJK Unified Ideographs）
    final chineseRegex = RegExp(r'[\u4E00-\u9FFF]');
    if (chineseRegex.hasMatch(filename)) {
      return 'zh';
    }

    // 检测英文字母
    final englishRegex = RegExp(r'[a-zA-Z]');
    if (englishRegex.hasMatch(filename)) {
      return 'en';
    }

    return null;
  }
}
