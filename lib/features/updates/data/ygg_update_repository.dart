import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/app_update.dart';
import 'update_arch_stub.dart' if (dart.library.io) 'update_arch_native.dart';

class YggUpdateRepository {
  YggUpdateRepository({
    Dio? dio,
    UpdateTarget? target,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
               headers: {'User-Agent': 'OmniTune-Updater'},
             ),
           ),
       target = target ?? currentTarget(),
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  static const appId = 'com.norns.omnitune';
  static final endpoint = Uri.parse('https://ygg.norns.cc.cd');
  final Dio _dio;
  final UpdateTarget? target;
  final Future<PackageInfo> Function() _packageInfoLoader;

  static UpdateTarget? currentTarget() {
    if (kIsWeb) return null;
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.linux => 'linux',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      _ => null,
    };
    return platform == null
        ? null
        : UpdateTarget(platform, updateArchitecture(platform));
  }

  Future<AppVersion> installedVersion() async {
    final info = await _packageInfoLoader();
    final code = int.tryParse(info.buildNumber);
    if (code == null || code < 1) {
      throw const AppUpdateException(AppUpdateFailure.invalidResponse);
    }
    return AppVersion(info.version, code);
  }

  Future<AppUpdateRelease?> check(int currentCode) async {
    final target = this.target;
    if (target == null) {
      throw const AppUpdateException(AppUpdateFailure.noPackage);
    }
    try {
      final response = await _dio.getUri<Object?>(
        endpoint
            .resolve('/api/v1/app/latest')
            .replace(
              queryParameters: {
                'app_id': appId,
                'version_code': '$currentCode',
                'channel': 'default',
                'platform': target.platform,
                'arch': target.arch,
              },
            ),
      );
      final body = response.data;
      if (body is! Map || body['code'] != 0 || body['data'] is! Map) {
        throw const AppUpdateException(AppUpdateFailure.invalidResponse);
      }
      final data = body['data'] as Map;
      final code = data['latest_version_code'];
      if (data['app_id'] != appId || code is! int || code < 1) {
        throw const AppUpdateException(AppUpdateFailure.invalidResponse);
      }
      // A server flag alone must never cause a reinstall or downgrade.
      if (code <= currentCode) return null;
      final rawPackages = data['packages'];
      final packages = rawPackages is List
          ? rawPackages
                .whereType<Map>()
                .where(
                  (p) =>
                      p['platform'] == target.platform &&
                      (p['arch'] == target.arch || p['arch'] == 'universal'),
                )
                .toList()
          : <Map>[];
      packages.sort(
        (a, b) => (a['arch'] == target.arch ? 0 : 1).compareTo(
          b['arch'] == target.arch ? 0 : 1,
        ),
      );
      final Map package;
      if (packages.isNotEmpty) {
        package = packages.first;
      } else if ((rawPackages is! List || rawPackages.isEmpty) &&
          data['platform'] == target.platform &&
          (data['arch'] == target.arch || data['arch'] == 'universal')) {
        package = data;
      } else {
        throw const AppUpdateException(AppUpdateFailure.noPackage);
      }
      final size = package['file_size'];
      final name = data['latest_version_name'];
      if (size is! int || size <= 0 || name is! String || name.trim().isEmpty) {
        throw const AppUpdateException(AppUpdateFailure.invalidResponse);
      }
      final digest = package['file_sha256'];
      final sha256 =
          digest is String && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest)
          ? digest.toLowerCase()
          : null;
      if (target.platform == 'android' && sha256 == null) {
        throw const AppUpdateException(AppUpdateFailure.checksumMissing);
      }
      final packageId = package['id'];
      return AppUpdateRelease(
        versionName: name,
        versionCode: code,
        changelog: data['changelog'] is String
            ? data['changelog'] as String
            : '',
        platform: target.platform,
        fileSize: size,
        sha256: sha256,
        // Keep update traffic on Ygg; never launch a server-supplied arbitrary URL.
        downloadUri: endpoint
            .resolve('/api/v1/app/download')
            .replace(
              queryParameters: {
                'app_id': appId,
                'version_code': '$code',
                'channel': 'default',
                'platform': target.platform,
                'arch': target.arch,
                if (packageId is String && packageId.isNotEmpty)
                  'package_id': packageId,
              },
            ),
      );
    } on DioException catch (error) {
      throw AppUpdateException(
        error.response?.statusCode == 404
            ? AppUpdateFailure.noPackage
            : AppUpdateFailure.network,
      );
    } on AppUpdateException {
      rethrow;
    } catch (_) {
      throw const AppUpdateException(AppUpdateFailure.invalidResponse);
    }
  }
}
