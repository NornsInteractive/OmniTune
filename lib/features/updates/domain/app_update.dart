class AppVersion {
  const AppVersion(this.name, this.code);
  final String name;
  final int code;
}

class UpdateTarget {
  const UpdateTarget(this.platform, this.arch);
  final String platform;
  final String arch;
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.versionName,
    required this.versionCode,
    required this.changelog,
    required this.platform,
    required this.downloadUri,
    required this.fileSize,
    this.sha256,
  });
  final String versionName;
  final int versionCode;
  final String changelog;
  final String platform;
  final Uri downloadUri;
  final int fileSize;
  final String? sha256;
}

enum AppUpdateFailure {
  network,
  invalidResponse,
  noPackage,
  checksumMissing,
  download,
  checksum,
  permission,
  installation,
  unknown,
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.failure);
  final AppUpdateFailure failure;
}
