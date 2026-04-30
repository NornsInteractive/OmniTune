# 刮削功能实现进度 - Phase 1+2 完成总结

**日期**: 2026-04-15  
**完成度**: Phase 1-2 / 3 (67%)  
**编译状态**: ✅ **无错误**  
**下一步**: UI 实现 (Phase 3-4)

---

## 📊 快速概览

| 项目 | 状态 | 说明 |
|------|------|------|
| **Phase 1** | ✅ 完成 | 数据模型、持久化、文件名解析器 |
| **Phase 2** | ✅ 完成 | MusicBrainz 刮削器 + Riverpod providers |
| **Phase 3-4** | 🔄 待做 | UI 实现、队列系统 |
| **编译** | ✅ 正常 | 0 errors, 0 warnings |
| **依赖** | ✅ 正常 | 所有依赖已解决 |

---

## 🎯 Phase 1: 数据模型 + 持久化（已完成）

### 1.1 文件创建位置
```
lib/core/database/
├── isar_manager.dart .......................... IsarManager（共享偏好设置）
├── scraping_metadata.dart ..................... ScrapingMetadata 模型（JSON 序列化）
├── scraping_cache.dart ........................ ScrapingCache + CacheResult
├── scraping_metadata_repository.dart ......... Repository（270 行）
└── scraping_cache_repository.dart ........... Repository（140 行）

lib/features/scraper/utils/
└── file_name_parser.dart ..................... 文件名解析器（200 行）

lib/l10n/
├── app_en.arb ................................ +24 新英文字符串
└── app_zh.arb ................................ +24 新中文字符串
```

### 1.2 核心类设计

**ScrapingMetadata**:
- 存储刮削状态、重试计数、手动/自动结果
- 优先级：手动 > 自动 > 原始
- JSON 序列化完整支持

**LibrarySong 扩展**:
- 新增 10 个字段（手动8个 + 自动2个）
- `displayTitle`、`displayArtist`、`displayAlbum` getters
- 向后兼容现有 JSON

**FileNameParser**:
- 7 种格式支持
- 正则表达式基础
- 安全回退机制

---

## 🚀 Phase 2: MusicBrainz 集成（已完成）

### 2.1 文件创建位置
```
lib/features/scraper/
├── data/
│   ├── musicbrainz_client.dart ............... MusicBrainz API 客户端（150 行）
│   └── musicbrainz_scraper.dart ............. 刮削器实现（100 行）
├── application/
│   ├── scraping_provider.dart ............... Riverpod providers（230 行）
│   └── scraping_provider.g.dart ............. 生成代码（由 build_runner）
└── domain/
    └── metadata_scraper.dart ................ 扩展接口（添加 coverUrl + lyrics）
```

### 2.2 核心功能

**MusicBrainzClient**:
- RESTful API 封装（MusicBrainz 官方 API）
- 支持艺术家 + 标题协调搜索
- 自动封面 URL 生成（使用 Cover Art Archive）
- 错误处理和超时控制

**MusicBrainzScraper**:
- 实现 `MetadataScraper` 接口
- `searchMetadata(title, artist)` 返回多个结果
- 结果包含匹配度分数（0-1）

**Riverpod Providers**:
```dart
// 搜索接口
searchMetadata(title, artist) → List<ScrapedMetadataResult>

// 数据操作
applyManualScrapingResult(fileId, result) → void
applyAutoScrapingResult(fileId, result) → void  
createScrapingRecord(...) → ScrapingMetadata

// 查询接口
scrapingStats() → ScrapingStatsResult
pendingScrapings() → List<ScrapingMetadata>
getScrapingMetadata(id) → ScrapingMetadata?

// 缓存管理
clearScrapingCache() → void
clearExpiredCache() → void
```

### 2.3 搜索缓存
- 自动 24h TTL
- 避免重复 API 请求
- 可配置过期时间
- 用户可手动清除

---

## 🔌 API 集成

### MusicBrainz API 端点
```
GET /recording?query=... → 搜索录音
GET /recording/{id}?inc=... → 获取详情
```

