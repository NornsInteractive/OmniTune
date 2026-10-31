// Contract tests for the planned AudioEmbeddedMetadataReader.requiredMp4HeadBytes.
//
// The API does not exist yet: this file is expected to fail to compile until it
// lands. No product code is edited here and no real/copyrighted media is used -
// every fixture is hand-built below.
//
// Contract under test:
//   static int? requiredMp4HeadBytes(Uint8List bytes, {required int maxBytes})
//   * returns null when moov is already fully inside `bytes`
//   * returns the absolute byte length needed to contain the whole moov when the
//     top-level moov header is visible, its body is truncated, and that length
//     is <= maxBytes
//   * returns null when the requirement cannot be bounded: invalid or truncated
//     box header, moov header not reachable inside `bytes`, 64-bit size that
//     overflows or exceeds maxBytes, or moov larger than maxBytes

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/utils/audio_embedded_metadata_reader.dart';

Uint8List _u32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.big);

Uint8List _u64(int v) =>
    Uint8List(8)..buffer.asByteData().setUint64(0, v, Endian.big);

Uint8List _atom(String type, List<int> payload) => Uint8List.fromList([
  ..._u32(8 + payload.length),
  ...latin1.encode(type),
  ...payload,
]);

/// 64-bit atom: size32 == 1, type, largesize (header included).
Uint8List _largeAtom(String type, int declared, List<int> payload) =>
    Uint8List.fromList([
      ..._u32(1),
      ...latin1.encode(type),
      ..._u64(declared),
      ...payload,
    ]);

Uint8List _concat(List<List<int>> parts) =>
    Uint8List.fromList([for (final p in parts) ...p]);

Uint8List _dataAtom(List<int> payload, {int typeCode = 1}) =>
    _atom('data', [..._u32(0), ..._u32(typeCode), ...payload]);

Uint8List _textAtom(String name, String value) =>
    _atom(name, _dataAtom(utf8.encode(value)));

Uint8List _ftyp() => _atom('ftyp', [
  ...ascii.encode('M4A '),
  ..._u32(0),
  ...ascii.encode('M4A '),
  ...ascii.encode('isom'),
]);

/// Synthetic tag set: album, albumArtist, lyrics and a ~1.9 MB JPEG cover, so
/// the resulting moov mirrors the 1.96 MB moov seen in real files.
Uint8List _taggedMoov({int coverBytes = 1900000}) {
  final jpeg = <int>[0xFF, 0xD8, 0xFF, 0xE0, ...List<int>.filled(coverBytes, 0x11)];
  final ilst = _atom('ilst', _concat([
    _textAtom('\u00a9alb', 'Test Album'),
    _textAtom('aART', 'Test Album Artist'),
    _textAtom('\u00a9lyr', 'line one\nline two'),
    _atom('covr', _dataAtom(jpeg, typeCode: 13)),
  ]));
  final meta = _atom('meta', [..._u32(0), ...ilst]);
  return _atom('moov', _atom('udta', meta));
}

/// Small tagged moov, used for the pure offset cases.
Uint8List _smallMoov() => _atom('moov', _atom('udta', _atom('meta', [
  ..._u32(0),
  ..._atom('ilst', _textAtom('\u00a9alb', 'Test Album')),
])));

