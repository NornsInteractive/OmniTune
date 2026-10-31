// Debug-only Cloud189 range probe (GET Range: bytes=0-1) behaviour.
//
// Drives the real DioCloud189RemoteClient against a fake HttpClientAdapter:
// the probe and the real download share one URL, so the fake branches on the
// Range header. No network, no credentials, no device.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/utils/debug_logger.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';

const _downloadUrl = 'https://download.example.com/song.flac';

class _ProbeAdapter implements HttpClientAdapter {
  final Map<String, Future<ResponseBody> Function(RequestOptions)> _handlers =
      {};
  final List<RequestOptions> probeRequests = [];
  final List<RequestOptions> downloadRequests = [];

  void addHandler(
    String path,
    Future<ResponseBody> Function(RequestOptions) handler,
  ) {
    _handlers[path] = handler;
  }

  void addJson(String path, Map<String, dynamic> data) {
    addHandler(
      path,
      (_) async => ResponseBody.fromBytes(
        Uint8List.fromList(jsonEncode(data).codeUnits),
        200,
        headers: {
          'content-type': ['application/json'],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    if (options.path == _downloadUrl) {
      if (options.headers['Range'] == 'bytes=0-1') {
        probeRequests.add(options);
      } else {
        downloadRequests.add(options);
      }
    }
    final handler = _handlers[options.path];
    if (handler == null) {
      throw DioException(
        requestOptions: options,
        error: 'No mock for ${options.path}',
        type: DioExceptionType.unknown,
      );
    }
    return handler(options);
  }
}

ResponseBody _body(
  int statusCode,
  List<int> bytes, {
  String? contentRange,
  String? acceptRanges,
  String? contentType = 'audio/flac',
}) {
  return ResponseBody.fromBytes(
    Uint8List.fromList(bytes),
    statusCode,
    headers: {
      'content-type': [contentType ?? 'application/octet-stream'],
      'content-length': ['${bytes.length}'],
      if (contentRange != null) 'content-range': [contentRange],
      if (acceptRanges != null) 'accept-ranges': [acceptRanges],
    },
  );
}

class _Capture {
  final List<String> lines = <String>[];
  DebugPrintCallback? _original;

  void start() {
    _original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      lines.add(message ?? '');
    };
  }

  void stop() {
    final original = _original;
    if (original != null) debugPrint = original;
  }

  String get joined => lines.join('\n');

  bool any(bool Function(String) predicate) => lines.any(predicate);
}

void main() {
  late _ProbeAdapter adapter;
  late Dio dio;
  late DioCloud189RemoteClient client;
  late _Capture capture;

  setUp(() {
    adapter = _ProbeAdapter();
    dio = Dio()
      ..httpClientAdapter = adapter
      ..options.baseUrl = Cloud189Constants.apiBaseUrl;
    client = DioCloud189RemoteClient(
      refreshToken: 'fake-refresh-token',
      dio: dio,
    );

    adapter.addJson(
      '${Cloud189Constants.authBaseUrl}/api/oauth2/refreshToken.do',
      {
        'result': 0,
        'accessToken': 'fake-access-token',
        'refreshToken': 'fake-refresh-token',
      },
    );
    adapter.addJson(
      '${Cloud189Constants.apiBaseUrl}/getSessionForPC.action',
      {
        'result': 0,
        'sessionKey': 'fake-session-key',
        'sessionSecret': 'fake-session-secret',
      },
    );
    adapter.addJson(
      '${Cloud189Constants.apiBaseUrl}/listFiles.action',
      {
        'result': 0,
        'fileListAO': {
          'count': 1,
          'folderList': [],
          'fileList': [
            {
              'id': 'file-1',
              'name': 'song.flac',
              'size': 100,
              'lastOpTime': '2024-01-01 00:00:00',
            },
          ],
        },
      },
    );
    adapter.addJson(
      '${Cloud189Constants.apiBaseUrl}/getFileDownloadUrl.action',
      {'fileDownloadUrl': _downloadUrl},
    );

    capture = _Capture()..start();
  });

  tearDown(() async {
    capture.stop();
    DebugLogger.setDebugEnabled(false);
    dio.close(force: true);
  });

  /// The probe is fire-and-forget, so wait for its log line instead of a
  /// fixed delay.
  Future<String> waitForProbeLog() async {
    for (var i = 0; i < 200; i++) {
      final match = capture.lines.where(
        (line) => line.contains('Cloud189 range probe'),
      );
      if (match.isNotEmpty) return match.last;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('probe log never appeared; captured=${capture.joined}');
  }

  Future<List<int>> drain(Cloud189ReadResult result) async {
    final bytes = <int>[];
    await for (final chunk in result.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  void installDownload() {
    adapter.addHandler(
      _downloadUrl,
      (_) async => _body(200, List<int>.generate(8, (i) => i)),
    );
  }

  group('probe with debug enabled', () {
    test('206 response logs host/status/headers only', () async {
      DebugLogger.setDebugEnabled(true);
      adapter.addHandler(
        _downloadUrl,
        (options) async {
          if (options.headers['Range'] == 'bytes=0-1') {
            return _body(
              206,
              [0x66, 0x74],
              contentRange: 'bytes 0-1/100',
              acceptRanges: 'bytes',
            );
          }
          return _body(200, List<int>.generate(8, (i) => i));
        },
      );

      final result = await client.openRead('/song.flac');
      final bytes = await drain(result);
      final line = await waitForProbeLog();

      expect(adapter.probeRequests, hasLength(1));
      expect(adapter.probeRequests.single.headers['Range'], 'bytes=0-1');
      expect(line, contains('host=download.example.com'));
      expect(line, contains('status=206'));
      expect(line, contains('type=audio/flac'));
      expect(line, contains('length=2'));
      expect(line, contains('acceptRanges=bytes'));
      expect(line, contains('contentRange=bytes 0-1/100'));
      // No path, query or credential may appear in the probe log.
      expect(line, isNot(contains('/song.flac')));
      expect(line, isNot(contains('?')));
      expect(line, isNot(contains('fake-access-token')));
      expect(line, isNot(contains('fake-session-key')));
      expect(bytes, hasLength(8));
    });

    test('200 response (range ignored) logs null range headers', () async {
      DebugLogger.setDebugEnabled(true);
      adapter.addHandler(
        _downloadUrl,
        (options) async {
          if (options.headers['Range'] == 'bytes=0-1') {
            return _body(200, [0x66, 0x74]);
          }
          return _body(200, List<int>.generate(8, (i) => i));
        },
      );

      final result = await client.openRead('/song.flac');
      final bytes = await drain(result);
      final line = await waitForProbeLog();

      expect(line, contains('status=200'));
      expect(line, contains('acceptRanges=null'));
      expect(line, contains('contentRange=null'));
      expect(line, isNot(contains('/song.flac')));
      expect(bytes, hasLength(8));
    });

    test('probe abandons a body that never ends', () async {
      DebugLogger.setDebugEnabled(true);
      final controller = StreamController<Uint8List>();
      controller.add(Uint8List.fromList([0x66, 0x74]));
      // Deliberately never closed: if the probe drained the body it would hang.

      adapter.addHandler(
        _downloadUrl,
        (options) async {
          if (options.headers['Range'] == 'bytes=0-1') {
            return ResponseBody(
              controller.stream,
              206,
              headers: {
                'content-type': ['audio/flac'],
                'content-length': ['2'],
                'content-range': ['bytes 0-1/100'],
              },
            );
          }
          return _body(200, List<int>.generate(8, (i) => i));
        },
      );

      final result = await client.openRead('/song.flac');
      final bytes = await drain(result);
      final line = await waitForProbeLog();

      expect(line, contains('status=206'));
      expect(bytes, List<int>.generate(8, (i) => i));
      await controller.close();
    });

    test('probe failure does not block playback', () async {
      DebugLogger.setDebugEnabled(true);
      adapter.addHandler(
        _downloadUrl,
        (options) async {
          if (options.headers['Range'] == 'bytes=0-1') {
            throw DioException(
              requestOptions: options,
              error: 'probe boom',
              type: DioExceptionType.connectionError,
            );
          }
          return _body(200, List<int>.generate(8, (i) => i));
        },
      );

      final result = await client.openRead('/song.flac');
      final bytes = await drain(result);
      final line = await waitForProbeLog();

      expect(line, contains('range probe failed type=DioExceptionType.connectionError'));
      expect(bytes, List<int>.generate(8, (i) => i));
      expect(adapter.downloadRequests, hasLength(1));
    });
  });

  group('probe with debug disabled', () {
    test('no probe request is made and playback still works', () async {
      DebugLogger.setDebugEnabled(false);
      installDownload();

      final result = await client.openRead('/song.flac');
      final bytes = await drain(result);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(adapter.probeRequests, isEmpty);
      expect(adapter.downloadRequests, hasLength(1));
      expect(capture.any((l) => l.contains('range probe')), isFalse);
      expect(bytes, hasLength(8));
    });

    test('bounded openRead never probes even when debug is on', () async {
      DebugLogger.setDebugEnabled(true);
      adapter.addHandler(
        _downloadUrl,
        (_) async => _body(
          206,
          [2, 3, 4, 5],
          contentRange: 'bytes 2-5/100',
          acceptRanges: 'bytes',
        ),
      );

      final result = await client.openRead('/song.flac', start: 2, end: 6);
      await drain(result);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(adapter.probeRequests, isEmpty);
      expect(capture.any((l) => l.contains('range probe')), isFalse);
    });
  });
}
