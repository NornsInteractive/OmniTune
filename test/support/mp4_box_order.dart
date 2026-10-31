// Isolated diagnostic helper (test-only, not product code).
//
// Walks the TOP-LEVEL box sequence of an ISO base media file (MP4/M4A) without
// reading the whole payload, so a caller can tell whether `moov` sits before or
// after `mdat` (faststart vs. moov-at-end) and how large `mdat` claims to be.
//
// CLI: dart run test/support/mp4_box_order.dart <file>

// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';

/// One top-level box header as described by ISO/IEC 14496-12.
class Mp4Box {
  const Mp4Box({
    required this.type,
    required this.offset,
    required this.size,
    required this.headerSize,
    required this.declaredSize,
    required this.truncated,
  });

  /// Four-character box type decoded as latin1 (e.g. `ftyp`, `moov`, `mdat`).
  final String type;

  /// Byte offset of the box header within the file/prefix.
  final int offset;

  /// Usable payload+header length actually present in the buffer.
  final int size;

  /// 8 for a normal box, 16 when a 64-bit `largesize` field is used.
  final int headerSize;

  /// Size the box declares for itself, which may exceed the buffer.
  final int declaredSize;

  /// True when `declaredSize` runs past the end of the supplied buffer.
  final bool truncated;

  int get payloadSize => size - headerSize;

  @override
  String toString() =>
      '$type@$offset(size=$declaredSize${truncated ? ',truncated' : ''})';
}

/// Raised for a structurally invalid box chain.
class Mp4ParseError implements Exception {
  const Mp4ParseError(this.message, this.offset);
  final String message;
  final int offset;

  @override
  String toString() => 'Mp4ParseError($message at byte $offset)';
}

const int _maxTopLevelBoxes = 100000;

/// Parses the top-level box chain of [data].
///
/// Throws [Mp4ParseError] when a box header is impossible:
///   * `size32` in 2..7 (smaller than the 8-byte header itself),
///   * `size32 == 1` with `largesize < 16`,
///   * a non-final box that declares zero payload.
///
/// `size32 == 0` means "box runs to end of file" and is accepted.
/// A box whose declared size exceeds the buffer is returned with
/// [Mp4Box.truncated] set, and parsing stops there (no guessing).
List<Mp4Box> parseTopLevelBoxes(Uint8List data) {
  final boxes = <Mp4Box>[];
  var offset = 0;

  while (offset < data.length) {
    if (boxes.length >= _maxTopLevelBoxes) {
      throw Mp4ParseError('too many top-level boxes', offset);
    }
    final remaining = data.length - offset;
    if (remaining < 8) {
      throw Mp4ParseError('truncated box header ($remaining bytes)', offset);
    }

    final header = ByteData.sublistView(data, offset, offset + 8);
    final size32 = header.getUint32(0);
    final type = String.fromCharCodes(data, offset + 4, offset + 8);

    var headerSize = 8;
    var declared = size32;

    if (size32 == 1) {
      if (remaining < 16) {
        throw Mp4ParseError('truncated 64-bit box header', offset);
      }
      final large = ByteData.sublistView(data, offset + 8, offset + 16)
          .getUint64(0);
      if (large < 16) {
        throw Mp4ParseError('largesize $large smaller than header', offset);
      }
      headerSize = 16;
      declared = large;
    } else if (size32 == 0) {
      declared = remaining;
    } else if (size32 < 8) {
      throw Mp4ParseError('invalid box size $size32', offset);
    }

    if (declared < headerSize) {
      throw Mp4ParseError('box size $declared smaller than header', offset);
    }

    final truncated = declared > remaining;
    final present = truncated ? remaining : declared;
    boxes.add(
      Mp4Box(
        type: type,
        offset: offset,
        size: present,
        headerSize: headerSize,
        declaredSize: declared,
        truncated: truncated,
      ),
    );

    if (truncated) break;
    if (present <= 0) throw Mp4ParseError('non-advancing box', offset);
    offset += present;
  }

  return boxes;
}

/// Convenience: box types in file order, e.g. `[ftyp, mdat, moov]`.
List<String> topLevelBoxOrder(Uint8List data) =>
    parseTopLevelBoxes(data).map((b) => b.type).toList();

/// True when `moov` precedes `mdat`, i.e. the file is streamable from byte 0.
bool isFastStart(Uint8List data) {
  final boxes = parseTopLevelBoxes(data);
  final moov = boxes.indexWhere((b) => b.type == 'moov');
  final mdat = boxes.indexWhere((b) => b.type == 'mdat');
  if (moov < 0 || mdat < 0) return false;
  return moov < mdat;
}

