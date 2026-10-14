import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../storage/cover_art_cache_manager.dart';

/// Only local cached artwork is exposed to native media sessions. Signed source
/// URLs and their credentials must not become system metadata.
Future<Uri?> resolveSystemArtwork({
  String? localPath,
  String? remoteUrl,
}) async {
  final cache = CoverArtCacheManager();
  if (kIsWeb) {
    final uri = Uri.tryParse(remoteUrl?.trim() ?? '');
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery) {
      return uri;
    }
    return Uri.base.resolve('assets/assets/images/default_cover.png');
  }
  if (localPath?.trim().isNotEmpty == true &&
      await cache.isUsableLocalPath(localPath!)) {
    return Uri.file(localPath);
  }
  final remote = Uri.tryParse(remoteUrl?.trim() ?? '');
  if (remote != null && (remote.scheme == 'https' || remote.scheme == 'http')) {
    final downloaded = await cache.downloadAndCache(remote.toString());
    if (downloaded != null && await cache.isUsableLocalPath(downloaded)) {
      return Uri.file(downloaded);
    }
  }
  return null;
}

Future<Uri?> defaultSystemArtwork() async {
  if (kIsWeb) return Uri.base.resolve('assets/assets/images/default_cover.png');
  try {
    final bytes = await rootBundle.load('assets/images/default_cover.png');
    final path = await CoverArtCacheManager().cacheBytes(
      'system-default-cover-v1',
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      extension: '.png',
    );
    return path == null ? null : Uri.file(path);
  } catch (_) {
    return null;
  }
}
