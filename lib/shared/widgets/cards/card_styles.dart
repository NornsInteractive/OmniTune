/// UI 卡片设计系统 - 基于 example.html 风格
/// 包含所有卡片类型和样式规范
library card_styles;

import 'package:flutter/material.dart';

/// 卡片公共样式常数
class CardStyles {
  CardStyles._();

  // 边框
  static const double borderWidth = 0.5;
  static const double borderRadiusSmall = 8;
  static const double borderRadiusMedium = 10;
  static const double borderRadiusLarge = 12;
  static const double borderRadiusXL = 14;
  static const double borderRadiusFull = 9999;

  // 间距
  static const double gapSmall = 4;
  static const double gapMedium = 6;
  static const double gapBase = 8;
  static const double gapLarge = 10;
  static const double gapXL = 12;
  static const double gapXXL = 14;
  static const double gapXXXL = 16;

  // 内边距
  static const double paddingSmall = 4;
  static const double paddingBase = 8;
  static const double paddingMedium = 10;
  static const double paddingLarge = 12;
  static const double paddingXL = 14;
  static const double paddingXXL = 16;

  // 字体大小
  static const double fontSizeXS = 10;
  static const double fontSizeSmall = 11;
  static const double fontSizeBase = 12;
  static const double fontSizeMedium = 13;
  static const double fontSizeLarge = 14;
  static const double fontSizeXL = 15;
  static const double fontSizeXXL = 16;

  // 宽高尺寸
  static const double iconSizeSmall = 12;
  static const double iconSizeMedium = 14;
  static const double iconSizeLarge = 16;
  static const double iconSizeXL = 20;

  static const double avatarSizeSmall = 36;
  static const double avatarSizeMedium = 40;
  static const double avatarSizeLarge = 90;

  // 播放按钮大小
  static const double playButtonHeight = 36;
  static const double playButtonRadius = 18;

  // 响应式网格列数
  static const Map<String, int> gridColumns = {
    'mobile': 2,
    'tablet': 3,
    'desktop': 4,
  };

  // 间距配置
  static const double gridGap = 10;
  static const double contentPadding = 16;
  static const double sectionSpacing = 14;
}

/// 构建卡片边框
Border buildCardBorder(ColorScheme colorScheme) {
  return Border.all(
    color: colorScheme.outlineVariant,
    width: CardStyles.borderWidth,
  );
}

/// 构建卡片装饰
BoxDecoration buildCardDecoration(ColorScheme colorScheme, {double radius = CardStyles.borderRadiusLarge}) {
  return BoxDecoration(
    color: colorScheme.surface,
    border: buildCardBorder(colorScheme),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// 构建专辑缩略图（带边框）
class AlbumThumbnail extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;

  const AlbumThumbnail({
    Key? key,
    this.size = 90,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = CardStyles.borderWidth,
    this.borderRadius = CardStyles.borderRadiusXL,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.secondaryContainer,
        border: Border.all(
          color: borderColor ?? colorScheme.outlineVariant,
          width: borderWidth,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 构建小头像（带边框）
class SmallAvatar extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;

  const SmallAvatar({
    Key? key,
    this.size = CardStyles.avatarSizeSmall,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = CardStyles.borderWidth,
    this.borderRadius = CardStyles.borderRadiusSmall,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.secondaryContainer,
        border: Border.all(
          color: borderColor ?? colorScheme.outlineVariant,
          width: borderWidth,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 播放按钮
class PlayButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double height;
  final double width;

  const PlayButton({
    Key? key,
    this.onPressed,
    this.height = CardStyles.playButtonHeight,
    this.width = double.infinity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(CardStyles.playButtonRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow,
              size: CardStyles.iconSizeSmall,
              color: colorScheme.onPrimary,
            ),
            SizedBox(width: CardStyles.gapBase),
            Text(
              'Play',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆形按钮（收藏、更多等）
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? iconColor;

  const CircleIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.size = 36,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: CardStyles.borderWidth,
          ),
          color: colorScheme.surface,
        ),
        child: Center(
          child: Icon(
            icon,
            size: CardStyles.iconSizeMedium,
            color: iconColor ?? colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

// NOTE: FilterChip removed to avoid conflict with Material FilterChip.
// Use Material FilterChip directly for chip filtering UI.

/// 获取响应式网格列数
int getGridColumns(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) return CardStyles.gridColumns['mobile'] ?? 2;
  if (width < 900) return CardStyles.gridColumns['tablet'] ?? 3;
  return CardStyles.gridColumns['desktop'] ?? 4;
}
