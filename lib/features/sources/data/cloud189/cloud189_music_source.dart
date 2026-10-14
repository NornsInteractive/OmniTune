import 'dart:async';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';
import 'cloud189_api_client.dart';
import '../webdav/webdav_playback_cache_base.dart';
import '../webdav/webdav_remote_client.dart';

typedef Cloud189RemoteClientFactory =
    Cloud189RemoteClient Function(SourceProfile profile);
typedef Cloud189PlaybackCacheFactory = WebDavPlaybackCache Function();

class Cloud189MusicSource implements MusicSource {
  Cloud189MusicSource(
    this.profile, {
    Cloud189RemoteClientFactory? clientFactory,
    required Cloud189PlaybackCacheFactory playbackCacheFactory,
    Cloud189CaptchaResolver? captchaResolver,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
  }) : _client =
           clientFactory?.call(profile) ??
           _defaultClientFactory(
             profile,
             captchaResolver: captchaResolver,
             qrCodeResolver: qrCodeResolver,
             smsVerificationResolver: smsVerificationResolver,
           ),
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

  final Cloud189RemoteClient _client;
  final WebDavPlaybackCache _playbackCache;
  final Map<String, String?> _textFileCache = <String, String?>{};
  bool _connected = false;

  String? get currentRefreshToken => _client.currentRefreshToken;

  @override
  Future<void> connect() async {
    if (_connected) {
      return;
    }
    await _client.connect();
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
            kind: file.isDirectory
                ? RemoteEntryKind.directory
                : _resolveFileKind(file.name, file.mimeType),
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
      diagnostics: DirectoryDiagnostics(
        protocolLabel: SourceProtocol.cloudDrive.label,
        requestedPath: path,
        attemptedPaths: [path],
        entryCount: entries.length,
      ),
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

    final cacheClient = _Cloud189PlaybackCacheClientAdapter(_client);
    final cachedAudioSourceFuture = _playbackCache
        .createCachedAudioSource(entry: entry, client: cacheClient)
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

    if (!_connected) {
      unawaited(connect());
    }
    unawaited(_playbackCache.prefetchEntry(entry: entry, client: cacheClient));
    return PlayableTrack(
      id: entry.uniqueId,
      sourceId: profile.id,
      title: entry.title,
      sourceName: profile.name,
      remotePath: entry.path,
      audioSource: _Cloud189CachedStreamAudioSource(
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

    try {
      await connect();
      final content = await _client.readText(path);
      _textFileCache[path] = content;
      return content;
    } catch (_) {
      _textFileCache[path] = null;
      return null;
    }
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

  @override
  Future<Uint8List?> readBinaryFileHead(
    String path, {
    int length = 128 * 1024,
  }) async {
    try {
      await connect();
      final result = await _client.openRead(path, start: 0, end: length);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in result.stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    } catch (_) {
      return null;
    }
  }

  RemoteEntryKind _resolveFileKind(String fileName, String? mimeType) {
    if ((mimeType ?? '').startsWith('audio/')) {
      return RemoteEntryKind.audio;
    }

    final normalized = fileName.toLowerCase();
    final isAudio = _audioExtensions.any(normalized.endsWith);
    return isAudio ? RemoteEntryKind.audio : RemoteEntryKind.file;
  }
}

class Cloud189MusicSourceFactory implements MusicSourceFactory {
  const Cloud189MusicSourceFactory({required this.playbackCacheFactory});

  final Cloud189PlaybackCacheFactory playbackCacheFactory;

  @override
  SourceProtocol get protocol => SourceProtocol.cloudDrive;

  @override
  MusicSource create(SourceProfile profile) {
    return Cloud189MusicSource(
      profile,
      playbackCacheFactory: playbackCacheFactory,
    );
  }
}

class _Cloud189CachedStreamAudioSource extends StreamAudioSource {
  _Cloud189CachedStreamAudioSource({
    required this.client,
    required this.entry,
    required this.playbackCache,
  });

  final Cloud189RemoteClient client;
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
      final cachedSnapshot = playbackCache.snapshotForTrack(entry.uniqueId);
      final cachedSourceLength = cachedSnapshot != null
          ? cachedSnapshot.totalLength
          : entry.size;
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
          contentType: _resolvePlaybackContentType(''),
        );
      }

      final networkResult = await client.openRead(
        entry.path,
        start: cachedRange.endExclusive,
        end: end,
      );
      if (networkResult.offset != cachedRange.endExclusive) {
        await networkResult.stream.listen(null).cancel();
        throw StateError(
          'Playback response does not continue the cached range.',
        );
      }
      final sourceLength = networkResult.sourceLength;
      final resolvedContentLength = _resolvedContentLength(
        requestedStart: requestedStart,
        sourceLength: sourceLength,
        cachedBytesLength: cachedRange.bytes.length,
        networkContentLength: networkResult.contentLength,
      );
      if (resolvedContentLength == null) {
        return _wholeResponse(networkResult, requestedEnd: end);
      }

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
        contentType: _resolvePlaybackContentType(networkResult.contentType),
      );
    }

    final result = await client.openRead(entry.path, start: start, end: end);
    final sourceLength = result.sourceLength;
    final resolvedContentLength = _resolvedContentLength(
      requestedStart: result.offset,
      sourceLength: sourceLength,
      cachedBytesLength: 0,
      networkContentLength: result.contentLength,
    );
    if (resolvedContentLength == null) {
      return _wholeResponse(result, requestedEnd: end);
    }

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
      contentType: _resolvePlaybackContentType(result.contentType),
    );
  }

  Future<StreamAudioResponse> _wholeResponse(
    Cloud189ReadResult result, {
    required int? requestedEnd,
  }) async {
    // just_audio requires a known response length for HTTP 206; serve a full 200.
    if (result.offset != 0 || requestedEnd != null) {
      await result.stream.listen(null).cancel();
      result = await client.openRead(entry.path);
    }
    if (result.offset != 0) {
      await result.stream.listen(null).cancel();
      throw StateError('Whole playback response must begin at byte zero.');
    }
    final sourceLength = result.sourceLength;
    return StreamAudioResponse(
      rangeRequestsSupported: false,
      sourceLength: null,
      contentLength: _resolvedContentLength(
        requestedStart: 0,
        sourceLength: sourceLength,
        cachedBytesLength: 0,
        networkContentLength: result.contentLength,
      ),
      offset: null,
      stream: playbackCache.wrapPlaybackStream(
        entry: entry,
        stream: result.stream,
        offset: 0,
        requestedEnd: null,
        expectedLength: sourceLength,
      ),
      contentType: _resolvePlaybackContentType(result.contentType),
    );
  }

  int? _resolvedContentLength({
    required int requestedStart,
    required int? sourceLength,
    required int cachedBytesLength,
    required int networkContentLength,
  }) {
    if (networkContentLength > 0) {
      return cachedBytesLength + networkContentLength;
    }
    if (sourceLength == requestedStart + cachedBytesLength) {
      return cachedBytesLength;
    }
    return null;
  }

  String _resolvePlaybackContentType(String headerContentType) {
    final normalizedHeader = headerContentType.trim().toLowerCase();
    if (normalizedHeader.startsWith('audio/')) {
      return normalizedHeader.split(';').first;
    }
    final normalizedMime = (entry.mimeType ?? '').trim().toLowerCase();
    if (normalizedMime.startsWith('audio/')) {
      return normalizedMime.split(';').first;
    }
    return 'audio/mpeg';
  }

  Stream<List<int>> _concatStreams(
    Stream<List<int>> first,
    Stream<List<int>> second,
  ) async* {
    yield* first;
    yield* second;
  }
}

