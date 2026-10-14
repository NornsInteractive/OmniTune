import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release wrapper keeps Tianyi enabled and forwards build arguments',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'omnitune-build-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final scripts = await Directory('${directory.path}/scripts').create();
      final wrapper = await File(
        'scripts/build_release_apk.sh',
      ).copy('${scripts.path}/build_release_apk.sh');
      final builder = File('${scripts.path}/build_apk.sh');
      await builder.writeAsString(r'''#!/usr/bin/env bash
printf '%s\n' "$@"
''');
      await Process.run('chmod', ['+x', builder.path]);
      final result = await Process.run('bash', [
        wrapper.path,
        '--target-platform=android-arm64',
        '--dart-define=EXAMPLE=value with spaces',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout.toString().trim().split('\n'), [
        '--target-platform=android-arm64',
        '--dart-define=EXAMPLE=value with spaces',
      ]);
    },
  );

  test('signing secret generation works with strict pipefail', () async {
    final script = await File('scripts/build_apk.sh').readAsString();
    final function = RegExp(
      r'random_secret\(\) \{[\s\S]*?^\}',
      multiLine: true,
    ).firstMatch(script)!.group(0)!;
    final result = await Process.run('bash', [
      '-c',
      'set -euo pipefail\n$function\nrandom_secret',
    ]);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout.toString().trim(), matches(r'^[a-zA-Z0-9]{32}$'));
  });

  test(
    'Android release keep.xml references every declared system action icon',
    () async {
      const iconNames = <String>[
        'ic_notification',
        'ic_favorite',
        'ic_favorite_border',
        'ic_playback_mode',
      ];
      for (final iconName in iconNames) {
        final file = File('android/app/src/main/res/drawable/$iconName.xml');
        expect(await file.exists(), isTrue, reason: '$iconName is missing');
      }

      final keepXml = await File(
        'android/app/src/main/res/raw/keep.xml',
      ).readAsString();
      for (final iconName in iconNames) {
        expect(keepXml, contains('@drawable/$iconName'));
      }
    },
  );
}
