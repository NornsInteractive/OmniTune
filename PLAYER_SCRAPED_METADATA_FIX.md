# Player Scraped Metadata Fix - Complete Implementation

## 版本
- **APK**: v1.0.107+108 (已成功编译)
- **日期**: 2026年

## 问题描述
播放器现在正在中断，因为it 试图显示 PlayableTrack 模型中不存在的刮削元数据字段。

## 解决方案概述
1. 增强 PlayableTrack 模型以包含自动刮削字段
2. 在播放器控制器中将 LibrarySong 的刮削元数据传递到 PlayableTrack
3. 更新 now_playing_panel UI 以使用 displayTitle/displayArtist/displayAlbum getter

## 详细更改

### 1. PlayableTrack 模型增强 ✅
**文件**: `lib/core/models/playable_track.dart`

**添加的字段**:
- `autoScrapedTitle` - 自动刮削的标题（优先级: 自动 > 原始）
- `autoScrapedArtist` - 自动刮削的艺术家
- `autoScrapedAlbum` - 自动刮削的专辑
- `autoScrapedCoverUrl` - 自动刮削的封面 URL
- `lyrics` - 歌词文本

**新增的 getter**:
- `displayTitle`: 返回 autoScrapedTitle 或原始 title
- `displayArtist`: 返回 autoScrapedArtist 或原始 artistName
- `displayAlbum`: 返回 autoScrapedAlbum 或原始 albumTitle
- `displayLyrics`: 返回歌词

### 2. 远程源工具更新 ✅
**文件**: `lib/features/sources/data/remote_source_utils.dart`

**修改 `buildRemotePlayableTrack` 函数**:
- 添加可选参数以接收刮削元数据
- 将参数转发到 PlayableTrack 构造函数

### 3. 播放器控制器优化 ✅
**文件**: `lib/features/player/application/player_controller.dart`

**修改 `_loadQueueIndex` 方法**:
```dart
// 在调用 buildPlayableTrack 后重新构造 PlayableTrack
// 使用来自 LibrarySong 的刮削元数据
track = PlayableTrack(
  id: track.id,
  sourceId: track.sourceId,
  title: track.title,
  sourceName: track.sourceName,
  remotePath: track.remotePath,
  audioSource: track.audioSource,
  sourceSizeBytes: track.sourceSizeBytes,
  artistName: track.artistName,
  albumTitle: track.albumTitle,
  
  // 应用刮削元数据（手动优先于自动）
  autoScrapedTitle: song.manuallyScrapedTitle ?? song.autoScrapedTitle,
  autoScrapedArtist: song.manuallyScrapedArtist ?? song.autoScrapedArtist,
  autoScrapedAlbum: song.manuallyScrapedAlbum ?? song.autoScrapedAlbum,
  autoScrapedCoverUrl: song.manuallyScrapedCoverUrl ?? song.autoScrapedCoverUrl,
  lyrics: song.manuallyScrapedLyrics ?? song.autoScrapedLyrics,
);
```

## 编译验证 ✅
```
Analyzing music...
21 issues found.  (所有均为 info 或 warning，无错误)
✓ Built build/app/outputs/flutter-apk/app-release.apk (64.7MB)
```

## 完整流程验证

### 场景 1: 列表中的歌曲
1. 用户扫描 WebDAV 源
2. LibrarySong 创建，使用文件夹元数据 + 自动刮削
3. library_page 使用 `song.displayTitle/displayArtist/displayAlbum` ✅

### 场景 2: 相册视图
1. albums_page 显示 track（即 LibrarySong）
2. UI 使用 `track.displayTitle/displayArtist/displayAlbum` ✅

### 场景 3: 播放器视图
1. 点击歌曲播放 → `playLibrarySong(index)`
2. `_loadQueueIndex` 调用 `source.buildPlayableTrack()`
3. 获得基本 PlayableTrack（仅文件夹数据）
4. 使用 LibrarySong 刮削数据重新构造 PlayableTrack ✅
5. now_playing_panel 使用 `track.displayTitle/displayArtist/displayAlbum` ✅

## 元数据优先级（完整链）

### LibrarySong 中的优先级
1. `manuallyScrapedTitle` (最高)
2. `autoScrapedTitle`
3. `scrapedArtistName` (遗留)
4. 原始字段 (最低)

### PlayableTrack 中的优先级
1. `autoScrapedTitle` (源自 LibrarySong 的任何刮削数据)
2. `title` (原始)

## UI 更新 ✅

所有三个位置现在都使用 display getter:

1. **library_page.dart**:
   - `song.displayTitle`, `song.displayArtist`, `song.displayAlbum`

2. **albums_page.dart**:
   - `track.displayTitle`, `track.displayArtist`, `track.displayAlbum`

3. **now_playing_panel.dart**:
   - `track.displayTitle` 在标题
   - `track.displayArtist` 在副标题
   - `track.displayAlbum` 在副标题

## 测试检查表

- [x] 代码编译无错误
- [x] APK 构建成功 (v1.0.107+108)
- [x] PlayableTrack 模型具有新字段和 getter
- [x] player_controller 将 LibrarySong 数据传递到 PlayableTrack
- [ ] 手动测试: 播放歌曲查看刮削元数据是否显示
- [ ] 手动测试: 检查debug日志中的刮削结果
- [ ] 手动测试: 切换debug模式查看后台刮削流程

## 依赖关系

- LibrarySong 模型必须具有所有刮削字段
- library_catalog_controller 必须在背景中运行 _scrapeMetadataAsync
- 歌词和歌词 UI 集成到 now_playing_panel（单独的特性/未开始）

## 已知限制

1. RemoteEntry 浏览播放（在 _playRemoteEntry 中）不传递刮削元数据
   - 原因: 仅来自未扫描库的临时条目
   - 影响: 浏览器中播放的歌曲显示文件夹元数据

2. 非 LibrarySong 的播放不能访问刮削数据
   - 这是合理的，只有库歌曲有刮削历史

## 后续改进

1. **歌词显示**:
   - 在 now_playing_panel 中集成歌词 UI
   - 在播放前后台加载歌词

2. **手动刮削 UI**:
   - 添加"编辑元数据"对话框
   - 单独覆盖标题/艺术家/专辑

3. **封面艺术**:
   - 从 `track.autoScrapedCoverUrl` 加载并显示

## 总结

用户现在可以播放库中的歌曲，并看到刮削的标题/艺术家/专辑元数据与列表和相册视图中的背景异步刮削一致。
