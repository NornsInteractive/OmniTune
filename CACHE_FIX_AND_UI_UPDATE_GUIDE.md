# 缓存持久化 + UI 实时更新修复指南

## 📋 问题分析

你遇到的两个问题都已诊断并修复：

### 问题 1: App 重启后显示空列表
**根本原因**：缓存文件损坏（UTF-8 解码失败）→ 加载失败 → 显示空列表

**症状**：
```
[JsonFileScanCacheRepository.loadAllResults] 加载缓存失败: FileSystemException: Failed to decode data using encoding 'utf-8'
```

**修复**：
- ✅ 添加了文件读取异常处理
- ✅ 缓存文件损坏时自动删除
- ✅ 下次重新扫描时重建有效缓存
- ✅ 详细日志记录文件问题

### 问题 2: 刮削完成后 UI 未实时更新
**根本原因**：
1. `refreshSongMetadata` 声明为 async，但调用时用了 `unawaited` → 时序问题
2. 库可能还在加载中 → currentState 为 null → 更新失败
3. Riverpod 状态变化没有正确通知 UI

**修复**：
- ✅ `refreshSongMetadata` 改为同步方法（消除 async/await 时序问题）
- ✅ 直接调用而不使用 `unawaited`
- ✅ 当库未加载时日志记录而非崩溃
- ✅ 所有异常都有详细日志输出

---

## 🔍 版本信息
- **当前版本**：`1.0.119+120`
- **包含修复的文件**：
  - `lib/core/database/library_scan_cache_repository.dart`
  - `lib/features/library/application/library_catalog_controller.dart`
  - `lib/features/player/application/player_controller.dart`

---

## 📊 新增日志点

### 缓存文件恢复（JsonFileScanCacheRepository）

#### loadAllResults() - 9 个日志点
```
[JsonFileScanCacheRepository.loadAllResults] 开始加载所有缓存结果
[JsonFileScanCacheRepository.loadAllResults] 缓存文件路径: /data/user/0/.../library_scan_cache.json
[JsonFileScanCacheRepository.loadAllResults] 文件是否存在: true/false

# 文件读取阶段
[JsonFileScanCacheRepository.loadAllResults] 读取文件内容
[JsonFileScanCacheRepository.loadAllResults] ❌ 文件读取异常（可能编码问题）: FileSystemException
[JsonFileScanCacheRepository.loadAllResults] 尝试删除损坏的文件并返回空结果
[JsonFileScanCacheRepository.loadAllResults] ✅ 已删除损坏的缓存文件

# JSON 解析阶段
[JsonFileScanCacheRepository.loadAllResults] 解析 JSON，文件大小: XXX 字符
[JsonFileScanCacheRepository.loadAllResults] ❌ JSON 解析失败: FormatException
[JsonFileScanCacheRepository.loadAllResults] 文件内容（前 200 字符）: {corrupted json...}
[JsonFileScanCacheRepository.loadAllResults] ✅ 已删除包含非法 JSON 的缓存文件

# 成功加载
[JsonFileScanCacheRepository.loadAllResults] ✅ 成功加载 N 个源的缓存
```

#### saveScanResults() - 详细的保存流程
```
[JsonFileScanCacheRepository.saveScanResults] 开始保存扫描结果: sourceId=music, 歌曲数=10
[JsonFileScanCacheRepository.saveScanResults] 缓存文件路径: /data/user/0/.../library_scan_cache.json
[JsonFileScanCacheRepository.saveScanResults] 缓存文件已存在，读取现有数据
[JsonFileScanCacheRepository.saveScanResults] 已读取现有数据，现有源数: 1
[JsonFileScanCacheRepository.saveScanResults] 开始序列化 10 首歌曲为 JSON
[JsonFileScanCacheRepository.saveScanResults] 序列化完成，现在有 1 个源
[JsonFileScanCacheRepository.saveScanResults] 开始写入文件: /data/user/0/.../library_scan_cache.json
[JsonFileScanCacheRepository.saveScanResults] ✅ 保存成功: sourceId=music, 歌曲数=10
```

### UI 实时更新（refreshSongMetadata）

```
[LibraryCatalogController.refreshSongMetadata] 开始刷新歌曲元数据: song-id-123
[LibraryCatalogController.refreshSongMetadata] 当前状态是否为空: false
[LibraryCatalogController.refreshSongMetadata] 查询缓存元数据: 找到=true
[LibraryCatalogController.refreshSongMetadata] 元数据状态: completed, 是否为completed: true
[LibraryCatalogController.refreshSongMetadata] 找到要更新的歌曲: Old Song Title -> New Song Title
[LibraryCatalogController.refreshSongMetadata] 构建新状态并触发 UI 更新
[LibraryCatalogController.refreshSongMetadata] ✅ 已刷新单个歌曲的元数据显示: song-id-123
```