/// Where `moov` sits relative to `mdat`, or why that cannot be decided.
enum MoovStatus { beforeMdat, afterMdat, absent, unknown }

/// Result of walking a file through bounded random-access header reads.
class Mp4FileLayout {
  const Mp4FileLayout({
    required this.fileLength,
    required this.boxes,
    required this.bytesRead,
    required this.problem,
  });

  final int fileLength;
  final List<Mp4Box> boxes;

  /// Total header bytes actually read (never the payload).
  final int bytesRead;

  /// Non-null when the walk stopped before a clean end of file.
  final String? problem;

  bool get complete => problem == null;

  List<String> get order => boxes.map((b) => b.type).toList();

  MoovStatus get moovStatus {
    if (!complete) return MoovStatus.unknown;
    final moov = boxes.where((b) => b.type == 'moov').toList();
    if (moov.isEmpty) return MoovStatus.absent;
    final mdat = boxes.where((b) => b.type == 'mdat').toList();
    if (mdat.isEmpty) return MoovStatus.unknown;
    return moov.first.offset < mdat.first.offset
        ? MoovStatus.beforeMdat
        : MoovStatus.afterMdat;
  }
}

/// Walks the top-level box chain of [file] using seek + small header reads.
///
/// Only 8 bytes per box (16 for a 64-bit box) are ever read, so a multi-GiB
/// `mdat` costs nothing. Never reads the whole file.
Future<Mp4FileLayout> walkTopLevelBoxes(File file) async {
  final raf = await file.open();
  final boxes = <Mp4Box>[];
  var bytesRead = 0;
  String? problem;

  try {
    final length = await raf.length();
    var offset = 0;

    while (offset < length) {
      final remaining = length - offset;
      if (remaining < 8) {
        problem = 'truncated box header at byte $offset ($remaining bytes left)';
        break;
      }

      await raf.setPosition(offset);
      final head = await raf.read(8);
      bytesRead += head.length;
      if (head.length < 8) {
        problem = 'short read at byte $offset';
        break;
      }

      final size32 = ByteData.sublistView(head).getUint32(0);
      final type = String.fromCharCodes(head, 4, 8);
      var headerSize = 8;
      var declared = size32;

      if (size32 == 1) {
        if (remaining < 16) {
          problem = 'truncated 64-bit header at byte $offset';
          break;
        }
        await raf.setPosition(offset + 8);
        final ext = await raf.read(8);
        bytesRead += ext.length;
        if (ext.length < 8) {
          problem = 'short read of largesize at byte $offset';
          break;
        }
        headerSize = 16;
        declared = ByteData.sublistView(ext).getUint64(0);
        if (declared < 16) {
          problem = 'largesize $declared smaller than header at byte $offset';
          break;
        }
      } else if (size32 == 0) {
        declared = remaining;
      } else if (size32 < 8) {
        problem = 'invalid box size $size32 at byte $offset';
        break;
      }

      final truncated = declared > remaining;
      boxes.add(
        Mp4Box(
          type: type,
          offset: offset,
          size: truncated ? remaining : declared,
          headerSize: headerSize,
          declaredSize: declared,
          truncated: truncated,
        ),
      );

      if (truncated) {
        problem = 'box $type at byte $offset declares $declared, '
            'only $remaining bytes remain';
        break;
      }
      offset += declared;
    }

    return Mp4FileLayout(
      fileLength: length,
      boxes: boxes,
      bytesRead: bytesRead,
      problem: problem,
    );
  } finally {
    await raf.close();
  }
}

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run test/support/mp4_box_order.dart <file>');
    exit(64);
  }
  final file = File(args.single);
  if (!await file.exists()) {
    stderr.writeln('no such file: ${args.single}');
    exit(66);
  }

  final layout = await walkTopLevelBoxes(file);
  print('file_bytes=${layout.fileLength}');
  print('box_order=${layout.order.join(',')}');
  for (final b in layout.boxes) {
    print(
      '  ${b.type} offset=${b.offset} declared=${b.declaredSize} '
      'header=${b.headerSize}${b.truncated ? ' (truncated)' : ''}',
    );
  }
  print('moov=${layout.moovStatus.name}');
  print('bytes_read=${layout.bytesRead}');
  if (layout.problem != null) {
    print('problem=${layout.problem}');
    exitCode = 2;
  }
}
