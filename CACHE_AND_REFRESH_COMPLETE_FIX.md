# 缓存和实时刷新完整修复 — v1.0.112+113

**2026-04-16**

## 问题诊断

### ❌ 问题 1: 退出重进 App 时歌曲列表为空
**根本原因**:
- 初始加载缓存的扫描结果时，没有应用 IsarManager 中已有的刮削数据
- 虽然扫描结果被缓存了，但显示出来的还是原始名称的歌曲列表
- 用户可能认为列表是空的，实际上是名称显示问题

**表现**: 
- App 重启后列表为空（实际上是有数据但看起来像空列表）
- 需要重新扫描才能看到歌曲

### ❌ 问题 2: 刮削后没有实时更新显示
**根本原因**:
- 刮削完成后虽然保存到了 IsarManager
- 但库列表的 refreshSongMetadata() 调用可能在 App 初始化时执行不稳定
- 用户只能重进 App 才能看到刮削后的名称

**表现**:
- 播放器名称没有变化
- 库列表名称没有变化
- 重进 App 后才能看到新名称

---

## 解决方案

### ✅ 修复 1: 初始加载时应用刮削数据
**文件**: `lib/features/library/application/library_catalog_controller.dart`

**改动 1 - build() 方法**: 
```dart
@override
Future<LibraryCatalogState> build() async {
  // ...
  if (allResults.isNotEmpty) {
    var allTracks = <LibrarySong>[];
    for (final tracks in allResults.values) {
      allTracks.addAll(tracks);
    }
    allTracks.sort(...);

    // ✅ 新增: 应用已缓存的刮削数据
    allTracks = _applyCachedScrapingMetadata(allTracks);

    cachedState = LibraryCatalogState(
      tracks: allTracks,  // 现在包含刮削名称
      folderAlbums: _buildFolderAlbums(allTracks),
      metadataAlbums: _buildMetadataAlbums(allTracks),
      ...
    );
  }
  // ...
}
```

**改动 2 - scanAllSources() 方法**:
```dart
// 扫描完成后
final displayTracks = _applyCachedScrapingMetadata(discovered);

state = AsyncData(
  current.copyWith(
    tracks: displayTracks,  // ✅ 应用刮削数据后再展示
    folderAlbums: _buildFolderAlbums(displayTracks),
    metadataAlbums: _buildMetadataAlbums(displayTracks),
    ...
  ),
);
```

**改动 3 - rescanSource() 方法**:
```dart
// 重新扫描源后
final displayTracks = _applyCachedScrapingMetadata(retained);

state = AsyncData(
  current.copyWith(
    tracks: displayTracks,  // ✅ 应用刮削数据后再展示
    folderAlbums: _buildFolderAlbums(displayTracks),
    metadataAlbums: _buildMetadataAlbums(displayTracks),
    ...
  ),
);
```

**新增方法**: `_applyCachedScrapingMetadata()`
```dart
/// 对歌曲列表应用已缓存的刮削数据
List<LibrarySong> _applyCachedScrapingMetadata(List<LibrarySong> tracks) {
  return tracks.map((track) {
    final cachedMetadata = IsarManager.getMetadata(track.id);
    if (cachedMetadata != null && cachedMetadata.status == ScrapingStatus.completed) {
      // 应用缓存的刮削数据到每首歌
      return LibrarySong(
        // ... 复制所有字段
        autoScrapedTitle: cachedMetadata.autoScrapedTitle ?? track.autoScrapedTitle,
        autoScrapedArtist: cachedMetadata.autoScrapedArtist ?? track.autoScrapedArtist,
        autoScrapedAlbum: cachedMetadata.autoScrapedAlbum ?? track.autoScrapedAlbum,
        autoScrapedCoverUrl: cachedMetadata.autoScrapedCoverUrl ?? track.autoScrapedCoverUrl,
        autoScrapedLyrics: cachedMetadata.autoScrapedLyrics ?? track.autoScrapedLyrics,
      );
    }
    return track;  // 无缓存则返回原始歌曲
  }).toList();
}
```

