import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> saveStudioBackgroundImage(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
}) async {
  final directory = await getApplicationSupportDirectory();
  final backgroundDirectory = Directory(p.join(directory.path, 'backgrounds'));
  if (!await backgroundDirectory.exists()) {
    await backgroundDirectory.create(recursive: true);
  }

  final extension = _safeImageExtension(fileName, mimeType);
  final file = File(
    p.join(
      backgroundDirectory.path,
      'studio_background_${DateTime.now().microsecondsSinceEpoch}$extension',
    ),
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Uint8List?> readStudioBackgroundImage(String source) async {
  final file = File(source);
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}

Future<void> deleteStudioBackgroundImage(String? source) async {
  if (source == null || source.isEmpty || source.startsWith('data:')) {
    return;
  }
  final file = File(source);
  if (await file.exists()) {
    await file.delete();
  }
}

String _safeImageExtension(String fileName, String? mimeType) {
  final extension = p.extension(fileName).toLowerCase();
  if (extension == '.jpg' ||
      extension == '.jpeg' ||
      extension == '.png' ||
      extension == '.webp') {
    return extension;
  }
  return switch (mimeType) {
    'image/png' => '.png',
    'image/webp' => '.webp',
    _ => '.jpg',
  };
}
