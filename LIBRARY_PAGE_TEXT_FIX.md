# Library Page Text Display Fix — v1.0.27+28

## 问题描述

在资料库（Library）页面发现两个文本显示问题：

1. **扫描音乐库按钮文字被遮挡**
   - 位置：_CollectionHomeBody 中的 FilledButton.icon
   - 原因：按钮被固定为 `SizedBox(height: 40)` 导致文本高度受限
   - 症状：按钮标签文字被截断或不可见

2. **音乐源名称文字太长，导致显示与图标不在同一行**
   - 位置：_SourceCardCompact 组件
   - 原因：源名称固定为 `maxLines: 1` 且容器宽度限制
   - 症状：长的音乐源名称被截断，无法看到完整文本

## 修复方案

### 修复 1：扫描按钮文字显示 (Library Page 第 330-345 行)

**问题代码：**
```dart
SizedBox(
  height: 40,
  child: FilledButton.icon(
    // ... 按钮配置
    label: Text(
      catalog?.isScanning == true ? l10n.scanningAction : l10n.scanLibraryAction,
      style: const TextStyle(fontSize: 12),
    ),
  ),
),
```

**修复代码：**
```dart
Flexible(
  child: FilledButton.icon(
    onPressed: () {
      ref.read(libraryCatalogControllerProvider.notifier).scanAllSources();
    },
    icon: Icon(
      catalog?.isScanning == true ? Icons.sync_rounded : Icons.radar_rounded,
      size: 18,
    ),
    label: Text(
      catalog?.isScanning == true ? l10n.scanningAction : l10n.scanLibraryAction,
      style: const TextStyle(fontSize: 12),
    ),
  ),
),
```

**改进说明：**
- 移除固定的 `SizedBox(height: 40)` 约束
- 改用 `Flexible` 包装，允许按钮在 Row 中灵活调整宽度
- 按钮高度由 Material Design 标准自动设置（不受约束）
- 文本可以完整显示，不再被截断

### 修复 2：音乐源名称显示 (Library Page 第 970-1020 行)

**问题代码：**
```dart
Text(
  source.name,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
),
// ...
Text(
  source.hostLabel,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
),
```

**修复代码：**
```dart
Flexible(
  child: Text(
    source.name,
    maxLines: 2,  // 允许最多 2 行
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
  ),
),
// ...
Flexible(
  child: Text(
    source.hostLabel,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
  ),
),
```

**改进说明：**
- 包装源名称 Text 在 `Flexible` 中
- 允许源名称最多显示 2 行，而不是被强制为 1 行
- Host label 保持 1 行（避免卡片过高）
- 长的源名称现在可以在卡片内自然排列，与图标对齐
- 仍然使用 `ellipsis` 处理超长文本

## 技术细节

### Flexible vs SizedBox 的区别

| 特性 | SizedBox | Flexible |
|------|---------|----------|
| 宽度控制 | 固定宽度 | 根据可用空间灵活调整 |
| 高度控制 | 固定高度 | 让子组件自然高度 |
| 行为 | 总是占用指定的空间 | 优先使用所需空间，填充剩余空间 |
| 文本溢出 | 易导致截断 | 自然换行和椭圆化 |

### maxLines 配置

| 字段 | 原值 | 新值 | 原因 |
|------|------|------|------|
| source.name | 1 | 2 | 长的源名称需要两行显示空间 |
| source.hostLabel | 1 | 1 | Host label 通常短，保持单行 |
| 按钮标签 | N/A | 多行 | Flexible 允许按钮文本自动换行 |

## 测试验证

✅ **编译测试**
```bash
flutter analyze
# Result: No issues found! (1.0s)
```

✅ **APK 构建**
- 版本：v1.0.27+28（自动递增）
- 大小：55 MB
- MD5：22ee119a8455dff3e430f09ec3bb95bf
- 状态：✅ 构建成功

## 修复的用户体验改进

### 按钮文字显示
- **之前**：扫描按钮文字 "扫描音乐库" 被截断，显示不完整
- **之后**：按钮以 Flexible 布局，文字完整显示，自适应宽度

### 源名称显示
- **之前**：长的源名称（如 "家里的 NAS 媒体库音乐服务器"）被强制截断为一行
- **之后**：源名称可以自然地展开为两行，与左侧图标保持对齐

### 整体布局
- 页面更紧凑，响应式更好
- 文本不再被覆盖或隐藏
- 信息展示更完整，提升用户体验

## 相关文件修改

- `/workspace/music/lib/features/library/presentation/library_page.dart`
  - 第 328-351 行：修复扫描按钮
  - 第 970-1020 行：修复源卡片

## 版本历史

- **v1.0.27+28**
  - 修复：扫描按钮文字显示不完整
  - 修复：音乐源名称文字太长显示问题
  - 改进：库页面响应式布局
