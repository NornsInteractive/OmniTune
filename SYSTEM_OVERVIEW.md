# 🎵 Flutter Music Player - 系统一览表

## 核心价值主张

这是一个**跨平台音乐播放器**，专为多个远程存储源而设计，具有以下特点:

✅ **WebDAV/SFTP/Samba 集成** - 流媒体播放，无需下载  
✅ **自动元数据刮削** - MusicBrainz 集成，后台处理  
✅ **丰富的库管理** - 文件夹分组、多源支持  
✅ **现代化 UI** - Material Design 3，动态主题  
✅ **本地化** - 英文、中文支持  
✅ **开发友好** - Riverpod 状态管理、完整的调试系统  

---

## 🏗️ 高级架构

```
┌──────────────────────────────────────────────────────────┐
│                   FLUTTER APPLICATION                     │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─ UI 层 ─────────────────────────────────────────────┐ │
│  │ • 库页面 (歌曲列表 + 文件夹分组)                    │ │
│  │ • 相册视图 (按文件夹/刮削数据分组)                 │ │
│  │ • 播放器 (完整播放器面板)                           │ │
│  │ • 设置 (源配置、主题选择)                           │ │
│  │ • 日志 (调试系统)                                   │ │
│  └─────────────────────────────────────────────────────┘ │
│           ▲                                               │
│           │ Riverpod Watchers                             │
│           │                                               │
│  ┌─ 状态层 ──────────────────────────────────────────┐  │
│  │ • library_catalog_state (歌曲列表)                │  │
│  │ • playerStateProvider (播放状态)                 │  │
│  │ • sourcesControllerProvider (源列表)             │  │
│  │ • debugModeProvider (调试开关)                    │  │
│  └────────────────────┬──────────────────────────────┘  │
│                       │                                   │
│  ┌────────────────────▼──────────────────────────────┐  │
│  │          BUSINESS LOGIC 层                        │  │
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ 库扫描                                       │ │  │
│  │ │ • scanAllSources()                          │ │  │
│  │ │ • _mapSong(waitForScraping:false)          │ │  │
│  │ │ • _scrapeMetadataAsync() [后台]            │ │  │
│  │ │ • _updateSongMetadata() [状态更新]         │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  │                                                     │  │
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ 播放器控制                                   │ │  │
│  │ │ • playLibrarySong()                         │ │  │
│  │ │ • _loadQueueIndex() [元数据注入]            │ │  │
│  │ │ • _loadLyrics() [异步]                      │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  │                                                     │  │
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ 元数据刮削                                   │ │  │
│  │ │ • MusicBrainz API (_makeRequest)            │ │  │
│  │ │ • 503 重试逻辑 (指数退避)                   │ │  │
│  │ │ • 结果缓存 (DebugLogStore)                  │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  │                                                     │  │
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ 调试日志                                     │ │  │
│  │ │ • DebugLogger (8 个级别)                    │ │  │
│  │ │ • DebugLogStore (环形缓冲区)                │ │  │
│  │ │ • DebugLogsPage (搜索/复制)                 │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  └────────────────────┬───────────────────────────────┘  │
│                       │                                   │
│  ┌────────────────────▼──────────────────────────────┐  │
│  │          数据模型层                               │  │
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ LibrarySong                                  │ │  │
│  │ │ • 基本字段: title, artistName, albumTitle   │ │  │
│  │ │ • 刮削字段: {auto|manually}Scraped*         │ │  │
│  │ │ • Getter: displayTitle/Artist/Album         │ │  │
│  │ │ • 优先级: 手动 > 自动 > 原始                │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  │                                                     │  │
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ PlayableTrack                                │ │  │
│  │ │ • AudioSource (播放)                         │ │  │
│  │ │ • 刮削字段: autoScrape* (从 LibrarySong)   │ │  │
│  │ │ • Getter: displayTitle/Artist/Album/Lyrics  │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  │                                                     │  │
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ RemoteEntry                                  │ │  │
│  │ │ • 原始响应: title, path, size, isDirectory  │ │  │
│  │ │ • 无刮削数据 (仅用于浏览)                   │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  │                                                     │  │
│  │ ┌──────────────────────────────────────────────┐ │  │
│  │ │ SourceProfile                                │ │  │
│  │ │ • 源配置: URL, 凭证, 协议                   │ │  │
│  │ │ • 持久化: flutter_secure_storage            │ │  │
│  │ └──────────────────────────────────────────────┘ │  │
│  └──────────────────┬────────────────────────────────┘  │
│                     │                                    │
│  ┌──────────────────▼─────────────────────────────────┐ │
│  │          DATA 源层                                │ │
│  │ ┌──────────────────────────────────────────────┐ │ │
│  │ │ 远程源实现                                   │ │ │
│  │ │ • WebDAVMusicSource (✅ 完整)               │ │ │
│  │ │ • SFTPMusicSource (⚠️ 存根)                │ │ │
│  │ │ • SambaMusicSource (⚠️ 存根)               │ │ │
│  │ │ • Cloud189Source (⚠️ 存根)                │ │ │
│  │ │ • FTPMusicSource (⚠️ 存根)                │ │ │
│  │ │                                             │ │ │
│  │ │ 接口: buildCatalog(), buildPlayableTrack() │ │ │
│  │ └──────────────────────────────────────────────┘ │ │
│  │                                                     │ │
│  │ ┌──────────────────────────────────────────────┐ │ │
│  │ │ 播放缓存                                     │ │ │
│  │ │ • 内存缓存 (LRU)                            │ │ │
│  │ │ • 文件缓存 (可选)                           │ │ │
│  │ │ • 302 OpenList 重定向处理                   │ │ │
│  │ └──────────────────────────────────────────────┘ │ │
│  │                                                     │ │
│  │ ┌──────────────────────────────────────────────┐ │ │
│  │ │ API 集成                                     │ │ │
│  │ │ • MusicBrainz (元数据)                       │ │ │
│  │ │ • WebDAV/HTTP (音频流)                       │ │ │
│  │ │ • 本地存储 (凭证, 主题)                      │ │ │
│  │ └──────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 🔄 关键操作流程

### 流程 1: 库扫描与异步刮削

```
用户: "扫描 WebDAV"
│
▼
┌─ scanAllSources() ──────────────────────────────┐
│                                                  │
│ 1️⃣ for each source in configured sources:      │
│   → buildCatalog() 获取 RemoteEntry 列表        │
│                                                  │
│ 2️⃣ for each RemoteEntry entry:                  │
│   → _mapSong(entry, waitForScraping: false)    │
│     ├─ 创建 LibrarySong                         │
│     ├─ 设置文件夹元数据 (标题/艺术家/专辑)    │
│     └─ 立即返回（⚡ 快速）                    │
│                                                  │
│ 3️⃣ 触发 UI 重建                                 │
│   → library_catalog_state 更新                  │
│   → RiverPod 通知观察者                        │
│   → library_page 显示歌曲 (文件夹名)           │
│                                                  │
│ 4️⃣ 后台: unawaited(_scrapeMetadataAsync())     │
│   → 对每个 LibrarySong 启动                    │
│   → 异步执行（无等待）                        │
│                                                  │
└──────────────────────────────────────────────────┘
              │
              ▼ (后台继续)
