import 'dart:ui' as ui;

import 'package:pinyin/pinyin.dart';

import '../models/app_preferences.dart';

bool shouldNormalizeToSimplifiedChinese(AppLocalePreference localePreference) {
  return switch (localePreference) {
    AppLocalePreference.chinese => true,
    AppLocalePreference.english => false,
    AppLocalePreference.system =>
      ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase() == 'zh',
  };
}

String normalizeChineseTextForLocale(
  String text,
  AppLocalePreference localePreference,
) {
  final normalized = text.trim();
  if (normalized.isEmpty ||
      !shouldNormalizeToSimplifiedChinese(localePreference)) {
    return normalized;
  }

  return ChineseHelper.convertToSimplifiedChinese(normalized);
}
