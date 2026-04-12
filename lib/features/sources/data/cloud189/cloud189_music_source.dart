import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';
import 'cloud189_api_client.dart';

typedef Cloud189RemoteClientFactory = Cloud189RemoteClient Function(SourceProfile profile);

class Cloud189MusicSource implements MusicSource {
  Cloud189MusicSource(
    this.profile, {
    Cloud189RemoteClientFactory? clientFactory,
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
           );

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
            kind: file.isDirectory ? RemoteEntryKind.directory : _resolveFileKind(file.name, file.mimeType),
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

    final folderSegments = p.posix.dirname(entry.path).split('/').where((segment) => segment.isNotEmpty).toList();

    await connect();
    return PlayableTrack(
      id: entry.uniqueId,
      sourceId: profile.id,
      title: entry.title,
      sourceName: profile.name,
      remotePath: entry.path,
      audioSource: _Cloud189StreamAudioSource(client: _client, entry: entry),
      sourceSizeBytes: entry.size,
      albumTitle: folderSegments.isEmpty ? profile.name : folderSegments.last,
      artistName: folderSegments.length >= 2 ? folderSegments[folderSegments.length - 2] : profile.name,
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

  RemoteEntryKind _resolveFileKind(String fileName, String? mimeType) {
    if ((mimeType ?? '').startsWith('audio/')) {
      return RemoteEntryKind.audio;
    }

    final normalized = fileName.toLowerCase();
    final isAudio = _audioExtensions.any(normalized.endsWith);
    return isAudio ? RemoteEntryKind.audio : RemoteEntryKind.file;
  }
}

class _Cloud189StreamAudioSource extends StreamAudioSource {
  _Cloud189StreamAudioSource({required this.client, required this.entry});

  final Cloud189RemoteClient client;
  final RemoteEntry entry;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final result = await client.openRead(entry.path, start: start, end: end);
    return StreamAudioResponse(
      sourceLength: result.sourceLength ?? entry.size,
      contentLength: result.contentLength,
      offset: result.offset,
      stream: result.stream,
      contentType: result.contentType,
    );
  }
}

class Cloud189MusicSourceFactory implements MusicSourceFactory {
  const Cloud189MusicSourceFactory();

  @override
  SourceProtocol get protocol => SourceProtocol.cloudDrive;

  @override
  MusicSource create(SourceProfile profile) {
    return Cloud189MusicSource(profile);
  }
}

Cloud189RemoteClient _defaultClientFactory(
  SourceProfile profile, {
  Cloud189CaptchaResolver? captchaResolver,
  Cloud189QRCodeResolver? qrCodeResolver,
  Cloud189SMSVerificationResolver? smsVerificationResolver,
}) {
  final metadata = profile.metadata;
  final enableDebugLogging = metadata[Cloud189Constants.debugLoggingMetadataKey] == 'true';
  final authMode = Cloud189AuthMode.fromStorageValue(metadata[Cloud189Constants.authModeMetadataKey]);
  if (authMode == Cloud189AuthMode.openListPassword) {
    return DioOpenListCloud189RemoteClient(
      username: profile.username,
      password: profile.password,
      enableDebugLogging: enableDebugLogging,
      captchaResolver: captchaResolver,
    );
  }

  if (authMode == Cloud189AuthMode.cloudTV) {
    final tvLoginMode = Cloud189TVLoginMode.fromValue(metadata[Cloud189Constants.tvLoginModeMetadataKey]);
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
    authorizationCode: metadata[Cloud189Constants.authorizationCodeMetadataKey] ?? '',
    redirectUri: metadata[Cloud189Constants.redirectUriMetadataKey] ?? '',
    enableDebugLogging: enableDebugLogging,
  );
}
