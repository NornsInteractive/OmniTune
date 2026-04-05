import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:music/l10n/app_localizations.dart';

import '../core/models/app_preferences.dart';
import '../core/storage/library_preferences_repository.dart';
import '../core/router/app_router.dart';
import '../features/settings/application/app_settings_controller.dart';

class MusicApp extends ConsumerWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final preferences =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const LibraryPreferences();

    final lightScheme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
    ).colorScheme;
    final darkScheme = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
    ).colorScheme;

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      themeMode: AppDisplayPreferences.themeModeFor(
        preferences.themePreference,
      ),
      theme: _buildTheme(
        lightScheme,
        Brightness.light,
        preferences.interfaceScaleFactor,
      ),
      darkTheme: _buildTheme(
        darkScheme,
        Brightness.dark,
        preferences.interfaceScaleFactor,
      ),
      locale: AppDisplayPreferences.localeFor(preferences.localePreference),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(preferences.fontScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  ThemeData _buildTheme(
    ColorScheme colorScheme,
    Brightness brightness,
    double interfaceScaleFactor,
  ) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      visualDensity: AppDisplayPreferences.visualDensityFor(
        interfaceScaleFactor,
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(),
    );
    final titleTheme = GoogleFonts.outfitTextTheme(baseTheme.textTheme);

    return baseTheme.copyWith(
      textTheme: titleTheme.copyWith(
        bodyLarge: GoogleFonts.spaceGrotesk(
          textStyle: titleTheme.bodyLarge,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: GoogleFonts.spaceGrotesk(
          textStyle: titleTheme.bodyMedium,
          fontWeight: FontWeight.w500,
        ),
        headlineMedium: GoogleFonts.outfit(
          textStyle: titleTheme.headlineMedium,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
        headlineSmall: GoogleFonts.outfit(
          textStyle: titleTheme.headlineSmall,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        titleLarge: GoogleFonts.outfit(
          textStyle: titleTheme.titleLarge,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: GoogleFonts.outfit(
          textStyle: titleTheme.titleMedium,
          fontWeight: FontWeight.w700,
        ),
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: AppDisplayPreferences.toolbarHeightFor(
          interfaceScaleFactor,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: AppDisplayPreferences.inputContentPaddingFor(
          interfaceScaleFactor,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface.withValues(alpha: 0.98),
        indicatorColor: colorScheme.secondaryContainer,
        height: AppDisplayPreferences.navigationBarHeightFor(
          interfaceScaleFactor,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: WidgetStatePropertyAll(
            AppDisplayPreferences.segmentedButtonPaddingFor(
              interfaceScaleFactor,
            ),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: AppDisplayPreferences.buttonPaddingFor(interfaceScaleFactor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: AppDisplayPreferences.buttonPaddingFor(interfaceScaleFactor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
