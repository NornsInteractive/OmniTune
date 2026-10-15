import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/source_profile_repository.dart';
import 'package:music/core/storage/library_preferences_repository.dart';
import 'package:music/features/settings/application/add_source_controller.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';
import 'package:music/features/sources/application/music_source_registry.dart';
import 'package:music/features/sources/application/sources_controller.dart';
import 'package:music/features/sources/domain/music_source.dart';
import 'package:music/features/library/application/library_controller.dart';

const _profileA = SourceProfile(
  id: 'source-a',
  name: 'Source A',
  protocol: SourceProtocol.webdav,
  baseUrl: 'https://example.com/a/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

const _profileB = SourceProfile(
  id: 'source-b',
  name: 'Source B',
  protocol: SourceProtocol.webdav,
  baseUrl: 'https://example.com/b/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

const _oldProfile = SourceProfile(
  id: 'old',
  name: 'Old',
  protocol: SourceProtocol.webdav,
  baseUrl: 'https://example.com/old/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

WebDavSourceDraft _draft(String sourceId) => WebDavSourceDraft(
  sourceId: sourceId,
  name: 'Draft $sourceId',
  baseUrl: 'https://example.com/$sourceId/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

class _FakeSourceProfileRepository implements SourceProfileRepository {
  _FakeSourceProfileRepository({
    required List<SourceProfile> initialProfiles,
    String? initialActiveSourceId,
  }) : _profiles = List.of(initialProfiles),
       _activeSourceId = initialActiveSourceId;

  List<SourceProfile> _profiles;
  String? _activeSourceId;

  Completer<void>? saveProfilesBlocker;
  Completer<void>? saveActiveSourceIdBlocker;
  Object? saveProfilesError;
  Object? saveActiveSourceIdError;

  final Completer<void> saveProfilesStarted = Completer<void>();
  final Completer<void> saveActiveSourceIdStarted = Completer<void>();

  final List<List<SourceProfile>> saveProfilesCalls = <List<SourceProfile>>[];
  final List<String?> saveActiveSourceIdCalls = <String?>[];

  List<SourceProfile> get storedProfiles => List.of(_profiles);

  String? get activeSourceId => _activeSourceId;

  @override
  Future<String?> loadActiveSourceId() async => _activeSourceId;

  @override
  Future<List<SourceProfile>> loadProfiles() async => List.of(_profiles);

  @override
  Future<void> saveActiveSourceId(String? sourceId) async {
    saveActiveSourceIdCalls.add(sourceId);
    if (!saveActiveSourceIdStarted.isCompleted) {
      saveActiveSourceIdStarted.complete();
    }
    final blocker = saveActiveSourceIdBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    final error = saveActiveSourceIdError;
    if (error != null) {
      throw error;
    }
    _activeSourceId = sourceId;
  }

  @override
  Future<void> saveProfiles(List<SourceProfile> profiles) async {
    saveProfilesCalls.add(List.of(profiles));
    if (!saveProfilesStarted.isCompleted) {
      saveProfilesStarted.complete();
    }
    final blocker = saveProfilesBlocker;
    if (blocker != null) {
      await blocker.future;
    }
    final error = saveProfilesError;
    if (error != null) {
      throw error;
    }
    _profiles = List.of(profiles);
  }
}

class _ControlledSource implements MusicSource {
  _ControlledSource(this.profile);

  @override
  final SourceProfile profile;

  Completer<void>? connectCompleter;
  final Completer<void> connectStarted = Completer<void>();

  Completer<void>? listCompleter;
  final Completer<void> listStarted = Completer<void>();

  Completer<void>? disconnectCompleter;
  final Completer<void> disconnectStarted = Completer<void>();

  Object? disconnectError;

  int connectCalls = 0;
  int listCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> connect() async {
    connectCalls++;
    if (!connectStarted.isCompleted) {
      connectStarted.complete();
    }
    final blocker = connectCompleter;
    if (blocker != null) {
      await blocker.future;
    }
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    if (!disconnectStarted.isCompleted) {
      disconnectStarted.complete();
    }
    final blocker = disconnectCompleter;
    if (blocker != null) {
      await blocker.future;
    }
    final error = disconnectError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<DirectoryListing> listFiles(String path) async {
    listCalls++;
    if (!listStarted.isCompleted) {
      listStarted.complete();
    }
    final blocker = listCompleter;
    if (blocker != null) {
      await blocker.future;
    }
    return const DirectoryListing(entries: <RemoteEntry>[]);
  }

  @override
  Future<PlayableTrack> buildPlayableTrack(RemoteEntry entry) {
    throw UnimplementedError();
  }

  @override
  Future<String?> readTextFile(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> readBinaryFile(String path) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List?> readBinaryFileHead(String path, {int length = 131072}) {
    throw UnimplementedError();
  }
}

class _QueueMusicSourceFactory implements MusicSourceFactory {
  _QueueMusicSourceFactory(this._sources);

  final List<MusicSource> _sources;
  int _index = 0;
  int createCalls = 0;

  @override
  SourceProtocol get protocol => SourceProtocol.webdav;

  @override
  MusicSource create(SourceProfile profile) {
    createCalls++;
    return _sources[_index++];
  }
}

class _FakeLibraryPreferencesRepository
    implements LibraryPreferencesRepository {
  const _FakeLibraryPreferencesRepository();

  @override
  Future<LibraryPreferences> load() async {
    return const LibraryPreferences();
  }

  @override
  Future<void> save(LibraryPreferences preferences) async {}

  @override
  Future<LibraryPreferences> update(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async {
    return transform(const LibraryPreferences());
  }
}

class _StubLibraryController extends LibraryController {
  @override
  Future<LibraryViewState> build() async {
    return const LibraryViewState(
      sources: <SourceProfile>[],
      selectedSource: null,
      currentPath: '/',
      entries: <RemoteEntry>[],
    );
  }
}

class _OverridingAddSourceController extends AddSourceController {
  _OverridingAddSourceController(this._capture);

  final void Function(
    _ControlledSource source,
    Cloud189CaptchaResolver? captchaResolver,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
  )
  _capture;

  @override
  MusicSource createConnectionSource(
    SourceProfile profile, {
    Cloud189CaptchaResolver? captchaResolver,
    Cloud189QRCodeResolver? qrCodeResolver,
    Cloud189SMSVerificationResolver? smsVerificationResolver,
  }) {
    final source = _ControlledSource(profile);
    _capture(source, captchaResolver, qrCodeResolver, smsVerificationResolver);
    return source;
  }
}

Cloud189SourceDraft _cloudDraft() => Cloud189SourceDraft(
  name: 'Cloud',
  authMode: Cloud189AuthMode.openListPassword,
  username: 'user',
  refreshToken: 'refresh',
  appKey: '',
  appSecret: '',
  redirectUri: '',
  authorizationCode: '',
  tvLoginMode: Cloud189TVLoginMode.scanCode,
  deviceId: '',
  rootPath: '/',
);

void main() {
  group('AddSourceController cancellation', () {
    test('cancels a save blocked in connect before any commit', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final source = _ControlledSource(_profileA);
      final blocker = Completer<void>();
      source.connectCompleter = blocker;
      final factory = _QueueMusicSourceFactory([source]);
      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
          musicSourceRegistryProvider.overrideWithValue(
            MusicSourceRegistry([factory]),
          ),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      final controller = container.read(addSourceControllerProvider.notifier);
      final saveFuture = controller.saveWebDavSource(_draft('source-a'));
      await source.connectStarted.future;

      final cancelResult = controller.cancelPendingOperation();
      expect(cancelResult, isTrue);
      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );

      final expectation = expectLater(
        saveFuture,
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      blocker.complete();
      await expectation;

      expect(source.listCalls, 0);
      expect(repository.saveProfilesCalls, isEmpty);
      expect(repository.saveActiveSourceIdCalls, isEmpty);
      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
      expect(source.disconnectCalls, greaterThanOrEqualTo(1));
    });

    test('cancels a save blocked in listFiles, then disconnects', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final source = _ControlledSource(_profileA);
      final blocker = Completer<void>();
      source.listCompleter = blocker;
      final factory = _QueueMusicSourceFactory([source]);
      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
          musicSourceRegistryProvider.overrideWithValue(
            MusicSourceRegistry([factory]),
          ),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      final controller = container.read(addSourceControllerProvider.notifier);
      final saveFuture = controller.saveWebDavSource(_draft('source-a'));
      await source.listStarted.future;

      final cancelResult = controller.cancelPendingOperation();
      expect(cancelResult, isTrue);
      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );

      final expectation = expectLater(
        saveFuture,
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      blocker.complete();
      await expectation;

      expect(source.connectCalls, 1);
      expect(source.listCalls, 1);
      expect(repository.saveProfilesCalls, isEmpty);
      expect(repository.saveActiveSourceIdCalls, isEmpty);
      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
      expect(source.disconnectCalls, greaterThanOrEqualTo(1));
    });

    test('superseding request cancels old connect preflight', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final oldSource = _ControlledSource(_profileA);
      final oldBlocker = Completer<void>();
      oldSource.connectCompleter = oldBlocker;
      final newSource = _ControlledSource(_profileB);
      final newBlocker = Completer<void>();
      newSource.connectCompleter = newBlocker;
      final factory = _QueueMusicSourceFactory([oldSource, newSource]);
      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
          musicSourceRegistryProvider.overrideWithValue(
            MusicSourceRegistry([factory]),
          ),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      final controller = container.read(addSourceControllerProvider.notifier);
      final oldFuture = controller.saveWebDavSource(_draft('old'));
      await oldSource.connectStarted.future;
      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncLoading<void>>(),
      );

      final newFuture = controller.saveWebDavSource(_draft('new'));
      await newSource.connectStarted.future;
      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncLoading<void>>(),
      );

      final oldExpectation = expectLater(
        oldFuture,
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      oldBlocker.complete();
      await oldExpectation;

      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncLoading<void>>(),
      );
      expect(repository.saveProfilesCalls, isEmpty);

      newBlocker.complete();
      final savedProfile = await newFuture;
      expect(savedProfile.id, 'new');
      expect(repository.saveProfilesCalls, hasLength(1));
      expect(repository.saveActiveSourceIdCalls, [savedProfile.id]);
      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
    });

    test(
      'superseding request cancels old list preflight after error release',
      () async {
        final repository = _FakeSourceProfileRepository(
          initialProfiles: const [],
          initialActiveSourceId: null,
        );
        final oldSource = _ControlledSource(_profileA);
        final oldBlocker = Completer<void>();
        oldSource.listCompleter = oldBlocker;
        final newSource = _ControlledSource(_profileB);
        final newBlocker = Completer<void>();
        newSource.connectCompleter = newBlocker;
        final factory = _QueueMusicSourceFactory([oldSource, newSource]);
        final container = ProviderContainer(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(repository),
            libraryControllerProvider.overrideWith(_StubLibraryController.new),
            musicSourceRegistryProvider.overrideWithValue(
              MusicSourceRegistry([factory]),
            ),
          ],
        );
        final addSubscription = container.listen(
          addSourceControllerProvider,
          (_, _) {},
        );
        final sourcesSubscription = container.listen(
          sourcesControllerProvider,
          (_, _) {},
        );
        addTearDown(() {
          addSubscription.close();
          sourcesSubscription.close();
          container.dispose();
        });
        await container.read(sourcesControllerProvider.future);

        final controller = container.read(addSourceControllerProvider.notifier);
        final oldFuture = controller.saveWebDavSource(_draft('old'));
        await oldSource.listStarted.future;

        final newFuture = controller.saveWebDavSource(_draft('new'));
        await newSource.connectStarted.future;

        final oldExpectation = expectLater(
          oldFuture,
          throwsA(isA<AddSourceOperationCancelled>()),
        );
        oldBlocker.completeError(StateError('old list failed'));
        await oldExpectation;

        expect(
          container.read(addSourceControllerProvider),
          isA<AsyncLoading<void>>(),
        );
        expect(repository.saveProfilesCalls, isEmpty);

        newBlocker.complete();
        final savedProfile = await newFuture;
        expect(savedProfile.id, 'new');
        expect(repository.saveActiveSourceIdCalls, [savedProfile.id]);
      },
    );

    test(
      'commit keeps isCommitting true across profile and active writes',
      () async {
        final repository = _FakeSourceProfileRepository(
          initialProfiles: const [],
          initialActiveSourceId: null,
        );
        final source = _ControlledSource(_profileA);
        final profilesBlocker = Completer<void>();
        final activeBlocker = Completer<void>();
        repository.saveProfilesBlocker = profilesBlocker;
        repository.saveActiveSourceIdBlocker = activeBlocker;
        final factory = _QueueMusicSourceFactory([source]);
        final container = ProviderContainer(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(repository),
            libraryControllerProvider.overrideWith(_StubLibraryController.new),
            musicSourceRegistryProvider.overrideWithValue(
              MusicSourceRegistry([factory]),
            ),
          ],
        );
        final addSubscription = container.listen(
          addSourceControllerProvider,
          (_, _) {},
        );
        final sourcesSubscription = container.listen(
          sourcesControllerProvider,
          (_, _) {},
        );
        addTearDown(() {
          addSubscription.close();
          sourcesSubscription.close();
          container.dispose();
        });
        await container.read(sourcesControllerProvider.future);

        final controller = container.read(addSourceControllerProvider.notifier);
        final saveFuture = controller.saveWebDavSource(_draft('source-a'));
        await repository.saveProfilesStarted.future;

        expect(controller.isCommitting, isTrue);
        expect(controller.cancelPendingOperation(), isFalse);
        expect(
          container.read(addSourceControllerProvider),
          isA<AsyncLoading<void>>(),
        );

        profilesBlocker.complete();
        await repository.saveActiveSourceIdStarted.future;

        expect(controller.isCommitting, isTrue);
        expect(controller.cancelPendingOperation(), isFalse);
        expect(
          container.read(addSourceControllerProvider),
          isA<AsyncLoading<void>>(),
        );

        activeBlocker.complete();
        final savedProfile = await saveFuture;

        expect(savedProfile.id, 'source-a');
        expect(controller.isCommitting, isFalse);
        expect(
          container.read(addSourceControllerProvider),
          isA<AsyncData<void>>(),
        );
        expect(repository.storedProfiles, contains(savedProfile));
        expect(repository.activeSourceId, savedProfile.id);
        expect(source.disconnectCalls, greaterThanOrEqualTo(1));
      },
    );

    test('commit refuses concurrent operation with StateError', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final source = _ControlledSource(_profileA);
      final profilesBlocker = Completer<void>();
      repository.saveProfilesBlocker = profilesBlocker;
      final secondSource = _ControlledSource(_profileB);
      final factory = _QueueMusicSourceFactory([source, secondSource]);
      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
          musicSourceRegistryProvider.overrideWithValue(
            MusicSourceRegistry([factory]),
          ),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      final controller = container.read(addSourceControllerProvider.notifier);
      final saveFuture = controller.saveWebDavSource(_draft('source-a'));
      await repository.saveProfilesStarted.future;

      Object? syncError;
      Future<SourceProfile>? secondFuture;
      try {
        secondFuture = controller.saveWebDavSource(_draft('second'));
      } on StateError catch (error) {
        syncError = error;
      }
      if (syncError != null) {
        expect(syncError, isA<StateError>());
      } else if (secondFuture != null) {
        await expectLater(secondFuture, throwsA(isA<StateError>()));
      }

      expect(factory.createCalls, 1);
      expect(secondSource.connectCalls, 0);

      profilesBlocker.complete();
      await saveFuture;
    });

    test(
      'save preflight failure exposes AsyncError and writes nothing',
      () async {
        final repository = _FakeSourceProfileRepository(
          initialProfiles: [_oldProfile],
          initialActiveSourceId: _oldProfile.id,
        );
        final source = _ControlledSource(_profileA);
        final failingBlocker = Completer<void>();
        source.connectCompleter = failingBlocker;
        final factory = _QueueMusicSourceFactory([source]);
        final container = ProviderContainer(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(repository),
            libraryControllerProvider.overrideWith(_StubLibraryController.new),
            musicSourceRegistryProvider.overrideWithValue(
              MusicSourceRegistry([factory]),
            ),
          ],
        );
        final addSubscription = container.listen(
          addSourceControllerProvider,
          (_, _) {},
        );
        final sourcesSubscription = container.listen(
          sourcesControllerProvider,
          (_, _) {},
        );
        addTearDown(() {
          addSubscription.close();
          sourcesSubscription.close();
          container.dispose();
        });
        await container.read(sourcesControllerProvider.future);

        final controller = container.read(addSourceControllerProvider.notifier);
        final saveFuture = controller.saveWebDavSource(_draft('source-a'));

        final expectation = expectLater(saveFuture, throwsA(isA<StateError>()));
        failingBlocker.completeError(StateError('connection failed'));
        await expectation;

        final state = container.read(addSourceControllerProvider);
        expect(state, isA<AsyncError<void>>());
        expect(repository.saveProfilesCalls, isEmpty);
        expect(repository.saveActiveSourceIdCalls, isEmpty);
        expect(container.read(sourcesControllerProvider).valueOrNull, [
          _oldProfile,
        ]);
      },
    );

    test(
      'container dispose during connect preflight cancels without writes',
      () async {
        final repository = _FakeSourceProfileRepository(
          initialProfiles: const [],
          initialActiveSourceId: null,
        );
        final source = _ControlledSource(_profileA);
        final blocker = Completer<void>();
        source.connectCompleter = blocker;
        final factory = _QueueMusicSourceFactory([source]);
        final container = ProviderContainer(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(repository),
            musicSourceRegistryProvider.overrideWithValue(
              MusicSourceRegistry([factory]),
            ),
            libraryControllerProvider.overrideWith(_StubLibraryController.new),
          ],
        );
        final addSubscription = container.listen(
          addSourceControllerProvider,
          (_, _) {},
        );
        final sourcesSubscription = container.listen(
          sourcesControllerProvider,
          (_, _) {},
        );
        await container.read(sourcesControllerProvider.future);

        final controller = container.read(addSourceControllerProvider.notifier);
        final saveFuture = controller.saveWebDavSource(_draft('source-a'));
        await source.connectStarted.future;

        container.dispose();

        final expectation = expectLater(
          saveFuture,
          throwsA(isA<AddSourceOperationCancelled>()),
        );
        blocker.complete();
        await expectation;

        addSubscription.close();
        sourcesSubscription.close();

        expect(repository.saveProfilesCalls, isEmpty);
        expect(repository.saveActiveSourceIdCalls, isEmpty);
        expect(source.listCalls, 0);
      },
    );

    test(
      'container dispose during list preflight cancels without writes',
      () async {
        final repository = _FakeSourceProfileRepository(
          initialProfiles: const [],
          initialActiveSourceId: null,
        );
        final source = _ControlledSource(_profileA);
        final blocker = Completer<void>();
        source.listCompleter = blocker;
        final factory = _QueueMusicSourceFactory([source]);
        final container = ProviderContainer(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(repository),
            musicSourceRegistryProvider.overrideWithValue(
              MusicSourceRegistry([factory]),
            ),
            libraryControllerProvider.overrideWith(_StubLibraryController.new),
          ],
        );
        final addSubscription = container.listen(
          addSourceControllerProvider,
          (_, _) {},
        );
        final sourcesSubscription = container.listen(
          sourcesControllerProvider,
          (_, _) {},
        );
        await container.read(sourcesControllerProvider.future);

        final controller = container.read(addSourceControllerProvider.notifier);
        final saveFuture = controller.saveWebDavSource(_draft('source-a'));
        await source.listStarted.future;

        container.dispose();

        final expectation = expectLater(
          saveFuture,
          throwsA(isA<AddSourceOperationCancelled>()),
        );
        blocker.complete();
        await expectation;

        addSubscription.close();
        sourcesSubscription.close();

        expect(repository.saveProfilesCalls, isEmpty);
        expect(repository.saveActiveSourceIdCalls, isEmpty);
      },
    );

    test(
      'container dispose during commit still completes save successfully',
      () async {
        final repository = _FakeSourceProfileRepository(
          initialProfiles: const [],
          initialActiveSourceId: null,
        );
        final source = _ControlledSource(_profileA);
        final profilesBlocker = Completer<void>();
        final activeBlocker = Completer<void>();
        repository.saveProfilesBlocker = profilesBlocker;
        repository.saveActiveSourceIdBlocker = activeBlocker;
        final factory = _QueueMusicSourceFactory([source]);
        final container = ProviderContainer(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(repository),
            musicSourceRegistryProvider.overrideWithValue(
              MusicSourceRegistry([factory]),
            ),
            libraryControllerProvider.overrideWith(_StubLibraryController.new),
          ],
        );
        final addSubscription = container.listen(
          addSourceControllerProvider,
          (_, _) {},
        );
        final sourcesSubscription = container.listen(
          sourcesControllerProvider,
          (_, _) {},
        );
        await container.read(sourcesControllerProvider.future);

        final controller = container.read(addSourceControllerProvider.notifier);
        final saveFuture = controller.saveWebDavSource(_draft('source-a'));
        await repository.saveProfilesStarted.future;

        expect(controller.isCommitting, isTrue);
        expect(controller.cancelPendingOperation(), isFalse);

        container.dispose();

        profilesBlocker.complete();
        await repository.saveActiveSourceIdStarted.future;
        activeBlocker.complete();

        final savedProfile = await saveFuture;
        expect(savedProfile.id, 'source-a');
        expect(repository.storedProfiles, contains(savedProfile));
        expect(repository.activeSourceId, savedProfile.id);
        expect(source.disconnectCalls, greaterThanOrEqualTo(1));

        addSubscription.close();
        sourcesSubscription.close();
      },
    );

    test(
      'save persistence failure exposes AsyncError and retains previous sources',
      () async {
        final repository = _FakeSourceProfileRepository(
          initialProfiles: [_oldProfile],
          initialActiveSourceId: _oldProfile.id,
        );
        repository.saveProfilesError = StateError('persistence failed');
        final source = _ControlledSource(_profileA);
        final factory = _QueueMusicSourceFactory([source]);
        final container = ProviderContainer(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(repository),
            musicSourceRegistryProvider.overrideWithValue(
              MusicSourceRegistry([factory]),
            ),
            libraryControllerProvider.overrideWith(_StubLibraryController.new),
          ],
        );
        final addSubscription = container.listen(
          addSourceControllerProvider,
          (_, _) {},
        );
        final sourcesSubscription = container.listen(
          sourcesControllerProvider,
          (_, _) {},
        );
        addTearDown(() {
          addSubscription.close();
          sourcesSubscription.close();
          container.dispose();
        });
        await container.read(sourcesControllerProvider.future);

        final controller = container.read(addSourceControllerProvider.notifier);
        final saveFuture = controller.saveWebDavSource(_draft('source-a'));

        final expectation = expectLater(saveFuture, throwsA(isA<StateError>()));
        await expectation;

        final state = container.read(addSourceControllerProvider);
        expect(state, isA<AsyncError<void>>());
        expect(repository.saveActiveSourceIdCalls, isEmpty);
        expect(container.read(sourcesControllerProvider).valueOrNull, [
          _oldProfile,
        ]);
        expect(source.disconnectCalls, greaterThanOrEqualTo(1));
      },
    );

    test('cancel during blocked testConnection cleanup', () async {
      final source = _ControlledSource(_profileA);
      final disconnectBlocker = Completer<void>();
      source.disconnectCompleter = disconnectBlocker;
      final factory = _QueueMusicSourceFactory([source]);
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          musicSourceRegistryProvider.overrideWithValue(
            MusicSourceRegistry([factory]),
          ),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      final controller = container.read(addSourceControllerProvider.notifier);
      final draft = WebDavSourceDraft(
        name: 'Conn',
        baseUrl: 'https://example.com/a/',
        username: 'user',
        password: 'pass',
        rootPath: '/',
      );
      final future = controller.testConnection(draft);
      await source.disconnectStarted.future;

      final cancelResult = controller.cancelPendingOperation();
      expect(cancelResult, isTrue);

      final expectation = expectLater(
        future,
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      disconnectBlocker.complete();
      await expectation;

      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
    });
    test('cloud captcha resolver stays uncalled after cancellation', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final connectBlocker = Completer<void>();
      _ControlledSource? capturedSource;
      Cloud189CaptchaResolver? capturedResolver;
      final factoryStarted = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          addSourceControllerProvider.overrideWith(
            () => _OverridingAddSourceController((source, captcha, _, _) {
              capturedSource = source;
              capturedResolver = captcha;
              source.connectCompleter = connectBlocker;
              if (!factoryStarted.isCompleted) {
                factoryStarted.complete();
              }
            }),
          ),
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            const _FakeLibraryPreferencesRepository(),
          ),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      var counter = 0;
      Future<String?> captchaResolver(Uint8List bytes) async {
        counter++;
        return 'captcha';
      }

      final controller = container.read(addSourceControllerProvider.notifier);
      final operationFuture = controller.testCloud189Connection(
        _cloudDraft(),
        captchaResolver: captchaResolver,
      );
      await factoryStarted.future;
      final source = capturedSource!;
      await source.connectStarted.future;

      expect(controller.cancelPendingOperation(), isTrue);

      final expectation = expectLater(
        capturedResolver!(Uint8List(0)),
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      await expectation;
      expect(counter, 0);

      final cancelExpectation = expectLater(
        operationFuture,
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      connectBlocker.complete();
      await cancelExpectation;

      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
    });

    test('cloud qr resolver stays uncalled after cancellation', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final connectBlocker = Completer<void>();
      _ControlledSource? capturedSource;
      Cloud189QRCodeResolver? capturedResolver;
      final factoryStarted = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          addSourceControllerProvider.overrideWith(
            () => _OverridingAddSourceController((source, _, qr, _) {
              capturedSource = source;
              capturedResolver = qr;
              source.connectCompleter = connectBlocker;
              if (!factoryStarted.isCompleted) {
                factoryStarted.complete();
              }
            }),
          ),
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            const _FakeLibraryPreferencesRepository(),
          ),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      var counter = 0;
      Future<void> qrResolver(String content) async {
        counter++;
      }

      final controller = container.read(addSourceControllerProvider.notifier);
      final operationFuture = controller.testCloud189Connection(
        _cloudDraft(),
        qrCodeResolver: qrResolver,
      );
      await factoryStarted.future;
      final source = capturedSource!;
      await source.connectStarted.future;

      expect(controller.cancelPendingOperation(), isTrue);

      final expectation = expectLater(
        capturedResolver!('qr-content'),
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      await expectation;
      expect(counter, 0);

      final cancelExpectation = expectLater(
        operationFuture,
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      connectBlocker.complete();
      await cancelExpectation;

      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
    });

    test('cloud sms resolver stays uncalled after cancellation', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final connectBlocker = Completer<void>();
      _ControlledSource? capturedSource;
      Cloud189SMSVerificationResolver? capturedResolver;
      final factoryStarted = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          addSourceControllerProvider.overrideWith(
            () => _OverridingAddSourceController((source, _, _, sms) {
              capturedSource = source;
              capturedResolver = sms;
              source.connectCompleter = connectBlocker;
              if (!factoryStarted.isCompleted) {
                factoryStarted.complete();
              }
            }),
          ),
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            const _FakeLibraryPreferencesRepository(),
          ),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      var counter = 0;
      Future<String?> smsResolver(String hint) async {
        counter++;
        return 'code';
      }

      final controller = container.read(addSourceControllerProvider.notifier);
      final operationFuture = controller.testCloud189Connection(
        _cloudDraft(),
        smsVerificationResolver: smsResolver,
      );
      await factoryStarted.future;
      final source = capturedSource!;
      await source.connectStarted.future;

      expect(controller.cancelPendingOperation(), isTrue);

      final expectation = expectLater(
        capturedResolver!('hint'),
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      await expectation;
      expect(counter, 0);

      final cancelExpectation = expectLater(
        operationFuture,
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      connectBlocker.complete();
      await cancelExpectation;

      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
    });

    test('cloud already-open resolver Future cancelled during await', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final connectBlocker = Completer<void>();
      final resolverBlocker = Completer<String?>();
      _ControlledSource? capturedSource;
      Cloud189CaptchaResolver? capturedResolver;
      final factoryStarted = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          addSourceControllerProvider.overrideWith(
            () => _OverridingAddSourceController((source, captcha, _, _) {
              capturedSource = source;
              capturedResolver = captcha;
              source.connectCompleter = connectBlocker;
              if (!factoryStarted.isCompleted) {
                factoryStarted.complete();
              }
            }),
          ),
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          libraryPreferencesRepositoryProvider.overrideWithValue(
            const _FakeLibraryPreferencesRepository(),
          ),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      var counter = 0;
      Future<String?> captchaResolver(Uint8List bytes) async {
        counter++;
        return await resolverBlocker.future;
      }

      final controller = container.read(addSourceControllerProvider.notifier);
      final operationFuture = controller.testCloud189Connection(
        _cloudDraft(),
        captchaResolver: captchaResolver,
      );
      await factoryStarted.future;
      final source = capturedSource!;
      await source.connectStarted.future;

      // Trigger the resolver while the operation is still in flight.
      final lateExpectation = expectLater(
        capturedResolver!(Uint8List(0)),
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      expect(controller.cancelPendingOperation(), isTrue);
      resolverBlocker.complete('late-answer');
      await lateExpectation;
      expect(counter, 1);

      final cancelExpectation = expectLater(
        operationFuture,
        throwsA(isA<AddSourceOperationCancelled>()),
      );
      connectBlocker.complete();
      await cancelExpectation;

      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
    });

    test('successful save remains successful when disconnect throws', () async {
      final repository = _FakeSourceProfileRepository(
        initialProfiles: const [],
        initialActiveSourceId: null,
      );
      final source = _ControlledSource(_profileA);
      source.disconnectError = StateError('disconnect failed');
      final factory = _QueueMusicSourceFactory([source]);
      final container = ProviderContainer(
        overrides: [
          sourceProfileRepositoryProvider.overrideWithValue(repository),
          musicSourceRegistryProvider.overrideWithValue(
            MusicSourceRegistry([factory]),
          ),
          libraryControllerProvider.overrideWith(_StubLibraryController.new),
        ],
      );
      final addSubscription = container.listen(
        addSourceControllerProvider,
        (_, _) {},
      );
      final sourcesSubscription = container.listen(
        sourcesControllerProvider,
        (_, _) {},
      );
      addTearDown(() {
        addSubscription.close();
        sourcesSubscription.close();
        container.dispose();
      });
      await container.read(sourcesControllerProvider.future);

      final controller = container.read(addSourceControllerProvider.notifier);
      final saveFuture = controller.saveWebDavSource(_draft('source-a'));

      final savedProfile = await saveFuture;

      expect(savedProfile.id, 'source-a');
      expect(repository.storedProfiles, contains(savedProfile));
      expect(repository.activeSourceId, savedProfile.id);
      expect(
        container.read(addSourceControllerProvider),
        isA<AsyncData<void>>(),
      );
      expect(controller.isCommitting, isFalse);
      expect(source.disconnectCalls, greaterThanOrEqualTo(1));
    });

    test(
      'provider listener observes isCommitting while state stays loading',
      () async {
        final repository = _FakeSourceProfileRepository(
          initialProfiles: const [],
          initialActiveSourceId: null,
        );
        final source = _ControlledSource(_profileA);
        final connectBlocker = Completer<void>();
        source.connectCompleter = connectBlocker;
        final profilesBlocker = Completer<void>();
        final activeBlocker = Completer<void>();
        repository.saveProfilesBlocker = profilesBlocker;
        repository.saveActiveSourceIdBlocker = activeBlocker;
        final factory = _QueueMusicSourceFactory([source]);
        final container = ProviderContainer(
          overrides: [
            sourceProfileRepositoryProvider.overrideWithValue(repository),
            musicSourceRegistryProvider.overrideWithValue(
              MusicSourceRegistry([factory]),
            ),
            libraryControllerProvider.overrideWith(_StubLibraryController.new),
          ],
        );
        final addSubscription = container.listen(
          addSourceControllerProvider,
          (_, _) {},
        );
        final sourcesSubscription = container.listen(
          sourcesControllerProvider,
          (_, _) {},
        );
        addTearDown(() {
          addSubscription.close();
          sourcesSubscription.close();
          container.dispose();
        });
        await container.read(sourcesControllerProvider.future);

        final controller = container.read(addSourceControllerProvider.notifier);
        final observations = <({bool isCommitting, bool isLoading})>[];
        final subscription = container.listen(addSourceControllerProvider, (
          _,
          next,
        ) {
          observations.add((
            isCommitting: controller.isCommitting,
            isLoading: next is AsyncLoading<void>,
          ));
        });

        final saveFuture = controller.saveWebDavSource(_draft('source-a'));
        await source.connectStarted.future;

        expect(
          observations.any((entry) => !entry.isCommitting && entry.isLoading),
          isTrue,
        );

        connectBlocker.complete();
        await repository.saveProfilesStarted.future;

        expect(
          observations.any((entry) => entry.isCommitting && entry.isLoading),
          isTrue,
        );

        profilesBlocker.complete();
        await repository.saveActiveSourceIdStarted.future;
        activeBlocker.complete();

        final savedProfile = await saveFuture;
        expect(savedProfile.id, 'source-a');
        expect(observations.last, (isCommitting: false, isLoading: false));
        subscription.close();

        expect(controller.isCommitting, isFalse);
      },
    );
  });
}
