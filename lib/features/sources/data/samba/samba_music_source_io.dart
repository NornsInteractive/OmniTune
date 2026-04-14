import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:smb_connect/smb_connect.dart';

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';
import '../remote_source_utils.dart';

class SambaMusicSource implements MusicSource {
  SambaMusicSource(this.profile);

  @override
  final SourceProfile profile;

  SmbConnect? _connection;
  late Uri _uri;
  late String _shareName;
  late List<String> _basePathSegments;
  bool _configured = false;

  @override
  Future<void> connect() async {
    if (_connection != null) {
      return;
    }
    _configure();
    final credentials = _credentials;
    _connection = await SmbConnect.connectAuth(
      host: _uri.host,
      domain: credentials.domain,
      username: credentials.username,
      password: _password,
    );
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    await connection?.close();
  }

  @override
  Future<DirectoryListing> listFiles(String path) async {
    await connect();
    final requestedPath = normalizeDirectoryPath(path);
    final remotePath = _remoteDirectoryPath(requestedPath);
    final folder = await _smb.file(remotePath);
    final files = await _smb.listFiles(folder);
    final entries = files.map((file) {
      final isDirectory = file.isDirectory();
      return RemoteEntry(
        sourceId: profile.id,
        name: file.name,
        path: joinRemotePath(
          requestedPath,
          file.name,
          isDirectory: isDirectory,
        ),
        kind: resolveRemoteEntryKind(
          isDirectory: isDirectory,
          fileName: file.name,
        ),
        size: isDirectory ? null : file.size,
        modifiedAt: _modifiedAt(file.lastModified),
      );
    }).toList();

    sortRemoteEntries(entries);
    return DirectoryListing(
      entries: entries,
      diagnostics: DirectoryDiagnostics(
        protocolLabel: SourceProtocol.samba.label,
        requestedPath: requestedPath,
        attemptedPaths: [remotePath],
        entryCount: entries.length,
      ),
    );
  }

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) async {
    entry.ensurePlayable();
    await connect();
    return buildRemotePlayableTrack(
      profile: profile,
      entry: entry,
      audioSource: _SambaStreamAudioSource(source: this, entry: entry),
    );
  }

  @override
  Future<String?> readTextFile(String path) async {
    try {
      await connect();
      final file = await _smb.file(_remoteFilePath(path));
      final stream = await _smb.openRead(file);
      final bytes = await _collectBytes(stream);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  SmbConnect get _smb {
    final connection = _connection;
    if (connection == null) {
      throw StateError('Samba source is not connected.');
    }
    return connection;
  }

  ({String domain, String username}) get _credentials {
    final configuredUsername = profile.username.trim();
    final rawUsername = configuredUsername.isNotEmpty
        ? configuredUsername
        : userInfoUsername(_uri);
    if (rawUsername.contains('\\')) {
      final parts = rawUsername.split('\\');
      return (domain: parts.first, username: parts.skip(1).join('\\'));
    }
    if (rawUsername.contains('/')) {
      final parts = rawUsername.split('/');
      return (domain: parts.first, username: parts.skip(1).join('/'));
    }
    return (domain: '', username: rawUsername);
  }

  String get _password {
    if (profile.password.isNotEmpty) {
      return profile.password;
    }
    return userInfoPassword(_uri);
  }

  void _configure() {
    if (_configured) {
      return;
    }
    _uri = parseSourceUri(profile, 'smb');
    final segments = uriPathSegments(_uri);
    if (segments.isEmpty) {
      throw FormatException('Samba URL must include a share name.');
    }
    _shareName = segments.first;
    _basePathSegments = segments.skip(1).toList();
    _configured = true;
  }

  String _remoteDirectoryPath(String path) {
    return normalizeDirectoryPath(_remoteFilePath(path));
  }

  String _remoteFilePath(String path) {
    return normalizeFilePath(
      combineBasePath([_shareName, ..._basePathSegments], path),
    );
  }

  Future<SmbFile> _fileForEntry(RemoteEntry entry) {
    return _smb.file(_remoteFilePath(entry.path));
  }

  Stream<List<int>> _openRead(
    SmbFile file,
    int requestedStart,
    int requestedEnd,
  ) async* {
    final stream = await _smb.openRead(file, requestedStart, requestedEnd);
    yield* stream;
  }

  DateTime? _modifiedAt(int millisecondsSinceEpoch) {
    if (millisecondsSinceEpoch <= 0) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  }

  Future<List<int>> _collectBytes(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}

class _SambaStreamAudioSource extends StreamAudioSource {
  _SambaStreamAudioSource({required this.source, required this.entry});

  final SambaMusicSource source;
  final RemoteEntry entry;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final file = await source._fileForEntry(entry);
    final sourceLength = entry.size ?? file.size;
    final requestedStart = start ?? 0;
    final requestedEnd = end ?? sourceLength;
    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: requestedEnd - requestedStart,
      offset: requestedStart,
      stream: source._openRead(file, requestedStart, requestedEnd),
      contentType: resolveAudioContentType(
        fileName: entry.name,
        fallbackMimeType: entry.mimeType,
      ),
    );
  }
}

class SambaMusicSourceFactory implements MusicSourceFactory {
  const SambaMusicSourceFactory();

  @override
  SourceProtocol get protocol => SourceProtocol.samba;

  @override
  MusicSource create(SourceProfile profile) {
    return SambaMusicSource(profile);
  }
}
