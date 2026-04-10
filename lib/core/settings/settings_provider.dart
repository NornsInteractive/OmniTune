import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'app_settings.dart';

// 存储键常量
const String _keySettings = 'app_settings_v1';

/// Riverpod Provider: 全局设置
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) => AppSettingsNotifier());

/// 设置管理器
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _init();
  }

  /// 初始化：从本地存储恢复设置
  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keySettings);
      if (jsonStr != null) {
        final json = Map<String, dynamic>.from(
          // 简单的 JSON 解析（如果需要复杂解析，可用 jsonDecode）
          _parseJson(jsonStr),
        );
        state = AppSettings.fromJson(json);
      }
    } catch (e) {
      // 失败时使用默认设置
    }
  }

  /// 保存到本地存储
  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = state.toJson();
      // 简单的 JSON 序列化
      final jsonStr = _stringifyJson(json);
      await prefs.setString(_keySettings, jsonStr);
    } catch (e) {
      // 保存失败时忽略
    }
  }

  /// 设置界面密度
  Future<void> setDensity(LayoutDensity density) async {
    state = state.copyWith(density: density);
    await _save();
  }

  /// 设置字体缩放
  Future<void> setFontScale(FontScale fontScale) async {
    state = state.copyWith(fontScale: fontScale);
    await _save();
  }

  /// 设置主题色
  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColor: color);
    await _save();
  }

  /// 设置深色模式
  Future<void> setDarkMode(bool isDarkMode) async {
    state = state.copyWith(isDarkMode: isDarkMode);
    await _save();
  }

  /// 恢复默认设置
  Future<void> resetToDefaults() async {
    state = const AppSettings();
    await _save();
  }

  // ── JSON 序列化辅助（简单实现）────────────

  /// 简单的 JSON 对象转字符串
  static String _stringifyJson(Map<String, dynamic> json) {
    final pairs = <String>[];
    json.forEach((key, value) {
      final valueStr = _encodeJsonValue(value);
      pairs.add('"$key":$valueStr');
    });
    return '{${pairs.join(',')}}';
  }

  /// 简单的 JSON 字符串转对象
  static Map<String, dynamic> _parseJson(String jsonStr) {
    final result = <String, dynamic>{};
    final cleaned = jsonStr.replaceAll('{', '').replaceAll('}', '').trim();
    final pairs = cleaned.split(',');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0].replaceAll('"', '').trim();
        final value = parts[1].trim();
        result[key] = _decodeJsonValue(value);
      }
    }
    return result;
  }

  /// 编码 JSON 值
  static String _encodeJsonValue(dynamic value) {
    if (value is String) return '"$value"';
    if (value is bool) return value ? 'true' : 'false';
    if (value is int) return value.toString();
    return 'null';
  }

  /// 解码 JSON 值
  static dynamic _decodeJsonValue(String value) {
    if (value == 'true') return true;
    if (value == 'false') return false;
    if (value.startsWith('"')) return value.replaceAll('"', '');
    try {
      return int.parse(value);
    } catch (e) {
      return value;
    }
  }
}
