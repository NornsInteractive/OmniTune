# 扫描结果持久化 - 快速参考

## 核心概念

| 组件 | 位置 | 职责 |
|------|------|------|
| **LibraryScanCacheRepository** | `lib/core/database/` | 管理缓存的 CRUD 操作 |
| **LibrarySong** | `lib/core/models/` | 提供 JSON 序列化方法 |
| **LibraryCatalogController** | `lib/features/library/application/` | 在启动/扫描时调用缓存 |
| **scan_cache_provider** | `lib/core/providers/` | Riverpod 提供者 |

## 工作流程

### 启动应用
```dart
build() {
  // 1. 加载缓存
  final cacheRepo = await createScanCacheRepository();
  final allResults = await cacheRepo.loadAllResults();
  
  // 2. 如果缓存存在，快速恢复 UI
  if (allResults.isNotEmpty) {
    return LibraryCatalogState(tracks: allTracks, ...);
  }
  
  // 3. 否则返回空状态
  return LibraryCatalogState.empty();
}
```

### 扫描音乐
```dart
scanAllSources() {
  // 1. 执行扫描
  final discovered = await _performScan();
  
  // 2. 保存到缓存
  final cacheRepo = await createScanCacheRepository();
  for (final source in sources) {
    final sourceSongs = discovered.where(
        (s) => s.sourceId == source.id).toList();
    await cacheRepo.saveScanResults(source.id, sourceSongs);
  }
  
  // 3. 更新 UI
  state = state.copyWith(tracks: discovered);
}
```

## 常见操作

### 加载缓存
```dart
final cacheRepo = await createScanCacheRepository();
final allResults = await cacheRepo.loadAllResults();
// allResults: Map<String, List<LibrarySong>>
```

### 保存扫描结果
```dart
await cacheRepo.saveScanResults('source-id', songList);
```

### 删除特定源的缓存
```dart
await cacheRepo.deleteScanResults('source-id');
```

### 清空所有缓存
```dart
await cacheRepo.clearAll();
```

## 数据流

```
用户启动应用
    ↓
LibraryCatalogController.build()
    ↓
createScanCacheRepository() 创建仓储
    ↓
loadAllResults() 加载所有源的缓存
    ↓
解析 JSON，转换为 LibrarySong
    ↓
_buildFolderAlbums() / _buildMetadataAlbums()
    ↓
返回 LibraryCatalogState（包含加载的数据）
    ↓
UI 显示缓存的库
    ↓
用户点击"扫描"
    ↓
scanAllSources() 执行扫描
    ↓
saveScanResults() 保存到缓存
    ↓
state.copyWith(tracks: discovered)
    ↓
UI 更新显示新扫描的数据
```

## 依赖关系

```
lib/core/models/library_song.dart
  - 提供 toJson() / fromJson()

lib/core/database/library_scan_cache_repository.dart
  - 依赖: path_provider, dart:io, dart:convert
  - 与 LibrarySong 配合使用

lib/core/providers/scan_cache_provider.dart
  - 依赖: flutter_riverpod
  - 提供 createScanCacheRepository()

lib/features/library/application/library_catalog_controller.dart
  - 依赖: library_scan_cache_repository, LibrarySong
  - 在 build() 和 scan 方法中使用
```

## 错误处理

所有缓存操作都应该被 try-catch 包装：

```dart
try {
  final cacheRepo = await createScanCacheRepository();
  await cacheRepo.saveScanResults(sourceId, songs);
} catch (e) {
  // 日志记录，但不中断主流程
  debugPrint('缓存保存失败: $e');
}
```

## 文件格式

缓存文件位置：`{appCacheDir}/library_scan_cache.json`

格式：
```json
{
  "source-id-1": [
    {
      "id": "...",
      "sourceId": "source-id-1",
      "title": "Song Title",
      "remotePath": "/path/to/song.flac",
      ...
    }
  ],
  "source-id-2": [ ... ]
}
```

## 调试技巧

### 查看缓存内容
```dart
final cacheRepo = await createScanCacheRepository();
final allResults = await cacheRepo.loadAllResults();
debugPrint('缓存中的源: ${allResults.keys}');
for (final (sourceId, songs) in allResults.entries) {
  debugPrint('$sourceId: ${songs.length} 首歌曲');
}
```

### 清空缓存进行重新扫描
```dart
final cacheRepo = await createScanCacheRepository();
await cacheRepo.clearAll();
// 然后执行扫描
```

### 验证 JSON 序列化
```dart
final song = LibrarySong(...);
final json = song.toJson();
final restored = LibrarySong.fromJson(json);
assert(song.id == restored.id);
```

## 下一步

- [ ] 在设置页面添加"清空缓存"按钮
- [ ] 显示缓存统计信息（歌曲数、文件大小）
- [ ] 实现缓存压缩（gzip）
- [ ] 添加缓存版本控制
- [ ] 考虑迁移到 Isar 数据库

---

**最后更新**: 2026年4月5日  
**版本**: 1.0.20+21
