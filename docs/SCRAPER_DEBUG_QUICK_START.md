# 🔍 刮削功能调试 - 快速启动指南

**日期**: 2026-04-15  
**版本**: Debug System v1.0  
**目标**: 快速诊断为什么没有一首歌刮削成功

---

## ⚡ 30秒快速开始

### 步骤 1: 启用调试模式
1. 打开应用 → 点击右上角 ⚙️ 设置
2. 向下滚动到关键部分 → 找到"开发者"
3. 打开"调试模式"开关 
4. 会看到提示: 🔍 **调试模式已启用 - 查看控制台查看详细日志**

### 步骤 2: 查看日志
```bash
# 打开新终端，运行应用并查看日志
flutter run -v 2>&1 | grep "🎵\|✅\|❌"
```

### 步骤 3: 尝试搜索
在应用中执行刮削操作，在终端中查看所有输出的日志。

---

## 🎯 检查清单 (按顺序执行)

### ✅ 网络层正常?
查看日志中是否有:
```
🌐 [MusicBrainz] GET /recording
✅ [MusicBrainz] 搜索成功: 找到 X 个结果
```

- ✅ 有这些日志 → 网络正常，继续下一步
- ❌ 没有这些日志 → **网络问题**
  ```
  解决:
  - 检查网络连接
  - 尝试访问 https://musicbrainz.org
  - 检查防火墙设置
  ```

### ✅ 搜索结果有效?
查看日志中是否有:
```
🎵 [MusicBrainzScraper] 搜索完成: 返回 X 个结果
```

- ✅ 返回 > 0 个结果 → 正常，继续下一步
- ❌ 返回 0 个结果 → **搜索词不匹配**
  ```
  解决:
  - 查看被搜索的歌名和艺术家
  - 在 MusicBrainz 网站手动验证
  - 检查 FileNameParser 是否正确提取
  ```

### ✅ 数据库保存成功?
查看日志中是否有:
```
💾 [ScrapingMetadataRepository] UPSERT - id=...
✅ [ScrapingMetadataRepository] UPSERT 成功
```

- ✅ 有这些日志 → 数据库正常，继续下一步
- ❌ 没有或有错误 → **数据库问题**
  ```
  解决:
  - 检查存储空间
  - 重启应用
  - 清空数据: DebugLogger.log('清空'); await IsarManager.clearAll();
  ```

### ✅ UI 更新成功?
查看日志中是否有:
```
✅ [applyManualScrapingResult] 已刷新相关 providers
```

- ✅ 有这个日志 → 所有过程成功！
- ❌ 没有这个日志 → **应用结果没有被调用**
  ```
  可能的原因:
  - 手动刮削对话框没有点击"确定"
  - 没有选择搜索结果
  ```

---

## 🔴 常见问题快速修复

### "网络超时"
```
❌ [MusicBrainz] DioException - DioExceptionType.connectionTimeout
```
**立即修复:**
```bash
# 1. 检查网络
ping musicbrainz.org

# 2. 重启应用
# 3. 稍后重试
```

### "搜索未返回结果"
```
⚠️ [MusicBrainzScraper] 搜索未返回结果 - 标题: "…", 艺术家: "…"
```
**立即修复:**
1. 复制日志中显示的标题和艺术家
2. 在 https://musicbrainz.org/search 手动搜索
3. 如果网站上也没有，这个歌曲就不在 MusicBrainz 中

### "UPSERT 失败"
```
❌ [IsarManager] 保存元数据失败
   错误详情: Disk quota exceeded
```
**立即修复:**
```dart
// 在调试控制台执行
await IsarManager.clearAll();
print('✅ 已清空所有数据');
```

### "没有 Provider 刷新日志"
说明 `applyManualScrapingResult` 没有被调用
**检查:**
1. 是否从对话框点击了"确定"按钮?
2. 是否选择了一个搜索结果?

---

## 📊 完整日志解读示例

### ✅ 成功的流程
```
🎵 [searchMetadata Provider] 查询开始: title="青花瓷", artist="周杰伦"
ℹ️  [searchMetadata Provider] 缓存未命中，执行搜索

🎵 [MusicBrainzScraper] 开始搜索: 标题="青花瓷", 艺术家="周杰伦"
🎵 [MusicBrainzScraper] 使用精确搜索 (艺术家 + 标题)

🌐 [MusicBrainz] GET /recording
✅ [MusicBrainz] 搜索成功: 找到 2 个结果

✅ [MusicBrainzScraper] 搜索完成: 返回 2 个结果

ℹ️  [searchMetadata Provider] 搜索返回 2 个结果
ℹ️  [searchMetadata Provider] 保存结果到缓存
✅ [searchMetadata Provider] 缓存保存成功

🎵 [applyManualScrapingResult] 应用手动刮削: fileId=source1::song.flac

💾 [ScrapingMetadataRepository] UPSERT
✅ [ScrapingMetadataRepository] UPSERT 成功
✅ [applyManualScrapingResult] 数据库更新成功
✅ [applyManualScrapingResult] 已刷新相关 providers

结果: ✅ 歌曲刮削成功!
```

