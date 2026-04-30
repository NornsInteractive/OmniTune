import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/models/app_preferences.dart';
import 'package:music/core/utils/chinese_text_localizer.dart';

void main() {
  group('normalizeChineseTextForLocale', () {
    test('converts traditional Chinese to simplified for Chinese locale', () {
      expect(
        normalizeChineseTextForLocale(
          '後來我們一起聽這首廣東歌',
          AppLocalePreference.chinese,
        ),
        '后来我们一起听这首广东歌',
      );
    });

    test('keeps original text for English locale', () {
      expect(
        normalizeChineseTextForLocale(
          '後來我們一起聽這首廣東歌',
          AppLocalePreference.english,
        ),
        '後來我們一起聽這首廣東歌',
      );
    });
  });
}
