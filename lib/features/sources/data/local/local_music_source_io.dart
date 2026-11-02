import 'dart:io';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/models/playable_track.dart';
import '../../../../core/models/remote_entry.dart';
import '../../../../core/models/source_profile.dart';
import '../../../../core/models/source_protocol.dart';
import '../../domain/music_source.dart';
import '../remote_source_utils.dart';

class LocalMusicSource implements MusicSource {
  const LocalMusicSource(this.profile);

  @override
  final SourceProfile profile;

  @override
  Future<void> connect() async {
    // Verify that at least one configured directory or root exists
    final targetDirs = profile.effectiveScanDirectories;
    var existsAny = false;
    for (final dirPath in targetDirs) {
      if (Directory(dirPath).existsSync()) {
        existsAny = true;
        break;
      }
    }
    if (!existsAny && targetDirs.isNotEmpty) {
      // In case directories are relative or need creation
      final rootDir = Directory(profile.rootPath);
      if (!rootDir.existsSync()) {
        try {
          rootDir.createSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<DirectoryListing> listFiles(String path) async {
    final cleanPath = path.trim();

    // If requested root '/' and multiple scan directories are configured, return virtual root list
    if ((cleanPath == '/' || cleanPath.isEmpty) && profile.scanDirectories.length > 1) {
      final entries = profile.scanDirectories.map((dir) {
        final normalized = dir.replaceAll(r'\', '/');
        final trimmed = normalized.endsWith('/') ? normalized.substring(0, normalized.length - 1) : normalized;
        final name = p.basename(trimmed);
        final fullPath = normalized.endsWith('/') ? normalized : '$normalized/';
        return RemoteEntry(
          sourceId: profile.id,
          name: name.isNotEmpty ? name : dir,
          path: fullPath,
          kind: RemoteEntryKind.directory,
          size: null,
        );
      }).toList(growable: false);

      return DirectoryListing(
        entries: entries,
        diagnostics: DirectoryDiagnostics(
          protocolLabel: SourceProtocol.local.label,
          requestedPath: path,
          attemptedPaths: [path],
          entryCount: entries.length,
        ),
      );
    }

    final targetPath = cleanPath == '/'
        ? (profile.scanDirectories.isNotEmpty ? profile.scanDirectories.first : profile.rootPath)
        : cleanPath;

    final dir = Directory(targetPath);
    if (!dir.existsSync()) {
      return DirectoryListing(
        entries: const [],
        diagnostics: DirectoryDiagnostics(
          protocolLabel: SourceProtocol.local.label,
          requestedPath: targetPath,
          attemptedPaths: [targetPath],
          entryCount: 0,
          summary: 'Directory does not exist: $targetPath',
        ),
      );
    }

    final entries = <RemoteEntry>[];
    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        final normalizedPath = entity.path.replaceAll(r'\', '/');
        final name = p.basename(normalizedPath);
        if (name.startsWith('.')) continue; // Skip hidden files

        if (entity is Directory) {
          final dirPath = normalizedPath.endsWith('/') ? normalizedPath : '$normalizedPath/';
          entries.add(
            RemoteEntry(
              sourceId: profile.id,
              name: name,
              path: dirPath,
              kind: RemoteEntryKind.directory,
              size: null,
            ),
          );
        } else if (entity is File) {
          final kind = resolveRemoteEntryKind(
            isDirectory: false,
            fileName: name,
          );
          if (kind == RemoteEntryKind.audio) {
            int? size;
            DateTime? modifiedAt;
            try {
              final stat = entity.statSync();
              size = stat.size;
              modifiedAt = stat.modified;
            } catch (_) {}

            entries.add(
              RemoteEntry(
                sourceId: profile.id,
                name: name,
                path: normalizedPath,
                kind: RemoteEntryKind.audio,
                size: size,
                modifiedAt: modifiedAt,
              ),
            );
          }
        }
      }
    } catch (e) {
      return DirectoryListing(
        entries: entries,
        diagnostics: DirectoryDiagnostics(
          protocolLabel: SourceProtocol.local.label,
          requestedPath: targetPath,
          attemptedPaths: [targetPath],
          entryCount: entries.length,
          summary: 'Error listing directory: $e',
        ),
      );
    }

    sortRemoteEntries(entries);
    return DirectoryListing(
      entries: entries,
      diagnostics: DirectoryDiagnostics(
        protocolLabel: SourceProtocol.local.label,
        requestedPath: targetPath,
        attemptedPaths: [targetPath],
        entryCount: entries.length,
      ),
    );
  }

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) async {
    entry.ensurePlayable();
    final file = File(entry.path);
    final audioSource = AudioSource.uri(
      Uri.file(file.path),
      tag: entry.uniqueId,
    );

    return buildRemotePlayableTrack(
      profile: profile,
      entry: entry,
      audioSource: audioSource,
    );
  }

  @override
  Future<String?> readTextFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> readBinaryFile(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      return await file.readAsBytes();
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
      final file = File(path);
      if (!file.existsSync()) return null;
      final raf = await file.open(mode: FileMode.read);
      try {
        return await raf.read(length);
      } finally {
        await raf.close();
      }
    } catch (_) {
      return null;
    }
  }
}

class LocalMusicSourceFactory implements MusicSourceFactory {
  const LocalMusicSourceFactory();

  @override
  SourceProtocol get protocol => SourceProtocol.local;

  @override
  MusicSource create(SourceProfile profile) {
    return LocalMusicSource(profile);
  }
}
