// Debug-log leak audit for the Cloud189 API client.
//
// Imports the real client from lib/ and drives it through an injected Dio with
// a fake adapter, so the assertions describe production behaviour directly.
//
// Requirement under test: request / response / error lines may expose only the
// HTTP method, host, status code and error type - never the URI path, query
// string, credentials, sessionKey or response payload.
//
// No network: a fake HttpClientAdapter answers every request.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart'
    as c;

const _host = 'api.cloud.189.cn';
const _password = 'PW-DO-NOT-LOG-7f3a';
const _token = 'TOKEN-DO-NOT-LOG-91bc';
const _session = 'SESSION-DO-NOT-LOG-4e2d';
const _apiPath = '/open/file/listFiles.action';
const _payloadKey = 'fileList';

/// Substrings that must never reach the log, whatever the outcome.
const _forbidden = <String>[
  _apiPath,
  '/open/',
  'accessToken',
  'sessionKey',
  'fileId',
  _token,
  _session,
  _password,
  'probe-user',
  _payloadKey,
  'res_code',
  '?',
];

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode);

  final int statusCode;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      '{"res_code":0,"$_payloadKey":[]}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json;charset=UTF-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _PrintCapture {
  final List<String> lines = <String>[];
  DebugPrintCallback? _original;

  String get joined => lines.join('\n');

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
}

/// Builds a client wired to a fake adapter and fires one synthetic request
/// carrying credential-shaped query parameters and a JSON body.
Future<({String log, String printed, int calls})> _runRequest({
  required bool debugEnabled,
  int statusCode = 200,
}) async {
  final adapter = _FakeAdapter(statusCode);
  final dio = Dio(BaseOptions(baseUrl: 'https://$_host'))
    ..httpClientAdapter = adapter;

  final client = c.DioOpenListCloud189RemoteClient(
    username: 'probe-user',
    password: _password,
    enableDebugLogging: debugEnabled,
    dio: dio,
  );
  expect(client, isNotNull);

  // Arm the buffer regardless of the flag: silence then means nothing was
  // logged, not that the sink was disabled.
  c.Cloud189DebugLogBuffer.begin(enabled: true);

  final capture = _PrintCapture()..start();
  try {
    await dio.post(
      _apiPath,
      queryParameters: {
        'accessToken': _token,
        'sessionKey': _session,
        'fileId': '42',
      },
      data: {'loginName': 'probe-user', 'password': _password},
    );
  } on DioException catch (_) {
    // A 500 is the error-path fixture; the interceptor already recorded it.
  } finally {
    capture.stop();
  }

  return (
    log: c.Cloud189DebugLogBuffer.dump(),
    printed: capture.joined,
    calls: adapter.calls,
  );
}

void _expectNoLeak(String text) {
  for (final needle in _forbidden) {
    expect(
      text,
      isNot(contains(needle)),
      reason: 'debug log leaked "$needle"',
    );
  }
}

void main() {
  group('debug logging disabled', () {
    test('writes nothing to the debug buffer or debugPrint', () async {
      final result = await _runRequest(debugEnabled: false);

      expect(result.calls, 1, reason: 'request must still be performed');
      expect(result.log, isEmpty);
      expect(result.printed, isEmpty);
    });
  });

  group('debug logging enabled', () {
    test('success logs method, host and status only', () async {
      final result = await _runRequest(debugEnabled: true);

      final lines = result.log.split('\n');
      expect(lines, hasLength(2));
      expect(lines[0], '[Cloud189][request] POST host=$_host');
      expect(lines[1], '[Cloud189][response] POST host=$_host status=200');
      _expectNoLeak(result.log);
      _expectNoLeak(result.printed);
    });

    test('error logs method, host, status and type only', () async {
      final result = await _runRequest(debugEnabled: true, statusCode: 500);

      final lines = result.log.split('\n');
      expect(lines, hasLength(2));
      expect(lines[0], '[Cloud189][request] POST host=$_host');
      expect(
        lines[1],
        startsWith('[Cloud189][error] POST host=$_host status=500'),
      );
      expect(lines[1], contains('type='));
      _expectNoLeak(result.log);
      _expectNoLeak(result.printed);
    });
  });
}
