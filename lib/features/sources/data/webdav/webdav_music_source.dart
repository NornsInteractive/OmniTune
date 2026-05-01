import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';
import 'webdav_playback_cache_base.dart';
import 'webdav_remote_client.dart';

typedef WebDavRemoteClientFactory =
    WebDavRemoteClient Function(SourceProfile profile);
typedef WebDavPlaybackCacheFactory = WebDavPlaybackCache Function();

class WebDavMusicSource implements MusicSource {
  WebDavMusicSource(
    this.profile, {
    WebDavRemoteClientFactory clientFactory = PackageWebDavRemoteClient.new,
    required WebDavPlaybackCacheFactory playbackCacheFactory,
  }) : _client = clientFactory(profile),
       _playbackCache = playbackCacheFactory();

  static const _audioExtensions = {
    '.aac',
    '.aif',
    '.aiff',
    '.alac',
    '.ape',
    '.dsf',
    '.dff',
    '.flac',
    '.m4a',
    '.mp3',
    '.ogg',
    '.oga',
    '.opus',
    '.wav',
    '.wma',
    '.wv',
  };

  @override
  final SourceProfile profile;

  final WebDavRemoteClient _client;
  final WebDavPlaybackCache _playbackCache;
  final Map<String, String?> _textFileCache = <String, String?>{};
  bool _connected = false;

  @override
  Future<void> connect() async {
    if (_connected) {
      return;
    }
    await _client.ping();
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _client.dispose();
  }

