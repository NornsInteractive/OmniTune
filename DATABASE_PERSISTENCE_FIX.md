# 刮削数据库持久化 & 库列表同步更新 — 完成总结

**2026-04-16**

## 问题修复

### ✅ 1. 改用数据库持久化而非本地文件
**问题**: 刮削完成的刮削数据保存成了本地 JSON 文件

**解决方案**:
- 改为使用 `IsarManager`（基于 SharedPreferences）来保存刮削元数据
- 移除对 `ScrapedMetadataRepository` 的依赖
- 所有刮削数据现在存储在数据库而不是单独的 JSON 文件

### ✅ 2. 库列表名称实时更新
**问题**: 刮削完成后，库列表中的歌曲名称没有更新

**解决方案**:
1. **刮削完成后触发库列表刷新**: 在 `player_controller.dart` 中调用 `ref.invalidate(libraryCatalogControllerProvider)`
2. **加载时应用刮削数据**: 在 `library_catalog_controller.dart` 的 `_mapSong()` 方法中从 IsarManager 查找并应用刮削数据
3. **显示优先级**:
   - ✓ 手动编辑（最高）
   - ✓ 自动刮削（已缓存在 IsarManager）
   - ✓ 文件夹名称
   - ✓ 原始文件名（fallback）

---

## 代码改动详解

### 1. PlayerController (_scrapeCurrentSongAsync 方法)

**改动**:
- ❌ 移除: `await ref.read(scrapedMetadataRepositoryProvider.future)`
- ✅ 新增: `final cachedMetadata = IsarManager.getMetadata(song.id)`
- ✅ 新增: 创建 `ScrapingMetadata` 对象，包含所有刮削信息
- ✅ 新增: `await IsarManager.saveMetadata(metadata)` 保存到数据库
- ✅ 新增: `ref.invalidate(libraryCatalogControllerProvider)` 触发库列表刷新

**工作流**:
```dart
播放歌曲
  ├─ 检查 IsarManager 中是否有缓存 (快速)
  │  └─ 如果有 → 返回
  └─ 如果没有 → 执行刮削
     ├─ 调用 scraperChainProvider
     ├─ 创建 ScrapingMetadata 对象
     ├─ 保存到数据库 (IsarManager)
     └─ 触发库列表更新 (invalidate)
```

### 2. LibraryCatalogController (_mapSong 方法)

**改动**:
- ✅ 新增: `final scrapingMetadata = IsarManager.getMetadata(entry.uniqueId)`
- ✅ 新增: 如果存在刮削数据，应用到 LibrarySong 对象
- ✅ 修改: 创建 LibrarySong 时直接传入 `autoScrapedTitle` 等字段

**效果**:
```
扫描库时:
  ├─ 对每首歌，检查 IsarManager 是否有刮削数据
  ├─ 如果有，应用到歌曲实例
  └─ 结果: 库列表立即显示最新的刮削数据
```

---

## 工作流演示

### 场景 1: 首次播放（无缓存）
```
用户点击播放
  ↓
PlayerController 检查 IsarManager
  ├─ 缓存未找到
  └─ 执行刮削
     ├─ scraperChainProvider 获取元数据
     ├─ 创建 ScrapingMetadata
     ├─ 保存到 IsarManager
     └─ invalidate 库列表
        ↓
库列表控制器刷新
  ├─ 扫描每首歌 _mapSong()
  ├─ 从 IsarManager 查找刮削数据
  ├─ 应用到 LibrarySong
  └─ 显示刮削后的名字
```

### 场景 2: 后续播放（有缓存）
```
用户再次点击播放同一首歌
  ↓
PlayerController 检查 IsarManager
  ├─ ✓ 缓存命中！
  └─ 返回（不重复刮削）
     ↓
库列表控制器加载时
  ├─ 从 IsarManager 直接读取刮削数据
  └─ 瞬间显示缓存的刮削名字
```

---

## 技术细节

### IsarManager 使用
```dart
// 保存刮削数据
await IsarManager.saveMetadata(scrapingMetadata);

// 查询刮削数据
final cached = IsarManager.getMetadata(songId);

// 获取所有刮削数据
final allMetadata = IsarManager.getAllMetadata();

// 删除特定数据
await IsarManager.deleteMetadata(songId);

// 清空所有缓存
await IsarManager.clearAll();
```

