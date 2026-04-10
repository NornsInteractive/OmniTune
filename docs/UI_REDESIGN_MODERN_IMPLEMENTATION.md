# Flutter Music Player - UI 完全重构计划

根据 `ui/example.html` 的设计，对所有页面进行完整重构。

## 设计系统规范

### 卡片样式（所有页面）
- **边框**: 0.5px solid（使用 `colorScheme.outlineVariant.withOpacity(0.5)`）
- **圆角**: 12px（部分地方10px、8px、14px根据用途）
- **背景**: 使用 `colorScheme.surface`
- **间距**: 10-14px padding
- **分隔符**: 0.5px border（用于分组）

### 色彩系统
- **主文本**: `colorScheme.onSurface`
- **次文本**: `colorScheme.onSurfaceVariant`
- **三级文本**: `colorScheme.outline`
- **主色**: `colorScheme.primary`
- **边框**: `colorScheme.outlineVariant.withOpacity(0.5)`

### 字体规范
| 用途 | 大小 | 粗细 |
|------|------|------|
| 页面标题 | 16px | w500 |
| 卡片标题 | 13-12px | w500 |
| 卡片副标题 | 11-10px | normal |
| 描述文本 | 12px | normal |

---

## 页面重构清单

### 1. Albums 页面（`albums_page.dart`）

**结构**:
```
[Header]
  - 标题: "Albums" (16px w500)
  - 音源切换: 水平列表（如果多个源）
    - 按钮样式: 12px w500, 圆角20px, 0.5px边框
    - 选中: 主色背景 + 文本
    
[Grid]
  - Mobile (< 600px): 2列
  - Tablet (600-900px): 3列
  - Desktop (> 900px): 4列
  - 间距: 10px
  
[Card]
  - 模型: ModernAlbumCard
  - 包含: 封面 + 标题 + 艺术家
  - 圆角: 12px, 0.5px边框
```

### 2. Library 页面（`library_page.dart`）

**子页面**:
1. **Home** (`library_home.dart`)
   - 快捷菜单: 2列网格（Liked Songs, Recently Played, Top Mixes, My Playlist）
   - 最近播放: 2/3/4列相应响应式网格
   - 使用 `ModernQuickMenuCard` 和 `ModernAlbumCard`

2. **Search** (`library_search.dart`)
   - 搜索框: 带图标, 边框0.5px, 圆角10px
   - 浏览分类: 2列网格
   - 每个分类: `ModernCategoryCard`（标题 + 子标题）

3. **Library List** (`library_list.dart`)
   - 选项卡: Playlists | Albums | Artists
   - 使用 `ModernListCard` 显示列表项
   - 每项: 图标(40x40) + 标题/计数 + 右箭头

4. **Browser** (`library_browser.dart`)
   - 保留现有功能，使用卡片样式包装

### 3. Player 页面（`player_page.dart`）

**结构**:
```
[大封面]
  - 尺寸: 240x240 或响应式
  - 圆角: 18px
  - 0.5px边框
  
[元数据]
  - 标题: 16px w500
  - 艺术家/年份: 12px
  
[进度条]
  - 高度: 3px
  - 进度把手: 10px圆形
  - 时间显示: 10px
  
[控制按钮]
  - 上一首、播放/暂停、下一首
  - 播放按钮: 50x50 圆形背景
  - 其他: 32x32 简单按钮
  
[音量控制]
  - 图标 + 滑块 + 图标
```

### 4. Settings 页面（`settings_page.dart`）

**结构** - 分组卡片:
1. **AUDIO** 分组
   - Audio quality (select)
   - Equalizer (toggle)

2. **PLAYBACK** 分组
   - Crossfade (select)
   - Gapless playback (switch)

3. **APPEARANCE** 分组
   - Theme (select)
   - Language (select)

4. **ACCOUNT** 分组
   - 用户头像 + 名字 + 邮箱
   - 使用 `ModernSettingsGroupCard`

### 5. MiniPlayer 组件（`mini_player.dart`）

