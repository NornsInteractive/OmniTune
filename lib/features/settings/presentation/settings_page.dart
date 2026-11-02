import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/core/i18n/localizations.dart';

import '../../../core/models/app_preferences.dart';
import '../../../core/models/custom_theme_colors.dart';
import '../../../core/models/playback_cache_settings.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../../../core/models/widget_style_config.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../../core/widgets/glacier_dialog.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../../core/widgets/top_snackbar.dart';
import '../../library/application/library_catalog_controller.dart';
import '../../library/application/library_controller.dart';
import '../../player/application/playback_cache_settings_controller.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/data/webdav/webdav_playback_cache_base.dart';
import '../../sources/data/webdav/webdav_playback_cache_provider.dart';
import '../application/app_settings_controller.dart';
import '../../updates/application/app_update_controller.dart';
import '../../updates/presentation/app_update_panel.dart';
import 'add_source_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int? _section;
  int _widgetPreviewSize = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sectionTitles = [
      l10n.sourceManagementSettingTitle,
      l10n.playbackSettingsTitle,
      l10n.appearanceSettingsTitle,
      l10n.desktopWidgetSettingsTitle,
      l10n.scraperPipelineLabel,
      l10n.advancedSettingsTitle,
      l10n.aboutAndUpdatesSettingTitle,
    ];
    const sectionIcons = [
      Icons.cloud_outlined,
      Icons.play_circle_outline_rounded,
      Icons.palette_outlined,
      Icons.widgets_outlined,
      Icons.lyrics_outlined,
      Icons.tune_rounded,
      Icons.info_outline_rounded,
    ];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final preferences =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const LibraryPreferences();
    final lightAccentHex = preferences.customThemeColors.effectiveHexFor(
      Brightness.light,
    );
    final darkAccentHex = preferences.customThemeColors.effectiveHexFor(
      Brightness.dark,
    );
    final accentSummary =
        '${_themeLabel(l10n, AppThemePreference.light)} ${lightAccentHex ?? "--"}'
        ' / '
        '${_themeLabel(l10n, AppThemePreference.dark)} ${darkAccentHex ?? "--"}';
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
    final updateState = ref.watch(appUpdateControllerProvider);
    final hasUpdateBadge = updateState.hasUnappliedUpdate ||
        updateState.phase == AppUpdatePhase.available;
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
    const defaultAlbumPageSize = 9;
    const defaultMemoryCacheTrackLimit = 3;
    const lightAccentPresetColors = <Color>[
      Colors.black,
      Color(0xFF32819F),
      Color(0xFFD7263D),
      Color(0xFFFF5FA2),
    ];
    const darkAccentPresetColors = <Color>[
      Color(0xFF1D796F),
      Colors.white,
      Color(0xFFD7263D),
      Color(0xFFFF5FA2),
    ];

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
        padding: studioPaddingOf(context, const EdgeInsets.all(16)),
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
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
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
          const EdgeInsets.symmetric(vertical: 0),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: trailing,
                  ),
                ),
              ],
            );
          },
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

    final compactSliderTheme = SliderTheme.of(context).copyWith(
      trackHeight: 2.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    );

    return PopScope(
      canPop: _section == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _section = null);
      },
      child: Scaffold(
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
                child: SliderTheme(
                  data: compactSliderTheme,
                  child: StudioEntranceTransition(
                    key: ValueKey(_section),
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
                                color: colorScheme.surfaceContainerHigh
                                    .withValues(alpha: isDark ? 0.8 : 0.92),
                                borderRadius: BorderRadius.circular(999),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () {
                                    if (_section != null) {
                                      setState(() => _section = null);
                                    } else {
                                      context.pop();
                                    }
                                  },
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
                              Expanded(
                                child: Text(
                                  _section == null
                                      ? l10n.settingsPageTitle
                                      : sectionTitles[_section!],
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_section != null) const SizedBox(height: 8),
                        if (_section == null)
                          for (
                            var index = 0;
                            index < sectionTitles.length;
                            index++
                          )
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                tileColor: colorScheme.surfaceContainerHigh,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    studioRadiusOf(context, 16),
                                  ),
                                ),
                                leading: Icon(
                                  sectionIcons[index],
                                  color: colorScheme.primary,
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      sectionTitles[index],
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    if (index == 6 && hasUpdateBadge) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: colorScheme.error,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (index == 6 && hasUpdateBadge) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: colorScheme.errorContainer,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'NEW',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: colorScheme
                                                .onErrorContainer,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                  ],
                                ),
                                onTap: () => setState(() => _section = index),
                              ),
                            ),
                        if (_section == 2)
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
                                      color: colorScheme.outlineVariant
                                          .withValues(
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
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
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
                                onTap: () =>
                                    _showSelectionDialog<AppLocalePreference>(
                                      context: context,
                                      title: l10n.languageSettingTitle,
                                      selectedValue:
                                          preferences.localePreference,
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
                                      onSelected: appSettingsController
                                          .setLocalePreference,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              divider(),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 10,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.themeSettingTitle,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _themeLabel(
                                          l10n,
                                          preferences.themePreference,
                                        ),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant
                                            .withValues(
                                              alpha: isDark ? 0.75 : 0.95,
                                            ),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        for (final value
                                            in AppThemePreference.values)
                                          Material(
                                            color:
                                                preferences.themePreference ==
                                                    value
                                                ? colorScheme.primary
                                                      .withValues(alpha: 0.2)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              onTap: () {
                                                appSettingsController
                                                    .setThemePreference(value);
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 7,
                                                    ),
                                                child: Text(
                                                  _themeLabel(l10n, value),
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color:
                                                            preferences
                                                                    .themePreference ==
                                                                value
                                                            ? colorScheme
                                                                  .primary
                                                            : colorScheme
                                                                  .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w600,
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
                              const SizedBox(height: 12),
                              divider(),
                              const SizedBox(height: 12),
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
                                      min: AppDisplayPreferences
                                          .minInterfaceScale,
                                      max: AppDisplayPreferences
                                          .maxInterfaceScale,
                                      divisions: 50,
                                      onChanged: appSettingsController
                                          .setInterfaceScale,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.scalePercentLabel(
                                      _scalePercent(
                                        preferences.interfaceScaleFactor,
                                      ),
                                    ),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
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
                                      AppDisplayPreferences
                                          .defaultInterfaceScale,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              divider(),
                              if (_section != null) const SizedBox(height: 8),
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
                                      onChanged:
                                          appSettingsController.setFontScale,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.scalePercentLabel(
                                      _scalePercent(
                                        preferences.fontScaleFactor,
                                      ),
                                    ),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
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
                                              AppDisplayPreferences
                                                  .defaultFontScale)
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
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      albumPageDescription,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Slider(
                                            value: preferences.albumPageSize
                                                .toDouble(),
                                            min: 1,
                                            max: 60,
                                            divisions: 59,
                                            onChanged: (value) {
                                              appSettingsController
                                                  .setAlbumPageSize(
                                                    value.round(),
                                                  );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          albumPageValue,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
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
                                          appSettingsController
                                              .setAlbumPageSize(
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
                              if (_section != null) const SizedBox(height: 8),
                              settingRow(
                                title: l10n.themeAccentColorSettingTitle,
                                subtitle: accentSummary,
                                trailing: SizedBox(
                                  width: 248,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _ThemeAccentSwatchRow(
                                        label: _themeLabel(
                                          l10n,
                                          AppThemePreference.light,
                                        ),
                                        currentHex: lightAccentHex,
                                        presets: lightAccentPresetColors,
                                        onPresetSelected: (color) async {
                                          await appSettingsController
                                              .setCustomThemeColors(
                                                preferences.customThemeColors
                                                    .copyWith(
                                                      lightPrimaryColorSeed:
                                                          _hexFromColor(color),
                                                    ),
                                              );
                                        },
                                        onCustomSelected: () async {
                                          final colorHex =
                                              await _showColorPickerDialog(
                                                context: context,
                                                currentColor:
                                                    lightAccentHex ?? '',
                                              );
                                          if (colorHex == null ||
                                              colorHex.isEmpty) {
                                            return;
                                          }
                                          await appSettingsController
                                              .setCustomThemeColors(
                                                preferences.customThemeColors
                                                    .copyWith(
                                                      lightPrimaryColorSeed:
                                                          colorHex,
                                                    ),
                                              );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      _ThemeAccentSwatchRow(
                                        label: _themeLabel(
                                          l10n,
                                          AppThemePreference.dark,
                                        ),
                                        currentHex: darkAccentHex,
                                        presets: darkAccentPresetColors,
                                        onPresetSelected: (color) async {
                                          await appSettingsController
                                              .setCustomThemeColors(
                                                preferences.customThemeColors
                                                    .copyWith(
                                                      darkPrimaryColorSeed:
                                                          _hexFromColor(color),
                                                    ),
                                              );
                                        },
                                        onCustomSelected: () async {
                                          final colorHex =
                                              await _showColorPickerDialog(
                                                context: context,
                                                currentColor:
                                                    darkAccentHex ?? '',
                                              );
                                          if (colorHex == null ||
                                              colorHex.isEmpty) {
                                            return;
                                          }
                                          await appSettingsController
                                              .setCustomThemeColors(
                                                preferences.customThemeColors
                                                    .copyWith(
                                                      darkPrimaryColorSeed:
                                                          colorHex,
                                                    ),
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              divider(),
                              const SizedBox(height: 12),
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
                                        value:
                                            CustomThemeColors.normalizeBorderRadius(
                                              preferences
                                                  .customThemeColors
                                                  .borderRadius,
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
                                          appSettingsController
                                              .setCustomThemeColors(
                                                preferences.customThemeColors
                                                    .copyWith(
                                                      borderRadius:
                                                          const CustomThemeColors()
                                                              .borderRadius,
                                                    ),
                                              );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              divider(),
                              const SizedBox(height: 12),
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
                                        value:
                                            CustomThemeColors.normalizeCompactness(
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
                                            preferences.customThemeColors
                                                .copyWith(
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
                              // OMNITUNE_PRESERVE_COMMENT:
                              // Background image setting is intentionally disabled.
                              // Keep this block commented out unless the user
                              // explicitly asks to restore the feature.
                              /*
                        const SizedBox(height: 12),
                        divider(),
                        const SizedBox(height: 12),
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
                        */
                            ],
                          ),
                        if (_section != null) const SizedBox(height: 8),
                        if (_section == 3)
                          () {
                            final activeWidgetConfig =
                                preferences.getWidgetConfig(_widgetPreviewSize);
                            return section(
                              title: l10n.desktopWidgetSettingsTitle,
                              children: [
                                _buildWidgetPreview(
                                  context: context,
                                  preferences: preferences,
                                  config: activeWidgetConfig,
                                  colorScheme: colorScheme,
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.tune_rounded,
                                          size: 13,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          l10n.widgetIndependentConfigTip,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                divider(),
                                const SizedBox(height: 12),
                                // 1. Artwork Position
                                settingRow(
                                  title: l10n.widgetCoverPositionTitle,
                                  subtitle:
                                      activeWidgetConfig.coverPosition == 'right'
                                          ? l10n.widgetCoverPositionRight
                                          : l10n.widgetCoverPositionLeft,
                                  trailing: SegmentedButton<String>(
                                    segments: [
                                      ButtonSegment<String>(
                                        value: 'left',
                                        label: Text(
                                          l10n.widgetCoverPositionLeft,
                                        ),
                                        icon: const Icon(
                                          Icons.align_horizontal_left_rounded,
                                          size: 16,
                                        ),
                                      ),
                                      ButtonSegment<String>(
                                        value: 'right',
                                        label: Text(
                                          l10n.widgetCoverPositionRight,
                                        ),
                                        icon: const Icon(
                                          Icons.align_horizontal_right_rounded,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                    selected: {
                                      activeWidgetConfig.coverPosition,
                                    },
                                    onSelectionChanged: (set) {
                                      appSettingsController.updateWidgetConfig(
                                        _widgetPreviewSize,
                                        activeWidgetConfig.copyWith(
                                          coverPosition: set.first,
                                        ),
                                      );
                                    },
                                    showSelectedIcon: false,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                divider(),
                                const SizedBox(height: 12),
                                // 2. Artwork Full Fill
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  visualDensity: const VisualDensity(
                                    horizontal: -2,
                                    vertical: -2,
                                  ),
                                  title: Text(l10n.widgetCoverFillTitle),
                                  subtitle: Text(l10n.widgetCoverFillSubtitle),
                                  value: activeWidgetConfig.coverFill,
                                  onChanged: (value) {
                                    appSettingsController.updateWidgetConfig(
                                      _widgetPreviewSize,
                                      activeWidgetConfig.copyWith(
                                        coverFill: value,
                                      ),
                                    );
                                  },
                                ),
                                if (activeWidgetConfig.coverFill) ...[
                                  const SizedBox(height: 12),
                                  divider(),
                                  const SizedBox(height: 12),
                                  // 3. Cover Scrim Darkness/Opacity Slider
                                  settingRow(
                                    title: l10n.widgetCoverOpacityTitle,
                                    subtitle:
                                        '${(activeWidgetConfig.coverOpacity * 100).round()}%',
                                    trailing: SizedBox(
                                      width: 180,
                                      child: Slider(
                                        value: activeWidgetConfig.coverOpacity,
                                        min: 0.0,
                                        max: 1.0,
                                        divisions: 20,
                                        label:
                                            '${(activeWidgetConfig.coverOpacity * 100).round()}%',
                                        onChanged: (val) {
                                          appSettingsController
                                              .updateWidgetConfig(
                                            _widgetPreviewSize,
                                            activeWidgetConfig.copyWith(
                                              coverOpacity: val,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                divider(),
                                const SizedBox(height: 12),
                                // 4. Show Lyrics Switch
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  visualDensity: const VisualDensity(
                                    horizontal: -2,
                                    vertical: -2,
                                  ),
                                  title: Text(l10n.widgetShowLyricsTitle),
                                  subtitle: Text(l10n.widgetShowLyricsSubtitle),
                                  value: activeWidgetConfig.showLyrics,
                                  onChanged: (value) {
                                    appSettingsController.updateWidgetConfig(
                                      _widgetPreviewSize,
                                      activeWidgetConfig.copyWith(
                                        showLyrics: value,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                divider(),
                                const SizedBox(height: 12),
                                // 5. Widget Background Color
                                settingRow(
                                  title: l10n.widgetBackgroundColorTitle,
                                  subtitle:
                                      activeWidgetConfig.backgroundColor,
                                  trailing: SizedBox(
                                    width: 250,
                                    child: _ThemeAccentSwatchRow(
                                      label: '',
                                      currentHex:
                                          activeWidgetConfig.backgroundColor,
                                      presets: _widgetBackgroundPresets,
                                      onPresetSelected: (color) {
                                        appSettingsController
                                            .updateWidgetConfig(
                                          _widgetPreviewSize,
                                          activeWidgetConfig.copyWith(
                                            backgroundColor:
                                                _hexFromColor(color),
                                          ),
                                        );
                                      },
                                      onCustomSelected: () async {
                                        final colorHex =
                                            await _showColorPickerDialog(
                                          context: context,
                                          currentColor: activeWidgetConfig
                                              .backgroundColor,
                                        );
                                        if (colorHex != null &&
                                            colorHex.isNotEmpty) {
                                          await appSettingsController
                                              .updateWidgetConfig(
                                            _widgetPreviewSize,
                                            activeWidgetConfig.copyWith(
                                              backgroundColor: colorHex,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                divider(),
                                const SizedBox(height: 12),
                                // 6. Widget Theme/Accent Color
                                settingRow(
                                  title: l10n.widgetThemeColorTitle,
                                  subtitle: activeWidgetConfig.themeColor,
                                  trailing: SizedBox(
                                    width: 250,
                                    child: _ThemeAccentSwatchRow(
                                      label: '',
                                      currentHex:
                                          activeWidgetConfig.themeColor,
                                      presets: _widgetAccentPresets,
                                      onPresetSelected: (color) {
                                        appSettingsController
                                            .updateWidgetConfig(
                                          _widgetPreviewSize,
                                          activeWidgetConfig.copyWith(
                                            themeColor:
                                                _hexFromColor(color),
                                          ),
                                        );
                                      },
                                      onCustomSelected: () async {
                                        final colorHex =
                                            await _showColorPickerDialog(
                                          context: context,
                                          currentColor:
                                              activeWidgetConfig.themeColor,
                                        );
                                        if (colorHex != null &&
                                            colorHex.isNotEmpty) {
                                          await appSettingsController
                                              .updateWidgetConfig(
                                            _widgetPreviewSize,
                                            activeWidgetConfig.copyWith(
                                              themeColor: colorHex,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }(),
                        if (_section != null) const SizedBox(height: 8),
                        if (_section == 0)
                          section(
                            title: l10n.sourceManagementSettingTitle,
                            trailing: FilledButton.tonalIcon(
                              onPressed: () => showSourceTypePicker(context),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(l10n.addSourceAction),
                            ),
                            children: [
                              settingRow(
                                title: l10n.sourceManagementSettingTitle,
                                subtitle: sources.isEmpty
                                    ? l10n.sourceManagementEmptySummary
                                    : l10n.sourceManagementSummary(
                                        browser?.selectedSource?.name ??
                                            sources.first.name,
                                        sources.length,
                                      ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                onTap: () => _showSourceManagementDialog(
                                  pageContext: context,
                                  ref: ref,
                                  sources: sources,
                                  selectedSource: browser?.selectedSource,
                                ),
                              ),
                              const SizedBox(height: 12),
                              divider(),
                              const SizedBox(height: 12),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                                title: Text(l10n.songFolderArtworkSettingTitle),
                                subtitle: Text(
                                  l10n.songFolderArtworkSettingDescription,
                                ),
                                value: preferences.enableFolderArtworkForSongs,
                                onChanged: (value) {
                                  appSettingsController
                                      .setEnableFolderArtworkForSongs(value);
                                },
                              ),
                              const SizedBox(height: 12),
                              divider(),
                              const SizedBox(height: 12),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                                title: Text(
                                  l10n.groupAlbumsByArtistSettingTitle,
                                ),
                                subtitle: Text(
                                  l10n.groupAlbumsByArtistSettingDescription,
                                ),
                                value: preferences.groupMetadataAlbumsByArtist,
                                onChanged: (value) {
                                  appSettingsController
                                      .setGroupMetadataAlbumsByArtist(value);
                                },
                              ),
                            ],
                          ),
                        if (_section != null) const SizedBox(height: 8),
                        if (_section == 4)
                          section(
                            title: l10n.scraperPipelineLabel,
                            children: [
                              settingRow(
                                title: l10n.lyricsScrapingServiceUrlLabel,
                                subtitle:
                                    (preferences.lyricsScrapingServiceBaseUrl
                                            ?.trim()
                                            .isNotEmpty ??
                                        false)
                                    ? l10n.lyricsScrapingServiceUrlConfigured
                                    : l10n.lyricsScrapingServiceUrlNotConfigured,
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                onTap: () => _showLyricsServiceUrlDialog(
                                  context: context,
                                  controller: appSettingsController,
                                  preferences: preferences,
                                ),
                              ),
                              const SizedBox(height: 12),
                              divider(),
                              const SizedBox(height: 12),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                                title: Text(l10n.enableLyricsScrapingLabel),
                                subtitle: Text(
                                  l10n.enableLyricsScrapingDescription,
                                ),
                                value: preferences.enableLyricsScraping,
                                onChanged: (value) {
                                  appSettingsController.setEnableLyricsScraping(
                                    value,
                                  );
                                },
                              ),
                            ],
                          ),
                        if (_section != null) const SizedBox(height: 8),
                        if (_section == 1)
                          section(
                            title: l10n.playbackCacheTitle,
                            children: [
                              settingRow(
                                title: l10n.persistentPlaybackCacheLabel,
                                subtitle:
                                    l10n.persistentPlaybackCacheDescription,
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
                              const SizedBox(height: 12),
                              divider(),
                              const SizedBox(height: 12),
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
                                            .setMemoryCacheTrackLimit(
                                              value.round(),
                                            );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.memoryCacheTrackLimitValue(
                                      cacheSettings.memoryCacheTrackLimit,
                                    ),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
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
                              if (_section != null) const SizedBox(height: 8),
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
                        if (_section != null) const SizedBox(height: 8),
                        if (_section == 5)
                          section(
                            title: l10n.debugSettingsTitle,
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                                title: Text(l10n.debugModeLabel),
                                subtitle: Text(l10n.debugModeDescription),
                                value: preferences.enableDebugMode,
                                onChanged: (value) {
                                  appSettingsController.setDebugMode(value);
                                  if (!value) {
                                    return;
                                  }
                                  showTopSnackBar(
                                    context,
                                    l10n.debugModeEnabledMessage,
                                    duration: const Duration(seconds: 3),
                                  );
                                },
                              ),
                            ],
                          ),
                        if (_section != null) const SizedBox(height: 8),
                        if (_section == 6)
                          section(
                            title: l10n.aboutAndUpdatesSettingTitle,
                            children: const [AppUpdatePanel()],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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

    return showModalBottomSheet<String?>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final dialogTheme = Theme.of(context);
            final dialogColorScheme = dialogTheme.colorScheme;
            final selectedColor = selectedHsv.toColor();

            void updateHsv(HSVColor color) {
              setState(() => selectedHsv = color);
              syncHexField(color.toColor());
            }

            return _SettingsBottomSheetFrame(
              title: l10n.themeColorDialogTitle,
              cancelLabel: materialL10n.cancelButtonLabel,
              confirmLabel: materialL10n.okButtonLabel,
              onCancel: () => Navigator.of(sheetContext).pop(),
              onConfirm: () {
                final hexColor = _hexFromColor(selectedHsv.toColor());
                final normalized =
                    CustomThemeColors.normalizeHexColor(hexColor) ?? hexColor;
                Navigator.of(sheetContext).pop(normalized);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: _CircularColorPicker(
                      hsvColor: selectedHsv,
                      onChanged: updateHsv,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HueSlider(
                    hsvColor: selectedHsv,
                    onChanged: (hue) {
                      updateHsv(selectedHsv.withHue(hue));
                    },
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: dialogColorScheme.surfaceContainerHigh.withValues(
                        alpha: 0.72,
                      ),
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
                              color ??= colorFromHex(value, enableAlpha: false);
                              if (color == null) {
                                return;
                              }
                              setState(
                                () => selectedHsv = HSVColor.fromColor(color!),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

  Future<void> _showCacheManagementDialog({
    required BuildContext context,
    required Map<String, String> sourceNames,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CacheManagementDialog(sourceNames: sourceNames),
    );
  }

  Future<void> _showLyricsServiceUrlDialog({
    required BuildContext context,
    required AppSettingsController controller,
    required LibraryPreferences preferences,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final textController = TextEditingController(
      text: preferences.lyricsScrapingServiceBaseUrl ?? '',
    );

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return GlacierDialog(
          title: Text(l10n.lyricsScrapingServiceUrlDialogTitle),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.lyricsScrapingServiceUrlDescription),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: l10n.lyricsScrapingServiceUrlHint,
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
              onPressed: () async {
                await controller.setLyricsScrapingServiceBaseUrl(null);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text(l10n.clearAction),
            ),
            FilledButton(
              onPressed: () async {
                await controller.setLyricsScrapingServiceBaseUrl(
                  textController.text,
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

    return showModalBottomSheet<void>(
      context: pageContext,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) {
        return _SettingsBottomSheetFrame(
          title: l10n.sourceManagementSettingTitle,
          headerTrailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sources.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await ref
                        .read(libraryCatalogControllerProvider.notifier)
                        .scanAllSources();
                  },
                  icon: const Icon(Icons.radar_rounded, size: 16),
                  label: Text(l10n.scanLibraryAction),
                ),
              if (sources.isNotEmpty) const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  showSourceTypePicker(pageContext);
                },
                icon: const Icon(Icons.add_link_rounded, size: 16),
                label: Text(l10n.addSourceAction),
              ),
            ],
          ),
          showFooter: false,
          cancelLabel: materialL10n.cancelButtonLabel,
          confirmLabel: materialL10n.okButtonLabel,
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () => Navigator.of(dialogContext).pop(),
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
    final materialL10n = MaterialLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return _SettingsBottomSheetFrame(
          title: title,
          cancelLabel: materialL10n.cancelButtonLabel,
          confirmLabel: materialL10n.okButtonLabel,
          onCancel: () => Navigator.of(dialogContext).pop(),
          onConfirm: () => Navigator.of(dialogContext).pop(),
          showFooter: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options) ...[
                StudioPanel(
                  padding: EdgeInsets.zero,
                  radius: 18,
                  tint: selectedValue == option.value
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerLow,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        studioRadiusOf(dialogContext, 18),
                      ),
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await onSelected(option.value);
                      },
                      child: Padding(
                        padding: studioListItemPaddingOf(dialogContext),
                        child: Row(
                          children: [
                            Container(
                              width: studioListIconBoxSizeOf(dialogContext),
                              height: studioListIconBoxSizeOf(dialogContext),
                              decoration: BoxDecoration(
                                color: selectedValue == option.value
                                    ? scheme.surface.withValues(alpha: 0.72)
                                    : scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  studioRadiusOf(dialogContext, 14),
                                ),
                              ),
                              child: Icon(
                                option.icon,
                                color: selectedValue == option.value
                                    ? scheme.primary
                                    : scheme.onPrimaryContainer,
                              ),
                            ),
                            SizedBox(width: studioListGapOf(dialogContext)),
                            Expanded(
                              child: Text(
                                option.label,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: selectedValue == option.value
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                      fontWeight: selectedValue == option.value
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                              ),
                            ),
                            if (selectedValue == option.value)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: scheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: studioListGapOf(dialogContext)),
              ],
            ],
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

  String _protocolLabel(AppLocalizations l10n, SourceProtocol value) {
    return switch (value) {
      SourceProtocol.webdav => l10n.webdavProtocol,
      SourceProtocol.sftp => l10n.sftpProtocol,
      SourceProtocol.ftp => l10n.ftpProtocol,
      SourceProtocol.samba => l10n.sambaProtocol,
      SourceProtocol.cloudDrive => l10n.cloud189Protocol,
    };
  }

  static const List<Color> _widgetBackgroundPresets = [
    Color(0xFF121620), // 深空黑 Deep Space Black
    Color(0xFF1E222D), // 曜石碳 Obsidian Dark
    Color(0xFF10223D), // 午夜深蓝 Midnight Navy
    Color(0xFF0D2826), // 北欧暗松青 Nordic Pine
    Color(0xFF2E141E), // 波尔多酒红 Bordeaux Wine
    Color(0xFF261536), // 暮色紫罗兰 Twilight Violet
    Color(0xFF291E16), // 琥珀黑咖 Amber Espresso
    Color(0xFF2C333D), // 雅致石板灰 Slate Gray
  ];

  static const List<Color> _widgetAccentPresets = [
    Color(0xFF58A6FF),
    Color(0xFFFFFFFF),
    Color(0xFFFFD700),
    Color(0xFF4ADE80),
    Color(0xFFFB7185),
    Color(0xFFA78BFA),
    Color(0xFFFB923C),
  ];

  Widget _buildWidgetPreview({
    required BuildContext context,
    required LibraryPreferences preferences,
    required WidgetStyleConfig config,
    required ColorScheme colorScheme,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final widgetBg = _colorFromHexOrFallback(
      config.backgroundColor,
      const Color(0xFF121620),
    );
    final widgetAccent = _colorFromHexOrFallback(
      config.themeColor,
      const Color(0xFF58A6FF),
    );
    final isCoverRight = config.coverPosition == 'right';
    final isCoverFill = config.coverFill;
    final coverOpacity = config.coverOpacity;
    final showLyrics = config.showLyrics;
    final isAccentLight = widgetAccent.computeLuminance() > 0.5;
    final playIconColor = isAccentLight ? const Color(0xFF121620) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  label: Text(l10n.widgetPreviewSmall),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text(l10n.widgetPreviewMedium),
                ),
                ButtonSegment<int>(
                  value: 2,
                  label: Text(l10n.widgetPreviewLarge),
                ),
              ],
              selected: {_widgetPreviewSize},
              onSelectionChanged: (set) {
                setState(() => _widgetPreviewSize = set.first);
              },
              showSelectedIcon: false,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: _widgetPreviewSize == 0 ? 170 : 320,
              height: _widgetPreviewSize == 0
                  ? 170
                  : (_widgetPreviewSize == 1 ? 120 : 330),
              decoration: BoxDecoration(
                color: widgetBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF2A3245),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (isCoverFill) ...[
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2B3A4A), Color(0xFF1E2836)],
                          ),
                        ),
                        child: Icon(
                          Icons.album_rounded,
                          size: 96,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    if (coverOpacity > 0.02)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(
                                  alpha: (0.35 * coverOpacity).clamp(0.0, 1.0),
                                ),
                                Colors.black.withValues(
                                  alpha: (0.85 * coverOpacity).clamp(0.0, 1.0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                  if (_widgetPreviewSize == 0)
                    _buildSmallPreviewContent(
                      isCoverFill: isCoverFill,
                      isCoverRight: isCoverRight,
                      widgetAccent: widgetAccent,
                      playIconColor: playIconColor,
                      showLyrics: showLyrics,
                    )
                  else if (_widgetPreviewSize == 1)
                    _buildMediumPreviewContent(
                      isCoverFill: isCoverFill,
                      isCoverRight: isCoverRight,
                      widgetAccent: widgetAccent,
                      playIconColor: playIconColor,
                      showLyrics: showLyrics,
                    )
                  else
                    _buildLargePreviewContent(
                      isCoverFill: isCoverFill,
                      isCoverRight: isCoverRight,
                      widgetAccent: widgetAccent,
                      playIconColor: playIconColor,
                      showLyrics: showLyrics,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallPreviewContent({
    required bool isCoverFill,
    required bool isCoverRight,
    required Color widgetAccent,
    required Color playIconColor,
    required bool showLyrics,
  }) {
    Widget coverTile() => Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF242C3D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF344057)),
          ),
          child: const Icon(
            Icons.music_note_rounded,
            size: 24,
            color: Color(0xFF8B949E),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (!isCoverFill && !isCoverRight) ...[
                  coverTile(),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '告白气球',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (showLyrics) ...[
                        Text(
                          '♪ 亲爱的 爱上你',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widgetAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        const Text(
                          '周杰伦',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF8B949E),
                            fontSize: 10,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: widgetAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'Hi-Res',
                          style: TextStyle(
                            color: widgetAccent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCoverFill && isCoverRight) ...[
                  const SizedBox(width: 8),
                  coverTile(),
                ],
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.skip_previous_rounded,
                size: 22,
                color: Color(0xFFE6EDF3),
              ),
              const SizedBox(width: 14),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widgetAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pause_rounded,
                  size: 16,
                  color: playIconColor,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(
                Icons.skip_next_rounded,
                size: 22,
                color: Color(0xFFE6EDF3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediumPreviewContent({
    required bool isCoverFill,
    required bool isCoverRight,
    required Color widgetAccent,
    required Color playIconColor,
    required bool showLyrics,
  }) {
    Widget coverTile() => Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF242C3D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF344057)),
          ),
          child: const Icon(
            Icons.music_note_rounded,
            size: 32,
            color: Color(0xFF8B949E),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          if (!isCoverFill && !isCoverRight) ...[
            coverTile(),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '告白气球',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: widgetAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Hi-Res',
                        style: TextStyle(
                          color: widgetAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Color(0xFFFF5252),
                    ),
                  ],
                ),
                if (showLyrics) ...[
                  Text(
                    '♪ 亲爱的 爱上你 从那天起',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widgetAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  const Text(
                    '周杰伦 · 周杰伦的床边故事',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 10,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      '01:18',
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 8,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: 0.35,
                          minHeight: 3,
                          backgroundColor: const Color(0xFF262E3E),
                          valueColor: AlwaysStoppedAnimation(widgetAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '03:35',
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.skip_previous_rounded,
                      size: 20,
                      color: Color(0xFFE6EDF3),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: widgetAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pause_rounded,
                        size: 14,
                        color: playIconColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.skip_next_rounded,
                      size: 20,
                      color: Color(0xFFE6EDF3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isCoverFill && isCoverRight) ...[
            const SizedBox(width: 10),
            coverTile(),
          ],
        ],
      ),
    );
  }

  Widget _buildLargePreviewContent({
    required bool isCoverFill,
    required bool isCoverRight,
    required Color widgetAccent,
    required Color playIconColor,
    required bool showLyrics,
  }) {
    Widget coverTile() => Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: const Color(0xFF242C3D),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF344057)),
          ),
          child: const Icon(
            Icons.music_note_rounded,
            size: 36,
            color: Color(0xFF8B949E),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!isCoverFill && !isCoverRight) ...[
                coverTile(),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: widgetAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'FLAC · 96kHz / 24bit',
                        style: TextStyle(
                          color: widgetAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '告白气球',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '周杰伦',
                      maxLines: 1,
                      style: TextStyle(color: Color(0xFFE6EDF3), fontSize: 11),
                    ),
                    const Text(
                      '周杰伦的床边故事',
                      maxLines: 1,
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 10),
                    ),
                    Text(
                      'OmniTune Hi-Fi Studio · Master Sound',
                      maxLines: 1,
                      style: TextStyle(color: widgetAccent, fontSize: 8),
                    ),
                  ],
                ),
              ),
              if (!isCoverFill && isCoverRight) ...[
                const SizedBox(width: 10),
                coverTile(),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: 0.35,
              minHeight: 3,
              backgroundColor: const Color(0xFF262E3E),
              valueColor: AlwaysStoppedAnimation(widgetAccent),
            ),
          ),
          const SizedBox(height: 2),
          const Row(
            children: [
              Text(
                '01:18',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 8),
              ),
              Spacer(),
              Text(
                '03:35',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 8),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: Color(0xFFFF5252),
              ),
              const Icon(
                Icons.skip_previous_rounded,
                size: 22,
                color: Color(0xFFE6EDF3),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: widgetAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.pause_rounded,
                  size: 16,
                  color: playIconColor,
                ),
              ),
              const Icon(
                Icons.skip_next_rounded,
                size: 22,
                color: Color(0xFFE6EDF3),
              ),
              const Icon(
                Icons.volume_up_rounded,
                size: 18,
                color: Color(0xFF8B949E),
              ),
            ],
          ),
          if (showLyrics) ...[
            const SizedBox(height: 6),
            Container(height: 1, color: const Color(0xFF202636)),
            const SizedBox(height: 6),
            // Lyric Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2232),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A354C)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '♪ ACTIVE LYRICS',
                    style: TextStyle(
                      color: widgetAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    '亲爱的 爱上你 从那天起 甜蜜的很轻易',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          // Queue Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2232),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2A354C)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UP NEXT IN QUEUE',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Next: 晴天 · 周杰伦',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFD0D7DE),
                    fontSize: 9,
                  ),
                ),
                Text(
                  'Then: 七里香 · 周杰伦',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF6E7681),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsBottomSheetFrame extends StatelessWidget {
  const _SettingsBottomSheetFrame({
    required this.title,
    required this.child,
    required this.onCancel,
    required this.onConfirm,
    required this.cancelLabel,
    required this.confirmLabel,
    this.headerTrailing,
    this.showFooter = true,
  });

  final String title;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final String confirmLabel;
  final Widget? headerTrailing;
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = studioRadiusOf(context, 28);
    final height = MediaQuery.sizeOf(context).height * 0.66;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (headerTrailing != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: headerTrailing!,
                        ),
                      ],
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.38),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: child,
                  ),
                ),
                if (showFooter) ...[
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.38),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            child: Text(cancelLabel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: onConfirm,
                            child: Text(confirmLabel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeAccentSwatchRow extends StatelessWidget {
  const _ThemeAccentSwatchRow({
    required this.label,
    required this.currentHex,
    required this.presets,
    required this.onPresetSelected,
    required this.onCustomSelected,
  });

  final String label;
  final String? currentHex;
  final List<Color> presets;
  final ValueChanged<Color> onPresetSelected;
  final VoidCallback onCustomSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedCurrent = CustomThemeColors.normalizeHexColor(currentHex);

    bool isSelected(Color color) {
      return normalizedCurrent == _hexFromColorStatic(color);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 30,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        for (final color in presets) ...[
          _ThemeAccentSwatchButton(
            color: color,
            selected: isSelected(color),
            onTap: () => onPresetSelected(color),
          ),
          const SizedBox(width: 6),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onCustomSelected,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHigh,
              border: Border.all(color: colorScheme.outline),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  static String _hexFromColorStatic(Color color) {
    final argb = color.toARGB32();
    final rgb = argb & 0xFFFFFF;
    return '#${rgb.toRadixString(16).toUpperCase().padLeft(6, '0')}';
  }
}

class _ThemeAccentSwatchButton extends StatelessWidget {
  const _ThemeAccentSwatchButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectionColor = color.computeLuminance() > 0.72
        ? colorScheme.onSurface
        : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? selectionColor : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
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

  static const _pickerSize = 220.0;

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
        const height = 15.0;
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
      5.5,
      Paint()
        ..color = selectedHueColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      5.5,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(thumbX, size.height / 2),
      6.6,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
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
  late final Future<List<PlaybackCacheInventoryItem>> _initialInventoryFuture;

  @override
  void initState() {
    super.initState();
    final cache = ref.read(webDavPlaybackCacheProvider);
    _inventoryStream = cache.watchCachedTracks();
    _initialInventoryFuture = cache.listCachedTracks();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    return FutureBuilder<List<PlaybackCacheInventoryItem>>(
      future: _initialInventoryFuture,
      builder: (context, initialSnapshot) {
        return StreamBuilder<List<PlaybackCacheInventoryItem>>(
          stream: _inventoryStream,
          initialData: initialSnapshot.data,
          builder: (context, snapshot) {
            final items =
                snapshot.data ??
                initialSnapshot.data ??
                const <PlaybackCacheInventoryItem>[];
            final itemIds = items.map((item) => item.trackId).toSet();
            final selectedIds = _selectedTrackIds
                .where(itemIds.contains)
                .toSet();

            return _SettingsBottomSheetFrame(
              title: l10n.clearCachedFilesTitle,
              cancelLabel: materialL10n.cancelButtonLabel,
              confirmLabel: materialL10n.okButtonLabel,
              onCancel: () => Navigator.of(context).pop(),
              onConfirm: () => Navigator.of(context).pop(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!snapshot.hasData &&
                      !initialSnapshot.hasData &&
                      snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (items.isEmpty)
                    _DialogEmptyState(
                      icon: Icons.offline_bolt_outlined,
                      title: l10n.cachedTracksEmptyTitle,
                      description: l10n.cachedTracksEmptyDescription,
                    )
                  else ...[
                    Text(l10n.playbackCacheNotice),
                    const SizedBox(height: 12),
                    Text(
                      '${l10n.cachedBytesLabel}: ${_cacheSize(items.fold<int>(0, (sum, item) => sum + item.cachedBytes))}',
                    ),
                    Text(
                      '${l10n.memoryCacheUsageLabel}: ${_cacheSize(ref.read(webDavPlaybackCacheProvider).retainedMemoryBytes)} / 64 MiB',
                    ),
                    for (final sourceId
                        in items.map((item) => item.sourceId).toSet())
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(widget.sourceNames[sourceId] ?? sourceId),
                        subtitle: Text(
                          _cacheSize(
                            items
                                .where((item) => item.sourceId == sourceId)
                                .fold<int>(
                                  0,
                                  (sum, item) => sum + item.cachedBytes,
                                ),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: l10n.clearSourceCacheAction,
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            await ref
                                .read(webDavPlaybackCacheProvider)
                                .removeCachedTracks(
                                  items
                                      .where(
                                        (item) => item.sourceId == sourceId,
                                      )
                                      .map((item) => item.trackId)
                                      .toSet(),
                                );
                            if (mounted) setState(_selectedTrackIds.clear);
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.selectedCacheCountLabel(selectedIds.length),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
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
                          onPressed: () async {
                            await ref
                                .read(webDavPlaybackCacheProvider)
                                .clearMemoryCachedData();
                            if (!mounted) {
                              return;
                            }
                            setState(_selectedTrackIds.clear);
                            showTopSnackBar(
                              this.context,
                              l10n.cacheClearedMessage,
                            );
                          },
                          child: Text(l10n.clearCacheAction),
                        ),
                        FilledButton.tonal(
                          onPressed: selectedIds.isEmpty
                              ? null
                              : () async {
                                  await ref
                                      .read(webDavPlaybackCacheProvider)
                                      .removeCachedTracks(selectedIds);
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedTrackIds.removeAll(selectedIds);
                                  });
                                  showTopSnackBar(
                                    this.context,
                                    l10n.selectedCacheDeletedMessage(
                                      selectedIds.length,
                                    ),
                                  );
                                },
                          child: Text(l10n.deleteSelectedCacheAction),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (context, _) =>
                          SizedBox(height: studioListGapOf(context)),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = selectedIds.contains(item.trackId);
                        final sourceName =
                            widget.sourceNames[item.sourceId] ??
                            l10n.cacheUnknownSourceLabel;
                        final cacheMode = _cacheModeLabel(l10n, item);
                        final coverage =
                            item.totalBytes == null || item.totalBytes == 0
                            ? l10n.cacheCoverageUnknownLabel
                            : l10n.cacheCoverageLabel(
                                ((item.cachedBytes / item.totalBytes!) * 100)
                                    .round(),
                              );

                        return Material(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                          child: CheckboxListTile(
                            value: selected,
                            dense: true,
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -3,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
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
                                  _selectedTrackIds.remove(item.trackId);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
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

String _cacheSize(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
