import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../../../core/storage/library_preferences_repository.dart';
import '../../../core/storage/source_profile_repository.dart';
import '../../library/application/library_controller.dart';
import '../../sources/application/music_source_registry.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/data/cloud189/cloud189_api_client.dart';
import '../../sources/data/cloud189/cloud189_music_source.dart';
import '../../sources/data/webdav/webdav_playback_cache_provider.dart';
import '../../sources/domain/music_source.dart';

part 'add_source_controller.g.dart';

class WebDavSourceDraft {
  const WebDavSourceDraft({
    this.sourceId,
    this.protocol = SourceProtocol.webdav,
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.rootPath,
    this.scanDirectories = const [],
    this.excludedScanDirectories = const [],
  });

  final String? sourceId;
  final SourceProtocol protocol;
  final String name;
  final String baseUrl;
  final String username;
  final String password;
  final String rootPath;
  final List<String> scanDirectories;
  final List<String> excludedScanDirectories;

  factory WebDavSourceDraft.fromProfile(SourceProfile profile) {
    return WebDavSourceDraft(
      sourceId: profile.id,
      protocol: profile.protocol,
      name: profile.name,
      baseUrl: profile.baseUrl,
      username: profile.username,
      password: profile.password,
      rootPath: profile.rootPath,
      scanDirectories: profile.scanDirectories,
      excludedScanDirectories: profile.excludedScanDirectories,
    );
  }

  SourceProfile toProfile() {
    final trimmedUrl = baseUrl.trim();
    final generatedName = Uri.tryParse(trimmedUrl)?.host;

    return SourceProfile(
      id:
          sourceId ??
          '${protocol.storageValue}_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty
          ? (generatedName ?? protocol.label)
          : name.trim(),
      protocol: protocol,
      baseUrl: trimmedUrl,
      username: username.trim(),
      password: password,
      rootPath: rootPath.trim().isEmpty ? '/' : rootPath.trim(),
      scanDirectories: scanDirectories,
      excludedScanDirectories: excludedScanDirectories,
    );
  }
}

class Cloud189SourceDraft {
  const Cloud189SourceDraft({
    this.sourceId,
    required this.name,
    required this.authMode,
    required this.username,
    required this.refreshToken,
    required this.appKey,
    required this.appSecret,
    required this.redirectUri,
    required this.authorizationCode,
    required this.tvLoginMode,
    required this.deviceId,
    required this.rootPath,
    this.scanDirectories = const [],
    this.excludedScanDirectories = const [],
  });

  final String? sourceId;
  final String name;
  final Cloud189AuthMode authMode;
  final String username;
  final String refreshToken;
  final String appKey;
  final String appSecret;
  final String redirectUri;
  final String authorizationCode;
  final Cloud189TVLoginMode tvLoginMode;
  final String deviceId;
  final String rootPath;
  final List<String> scanDirectories;
  final List<String> excludedScanDirectories;

  factory Cloud189SourceDraft.fromProfile(SourceProfile profile) {
    final metadata = profile.metadata;
    return Cloud189SourceDraft(
      sourceId: profile.id,
      name: profile.name,
      authMode: Cloud189AuthMode.fromStorageValue(
        metadata[Cloud189Constants.authModeMetadataKey],
      ),
      username: profile.username,
      refreshToken: profile.password,
      appKey: metadata[Cloud189Constants.appKeyMetadataKey] ?? '',
      appSecret: metadata[Cloud189Constants.appSecretMetadataKey] ?? '',
      redirectUri: metadata[Cloud189Constants.redirectUriMetadataKey] ?? '',
      authorizationCode:
          metadata[Cloud189Constants.authorizationCodeMetadataKey] ?? '',
      tvLoginMode: Cloud189TVLoginMode.fromValue(
        metadata[Cloud189Constants.tvLoginModeMetadataKey],
      ),
      deviceId: metadata['cloud189.deviceId'] ?? '',
      rootPath: profile.rootPath,
      scanDirectories: profile.scanDirectories,
      excludedScanDirectories: profile.excludedScanDirectories,
    );
  }