  @override
  Future<DirectoryListing> listFiles(String path) async {
    await connect();

    final files = await _client.readDirectory(path);
    final entries = files
        .map(
          (file) => RemoteEntry(
            sourceId: profile.id,
            name: file.name,
            path: file.path,
            kind: _resolveKind(
              isDirectory: file.isDirectory,
              mimeType: file.mimeType,
              fileName: file.name,
            ),
            mimeType: file.mimeType,
            size: file.size,
            modifiedAt: file.modifiedAt,
          ),
        )
        .toList();

    entries.sort((left, right) {
      final kindComparison = left.kind.index.compareTo(right.kind.index);
      if (kindComparison != 0) {
        return kindComparison;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    return DirectoryListing(
      entries: entries,
      diagnostics: _buildDiagnostics(path, entries.length),
    );
  }

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) async {
    entry.ensurePlayable();

    final folderSegments = p.posix
        .dirname(entry.path)
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    // 快速检查缓存（不等待完整的磁盘验证）
    // 超时时间为 1 秒，避免阻塞
    final cachedAudioSourceFuture = _playbackCache
        .createCachedAudioSource(entry: entry, client: _client)
        .timeout(const Duration(seconds: 1), onTimeout: () => null);

    final cachedAudioSource = await cachedAudioSourceFuture;

    if (cachedAudioSource != null) {
      return PlayableTrack(
        id: entry.uniqueId,
        sourceId: profile.id,
        title: entry.title,
        sourceName: profile.name,
        remotePath: entry.path,
        audioSource: cachedAudioSource,
        sourceSizeBytes: entry.size,
        albumTitle: folderSegments.isEmpty ? profile.name : folderSegments.last,
        artistName: folderSegments.length >= 2
            ? folderSegments[folderSegments.length - 2]
            : profile.name,
      );
    }

    // 如果没有缓存，立即返回流源
    // 在后台异步连接（不阻塞返回）
    if (!_connected) {
      unawaited(connect());
    }

    return PlayableTrack(
      id: entry.uniqueId,
      sourceId: profile.id,
      title: entry.title,
      sourceName: profile.name,
      remotePath: entry.path,
      audioSource: _WebDavStreamAudioSource(
        client: _client,
        entry: entry,
        playbackCache: _playbackCache,
      ),
      sourceSizeBytes: entry.size,
      albumTitle: folderSegments.isEmpty ? profile.name : folderSegments.last,
      artistName: folderSegments.length >= 2
          ? folderSegments[folderSegments.length - 2]
          : profile.name,
    );
  }

  @override
  Future<String?> readTextFile(String path) async {
    if (_textFileCache.containsKey(path)) {
      return _textFileCache[path];
    }

    await connect();
    final content = await _client.readText(path);
    _textFileCache[path] = content;
    return content;
  }

  @override
  Future<Uint8List?> readBinaryFile(String path) async {
    try {
      await connect();
      final result = await _client.openRead(path);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in result.stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (_) {
      return null;
    }
  }

  RemoteEntryKind _resolveKind({
    required bool isDirectory,
    required String? mimeType,
    required String fileName,
  }) {
    if (isDirectory) {
      return RemoteEntryKind.directory;
    }

    if ((mimeType ?? '').startsWith('audio/')) {
      return RemoteEntryKind.audio;
    }

    final normalized = fileName.toLowerCase();
    final isAudio = _audioExtensions.any(normalized.endsWith);
    return isAudio ? RemoteEntryKind.audio : RemoteEntryKind.file;
  }

  DirectoryDiagnostics _buildDiagnostics(String path, int entryCount) {
    final debug = _client.lastDirectoryDebugInfo;
    return DirectoryDiagnostics(
      protocolLabel: profile.protocol.label,
      requestedPath: path,
      attemptedPaths:
          debug?.attempts.map((attempt) => attempt.path).toList() ?? [path],
      entryCount: entryCount,
      details: debug?.describe() ?? const [],
    );
  }
}

class _WebDavStreamAudioSource extends StreamAudioSource {
  _WebDavStreamAudioSource({
    required this.client,
    required this.entry,
    required this.playbackCache,
  });

  final WebDavRemoteClient client;
  final RemoteEntry entry;
  final WebDavPlaybackCache playbackCache;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final requestedStart = start ?? 0;
    final cachedRange = await playbackCache.readCachedRange(
      entry: entry,
      start: requestedStart,
      end: end,
    );

    if (cachedRange != null) {
      final cachedSourceLength = entry.size;
      final cachedContentLength = cachedRange.bytes.length;
      final cacheSatisfiesRequest = end != null
          ? cachedRange.endExclusive >= end
          : (cachedSourceLength != null &&
                cachedRange.endExclusive >= cachedSourceLength);

      if (cacheSatisfiesRequest) {
        return StreamAudioResponse(
          sourceLength: cachedSourceLength,
          contentLength: cachedContentLength,
          offset: requestedStart,
          stream: Stream<List<int>>.value(cachedRange.bytes),
          contentType: _resolvePlaybackContentType(
            '',
            fallbackMimeType: entry.mimeType,
            fileName: entry.name,
          ),
        );
      }

      final networkResult = await client.openRead(
        entry.path,
        start: cachedRange.endExclusive,
        end: end,
      );
      final sourceLength = networkResult.sourceLength ?? entry.size;
      final resolvedContentLength = _resolvedContentLength(
        requestedStart: requestedStart,
        requestedEnd: end,
        sourceLength: sourceLength,
        cachedBytesLength: cachedRange.bytes.length,
        networkContentLength: networkResult.contentLength,
      );

      return StreamAudioResponse(
        sourceLength: sourceLength,
        contentLength: resolvedContentLength,
        offset: requestedStart,
        stream: _concatStreams(
          Stream<List<int>>.value(cachedRange.bytes),
          playbackCache.wrapPlaybackStream(
            entry: entry,
            stream: networkResult.stream,
            offset: networkResult.offset,
            requestedEnd: end,
            expectedLength: sourceLength,
          ),
        ),
        contentType: _resolvePlaybackContentType(
          networkResult.contentType,
          fallbackMimeType: entry.mimeType,
          fileName: entry.name,
        ),
      );
    }

    final result = await client.openRead(entry.path, start: start, end: end);
    final sourceLength = result.sourceLength ?? entry.size;
    final resolvedContentLength = _resolvedContentLength(
      requestedStart: result.offset,
      requestedEnd: end,
      sourceLength: sourceLength,
      cachedBytesLength: 0,
      networkContentLength: result.contentLength,
    );

    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: resolvedContentLength,
      offset: result.offset,
      stream: playbackCache.wrapPlaybackStream(
        entry: entry,
        stream: result.stream,
        offset: result.offset,
        requestedEnd: end,
        expectedLength: sourceLength,
      ),
      contentType: _resolvePlaybackContentType(
        result.contentType,
        fallbackMimeType: entry.mimeType,
        fileName: entry.name,
      ),
    );
  }

  int _resolvedContentLength({
    required int requestedStart,
    required int? requestedEnd,
    required int? sourceLength,
    required int cachedBytesLength,
    required int networkContentLength,
  }) {
    if (requestedEnd != null) {
      return requestedEnd - requestedStart;
    }
    if (sourceLength != null) {
      return sourceLength - requestedStart;
    }
    if (cachedBytesLength > 0) {
      return cachedBytesLength + networkContentLength;
    }
    return networkContentLength;
  }

  String _resolvePlaybackContentType(
    String headerContentType, {
    required String? fallbackMimeType,
    required String fileName,
  }) {
    final normalizedHeader = headerContentType.trim().toLowerCase();
    if (_isSpecificAudioContentType(normalizedHeader)) {
      return _normalizeAudioContentType(normalizedHeader);
    }

    final normalizedFallback = (fallbackMimeType ?? '').trim().toLowerCase();
    if (_isSpecificAudioContentType(normalizedFallback)) {
      return _normalizeAudioContentType(normalizedFallback);
    }

    final extension = p.extension(fileName).toLowerCase();
    return switch (extension) {
      '.flac' => 'audio/flac',
      '.mp3' => 'audio/mpeg',
      '.m4a' => 'audio/mp4',
      '.aac' => 'audio/aac',
      '.wav' => 'audio/wav',
      '.aif' || '.aiff' => 'audio/aiff',
      '.ogg' || '.oga' => 'audio/ogg',
      '.opus' => 'audio/opus',
      '.wma' => 'audio/x-ms-wma',
      '.ape' => 'audio/ape',
      '.alac' => 'audio/mp4',
      '.wv' => 'audio/wavpack',
      _ =>
        normalizedFallback.isNotEmpty
            ? normalizedFallback
            : (normalizedHeader.isNotEmpty
                  ? normalizedHeader
                  : 'application/octet-stream'),
    };
  }

  bool _isSpecificAudioContentType(String value) {
    if (value.isEmpty) {
      return false;
    }
    if (value == 'application/octet-stream' || value == 'binary/octet-stream') {
      return false;
    }
    return value.startsWith('audio/') || value == 'application/flac';
  }

  String _normalizeAudioContentType(String value) {
    return switch (value) {
      'audio/x-flac' || 'application/flac' => 'audio/flac',
      'audio/x-wav' => 'audio/wav',
      _ => value,
    };
  }
}

Stream<List<int>> _concatStreams(
  Stream<List<int>> first,
  Stream<List<int>> second,
) async* {
  await for (final chunk in first) {
    yield chunk;
  }
  await for (final chunk in second) {
    yield chunk;
  }
}

class WebDavMusicSourceFactory implements MusicSourceFactory {
  const WebDavMusicSourceFactory({required this.playbackCacheFactory});

  final WebDavPlaybackCacheFactory playbackCacheFactory;

  @override
  SourceProtocol get protocol => SourceProtocol.webdav;

  @override
  MusicSource create(SourceProfile profile) {
    return WebDavMusicSource(
      profile,
      playbackCacheFactory: playbackCacheFactory,
    );
  }
}