┌─ _scrapeMetadataAsync(song) ──────────────────┐
│                                                │
│ 1️⃣ DebugLogger.scraping("🔄 查询 MusicBrainz")│
│                                                │
│ 2️⃣ _performScraping()                          │
│   → MusicBrainzClient.searchRecordings()      │
│     ├─ _makeRequest() [带重试逻辑]            │
│     ├─ 如果 503: 等待 1000ms → 重试           │
│     ├─ 如果 HTTP 200: 返回结果                │
│     └─ 如果失败 3 次: 放弃                     │
│                                                │
│ 3️⃣ 结果处理:                                   │
│   ├─ 如果成功: title, artist, album           │
│   │  → _updateSongMetadata(song, result)     │
│   │    ├─ song.autoScrapedTitle = result.title│
│   │    ├─ song.autoScrapedArtist = ...        │
│   │    ├─ song.autoScrapedAlbum = ...         │
│   │    └─ 保存到 library_catalog_state        │
│   │                                            │
│   └─ 如果失败: 不修改 (保持文件夹数据)        │
│                                                │
│ 4️⃣ Riverpod 检测状态变化                       │
│   → 自动通知所有监听者                         │
│   → UI 重建 (library_page 等)                 │
│                                                │
│ 5️⃣ DebugLogger 记录结果                        │
│   → ✅ "刮削成功: Artist - Title"             │
│   → ❌ "刮削失败: 未找到"                      │
│                                                │
└────────────────────────────────────────────────┘
```

### 流程 2: 播放歌曲与元数据注入

```
用户: 点击 library_page 中的歌曲
│
▼
┌─ playLibrarySong(index) ────────────────────┐
│                                              │
│ 1️⃣ song = _playlist[index]  # LibrarySong   │
│                                              │
│ 2️⃣ _loadQueueIndex(index)                   │
│   ├─ 获取 SourceProfile                     │
│   ├─ 获取 MusicSource 实例                  │
│   └─ 启动 buildPlayableTrack()             │
│                                              │
└────────────────┬─────────────────────────────┘
                 │
                 ▼
