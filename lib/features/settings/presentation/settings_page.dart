import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/app_preferences.dart';
import '../../../core/models/custom_theme_colors.dart';
import '../../../core/models/playback_cache_settings.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../../../core/storage/background_image_store.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../../core/widgets/glacier_dialog.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../debug/application/debug_mode_provider.dart';
import '../../library/application/library_catalog_controller.dart';
import '../../library/application/library_controller.dart';
import '../../player/application/playback_cache_settings_controller.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/data/webdav/webdav_playback_cache_base.dart';
import '../../sources/data/webdav/webdav_playback_cache_provider.dart';
import '../application/app_settings_controller.dart';
import 'add_source_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const LibraryPreferences();
    final accentHex = preferences.customThemeColors.primaryColorSeed;
    final accentColor =
        preferences.customThemeColors.getSeedColor() ?? colorScheme.primary;
    final accentSummary = accentHex == null || accentHex.trim().isEmpty
        ? l10n.themeAccentColorDefaultLabel
        : accentHex;
    final cacheSettings =
        ref.watch(playbackCacheSettingsControllerProvider).valueOrNull ??
        const PlaybackCacheSettings();
    final sources =
        ref.watch(sourcesControllerProvider).valueOrNull ??
        const <SourceProfile>[];
    final browser = ref.watch(libraryControllerProvider).valueOrNull;
    final appSettingsController = ref.read(
      appSettingsControllerProvider.notifier,
    );
    final sourcesController = ref.read(sourcesControllerProvider.notifier);
    final libraryController = ref.read(libraryControllerProvider.notifier);
    final materialL10n = MaterialLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.5 : 0.62,
    );
    final sectionBorderColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.34 : 0.5,
    );
    final sectionBackground = colorScheme.surfaceContainerHigh.withValues(
      alpha: isDark ? 0.62 : 0.88,
    );
    final shellBackground = colorScheme.surface;
    final selectedSourceId = browser?.selectedSource?.id;
    const defaultAlbumPageSize = 9;
    const defaultMemoryCacheTrackLimit = 3;

    Widget section({
      required String title,
      required List<Widget> children,
      Widget? trailing,
    }) {
      final sectionRadius = studioRadiusOf(context, 16);
      return Container(
        decoration: BoxDecoration(
          color: sectionBackground,
          borderRadius: BorderRadius.circular(sectionRadius),
          border: Border.all(color: sectionBorderColor),
        ),
        padding: studioPaddingOf(context, const EdgeInsets.all(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );
    }

    Widget divider() => Container(height: 1, color: dividerColor);

    Widget resetButton({required VoidCallback onPressed, bool enabled = true}) {
      return TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(l10n.resetToDefaultAction),
      );
    }

    Widget settingRow({
      required String title,
      required String subtitle,
      required Widget trailing,
      VoidCallback? onTap,
    }) {
      final rowRadius = studioRadiusOf(context, 10);
      final row = Padding(
        padding: studioPaddingOf(
          context,
          const EdgeInsets.symmetric(vertical: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      );
      if (onTap == null) {
        return row;
      }
      return InkWell(
        borderRadius: BorderRadius.circular(rowRadius),
        onTap: onTap,
        child: row,
      );
    }

    return Scaffold(
      backgroundColor: shellBackground,
      body: Container(
        decoration: BoxDecoration(
          color: shellBackground,
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08),
              shellBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: studioListPaddingOf(
                  context,
                  const EdgeInsets.fromLTRB(16, 4, 16, 28),
                ),
                children: [
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        Material(
                          color: colorScheme.surfaceContainerHigh.withValues(
                            alpha: isDark ? 0.8 : 0.92,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => context.pop(),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          l10n.settingsPageTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  section(
                    title: l10n.appearanceSettingsTitle,
                    children: [
                      settingRow(
                        title: l10n.languageSettingTitle,
                        subtitle: _localeLabel(
                          l10n,
                          preferences.localePreference,
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: isDark ? 0.75 : 0.95,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _localeLabel(
                                  l10n,
                                  preferences.localePreference,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _showSelectionDialog<AppLocalePreference>(
                          context: context,
                          title: l10n.languageSettingTitle,
                          selectedValue: preferences.localePreference,
                          options: [
                            _DialogOption(
                              value: AppLocalePreference.system,
                              label: _localeLabel(
                                l10n,
                                AppLocalePreference.system,
                              ),
                              icon: Icons.settings_suggest_rounded,
                            ),
                            _DialogOption(
                              value: AppLocalePreference.chinese,
                              label: _localeLabel(
                                l10n,
                                AppLocalePreference.chinese,
                              ),
                              icon: Icons.translate_rounded,
                            ),
                            _DialogOption(
                              value: AppLocalePreference.english,
                              label: _localeLabel(
                                l10n,
                                AppLocalePreference.english,
                              ),
                              icon: Icons.public_rounded,
                            ),
                          ],
                          onSelected: appSettingsController.setLocalePreference,
                        ),
                      ),
                      const SizedBox(height: 14),
                      divider(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.themeSettingTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _themeLabel(
                                    l10n,
                                    preferences.themePreference,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: isDark ? 0.75 : 0.95,
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final value in AppThemePreference.values)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Material(
                                      color:
                                          preferences.themePreference == value
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.2,
                                            )
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          appSettingsController
                                              .setThemePreference(value);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          child: Text(
                                            _themeLabel(l10n, value),
                                            style: theme.textTheme.labelMedium
                                                ?.copyWith(
                                                  color:
                                                      preferences
                                                              .themePreference ==
                                                          value
                                                      ? colorScheme.primary
                                                      : colorScheme
                                                            .onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      divider(),
                      const SizedBox(height: 14),
                      Text(
                        l10n.interfaceSizeSettingTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.interfaceSizeDialogDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: preferences.interfaceScaleFactor,
                              min: AppDisplayPreferences.minInterfaceScale,
                              max: AppDisplayPreferences.maxInterfaceScale,
                              divisions: 50,
                              onChanged:
                                  appSettingsController.setInterfaceScale,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.scalePercentLabel(
                              _scalePercent(preferences.interfaceScaleFactor),
                            ),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: resetButton(
                          enabled:
                              (preferences.interfaceScaleFactor -
                                      AppDisplayPreferences
                                          .defaultInterfaceScale)
                                  .abs() >
                              0.0001,
                          onPressed: () {
                            appSettingsController.setInterfaceScale(
                              AppDisplayPreferences.defaultInterfaceScale,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      divider(),
                      const SizedBox(height: 14),
                      Text(
                        l10n.fontSizeSettingTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.fontSizeDialogDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: preferences.fontScaleFactor,
                              min: AppDisplayPreferences.minFontScale,
                              max: AppDisplayPreferences.maxFontScale,
                              divisions: 57,
                              onChanged: appSettingsController.setFontScale,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.scalePercentLabel(
                              _scalePercent(preferences.fontScaleFactor),
                            ),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: resetButton(
                          enabled:
                              (preferences.fontScaleFactor -
                                      AppDisplayPreferences.defaultFontScale)
                                  .abs() >
                              0.0001,
                          onPressed: () {
                            appSettingsController.setFontScale(
                              AppDisplayPreferences.defaultFontScale,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      (() {
                        final isZh =
                            Localizations.localeOf(
                              context,
                            ).languageCode.toLowerCase() ==
                            'zh';
                        final albumPageTitle = isZh
                            ? '专辑每页数量'
                            : 'Albums per page';
                        final albumPageDescription = isZh
                            ? '设置专辑列表分页时每页最多显示的专辑数量（默认 9）。'
                            : 'Set the maximum number of albums shown on each page (default 9).';
                        final albumPageValue = isZh
                            ? '每页 ${preferences.albumPageSize} 条'
                            : '${preferences.albumPageSize} per page';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              albumPageTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              albumPageDescription,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: preferences.albumPageSize.toDouble(),
                                    min: 1,
                                    max: 60,
                                    divisions: 59,
                                    onChanged: (value) {
                                      appSettingsController.setAlbumPageSize(
                                        value.round(),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  albumPageValue,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: resetButton(
                                enabled:
                                    preferences.albumPageSize !=
                                    defaultAlbumPageSize,
                                onPressed: () {
                                  appSettingsController.setAlbumPageSize(
                                    defaultAlbumPageSize,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        );
                      })(),
                      divider(),
                      const SizedBox(height: 14),
                      settingRow(
                        title: l10n.themeAccentColorSettingTitle,
                        subtitle: accentSummary,
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            for (final color in const <Color>[
                              Color(0xFF7DD3FC),
                              Color(0xFFC8A0F0),
                              Color(0xFF34D399),
                              Color(0xFFFB7185),
                            ])
                              InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () async {
                                  await appSettingsController
                                      .setCustomThemeColors(
                                        preferences.customThemeColors.copyWith(
                                          primaryColorSeed: _hexFromColor(
                                            color,
                                          ),
                                        ),
                                      );
                                },
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                    border: Border.all(
                                      color:
                                          (accentColor.toARGB32() & 0xFFFFFF) ==
                                              (color.toARGB32() & 0xFFFFFF)
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () async {
                                final colorHex = await _showColorPickerDialog(
                                  context: context,
                                  currentColor: accentHex ?? '',
                                );
                                if (colorHex == null || colorHex.isEmpty) {
                                  return;
                                }
                                await appSettingsController
                                    .setCustomThemeColors(
                                      preferences.customThemeColors.copyWith(
                                        primaryColorSeed: colorHex,
                                      ),
                                    );
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.surfaceContainerHigh,
                                  border: Border.all(
                                    color: colorScheme.outline,
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      divider(),
                      const SizedBox(height: 14),
                      settingRow(
                        title: l10n.themeBorderRadiusSettingTitle,
                        subtitle:
                            '${preferences.customThemeColors.borderRadius.toStringAsFixed(1)}px',
                        trailing: SizedBox(
                          width: 190,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Slider(
                                value: CustomThemeColors.normalizeBorderRadius(
                                  preferences.customThemeColors.borderRadius,
                                ),
                                min: 12,
                                max: 32,
                                divisions: 40,
                                onChanged: (value) {
                                  appSettingsController.setCustomThemeColors(
                                    preferences.customThemeColors.copyWith(
                                      borderRadius:
                                          CustomThemeColors.normalizeBorderRadius(
                                            value,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              resetButton(
                                enabled:
                                    (preferences
                                                .customThemeColors
                                                .borderRadius -
                                            const CustomThemeColors()
                                                .borderRadius)
                                        .abs() >
                                    0.0001,
                                onPressed: () {
                                  appSettingsController.setCustomThemeColors(
                                    preferences.customThemeColors.copyWith(
                                      borderRadius: const CustomThemeColors()
                                          .borderRadius,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      divider(),
                      const SizedBox(height: 14),
                      settingRow(
                        title: l10n.themeCompactnessSettingTitle,
                        subtitle:
                            '${(preferences.customThemeColors.interfaceCompactness * 100).toStringAsFixed(0)}%',
                        trailing: SizedBox(
                          width: 190,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Slider(
                                value: CustomThemeColors.normalizeCompactness(
                                  preferences
                                      .customThemeColors
                                      .interfaceCompactness,
                                ),
                                min: 0.5,
                                max: 1.5,
                                divisions: 20,
                                onChanged: (value) {
                                  appSettingsController.setCustomThemeColors(
                                    preferences.customThemeColors.copyWith(
                                      interfaceCompactness:
                                          CustomThemeColors.normalizeCompactness(
                                            value,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              resetButton(
                                enabled:
                                    (preferences
                                                .customThemeColors
                                                .interfaceCompactness -
                                            const CustomThemeColors()
                                                .interfaceCompactness)
                                        .abs() >
                                    0.0001,
                                onPressed: () {
                                  appSettingsController.setCustomThemeColors(
                                    preferences.customThemeColors.copyWith(
                                      interfaceCompactness:
                                          const CustomThemeColors()
                                              .interfaceCompactness,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      divider(),
                      const SizedBox(height: 14),
                      settingRow(
                        title: l10n.backgroundImageSettingTitle,
                        subtitle: preferences.backgroundImageSource == null
                            ? l10n.backgroundImageDefaultSummary
                            : l10n.backgroundImageConfiguredSummary,
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onTap: () => _showBackgroundImageDialog(
                          context: context,
                          ref: ref,
                          preferences: preferences,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  section(
                    title: l10n.sourceManagementSettingTitle,
                    trailing: FilledButton.tonalIcon(
                      onPressed: () => showSourceTypePicker(context),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(l10n.addSourceAction),
                    ),
                    children: [
                      if (sources.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            l10n.sourceManagementEmptySummary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        for (
                          var index = 0;
                          index < sources.length;
                          index++
                        ) ...[
                          Material(
                            color: colorScheme.surfaceContainerHigh.withValues(
                              alpha: isDark ? 0.52 : 0.85,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () async {
                                await libraryController.selectSource(
                                  sources[index].id,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 9,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                      child: Icon(
                                        _protocolIcon(sources[index].protocol),
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sources[index].name,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  color: colorScheme.onSurface,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${_protocolLabel(l10n, sources[index].protocol)} · ${sources[index].hostLabel}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selectedSourceId == sources[index].id)
                                      Padding(
                                        padding: EdgeInsets.only(right: 2),
                                        child: Icon(
                                          Icons.check_circle_rounded,
                                          color: colorScheme.primary,
                                          size: 18,
                                        ),
                                      ),
                                    IconButton(
                                      tooltip: l10n.editSourceAction,
                                      onPressed: () {
                                        context.push(
                                          '/settings/source/${sources[index].id}',
                                        );
                                      },
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 19,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: materialL10n.deleteButtonTooltip,
                                      onPressed: () async {
                                        final confirmed =
                                            await showDialog<bool>(
                                              context: context,
                                              builder: (dialogContext) {
                                                return GlacierDialog(
                                                  title: Text(
                                                    materialL10n
                                                        .deleteButtonTooltip,
                                                  ),
                                                  content: Text(
                                                    sources[index].name,
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            dialogContext,
                                                          ).pop(false),
                                                      child: Text(
                                                        materialL10n
                                                            .cancelButtonLabel,
                                                      ),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            dialogContext,
                                                          ).pop(true),
                                                      child: Text(
                                                        materialL10n
                                                            .deleteButtonTooltip,
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ) ??
                                            false;
                                        if (!confirmed) {
                                          return;
                                        }
                                        await sourcesController.deleteProfile(
                                          sources[index].id,
                                        );
                                        ref.invalidate(
                                          libraryControllerProvider,
                                        );
                                        ref.invalidate(
                                          libraryCatalogControllerProvider,
                                        );
                                      },
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: colorScheme.error,
                                        size: 19,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (index != sources.length - 1)
                            const SizedBox(height: 10),
                        ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  section(
                    title: l10n.playbackCacheTitle,
                    children: [
                      settingRow(
                        title: l10n.persistentPlaybackCacheLabel,
                        subtitle: l10n.persistentPlaybackCacheDescription,
                        trailing: Switch.adaptive(
                          value: cacheSettings.enablePersistentCache,
                          onChanged: (value) {
                            ref
                                .read(
                                  playbackCacheSettingsControllerProvider
                                      .notifier,
                                )
                                .setPersistentCacheEnabled(value);
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      divider(),
                      const SizedBox(height: 14),
                      Text(
                        l10n.memoryCacheTrackLimitLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.memoryCacheTrackLimitDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              min: 1,
                              max: 12,
                              divisions: 11,
                              value: cacheSettings.memoryCacheTrackLimit
                                  .toDouble()
                                  .clamp(1, 12),
                              onChanged: (value) {
                                ref
                                    .read(
                                      playbackCacheSettingsControllerProvider
                                          .notifier,
                                    )
                                    .setMemoryCacheTrackLimit(value.round());
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.memoryCacheTrackLimitValue(
                              cacheSettings.memoryCacheTrackLimit,
                            ),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: resetButton(
                          enabled:
                              cacheSettings.memoryCacheTrackLimit !=
                              defaultMemoryCacheTrackLimit,
                          onPressed: () {
                            ref
                                .read(
                                  playbackCacheSettingsControllerProvider
                                      .notifier,
                                )
                                .setMemoryCacheTrackLimit(
                                  defaultMemoryCacheTrackLimit,
                                );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      divider(),
                      const SizedBox(height: 14),
                      settingRow(
                        title: l10n.clearCachedFilesTitle,
                        subtitle: l10n.clearCachedFilesDescription,
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onTap: () => _showCacheManagementDialog(
                          context: context,
                          sourceNames: {
                            for (final source in sources)
                              source.id: source.name,
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  section(
                    title: l10n.debugSettingsTitle,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.debugModeLabel),
                        subtitle: Text(l10n.debugModeDescription),
                        value: preferences.enableDebugMode,
                        onChanged: (value) {
                          ref
                              .read(debugModeProvider.notifier)
                              .setEnabled(value);
                          appSettingsController.setDebugMode(value);
                          if (!value) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.debugModeEnabledMessage),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCacheSettingsDialog({
    required BuildContext context,
    required WidgetRef ref,
    required PlaybackCacheSettings initialSettings,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    var enablePersistentCache = initialSettings.enablePersistentCache;
    var memoryCacheTrackLimit = initialSettings.memoryCacheTrackLimit
        .toDouble();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return GlacierDialog(
              title: Text(l10n.cacheSettingsEntryTitle),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.persistentPlaybackCacheLabel),
                        subtitle: Text(l10n.persistentPlaybackCacheDescription),
                        value: enablePersistentCache,
                        onChanged: (value) {
                          setState(() {
                            enablePersistentCache = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.memoryCacheTrackLimitLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.memoryCacheTrackLimitDescription,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.memoryCacheTrackLimitValue(
                          memoryCacheTrackLimit.round(),
                        ),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Slider(
                        min: 1,
                        max: 12,
                        divisions: 11,
                        value: memoryCacheTrackLimit,
                        label: l10n.memoryCacheTrackLimitValue(
                          memoryCacheTrackLimit.round(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            memoryCacheTrackLimit = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(materialL10n.cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: () async {
                    final controller = ref.read(
                      playbackCacheSettingsControllerProvider.notifier,
                    );
                    await controller.setPersistentCacheEnabled(
                      enablePersistentCache,
                    );
                    await controller.setMemoryCacheTrackLimit(
                      memoryCacheTrackLimit.round(),
                    );
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(materialL10n.okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showBackgroundImageDialog({
    required BuildContext context,
    required WidgetRef ref,
    required LibraryPreferences preferences,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final controller = ref.read(appSettingsControllerProvider.notifier);
    final originalSource = preferences.backgroundImageSource;
    final stagedSources = <String>[];
    var didSave = false;
    var source = preferences.backgroundImageSource;
    var alignment = Alignment(
      preferences.backgroundImageAlignmentX,
      preferences.backgroundImageAlignmentY,
    );
    var previewFuture = source == null
        ? Future<Uint8List?>.value()
        : readStudioBackgroundImage(source);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> chooseImage() async {
              final file = await openFile(
                acceptedTypeGroups: [
                  XTypeGroup(
                    label: l10n.backgroundImageFileTypeLabel,
                    extensions: const ['jpg', 'jpeg', 'png', 'webp'],
                    mimeTypes: const ['image/jpeg', 'image/png', 'image/webp'],
                  ),
                ],
              );
              if (file == null) {
                return;
              }

              final bytes = await file.readAsBytes();
              final nextSource = await saveStudioBackgroundImage(
                bytes,
                fileName: file.name,
                mimeType: file.mimeType,
              );
              stagedSources.add(nextSource);
              setState(() {
                source = nextSource;
                alignment = Alignment.center;
                previewFuture = Future<Uint8List?>.value(bytes);
              });
            }

            return GlacierDialog(
              title: Text(l10n.backgroundImageDialogTitle),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.backgroundImageDialogDescription),
                      const SizedBox(height: 16),
                      _BackgroundImagePositionPreview(
                        previewFuture: previewFuture,
                        alignment: alignment,
                        emptyLabel: l10n.backgroundImageEmptyPreview,
                        onAlignmentChanged: (value) {
                          setState(() => alignment = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.backgroundImagePositionHelpText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: chooseImage,
                            icon: const Icon(Icons.image_search_rounded),
                            label: Text(
                              source == null
                                  ? l10n.backgroundImageChooseAction
                                  : l10n.backgroundImageChangeAction,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: source == null
                                ? null
                                : () {
                                    setState(
                                      () => alignment = Alignment.center,
                                    );
                                  },
                            icon: const Icon(Icons.center_focus_strong_rounded),
                            label: Text(l10n.backgroundImageCenterAction),
                          ),
                          OutlinedButton.icon(
                            onPressed: source == null
                                ? null
                                : () async {
                                    setState(() {
                                      source = null;
                                      alignment = Alignment.center;
                                      previewFuture =
                                          Future<Uint8List?>.value();
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: Text(l10n.backgroundImageClearAction),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(materialL10n.cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: () async {
                    final nextSource = source;
                    if (nextSource == null) {
                      await controller.clearBackgroundImage();
                    } else {
                      await controller.setBackgroundImage(
                        source: nextSource,
                        alignmentX: alignment.x,
                        alignmentY: alignment.y,
                      );
                    }
                    didSave = true;
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(materialL10n.okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );

    if (didSave) {
      if (originalSource != source) {
        await deleteStudioBackgroundImage(originalSource);
      }
      for (final stagedSource in stagedSources) {
        if (stagedSource != source) {
          await deleteStudioBackgroundImage(stagedSource);
        }
      }
      return;
    }

    for (final stagedSource in stagedSources) {
      await deleteStudioBackgroundImage(stagedSource);
    }
  }

  Future<void> _showScaleDialog({
    required BuildContext context,
    required String title,
    required String description,
    required double min,
    required double max,
    required int divisions,
    required double initialValue,
    required Future<void> Function(double value) onSaved,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    var value = initialValue;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return GlacierDialog(
              title: Text(title),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(description),
                      const SizedBox(height: 20),
                      Text(
                        l10n.scalePercentLabel(_scalePercent(value)),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        min: min,
                        max: max,
                        divisions: divisions,
                        value: value,
                        label: l10n.scalePercentLabel(_scalePercent(value)),
                        onChanged: (nextValue) {
                          setState(() {
                            value = nextValue;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.scaleRangeLabel(
                          _scalePercent(min),
                          _scalePercent(max),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(materialL10n.cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: () async {
                    await onSaved(value);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(materialL10n.okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showColorPickerDialog({
    required BuildContext context,
    required String currentColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    var selectedHsv = HSVColor.fromColor(
      _colorFromHexOrFallback(
        currentColor,
        Theme.of(context).colorScheme.primary,
      ),
    );
    final hexController = TextEditingController(
      text: _hexFromColor(selectedHsv.toColor()),
    );

    void syncHexField(Color color) {
      final nextHex = _hexFromColor(color);
      if (hexController.text == nextHex) {
        return;
      }
      hexController.value = TextEditingValue(
        text: nextHex,
        selection: TextSelection.collapsed(offset: nextHex.length),
      );
    }

    return showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dialogTheme = Theme.of(context);
            final dialogColorScheme = dialogTheme.colorScheme;
            final selectedColor = selectedHsv.toColor();

            void updateHsv(HSVColor color) {
              setState(() => selectedHsv = color);
              syncHexField(color.toColor());
            }

            final isDark = dialogTheme.brightness == Brightness.dark;
            // 生成实时主题预览
            final previewScheme = ColorScheme.fromSeed(
              seedColor: selectedColor,
              brightness: isDark ? Brightness.dark : Brightness.light,
            );

            return GlacierDialog(
              title: Text(l10n.themeColorDialogTitle),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: _CircularColorPicker(
                        hsvColor: selectedHsv,
                        onChanged: updateHsv,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _HueSlider(
                      hsvColor: selectedHsv,
                      onChanged: (hue) {
                        updateHsv(selectedHsv.withHue(hue));
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            l10n.themeColorPresetLabel,
                            style: dialogTheme.textTheme.bodyMedium?.copyWith(
                              color: dialogColorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: previewScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: dialogColorScheme.outlineVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: dialogColorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: dialogColorScheme.outlineVariant.withValues(
                            alpha: 0.52,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          _ColorPreview(color: selectedColor, size: 34),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: hexController,
                              decoration: InputDecoration(
                                labelText: l10n.themeColorHexFieldLabel,
                                helperText: l10n.themeColorHexFieldHint,
                              ),
                              textCapitalization: TextCapitalization.characters,
                              onChanged: (value) {
                                Color? color = _parseHexColor(value);
                                color ??= colorFromHex(
                                  value,
                                  enableAlpha: false,
                                );
                                if (color == null) {
                                  return;
                                }
                                setState(
                                  () =>
                                      selectedHsv = HSVColor.fromColor(color!),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(materialL10n.cancelButtonLabel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop('');
                  },
                  child: Text(l10n.themeAccentColorDefaultLabel),
                ),
                FilledButton(
                  onPressed: () {
                    // 生成hex值并规范化，确保一致的存储格式
                    final hexColor = _hexFromColor(selectedHsv.toColor());
                    final normalized =
                        CustomThemeColors.normalizeHexColor(hexColor) ??
                        hexColor;
                    Navigator.of(dialogContext).pop(normalized);
                  },
                  child: Text(materialL10n.okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(hexController.dispose);
  }

  Color _colorFromHexOrFallback(String colorHex, Color fallback) {
    // 首先尝试使用自定义的hex解析，确保一致性
    final parsed = _parseHexColor(colorHex);
    if (parsed != null) {
      return parsed;
    }
    // 如果自定义解析失败，尝试使用flutter_colorpicker的函数
    return colorFromHex(colorHex, enableAlpha: false) ?? fallback;
  }

  String _hexFromColor(Color color) {
    // 使用自定义的hex生成器确保格式一致
    // 将Color转换为ARGB，然后提取RGB部分
    // ignore: deprecated_member_use
    final argb = color.value;
    final rgb = argb & 0xFFFFFF;
    return '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }

  /// 自定义的hex颜色解析器，确保一致的格式处理
  Color? _parseHexColor(String hex) {
    try {
      // 清理输入：去掉 # 和空格
      var cleanHex = hex.trim().replaceFirst('#', '').toUpperCase();

      // 验证格式（6位RGB或8位ARGB）
      if (!RegExp(r'^[0-9A-F]{6}([0-9A-F]{2})?$').hasMatch(cleanHex)) {
        return null;
      }

      // 解析为整数
      final value = int.parse(cleanHex, radix: 16);

      // 如果只有6位，添加完全不透明的alpha
      if (cleanHex.length == 6) {
        return Color((value & 0xFFFFFF) | 0xFF000000);
      }

      // 8位ARGB格式，直接使用
      return Color(value);
    } catch (e) {
      return null;
    }
  }

  Future<double?> _showBorderRadiusSlider({
    required BuildContext context,
    required double initialValue,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    var value = initialValue;

    return showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return GlacierDialog(
              title: Text(l10n.themeBorderRadiusDialogTitle),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${value.toStringAsFixed(1)}px',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    Slider(
                      min: 12,
                      max: 32,
                      divisions: 20,
                      value: value,
                      label: '${value.toStringAsFixed(1)}px',
                      onChanged: (nextValue) {
                        setState(() {
                          value = nextValue;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.themeBorderRadiusRangeLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(materialL10n.cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: Text(materialL10n.okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<double?> _showCompactnessSlider({
    required BuildContext context,
    required double initialValue,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    var value = initialValue;

    return showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return GlacierDialog(
              title: Text(l10n.themeCompactnessDialogTitle),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(value * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    Slider(
                      min: 0.5,
                      max: 1.5,
                      divisions: 10,
                      value: value,
                      label: '${(value * 100).toStringAsFixed(0)}%',
                      onChanged: (nextValue) {
                        setState(() {
                          value = nextValue;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.themeCompactnessRangeLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(materialL10n.cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: Text(materialL10n.okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showCacheManagementDialog({
    required BuildContext context,
    required Map<String, String> sourceNames,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _CacheManagementDialog(sourceNames: sourceNames),
    );
  }

  int _scalePercent(double value) => (value * 100).round();

  Future<void> _showSourceManagementDialog({
    required BuildContext pageContext,
    required WidgetRef ref,
    required List<SourceProfile> sources,
    required SourceProfile? selectedSource,
  }) {
    final l10n = AppLocalizations.of(pageContext)!;
    final materialL10n = MaterialLocalizations.of(pageContext);

    return showDialog<void>(
      context: pageContext,
      builder: (dialogContext) {
        return GlacierDialog(
          title: Text(l10n.sourceManagementSettingTitle),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.sourceManagementDialogDescription),
                  const SizedBox(height: 16),
                  if (sources.isEmpty)
                    _DialogEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: l10n.sourceManagementEmptyTitle,
                      description: l10n.sourceManagementEmptySummary,
                    )
                  else
                    for (final source in sources) ...[
                      _SourceManagementCard(
                        source: source,
                        selected: selectedSource?.id == source.id,
                        protocolLabel: _protocolLabel(l10n, source.protocol),
                        editLabel: l10n.editSourceAction,
                        deleteLabel: materialL10n.deleteButtonTooltip,
                        onTap: () async {
                          Navigator.of(dialogContext).pop();
                          await ref
                              .read(libraryControllerProvider.notifier)
                              .selectSource(source.id);
                        },
                        onEdit: () {
                          Navigator.of(dialogContext).pop();
                          GoRouter.of(
                            pageContext,
                          ).push('/settings/source/${source.id}');
                        },
                        onDelete: () async {
                          Navigator.of(dialogContext).pop();
                          await ref
                              .read(sourcesControllerProvider.notifier)
                              .deleteProfile(source.id);
                          ref.invalidate(libraryControllerProvider);
                          ref.invalidate(libraryCatalogControllerProvider);
                        },
                      ),
                      SizedBox(height: studioListGapOf(dialogContext)),
                    ],
                ],
              ),
            ),
          ),
          actions: [
            if (sources.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await ref
                      .read(libraryCatalogControllerProvider.notifier)
                      .scanAllSources();
                },
                icon: const Icon(Icons.radar_rounded),
                label: Text(l10n.scanLibraryAction),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(materialL10n.closeButtonLabel),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                showSourceTypePicker(pageContext);
              },
              icon: const Icon(Icons.add_link_rounded),
              label: Text(l10n.addSourceAction),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSelectionDialog<T>({
    required BuildContext context,
    required String title,
    required T selectedValue,
    required List<_DialogOption<T>> options,
    required Future<void> Function(T value) onSelected,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return GlacierDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: RadioGroup<T>(
                groupValue: selectedValue,
                onChanged: (value) async {
                  if (value == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  await onSelected(value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: selectedValue == option.value
                              ? scheme.primary.withValues(alpha: 0.12)
                              : scheme.surfaceContainerHigh.withValues(
                                  alpha: 0.55,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedValue == option.value
                                ? scheme.primary.withValues(alpha: 0.38)
                                : scheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: RadioListTile<T>(
                          value: option.value,
                          activeColor: scheme.primary,
                          secondary: Icon(
                            option.icon,
                            color: selectedValue == option.value
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          title: Text(
                            option.label,
                            style: TextStyle(
                              color: selectedValue == option.value
                                  ? scheme.primary
                                  : scheme.onSurface,
                              fontWeight: selectedValue == option.value
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _localeLabel(AppLocalizations l10n, AppLocalePreference value) {
    return switch (value) {
      AppLocalePreference.system => l10n.languageOptionSystem,
      AppLocalePreference.english => l10n.languageOptionEnglish,
      AppLocalePreference.chinese => l10n.languageOptionChinese,
    };
  }

  String _themeLabel(AppLocalizations l10n, AppThemePreference value) {
    return switch (value) {
      AppThemePreference.system => l10n.themeOptionSystem,
      AppThemePreference.light => l10n.themeOptionLight,
      AppThemePreference.dark => l10n.themeOptionDark,
    };
  }

  IconData _protocolIcon(SourceProtocol protocol) {
    return switch (protocol) {
      SourceProtocol.webdav => Icons.dns_rounded,
      SourceProtocol.sftp => Icons.terminal_rounded,
      SourceProtocol.ftp => Icons.swap_vert_circle_rounded,
      SourceProtocol.samba => Icons.lan_rounded,
      SourceProtocol.cloudDrive => Icons.cloud_queue_rounded,
    };
  }

  String _protocolLabel(AppLocalizations l10n, SourceProtocol value) {
    return switch (value) {
      SourceProtocol.webdav => l10n.webdavProtocol,
      SourceProtocol.sftp => l10n.sftpProtocol,
      SourceProtocol.ftp => l10n.ftpProtocol,
      SourceProtocol.samba => l10n.sambaProtocol,
      SourceProtocol.cloudDrive => l10n.cloudDriveProtocol,
    };
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return StudioPanel(
      radius: 20,
      tint: const Color(0xFF0F1524),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: studioListSpacingOf(context, 10)),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              SizedBox(height: studioListGapOf(context)),
          ],
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = destructive
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;
    final radius = studioRadiusOf(context, 14);
    final iconBoxSize = studioListIconBoxSizeOf(context).clamp(34.0, 40.0);

    return StudioPanel(
      padding: EdgeInsets.zero,
      radius: 14,
      tint: const Color(0xFF141C2E),
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: studioListPaddingOf(
              context,
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: Row(
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: destructive
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(
                      studioRadiusOf(context, 16),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: studioListSpacingOf(
                      context,
                      20,
                    ).clamp(18.0, 23.0).toDouble(),
                    color: destructive
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: studioListGapOf(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: destructive ? colorScheme.error : null,
                            ),
                      ),
                      SizedBox(height: studioListSpacingOf(context, 3)),
                      Text(
                        subtitle,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: accentColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: studioListGapOf(context)),
                if (trailing != null) ...[
                  trailing!,
                  SizedBox(width: studioListGapOf(context)),
                ],
                Icon(Icons.chevron_right_rounded, color: accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundImagePositionPreview extends StatelessWidget {
  const _BackgroundImagePositionPreview({
    required this.previewFuture,
    required this.alignment,
    required this.emptyLabel,
    required this.onAlignmentChanged,
  });

  final Future<Uint8List?> previewFuture;
  final Alignment alignment;
  final String emptyLabel;
  final ValueChanged<Alignment> onAlignmentChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.sizeOf(context);
    final aspectRatio = screenSize.width / screenSize.height;

    return AspectRatio(
      aspectRatio: aspectRatio.clamp(0.56, 1.9).toDouble(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(studioRadiusOf(context, 24)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
          child: FutureBuilder<Uint8List?>(
            future: previewFuture,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null || bytes.isEmpty) {
                return Center(
                  child: Text(
                    emptyLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  Alignment draggedAlignment(Offset delta) {
                    final nextX =
                        (alignment.x - delta.dx / constraints.maxWidth * 2)
                            .clamp(-1.0, 1.0)
                            .toDouble();
                    final nextY =
                        (alignment.y - delta.dy / constraints.maxHeight * 2)
                            .clamp(-1.0, 1.0)
                            .toDouble();
                    return Alignment(nextX, nextY);
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      onAlignmentChanged(draggedAlignment(details.delta));
                    },
                    onDoubleTap: () => onAlignmentChanged(Alignment.center),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          alignment: alignment,
                          filterQuality: FilterQuality.medium,
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                colorScheme.surface.withValues(alpha: 0.08),
                                colorScheme.surface.withValues(alpha: 0.22),
                              ],
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.16,
                                ),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _SourceManagementAction { edit, delete }

class _SourceManagementCard extends StatelessWidget {
  const _SourceManagementCard({
    required this.source,
    required this.selected,
    required this.protocolLabel,
    required this.editLabel,
    required this.deleteLabel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final SourceProfile source;
  final bool selected;
  final String protocolLabel;
  final String editLabel;
  final String deleteLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = studioRadiusOf(context, 22);

    return StudioPanel(
      padding: EdgeInsets.zero,
      radius: 22,
      tint: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      child: Material(
        color: colorScheme.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: studioListItemPaddingOf(context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final foreground = selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface;
                final secondary = selected
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.72)
                    : colorScheme.onSurfaceVariant;

                return Row(
                  children: [
                    Container(
                      width: studioListIconBoxSizeOf(context),
                      height: studioListIconBoxSizeOf(context),
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.surface.withValues(alpha: 0.72)
                            : colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          studioRadiusOf(context, 14),
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_circle_rounded,
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(width: studioListGapOf(context)),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  source.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: foreground,
                                  ),
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: studioListSpacingOf(context, 3)),
                          Text(
                            '$protocolLabel · ${source.hostLabel}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondary,
                            ),
                          ),
                          Text(
                            source.rootPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: studioListGapOf(context)),
                    if (compact)
                      PopupMenuButton<_SourceManagementAction>(
                        tooltip: editLabel,
                        icon: Icon(Icons.more_horiz_rounded, color: secondary),
                        onSelected: (value) {
                          switch (value) {
                            case _SourceManagementAction.edit:
                              onEdit();
                            case _SourceManagementAction.delete:
                              onDelete();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: _SourceManagementAction.edit,
                            child: Text(editLabel),
                          ),
                          PopupMenuItem(
                            value: _SourceManagementAction.delete,
                            child: Text(deleteLabel),
                          ),
                        ],
                      )
                    else ...[
                      IconButton(
                        tooltip: editLabel,
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_outlined, color: secondary),
                      ),
                      IconButton(
                        tooltip: deleteLabel,
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPreview extends StatelessWidget {
  const _ColorPreview({required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.68),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _CircularColorPicker extends StatelessWidget {
  const _CircularColorPicker({required this.hsvColor, required this.onChanged});

  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onChanged;

  static const _pickerSize = 280.0;

  void _selectColor(Offset localPosition, Size size) {
    if (!_containsCircle(localPosition, size)) {
      return;
    }

    final selected = _SaturationValueCirclePainter.hsvForOffset(
      localPosition,
      size,
      hsvColor.hue,
    );

    onChanged(selected);
  }

  bool _containsCircle(Offset offset, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    return (offset - center).distance <= radius;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _pickerSize,
      height: _pickerSize,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colorScheme = Theme.of(context).colorScheme;
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final thumbOffset = _SaturationValueCirclePainter.offsetForHsv(
            hsvColor,
            size,
          );

          return GestureDetector(
            onTapDown: (details) => _selectColor(details.localPosition, size),
            onPanDown: (details) => _selectColor(details.localPosition, size),
            onPanUpdate: (details) {
              _selectColor(details.localPosition, size);
            },
            child: CustomPaint(
              painter: _SaturationValueCirclePainter(
                selectedColor: hsvColor.toColor(),
                thumbOffset: thumbOffset,
                hue: hsvColor.hue,
                outlineColor: colorScheme.outlineVariant.withValues(
                  alpha: 0.48,
                ),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _SaturationValueCirclePainter extends CustomPainter {
  const _SaturationValueCirclePainter({
    required this.selectedColor,
    required this.thumbOffset,
    required this.hue,
    required this.outlineColor,
  });

  final Color selectedColor;
  final Offset thumbOffset;
  final double hue;
  final Color outlineColor;

  static HSVColor hsvForOffset(Offset offset, Size size, double hue) {
    final saturation = (offset.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - offset.dy / size.height).clamp(0.0, 1.0);

    return HSVColor.fromAHSV(1, hue, saturation, value);
  }

  static Offset offsetForHsv(HSVColor hsvColor, Size size) {
    final candidate = Offset(
      hsvColor.saturation * size.width,
      (1 - hsvColor.value) * size.height,
    );
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final vector = candidate - center;

    if (vector.distance <= radius) {
      return candidate;
    }

    final direction = math.atan2(vector.dy, vector.dx);
    return Offset(
      center.dx + math.cos(direction) * radius,
      center.dy + math.sin(direction) * radius,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = math.min(size.width, size.height) / 2;
    final circle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.clipPath(circle);
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(rect, Paint()..color = hueColor);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Color(0x00FFFFFF)],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Colors.black],
        ).createShader(rect),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius - 0.5,
      Paint()
        ..color = outlineColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      thumbOffset,
      10,
      Paint()
        ..color = selectedColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      thumbOffset,
      10,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      thumbOffset,
      12,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.38)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValueCirclePainter oldDelegate) {
    return oldDelegate.selectedColor != selectedColor ||
        oldDelegate.thumbOffset != thumbOffset ||
        oldDelegate.hue != hue ||
        oldDelegate.outlineColor != outlineColor;
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hsvColor, required this.onChanged});

  final HSVColor hsvColor;
  final ValueChanged<double> onChanged;

  void _selectHue(Offset localPosition, Size size) {
    final hue = (localPosition.dx / size.width).clamp(0.0, 1.0) * 360;
    onChanged(hue);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(240.0, 420.0);
        const height = 42.0;
        final size = Size(width, height);

        return Center(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: GestureDetector(
              onTapDown: (details) {
                _selectHue(details.localPosition, size);
              },
              onPanDown: (details) {
                _selectHue(details.localPosition, size);
              },
              onPanUpdate: (details) {
                _selectHue(details.localPosition, size);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: CustomPaint(
                  painter: _HueSliderPainter(hsvColor: hsvColor),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HueSliderPainter extends CustomPainter {
  const _HueSliderPainter({required this.hsvColor});

  final HSVColor hsvColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final selectedHueColor = HSVColor.fromAHSV(1, hsvColor.hue, 1, 1).toColor();
    final thumbX = (hsvColor.hue / 360).clamp(0.0, 1.0) * size.width;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            for (var hue = 0; hue <= 360; hue += 60)
              HSVColor.fromAHSV(1, hue.toDouble(), 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      12,
      Paint()
        ..color = selectedHueColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      12,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      14,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.36)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _HueSliderPainter oldDelegate) {
    return oldDelegate.hsvColor != hsvColor;
  }
}

class _CacheManagementDialog extends ConsumerStatefulWidget {
  const _CacheManagementDialog({required this.sourceNames});

  final Map<String, String> sourceNames;

  @override
  ConsumerState<_CacheManagementDialog> createState() =>
      _CacheManagementDialogState();
}

class _CacheManagementDialogState
    extends ConsumerState<_CacheManagementDialog> {
  final Set<String> _selectedTrackIds = <String>{};
  late final Stream<List<PlaybackCacheInventoryItem>> _inventoryStream;

  @override
  void initState() {
    super.initState();
    _inventoryStream = ref
        .read(webDavPlaybackCacheProvider)
        .watchCachedTracks();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    return StreamBuilder<List<PlaybackCacheInventoryItem>>(
      stream: _inventoryStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <PlaybackCacheInventoryItem>[];
        final itemIds = items.map((item) => item.trackId).toSet();
        final selectedIds = _selectedTrackIds.where(itemIds.contains).toSet();

        return GlacierDialog(
          title: Text(l10n.clearCachedFilesTitle),
          content: SizedBox(
            width: 560,
            child:
                !snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : (items.isEmpty
                      ? _DialogEmptyState(
                          icon: Icons.offline_bolt_outlined,
                          title: l10n.cachedTracksEmptyTitle,
                          description: l10n.cachedTracksEmptyDescription,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.cachedTracksDialogDescription),
                            const SizedBox(height: 12),
                            Text(
                              l10n.selectedCacheCountLabel(selectedIds.length),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 360),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: items.length,
                                separatorBuilder: (context, _) =>
                                    SizedBox(height: studioListGapOf(context)),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final selected = selectedIds.contains(
                                    item.trackId,
                                  );
                                  final sourceName =
                                      widget.sourceNames[item.sourceId] ??
                                      l10n.cacheUnknownSourceLabel;
                                  final cacheMode = _cacheModeLabel(l10n, item);
                                  final coverage =
                                      item.totalBytes == null ||
                                          item.totalBytes == 0
                                      ? l10n.cacheCoverageUnknownLabel
                                      : l10n.cacheCoverageLabel(
                                          ((item.cachedBytes /
                                                      item.totalBytes!) *
                                                  100)
                                              .round(),
                                        );

                                  return Material(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(22),
                                    child: CheckboxListTile(
                                      value: selected,
                                      dense: true,
                                      visualDensity: VisualDensity.compact,
                                      contentPadding: studioListItemPaddingOf(
                                        context,
                                      ),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      title: Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '$sourceName · $cacheMode · $coverage\n${item.remotePath}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedTrackIds.add(item.trackId);
                                          } else {
                                            _selectedTrackIds.remove(
                                              item.trackId,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )),
          ),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(materialL10n.closeButtonLabel),
                ),
                if (items.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (selectedIds.length == items.length) {
                          _selectedTrackIds.clear();
                        } else {
                          _selectedTrackIds
                            ..clear()
                            ..addAll(itemIds);
                        }
                      });
                    },
                    child: Text(
                      selectedIds.length == items.length
                          ? l10n.clearSelectionAction
                          : l10n.selectAllAction,
                    ),
                  ),
                OutlinedButton(
                  onPressed: items.isEmpty
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(this.context);
                          await ref
                              .read(webDavPlaybackCacheProvider)
                              .clearAllCachedData();
                          if (!mounted) {
                            return;
                          }
                          setState(_selectedTrackIds.clear);
                          messenger.showSnackBar(
                            SnackBar(content: Text(l10n.cacheClearedMessage)),
                          );
                        },
                  child: Text(l10n.clearCacheAction),
                ),
                FilledButton(
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(this.context);
                          await ref
                              .read(webDavPlaybackCacheProvider)
                              .removeCachedTracks(selectedIds);
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _selectedTrackIds.removeAll(selectedIds);
                          });
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.selectedCacheDeletedMessage(
                                  selectedIds.length,
                                ),
                              ),
                            ),
                          );
                        },
                  child: Text(l10n.deleteSelectedCacheAction),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _cacheModeLabel(
    AppLocalizations l10n,
    PlaybackCacheInventoryItem item,
  ) {
    if (item.hasPersistentCopy && item.hasMemoryData) {
      return l10n.cacheModeHybridLabel;
    }
    if (item.hasPersistentCopy) {
      return l10n.cacheModeLocalLabel;
    }
    return l10n.cacheModeMemoryLabel;
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _DialogEmptyState extends StatelessWidget {
  const _DialogEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogOption<T> {
  const _DialogOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}
