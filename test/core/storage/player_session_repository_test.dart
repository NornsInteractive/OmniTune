import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:music/core/models/library_song.dart';
import 'package:music/core/storage/player_session_repository.dart';

class _BackgroundSerializedSong extends LibrarySong {
  _BackgroundSerializedSong(String id, this.origin)
    : super(
        id: id,
        sourceId: 'source',
        sourceName: 'Source',
        title: 'Title',
        fileName: '$id.flac',
        remotePath: '/Music/$id.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/Music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
        manuallyScrapedTitle: 'Manual title',
        autoScrapedLyrics: '[00:01.00]Lyrics',
      );

  final Isolate origin;

  @override
  Map<String, dynamic> toJson() {
    if (Isolate.current == origin) {
      throw StateError('Song serialization blocked the calling isolate');
    }
    return super.toJson();
  }
}

class _CrashingSong extends LibrarySong {
  _CrashingSong()
    : super(
        id: 'crash',
        sourceId: 'source',
        sourceName: 'Source',
        title: 'Title',
        fileName: 'crash.flac',
        remotePath: '/Music/crash.flac',
        albumTitle: 'Album',
        artistName: 'Artist',
        directoryPath: '/Music',
        folderAlbumTitle: 'Album',
        folderArtistName: 'Artist',
      );

  @override
  Map<String, dynamic> toJson() {
    throw StateError('Serialization failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('player session overwrite', () async {
    final repo = SharedPreferencesPlayerSessionRepository();

    final songs = <LibrarySong>[
      _BackgroundSerializedSong('other', Isolate.current),
      _BackgroundSerializedSong('track', Isolate.current),
    ];

    final snapshot = PlayerSessionSnapshot(
      playlist: songs,
      currentIndex: 1,
      playbackMode: 'shuffle',
      position: const Duration(milliseconds: 1234),
    );

    await repo.save(snapshot);
    final loaded = await repo.load();

    expect(loaded, isNotNull);
    expect(loaded!.playlist, hasLength(2));
    expect(loaded.playlist[0].displayTitle, 'Manual title');
    expect(loaded.playlist[0].autoScrapedLyrics, '[00:01.00]Lyrics');
    expect(loaded.playlist[1].id, 'track');
    expect(loaded.currentIndex, 1);
    expect(loaded.playbackMode, 'shuffle');
    expect(loaded.position, const Duration(milliseconds: 1234));
  });

  test(
    'bulk save round trips 10000 songs with metadata, index, mode, position',
    () async {
      final repo = SharedPreferencesPlayerSessionRepository();

      final songs = List.generate(
        10000,
        (index) => _BackgroundSerializedSong('track-$index', Isolate.current),
      );

      final snapshot = PlayerSessionSnapshot(
        playlist: songs,
        currentIndex: 5000,
        playbackMode: 'repeat_one',
        position: const Duration(minutes: 3, seconds: 45),
      );

      await repo.save(snapshot);
      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded!.playlist, hasLength(10000));
      expect(loaded.playlist.last.id, 'track-9999');
      expect(loaded.playlist.last.displayTitle, 'Manual title');
      expect(loaded.playlist[5000].id, 'track-5000');
      expect(loaded.currentIndex, 5000);
      expect(loaded.playbackMode, 'repeat_one');
      expect(loaded.position, const Duration(minutes: 3, seconds: 45));
    },
  );

  test('concurrent saves enqueue FIFO and clear ordered', () async {
    final repo = SharedPreferencesPlayerSessionRepository();

    final heavySongs = List.generate(
      10000,
      (index) => _BackgroundSerializedSong('heavy-$index', Isolate.current),
    );
    final heavySave = repo.save(
      PlayerSessionSnapshot(
        playlist: heavySongs,
        currentIndex: 5000,
        playbackMode: 'repeat_one',
        position: const Duration(minutes: 5),
      ),
    );

    final lightSave = repo.save(
      PlayerSessionSnapshot(
        playlist: [_BackgroundSerializedSong('last', Isolate.current)],
        currentIndex: 0,
        playbackMode: 'shuffle',
        position: const Duration(seconds: 42),
      ),
    );

    await Future.wait([heavySave, lightSave]);
    final loaded = await repo.load();
    expect(loaded, isNotNull);
    expect(loaded!.currentIndex, 0);
    expect(loaded.playbackMode, 'shuffle');
    expect(loaded.position, const Duration(seconds: 42));
    expect(loaded.playlist.single.id, 'last');

    final heavySave2 = repo.save(
      PlayerSessionSnapshot(
        playlist: heavySongs,
        currentIndex: 100,
        playbackMode: 'list',
        position: const Duration(minutes: 1),
      ),
    );
    await repo.clear();
    await heavySave2;
    final afterClear = await repo.load();
    expect(afterClear, isNull);
  });

  test(
    'serialization exception surfaced but following valid save works',
    () async {
      final repo = SharedPreferencesPlayerSessionRepository();

      final badSnapshot = PlayerSessionSnapshot(
        playlist: [_CrashingSong()],
        currentIndex: 0,
        playbackMode: 'list',
        position: Duration.zero,
      );

      await expectLater(repo.save(badSnapshot), throwsA(isA<StateError>()));

      final goodSnapshot = PlayerSessionSnapshot(
        playlist: [_BackgroundSerializedSong('ok', Isolate.current)],
        currentIndex: 0,
        playbackMode: 'list',
        position: Duration.zero,
      );

      await repo.save(goodSnapshot);
      final loaded = await repo.load();

      expect(loaded, isNotNull);
      expect(loaded!.playlist.single.id, 'ok');
    },
  );

  test(
    'corrupt or legacy player_session_v1 JSON clears and returns null',
    () async {
      SharedPreferences.setMockInitialValues({
        'player_session_v1': 'not-valid-json{{{',
      });

      final repo = SharedPreferencesPlayerSessionRepository();
      final loaded = await repo.load();

      expect(loaded, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('player_session_v1'), isFalse);
    },
  );

  test('valid legacy v1 JSON loads correctly', () async {
    final validJson = '''
    {
      "playlist": [
        {
          "id": "legacy-1",
          "sourceId": "source",
          "sourceName": "Source",
          "title": "Legacy Song",
          "fileName": "legacy.flac",
          "remotePath": "/Music/legacy.flac",
          "albumTitle": "Album",
          "artistName": "Artist",
          "directoryPath": "/Music",
          "folderAlbumTitle": "Album",
          "folderArtistName": "Artist",
          "mimeType": "audio/flac",
          "size": 12345,
          "modifiedAt": "2024-01-01T00:00:00.000Z"
        }
      ],
      "currentIndex": 0,
      "playbackMode": "list",
      "positionMs": 5000
    }
    ''';

    SharedPreferences.setMockInitialValues({'player_session_v1': validJson});

    final repo = SharedPreferencesPlayerSessionRepository();
    final loaded = await repo.load();

    expect(loaded, isNotNull);
    expect(loaded!.playlist.single.id, 'legacy-1');
    expect(loaded.currentIndex, 0);
    expect(loaded.playbackMode, 'list');
    expect(loaded.position, const Duration(milliseconds: 5000));
  });
}
