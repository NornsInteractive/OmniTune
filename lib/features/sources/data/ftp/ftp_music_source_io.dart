import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ftpconnect/ftpconnect.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';
import '../remote_source_utils.dart';

class FtpMusicSource implements MusicSource {
  FtpMusicSource(this.profile);

  @override
  final SourceProfile profile;

  late Uri _uri;
  late List<String> _basePathSegments;
  bool _configured = false;
  Directory? _tempDirectory;
  final Map<String, Future<File>> _downloadCache = {};

  @override
  Future<void> connect() async {
    _configure();
  }

  @override
  Future<void> disconnect() async {
    _downloadCache.clear();
    final tempDirectory = _tempDirectory;
    _tempDirectory = null;
    if (tempDirectory != null && await tempDirectory.exists()) {
      try {
        await tempDirectory.delete(recursive: true);
      } catch (_) {
        // Playback may still hold a file handle; the OS temp directory can clean it later.
      }
    }
  }

  @override
  Future<DirectoryListing> listFiles(String path) async {
    await connect();
    final requestedPath = normalizeDirectoryPath(path);
    final remotePath = _remoteDirectoryPath(requestedPath);
    final files = await _withClient((client) async {
      final changed = await client.changeDirectory(remotePath);
      if (!changed) {
        throw StateError('Unable to open FTP directory $remotePath.');
      }
      return client.listDirectoryContent();
    });

    final entries = files
        .where((file) => file.name != '.' && file.name != '..')
        .map((file) {
          final isDirectory = file.type == FTPEntryType.dir;
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
            modifiedAt: file.modifyTime,
          );
        })
        .toList();

    sortRemoteEntries(entries);
    return DirectoryListing(
      entries: entries,
      diagnostics: DirectoryDiagnostics(
        protocolLabel: SourceProtocol.ftp.label,
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
      audioSource: _FtpDownloadedAudioSource(source: this, entry: entry),
    );
  }

  @override
  Future<String?> readTextFile(String path) async {
    try {
      await connect();
      final file = await _downloadRemotePath(path);
      return utf8.decode(await file.readAsBytes(), allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  int get _port => _uri.hasPort ? _uri.port : _defaultPort;

  int get _defaultPort => _securityType == SecurityType.ftps ? 990 : 21;

  String get _username {
    final configuredUsername = profile.username.trim();
    final username = configuredUsername.isNotEmpty
        ? configuredUsername
        : userInfoUsername(_uri);
    return username.isEmpty ? 'anonymous' : username;
  }

  String get _password {
    if (profile.password.isNotEmpty) {
      return profile.password;
    }
    return userInfoPassword(_uri);
  }

  SecurityType get _securityType {
    return switch (_uri.scheme.toLowerCase()) {
      'ftps' => SecurityType.ftps,
      'ftpes' => SecurityType.ftpes,
      _ => SecurityType.ftp,
    };
  }

  void _configure() {
    if (_configured) {
      return;
    }
    _uri = parseSourceUri(profile, 'ftp');
    _basePathSegments = uriPathSegments(_uri);
    _configured = true;
  }

  FTPConnect _createClient() {
    final client = FTPConnect(
      _uri.host,
      port: _port,
      user: _username,
      pass: _password,
      securityType: _securityType,
      timeout: 30,
    );
    client.transferMode = TransferMode.passive;
    return client;
  }

  Future<T> _withClient<T>(Future<T> Function(FTPConnect client) action) async {
    final client = _createClient();
    final connected = await client.connect();
    if (!connected) {
      throw StateError('Unable to connect to FTP server ${_uri.host}.');
    }
    try {
      await client.setTransferType(TransferType.binary);
      return await action(client);
    } finally {
      await client.disconnect();
    }
  }

  String _remoteDirectoryPath(String path) {
    return normalizeDirectoryPath(combineBasePath(_basePathSegments, path));
  }

  String _remoteFilePath(String path) {
    return normalizeFilePath(combineBasePath(_basePathSegments, path));
  }

  Future<File> _downloadRemotePath(String path) {
    final normalizedPath = normalizeFilePath(path);
    return _downloadCache.putIfAbsent(normalizedPath, () async {
      final remotePath = _remoteFilePath(normalizedPath);
      final tempDirectory = await _ensureTempDirectory();
      final file = File(
        p.join(
          tempDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}_${_safeFileName(p.posix.basename(remotePath))}',
        ),
      );
      await _withClient((client) async {
        final directory = p.posix.dirname(remotePath);
        final fileName = p.posix.basename(remotePath);
        final changed = await client.changeDirectory(directory);
        if (!changed) {
          throw StateError('Unable to open FTP directory $directory.');
        }
        final downloaded = await client.downloadFile(fileName, file);
        if (!downloaded) {
          throw StateError('Unable to download FTP file $remotePath.');
        }
      });
      return file;
    });
  }

  Future<Directory> _ensureTempDirectory() async {
    final existing = _tempDirectory;
    if (existing != null) {
      return existing;
    }
    final created = await Directory.systemTemp.createTemp('flux_music_ftp_');
    _tempDirectory = created;
    return created;
  }

  String _safeFileName(String name) {
    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}

class _FtpDownloadedAudioSource extends StreamAudioSource {
  _FtpDownloadedAudioSource({required this.source, required this.entry});

  final FtpMusicSource source;
  final RemoteEntry entry;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final file = await source._downloadRemotePath(entry.path);
    final sourceLength = await file.length();
    final requestedStart = start ?? 0;
    final requestedEnd = end ?? sourceLength;
    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: requestedEnd - requestedStart,
      offset: requestedStart,
      stream: _readFileRange(file, requestedStart, requestedEnd),
      contentType: resolveAudioContentType(
        fileName: entry.name,
        fallbackMimeType: entry.mimeType,
      ),
    );
  }

  Stream<List<int>> _readFileRange(File file, int start, int end) async* {
    final raf = await file.open();
    try {
      await raf.setPosition(start);
      var remaining = end - start;
      while (remaining > 0) {
        final bytes = await raf.read(math.min(64 * 1024, remaining));
        if (bytes.isEmpty) {
          break;
        }
        remaining -= bytes.length;
        yield bytes;
      }
    } finally {
      await raf.close();
    }
  }
}

class FtpMusicSourceFactory implements MusicSourceFactory {
  const FtpMusicSourceFactory();

  @override
  SourceProtocol get protocol => SourceProtocol.ftp;

  @override
  MusicSource create(SourceProfile profile) {
    return FtpMusicSource(profile);
  }
}
