import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/audio/system_audio_handler.dart';
import 'core/database/isar_manager.dart';
import 'core/utils/debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeSystemAudioHandler();
  } catch (error) {
    // A missing desktop media bus must not prevent ordinary playback.
    DebugLogger.warning(
      'SystemAudio',
      'Media integration unavailable: ${error.runtimeType}',
    );
  }

  // 初始化 Isar 数据库
  await IsarManager.initialize();

  runApp(const ProviderScope(child: MusicApp()));
}
