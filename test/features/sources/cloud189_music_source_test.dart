import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:music/core/models/playback_cache_settings.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';
import 'package:music/features/sources/data/cloud189/cloud189_music_source.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';

class _FakeCloud189RemoteClient implements Cloud189RemoteClient {
  static const _nextRefreshToken = 'rotated-refresh-token';

  var connectCount = 0;
  var readTextCount = 0;
  String? openedPath;
  int? openedStart;
  int? openedEnd;

  /// Content-Type the fake 189 download endpoint reports back to the client.
  String responseContentType = 'audio/flac';

  @override
  String? get currentRefreshToken => _nextRefreshToken;

  @override
  Future<void> connect() async {
    connectCount += 1;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<Cloud189ReadResult> openRead(
    String path, {
    int? start,
    int? end,
  }) async {
    openedPath = path;
    openedStart = start;
    openedEnd = end;
    return Cloud189ReadResult(
      stream: Stream.value(const [1, 2, 3]),
      offset: start ?? 0,
      contentLength: 3,
      contentType: responseContentType,
      sourceLength: 1024,
    );
  }

  @override
  Future<List<Cloud189FileEntry>> readDirectory(String path) async {
    return const [
      Cloud189FileEntry(
        id: 'notes',
        name: 'notes.txt',
        path: '/Music/notes.txt',
        isDirectory: false,
        size: 8,
        mimeType: 'text/plain',
      ),
      Cloud189FileEntry(
        id: 'album',
        name: 'Album',
        path: '/Music/Album/',
        isDirectory: true,
      ),
      Cloud189FileEntry(
        id: 'song',
        name: 'song.flac',
        path: '/Music/song.flac',
        isDirectory: false,
        size: 1024,
        mimeType: 'audio/flac',
      ),
    ];
  }

  @override
  Future<String?> readText(String path) async {
    readTextCount += 1;
    return '[00:00.00]Hello from 189 Cloud';
  }
}

class _FakePlaybackCache implements WebDavPlaybackCache {
  @override
  int get retainedMemoryBytes => 0;

  @override
  void applySettings(PlaybackCacheSettings settings) {}

  @override
  void setActivePlaybackTrack(String? trackId) {}

  @override
  Stream<PlaybackCacheSnapshot> get snapshotStream =>
      const Stream<PlaybackCacheSnapshot>.empty();

  @override
  PlaybackCacheSnapshot? snapshotForTrack(String trackId) => null;

  @override
  Stream<List<PlaybackCacheInventoryItem>> watchCachedTracks() =>
      const Stream<List<PlaybackCacheInventoryItem>>.empty();

  @override
  Future<List<PlaybackCacheInventoryItem>> listCachedTracks() async =>
      const <PlaybackCacheInventoryItem>[];

  @override
  Future<AudioSource?> createCachedAudioSource({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  }) async => null;

  @override
  Future<void> prefetchEntry({
    required RemoteEntry entry,
    required WebDavRemoteClient client,
  }) async {}

  @override
  Future<WebDavCachedRange?> readCachedRange({
    required RemoteEntry entry,
    required int start,
    int? end,
  }) async => null;

  @override
  Future<String?> persistentFilePathForEntry(RemoteEntry entry) async => null;

  @override
  Stream<List<int>> wrapPlaybackStream({
    required RemoteEntry entry,
    required Stream<List<int>> stream,
    required int offset,
    required int? requestedEnd,
    required int? expectedLength,
  }) {
    return stream;
  }

  @override
  Future<void> clearAllCachedData() async {}

  @override
  Future<void> clearMemoryCachedData() async {}

  @override
  Future<void> removeCachedTracks(Set<String> trackIds) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  late SourceProfile profile;
  late _FakeCloud189RemoteClient client;

  setUp(() {
    profile = const SourceProfile(
      id: 'cloud189-1',
      name: '189 Cloud',
      protocol: SourceProtocol.cloudDrive,
      baseUrl: Cloud189Constants.apiBaseUrl,
      username: Cloud189Constants.providerId,
      password: 'refresh-token',
      rootPath: '/Music/',
    );
    client = _FakeCloud189RemoteClient();
  });

  test('sorts Tianyi folders before playable audio and other files', () async {
    final source = Cloud189MusicSource(
      profile,
      clientFactory: (_) => client,
      playbackCacheFactory: () => _FakePlaybackCache(),
    );

    final listing = await source.listFiles('/Music/');
    final entries = listing.entries;

    expect(entries.map((entry) => entry.kind), [
      RemoteEntryKind.directory,
      RemoteEntryKind.audio,
      RemoteEntryKind.file,
    ]);
    expect(entries.first.path, '/Music/Album/');
    expect(entries[1].path, '/Music/song.flac');
    expect(listing.diagnostics?.protocolLabel, SourceProtocol.cloudDrive.label);
  });

