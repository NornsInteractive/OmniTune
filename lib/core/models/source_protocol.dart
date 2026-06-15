import 'package:flutter/foundation.dart';

enum SourceProtocol { webdav, sftp, ftp, samba, cloudDrive }

extension SourceProtocolX on SourceProtocol {
  String get storageValue => switch (this) {
    SourceProtocol.webdav => 'webdav',
    SourceProtocol.sftp => 'sftp',
    SourceProtocol.ftp => 'ftp',
    SourceProtocol.samba => 'samba',
    SourceProtocol.cloudDrive => 'cloudDrive',
  };

  bool get isImplemented => true;

  bool get isSupportedOnCurrentPlatform => switch (this) {
    SourceProtocol.sftp || SourceProtocol.ftp || SourceProtocol.samba => !kIsWeb,
    SourceProtocol.webdav || SourceProtocol.cloudDrive => true,
  };

  String get label => switch (this) {
    SourceProtocol.webdav => 'WebDAV',
    SourceProtocol.sftp => 'SFTP',
    SourceProtocol.ftp => 'FTP',
    SourceProtocol.samba => 'Samba',
    SourceProtocol.cloudDrive => 'Cloud drive',
  };

  static SourceProtocol fromStorageValue(String value) {
    return SourceProtocol.values.firstWhere(
      (protocol) => protocol.storageValue == value,
      orElse: () => SourceProtocol.webdav,
    );
  }

  static List<SourceProtocol> supportedOnCurrentPlatform() {
    return SourceProtocol.values
        .where((protocol) => protocol.isSupportedOnCurrentPlatform)
        .toList(growable: false);
  }

  static SourceProtocol sanitizeForCurrentPlatform(SourceProtocol protocol) {
    if (protocol.isSupportedOnCurrentPlatform) {
      return protocol;
    }

    final supportedProtocols = supportedOnCurrentPlatform();
    if (supportedProtocols.isEmpty) {
      return SourceProtocol.webdav;
    }
    return supportedProtocols.first;
  }
}