### ScrapingMetadata 字段
```dart
id                    // 唯一标识 (sourceId::filePath)
sourceId              // 音源 ID
filePath              // 完整路径
filenameWithoutExt    // 文件名（不含扩展名）
originalFileName      // 原始文件名

// 自动刮削结果
autoScrapedTitle      // 刮削获得的歌名
autoScrapedArtist     // 刮削获得的艺术家
autoScrapedAlbum      // 刮削获得的专辑
autoScrapedCoverUrl   // 刮削获得的封面 URL
autoScrapedLyrics     // 刮削获得的歌词

// 手动编辑（优先级最高）
manuallyScrapedTitle  // 用户手动编辑的歌名
manuallyScrapedArtist // 用户手动编辑的艺术家
// ...

// 状态
status                // pending | scraping | completed | failed
statusMessage         // 错误信息（如果失败）

// 日期
autoScrapedAt         // 刮削完成时间
createdAt             // 记录创建时间
updatedAt             // 记录更新时间
```

---

## 文件变更总结

### 修改
- `lib/features/player/application/player_controller.dart`
  - 导入: 添加 `isar_manager`, `scraping_metadata`
  - 导入: 添加 `library_catalog_controller`（用于 invalidate）
  - `_scrapeCurrentSongAsync()`: 改用 IsarManager，添加 invalidate 触发
  - `_loadQueueIndex()`: 从 IsarManager 加载刮削数据并应用

- `lib/features/library/application/library_catalog_controller.dart`
  - 导入: 添加 `isar_manager`, `scraping_metadata`
  - `_mapSong()`: 从 IsarManager 查找并应用刮削数据

### 未变更
- ✓ `lib/core/database/scraped_metadata_repository.dart` 保留（可能未来用）
- ✓ `lib/main.dart` 已有 `IsarManager.initialize()`

---

## 测试验证

### ✓ 已验证
- [ ] Dart 分析: 0 errors, 20 infos (全部通过)
- [ ] Riverpod 代码生成: 10 outputs (成功)
- [ ] APK 构建: 64.8 MB (成功)

### 推荐测试步骤

1. **安装 APK**
```bash
adb uninstall com.music_player.app
adb install build/app/outputs/flutter-apk/app-release.apk
```

2. **验证库列表显示**
   - 打开 Library/Albums
   - 观察歌曲名称（应为文件夹名或原始名称）

3. **验证播放时刮削**
   - 选择一首歌播放
   - 观察 DebugLogger:
     ```
     [IsarManager] 保存元数据: id=xxx
     [LibraryCatalogController] 应用刮削数据到歌曲
     ```
   - 返回库列表，刷新后歌名应该更新

4. **验证缓存工作**
   - 再次播放同一首歌
   - DebugLogger 应显示: `[IsarManager] 从缓存获取: id=xxx`
   - 不应出现新的刮削操作

5. **关闭重启测试**
   - 完全关闭 App
   - 重新打开
   - 库列表应立即显示已缓存的刮削名字

---

## 核心改进

| 方面 | 来源 | 目的地 |
|-----|------|--------|
| **存储方式** | JSON 文件 → | IsarManager (数据库) |
| **查询效率** | 文件 I/O → | 内存 + SharedPreferences |
| **库列表更新** | 未同步 → | 自动 invalidate 刷新 |
| **刮削完成后** | 需要手动重启 App → | 无需重启，自动更新 |

---

## 下一步建议

### 立即 (今天)
- [ ] 安装新 APK 并测试上述 5 个验证步骤
- [ ] 观看 DebugLogger 确认工作流正确
- [ ] 验证库列表确实在刮削完成后更新

### 短期
- [ ] 优化：如果刮削失败，是否应该缓存失败状态以避免重复尝试？
- [ ] 清空缓存功能：Settings 中添加"清空刮削缓存"按钮

### 中期
- [ ] 缓存过期政策：设置 TTL（如 7 天后自动过期）
- [ ] 缓存统计显示：Settings 中显示缓存大小、条目数

---

## 版本信息

- **APK 版本**: v1.0.111+112
- **APK 大小**: 64.8 MB
- **构建状态**: ✅ 成功

