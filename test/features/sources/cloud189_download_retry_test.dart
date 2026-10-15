import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Map<String, Future<ResponseBody> Function(RequestOptions)> _handlers =
      {};
  final List<RequestOptions> _downloadRequests = [];

  void addHandler(
    String path,
    Future<ResponseBody> Function(RequestOptions) handler,
  ) {
    _handlers[path] = handler;
  }

  void addJsonResponse(String path, int statusCode, Map<String, dynamic> data) {
    addHandler(
      path,
      (_) async => ResponseBody.fromBytes(
        Uint8List.fromList(jsonEncode(data).codeUnits),
        statusCode,
        headers: {
          'content-type': ['application/json'],
        },
      ),
    );
  }

  void addDownloadError(
    String path,
    Object error,
    DioExceptionType type, {
    int? statusCode,
    String? responseBody,
  }) {
    addHandler(path, (_) async {
      if (statusCode != null && responseBody != null) {
        return ResponseBody.fromString(responseBody, statusCode);
      }
      throw DioException(
        requestOptions: RequestOptions(path: path),
        error: error,
        type: type,
        response: statusCode != null
            ? Response(
                requestOptions: RequestOptions(path: path),
                statusCode: statusCode,
                data: responseBody,
              )
            : null,
      );
    });
  }

  List<RequestOptions> get downloadRequests =>
      List.unmodifiable(_downloadRequests);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    if (options.path.startsWith('https://download.example.com')) {
      _downloadRequests.add(options);
    }
    final handler = _handlers[options.path];
    if (handler != null) {
      return handler(options);
    }
    throw DioException(
      requestOptions: options,
      error: 'No mock for ${options.path}',
      type: DioExceptionType.unknown,
    );
  }
}

ResponseBody _streamResponse(
  int statusCode,
  List<int> bytes, {
  required String contentRange,
  required String contentLength,
  String contentType = 'audio/flac',
}) {
  return ResponseBody.fromBytes(
    Uint8List.fromList(bytes),
    statusCode,
    headers: {
      'content-range': [contentRange],
      'content-length': [contentLength],
      'content-type': [contentType],
    },
  );
}

Stream<Uint8List> _prefixThenError(List<int> prefix, Object error) async* {
  yield Uint8List.fromList(prefix);
  throw error;
}

ResponseBody _streamThenError(List<int> prefix, Object error) {
  return ResponseBody(
    _prefixThenError(prefix, error),
    206,
    headers: {
      'content-range': ['bytes 2-5/8'],
      'content-length': ['4'],
      'content-type': ['audio/flac'],
    },
  );
}

