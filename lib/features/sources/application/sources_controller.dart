import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/source_profile.dart';
import '../../../core/storage/source_profile_repository.dart';
import 'source_session_manager.dart';

part 'sources_controller.g.dart';

@riverpod
class SourcesController extends _$SourcesController {
  @override
  Future<List<SourceProfile>> build() {
    return ref.watch(sourceProfileRepositoryProvider).loadProfiles();
  }

  Future<SourceProfile> saveProfile(SourceProfile profile) async {
    final currentProfiles = state.valueOrNull ?? await future;
    final updatedProfiles =
        [...currentProfiles.where((item) => item.id != profile.id), profile]
          ..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );

    state = AsyncData(updatedProfiles);
    await ref
        .read(sourceProfileRepositoryProvider)
        .saveProfiles(updatedProfiles);
    return profile;
  }

  Future<void> deleteProfile(String sourceId) async {
    final currentProfiles = state.valueOrNull ?? await future;
    final updatedProfiles = currentProfiles
        .where((item) => item.id != sourceId)
        .toList();

    state = AsyncData(updatedProfiles);

    final repository = ref.read(sourceProfileRepositoryProvider);
    await repository.saveProfiles(updatedProfiles);

    final activeSourceId = await repository.loadActiveSourceId();
    if (activeSourceId == sourceId) {
      await repository.saveActiveSourceId(
        updatedProfiles.isEmpty ? null : updatedProfiles.first.id,
      );
    }

    await ref.read(musicSourceSessionManagerProvider).invalidate(sourceId);
  }
}
