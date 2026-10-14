import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';
import 'package:music/features/sources/data/cloud189/cloud189_music_source.dart';
import 'package:music/features/sources/data/webdav/webdav_music_source.dart';
import 'package:music/features/sources/data/webdav/webdav_playback_cache_base.dart';
import 'package:music/features/sources/data/webdav/webdav_remote_client.dart';

const _data = <int>[0, 1, 2, 3, 4, 5, 6, 7];

class _FakeCloud189RemoteClient implements Cloud189RemoteClient {
  _FakeCloud189RemoteClient({this.mismatched = false});
  bool mismatched;
  final List<(int?, int?)> calls = [];
  int canceled = 0;

  @override
  String? get currentRefreshToken => null;

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<List<Cloud189FileEntry>> readDirectory(String path) async => const [];

  @override
  Future<String?> readText(String path) async => null;

  @override
  Future<Cloud189ReadResult> openRead(
    String path, {
    int? start,
    int? end,
  }) async {
    calls.add((start, end));
    final s = start ?? 0;
    final bytes = _slice(start, end);
    final isMismatch = mismatched && s == 2;
    final controller = StreamController<List<int>>(
      onCancel: () => canceled += 1,
    );
    Future.microtask(() {
      controller.add(bytes);
      controller.close();
    });
    return Cloud189ReadResult(
      stream: controller.stream,
      offset: isMismatch ? 0 : s,
      contentLength: isMismatch ? _data.length : 0,
      contentType: 'audio/flac',
      sourceLength: isMismatch ? _data.length : null,
    );
  }

  List<int> _slice(int? start, int? end) {
    final s = (start ?? 0).clamp(0, _data.length);
    var e = end ?? _data.length;
    if (e > _data.length) e = _data.length;
    if (e < s) e = s;
    return _data.sublist(s, e);
  }
}

class _FakeWebDavRemoteClient implements WebDavRemoteClient {
  _FakeWebDavRemoteClient({this.mismatched = false});
  bool mismatched;
  final List<(int?, int?)> calls = [];
  int canceled = 0;
  @override
  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;

  @override
  Future<void> ping() async {}

  @override
  Future<List<WebDavRemoteFile>> readDirectory(String path) async => const [];

  @override
  Future<String?> readText(String path) async => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    calls.add((start, end));
    final s = start ?? 0;
    final bytes = _slice(start, end);
    final isMismatch = mismatched && s == 2;
    final controller = StreamController<List<int>>(
      onCancel: () => canceled += 1,
    );
    Future.microtask(() {
      controller.add(bytes);
      controller.close();
    });
    return WebDavReadResult(
      stream: controller.stream,
      offset: isMismatch ? 0 : s,
      contentLength: isMismatch ? _data.length : 0,
      contentType: 'audio/flac',
      sourceLength: isMismatch ? _data.length : null,
    );
  }

  List<int> _slice(int? start, int? end) {
    final s = (start ?? 0).clamp(0, _data.length);
    var e = end ?? _data.length;
    if (e > _data.length) e = _data.length;
    if (e < s) e = s;
    return _data.sublist(s, e);
  }
}

class _FakePlaybackCache implements WebDavPlaybackCache {
  final List<int>? cacheBytes;
  _FakePlaybackCache({this.cacheBytes});
  @override
  int get retainedMemoryBytes => 0;
  @override
  void applySettings(_) {}
  @override
  void setActivePlaybackTrack(_) {}
  @override
  Stream<PlaybackCacheSnapshot> get snapshotStream =>
      const Stream<PlaybackCacheSnapshot>.empty();
  @override
  PlaybackCacheSnapshot? snapshotForTrack(_) => null;
  @override
  Stream<List<PlaybackCacheInventoryItem>> watchCachedTracks() =>
      const Stream<List<PlaybackCacheInventoryItem>>.empty();
  @override
  Future<List<PlaybackCacheInventoryItem>> listCachedTracks() async =>
      const <PlaybackCacheInventoryItem>[];
  @override
  Future<AudioSource?> createCachedAudioSource({
    required entry,
    required client,
  }) async => null;
  @override
  Future<void> prefetchEntry({required entry, required client}) async {}
  @override
  Future<WebDavCachedRange?> readCachedRange({
    required entry,
    required start,
    int? end,
  }) async {
    final bytes = cacheBytes;
    if (bytes == null || bytes.isEmpty || start != 0) return null;
    return WebDavCachedRange(
      start: 0,
      endExclusive: bytes.length,
      bytes: Uint8List.fromList(bytes),
    );
  }

