import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:music/app/app.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/core/storage/source_profile_repository.dart';

class _FakeSourceProfileRepository implements SourceProfileRepository {
  @override
  Future<String?> loadActiveSourceId() async => null;

  @override
  Future<List<SourceProfile>> loadProfiles() async => const [];

  @override
  Future<void> saveActiveSourceId(String? sourceId) async {}

  @override
  Future<void> saveProfiles(List<SourceProfile> profiles) async {}
}

class _FakeLibraryPreferencesRepository
    implements LibraryPreferencesRepository {
  @override
  Future<LibraryPreferences> load() async => const LibraryPreferences();

  @override
  Future<void> save(LibraryPreferences preferences) async {}
}

void main() {
  testWidgets('app boots without crashing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(
            _FakeSourceProfileRepository(),
          ),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            _FakeLibraryPreferencesRepository(),
          ),
        ],
        child: const MusicApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Add source'), findsOneWidget);
  });
}
