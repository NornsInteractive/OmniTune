import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/isar_manager.dart';
import '../../../library/presentation/folder_artwork_provider.dart';
import '../../../settings/application/app_settings_controller.dart';

import 'cover_art_image.dart';

class TrackCoverThumbnail extends ConsumerWidget {
  const TrackCoverThumbnail({
    super.key,
    required this.title,
    required this.subtitle,
    required this.size,
    required this.borderRadius,
    this.clipBorderRadius,
    this.showFrame = true,
    this.localCoverPath,
    this.coverUrl,
    this.isCurrentTrack = false,
    this.trackId,
    this.sourceId,
    this.directoryPath,
  });

  final String title;
  final String subtitle;
  final double size;
  final double borderRadius;
  final BorderRadiusGeometry? clipBorderRadius;
  final bool showFrame;
  final String? localCoverPath;
  final String? coverUrl;
  final bool isCurrentTrack;
  final String? trackId;
  final String? sourceId;
  final String? directoryPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final preferences = ref.watch(appSettingsControllerProvider).valueOrNull;
    final metadata = _normalized(trackId) == null
        ? null
        : IsarManager.getMetadata(_normalized(trackId)!);
    final hasResolvedSongCover =
        _normalized(localCoverPath) != null || _normalized(coverUrl) != null;
    final hasManualCover =
        _normalized(metadata?.manuallyScrapedLocalCoverPath) != null ||
        _normalized(metadata?.manuallyScrapedCoverUrl) != null;
    final hasEmbeddedCover = metadata?.autoScrapedCoverSource == 'embedded';
    final canUseFolderArtwork =
        (preferences?.enableFolderArtworkForSongs ?? true) &&
        _normalized(sourceId) != null &&
        _normalized(directoryPath) != null &&
        !hasManualCover &&
        !hasEmbeddedCover &&
        !(metadata == null && hasResolvedSongCover);
    final folderArtwork = canUseFolderArtwork
        ? ref.watch(
            folderArtworkProvider(
              FolderArtworkRequest(
                sourceId: _normalized(sourceId)!,
                directoryPath: _normalized(directoryPath)!,
              ),
            ),
          )
        : null;
    final folderArtworkPath = _normalized(
      folderArtwork?.valueOrNull?.localPath,
    );
    final effectiveLocalCoverPath = folderArtworkPath ?? localCoverPath;
    final effectiveCoverUrl = folderArtworkPath == null ? coverUrl : null;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CoverArtImage(
            title: title,
            subtitle: subtitle,
            size: size,
            borderRadius: borderRadius,
            clipBorderRadius: clipBorderRadius,
            showFrame: showFrame,
            localCoverPath: effectiveLocalCoverPath,
            coverUrl: effectiveCoverUrl,
          ),
          if (isCurrentTrack)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 2),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: size * 0.28,
                  color: colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _normalized(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
