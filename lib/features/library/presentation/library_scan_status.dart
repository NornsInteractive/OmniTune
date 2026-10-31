import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/localizations.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../application/library_catalog_controller.dart';

class LibraryScanStatus extends ConsumerWidget {
  const LibraryScanStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryCatalogControllerProvider).valueOrNull;
    if (state == null ||
        (!state.isScanning &&
            !state.isScanCancelled &&
            state.failedSourceIds.isEmpty)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(libraryCatalogControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final cardRadius = studioRadiusOf(context, 16);

    final isFailed = !state.isScanning && state.failedSourceIds.isNotEmpty;

    final headerIcon = state.isScanning
        ? Icons.radar_rounded
        : isFailed
        ? Icons.warning_amber_rounded
        : Icons.info_outline_rounded;

    final headerIconColor = isFailed
        ? colorScheme.error
        : state.isScanning
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    final headerTitle = state.isScanning
        ? l10n.currentScanSourceLabel(state.lastScanSourceName ?? '')
        : isFailed
        ? '${l10n.scanFailedSourcesLabel}: ${state.failedSourceIds.length}'
        : l10n.scanCancelledLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: isFailed
            ? colorScheme.errorContainer.withValues(alpha: 0.22)
            : colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: isFailed
                ? colorScheme.error.withValues(alpha: 0.35)
                : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: studioPaddingOf(context, const EdgeInsets.all(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(headerIcon, color: headerIconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      headerTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isFailed
                            ? colorScheme.error
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              if (state.isScanning) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: disableAnimations ? 0.5 : null,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.scanningProgress(
                    state.scannedDirectoryCount,
                    state.discoveredTrackCount,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (state.lastScanPath.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    state.lastScanPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ],
              if (state.isScanCancelled && state.isScanning) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.scanCancelledLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (isFailed &&
                  state.lastScanError != null &&
                  state.lastScanError!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  state.lastScanError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (state.isScanning)
                    OutlinedButton.icon(
                      onPressed: state.isScanCancelled
                          ? null
                          : controller.cancelScan,
                      icon: const Icon(Icons.stop_circle_outlined, size: 16),
                      label: Text(l10n.cancelScanAction),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(48, 36),
                      ),
                    ),
                  if (!state.isScanning && state.failedSourceIds.isNotEmpty)
                    FilledButton.tonalIcon(
                      onPressed: controller.retryFailedSources,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(l10n.retryFailedScanAction),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(48, 36),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
