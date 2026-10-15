import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/source_profile.dart';
import '../../../core/storage/source_profile_repository.dart';
import '../../../core/models/source_protocol.dart';
import 'source_session_manager.dart';

part 'sources_controller.g.dart';

@riverpod
class SourcesController extends _$SourcesController {
  bool _disposed = false;

  @override
  Future<List<SourceProfile>> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final repository = ref.watch(sourceProfileRepositoryProvider);
    final filtered = await _loadVisibleProfiles(repository);

    final activeSourceId = await repository.loadActiveSourceId();
    if (filtered.isEmpty) {
      if (activeSourceId != null) {
        await repository.saveActiveSourceId(null);
      }
      return const [];
    }

    final hasActiveSource = filtered.any(
      (profile) => profile.id == activeSourceId,
    );
    if (!hasActiveSource) {
      await repository.saveActiveSourceId(filtered.first.id);
    }

    return filtered;
  }

  Future<SourceProfile> saveProfile(SourceProfile profile) async {
    if (!profile.protocol.isSupportedOnCurrentPlatform) {
      throw UnsupportedError(
        'Protocol ${profile.protocol.storageValue} is not supported on this platform.',
      );
    }

    final keepAlive = ref.keepAlive();
    final repository = ref.read(sourceProfileRepositoryProvider);
    try {
      final persistedProfiles = await repository.loadProfiles();
      final updatedPersistedProfiles = [
        ...persistedProfiles.where((item) => item.id != profile.id),
        profile,
      ]..sort(_compareProfilesByName);
      final visibleProfiles = _filterVisibleProfiles(updatedPersistedProfiles);

      await repository.saveProfiles(updatedPersistedProfiles);
      if (!_disposed) {
        state = AsyncData(visibleProfiles);
      }
      return profile;
    } finally {
      keepAlive.close();
    }
  }

  Future<void> deleteProfile(String sourceId) async {
    final repository = ref.read(sourceProfileRepositoryProvider);
    final persistedProfiles = await repository.loadProfiles();
    final updatedPersistedProfiles = persistedProfiles
        .where((item) => item.id != sourceId)
        .toList(growable: false);
    final visibleProfiles = _filterVisibleProfiles(updatedPersistedProfiles);

    state = AsyncData(visibleProfiles);
    await repository.saveProfiles(updatedPersistedProfiles);

    final activeSourceId = await repository.loadActiveSourceId();
    if (activeSourceId == sourceId) {
      await repository.saveActiveSourceId(
        visibleProfiles.isEmpty ? null : visibleProfiles.first.id,
      );
    }

    await ref.read(musicSourceSessionManagerProvider).invalidate(sourceId);
  }

  Future<List<SourceProfile>> _loadVisibleProfiles(
    SourceProfileRepository repository,
  ) async {
    final profiles = await repository.loadProfiles();
    return _filterVisibleProfiles(profiles);
  }

  List<SourceProfile> _filterVisibleProfiles(List<SourceProfile> profiles) {
    return profiles
        .where((profile) => profile.protocol.isSupportedOnCurrentPlatform)
        .toList(growable: false);
  }

  int _compareProfilesByName(SourceProfile left, SourceProfile right) {
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }
}
