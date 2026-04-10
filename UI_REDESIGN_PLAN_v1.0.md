# Flutter 音乐播放器 UI 完全重构计划

## 概览
根据 `ui/example.html` 的设计，对所有页面进行 UI 风格统一和响应式适配。

## 设计规范（来自 example.html）

### 1. 卡片系统
- **边框**: 0.5px solid, `var(--color-border-tertiary)`
- **圆角**: 
  - 小组件: 8px (头像)
  - 普通卡片: 12px (相册、播放列表)
  - 大组件: 14px (相册详情图)
  - 完全圆形: 9999px (标签)
- **背景**: `var(--color-background-primary)`（卡片）、`var(--color-background-secondary)`（缩略图）
- **间距**: 8-16px padding, 10-14px gap

### 2. 响应式网格
| 布局 | 宽度 | 网格列数 | 导航 |
|------|------|--------|------|
| Mobile | < 600px | 2 | BottomNavigationBar |
| Tablet | 600-900px | 3 | NavigationRail |
| Desktop | > 900px | 4 | NavigationDrawer |

### 3. 字体大小
- 大标题: 16px (font-weight: 500)
- 标题: 13-15px (font-weight: 500)
- 正文: 12px
- 小文本: 11px
- 超小文本: 10px

### 4. 颜色系统
- 主文字: `--color-text-primary`
- 次文字: `--color-text-secondary`
- 三级文字: `--color-text-tertiary`
- 播放按钮背景: 主色（solid fill）
- 播放按钮文字: 逆色

## 页面重构清单

### 1. Albums Page (相册)
**当前状态**: 固定二列网格
**目标状态**: 响应式网格（2/3/4列）+ 卡片样式

**组件**:
- 使用 `ModernAlbumCard` 组件
- 响应式 GridView
- 动态列数基于屏幕宽度
- 选项卡：Albums / Artists / Playlists

**文件**:
```
lib/features/library/presentation/albums_page.dart
```

**样式规范**:
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: getGridColumns(context),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
  ),
)
```

### 2. Library Page (库)
**当前状态**: 固定列表布局
**目标状态**: 分层布局（推荐 + 我的库 + 浏览）

**组件**:
- Home section: 2x2 快速访问卡片
- Recently Played: 响应式网格
- 搜索框: 带搜索图标，圆角10px
- 类别: 2列网格
- 播放列表: `ListItemCard` 组件

**文件**:
```
lib/features/library/presentation/library_page.dart
```

**子页面**:
- Collection/Home: 推荐内容
- Collection/List: 播放列表详情
- Collection/Browser: 远程浏览器

### 3. Player Page (播放器)
**当前状态**: 简单布局
**目标状态**: 现代化播放器界面

**组件**:
- 专辑封面: 大尺寸 (90x90px)
- 标题 + 艺术家 + 元信息
- 播放控制: PlayButton + CircleIconButton (收藏、更多)
- 曲目列表: `TrackRowCard` 组件
- 进度条: 连续拖动条
- 迷你播放器: 底部固定栏

**文件**:
```
lib/features/player/presentation/widgets/now_playing_panel.dart
lib/features/player/presentation/widgets/mini_player.dart
lib/features/player/presentation/widgets/playback_timeline.dart
```

### 4. Settings Page (设置)
**当前状态**: 基础表单
**目标状态**: 现代卡片式设置

**组件**:
- 音源列表: `ListItemCard` 组件
- 主题设置: 卡片 + 颜色选择器
- 开关/输入框: Material Design 3 风格
- 按钮: 0.5px 边框，圆角 8-12px

**文件**:
```
lib/features/settings/presentation/settings_page.dart
lib/features/settings/presentation/add_source_page.dart
lib/features/settings/presentation/source_settings_page.dart
```

## 实施步骤

### 第1步: 创建卡片系统 ✅
- ✅ `lib/shared/widgets/cards/card_styles.dart` - 常数和工具函数
- ✅ `lib/shared/widgets/cards/modern_cards.dart` - 卡片组件库

### 第2步: 重构 Albums Page
1. 导入卡片组件
2. 将相册映射到 `ModernAlbumCard`
3. 使用 `getGridColumns()` 实现响应式列数
4. 更新 grid gap 和间距
5. 编译验证

### 第3步: 重构 Library Page
1. 分离首页、列表、浏览三个子页面
2. 实现"我的最爱"等快速访问卡片
3. 最近播放使用响应式网格
4. 播放列表使用 `ListItemCard`
5. 编译验证

### 第4步: 重构 Player Page
1. 更新专辑详情布局
2. 使用 `PlayButton` 和 `CircleIconButton`
3. 曲目列表使用 `TrackRowCard`
4. 改进迷你播放器样式
5. 编译验证

### 第5步: 重构 Settings Page
1. 音源列表使用 `ListItemCard`
2. 表单输入框统一圆角和边框
3. 按钮样式标准化
4. 编译验证

### 第6步: 测试和构建
1. `flutter analyze` - 确保 0 个错误
2. `bash scripts/build_apk.sh` - 构建生产 APK
3. 在三种屏幕尺寸测试

## 色彩系统映射
| HTML 变量 | Flutter 对应 |
|----------|------------|
| `--color-background-primary` | `colorScheme.surface` |
| `--color-background-secondary` | `colorScheme.secondaryContainer` |
| `--color-text-primary` | `colorScheme.onSurface` |
| `--color-text-secondary` | `colorScheme.onSurface.withValues(alpha: 0.6)` |
| `--color-text-tertiary` | `colorScheme.onSurface.withValues(alpha: 0.5)` |
| `--color-border-tertiary` | `colorScheme.outlineVariant` |
| `--color-border-secondary` | `colorScheme.outline` |

## 尺寸对应表
| 元素 | HTML | Flutter |
|-----|------|---------|
| 小头像 | 36px | `CardStyles.avatarSizeSmall` |
| 中头像 | 40px | `CardStyles.avatarSizeMedium` |
| 大封面 | 90px | `CardStyles.avatarSizeLarge` |
| 卡片圆角 | 12px | `CardStyles.borderRadiusLarge` |
| 播放按钮 | 36px H | `CardStyles.playButtonHeight` |

## 关键注意事项
1. ✅ 所有字符串使用 l10n（ARB 文件）
2. ✅ 所有颜色使用 colorScheme
3. ✅ 使用 LayoutBuilder 实现响应式
4. ✅ 不修改路由系统，保持现有导航
5. ✅ MiniPlayer 在所有模式下都应显示

## 验证清单
- [ ] 所有页面编译无错误
- [ ] Mobile 模式: 2列网格 + BottomBar
- [ ] Tablet 模式: 3列网格 + Rail
- [ ] Desktop 模式: 4列网格 + Drawer
- [ ] 所有卡片的边框、圆角、间距符合规范
- [ ] 响应式图片和文本排版正确
- [ ] APK 构建成功
- [ ] 所有功能正常工作（播放、搜索、设置等）
