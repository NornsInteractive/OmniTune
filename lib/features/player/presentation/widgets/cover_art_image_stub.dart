import 'package:flutter/material.dart';

import '../../../../core/widgets/studio_chrome.dart';
import 'generated_cover_art.dart';

class CoverArtImage extends StatelessWidget {
  const CoverArtImage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.size,
    required this.borderRadius,
    this.clipBorderRadius,
    this.showFrame = true,
    this.localCoverPath,
    this.coverUrl,
  });

  final String title;
  final String subtitle;
  final double size;
  final double borderRadius;
  final BorderRadiusGeometry? clipBorderRadius;
  final bool showFrame;
  final String? localCoverPath;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final remoteUrl = coverUrl?.trim();
    final effectiveBorderRadius = clipBorderRadius != null
        ? studioBorderRadiusOf(context, clipBorderRadius!)
        : BorderRadius.circular(studioRadiusOf(context, borderRadius));
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Image.network(
          remoteUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => _generated(),
        ),
      );
    }
    return _generated();
  }

  Widget _generated() {
    return GeneratedCoverArt(
      title: title,
      subtitle: subtitle,
      size: size,
      borderRadius: borderRadius,
      clipBorderRadius: clipBorderRadius,
      showFrame: showFrame,
    );
  }
}
