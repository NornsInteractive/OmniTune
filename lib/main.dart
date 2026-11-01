import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/audio/system_audio_handler.dart';
import 'core/database/isar_manager.dart';
import 'core/utils/debug_logger.dart';
import 'core/widgets/widget_sync_service.dart';

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

  // 初始化跨平台小组件同步服务
  await WidgetSyncService.instance.initialize();

  runApp(const ProviderScope(child: MusicApp()));
}