void main() {
  group('DioCloud189RemoteClient openRead download retry', () {
    late _FakeAdapter adapter;
    late Dio dio;
    late DioCloud189RemoteClient client;

    void setupAuthFixtures() {
      adapter.addJsonResponse(
        '${Cloud189Constants.authBaseUrl}/api/oauth2/refreshToken.do',
        200,
        {
          'result': 0,
          'accessToken': 'fake-access-token',
          'refreshToken': 'fake-refresh-token',
        },
      );
      adapter.addJsonResponse(
        '${Cloud189Constants.apiBaseUrl}/getSessionForPC.action',
        200,
        {
          'result': 0,
          'sessionKey': 'fake-session-key',
          'sessionSecret': 'fake-session-secret',
        },
      );
      adapter.addJsonResponse(
        '${Cloud189Constants.apiBaseUrl}/listFiles.action',
        200,
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
      adapter.addJsonResponse(
        '${Cloud189Constants.apiBaseUrl}/getFileDownloadUrl.action',
        200,
        {'fileDownloadUrl': 'https://download.example.com/song.flac'},
      );
    }

    setUp(() {
      adapter = _FakeAdapter();
      dio = Dio()
        ..httpClientAdapter = adapter
        ..options.baseUrl = Cloud189Constants.apiBaseUrl;
      client = DioCloud189RemoteClient(
        refreshToken: 'fake-refresh-token',
        dio: dio,
      );
      setupAuthFixtures();
    });

    tearDown(() async {
      dio.close(force: true);
    });

    test(
      '1. transient unknown SocketException then success 206 bytes 2-5/100 -> 2 GET, bytes 2,3,4,5',
      () async {
        var attempt = 0;
        adapter.addHandler('https://download.example.com/song.flac', (_) async {
          attempt++;
          if (attempt == 1) {
            throw DioException(
              requestOptions: RequestOptions(
                path: 'https://download.example.com/song.flac',
              ),
              error: SocketException(
                'Connection reset',
                osError: OSError('reset', 104),
              ),
              type: DioExceptionType.unknown,
            );
          }
          return _streamResponse(
            206,
            [2, 3, 4, 5],
            contentRange: 'bytes 2-5/100',
            contentLength: '4',
          );
        });

        final result = await client.openRead('/song.flac', start: 2, end: 6);
        final bytes = <int>[];
        await for (final chunk in result.stream) {
          bytes.addAll(chunk);
        }

        expect(adapter.downloadRequests.length, 2);
        for (final req in adapter.downloadRequests) {
          expect(req.headers['range'], 'bytes=2-5');
        }
        expect(bytes, [2, 3, 4, 5]);
      },
    );

    test(
      '1b. transient DioException.connectionError then success 206 -> 2 GET',
      () async {
        var attempt = 0;
        adapter.addHandler('https://download.example.com/song.flac', (_) async {
          attempt++;
          if (attempt == 1) {
            throw DioException(
              requestOptions: RequestOptions(
                path: 'https://download.example.com/song.flac',
              ),
              error: 'Connection closed',
              type: DioExceptionType.connectionError,
            );
          }
          return _streamResponse(
            206,
            [2, 3, 4, 5],
            contentRange: 'bytes 2-5/100',
            contentLength: '4',
          );
        });

        final result = await client.openRead('/song.flac', start: 2, end: 6);
        final bytes = <int>[];
        await for (final chunk in result.stream) {
          bytes.addAll(chunk);
        }

        expect(adapter.downloadRequests.length, 2);
        for (final req in adapter.downloadRequests) {
          expect(req.headers['range'], 'bytes=2-5');
        }
        expect(bytes, [2, 3, 4, 5]);
      },
    );

    test(
      '2. reset twice then fail -> exactly 2 GET, error propagates',
      () async {
        var attempt = 0;
        adapter.addHandler('https://download.example.com/song.flac', (_) async {
          attempt++;
          if (attempt <= 2) {
            throw DioException(
              requestOptions: RequestOptions(
                path: 'https://download.example.com/song.flac',
              ),
              error: SocketException(
                'Connection reset',
                osError: OSError('reset', 104),
              ),
              type: DioExceptionType.unknown,
            );
          }
          return _streamResponse(
            206,
            [2, 3, 4, 5],
            contentRange: 'bytes 2-5/100',
            contentLength: '4',
          );
        });

        await expectLater(
          client.openRead('/song.flac', start: 2, end: 6),
          throwsA(isA<DioException>()),
        );
        expect(adapter.downloadRequests.length, 2);
      },
    );

    test(
      '3. non-retryable errors: 401, cancel, badCertificate, FormatException -> 1 GET each',
      () async {
        for (final (name, error, type, statusCode, body) in [
          (
            '401',
            'Unauthorized',
            DioExceptionType.badResponse,
            401,
            'Unauthorized',
          ),
          ('cancel', 'Cancelled', DioExceptionType.cancel, null, null),
          (
            'badCertificate',
            HandshakeException('Bad certificate'),
            DioExceptionType.badCertificate,
            null,
            null,
          ),
          (
            'FormatException',
            const FormatException('Invalid header'),
            DioExceptionType.unknown,
            null,
            null,
          ),
        ]) {
          adapter = _FakeAdapter();
          dio = Dio()..httpClientAdapter = adapter;
          client = DioCloud189RemoteClient(
            refreshToken: 'fake-refresh-token',
            dio: dio,
          );
          setupAuthFixtures();

          adapter.addDownloadError(
            'https://download.example.com/song.flac',
            error,
            type,
            statusCode: statusCode,
            responseBody: body,
          );

          await expectLater(
            client.openRead('/song.flac', start: 2, end: 6),
            throwsA(
              predicate(
                (e) =>
                    e is DioException &&
                    (statusCode == null ||
                        e.response?.statusCode == statusCode),
              ),
            ),
          );
          expect(
            adapter.downloadRequests.length,
            1,
            reason: '$name should not retry',
          );
          dio.close(force: true);
        }
      },
    );

    test(
      '3b. successful headers then body stream error after prefix -> 1 GET, prefix received, error propagates',
      () async {
        adapter.addHandler('https://download.example.com/song.flac', (_) async {
          return _streamThenError([2, 3], SocketException('Stream broken'));
        });

        final result = await client.openRead('/song.flac', start: 2, end: 6);
        final bytes = <int>[];
        await expectLater(() async {
          await for (final chunk in result.stream) {
            bytes.addAll(chunk);
          }
        }(), throwsA(isA<SocketException>()));
        expect(adapter.downloadRequests.length, 1);
        expect(bytes, [2, 3]);
      },
    );
  });
}
