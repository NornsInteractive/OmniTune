# 快速参考: 异步刮削系统

## 版本信息
- **当前版本**: 1.0.107+108
- **编译状态**: ✅ 成功 (62MB APK)
- **代码质量**: 0 错误，21 条警告
- **功能完成度**: 100%

## 用户快速开始

### 1. 启用调试模式
```
1. 打开应用 → 设置页面 (齿轮图标)
2. 切换"调试模式" ON
3. 返回主屏幕 → "日志"选项卡出现在底部导航
```

### 2. 扫描库
```
1. 设置 → 添加源 → 配置WebDAV
2. 返回库页面
3. 刷新 → 歌曲立即显示 (文件夹名称作为艺术家/专辑)
4. 查看日志标签 → 观察"🔄 刮削中..."消息
```

### 3. 播放歌曲
```
1. 从列表中点击歌曲
2. 播放器显示 displayTitle/displayArtist/displayAlbum
3. 检查日志 → 如果有刮削成功或失败的消息
4. 等待 → 元数据从 MusicBrainz 更新 (通常 2-5 秒)
```

## 开发人员快速参考

### 三个主要数据流

#### 流程 1: 库扫描
```dart
// lib/features/library/application/library_catalog_controller.dart
scanAllSources() {
  for (file in files) {
    song = _mapSong(file, waitForScraping: false)  // 立即返回
    unawaited(_scrapeMetadataAsync(song))           // 后台启动
  }
}

_scrapeMetadataAsync() {
  // MusicBrainz API 调用 (携带重试逻辑)
  result = await _performScraping()
  // 更新 state，Riverpod 触发 UI 重建
  _updateSongMetadata(result)
}
```

#### 流程 2: 播放歌曲
```dart
// lib/features/player/application/player_controller.dart
_loadQueueIndex(index) {
  song = _playlist[index]  // LibrarySong with scraped data
  track = await source.buildPlayableTrack(song.toRemoteEntry())
  
  // 关键: 使用 LibrarySong 的刮削字段增强 PlayableTrack
  track = PlayableTrack(
    ...track fields...,
    autoScrapedTitle: song.manuallyScrapedTitle ?? song.autoScrapedTitle,
    autoScrapedArtist: song.manuallyScrapedArtist ?? song.autoScrapedArtist,
    autoScrapedAlbum: song.manuallyScrapedAlbum ?? song.autoScrapedAlbum,
  )
  
  service.loadTrack(track)
}
```

#### 流程 3: 显示元数据
```dart
// 所有 display* getter 遵循相同的模式
// lib/core/models/playable_track.dart 和 lib/core/models/library_song.dart

get displayTitle {
  if (autoScrapedTitle?.isNotEmpty) return autoScrapedTitle!
  return title  // 回退到原始
}
```

### 调试日志 API

```dart
// 导入
import 'package:music/core/utils/debug_logger.dart';

// 使用
DebugLogger.info('Message')      // 📝 INFO
DebugLogger.success('Message')   // ✅ SUCCESS  
DebugLogger.warning('Message')   // ⚠️ WARNING
DebugLogger.error('Message')     // ❌ ERROR
DebugLogger.network('Message')   // 🌐 NETWORK
DebugLogger.database('Message')  // 💾 DATABASE
DebugLogger.scraping('Message')  // 🎵 SCRAPING
DebugLogger.performance('Message')  // ⏱️ PERFORMANCE

// 启用/禁用
DebugLogger.setDebugEnabled(true)

// 从 UI 访问日志
ref.watch(debugModeProvider)  // 获取当前模式
ref.read(debugModeProvider.notifier).setEnabled(true)  // 设置模式
```

### MusicBrainz 重试逻辑

```dart
// lib/features/scraper/data/musicbrainz_client.dart
_makeRequest(url) {
  for attempt in 1..3:
    try:
      response = http.get(url)
      if response.statusCode == 503:
        wait(1000ms * attempt)  // 指数退避
        continue
      return response
    catch TimeoutException:
      wait(1000ms * attempt)
      continue
}
```

### 添加新的日志类别

```dart
// 在 lib/core/utils/debug_logger.dart 中添加新方法:
static void customCategory(String message) {
  final entry = DebugLogEntry(
    timestamp: DateTime.now(),
    message: message,
    level: 'CUSTOM',  // 自定义级别
  )
  DebugLogStore().addLog(entry)
}

// 使用:
DebugLogger.customCategory('My custom log message')
```

## 关键文件快速查找

### 调试系统
- 日志存储: `lib/core/utils/debug_log_store.dart`
- 日志 API: `lib/core/utils/debug_logger.dart`
- 日志 UI: `lib/features/debug/presentation/debug_logs_page.dart`
- 状态: `lib/features/debug/application/debug_mode_provider.dart`

