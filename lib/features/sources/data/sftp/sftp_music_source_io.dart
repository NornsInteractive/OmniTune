import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';
import '../remote_source_utils.dart';

class SftpMusicSource implements MusicSource {
  SftpMusicSource(this.profile);

  @override
  final SourceProfile profile;

  SSHClient? _sshClient;
  SftpClient? _sftpClient;
  late Uri _uri;
  late List<String> _basePathSegments;
  bool _configured = false;

  @override
  Future<void> connect() async {
    if (_sftpClient != null) {
      return;
    }

    _configure();
    final socket = await SSHSocket.connect(_uri.host, _port);
    final username = _username;
    final password = _password;
    final sshClient = SSHClient(
      socket,
      username: username,
      onPasswordRequest: password.isEmpty ? null : () => password,
    );
    _sshClient = sshClient;
    _sftpClient = await sshClient.sftp();
  }

  @override
  Future<void> disconnect() async {
    final sftpClient = _sftpClient;
    final sshClient = _sshClient;
    _sftpClient = null;
    _sshClient = null;
    sftpClient?.close();
    sshClient?.close();
    try {
      await sshClient?.done.timeout(const Duration(seconds: 2));
    } catch (_) {
      // The socket may already be closed by the server.
    }
  }

  @override
  Future<DirectoryListing> listFiles(String path) async {
    await connect();
    final requestedPath = normalizeDirectoryPath(path);
    final remotePath = _remoteDirectoryPath(requestedPath);
    final names = await _sftp.listdir(remotePath);
    final entries = names
        .where((name) => name.filename != '.' && name.filename != '..')
        .map((name) {
          final isDirectory = name.attr.isDirectory;
          return RemoteEntry(
            sourceId: profile.id,
            name: name.filename,
            path: joinRemotePath(
              requestedPath,
              name.filename,
              isDirectory: isDirectory,
            ),
            kind: resolveRemoteEntryKind(
              isDirectory: isDirectory,
              fileName: name.filename,
            ),
            size: isDirectory ? null : name.attr.size,
            modifiedAt: _modifiedAt(name.attr.modifyTime),
          );
        })
        .toList();

    sortRemoteEntries(entries);
    return DirectoryListing(
      entries: entries,
      diagnostics: DirectoryDiagnostics(
        protocolLabel: SourceProtocol.sftp.label,
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
      audioSource: _SftpStreamAudioSource(source: this, entry: entry),
    );
  }

  @override
  Future<String?> readTextFile(String path) async {
    try {
      await connect();
      final file = await _sftp.open(_remoteFilePath(path));
      try {
        final bytes = await file.readBytes();
        return utf8.decode(bytes, allowMalformed: true);
      } finally {
        await file.close();
      }
    } catch (_) {
      return null;
    }
  }

  SftpClient get _sftp {
    final client = _sftpClient;
    if (client == null) {
      throw StateError('SFTP source is not connected.');
    }
    return client;
  }

  int get _port => _uri.hasPort ? _uri.port : 22;

  String get _username {
    final configuredUsername = profile.username.trim();
    return configuredUsername.isNotEmpty
        ? configuredUsername
        : userInfoUsername(_uri);
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
    _uri = parseSourceUri(profile, 'sftp');
    _basePathSegments = uriPathSegments(_uri);
    _configured = true;
  }

  String _remoteDirectoryPath(String path) {
    return normalizeDirectoryPath(combineBasePath(_basePathSegments, path));
  }

  String _remoteFilePath(String path) {
    return normalizeFilePath(combineBasePath(_basePathSegments, path));
  }

  Future<int> _fileSize(RemoteEntry entry) async {
    if (entry.size != null) {
      return entry.size!;
    }
    final attrs = await _sftp.stat(_remoteFilePath(entry.path));
    final size = attrs.size;
    if (size == null) {
      throw StateError('Unable to read SFTP file size for ${entry.path}.');
    }
    return size;
  }

  Stream<List<int>> _openRead(RemoteEntry entry, int start, int end) async* {
    await connect();
    final file = await _sftp.open(_remoteFilePath(entry.path));
    try {
      yield* file.read(length: end - start, offset: start);
    } finally {
      await file.close();
    }
  }

  DateTime? _modifiedAt(int? secondsSinceEpoch) {
    if (secondsSinceEpoch == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      secondsSinceEpoch * 1000,
      isUtc: true,
    );
  }
}

class _SftpStreamAudioSource extends StreamAudioSource {
  _SftpStreamAudioSource({required this.source, required this.entry});

  final SftpMusicSource source;
  final RemoteEntry entry;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final sourceLength = await source._fileSize(entry);
    final requestedStart = start ?? 0;
    final requestedEnd = end ?? sourceLength;
    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: requestedEnd - requestedStart,
      offset: requestedStart,
      stream: source._openRead(entry, requestedStart, requestedEnd),
      contentType: resolveAudioContentType(
        fileName: entry.name,
        fallbackMimeType: entry.mimeType,
      ),
    );
  }
}

class SftpMusicSourceFactory implements MusicSourceFactory {
  const SftpMusicSourceFactory();

  @override
  SourceProtocol get protocol => SourceProtocol.sftp;

  @override
  MusicSource create(SourceProfile profile) {
    return SftpMusicSource(profile);
  }
}
