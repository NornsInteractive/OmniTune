import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/l10n/app_localizations.dart';

import '../core/router/app_router.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/settings_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/exception_handler_widget.dart';

class MusicApp extends ConsumerWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final appSettings = ref.watch(appSettingsProvider);

    // 从 AppSettings 生成完整的主题
    final themeData = AppTheme.build(appSettings);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      themeMode: appSettings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: themeData,
      darkTheme: themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final fontScale = appSettings.fontScale;
        final fontScaleFactor = switch (fontScale) {
          FontScale.small => 0.85,
          FontScale.medium => 1.0,
          FontScale.large => 1.2,
          FontScale.extraLarge => 1.4,
        };

        final mediaQuery = MediaQuery.of(context);
        return ExceptionHandlerWidget(
          child: MediaQuery(
            data: mediaQuery.copyWith(textScaler: TextScaler.linear(fontScaleFactor)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
