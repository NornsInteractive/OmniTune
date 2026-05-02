import 'dart:convert';
import 'dart:typed_data';

class EmbeddedAudioMetadata {
  const EmbeddedAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.coverBytes,
    this.coverExtension,
  });

  final String? title;
  final String? artist;
  final String? album;
  final Uint8List? coverBytes;
  final String? coverExtension;

  bool get hasTextualMetadata =>
      (title?.trim().isNotEmpty ?? false) ||
      (artist?.trim().isNotEmpty ?? false) ||
      (album?.trim().isNotEmpty ?? false);

  bool get hasCover => coverBytes?.isNotEmpty == true;
}

class AudioEmbeddedMetadataReader {
  static EmbeddedAudioMetadata? parse(
    Uint8List bytes, {
    required String fileName,
  }) {
    if (bytes.length < 16) {
      return null;
    }

    final lower = fileName.toLowerCase();
    if (_startsWith(bytes, 'ID3'.codeUnits)) {
      return _parseId3(bytes);
    }
    if (_startsWith(bytes, 'fLaC'.codeUnits) || lower.endsWith('.flac')) {
      return _parseFlac(bytes);
    }
    return null;
  }

  static EmbeddedAudioMetadata? _parseId3(Uint8List bytes) {
    if (bytes.length < 10) {
      return null;
    }

    final majorVersion = bytes[3];
    final tagSize = _synchsafeInt(bytes, 6);
    final totalSize = 10 + tagSize;
    if (totalSize <= 10 || bytes.length < totalSize) {
      return null;
    }

    String? title;
    String? artist;
    String? album;
    Uint8List? coverBytes;
    String? coverExtension;

    var offset = 10;
    while (offset + 10 <= totalSize && offset + 10 <= bytes.length) {
      final frameId = ascii.decode(bytes.sublist(offset, offset + 4));
      if (frameId.trim().isEmpty ||
          frameId.codeUnits.every((code) => code == 0)) {
        break;
      }

      final frameSize = majorVersion >= 4
          ? _synchsafeInt(bytes, offset + 4)
          : _uint32Be(bytes, offset + 4);
      if (frameSize <= 0) {
        break;
      }

      final contentStart = offset + 10;
      final contentEnd = contentStart + frameSize;
      if (contentEnd > bytes.length || contentEnd > totalSize) {
        break;
      }

      final content = bytes.sublist(contentStart, contentEnd);
      switch (frameId) {
        case 'TIT2':
          title ??= _decodeTextFrame(content);
          break;
        case 'TPE1':
          artist ??= _decodeTextFrame(content);
          break;
        case 'TALB':
          album ??= _decodeTextFrame(content);
          break;
        case 'APIC':
          final picture = _decodeApicFrame(content);
          if (picture != null) {
            coverBytes ??= picture.$1;
            coverExtension ??= picture.$2;
          }
          break;
        default:
          break;
      }
      offset = contentEnd;
    }

    if ((title?.isEmpty ?? true) &&
        (artist?.isEmpty ?? true) &&
        (album?.isEmpty ?? true) &&
        coverBytes == null) {
      return null;
    }
    return EmbeddedAudioMetadata(
      title: _normalized(title),
      artist: _normalized(artist),
      album: _normalized(album),
      coverBytes: coverBytes,
      coverExtension: coverExtension,
    );
  }

  static EmbeddedAudioMetadata? _parseFlac(Uint8List bytes) {
    if (bytes.length < 8 || !_startsWith(bytes, 'fLaC'.codeUnits)) {
      return null;
    }

    String? title;
    String? artist;
    String? album;
    Uint8List? coverBytes;
    String? coverExtension;

    var offset = 4;
    var isLast = false;
    while (!isLast && offset + 4 <= bytes.length) {
      final header = bytes[offset];
      isLast = (header & 0x80) != 0;
      final blockType = header & 0x7f;
      final blockLength =
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      final blockStart = offset + 4;
      final blockEnd = blockStart + blockLength;
      if (blockEnd > bytes.length) {
        break;
      }

      final block = bytes.sublist(blockStart, blockEnd);
      if (blockType == 4) {
        final vorbis = _parseVorbisComments(block);
        title ??= vorbis['TITLE'];
        artist ??= vorbis['ARTIST'];
        album ??= vorbis['ALBUM'];
      } else if (blockType == 6) {
        final picture = _parseFlacPicture(block);
        if (picture != null) {
          coverBytes ??= picture.$1;
          coverExtension ??= picture.$2;
        }
      }
      offset = blockEnd;
    }

    if ((title?.isEmpty ?? true) &&
        (artist?.isEmpty ?? true) &&
        (album?.isEmpty ?? true) &&
        coverBytes == null) {
      return null;
    }
    return EmbeddedAudioMetadata(
      title: _normalized(title),
      artist: _normalized(artist),
      album: _normalized(album),
      coverBytes: coverBytes,
      coverExtension: coverExtension,
    );
  }

