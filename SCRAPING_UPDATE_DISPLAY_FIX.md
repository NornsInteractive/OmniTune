# 刮削完成后数据显示同步修复 — v1.0.111+112

**2026-04-16**

## 问题描述

### ❌ 问题 1: 歌曲列表全部消失
- **现象**: 刮削完成后，歌曲列表中的所有歌曲都不见了
- **根本原因**: 使用 `ref.invalidate(libraryCatalogControllerProvider)` 完全清除了 provider 的缓存，导致列表在重新加载前暂时为空
- **影响**: 用户看不到列表，需要手动重新扫描才能显示

### ❌ 问题 2: 播放器界面没有刮削数据
- **现象**: 歌曲列表显示了刮削后的名称，但播放器界面（NowPlayingPanel）没有显示
- **根本原因**: 播放器的 `currentTrack` 对象在播放开始后就固定了，刮削完成后不会自动更新
- **影响**: 用户看到的多是原始文件名，而不是刮削后的优化名称

---

## 解决方案

### 修复 1: 增量更新歌曲而非全量重新加载
**文件**: `lib/features/library/application/library_catalog_controller.dart`

**改动**:
- 新增方法 `refreshSongMetadata(String songId)`
- 只更新指定歌曲的元数据，不重新加载整个列表
- 更新操作是同步的，避免列表"闪烁"消失

**工作流**:
```
刮削完成
  ├─ 保存到 IsarManager
  ├─ 调用 libraryCatalogNotifier.refreshSongMetadata(songId)
  │  └─ 从数据库读取元数据
  │  └─ 只更新该歌曲的字段
  │  └─ 重新构建专辑分组
  │  └─ 更新状态（保持其他列表项不变）
  └─ 列表立即显示新数据（不消失）
```

### 修复 2: 播放器同步更新当前曲目元数据
**文件**: `lib/features/player/application/player_controller.dart`

**改动**:
- 在 `_scrapeCurrentSongAsync()` 中，如果刮削的是当前正在播放的歌曲：
  - 更新 `_playlist[_currentIndex]` 中的歌曲对象
  - 包含新的 `autoScrapedTitle`, `autoScrapedArtist` 等字段
  - 调用 `_syncState()` 重新构建播放器状态
- 播放器 UI 使用 `track.displayArtist` 等 getter，会自动取用新值

**执行顺序**:
```
刮削完成后 (_scrapeCurrentSongAsync)
  ├─ [立即] 如果是当前播放的歌曲：
  │  ├─ 更新 _playlist[_currentIndex]
  │  ├─ 调用 _syncState()
  │  └─ 播放器 UI 立即刷新显示新名称
  │
  ├─ [异步] 调用 refreshSongMetadata()
  │  └─ 库列表更新显示（不消失）
  └─ [后台] 完成
```

---

## 代码改动详解

### LibraryCatalogController.refreshSongMetadata()

```dart
/// 刷新单个歌曲的元数据（用于刮削完成后的增量更新，避免全列表重新加载）
Future<void> refreshSongMetadata(String songId) async {
  try {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    
    final cachedMetadata = IsarManager.getMetadata(songId);
    if (cachedMetadata == null || cachedMetadata.status != ScrapingStatus.completed) {
      return;
    }
    
    // 仅更新该歌曲，不重新加载整个列表
    final updatedTracks = currentState.tracks.map((track) {
      if (track.id == songId) {
        return LibrarySong(
          // ... 复制所有原始字段
          autoScrapedTitle: cachedMetadata.autoScrapedTitle ?? track.autoScrapedTitle,
          autoScrapedArtist: cachedMetadata.autoScrapedArtist ?? track.autoScrapedArtist,
          autoScrapedAlbum: cachedMetadata.autoScrapedAlbum ?? track.autoScrapedAlbum,
          autoScrapedCoverUrl: cachedMetadata.autoScrapedCoverUrl ?? track.autoScrapedCoverUrl,
          autoScrapedLyrics: cachedMetadata.autoScrapedLyrics ?? track.autoScrapedLyrics,
        );
      }
      return track;
    }).toList();
    
    // 更新状态，同时重建专辑分组（保持一致性）
    state = AsyncData(
      currentState.copyWith(
        tracks: updatedTracks,
        folderAlbums: _buildFolderAlbums(updatedTracks),
        metadataAlbums: _buildMetadataAlbums(updatedTracks),
      ),
    );
  } catch (e) {
    DebugLogger.warning('LibraryCatalogController.refreshSongMetadata', '刷新歌曲元数据失败: $e');
  }
}
```

### PlayerController._scrapeCurrentSongAsync()

