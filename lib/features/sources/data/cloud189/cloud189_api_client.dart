import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart' as pc;
import 'package:xml/xml.dart';

class Cloud189Constants {
  const Cloud189Constants._();

  static const providerId = 'cloud189';
  static const displayHost = 'api.cloud.189.cn';
  static const webBaseUrl = 'https://cloud.189.cn';
  static const apiBaseUrl = 'https://api.cloud.189.cn';
  static const authBaseUrl = 'https://open.e.189.cn';
  static const oauthAuthorizeUrl =
      'https://open.e.189.cn/api/oauth2/authorize.do';
  static const openListAppId = '8025431004';
  static const openListPcAccountType = '02';
  static const openListPcClientType = '10020';
  static const openListPcReturnUrl =
      'https://m.cloud.189.cn/zhuanti/2020/loginErrorPc/index.html';
  static const openListOcrApiUrl =
      'https://openlistteam-ocr-api-server.hf.space/ocr/file/json';
  static const clientType = 'TELEPC';
  static const version = '6.2';
  static const channelId = 'web_cloud.189.cn';
  static const rootFolderId = '-11';
  static const openListUserAgent =
      'Mozilla/5.0 (Macintosh; Apple macOS 26_1_0) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Safari/537.36 Chrome/142.0.0.0 OpenList/425.6.30';

  // Cloud189 TV API constants
  static const tvAppId = 'tv_cloud_189';
  static const tvClientType = 'ANDROID';
  static const tvApiBaseUrl = 'https://tv-api.cloud.189.cn';

  static const authModeMetadataKey = 'cloud189.authMode';
  static const appKeyMetadataKey = 'cloud189.appKey';
  static const appSecretMetadataKey = 'cloud189.appSecret';
  static const redirectUriMetadataKey = 'cloud189.redirectUri';
  static const authorizationCodeMetadataKey = 'cloud189.authorizationCode';
  static const debugLoggingMetadataKey = 'cloud189.debugLogging';
  static const tvLoginModeMetadataKey = 'cloud189.tvLoginMode';
}

class Cloud189DebugLogBuffer {
  Cloud189DebugLogBuffer._();

  static final List<String> _entries = <String>[];
  static bool _enabled = false;

  static void begin({required bool enabled}) {
    _enabled = enabled;
    _entries.clear();
  }

  static void add(String message) {
    if (!_enabled) {
      return;
    }
    _entries.add(message);
    debugPrint(message);
  }

  static String dump() => _entries.join('\n');
}

enum Cloud189AuthMode {
  openListPassword('openListPassword'),
  appAuthorization('appAuthorization'),
  cloudTV('cloudTV');

  const Cloud189AuthMode(this.storageValue);

  final String storageValue;

  static Cloud189AuthMode fromStorageValue(String? value) {
    if (value == 'openListRefreshToken') {
      return Cloud189AuthMode.openListPassword;
    }
    return Cloud189AuthMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => Cloud189AuthMode.openListPassword,
    );
  }
}

enum Cloud189TVLoginMode {
  scanCode('scanCode'),
  sms('sms');

  const Cloud189TVLoginMode(this.value);
  final String value;

  static Cloud189TVLoginMode fromValue(String? value) {
    return Cloud189TVLoginMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => Cloud189TVLoginMode.scanCode,
    );
  }
}

class Cloud189Session {
  const Cloud189Session({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionKey,
    required this.sessionSecret,
  });

  final String accessToken;
  final String refreshToken;
  final String sessionKey;
  final String sessionSecret;
}

class Cloud189FileEntry {
  const Cloud189FileEntry({
    required this.id,
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modifiedAt,
    this.mimeType,
  });

  final String id;
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedAt;
  final String? mimeType;
}

