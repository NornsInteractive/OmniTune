import 'package:flutter/material.dart';

/// 自定义主题颜色配置
class CustomThemeColors {
  const CustomThemeColors({this.primaryColorSeed, this.borderRadius = 24.0, this.interfaceCompactness = 1.0});

  /// 主题颜色种子（hex 颜色值，如 '#FF5722'）
  final String? primaryColorSeed;

  /// 边框圆角半径 (12.0 - 32.0)
  final double borderRadius;

  /// 界面紧凑度 (0.5 - 1.5)
  /// 0.5 = 非常紧凑
  /// 1.0 = 标准
  /// 1.5 = 宽松
  final double interfaceCompactness;

  CustomThemeColors copyWith({String? primaryColorSeed, double? borderRadius, double? interfaceCompactness}) {
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
      interfaceCompactness: (json['interfaceCompactness'] as num?)?.toDouble() ?? 1.0,
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

  /// 获取主题种子颜色
  Color? getSeedColor() {
    if (primaryColorSeed == null || primaryColorSeed!.isEmpty) {
      return null;
    }
    try {
      // 支持 #RRGGBB 和 #AARRGGBB 格式
      final hex = primaryColorSeed!.replaceFirst('#', '');
      final value = int.parse(hex, radix: 16);
      if (hex.length == 6) {
        return Color(value | 0xFF000000);
      }
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