**结构**:
```
[行布局]
  - 封面: 36x36, 圆角8px
  - 标题/艺术家列
  - 按钮组: 播放/暂停、下一首
```

---

## 实现步骤

### Phase 1: 基础组件
- ✅ `lib/shared/widgets/modern_ui/modern_card.dart` (7个组件)
- ⏳ 导出文件 `modern_ui.dart`

### Phase 2: 页面重构（按优先级）
1. **Albums 页面** - 最复杂但独立
   - [ ] 替换 `albums_page.dart`
   - [ ] 完全按 example.html 结构重写
   
2. **Library 页面群** - 5个子页面
   - [ ] 创建/重构 `library_home.dart`
   - [ ] 创建/重构 `library_search.dart`
   - [ ] 创建/重构 `library_list.dart`
   - [ ] 更新 `library_page.dart` 路由
   - [ ] Browser 子页面保留或轻微调整

3. **Player 页面** - 复杂布局
   - [ ] 替换 `player_page.dart`
   - [ ] 更新 `playback_timeline.dart` 进度条样式
   - [ ] 更新播放按钮组

4. **Settings 页面** - 相对简单
   - [ ] 替换 `settings_page.dart` 中的布局
   - [ ] 使用 `ModernSettingsGroupCard`

5. **MiniPlayer** - 小但关键
   - [ ] 更新 `mini_player.dart`

### Phase 3: 验证和构建
- [ ] `flutter analyze` - 0 错误
- [ ] 在三种设备尺寸上测试 (Mobile/Tablet/Desktop)
- [ ] `bash scripts/build_apk.sh` - 构建 APK

---

## 组件使用示例

### AlbumCard 网格
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns, // 2/3/4
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 0.85,
  ),
  itemBuilder: (context, index) {
    final album = albums[index];
    return ModernAlbumCard(
      thumbnail: AlbumImage(url: album.imageUrl),
      title: album.title,
      artist: album.artist,
      onTap: () => context.push('/albums/${album.id}'),
    );
  },
)
```

### 设置分组
```dart
ModernSettingsGroupCard(
  header: 'AUDIO',
  items: [
    ModernSettingsItem(
      label: 'Audio quality',
      value: Text('High'),
      onTap: () => showDialog(...),
    ),
  ],
)
```

---

## 关键约束

1. **零硬编码**: 所有颜色/字体/间距都用系统 tokens
2. **国际化**: 使用 `AppLocalizations`
3. **响应式**: 所有页面支持三个断点 (600px / 900px)
4. **可访问性**: 合理的 TAP 目标大小 (48dp+)
5. **性能**: 列表使用 `ListView.builder` / `GridView.builder`

---

## 文件清单

需要修改/创建的文件：

```
lib/shared/widgets/modern_ui/
  ✅ modern_card.dart (已创建)
  ✅ modern_ui.dart (已创建)

lib/features/library/presentation/
  - [ ] albums_page.dart (重构)
  - [ ] library_page.dart (更新路由)
  - [ ] library_home.dart (创建或重构)
  - [ ] library_search.dart (创建或重构)
  - [ ] library_list.dart (创建或重构)
  - [ ] library_browser.dart (可选: 轻微调整)

lib/features/player/presentation/
  - [ ] player_page.dart (重构)
  - [ ] mini_player.dart (更新)
  - [ ] playback_timeline.dart (可选: 轻微调整)

lib/features/settings/presentation/
  - [ ] settings_page.dart (重构)
```

---

## 参考设计

所有设计规范详见 `ui/example.html`:
- Home 页面: 快捷菜单 + 最近播放
- Search 页面: 搜索框 + 分类网格
- Library 页面: 选项卡 + 播放列表
- Album 页面: 专辑头部 + 曲目列表
- Player 页面: 大封面 + 进度 + 控制
- Settings 页面: 分组设置

---

**开始日期**: 2026-04-08  
**预计完成**: 需要分阶段进行  
**当前进度**: Phase 1 (ModernUI组件库) 进行中
