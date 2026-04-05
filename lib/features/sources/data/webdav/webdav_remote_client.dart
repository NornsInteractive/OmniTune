import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:xml/xml.dart';

import '../../../../core/models/source_profile.dart';

class WebDavRemoteFile {
  const WebDavRemoteFile({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.mimeType,
    this.size,
    this.modifiedAt,
  });

  final String path;
  final String name;
  final bool isDirectory;
  final String? mimeType;
  final int? size;
  final DateTime? modifiedAt;
}

class WebDavReadResult {
  const WebDavReadResult({
    required this.stream,
    required this.offset,
    required this.contentLength,
    required this.contentType,
    this.sourceLength,
  });

  final Stream<List<int>> stream;
  final int offset;
  final int contentLength;
  final String contentType;
  final int? sourceLength;
}

class WebDavDirectoryAttempt {
  const WebDavDirectoryAttempt({
    required this.path,
    required this.requestUri,
    required this.responseLength,
    required this.hrefCount,
    required this.entryCount,
    this.firstHref,
    this.errorMessage,
  });

  final String path;
  final Uri requestUri;
  final int responseLength;
  final int hrefCount;
  final int entryCount;
  final String? firstHref;
  final String? errorMessage;
}

class WebDavDirectoryDebugInfo {
  const WebDavDirectoryDebugInfo({
    required this.requestedPath,
    required this.attempts,
    required this.entryCount,
  });

  final String requestedPath;
  final List<WebDavDirectoryAttempt> attempts;
  final int entryCount;

  List<String> describe() {
    final lines = <String>[
      'Requested path: $requestedPath',
      'Resolved items: $entryCount',
    ];

    for (final attempt in attempts) {
      lines.add(
        'Attempt ${attempt.path} -> ${attempt.requestUri} | href=${attempt.hrefCount}, entries=${attempt.entryCount}, bytes=${attempt.responseLength}',
      );
      if (attempt.firstHref != null && attempt.firstHref!.isNotEmpty) {
        lines.add('First href: ${attempt.firstHref}');
      }
      if (attempt.errorMessage != null && attempt.errorMessage!.isNotEmpty) {
        lines.add('Error: ${attempt.errorMessage}');
      }
    }

    return lines;
  }
}

