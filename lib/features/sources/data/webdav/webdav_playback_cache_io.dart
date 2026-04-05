import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/models/playback_cache_settings.dart';
import '../../../../core/models/remote_entry.dart';
import 'webdav_playback_cache_base.dart';
import 'webdav_remote_client.dart';

class _IoWebDavPlaybackCache implements WebDavPlaybackCache {
  _IoWebDavPlaybackCache({required PlaybackCacheSettings initialSettings})
    : _settings = initialSettings.normalized;

  static const _cacheDirectoryName = 'flux_music_player/webdav_cache';

  final LinkedHashMap<String, _TrackCacheState> _trackCache =
      LinkedHashMap<String, _TrackCacheState>();
  final Map<String, int> _activeCaptureCounts = <String, int>{};
  final StreamController<PlaybackCacheSnapshot> _snapshotController =
      StreamController<PlaybackCacheSnapshot>.broadcast();
  final StreamController<List<PlaybackCacheInventoryItem>>
  _inventoryController =
      StreamController<List<PlaybackCacheInventoryItem>>.broadcast();
  final Map<String, _PersistedTrackCacheState> _persistedTrackCache =
      <String, _PersistedTrackCacheState>{};
  PlaybackCacheSettings _settings;
  bool _persistedTrackCacheLoaded = false;

  @override
  void applySettings(PlaybackCacheSettings settings) {
    final previousSettings = _settings;
    _settings = settings.normalized;
    if (!previousSettings.enablePersistentCache &&
        _settings.enablePersistentCache) {
      unawaited(_persistCompletedTracksToDisk());
    }
    _trimMemoryCache();
  }

  @override
  Stream<PlaybackCacheSnapshot> get snapshotStream =>
      _snapshotController.stream;

  @override
  PlaybackCacheSnapshot? snapshotForTrack(String trackId) {
    final state = _trackCache[trackId];
    if (state == null) {
      return null;
    }

    return PlaybackCacheSnapshot(
      trackId: trackId,
      totalLength: state.totalLength,
      segments: state.visualSegments,
    );
  }

  @override
  Stream<List<PlaybackCacheInventoryItem>> watchCachedTracks() async* {
    await _ensurePersistedTrackCacheLoaded();
    yield _buildInventory();
    yield* _inventoryController.stream;
  }

  @override
  Future<List<PlaybackCacheInventoryItem>> listCachedTracks() async {
    await _ensurePersistedTrackCacheLoaded();
    return _buildInventory();
  }

  @override
  Future<AudioSource?> createCachedAudioSource({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  }) async {
    await _ensurePersistedTrackCacheLoaded();

    if (_settings.enablePersistentCache) {
      final targetFile = await _targetFileFor(entry);
      if (await targetFile.exists()) {
        final cachedLength = await targetFile.length();
        if (entry.size == null || cachedLength == entry.size) {
          final state = _touchOrCreateTrackState(entry.uniqueId);
          state.totalLength = cachedLength;
          state.hasPersistedCopy = true;
          state.updatedAt = DateTime.now();
          _persistedTrackCache[entry.uniqueId] = _PersistedTrackCacheState(
            bytes: cachedLength,
            updatedAt: state.updatedAt,
          );
          _emitSnapshot(entry.uniqueId);
          _emitInventory();
          await _validateFile(
            targetFile,
            extension: _normalizedExtension(entry.name),
          );
          return AudioSource.uri(Uri.file(targetFile.path));
        }
        await targetFile.delete();
        _persistedTrackCache.remove(entry.uniqueId);
        _emitInventory();
      }
    }

    final existingState = _touchTrackState(entry.uniqueId);
    final completeBytes = existingState?.completeBytes;
    if (completeBytes == null) {
      return null;
    }

    if (_settings.enablePersistentCache) {
      try {
        final persistedFile = await _persistCompleteBytesToDisk(
          entry: entry,
          completeBytes: completeBytes,
          updatedAt: DateTime.now(),
        );
        return AudioSource.uri(Uri.file(persistedFile.path));
      } catch (_) {
        existingState?.updatedAt = DateTime.now();
        _emitInventory();
      }
    } else {
      existingState?.updatedAt = DateTime.now();
      _emitInventory();
    }
    return _InMemoryAudioSource(
      bytes: completeBytes,
      contentType: _contentTypeFor(entry),
    );
  }

