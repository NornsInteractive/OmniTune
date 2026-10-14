import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:music/core/audio/system_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final supportDirectory = Directory.systemTemp.createTempSync(
    'omnitune_system_artwork_test_',
  );
  final channel = const MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return supportDirectory.path;
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('resolveSystemArtwork returns file uri for usable local path', () async {
    final asset = await rootBundle.load('assets/images/default_cover.png');
    final bytes = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    final file = File('${supportDirectory.path}/cover.png');
    await file.writeAsBytes(bytes);

    final uri = await resolveSystemArtwork(localPath: file.path);
    expect(uri, isNotNull);
    expect(uri!.scheme, 'file');
    expect(Uri.decodeFull(uri.path), file.path);
  });

  test(
    'resolveSystemArtwork returns null when no local or remote artwork',
    () async {
      final uri = await resolveSystemArtwork();
      expect(uri, isNull);
    },
  );

  test('resolveSystemArtwork ignores non-http remote urls', () async {
    final uri = await resolveSystemArtwork(
      remoteUrl: 'ftp://example.com/cover.png',
    );
    expect(uri, isNull);
  });

  test('defaultSystemArtwork uses bundled asset when available', () async {
    final uri = await defaultSystemArtwork();
    expect(uri, isNotNull);
    expect(uri!.scheme, 'file');
    final file = File(uri.toFilePath());
    expect(await file.exists(), isTrue);
    final fileBytes = await file.readAsBytes();
    expect(fileBytes.take(8).toList(), const <int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
  });
}