class Cloud189ReadResult {
  const Cloud189ReadResult({
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

typedef Cloud189CaptchaResolver =
    Future<String?> Function(Uint8List captchaImageBytes);

typedef Cloud189QRCodeResolver = Future<void> Function(String qrContent);
typedef Cloud189SMSVerificationResolver =
    Future<String?> Function(String phoneHint);

/// Response from 189CloudTV device login initiation (QR code request)
class Cloud189TVDeviceLoginResponse {
  const Cloud189TVDeviceLoginResponse({
    required this.deviceId,
    required this.qrContent,
    required this.checkCode,
    required this.timeoutSeconds,
  });

  final String deviceId;
  final String qrContent; // Raw QR code content or URL to render
  final String checkCode; // Used to poll login status
  final int timeoutSeconds; // QR code validity duration

  factory Cloud189TVDeviceLoginResponse.fromJson(Map<String, dynamic> json) {
    return Cloud189TVDeviceLoginResponse(
      deviceId: (json['deviceId'] ?? json['device_id'] ?? '').toString(),
      qrContent: (json['qrContent'] ?? json['qrcode'] ?? '').toString(),
      checkCode: (json['checkCode'] ?? json['check_code'] ?? '').toString(),
      timeoutSeconds: (json['timeoutSeconds'] ?? json['timeout'] ?? 300) as int,
    );
  }
}

abstract class Cloud189RemoteClient {
  String? get currentRefreshToken;

  Future<void> connect();

  Future<List<Cloud189FileEntry>> readDirectory(String path);

  Future<Cloud189ReadResult> openRead(String path, {int? start, int? end});

  Future<String?> readText(String path);

  Future<void> dispose();
}

class DioOpenListCloud189RemoteClient implements Cloud189RemoteClient {
  DioOpenListCloud189RemoteClient({
    required String username,
    required String password,
    String rootFolderId = Cloud189Constants.rootFolderId,
    bool enableDebugLogging = false,
    Cloud189CaptchaResolver? captchaResolver,
    Dio? dio,
  }) : _username = username.trim(),
       _password = password,
       _rootFolderId = rootFolderId.trim().isEmpty
           ? Cloud189Constants.rootFolderId
           : rootFolderId.trim(),
       _captchaResolver = captchaResolver,
       _dio = dio ?? Dio(),
       _random = math.Random.secure(),
       _cookies = _Cloud189CookieStore() {
    _attachCloud189DebugInterceptor(_dio, enableDebugLogging);
    _cookies.attach(_dio);
    _dio.options.headers.addAll({
      'User-Agent': Cloud189Constants.openListUserAgent,
      'Accept': 'application/json;charset=UTF-8',
      'Referer': '${Cloud189Constants.webBaseUrl}/',
    });
  }

  final String _username;
  final String _password;
  final String _rootFolderId;
  final Cloud189CaptchaResolver? _captchaResolver;
  final Dio _dio;
  final math.Random _random;
  final _Cloud189CookieStore _cookies;
  final Map<String, String> _folderIdByPath = {};
  final Map<String, Cloud189FileEntry> _entryByPath = {};
  bool _connected = false;
  Cloud189Session? _session;

  @override
  String? get currentRefreshToken => null;

  @override
  Future<void> connect() async {
    if (_connected) {
      return;
    }
    if (_username.isEmpty || _password.isEmpty) {
      throw ArgumentError(
        'Cloud189 OpenList mount requires username and password.',
      );
    }

    _folderIdByPath['/'] = _rootFolderId;
    await _loginWithPassword();
    _connected = true;
  }

  @override
  Future<List<Cloud189FileEntry>> readDirectory(String path) async {
    await connect();

    final normalizedPath = _normalizeDirectoryPath(path);
    final folderId = await _folderIdForPath(normalizedPath);
    final entries = <Cloud189FileEntry>[];

    for (var page = 1; ; page++) {
      final pageResult = await _listFiles(folderId, page: page);
      if (pageResult.entries.isEmpty) {
        break;
      }
      entries.addAll(
        pageResult.entries.map(
          (entry) => _entryWithResolvedPath(normalizedPath, entry),
        ),
      );
      if (entries.length >= pageResult.count) {
        break;
      }
    }

    for (final entry in entries) {
      _entryByPath[entry.path] = entry;
      if (entry.isDirectory) {
        _folderIdByPath[_normalizeDirectoryPath(entry.path)] = entry.id;
      }
    }

    return entries;
  }

  @override
  Future<Cloud189ReadResult> openRead(
    String path, {
    int? start,
    int? end,
  }) async {
    await connect();

    final entry = await _entryForPath(path);
    final downloadUrl = await _downloadUrlForFile(entry.id);
    final response = await _dio.get<ResponseBody>(
      downloadUrl,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: {
          'User-Agent': Cloud189Constants.openListUserAgent,
          if (start != null || end != null)
            'range': _rangeHeader(start: start, end: end),
        },
      ),
    );

    final body = response.data;
    if (body == null) {
      throw StateError('Cloud189 stream response was empty for $path.');
    }

    final contentTypeHeader =
        response.headers.value(Headers.contentTypeHeader) ??
        entry.mimeType ??
        'application/octet-stream';
    final contentType = contentTypeHeader.split(';').first;
    final contentLength =
        int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        entry.size ??
        0;
    final contentRange = response.headers.value('content-range');
    var resolvedOffset = start ?? 0;
    int? sourceLength = entry.size;

    final rangeMatch = RegExp(
      r'bytes\s+(\d+)-(\d+)/(\d+|\*)',
    ).firstMatch(contentRange ?? '');
    if (rangeMatch != null) {
      resolvedOffset = int.parse(rangeMatch.group(1)!);
      final total = rangeMatch.group(3);
      if (total != null && total != '*') {
        sourceLength = int.parse(total);
      }
    }

    return Cloud189ReadResult(
      stream: body.stream.map((chunk) => chunk),
      offset: resolvedOffset,
      contentLength: contentLength,
      contentType: _resolveContentType(contentType, entry.name),
      sourceLength: sourceLength,
    );
  }

  @override
  Future<String?> readText(String path) async {
    await connect();

    final entry = await _entryForPath(path);
    final downloadUrl = await _downloadUrlForFile(entry.id);
    final response = await _dio.get<List<int>>(
      downloadUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<void> dispose() async {}

  Future<void> _loginWithPassword() async {
    final loginParams = await _initOpenListPcLoginParams();
    final encryptConfResponse = await _dio.post<dynamic>(
      '${Cloud189Constants.authBaseUrl}/api/logbox/config/encryptConf.do',
      data: {'appId': Cloud189Constants.openListAppId},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
      ),
    );
    final encryptConf = cloud189MapFromResponseData(
      encryptConfResponse.data,
      'Cloud189 encryptConf',
    );
    if (!_isZeroResult(encryptConf['result'])) {
      throw StateError('Cloud189 encryptConf request failed.');
    }
    final encryptData =
        encryptConf['data'] as Map<String, dynamic>? ?? const {};
    final rsaPrefix = (encryptData['pre'] ?? '').toString();
    final publicKey = (encryptData['pubKey'] ?? '').toString();
    if (rsaPrefix.isEmpty || publicKey.isEmpty) {
      throw StateError('Cloud189 encryptConf response missed RSA parameters.');
    }

    final encryptedUsername =
        rsaPrefix + _rsaEncryptUpperHex(_username, publicKey);
    final encryptedPassword =
        rsaPrefix + _rsaEncryptUpperHex(_password, publicKey);
    final needCaptchaResponse = await _dio.post<String>(
      '${Cloud189Constants.authBaseUrl}/api/logbox/oauth2/needcaptcha.do',
      data: {
        'appKey': Cloud189Constants.openListAppId,
        'accountType': Cloud189Constants.openListPcAccountType,
        'userName': encryptedUsername,
      },
      options: Options(
        headers: {'REQID': loginParams.reqId},
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
      ),
    );
    final needCaptcha = (needCaptchaResponse.data ?? '').trim();
    Cloud189DebugLogBuffer.add('[Cloud189][login] needcaptcha=$needCaptcha');
    final validateCode = needCaptcha == '0'
        ? ''
        : await _resolveOpenListPcCaptcha(loginParams);

    late Response<dynamic> loginResponse;
    try {
      loginResponse = await _dio.post<dynamic>(
        '${Cloud189Constants.authBaseUrl}/api/logbox/oauth2/loginSubmit.do',
        data: {
          'appKey': Cloud189Constants.openListAppId,
          'accountType': Cloud189Constants.openListPcAccountType,
          'userName': encryptedUsername,
          'password': encryptedPassword,
          'validateCode': validateCode,
          'captchaToken': loginParams.captchaToken,
          'returnUrl': Cloud189Constants.openListPcReturnUrl,
          'dynamicCheck': 'FALSE',
          'clientType': Cloud189Constants.openListPcClientType,
          'cb_SaveName': '1',
          'isOauth2': 'false',
          'state': '',
          'paramId': loginParams.paramId,
        },
        options: Options(
          headers: {'REQID': loginParams.reqId, 'lt': loginParams.lt},
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );
    } catch (error) {
      // Some servers may return non-ASCII or otherwise invalid HTTP header
      // values which cause the Dart HttpClient to throw a FormatException
      // while parsing headers. Catch that and provide clearer debug logs so
      // callers can handle the situation instead of crashing with an
      // uncaught FormatException.
      if (error is FormatException) {
        Cloud189DebugLogBuffer.add(
          '[Cloud189][error] loginSubmit header parse error: ${error.message}',
        );
        throw StateError(
          'Cloud189 login response contained invalid HTTP header: ${error.message}',
        );
      }
      if (error is DioException) {
        Cloud189DebugLogBuffer.add(
          '[Cloud189][error] loginSubmit dio error: ${error.message} data=${_shortDebugValue(_sanitizeDebugValue(error.response?.data))}',
        );
        // Rethrow to preserve original DioException for upstream handling.
        rethrow;
      }
      rethrow;
    }

    final loginData = cloud189MapFromResponseData(
      loginResponse.data,
      'Cloud189 loginSubmit',
    );
    if (!_isZeroResult(loginData['result'])) {
      throw StateError(
        (loginData['msg'] ?? 'Cloud189 login failed.').toString(),
      );
    }
    final toUrl = (loginData['toUrl'] ?? '').toString().trim();
    if (toUrl.isEmpty) {
      throw StateError(
        'Cloud189 login did not return a PC session redirect URL.',
      );
    }

    final sessionResponse = await _dio.post<dynamic>(
      '${Cloud189Constants.apiBaseUrl}/getSessionForPC.action',
      queryParameters: {..._clientSuffix(), 'redirectURL': toUrl},
      options: Options(responseType: ResponseType.json),
    );
    final sessionData = cloud189MapFromResponseData(
      sessionResponse.data,
      'Cloud189 PC session',
    );
    _throwIfApiError(sessionData);
    final accessToken = (sessionData['accessToken'] ?? '').toString().trim();
    final refreshToken = (sessionData['refreshToken'] ?? '').toString().trim();
    final sessionKey = (sessionData['sessionKey'] ?? '').toString().trim();
    final sessionSecret = (sessionData['sessionSecret'] ?? '')
        .toString()
        .trim();
    if (accessToken.isEmpty || sessionKey.isEmpty || sessionSecret.isEmpty) {
      throw StateError('Cloud189 PC session response missed session fields.');
    }
    _session = Cloud189Session(
      accessToken: accessToken,
      refreshToken: refreshToken,
      sessionKey: sessionKey,
      sessionSecret: sessionSecret,
    );
    Cloud189DebugLogBuffer.add('[Cloud189][login] PC password login accepted.');
  }

  Future<_Cloud189PcLoginParams> _initOpenListPcLoginParams() async {
    final response = await _dio.get<String>(
      '${Cloud189Constants.webBaseUrl}/api/portal/unifyLoginForPC.action',
      queryParameters: {
        'appId': Cloud189Constants.openListAppId,
        'clientType': Cloud189Constants.openListPcClientType,
        'returnURL': Cloud189Constants.openListPcReturnUrl,
        'timeStamp': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data ?? '';
    return _Cloud189PcLoginParams(
      captchaToken: _requiredFirstMatch(
        html,
        RegExp(r'''name=['"]captchaToken['"]\s+value=['"]([^'"]+)['"]'''),
        'captchaToken',
      ),
      lt: cloud189ExtractPcLoginLt(html),
      paramId: _requiredFirstMatch(
        html,
        RegExp(r'\bparamId\s*=\s*"([^"]+)"'),
        'paramId',
      ),
      reqId: _requiredFirstMatch(
        html,
        RegExp(r'\breqId\s*=\s*"([^"]+)"'),
        'reqId',
      ),
    );
  }

  Future<String> _resolveOpenListPcCaptcha(
    _Cloud189PcLoginParams loginParams,
  ) async {
    final captchaBytes = await _fetchOpenListPcCaptcha(loginParams);
    if (captchaBytes.length <= 20) {
      throw StateError('Cloud189 captcha image response was empty.');
    }

    Object? ocrError;
    try {
      final validateCode = await _recognizeOpenListPcCaptcha(captchaBytes);
      if (validateCode.isNotEmpty) {
        Cloud189DebugLogBuffer.add('[Cloud189][login] captcha OCR accepted.');
        return validateCode;
      }
      ocrError = StateError(
        'Cloud189 captcha OCR did not return validateCode.',
      );
    } catch (error) {
      ocrError = error;
      Cloud189DebugLogBuffer.add(
        '[Cloud189][login] captcha OCR unavailable; waiting for manual input.',
      );
    }

    final resolver = _captchaResolver;
    if (resolver != null) {
      final manualCode = (await resolver(
        Uint8List.fromList(captchaBytes),
      ))?.trim();
      if (manualCode?.isNotEmpty == true) {
        Cloud189DebugLogBuffer.add(
          '[Cloud189][login] manual captcha accepted.',
        );
        return manualCode!;
      }
    }

    if (ocrError is StateError) {
      throw ocrError;
    }
    throw StateError('Cloud189 captcha OCR failed: $ocrError');
  }

  Future<List<int>> _fetchOpenListPcCaptcha(
    _Cloud189PcLoginParams loginParams,
  ) async {
    final response = await _dio.get<List<int>>(
      '${Cloud189Constants.authBaseUrl}/api/logbox/oauth2/picCaptcha.do',
      queryParameters: {
        'token': loginParams.captchaToken,
        'REQID': loginParams.reqId,
        'rnd': DateTime.now().millisecondsSinceEpoch.toString(),
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data ?? const <int>[];
    Cloud189DebugLogBuffer.add(
      '[Cloud189][login] captcha image bytes=${bytes.length}',
    );
    return bytes;
  }

  Future<String> _recognizeOpenListPcCaptcha(List<int> captchaBytes) async {
    final ocrDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 18),
        headers: {
          'Accept': 'application/json',
          'User-Agent': Cloud189Constants.openListUserAgent,
        },
      ),
    );

    const maxAttempts = 6;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (attempt > 1) {
        final delay = _openListOcrRetryDelay(attempt);
        Cloud189DebugLogBuffer.add(
          '[Cloud189][login] captcha OCR retry=$attempt '
          'delay=${delay.inSeconds}s',
        );
        await Future<void>.delayed(delay);
      }

      Cloud189DebugLogBuffer.add(
        '[Cloud189][request] POST ${Cloud189Constants.openListOcrApiUrl} '
        'attempt=$attempt data={image: [binary:${captchaBytes.length}]}',
      );
      try {
        final response = await ocrDio.post<dynamic>(
          Cloud189Constants.openListOcrApiUrl,
          data: FormData.fromMap({
            'image': MultipartFile.fromBytes(
              captchaBytes,
              filename: 'validateCode.png',
              contentType: DioMediaType('image', 'png'),
            ),
          }),
          options: Options(
            responseType: ResponseType.json,
            validateStatus: (_) => true,
          ),
        );
        final statusCode = response.statusCode ?? 0;
        if (statusCode >= 400) {
          Cloud189DebugLogBuffer.add(
            '[Cloud189][response] POST ${Cloud189Constants.openListOcrApiUrl} '
            'httpStatus=$statusCode data=${_shortDebugValue(_sanitizeDebugValue(response.data))}',
          );
          lastError = StateError('Cloud189 captcha OCR HTTP $statusCode.');
          if (_shouldRetryOpenListOcr(statusCode)) {
            continue;
          }
          break;
        }

        final data = cloud189MapFromResponseData(
          response.data,
          'Cloud189 captcha OCR',
        );
        final status = data['status']?.toString().trim() ?? '';
        final result = data['result']?.toString().trim() ?? '';
        Cloud189DebugLogBuffer.add(
          '[Cloud189][response] POST ${Cloud189Constants.openListOcrApiUrl} '
          'httpStatus=$statusCode data={status: $status, result: ${_redactedDebugValue(result)}}',
        );
        if (_isSuccessCode(status) && result.isNotEmpty) {
          return result;
        }
        final message =
            (data['message'] ?? data['msg'] ?? 'Cloud189 captcha OCR failed.')
                .toString();
        lastError = StateError(message);
        if (!_shouldRetryOpenListOcr(statusCode)) {
          break;
        }
      } on DioException catch (error) {
        lastError = error;
        Cloud189DebugLogBuffer.add(
          '[Cloud189][error] POST ${Cloud189Constants.openListOcrApiUrl} '
          'attempt=$attempt error=${error.message}',
        );
      }
    }

    if (lastError is StateError) {
      throw lastError;
    }
    throw StateError('Cloud189 captcha OCR failed: $lastError');
  }

  Future<_Cloud189ListPage> _listFiles(String folderId, {required int page}) {
    return _signedGet<dynamic>(
      '${Cloud189Constants.apiBaseUrl}/listFiles.action',
      queryParameters: {
        'folderId': folderId,
        'recursive': '0',
        'fileType': '0',
        'iconOption': '5',
        'mediaAttr': '0',
        'orderBy': 'filename',
        'descending': 'false',
        'pageNum': '$page',
        'pageSize': '1000',
        ..._clientSuffix(),
      },
    ).then((response) {
      final data = cloud189MapFromResponseData(
        response.data,
        'Cloud189 PC listFiles',
      );
      _throwIfApiError(data);
      final list = data['fileListAO'] as Map<String, dynamic>? ?? const {};
      final folders = (list['folderList'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => _legacyEntryFromJson(item, isDirectory: true));
      final files = (list['fileList'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => _legacyEntryFromJson(item, isDirectory: false));

      return _Cloud189ListPage(
        count: (list['count'] as num?)?.toInt() ?? 0,
        entries: [...folders, ...files],
      );
    });
  }

  Future<String> _downloadUrlForFile(String fileId) async {
    final response = await _signedGet<dynamic>(
      '${Cloud189Constants.apiBaseUrl}/getFileDownloadUrl.action',
      queryParameters: {
        'fileId': fileId,
        'dt': '3',
        'flag': '1',
        ..._clientSuffix(),
      },
    );
    final data = response.data;
    final url = switch (data) {
      final Map<String, dynamic> map =>
        (map['fileDownloadUrl'] ?? map['downloadUrl'])?.toString().trim(),
      final String text => _downloadUrlFromXml(text),
      _ => null,
    };
    if (url == null || url.isEmpty) {
      throw StateError('Cloud189 did not return a download URL.');
    }
    return _normalizeCloudUrl(url);
  }

  Future<Response<T>> _signedGet<T>(
    String url, {
    required Map<String, String> queryParameters,
  }) {
    final session = _session;
    if (session == null) {
      throw StateError('Cloud189 is not connected.');
    }

    final date = _httpDate();
    return _dio.get<T>(
      url,
      queryParameters: queryParameters,
      options: Options(
        headers: {
          'Accept': 'application/json;charset=UTF-8',
          'Date': date,
          'SessionKey': session.sessionKey,
          'Signature': _signatureOfHmac(
            secretKey: session.sessionSecret,
            sessionKey: session.sessionKey,
            method: 'GET',
            url: url,
            date: date,
          ),
          'X-Request-ID': _uuid(),
        },
      ),
    );
  }

  Map<String, String> _clientSuffix() {
    return {
      'clientType': Cloud189Constants.clientType,
      'version': Cloud189Constants.version,
      'channelId': Cloud189Constants.channelId,
      'rand': '${_random.nextInt(100000)}_${_random.nextInt(1000000000)}',
    };
  }

  String _signatureOfHmac({
    required String secretKey,
    required String sessionKey,
    required String method,
    required String url,
    required String date,
  }) {
    final uri = Uri.parse(url);
    final plain =
        'SessionKey=$sessionKey&Operate=$method&RequestURI=${uri.path}&Date=$date';
    final hmacSha1 = Hmac(sha1, utf8.encode(secretKey));
    return hmacSha1.convert(utf8.encode(plain)).toString().toUpperCase();
  }

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String _httpDate() {
    return '${DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US').format(DateTime.now().toUtc())} GMT';
  }

  String _requiredFirstMatch(String text, RegExp pattern, String fieldName) {
    final match = pattern.firstMatch(text);
    final value = match?.group(1)?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError('Cloud189 PC login page missed $fieldName.');
    }
    return value;
  }

  Future<String> _folderIdForPath(String path) async {
    final normalizedPath = _normalizeDirectoryPath(path);
    final cached = _folderIdByPath[normalizedPath];
    if (cached != null) {
      return cached;
    }

    var currentPath = '/';
    var currentFolderId = _rootFolderId;
    for (final segment in _pathSegments(normalizedPath)) {
      final children = await readDirectory(currentPath);
      final nextPath = _joinDirectoryPath(currentPath, segment);
      final folder = children
          .where((entry) => entry.isDirectory)
          .where((entry) => entry.name == segment)
          .firstOrNull;
      if (folder == null) {
        throw StateError('Cloud189 folder was not found: $nextPath');
      }
      currentPath = nextPath;
      currentFolderId = folder.id;
      _folderIdByPath[currentPath] = currentFolderId;
    }

    return currentFolderId;
  }

  Future<Cloud189FileEntry> _entryForPath(String path) async {
    final normalizedPath = _normalizeItemPath(path);
    final cached = _entryByPath[normalizedPath];
    if (cached != null) {
      return cached;
    }

    final parentPath = _parentDirectoryPath(normalizedPath);
    final fileName = p.posix.basename(normalizedPath);
    final entries = await readDirectory(parentPath);
    final entry = entries
        .where((item) => !item.isDirectory && item.name == fileName)
        .firstOrNull;
    if (entry == null) {
      throw StateError('Cloud189 file was not found: $normalizedPath');
    }
    return entry;
  }
}

class DioCloud189RemoteClient implements Cloud189RemoteClient {
  DioCloud189RemoteClient({
    required String refreshToken,
    String clientId = Cloud189Constants.openListAppId,
    String clientSecret = '',
    String authorizationCode = '',
    String redirectUri = '',
    bool enableDebugLogging = false,
    Dio? dio,
    math.Random? random,
  }) : _initialRefreshToken = refreshToken.trim(),
       _clientId = clientId.trim().isEmpty
           ? Cloud189Constants.openListAppId
           : clientId.trim(),
       _clientSecret = clientSecret.trim(),
       _authorizationCode = authorizationCode.trim(),
       _redirectUri = redirectUri.trim(),
       _dio = dio ?? Dio(),
       _random = random ?? math.Random.secure() {
    _attachCloud189DebugInterceptor(_dio, enableDebugLogging);
    _dio.options.headers.addAll({'User-Agent': 'Mozilla/5.0'});
  }

  final String _initialRefreshToken;
  final String _clientId;
  final String _clientSecret;
  final String _authorizationCode;
  final String _redirectUri;
  final Dio _dio;
  final math.Random _random;
  final Map<String, String> _folderIdByPath = {
    '/': Cloud189Constants.rootFolderId,
  };
  final Map<String, Cloud189FileEntry> _entryByPath = {};
  Cloud189Session? _session;
  String? _clientSn;

  @override
  String? get currentRefreshToken => _session?.refreshToken;

  @override
  Future<void> connect() async {
    if (_session != null) {
      return;
    }
    if (_initialRefreshToken.isEmpty && _authorizationCode.isEmpty) {
      throw ArgumentError.value(
        '',
        'refreshToken',
        'Refresh token or authorization code is required.',
      );
    }

    final refreshed = _initialRefreshToken.isEmpty
        ? await _exchangeAuthorizationCode()
        : await _refreshAccessToken(_initialRefreshToken);
    _session = await _refreshSession(refreshed);
  }

  @override
  Future<List<Cloud189FileEntry>> readDirectory(String path) async {
    await connect();

    final normalizedPath = _normalizeDirectoryPath(path);
    final folderId = await _folderIdForPath(normalizedPath);
    final entries = <Cloud189FileEntry>[];

    for (var page = 1; ; page++) {
      final pageResult = await _listFiles(folderId, page: page);
      entries.addAll(
        pageResult.entries.map(
          (entry) => _entryWithResolvedPath(normalizedPath, entry),
        ),
      );

      if (entries.length >= pageResult.count || pageResult.entries.isEmpty) {
        break;
      }
    }

    for (final entry in entries) {
      _entryByPath[entry.path] = entry;
      if (entry.isDirectory) {
        _folderIdByPath[_normalizeDirectoryPath(entry.path)] = entry.id;
      }
    }

    return entries;
  }

  @override
  Future<Cloud189ReadResult> openRead(
    String path, {
    int? start,
    int? end,
  }) async {
    await connect();

    final entry = await _entryForPath(path);
    final downloadUrl = await _downloadUrlForFile(entry.id);
    final response = await _dio.get<ResponseBody>(
      downloadUrl,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: {
          'User-Agent': 'Mozilla/5.0',
          if (start != null || end != null)
            'range': _rangeHeader(start: start, end: end),
        },
      ),
    );

    final body = response.data;
    if (body == null) {
      throw StateError('Cloud189 stream response was empty for $path.');
    }

    final contentTypeHeader =
        response.headers.value(Headers.contentTypeHeader) ??
        entry.mimeType ??
        'application/octet-stream';
    final contentType = contentTypeHeader.split(';').first;
    final contentLength =
        int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        entry.size ??
        0;
    final contentRange = response.headers.value('content-range');
    var resolvedOffset = start ?? 0;
    int? sourceLength = entry.size;

    final rangeMatch = RegExp(
      r'bytes\s+(\d+)-(\d+)/(\d+|\*)',
    ).firstMatch(contentRange ?? '');
    if (rangeMatch != null) {
      resolvedOffset = int.parse(rangeMatch.group(1)!);
      final total = rangeMatch.group(3);
      if (total != null && total != '*') {
        sourceLength = int.parse(total);
      }
    }

    return Cloud189ReadResult(
      stream: body.stream.map((chunk) => chunk),
      offset: resolvedOffset,
      contentLength: contentLength,
      contentType: _resolveContentType(contentType, entry.name),
      sourceLength: sourceLength,
    );
  }

  @override
  Future<String?> readText(String path) async {
    await connect();

    final entry = await _entryForPath(path);
    final downloadUrl = await _downloadUrlForFile(entry.id);
    final response = await _dio.get<List<int>>(
      downloadUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  Future<void> dispose() async {}

  Future<_RefreshAccessTokenResult> _refreshAccessToken(
    String refreshToken,
  ) async {
    final response = await _dio.post<dynamic>(
      '${Cloud189Constants.authBaseUrl}/api/oauth2/refreshToken.do',
      data: {
        'clientId': _clientId,
        'refreshToken': refreshToken,
        'grantType': 'refresh_token',
        'format': 'json',
        if (_clientSecret.isNotEmpty) 'clientSecret': _clientSecret,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.json,
      ),
    );

    final data = cloud189MapFromResponseData(
      response.data,
      'Cloud189 refreshToken',
    );
    _throwIfApiError(data);

    final accessToken = (data['accessToken'] as String?)?.trim() ?? '';
    final nextRefreshToken =
        (data['refreshToken'] as String?)?.trim() ?? refreshToken;
    if (accessToken.isEmpty) {
      throw StateError(
        'Cloud189 refresh response did not include accessToken.',
      );
    }

    return _RefreshAccessTokenResult(
      accessToken: accessToken,
      refreshToken: nextRefreshToken,
    );
  }

  Future<_RefreshAccessTokenResult> _exchangeAuthorizationCode() async {
    if (_clientSecret.isEmpty || _redirectUri.isEmpty) {
      throw ArgumentError(
        'Cloud189 app authorization requires appKey, appSecret, redirectUri, and authorization code.',
      );
    }

    final response = await _dio.get<dynamic>(
      '${Cloud189Constants.authBaseUrl}/api/oauth2/accessToken.do',
      queryParameters: {
        'clientId': _clientId,
        'clientSecret': _clientSecret,
        'grantType': 'authorization_code',
        'code': _authorizationCode,
        'redirectUri': _redirectUri,
        'format': 'json',
      },
      options: Options(responseType: ResponseType.json),
    );

    final data = cloud189MapFromResponseData(
      response.data,
      'Cloud189 accessToken',
    );
    _throwIfApiError(data);

    final accessToken = (data['accessToken'] as String?)?.trim() ?? '';
    final refreshToken = (data['refreshToken'] as String?)?.trim() ?? '';
    if (accessToken.isEmpty) {
      throw StateError(
        'Cloud189 authorization response did not include accessToken.',
      );
    }

    return _RefreshAccessTokenResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  Future<Cloud189Session> _refreshSession(
    _RefreshAccessTokenResult refreshed,
  ) async {
    final response = await _unsignedGet<dynamic>(
      '${Cloud189Constants.apiBaseUrl}/getSessionForPC.action',
      queryParameters: {
        'appId': _clientId,
        'accessToken': refreshed.accessToken,
        'clientSn': _clientSnValue(),
        ..._clientSuffix(),
      },
    );

    final data = cloud189MapFromResponseData(response.data, 'Cloud189 session');
    _throwIfApiError(data);

    final sessionKey = (data['sessionKey'] as String?)?.trim() ?? '';
    final sessionSecret = (data['sessionSecret'] as String?)?.trim() ?? '';
    if (sessionKey.isEmpty || sessionSecret.isEmpty) {
      throw StateError(
        'Cloud189 session response did not include session keys.',
      );
    }

    return Cloud189Session(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken,
      sessionKey: sessionKey,
      sessionSecret: sessionSecret,
    );
  }

  Future<_Cloud189ListPage> _listFiles(String folderId, {required int page}) {
    return _signedGet<dynamic>(
      '${Cloud189Constants.apiBaseUrl}/listFiles.action',
      queryParameters: {
        'folderId': folderId,
        'recursive': '0',
        'fileType': '0',
        'iconOption': '5',
        'mediaAttr': '0',
        'orderBy': 'filename',
        'descending': 'false',
        'pageNum': '$page',
        'pageSize': '1000',
        ..._clientSuffix(),
      },
    ).then((response) {
      final data = cloud189MapFromResponseData(
        response.data,
        'Cloud189 listFiles',
      );
      _throwIfApiError(data);
      final list = data['fileListAO'] as Map<String, dynamic>? ?? const {};
      final folders = (list['folderList'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => _entryFromJson(item, isDirectory: true));
      final files = (list['fileList'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => _entryFromJson(item, isDirectory: false));

      return _Cloud189ListPage(
        count: (list['count'] as num?)?.toInt() ?? 0,
        entries: [...folders, ...files],
      );
    });
  }

  Future<String> _downloadUrlForFile(String fileId) async {
    final response = await _signedGet<dynamic>(
      '${Cloud189Constants.apiBaseUrl}/getFileDownloadUrl.action',
      queryParameters: {
        'fileId': fileId,
        'dt': '3',
        'flag': '1',
        ..._clientSuffix(),
      },
    );

    final data = response.data;
    final url = switch (data) {
      final Map<String, dynamic> map =>
        (map['fileDownloadUrl'] as String?)?.trim(),
      final String text => _downloadUrlFromXml(text),
      _ => null,
    };

    if (url == null || url.isEmpty) {
      throw StateError('Cloud189 did not return a download URL.');
    }
    return url.replaceAll('&amp;', '&').replaceFirst('http://', 'https://');
  }

  Future<String> _folderIdForPath(String path) async {
    final normalizedPath = _normalizeDirectoryPath(path);
    final cached = _folderIdByPath[normalizedPath];
    if (cached != null) {
      return cached;
    }

    var currentPath = '/';
    var currentFolderId = Cloud189Constants.rootFolderId;
    for (final segment in _pathSegments(normalizedPath)) {
      final children = await readDirectory(currentPath);
      final nextPath = _joinDirectoryPath(currentPath, segment);
      final folder = children
          .where((entry) => entry.isDirectory)
          .where((entry) => entry.name == segment)
          .firstOrNull;
      if (folder == null) {
        throw StateError('Cloud189 folder was not found: $nextPath');
      }
      currentPath = nextPath;
      currentFolderId = folder.id;
      _folderIdByPath[currentPath] = currentFolderId;
    }

    return currentFolderId;
  }

  Future<Cloud189FileEntry> _entryForPath(String path) async {
    final normalizedPath = _normalizeItemPath(path);
    final cached = _entryByPath[normalizedPath];
    if (cached != null) {
      return cached;
    }

    final parentPath = _parentDirectoryPath(normalizedPath);
    final fileName = p.posix.basename(normalizedPath);
    final entries = await readDirectory(parentPath);
    final entry = entries
        .where((item) => !item.isDirectory && item.name == fileName)
        .firstOrNull;
    if (entry == null) {
      throw StateError('Cloud189 file was not found: $normalizedPath');
    }
    return entry;
  }

  Future<Response<T>> _signedGet<T>(
    String url, {
    required Map<String, String> queryParameters,
  }) async {
    final session = _session;
    if (session == null) {
      throw StateError('Cloud189 is not connected.');
    }

    final date = _httpDate();
    return _dio.get<T>(
      url,
      queryParameters: queryParameters,
      options: Options(
        headers: {
          'Accept': 'application/json;charset=UTF-8',
          'Date': date,
          'SessionKey': session.sessionKey,
          'Signature': _signatureOfHmac(
            secretKey: session.sessionSecret,
            sessionKey: session.sessionKey,
            method: 'GET',
            url: url,
            date: date,
          ),
          'X-Request-ID': _uuid(),
        },
      ),
    );
  }

  Future<Response<T>> _unsignedGet<T>(
    String url, {
    required Map<String, String> queryParameters,
  }) {
    return _dio.get<T>(
      url,
      queryParameters: queryParameters,
      options: Options(headers: {'X-Request-ID': _uuid()}),
    );
  }

  Cloud189FileEntry _entryFromJson(
    Map<String, dynamic> json, {
    required bool isDirectory,
  }) {
    return Cloud189FileEntry(
      id: (json['id'] ?? json['fileId'] ?? json['folderId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      path: '',
      isDirectory: isDirectory,
      size: (json['size'] as num?)?.toInt(),
      modifiedAt: _parseCloud189Time(json['lastOpTime'] ?? json['createDate']),
      mimeType: isDirectory
          ? null
          : _mimeTypeForName((json['name'] ?? '').toString()),
    );
  }

  Cloud189FileEntry _entryWithResolvedPath(
    String parentPath,
    Cloud189FileEntry entry,
  ) {
    final path = entry.isDirectory
        ? _joinDirectoryPath(parentPath, entry.name)
        : _joinItemPath(parentPath, entry.name);
    return Cloud189FileEntry(
      id: entry.id,
      name: entry.name,
      path: path,
      isDirectory: entry.isDirectory,
      size: entry.size,
      modifiedAt: entry.modifiedAt,
      mimeType: entry.mimeType,
    );
  }

  String _signatureOfHmac({
    required String secretKey,
    required String sessionKey,
    required String method,
    required String url,
    required String date,
  }) {
    final uri = Uri.parse(url);
    final plain =
        'SessionKey=$sessionKey&Operate=$method&RequestURI=${uri.path}&Date=$date';
    final hmacSha1 = Hmac(sha1, utf8.encode(secretKey));
    return hmacSha1.convert(utf8.encode(plain)).toString().toUpperCase();
  }

  Map<String, String> _clientSuffix() {
    return {
      'clientType': Cloud189Constants.clientType,
      'version': Cloud189Constants.version,
      'channelId': Cloud189Constants.channelId,
      'rand': '${_random.nextInt(100000)}_${_random.nextInt(1000000000)}',
    };
  }

  String _clientSnValue() => _clientSn ??= _uuid().toUpperCase();

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String _httpDate() {
    return '${DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US').format(DateTime.now().toUtc())} GMT';
  }

  String _rangeHeader({int? start, int? end}) {
    final startValue = start ?? 0;
    return end == null ? 'bytes=$startValue-' : 'bytes=$startValue-$end';
  }

  String? _downloadUrlFromXml(String text) {
    try {
      return XmlDocument.parse(text).rootElement.innerText.trim();
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseCloud189Time(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text) ??
        _parseDateFormat('yyyy-MM-dd HH:mm:ss', text)?.toLocal() ??
        _parseDateFormat('MMM d, yyyy HH:mm:ss a', text)?.toLocal();
  }

  DateTime? _parseDateFormat(String pattern, String value) {
    try {
      return DateFormat(pattern, 'en_US').parse(value);
    } on FormatException {
      return null;
    }
  }

  String _normalizeDirectoryPath(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      normalized = '/';
    }
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return p.posix.normalize(normalized).endsWith('/')
        ? p.posix.normalize(normalized)
        : '${p.posix.normalize(normalized)}/';
  }

  String _normalizeItemPath(String value) {
    var normalized = value.trim();
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }
    return p.posix.normalize(normalized);
  }

  List<String> _pathSegments(String value) {
    return value.split('/').where((segment) => segment.isNotEmpty).toList();
  }

  String _joinDirectoryPath(String parent, String child) {
    return _normalizeDirectoryPath(p.posix.join(parent, child));
  }

  String _joinItemPath(String parent, String child) {
    return _normalizeItemPath(p.posix.join(parent, child));
  }

  String _parentDirectoryPath(String path) {
    return _normalizeDirectoryPath(p.posix.dirname(_normalizeItemPath(path)));
  }

  String? _mimeTypeForName(String fileName) {
    final extension = p.extension(fileName).toLowerCase();
    return switch (extension) {
      '.flac' => 'audio/flac',
      '.mp3' => 'audio/mpeg',
      '.m4a' => 'audio/mp4',
      '.aac' => 'audio/aac',
      '.wav' => 'audio/wav',
      '.ogg' || '.oga' => 'audio/ogg',
      '.opus' => 'audio/opus',
      '.wma' => 'audio/x-ms-wma',
      '.ape' => 'audio/ape',
      '.alac' => 'audio/mp4',
      _ => null,
    };
  }

  String _resolveContentType(String headerContentType, String fileName) {
    final normalized = headerContentType.trim().toLowerCase();
    if (normalized.startsWith('audio/') || normalized == 'application/flac') {
      return normalized == 'application/flac' ? 'audio/flac' : normalized;
    }
    return _mimeTypeForName(fileName) ?? 'application/octet-stream';
  }

  void _throwIfApiError(Map<String, dynamic> data) {
    final result = data['result'];
    final resCode = data['res_code'];
    final code = (data['code'] ?? data['errorCode'] ?? data['error'])
        ?.toString()
        .trim();
    final message =
        (data['res_message'] ??
                data['message'] ??
                data['msg'] ??
                data['errorMsg'])
            ?.toString()
            .trim();

    final hasResultError = switch (result) {
      final int value => value != 0,
      final num value => value.toInt() != 0,
      final String value => value.trim().isNotEmpty && value.trim() != '0',
      _ => false,
    };
    final hasResError = switch (resCode) {
      final int value => value != 0,
      final num value => value.toInt() != 0,
      final String value => value.trim().isNotEmpty && !_isSuccessCode(value),
      _ => false,
    };
    final hasCodeError =
        code != null && code.isNotEmpty && !_isSuccessCode(code);
    if (hasResultError || hasResError || hasCodeError) {
      throw StateError(
        message?.isNotEmpty == true ? message! : 'Cloud189 API error.',
      );
    }
  }

  bool _isSuccessCode(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized == '0' ||
        normalized == '200' ||
        normalized == 'SUCCESS' ||
        normalized == 'OK';
  }
}

class _Cloud189CookieStore {
  final Map<String, String> _cookies = {};

  void attach(Dio dio) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_cookies.isNotEmpty) {
            options.headers['Cookie'] = _cookies.entries
                .map((entry) => '${entry.key}=${entry.value}')
                .join('; ');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          for (final cookie in response.headers.map['set-cookie'] ?? const []) {
            final pair = cookie.split(';').first;
            final separator = pair.indexOf('=');
            if (separator <= 0) {
              continue;
            }
            _cookies[pair.substring(0, separator)] = pair.substring(
              separator + 1,
            );
          }
          handler.next(response);
        },
      ),
    );
  }
}

@visibleForTesting
Map<String, dynamic> cloud189MapFromResponseData(Object? data, String context) {
  if (data == null) {
    return const <String, dynamic>{};
  }
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  if (data is String) {
    final text = data.trim();
    if (text.isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(text);
      return cloud189MapFromResponseData(decoded, context);
    } on FormatException catch (error) {
      throw StateError('$context returned invalid JSON: ${error.message}');
    }
  }
  throw StateError('$context response was not a JSON object.');
}

@visibleForTesting
String cloud189ExtractPcLoginLt(String html) {
  final match = RegExp(r'\blt\s*=\s*"([^"]+)"').firstMatch(html);
  final value = match?.group(1)?.trim() ?? '';
  if (value.isEmpty) {
    throw StateError('Cloud189 PC login page missed lt.');
  }
  return value;
}

void _attachCloud189DebugInterceptor(Dio dio, bool enabled) {
  if (!enabled) {
    return;
  }
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        Cloud189DebugLogBuffer.add(
          '[Cloud189][request] ${options.method} ${_debugUri(options.uri)} '
          'query=${_shortDebugValue(_sanitizeDebugValue(_debugQueryParameters(options)))} '
          'data=${_shortDebugValue(_sanitizeDebugValue(options.data))}',
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        Cloud189DebugLogBuffer.add(
          '[Cloud189][response] ${response.requestOptions.method} '
          '${_debugUri(response.requestOptions.uri)} status=${response.statusCode} '
          'data=${_shortDebugValue(_sanitizeDebugValue(response.data))}',
        );
        handler.next(response);
      },
      onError: (error, handler) {
        Cloud189DebugLogBuffer.add(
          '[Cloud189][error] ${error.requestOptions.method} '
          '${_debugUri(error.requestOptions.uri)} error=${error.message} '
          'data=${_shortDebugValue(_sanitizeDebugValue(error.response?.data))}',
        );
        handler.next(error);
      },
    ),
  );
}

