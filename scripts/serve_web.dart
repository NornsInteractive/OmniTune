import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final options = _ServeOptions.parse(args);
  final root = Directory(p.normalize(p.absolute(options.directory)));
  final indexFile = File(p.join(root.path, 'index.html'));

  if (!await root.exists()) {
    stderr.writeln('Build directory not found: ${root.path}');
    exitCode = 64;
    return;
  }
  if (!await indexFile.exists()) {
    stderr.writeln('Missing index.html in ${root.path}');
    exitCode = 64;
    return;
  }

  final server = await _bindServer(options.port);
  stdout.writeln(
    'Serving ${root.path} at http://localhost:${server.port} with SPA fallback',
  );

  await for (final request in server) {
    _handleRequest(request, root, indexFile);
  }
}

Future<HttpServer> _bindServer(int preferredPort) async {
  try {
    return await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
  } on SocketException catch (error) {
    final portInUse =
        error.osError?.errorCode == 98 ||
        error.osError?.errorCode == 48 ||
        error.message.toLowerCase().contains('address already in use');
    if (!portInUse) {
      rethrow;
    }

    final fallbackServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    stdout.writeln(
      'Port $preferredPort is unavailable; using port ${fallbackServer.port} instead.',
    );
    return fallbackServer;
  }
}

Future<void> _handleRequest(
  HttpRequest request,
  Directory root,
  File indexFile,
) async {
  if (request.method != 'GET' && request.method != 'HEAD') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    await request.response.close();
    return;
  }

  final file = await _resolveRequestedFile(request.uri, root);
  if (file != null) {
    await _serveFile(request, file);
    return;
  }

  await _serveFile(request, indexFile, contentType: ContentType.html);
}

Future<File?> _resolveRequestedFile(Uri uri, Directory root) async {
  final relativePath = uri.path == '/' ? 'index.html' : uri.path.substring(1);
  final normalizedPath = p.normalize(relativePath);
  if (normalizedPath.startsWith('..')) {
    return null;
  }

  final resolvedPath = p.join(root.path, normalizedPath);
  final entityType = FileSystemEntity.typeSync(resolvedPath);
  if (entityType == FileSystemEntityType.file) {
    return File(resolvedPath);
  }
  if (entityType == FileSystemEntityType.directory) {
    final nestedIndex = File(p.join(resolvedPath, 'index.html'));
    if (await nestedIndex.exists()) {
      return nestedIndex;
    }
  }

  return null;
}

Future<void> _serveFile(
  HttpRequest request,
  File file, {
  ContentType? contentType,
}) async {
  request.response.headers.contentType =
      contentType ?? _contentTypeFor(file.path);
  request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

  if (request.method == 'HEAD') {
    request.response.contentLength = await file.length();
    await request.response.close();
    return;
  }

  await request.response.addStream(file.openRead());
  await request.response.close();
}

ContentType _contentTypeFor(String path) {
  final extension = p.extension(path).toLowerCase();
  return switch (extension) {
    '.css' => ContentType('text', 'css', charset: 'utf-8'),
    '.js' => ContentType('text', 'javascript', charset: 'utf-8'),
    '.json' => ContentType('application', 'json', charset: 'utf-8'),
    '.map' => ContentType('application', 'json', charset: 'utf-8'),
    '.png' => ContentType('image', 'png'),
    '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
    '.svg' => ContentType('image', 'svg+xml'),
    '.wasm' => ContentType('application', 'wasm'),
    '.woff' => ContentType('font', 'woff'),
    '.woff2' => ContentType('font', 'woff2'),
    _ => ContentType.html,
  };
}

class _ServeOptions {
  const _ServeOptions({required this.directory, required this.port});

  final String directory;
  final int port;

  static _ServeOptions parse(List<String> args) {
    var directory = 'build/web';
    var port = 8080;

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--directory' && index + 1 < args.length) {
        directory = args[++index];
        continue;
      }
      if (arg == '--port' && index + 1 < args.length) {
        port = int.tryParse(args[++index]) ?? port;
      }
    }

    return _ServeOptions(directory: directory, port: port);
  }
}
