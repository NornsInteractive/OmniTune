import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/models/source_protocol.dart';
import 'package:music/features/settings/application/add_source_controller.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';

void main() {
  test('OpenList Tianyi mount stores username and password credentials', () {
    const draft = Cloud189SourceDraft(
      name: 'Tianyi',
      authMode: Cloud189AuthMode.openListPassword,
      username: '18900000000',
      refreshToken: 'login-password',
      appKey: '',
      appSecret: '',
      redirectUri: '',
      authorizationCode: '',
      tvLoginMode: Cloud189TVLoginMode.scanCode,
      deviceId: '',
      rootPath: '/',
    );

    final profile = draft.toProfile();

    expect(profile.protocol, SourceProtocol.cloudDrive);
    expect(profile.baseUrl, Cloud189Constants.webBaseUrl);
    expect(profile.username, '18900000000');
    expect(profile.password, 'login-password');
    expect(profile.metadata[Cloud189Constants.authModeMetadataKey], Cloud189AuthMode.openListPassword.storageValue);
    expect(profile.metadata.containsKey(Cloud189Constants.appKeyMetadataKey), isFalse);
  });

  test('Tianyi app authorization stores app credentials as metadata', () {
    const draft = Cloud189SourceDraft(
      name: 'Tianyi App',
      authMode: Cloud189AuthMode.appAuthorization,
      username: '',
      refreshToken: 'refresh-token',
      appKey: 'app-key',
      appSecret: 'app-secret',
      redirectUri: 'music://cloud189/callback',
      authorizationCode: 'auth-code',
      tvLoginMode: Cloud189TVLoginMode.scanCode,
      deviceId: '',
      rootPath: '/',
    );

    final profile = draft.toProfile();

    expect(profile.baseUrl, Cloud189Constants.apiBaseUrl);
    expect(profile.username, Cloud189Constants.providerId);
    expect(profile.password, 'refresh-token');
    expect(
      profile.metadata,
      containsPair(Cloud189Constants.authModeMetadataKey, Cloud189AuthMode.appAuthorization.storageValue),
    );
    expect(profile.metadata, containsPair(Cloud189Constants.appKeyMetadataKey, 'app-key'));
    expect(profile.metadata, containsPair(Cloud189Constants.authorizationCodeMetadataKey, 'auth-code'));
  });
}
