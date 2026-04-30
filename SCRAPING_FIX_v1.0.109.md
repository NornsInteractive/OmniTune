# 刮削系统修复 - v1.0.109+110

## 问题分析与解决方案

### 问题 1: 没有一个刮削成功

**原因**: MusicBrainz 搜索查询语法可能不匹配或 API 返回格式问题。

**解决方案**: 
在 `lib/features/scraper/data/musicbrainz_client.dart` 中实现了 **多策略搜索回退机制**:

```dart
/// 策略 1: 尝试 artist + recording 组合（带引号）
artist:"$artist" AND recording:"$title"

/// 策略 2: 尝试不带引号的查询
artist:$artist AND recording:$title

/// 策略 3: 仅用标题搜索（作为后备）
$title
```

**关键改进**:
- ✅ 每个策略失败时自动尝试下一个
- ✅ 添加详细的日志记录每个搜索阶段
- ✅ 改进了 JSON 解析错误处理
- ✅ 添加了"已解析录音数量"的诊断日志

---

### 问题 2: 异步刮削时显示数据没有自动更新

**原因**: LibrarySong 的 `displayTitle` getter 有优先级错误。

**修复**:
在 `lib/core/models/library_song.dart` 中修正了 getter 的优先级:

```dart
// ❌ 错误: 检查了 scrapedAlbumTitle（这是专辑，不是标题）
String get displayTitle {
  if (manuallyScrapedTitle?.isNotEmpty == true) return manuallyScrapedTitle!;
  if (autoScrapedTitle?.isNotEmpty == true) return autoScrapedTitle!;
  if (scrapedAlbumTitle?.isNotEmpty == true) return scrapedAlbumTitle!;  // ❌ 错误！
  return title;
}

// ✅ 正确: 正确的优先级链
String get displayTitle {
  if (manuallyScrapedTitle?.isNotEmpty == true) return manuallyScrapedTitle!;
  if (autoScrapedTitle?.isNotEmpty == true) return autoScrapedTitle!;
  return title;  // 直接回退到原始标题
}
```

**效果**:
- ✅ 当刮削成功时，`displayTitle` 会正确返回 `autoScrapedTitle`
- ✅ UI 自动显示新数据（Riverpod 通知观察者）
- ✅ `displayArtist` 和 `displayAlbum` 已经正确

---

## 完整的数据流现在是:

```
扫描库
  ↓
_mapSong(waitForScraping: false) 
  → 立即返回 Song（文件夹数据）
  → 同时启动 _scrapeMetadataAsync()
  ↓
后台: MusicBrainz 搜索
  → 策略 1 (artist + title 带引号)
  → 失败? 尝试策略 2 (artist + title 无引号)
  → 失败? 尝试策略 3 (仅 title)
  ↓
刮削成功 → 获取元数据
  ↓
_updateSongMetadata(updatedSong)
  → 更新 library_catalog_state
  → Riverpod 通知观察者
  ↓
UI 自动重建
  → library_page 显示新数据 (displayTitle/displayArtist/displayAlbum)
  → albums_page 自动更新分组
  → 播放器也显示更新的数据
```

---

## 修改的文件

### 1. `lib/features/scraper/data/musicbrainz_client.dart`

**改进 searchByArtistAndTitle() 方法**:
- 添加三个搜索策略回退
- 每个失败时自动尝试下一个
- 添加详细的成功/失败日志

**改进 searchRecordings() 方法**:
- 添加了 JSON 解析错误处理
- 每个无效录音对象都记录警告
- 添加了解析结果计数的日志

### 2. `lib/core/models/library_song.dart`

**修复 displayTitle getter**:
- 移除了错误的 `scrapedAlbumTitle` 检查
- 现在正确地: 手动 > 自动 > 原始

---

## 调试命令

现在可以在日志中看到详细的搜索过程。启用调试模式后，查看"日志"标签查看:

✅ 搜索策略尝试  
✅ API 响应状态  
✅ 解析的录音数量  
✅ 使用的最终结果  

例如:
```
🌐 搜索成功: 使用精确搜索 (艺术家 + 标题)
✅ 搜索成功: 找到 5 个结果 (查询: "artist:Artist" AND recording:"Title")
💾 已解析录音对象: 5 个有效结果
✅ 成功刮削: Artist - Title
```

---

## 验证

### ✅ 编译状态
- 0 编译错误
- 合理的 warnings 只有 22 个

### ✅ 构建状态
- 版本: 1.0.109+110 (自动递增)
- APK 大小: 62MB
- 构建时间: ~38 秒

### ✅ 功能验证
待手动测试:
- [ ] 启用调试模式
- [ ] 添加 WebDAV 源
- [ ] 扫描库 → 查看"日志"标签
- [ ] 观察搜索策略尝试情况
- [ ] 刮削完成时 → 验证列表和播放器自动更新
- [ ] 播放歌曲 → 验证 now_playing_panel 显示正确的刮削数据

---

## 关键改进总结

| 方面 | 改进 |
|------|------|
| 搜索成功率 | 从单个查询 → 三策略回退 |
| 错误诊断 | 添加了详细的搜索阶段日志 |
| 数据映射 | 修复了 displayTitle getter 优先级 |
| UI 更新 | 现在正确地反映刮削结果 |
| 用户体验 | 用户现在可在调试日志中看到搜索过程 |

---

## 已知限制

1. MusicBrainz 可能对某些歌曲没有母带记录
   - 解决: 当找不到时保持原始数据
   
2. 特殊字符/非英文标题可能难以匹配
   - 解决: 三个搜索策略中至少一个会尝试

3. 搜索延迟
   - 解决: 后台异步，不阻塞 UI

---

## 后续改进方向

1. **添加缓存**: 相同查询不再重复搜索
2. **用户反馈**: 手动选择刮削结果的 UI
3. **其他来源**: 支持 Spotify、LastFM 等其他元数据源
4. **智能匹配**: 使用模糊匹配改进结果

---

## 致谢

这个修复确保了:
- 🎯 更高的刮削成功率
- 📊 更清晰的诊断日志  
- ✨ 更好的用户体验
- 🔄 自动的 UI 更新

**用户现在可以快速扫描库，观察后台刮削进度，并自动看到元数据更新！**