String _debugUri(Uri uri) {
  if (!uri.hasQuery) {
    return uri.toString();
  }

  final query = uri.queryParametersAll.entries.expand((entry) {
    return entry.value.map((value) {
      final sanitizedValue = _shouldRedactDebugKey(entry.key)
          ? _redactedDebugValue(value)
          : value;
      return MapEntry(entry.key, sanitizedValue);
    });
  });
  final queryText = query
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
  return uri.replace(query: queryText).toString();
}

Object _debugQueryParameters(RequestOptions options) {
  if (options.uri.queryParametersAll.isNotEmpty) {
    return options.uri.queryParametersAll.map((key, value) {
      return MapEntry(key, value.length == 1 ? value.first : value);
    });
  }
  return options.queryParameters;
}

Object? _sanitizeDebugValue(Object? value) {
  if (value is FormData) {
    final result = <String, Object?>{};
    for (final field in value.fields) {
      final sanitizedField = _sanitizeDebugValue({field.key: field.value});
      result[field.key] = sanitizedField is Map
          ? sanitizedField[field.key]
          : field.value;
    }
    return result;
  }
  if (value is List<int> &&
      value.length > 64 &&
      value.every((item) => item >= 0 && item <= 255)) {
    return '[binary:${value.length}]';
  }
  if (value is Map) {
    return value.map((key, item) {
      return MapEntry(
        key.toString(),
        _shouldRedactDebugKey(key.toString())
            ? _redactedDebugValue(item)
            : _sanitizeDebugValue(item),
      );
    });
  }
  if (value is Iterable) {
    return value.map(_sanitizeDebugValue).toList();
  }
  return value;
}