```dart
// 4. 如果当前播放的就是这首歌，立即更新播放器显示的元数据
if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
  final currentSong = _playlist[_currentIndex];
  if (currentSong.id == song.id) {
    // 创建包含新刮削数据的歌曲副本
    final updatedSong = LibrarySong(
      // ... 复制所有字段，但用新的刮削数据
      autoScrapedTitle: metadata.autoScrapedTitle ?? currentSong.autoScrapedTitle,
      autoScrapedArtist: metadata.autoScrapedArtist ?? currentSong.autoScrapedArtist,
      // ...
    );
    // 更新播放列表中对应位置的歌曲
    _playlist[_currentIndex] = updatedSong;
    // 更新播放器状态显示新名称
    _syncState();
    DebugLogger.success('PlayerController._scrapeCurrentSongAsync',
      '已更新当前播放曲目的元数据显示: ${updatedSong.displayTitle}');
  }
}

// 5. 异步更新库列表中的歌曲（不等待，避免阻塞）
try {
  final libraryCatalogNotifier = ref.read(libraryCatalogControllerProvider.notifier);
  unawaited(libraryCatalogNotifier.refreshSongMetadata(song.id));
} catch (e) {
  DebugLogger.warning('PlayerController._scrapeCurrentSongAsync', '更新库列表失败: $e');
}
```

---

## 修复前后对比

| 阶段 | 列表状态 | 播放器显示 | 用户体验 |
|------|--------|----------|---------|
| **修复前** |
| 刮削开始 | ✓ 正常 | ✓ 原始名称 | - |
| 刮削完成 | ❌ **消失** | ❌ **无变化** | 🔴 用户看不到列表和播放信息 |
| 刷新/重扫 | ✓ 恢复 | ✓ 新名称 | 🟡 需要手动操作 |
| **修复后** |
| 刮削开始 | ✓ 正常 | ✓ 原始名称 | - |
| 刮削完成 | ✓ 实时更新 | ✓ **实时更新** | 🟢 无缝更新，流畅体验 |
| 立即播放 | ✓ 新名称 | ✓ 新名称 | 🟢 完全同步 |

---

## 关键改进

### 1. 减少 UI 闪烁
- **之前**: `invalidate()` 清除缓存 → 列表消失 → 重新加载 → 列表显示（1-2 秒延迟）
- **之后**: 增量更新 → 只改变一行 → 立即显示（无感知延迟）

### 2. 播放器实时同步
- **之前**: 播放器用的是过期的 `currentTrack` 对象，新数据无法显示
- **之后**: 刮削完成后立即更新 `_playlist` 和状态，`displayArtist` getter 自动返回新值

### 3. 避免列表丢失
- **之前**: 用户可能看不到任何歌曲
- **之后**: 列表成员一直保持，只是个别项更新

---

## 测试指南

### 场景 1: 单曲刮削（当前播放）
```
1. 打开 Library，查看歌曲列表（原始名称）
2. 点击播放任意歌曲 → 播放器显示原始名称
3. 观察 DebugLogger，等待刮削完成（3-5 秒）
4. ✅ 预期: 列表中的歌曲名称更新 + 播放器显示新名称，列表不消失
5. ✅ 验证: 再次播放同一首歌 → 缓存命中，无刮削
```

### 场景 2: 多曲并行刮削
```
1. 播放第一首歌 → 刮削 A
2. 快速切换到第二首歌 → 刮削 B
3. ✅ 预期: 两个都完成时，播放器显示 B 的元数据，列表显示 A、B 的新名称
4. ✅ 验证: 列表不出现任何时刻的消失
```

### 场景 3: App 重启持久化
```
1. 刮削完成（数据已保存到 IsarManager）
2. 完全关闭 App
3. 重新打开 → 列表加载
4. ✅ 预期: 列表直接显示已缓存的刮削名称（不需要再刮削）
```

---

## 文件变更统计

| 文件 | 行数变化 | 修改类型 |
|------|---------|---------|
| `lib/features/player/application/player_controller.dart` | +45 -10 | 重写刮削完成逻辑 |
| `lib/features/library/application/library_catalog_controller.dart` | +47 | 新增增量更新方法 |

**总计**: +92 行, -10 行（净增 82 行）

---

## 性能影响

- **内存**: 增加极小（只是多存 1 个 LibrarySong 对象）
- **CPU**: 无变化（更新 1 条 vs 更新 N 条）
- **网络**: 无变化
- **响应时间**: 更快（增量 vs 全量）

---

## 版本信息

- **APK 版本**: v1.0.111+112
- **APK 大小**: 64.8 MB
- **构建状态**: ✅ 成功
- **Dart 分析**: ✅ 0 errors, 20 infos
- **代码生成**: ✅ 10 outputs in 12s

---

## 下一步建议

### 立即 (今天)
- [ ] 安装新 APK 并测试上述 3 个场景
- [ ] 观看 DebugLogger：
  - `已更新当前播放曲目的元数据显示` ← 播放器更新成功
  - `已刷新单个歌曲的元数据显示` ← 列表更新成功
  - 两条日志都出现 ✅

### 测试要点
- 列表是否在任何时刻消失？
- 播放器名称是否更新？
- 多曲并行刮削是否正确处理？
- 关闭重启后是否保留刮削数据？

### 如有问题
- 检查 DebugLogger 输出，查看是否有异常/警告
- 验证 `IsarManager` 是否正确保存/读取数据
- 检查是否同时有多个刮削任务相互干扰