  @override
  Future<WebDavCachedRange?> readCachedRange({
    required RemoteEntry entry,
    required int start,
    int? end,
  }) async {
    final state = _touchTrackState(entry.uniqueId);
    if (state == null) {
      return null;
    }

    final bytes = state.readContiguousBytes(start, end: end);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    return WebDavCachedRange(
      start: start,
      endExclusive: start + bytes.length,
      bytes: bytes,
    );
  }

  @override
  Stream<List<int>> wrapPlaybackStream({
    required RemoteEntry entry,
    required Stream<List<int>> stream,
    required int offset,
    required int? requestedEnd,
    required int? expectedLength,
  }) async* {
    _activeCaptureCounts.update(
      entry.uniqueId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    var currentOffset = offset;

    try {
      await for (final chunk in stream) {
        if (chunk.isNotEmpty) {
          _storeChunk(
            entry: entry,
            offset: currentOffset,
            bytes: Uint8List.fromList(chunk),
            expectedLength: expectedLength,
          );
          currentOffset += chunk.length;
        }
        yield chunk;
      }

      await _persistIfComplete(entry);
    } finally {
      final nextCount = (_activeCaptureCounts[entry.uniqueId] ?? 1) - 1;
      if (nextCount <= 0) {
        _activeCaptureCounts.remove(entry.uniqueId);
      } else {
        _activeCaptureCounts[entry.uniqueId] = nextCount;
      }
      _trimMemoryCache();
    }
  }

  @override
  Future<void> clearAllCachedData() async {
    final trackIds = _trackCache.keys.toList(growable: false);
    _trackCache.clear();
    _activeCaptureCounts.clear();
    _persistedTrackCache.clear();

    for (final trackId in trackIds) {
      if (!_snapshotController.isClosed) {
        _snapshotController.add(
          PlaybackCacheSnapshot(
            trackId: trackId,
            totalLength: null,
            segments: const [],
          ),
        );
      }
    }

    final directory = Directory(
      '${Directory.systemTemp.path}/$_cacheDirectoryName',
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    _emitInventory();
  }

  @override
  Future<void> removeCachedTracks(Set<String> trackIds) async {
    if (trackIds.isEmpty) {
      return;
    }

    await _ensurePersistedTrackCacheLoaded();
    final directory = await _cacheDirectory();

    for (final trackId in trackIds) {
      _trackCache.remove(trackId);
      _activeCaptureCounts.remove(trackId);
      _persistedTrackCache.remove(trackId);
      await _deletePersistedTrackFiles(directory, trackId);
      if (!_snapshotController.isClosed) {
        _snapshotController.add(
          PlaybackCacheSnapshot(
            trackId: trackId,
            totalLength: null,
            segments: const [],
          ),
        );
      }
    }

    _emitInventory();
  }

  @override
  Future<void> dispose() async {
    _trackCache.clear();
    _activeCaptureCounts.clear();
    _persistedTrackCache.clear();
    await _snapshotController.close();
    await _inventoryController.close();
  }

  void _storeChunk({
    required RemoteEntry entry,
    required int offset,
    required Uint8List bytes,
    required int? expectedLength,
  }) {
    final state = _touchOrCreateTrackState(entry.uniqueId);
    state.totalLength = expectedLength ?? state.totalLength ?? entry.size;
    state.updatedAt = DateTime.now();
    state.insertChunk(offset, bytes);
    _emitSnapshot(entry.uniqueId);
    _emitInventory();
    _trimMemoryCache();
  }

  Future<void> _persistIfComplete(RemoteEntry entry) async {
    if (!_settings.enablePersistentCache) {
      return;
    }

    final state = _touchTrackState(entry.uniqueId);
    final completeBytes = state?.completeBytes;
    if (completeBytes == null) {
      return;
    }

    await _persistCompleteBytesToDisk(
      entry: entry,
      completeBytes: completeBytes,
      updatedAt: DateTime.now(),
    );
  }

  _TrackCacheState? _touchTrackState(String trackId) {
    final state = _trackCache.remove(trackId);
    if (state == null) {
      return null;
    }
    _trackCache[trackId] = state;
    return state;
  }

  _TrackCacheState _touchOrCreateTrackState(String trackId) {
    return _touchTrackState(trackId) ??
        (_trackCache[trackId] = _TrackCacheState());
  }

  void _trimMemoryCache() {
    while (_memoryResidentTrackCount() > _settings.memoryCacheTrackLimit) {
      final removableEntry = _firstRemovableMemoryEntry();
      if (removableEntry == null) {
        break;
      }

      final trackId = removableEntry.key;
      final state = removableEntry.value;
      if (state.hasPersistedCopy) {
        state.clearInMemoryBytes();
        _emitSnapshot(trackId);
      } else {
        _trackCache.remove(trackId);
        if (!_snapshotController.isClosed) {
          _snapshotController.add(
            PlaybackCacheSnapshot(
              trackId: trackId,
              totalLength: state.totalLength,
              segments: const [],
            ),
          );
        }
      }
      _emitInventory();
    }
  }

  void _emitSnapshot(String trackId) {
    final snapshot = snapshotForTrack(trackId);
    if (snapshot != null && !_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
    }
  }

  void _emitInventory() {
    if (!_inventoryController.isClosed) {
      _inventoryController.add(_buildInventory());
    }
  }

  Future<Directory> _cacheDirectory() async {
    final directory = Directory(
      '${Directory.systemTemp.path}/$_cacheDirectoryName',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> _targetFileFor(RemoteEntry entry) async {
    final directory = await _cacheDirectory();
    return File(
      '${directory.path}/${_cacheKeyFor(entry)}${_normalizedExtension(entry.name)}',
    );
  }

  Future<void> _ensurePersistedTrackCacheLoaded() async {
    if (_persistedTrackCacheLoaded) {
      return;
    }

    final directory = Directory(
      '${Directory.systemTemp.path}/$_cacheDirectoryName',
    );
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is! File) {
          continue;
        }

        final fileName = p.basename(entity.path);
        if (fileName.endsWith('.part')) {
          continue;
        }

        final trackId = _trackIdForCacheFile(entity.path);
        if (trackId == null) {
          continue;
        }

        final stat = await entity.stat();
        _persistedTrackCache[trackId] = _PersistedTrackCacheState(
          bytes: stat.size,
          updatedAt: stat.modified,
        );
        final state = _trackCache[trackId];
        if (state != null) {
          state.hasPersistedCopy = true;
          state.totalLength ??= stat.size;
          state.updatedAt = stat.modified;
        }
      }
    }

    _persistedTrackCacheLoaded = true;
  }

  List<PlaybackCacheInventoryItem> _buildInventory() {
    final items = <String, PlaybackCacheInventoryItem>{};

    for (final entry in _persistedTrackCache.entries) {
      items[entry.key] = _inventoryItemFor(
        trackId: entry.key,
        cachedBytes: entry.value.bytes,
        totalBytes: entry.value.bytes,
        hasPersistentCopy: true,
        hasMemoryData: false,
        updatedAt: entry.value.updatedAt,
      );
    }

    for (final entry in _trackCache.entries) {
      final current = items[entry.key];
      final state = entry.value;
      final cachedBytes = current == null
          ? state.cachedByteCount
          : (current.cachedBytes > state.cachedByteCount
                ? current.cachedBytes
                : state.cachedByteCount);
      final totalBytes = current?.totalBytes ?? state.totalLength;
      final updatedAt = current == null
          ? state.updatedAt
          : (current.updatedAt.isAfter(state.updatedAt)
                ? current.updatedAt
                : state.updatedAt);

      items[entry.key] = _inventoryItemFor(
        trackId: entry.key,
        cachedBytes: cachedBytes,
        totalBytes: totalBytes,
        hasPersistentCopy: current?.hasPersistentCopy ?? state.hasPersistedCopy,
        hasMemoryData: state.hasInMemoryBytes,
        updatedAt: updatedAt,
      );
    }

    final result = items.values.toList(growable: false)
      ..sort((left, right) {
        final updatedComparison = right.updatedAt.compareTo(left.updatedAt);
        if (updatedComparison != 0) {
          return updatedComparison;
        }
        return left.title.toLowerCase().compareTo(right.title.toLowerCase());
      });
    return result;
  }

  PlaybackCacheInventoryItem _inventoryItemFor({
    required String trackId,
    required int cachedBytes,
    required int? totalBytes,
    required bool hasPersistentCopy,
    required bool hasMemoryData,
    required DateTime updatedAt,
  }) {
    final parts = _parseTrackId(trackId);
    return PlaybackCacheInventoryItem(
      trackId: trackId,
      sourceId: parts.sourceId,
      title: p.basenameWithoutExtension(parts.remotePath),
      fileName: p.basename(parts.remotePath),
      remotePath: parts.remotePath,
      cachedBytes: cachedBytes,
      totalBytes: totalBytes,
      hasPersistentCopy: hasPersistentCopy,
      hasMemoryData: hasMemoryData,
      updatedAt: updatedAt,
    );
  }

  _TrackIdentity _parseTrackId(String trackId) {
    final delimiterIndex = trackId.indexOf('::');
    if (delimiterIndex == -1) {
      return _TrackIdentity(sourceId: '', remotePath: trackId);
    }

    return _TrackIdentity(
      sourceId: trackId.substring(0, delimiterIndex),
      remotePath: trackId.substring(delimiterIndex + 2),
    );
  }

  int _memoryResidentTrackCount() {
    var count = 0;
    for (final state in _trackCache.values) {
      if (state.hasInMemoryBytes) {
        count++;
      }
    }
    return count;
  }

  MapEntry<String, _TrackCacheState>? _firstRemovableMemoryEntry() {
    MapEntry<String, _TrackCacheState>? activeFallback;
    for (final entry in _trackCache.entries) {
      if (!entry.value.hasInMemoryBytes) {
        continue;
      }
      if (_activeCaptureCounts.containsKey(entry.key)) {
        activeFallback ??= entry;
        continue;
      }
      return entry;
    }
    return activeFallback;
  }

  Future<void> _deletePersistedTrackFiles(
    Directory directory,
    String trackId,
  ) async {
    if (!await directory.exists()) {
      return;
    }

    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      if (_trackIdForCacheFile(entity.path) != trackId) {
        continue;
      }
      await entity.delete();
    }
  }

