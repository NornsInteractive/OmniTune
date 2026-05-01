import 'package:flutter/material.dart';

import 'cover_art_image.dart';

class TrackCoverThumbnail extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
            localCoverPath: localCoverPath,
            coverUrl: coverUrl,
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
}