### ❌ 网络超时的流程
```
🎵 [searchMetadata Provider] 查询开始: title="测试", artist="测试"
ℹ️  [searchMetadata Provider] 缓存未命中，执行搜索

🎵 [MusicBrainzScraper] 开始搜索: 标题="测试", 艺术家="测试"
🎵 [MusicBrainzScraper] 使用精确搜索 (艺术家 + 标题)

🌐 [MusicBrainz] GET /recording
❌ [MusicBrainz] DioException - DioExceptionType.connectionTimeout
   连接超时: URL: /recording

⚠️ [MusicBrainzScraper] 搜索未返回结果

❌ [searchMetadata Provider] 查询异常

结果: ❌ 搜索失败，需要检查网络
```

### ❌ 搜索结果为空的流程
```
🎵 [MusicBrainzScraper] 开始搜索: 标题="xxx", 艺术家="yyy"

🌐 [MusicBrainz] GET /recording
✅ [MusicBrainz] 搜索成功: 找到 0 个结果 (查询: "artist:"yyy" AND recording:"xxx"")

⚠️ [MusicBrainzScraper] 搜索未返回结果 - 标题: "xxx", 艺术家: "yyy"

result: ❌ 搜索词不匹配 - 这个歌曲在 MusicBrainz 中不存在或名称不同
```

---

## 🛠️ 高级调试命令

### 查看特定模块的日志
```bash
# 仅看 MusicBrainz 日志
flutter run -v 2>&1 | grep "MusicBrainz"

# 仅看错误
flutter run -v 2>&1 | grep "❌"

# 仅看刮削操作
flutter run -v 2>&1 | grep "🎵"

# 保存完整日志到文件
flutter run -v 2>&1 | tee debug.log
```

### 按时间查看日志变化
```bash
# 持续监控日志（实时显示新日志）
flutter run -v 2>&1 | grep --color=always "🎵\|✅\|❌\|⚠️"
```

### 统计不同类型的日志
```bash
# 统计错误数
flutter run -v | grep "❌" | wc -l

# 统计成功数
flutter run -v | grep "✅" | wc -l

#统计网络请求数
flutter run -v | grep "🌐" | wc -l
```

---

## 💡 故障排除决策树

```
没有一首歌刮削成功
├─ 启用调试模式
│  └─ 搜索歌曲
│
├─ 是否看到 🌐 网络请求?
│  ├─ 否 → 检查网络连接
│  └─ 是 → 继续下一步
│
├─ 是否看到 "找到 X 个结果"?
│  ├─ 否 (0 个结果) → 搜索词不匹配 (在 MusicBrainz 网站验证)
│  └─ 是 (> 0) → 继续下一步
│
├─ 是否看到 🎵 "搜索完成: 返回 X 个结果"?
│  ├─ 否 → API 数据解析失败
│  └─ 是 → 继续下一步
│
├─ 是否选择了搜索结果并点击确定?
│  ├─ 否 → 需要手动选择
│  └─ 是 → 继续下一步
│
├─ 是否看到 💾 "UPSERT"?
│  ├─ 否 → 应用结果调用失败
│  └─ 是 → 继续下一步
│
├─ 是否看到 ✅ "UPSERT 成功"?
│  ├─ 否 → 数据库错误 (清空并重试)
│  └─ 是 → ✅ 成功!
│
└─ 歌曲表中是否看到新元数据?
   ├─ 否 → UI 刷新问题
   └─ 是 → ✅ 完全成功!
```

---

## 📞 如果仍然无法解决

请收集并提供以下信息:

### 日志信息
```bash
# 运行并保存完整日志
flutter run -v 2>&1 | tee full_debug.log

# 提取相关部分（搜索 '青花瓷' 的所有日志）
grep "青花瓷" full_debug.log > scraping_logs.txt
```

### 系统信息
```bash
flutter --version
dart --version
adb shell getprop ro.build.version.release  # Android 系统版本
```

### 设备信息
```
设备: [你的设备名]
系统: [iOS/Android/...]
版本: [系统版本]
应用版本: 1.0.23+24
```

### 最后 50 行日志
```bash
grep "❌\|⚠️" full_debug.log | tail -50
```

---

## ✅ 验证调试模式启用

在设置页面启用调试模式后，应该看到:

1. SnackBar 提示: 🔍 **调试模式已启用 - 查看控制台查看详细日志**
2. 终端输出: `ℹ️ 🔍 调试模式已启用`
3. 之后的所有操作都会输出详细日志

---

**创建时间**: 2026-04-15  
**最后更新**: 2026-04-15  
**维护者**: AI Agent (GitHub Copilot)

