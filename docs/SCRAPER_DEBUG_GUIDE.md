# 刮削功能调试指南

**创建日期**: 2026-04-15  
**版本**: Debug System v1.0  
**状态**: ✅ 已实现

---

## 🔍 调试系统概述

已为所有刮削功能添加完整的调试日志系统。每个关键操作都会输出详细的日志信息，帮助追踪问题。

### 调试输出符号
```
🔍 - 调试模式初始化
ℹ️  - 信息  (信息级别)
✅ - 成功 (操作成功)
⚠️  - 警告 (可能的问题)
❌ - 错误 (发生错误，需要处理)
🌐 - 网络 (网络请求)
💾 - 数据库 (数据库操作)
🎵 - 刮削 (刮削相关操作)
⏱️  - 性能 (性能数据)
📝 - 日志 (通用日志)
─   - 分隔线
```

---

## 📊 调试模块

### 1. **MusicBrainz API 客户端** 
📍 文件: `lib/features/scraper/data/musicbrainz_client.dart`

**追踪的操作:**
- ✅ 搜索请求开始
- ✅ API 响应接收
- ✅ 结果数量
- ❌ 连接超时
- ❌ 接收超时
- ❌ 其他 DioException 错误

**示例输出:**
```
🌐 [MusicBrainz] GET /recording
   response=query=青花瓷&limit=20
✅ [MusicBrainz] 搜索成功: 找到 5 个结果 (查询: "青花瓷")
```

### 2. **MusicBrainz 刮削器**
📍 文件: `lib/features/scraper/data/musicbrainz_scraper.dart`

**追踪的操作:**
- 🎵 搜索开始（包含查询参数）
- 🎵 搜索方式选择（精确/标题）
- 🎵 每个结果的转换
- 🎵 搜索完成（总数）
- ❌ 搜索异常

**示例输出:**
```
🎵 [MusicBrainzScraper] 开始搜索: 标题="青花瓷", 艺术家="周杰伦"
🎵 [MusicBrainzScraper] 使用精确搜索 (艺术家 + 标题)
✅ [MusicBrainzScraper] 搜索成功: 找到 3 个结果
🎵 [MusicBrainzScraper] 转换结果: 青花瓷 (匹配度: 100%)
✅ [MusicBrainzScraper] 搜索完成: 返回 3 个结果
```

### 3. **Riverpod Providers**
📍 文件: `lib/features/scraper/application/scraping_provider.dart`

**追踪的操作:**
- 🎵 查询开始
- 🎵 缓存命中状态
- ℹ️  缓存未命中时执行搜索
- 🎵 搜索结果数
- ℹ️  缓存保存操作
- ✅ 缓存保存成功
- ⚠️  没有结果可保存
- 🎵 应用手动刮削结果
- ✅ 数据库更新成功
- ✅ Provider 刷新
- ❌ 异常错误

**示例输出:**
```
🎵 [searchMetadata Provider] 查询开始: title="青花瓷", artist="周杰伦"
✅ [searchMetadata Provider] 从缓存返回 3 个结果

# 或者（缓存未命中）
🎵 [searchMetadata Provider] 查询开始: title="新歌", artist="新艺术家"
ℹ️  [searchMetadata Provider] 缓存未命中，执行搜索
ℹ️  [searchMetadata Provider] 搜索返回 0 个结果
```

### 4. **数据库操作**
📍 文件: `lib/core/database/isar_manager.dart`  
📍 文件: `lib/core/database/scraping_metadata_repository.dart`

**IsarManager 追踪:**
- 💾 初始化操作
- ℹ️  元数据保存
- ✅ 保存成功
- ℹ️  索引列表更新数量
- ℹ️  缓存加载或存储加载
- ℹ️  元数据删除
- ℹ️  清空操作
- ❌ 所有错误

**Repository 追踪:**
- 💾 UPSERT 操作
- 💾 GET 查询（成功/未找到）
- 💾 GET_PENDING（待刮削数量）
- 💾 GET_FAILED_FOR_RETRY（可重试数）
- 💾 GET_BY_SOURCE（来源记录数）
- ❌ 所有数据库错误

**示例输出:**
```
💾 [IsarManager] 初始化中...
✅ [IsarManager] SharedPreferences 初始化成功

ℹ️  [IsarManager] 保存元数据: id=source1::file.flac
✅ [IsarManager] 元数据保存成功
ℹ️  [IsarManager] 已添加到索引列表, 总数: 42

💾 [ScrapingMetadataRepository] UPSERT - id=source1::file.flac, status=completed
✅ [ScrapingMetadataRepository] UPSERT 成功

💾 [ScrapingMetadataRepository] GET_PENDING - limit=100
✅ [ScrapingMetadataRepository] 找到 15 个待刮削的记录
```