  Future<void> _persistCompletedTracksToDisk() async {
    await _ensurePersistedTrackCacheLoaded();

    for (final entry in _trackCache.entries.toList(growable: false)) {
      final completeBytes = entry.value.completeBytes;
      if (completeBytes == null) {
        continue;
      }

      final identity = _parseTrackId(entry.key);
      final remoteEntry = RemoteEntry(
        sourceId: identity.sourceId,
        name: p.basename(identity.remotePath),
        path: identity.remotePath,
        kind: RemoteEntryKind.audio,
        size: completeBytes.length,
      );

      try {
        await _persistCompleteBytesToDisk(
          entry: remoteEntry,
          completeBytes: completeBytes,
          updatedAt: entry.value.updatedAt,
        );
      } catch (_) {
        // Keep playback working from memory even if local persistence fails.
      }
    }
  }

  Future<File> _persistCompleteBytesToDisk({
    required RemoteEntry entry,
    required Uint8List completeBytes,
    required DateTime updatedAt,
  }) async {
    final targetFile = await _targetFileFor(entry);
    if (await targetFile.exists()) {
      final currentLength = await targetFile.length();
      if (currentLength == completeBytes.length) {
        final persistedState = _touchOrCreateTrackState(entry.uniqueId);
        persistedState.hasPersistedCopy = true;
        persistedState.totalLength ??= completeBytes.length;
        persistedState.updatedAt = updatedAt;
        _persistedTrackCache[entry.uniqueId] = _PersistedTrackCacheState(
          bytes: completeBytes.length,
          updatedAt: updatedAt,
        );
        _emitSnapshot(entry.uniqueId);
        _emitInventory();
        return targetFile;
      }
      await targetFile.delete();
    }

    final tempFile = File('${targetFile.path}.part');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    await tempFile.writeAsBytes(completeBytes, flush: true);
    await _validateFile(tempFile, extension: _normalizedExtension(entry.name));
    await tempFile.rename(targetFile.path);

    final persistedState = _touchOrCreateTrackState(entry.uniqueId);
    persistedState.hasPersistedCopy = true;
    persistedState.totalLength ??= completeBytes.length;
    persistedState.updatedAt = updatedAt;
    _persistedTrackCache[entry.uniqueId] = _PersistedTrackCacheState(
      bytes: completeBytes.length,
      updatedAt: updatedAt,
    );
    _emitSnapshot(entry.uniqueId);
    _emitInventory();
    return targetFile;
  }

