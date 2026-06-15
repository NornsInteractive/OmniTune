import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/cover_art_cache_manager.dart';
import '../../sources/application/source_session_manager.dart';
import '../../sources/application/sources_controller.dart';

class FolderArtworkData {
  const FolderArtworkData({required this.localPath});

  final String localPath;
}

class FolderArtworkRequest {
  const FolderArtworkRequest({
    required this.sourceId,
    required this.directoryPath,
  });

  final String sourceId;
  final String directoryPath;

  @override
  bool operator ==(Object other) {
    return other is FolderArtworkRequest &&
        other.sourceId == sourceId &&
        other.directoryPath == directoryPath;
  }

  @override
  int get hashCode => Object.hash(sourceId, directoryPath);
}

final folderArtworkProvider =
    FutureProvider.family<FolderArtworkData?, FolderArtworkRequest>(
      (ref, request) async => resolveFolderArtwork(ref, request),
    );

Future<FolderArtworkData?> resolveFolderArtwork(
  Ref ref,
  FolderArtworkRequest request,
) async {
  final sources = await ref.read(sourcesControllerProvider.future);
  if (sources.isEmpty) {
    return null;
  }

  final source = sources.firstWhere(
    (item) => item.id == request.sourceId,
    orElse: () => sources.first,
  );
  if (source.id != request.sourceId) {
    return null;
  }

  final sessionManager = ref.read(musicSourceSessionManagerProvider);
  final musicSource = await sessionManager.get(source);
  final listing = await musicSource.listFiles(request.directoryPath);
  final imageFiles = listing.entries
      .where((entry) {
        if (entry.isDirectory) {
          return false;
        }
        final ext = p.extension(entry.name).toLowerCase();
        return ext == '.jpg' ||
            ext == '.jpeg' ||
            ext == '.png' ||
            ext == '.webp';
      })
      .toList(growable: false);
  if (imageFiles.isEmpty) {
    return null;
  }

  const preferredNames = ['cover', 'folder', 'front', 'album', 'artwork'];

  imageFiles.sort((left, right) {
    final leftName = p.basenameWithoutExtension(left.name).toLowerCase();
    final rightName = p.basenameWithoutExtension(right.name).toLowerCase();
    final leftPreferred = preferredNames.indexOf(leftName);
    final rightPreferred = preferredNames.indexOf(rightName);
    final leftOrder = leftPreferred == -1 ? 999 : leftPreferred;
    final rightOrder = rightPreferred == -1 ? 999 : rightPreferred;
    if (leftOrder != rightOrder) {
      return leftOrder.compareTo(rightOrder);
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });

  for (final file in imageFiles) {
    final extension = p.extension(file.name).toLowerCase();
    final cacheKey = 'folder-artwork:${request.sourceId}:${file.path}';
    final cacheManager = CoverArtCacheManager();
    final cachedPath = await cacheManager.cachedPathForKey(
      cacheKey,
      extension: extension,
    );
    if (cachedPath?.isNotEmpty == true) {
      return FolderArtworkData(localPath: cachedPath!);
    }

    final bytes = await musicSource.readBinaryFile(file.path);
    if (bytes != null && bytes.isNotEmpty) {
      final localPath = await cacheManager.cacheBytes(
        cacheKey,
        bytes,
        extension: extension,
      );
      if (localPath?.isNotEmpty == true) {
        return FolderArtworkData(localPath: localPath!);
      }
    }
  }

  return null;
}