---

## ✅ 预期行为测试步骤

### 测试 1: 缓存加载恢复

1. **卸载旧版本 App**
2. **安装新 APK**（v1.0.119+120）
3. **打开 App**
   - 预期日志：`[LibraryCatalogController.build] 加载缓存结果: 0 个源`（首次为空）
4. **点击扫描**
   - 预期日志：
     ```
     [开始保存扫描结果到缓存]
     [JsonFileScanCacheRepository.saveScanResults] ✅ 保存成功: sourceId=music, 歌曲数=XX
     [所有扫描结果已保存到缓存]
     ```
5. **列表显示歌曲** ✅
6. **完全关闭 App**（不是后台）
7. **重新打开 App**
   - 预期日志：`[LibraryCatalogController.build] 加载缓存结果: 1 个源`
   - 预期结果：**歌曲列表立即显示，无需重新扫描** ✅

### 测试 2: 刮削后 UI 动态更新

1. **确保库已加载**（有歌曲显示）
2. **播放一首歌**
3. **等待刮削完成**
   - 预期日志：`[刮削完成并已保存到数据库]`
4. **检查列表和播放器**
   - 预期：歌曲名称已更新为刮削到的名称 ✅
   - 预期日志：`[LibraryCatalogController.refreshSongMetadata] ✅ 已刷新单个歌曲的元数据显示: song-id`

### 测试 3: 缓存文件损坏恢复

1. **手动破坏缓存文件**（编辑 `/data/user/0/com.example.music/cache/library_scan_cache.json` 为无效内容）
2. **重启 App**
   - 预期日志：
     ```
     [JsonFileScanCacheRepository.loadAllResults] ❌ 文件读取异常（可能编码问题）
     [JsonFileScanCacheRepository.loadAllResults] ✅ 已删除损坏的缓存文件
     [加载缓存结果: 0 个源]
     ```
3. **重新扫描**
   - App 应该正常工作，生成新的有效缓存 ✅

---

## 🐛 故障排除

### 症状：列表仍然为空

**检查这些日志**：
```
1. [加载缓存结果: 0 个源] → 缓存为空或未加载
2. [❌ 文件读取异常] → 缓存文件损坏
3. [❌ JSON 解析失败] → 缓存文件格式错误
```

**解决**：
- 手动清除 App 数据
- 重新安装 App
- 重新扫描

### 症状：刮削后名字没有变化

**检查这些日志**：
```
1. 有 [刮削完成并已保存到数据库] → 刮削成功
2. 没有 [已刷新单个歌曲的元数据显示] → refreshSongMetadata 未被调用或失败
3. [当前状态是否为空: true] → 库还在加载，不能立即更新
```

**解决**：
- 等待库加载完成（看到歌曲列表）
- 再播放歌曲进行刮削
- 检查是否看到 UI 更新日志

### 症状：缓存文件路径错误

**检查日志中的实际路径**：
```
[缓存文件路径: /data/user/0/com.example.music/cache/library_scan_cache.json]
```

**验证**：
- 路径应该在应用沙箱内
- 文件应该自动创建
- 如果找不到，检查文件权限

---

## 📝 关键代码改动

### 1. loadAllResults() 异常处理

```dart
// 文件读取异常 → 自动删除损坏文件
try {
  content = await file.readAsString();
} catch (e) {
  DebugLogger.error('...', 'UTF-8 解码失败: $e');
  await file.delete();
  return {};
}

// JSON 解析异常 → 自动删除
try {
  allData = jsonDecode(content) as Map<String, dynamic>;
} catch (e) {
  DebugLogger.error('...', 'JSON 解析失败: $e');
  await file.delete();
  return {};
}
```

### 2. refreshSongMetadata 同步化

```dart
// 原来：Future<void> refreshSongMetadata(String songId) async
// 现在：void refreshSongMetadata(String songId)

// 直接调用而不使用 unawaited
libraryCatalogNotifier.refreshSongMetadata(song.id);
```

### 3. 状态更新通知

```dart
state = AsyncData(
  currentState.copyWith(
    tracks: updatedTracks,
    folderAlbums: _buildFolderAlbums(updatedTracks),
    metadataAlbums: _buildMetadataAlbums(updatedTracks),
  ),
);
// Riverpod 会自动通知所有 watch(libraryCatalogControllerProvider) 的 widget
```

---

## 🚀 下一步操作

1. **安装新 APK**
2. **拍摄完整日志**（包括扫描、刮削、UI 更新的所有步骤）
3. **分享结果**以便验证修复

所有日志都会显示在 Debug Panel 中（打开方式：长按播放器）