  @override
  Future<String?> persistentFilePathForEntry(_) async => null;
  @override
  Stream<List<int>> wrapPlaybackStream({
    required entry,
    required stream,
    required offset,
    required requestedEnd,
    required expectedLength,
  }) => stream;
  @override
  Future<void> clearAllCachedData() async {}
  @override
  Future<void> clearMemoryCachedData() async {}
  @override
  Future<void> removeCachedTracks(_) async {}
  @override
  Future<void> dispose() async {}
}

Future<List<int>> _collect(Stream<List<int>> stream) async {
  final out = <int>[];
  await for (final c in stream) {
    out.addAll(c);
  }
  return out;
}

Future<void> _assertWhole(StreamAudioResponse r) async {
  expect(r.contentLength, isNull);
  expect(r.offset, isNull);
  expect(r.sourceLength, isNull);
  expect(r.rangeRequestsSupported, false);
  final bytes = await _collect(r.stream);
  expect(bytes, _data);
}

void main() {
  group('Cloud189 unknown length', () {
    const cloudProfile = SourceProfile(
      id: 'cloud189-1',
      name: '189 Cloud',
      protocol: SourceProtocol.cloudDrive,
      baseUrl: '',
      username: '',
      password: 't',
      rootPath: '/Music/',
    );

    test('(a) full unknown => one openRead(null,null)', () async {
      final client = _FakeCloud189RemoteClient();
      final cache = _FakePlaybackCache();
      final source = Cloud189MusicSource(
        cloudProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'cloud189-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await _assertWhole(await src.request());
      expect(client.calls, [(null, null)]);
      expect(client.canceled, 1);
    });

    test('(b) request(2,null) => first canceled + full reopen', () async {
      final client = _FakeCloud189RemoteClient();
      final cache = _FakePlaybackCache();
      final source = Cloud189MusicSource(
        cloudProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'cloud189-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await _assertWhole(await src.request(2, null));
      expect(client.calls, [(2, null), (null, null)]);
      expect(client.canceled, 2);
    });

    test('(c) request(0,3) => first canceled + full reopen', () async {
      final client = _FakeCloud189RemoteClient();
      final cache = _FakePlaybackCache();
      final source = Cloud189MusicSource(
        cloudProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'cloud189-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await _assertWhole(await src.request(0, 3));
      expect(client.calls, [(0, 3), (null, null)]);
      expect(client.canceled, 2);
    });

    test('cached-prefix unknown => reopen full', () async {
      final client = _FakeCloud189RemoteClient();
      final cache = _FakePlaybackCache(cacheBytes: [0, 1]);
      final source = Cloud189MusicSource(
        cloudProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'cloud189-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await _assertWhole(await src.request());
      expect(client.calls, [(2, null), (null, null)]);
      expect(client.canceled, 2);
    });

    test('mismatched prefix offset throws StateError', () async {
      final client = _FakeCloud189RemoteClient(mismatched: true);
      final cache = _FakePlaybackCache(cacheBytes: [0, 1]);
      final source = Cloud189MusicSource(
        cloudProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'cloud189-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await expectLater(src.request(), throwsA(isA<StateError>()));
      expect(client.calls, [(2, null)]);
      expect(client.canceled, 1);
    });
  });

  group('WebDAV unknown length', () {
    const wdProfile = SourceProfile(
      id: 'source-1',
      name: 'Home DAV',
      protocol: SourceProtocol.webdav,
      baseUrl: 'https://dav.example.com/files/',
      username: 'demo',
      password: 'secret',
      rootPath: '/Music/',
    );

    test('(a) full unknown => one openRead(null,null)', () async {
      final client = _FakeWebDavRemoteClient();
      final cache = _FakePlaybackCache();
      final source = WebDavMusicSource(
        wdProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await _assertWhole(await src.request());
      expect(client.calls, [(null, null)]);
      expect(client.canceled, 1);
    });

    test('(b) request(2,null) => first canceled + full reopen', () async {
      final client = _FakeWebDavRemoteClient();
      final cache = _FakePlaybackCache();
      final source = WebDavMusicSource(
        wdProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await _assertWhole(await src.request(2, null));
      expect(client.calls, [(2, null), (null, null)]);
      expect(client.canceled, 2);
    });

    test('(c) request(0,3) => first canceled + full reopen', () async {
      final client = _FakeWebDavRemoteClient();
      final cache = _FakePlaybackCache();
      final source = WebDavMusicSource(
        wdProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await _assertWhole(await src.request(0, 3));
      expect(client.calls, [(0, 3), (null, null)]);
      expect(client.canceled, 2);
    });

    test('cached-prefix unknown => reopen full', () async {
      final client = _FakeWebDavRemoteClient();
      final cache = _FakePlaybackCache(cacheBytes: [0, 1]);
      final source = WebDavMusicSource(
        wdProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await _assertWhole(await src.request());
      expect(client.calls, [(2, null), (null, null)]);
      expect(client.canceled, 2);
    });

    test('mismatched prefix offset throws StateError', () async {
      final client = _FakeWebDavRemoteClient(mismatched: true);
      final cache = _FakePlaybackCache(cacheBytes: [0, 1]);
      final source = WebDavMusicSource(
        wdProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: null,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      await expectLater(src.request(), throwsA(isA<StateError>()));
      expect(client.calls, [(2, null)]);
      expect(client.canceled, 1);
    });
  });
  group('stale Cloud189 total', () {
    const cloudProfile = SourceProfile(
      id: 'cloud189-1',
      name: '189 Cloud',
      protocol: SourceProtocol.cloudDrive,
      baseUrl: '',
      username: '',
      password: 't',
      rootPath: '/Music/',
    );

    test('real source request does not restore stale size5', () async {
      final client = _StaleCloud189TotalClient();
      final cache = _FakePlaybackCache();
      final source = Cloud189MusicSource(
        cloudProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'cloud189-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 5,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      final response = await src.request(0, null);
      expect(response.sourceLength, isNull);
      expect(await _collectAll(response.stream), hasLength(10));
    });

    test('bounded request 0..5 does not restore stale size5', () async {
      final client = _BoundedCloud189Client();
      final cache = _FakePlaybackCache();
      final source = Cloud189MusicSource(
        cloudProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'cloud189-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 5,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      final response = await src.request(0, 5);
      expect(response.sourceLength, isNull);
      expect(await _collectAll(response.stream), hasLength(5));
    });
  });

  group('stale WebDAV total', () {
    const wdProfile = SourceProfile(
      id: 'source-1',
      name: 'Home DAV',
      protocol: SourceProtocol.webdav,
      baseUrl: 'https://dav.example.com/files/',
      username: 'demo',
      password: 'secret',
      rootPath: '/Music/',
    );

    test('real WebDAV source does not restore stale size5', () async {
      final client = _StaleWebDavTotalClient();
      final cache = _FakePlaybackCache();
      final source = WebDavMusicSource(
        wdProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 5,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      final response = await src.request(0, null);
      expect(response.sourceLength, isNull);
      expect(await _collectAll(response.stream), hasLength(10));
    });

    test('valid metadata total20 remains20', () async {
      final client = _ValidWebDavTotalClient();
      final cache = _FakePlaybackCache();
      final source = WebDavMusicSource(
        wdProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 20,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      final response = await src.request(0, null);
      expect(response.sourceLength, 20);
    });

    test(
      'cached range preserves null snapshot total instead of stale size5',
      () async {
        final cache = _SnapshotPlaybackCache(
          cachedBytes: const [0, 1],
          snapshotTotal: null,
        );
        final client = _CachedWebDavClient();
        final source = WebDavMusicSource(
          wdProfile,
          clientFactory: (_) => client,
          playbackCacheFactory: () => cache,
        );
        final entry = const RemoteEntry(
          sourceId: 'source-1',
          name: 'song.flac',
          path: '/Music/song.flac',
          kind: RemoteEntryKind.audio,
          mimeType: 'audio/flac',
          size: 5,
        );
        final track = await source.buildPlayableTrack(entry);
        final src = track.audioSource as StreamAudioSource;
        final response = await src.request(0, 2);
        expect(response.sourceLength, isNull);
      },
    );

    test('cached range preserves valid snapshot total10', () async {
      final cache = _SnapshotPlaybackCache(
        cachedBytes: const [0, 1],
        snapshotTotal: 10,
      );
      final client = _CachedWebDavClient();
      final source = WebDavMusicSource(
        wdProfile,
        clientFactory: (_) => client,
        playbackCacheFactory: () => cache,
      );
      final entry = const RemoteEntry(
        sourceId: 'source-1',
        name: 'song.flac',
        path: '/Music/song.flac',
        kind: RemoteEntryKind.audio,
        mimeType: 'audio/flac',
        size: 5,
      );
      final track = await source.buildPlayableTrack(entry);
      final src = track.audioSource as StreamAudioSource;
      final response = await src.request(0, 2);
      expect(response.sourceLength, 10);
    });
  });
}

class _StaleCloud189TotalClient implements Cloud189RemoteClient {
  @override
  String? get currentRefreshToken => null;
  @override
  Future<void> connect() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<List<Cloud189FileEntry>> readDirectory(String path) async => const [];
  @override
  Future<String?> readText(String path) async => null;
  @override
  Future<Cloud189ReadResult> openRead(
    String path, {
    int? start,
    int? end,
  }) async {
    return Cloud189ReadResult(
      stream: Stream.value(List<int>.filled(10, 1)),
      offset: start ?? 0,
      contentLength: 10,
      contentType: 'audio/flac',
      sourceLength: null,
    );
  }
}

class _StaleWebDavTotalClient implements WebDavRemoteClient {
  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> ping() async {}
  @override
  Future<List<WebDavRemoteFile>> readDirectory(String path) async => const [];
  @override
  Future<String?> readText(String path) async => null;
  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    return WebDavReadResult(
      stream: Stream.value(List<int>.filled(10, 1)),
      offset: start ?? 0,
      contentLength: 10,
      contentType: 'audio/flac',
      sourceLength: null,
    );
  }
}

class _ValidWebDavTotalClient implements WebDavRemoteClient {
  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> ping() async {}
  @override
  Future<List<WebDavRemoteFile>> readDirectory(String path) async => const [];
  @override
  Future<String?> readText(String path) async => null;
  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    return WebDavReadResult(
      stream: Stream.value(List<int>.filled(10, 1)),
      offset: start ?? 0,
      contentLength: 10,
      contentType: 'audio/flac',
      sourceLength: 20,
    );
  }
}

Future<List<int>> _collectAll(Stream<List<int>> stream) async {
  final out = <int>[];
  await for (final c in stream) {
    out.addAll(c);
  }
  return out;
}

class _BoundedCloud189Client implements Cloud189RemoteClient {
  @override
  String? get currentRefreshToken => null;
  @override
  Future<void> connect() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<List<Cloud189FileEntry>> readDirectory(String path) async => const [];
  @override
  Future<String?> readText(String path) async => null;
  @override
  Future<Cloud189ReadResult> openRead(
    String path, {
    int? start,
    int? end,
  }) async {
    return Cloud189ReadResult(
      stream: Stream.value(List<int>.filled(5, 1)),
      offset: start ?? 0,
      contentLength: 5,
      contentType: 'audio/flac',
      sourceLength: null,
    );
  }
}

class _CachedWebDavClient implements WebDavRemoteClient {
  @override
  WebDavDirectoryDebugInfo? get lastDirectoryDebugInfo => null;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> ping() async {}
  @override
  Future<List<WebDavRemoteFile>> readDirectory(String path) async => const [];
  @override
  Future<String?> readText(String path) async => null;
  @override
  Future<WebDavReadResult> openRead(String path, {int? start, int? end}) async {
    return WebDavReadResult(
      stream: Stream.value(const <int>[]),
      offset: start ?? 0,
      contentLength: 0,
      contentType: 'audio/flac',
      sourceLength: null,
    );
  }
}

class _SnapshotPlaybackCache extends _FakePlaybackCache {
  _SnapshotPlaybackCache({
    required this.cachedBytes,
    required this.snapshotTotal,
  });
  final List<int> cachedBytes;
  final int? snapshotTotal;

  @override
  Future<WebDavCachedRange?> readCachedRange({
    required RemoteEntry entry,
    required int start,
    int? end,
  }) async {
    if (start != 0 || cachedBytes.isEmpty) return null;
    return WebDavCachedRange(
      start: 0,
      endExclusive: cachedBytes.length,
      bytes: Uint8List.fromList(cachedBytes),
    );
  }

  @override
  PlaybackCacheSnapshot? snapshotForTrack(String trackId) =>
      PlaybackCacheSnapshot(
        trackId: trackId,
        totalLength: snapshotTotal,
        segments: const <PlaybackCacheSegment>[],
      );
}
