import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';
import '../settings/app_settings.dart';

/// Material Design 3 主题生成器
class AppTheme {
  /// 根据 AppSettings 构建完整的 ThemeData
  static ThemeData build(AppSettings settings) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: settings.seedColor,
      brightness: settings.isDarkMode ? Brightness.dark : Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    final fontFamily = GoogleFonts.dmSans().fontFamily;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,

      // AppBar 样式
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: AppTokens.fontTitle(settings.fontScale),
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      // 底部导航栏
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.surfaceContainerHighest,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.dmSans(fontSize: AppTokens.fontLabel(settings.fontScale), fontWeight: FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.all(IconThemeData(size: AppTokens.iconSmall)),
      ),

      // 侧栏导航
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.surfaceContainerHighest,
        labelType: NavigationRailLabelType.all,
        elevation: 0,
        minWidth: 72,
      ),

      // 卡片
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusCard)),
      ),

      // 分割线
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: AppTokens.dividerThickness,
        space: 0,
      ),

      // 按钮样式
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.onSurface,
          foregroundColor: colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusButton)),
          minimumSize: Size(0, AppTokens.buttonHeight(settings.density)),
          padding: EdgeInsets.symmetric(horizontal: AppTokens.cardPadding(settings.density) * 1.5, vertical: 0),
          textStyle: GoogleFonts.dmSans(fontSize: AppTokens.fontBody(settings.fontScale), fontWeight: FontWeight.w500),
        ),
      ),

      // 文本字段
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTokens.cardPadding(settings.density),
          vertical: AppTokens.cardPadding(settings.density) * 0.6,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInner),
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: AppTokens.dividerThickness),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusInner),
          borderSide: BorderSide(color: colorScheme.outline, width: AppTokens.borderWidth),
        ),
        hintStyle: GoogleFonts.dmSans(
          fontSize: AppTokens.fontBody(settings.fontScale),
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // 文本主题
      textTheme: TextTheme(
        displayLarge: GoogleFonts.dmSans(
          fontSize: AppTokens.fontDisplay(settings.fontScale),
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: AppTokens.fontTitle(settings.fontScale),
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: AppTokens.fontBody(settings.fontScale),
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurface,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: AppTokens.fontLabel(settings.fontScale),
          fontWeight: FontWeight.w400,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Slider 主题
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: colorScheme.onSurface,
        inactiveTrackColor: colorScheme.outlineVariant,
        thumbColor: colorScheme.onSurface,
        overlayColor: Colors.transparent,
      ),

      // Switch 主题
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(colorScheme.onSurface),
        trackColor: WidgetStatePropertyAll(colorScheme.outlineVariant),
      ),
    );
  }
}