List<WebDavRemoteFile> parseWebDavDirectoryResponse({
  required String xmlContent,
  required String requestPath,
  required Uri baseUri,
  required Uri requestUri,
}) {
  if (xmlContent.trim().isEmpty) {
    return const [];
  }

  final normalizedPath = _normalizeDirectoryPathValue(requestPath);
  final document = XmlDocument.parse(xmlContent);
  final responses = document.findAllElements('response', namespace: '*');
  final files = <WebDavRemoteFile>[];

  for (final responseNode in responses) {
    final href = responseNode
        .findElements('href', namespace: '*')
        .map((node) => node.innerText.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    if (href == null) {
      continue;
    }

    final prop = _extractSuccessProp(responseNode);
    if (prop == null) {
      continue;
    }

    final isDirectory = prop
        .findElements('resourcetype', namespace: '*')
        .expand((node) => node.findElements('collection', namespace: '*'))
        .isNotEmpty;
    final itemPath = _resolveRelativePathValue(
      href,
      requestPath: requestPath,
      baseUri: baseUri,
      requestUri: requestUri,
      isDirectory: isDirectory,
    );

    if (itemPath == normalizedPath) {
      continue;
    }

    files.add(
      WebDavRemoteFile(
        path: itemPath,
        name: _resolveNameValue(
          prop
              .findElements('displayname', namespace: '*')
              .firstOrNull
              ?.innerText,
          itemPath,
        ),
        isDirectory: isDirectory,
        mimeType: prop
            .findElements('getcontenttype', namespace: '*')
            .firstOrNull
            ?.innerText
            .trim(),
        size: int.tryParse(
          prop
                  .findElements('getcontentlength', namespace: '*')
                  .firstOrNull
                  ?.innerText
                  .trim() ??
              '',
        ),
        modifiedAt: _parseModifiedAtValue(
          prop
              .findElements('getlastmodified', namespace: '*')
              .firstOrNull
              ?.innerText,
        ),
      ),
    );
  }

  return files;
}

abstract class WebDavRemoteClient {
  Future<void> ping();

  Future<List<WebDavRemoteFile>> readDirectory(String path);

  Future<WebDavReadResult> openRead(String path, {int? start, int? end});

  Future<String?> readText(String path);

  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo;

  Future<void> dispose();
}

class PackageWebDavRemoteClient implements WebDavRemoteClient {
  PackageWebDavRemoteClient(SourceProfile profile)
    : _profile = profile,
      _baseUri = Uri.parse(profile.normalizedBaseUrl),
      _client = webdav.newClient(
        profile.normalizedBaseUrl,
        user: profile.username,
        password: profile.password,
      ) {
    _client.setConnectTimeout(10000);
    _client.setReceiveTimeout(20000);
    _client.setSendTimeout(20000);
    _client.setHeaders({'accept-charset': 'utf-8'});
  }

  static const _propfindBody = '''
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
    <d:getcontentlength/>
    <d:getcontenttype/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>
''';

  final SourceProfile _profile;
  final Uri _baseUri;
  final webdav.Client _client;

  @override
  WebDavDirectoryDebugInfo? lastDirectoryDebugInfo;

  @override
  Future<void> ping() => _client.ping();

  @override
  Future<List<WebDavRemoteFile>> readDirectory(String path) async {
    final normalizedPath = _normalizeDirectoryPathValue(path);
    final candidatePaths = _candidateDirectoryPaths(normalizedPath);
    final attempts = <WebDavDirectoryAttempt>[];
    Object? lastError;

    for (final candidatePath in candidatePaths) {
      final requestUri = _requestUriFor(candidatePath);
      final requestPath = _encodeDirectoryRequestPath(candidatePath);

      try {
        final response = await _client.c.wdPropfind(
          _client,
          requestPath,
          true,
          _propfindBody,
        );
        final xmlContent = response.data is String
            ? response.data as String
            : '';
        final firstHref = _extractFirstHref(xmlContent);
        final files = xmlContent.trim().isEmpty
            ? const <WebDavRemoteFile>[]
            : parseWebDavDirectoryResponse(
                xmlContent: xmlContent,
                requestPath: candidatePath,
                baseUri: _baseUri,
                requestUri: requestUri,
              );

        attempts.add(
          WebDavDirectoryAttempt(
            path: candidatePath,
            requestUri: requestUri,
            responseLength: utf8.encode(xmlContent).length,
            hrefCount: _countHrefValues(xmlContent),
            entryCount: files.length,
            firstHref: firstHref,
          ),
        );

        if (files.isNotEmpty) {
          lastDirectoryDebugInfo = WebDavDirectoryDebugInfo(
            requestedPath: normalizedPath,
            attempts: attempts,
            entryCount: files.length,
          );
          return files;
        }
      } catch (error) {
        lastError = error;
        attempts.add(
          WebDavDirectoryAttempt(
            path: candidatePath,
            requestUri: requestUri,
            responseLength: 0,
            hrefCount: 0,
            entryCount: 0,
            errorMessage: error.toString(),
          ),
        );
      }
    }

    lastDirectoryDebugInfo = WebDavDirectoryDebugInfo(
      requestedPath: normalizedPath,
      attempts: attempts,
      entryCount: 0,
    );

    if (lastError != null &&
        attempts.every((attempt) => attempt.errorMessage != null)) {
      throw lastError;
    }

    return const [];
  }

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    final normalizedPath = _normalizeItemPathValue(path);
    final candidatePaths = _candidateItemPaths(normalizedPath);
    Object? lastError;

    for (final candidatePath in candidatePaths) {
      try {
        return await _openReadOnce(candidatePath, start: start, end: end);
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError != null) {
      throw _mapFileReadError(lastError, normalizedPath, candidatePaths);
    }

    throw StateError('WebDAV file response was empty for $normalizedPath.');
  }

  @override
  Future<String?> readText(String path) async {
    final normalizedPath = _normalizeItemPathValue(path);
    final candidatePaths = _candidateItemPaths(normalizedPath);
    Object? lastError;

    for (final candidatePath in candidatePaths) {
      final requestUri = _requestUriForItem(candidatePath);
      final requestPath = _encodeItemRequestPath(candidatePath);
      final response = await _sendGetRequest<List<int>>(
        requestUri: requestUri,
        requestPathForAuth: requestPath,
        responseType: ResponseType.bytes,
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode == 404) {
        continue;
      }
      if (statusCode != 200) {
        lastError = DioException.badResponse(
          statusCode: statusCode,
          requestOptions: response.requestOptions,
          response: response,
        );
        continue;
      }

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      return utf8.decode(bytes, allowMalformed: true);
    }

    if (lastError != null) {
      throw _mapFileReadError(lastError, normalizedPath, candidatePaths);
    }

    return null;
  }

  @override
  Future<void> dispose() async {}

  List<String> _candidateDirectoryPaths(String requestedPath) {
    final candidates = <String>[requestedPath];
    final configuredRoot = _normalizeDirectoryPathValue(
      _profile.normalizedRootPath,
    );
    final effectiveRoot = _normalizeDirectoryPathValue(
      _profile.effectiveRootPath,
    );

    void addCandidate(String value) {
      if (!candidates.contains(value)) {
        candidates.add(value);
      }
    }

    if (requestedPath == effectiveRoot) {
      addCandidate(configuredRoot);
      addCandidate('/');
    } else if (requestedPath == '/') {
      addCandidate(configuredRoot);
      addCandidate(effectiveRoot);
    }

    return candidates;
  }

  List<String> _candidateItemPaths(String requestedPath) {
    final normalizedPath = _normalizeItemPathValue(requestedPath);
    final candidates = <String>[normalizedPath];
    final configuredRoot = _normalizeDirectoryPathValue(
      _profile.normalizedRootPath,
    );
    final effectiveRoot = _normalizeDirectoryPathValue(
      _profile.effectiveRootPath,
    );

    void addCandidate(String value) {
      final normalizedValue = _normalizeItemPathValue(value);
      if (!candidates.contains(normalizedValue)) {
        candidates.add(normalizedValue);
      }
    }

    final rebasedToConfigured = _rebaseItemPath(
      normalizedPath,
      fromRoot: effectiveRoot,
      toRoot: configuredRoot,
    );
    if (rebasedToConfigured != null) {
      addCandidate(rebasedToConfigured);
    }

    final rebasedToEffective = _rebaseItemPath(
      normalizedPath,
      fromRoot: configuredRoot,
      toRoot: effectiveRoot,
    );
    if (rebasedToEffective != null) {
      addCandidate(rebasedToEffective);
    }

    if (configuredRoot != '/') {
      addCandidate(
        '${configuredRoot.substring(0, configuredRoot.length - 1)}$normalizedPath',
      );
    }

    return candidates;
  }

  Uri _requestUriFor(String normalizedPath) {
    final relativePath = _encodeRelativePath(normalizedPath, directory: true);
    return relativePath.isEmpty ? _baseUri : _baseUri.resolve(relativePath);
  }

  Uri _requestUriForItem(String normalizedPath) {
    final relativePath = _encodeRelativePath(normalizedPath, directory: false);
    return relativePath.isEmpty ? _baseUri : _baseUri.resolve(relativePath);
  }

  String _encodeDirectoryRequestPath(String path) {
    return _encodeRequestPath(path, directory: true);
  }

  String _encodeItemRequestPath(String path) {
    return _encodeRequestPath(path, directory: false);
  }

  Future<WebDavReadResult> _openReadOnce(
    String candidatePath, {
    int? start,
    int? end,
  }) async {
    final requestUri = _requestUriForItem(candidatePath);
    final requestPath = _encodeItemRequestPath(candidatePath);
    final response = await _sendGetRequest<ResponseBody>(
      requestUri: requestUri,
      requestPathForAuth: requestPath,
      responseType: ResponseType.stream,
      start: start,
      end: end,
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode != 200 && statusCode != 206) {
      throw DioException.badResponse(
        statusCode: statusCode,
        requestOptions: response.requestOptions,
        response: response,
      );
    }

    final responseBody = response.data;
    if (responseBody == null) {
      throw StateError('WebDAV stream response body was empty.');
    }

    final contentTypeHeader =
        response.headers.value(Headers.contentTypeHeader) ?? 'audio/mpeg';
    final contentType = contentTypeHeader.split(';').first;
    final contentLength =
        int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        0;
    final contentRange = response.headers.value('content-range');

    var resolvedOffset = start ?? 0;
    int? resolvedSourceLength;
    var resolvedContentLength = contentLength;
    Stream<List<int>> resolvedStream = responseBody.stream.map(
      (chunk) => chunk,
    );

    if (contentRange != null) {
      final match = RegExp(
        r'bytes\s+(\d+)-(\d+)/(\d+|\*)',
      ).firstMatch(contentRange);
      if (match != null) {
        resolvedOffset = int.parse(match.group(1)!);
        final total = match.group(3);
        if (total != null && total != '*') {
          resolvedSourceLength = int.parse(total);
        }
      }
    } else if (statusCode == 200 && contentLength > 0) {
      resolvedSourceLength = contentLength;
    }

    if ((start != null || end != null) &&
        statusCode == 200 &&
        contentRange == null) {
      final effectiveSkip = start ?? 0;
      final effectiveTake = end != null
          ? end - effectiveSkip
          : (resolvedSourceLength != null
                ? resolvedSourceLength - effectiveSkip
                : null);
      resolvedStream = _sliceByteStream(
        responseBody.stream,
        skip: effectiveSkip,
        take: effectiveTake,
      );
      resolvedOffset = effectiveSkip;
      if (effectiveTake != null) {
        resolvedContentLength = effectiveTake;
      } else if (resolvedSourceLength != null) {
        resolvedContentLength = resolvedSourceLength - effectiveSkip;
      }
    }

    return WebDavReadResult(
      stream: resolvedStream,
      offset: resolvedOffset,
      contentLength: resolvedContentLength,
      contentType: contentType,
      sourceLength: resolvedSourceLength,
    );
  }

  Future<Response<T>> _sendGetRequest<T>({
    required Uri requestUri,
    required String requestPathForAuth,
    required ResponseType responseType,
    int? start,
    int? end,
  }) async {
    final baseHeaders = Map<String, dynamic>.from(_client.c.options.headers);
    if (start != null || end != null) {
      final rangeStart = start ?? 0;
      final rangeEnd = end != null ? end - 1 : '';
      baseHeaders['range'] = 'bytes=$rangeStart-$rangeEnd';
    }

    var currentUri = requestUri;
    var attachAuth = true;

    for (var redirectCount = 0; redirectCount < 5; redirectCount++) {
      final response = await _requestRaw<T>(
        requestUri: currentUri,
        requestPathForAuth: attachAuth ? requestPathForAuth : null,
        responseType: responseType,
        headers: baseHeaders,
      );

      final statusCode = response.statusCode ?? 0;
      final location = response.headers.value('location');
      if (!_isRedirectStatus(statusCode) ||
          location == null ||
          location.isEmpty) {
        return response;
      }

      final responseBody = response.data;
      if (responseBody is ResponseBody) {
        await responseBody.stream.drain<void>();
      }

      currentUri = currentUri.resolve(location);
      attachAuth = false;
    }

    throw StateError(
      'Too many redirects while reading WebDAV file: $requestUri',
    );
  }

  Future<Response<T>> _requestRaw<T>({
    required Uri requestUri,
    required String? requestPathForAuth,
    required ResponseType responseType,
    required Map<String, dynamic> headers,
  }) {
    final effectiveHeaders = Map<String, dynamic>.from(headers);
    if (requestPathForAuth != null) {
      final authorization = _client.auth.authorize('GET', requestPathForAuth);
      if (authorization != null) {
        effectiveHeaders['authorization'] = authorization;
      }
    }
    effectiveHeaders.remove('host');

    return _client.c.requestUri<T>(
      requestUri,
      options: Options(
        method: 'GET',
        headers: effectiveHeaders,
        responseType: responseType,
        followRedirects: false,
        validateStatus: (status) => true,
      ),
    );
  }

  Object _mapFileReadError(
    Object error,
    String normalizedPath,
    List<String> candidatePaths,
  ) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 400 && _looksLikeOpenListWebDav()) {
        return StateError(
          'OpenList WebDAV failed to read file "$normalizedPath" with HTTP 400. '
          'The OpenList 302 redirect download may have rejected the request. '
          'Tried paths: ${candidatePaths.join(', ')}',
        );
      }
    }
    return error;
  }

  bool _looksLikeOpenListWebDav() {
    final normalizedBasePath = _baseUri.path.toLowerCase();
    return normalizedBasePath == '/dav/' ||
        normalizedBasePath.endsWith('/dav/');
  }

  String _encodeRequestPath(String path, {required bool directory}) {
    final normalized = directory
        ? _normalizeDirectoryPathValue(path)
        : _normalizeItemPathValue(path);
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');

    if (segments.isEmpty) {
      return '/';
    }

    return directory ? '/$segments/' : '/$segments';
  }

  String _encodeRelativePath(String path, {required bool directory}) {
    final normalized = directory
        ? _normalizeDirectoryPathValue(path)
        : _normalizeItemPathValue(path);
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');

    if (segments.isEmpty) {
      return '';
    }

    return directory ? '$segments/' : segments;
  }
}

