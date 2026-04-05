import 'package:flutter/material.dart';

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
    return AppThemePreference.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppThemePreference.system,
    );
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
    return EdgeInsets.symmetric(
      horizontal: 20 * normalizedScale,
      vertical: 16 * normalizedScale,
    );
  }

  static EdgeInsets segmentedButtonPaddingFor(double scale) {
    final normalizedScale = scale.clamp(0.5, 2).toDouble();
    return EdgeInsets.symmetric(
      horizontal: 16 * normalizedScale,
      vertical: 14 * normalizedScale,
    );
  }

  static EdgeInsets inputContentPaddingFor(double scale) {
    final normalizedScale = scale.clamp(0.5, 2).toDouble();
    return EdgeInsets.symmetric(
      horizontal: 18 * normalizedScale,
      vertical: 18 * normalizedScale,
    );
  }
}
