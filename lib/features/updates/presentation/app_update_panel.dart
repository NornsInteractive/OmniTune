import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/studio_chrome.dart';
import '../application/app_update_controller.dart';

class AppUpdatePanel extends ConsumerStatefulWidget {
  const AppUpdatePanel({super.key, this.onLaunchUrl});

  final Future<bool> Function(Uri uri)? onLaunchUrl;

  @override
  ConsumerState<AppUpdatePanel> createState() => _AppUpdatePanelState();
}

class _AppUpdatePanelState extends ConsumerState<AppUpdatePanel> {
  static final Uri _repositoryUri = Uri.parse(
    'https://github.com/NornsInteractive/OmniTune',
  );
  static final Uri _websiteUri = Uri.parse(
    'https://norns.cc.cd',
  );

  Future<void> _launchWebsiteUrl() async {
    final launcher = widget.onLaunchUrl;
    if (launcher != null) {
      await launcher(_websiteUri);
      return;
    }
    try {
      await launchUrl(_websiteUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Prevent unhandled exception in environments without launcher.
    }
  }

  Future<void> _launchRepositoryUrl() async {
    final launcher = widget.onLaunchUrl;
    if (launcher != null) {
      await launcher(_repositoryUri);
      return;
    }
    try {
      await launchUrl(_repositoryUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Prevent unhandled exception in environments without launcher.
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final state = ref.read(appUpdateControllerProvider);
      if (!state.isBusy &&
          state.phase != AppUpdatePhase.downloading &&
          state.phase != AppUpdatePhase.awaitingInstall) {
        ref.read(appUpdateControllerProvider.notifier).check();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appUpdateControllerProvider);
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final isAndroid = state.release?.platform == 'android';

    return TickerMode(
      enabled: !disableAnimations,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVersionHeader(
            l10n: l10n,
            colorScheme: colorScheme,
            theme: theme,
            state: state,
            disableAnimations: disableAnimations,
            onCheck: controller.check,
          ),
          const SizedBox(height: 12),
          _buildStatusBody(
            state: state,
            controller: controller,
            l10n: l10n,
            colorScheme: colorScheme,
            theme: theme,
            isAndroid: isAndroid,
            disableAnimations: disableAnimations,
          ),
          if (state.phase != AppUpdatePhase.idle) const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 14),
          _buildIdentitySection(
            context: context,
            l10n: l10n,
            colorScheme: colorScheme,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildVersionHeader({
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required AppUpdateState state,
    required bool disableAnimations,
    required VoidCallback onCheck,
  }) {
    final versionText = _formatVersion(
      l10n,
      state.installedVersion,
      state.installedBuild,
    );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${l10n.appUpdateCurrentVersionLabel}: $versionText',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: state.isBusy ? null : onCheck,
          icon: state.isBusy
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: disableAnimations
                      ? Icon(
                          Icons.hourglass_empty_rounded,
                          size: 14,
                          color: colorScheme.onSecondaryContainer,
                        )
                      : CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onSecondaryContainer,
                        ),
                )
              : const Icon(Icons.refresh_rounded, size: 16),
          label: Text(l10n.appUpdateCheckAction),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBody({
    required AppUpdateState state,
    required AppUpdateController controller,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required bool isAndroid,
    required bool disableAnimations,
  }) {
    switch (state.phase) {
      case AppUpdatePhase.idle:
        return const SizedBox.shrink();

      case AppUpdatePhase.checking:
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 18,
            height: 18,
            child: disableAnimations
                ? Icon(Icons.sync_rounded, size: 18, color: colorScheme.primary)
                : CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
          ),
          title: Text(
            l10n.appUpdateCheckingStatus,
            style: theme.textTheme.bodyMedium,
          ),
        );

      case AppUpdatePhase.upToDate:
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.check_circle_outline_rounded,
            color: colorScheme.primary,
            size: 20,
          ),
          title: Text(
            l10n.appUpdateUpToDateStatus,
            style: theme.textTheme.bodyMedium,
          ),
        );

      case AppUpdatePhase.unsupported:
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.help_outline_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          title: Text(
            l10n.appUpdateUnsupportedPlatform,
            style: theme.textTheme.bodyMedium,
          ),
        );

      case AppUpdatePhase.canceled:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              l10n.appUpdateCanceledStatus,
              style: theme.textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: controller.check,
              child: Text(l10n.appUpdateCheckAction),
            ),
          ],
        );

      case AppUpdatePhase.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _failureMessage(l10n, state.failure),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                FilledButton.tonal(
                  onPressed: controller.check,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l10n.appUpdateCheckAgainAction),
                ),
                if (state.release != null)
                  FilledButton(
                    onPressed: controller.downloadAndInstall,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(l10n.appUpdateRetryDownloadAction),
                  ),
              ],
            ),
          ],
        );

      case AppUpdatePhase.available:
      case AppUpdatePhase.downloading:
      case AppUpdatePhase.awaitingInstall:
        final release = state.release;
        if (release == null) {
          return const SizedBox.shrink();
        }
        final releaseVersionText = _formatVersion(
          l10n,
          release.versionName,
          release.versionCode,
        );
        final sizeText = _formatFileSize(l10n, release.fileSize);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${l10n.appUpdateAvailableTitle}: $releaseVersionText',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  sizeText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (release.changelog.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                l10n.appUpdateReleaseNotesTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(
                    studioRadiusOf(context, 8),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    release.changelog.trim(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildAction(
              state: state,
              controller: controller,
              l10n: l10n,
              colorScheme: colorScheme,
              theme: theme,
              isAndroid: isAndroid,
              disableAnimations: disableAnimations,
            ),
          ],
        );
    }
  }

  Widget _buildAction({
    required AppUpdateState state,
    required AppUpdateController controller,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required bool isAndroid,
    required bool disableAnimations,
  }) {
    if (state.phase == AppUpdatePhase.downloading) {
      final progress = state.progress;
      final percentInt = progress != null
          ? (progress * 100).clamp(0, 100).toInt()
          : null;
      final percentText = percentInt != null
          ? l10n.appUpdateProgressPercent(percentInt)
          : '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.appUpdateDownloadingLabel,
                style: theme.textTheme.bodySmall,
              ),
              if (percentText.isNotEmpty)
                Text(
                  percentText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: disableAnimations ? (progress ?? 0.0) : progress,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: controller.cancel,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.appUpdateCancelAction),
            ),
          ),
        ],
      );
    }

    if (state.phase == AppUpdatePhase.awaitingInstall) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.appUpdateAwaitingInstallTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.appUpdateAwaitingInstallDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: controller.downloadAndInstall,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: Text(l10n.appUpdateRetryDownloadAction),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: controller.downloadAndInstall,
        icon: Icon(
          isAndroid ? Icons.download_rounded : Icons.open_in_browser_rounded,
          size: 18,
        ),
        label: Text(
          isAndroid
              ? l10n.appUpdateActionDownloadAndInstall
              : l10n.appUpdateActionDownloadLatest,
        ),
      ),
    );
  }

  Widget _buildIdentitySection({
    required BuildContext context,
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.corporate_fare_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.aboutOrganizationLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              l10n.aboutOrganizationValue,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.language_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.aboutOfficialWebsiteLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Tooltip(
              message: _websiteUri.toString(),
              child: OutlinedButton.icon(
                onPressed: _launchWebsiteUrl,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('norns.cc.cd'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      studioRadiusOf(context, 8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.code_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.aboutRepositoryLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Tooltip(
              message: _repositoryUri.toString(),
              child: OutlinedButton.icon(
                onPressed: _launchRepositoryUrl,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: Text(l10n.aboutRepositoryAction),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 32),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      studioRadiusOf(context, 8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatVersion(
    AppLocalizations l10n,
    String? version,
    int? build,
  ) {
    if (version == null) {
      return l10n.appUpdateVersionUnknown;
    }
    if (build != null && build > 0) {
      return l10n.appUpdateVersionFormat(version, build);
    }
    return l10n.appUpdateVersionOnly(version);
  }

  static String _formatFileSize(AppLocalizations l10n, int bytes) {
    if (bytes <= 0) {
      return l10n.appUpdateSizeB('0');
    }
    if (bytes >= 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      return l10n.appUpdateSizeMB(mb.toStringAsFixed(mb >= 100 ? 0 : 1));
    }
    if (bytes >= 1024) {
      final kb = bytes / 1024;
      return l10n.appUpdateSizeKB(kb.toStringAsFixed(kb >= 100 ? 0 : 1));
    }
    return l10n.appUpdateSizeB('$bytes');
  }

  static String _failureMessage(
    AppLocalizations l10n,
    AppUpdateFailure? failure,
  ) {
    return switch (failure) {
      AppUpdateFailure.network => l10n.appUpdateErrorNetwork,
      AppUpdateFailure.invalidResponse => l10n.appUpdateErrorInvalidResponse,
      AppUpdateFailure.noPackage => l10n.appUpdateUnsupportedPlatform,
      AppUpdateFailure.checksumMissing => l10n.appUpdateErrorChecksumMissing,
      AppUpdateFailure.checksum => l10n.appUpdateErrorChecksumMismatch,
      AppUpdateFailure.download => l10n.appUpdateErrorDownloadFailed,
      AppUpdateFailure.permission => l10n.appUpdateErrorPermissionDenied,
      AppUpdateFailure.installation => l10n.appUpdateErrorInstallationFailed,
      _ => l10n.appUpdateErrorUnknown,
    };
  }
}
