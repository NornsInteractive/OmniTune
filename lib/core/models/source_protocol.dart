enum SourceProtocol { webdav, sftp, cloudDrive }

extension SourceProtocolX on SourceProtocol {
  String get storageValue => switch (this) {
    SourceProtocol.webdav => 'webdav',
    SourceProtocol.sftp => 'sftp',
    SourceProtocol.cloudDrive => 'cloudDrive',
  };

  bool get isImplemented => this == SourceProtocol.webdav;

  String get label => switch (this) {
    SourceProtocol.webdav => 'WebDAV',
    SourceProtocol.sftp => 'SFTP',
    SourceProtocol.cloudDrive => 'Cloud drive',
  };

  static SourceProtocol fromStorageValue(String value) {
    return SourceProtocol.values.firstWhere(
      (protocol) => protocol.storageValue == value,
      orElse: () => SourceProtocol.webdav,
    );
  }
}
