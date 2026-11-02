import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:music/core/widgets/glacier_dialog.dart';
import 'package:music/core/widgets/studio_chrome.dart';
import 'package:music/features/updates/application/app_update_controller.dart';

class AutoUpdateDialog extends ConsumerWidget {
  const AutoUpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AutoUpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final release = state.release;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (release == null) {
      return const SizedBox.shrink();
    }

    final versionText = release.versionCode > 0
        ? l10n.appUpdateVersionFormat(release.versionName, release.versionCode)
        : l10n.appUpdateVersionOnly(release.versionName);

    final sizeText = _formatFileSize(l10n, release.fileSize);
    final isAndroid = release.platform == 'android';

    return GlacierDialog(
      maxWidth: 480,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(studioRadiusOf(context, 12)),
            ),
            child: Icon(
              Icons.system_update_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.appUpdateAvailableTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$versionText  ·  $sizeText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (release.changelog.trim().isNotEmpty) ...[
            Text(
              l10n.appUpdateReleaseNotesTitle,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(studioRadiusOf(context, 12)),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  release.changelog.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(appUpdateControllerProvider.notifier).dismissUpdateDialog();
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: Text(l10n.appUpdateLaterAction),
        ),
        FilledButton.icon(
          onPressed: () {
            ref.read(appUpdateControllerProvider.notifier).downloadAndInstall();
            Navigator.of(context, rootNavigator: true).pop();
          },
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
      ],
    );
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
}
