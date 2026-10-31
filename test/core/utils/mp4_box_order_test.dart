// Isolated diagnostics for MP4/M4A top-level box layout.
//
// No product code, no network, no ffmpeg: every fixture is hand-built here.
// Purpose: decide whether a file is streamable from byte 0 (moov before mdat)
// or needs seeking to the tail (moov after a large mdat), and to pin down how
// the walker behaves on malformed and 64-bit-sized boxes.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import '../../support/mp4_box_order.dart';

Uint8List _u32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.big);

Uint8List _u64(int v) =>
    Uint8List(8)..buffer.asByteData().setUint64(0, v, Endian.big);

/// Normal 32-bit box: 4-byte size, 4-byte type, payload.
Uint8List box(String type, List<int> payload) => Uint8List.fromList([
      ..._u32(8 + payload.length),
      ...type.codeUnits,
      ...payload,
    ]);

/// 64-bit box: size32==1, type, 8-byte largesize (header included).
Uint8List largeBox(String type, int declaredSize) => Uint8List.fromList([
      ..._u32(1),
      ...type.codeUnits,
      ..._u64(declaredSize),
    ]);

Uint8List concat(List<List<int>> parts) =>
    Uint8List.fromList([for (final p in parts) ...p]);

final _ftyp = box('ftyp', 'isom'.codeUnits + [0, 0, 2, 0] + 'isom'.codeUnits);
final _moov = box('moov', List<int>.filled(64, 0x11));
const _mdatPayload = 300 * 1024; // 300 KiB of filler, stands in for audio
final _mdat = box('mdat', List<int>.filled(_mdatPayload, 0x22));