bool _shouldRedactDebugKey(String key) {
  final normalizedKey = key.toLowerCase();
  return normalizedKey.contains('password') ||
      normalizedKey == 'epd' ||
      normalizedKey == 'username' ||
      normalizedKey == 'username'.toLowerCase() ||
      normalizedKey.contains('secret') ||
      normalizedKey.contains('token') ||
      normalizedKey.contains('code') ||
      normalizedKey.contains('cookie');
}

String _redactedDebugValue(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) {
    return '[empty]';
  }
  return '[redacted:${text.length}]';
}

String _shortDebugValue(Object? value) {
  final text = value?.toString() ?? 'null';
  if (text.length <= 1200) {
    return text;
  }
  return '${text.substring(0, 1200)}...';
}

Cloud189FileEntry _legacyEntryFromJson(
  Map<String, dynamic> json, {
  required bool isDirectory,
}) {
  final name = (json['name'] ?? '').toString();
  return Cloud189FileEntry(
    id: (json['id'] ?? '').toString(),
    name: name,
    path: '',
    isDirectory: isDirectory,
    size: (json['size'] as num?)?.toInt(),
    modifiedAt: _parseCloud189Time(json['lastOpTime'] ?? json['createDate']),
    mimeType: isDirectory ? null : _mimeTypeForName(name),
  );
}

