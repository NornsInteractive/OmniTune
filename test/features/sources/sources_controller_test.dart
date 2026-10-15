import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/source_profile_repository.dart';
import 'package:music/features/sources/application/sources_controller.dart';

void main() {
  const oldProfile = SourceProfile(
    id: 'old',
    name: 'Old',
    protocol: SourceProtocol.webdav,
    baseUrl: 'https://example.com/dav/',
    username: 'user',
    password: 'pass',
    rootPath: '/',
  );

  const newProfile = SourceProfile(
    id: 'new',
    name: 'New',
    protocol: SourceProtocol.webdav,
    baseUrl: 'https://example.com/dav/',
    username: 'user',
    password: 'pass',
    rootPath: '/',
  );

  late _FakeSourceProfileRepository repository;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<List<SourceProfile>>> subscription;

  setUp(() {
    repository = _FakeSourceProfileRepository(
      initialProfiles: [oldProfile],
      initialActiveSourceId: oldProfile.id,
    );
  });

  tearDown(() async {
    subscription.close();
    container.dispose();
  });

  Future<void> createContainer() async {
    container = ProviderContainer(
      overrides: [
        sourceProfileRepositoryProvider.overrideWithValue(repository),
      ],
    );
    subscription = container.listen(
      sourcesControllerProvider,
      (previous, next) {},
    );
    await container.read(sourcesControllerProvider.future);
  }

  test('retains old profiles while save is blocked', () async {
    await createContainer();
    repository.saveCompleter = Completer<void>();

    final saveFuture = container
        .read(sourcesControllerProvider.notifier)
        .saveProfile(newProfile);
    await repository.saveStarted.future;

    final current = container.read(sourcesControllerProvider);
    expect(current.valueOrNull, [oldProfile]);
    expect(repository.saveCalls.single, [newProfile, oldProfile]);
    expect(repository.saveCompleter!.isCompleted, isFalse);

    repository.saveCompleter!.complete();
    await saveFuture;
  });

  test('save failure throws and retains old visible data', () async {
    await createContainer();
    repository.saveCompleter = Completer<void>();
    repository.saveError = StateError('boom');

    final saveFuture = container
        .read(sourcesControllerProvider.notifier)
        .saveProfile(newProfile);
    await repository.saveStarted.future;
    repository.saveCompleter!.complete();

    await expectLater(saveFuture, throwsA(isA<StateError>()));
    expect(container.read(sourcesControllerProvider).valueOrNull, [oldProfile]);
    expect(repository.storedProfiles, [oldProfile]);
  });

  test('publishes correct profiles only after repository commit', () async {
    await createContainer();
    repository.saveCompleter = Completer<void>();

    final saveFuture = container
        .read(sourcesControllerProvider.notifier)
        .saveProfile(newProfile);
    await repository.saveStarted.future;

    expect(container.read(sourcesControllerProvider).valueOrNull, [oldProfile]);

    repository.saveCompleter!.complete();
    final result = await saveFuture;

    expect(result, newProfile);
    expect(container.read(sourcesControllerProvider).valueOrNull, [
      newProfile,
      oldProfile,
    ]);
    expect(repository.storedProfiles, [newProfile, oldProfile]);
  });
}

class _FakeSourceProfileRepository implements SourceProfileRepository {
  _FakeSourceProfileRepository({
    required List<SourceProfile> initialProfiles,
    String? initialActiveSourceId,
  }) : _profiles = List.of(initialProfiles),
       _activeSourceId = initialActiveSourceId;

  List<SourceProfile> _profiles;
  String? _activeSourceId;
  Completer<void>? saveCompleter;
  Object? saveError;
  final Completer<void> saveStarted = Completer<void>();
  final List<List<SourceProfile>> saveCalls = <List<SourceProfile>>[];

  List<SourceProfile> get storedProfiles => List.of(_profiles);

  @override
  Future<String?> loadActiveSourceId() async => _activeSourceId;

  @override
  Future<List<SourceProfile>> loadProfiles() async => List.of(_profiles);

  @override
  Future<void> saveActiveSourceId(String? sourceId) async {
    _activeSourceId = sourceId;
  }

  @override
  Future<void> saveProfiles(List<SourceProfile> profiles) async {
    saveCalls.add(List.of(profiles));
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    final blocker = saveCompleter;
    if (blocker != null) {
      await blocker.future;
    }
    final error = saveError;
    if (error != null) {
      throw error;
    }
    _profiles = List.of(profiles);
  }
}
