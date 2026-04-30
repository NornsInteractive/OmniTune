import 'dart:convert';
import 'dart:typed_data';

Future<String> saveStudioBackgroundImage(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
}) async {
  final resolvedMimeType = mimeType ?? _mimeTypeForFileName(fileName);
  return 'data:$resolvedMimeType;base64,${base64Encode(bytes)}';
}

Future<Uint8List?> readStudioBackgroundImage(String source) async {
  final commaIndex = source.indexOf(',');
  if (!source.startsWith('data:') || commaIndex < 0) {
    return null;
  }
  return base64Decode(source.substring(commaIndex + 1));
}

Future<void> deleteStudioBackgroundImage(String? source) async {}

String _mimeTypeForFileName(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
