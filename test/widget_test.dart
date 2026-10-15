import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:music/app/app.dart';
import 'package:music/core/i18n/localizations.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/core/storage/source_profile_repository.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';

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
  LibraryPreferences _preferences = const LibraryPreferences();

  @override
  Future<LibraryPreferences> load() async => _preferences;

  @override
  Future<void> save(LibraryPreferences preferences) async {
    _preferences = preferences;
  }

  @override
  Future<LibraryPreferences> update(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async {
    _preferences = transform(_preferences);
    return _preferences;
  }
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'app boots without crashing and exposes localized add source entrance',
    (tester) async {
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

      final l10n = AppLocalizations.of(
        tester.element(find.byType(Navigator).first),
      )!;
      expect(find.text(l10n.addSourceAction), findsAtLeastNWidgets(1));

      // Meaningful entrance regression: tapping add source opens the source picker
      await tester.tap(find.text(l10n.addSourceAction).first);
      await tester.pumpAndSettle();

      final dialogFinder = find.byKey(const Key('add-source-dialog'));
      expect(dialogFinder, findsOneWidget);
      expect(find.byKey(const Key('source-type-step')), findsOneWidget);
      expect(find.text(l10n.sourceTypeSelectionTitle), findsOneWidget);

      final cloud189Finder = find.descendant(
        of: dialogFinder,
        matching: find.text(l10n.cloud189SourceTypeTitle),
      );
      await tester.scrollUntilVisible(
        cloud189Finder,
        100,
        scrollable: find
            .descendant(of: dialogFinder, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();

      expect(cloud189Finder, findsOneWidget);

      // Tapping cloud189 navigates to supported add-source form in same dialog
      await tester.tap(cloud189Finder);
      await tester.pumpAndSettle();

      expect(dialogFinder, findsOneWidget);
      expect(
        find.descendant(
          of: dialogFinder,
          matching: find.byKey(const Key('source-config-step')),
        ),
        findsAtLeastNWidgets(1),
      );
      expect(find.text(l10n.cloud189SourceTypeTitle), findsOneWidget);

      // Supported form contract: OpenList and App authorization modes present,
      // legacy CloudTV mode/fields absent.
      final segmentedButtonFinder = find.byType(
        SegmentedButton<Cloud189AuthMode>,
      );
      expect(segmentedButtonFinder, findsOneWidget);
      final segmentedButton = tester.widget<SegmentedButton<Cloud189AuthMode>>(
        segmentedButtonFinder,
      );
      final segmentValues = segmentedButton.segments
          .map((s) => s.value)
          .toSet();
      expect(
        segmentValues,
        equals({
          Cloud189AuthMode.openListPassword,
          Cloud189AuthMode.appAuthorization,
        }),
      );
      expect(segmentValues.contains(Cloud189AuthMode.cloudTV), isFalse);

      expect(find.text(l10n.cloud189OpenListModeLabel), findsOneWidget);
      expect(find.text(l10n.cloud189AppAuthorizationModeLabel), findsOneWidget);
      await tester.tap(find.text(l10n.cloud189AppAuthorizationModeLabel));
      await tester.pumpAndSettle();
      expect(find.text(l10n.cloud189AppKeyLabel), findsOneWidget);
      await tester.tap(find.text(l10n.cloud189OpenListModeLabel));
      await tester.pumpAndSettle();
      expect(find.text(l10n.cloud189OpenListUsernameLabel), findsOneWidget);
    },
  );
}
