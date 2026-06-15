abstract final class BuildEnv {
  static const webApkUrl = String.fromEnvironment('OMNITUNE_WEB_APK_URL');
  static const _defaultWebDavProxyBaseUrl = String.fromEnvironment(
    'OMNITUNE_WEB_WEBDAV_PROXY_BASE_URL',
    defaultValue: '/api/webdav/',
  );

  static bool get hasWebApkUrl => webApkUrl.trim().isNotEmpty;

  static String get webDavProxyBaseUrl => _defaultWebDavProxyBaseUrl.trim();

  static bool get hasWebDavProxyBaseUrl => webDavProxyBaseUrl.isNotEmpty;
}