  test('builds playable track backed by the Tianyi stream source', () async {
    final source = Cloud189MusicSource(
      profile,
      clientFactory: (_) => client,
      playbackCacheFactory: () => _FakePlaybackCache(),
    );

    final track = await source.buildPlayableTrack(
      const RemoteEntry(
        sourceId: 'cloud189-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 1024,
      ),
    );

    expect(track.id, 'cloud189-1::/Music/song.flac');
    expect(track.sourceName, '189 Cloud');
    expect(track.albumTitle, 'Music');
    expect(track.audioSource, isA<StreamAudioSource>());

    final response = await (track.audioSource as StreamAudioSource).request(
      10,
      12,
    );
    expect(response.contentType, 'audio/flac');
    expect(response.offset, 10);
    expect(response.sourceLength, 1024);
    expect(client.openedPath, '/Music/song.flac');
    expect(client.openedStart, 10);
    expect(client.openedEnd, 12);
  });

  test('caches lyric reads within the same Tianyi source session', () async {
    final source = Cloud189MusicSource(
      profile,
      clientFactory: (_) => client,
      playbackCacheFactory: () => _FakePlaybackCache(),
    );

    final first = await source.readTextFile('/Music/song.lrc');
    final second = await source.readTextFile('/Music/song.lrc');

    expect(first, '[00:00.00]Hello from 189 Cloud');
    expect(second, first);
    expect(client.connectCount, 1);
    expect(client.readTextCount, 1);
  });

  // Exercises the real playback path: Cloud189MusicSource.buildPlayableTrack
  // produces the stream source, and StreamAudioSource.request() decides the
  // Content-Type handed to just_audio. This is what the AppleMusic版本 M4A
  // tracks go through, so the assertions are on the actual response object.
  group('playback content type through buildPlayableTrack', () {
    Future<StreamAudioResponse> requestFor({
      required String name,
      required String path,
      String? entryMimeType,
      required String responseContentType,
    }) async {
      client.responseContentType = responseContentType;
      final source = Cloud189MusicSource(
        profile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => _FakePlaybackCache(),
      );
      final track = await source.buildPlayableTrack(
        RemoteEntry(
          sourceId: 'cloud189-1',
          name: name,
          path: path,
          kind: RemoteEntryKind.audio,
          mimeType: entryMimeType,
          size: 1024,
        ),
      );
      expect(track.audioSource, isA<StreamAudioSource>());
      return (track.audioSource as StreamAudioSource).request(0, 3);
    }

    test('M4A with generic response header stays audio/mp4', () async {
      final response = await requestFor(
        name: '01. 太阳之子.m4a',
        path: '/Music/AppleMusic版本/01. 太阳之子.m4a',
        entryMimeType: 'application/octet-stream',
        responseContentType: 'application/octet-stream',
      );

      expect(response.contentType, 'audio/mp4');
    });

    test('FLAC with generic response header stays audio/flac', () async {
      final response = await requestFor(
        name: '01. 夜曲.flac',
        path: '/Music/杰伦/01. 夜曲.flac',
        entryMimeType: 'application/octet-stream',
        responseContentType: 'binary/octet-stream',
      );

      expect(response.contentType, 'audio/flac');
    });

    test('absent header and absent entry MIME fall back to the extension',
        () async {
      final m4a = await requestFor(
        name: '02. 西西里.m4a',
        path: '/Music/AppleMusic版本/02. 西西里.m4a',
        responseContentType: '',
      );
      expect(m4a.contentType, 'audio/mp4');

      final flac = await requestFor(
        name: '02. 以父之名.flac',
        path: '/Music/叶惠美/02. 以父之名.flac',
        responseContentType: '',
      );
      expect(flac.contentType, 'audio/flac');
    });

    test('explicit audio MIME from the response is preserved', () async {
      final m4a = await requestFor(
        name: '03. 那天下雨了.m4a',
        path: '/Music/AppleMusic版本/03. 那天下雨了.m4a',
        responseContentType: 'audio/mp4',
      );
      expect(m4a.contentType, 'audio/mp4');

      final flac = await requestFor(
        name: '03. 晴天.flac',
        path: '/Music/叶惠美/03. 晴天.flac',
        responseContentType: 'audio/flac',
      );
      expect(flac.contentType, 'audio/flac');
    });

    test('explicit entry MIME survives a generic response header', () async {
      final response = await requestFor(
        name: '04. 湘女多情.m4a',
        path: '/Music/AppleMusic版本/04. 湘女多情.m4a',
        entryMimeType: 'audio/mp4',
        responseContentType: 'application/octet-stream',
      );

      expect(response.contentType, 'audio/mp4');
    });
  });
}
