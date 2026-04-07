import 'package:flutter/material.dart';
import 'spacing_theme.dart';

enum AppThemePreference { system, light, dark }

enum AppLocalePreference { system, english, chinese }

final class AppDisplayPreferences {
  static const double minInterfaceScale = 0.5;
  static const double maxInterfaceScale = 2;
  static const double defaultInterfaceScale = 1;

  static const double minFontScale = 0.5;
  static const double maxFontScale = 2;
  static const double defaultFontScale = 1;

  static ThemeMode themeModeFor(AppThemePreference value) {
    return switch (value) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }

  static Locale? localeFor(AppLocalePreference value) {
    return switch (value) {
      AppLocalePreference.system => null,
      AppLocalePreference.english => const Locale('en'),
      AppLocalePreference.chinese => const Locale('zh'),
    };
  }

  static AppThemePreference themePreferenceFromStorage(String? value) {
    return AppThemePreference.values.firstWhere((item) => item.name == value, orElse: () => AppThemePreference.system);
  }

  static AppLocalePreference localePreferenceFromStorage(String? value) {
    return AppLocalePreference.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppLocalePreference.system,
    );
  }

  static double interfaceScaleFromStorage(Object? value) {
    if (value is num) {
      return normalizeInterfaceScale(value.toDouble());
    }

    if (value is String) {
      return switch (value) {
        'compact' => 0.88,
        'comfortable' => 1.16,
        'standard' => defaultInterfaceScale,
        _ => defaultInterfaceScale,
      };
    }

    return defaultInterfaceScale;
  }

  static double fontScaleFromStorage(Object? value) {
    if (value is num) {
      return normalizeFontScale(value.toDouble());
    }

    if (value is String) {
      return switch (value) {
        'small' => 0.92,
        'large' => 1.12,
        'extraLarge' => 1.24,
        'standard' => defaultFontScale,
        _ => defaultFontScale,
      };
    }

    return defaultFontScale;
  }

  static double normalizeInterfaceScale(double value) {
    return value.clamp(minInterfaceScale, maxInterfaceScale).toDouble();
  }

  static double normalizeFontScale(double value) {
    return value.clamp(minFontScale, maxFontScale).toDouble();
  }

  static VisualDensity visualDensityFor(double scale) {
    final densityValue = ((scale - 1) * 3.2).clamp(-3.2, 3.2).toDouble();
    return VisualDensity(horizontal: densityValue, vertical: densityValue);
  }

  static double toolbarHeightFor(double scale) {
    return (64 * scale).clamp(40, 128).toDouble();
  }

  static double navigationBarHeightFor(double scale) {
    return (80 * scale).clamp(52, 160).toDouble();
  }

  static EdgeInsets buttonPaddingFor(double scale) {
    final normalizedScale = scale.clamp(0.5, 2).toDouble();
    return EdgeInsets.symmetric(horizontal: 20 * normalizedScale, vertical: 16 * normalizedScale);
  }

  static EdgeInsets segmentedButtonPaddingFor(double scale) {
    final normalizedScale = scale.clamp(0.5, 2).toDouble();
    return EdgeInsets.symmetric(horizontal: 16 * normalizedScale, vertical: 14 * normalizedScale);
  }

  static EdgeInsets inputContentPaddingFor(double scale) {
    final normalizedScale = scale.clamp(0.5, 2).toDouble();
    return EdgeInsets.symmetric(horizontal: 18 * normalizedScale, vertical: 18 * normalizedScale);
  }

  /// 创建 SpacingTheme 实例
  ///
  /// 根据 interfaceCompactness 参数生成响应式间距
  ///
  /// 参数:
  ///   - interfaceCompactness: 紧凑度 (0.5-1.5)
  ///
  /// 返回: SpacingTheme 实例
  static SpacingTheme createSpacingTheme(double interfaceCompactness) {
    final normalizedScale = interfaceCompactness.clamp(0.5, 1.5).toDouble();
    return SpacingTheme(baseUnit: 8, scaleFactor: normalizedScale);
  }

  /// 获取圆角半径
  ///
  /// 参数:
  ///   - borderRadius: 自定义主题圆角 (12-32)
  ///
  /// 返回: 圆角值，确保在 12-32 范围内
  static double getBorderRadiusValue(double borderRadius) {
    return borderRadius.clamp(12, 32).toDouble();
  }

  /// 获取响应式圆角
  ///
  /// 用于圆角值需要相对于基础值的情况
  /// 例如: 输入框圆角通常比卡片圆角小 8px
  ///
  /// 参数:
  ///   - baseBorderRadius: 基础圆角 (12-32)
  ///   - offset: 偏移量 (可正可负)
  ///
  /// 返回: 调整后的圆角值
  static double getResponsiveBorderRadius(double baseBorderRadius, double offset) {
    final adjusted = baseBorderRadius + offset;
    return adjusted.clamp(4, 48).toDouble();
  }

  /// 获取圆角 BorderRadius 对象
  ///
  /// 参数:
  ///   - radius: 圆角值
  ///
  /// 返回: BorderRadius.circular 对象
  static BorderRadius createBorderRadius(double radius) {
    return BorderRadius.circular(radius.clamp(0, 50).toDouble());
  }

  /// 验证紧凑度范围
  ///
  /// 参数:
  ///   - compactness: 紧凑度值
  ///
  /// 返回: 是否在有效范围内 (0.5-1.5)
  static bool isValidCompactness(double compactness) {
    return compactness >= 0.5 && compactness <= 1.5;
  }
}
