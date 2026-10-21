import 'dart:ffi';

String updateArchitecture(String platform) {
  final abi = Abi.current().toString();
  if (abi.contains('arm64')) {
    return platform == 'macos' ? 'apple-silicon' : 'arm64-v8a';
  }
  if (abi.contains('x64')) return 'x86_64';
  if (abi.contains('ia32')) return 'x86';
  if (abi.contains('arm')) return 'armeabi-v7a';
  return 'universal';
}
