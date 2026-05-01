import 'package:flutter/foundation.dart';

import 'debug_log_store.dart';

/// 全局调试记录器
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();

  factory DebugLogger() {
    return _instance;
  }

  DebugLogger._internal();

  /// 是否启用调试模式，默认关闭，按设置页手动开启
  static bool _debugEnabled = false;

  /// 设置调试模式开关
  static void setDebugEnabled(bool enabled) {
    _debugEnabled = enabled;
    if (enabled) {
      log('🔍 调试模式已启用');
    }
  }

  /// 是否启用调试模式
  static bool get isDebugEnabled => _debugEnabled;

  /// 记录信息
  static void info(String tag, String message) {
    if (_debugEnabled) {
      final text = 'ℹ️ [$tag] $message';
      debugPrint(text);
      DebugLogStore().addLog(text, 'info');
    }
  }

  /// 记录成功
  static void success(String tag, String message) {
    if (_debugEnabled) {
      final text = '✅ [$tag] $message';
      debugPrint(text);
      DebugLogStore().addLog(text, 'success');
    }
  }

  /// 记录警告
  static void warning(String tag, String message) {
    if (_debugEnabled) {
      final text = '⚠️ [$tag] $message';
      debugPrint(text);
      DebugLogStore().addLog(text, 'warning');
    }
  }

  /// 记录错误
  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (_debugEnabled) {
      var text = '❌ [$tag] $message';
      debugPrint(text);
      DebugLogStore().addLog(text, 'error');
      if (error != null) {
        final errText = '   错误详情: $error';
        debugPrint(errText);
        DebugLogStore().addLog(errText, 'error');
      }
      if (stackTrace != null) {
        final stackText = '   堆栈跟踪: $stackTrace';
        debugPrint(stackText);
        DebugLogStore().addLog(stackText, 'error');
      }
    }
  }

  /// 记录网络请求
  static void network(
    String tag,
    String method,
    String url, {
    int? statusCode,
    Object? response,
  }) {
    if (_debugEnabled) {
      var text = '🌐 [$tag] $method $url';
      debugPrint(text);
      DebugLogStore().addLog(text, 'network');
      if (statusCode != null) {
        final statusText = '   状态码: $statusCode';
        debugPrint(statusText);
        DebugLogStore().addLog(statusText, 'network');
      }
      if (response != null) {
        final respText = '   响应: $response';
        debugPrint(respText);
        DebugLogStore().addLog(respText, 'network');
      }
    }
  }

  /// 记录数据库操作
  static void database(String tag, String operation, String details) {
    if (_debugEnabled) {
      final text = '💾 [$tag] $operation - $details';
      debugPrint(text);
      DebugLogStore().addLog(text, 'database');
    }
  }

  /// 记录刮削操作
  static void scraping(String tag, String message) {
    if (_debugEnabled) {
      final text = '🎵 [$tag] $message';
      debugPrint(text);
      DebugLogStore().addLog(text, 'scraping');
    }
  }

  /// 记录性能数据
  static void performance(String tag, String operation, Duration duration) {
    if (_debugEnabled) {
      final text = '⏱️ [$tag] $operation 耗时: ${duration.inMilliseconds}ms';
      debugPrint(text);
      DebugLogStore().addLog(text, 'performance');
    }
  }

  /// 记录日志（通用）
  static void log(String message) {
    if (_debugEnabled) {
      final text = '📝 $message';
      debugPrint(text);
      DebugLogStore().addLog(text, 'info');
    }
  }

  /// 记录分隔线
  static void separator() {
    if (_debugEnabled) {
      debugPrint('─' * 80);
    }
  }
}
