import 'package:path/path.dart' as p;

enum RemoteEntryKind { directory, audio, file }

class RemoteEntry {
  const RemoteEntry({
    required this.sourceId,
    required this.name,
    required this.path,
    required this.kind,
    this.mimeType,
    this.size,
    this.modifiedAt,
  });

  final String sourceId;
  final String name;
  final String path;
  final RemoteEntryKind kind;
  final String? mimeType;
  final int? size;
  final DateTime? modifiedAt;

  bool get isDirectory => kind == RemoteEntryKind.directory;

  bool get isPlayable => kind == RemoteEntryKind.audio;

  String get title {
    if (isDirectory) {
      return name;
    }
    return p.basenameWithoutExtension(name);
  }

  String get uniqueId => '$sourceId::$path';
}
