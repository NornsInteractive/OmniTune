import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/models/playable_track.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/storage/source_profile_repository.dart';
import 'package:music/features/library/application/library_controller.dart';
import 'package:music/features/sources/application/music_source_registry.dart';
import 'package:music/features/sources/domain/music_source.dart';

void main() {
  test('build returns before the selected remote source connects', () async {
    final connectCompleter = Completer<void>();
    final source = _BlockingMusicSource(_profile, connectCompleter.future);
    final container = ProviderContainer(
      overrides: [
        sourceProfileRepositoryProvider.overrideWithValue(
          _FakeSourceProfileRepository([_profile]),
        ),
        musicSourceRegistryProvider.overrideWithValue(
          MusicSourceRegistry([_FakeMusicSourceFactory(source)]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container
        .read(libraryControllerProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(state.sources, [_profile]);
    expect(state.selectedSource, _profile);
    expect(state.currentPath, _profile.effectiveRootPath);
    expect(state.entries, isEmpty);
    expect(state.isLoading, isTrue);
    expect(connectCompleter.isCompleted, isFalse);
  });
}

const _profile = SourceProfile(
  id: 'source-1',
  name: 'NAS',
  protocol: SourceProtocol.webdav,
  baseUrl: 'https://example.com/dav/',
  username: 'user',
  password: 'pass',
  rootPath: '/',
);

class _FakeSourceProfileRepository implements SourceProfileRepository {
  _FakeSourceProfileRepository(this._profiles);

  final List<SourceProfile> _profiles;
  String? _activeSourceId;

  @override
  Future<String?> loadActiveSourceId() async => _activeSourceId;

  @override
  Future<List<SourceProfile>> loadProfiles() async => _profiles;

  @override
  Future<void> saveActiveSourceId(String? sourceId) async {
    _activeSourceId = sourceId;
  }

  @override
  Future<void> saveProfiles(List<SourceProfile> profiles) async {}
}

class _FakeMusicSourceFactory implements MusicSourceFactory {
  const _FakeMusicSourceFactory(this._source);

  final MusicSource _source;

  @override
  SourceProtocol get protocol => SourceProtocol.webdav;

  @override
  MusicSource create(SourceProfile profile) => _source;
}

class _BlockingMusicSource implements MusicSource {
  const _BlockingMusicSource(this.profile, this._connectFuture);

  @override
  final SourceProfile profile;

  final Future<void> _connectFuture;

  @override
  Future<void> connect() => _connectFuture;

  @override
  Future<void> disconnect() async {}

  @override
  Future<DirectoryListing> listFiles(String path) async {
    return const DirectoryListing(entries: []);
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
}