---

## 🚀 启用调试模式

### 方法 1：在代码中启用（开发用）
```dart
import 'package:music/core/utils/debug_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 启用调试模式
  DebugLogger.setDebugEnabled(true);
  
  // ... 其余代码
}
```

### 方法 2：通过设置界面启用（推荐用户版本）
1. 打开应用 → 设置 ⚙️
2. 找到"开发者选项"或"调试模式"
3. 点击启用
4. 所有后续日志会在控制台输出

### 方法 3：查询当前状态
```dart
// 检查调试模式是否启用
bool isEnabled = DebugLogger.isDebugEnabled;
print('调试模式: ${isEnabled ? "已启用" : "已禁用"}');
```

---

## 📱 真机调试

### Android
```bash
# 在应用运行时查看日志
adb logcat | grep "🎵\|✅\|❌\|⚠️"

# 过滤特定模块
adb logcat | grep "MusicBrainz"
```

### iOS
```bash
# 使用 Xcode 运行应用
# 在 Console 输出中查看日志
```

### 通用
```bash
# 按优先级查看
flutter run -v 2>&1 | grep "🎵\|✅\|❌"

# 保存到文件进行离线分析
flutter run -v > debug.log 2>&1
cat debug.log | grep "❌"  # 只看错误
```

---

## 🔧 常见问题排查

### Q: "没有一首歌是刮削成功的" - 调试步骤

#### 步骤 1: 启用调试模式
```dart
DebugLogger.setDebugEnabled(true);
```

#### 步骤 2: 查看网络请求
查看是否有类似输出：
```
🌐 [MusicBrainz] GET /recording
   response=query=歌名&limit=20
```

**可能的问题:**
- ❌ `连接超时` → 网络问题或 MusicBrainz 服务不可用
- ❌ `接收超时` → 网络太慢或 API 响应慢
- ❌ `状态码 403/401` → 权限问题
- ❌ 没有 🌐 日志 → 请求甚至没有发送

#### 步骤 3: 查看搜索结果
```
🎵 [MusicBrainzScraper] 搜索完成: 返回 3 个结果
```

**可能的问题:**
- ⚠️ `返回 0 个结果` → 搜索词不匹配（尝试修改 FileNameParser）
- ✅ `返回多个结果` → 正常，下一步检查应用

#### 步骤 4: 查看数据库保存
```
💾 [ScrapingMetadataRepository] UPSERT - id=source1::file.flac
✅ [ScrapingMetadataRepository] UPSERT 成功
```

**可能的问题:**
- ❌ `❌ UPSERT 失败` → 数据库错误，检查存储空间
- ❌ 没有 💾 日志 → 应用结果没有被调用

#### 步骤 5: 查看最终结果
```
✅ [ScrapingMetadataRepository] 找到 42 个属于源 "source1" 的记录
```

---

## 📋 调试检查清单

使用此检查清单逐步诊断问题：

### 网络层
- [ ] MusicBrainz API 可访问性
  ```bash
  curl -s "https://musicbrainz.org/ws/2/recording?query=test&fmt=json" | head
  ```
- [ ] 查看 🌐 日志中是否有 `GET /recording`
- [ ] 查看状态码是否为 200
- [ ] 查看是否有分析错误 ❌

### 搜索层
- [ ] FileNameParser 是否正确解析文件名
  - 查看 🎵 日志中的 `开始搜索` 部分
  - 验证 `标题` 和 `艺术家` 是否正确
- [ ] 是否选择了正确的搜索方式（如果有艺术家→精确搜索）
- [ ] 搜索结果数量是否为 0
  - 是 → 尝试用不同关键词搜索 MusicBrainz 网站
  - 否 → 继续下一步

### 缓存层
- [ ] 第一次搜索：ℹ️ `缓存未命中，执行搜索`
- [ ] 第二次搜索相同条件：✅ `从缓存返回 X 个结果`
- [ ] 缓存是否过期（24 小时）

### 数据库层
- [ ] 元数据是否保存：💾 `UPSERT` 日志
- [ ] 是否有 ✅ `保存成功`
- [ ] Provider 是否刷新：✅ `已刷新相关 providers`
- [ ] 查询结果：✅ `找到 X 个属于源的记录`

### UI 层
- [ ] 歌曲列表是否显示新的元数据
- [ ] displayTitle/displayArtist getters 是否返回正确值
- [ ] 优先级是否正确（手动 > 自动 > 原始）

---

## 🎯 按错误类型查找

### "连接超时"
```
❌ [MusicBrainz] DioException - DioExceptionType.connectionTimeout
   错误详情: Connection timed out
```
**解决:**
- 检查网络连接
- 检查防火墙/代理设置
- MusicBrainz 服务器状态：https://musicbrainz.org/