class _Cloud189PlaybackCacheClientAdapter implements WebDavRemoteClient {
  const _Cloud189PlaybackCacheClientAdapter(this._client);

  final Cloud189RemoteClient _client;

  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    final result = await _client.openRead(path, start: start, end: end);
    return WebDavReadResult(
      stream: result.stream,
      offset: result.offset,
      contentLength: result.contentLength,
      contentType: result.contentType,
      sourceLength: result.sourceLength,
      sourceLengthIsAuthoritative: true,
    );
  }

  @override
  Future<void> ping() => _client.connect();

  @override
  Future<List<WebDavRemoteFile>> readDirectory(String path) async {
    final items = await _client.readDirectory(path);
    return items
        .map(
          (file) => WebDavRemoteFile(
            path: file.path,
            name: file.name,
            isDirectory: file.isDirectory,
            mimeType: file.mimeType,
            size: file.size,
            modifiedAt: file.modifiedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String?> readText(String path) => _client.readText(path);
}

Cloud189RemoteClient _defaultClientFactory(
  SourceProfile profile, {
  Cloud189CaptchaResolver? captchaResolver,
  Cloud189QRCodeResolver? qrCodeResolver,
  Cloud189SMSVerificationResolver? smsVerificationResolver,
}) {
  final metadata = profile.metadata;
  final enableDebugLogging =
      metadata[Cloud189Constants.debugLoggingMetadataKey] == 'true';
  final authMode = Cloud189AuthMode.fromStorageValue(
    metadata[Cloud189Constants.authModeMetadataKey],
  );
  if (authMode == Cloud189AuthMode.openListPassword) {
    return DioOpenListCloud189RemoteClient(
      username: profile.username,
      password: profile.password,
      enableDebugLogging: enableDebugLogging,
      captchaResolver: captchaResolver,
    );
  }

  if (authMode == Cloud189AuthMode.cloudTV) {
    final tvLoginMode = Cloud189TVLoginMode.fromValue(
      metadata[Cloud189Constants.tvLoginModeMetadataKey],
    );
    final deviceId = metadata['cloud189.deviceId'] ?? '';
    return DioCloud189TVRemoteClient(
      tvLoginMode: tvLoginMode,
      deviceId: deviceId.isNotEmpty ? deviceId : null,
      enableDebugLogging: enableDebugLogging,
      qrCodeResolver: qrCodeResolver,
      smsVerificationResolver: smsVerificationResolver,
    );
  }

  final appKey = metadata[Cloud189Constants.appKeyMetadataKey] ?? '';
  return DioCloud189RemoteClient(
    refreshToken: profile.password,
    clientId: appKey.isEmpty ? Cloud189Constants.openListAppId : appKey,
    clientSecret: metadata[Cloud189Constants.appSecretMetadataKey] ?? '',
    authorizationCode:
        metadata[Cloud189Constants.authorizationCodeMetadataKey] ?? '',
    redirectUri: metadata[Cloud189Constants.redirectUriMetadataKey] ?? '',
    enableDebugLogging: enableDebugLogging,
  );
}