bool _isRedirectStatus(int statusCode) {
  return statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;
}

Stream<List<int>> _sliceByteStream(
  Stream<List<int>> source, {
  required int skip,
  int? take,
}) async* {
  var remainingSkip = skip;
  var remainingTake = take;

  await for (final chunk in source) {
    var startIndex = 0;

    if (remainingSkip > 0) {
      if (remainingSkip >= chunk.length) {
        remainingSkip -= chunk.length;
        continue;
      }
      startIndex = remainingSkip;
      remainingSkip = 0;
    }

    final available = chunk.length - startIndex;
    if (available <= 0) {
      continue;
    }

    if (remainingTake != null) {
      if (remainingTake <= 0) {
        break;
      }
      final endIndex =
          startIndex + (available < remainingTake ? available : remainingTake);
      yield chunk.sublist(startIndex, endIndex);
      remainingTake -= endIndex - startIndex;
      if (remainingTake <= 0) {
        break;
      }
      continue;
    }

    yield chunk.sublist(startIndex);
  }
}

XmlElement? _extractSuccessProp(XmlElement responseNode) {
  for (final propStat in responseNode.findElements(
    'propstat',
    namespace: '*',
  )) {
    final hasSuccess = propStat
        .findElements('status', namespace: '*')
        .any((status) => status.innerText.contains('200'));
    if (!hasSuccess) {
      continue;
    }
    return propStat.findElements('prop', namespace: '*').firstOrNull;
  }
  return null;
}

