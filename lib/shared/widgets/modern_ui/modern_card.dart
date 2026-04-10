import 'package:flutter/material.dart';

/// 现代卡片组件 - 按照 example.html 设计
/// - 边框：0.5px solid --color-border-tertiary
/// - 圆角：12px
/// - 背景：--color-background-primary
/// - 无阴影、无渐变
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool dense;

  const ModernCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.dense = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withOpacity(0.5);
    final backgroundColor = colorScheme.surface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(dense ? 10 : 12),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// 水平列表项卡片 - 用于 Library 列表
class ModernListCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double leadingSize;

  const ModernListCard({
    Key? key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.leadingSize = 40,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withOpacity(0.5);
    final titleColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            SizedBox(
              width: leadingSize,
              height: leadingSize,
              child: leading,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: subtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// 相册卡片 - 用于 Albums 网格
class ModernAlbumCard extends StatelessWidget {
  final Widget thumbnail;
  final String title;
  final String? artist;
  final VoidCallback? onTap;

  const ModernAlbumCard({
    Key? key,
    required this.thumbnail,
    required this.title,
    this.artist,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withOpacity(0.5);
    final titleColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: borderColor,
                    width: 0.5,
                  ),
                ),
                child: thumbnail,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: titleColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (artist != null) ...[
              const SizedBox(height: 2),
              Text(
                artist!,
                style: TextStyle(
                  fontSize: 11,
                  color: subtitleColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 分组设置卡片 - 用于 Settings
class ModernSettingsGroupCard extends StatelessWidget {
  final String? header;
  final List<ModernSettingsItem> items;

  const ModernSettingsGroupCard({
    Key? key,
    this.header,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withOpacity(0.5);
    final headerColor = colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(
          color: borderColor,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: headerColor,
                  letterSpacing: 0.05,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          ...List.generate(
            items.length,
            (index) => Column(
              children: [
                if (index > 0 || header != null)
                  Divider(
                    height: 0.5,
                    color: borderColor,
                    thickness: 0.5,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: items[index],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置项 - 用于 ModernSettingsGroupCard
class ModernSettingsItem extends StatelessWidget {
  final String label;
  final Widget? value;
  final VoidCallback? onTap;

  const ModernSettingsItem({
    Key? key,
    required this.label,
    this.value,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelColor = colorScheme.onSurface;
    final valueColor = colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: labelColor,
            ),
          ),
          value ??
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 12,
                  color: valueColor,
                ),
              ),
        ],
      ),
    );
  }
}

/// 快捷菜单卡片 - 用于 Home
class ModernQuickMenuCard extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  const ModernQuickMenuCard({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withOpacity(0.5);
    final labelColor = colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: icon,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 类别卡片 - 用于 Search
class ModernCategoryCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const ModernCategoryCard({
    Key? key,
    required this.title,
    this.subtitle,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant.withOpacity(0.5);
    final titleColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(
            color: borderColor,
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: titleColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: subtitleColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 曲目行 - 用于 Album/Player
class ModernTrackRow extends StatelessWidget {
  final String number;
  final String title;
  final String? artist;
  final String? duration;
  final bool isPlaying;
  final VoidCallback? onTap;

  const ModernTrackRow({
    Key? key,
    required this.number,
    required this.title,
    this.artist,
    this.duration,
    this.isPlaying = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isPlaying ? colorScheme.surfaceVariant : colorScheme.surface;
    final titleColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;
    final numberColor = isPlaying ? colorScheme.onSurface : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: Text(
                isPlaying ? '▶' : number,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
                  color: numberColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (artist != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      artist!,
                      style: TextStyle(
                        fontSize: 10,
                        color: subtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (duration != null) ...[
              const SizedBox(width: 10),
              Text(
                duration!,
                style: TextStyle(
                  fontSize: 10,
                  color: subtitleColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
