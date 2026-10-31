import 'dart:convert';
import 'dart:typed_data';

class EmbeddedAudioMetadata {
  const EmbeddedAudioMetadata({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.composer,
    this.comment,
    this.lyrics,
    this.trackNumber,
    this.trackTotal,
    this.discNumber,
    this.discTotal,
    this.coverBytes,
    this.coverExtension,
  });

  final String? title;
  final String? artist;
  final String? album;
  final String? albumArtist;
  final String? genre;
  final String? year;
  final String? composer;
  final String? comment;
  final String? lyrics;
  final int? trackNumber;
  final int? trackTotal;
  final int? discNumber;
  final int? discTotal;
  final Uint8List? coverBytes;
  final String? coverExtension;

  bool get hasTextualMetadata => [
    title,
    artist,
    album,
    albumArtist,
    genre,
    year,
    composer,
    comment,
    lyrics,
  ].any((value) => value?.trim().isNotEmpty == true);

  bool get hasStructuredMetadata =>
      trackNumber != null ||
      trackTotal != null ||
      discNumber != null ||
      discTotal != null;

  bool get hasCover => coverBytes?.isNotEmpty == true;

  bool get hasAnyMetadata =>
      hasTextualMetadata || hasStructuredMetadata || hasCover;
}

class AudioEmbeddedMetadataReader {
  /// Returns the bounded prefix needed to include a top-level MP4 moov box.
  static int? requiredMp4HeadBytes(Uint8List bytes, {required int maxBytes}) {
    var offset = 0;
    while (offset + 8 <= bytes.length) {
      var size = _uint32Be(bytes, offset);
      final type = latin1.decode(bytes.sublist(offset + 4, offset + 8));
      var headerSize = 8;
      if (size == 1) {
        if (offset + 16 > bytes.length) return null;
        size = _uint64Be(bytes, offset + 8);
        headerSize = 16;
      }
      if (size < headerSize) return null;
      final end = offset + size;
      if (type == 'moov') {
        return end > bytes.length && end <= maxBytes ? end : null;
      }
      if (end > bytes.length) return null;
      offset = end;
    }
    return null;
  }

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
    if (_looksLikeOgg(bytes) ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.oga') ||
        lower.endsWith('.opus')) {
      return _parseOgg(bytes);
    }
    if (_looksLikeMp4(bytes) ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.alac')) {
      return _parseMp4(bytes);
    }
    if (_looksLikeWav(bytes) || lower.endsWith('.wav')) {
      return _parseWav(bytes);
    }
    if (_looksLikeAiff(bytes) ||
        lower.endsWith('.aif') ||
        lower.endsWith('.aiff')) {
      return _parseAiff(bytes);
    }
    if (_looksLikeWma(bytes) || lower.endsWith('.wma')) {
      return _parseWma(bytes);
    }
    if (_findBytes(bytes, 'APETAGEX'.codeUnits) >= 0 ||
        lower.endsWith('.ape') ||
        lower.endsWith('.wv')) {
      return _parseApe(bytes);
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
    String? albumArtist;
    String? genre;
    String? year;
    String? composer;
    String? comment;
    String? lyrics;
    int? trackNumber;
    int? trackTotal;
    int? discNumber;
    int? discTotal;
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
        case 'TPE2':
          albumArtist ??= _decodeTextFrame(content);
          break;
        case 'TCON':
          genre ??= _decodeTextFrame(content);
          break;
        case 'TDRC':
        case 'TYER':
          year ??= _decodeTextFrame(content);
          break;
        case 'TCOM':
          composer ??= _decodeTextFrame(content);
          break;
        case 'COMM':
          comment ??= _decodeCommentFrame(content);
          break;
        case 'USLT':
          lyrics ??= _decodeLyricsFrame(content);
          break;
        case 'TRCK':
          final pair = _parsePositionValue(_decodeTextFrame(content));
          trackNumber ??= pair.$1;
          trackTotal ??= pair.$2;
          break;
        case 'TPOS':
          final pair = _parsePositionValue(_decodeTextFrame(content));
          discNumber ??= pair.$1;
          discTotal ??= pair.$2;
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

    return _buildMetadata(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genre,
      year: year,
      composer: composer,
      comment: comment,
      lyrics: lyrics,
      trackNumber: trackNumber,
      trackTotal: trackTotal,
      discNumber: discNumber,
      discTotal: discTotal,
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
    String? albumArtist;
    String? genre;
    String? year;
    String? composer;
    String? comment;
    String? lyrics;
    int? trackNumber;
    int? trackTotal;
    int? discNumber;
    int? discTotal;
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
        albumArtist ??= _firstComment(vorbis, ['ALBUMARTIST', 'ALBUM ARTIST']);
        genre ??= vorbis['GENRE'];
        year ??= _firstComment(vorbis, ['DATE', 'YEAR']);
        composer ??= vorbis['COMPOSER'];
        comment ??= vorbis['COMMENT'];
        lyrics ??= _firstComment(vorbis, ['LYRICS', 'UNSYNCEDLYRICS']);
        trackNumber ??= _parseIntValue(vorbis['TRACKNUMBER']);
        trackTotal ??= _parseIntValue(vorbis['TRACKTOTAL']);
        discNumber ??= _parseIntValue(vorbis['DISCNUMBER']);
        discTotal ??= _parseIntValue(vorbis['DISCTOTAL']);
      } else if (blockType == 6) {
        final picture = _parseFlacPicture(block);
        if (picture != null) {
          coverBytes ??= picture.$1;
          coverExtension ??= picture.$2;
        }
      }
      offset = blockEnd;
    }