String _resolveNameValue(String? name, String path) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isNotEmpty && trimmed != '/') {
    return trimmed;
  }

  final normalizedPath = _normalizeItemPathValue(path);
  if (normalizedPath == '/') {
    return '/';
  }

  final withoutTrailingSlash = normalizedPath.endsWith('/')
      ? normalizedPath.substring(0, normalizedPath.length - 1)
      : normalizedPath;
  final lastSeparator = withoutTrailingSlash.lastIndexOf('/');

  if (lastSeparator == -1) {
    return withoutTrailingSlash;
  }

  return withoutTrailingSlash.substring(lastSeparator + 1);
}

String _normalizeDirectoryPathValue(String path) {
  if (path == '/') {
    return '/';
  }

  var normalized = path.trim();
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  if (!normalized.endsWith('/')) {
    normalized = '$normalized/';
  }
  return normalized;
}

String _normalizeItemPathValue(String path) {
  if (path == '/') {
    return '/';
  }

  var normalized = path.trim();
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  return normalized;
}

String? _rebaseItemPath(
  String path, {
  required String fromRoot,
  required String toRoot,
}) {
  final normalizedPath = _normalizeItemPathValue(path);
  final normalizedFromRoot = _normalizeDirectoryPathValue(fromRoot);
  final normalizedToRoot = _normalizeDirectoryPathValue(toRoot);

  if (normalizedFromRoot == normalizedToRoot) {
    return null;
  }

  if (normalizedFromRoot == '/') {
    final remainder = normalizedPath.substring(1);
    if (remainder.isEmpty) {
      return normalizedToRoot == '/'
          ? '/'
          : normalizedToRoot.substring(0, normalizedToRoot.length - 1);
    }
    if (normalizedToRoot == '/') {
      return normalizedPath;
    }
    return '${normalizedToRoot.substring(0, normalizedToRoot.length - 1)}/$remainder';
  }

  if (!normalizedPath.startsWith(normalizedFromRoot)) {
    return null;
  }

  final remainder = normalizedPath.substring(normalizedFromRoot.length);
  if (normalizedToRoot == '/') {
    return remainder.isEmpty ? '/' : '/$remainder';
  }
  return '${normalizedToRoot.substring(0, normalizedToRoot.length - 1)}/$remainder';
}