  String? _trackIdForCacheFile(String path) {
    final cacheKey = p.basenameWithoutExtension(path);
    if (cacheKey.isEmpty) {
      return null;
    }

    final paddingLength = (4 - cacheKey.length % 4) % 4;
    final padded = '$cacheKey${'=' * paddingLength}';
    try {
      return utf8.decode(base64Url.decode(padded));
    } on FormatException {
      return null;
    }
  }

  String _cacheKeyFor(RemoteEntry entry) {
    return base64Url.encode(utf8.encode(entry.uniqueId)).replaceAll('=', '');
  }

  String _normalizedExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return fileName.substring(dotIndex).toLowerCase();
  }

  String _contentTypeFor(RemoteEntry entry) {
    final mimeType = entry.mimeType?.trim();
    if (mimeType != null && mimeType.isNotEmpty) {
      return mimeType;
    }

    return switch (_normalizedExtension(entry.name)) {
      '.flac' => 'audio/flac',
      '.mp3' => 'audio/mpeg',
      '.m4a' || '.alac' => 'audio/mp4',
      '.wav' => 'audio/wav',
      '.aif' || '.aiff' => 'audio/aiff',
      '.ogg' || '.oga' => 'audio/ogg',
      '.opus' => 'audio/opus',
      '.ape' => 'audio/ape',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _validateFile(File file, {required String extension}) async {
    if (extension != '.flac') {
      return;
    }

    final header = await file
        .openRead(0, 4)
        .fold<List<int>>(<int>[], (all, chunk) => [...all, ...chunk]);
    await _validateBytes(Uint8List.fromList(header), extension: extension);
  }

  Future<void> _validateBytes(
    Uint8List bytes, {
    required String extension,
  }) async {
    if (extension != '.flac') {
      return;
    }
    if (bytes.length < 4) {
      throw StateError(
        'Expected FLAC data from WebDAV, but the file was incomplete.',
      );
    }

    final signature = ascii.decode(bytes.sublist(0, 4), allowInvalid: true);
    if (signature != 'fLaC') {
      throw StateError(
        'Expected FLAC data from WebDAV, but received "$signature" instead.',
      );
    }
  }
}

class _TrackCacheState {
  int? totalLength;
  bool hasPersistedCopy = false;
  DateTime updatedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_ByteSegment> _segments = <_ByteSegment>[];

  void insertChunk(int start, Uint8List bytes) {
    if (bytes.isEmpty) {
      return;
    }

    var mergedStart = start;
    var mergedEnd = start + bytes.length;
    final overlapping = <_ByteSegment>[];

    for (final segment in _segments) {
      if (segment.endExclusive < mergedStart || segment.start > mergedEnd) {
        continue;
      }
      overlapping.add(segment);
      if (segment.start < mergedStart) {
        mergedStart = segment.start;
      }
      if (segment.endExclusive > mergedEnd) {
        mergedEnd = segment.endExclusive;
      }
    }

    final mergedBytes = Uint8List(mergedEnd - mergedStart);
    for (final segment in overlapping) {
      mergedBytes.setRange(
        segment.start - mergedStart,
        segment.endExclusive - mergedStart,
        segment.bytes,
      );
      _segments.remove(segment);
    }
    mergedBytes.setRange(
      start - mergedStart,
      start - mergedStart + bytes.length,
      bytes,
    );
    _segments.add(_ByteSegment(start: mergedStart, bytes: mergedBytes));
    _segments.sort((left, right) => left.start.compareTo(right.start));
  }

  Uint8List? readContiguousBytes(int start, {int? end}) {
    final segment = _segments
        .where(
          (candidate) =>
              candidate.start <= start && candidate.endExclusive > start,
        )
        .firstOrNull;
    if (segment == null) {
      return null;
    }

    final endExclusive = end == null || end > segment.endExclusive
        ? segment.endExclusive
        : end;
    if (endExclusive <= start) {
      return null;
    }

    return Uint8List.fromList(
      segment.bytes.sublist(
        start - segment.start,
        endExclusive - segment.start,
      ),
    );
  }

  Uint8List? get completeBytes {
    final expectedLength = totalLength;
    if (expectedLength == null || _segments.length != 1) {
      return null;
    }

    final segment = _segments.single;
    if (segment.start != 0 || segment.endExclusive < expectedLength) {
      return null;
    }

    return Uint8List.fromList(segment.bytes.sublist(0, expectedLength));
  }

  int get cachedByteCount {
    var total = 0;
    for (final segment in _segments) {
      total += segment.bytes.length;
    }
    return total;
  }

  bool get hasInMemoryBytes => _segments.isNotEmpty;

  void clearInMemoryBytes() {
    _segments.clear();
  }

  List<PlaybackCacheSegment> get visualSegments {
    if (hasPersistedCopy && totalLength != null) {
      return [PlaybackCacheSegment(start: 0, endExclusive: totalLength!)];
    }

    return _segments
        .map(
          (segment) => PlaybackCacheSegment(
            start: segment.start,
            endExclusive: segment.endExclusive,
          ),
        )
        .toList(growable: false);
  }
}

class _PersistedTrackCacheState {
  const _PersistedTrackCacheState({
    required this.bytes,
    required this.updatedAt,
  });

  final int bytes;
  final DateTime updatedAt;
}

class _TrackIdentity {
  const _TrackIdentity({required this.sourceId, required this.remotePath});

  final String sourceId;
  final String remotePath;
}

class _ByteSegment {
  const _ByteSegment({required this.start, required this.bytes});

  final int start;
  final Uint8List bytes;

  int get endExclusive => start + bytes.length;
}

class _InMemoryAudioSource extends StreamAudioSource {
  _InMemoryAudioSource({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final normalizedStart = start ?? 0;
    final normalizedEnd = end == null || end > bytes.length
        ? bytes.length
        : end;
    final slice = bytes.sublist(normalizedStart, normalizedEnd);

    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: slice.length,
      offset: normalizedStart,
      stream: Stream<List<int>>.value(slice),
      contentType: contentType,
    );
  }
}

WebDavPlaybackCache createWebDavPlaybackCache({
  required PlaybackCacheSettings initialSettings,
}) => _IoWebDavPlaybackCache(initialSettings: initialSettings);
