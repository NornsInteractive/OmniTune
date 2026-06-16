import 'dart:async';
import 'dart:collection';

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

final folderArtworkProvider = FutureProvider.autoDispose
    .family<FolderArtworkData?, FolderArtworkRequest>(
      (ref, request) async => resolveFolderArtwork(ref, request),
    );

const _folderArtworkNegativeCacheDuration = Duration(minutes: 10);

final _folderArtworkQueue = _FolderArtworkQueue(maxConcurrent: 2);
final _folderArtworkCache = <FolderArtworkRequest, _FolderArtworkCacheEntry>{};
final _folderArtworkInFlight =
    <FolderArtworkRequest, Future<FolderArtworkData?>>{};

Future<FolderArtworkData?> resolveFolderArtwork(
  Ref ref,
  FolderArtworkRequest request,
) async {
  final cached = _folderArtworkCache[request];
  if (cached != null && !cached.isExpired) {
    return cached.data;
  }

  final inFlight = _folderArtworkInFlight[request];
  if (inFlight != null) {
    return inFlight;
  }

  final future = _folderArtworkQueue.run(
    () => _resolveFolderArtworkUncached(ref, request),
  );
  _folderArtworkInFlight[request] = future;
  try {
    final data = await future;
    _folderArtworkCache[request] = _FolderArtworkCacheEntry(data);
    return data;
  } finally {
    _folderArtworkInFlight.remove(request);
  }
}

Future<FolderArtworkData?> _resolveFolderArtworkUncached(
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

  final cacheManager = CoverArtCacheManager();
  for (final file in imageFiles) {
    final extension = p.extension(file.name).toLowerCase();
    final cacheKey = 'folder-artwork:${request.sourceId}:${file.path}';
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

class _FolderArtworkCacheEntry {
  _FolderArtworkCacheEntry(this.data) : cachedAt = DateTime.now();

  final FolderArtworkData? data;
  final DateTime cachedAt;

  bool get isExpired =>
      data == null &&
      DateTime.now().difference(cachedAt) > _folderArtworkNegativeCacheDuration;
}

class _FolderArtworkQueue {
  _FolderArtworkQueue({required this.maxConcurrent});

  final int maxConcurrent;
  int _running = 0;
  final Queue<void Function()> _pending = Queue<void Function()>();

  Future<T> run<T>(Future<T> Function() task) {
    final completer = Completer<T>();

    void start() {
      _running += 1;
      Future<T>(task)
          .then(completer.complete, onError: completer.completeError)
          .whenComplete(() {
            _running -= 1;
            if (_pending.isNotEmpty) {
              scheduleMicrotask(_pending.removeFirst());
            }
          });
    }

    if (_running < maxConcurrent) {
      start();
    } else {
      _pending.addLast(start);
    }

    return completer.future;
  }
}
