import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/audio/system_audio_handler.dart';
import 'core/database/isar_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_shouldInitBackgroundAudio()) {
    await initializeSystemAudioHandler();
  }

  // 初始化 Isar 数据库
  await IsarManager.initialize();

  runApp(const ProviderScope(child: MusicApp()));
}

bool _shouldInitBackgroundAudio() {
  if (kIsWeb) {
    return false;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}
