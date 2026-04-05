import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../core/models/app_preferences.dart';
import '../../../core/models/playback_cache_settings.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../library/application/library_catalog_controller.dart';
import '../../library/application/library_controller.dart';
import '../../player/application/playback_cache_settings_controller.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/data/webdav/webdav_playback_cache_base.dart';
import '../../sources/data/webdav/webdav_playback_cache_provider.dart';
import '../application/app_settings_controller.dart';

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
    final cacheSettings =
        ref.watch(playbackCacheSettingsControllerProvider).valueOrNull ??
        const PlaybackCacheSettings();
    final sources =
        ref.watch(sourcesControllerProvider).valueOrNull ??
        const <SourceProfile>[];
    final browser = ref.watch(libraryControllerProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPageTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.surfaceContainerHigh,
                        colorScheme.secondaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.settingsCenterHeadline,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.settingsCenterDescription,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _MetaPill(
                            icon: Icons.language_rounded,
                            label: _localeLabel(
                              l10n,
                              preferences.localePreference,
                            ),
                          ),
                          _MetaPill(
                            icon: Icons.palette_outlined,
                            label: _themeLabel(
                              l10n,
                              preferences.themePreference,
                            ),
                          ),
                          _MetaPill(
                            icon: Icons.cloud_done_rounded,
                            label: l10n.savedSourcesCountLabel(sources.length),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: l10n.appearanceSettingsTitle,
                  children: [
                    _SettingTile(
                      icon: Icons.language_rounded,
                      title: l10n.languageSettingTitle,
                      subtitle: _localeLabel(
                        l10n,
                        preferences.localePreference,
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
                        onSelected: (value) {
                          return ref
                              .read(appSettingsControllerProvider.notifier)
                              .setLocalePreference(value);
                        },
                      ),
                    ),
                    _SettingTile(
                      icon: Icons.dark_mode_outlined,
                      title: l10n.themeSettingTitle,
                      subtitle: _themeLabel(l10n, preferences.themePreference),
                      onTap: () => _showSelectionDialog<AppThemePreference>(
                        context: context,
                        title: l10n.themeSettingTitle,
                        selectedValue: preferences.themePreference,
                        options: [
                          _DialogOption(
                            value: AppThemePreference.system,
                            label: _themeLabel(l10n, AppThemePreference.system),
                            icon: Icons.brightness_auto_rounded,
                          ),
                          _DialogOption(
                            value: AppThemePreference.light,
                            label: _themeLabel(l10n, AppThemePreference.light),
                            icon: Icons.light_mode_rounded,
                          ),
                          _DialogOption(
                            value: AppThemePreference.dark,
                            label: _themeLabel(l10n, AppThemePreference.dark),
                            icon: Icons.dark_mode_rounded,
                          ),
                        ],
                        onSelected: (value) {
                          return ref
                              .read(appSettingsControllerProvider.notifier)
                              .setThemePreference(value);
                        },
                      ),
                    ),
                    _SettingTile(
                      icon: Icons.dashboard_customize_outlined,
                      title: l10n.interfaceSizeSettingTitle,
                      subtitle: l10n.interfaceScaleSummary(
                        _scalePercent(preferences.interfaceScaleFactor),
                      ),
                      onTap: () => _showScaleDialog(
                        context: context,
                        title: l10n.interfaceSizeSettingTitle,
                        description: l10n.interfaceSizeDialogDescription,
                        min: AppDisplayPreferences.minInterfaceScale,
                        max: AppDisplayPreferences.maxInterfaceScale,
                        divisions: 50,
                        initialValue: preferences.interfaceScaleFactor,
                        onSaved: (value) {
                          return ref
                              .read(appSettingsControllerProvider.notifier)
                              .setInterfaceScale(value);
                        },
                      ),
                    ),
                    _SettingTile(
                      icon: Icons.format_size_rounded,
                      title: l10n.fontSizeSettingTitle,
                      subtitle: l10n.fontScaleSummary(
                        _scalePercent(preferences.fontScaleFactor),
                      ),
                      onTap: () => _showScaleDialog(
                        context: context,
                        title: l10n.fontSizeSettingTitle,
                        description: l10n.fontSizeDialogDescription,
                        min: AppDisplayPreferences.minFontScale,
                        max: AppDisplayPreferences.maxFontScale,
                        divisions: 57,
                        initialValue: preferences.fontScaleFactor,
                        onSaved: (value) {
                          return ref
                              .read(appSettingsControllerProvider.notifier)
                              .setFontScale(value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: l10n.librarySettingsTitle,
                  children: [
                    _SettingTile(
                      icon: Icons.storage_rounded,
                      title: l10n.sourceManagementSettingTitle,
                      subtitle: browser?.selectedSource == null
                          ? l10n.sourceManagementEmptySummary
                          : l10n.sourceManagementSummary(
                              browser!.selectedSource!.name,
                              sources.length,
                            ),
                      onTap: () => _showSourceManagementDialog(
                        pageContext: context,
                        ref: ref,
                        sources: sources,
                        selectedSource: browser?.selectedSource,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SettingsSection(
                  title: l10n.playbackCacheTitle,
                  children: [
                    _SettingTile(
                      icon: Icons.offline_bolt_outlined,
                      title: l10n.cacheSettingsEntryTitle,
                      subtitle: l10n.cacheSettingsSummary(
                        cacheSettings.enablePersistentCache
                            ? l10n.cacheStorageModeLocal
                            : l10n.cacheStorageModeMemory,
                        cacheSettings.memoryCacheTrackLimit,
                      ),
                      onTap: () => _showCacheSettingsDialog(
                        context: context,
                        ref: ref,
                        initialSettings: cacheSettings,
                      ),
                    ),
                    _SettingTile(
                      icon: Icons.delete_sweep_outlined,
                      title: l10n.clearCachedFilesTitle,
                      subtitle: l10n.clearCachedFilesDescription,
                      destructive: true,
                      onTap: () => _showCacheManagementDialog(
                        context: context,
                        sourceNames: {
                          for (final source in sources) source.id: source.name,
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
            return AlertDialog(
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
            return AlertDialog(
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
        return AlertDialog(
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
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              dialogContext,
                            ).colorScheme.surface,
                            child: const Icon(Icons.cloud_circle_rounded),
                          ),
                          title: Text(source.name),
                          subtitle: Text(
                            '${_protocolLabel(l10n, source.protocol)} · ${source.rootPath} · ${source.hostLabel}',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              if (selectedSource?.id == source.id)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Theme.of(
                                    dialogContext,
                                  ).colorScheme.primary,
                                ),
                              IconButton(
                                tooltip: l10n.editSourceAction,
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  GoRouter.of(
                                    pageContext,
                                  ).push('/settings/source/${source.id}');
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: materialL10n.deleteButtonTooltip,
                                onPressed: () async {
                                  Navigator.of(dialogContext).pop();
                                  await ref
                                      .read(sourcesControllerProvider.notifier)
                                      .deleteProfile(source.id);
                                  ref.invalidate(libraryControllerProvider);
                                  ref.invalidate(
                                    libraryCatalogControllerProvider,
                                  );
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                          onTap: () async {
                            Navigator.of(dialogContext).pop();
                            await ref
                                .read(libraryControllerProvider.notifier)
                                .selectSource(source.id);
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
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
                GoRouter.of(pageContext).push('/settings/add-source');
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
        return AlertDialog(
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
                      Card(
                        child: RadioListTile<T>(
                          value: option.value,
                          secondary: Icon(option.icon),
                          title: Text(option.label),
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

  String _protocolLabel(AppLocalizations l10n, SourceProtocol value) {
    return switch (value) {
      SourceProtocol.webdav => l10n.webdavProtocol,
      SourceProtocol.sftp => l10n.sftpProtocol,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 12),
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
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = destructive
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: destructive
                      ? colorScheme.errorContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: destructive
                      ? colorScheme.onErrorContainer
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: destructive ? colorScheme.error : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: accentColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: accentColor),
            ],
          ),
        ),
      ),
    );
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

        return AlertDialog(
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
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
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
