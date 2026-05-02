import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readLocalFileBytes(String path) async {
  final normalized = path.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final file = File(normalized);
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}