### "接收超时"
```
❌ [MusicBrainz] DioException - DioExceptionType.receiveTimeout
   可能是网络太慢或 MusicBrainz 服务器响应慢
```
**解决:**
- 检查网络速度
- 稍后重试
- 检查 MusicBrainz 负载状态

### "搜索未返回结果"
```
⚠️ [MusicBrainzScraper] 搜索未返回结果 - 标题: "歌名", 艺术家: "艺术家"
```
**解决:**
- 在 MusicBrainz 网站上手动搜索
- 检查 FileNameParser 是否正确提取了歌名
- 尝试简化搜索词（去掉特殊字符）

### "UPSERT 失败"
```
❌ [IsarManager] 保存元数据失败
   错误详情: Disk quota exceeded
```
**解决:**
- 检查存储空间
- 清空非必要缓存
- 调用 `DebugLogger.log('清空缓存中...')` 后 `await IsarManager.clearAll()`

---

## 💡 高级调试技巧

### 1. 按模块过滤日志
```bash
# 只看 MusicBrainz 日志
flutter run -v 2>&1 | grep "MusicBrainz"

# 只看错误
flutter run -v 2>&1 | grep "❌"

# 只看刮削操作
flutter run -v 2>&1 | grep "🎵"
```

### 2. 监控特定操作
```bash
# 监控搜索操作
flutter run -v 2>&1 | grep -A 5 "开始搜索"

# 监控数据库保存
flutter run -v 2>&1 | grep -A 3 "UPSERT"
```

### 3. 性能分析
```
⏱️ [操作名] 耗时: 523ms
```

### 4. 导出完整日志用于分析
```bash
flutter run -v 2>&1 | tee full_debug.log
# 将日志保存到文件，便于事后分析
```

### 5. 清空所有刮削数据重新来过
```dart
await IsarManager.clearAll();
print('✅ 所有数据已清空,准备重新测试');
```

---

## 🎯 预期行为

### 成功的刮削流程日志

```
🎵 [searchMetadata Provider] 查询开始: title="青花瓷", artist="周杰伦"
ℹ️  [searchMetadata Provider] 缓存未命中，执行搜索

🎵 [MusicBrainzScraper] 开始搜索: 标题="青花瓷", 艺术家="周杰伦"
🎵 [MusicBrainzScraper] 使用精确搜索 (艺术家 + 标题)

🌐 [MusicBrainz] GET /recording
   response=query=artist:"周杰伦" AND recording:"青花瓷"&limit=20
✅ [MusicBrainz] 搜索成功: 找到 2 个结果 (查询: "artist:"周杰伦" AND recording:"青花瓷"")

🎵 [MusicBrainzScraper] 转换结果: 青花瓷 (匹配度: 100%)
✅ [MusicBrainzScraper] 搜索成功: 找到 2 个结果
✅ [MusicBrainzScraper] 搜索完成: 返回 2 个结果

ℹ️  [searchMetadata Provider] 搜索返回 2 个结果
ℹ️  [searchMetadata Provider] 保存结果到缓存
✅ [searchMetadata Provider] 缓存保存成功

🎵 [applyManualScrapingResult] 应用手动刮削: fileId=source1::song.flac
ℹ️  [applyManualScrapingResult] 结果: title="青花瓷", artist="周杰伦"

💾 [ScrapingMetadataRepository] UPSERT - id=source1::song.flac, status=completed
💾 [IsarManager] 保存元数据: id=source1::song.flac
✅ [IsarManager] 元数据保存成功
✅ [ScrapingMetadataRepository] UPSERT 成功
✅ [applyManualScrapingResult] 数据库更新成功
✅ [applyManualScrapingResult] 已刷新相关 providers
```

---

## 📞 问题反馈模板

若遇到问题，请提供以下信息：

```
【问题描述】
没有一首歌刮削成功

【环境信息】
- 设备: Android / iOS / 其他
- 系统版本: 
- 应用版本: 1.0.23+24

【调试输出】
（粘贴相关的调试日志）
❌ ...

【已尝试的步骤】
- [ ] 检查网络连接
- [ ] 启用调试模式
- [ ] 重启应用
- [ ] 清空缓存

【其他信息】
- 歌曲文件名: 
- 预期的艺术家/歌名:
```

---

**版本**: Debug System v1.0  
**最后更新**: 2026-04-15  
**维护者**: AI Agent (GitHub Copilot)

---

## 🔗 相关文件

- [DebugLogger 类](lib/core/utils/debug_logger.dart)
- [MusicBrainz 客户端](lib/features/scraper/data/musicbrainz_client.dart)
- [刮削 Provider](lib/features/scraper/application/scraping_provider.dart)
- [数据库管理](lib/core/database/isar_manager.dart)

