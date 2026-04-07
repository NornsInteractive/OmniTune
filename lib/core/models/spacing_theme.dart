//! SpacingTheme - 响应式间距主题
//!
//! 根据 interfaceCompactness 参数动态生成间距值
//! 支持响应式设计，在不同紧凑度下显示不同的间距
//!
//! 范围: 0.5 (最紧凑) ~ 1.5 (最宽松)
//! 基础单位: 8px

class SpacingTheme {
  /// 基础间距单位 (通常 8px)
  final double baseUnit;

  /// 缩放因子 (interfaceCompactness: 0.5-1.5)
  final double scaleFactor;

  SpacingTheme({this.baseUnit = 8, required this.scaleFactor})
    : assert(scaleFactor >= 0.5 && scaleFactor <= 1.5, 'scaleFactor must be between 0.5 and 1.5');

  /// 极小间距: 4px ~ 6px
  double get xs => baseUnit * 0.5 * scaleFactor;

  /// 小间距: 8px ~ 12px
  double get sm => baseUnit * 1.0 * scaleFactor;

  /// 中间距: 16px ~ 24px
  double get md => baseUnit * 2.0 * scaleFactor;

  /// 大间距: 24px ~ 36px
  double get lg => baseUnit * 3.0 * scaleFactor;

  /// 超大间距: 32px ~ 48px
  double get xl => baseUnit * 4.0 * scaleFactor;

  /// 巨大间距: 48px ~ 72px
  double get xxl => baseUnit * 6.0 * scaleFactor;

  /// 获取自定义间距
  ///
  /// 参数: multiplier - 相对于基础单位的倍数
  ///
  /// 示例:
  /// ```dart
  /// final custom = spacing.custom(2.5); // 20px ~ 30px
  /// ```
  double custom(double multiplier) {
    return baseUnit * multiplier * scaleFactor;
  }

  @override
  String toString() =>
      '''SpacingTheme(
  baseUnit: $baseUnit,
  scaleFactor: $scaleFactor,
  xs: $xs,
  sm: $sm,
  md: $md,
  lg: $lg,
  xl: $xl,
  xxl: $xxl,
)''';
}
