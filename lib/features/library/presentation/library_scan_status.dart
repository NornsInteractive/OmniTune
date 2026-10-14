import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/localizations.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isScanning) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(l10n.currentScanSourceLabel(state.lastScanSourceName ?? '')),
            Text(
              l10n.scanningProgress(
                state.scannedDirectoryCount,
                state.discoveredTrackCount,
              ),
            ),
            Text(
              state.lastScanPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (state.isScanCancelled) Text(l10n.scanCancelledLabel),
          if (state.failedSourceIds.isNotEmpty)
            Text(
              '${l10n.scanFailedSourcesLabel}: ${state.failedSourceIds.length}',
            ),
          Wrap(
            spacing: 8,
            children: [
              if (state.isScanning)
                TextButton.icon(
                  onPressed: state.isScanCancelled
                      ? null
                      : controller.cancelScan,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(l10n.cancelScanAction),
                ),
              if (!state.isScanning && state.failedSourceIds.isNotEmpty)
                TextButton.icon(
                  onPressed: controller.retryFailedSources,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retryFailedScanAction),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
