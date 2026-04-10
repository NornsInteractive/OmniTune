import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_settings.dart';
import 'settings_provider.dart';

/// 扩展 SettingsProvider 的导出文件，确保所有需要的 API 都可用
export 'app_settings.dart';
export 'settings_provider.dart';

/// 获取当前设置的便利方法
AppSettings getSettings(WidgetRef ref) {
  return ref.watch(appSettingsProvider);
}

/// 获取设置控制器的便利方法
AppSettingsNotifier getSettingsNotifier(WidgetRef ref) {
  return ref.read(appSettingsProvider.notifier);
}
