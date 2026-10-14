import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/models/library_album.dart';
import 'package:music/core/storage/library_preferences_repository.dart';

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage([Map<String, String>? data])
      : _data = data ?? <String, String>{},
        super();

  final Map<String, String> _data;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }
}

class _FailingOnceStorage extends _FakeSecureStorage {
  _FailingOnceStorage(super.data);

  int _writeCount = 0;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_writeCount++ == 0) {
      throw StateError('write failed');
    }
    await super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageKey = 'library_preferences_v1';

  test('missing albumGroupingMode defaults to folder', () async {
    final data = <String, String>{};
    final storage = _FakeSecureStorage(data);
    final repository = SecureLibraryPreferencesRepository(storage);

    await storage.write(
      key: storageKey,
      value: jsonEncode(<String, dynamic>{
        'favoriteTrackIds': <String>['track-1'],
      }),
    );

    final preferences = await repository.load();
    expect(preferences.albumGroupingMode, LibraryAlbumGroupingMode.folder);
    expect(preferences.favoriteTrackIds, contains('track-1'));
  });

  test('unknown albumGroupingMode defaults to folder', () async {
    final data = <String, String>{};
    final storage = _FakeSecureStorage(data);
    final repository = SecureLibraryPreferencesRepository(storage);

    await storage.write(
      key: storageKey,
      value: jsonEncode(<String, dynamic>{
        'albumGroupingMode': 'surprise',
      }),
    );

    final preferences = await repository.load();
    expect(preferences.albumGroupingMode, LibraryAlbumGroupingMode.folder);
  });

  test('both grouping modes round trip through rebuilt repository', () async {
    final data = <String, String>{};
    final storage = _FakeSecureStorage(data);

    for (final mode in LibraryAlbumGroupingMode.values) {
      final repository = SecureLibraryPreferencesRepository(storage);
      final saved = await repository.update(
        (preferences) => preferences.copyWith(albumGroupingMode: mode),
      );
      expect(saved.albumGroupingMode, mode);

      final rebuilt = SecureLibraryPreferencesRepository(storage);
      final restored = await rebuilt.load();
      expect(restored.albumGroupingMode, mode);
    }
  });

  test('settings update does not discard favorites', () async {
    final data = <String, String>{};
    final storage = _FakeSecureStorage(data);
    final repository = SecureLibraryPreferencesRepository(storage);

    await repository.update(
      (preferences) => preferences.copyWith(favoriteTrackIds: <String>{'track-1'}),
    );
    await repository.update(
      (preferences) => preferences.copyWith(
        albumGroupingMode: LibraryAlbumGroupingMode.metadata,
      ),
    );

    final restored = await repository.load();
    expect(restored.favoriteTrackIds, contains('track-1'));
    expect(restored.albumGroupingMode, LibraryAlbumGroupingMode.metadata);
  });

  test('settings update does not revert playback cache settings', () async {
    final data = <String, String>{};
    final storage = _FakeSecureStorage(data);
    final repository = SecureLibraryPreferencesRepository(storage);

    await repository.update(
      (preferences) => preferences.copyWith(
        enablePersistentPlaybackCache: true,
        memoryPlaybackCacheTrackLimit: 7,
      ),
    );
    await repository.update(
      (preferences) => preferences.copyWith(
        albumGroupingMode: LibraryAlbumGroupingMode.metadata,
      ),
    );

    final restored = await repository.load();
    expect(restored.enablePersistentPlaybackCache, isTrue);
    expect(restored.memoryPlaybackCacheTrackLimit, 7);
    expect(restored.albumGroupingMode, LibraryAlbumGroupingMode.metadata);
  });

  test('concurrent updates merge all fields', () async {
    final data = <String, String>{};
    final storage = _FakeSecureStorage(data);
    final repository = SecureLibraryPreferencesRepository(storage);

    await Future.wait(<Future<LibraryPreferences>>[
      repository.update(
        (preferences) => preferences.copyWith(favoriteTrackIds: <String>{'track-1'}),
      ),
      repository.update(
        (preferences) => preferences.copyWith(
          albumGroupingMode: LibraryAlbumGroupingMode.metadata,
        ),
      ),
      repository.update(
        (preferences) => preferences.copyWith(
          enablePersistentPlaybackCache: true,
          memoryPlaybackCacheTrackLimit: 9,
          albumViewGrid: true,
        ),
      ),
    ]);

    final restored = await repository.load();
    expect(restored.favoriteTrackIds, contains('track-1'));
    expect(restored.albumGroupingMode, LibraryAlbumGroupingMode.metadata);
    expect(restored.enablePersistentPlaybackCache, isTrue);
    expect(restored.memoryPlaybackCacheTrackLimit, 9);
    expect(restored.albumViewGrid, isTrue);
  });

  test('failed write is followed by successful update', () async {
    final data = <String, String>{};
    final storage = _FailingOnceStorage(data);
    final repository = SecureLibraryPreferencesRepository(storage);

    await expectLater(
      repository.update(
        (preferences) => preferences.copyWith(albumViewGrid: true),
      ),
      throwsA(isA<StateError>()),
    );

    final result = await repository.update(
      (preferences) => preferences.copyWith(albumViewGrid: true),
    );
    expect(result.albumViewGrid, isTrue);

    final restored = await SecureLibraryPreferencesRepository(storage).load();
    expect(restored.albumViewGrid, isTrue);
  });

  test('fast favorite toggles settle correctly', () async {
    final data = <String, String>{};
    final storage = _FakeSecureStorage(data);
    final repository = SecureLibraryPreferencesRepository(storage);

    const trackId = 'track-1';
    final futures = List.generate(10, (_) {
      return repository.update((preferences) {
        final updated = <String>{...preferences.favoriteTrackIds};
        if (!updated.remove(trackId)) {
          updated.add(trackId);
        }
        return preferences.copyWith(favoriteTrackIds: updated);
      });
    });

    await Future.wait(futures);
    final restored = await repository.load();
    // Ten toggles starting from empty should end empty.
    expect(restored.favoriteTrackIds, isEmpty);
  });
}