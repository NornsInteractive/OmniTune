import 'package:flutter/material.dart';
import 'card_styles.dart';

/// 现代化相册卡片（竖排）- 包含专辑封面、标题、艺术家
/// 响应式：Mobile 2列, Tablet 3列, Desktop 4列
class ModernAlbumCard extends StatelessWidget {
  final String title;
  final String artist;
  final VoidCallback? onTap;
  final Widget? coverImage;

  const ModernAlbumCard({
    Key? key,
    required this.title,
    required this.artist,
    this.onTap,
    this.coverImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: buildCardDecoration(colorScheme, radius: CardStyles.borderRadiusLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 专辑封面
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(CardStyles.borderRadiusLarge),
                topRight: Radius.circular(CardStyles.borderRadiusLarge),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: coverImage ??
                    Container(
                      color: colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.album,
                        size: 48,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
              ),
            ),
            // 文本信息
            Padding(
              padding: const EdgeInsets.all(CardStyles.paddingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: CardStyles.gapSmall),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 快捷访问卡片（横排）- 包含小图标和标题
/// 用于"我的最爱"、"最近播放"等
class QuickAccessCard extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Widget? thumbnail;
  final IconData? icon;

  const QuickAccessCard({
    Key? key,
    required this.title,
    this.onTap,
    this.thumbnail,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: buildCardDecoration(colorScheme, radius: CardStyles.borderRadiusLarge),
        padding: const EdgeInsets.all(CardStyles.paddingLarge),
        child: Row(
          children: [
            // 小头像
            thumbnail ??
                SmallAvatar(
                  size: CardStyles.avatarSizeSmall,
                  backgroundColor: colorScheme.secondaryContainer,
                  borderColor: colorScheme.outlineVariant,
                  borderRadius: CardStyles.borderRadiusSmall,
                ),
            SizedBox(width: CardStyles.gapLarge),
            // 标题
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 列表项卡片（播放列表、曲目等）
/// 包含图标/数字、标题、副标题、右侧箭头
class ListItemCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool showArrow;

  const ListItemCard({
    Key? key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.showArrow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: buildCardDecoration(colorScheme, radius: CardStyles.borderRadiusLarge),
        padding: const EdgeInsets.all(CardStyles.paddingBase),
        child: Row(
          children: [
            // 左侧图标/头像
            leading ??
                SmallAvatar(
                  size: CardStyles.avatarSizeMedium,
                  borderRadius: CardStyles.borderRadiusSmall,
                ),
            SizedBox(width: CardStyles.gapLarge),
            // 中间文本
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: CardStyles.gapSmall),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 右侧尾部
            if (trailing != null || showArrow) ...[
              SizedBox(width: CardStyles.gapLarge),
              if (trailing != null)
                Text(
                  trailing!,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              if (showArrow)
                Padding(
                  padding: const EdgeInsets.only(left: CardStyles.gapBase),
                  child: Icon(
                    Icons.chevron_right,
                    size: CardStyles.iconSizeMedium,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 类别卡片（流派、电台等）
/// 大文本标题 + 副标题（数量）
class CategoryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const CategoryCard({
    Key? key,
    required this.title,
    this.subtitle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: buildCardDecoration(colorScheme, radius: CardStyles.borderRadiusLarge),
        padding: const EdgeInsets.symmetric(
          horizontal: CardStyles.paddingXL,
          vertical: CardStyles.paddingXL,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: CardStyles.gapSmall),
              Text(
                subtitle!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 曲目行卡片（在专辑/播放列表中使用）
class TrackRowCard extends StatelessWidget {
  final int trackNumber;
  final String title;
  final String? artist;
  final String? duration;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  const TrackRowCard({
    Key? key,
    required this.trackNumber,
    required this.title,
    this.artist,
    this.duration,
    this.isPlaying = false,
    this.onTap,
    this.onMoreTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isPlaying
              ? colorScheme.secondaryContainer
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(CardStyles.borderRadiusMedium),
        ),
        padding: const EdgeInsets.all(CardStyles.paddingBase),
        child: Row(
          children: [
            // 曲目号或播放图标
            SizedBox(
              width: 16,
              child: isPlaying
                  ? Icon(
                      Icons.play_arrow,
                      size: CardStyles.iconSizeSmall,
                      color: colorScheme.onSecondaryContainer,
                    )
                  : Center(
                      child: Text(
                        trackNumber.toString(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
            ),
            SizedBox(width: CardStyles.gapLarge),
            // 标题和艺术家
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (artist != null) ...[
                    SizedBox(height: CardStyles.gapSmall),
                    Text(
                      artist!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: CardStyles.fontSizeXS,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 时长
            if (duration != null) ...[
              SizedBox(width: CardStyles.gapLarge),
              Text(
                duration!,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                  fontSize: CardStyles.fontSizeXS,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
