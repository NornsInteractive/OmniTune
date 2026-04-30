import 'package:flutter/material.dart';

/// 自定义主题颜色配置
class CustomThemeColors {
  const CustomThemeColors({
    this.primaryColorSeed,
    this.borderRadius = 24.0,
    this.interfaceCompactness = 0.5,
  });

  /// 主题颜色种子（hex 颜色值，如 '#FF5722'）
  final String? primaryColorSeed;

  /// 边框圆角半径 (12.0 - 32.0)
  final double borderRadius;

  /// 界面紧凑度 (0.5 - 1.5)
  /// 0.5 = 非常紧凑
  /// 1.0 = 标准
  /// 1.5 = 宽松
  final double interfaceCompactness;

  CustomThemeColors copyWith({
    String? primaryColorSeed,
    double? borderRadius,
    double? interfaceCompactness,
  }) {
    return CustomThemeColors(
      primaryColorSeed: primaryColorSeed ?? this.primaryColorSeed,
      borderRadius: borderRadius ?? this.borderRadius,
      interfaceCompactness: interfaceCompactness ?? this.interfaceCompactness,
    );
  }

  /// 从存储的 Map 反序列化
  factory CustomThemeColors.fromJson(Map<String, dynamic> json) {
    return CustomThemeColors(
      primaryColorSeed: json['primaryColorSeed'] as String?,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 24.0,
      interfaceCompactness:
          (json['interfaceCompactness'] as num?)?.toDouble() ?? 0.5,
    );
  }

  /// 序列化为 Map
  Map<String, dynamic> toJson() {
    return {
      'primaryColorSeed': primaryColorSeed,
      'borderRadius': borderRadius,
      'interfaceCompactness': interfaceCompactness,
    };
  }

  /// 规范化hex颜色值格式，确保一致的格式存储
  static String? normalizeHexColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return null;
    }
    
    try {
      var cleanHex = hex.trim();
      if (cleanHex.startsWith('#')) {
        cleanHex = cleanHex.substring(1);
      }
      cleanHex = cleanHex.toUpperCase();
      
      // 验证格式
      if (!RegExp(r'^[0-9A-F]{6}([0-9A-F]{2})?$').hasMatch(cleanHex)) {
        return null;
      }
      
      // 只保留6位RGB格式（去掉alpha通道）
      if (cleanHex.length == 8) {
        cleanHex = cleanHex.substring(2);
      }
      
      return '#$cleanHex';
    } catch (e) {
      return null;
    }
  }

  /// 获取主题种子颜色
  Color? getSeedColor() {
    if (primaryColorSeed == null || primaryColorSeed!.isEmpty) {
      return null;
    }
    try {
      // 标准化hex值：去掉 # 前缀并转换为大写
      var hex = primaryColorSeed!.trim();
      if (hex.startsWith('#')) {
        hex = hex.substring(1);
      }
      hex = hex.toUpperCase();
      
      // 验证hex格式
      if (!RegExp(r'^[0-9A-F]{6}([0-9A-F]{2})?$').hasMatch(hex)) {
        return null;
      }
      
      // 解析hex值
      final value = int.parse(hex, radix: 16);
      
      // 如果只有6位（RGB），添加完全不透明的alpha
      if (hex.length == 6) {
        return Color((value & 0xFFFFFF) | 0xFF000000);
      }
      
      // 8位（ARGB），直接使用
      return Color(value);
    } catch (e) {
      return null;
    }
  }

  /// 验证边框半径值
  static double normalizeBorderRadius(double value) {
    return value.clamp(12.0, 32.0);
  }

  /// 验证紧凑度值
  static double normalizeCompactness(double value) {
    return value.clamp(0.5, 1.5);
  }
}
