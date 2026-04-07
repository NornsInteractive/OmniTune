import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/l10n/app_localizations.dart';

import '../core/models/app_preferences.dart';
import '../core/models/custom_theme_colors.dart';
import '../core/storage/library_preferences_repository.dart';
import '../core/router/app_router.dart';
import '../core/widgets/exception_handler_widget.dart';
import '../features/settings/application/app_settings_controller.dart';

class MusicApp extends ConsumerWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final preferences = ref.watch(appSettingsControllerProvider).valueOrNull ?? const LibraryPreferences();

    // 获取自定义主题颜色或使用默认
    final customColors = preferences.customThemeColors;
    final seedColor = customColors.getSeedColor() ?? Colors.blue;

    final lightScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.light);
    final darkScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      themeMode: AppDisplayPreferences.themeModeFor(preferences.themePreference),
      theme: _buildTheme(lightScheme, Brightness.light, preferences.interfaceScaleFactor, customColors),
      darkTheme: _buildTheme(darkScheme, Brightness.dark, preferences.interfaceScaleFactor, customColors),
      locale: AppDisplayPreferences.localeFor(preferences.localePreference),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return ExceptionHandlerWidget(
          child: MediaQuery(
            data: mediaQuery.copyWith(textScaler: TextScaler.linear(preferences.fontScaleFactor)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(
    ColorScheme colorScheme,
    Brightness brightness,
    double interfaceScaleFactor,
    CustomThemeColors customColors,
  ) {
    final br = customColors.borderRadius;
    final scaleFactor = interfaceScaleFactor; // 字体缩放因子: 0.5-1.5

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      visualDensity: AppDisplayPreferences.visualDensityFor(interfaceScaleFactor),
      textTheme: GoogleFonts.spaceGroteskTextTheme(),
    );
    final titleTheme = GoogleFonts.outfitTextTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      textTheme: titleTheme.copyWith(
        // 显示文本 (Display: 用于大标题)
        displayLarge: GoogleFonts.outfit(
          fontSize: (titleTheme.displayLarge?.fontSize ?? 32) * scaleFactor,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: (titleTheme.displayMedium?.fontSize ?? 28) * scaleFactor,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        displaySmall: GoogleFonts.outfit(
          fontSize: (titleTheme.displaySmall?.fontSize ?? 24) * scaleFactor,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),

        // 标题文本 (Headline)
        headlineLarge: GoogleFonts.outfit(
          fontSize: (titleTheme.headlineLarge?.fontSize ?? 22) * scaleFactor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.9,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: (titleTheme.headlineMedium?.fontSize ?? 20) * scaleFactor,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: (titleTheme.headlineSmall?.fontSize ?? 18) * scaleFactor,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),

        // 标题 (Title)
        titleLarge: GoogleFonts.outfit(
          fontSize: (titleTheme.titleLarge?.fontSize ?? 16) * scaleFactor,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.outfit(
          fontSize: (titleTheme.titleMedium?.fontSize ?? 14) * scaleFactor,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: GoogleFonts.outfit(
          fontSize: (titleTheme.titleSmall?.fontSize ?? 12) * scaleFactor,
          fontWeight: FontWeight.w700,
        ),

        // 正文 (Body)
        bodyLarge: GoogleFonts.spaceGrotesk(
          fontSize: (titleTheme.bodyLarge?.fontSize ?? 16) * scaleFactor,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.spaceGrotesk(
          fontSize: (titleTheme.bodyMedium?.fontSize ?? 14) * scaleFactor,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: GoogleFonts.spaceGrotesk(
          fontSize: (titleTheme.bodySmall?.fontSize ?? 12) * scaleFactor,
          fontWeight: FontWeight.w400,
        ),

        // 标签 (Label)
        labelLarge: GoogleFonts.spaceGrotesk(
          fontSize: (titleTheme.labelLarge?.fontSize ?? 12) * scaleFactor,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: GoogleFonts.spaceGrotesk(
          fontSize: (titleTheme.labelMedium?.fontSize ?? 11) * scaleFactor,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: GoogleFonts.spaceGrotesk(
          fontSize: (titleTheme.labelSmall?.fontSize ?? 10) * scaleFactor,
          fontWeight: FontWeight.w600,
        ),
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: AppDisplayPreferences.toolbarHeightFor(interfaceScaleFactor),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(br),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(side: BorderSide(color: colorScheme.outlineVariant)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: AppDisplayPreferences.inputContentPaddingFor(interfaceScaleFactor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(br - 8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(br - 8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(br - 8),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.98),
        indicatorColor: colorScheme.secondaryContainer,
        height: AppDisplayPreferences.navigationBarHeightFor(interfaceScaleFactor),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(AppDisplayPreferences.segmentedButtonPaddingFor(interfaceScaleFactor)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: AppDisplayPreferences.buttonPaddingFor(interfaceScaleFactor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br - 6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppDisplayPreferences.buttonPaddingFor(interfaceScaleFactor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br - 6)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br - 8))),
    );
  }
}