void main() {
  group('requiredMp4HeadBytes: no re-read needed', () {
    test('moov fully inside the buffer returns null', () {
      final file = _concat([_ftyp(), _smallMoov()]);
      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
          file,
          maxBytes: 1 << 20,
        ),
        isNull,
      );
    });

    test('buffer larger than the file returns null', () {
      final file = _concat([_ftyp(), _smallMoov(), _atom('mdat', [1, 2, 3])]);
      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
          file,
          maxBytes: 1 << 20,
        ),
        isNull,
      );
    });
  });

  group('requiredMp4HeadBytes: bounded requirement', () {
    test('truncated moov body returns the moov end offset', () {
      final moov = _smallMoov();
      final file = _concat([_ftyp(), moov]);
      final head = Uint8List.sublistView(file, 0, 40); // inside the moov body

      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(head, maxBytes: 1 << 20),
        _ftyp().length + moov.length,
      );
    });

    test('mdat before moov is skipped by its declared size', () {
      final mdat = _atom('mdat', List<int>.filled(64, 0));
      final moov = _smallMoov();
      final file = _concat([_ftyp(), mdat, moov]);
      // Head covers ftyp + mdat + the moov header, but not its body.
      final head = Uint8List.sublistView(
        file,
        0,
        _ftyp().length + mdat.length + 8,
      );

      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(head, maxBytes: 1 << 20),
        file.length,
      );
    });

    test('64-bit moov largesize inside the cap returns its end', () {
      final payload = List<int>.filled(200, 0);
      final moov = _largeAtom('moov', 16 + payload.length, payload);
      final file = _concat([_ftyp(), moov]);
      final head = Uint8List.sublistView(file, 0, _ftyp().length + 16);

      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(head, maxBytes: 1 << 20),
        _ftyp().length + 16 + payload.length,
      );
    });
  });

  group('requiredMp4HeadBytes: unbounded / invalid', () {
    test('mdat larger than the head hides the moov header', () {
      final file = _concat([
        _ftyp(),
        _u32(8 + 5 * 1024 * 1024), // mdat declares 5 MiB
        ascii.encode('mdat'),
        List<int>.filled(1024, 0),
      ]);
      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
          file,
          maxBytes: 1 << 20,
        ),
        isNull,
      );
    });

    test('trailing partial header returns null', () {
      final file = _concat([_ftyp(), [0, 0, 0]]);
      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
          file,
          maxBytes: 1 << 20,
        ),
        isNull,
      );
    });

    test('impossible box size returns null', () {
      final file = _concat([
        _ftyp(),
        [0, 0, 0, 4],
        ascii.encode('free'),
        [0, 0],
      ]);
      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
          file,
          maxBytes: 1 << 20,
        ),
        isNull,
      );
    });

    test('64-bit largesize overflow returns null', () {
      final file = _concat([
        _ftyp(),
        _u32(1),
        ascii.encode('moov'),
        _u64(0xFFFFFFFFFFFFFFFF),
      ]);
      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
          file,
          maxBytes: 1 << 21,
        ),
        isNull,
      );
    });

    test('product 4 MiB cap accepts just-under and rejects just-over', () {
      const cap = 4 * 1024 * 1024;
      final under = _atom('moov', List<int>.filled(cap - 200, 0));
      final over = _atom('moov', List<int>.filled(cap + 200, 0));

      final underFile = _concat([_ftyp(), under]);
      final overFile = _concat([_ftyp(), over]);

      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
          Uint8List.sublistView(underFile, 0, 64),
          maxBytes: cap,
        ),
        underFile.length,
      );
      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
          Uint8List.sublistView(overFile, 0, 64),
          maxBytes: cap,
        ),
        isNull,
      );
    });

    test('moov larger than the cap returns null', () {
      final moov = _taggedMoov();
      final file = _concat([_ftyp(), moov]);
      final head = Uint8List.sublistView(file, 0, 64);

      expect(moov.length, greaterThan(1 << 20));
      expect(
        AudioEmbeddedMetadataReader.requiredMp4HeadBytes(head, maxBytes: 1 << 20),
        isNull,
      );
    });
  });

  group('re-read then parse', () {
    test('1.96 MB moov: 128 KiB head requests the full moov and parses', () {
      final moov = _taggedMoov();
      final file = _concat([_ftyp(), moov, _atom('mdat', List<int>.filled(4096, 0))]);
      expect(moov.length, greaterThan(1900000));
      expect(file.length, greaterThan(1900000));

      const maxBytes = 4 << 20;
      final head = Uint8List.sublistView(file, 0, 128 * 1024);

      // 1. The current head cannot produce tags.
      expect(
        AudioEmbeddedMetadataReader.parse(head, fileName: 'track.m4a'),
        isNull,
      );

      // 2. The planned API says how much to re-read.
      final required = AudioEmbeddedMetadataReader.requiredMp4HeadBytes(
        head,
        maxBytes: maxBytes,
      );
      expect(required, isNotNull);
      expect(required, _ftyp().length + moov.length);
      expect(required, lessThanOrEqualTo(maxBytes));

      // 3. Re-reading exactly that many bytes yields the tags.
      final reread = Uint8List.sublistView(file, 0, required!);
      final metadata = AudioEmbeddedMetadataReader.parse(
        reread,
        fileName: 'track.m4a',
      );
      expect(metadata, isNotNull);
      expect(metadata!.album, 'Test Album');
      expect(metadata.albumArtist, 'Test Album Artist');
      expect(metadata.lyrics, contains('line two'));
      expect(metadata.coverBytes, isNotNull);
      expect(metadata.coverBytes!.length, greaterThan(1000000));
    });
  });
}