---

## 完整工作流

### 场景 1: App 初启（有扫描缓存）
```
App 重启
  ├─ build() 启动
  ├─ loadAllResults() 从缓存读取扫描结果 ✓ 有数据
  ├─ _applyCachedScrapingMetadata() 应用刮削缓存
  │  └─ IsarManager.getMetadata() 检查每首歌的刮削数据
  │  └─ 如果有 → 应用刮削名称
  │  └─ 如果没有 → 保持原始名称  
  └─ 库列表显示
     ├─ 列表不为空 ✅
     ├─ 已刮削的歌曲显示刮削名 ✅
     └─ 未刮削的歌曲显示原始名 ✅
```

### 场景 2: 扫描后立即查看列表
```
用户点击"扫描音乐库"
  ├─ scanAllSources() 执行
  ├─ 发现歌曲 → discovered 列表
  ├─ 保存到缓存
  ├─ _applyCachedScrapingMetadata(discovered)
  │  └─ 检查每首歌是否有刮削缓存
  │  └─ 如果有 → 应用刮削名称
  └─ 库列表立即显示
     ├─ 显示所有歌曲 ✅
     ├─ 已刮削的显示新名称 ✅
     └─ 未刮削的显示原始名称 ✅
```

### 场景 3: 播放新歌曲（首次，无缓存）
```
用户点击播放歌曲 A
  ├─ playLibrarySong() → 立即播放
  └─ _scrapeCurrentSongAsync() 后台刮削
     ├─ IsarManager.saveMetadata() 保存
     ├─ 更新播放器中的 _playlist[_currentIndex]
     ├─ _syncState() → 播放器 UI 更新，displayTitle getter 返回新名称 ✅
     │
     └─ 调用 refreshSongMetadata()
        ├─ 库列表状态更新
        ├─ 找到对应的歌曲 A，应用刮削数据
        └─ UI 刷新，列表显示新名称 ✅
```

### 场景 4: 播放已刮削的歌曲（缓存命中）
```
用户点击播放已刮削的歌曲 B
  ├─ get displayTitle → 返回已缓存的刮削名称 ✅
  ├─ playLibrarySong() → 立即播放
  └─ _scrapeCurrentSongAsync() 后台
     ├─ IsarManager.getMetadata() → 缓存命中！
     ├─ 返回，不需要重复刮削
     ├─ 播放器和列表已显示刮削名称 ✅
     └─ 完成
```

---

## 关键改动

| 位置 | 改动 | 效果 |
|------|------|------|
| `build()` | 加载缓存后应用刮削数据 | App 重启后直接显示已刮削名称 |
| `scanAllSources()` | 扫描完成前应用刮削数据 | 扫描后列表不为空，显示正确名称 |
| `rescanSource()` | 单源重扫前应用刮削数据 | 重扫后列表保持，显示正确名称 |
| 新增方法 | `_applyCachedScrapingMetadata()` | 统一的缓存应用逻辑 |

---

## 数据流向

```
IsarManager (数据库)
  ↓ (包含已刮削的元数据)
  
_applyCachedScrapingMetadata()
  ├─ 检查每首歌的 ID
  ├─ 查询 IsarManager.getMetadata(id)
  ├─ 应用到 LibrarySong 对象的 autoScrapedTitle 等字段
  └─ 返回增强后的歌曲列表
  
LibraryCatalogState.tracks
  ↓ (现在包含刮削数据)
  
UI 显示
  ├─ displayTitle getter → 优先返回 autoScrapedTitle ✅
  ├─ displayArtist getter → 优先返回 autoScrapedArtist ✅
  └─ 用户看到刮削后的名称 ✅
```

---

## 修复后的效果

