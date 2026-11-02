import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/models/remote_entry.dart';
import 'package:music/core/models/source_profile.dart';
import 'package:music/core/models/source_protocol.dart';
import 'package:music/core/utils/path_nesting_validator.dart';
import 'package:music/features/sources/data/local/local_music_source.dart';

void main() {
  group('PathNestingValidator', () {
    test('normalizes paths consistently', () {
      expect(PathNestingValidator.normalize(r'C:\Music\Rock\'), 'C:/Music/Rock');
      expect(PathNestingValidator.normalize('/storage/emulated/0/Music///'), '/storage/emulated/0/Music');
      expect(PathNestingValidator.normalize('/'), '/');
      expect(PathNestingValidator.normalize('  '), '');
    });

    test('detects identical and nested parent/child paths', () {
      expect(
        PathNestingValidator.areNested('/storage/emulated/0/Music', '/storage/emulated/0/Music'),
        isTrue,
      );
      expect(
        PathNestingValidator.areNested('/storage/emulated/0/Music', '/storage/emulated/0/Music/Rock'),
        isTrue,
      );
      expect(
        PathNestingValidator.areNested('/storage/emulated/0/Music/Rock', '/storage/emulated/0/Music'),
        isTrue,
      );
    });

    test('does not report false positives on sibling or partial name overlap', () {
      // Sibling directories
      expect(
        PathNestingValidator.areNested('/storage/emulated/0/Music/Rock', '/storage/emulated/0/Music/Jazz'),
        isFalse,
      );
      // Partial folder name overlap ('Rock' vs 'Rockstar')
      expect(
        PathNestingValidator.areNested('/storage/emulated/0/Music/Rock', '/storage/emulated/0/Music/Rockstar'),
        isFalse,
      );
    });

    test('findConflict returns the conflicting directory or null', () {
      final existing = [
        '/storage/emulated/0/Music/Classical',
        '/storage/emulated/0/Downloads',
      ];

      // Child of existing
      expect(
        PathNestingValidator.findConflict('/storage/emulated/0/Music/Classical/Beethoven', existing),
        '/storage/emulated/0/Music/Classical',
      );

      // Parent of existing
      expect(
        PathNestingValidator.findConflict('/storage/emulated/0/Music', existing),
        '/storage/emulated/0/Music/Classical',
      );

      // Independent path
      expect(
        PathNestingValidator.findConflict('/storage/emulated/0/Music/Pop', existing),
        isNull,
      );
    });
  });

  group('LocalMusicSource', () {
    late Directory tempDir;
    late Directory subDirA;
    late Directory subDirB;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('omnitune_local_test_');
      subDirA = Directory('${tempDir.path}/AlbumA')..createSync();
      subDirB = Directory('${tempDir.path}/AlbumB')..createSync();

      File('${subDirA.path}/song1.mp3').writeAsStringSync('dummy audio content');
      File('${subDirA.path}/song2.flac').writeAsStringSync('dummy audio content');
      File('${subDirA.path}/notes.txt').writeAsStringSync('text file');
      File('${subDirB.path}/song3.wav').writeAsStringSync('dummy audio content');
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('listFiles returns audio files and subdirectories correctly', () async {
      final profile = SourceProfile(
        id: 'local_test',
        name: 'Local Test',
        protocol: SourceProtocol.local,
        baseUrl: 'file://',
        username: '',
        password: '',
        rootPath: tempDir.path,
        scanDirectories: [tempDir.path],
      );

      final source = LocalMusicSource(profile);
      await source.connect();

      final listing = await source.listFiles(tempDir.path);
      final directories = listing.entries.where((e) => e.isDirectory).toList();
      expect(directories.length, 2);

      final subListingA = await source.listFiles(subDirA.path);
      final audioFiles = subListingA.entries.where((e) => e.isPlayable).toList();
      expect(audioFiles.length, 2);
      expect(audioFiles.map((e) => e.name), containsAll(['song1.mp3', 'song2.flac']));

      // Build playable track
      final track = await source.buildPlayableTrack(audioFiles.first);
      expect(track.sourceId, 'local_test');
      expect(track.remotePath, audioFiles.first.path);
      expect(track.audioSource, isNotNull);
    });

    test('virtual root is returned when multiple scan directories configured', () async {
      final profile = SourceProfile(
        id: 'local_multi',
        name: 'Local Multi',
        protocol: SourceProtocol.local,
        baseUrl: 'file://',
        username: '',
        password: '',
        rootPath: subDirA.path,
        scanDirectories: [subDirA.path, subDirB.path],
      );

      final source = LocalMusicSource(profile);
      final rootListing = await source.listFiles('/');
      expect(rootListing.entries.length, 2);
      expect(rootListing.entries.every((e) => e.kind == RemoteEntryKind.directory), isTrue);
    });
  });
}
