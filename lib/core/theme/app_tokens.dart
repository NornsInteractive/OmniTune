import '../settings/app_settings.dart';

/// 应用所有 UI 尺寸、字号、圆角的集中定义
/// 禁止硬编码：所有地方都从这里取值
class AppTokens {
  // ── 间距：根据界面密度 ────────────────────────────────

  /// 页面 padding
  static double pagePadding(LayoutDensity density) => switch (density) {
    LayoutDensity.compact => 10.0,
    LayoutDensity.standard => 16.0,
    LayoutDensity.comfortable => 24.0,
  };

  /// 卡片之间的间距
  static double cardGap(LayoutDensity density) => switch (density) {
    LayoutDensity.compact => 6.0,
    LayoutDensity.standard => 10.0,
    LayoutDensity.comfortable => 16.0,
  };

  /// 卡片内部 padding
  static double cardPadding(LayoutDensity density) => switch (density) {
    LayoutDensity.compact => 8.0,
    LayoutDensity.standard => 12.0,
    LayoutDensity.comfortable => 18.0,
  };

  /// 列表行高度（如音轨行）
  static double trackRowHeight(LayoutDensity density) => switch (density) {
    LayoutDensity.compact => 44.0,
    LayoutDensity.standard => 54.0,
    LayoutDensity.comfortable => 64.0,
  };

  /// 专辑封面等图片尺寸
  static double artworkSize(LayoutDensity density) => switch (density) {
    LayoutDensity.compact => 32.0,
    LayoutDensity.standard => 40.0,
    LayoutDensity.comfortable => 52.0,
  };

  /// 现在播放栏高度
  static double nowBarHeight(LayoutDensity density) => switch (density) {
    LayoutDensity.compact => 56.0,
    LayoutDensity.standard => 64.0,
    LayoutDensity.comfortable => 76.0,
  };

  /// 按钮最小高度
  static double buttonHeight(LayoutDensity density) => switch (density) {
    LayoutDensity.compact => 36.0,
    LayoutDensity.standard => 40.0,
    LayoutDensity.comfortable => 48.0,
  };

  // ── 字体大小：根据字体缩放 ────────────────────────────

  /// 标题大（Display）：如页面标题
  static double fontDisplay(FontScale scale) => switch (scale) {
    FontScale.small => 18.0,
    FontScale.medium => 22.0,
    FontScale.large => 26.0,
    FontScale.extraLarge => 30.0,
  };

  /// 标题（Title）：如卡片标题
  static double fontTitle(FontScale scale) => switch (scale) {
    FontScale.small => 13.0,
    FontScale.medium => 15.0,
    FontScale.large => 17.0,
    FontScale.extraLarge => 20.0,
  };

  /// 正文（Body）：如描述文字
  static double fontBody(FontScale scale) => switch (scale) {
    FontScale.small => 11.0,
    FontScale.medium => 13.0,
    FontScale.large => 15.0,
    FontScale.extraLarge => 17.0,
  };

  /// 标签（Label）：如时间、数字
  static double fontLabel(FontScale scale) => switch (scale) {
    FontScale.small => 10.0,
    FontScale.medium => 11.0,
    FontScale.large => 13.0,
    FontScale.extraLarge => 15.0,
  };

  // ── 圆角：固定，不随密度变化 ────────────────────────────

  /// 主卡片圆角
  static const double radiusCard = 16.0;

  /// 卡片内部元素圆角
  static const double radiusInner = 10.0;

  /// 按钮圆角（通常用 Pill 风格）
  static const double radiusButton = 20.0;

  /// 小元素圆角（如图片、小按钮）
  static const double radiusSmall = 8.0;

  // ── 其他固定值 ──────────────────────────────────────

  /// 分割线厚度（代替阴影）
  static const double dividerThickness = 0.5;

  /// 边框宽度
  static const double borderWidth = 1.0;

  /// Icon 大小（标准）
  static const double iconMedium = 24.0;

  /// Icon 大小（小）
  static const double iconSmall = 18.0;

  /// Icon 大小（大）
  static const double iconLarge = 32.0;

  // ── 响应式断点 ──────────────────────────────────────

  /// 小屏/大屏的切换点（像素）
  /// 小于此值使用底部导航栏，大于此值使用侧栏
  static const double breakpointSmallScreen = 720.0;
}