String _resolveRelativePathValue(
  String href, {
  required String requestPath,
  required Uri baseUri,
  required Uri requestUri,
  required bool isDirectory,
}) {
  final hrefUri = Uri.tryParse(href);
  final requestSegments = _normalizeDirectoryPathValue(
    requestPath,
  ).split('/').where((segment) => segment.isNotEmpty).toList();
  final rawRelativeSegments =
      (hrefUri?.hasScheme ?? false) || href.startsWith('/')
      ? const <String>[]
      : (hrefUri?.pathSegments ?? href.split('/'))
            .where((segment) => segment.isNotEmpty)
            .map(_safeDecodeUriSegment)
            .toList();

  if (rawRelativeSegments.isNotEmpty &&
      (rawRelativeSegments.length == requestSegments.length &&
              _segmentsEqual(rawRelativeSegments, requestSegments) ||
          (requestSegments.isNotEmpty &&
              rawRelativeSegments.length == 1 &&
              rawRelativeSegments.single == requestSegments.last))) {
    return isDirectory
        ? _normalizeDirectoryPathValue(requestPath)
        : _normalizeItemPathValue(requestPath);
  }

  final resolvedUri = hrefUri == null
      ? requestUri.resolve(href)
      : hrefUri.hasScheme
      ? hrefUri
      : requestUri.resolveUri(hrefUri);
  final hrefSegments = resolvedUri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .map(_safeDecodeUriSegment)
      .toList();
  final baseSegments = baseUri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .map(_safeDecodeUriSegment)
      .toList();

  var relativeSegments = hrefSegments;
  if (_startsWithSegmentsValue(hrefSegments, baseSegments)) {
    relativeSegments = hrefSegments.sublist(baseSegments.length);
  }

  if (relativeSegments.isEmpty) {
    return '/';
  }

  final result = '/${relativeSegments.join('/')}';
  return isDirectory ? '$result/' : result;
}

bool _startsWithSegmentsValue(List<String> full, List<String> prefix) {
  if (prefix.length > full.length) {
    return false;
  }

  for (var index = 0; index < prefix.length; index++) {
    if (full[index] != prefix[index]) {
      return false;
    }
  }

  return true;
}

bool _segmentsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}

DateTime? _parseModifiedAtValue(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  try {
    return DateTime.parse(raw).toLocal();
  } catch (_) {
    return null;
  }
}

String _safeDecodeUriSegment(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

String? _extractFirstHref(String xmlContent) {
  if (xmlContent.trim().isEmpty) {
    return null;
  }

  try {
    final document = XmlDocument.parse(xmlContent);
    return document
        .findAllElements('href', namespace: '*')
        .map((node) => node.innerText.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
  } catch (_) {
    return null;
  }
}

int _countHrefValues(String xmlContent) {
  if (xmlContent.trim().isEmpty) {
    return 0;
  }

  try {
    final document = XmlDocument.parse(xmlContent);
    return document.findAllElements('href', namespace: '*').length;
  } catch (_) {
    return 0;
  }
}
