import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/playable_track.dart';
import '../../../core/models/remote_entry.dart';
import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';

const remoteAudioExtensions = {
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

RemoteEntryKind resolveRemoteEntryKind({
  required bool isDirectory,
  required String fileName,
  String? mimeType,
}) {
  if (isDirectory) {
    return RemoteEntryKind.directory;
  }

  if ((mimeType ?? '').startsWith('audio/')) {
    return RemoteEntryKind.audio;
  }

  final normalized = fileName.toLowerCase();
  return remoteAudioExtensions.any(normalized.endsWith)
      ? RemoteEntryKind.audio
      : RemoteEntryKind.file;
}

void sortRemoteEntries(List<RemoteEntry> entries) {
  entries.sort((left, right) {
    final kindComparison = left.kind.index.compareTo(right.kind.index);
    if (kindComparison != 0) {
      return kindComparison;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });
}

PlayableTrack buildRemotePlayableTrack({
  required SourceProfile profile,
  required RemoteEntry entry,
  required AudioSource audioSource,
  String? autoScrapedTitle,
  String? autoScrapedArtist,
  String? autoScrapedAlbum,
  String? autoScrapedCoverUrl,
  String? lyrics,
}) {
  final folderSegments = p.posix
      .dirname(entry.path)
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();

  return PlayableTrack(
    id: entry.uniqueId,
    sourceId: profile.id,
    title: entry.title,
    sourceName: profile.name,
    remotePath: entry.path,
    audioSource: audioSource,
    sourceSizeBytes: entry.size,
    albumTitle: folderSegments.isEmpty ? profile.name : folderSegments.last,
    artistName: folderSegments.length >= 2
        ? folderSegments[folderSegments.length - 2]
        : profile.name,
    autoScrapedTitle: autoScrapedTitle,
    autoScrapedArtist: autoScrapedArtist,
    autoScrapedAlbum: autoScrapedAlbum,
    autoScrapedCoverUrl: autoScrapedCoverUrl,
    lyrics: lyrics,
  );
}

String resolveAudioContentType({
  required String fileName,
  String? fallbackMimeType,
  String? headerContentType,
}) {
  final normalizedHeader = (headerContentType ?? '').trim().toLowerCase();
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

String normalizeDirectoryPath(String path) {
  var normalized = path.trim();
  if (normalized.isEmpty) {
    return '/';
  }
  normalized = normalized.replaceAll('\\', '/');
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  if (!normalized.endsWith('/')) {
    normalized = '$normalized/';
  }
  return normalized;
}

String normalizeFilePath(String path) {
  var normalized = path.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) {
    return '/';
  }
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  return p.posix.normalize(normalized);
}

String joinRemotePath(String parent, String name, {required bool isDirectory}) {
  final normalizedParent = normalizeDirectoryPath(parent);
  final normalizedName = name.trim();
  final joined = p.posix.join(normalizedParent, normalizedName);
  return isDirectory
      ? normalizeDirectoryPath(joined)
      : normalizeFilePath(joined);
}

Uri parseSourceUri(SourceProfile profile, String defaultScheme) {
  final raw = profile.baseUrl.trim();
  final normalized = raw.contains('://') ? raw : '$defaultScheme://$raw';
  final uri = Uri.parse(normalized);
  if (uri.host.trim().isEmpty) {
    throw FormatException('Invalid ${profile.protocol.storageValue} host.');
  }
  return uri;
}

List<String> uriPathSegments(Uri uri) {
  return uri.pathSegments
      .map(Uri.decodeComponent)
      .where((segment) => segment.trim().isNotEmpty)
      .toList();
}

String combineBasePath(List<String> baseSegments, String path) {
  final pathSegments = normalizeFilePath(
    path,
  ).split('/').where((segment) => segment.isNotEmpty).toList();
  return '/${[...baseSegments, ...pathSegments].join('/')}';
}

String userInfoUsername(Uri uri) {
  if (uri.userInfo.isEmpty) {
    return '';
  }
  return Uri.decodeComponent(uri.userInfo.split(':').first);
}

String userInfoPassword(Uri uri) {
  if (!uri.userInfo.contains(':')) {
    return '';
  }
  return Uri.decodeComponent(uri.userInfo.split(':').skip(1).join(':'));
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
