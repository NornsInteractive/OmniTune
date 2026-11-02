import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/models/widget_style_config.dart';
import 'package:music/core/storage/library_preferences_repository.dart';

void main() {
  group('WidgetStyleConfig', () {
    test('default configuration matches requirements', () {
      const config = WidgetStyleConfig();
      expect(config.coverPosition, 'left');
      expect(config.coverFill, isTrue);
      expect(config.coverOpacity, 0.5);
      expect(config.backgroundColor, '#121620');
      expect(config.themeColor, '#58A6FF');
      expect(config.showLyrics, isTrue);
    });

    test('toJson and fromJson preserves all attributes', () {
      const original = WidgetStyleConfig(
        coverPosition: 'right',
        coverFill: false,
        coverOpacity: 0.8,
        backgroundColor: '#1E222D',
        themeColor: '#FFD700',
        showLyrics: false,
      );

      final json = original.toJson();
      final restored = WidgetStyleConfig.fromJson(json);

      expect(restored.coverPosition, 'right');
      expect(restored.coverFill, isFalse);
      expect(restored.coverOpacity, 0.8);
      expect(restored.backgroundColor, '#1E222D');
      expect(restored.themeColor, '#FFD700');
      expect(restored.showLyrics, isFalse);
      expect(restored, equals(original));
    });

    test('copyWith works correctly with clamping on opacity', () {
      const original = WidgetStyleConfig();
      final modified = original.copyWith(
        coverOpacity: 1.5, // should clamp to 1.0
        coverPosition: 'right',
      );

      expect(modified.coverOpacity, 1.0);
      expect(modified.coverPosition, 'right');
      expect(modified.coverFill, isTrue);
    });
  });

  group('LibraryPreferences Widget Multi-Size Independence', () {
    test('small, medium, and large configs are completely independent', () {
      const small = WidgetStyleConfig(
        coverPosition: 'right',
        coverFill: false,
        coverOpacity: 0.2,
        backgroundColor: '#10223D',
        themeColor: '#4ADE80',
        showLyrics: false,
      );
      const medium = WidgetStyleConfig(
        coverPosition: 'left',
        coverFill: true,
        coverOpacity: 0.6,
        backgroundColor: '#0D2826',
        themeColor: '#FB7185',
        showLyrics: true,
      );
      const large = WidgetStyleConfig(
        coverPosition: 'right',
        coverFill: true,
        coverOpacity: 0.9,
        backgroundColor: '#2E141E',
        themeColor: '#A78BFA',
        showLyrics: false,
      );

      var prefs = const LibraryPreferences(
        widgetSmallConfig: small,
        widgetMediumConfig: medium,
        widgetLargeConfig: large,
      );

      expect(prefs.getWidgetConfig(0), equals(small));
      expect(prefs.getWidgetConfig(1), equals(medium));
      expect(prefs.getWidgetConfig(2), equals(large));

      // Updating small does not alter medium or large
      prefs = prefs.copyWithWidgetConfig(
        0,
        small.copyWith(backgroundColor: '#FFFFFF'),
      );

      expect(prefs.getWidgetConfig(0).backgroundColor, '#FFFFFF');
      expect(prefs.getWidgetConfig(1).backgroundColor, '#0D2826');
      expect(prefs.getWidgetConfig(2).backgroundColor, '#2E141E');
    });

    test('tracks lastDailyUpdateCheckDate', () {
      const prefs = LibraryPreferences(
        lastDailyUpdateCheckDate: '2026-11-02',
      );
      expect(prefs.lastDailyUpdateCheckDate, '2026-11-02');
    });
  });
}