  SourceProfile toProfile() {
    final trimmedAppKey = appKey.trim();
    final metadata = <String, String>{
      Cloud189Constants.authModeMetadataKey: authMode.storageValue,
      if (authMode == Cloud189AuthMode.cloudTV)
        Cloud189Constants.tvLoginModeMetadataKey: tvLoginMode.value,
      if (authMode == Cloud189AuthMode.cloudTV && deviceId.trim().isNotEmpty)
        'cloud189.deviceId': deviceId.trim(),
      if (authMode == Cloud189AuthMode.appAuthorization &&
          trimmedAppKey.isNotEmpty)
        Cloud189Constants.appKeyMetadataKey: trimmedAppKey,
      if (authMode == Cloud189AuthMode.appAuthorization &&
          appSecret.trim().isNotEmpty)
        Cloud189Constants.appSecretMetadataKey: appSecret.trim(),
      if (authMode == Cloud189AuthMode.appAuthorization &&
          redirectUri.trim().isNotEmpty)
        Cloud189Constants.redirectUriMetadataKey: redirectUri.trim(),
      if (authMode == Cloud189AuthMode.appAuthorization &&
          authorizationCode.trim().isNotEmpty)
        Cloud189Constants.authorizationCodeMetadataKey: authorizationCode
            .trim(),
    };

    return SourceProfile(
      id: sourceId ?? 'cloud189_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? Cloud189Constants.displayHost : name.trim(),
      protocol: SourceProtocol.cloudDrive,
      baseUrl: authMode == Cloud189AuthMode.openListPassword
          ? Cloud189Constants.webBaseUrl
          : authMode == Cloud189AuthMode.cloudTV
          ? Cloud189Constants.tvApiBaseUrl
          : Cloud189Constants.apiBaseUrl,
      username: authMode == Cloud189AuthMode.openListPassword
          ? username.trim()
          : Cloud189Constants.providerId,
      password: authMode == Cloud189AuthMode.openListPassword
          ? refreshToken
          : refreshToken.trim(),
      rootPath: rootPath.trim().isEmpty ? '/' : rootPath.trim(),
      scanDirectories: scanDirectories,
      excludedScanDirectories: excludedScanDirectories,
      metadata: metadata,
    );
  }
}

@riverpod
class AddSourceController extends _$AddSourceController {
  @override
  FutureOr<void> build() {}

  Future<void> testConnection(WebDavSourceDraft draft) {
    return _testProfile(draft.toProfile());
  }

  Future<SourceProfile> saveWebDavSource(WebDavSourceDraft draft) {
    return _saveProfile(draft.toProfile());
  }

  Future<void> testCloud189Connection(
    Cloud189SourceDraft draft, {
    Cloud189CaptchaResolver? captchaResolver,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
  }) {
    return _testProfile(
      draft.toProfile(),
      captchaResolver: captchaResolver,
      qrCodeResolver: qrCodeResolver,
      smsVerificationResolver: smsVerificationResolver,
    );
  }

  Future<SourceProfile> saveCloud189Source(
    Cloud189SourceDraft draft, {
    Cloud189CaptchaResolver? captchaResolver,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
  }) {
    return _saveProfile(
      draft.toProfile(),
      captchaResolver: captchaResolver,
      qrCodeResolver: qrCodeResolver,
      smsVerificationResolver: smsVerificationResolver,
    );
  }

  String connectionDebugLog() => Cloud189DebugLogBuffer.dump();

  Future<void> _testProfile(
    SourceProfile profile, {
    Cloud189CaptchaResolver? captchaResolver,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
  }) async {
    state = const AsyncLoading();

    MusicSource? source;
    try {
      final connectionProfile = await _profileForConnection(profile);
      source = _createConnectionSource(
        connectionProfile,
        captchaResolver: captchaResolver,
        qrCodeResolver: qrCodeResolver,
        smsVerificationResolver: smsVerificationResolver,
      );
      await source.connect();
      await source.listFiles(connectionProfile.effectiveRootPath);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      _appendConnectionErrorToDebugLog(profile, error);
      state = AsyncError(error, stackTrace);
      rethrow;
    } finally {
      await source?.disconnect();
    }
  }