Cloud189FileEntry _entryWithResolvedPath(
  String parentPath,
  Cloud189FileEntry entry,
) {
  final path = entry.isDirectory
      ? _joinDirectoryPath(parentPath, entry.name)
      : _joinItemPath(parentPath, entry.name);
  return Cloud189FileEntry(
    id: entry.id,
    name: entry.name,
    path: path,
    isDirectory: entry.isDirectory,
    size: entry.size,
    modifiedAt: entry.modifiedAt,
    mimeType: entry.mimeType,
  );
}

String _rsaEncryptUpperHex(String value, String publicKeyText) {
  final encrypted = _rsaEncryptBytes(value, publicKeyText);
  return encrypted
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}

Uint8List _rsaEncryptBytes(String value, String publicKeyText) {
  final pem =
      '-----BEGIN PUBLIC KEY-----\n$publicKeyText\n-----END PUBLIC KEY-----';
  final publicKey = encrypt.RSAKeyParser().parse(pem) as pc.RSAPublicKey;
  final cipher = pc.PKCS1Encoding(pc.RSAEngine())
    ..init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));
  final input = Uint8List.fromList(utf8.encode(value));
  final output = Uint8List(cipher.outputBlockSize);
  final outputLength = cipher.processBlock(input, 0, input.length, output, 0);
  return output.sublist(0, outputLength);
}

