# 刮削功能完整架构设计

**版本**: 1.0.0
**日期**: 2026-04-15
**状态**: 设计阶段

## 需求概述

### 核心需求
1. **后台自动刮削**: 扫描到新歌曲后自动刮削，但播放时优先刮削当前歌曲
2. **文件名处理**: 识别多种文件命名格式，提取歌曲名和艺术家
3. **元数据替换**: 刮削后更新列表显示和播放器显示
4. **手动刮削**: 提供 UI 界面让用户手动搜索和选择
5. **优先级管理**: 手动刮削 > 自动刮削 > 原始文件名

### 支持的文件名格式
```
01.青花瓷.flac
01 - 青花瓷.flac
周杰伦 - 青花瓷.flac
周杰伦_青花瓷.flac
青花瓷 (Live版).flac
[专辑] 01 青花瓷.flac
青花瓷【周杰伦】.flac
```

### 需要刮削的元数据
- 📸 **封面图**: Album artwork
- 🎵 **歌曲名**: Track title
- 🎤 **艺术家名**: Artist name
- 📄 **歌词**: Lyrics

---

## 架构设计

### 1. 数据模型与持久化

#### Isar Collections
```
class ScrapingMetadata {
  Id? id;  // Isar ID
  
  // 标识字段
  String sourceId;           // 音源 ID
  String filePath;           // 完整文件路径（唯一标识）
  String filenameWithoutExt; // 文件名（用于搜索）
  
  // 手动刮削结果（最高优先级）
  String? manuallyScrapedTitle;
  String? manuallyScrapedArtist;
  String? manuallyScrapedAlbum;
  DateTime? manualScrapedAt;
  
  // 自动刮削结果
  String? autoScrapedTitle;
  String? autoScrapedArtist;
  String? autoScrapedAlbum;
  String? coverImageUrl;
  String? lyrics;
  DateTime? autoScrapedAt;
  
  // 刮削状态
  ScrapingStatus status;  // enum: pending, scraping, completed, failed
  String? errorMessage;
  int retryCount;
  
  // 时间戳
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastScrapedAt;
}

enum ScrapingStatus {
  pending,      // 待刮削
  scraping,     // 刮削中
  completed,    // 已完成
  failed,       // 失败
}

class ScrapingCache {
  Id? id;
  
  String query;              // 搜索关键词
  String? artist;
  String? title;
  DateTime cachedAt;
  
  // 缓存的搜索结果（JSON）
  List<String> resultJsons;  // 序列化的刮削结果
}
```

#### LibrarySong 扩展
```dart
// 现有字段保留，添加：
String? manuallyScrapedTitle;
String? manuallyScrapedArtist;
String? autoScrapedTitle;
String? autoScrapedArtist;
String? coverImageUrl;
String? lyrics;

// 优先级 getter
String get displayTitle => 
  manuallyScrapedTitle?.isNotEmpty == true ? manuallyScrapedTitle! :
  autoScrapedTitle?.isNotEmpty == true ? autoScrapedTitle! :
  filename;

String get displayArtist =>
  manuallyScrapedArtist?.isNotEmpty == true ? manuallyScrapedArtist! :
  autoScrapedArtist?.isNotEmpty == true ? autoScrapedArtist! :
  extractedArtist ?? 'Unknown';
```

---

### 2. 核心组件

#### A. 文件名解析器 (`file_name_parser.dart`)
```dart
class FileNameParser {
  static ParsedFilename parse(String filename) {
    // 1. 移除文件扩展名
    // 2. 尝试多种解析模式
    // 3. 返回 title 和 artist
  }
}

class ParsedFilename {
  String? title;        // 提取的歌曲名
  String? artist;       // 提取的艺术家
  String? trackNumber;  // 提取的曲号
  String prefix;        // 识别出的前缀（如"[专辑]"）
}
```

**设计**:
- 尝试正则表达式匹配常见格式
- 优先级: 最精确格式 → 更通用格式
- 返回最可能的 title 和 artist

#### B. 刮削请求处理器 (`scraping_request_handler.dart`)
```dart
class ScrapingRequest {
  String filePath;
  String title;         // 解析或手动输入的歌曲名
  String? artist;       // 解析或手动输入的艺术家
  ScrapingSource source; // 刮削源优先级
  bool isManual;        // 是否为手动请求
  int priority;         // 排队优先级（播放时为 HIGH）
}

enum ScrapingSource {
  musicBrainz,
  spotify,
  other,
}
```

#### C. 刮削引擎 (`scrapers/`)
```dart
// lib/features/scraper/data/musicbrainz_scraper.dart
class MusicBrainzScraper implements MetadataScraper {
  @override
  int get priority => 100; // 高优先级
  
  @override
  Future<ScrapedMetadata?> scrape(
    String title,
    String? artist,
  ) async {
    // 调用 MusicBrainz API
    // 返回最匹配的结果
  }
}

// 返回结构
class ScrapedMetadata {
  String title;
  String? artist;
  String? album;
  String? coverUrl;
  String? lyrics;
  double matchScore;  // 0-1 匹配度
  DateTime fetchedAt;
}
```

#### D. 刮削队列系统 (`scraping_queue.dart`)
```dart
class ScrapingQueueManager {
  // 维护两个队列
  final Queue<ScrapingRequest> _backgroundQueue;
  final Queue<ScrapingRequest> _priorityQueue;  // 播放时优先
  
  void enqueueBackground(ScrapingRequest req);
  void enqueuePriority(ScrapingRequest req);
  Future<void> processPending();
}
```

**特性**:
- 背景队列处理新扫描歌曲
- 优先队列用于播放中的歌曲
- 可配置的并发数和抖动延迟
- 自动重试失败的请求