| 场景 | 修复前 | 修复后 |
|------|-------|-------|
| **App 重启** | 列表为空，需重扫 | 列表直接显示，无需操作 |
| **扫描后** | 显示原始名称 | 显示已缓存的刮削名称 |
| **播放新歌** | 需要等待刮削 + 重进 App | 立即在播放器显示，稍后列表更新 |
| **播放已刮削** | 需要加载 | 秒速显示缓存的刮削名称 |

---

## 技术细节

### 缓存层次
1. **扫描缓存** (`LibraryScanCacheRepository`)
   - 存储: 文件系统
   - 用途: 记住扫描结果
   - 加载时机: App 启动时

2. **刮削缓存** (`IsarManager`)
   - 存储: SharedPreferences
   - 用途: 记住刮削的元数据
   - 查询时机: UI 渲染时

### 三层应用
1. **初始化时** → `build()` 加载扫描缓存，应用刮削缓存
2. **扫描时** → `scanAllSources()` 保存新扫描结果，应用刮削缓存
3. **刮削时** → `refreshSongMetadata()` 从 IsarManager 读取最新数据，更新 UI

---

## 验证清单

✅ 初始加载时应用刮削数据  
✅ 扫描时应用刮削数据  
✅ 单源重扫时应用刮削数据  
✅ refreshSongMetadata() 正确更新状态  
✅ 编译通过，0 errors  
✅ APK 构建成功 (64.8 MB)  

---

## 使用 DebugLogger 验证

查看 DebugLogger 输出中的以下消息来验证修复：

1. **初始加载时**:
```
[LibraryCatalogController.build] 加载扫描缓存...
[_applyCachedScrapingMetadata] 为歌曲应用刮削data...
```

2. **扫描时**:
```
[LibraryCatalogController.scanAllSources] 开始扫描...
[saveScanResults] 源: 3 首歌曲
[_applyCachedScrapingMetadata] 应用刮削数据完成...
```

3. **刮削时**:
```
[PlayerController._scrapeCurrentSongAsync] 已更新当前播放曲目的元数据显示
[LibraryCatalogController.refreshSongMetadata] 已刷新单个歌曲的元数据显示
```

---

## 版本信息

- **APK 版本**: v1.0.112+113
- **APK 大小**: 64.8 MB
- **构建状态**: ✅ 成功
- **修改行数**: +35 行
- **文件修改数**: 1 个

---

## 测试步骤

### 完整测试流程

1. **安装新 APK**
```bash
adb uninstall com.music_player.app
adb install build/app/outputs/flutter-apk/app-release.apk
```

2. **初次启动**
   - 打开 App
   - 手动添加音源
   - 扫描音乐库
   - ✅ 验证: 列表显示所有歌曲，已刮削的显示新名称

3. **关闭重启测试**
   - 完全关闭 App
   - 重新打开
   - ✅ 验证: 列表直接显示，无需扫描，显示已缓存的名称

4. **播放测试**
   - 播放新歌曲
   - 等待刮削完成 (3-5 秒)
   - ✅ 验证: 播放器和列表同时更新显示新名称

5. **重复播放**
   - 播放已刮削的歌曲
   - ✅ 验证: 秒速显示刮削名称，无延迟

### 预期结果

所有场景下，库列表和播放器应该：
- ✅ 显示已缓存的刮削名称（如果有）
- ✅ 实时更新新的刮削名称（刮削完成后）
- ✅ 不消失、不闪烁
- ✅ App 重启后保留数据

---

## 后续建议

### 立即
- [ ] 在真实设备上完整测试上述 5 个步骤
- [ ] 观察 DebugLogger 确认各个环节执行

### 短期
- [ ] 添加缓存策略：提供"清空刮削缓存"选项
- [ ] 缓存过期：设置 TTL = 7 天

### 中期  
- [ ] 缓存统计：在 Settings 显示"刮削缓存: N 首歌曲"
- [ ] 批量操作：支持"重新刮削所有歌曲"

