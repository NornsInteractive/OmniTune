# On-Play 异步刮削 — 快速测试指南
**版本**: v1.0.111+112  
**APK 位置**: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🚀 快速开始

### 1. 安装 APK
```bash
cd /workspace/music

# 卸载旧版本（如果存在）
adb uninstall com.music_player.app

# 安装新 APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 2. 验证安装
```bash
adb shell am start -n com.music_player.app/.MainActivity
```

---

## 📋 4 个功能快速验证

### ✅ 需求 1：库扫描快速（无自动刮削）

**步骤**：
1. 打开 App
2. 进入 **Settings** (齿轮图标)
3. 点击 **Add Source** 或 **Edit Source**
4. 配置 WebDAV 源，点击 **Scan**
5. **观察扫描时间**

**验证标准**：
- 1000 首歌应在 **3-10 秒** 内完成
- 无网络延迟（以前可能需要 30-60 秒）
- DebugLogger 日志中:
  ```
  [LibraryCatalogController] 扫描完成: 找到 1000 首歌
  ```
  
**注意**：库列表中的歌名仍为原始名称（绿色标志 ✅）

---

### ✅ 需求 2：播放时异步刮削

**步骤**：
1. 库扫描完成后，进入 **Library** 或 **Albums**
2. 选择一首歌 **点击播放**
3. **立即** 观察 Now Playing Panel 中的歌名
4. 等待 **5-30 秒**
5. **再次观察** 歌名：应该已更新为刮削后的值

**验证标准**：
- 播放**立即启动**（无延迟）
- DebugLogger 日志中出现:
  ```
  [PlayerController._scrapeCurrentSongAsync] 开始后台刮削: [歌名]
  ...
  [PlayerController._scrapeCurrentSongAsync] 刮削完成: [原名] -> [新名]
  ```
- Now Playing Panel 显示刮削后的歌名（通常在 5-20 秒后更新）

**预期行为**：
- ⏱️ 首次播放：1) 显示原始名称 2) 后台刮削 3) 5-30 秒后更新为新名称
- 🚀 后续播放：瞬间显示新名称（使用缓存）

---

### ✅ 需求 3：刮削结果本地缓存

**步骤**：
1. 完成需求 2（播放歌曲直到刮削完成）
2. **完全关闭 App** (从后台清除)
3. **重新打开 App**
4. 进入 **Library**，播放 **同一首歌**
5. **观察** Now Playing Panel 中的歌名

**验证标准**：
- 歌名**瞬间显示**为刮削后的值（无延迟）
- DebugLogger 日志中:
  ```
  [ScrapedMetadataRepository.loadMetadata] 从缓存读取: songId-xyz
  ```
  无新的刮削操作日志（确认使用了缓存）

**检查缓存文件**：
```bash
# 在 PC 上查看
adb pull /data/data/com.music_player.app/app_flutter/scraped_metadata_cache.json ./

# 查看文件内容
cat scraped_metadata_cache.json | jq .

# 预期内容示例：
{
  "songId-123": {
    "songId": "songId-123",
    "title": "新的歌名",
    "artist": "艺术家名",
    "album": "专辑名",
    "coverUrl": "https://...",
    "lyrics": "歌词...",
    "scrapedAt": "2026-04-15T10:30:00.000Z"
  }
}
```

---

### ✅ 需求 4：库扫描结果缓存

**步骤**：
1. 添加 WebDAV 源，完成库扫描
2. 进入 **Library**，验证显示 N 首歌
3. **完全关闭 App**
4. **重新打开 App**
5. **观察** Library 加载速度

**验证标准**：
- Library **瞬间加载**（<200 ms）
- 无 "Scanning..." 或 "Loading..." 的等待状态
- DebugLogger 日志中:
  ```
  [LibraryCatalogController] 从缓存加载: 1000 首歌
  ```

**检查缓存**：
```bash
# 列出缓存文件
adb shell ls -la /data/data/com.music_player.app/app_flutter/ | grep -E "scan_cache|catalog"