  Future<SourceProfile> _saveProfile(
    SourceProfile initialProfile, {
    Cloud189CaptchaResolver? captchaResolver,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
  }) async {
    if (!initialProfile.protocol.isSupportedOnCurrentPlatform) {
      throw UnsupportedError(
        'Protocol ${initialProfile.protocol.storageValue} is not supported on this platform.',
      );
    }

    state = const AsyncLoading();

    MusicSource? source;
    try {
      final connectionProfile = await _profileForConnection(initialProfile);
      source = _createConnectionSource(
        connectionProfile,
        captchaResolver: captchaResolver,
        qrCodeResolver: qrCodeResolver,
        smsVerificationResolver: smsVerificationResolver,
      );
      await source.connect();
      await source.listFiles(connectionProfile.effectiveRootPath);

      final nextRefreshToken = source is Cloud189MusicSource
          ? source.currentRefreshToken
          : null;
      final profile = source is Cloud189MusicSource
          ? initialProfile.copyWith(
              password: nextRefreshToken?.isNotEmpty == true
                  ? nextRefreshToken
                  : initialProfile.password,
              metadata: _metadataAfterCloud189Save(
                initialProfile,
                nextRefreshToken,
              ),
            )
          : initialProfile;

      await ref.read(sourcesControllerProvider.notifier).saveProfile(profile);
      await ref
          .read(sourceProfileRepositoryProvider)
          .saveActiveSourceId(profile.id);
      ref.invalidate(libraryControllerProvider);

      state = const AsyncData(null);
      return profile;
    } catch (error, stackTrace) {
      _appendConnectionErrorToDebugLog(initialProfile, error);
      state = AsyncError(error, stackTrace);
      rethrow;
    } finally {
      await source?.disconnect();
    }
  }

  MusicSource _createConnectionSource(
    SourceProfile profile, {
    Cloud189CaptchaResolver? captchaResolver,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
  }) {
    if (profile.protocol == SourceProtocol.cloudDrive) {
      return Cloud189MusicSource(
        profile,
        playbackCacheFactory: () => ref.read(webDavPlaybackCacheProvider),
        captchaResolver: captchaResolver,
        qrCodeResolver: qrCodeResolver,
        smsVerificationResolver: smsVerificationResolver,
      );
    }
    return ref.read(musicSourceRegistryProvider).create(profile);
  }

  Future<SourceProfile> _profileForConnection(SourceProfile profile) async {
    if (profile.protocol != SourceProtocol.cloudDrive) {
      return profile;
    }

    final enableDebugMode =
        (await ref.read(libraryPreferencesRepositoryProvider).load())
            .enableDebugMode;
    Cloud189DebugLogBuffer.begin(enabled: enableDebugMode);
    if (!enableDebugMode) {
      return profile;
    }

    final metadata = Map<String, String>.from(profile.metadata)
      ..[Cloud189Constants.debugLoggingMetadataKey] = 'true';
    Cloud189DebugLogBuffer.add(
      '[Cloud189][add-source] mode=${metadata[Cloud189Constants.authModeMetadataKey]} '
      'baseUrl=${profile.baseUrl} rootPath=${profile.rootPath} '
      'username=${_debugRedact(profile.username)} '
      'password=${_debugRedact(profile.password)} '
      'metadata=${_debugMetadata(metadata)}',
    );
    return profile.copyWith(metadata: metadata);
  }

  void _appendConnectionErrorToDebugLog(SourceProfile profile, Object error) {
    if (profile.protocol != SourceProtocol.cloudDrive) {
      return;
    }
    Cloud189DebugLogBuffer.add(
      '[Cloud189][add-source:error] ${error.runtimeType}: $error',
    );
  }

  Map<String, String> _metadataAfterCloud189Save(
    SourceProfile profile,
    String? refreshToken,
  ) {
    final metadata = Map<String, String>.from(profile.metadata);
    if (refreshToken?.isNotEmpty == true) {
      metadata.remove(Cloud189Constants.authorizationCodeMetadataKey);
    }
    return metadata;
  }

  String _debugRedact(String value) {
    if (value.isEmpty) {
      return '[empty]';
    }
    return '[redacted:${value.length}]';
  }

  Map<String, String> _debugMetadata(Map<String, String> metadata) {
    return metadata.map((key, value) {
      final normalized = key.toLowerCase();
      final shouldRedact =
          normalized.contains('secret') ||
          normalized.contains('token') ||
          normalized.contains('code');
      return MapEntry(key, shouldRedact ? _debugRedact(value) : value);
    });
  }
}
