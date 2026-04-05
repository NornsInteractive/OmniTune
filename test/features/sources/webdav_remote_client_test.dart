import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';

void main() {
  test(
    'follows OpenList-style redirects without forwarding WebDAV auth headers',
    () async {
      final requests = <_CapturedRequest>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        requests.add(_CapturedRequest.fromRequest(request));

        if (request.method == 'OPTIONS' && request.uri.path == '/dav/') {
          final authorization = request.headers.value(
            HttpHeaders.authorizationHeader,
          );
          if (authorization == _expectedBasicAuth) {
            request.response.statusCode = HttpStatus.ok;
          } else {
            request.response.statusCode = HttpStatus.unauthorized;
            request.response.headers.set(
              HttpHeaders.wwwAuthenticateHeader,
              'Basic realm="OpenList"',
            );
          }
          await request.response.close();
          return;
        }

        if (request.method == 'GET' &&
            request.uri.pathSegments.length == 4 &&
            request.uri.pathSegments[0] == 'dav' &&
            request.uri.pathSegments[1] == 'Music' &&
            request.uri.pathSegments[2] == 'Album One' &&
            request.uri.pathSegments[3] == '中文 歌曲.flac') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            '../redirect/step?token=one',
          );
          await request.response.close();
          return;
        }

        if (request.method == 'GET' &&
            request.uri.path == '/dav/Music/redirect/step') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            'http://${server.address.host}:${server.port}/download/final.flac?token=two',
          );
          await request.response.close();
          return;
        }

        if (request.method == 'GET' &&
            request.uri.path == '/download/final.flac') {
          final authorization = request.headers.value(
            HttpHeaders.authorizationHeader,
          );
          if (authorization != null) {
            request.response.statusCode = HttpStatus.badRequest;
          } else {
            final bytes = ascii.encode('fLaCtest-data');
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType('audio', 'flac');
            request.response.headers.contentLength = bytes.length;
            request.response.add(bytes);
          }
          await request.response.close();
          return;
        }

        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      final profile = SourceProfile(
        id: 'openlist',
        name: 'OpenList',
        protocol: SourceProtocol.webdav,
        baseUrl: 'http://${server.address.host}:${server.port}/dav/',
        username: 'demo',
        password: 'secret',
        rootPath: '/Music/',
      );
      final client = PackageWebDavRemoteClient(profile);

      try {
        await client.ping();
        final result = await client.openRead('/Music/Album One/中文 歌曲.flac');
        final bytes = await result.stream.expand((chunk) => chunk).toList();

        expect(ascii.decode(bytes), 'fLaCtest-data');
        expect(
          requests
              .where((request) => request.path == '/download/final.flac')
              .single
              .authorization,
          isNull,
        );
        expect(
          requests.any(
            (request) =>
                request.pathSegments.length == 4 &&
                request.pathSegments[2] == 'Album One' &&
                request.pathSegments[3] == '中文 歌曲.flac',
          ),
          isTrue,
        );
      } finally {
        await client.dispose();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );

  test('reads redirected lyric files through the same download flow', () async {
    final requests = <_CapturedRequest>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      requests.add(_CapturedRequest.fromRequest(request));

      if (request.method == 'OPTIONS' && request.uri.path == '/dav/') {
        final authorization = request.headers.value(
          HttpHeaders.authorizationHeader,
        );
        if (authorization == _expectedBasicAuth) {
          request.response.statusCode = HttpStatus.ok;
        } else {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.headers.set(
            HttpHeaders.wwwAuthenticateHeader,
            'Basic realm="OpenList"',
          );
        }
        await request.response.close();
        return;
      }

      if (request.method == 'GET' &&
          request.uri.path == '/dav/Music/song.lrc') {
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          HttpHeaders.locationHeader,
          '/download/song.lrc?token=lyric',
        );
        await request.response.close();
        return;
      }

      if (request.method == 'GET' && request.uri.path == '/download/song.lrc') {
        if (request.headers.value(HttpHeaders.authorizationHeader) != null) {
          request.response.statusCode = HttpStatus.badRequest;
        } else {
          final content = utf8.encode('[00:00.00]Hello');
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.text;
          request.response.headers.contentLength = content.length;
          request.response.add(content);
        }
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    final profile = SourceProfile(
      id: 'openlist',
      name: 'OpenList',
      protocol: SourceProtocol.webdav,
      baseUrl: 'http://${server.address.host}:${server.port}/dav/',
      username: 'demo',
      password: 'secret',
      rootPath: '/Music/',
    );
    final client = PackageWebDavRemoteClient(profile);

    try {
      await client.ping();
      final lyrics = await client.readText('/Music/song.lrc');

      expect(lyrics, '[00:00.00]Hello');
      expect(
        requests
            .where((request) => request.path == '/download/song.lrc')
            .single
            .authorization,
        isNull,
      );
    } finally {
      await client.dispose();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}

const _expectedBasicAuth = 'Basic ZGVtbzpzZWNyZXQ=';

class _CapturedRequest {
  const _CapturedRequest({
    required this.path,
    required this.pathSegments,
    required this.authorization,
  });

  factory _CapturedRequest.fromRequest(HttpRequest request) {
    return _CapturedRequest(
      path: request.uri.path,
      pathSegments: request.uri.pathSegments,
      authorization: request.headers.value(HttpHeaders.authorizationHeader),
    );
  }

  final String path;
  final List<String> pathSegments;
  final String? authorization;
}
