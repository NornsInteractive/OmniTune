import 'package:flutter/foundation.dart';

/// 日志条目
class DebugLogEntry {
  final String timestamp;
  final String message;
  final String level; // 'info', 'success', 'warning', 'error', 'network', 'database', 'scraping', 'performance'

  DebugLogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
  });

  String get formattedMessage => '[$timestamp] $message';
}

/// 日志存储 - 存储最后1000条日志
class DebugLogStore extends ChangeNotifier {
  static final DebugLogStore _instance = DebugLogStore._internal();

  factory DebugLogStore() {
    return _instance;
  }

  DebugLogStore._internal();

  final List<DebugLogEntry> _logs = [];
  static const int _maxLogs = 1000;

  /// 获取所有日志
  List<DebugLogEntry> get logs => List.unmodifiable(_logs);

  /// 添加日志条目
  void addLog(String message, String level) {
    final now = DateTime.now();
    final timestamp = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    final entry = DebugLogEntry(
      timestamp: timestamp,
      message: message,
      level: level,
    );

    // 在顶部插入新日志
    _logs.insert(0, entry);

    // 保持日志数量在限制内
    if (_logs.length > _maxLogs) {
      _logs.removeAt(_logs.length - 1);
    }

    notifyListeners();
  }

  /// 清空所有日志
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// 获取最后N条日志
  List<DebugLogEntry> getLastLogs(int count) {
    final start = (_logs.length - count).clamp(0, _logs.length);
    return _logs.sublist(start);
  }

  /// 根据关键字搜索日志
  List<DebugLogEntry> search(String keyword) {
    return _logs
        .where((entry) =>
            entry.message.toLowerCase().contains(keyword.toLowerCase()) ||
            entry.level.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
  }

  /// 导出日志为字符串
  String exportAsText() {
    return _logs.map((e) => '${e.formattedMessage} [${e.level.toUpperCase()}]').join('\n');
  }
}
