import 'source_protocol.dart';

class SourceProfile {
  const SourceProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.rootPath,
    this.scanDirectories = const [],
    this.excludedScanDirectories = const [],
    this.metadata = const {},
  });

  final String id;
  final String name;
  final SourceProtocol protocol;
  final String baseUrl;
  final String username;
  final String password;
  final String rootPath;
  final List<String> scanDirectories;
  final List<String> excludedScanDirectories;
  final Map<String, String> metadata;

  String get normalizedBaseUrl => baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  String get normalizedRootPath {
    var normalized = rootPath.trim();
    if (normalized.isEmpty) {
      return '/';
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return normalized;
  }

  String get effectiveRootPath {
    final normalized = normalizedRootPath;
    if (normalized == '/') {
      return normalized;
    }

    final uri = Uri.tryParse(normalizedBaseUrl);
    if (uri == null) {
      return normalized;
    }

    final baseSegments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    final rootSegments = _pathSegments(normalized);

    if (baseSegments.isEmpty || rootSegments.isEmpty) {
      return normalized;
    }

    final maxOverlap = baseSegments.length < rootSegments.length
        ? baseSegments.length
        : rootSegments.length;

    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final baseSuffix = baseSegments.sublist(baseSegments.length - overlap);
      final rootPrefix = rootSegments.sublist(0, overlap);

      if (_segmentsEqual(baseSuffix, rootPrefix)) {
        final remaining = rootSegments.sublist(overlap);
        if (remaining.isEmpty) {
          return '/';
        }
        return '/${remaining.join('/')}/';
      }
    }

    return normalized;
  }

  List<String> get normalizedScanDirectories =>
      _normalizeConfiguredDirectories(scanDirectories);

  List<String> get normalizedExcludedScanDirectories =>
      _normalizeConfiguredDirectories(excludedScanDirectories);

  List<String> get effectiveScanDirectories {
    final configuredDirectories = normalizedScanDirectories;
    if (configuredDirectories.isEmpty) {
      return [effectiveRootPath];
    }

    return _deduplicateDirectories(
      configuredDirectories.map(resolveRelativePathFromRoot).toList(),
    );
  }

  List<String> get effectiveExcludedScanDirectories => _deduplicateDirectories(
    normalizedExcludedScanDirectories.map(resolveRelativePathFromRoot).toList(),
  );

  String resolveRelativePathFromRoot(String path) {
    final normalizedRelativePath = _normalizeConfiguredDirectory(path);
    if (normalizedRelativePath == '/') {
      return effectiveRootPath;
    }

    final rootSegments = _pathSegments(effectiveRootPath);
    final relativeSegments = _pathSegments(normalizedRelativePath);
    return '/${[...rootSegments, ...relativeSegments].join('/')}/';
  }

  String get hostLabel {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) {
      return baseUrl;
    }
    if (uri.host.isEmpty) {
      return baseUrl;
    }
    return uri.host;
  }

  SourceProfile copyWith({
    String? id,
    String? name,
    SourceProtocol? protocol,
    String? baseUrl,
    String? username,
    String? password,
    String? rootPath,
    List<String>? scanDirectories,
    List<String>? excludedScanDirectories,
    Map<String, String>? metadata,
  }) {
    return SourceProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      protocol: protocol ?? this.protocol,
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      rootPath: rootPath ?? this.rootPath,
      scanDirectories: scanDirectories ?? this.scanDirectories,
      excludedScanDirectories:
          excludedScanDirectories ?? this.excludedScanDirectories,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'protocol': protocol.storageValue,
      'baseUrl': baseUrl,
      'username': username,
      'password': password,
      'rootPath': rootPath,
      'scanDirectories': normalizedScanDirectories,
      'excludedScanDirectories': normalizedExcludedScanDirectories,
      'metadata': Map<String, String>.from(metadata),
    };
  }

  factory SourceProfile.fromJson(Map<String, dynamic> json) {
    return SourceProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      protocol: SourceProtocolX.fromStorageValue(json['protocol'] as String),
      baseUrl: json['baseUrl'] as String,
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      rootPath: json['rootPath'] as String? ?? '/',
      scanDirectories: _directoriesFromJson(json['scanDirectories']),
      excludedScanDirectories: _directoriesFromJson(
        json['excludedScanDirectories'],
      ),
      metadata: _metadataFromJson(json['metadata']),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SourceProfile &&
            runtimeType == other.runtimeType &&
            id == other.id &&
            name == other.name &&
            protocol == other.protocol &&
            baseUrl == other.baseUrl &&
            username == other.username &&
            password == other.password &&
            rootPath == other.rootPath &&
            _listEquals(scanDirectories, other.scanDirectories) &&
            _listEquals(
              excludedScanDirectories,
              other.excludedScanDirectories,
            ) &&
            _mapEquals(metadata, other.metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    protocol,
    baseUrl,
    username,
    password,
    rootPath,
    Object.hashAll(scanDirectories),
    Object.hashAll(excludedScanDirectories),
    Object.hashAllUnordered(
      metadata.entries.map((entry) {
        return Object.hash(entry.key, entry.value);
      }),
    ),
  );

  static List<String> _directoriesFromJson(Object? jsonValue) {
    final values = switch (jsonValue) {
      final List<dynamic> list => list.whereType<String>().toList(),
      _ => const <String>[],
    };
    return _normalizeDirectories(values);
  }

  static Map<String, String> _metadataFromJson(Object? jsonValue) {
    if (jsonValue is! Map) {
      return const {};
    }

    return jsonValue.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  List<String> _normalizeConfiguredDirectories(List<String> directories) {
    return _normalizeDirectories(
      directories.map((item) => _trimRootPrefix(item)).toList(),
    );
  }

  static List<String> _normalizeDirectories(List<String> directories) {
    final normalized = <String>[];
    for (final directory in directories) {
      final nextDirectory = _normalizeDirectory(directory);
      if (!normalized.contains(nextDirectory)) {
        normalized.add(nextDirectory);
      }
    }
    return normalized;
  }

  static String _normalizeDirectory(String path) {
    var normalized = path.trim();
    if (normalized.isEmpty) {
      return '/';
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return normalized;
  }

  String _normalizeConfiguredDirectory(String path) {
    return _normalizeDirectory(_trimRootPrefix(path));
  }

  String _trimRootPrefix(String path) {
    final normalizedPath = _normalizeDirectory(path);
    final normalizedRoot = normalizedRootPath;
    if (normalizedRoot == '/' || normalizedPath == '/') {
      return normalizedPath;
    }

    if (normalizedPath == normalizedRoot) {
      return '/';
    }

    if (normalizedPath.startsWith(normalizedRoot)) {
      final remaining = normalizedPath.substring(normalizedRoot.length - 1);
      return remaining.isEmpty ? '/' : remaining;
    }

    return normalizedPath;
  }

  List<String> _deduplicateDirectories(List<String> directories) {
    final normalized = <String>[];
    for (final directory in directories) {
      final normalizedDirectory = _normalizeDirectory(directory);
      if (!normalized.contains(normalizedDirectory)) {
        normalized.add(normalizedDirectory);
      }
    }
    return normalized;
  }

  List<String> _pathSegments(String path) {
    return path.split('/').where((segment) => segment.isNotEmpty).toList();
  }

  bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }

  bool _mapEquals(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }

  bool _segmentsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