String _normalizeCloudUrl(String value) {
  final trimmed = value.trim().replaceAll('&amp;', '&');
  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }
  return trimmed.replaceFirst('http://', 'https://');
}

String? _downloadUrlFromXml(String text) {
  try {
    return XmlDocument.parse(text).rootElement.innerText.trim();
  } catch (_) {
    return null;
  }
}

String _rangeHeader({int? start, int? end}) {
  final startValue = start ?? 0;
  return end == null ? 'bytes=$startValue-' : 'bytes=$startValue-$end';
}

DateTime? _parseCloud189Time(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text) ??
      _parseDateFormat('yyyy-MM-dd HH:mm:ss', text)?.toLocal() ??
      _parseDateFormat('MMM d, yyyy HH:mm:ss a', text)?.toLocal();
}

DateTime? _parseDateFormat(String pattern, String value) {
  try {
    return DateFormat(pattern, 'en_US').parse(value);
  } on FormatException {
    return null;
  }
}

String _normalizeDirectoryPath(String value) {
  var normalized = value.trim();
  if (normalized.isEmpty) {
    normalized = '/';
  }
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  if (!normalized.endsWith('/')) {
    normalized = '$normalized/';
  }
  return p.posix.normalize(normalized).endsWith('/')
      ? p.posix.normalize(normalized)
      : '${p.posix.normalize(normalized)}/';
}

