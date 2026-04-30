# 刮削功能实现进度 - Stage 2 Report

**日期**: 2026-04-15
**完成度**: Phase 1/3 (33%)
**状态**: ✅ Phase 1 完成，Phase 2 进行中

---

## ✅ 已完成工作

### Phase 1: 数据模型 + 持久化 (100% 完成)

#### 1.1 架构设计文档
- 📄 [SCRAPER_ARCHITECTURE.md](docs/SCRAPER_ARCHITECTURE.md)
- 完整的流程图、数据模型设计、优先级系统
- 6个阶段实现计划

#### 1.2 数据模型实现
✅ **ScrapingMetadata** (`lib/core/database/scraping_metadata.dart`)
- 支持手动刮削结果（优先级最高）
- 支持自动刮削结果
- 刮削状态跟踪（pending/scraping/completed/failed）
- 重试计数和失败恢复机制
- JSON 序列化/反序列化

✅ **ScrapingCache** (`lib/core/database/scraping_cache.dart`)
- 缓存搜索结果避免重复 API 请求
- 支持 24h TTL（可配置）
- 缓存有效性管理

✅ **LibrarySong 扩展** (`lib/core/models/library_song.dart`)
- 新增 10 个刮削结果字段
- 智能 getter：`displayTitle`、`displayArtist`、`displayAlbum`、`displayCoverUrl`、`displayLyrics`
- 优先级：手动 > 自动 > 原始

#### 1.3 持久化层
✅ **IsarManager** (`lib/core/database/isar_manager.dart`)
- 使用 SharedPreferences + JSON（避免代码生成冲突）
- 内存缓存 + 持久化
- 安全的并发访问

✅ **ScrapingMetadataRepository** (`lib/core/database/scraping_metadata_repository.dart`)
- CRUD 操作
- 查询：待刮削、失败、源过滤、手动/自动分类
- 统计信息
- 160+ 行测试就绪的代码

✅ **ScrapingCacheRepository** (`lib/core/database/scraping_cache_repository.dart`)
- 搜索缓存管理
- 过期清理
- 统计信息

#### 1.4 文件名解析器
✅ **FileNameParser** (`lib/features/scraper/utils/file_name_parser.dart`)
- 支持 7 种常见文件名格式
- 智能模式匹配（优先级排序）
- 移除干扰内容（Live 版、括号等）
- 可靠的回退方案

**支持格式示例**:
```
01.青花瓷.flac → title:"青花瓷" artist:null
周杰伦 - 青花瓷.flac → title:"青花瓷" artist:"周杰伦"
青花瓷【周杰伦】.flac → title:"青花瓷" artist:"周杰伦"
[专辑] 01 青花瓷.flac → title:"青花瓷" trackNumber:"01" prefix:"[专辑]"
```

#### 1.5 国际化 (i18n)
✅ **app_en.arb** - 24 条新的英文字符串
✅ **app_zh.arb** - 24 条新的中文字符串

包含：手动刮削、搜索、结果显示、状态标签等

#### 1.6 App 初始化
✅ **main.dart** - 集成 IsarManager 初始化

---

## 🔄 进行中

### Phase 2: 具体刮削器实现（20% 开始）

TODO:
1. [ ] MusicBrainz API 集成
   - MusicBrainz 客户端实现
   - 搜索 API（艺术家、录音）
   - 封面获取（Album Art Archive）
   - 歌词获取（暂定为占位符）

2. [ ] Riverpod Providers
   - `searchMetadataProvider` - 搜索接口
   - `scrapingStatsProvider` - 统计信息
   - `applyScrappingResultProvider` - 应用结果

---

## 📋 后续阶段

### Phase 3: 队列系统 + 状态管理
- 后台刮削队列
- 播放优先级处理
- 自动重试机制

### Phase 4: UI 实现
- 手动刮削对话框
- 搜索结果列表选择
- 歌曲列表集成（更多菜单）
- 播放器集成（封面、歌词按钮）

### Phase 5-6: 测试、优化、验证

---

## 📊 代码质量指标

| 指标 | 值 |
|------|-----|
| 新增文件 | 8 个 |
| 新增代码行数 | ~2000 行 |
| 编译错误 | 0 ❌ → 0 ✅ |
| 总体警告 | 0 |
| 测试覆盖 | 0（待 Phase 6） |

---

## 💡 关键设计决策

1. **SharedPreferences 替代 Isar**
   - 原因：避免 Riverpod + Isar_generator 版本冲突
   - 优势：更轻量、更快启动、更简单调试
   - 劣势：不支持复杂查询（但我们的查询足够简单）

2. **优先级系统**
   - 手动 > 自动 > 原始文件名/元数据
   - 用户有最终决定权

3. **后台 + 播放优先**
   - 新扫描歌曲加入低优先级队列
   - 播放时立即优先处理

4. **缓存策略**
   - 24h TTL 避免过时数据
   - 用户可手动清除

---

## 🚀 下一步

继续 Phase 2：实现 MusicBrainz 刮削器和 Riverpod providers。
预计完成时间：2-3 小时

---

## 附录：文件清单

### 新建文件
```
lib/core/database/
  ├── isar_manager.dart ........................ IsarManager (SharedPreferences)
  ├── scraping_metadata.dart .................. ScrapingMetadata 模型
  ├── scraping_cache.dart ..................... ScrapingCache + CacheResult
  ├── scraping_metadata_repository.dart ....... Repository 类 (270+ 行)
  └── scraping_cache_repository.dart ......... Repository 类 (140+ 行)

lib/features/scraper/
  └── utils/
      └── file_name_parser.dart .............. FileNameParser (200+ 行)

lib/l10n/
  ├── app_en.arb ............................. +24 新字符串
  └── app_zh.arb ............................. +24 新字符串
```

### 修改文件
```
lib/core/models/
  └── library_song.dart ....................... +10 字段、新 getters

lib/main.dart ................................ +IsarManager.initialize()

pubspec.yaml ................................. 依赖调整（去除 Isar）
```