### 搜索查询语法
```dart
// 简单搜索（仅标题）
'青花瓷'

// 精确搜索（艺术家 + 标题）
'artist:"周杰伦" AND recording:"青花瓷"'
```

### 结果映射
```
MusicBrainz JSON → ScrapedMetadataResult
- title: .title
- artist: .artist-credit[0].artist.name
- album: .releases[0].title
- coverUrl: https://coverartarchive.org/release/{id}/front-250.jpg
- score: .score / 100
```

---

## 📋 i18n 支持

### 新增字符串（24 条）

**英文** (app_en.arb):
```
manualScrapingTitle
scrapingSongName
scrapingSearchButton
scrapingSearchResultsTitle
scrapingMatchScoreLabel
... 等
```

**中文** (app_zh.arb):
```
手动刮削
歌名
搜索
搜索结果
匹配度：{score}%
... 等
```

---

## 🔄 数据流示例

### 搜索歌曲流程
```
用户输入 "青花瓷" (艺术家可选)
↓
searchMetadata provider 调用
↓
检查缓存（24h）
├─ 命中 → 返回缓存结果
└─ 未命中 → 请求 MusicBrainz API
  ↓
  API 返回搜索结果（最多 20 个，按匹配度排序）
  ↓
  转换为 ScrapedMetadataResult 列表
  ↓
  保存到缓存（24h TTL）
  ↓
  返回结果
```

### 应用结果流程
```
用户选择搜索结果
↓
applyManualScrapingResult provider 调用
↓
更新 Repository（新增/修改）
  - 生成 ID: sourceId::filePath
  - 设置 manuallyScrapedTitle 等字段
  - 标记 status = completed
  ↓
保存到 SharedPreferences（JSON）
↓
通知 UI 刷新（invalidate providers）
  - scrapingStatsProvider
  - pendingScrapingsProvider
  - getScrapingMetadataProvider
```

---

## 📚 核心数据访问

### Repository 方法
```dart
// 创建刮削记录
createInitialMetadata(sourceId, path, filename, artist?)
  → ScrapingMetadata

// 查询
getById(id) → ScrapingMetadata?
getBySourceId(sourceId) → List<ScrapingMetadata>
getPending() → List<ScrapingMetadata>
getFailedForRetry(maxRetries) → List<ScrapingMetadata>
getManuallyScraped() → List<ScrapingMetadata>
getAutoScraped() → List<ScrapingMetadata>

// 更新
updateManualScrapingResult(id, title, artist, ...)
updateAutoScrapingResult(id, title, artist, ..., score)
updateStatus(id, status, errorMessage?)

// 清理
deleteByIds(ids)
deleteBySourceId(sourceId)  
clearAll()
```

---

## 💾 存储详情

### SharedPreferences 键
```
scraping_metadata_{id}     → JSON 序列化的 ScrapingMetadata
scraping_metadata_list     → String[]（所有 ID 列表）

scraping_cache_{queryKey}  → JSON 序列化的 ScrapingCache
scraping_cache_list        → String[]（所有 queryKey 列表）
```

### JSON 结构示例
```json
{
  "id": "source1::path/to/file.flac",
  "sourceId": "source1",
  "filePath": "path/to/file.flac",
  "filenameWithoutExt": "01.青花瓷",
  "manuallyScrapedTitle": "青花瓷",
  "manuallyScrapedArtist": "周杰伦",
  "autoScrapedTitle": null,
  "status": "completed",
  "retryCount": 0,
  "createdAt": "2026-04-15T12:00:00Z",
  "updatedAt": "2026-04-15T12:05:00Z"
}
```

---

##  ⚙️ 环境与配置

### Dart/Flutter 版本
- Dart: ^3.10.0
- Flutter: ^3.x
- Riverpod: ^2.6.1
- Build Runner: ^2.4.15

### 额外依赖
- `dio`: HTTP 请求（MusicBrainz API）
- `shared_preferences`: 本地存储
- 所有依赖均已 `flutter pub get`

### 构建命令
```bash
# 生成 Riverpod 代码
dart run build_runner build --delete-conflicting-outputs

# 生成本地化字符串
flutter gen-l10n

# 静态分析
dart analyze

# 构建 APK
bash scripts/build_apk.sh
```