void main() {
  group('top-level box order', () {
    test('faststart: moov precedes mdat', () {
      final data = concat([_ftyp, _moov, _mdat]);
      final boxes = parseTopLevelBoxes(data);

      expect(boxes.map((b) => b.type).toList(), ['ftyp', 'moov', 'mdat']);
      expect(boxes[1].offset, _ftyp.length);
      expect(boxes[2].offset, _ftyp.length + _moov.length);
      expect(boxes[2].declaredSize, 8 + _mdatPayload);
      expect(boxes.any((b) => b.truncated), isFalse);
      expect(isFastStart(data), isTrue);
    });

    test('moov after a large mdat is not faststart', () {
      final data = concat([_ftyp, _mdat, _moov]);
      final boxes = parseTopLevelBoxes(data);

      expect(boxes.map((b) => b.type).toList(), ['ftyp', 'mdat', 'moov']);
      expect(boxes[1].declaredSize, 8 + _mdatPayload);
      expect(boxes[2].offset, _ftyp.length + _mdat.length);
      expect(boxes[2].offset, greaterThan(_ftyp.length + _mdatPayload));
      expect(isFastStart(data), isFalse);
    });

    test('head-only prefix hides a trailing moov', () {
      final data = concat([_ftyp, _mdat, _moov]);
      // Same 128 KiB window the embedded metadata reader uses.
      final head = Uint8List.sublistView(data, 0, 128 * 1024);
      final boxes = parseTopLevelBoxes(head);

      expect(boxes.map((b) => b.type).toList(), ['ftyp', 'mdat']);
      expect(boxes.last.truncated, isTrue);
      expect(boxes.last.declaredSize, 8 + _mdatPayload);
      expect(boxes.any((b) => b.type == 'moov'), isFalse);
    });

    test('size32 == 0 extends the final box to end of data', () {
      final tail = Uint8List.fromList([
        ..._u32(0),
        ...'mdat'.codeUnits,
        ...List<int>.filled(100, 0x33),
      ]);
      final data = concat([_ftyp, tail]);
      final boxes = parseTopLevelBoxes(data);

      expect(boxes.map((b) => b.type).toList(), ['ftyp', 'mdat']);
      expect(boxes.last.declaredSize, data.length - _ftyp.length);
      expect(boxes.last.truncated, isFalse);
    });
  });

  group('large-size boxes', () {
    test('64-bit largesize beyond the buffer is parsed and flagged', () {
      final declared = (1 << 32) + 4096; // > 4 GiB, far past this fixture
      final data = concat([_ftyp, largeBox('mdat', declared)]);
      final boxes = parseTopLevelBoxes(data);

      expect(boxes.map((b) => b.type).toList(), ['ftyp', 'mdat']);
      final mdat = boxes.last;
      expect(mdat.headerSize, 16);
      expect(mdat.declaredSize, declared);
      expect(mdat.truncated, isTrue);
      expect(mdat.size, data.length - _ftyp.length);
      // Parsing stops at the truncated box instead of inventing children.
      expect(isFastStart(data), isFalse);
    });

    test('64-bit largesize within the buffer advances normally', () {
      final payload = List<int>.filled(48, 0x44);
      // A real 64-bit mdat: 16-byte header + payload, largesize counts both.
      final mdatLarge = Uint8List.fromList([
        ..._u32(1),
        ...'mdat'.codeUnits,
        ..._u64(16 + payload.length),
        ...payload,
      ]);
      final data = concat([_ftyp, mdatLarge, box('moov', payload)]);
      final boxes = parseTopLevelBoxes(data);

      expect(boxes.map((b) => b.type).toList(), ['ftyp', 'mdat', 'moov']);
      expect(boxes[1].declaredSize, 64);
      expect(boxes[2].offset, _ftyp.length + 64);
      expect(boxes.any((b) => b.truncated), isFalse);
    });

    test('largesize smaller than its own 16-byte header is rejected', () {
      final data = concat([_ftyp, largeBox('mdat', 12)]);
      expect(
        () => parseTopLevelBoxes(data),
        throwsA(isA<Mp4ParseError>()),
      );
    });
  });

  group('malformed input', () {
    test('size32 in 2..7 is rejected instead of looping', () {
      for (final bad in [2, 3, 4, 7]) {
        final data = Uint8List.fromList([..._u32(bad), ...'free'.codeUnits, 0, 0]);
        expect(
          () => parseTopLevelBoxes(data),
          throwsA(isA<Mp4ParseError>()),
          reason: 'size32=$bad must not be accepted',
        );
      }
    });

    test('truncated trailing header is rejected', () {
      final data = concat([_ftyp, [0, 0, 0, 0]]);
      expect(
        () => parseTopLevelBoxes(data),
        throwsA(isA<Mp4ParseError>()),
      );
    });

    test('truncated 64-bit header is rejected', () {
      final data = concat([_ftyp, _u32(1), 'mdat'.codeUnits]);
      expect(
        () => parseTopLevelBoxes(data),
        throwsA(isA<Mp4ParseError>()),
      );
    });

    test('empty input yields no boxes', () {
      expect(parseTopLevelBoxes(Uint8List(0)), isEmpty);
    });

    test('long flat chain terminates', () {
      final parts = <List<int>>[for (var i = 0; i < 5000; i++) box('free', const [])];
      final boxes = parseTopLevelBoxes(concat(parts));
      expect(boxes.length, 5000);
      expect(boxes.every((b) => b.type == 'free'), isTrue);
    });
  });

  group('random-access walker on real files', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('mp4box_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    /// Writes ftyp + mdat(payloadBytes) [+ moov], streaming the payload so the
    /// fixture itself stays small in memory.
    Future<File> writeMedia({
      required int payloadBytes,
      required bool moovAtEnd,
      bool moovAtFront = false,
    }) async {
      final file = File('${tmp.path}/media.mp4');
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.writeFrom(_ftyp);
        if (moovAtFront) await raf.writeFrom(_moov);
        await raf.writeFrom(_u32(8 + payloadBytes));
        await raf.writeFrom('mdat'.codeUnits);
        final chunk = Uint8List(64 * 1024);
        var left = payloadBytes;
        while (left > 0) {
          final n = left < chunk.length ? left : chunk.length;
          await raf.writeFrom(chunk, 0, n);
          left -= n;
        }
        if (moovAtEnd) await raf.writeFrom(_moov);
      } finally {
        await raf.close();
      }
      return file;
    }

    test('mdat over 1 MiB with moov at end is located by seeking', () async {
      const payload = 2 * 1024 * 1024;
      final file = await writeMedia(payloadBytes: payload, moovAtEnd: true);

      final layout = await walkTopLevelBoxes(file);

      expect(layout.order, ['ftyp', 'mdat', 'moov']);
      expect(layout.moovStatus, MoovStatus.afterMdat);
      expect(layout.complete, isTrue);
      expect(layout.fileLength, _ftyp.length + 8 + payload + _moov.length);
      expect(layout.boxes[2].offset, _ftyp.length + 8 + payload);
      // Only box headers were read: three 8-byte headers, not 2 MiB.
      expect(layout.bytesRead, lessThanOrEqualTo(48));
    });

    test('faststart file of the same size reports moov before mdat', () async {
      const payload = 2 * 1024 * 1024;
      final file = await writeMedia(
        payloadBytes: payload,
        moovAtEnd: false,
        moovAtFront: true,
      );

      final layout = await walkTopLevelBoxes(file);

      expect(layout.order, ['ftyp', 'moov', 'mdat']);
      expect(layout.moovStatus, MoovStatus.beforeMdat);
      expect(layout.bytesRead, lessThanOrEqualTo(48));
    });

    test('trailing partial header yields unknown, never "absent"', () async {
      final file = File('${tmp.path}/bad_tail.mp4');
      await file.writeAsBytes(concat([_ftyp, [0, 0, 0]]));

      final layout = await walkTopLevelBoxes(file);

      expect(layout.complete, isFalse);
      expect(layout.problem, contains('truncated box header'));
      expect(layout.moovStatus, MoovStatus.unknown);
      expect(layout.moovStatus, isNot(MoovStatus.absent));
    });

    test('mdat declaring more bytes than the file holds yields unknown', () async {
      final file = File('${tmp.path}/short_mdat.mp4');
      // Declares 1 MiB payload, ships 16 bytes.
      await file.writeAsBytes(concat([
        _ftyp,
        _u32(8 + 1024 * 1024),
        'mdat'.codeUnits,
        List<int>.filled(16, 0),
      ]));

      final layout = await walkTopLevelBoxes(file);

      expect(layout.complete, isFalse);
      expect(layout.problem, contains('declares'));
      expect(layout.moovStatus, MoovStatus.unknown);
    });

    test('size32 == 0 mdat runs to EOF and moov is genuinely absent', () async {
      final file = File('${tmp.path}/zero_size.mp4');
      await file.writeAsBytes(concat([
        _ftyp,
        [0, 0, 0, 0],
        'mdat'.codeUnits,
        List<int>.filled(4096, 0x55),
      ]));

      final layout = await walkTopLevelBoxes(file);

      expect(layout.complete, isTrue);
      expect(layout.order, ['ftyp', 'mdat']);
      expect(layout.boxes.last.declaredSize, 8 + 4096);
      expect(layout.moovStatus, MoovStatus.absent);
    });

    test('64-bit header too short for its own header yields unknown', () async {
      final file = File('${tmp.path}/bad_largesize.mp4');
      await file.writeAsBytes(concat([_ftyp, largeBox('mdat', 12)]));

      final layout = await walkTopLevelBoxes(file);

      expect(layout.complete, isFalse);
      expect(layout.problem, contains('largesize'));
      expect(layout.moovStatus, MoovStatus.unknown);
    });

    test('64-bit mdat header is read with a 16-byte probe', () async {
      final file = File('${tmp.path}/large_header.mp4');
      final payload = List<int>.filled(1024, 0x66);
      await file.writeAsBytes(concat([
        _ftyp,
        _u32(1),
        'mdat'.codeUnits,
        _u64(16 + payload.length),
        payload,
        _moov,
      ]));

      final layout = await walkTopLevelBoxes(file);

      expect(layout.order, ['ftyp', 'mdat', 'moov']);
      expect(layout.boxes[1].headerSize, 16);
      expect(layout.moovStatus, MoovStatus.afterMdat);
      expect(layout.bytesRead, 8 + 16 + 8);
    });
  });
}
