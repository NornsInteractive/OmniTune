import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/source_profile.dart';
import '../../../core/models/source_protocol.dart';
import '../../../core/storage/source_profile_repository.dart';
import '../../library/application/library_controller.dart';
import '../../sources/application/music_source_registry.dart';
import '../../sources/application/sources_controller.dart';
import '../../sources/domain/music_source.dart';

part 'add_source_controller.g.dart';

class WebDavSourceDraft {
  const WebDavSourceDraft({
    this.sourceId,
    required this.name,
    required this.baseUrl,
    required this.username,
    required this.password,
    required this.rootPath,
    this.scanDirectories = const [],
    this.excludedScanDirectories = const [],
  });

  final String? sourceId;
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
      id: sourceId ?? 'webdav_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? (generatedName ?? 'WebDAV') : name.trim(),
      protocol: SourceProtocol.webdav,
      baseUrl: trimmedUrl,
      username: username.trim(),
      password: password,
      rootPath: rootPath.trim().isEmpty ? '/' : rootPath.trim(),
      scanDirectories: scanDirectories,
      excludedScanDirectories: excludedScanDirectories,
    );
  }
}

@riverpod
class AddSourceController extends _$AddSourceController {
  @override
  FutureOr<void> build() {}

  Future<void> testConnection(WebDavSourceDraft draft) async {
    state = const AsyncLoading();

    MusicSource? source;
    try {
      final profile = draft.toProfile();
      source = ref.read(musicSourceRegistryProvider).create(profile);
      await source.connect();
      await source.listFiles(profile.effectiveRootPath);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    } finally {
      await source?.disconnect();
    }
  }

  Future<SourceProfile> saveWebDavSource(WebDavSourceDraft draft) async {
    state = const AsyncLoading();

    MusicSource? source;
    try {
      final profile = draft.toProfile();
      source = ref.read(musicSourceRegistryProvider).create(profile);
      await source.connect();
      await source.listFiles(profile.effectiveRootPath);

      await ref.read(sourcesControllerProvider.notifier).saveProfile(profile);
      await ref
          .read(sourceProfileRepositoryProvider)
          .saveActiveSourceId(profile.id);
      ref.invalidate(libraryControllerProvider);

      state = const AsyncData(null);
      return profile;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
