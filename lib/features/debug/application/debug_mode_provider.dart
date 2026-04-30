import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/debug_logger.dart';

/// 调试模式状态 - 是否启用调试模式
final debugModeProvider = StateNotifierProvider<_DebugModeNotifier, bool>((ref) {
  return _DebugModeNotifier();
});

class _DebugModeNotifier extends StateNotifier<bool> {
  _DebugModeNotifier() : super(DebugLogger.isDebugEnabled);

  void setEnabled(bool enabled) {
    DebugLogger.setDebugEnabled(enabled);
    state = enabled;
  }
}