#### E. 状态管理 (`scraping_provider.dart`)
```dart
// Riverpod providers
@riverpod
Future<List<ScrapingSearchResult>> searchMetadata(
  SearchMetadataRef ref,
  String title,
  String? artist,
) async {
  // 调用刮削引擎，返回可选结果列表
}

@riverpod
Future<void> applyManualScrapingResult(
  ApplyManualScrapingResultRef ref,
  String filePath,
  ScrapedMetadata metadata,
) async {
  // 保存手动刮削结果到 Isar
  // 更新 LibrarySong
  // 通知 UI 刷新
}

@riverpod
Future<ScrapingMetadata?> getScrapingMetadata(
  GetScrapingMetadataRef ref,
  String filePath,
) async {
  // 获取单个文件的刮削状态
}

@riverpod
Future<List<ScrapingMetadata>> getPendingScrapings(
  GetPendingScrapingsRef ref,
) async {
  // 获取待刮削列表
}

@riverpod
Future<void> retryScrapingFailed(
  RetryScrapingFailedRef ref,
) async {
  // 重试所有失败的刮削
}
```

---

### 3. UI 组件

#### A. 手动刮削对话框 (`manual_scraping_dialog.dart`)
**结构**:
1. **输入区域**
   - 歌曲名输入框（默认填充文件名提取值）
   - 艺术家输入框（默认填充文件名提取值）
   - 搜索按钮

2. **结果列表**
   - 显示搜索到的所有结果
   - 每个结果包含: 封面、歌曲名、艺术家、匹配度
   - 可滚动、支持虚拟列表

3. **选择区域**
   - 用户点击结果后确认
   - 预览即将应用的数据

#### B. 歌曲列表更多菜单
**新增选项**:
- 👉 现有: 删除、播放全部等
- ✨ **新增**: "💾 手动刮削"

#### C. 播放器页面集成
**新增区域**:
- 封面图: 长按显示"🔄 更新封面"菜单
- 歌词: 添加"📝 获取歌词"按钮

---

### 4. 工作流程

#### 4.1 自动刮削流程
```
用户扫描添加音源
  ↓
LibraryController 扫描完成
  ↓
遍历新扫描的歌曲
  ↓
创建 ScrapingMetadata 记录（status=pending）
  ↓
加入后台队列 → ScrapingQueueManager._backgroundQueue
  ↓
[后台线程] 按优先级处理队列
  ↓
调用 MetadataScraper.scrape(title, artist)
  ↓
保存结果到 Isar + LibrarySong
  ↓
如果播放中，刷新播放器 UI
```

#### 4.2 播放时优先刮削流程
```
用户点击播放（歌曲未刮削）
  ↓
PlayerNotifier.play(song)
  ↓
检查该歌曲的 ScrapingMetadata 状态
  ↓
如果 status != completed
  ↓
创建优先请求 + priority=HIGH
  ↓
加入 _priorityQueue（插到前面）
  ↓
立即启动搜索并应用结果
  ↓
播放器显示刮削到的封面 + 歌词
```

#### 4.3 手动刮削流程
```
用户点击歌曲的更多菜单 → "手动刮削"
  ↓
打开 ManualScrapingDialog
  ↓
对话框自动填充文件名提取值
  ↓
用户修改搜索词并点击搜索
  ↓
调用 searchMetadata() provider
  ↓
返回结果列表
  ↓
用户选择其中一个结果
  ↓
调用 applyManualScrapingResult()
  ↓
保存到 Isar（status=completed, 标记为 manual）
  ↓
UPDATE LibrarySong.manuallyScrapedTitle 等
  ↓
通知所有列表和播放器刷新 UI
```

---

### 5. 国际化 (i18n)

需要在 `app_en.arb` 和 `app_zh.arb` 中添加:
```json
{
  "manualScrapingTitle": "Manual Scraping",
  "enterSongName": "Enter song name",
  "enterArtistName": "Enter artist name",
  "searchResults": "Search Results",
  "noResultsFound": "No results found",
  "matchScore": "Match: {score}%",
  "scraping": "Scraping...",
  "scrapingFailed": "Scraping failed",
  "retryScrapers": "Retry"
}
```

---

### 6. 实现顺序

1. **第1阶段**: 数据模型 + Isar 集成
   - 创建 Isar collections
   - 扩展 LibrarySong 模型
   - 实现 Repository 类

2. **第2阶段**: 文件名解析 + 基础刮削引擎
   - 文件名解析器
   - MusicBrainz 刮削器临时实现

3. **第3阶段**: 队列系统 + 状态管理
   - ScrapingQueueManager
   - Riverpod providers
   - 后台处理

4. **第4阶段**: 手动刮削 UI
   - 对话框组件
   - 搜索结果列表
   - 确认和应用逻辑

5. **第5阶段**: 集成到现有 UI
   - 歌曲列表更多菜单
   - 播放器页面集成

6. **第6阶段**: 测试和优化

---

## 核心设计决策

| 决策 | 原因 |
|------|------|
| Isar（非持久化的 SharedPreferences）| 支持复杂查询和事务 |
| 两个分离的队列 | 播放优先级 vs 后台处理 |
| 手动 > 自动 > 原始 | 尊重用户手动输入 |
| 缓存搜索结果 | 避免重复请求 API |
| 异步刮削 | 防止 UI 阻塞 |

---

## 风险 & 缓解方案

| 风险 | 缓解 |
|------|------|
| API 限流 | 实现速率限制 + 指数退避 |
| 搜索错误匹配 | 显示匹配度分数让用户决策 |
| 用户数据丢失 | 所有操作前备份 + Isar 事务 |
| 性能问题阻塞播放 | 后台线程 + 异步处理 |