  static Map<String, String> _parseVorbisComments(Uint8List block) {
    final values = <String, String>{};
    if (block.length < 8) {
      return values;
    }

    var offset = 0;
    final vendorLength = _uint32Le(block, offset);
    offset += 4 + vendorLength;
    if (offset + 4 > block.length) {
      return values;
    }

    final commentCount = _uint32Le(block, offset);
    offset += 4;
    for (var index = 0; index < commentCount; index++) {
      if (offset + 4 > block.length) {
        break;
      }
      final commentLength = _uint32Le(block, offset);
      offset += 4;
      if (offset + commentLength > block.length) {
        break;
      }
      final raw = utf8.decode(
        block.sublist(offset, offset + commentLength),
        allowMalformed: true,
      );
      final separator = raw.indexOf('=');
      if (separator > 0) {
        final key = raw.substring(0, separator).trim().toUpperCase();
        final value = raw.substring(separator + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty && !values.containsKey(key)) {
          values[key] = value;
        }
      }
      offset += commentLength;
    }
    return values;
  }

  static (Uint8List, String)? _parseFlacPicture(Uint8List block) {
    if (block.length < 32) {
      return null;
    }
    var offset = 0;
    offset += 4; // picture type
    final mimeLength = _uint32Be(block, offset);
    offset += 4;
    if (offset + mimeLength > block.length) {
      return null;
    }
    final mime = ascii.decode(
      block.sublist(offset, offset + mimeLength),
      allowInvalid: true,
    );
    offset += mimeLength;
    final descriptionLength = _uint32Be(block, offset);
    offset += 4 + descriptionLength;
    if (offset + 20 > block.length) {
      return null;
    }
    offset += 16; // width height depth colors
    final dataLength = _uint32Be(block, offset);
    offset += 4;
    if (offset + dataLength > block.length) {
      return null;
    }
    return (
      Uint8List.fromList(block.sublist(offset, offset + dataLength)),
      _extensionForMime(mime),
    );
  }

  static (Uint8List, String)? _decodeApicFrame(Uint8List frame) {
    if (frame.length < 4) {
      return null;
    }
    final encoding = frame[0];
    var offset = 1;
    final mimeEnd = frame.indexOf(0, offset);
    if (mimeEnd < 0) {
      return null;
    }
    final mime = ascii.decode(
      frame.sublist(offset, mimeEnd),
      allowInvalid: true,
    );
    offset = mimeEnd + 1;
    if (offset >= frame.length) {
      return null;
    }

    offset += 1; // picture type
    offset = _skipEncodedString(frame, offset, encoding);
    if (offset >= frame.length) {
      return null;
    }

    return (Uint8List.fromList(frame.sublist(offset)), _extensionForMime(mime));
  }

  static String? _decodeTextFrame(Uint8List frame) {
    if (frame.isEmpty) {
      return null;
    }
    final encoding = frame[0];
    final content = frame.sublist(1);
    return _decodeEncodedString(content, encoding);
  }

  static String? _decodeEncodedString(Uint8List bytes, int encoding) {
    if (bytes.isEmpty) {
      return null;
    }
    try {
      switch (encoding) {
        case 0:
          return latin1.decode(bytes).replaceAll('\u0000', '').trim();
        case 1:
        case 2:
          final decoded = _decodeUtf16(bytes);
          return decoded.replaceAll('\u0000', '').trim();
        case 3:
          return utf8
              .decode(bytes, allowMalformed: true)
              .replaceAll('\u0000', '')
              .trim();
        default:
          return latin1.decode(bytes).replaceAll('\u0000', '').trim();
      }
    } catch (_) {
      return null;
    }
  }

  static String _decodeUtf16(Uint8List bytes) {
    if (bytes.length < 2) {
      return '';
    }
    final bomLe = bytes[0] == 0xff && bytes[1] == 0xfe;
    final bomBe = bytes[0] == 0xfe && bytes[1] == 0xff;
    final start = (bomLe || bomBe) ? 2 : 0;
    final codeUnits = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      final unit = bomBe
          ? (bytes[i] << 8) | bytes[i + 1]
          : (bytes[i + 1] << 8) | bytes[i];
      if (unit == 0) {
        continue;
      }
      codeUnits.add(unit);
    }
    return String.fromCharCodes(codeUnits);
  }

  static int _skipEncodedString(Uint8List bytes, int offset, int encoding) {
    if (encoding == 1 || encoding == 2) {
      for (var i = offset; i + 1 < bytes.length; i += 2) {
        if (bytes[i] == 0 && bytes[i + 1] == 0) {
          return i + 2;
        }
      }
      return bytes.length;
    }

    final end = bytes.indexOf(0, offset);
    return end < 0 ? bytes.length : end + 1;
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  static int _synchsafeInt(Uint8List bytes, int offset) {
    return ((bytes[offset] & 0x7f) << 21) |
        ((bytes[offset + 1] & 0x7f) << 14) |
        ((bytes[offset + 2] & 0x7f) << 7) |
        (bytes[offset + 3] & 0x7f);
  }

  static int _uint32Be(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static int _uint32Le(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static String _extensionForMime(String mime) {
    final normalized = mime.toLowerCase();
    if (normalized.contains('png')) {
      return '.png';
    }
    if (normalized.contains('webp')) {
      return '.webp';
    }
    return '.jpg';
  }

  static String? _normalized(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