### 刮削系统
- 库扫描: `lib/features/library/application/library_catalog_controller.dart`
- MusicBrainz API: `lib/features/scraper/data/musicbrainz_client.dart`
- 提供商: `lib/features/scraper/application/scraping_provider.dart`

### 播放器
- 播放控制: `lib/features/player/application/player_controller.dart`
- 播放面板: `lib/features/player/presentation/widgets/now_playing_panel.dart`
- 音轨模型: `lib/core/models/playable_track.dart`

### 数据模型
- 库歌曲: `lib/core/models/library_song.dart`
- 源配置: `lib/core/models/source_profile.dart`

## 常见问题和解决方案

### Q: 扫描后看不到日志
A: 检查调试模式是否启用
```
设置 → 向下滚动 → "调试模式" 开关
```

### Q: 歌曲没有刮削元数据显示
A: 可能原因:
1. MusicBrainz API 不可用 → 查看日志获取错误
2. 歌曲不在 MusicBrainz 中 → 日志将显示"未找到"
3. 后台刮削仍在进行 → 等待 2-5 秒后重新进入播放器

### Q: 我如何添加手动元数据？
A: 尚未实现，但代码已准备好:
```dart
// 这些字段存在:
song.manuallyScrapedTitle
song.manuallyScrapedArtist
song.manuallyScrapedAlbum

// 需要 UI 对话框来编辑它们
```

### Q: 503 错误何时会触发重试？
A: 在以下情况下:
- HTTP 503 (Service Unavailable)
- 连接超时
- 接收超时

重试最多 3 次，延迟 1s/2s/3s

### Q: 调试日志会保存到文件吗？
A: 不会，仅存储在内存中 (最多 1000 项)
一旦应用关闭，日志丢失
(未来改进: 持久化到 Isar 数据库)

## 测试清单

- [ ] 启用调试模式 → 日志选项卡出现
- [ ] 扫描库 → 歌曲立即显示格式化的标题
- [ ] 观察日志 → 看到"🔄 扫描进行中..."消息
- [ ] 等待刮削 → 查看"✅ 刮削成功"或"❌ 失败"
- [ ] 播放歌曲 → 显示刮削的标题/艺术家/专辑
- [ ] 禁用调试 → 日志选项卡消失
- [ ] MusicBrainz 宕机期间测试 → 观察重试日志

## 架构图

```
┌──────────────────────────────────────────────────────┐
│                 APPLICATION UI                       │
├──────────────────────────────────────────────────────┤
│  Library Page  │  Albums  │  Player  │  Logs (调试)  │
│                │          │          │               │
│ display*       │ display* │ display* │ Console 风格  │
└────────┬───────┴──┬───────┴──┬───────┴────────┬──────┘
         │          │          │                │
    ┌────▼──────────▼──────────▼────────────────▼──────┐
    │         STATE MANAGEMENT (Riverpod)              │
    ├─────────────────────────────────────────────────┤
    │ library_catalog_state  │  debugModeProvider    │
    │ LibrarySong list       │  debug enabled/logs   │
    └────┬──────────────────────┬────────────────────┘
         │                      │
    ┌────▼──────────────┐       └──────────────────┐
    │  SCRAPING LAYER   │                          │
    │ ┌────────────────┐│    ┌────────────────────┐│
    │ │ MusicBrainz    ││    │ DebugLogger/Store  ││
    │ │ _makeRequest() ││    │ Loggingto memory   ││
    │ │ +503 retry     ││    └────────────────────┘│
    │ └────────────────┘│                          │
    │ + background work │                          │
    └────┬─────────────┘                           │
         │                                          │
    ┌────▼──────────────────────┬──────────────────┘
    │  DATA MODELS              │
    ├───────────────────────────┤
    │ LibrarySong (display*     │
    │   getters)                │
    │ PlayableTrack (display*   │
    │   getters)                │
    │ RemoteEntry (raw)         │
    └─────────────────────────────
```

## 版本历史

| 版本 | 特性 | 日期 |
|------|------|------|
| 1.0.107+108 | ✅ 异步刮削 + 调试系统 | 2026年4月 |
| 1.0.104+105 | 基础刮削 | 2026年3月 |  
| 1.0.0+1 | 初始发布 | 2025年 |

## 下一步

1. **手动刮削编辑** (待实现)
2. **歌词显示** (等待字段集成)
3. **Isar 数据库持久化** (用于扫描结果)
4. **更多协议** (SFTP, Samba, Cloud189)
5. **改进的 UI** (长按菜单, 批量操作)

---

**问题?** 查看 `ASYNC_SCRAPING_COMPLETE.md` 了解完整详情或检查代码注释。
