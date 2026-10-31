import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/utils/audio_embedded_metadata_reader.dart';

/// Isolated reproduction of the cloud189 "AppleMusic版本" M4A report.
///
/// Hand-crafted MP4/M4A byte fixtures only: no product code is modified and no
/// network, device or real media file is involved.
///
/// The production reader is handed a byte buffer and must find `moov` entirely
/// inside it (`atomEnd > bytes.length` aborts the walk). Library scanning feeds
/// it only the first 128 KiB and playback only the first 256 KiB, so an MP4
/// whose `moov` sits *after* a large `mdat` yields no tags at all.

const int _libraryHeadBytes = 128 * 1024;
const int _playerHeadBytes = 256 * 1024;

/// 300 KiB of payload, comfortably larger than either head window.
const int _largeMdatPayload = 300 * 1024;

Uint8List _u32(int value) => Uint8List(4)..buffer.asByteData().setUint32(
  0,
  value,
  Endian.big,
);

Uint8List _atom(String type, List<int> payload) {
  // Atom types are latin1 on disk; `©nam` is byte 0xA9 followed by 'nam'.
  final header = <int>[..._u32(8 + payload.length), ...latin1.encode(type)];
  return Uint8List.fromList([...header, ...payload]);
}

Uint8List _concat(List<List<int>> parts) =>
    Uint8List.fromList([for (final part in parts) ...part]);

/// `data` box: size(4) type(4) version/flags(4) locale(4) payload.
Uint8List _dataAtom(List<int> payload, {int typeCode = 1}) => _atom('data', [
  ..._u32(0),
  ..._u32(typeCode),
  ...payload,
]);

/// Text tag such as `©nam`, `©ART`, `©alb`, `©lyr`.
Uint8List _textAtom(String name, String value) =>
    _atom(name, _dataAtom(utf8.encode(value)));

Uint8List _ftyp() => _atom('ftyp', [
  ...ascii.encode('M4A '),
  ..._u32(0),
  ...ascii.encode('M4A '),
  ...ascii.encode('isom'),
]);

Uint8List _moov() {
  final ilst = _atom('ilst', _concat([
    _textAtom('\u00a9nam', '太阳之子'),
    _textAtom('\u00a9ART', '周杰伦'),
    _textAtom('\u00a9alb', '最伟大的作品'),
    _textAtom('\u00a9lyr', '太阳之子 - 测试歌词\n第二行'),
  ]));
  // `meta` is a full box: 4 bytes of version/flags precede its children.
  final meta = _atom('meta', [..._u32(0), ...ilst]);
  final udta = _atom('udta', meta);
  return _atom('moov', udta);
}

Uint8List _mdat(int payloadBytes) =>
    _atom('mdat', Uint8List(payloadBytes));

/// `moov` first, then a large `mdat` (faststart layout).
Uint8List _moovAtFront() => _concat([_ftyp(), _moov(), _mdat(_largeMdatPayload)]);

/// Large `mdat` first, then `moov` at the very end (typical of un-optimised
/// M4A/ALAC exports and of cloud "App Music" transcodes).
Uint8List _moovAtEnd() => _concat([_ftyp(), _mdat(_largeMdatPayload), _moov()]);

Uint8List _head(Uint8List bytes, int length) =>
    Uint8List.sublistView(bytes, 0, length);

void main() {
  group('MP4/M4A embedded metadata layout', () {
    test('moov at front, whole file: title/artist/album/lyrics parsed', () {
      final file = _moovAtFront();
      final metadata = AudioEmbeddedMetadataReader.parse(
        file,
        fileName: '01. 太阳之子.m4a',
      );

      expect(metadata, isNotNull);
      expect(metadata!.title, '太阳之子');
      expect(metadata.artist, '周杰伦');
      expect(metadata.album, '最伟大的作品');
      expect(metadata.lyrics, contains('测试歌词'));
    });

    test('moov after large mdat, whole file: metadata still parsed', () {
      final file = _moovAtEnd();
      final metadata = AudioEmbeddedMetadataReader.parse(
        file,
        fileName: '01. 太阳之子.m4a',
      );

      expect(metadata, isNotNull);
      expect(metadata!.title, '太阳之子');
      expect(metadata.album, '最伟大的作品');
      expect(metadata.lyrics, contains('测试歌词'));
    });

    test(
      'moov at front, first 128 KiB only: metadata parsed (layout control)',
      () {
        final file = _moovAtFront();
        expect(file.length, greaterThan(_libraryHeadBytes));

        final metadata = AudioEmbeddedMetadataReader.parse(
          _head(file, _libraryHeadBytes),
          fileName: '01. 太阳之子.m4a',
        );

        expect(metadata, isNotNull);
        expect(metadata!.title, '太阳之子');
      },
    );

    test(
      'moov after large mdat, first 128 KiB only: no metadata at all',
      () {
        final file = _moovAtEnd();
        final head = _head(file, _libraryHeadBytes);

        // The head window ends inside `mdat`; `moov` starts past it.
        final moovOffset = _indexOfMoov(file);
        expect(moovOffset, greaterThanOrEqualTo(_libraryHeadBytes));

        final metadata = AudioEmbeddedMetadataReader.parse(
          head,
          fileName: '01. 太阳之子.m4a',
        );

        expect(metadata, isNull);
      },
    );

    test(
      'moov after large mdat, first 256 KiB only: playback-side read also empty',
      () {
        final file = _moovAtEnd();
        final head = _head(file, _playerHeadBytes);

        final metadata = AudioEmbeddedMetadataReader.parse(
          head,
          fileName: '01. 太阳之子.m4a',
        );

        expect(metadata, isNull);
      },
    );

    test('moov at end stays unreachable for every head length up to mdat end',
        () {
      final file = _moovAtEnd();
      final moovOffset = _indexOfMoov(file);

      // Mirrors the real files: mdat alone (40-70 MB) dwarfs any head read.
      for (final length in <int>[
        32 * 1024,
        _libraryHeadBytes,
        _playerHeadBytes,
        moovOffset - 1,
      ]) {
        final metadata = AudioEmbeddedMetadataReader.parse(
          _head(file, length),
          fileName: '01. 太阳之子.m4a',
        );
        expect(metadata, isNull, reason: 'head length $length should be empty');
      }

      // Only a buffer that reaches the trailing moov recovers the tags.
      final full = AudioEmbeddedMetadataReader.parse(
        _head(file, moovOffset + _moov().length),
        fileName: '01. 太阳之子.m4a',
      );
      expect(full?.title, '太阳之子');
    });
  });
}

int _indexOfMoov(Uint8List bytes) {
  final needle = ascii.encode('moov');
  for (var i = 0; i + 4 <= bytes.length; i++) {
    if (bytes[i] == needle[0] &&
        bytes[i + 1] == needle[1] &&
        bytes[i + 2] == needle[2] &&
        bytes[i + 3] == needle[3]) {
      return i - 4;
    }
  }
  return -1;
}