┌─ buildPlayableTrack(song.toRemoteEntry()) ──┐
│                                              │
│ 1️⃣ WebDAVMusicSource.buildPlayableTrack()   │
│                                              │
│ 2️⃣ 构建缓存:                                 │
│   → _playbackCache.createCachedAudioSource()│
│   → 如果缓存: 返回                           │
│   → 未缓存: 创建 StreamAudioSource()         │
│                                              │
│ 3️⃣ 返回 PlayableTrack (基本数据):          │
│   {                                         │
│     id, sourceId, title,                    │
│     sourceName, remotePath,                 │
│     audioSource,                            │
│     artistName, albumTitle,                 │
│     [无刮削数据]                            │
│   }                                         │
│                                              │
└────────────────┬─────────────────────────────┘
                 │
                 ▼ (回到 _loadQueueIndex)
┌─ 元数据注入!!!! ────────────────────────┐
│                                         │
│ track = PlayableTrack(                  │
│   ...track 的所有字段...,              │
│                                         │
│   // ⭐ 新增: LibrarySong 数据        │
│   autoScrapedTitle:                    │
│     song.manuallyScrapedTitle ??       │
│     song.autoScrapedTitle,             │
│   autoScrapedArtist:                   │
│     song.manuallyScrapedArtist ??      │
│     song.autoScrapedArtist,            │
│   autoScrapedAlbum: ...                │
│   autoScrapedCoverUrl: ...             │
│   lyrics: ...                          │
│ )                                       │
│                                         │
│ ✅ 现在 track 具有刮削数据!           │
│                                         │
└────────────────┬─────────────────────────┘
                 │
                 ▼
┌─ service.loadTrack(track) ──────────────────┐
│                                              │
│ 1️⃣ just_audio.setAudioSource(track.audioSource)│
│                                              │
│ 2️⃣ UI 更新                                   │
│   → now_playing_panel 刷新                  │
│   → 显示 track.displayTitle ✓               │
│   → 显示 track.displayArtist ✓              │
│   → 显示 track.displayAlbum ✓               │
│                                              │
│ 3️⃣ 音频播放开始 ▶️                           │
│                                              │
└──────────────────────────────────────────────┘
```

### 流程 3: UI 显示一致性

```
所有位置都使用 display* getter:

Getter 定义:
┌─ LibrarySong.displayTitle ─────────┐
│ if manuallyScrapedTitle ≠ null      │
│   → return manuallyScrapedTitle ✅  │
│ else if autoScrapedTitle ≠ null     │
│   → return autoScrapedTitle ✅      │
│ else if scrapedArtistName ≠ null    │
│   → return scrapedArtistName        │
│ else if folderArtistName ≠ null     │
│   → return folderArtistName         │
│ else                                │
│   → return title (原始)             │
└─────────────────────────────────────┘

┌─ PlayableTrack.displayTitle ──────┐
│ if autoScrapedTitle ≠ null         │
│   → return autoScrapedTitle ✅     │
│ else                               │
│   → return title (原始)            │
└──────────────────────────────────────┘

使用位置:
1️⃣  library_page.dart
    song.displayTitle         ← LibrarySong
    song.displayArtist
    song.displayAlbum

2️⃣  albums_page.dart  
    track.displayTitle        ← LibrarySong (用作 track)
    track.displayArtist
    track.displayAlbum

3️⃣  now_playing_panel.dart
    track.displayTitle        ← PlayableTrack
    track.displayArtist
    track.displayAlbum

✅ 结果: 所有位置显示相同数据
```

---

## 📊 状态管理图

```
Riverpod 提供商关系:

sourcesControllerProvider
    ↓
    └─→ 源列表
        ├─ WebDAV URL, 凭证
        ├─ SFTP URL, SSH 密钥
        └─ ...