String _normalizeItemPath(String value) {
  var normalized = value.trim();
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }
  return p.posix.normalize(normalized);
}

List<String> _pathSegments(String value) {
  return value.split('/').where((segment) => segment.isNotEmpty).toList();
}

String _joinDirectoryPath(String parent, String child) {
  return _normalizeDirectoryPath(p.posix.join(parent, child));
}

String _joinItemPath(String parent, String child) {
  return _normalizeItemPath(p.posix.join(parent, child));
}

String _parentDirectoryPath(String path) {
  return _normalizeDirectoryPath(p.posix.dirname(_normalizeItemPath(path)));
}

String? _mimeTypeForName(String fileName) {
  final extension = p.extension(fileName).toLowerCase();
  return switch (extension) {
    '.flac' => 'audio/flac',
    '.mp3' => 'audio/mpeg',
    '.m4a' => 'audio/mp4',
    '.aac' => 'audio/aac',
    '.wav' => 'audio/wav',
    '.ogg' || '.oga' => 'audio/ogg',
    '.opus' => 'audio/opus',
    '.wma' => 'audio/x-ms-wma',
    '.ape' => 'audio/ape',
    '.alac' => 'audio/mp4',
    _ => null,
  };
}

String _resolveContentType(String headerContentType, String fileName) {
  final normalized = headerContentType.trim().toLowerCase();
  if (normalized.startsWith('audio/') || normalized == 'application/flac') {
    return normalized == 'application/flac' ? 'audio/flac' : normalized;
  }
  return _mimeTypeForName(fileName) ?? 'application/octet-stream';
}

void _throwIfApiError(Map<String, dynamic> data) {
  final result = data['result'];
  final resCode = data['res_code'];
  final code = (data['code'] ?? data['errorCode'] ?? data['error'])
      ?.toString()
      .trim();
  final message =
      (data['res_message'] ??
              data['message'] ??
              data['msg'] ??
              data['errorMsg'])
          ?.toString()
          .trim();

  final hasResultError = switch (result) {
    final int value => value != 0,
    final num value => value.toInt() != 0,
    final String value => value.trim().isNotEmpty && value.trim() != '0',
    _ => false,
  };
  final hasResError = switch (resCode) {
    final int value => value != 0,
    final num value => value.toInt() != 0,
    final String value => value.trim().isNotEmpty && !_isSuccessCode(value),
    _ => false,
  };
  final hasCodeError = code != null && code.isNotEmpty && !_isSuccessCode(code);
  if (hasResultError || hasResError || hasCodeError) {
    throw StateError(
      message?.isNotEmpty == true ? message! : 'Cloud189 API error.',
    );
  }
}

bool _isSuccessCode(String value) {
  final normalized = value.trim().toUpperCase();
  return normalized == '0' ||
      normalized == '200' ||
      normalized == 'SUCCESS' ||
      normalized == 'OK';
}

bool _isZeroResult(Object? value) {
  return switch (value) {
    final int number => number == 0,
    final num number => number.toInt() == 0,
    final String text => text.trim() == '0',
    _ => false,
  };
}

bool _shouldRetryOpenListOcr(int statusCode) {
  return statusCode == 0 || statusCode == 429 || statusCode >= 500;
}

Duration _openListOcrRetryDelay(int attempt) {
  return switch (attempt) {
    2 => const Duration(seconds: 2),
    3 => const Duration(seconds: 5),
    4 => const Duration(seconds: 10),
    5 => const Duration(seconds: 15),
    _ => const Duration(seconds: 20),
  };
}

