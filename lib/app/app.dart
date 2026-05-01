import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/l10n/app_localizations.dart';

import '../core/models/app_preferences.dart';
import '../core/models/custom_theme_colors.dart';
import '../core/router/app_router.dart';
import '../core/storage/library_preferences_repository.dart';
import '../core/widgets/exception_handler_widget.dart';
import '../core/widgets/studio_chrome.dart';
import '../features/settings/application/app_settings_controller.dart';

class MusicApp extends ConsumerWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final preferences =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const LibraryPreferences();

    final customColors = preferences.customThemeColors;
    final seedColor =
        customColors.getSeedColor() ??
        ThemeData(useMaterial3: true).colorScheme.primary;

    debugPrint(
      '🎨 [App] Current theme seed color: ${customColors.primaryColorSeed}',
    );
    debugPrint(
      '🎨 [App] Parsed seed color from getSeedColor(): ${seedColor.toString()}',
    );

    // 构建亮色方案
    final lightScheme = _buildColorScheme(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    // 构建深色方案
    final darkScheme = _buildColorScheme(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      themeMode: AppDisplayPreferences.themeModeFor(
        preferences.themePreference,
      ),
      theme: _buildTheme(
        colorScheme: lightScheme,
        brightness: Brightness.light,
        interfaceScaleFactor: preferences.interfaceScaleFactor,
        customColors: customColors,
        backgroundImageSource: preferences.backgroundImageSource,
        backgroundImageAlignment: Alignment(
          preferences.backgroundImageAlignmentX,
          preferences.backgroundImageAlignmentY,
        ),
      ),
      darkTheme: _buildTheme(
        colorScheme: darkScheme,
        brightness: Brightness.dark,
        interfaceScaleFactor: preferences.interfaceScaleFactor,
        customColors: customColors,
        backgroundImageSource: preferences.backgroundImageSource,
        backgroundImageAlignment: Alignment(
          preferences.backgroundImageAlignmentX,
          preferences.backgroundImageAlignmentY,
        ),
      ),
      locale: AppDisplayPreferences.localeFor(preferences.localePreference),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return ExceptionHandlerWidget(
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: TextScaler.linear(preferences.fontScaleFactor),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Brightness brightness,
    required double interfaceScaleFactor,
    required CustomThemeColors customColors,
    required String? backgroundImageSource,
    required Alignment backgroundImageAlignment,
  }) {
    final scaleFactor = interfaceScaleFactor.clamp(0.5, 2).toDouble();
    final compactness = customColors.interfaceCompactness
        .clamp(0.5, 1.5)
        .toDouble();
    final layoutScale = (interfaceScaleFactor * compactness)
        .clamp(0.5, 2)
        .toDouble();
    final radius = AppDisplayPreferences.getBorderRadiusValue(
      customColors.borderRadius,
    );
    final controlRadius = AppDisplayPreferences.getResponsiveBorderRadius(
      radius,
      -8,
    );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      visualDensity: AppDisplayPreferences.visualDensityFor(layoutScale),
    );
    final textTheme = GoogleFonts.notoSansTextTheme(baseTheme.textTheme);

    TextStyle appTextStyle(
      TextStyle? style,
      double fallbackSize,
      FontWeight fontWeight, {
      double? letterSpacing,
      double? height,
    }) {
      return GoogleFonts.notoSans(
        textStyle: style,
        color: style?.color ?? colorScheme.onSurface,
        fontSize: (style?.fontSize ?? fallbackSize) * scaleFactor,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        height: height,
      );
    }

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme.copyWith(
        displayLarge: appTextStyle(
          textTheme.displayLarge,
          34,
          FontWeight.w800,
          letterSpacing: -0.8,
        ),
        displayMedium: appTextStyle(
          textTheme.displayMedium,
          30,
          FontWeight.w800,
          letterSpacing: -0.7,
        ),
        displaySmall: appTextStyle(
          textTheme.displaySmall,
          26,
          FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineLarge: appTextStyle(
          textTheme.headlineLarge,
          24,
          FontWeight.w800,
          letterSpacing: -0.4,
        ),
        headlineMedium: appTextStyle(
          textTheme.headlineMedium,
          22,
          FontWeight.w700,
        ),
        headlineSmall: appTextStyle(
          textTheme.headlineSmall,
          20,
          FontWeight.w700,
        ),
        titleLarge: appTextStyle(textTheme.titleLarge, 18, FontWeight.w700),
        titleMedium: appTextStyle(textTheme.titleMedium, 16, FontWeight.w700),
        titleSmall: appTextStyle(textTheme.titleSmall, 14, FontWeight.w700),
        bodyLarge: appTextStyle(
          textTheme.bodyLarge,
          16,
          FontWeight.w600,
          height: 1.4,
        ),
        bodyMedium: appTextStyle(
          textTheme.bodyMedium,
          14,
          FontWeight.w500,
          height: 1.38,
        ),
        bodySmall: appTextStyle(
          textTheme.bodySmall,
          12,
          FontWeight.w500,
          height: 1.36,
        ),
        labelLarge: appTextStyle(textTheme.labelLarge, 12, FontWeight.w700),
        labelMedium: appTextStyle(textTheme.labelMedium, 11, FontWeight.w700),
        labelSmall: appTextStyle(textTheme.labelSmall, 10, FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface.withValues(alpha: 0),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: colorScheme.surface.withValues(alpha: 0),
        toolbarHeight: AppDisplayPreferences.toolbarHeightFor(layoutScale),
        titleTextStyle: GoogleFonts.notoSans(
          color: colorScheme.onSurface,
          fontSize: 18 * scaleFactor,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        hintStyle: GoogleFonts.notoSans(color: colorScheme.onSurfaceVariant),
        helperStyle: GoogleFonts.notoSans(color: colorScheme.onSurfaceVariant),
        contentPadding: AppDisplayPreferences.inputContentPaddingFor(
          layoutScale,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        iconColor: colorScheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0),
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.notoSans(
            fontSize: 10 * scaleFactor,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
        height: (44 * scaleFactor).clamp(40, 48).toDouble(),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(
            AppDisplayPreferences.segmentedButtonPaddingFor(layoutScale),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppDisplayPreferences.getResponsiveBorderRadius(radius, -10),
              ),
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: AppDisplayPreferences.buttonPaddingFor(layoutScale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppDisplayPreferences.buttonPaddingFor(layoutScale),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
          textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          padding: EdgeInsets.all((12 * compactness).clamp(8.0, 16.0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: (10 * compactness).clamp(8.0, 14.0),
          vertical: (6 * compactness).clamp(4.0, 10.0),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        extendedTextStyle: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.notoSans(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(controlRadius),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        modalBackgroundColor: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius + 4)),
        ),
      ),
      extensions: [
        StudioThemeData(
          compactness: compactness,
          backgroundImageSource: backgroundImageSource,
          backgroundImageAlignment: backgroundImageAlignment,
        ),
      ],
    );
  }

  ColorScheme _buildColorScheme({
    required Color seedColor,
    required Brightness brightness,
  }) {
    // 首先使用 fromSeed 获得一个协调的基础色系统
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      contrastLevel: brightness == Brightness.light ? 0.08 : 0.14,
    );

    // 计算文本颜色（基于种子色的亮度）
    final luminance = seedColor.computeLuminance();
    final onColor = luminance > 0.5 ? Colors.black : Colors.white;

    // 直接使用 primary 作为 primaryContainer
    // 这样按钮和容器会显示用户选择的真实颜色（就像添加音源按钮一样）
    return baseScheme.copyWith(
      primary: seedColor,
      primaryContainer: seedColor, // 直接使用，不混合
      onPrimary: onColor,
      onPrimaryContainer: onColor,
      // 同样对待其他容器颜色
      secondaryContainer: baseScheme.secondary,
      tertiaryContainer: baseScheme.tertiary,
    );
  }
}