    return _buildMetadata(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genre,
      year: year,
      composer: composer,
      comment: comment,
      lyrics: lyrics,
      trackNumber: trackNumber,
      trackTotal: trackTotal,
      discNumber: discNumber,
      discTotal: discTotal,
      coverBytes: coverBytes,
      coverExtension: coverExtension,
    );
  }

  static EmbeddedAudioMetadata? _parseMp4(Uint8List bytes) {
    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    String? year;
    String? composer;
    String? comment;
    String? lyrics;
    int? trackNumber;
    int? trackTotal;
    int? discNumber;
    int? discTotal;
    Uint8List? coverBytes;
    String? coverExtension;

    void parseContainer(int start, int end, {bool skipFullBoxHeader = false}) {
      var offset = start + (skipFullBoxHeader ? 4 : 0);
      while (offset + 8 <= end && offset + 8 <= bytes.length) {
        final atomSize = _uint32Be(bytes, offset);
        final atomType = latin1.decode(
          bytes.sublist(offset + 4, offset + 8),
          allowInvalid: true,
        );
        var headerSize = 8;
        var resolvedAtomSize = atomSize;
        if (atomSize == 1) {
          if (offset + 16 > end || offset + 16 > bytes.length) {
            break;
          }
          resolvedAtomSize = _uint64Be(bytes, offset + 8);
          headerSize = 16;
        } else if (atomSize == 0) {
          resolvedAtomSize = end - offset;
        }
        if (resolvedAtomSize < headerSize) {
          break;
        }

        final atomEnd = offset + resolvedAtomSize;
        if (atomEnd > end || atomEnd > bytes.length) {
          break;
        }

        final atomBodyStart = offset + headerSize;
        switch (atomType) {
          case 'moov':
          case 'udta':
          case 'ilst':
            parseContainer(atomBodyStart, atomEnd);
            break;
          case 'meta':
            parseContainer(atomBodyStart, atomEnd, skipFullBoxHeader: true);
            break;
          case 'trak':
          case 'mdia':
          case 'minf':
          case 'stbl':
            parseContainer(atomBodyStart, atomEnd);
            break;
          case '\u00a9nam':
            title ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case '\u00a9ART':
            artist ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case 'aART':
            albumArtist ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case '\u00a9alb':
            album ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case '\u00a9gen':
          case 'gnre':
            genre ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case '\u00a9day':
            year ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case '\u00a9wrt':
            composer ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case '\u00a9lyr':
            lyrics ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case '\u00a9cmt':
            comment ??= _decodeMp4TextAtom(bytes, atomBodyStart, atomEnd);
            break;
          case 'trkn':
            final pair = _decodeMp4IndexAtom(bytes, atomBodyStart, atomEnd);
            trackNumber ??= pair.$1;
            trackTotal ??= pair.$2;
            break;
          case 'disk':
            final pair = _decodeMp4IndexAtom(bytes, atomBodyStart, atomEnd);
            discNumber ??= pair.$1;
            discTotal ??= pair.$2;
            break;
          case 'covr':
            final picture = _decodeMp4CoverAtom(bytes, atomBodyStart, atomEnd);
            if (picture != null) {
              coverBytes ??= picture.$1;
              coverExtension ??= picture.$2;
            }
            break;
          default:
            break;
        }

        offset = atomEnd;
      }
    }

    parseContainer(0, bytes.length);

    return _buildMetadata(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genre,
      year: year,
      composer: composer,
      comment: comment,
      lyrics: lyrics,
      trackNumber: trackNumber,
      trackTotal: trackTotal,
      discNumber: discNumber,
      discTotal: discTotal,
      coverBytes: coverBytes,
      coverExtension: coverExtension,
    );
  }

  static EmbeddedAudioMetadata? _parseWav(Uint8List bytes) {
    if (!_looksLikeWav(bytes)) {
      return null;
    }

    String? title;
    String? artist;
    String? album;
    String? genre;
    String? year;
    String? composer;
    String? comment;
    int? trackNumber;
    EmbeddedAudioMetadata? id3Metadata;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = ascii.decode(
        bytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final chunkLength = _uint32Le(bytes, offset + 4);
      final chunkStart = offset + 8;
      final chunkEnd = chunkStart + chunkLength;
      if (chunkEnd > bytes.length) {
        break;
      }

      if ((chunkId == 'ID3 ' || chunkId == 'id3 ') &&
          bytes.length >= chunkStart + 10) {
        id3Metadata ??= _parseId3(bytes.sublist(chunkStart, chunkEnd));
      } else if (chunkId == 'LIST' &&
          chunkLength >= 4 &&
          ascii.decode(
                bytes.sublist(chunkStart, chunkStart + 4),
                allowInvalid: true,
              ) ==
              'INFO') {
        var infoOffset = chunkStart + 4;
        while (infoOffset + 8 <= chunkEnd) {
          final infoId = ascii.decode(
            bytes.sublist(infoOffset, infoOffset + 4),
            allowInvalid: true,
          );
          final infoLength = _uint32Le(bytes, infoOffset + 4);
          final infoStart = infoOffset + 8;
          final infoEnd = infoStart + infoLength;
          if (infoEnd > chunkEnd) {
            break;
          }
          final value = _decodeLatin1Trimmed(bytes.sublist(infoStart, infoEnd));
          switch (infoId) {
            case 'INAM':
              title ??= value;
              break;
            case 'IART':
              artist ??= value;
              break;
            case 'IPRD':
              album ??= value;
              break;
            case 'IGNR':
              genre ??= value;
              break;
            case 'ICRD':
              year ??= value;
              break;
            case 'IENG':
              composer ??= value;
              break;
            case 'ICMT':
              comment ??= value;
              break;
            case 'ITRK':
              trackNumber ??= _parseIntValue(value);
              break;
            default:
              break;
          }
          infoOffset = infoEnd + (infoLength.isOdd ? 1 : 0);
        }
      }

      offset = chunkEnd + (chunkLength.isOdd ? 1 : 0);
    }

    if (id3Metadata != null) {
      return _buildMetadata(
        title: id3Metadata.title ?? title,
        artist: id3Metadata.artist ?? artist,
        album: id3Metadata.album ?? album,
        albumArtist: id3Metadata.albumArtist,
        genre: id3Metadata.genre ?? genre,
        year: id3Metadata.year ?? year,
        composer: id3Metadata.composer ?? composer,
        comment: id3Metadata.comment ?? comment,
        lyrics: id3Metadata.lyrics,
        trackNumber: id3Metadata.trackNumber ?? trackNumber,
        trackTotal: id3Metadata.trackTotal,
        discNumber: id3Metadata.discNumber,
        discTotal: id3Metadata.discTotal,
        coverBytes: id3Metadata.coverBytes,
        coverExtension: id3Metadata.coverExtension,
      );
    }

    return _buildMetadata(
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      year: year,
      composer: composer,
      comment: comment,
      trackNumber: trackNumber,
    );
  }

  static EmbeddedAudioMetadata? _parseAiff(Uint8List bytes) {
    if (!_looksLikeAiff(bytes)) {
      return null;
    }

    String? title;
    String? artist;
    String? comment;
    EmbeddedAudioMetadata? id3Metadata;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = ascii.decode(
        bytes.sublist(offset, offset + 4),
        allowInvalid: true,
      );
      final chunkLength = _uint32Be(bytes, offset + 4);
      final chunkStart = offset + 8;
      final chunkEnd = chunkStart + chunkLength;
      if (chunkEnd > bytes.length) {
        break;
      }

      switch (chunkId) {
        case 'ID3 ':
        case 'id3 ':
          if (chunkLength >= 10) {
            id3Metadata ??= _parseId3(bytes.sublist(chunkStart, chunkEnd));
          }
          break;
        case 'NAME':
          title ??= _decodeAiffTextChunk(bytes.sublist(chunkStart, chunkEnd));
          break;
        case 'AUTH':
          artist ??= _decodeAiffTextChunk(bytes.sublist(chunkStart, chunkEnd));
          break;
        case 'ANNO':
          comment ??= _decodeAiffTextChunk(bytes.sublist(chunkStart, chunkEnd));
          break;
        default:
          break;
      }

      offset = chunkEnd + (chunkLength.isOdd ? 1 : 0);
    }

    if (id3Metadata != null) {
      return _buildMetadata(
        title: id3Metadata.title ?? title,
        artist: id3Metadata.artist ?? artist,
        album: id3Metadata.album,
        albumArtist: id3Metadata.albumArtist,
        genre: id3Metadata.genre,
        year: id3Metadata.year,
        composer: id3Metadata.composer,
        comment: id3Metadata.comment ?? comment,
        lyrics: id3Metadata.lyrics,
        trackNumber: id3Metadata.trackNumber,
        trackTotal: id3Metadata.trackTotal,
        discNumber: id3Metadata.discNumber,
        discTotal: id3Metadata.discTotal,
        coverBytes: id3Metadata.coverBytes,
        coverExtension: id3Metadata.coverExtension,
      );
    }

    return _buildMetadata(title: title, artist: artist, comment: comment);
  }

  static EmbeddedAudioMetadata? _parseApe(Uint8List bytes) {
    final tagOffset = _findBytes(bytes, 'APETAGEX'.codeUnits);
    if (tagOffset < 0 || bytes.length < tagOffset + 32) {
      return null;
    }

    final tagSize = _uint32Le(bytes, tagOffset + 12);
    final itemCount = _uint32Le(bytes, tagOffset + 16);
    final tagEnd = tagSize > 0 && tagOffset + tagSize <= bytes.length
        ? tagOffset + tagSize
        : bytes.length;

    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    String? year;
    String? composer;
    String? comment;
    String? lyrics;
    int? trackNumber;
    int? trackTotal;
    int? discNumber;
    int? discTotal;
    Uint8List? coverBytes;
    String? coverExtension;

    var offset = tagOffset + 32;
    for (var index = 0; index < itemCount && offset + 8 <= tagEnd; index++) {
      final valueLength = _uint32Le(bytes, offset);
      final flags = _uint32Le(bytes, offset + 4);
      final keyStart = offset + 8;
      final keyEnd = bytes.indexOf(0, keyStart);
      if (keyEnd < 0 || keyEnd >= tagEnd) {
        break;
      }
      final valueStart = keyEnd + 1;
      final valueEnd = valueStart + valueLength;
      if (valueEnd > tagEnd || valueEnd > bytes.length) {
        break;
      }

      final key = utf8
          .decode(bytes.sublist(keyStart, keyEnd), allowMalformed: true)
          .trim()
          .toLowerCase();
      final isBinary = (flags & 0x00000006) != 0;
      final valueBytes = bytes.sublist(valueStart, valueEnd);
      if (key == 'cover art (front)' && valueBytes.isNotEmpty) {
        final separator = valueBytes.indexOf(0);
        final imageBytes = separator >= 0
            ? valueBytes.sublist(separator + 1)
            : valueBytes;
        if (imageBytes.isNotEmpty) {
          coverBytes ??= Uint8List.fromList(imageBytes);
          coverExtension ??= _extensionForImageData(imageBytes);
        }
      } else if (!isBinary) {
        final value = utf8.decode(valueBytes, allowMalformed: true).trim();
        switch (key) {
          case 'title':
            title ??= value;
            break;
          case 'artist':
            artist ??= value;
            break;
          case 'album':
            album ??= value;
            break;
          case 'album artist':
            albumArtist ??= value;
            break;
          case 'genre':
            genre ??= value;
            break;
          case 'year':
            year ??= value;
            break;
          case 'composer':
            composer ??= value;
            break;
          case 'comment':
            comment ??= value;
            break;
          case 'lyrics':
            lyrics ??= value;
            break;
          case 'track':
            final pair = _parsePositionValue(value);
            trackNumber ??= pair.$1;
            trackTotal ??= pair.$2;
            break;
          case 'disc':
            final pair = _parsePositionValue(value);
            discNumber ??= pair.$1;
            discTotal ??= pair.$2;
            break;
          default:
            break;
        }
      }

      offset = valueEnd;
    }

    return _buildMetadata(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genre,
      year: year,
      composer: composer,
      comment: comment,
      lyrics: lyrics,
      trackNumber: trackNumber,
      trackTotal: trackTotal,
      discNumber: discNumber,
      discTotal: discTotal,
      coverBytes: coverBytes,
      coverExtension: coverExtension,
    );
  }

  static EmbeddedAudioMetadata? _parseOgg(Uint8List bytes) {
    final packets = _collectOggPackets(bytes);
    if (packets.isEmpty) {
      return null;
    }

    for (final packet in packets) {
      if (packet.length > 7 &&
          packet[0] == 0x03 &&
          ascii.decode(packet.sublist(1, 7), allowInvalid: true) == 'vorbis') {
        final comments = _parseVorbisComments(packet.sublist(7));
        return _buildMetadataFromVorbisComments(comments);
      }

      if (packet.length > 8 &&
          ascii.decode(packet.sublist(0, 8), allowInvalid: true) ==
              'OpusTags') {
        final comments = _parseVorbisComments(packet.sublist(8));
        return _buildMetadataFromVorbisComments(comments);
      }
    }

    return null;
  }

  static EmbeddedAudioMetadata? _parseWma(Uint8List bytes) {
    if (!_looksLikeWma(bytes) || bytes.length < 30) {
      return null;
    }

    String? title;
    String? artist;
    String? album;
    String? albumArtist;
    String? genre;
    String? year;
    String? composer;
    String? comment;
    String? lyrics;
    int? trackNumber;
    int? discNumber;

    var offset = 30;
    while (offset + 24 <= bytes.length) {
      final objectGuid = bytes.sublist(offset, offset + 16);
      final objectSize = _uint64Le(bytes, offset + 16);
      if (objectSize < 24) {
        break;
      }
      final objectEnd = offset + objectSize;
      if (objectEnd > bytes.length) {
        break;
      }

      if (_guidEquals(objectGuid, _asfContentDescriptionGuid)) {
        if (offset + 34 > objectEnd) {
          break;
        }
        final titleLength = _uint16Le(bytes, offset + 24);
        final authorLength = _uint16Le(bytes, offset + 26);
        final copyrightLength = _uint16Le(bytes, offset + 28);
        final descriptionLength = _uint16Le(bytes, offset + 30);
        final ratingLength = _uint16Le(bytes, offset + 32);
        var valueOffset = offset + 34;
        title ??= _decodeUtf16Le(bytes, valueOffset, titleLength);
        valueOffset += titleLength;
        artist ??= _decodeUtf16Le(bytes, valueOffset, authorLength);
        valueOffset += authorLength + copyrightLength;
        comment ??= _decodeUtf16Le(bytes, valueOffset, descriptionLength);
        valueOffset += descriptionLength + ratingLength;
      } else if (_guidEquals(objectGuid, _asfExtendedContentDescriptionGuid)) {
        if (offset + 26 > objectEnd) {
          break;
        }
        final contentCount = _uint16Le(bytes, offset + 24);
        var descriptorOffset = offset + 26;
        for (
          var index = 0;
          index < contentCount && descriptorOffset + 6 <= objectEnd;
          index++
        ) {
          final nameLength = _uint16Le(bytes, descriptorOffset);
          descriptorOffset += 2;
          final name = _decodeUtf16Le(bytes, descriptorOffset, nameLength);
          descriptorOffset += nameLength;
          if (descriptorOffset + 4 > objectEnd) {
            break;
          }
          final valueType = _uint16Le(bytes, descriptorOffset);
          final valueLength = _uint16Le(bytes, descriptorOffset + 2);
          descriptorOffset += 4;
          if (descriptorOffset + valueLength > objectEnd) {
            break;
          }
          final value = _decodeAsfAttributeValue(
            bytes.sublist(descriptorOffset, descriptorOffset + valueLength),
            valueType,
          );
          descriptorOffset += valueLength;
          if (name == null || value == null) {
            continue;
          }

          switch (name) {
            case 'WM/AlbumTitle':
              album ??= value;
              break;
            case 'WM/AlbumArtist':
              albumArtist ??= value;
              break;
            case 'WM/Genre':
              genre ??= value;
              break;
            case 'WM/Year':
              year ??= value;
              break;
            case 'WM/Composer':
              composer ??= value;
              break;
            case 'WM/TrackNumber':
            case 'WM/Track':
              trackNumber ??= _parseIntValue(value);
              break;
            case 'WM/PartOfSet':
              discNumber ??= _parseIntValue(value);
              break;
            case 'WM/Lyrics':
            case 'WM/LYRICS':
            case 'WM/UnsynchronizedLyrics':
              lyrics ??= value;
              break;
            case 'Description':
              comment ??= value;
              break;
            default:
              break;
          }
        }
      }

      offset = objectEnd;
    }

    return _buildMetadata(
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genre,
      year: year,
      composer: composer,
      comment: comment,
      lyrics: lyrics,
      trackNumber: trackNumber,
      discNumber: discNumber,
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
    offset += 4;
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
    offset += 16;
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

    offset += 1;
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

  static String? _decodeCommentFrame(Uint8List frame) {
    if (frame.length < 5) {
      return null;
    }
    final encoding = frame[0];
    var offset = 4;
    offset = _skipEncodedString(frame, offset, encoding);
    if (offset >= frame.length) {
      return null;
    }
    return _decodeEncodedString(frame.sublist(offset), encoding);
  }

  static String? _decodeLyricsFrame(Uint8List frame) {
    if (frame.length < 5) {
      return null;
    }
    final encoding = frame[0];
    var offset = 4;
    offset = _skipEncodedString(frame, offset, encoding);
    if (offset >= frame.length) {
      return null;
    }
    return _decodeEncodedString(frame.sublist(offset), encoding);
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

  static String? _decodeUtf16Le(List<int> bytes, int start, int length) {
    if (length <= 0 || start < 0 || start + length > bytes.length) {
      return null;
    }
    final slice = Uint8List.fromList(bytes.sublist(start, start + length));
    return _normalized(_decodeUtf16(slice));
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

  static EmbeddedAudioMetadata? _buildMetadataFromVorbisComments(
    Map<String, String> comments,
  ) {
    final trackPair = _parsePositionValue(
      _firstComment(comments, ['TRACKNUMBER', 'TRACK']),
    );
    final discPair = _parsePositionValue(
      _firstComment(comments, ['DISCNUMBER', 'DISC']),
    );
    return _buildMetadata(
      title: comments['TITLE'],
      artist: comments['ARTIST'],
      album: comments['ALBUM'],
      albumArtist: _firstComment(comments, ['ALBUMARTIST', 'ALBUM ARTIST']),
      genre: comments['GENRE'],
      year: _firstComment(comments, ['DATE', 'YEAR']),
      composer: comments['COMPOSER'],
      comment: comments['COMMENT'],
      lyrics: _firstComment(comments, ['LYRICS', 'UNSYNCEDLYRICS']),
      trackNumber: trackPair.$1,
      trackTotal: trackPair.$2 ?? _parseIntValue(comments['TRACKTOTAL']),
      discNumber: discPair.$1,
      discTotal: discPair.$2 ?? _parseIntValue(comments['DISCTOTAL']),
    );
  }

  static String? _decodeMp4TextAtom(Uint8List bytes, int start, int end) {
    var offset = start;
    while (offset + 16 <= end && offset + 16 <= bytes.length) {
      final atomSize = _uint32Be(bytes, offset);
      final atomType = ascii.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      if (atomSize < 16 ||
          offset + atomSize > end ||
          offset + atomSize > bytes.length) {
        break;
      }
      if (atomType == 'data') {
        final payload = bytes.sublist(offset + 16, offset + atomSize);
        final decoded = utf8
            .decode(payload, allowMalformed: true)
            .replaceAll('\u0000', '');
        return _normalized(decoded);
      }
      offset += atomSize;
    }
    return null;
  }

  static (int?, int?) _decodeMp4IndexAtom(Uint8List bytes, int start, int end) {
    var offset = start;
    while (offset + 24 <= end && offset + 24 <= bytes.length) {
      final atomSize = _uint32Be(bytes, offset);
      final atomType = ascii.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      if (atomSize < 24 ||
          offset + atomSize > end ||
          offset + atomSize > bytes.length) {
        break;
      }
      if (atomType == 'data') {
        final payload = bytes.sublist(offset + 16, offset + atomSize);
        if (payload.length >= 6) {
          return (_uint16Be(payload, 2), _uint16Be(payload, 4));
        }
      }
      offset += atomSize;
    }
    return (null, null);
  }

  static (Uint8List, String)? _decodeMp4CoverAtom(
    Uint8List bytes,
    int start,
    int end,
  ) {
    var offset = start;
    while (offset + 16 <= end && offset + 16 <= bytes.length) {
      final atomSize = _uint32Be(bytes, offset);
      final atomType = ascii.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      if (atomSize < 16 ||
          offset + atomSize > end ||
          offset + atomSize > bytes.length) {
        break;
      }
      if (atomType == 'data') {
        final dataType = _uint32Be(bytes, offset + 12);
        final payload = bytes.sublist(offset + 16, offset + atomSize);
        if (payload.isNotEmpty) {
          return (
            Uint8List.fromList(payload),
            switch (dataType) {
              14 => '.png',
              13 => '.jpg',
              _ => _extensionForImageData(payload),
            },
          );
        }
      }
      offset += atomSize;
    }
    return null;
  }

  static EmbeddedAudioMetadata? _buildMetadata({
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    String? genre,
    String? year,
    String? composer,
    String? comment,
    String? lyrics,
    int? trackNumber,
    int? trackTotal,
    int? discNumber,
    int? discTotal,
    Uint8List? coverBytes,
    String? coverExtension,
  }) {
    final metadata = EmbeddedAudioMetadata(
      title: _normalized(title),
      artist: _normalized(artist),
      album: _normalized(album),
      albumArtist: _normalized(albumArtist),
      genre: _normalized(genre),
      year: _normalized(year),
      composer: _normalized(composer),
      comment: _normalized(comment),
      lyrics: _normalized(lyrics),
      trackNumber: trackNumber,
      trackTotal: trackTotal,
      discNumber: discNumber,
      discTotal: discTotal,
      coverBytes: coverBytes,
      coverExtension: coverExtension,
    );
    return metadata.hasAnyMetadata ? metadata : null;
  }

  static String? _firstComment(Map<String, String> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key];
      if (value?.trim().isNotEmpty == true) {
        return value!.trim();
      }
    }
    return null;
  }

  static (int?, int?) _parsePositionValue(String? value) {
    final normalized = _normalized(value);
    if (normalized == null) {
      return (null, null);
    }
    final parts = normalized.split('/');
    final current = _parseIntValue(parts.first);
    final total = parts.length >= 2 ? _parseIntValue(parts[1]) : null;
    return (current, total);
  }

  static int? _parseIntValue(String? value) {
    final match = RegExp(r'\d+').firstMatch(value ?? '');
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(0)!);
  }

  static String _decodeLatin1Trimmed(List<int> bytes) {
    return latin1.decode(bytes).replaceAll('\u0000', '').trim();
  }

  static bool _looksLikeMp4(Uint8List bytes) {
    return bytes.length >= 12 &&
        latin1.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp';
  }

  static bool _looksLikeWav(Uint8List bytes) {
    return bytes.length >= 12 &&
        _startsWith(bytes, 'RIFF'.codeUnits) &&
        latin1.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WAVE';
  }

  static bool _looksLikeAiff(Uint8List bytes) {
    if (bytes.length < 12 || !_startsWith(bytes, 'FORM'.codeUnits)) {
      return false;
    }
    final formType = latin1.decode(bytes.sublist(8, 12), allowInvalid: true);
    return formType == 'AIFF' || formType == 'AIFC';
  }

  static bool _looksLikeOgg(Uint8List bytes) {
    return bytes.length >= 4 && _startsWith(bytes, 'OggS'.codeUnits);
  }

  static bool _looksLikeWma(Uint8List bytes) {
    return bytes.length >= 16 &&
        _guidEquals(bytes.sublist(0, 16), _asfHeaderGuid);
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

  static int _uint16Be(List<int> bytes, int offset) {
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  static int _uint16Le(List<int> bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static int _uint32Be(List<int> bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static int _uint32Le(List<int> bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static int _uint64Be(List<int> bytes, int offset) {
    return (bytes[offset] << 56) |
        (bytes[offset + 1] << 48) |
        (bytes[offset + 2] << 40) |
        (bytes[offset + 3] << 32) |
        (bytes[offset + 4] << 24) |
        (bytes[offset + 5] << 16) |
        (bytes[offset + 6] << 8) |
        bytes[offset + 7];
  }

  static int _uint64Le(List<int> bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24) |
        (bytes[offset + 4] << 32) |
        (bytes[offset + 5] << 40) |
        (bytes[offset + 6] << 48) |
        (bytes[offset + 7] << 56);
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

  static String _extensionForImageData(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return '.jpg';
    }
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return '.webp';
    }
    return '.jpg';
  }

  static String? _normalized(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _decodeAiffTextChunk(List<int> bytes) {
    return _normalized(utf8.decode(bytes, allowMalformed: true));
  }

  static List<Uint8List> _collectOggPackets(Uint8List bytes) {
    final packets = <Uint8List>[];
    var currentPacket = BytesBuilder(copy: false);
    var offset = 0;

    while (offset + 27 <= bytes.length && packets.length < 8) {
      if (ascii.decode(bytes.sublist(offset, offset + 4), allowInvalid: true) !=
          'OggS') {
        break;
      }
      final segmentCount = bytes[offset + 26];
      final segmentTableStart = offset + 27;
      final segmentTableEnd = segmentTableStart + segmentCount;
      if (segmentTableEnd > bytes.length) {
        break;
      }

      var payloadOffset = segmentTableEnd;
      for (var index = 0; index < segmentCount; index++) {
        final segmentLength = bytes[segmentTableStart + index];
        if (payloadOffset + segmentLength > bytes.length) {
          return packets;
        }
        currentPacket.add(
          bytes.sublist(payloadOffset, payloadOffset + segmentLength),
        );
        payloadOffset += segmentLength;
        if (segmentLength < 255) {
          packets.add(currentPacket.takeBytes());
          if (packets.length >= 8) {
            return packets;
          }
          currentPacket = BytesBuilder(copy: false);
        }
      }

      offset = payloadOffset;
    }

    return packets;
  }

  static String? _decodeAsfAttributeValue(List<int> bytes, int type) {
    switch (type) {
      case 0:
        return _normalized(_decodeUtf16(Uint8List.fromList(bytes)));
      case 1:
        return null;
      case 2:
        return bytes.isNotEmpty && bytes.first != 0 ? '1' : '0';
      case 3:
        return bytes.length >= 4 ? _uint32Le(bytes, 0).toString() : null;
      case 4:
        return bytes.length >= 8 ? _uint64Le(bytes, 0).toString() : null;
      case 5:
        return bytes.length >= 2 ? _uint16Le(bytes, 0).toString() : null;
      default:
        return null;
    }
  }

  static int _findBytes(List<int> bytes, List<int> needle) {
    if (needle.isEmpty || bytes.length < needle.length) {
      return -1;
    }
    for (var offset = 0; offset <= bytes.length - needle.length; offset++) {
      var matched = true;
      for (var index = 0; index < needle.length; index++) {
        if (bytes[offset + index] != needle[index]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return offset;
      }
    }
    return -1;
  }

  static bool _guidEquals(List<int> bytes, List<int> guid) {
    if (bytes.length < guid.length) {
      return false;
    }
    for (var index = 0; index < guid.length; index++) {
      if (bytes[index] != guid[index]) {
        return false;
      }
    }
    return true;
  }

  static const List<int> _asfHeaderGuid = [
    0x30,
    0x26,
    0xB2,
    0x75,
    0x8E,
    0x66,
    0xCF,
    0x11,
    0xA6,
    0xD9,
    0x00,
    0xAA,
    0x00,
    0x62,
    0xCE,
    0x6C,
  ];

  static const List<int> _asfContentDescriptionGuid = [
    0x33,
    0x26,
    0xB2,
    0x75,
    0x8E,
    0x66,
    0xCF,
    0x11,
    0xA6,
    0xD9,
    0x00,
    0xAA,
    0x00,
    0x62,
    0xCE,
    0x6C,
  ];

  static const List<int> _asfExtendedContentDescriptionGuid = [
    0x40,
    0xA4,
    0xD0,
    0xD2,
    0x07,
    0xE3,
    0xD2,
    0x11,
    0x97,
    0xF0,
    0x00,
    0xA0,
    0xC9,
    0x5E,
    0xA8,
    0x50,
  ];
}
