import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';
import 'package:music/features/sources/data/cloud189/cloud189_music_source.dart';

class _FakeCloud189RemoteClient implements Cloud189RemoteClient {
  static const _nextRefreshToken = 'rotated-refresh-token';

  var connectCount = 0;
  var readTextCount = 0;
  String? openedPath;
  int? openedStart;
  int? openedEnd;

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
      contentType: 'audio/flac',
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
    final source = Cloud189MusicSource(profile, clientFactory: (_) => client);

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
    final source = Cloud189MusicSource(profile, clientFactory: (_) => client);

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
    final source = Cloud189MusicSource(profile, clientFactory: (_) => client);

    final first = await source.readTextFile('/Music/song.lrc');
    final second = await source.readTextFile('/Music/song.lrc');

    expect(first, '[00:00.00]Hello from 189 Cloud');
    expect(second, first);
    expect(client.connectCount, 1);
    expect(client.readTextCount, 1);
  });
}
