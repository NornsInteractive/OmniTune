import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_preferences.dart';
import '../../../core/models/custom_theme_colors.dart';
import '../../../core/storage/library_preferences_repository.dart';

class AppSettingsController extends AsyncNotifier<LibraryPreferences> {
  @override
  Future<LibraryPreferences> build() {
    return ref.read(libraryPreferencesRepositoryProvider).load();
  }

  Future<void> setThemePreference(AppThemePreference value) async {
    await _save((preferences) => preferences.copyWith(themePreference: value));
  }

  Future<void> setLocalePreference(AppLocalePreference value) async {
    await _save((preferences) => preferences.copyWith(localePreference: value));
  }

  Future<void> setInterfaceScale(double value) async {
    await _save((preferences) => preferences.copyWith(interfaceScaleFactor: value));
  }

  Future<void> setFontScale(double value) async {
    await _save((preferences) => preferences.copyWith(fontScaleFactor: value));
  }

  Future<void> setDebugMode(bool value) async {
    await _save((preferences) => preferences.copyWith(enableDebugMode: value));
  }

  Future<void> setCustomThemeColors(CustomThemeColors value) async {
    await _save((preferences) => preferences.copyWith(customThemeColors: value));
  }

  Future<void> _save(LibraryPreferences Function(LibraryPreferences preferences) transform) async {
    final repository = ref.read(libraryPreferencesRepositoryProvider);
    final current = state.valueOrNull ?? await repository.load();
    final next = transform(current);
    state = AsyncData(next);
    await repository.save(next);
  }
}

final appSettingsControllerProvider = AsyncNotifierProvider<AppSettingsController, LibraryPreferences>(
  AppSettingsController.new,
);