---

## 🚀 下一步 (Phase 3-4)

### Phase 3: UI 实现
1. **手动刮削对话框** (`manual_scraping_dialog.dart`)
   - 输入框：歌曲名、艺术家名
   - 搜索按钮和加载状态
   - 结果列表（虚拟滚动）
   - 选择确认按钮

2. **搜索结果选择器**
   - 列表项：封面、标题、艺术家、匹配度
   - 触摸反馈
   - 预览已选中结果

### Phase 4: 集成到现有 UI
1. **歌曲列表更多菜单**
   - 现有选项：删除、播放全部等
   - 新增：💾 手动刮削

2. **播放器页面**
   - 长按封面：🔄 更新封面
   - 添加歌词按钮：📝 获取歌词

3. **队列系统**
   - 后台刮削（低优先级）
   - 播放优先（高优先级）
   - 自动重试机制

### Phase 5: 测试与优化
- 单元测试（Repository、Parser、Scraper）
- 集成测试（搜索、缓存、应用结果）
- 性能优化（缓存命中率、搜索响应时间）
- 错误处理和用户提示

---

## 📊 代码统计

| 组件 | 文件数 | 代码行数 | 状态 |
|------|--------|---------|------|
| 数据提供者 | 1 | 230 | ✅ 完成 |
| MusicBrainz 集成 | 2 | 250 | ✅ 完成 |
| 数据模型 | 3 | 400+ | ✅ 完成 |
| Repository | 2 | 410 | ✅ 完成 |
| 工具函数 | 1 | 200+ | ✅ 完成 |
| i18n | 2 | 24 项 | ✅ 完成 |
| **总计** | **11** | **~1650** | ✅ 完成 |

---

## ✅ 质量保证

| 项 | 结果 |
|----|------|
| 编译错误 | 0 ✅ |
| 警告 | 0 ✅ |
| Dart Analyze | 通过 ✅ |
| 导入冲突 | 0 ✅ |
| 类型安全 | 是 ✅ |
| null-safety | 完整 ✅ |

---

## 💡 关键成就

1. ✅ **干净的架构** - Repository、Provider、Model 分离
2. ✅ **缓存策略** - 24h TTL，避免 API 过载
3. ✅ **优先级系统** - 手动 > 自动 > 原始
4. ✅ **错误恢复** - 重试机制、失败记录
5. ✅ **国际化** - 中英文完整支持
6. ✅ **文件名智能解析** - 7 种格式识别
7. ✅ **MusicBrainz 集成** - 官方 API，无密钥
8. ✅ **性能优先** - SharedPreferences（快速）+ JSON（兼容）

---

## 📝 后续开发建议

1. **监听新扫描歌曲** - 集成到 `LibraryCatalogController`
   - 扫描完成时自动创建初始刮削记录
   - 加入后台队列

2. **播放时优先处理** - 集成到 `PlayerNotifier`
   - 检查当前歌曲的刮削状态
   - 如未完成，加入优先队列

3. **后台处理线程** - 实现队列处理器
   - 读取 pending 队列（低优先级）
   - 提升播放歌曲优先级
   - 批量处理，避免 API 限流

4. **搜索缓存预热** - 热门歌曲提前缓存
   - 用户历史列表
   - 推荐歌曲列表

5. **错误处理改进** - 用户友好的错误消息
   - API 超时
   - 网络错误
   - 无结果找到

---

## 🔗 文件导航

| 用途 | 文件 |
|------|------|
| 架构设计 | [docs/SCRAPER_ARCHITECTURE.md](docs/SCRAPER_ARCHITECTURE.md) |
| Phase 1 总结 | [docs/SCRAPER_PHASE1_COMPLETE.md](docs/SCRAPER_PHASE1_COMPLETE.md) |
| 本文档 | [docs/SCRAPER_PHASE12_COMPLETE.md](docs/SCRAPER_PHASE12_COMPLETE.md) |

---

**状态**: ✅ **Phase 1-2 完成，编译无误，准备 UI 实现**  
**下次工程师任务**: 实现手动刮削对话框 UI 组件

