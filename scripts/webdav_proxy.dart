import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _proxyPrefix = '/api/webdav';

Future<void> main(List<String> args) async {
  final options = _ProxyOptions.parse(args);
  final server = await HttpServer.bind(options.host, options.port);

  stdout.writeln(
    'WebDAV proxy listening at http://${options.host.address}:${server.port}$_proxyPrefix/',
  );

  await for (final request in server) {
    unawaited(_handleRequest(request));
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  if (request.method == 'OPTIONS') {
    _applyCorsHeaders(request.response, request);
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  if (!request.uri.path.startsWith(_proxyPrefix)) {
    request.response.statusCode = HttpStatus.notFound;
    _applyCorsHeaders(request.response, request);
    request.response.write('Not found');
    await request.response.close();
    return;
  }

  final targetUrlHeader = request.headers.value('x-omnitune-target-url');
  if (targetUrlHeader != null && targetUrlHeader.trim().isNotEmpty) {
    final targetUri = Uri.tryParse(targetUrlHeader.trim());
    if (targetUri == null || !targetUri.hasScheme) {
      await _writeJsonError(
        request,
        HttpStatus.badRequest,
        'Invalid target WebDAV request URL.',
      );
      return;
    }

    await _forwardRequest(request, targetUri);
    return;
  }

  final targetBaseUrl = request.headers.value('x-omnitune-target-base-url');
  if (targetBaseUrl == null || targetBaseUrl.trim().isEmpty) {
    await _writeJsonError(
      request,
      HttpStatus.badRequest,
      'Missing x-omnitune-target-base-url header.',
    );
    return;
  }

  final targetBaseUri = Uri.tryParse(targetBaseUrl.trim());
  if (targetBaseUri == null || !targetBaseUri.hasScheme) {
    await _writeJsonError(
      request,
      HttpStatus.badRequest,
      'Invalid target WebDAV base URL.',
    );
    return;
  }

  final targetUri = _resolveTargetUri(request.uri, targetBaseUri);
  await _forwardRequest(request, targetUri);
}

Future<void> _forwardRequest(HttpRequest request, Uri targetUri) async {
  final client = HttpClient();

  try {
    final upstreamRequest = await client.openUrl(request.method, targetUri);
    upstreamRequest.followRedirects =
        request.method == 'GET' || request.method == 'HEAD';
    _copyRequestHeaders(request.headers, upstreamRequest.headers);

    final username = request.headers.value('x-omnitune-username') ?? '';
    final password = request.headers.value('x-omnitune-password') ?? '';
    if (username.isNotEmpty || password.isNotEmpty) {
      upstreamRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      );
    }

    if (request.method != 'GET' && request.method != 'HEAD') {
      await upstreamRequest.addStream(request);
    }

    final upstreamResponse = await upstreamRequest.close();
    request.response.statusCode = upstreamResponse.statusCode;
    _copyResponseHeaders(upstreamResponse.headers, request.response.headers);
    _applyCorsHeaders(request.response, request);
    await request.response.addStream(upstreamResponse);
  } catch (error) {
    await _writeJsonError(
      request,
      HttpStatus.badGateway,
      'Proxy request failed: $error',
    );
  } finally {
    await request.response.close();
    client.close(force: true);
  }
}

Uri _resolveTargetUri(Uri proxyUri, Uri baseUri) {
  final normalizedBase = baseUri.path.endsWith('/')
      ? baseUri
      : baseUri.replace(path: '${baseUri.path}/');
  final suffix = proxyUri.path.substring(_proxyPrefix.length);
  final relativePath = suffix.startsWith('/') ? suffix.substring(1) : suffix;
  final resolved = normalizedBase.resolve(relativePath);
  if (proxyUri.hasQuery) {
    return resolved.replace(query: proxyUri.query);
  }
  return resolved;
}

void _copyRequestHeaders(HttpHeaders source, HttpHeaders target) {
  source.forEach((name, values) {
    final lower = name.toLowerCase();
    if (lower == HttpHeaders.hostHeader ||
        lower == 'origin' ||
        lower == HttpHeaders.refererHeader ||
        lower == HttpHeaders.contentLengthHeader ||
        lower.startsWith('x-omnitune-')) {
      return;
    }
    for (final value in values) {
      target.add(name, value);
    }
  });
}

void _copyResponseHeaders(HttpHeaders source, HttpHeaders target) {
  source.forEach((name, values) {
    final lower = name.toLowerCase();
    if (lower == HttpHeaders.transferEncodingHeader ||
        lower == HttpHeaders.connectionHeader) {
      return;
    }
    for (final value in values) {
      target.add(name, value);
    }
  });
}

void _applyCorsHeaders(HttpResponse response, HttpRequest request) {
  final origin = request.headers.value('origin') ?? '*';
  response.headers
    ..set('access-control-allow-origin', origin)
    ..set('access-control-allow-methods', 'GET,HEAD,OPTIONS,PROPFIND')
    ..set(
      'access-control-allow-headers',
      'Authorization,Content-Type,Depth,Range,Accept,Accept-Charset,X-OmniTune-Target-Base-Url,X-OmniTune-Username,X-OmniTune-Password',
    )
    ..set(
      'access-control-expose-headers',
      'Content-Length,Content-Range,Content-Type,DAV,ETag,Last-Modified',
    )
    ..set('access-control-allow-credentials', 'false')
    ..set('vary', 'Origin');
}

Future<void> _writeJsonError(
  HttpRequest request,
  int statusCode,
  String message,
) async {
  _applyCorsHeaders(request.response, request);
  request.response.statusCode = statusCode;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(<String, String>{'error': message}));
}

class _ProxyOptions {
  const _ProxyOptions({required this.host, required this.port});

  final InternetAddress host;
  final int port;

  static _ProxyOptions parse(List<String> args) {
    var host = InternetAddress.loopbackIPv4;
    var port = 8788;

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--host' && index + 1 < args.length) {
        host = InternetAddress(args[++index]);
        continue;
      }
      if (arg == '--port' && index + 1 < args.length) {
        port = int.tryParse(args[++index]) ?? port;
      }
    }

    return _ProxyOptions(host: host, port: port);
  }
}