library_catalog_state (StateNotifierProvider)
    ↓
    └─→ List<LibrarySong>
        ├─ id, title, ...
        ├─ autoScrapedTitle ← 后台更新
        ├─ autoScrapedArtist
        └─ ...

        监视者:
        ├─ library_page (显示列表)
        ├─ albums_page (按刮削分组)
        └─ player (选择要播放)

playerStateProvider
    ↓
    ├─ currentTrack (PlayableTrack)
    ├─ isPlaying
    ├─ position
    ├─ duration
    └─ playlist

    监视者:
    ├─ now_playing_panel (显示当前曲目)
    ├─ mini_player (显示缩略图)
    └─ playback_timeline (显示进度)

debugModeProvider (StateNotifierProvider)
    ↓
    └─→ bool (enabled/disabled)
        
    监视者:
    ├─ app_shell (条件显示"日志"选项卡)
    └─ settings_page (显示调试切换)

DebugLogStore (单例 ChangeNotifier)
    ↓
    └─→ List<DebugLogEntry> (最多 1000)
        
    监视者:
    └─ debug_logs_page (显示和搜索)
```

---

## 🎯 关键设计模式

### 1. Display Getter 模式

**问题**: 多个数据源，需要优先级处理

**解决方案**:
```dart
get displayTitle {
  // 优先尝试刮削源
  if (autoScrapedTitle?.isNotEmpty == true) return autoScrapedTitle!
  // 回退到原始
  return title
}
```

**优点**:
- 一致的优先级管理
- 单一获取点
- 易于测试

### 2. 异步数据增强

**问题**: PlayableTrack 缺少刮削数据，但需要用于显示

**解决方案**:
- 获取基本 PlayableTrack
- 从 LibrarySong 源获取刮削字段
- 重新构造更新的 PlayableTrack
- 传递给播放服务

**优点**:
- 分离关注点
- 源不需要了解刮削
- 播放器获得完整数据

### 3. 后台异步刮削

**问题**: 刮削阻止库加载 UX

**解决方案**:
```dart
_mapSong(waitForScraping: false)  // 立即返回
unawaited(_scrapeMetadataAsync()) // 后台启动
```

**优点**:
- 快速库加载
- 用户立即看到歌曲
- 元数据逐步更新

### 4. 指数退避重试

**问题**: MusicBrainz 503 错误

**解决方案**:
```dart
for attempt in 1..3:
  delay = 1000 * attempt  // 1s, 2s, 3s
  if response == 503:
    wait(delay)
    retry
```

**优点**:
- 自动恢复
- 避免压倒 API
- 可配置

### 5. 条件导航

**问题**: 调试页面仅供开发人员使用

**解决方案**:
```dart
if (debugModeEnabled) {
  StatefulShellBranch('/debug-logs', DebugLogsPage)
}
```

**优点**:
- 仅在需要时显示
- 生产版本无开销
- 用户可切换

---

## 🔗 数据流总结

```
RemoteEntry (WebDAV 文件)
    ↓
_mapSong() → LibrarySong (文件夹元数据)
    ↓
library_page/albums_page 显示 (使用 display*)
    ↓
[后台] _scrapeMetadataAsync() → MusicBrainz API
    ↓
_updateSongMetadata() → 更新 LibrarySong
    ↓
Riverpod 通知 → UI 重建 (自动更新显示)
    ↓
用户点击播放 ↓
    ↓
playLibrarySong() → _loadQueueIndex()
    ↓
buildPlayableTrack() → 基本 PlayableTrack
    ↓
[关键] 使用 LibrarySong 刮削数据重新构造
    ↓
now_playing_panel 显示 (使用 display* getter)
    ↓
✅ 结果: 播放器显示刮削的元数据
```

---

## 📝 总结

这个系统通过以下方式整合:

1. **多源远程文件访问** → 扫描库和即时浏览
2. **后台元数据刮削** → 非阻塞 UX，自动更新
3. **可靠 API 集成** → 503 重试，错误管理
4. **响应式 UI** → Riverpod 自动重建
5. **一致的元数据显示** → display* getter 优先级
6. **播放器元数据注入** → 将刮削数据带入播放时
7. **开发友好的调试** → 应用内日志，随时可见
8. **本地化完整** → 所有字符串 l10n，所有颜色主题

**结果**: 用户获得了一个流畅、快速、可靠的音乐播放体验，具有自动元数据改进和完全的开发可见性。

