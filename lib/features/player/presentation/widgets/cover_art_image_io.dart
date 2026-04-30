import 'dart:io';

import 'package:flutter/material.dart';

import 'generated_cover_art.dart';

class CoverArtImage extends StatelessWidget {
  const CoverArtImage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.size,
    required this.borderRadius,
    this.localCoverPath,
    this.coverUrl,
  });

  final String title;
  final String subtitle;
  final double size;
  final double borderRadius;
  final String? localCoverPath;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final localPath = localCoverPath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          File(localPath),
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) => _remoteOrGenerated(),
        ),
      );
    }

    return _remoteOrGenerated();
  }

  Widget _remoteOrGenerated() {
    final remoteUrl = coverUrl?.trim();
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
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
    );
  }
}
