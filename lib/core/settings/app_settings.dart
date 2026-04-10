import 'package:flutter/material.dart';

/// 界面密度枚举
enum LayoutDensity {
  compact, // 紧凑：较小间距
  standard, // 标准：中等间距（推荐）
  comfortable, // 宽松：较大间距
}

/// 字体缩放枚举
enum FontScale {
  small, // 小
  medium, // 标准（推荐）
  large, // 大
  extraLarge, // 超大
}

/// 应用全局设置
class AppSettings {
  /// 界面密度
  final LayoutDensity density;

  /// 字体大小缩放
  final FontScale fontScale;

  /// 主题种子色（用于生成 ColorScheme）
  final Color seedColor;

  /// 是否深色模式
  final bool isDarkMode;

  const AppSettings({
    this.density = LayoutDensity.standard,
    this.fontScale = FontScale.medium,
    this.seedColor = const Color(0xFF6750A4), // Material 3 默认紫色
    this.isDarkMode = false,
  });

  /// 复制并修改
  AppSettings copyWith({LayoutDensity? density, FontScale? fontScale, Color? seedColor, bool? isDarkMode}) =>
      AppSettings(
        density: density ?? this.density,
        fontScale: fontScale ?? this.fontScale,
        seedColor: seedColor ?? this.seedColor,
        isDarkMode: isDarkMode ?? this.isDarkMode,
      );

  /// 转换为 JSON（用于持久化）
  Map<String, dynamic> toJson() => {
    'density': density.index,
    'fontScale': fontScale.index,
    'seedColor': seedColor.toARGB32(),
    'isDarkMode': isDarkMode,
  };

  /// 从 JSON 恢复
  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    density: LayoutDensity.values[json['density'] as int? ?? 1],
    fontScale: FontScale.values[json['fontScale'] as int? ?? 1],
    seedColor: Color(json['seedColor'] as int? ?? 0xFF6750A4),
    isDarkMode: json['isDarkMode'] as bool? ?? false,
  );
}
