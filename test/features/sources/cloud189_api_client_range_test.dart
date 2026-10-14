import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';

void main() {
  group('cloud189ReadResponse direct parser tests', () {
    test(
      '1_206 Content-Range bytes 2-5/8 CL4 body[2,3,4,5] entrySize100 stale',
      () async {
        final bytes = Uint8List.fromList([2, 3, 4, 5]);
        final responseBody = ResponseBody.fromBytes(
          bytes,
          206,
          headers: {
            'content-range': ['bytes 2-5/8'],
            'content-length': ['4'],
            'content-type': ['audio/flac'],
          },
        );
        final response = Response<ResponseBody>(
          data: responseBody,
          statusCode: 206,
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'content-range': ['bytes 2-5/8'],
            'content-length': ['4'],
            'content-type': ['audio/flac'],
          }),
        );
        final result = cloud189ReadResponse(
          response,
          start: 2,
          end: 6,
          entrySize: 100,
          contentType: 'audio/flac',
        );
        expect(result.offset, 2);
        expect(result.contentLength, 4);
        expect(result.sourceLength, 8);
        final consumed = <int>[];
        await for (final chunk in result.stream) {
          consumed.addAll(chunk);
        }
        expect(consumed, [2, 3, 4, 5]);
      },
    );

    test(
      '2_200 ignored Range CL8 full body start2 end6 entrySize100',
      () async {
        final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
        final responseBody = ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            'content-length': ['8'],
            'content-type': ['audio/flac'],
          },
        );
        final response = Response<ResponseBody>(
          data: responseBody,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'content-length': ['8'],
            'content-type': ['audio/flac'],
          }),
        );
        final result = cloud189ReadResponse(
          response,
          start: 2,
          end: 6,
          entrySize: 100,
          contentType: 'audio/flac',
        );
        expect(result.offset, 2);
        expect(result.contentLength, 4);
        expect(result.sourceLength, 8);
        final consumed = <int>[];
        await for (final chunk in result.stream) {
          consumed.addAll(chunk);
        }
        expect(consumed, [2, 3, 4, 5]);
      },
    );

    test('3_200 CL8 start2 end99 caps at EOF len6 total8', () async {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      final responseBody = ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          'content-length': ['8'],
          'content-type': ['audio/flac'],
        },
      );
      final response = Response<ResponseBody>(
        data: responseBody,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/test'),
        headers: Headers.fromMap({
          'content-length': ['8'],
          'content-type': ['audio/flac'],
        }),
      );
      final result = cloud189ReadResponse(
        response,
        start: 2,
        end: 99,
        entrySize: 100,
        contentType: 'audio/flac',
      );
      expect(result.offset, 2);
      expect(result.contentLength, 6);
      expect(result.sourceLength, 8);
      final consumed = <int>[];
      await for (final chunk in result.stream) {
        consumed.addAll(chunk);
      }
      expect(consumed, [2, 3, 4, 5, 6, 7]);
    });

    test('4a_200 start8 equals available throws RangeError', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      final responseBody = ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          'content-length': ['8'],
          'content-type': ['audio/flac'],
        },
      );
      final response = Response<ResponseBody>(
        data: responseBody,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/test'),
        headers: Headers.fromMap({
          'content-length': ['8'],
          'content-type': ['audio/flac'],
        }),
      );
      expect(
        () => cloud189ReadResponse(
          response,
          start: 8,
          end: null,
          entrySize: 100,
          contentType: 'audio/flac',
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('4b_200 start10 beyond available throws RangeError', () {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
      final responseBody = ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          'content-length': ['8'],
          'content-type': ['audio/flac'],
        },
      );
      final response = Response<ResponseBody>(
        data: responseBody,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/test'),
        headers: Headers.fromMap({
          'content-length': ['8'],
          'content-type': ['audio/flac'],
        }),
      );
      expect(
        () => cloud189ReadResponse(
          response,
          start: 10,
          end: null,
          entrySize: 100,
          contentType: 'audio/flac',
        ),
        throwsA(isA<RangeError>()),
      );
    });

    test('5_206 missing Content-Range throws StateError', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final responseBody = ResponseBody.fromBytes(
        bytes,
        206,
        headers: {
          'content-type': ['audio/flac'],
        },
      );
      final response = Response<ResponseBody>(
        data: responseBody,
        statusCode: 206,
        requestOptions: RequestOptions(path: '/test'),
        headers: Headers.fromMap({
          'content-type': ['audio/flac'],
        }),
      );
      expect(
        () => cloud189ReadResponse(
          response,
          start: 0,
          end: 3,
          entrySize: 100,
          contentType: 'audio/flac',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('6_206 range 0-4/8 CL10 mismatch throws StateError synchronously', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final responseBody = ResponseBody.fromBytes(
        bytes,
        206,
        headers: {
          'content-range': ['bytes 0-4/8'],
          'content-length': ['10'],
          'content-type': ['audio/flac'],
        },
      );
      final response = Response<ResponseBody>(
        data: responseBody,
        statusCode: 206,
        requestOptions: RequestOptions(path: '/test'),
        headers: Headers.fromMap({
          'content-range': ['bytes 0-4/8'],
          'content-length': ['10'],
          'content-type': ['audio/flac'],
        }),
      );
      expect(
        () => cloud189ReadResponse(
          response,
          start: 0,
          end: 5,
          entrySize: 100,
          contentType: 'audio/flac',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      '7_206 range 0-9/10 CL10 body[0,1] constructs but stream throws StateError',
      () async {
        final bytes = Uint8List.fromList([0, 1]);
        final responseBody = ResponseBody.fromBytes(
          bytes,
          206,
          headers: {
            'content-range': ['bytes 0-9/10'],
            'content-length': ['10'],
            'content-type': ['audio/flac'],
          },
        );
        final response = Response<ResponseBody>(
          data: responseBody,
          statusCode: 206,
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'content-range': ['bytes 0-9/10'],
            'content-length': ['10'],
            'content-type': ['audio/flac'],
          }),
        );
        final result = cloud189ReadResponse(
          response,
          start: 0,
          end: null,
          entrySize: null,
          contentType: 'audio/flac',
        );
        await expectLater(result.stream.toList(), throwsStateError);
      },
    );

    test('8_200 CL0 empty body startNULL endNULL entrySizeNULL', () async {
      final bytes = Uint8List.fromList(<int>[]);
      final responseBody = ResponseBody.fromBytes(
        bytes,
        200,
        headers: {
          'content-length': ['0'],
          'content-type': ['audio/flac'],
        },
      );
      final response = Response<ResponseBody>(
        data: responseBody,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/test'),
        headers: Headers.fromMap({
          'content-length': ['0'],
          'content-type': ['audio/flac'],
        }),
      );
      final result = cloud189ReadResponse(
        response,
        start: null,
        end: null,
        entrySize: null,
        contentType: 'audio/flac',
      );
      expect(result.contentLength, 0);
      expect(result.sourceLength, 0);
      final consumed = <int>[];
      await for (final chunk in result.stream) {
        consumed.addAll(chunk);
      }
      expect(consumed, isEmpty);
    });

    test(
      '9_200 missingCL entrySizeNULL startNULL endNULL body[0..7]',
      () async {
        final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
        final responseBody = ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            'content-type': ['audio/flac'],
          },
        );
        final response = Response<ResponseBody>(
          data: responseBody,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'content-type': ['audio/flac'],
          }),
        );
        final result = cloud189ReadResponse(
          response,
          start: null,
          end: null,
          entrySize: null,
          contentType: 'audio/flac',
        );
        expect(result.contentLength, 0);
        expect(result.sourceLength, null);
        final consumed = <int>[];
        await for (final chunk in result.stream) {
          consumed.addAll(chunk);
        }
        expect(consumed, [0, 1, 2, 3, 4, 5, 6, 7]);
      },
    );

    test(
      '10_200 missingCL entrySizeNULL start2 end5 body[0..7] len0 not3',
      () async {
        final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7]);
        final responseBody = ResponseBody.fromBytes(
          bytes,
          200,
          headers: {
            'content-type': ['audio/flac'],
          },
        );
        final response = Response<ResponseBody>(
          data: responseBody,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'content-type': ['audio/flac'],
          }),
        );
        final result = cloud189ReadResponse(
          response,
          start: 2,
          end: 5,
          entrySize: null,
          contentType: 'audio/flac',
        );
        expect(result.contentLength, 0);
        expect(result.sourceLength, null);
        final consumed = <int>[];
        await for (final chunk in result.stream) {
          consumed.addAll(chunk);
        }
        expect(consumed, [2, 3, 4]);
      },
    );

    test('11_206 bytes 2-5/* CL4 entrySizeNULL start2 end6', () async {
      final bytes = Uint8List.fromList([2, 3, 4, 5]);
      final responseBody = ResponseBody.fromBytes(
        bytes,
        206,
        headers: {
          'content-range': ['bytes 2-5/*'],
          'content-length': ['4'],
          'content-type': ['audio/flac'],
        },
      );
      final response = Response<ResponseBody>(
        data: responseBody,
        statusCode: 206,
        requestOptions: RequestOptions(path: '/test'),
        headers: Headers.fromMap({
          'content-range': ['bytes 2-5/*'],
          'content-length': ['4'],
          'content-type': ['audio/flac'],
        }),
      );
      final result = cloud189ReadResponse(
        response,
        start: 2,
        end: 6,
        entrySize: null,
        contentType: 'audio/flac',
      );
      expect(result.offset, 2);
      expect(result.contentLength, 4);
      expect(result.sourceLength, null);
      final consumed = <int>[];
      await for (final chunk in result.stream) {
        consumed.addAll(chunk);
      }
      expect(consumed, [2, 3, 4, 5]);
    });

    test(
      'CR bytes 0-9/* with 10 bytes, stale entrySize5 => null sourceLength and all bytes',
      () async {
        final bytes = Uint8List.fromList(List<int>.generate(10, (i) => i));
        final responseBody = ResponseBody.fromBytes(
          bytes,
          206,
          headers: {
            'content-range': ['bytes 0-9/*'],
            'content-length': ['10'],
            'content-type': ['audio/flac'],
          },
        );
        final response = Response<ResponseBody>(
          data: responseBody,
          statusCode: 206,
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'content-range': ['bytes 0-9/*'],
            'content-length': ['10'],
            'content-type': ['audio/flac'],
          }),
        );
        final result = cloud189ReadResponse(
          response,
          start: 0,
          end: null,
          entrySize: 5,
          contentType: 'audio/flac',
        );
        expect(result.sourceLength, isNull);
        final consumed = <int>[];
        await for (final chunk in result.stream) {
          consumed.addAll(chunk);
        }
        expect(consumed, bytes);
        expect(consumed.length, 10);
      },
    );

    test(
      'bounded bytes after advertised 0-9/* must not restore size5',
      () async {
        final bytes = Uint8List.fromList(List<int>.generate(10, (i) => i));
        final responseBody = ResponseBody.fromBytes(
          bytes,
          206,
          headers: {
            'content-range': ['bytes 0-9/*'],
            'content-length': ['10'],
            'content-type': ['audio/flac'],
          },
        );
        final response = Response<ResponseBody>(
          data: responseBody,
          statusCode: 206,
          requestOptions: RequestOptions(path: '/test'),
          headers: Headers.fromMap({
            'content-range': ['bytes 0-9/*'],
            'content-length': ['10'],
            'content-type': ['audio/flac'],
          }),
        );
        final result = cloud189ReadResponse(
          response,
          start: 0,
          end: 5,
          entrySize: 5,
          contentType: 'audio/flac',
        );
        expect(result.contentLength, 5);
        expect(result.sourceLength, isNull);
        final consumed = <int>[];
        await for (final chunk in result.stream) {
          consumed.addAll(chunk);
        }
        expect(consumed, bytes.sublist(0, 5));
      },
    );
  });
}
