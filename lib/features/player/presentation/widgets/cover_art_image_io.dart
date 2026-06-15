import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/storage/cover_art_cache_manager.dart';
import '../../../../core/widgets/studio_chrome.dart';
import 'generated_cover_art.dart';

class CoverArtImage extends StatefulWidget {
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
  State<CoverArtImage> createState() => _CoverArtImageState();
}

class _CoverArtImageState extends State<CoverArtImage> {
  String? _resolvedLocalPath;

  @override
  void initState() {
    super.initState();
    _resolvedLocalPath = _normalize(widget.localCoverPath);
    _primeLocalCover();
  }

  @override
  void didUpdateWidget(covariant CoverArtImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localCoverPath != widget.localCoverPath ||
        oldWidget.coverUrl != widget.coverUrl) {
      _resolvedLocalPath = _normalize(widget.localCoverPath);
      _primeLocalCover();
    }
  }

  Future<void> _primeLocalCover() async {
    if (_resolvedLocalPath?.isNotEmpty == true) {
      return;
    }

    final remoteUrl = _normalize(widget.coverUrl);
    if (remoteUrl == null) {
      return;
    }

    final cacheManager = CoverArtCacheManager();
    final cachedPath = await cacheManager.cachedPathForUrl(remoteUrl);
    if (!mounted) {
      return;
    }
    if (cachedPath?.isNotEmpty == true) {
      setState(() => _resolvedLocalPath = cachedPath);
      return;
    }

    final downloadedPath = await cacheManager.downloadAndCache(remoteUrl);
    if (!mounted) {
      return;
    }
    if (downloadedPath?.isNotEmpty == true) {
      setState(() => _resolvedLocalPath = downloadedPath);
    }
  }

  String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.clipBorderRadius != null
        ? studioBorderRadiusOf(context, widget.clipBorderRadius!)
        : BorderRadius.circular(studioRadiusOf(context, widget.borderRadius));
    final cacheExtent = _cacheExtentFor(context);
    final localPath = _resolvedLocalPath;
    if (localPath != null && localPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Image.file(
          File(localPath),
          fit: BoxFit.cover,
          width: widget.size,
          height: widget.size,
          cacheWidth: cacheExtent,
          cacheHeight: cacheExtent,
          errorBuilder: (context, error, stackTrace) => _remoteOrGenerated(),
        ),
      );
    }

    return _remoteOrGenerated();
  }

  Widget _remoteOrGenerated() {
    final remoteUrl = _normalize(widget.coverUrl);
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      final effectiveBorderRadius = widget.clipBorderRadius != null
          ? studioBorderRadiusOf(context, widget.clipBorderRadius!)
          : BorderRadius.circular(studioRadiusOf(context, widget.borderRadius));
      return ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: Image.network(
          remoteUrl,
          fit: BoxFit.cover,
          width: widget.size,
          height: widget.size,
          cacheWidth: _cacheExtentFor(context),
          cacheHeight: _cacheExtentFor(context),
          errorBuilder: (context, error, stackTrace) => _generated(),
        ),
      );
    }
    return _generated();
  }

  Widget _generated() {
    return GeneratedCoverArt(
      title: widget.title,
      subtitle: widget.subtitle,
      size: widget.size,
      borderRadius: widget.borderRadius,
      clipBorderRadius: widget.clipBorderRadius,
      showFrame: widget.showFrame,
    );
  }

  int _cacheExtentFor(BuildContext context) {
    final logicalSize = widget.size.isFinite && widget.size > 0
        ? widget.size
        : 120.0;
    final physicalSize = (logicalSize * MediaQuery.devicePixelRatioOf(context))
        .ceil();
    return physicalSize.clamp(1, 1024).toInt();
  }
}