class _RefreshAccessTokenResult {
  const _RefreshAccessTokenResult({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class _Cloud189ListPage {
  const _Cloud189ListPage({required this.count, required this.entries});

  final int count;
  final List<Cloud189FileEntry> entries;
}

class _Cloud189PcLoginParams {
  const _Cloud189PcLoginParams({
    required this.captchaToken,
    required this.lt,
    required this.paramId,
    required this.reqId,
  });

  final String captchaToken;
  final String lt;
  final String paramId;
  final String reqId;
}

/// Implements Cloud189 TV device login with QR code scanning or SMS verification
///
/// Login flow:
/// 1. (QR mode) Request device QR code -> show to user -> poll until scanned
///    User scans with phone 189Cloud app -> device receives token
/// 2. (SMS mode) Request OTP -> send to phone -> user enters code -> get token
class DioCloud189TVRemoteClient implements Cloud189RemoteClient {
  DioCloud189TVRemoteClient({
    required Cloud189TVLoginMode tvLoginMode,
    String? deviceId,
    bool enableDebugLogging = false,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
    Dio? dio,
  }) : _tvLoginMode = tvLoginMode,
       _deviceId = deviceId,
       _qrCodeResolver = qrCodeResolver,
       _smsVerificationResolver = smsVerificationResolver,
       _dio = dio ?? Dio(),
       _random = math.Random.secure() {
    _attachCloud189DebugInterceptor(_dio, enableDebugLogging);
    _dio.options.headers.addAll({
      'User-Agent': 'Mozilla/5.0 (Android 12; Android TV)',
      'Accept': 'application/json;charset=UTF-8',
    });
  }

  final Cloud189TVLoginMode _tvLoginMode;
  final String? _deviceId;
  final Cloud189QRCodeResolver? _qrCodeResolver;
  final Cloud189SMSVerificationResolver? _smsVerificationResolver;
  final Dio _dio;
  final math.Random _random;

  bool _connected = false;
  Cloud189Session? _session;
  String? _refreshToken;

  @override
  String? get currentRefreshToken => _refreshToken;

  @override
  Future<void> connect() async {
    if (_connected) {
      return;
    }

    try {
      switch (_tvLoginMode) {
        case Cloud189TVLoginMode.scanCode:
          await _loginWithQRCode();
          break;
        case Cloud189TVLoginMode.sms:
          await _loginWithSMS();
          break;
      }
      _connected = true;
    } catch (error) {
      _connected = false;
      rethrow;
    }
  }

  @override
  Future<List<Cloud189FileEntry>> readDirectory(String path) async {
    await connect();
    if (_session == null) {
      throw StateError('Cloud189TV session is not established');
    }
    // TODO: Implement directory listing using _session
    return const [];
  }

  @override
  Future<Cloud189ReadResult> openRead(
    String path, {
    int? start,
    int? end,
  }) async {
    await connect();
    // TODO: Implement file streaming using _session
    throw UnimplementedError('File streaming not yet implemented for TV mode');
  }

  @override
  Future<String?> readText(String path) async {
    await connect();
    // TODO: Implement text file reading using _session
    throw UnimplementedError(
      'Text file reading not yet implemented for TV mode',
    );
  }

  @override
  Future<void> dispose() async {}

  /// QR Code login flow for 189CloudTV
  Future<void> _loginWithQRCode() async {
    Cloud189DebugLogBuffer.add('[Cloud189TV][qrcode] Initiating QR code login');

    final qrResponse = await _requestDeviceQRCode();
    final deviceId = qrResponse.deviceId;
    final checkCode = qrResponse.checkCode;
    final qrContent = qrResponse.qrContent;

    Cloud189DebugLogBuffer.add(
      '[Cloud189TV][qrcode] Received QR code: deviceId=$deviceId',
    );

    final resolver = _qrCodeResolver;
    if (resolver != null) {
      await resolver(qrContent);
    }

    final loginResult = await _pollQRCodeLogin(
      deviceId,
      checkCode,
      qrResponse.timeoutSeconds,
    );

    Cloud189DebugLogBuffer.add(
      '[Cloud189TV][qrcode] QR code login completed, accessToken received',
    );

    await _establishSession(loginResult.accessToken, loginResult.refreshToken);
  }

  /// SMS verification login flow for 189CloudTV
  Future<void> _loginWithSMS() async {
    Cloud189DebugLogBuffer.add(
      '[Cloud189TV][sms] Initiating SMS verification login',
    );

    final smsResponse = await _requestSMSCode();
    final checkCode = smsResponse['checkCode'] ?? '';
    final phoneHint = smsResponse['phoneHint'] ?? '****';

    Cloud189DebugLogBuffer.add(
      '[Cloud189TV][sms] OTP sent to phone ending with $phoneHint',
    );

    final verificationResolver = _smsVerificationResolver;
    if (verificationResolver == null) {
      throw StateError(
        'Cloud189 TV SMS login requires SMS verification resolver callback',
      );
    }

    final verificationCode = (await verificationResolver(phoneHint))?.trim();
    if (verificationCode?.isEmpty != false) {
      throw StateError('Cloud189 TV SMS verification code was not provided');
    }

    final loginResult = await _verifySMSCode(checkCode, verificationCode!);

    Cloud189DebugLogBuffer.add(
      '[Cloud189TV][sms] SMS verification completed, accessToken received',
    );

    await _establishSession(loginResult.accessToken, loginResult.refreshToken);
  }

  /// Request device QR code from 189CloudTV API
  Future<Cloud189TVDeviceLoginResponse> _requestDeviceQRCode() async {
    try {
      final response = await _dio.post<dynamic>(
        '${Cloud189Constants.tvApiBaseUrl}/open/device/login/qrCodeRequest',
        data: {
          'appId': Cloud189Constants.tvAppId,
          'deviceId': _deviceId ?? _generateDeviceId(),
          'clientType': Cloud189Constants.tvClientType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );

      final data = cloud189MapFromResponseData(
        response.data,
        'Cloud189TV QR code request',
      );
      _throwIfApiError(data);

      return Cloud189TVDeviceLoginResponse.fromJson(data['data'] ?? data);
    } catch (error) {
      Cloud189DebugLogBuffer.add(
        '[Cloud189TV][error] QR code request failed: $error',
      );
      rethrow;
    }
  }

  /// Poll for QR code scan completion
  Future<_TVLoginResult> _pollQRCodeLogin(
    String deviceId,
    String checkCode,
    int timeoutSeconds,
  ) async {
    const pollIntervalMs = 2000;
    final maxAttempts = (timeoutSeconds * 1000) ~/ pollIntervalMs;

    Cloud189DebugLogBuffer.add(
      '[Cloud189TV][qrcode] Starting polling for QR code scan (max ${timeoutSeconds}s)',
    );

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _dio.post<dynamic>(
          '${Cloud189Constants.tvApiBaseUrl}/open/device/login/qrCodeCheckStatus',
          data: {
            'deviceId': deviceId,
            'checkCode': checkCode,
            'appId': Cloud189Constants.tvAppId,
          },
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.json,
            validateStatus: (_) => true,
          ),
        );

        final data = cloud189MapFromResponseData(
          response.data,
          'Cloud189TV QR code status check',
        );

        if (_tvIsSuccessCode((data['code'] ?? data['result']).toString())) {
          final loginData = data['data'] as Map<String, dynamic>? ?? {};
          final accessToken = (loginData['accessToken'] ?? '')
              .toString()
              .trim();
          final refreshToken = (loginData['refreshToken'] ?? '')
              .toString()
              .trim();

          if (accessToken.isNotEmpty) {
            return _TVLoginResult(
              accessToken: accessToken,
              refreshToken: refreshToken,
            );
          }
        }

        final statusCode = (data['code'] ?? data['result']).toString();
        if (statusCode == '9999' ||
            statusCode.contains('not') ||
            statusCode == '0') {
          Cloud189DebugLogBuffer.add(
            '[Cloud189TV][qrcode] Waiting for QR code scan...',
          );
        } else if (!_tvIsSuccessCode(statusCode)) {
          final message = data['message'] ?? data['msg'] ?? 'Unknown error';
          throw StateError('Cloud189TV QR code poll failed: $message');
        }
      } catch (error) {
        Cloud189DebugLogBuffer.add(
          '[Cloud189TV][error] QR code poll attempt $attempt failed: $error',
        );
        if (error is StateError) {
          rethrow;
        }
      }

      if (attempt < maxAttempts) {
        await Future<void>.delayed(
          const Duration(milliseconds: pollIntervalMs),
        );
      }
    }

    throw StateError('Cloud189TV QR code login timed out (${timeoutSeconds}s)');
  }

  /// Request SMS OTP code
  Future<Map<String, dynamic>> _requestSMSCode() async {
    try {
      final response = await _dio.post<dynamic>(
        '${Cloud189Constants.tvApiBaseUrl}/open/device/login/smsCodeRequest',
        data: {
          'appId': Cloud189Constants.tvAppId,
          'deviceId': _deviceId ?? _generateDeviceId(),
          'clientType': Cloud189Constants.tvClientType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );

      final data = cloud189MapFromResponseData(
        response.data,
        'Cloud189TV SMS code request',
      );
      _throwIfApiError(data);

      return (data['data'] as Map<String, dynamic>?) ?? data;
    } catch (error) {
      Cloud189DebugLogBuffer.add(
        '[Cloud189TV][error] SMS request failed: $error',
      );
      rethrow;
    }
  }

  /// Verify SMS code and get access token
  Future<_TVLoginResult> _verifySMSCode(
    String checkCode,
    String verificationCode,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        '${Cloud189Constants.tvApiBaseUrl}/open/device/login/smsCodeVerify',
        data: {
          'deviceId': _deviceId ?? _generateDeviceId(),
          'checkCode': checkCode,
          'verificationCode': verificationCode,
          'appId': Cloud189Constants.tvAppId,
          'clientType': Cloud189Constants.tvClientType,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
        ),
      );

      final data = cloud189MapFromResponseData(
        response.data,
        'Cloud189TV SMS verification',
      );
      _throwIfApiError(data);

      final loginData = data['data'] as Map<String, dynamic>? ?? {};
      final accessToken = (loginData['accessToken'] ?? '').toString().trim();
      final refreshToken = (loginData['refreshToken'] ?? '').toString().trim();

      if (accessToken.isEmpty) {
        throw StateError(
          'Cloud189TV SMS verification did not return accessToken',
        );
      }

      return _TVLoginResult(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } catch (error) {
      Cloud189DebugLogBuffer.add(
        '[Cloud189TV][error] SMS code verification failed: $error',
      );
      rethrow;
    }
  }

  /// Establish API session with access token
  Future<void> _establishSession(
    String accessToken,
    String refreshToken,
  ) async {
    try {
      _refreshToken = refreshToken;

      final response = await _dio.post<dynamic>(
        '${Cloud189Constants.apiBaseUrl}/getSessionForPC.action',
        queryParameters: {
          'appId': Cloud189Constants.tvAppId,
          'accessToken': accessToken,
          'clientType': Cloud189Constants.tvClientType,
          'version': '6.2',
          'rand': '${_random.nextInt(100000)}_${_random.nextInt(1000000000)}',
        },
        options: Options(responseType: ResponseType.json),
      );

      final data = cloud189MapFromResponseData(
        response.data,
        'Cloud189TV session',
      );
      _throwIfApiError(data);

      final sessionKey = (data['sessionKey'] as String?)?.trim() ?? '';
      final sessionSecret = (data['sessionSecret'] as String?)?.trim() ?? '';

      if (sessionKey.isEmpty || sessionSecret.isEmpty) {
        throw StateError(
          'Cloud189TV session response did not include session keys',
        );
      }

      _session = Cloud189Session(
        accessToken: accessToken,
        refreshToken: refreshToken,
        sessionKey: sessionKey,
        sessionSecret: sessionSecret,
      );

      Cloud189DebugLogBuffer.add(
        '[Cloud189TV] Session established successfully',
      );
    } catch (error) {
      Cloud189DebugLogBuffer.add(
        '[Cloud189TV][error] Session establishment failed: $error',
      );
      rethrow;
    }
  }

  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _random.nextInt(1000000);
    return 'flutter_music_$timestamp-$random';
  }

  bool _tvIsSuccessCode(String value) {
    final normalized = value.trim().toUpperCase();
    return normalized == '0' ||
        normalized == '200' ||
        normalized == 'SUCCESS' ||
        normalized == 'OK';
  }

  void _throwIfApiError(Map<String, dynamic> data) {
    final code = (data['code'] ?? data['result']).toString().trim();
    final message = (data['message'] ?? data['msg'] ?? '').toString().trim();

    if (code.isNotEmpty && !_tvIsSuccessCode(code)) {
      throw StateError(
        message.isNotEmpty ? message : 'Cloud189TV API error: $code',
      );
    }
  }
}

class _TVLoginResult {
  const _TVLoginResult({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}