# 查看文件大小
adb shell du -sh /data/data/com.music_player.app/app_flutter/
```

---

## 🔍 DebugLogger 日志分析

### 启用详细日志
```bash
adb logcat -s "DebugLogger" -v threadtime
```

### 关键日志模式

**库扫描阶段**：
```
[LibraryCatalogController] 开始扫描源: [sourceId]
[LibraryCatalogController] 扫描完成: 找到 1000 首歌
[LibraryCatalogController] 从缓存加载: 1000 首歌 (第二次启动时)
```

**播放阶段**：
```
[PlayerController] 播放: [歌名]
[PlayerController._scrapeCurrentSongAsync] 开始后台刮削: [歌名]
[ScrapedMetadataRepository.loadMetadata] 从缓存读取: songId-xyz [✓ 缓存命中]
[ScrapedMetadataRepository.loadMetadata] 缓存不存在: songId-new [✗ 需要刮削]
[ScraperChain.scrape] 开始刮削: [歌名]
[ScraperChain.scrape] 成功: [原名] -> [新刮削名]
[PlayerController._scrapeCurrentSongAsync] 保存刮削结果到本地缓存
```

**错误日志** (需要处理但不阻塞)：
```
[PlayerController._scrapeCurrentSongAsync] 刮削异常: [错误信息]
[ScrapedMetadataRepository] JSON 解析错误: [文件路径]
```

---

## 📊 性能基准

| 操作 | 预期时间 | 工具 |
|-----|---------|------|
| 库扫描（1000 首） | 3-10 秒 | Android Studio Profiler |
| 首次播放 + 刮削 | <100ms 启动 + 5-30s 刮削 | DebugLogger |
| 后续播放（缓存） | <100ms | 肉眼观察 |
| App 重启后打开库 | <200ms | 肉眼观察 |

---

## 🐛 常见问题排查

### Q1：库扫描仍然很慢
**原因**：可能仍在执行旧版本代码  
**解决**：
```bash
# 完全清除应用数据
adb shell pm clear com.music_player.app

# 重新安装
adb uninstall com.music_player.app
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Q2：播放时没有看到刮削进行
**原因**：可能需要稍等或日志级别未启用  
**解决**：
1. 检查 DebugLogger 日志：
   ```bash
   adb logcat -s "DebugLogger" | grep "scrape"
   ```
2. 若无日志，检查刮削源配置是否正确

### Q3：Now Playing Panel 没有更新为新名称
**原因**：可能 PlayableTrack 的 displayTitle getter 未正确使用缓存值  
**解决**：
1. 查看 DebugLogger 中刮削是否完成
2. 查看缓存文件是否包含该歌曲
3. 强制杀死 App 并重新启动

### Q4：缓存文件很大或损坏
**原因**：长期使用或异常关闭  
**解决**：
```bash
# 删除缓存
adb shell rm /data/data/com.music_player.app/app_flutter/scraped_metadata_cache.json

# App 将自动重新建立缓存
```

---

## 📝 测试报告模板

```markdown
## v1.0.111+112 测试报告

**测试日期**: [日期]
**测试设备**: [设备型号、Android 版本]
**WebDAV 源**: [源地址、库大小]

### 需求 1：库扫描快速
- [ ] 扫描 1000 首歌耗时: _____ 秒
- [ ] 是否 < 10 秒: [ ] 是 [ ] 否
- [ ] DebugLogger 显示完成: [ ] 是 [ ] 否

### 需求 2：播放时异步刮削
- [ ] 播放立即开始: [ ] 是 [ ] 否
- [ ] 歌名在 5-30 秒后更新: [ ] 是 [ ] 否
- [ ] DebugLogger 显示刮削完成: [ ] 是 [ ] 否

### 需求 3：刮削缓存持久化
- [ ] 关闭重启后歌名瞬间显示: [ ] 是 [ ] 否
- [ ] 缓存文件存在: [ ] 是 [ ] 否
- [ ] DebugLogger 显示"从缓存读取": [ ] 是 [ ] 否

### 需求 4：库扫描缓存
- [ ] App 重启后 Library 瞬间加载: [ ] 是 [ ] 否
- [ ] 无"Scanning..."等待: [ ] 是 [ ] 否
- [ ] DebugLogger 显示"从缓存加载": [ ] 是 [ ] 否

### 一致性检查
- [ ] 库列表歌名 = Now Playing Panel 歌名: [ ] 是 [ ] 否
- [ ] 刮削后名称在两处都显示: [ ] 是 [ ] 否

### 其他问题
- [列出遇到的任何其他问题]

**总体评分**: [ ] ✅ 通过 [ ] ⚠️ 需要改进 [ ] ❌ 失败
```

---

## 🚀 后续工作

构建完成后的建议行动：

1. **立即测试** (30 分钟)
   - 按这个指南验证 4 个功能
   - 收集 DebugLogger 日志供参考

2. **边界案例测试** (可选)
   - 测试极大库（10000+ 首）
   - 测试网络中断后的行为
   - 测试缓存损坏恢复

3. **用户反馈** (重要)
   - 获取用户对速度改进的反馈
   - 收集实际使用中发现的问题

4. **下一阶段开发**
   - 搜索/过滤功能
   - 播放列表管理
   - 新协议支持

---

## 📞 支持

遇到问题？查看以下资源：

- 📖 完整文档：[ON_PLAY_SCRAPING_COMPLETE.md](./ON_PLAY_SCRAPING_COMPLETE.md)
- 🔧 刮削架构：[docs/SCRAPER_ARCHITECTURE.md](./docs/SCRAPER_ARCHITECTURE.md)
- 📊 项目进度：[docs/PROJECT_PROGRESS.md](./docs/PROJECT_PROGRESS.md)
- 🐛 调试指南：[DEBUG_QUICK_REFERENCE.md](./DEBUG_QUICK_REFERENCE.md)

