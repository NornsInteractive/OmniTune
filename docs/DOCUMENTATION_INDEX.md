# 刮削功能实现 - 文档导航

**本文档维护日期**: 2026-04-15  
**项目版本**: 1.0.23+24  
**当前阶段**: Phase 1-2 (Backend 完成) + **Debug System 实现** ✅  

---

## 📚 文档阅读顺序（新工程师必读）

### 第一步：了解项目整体
1. **[AGENTS.md](../AGENTS.md)** - AI Agent 规则和项目身份
2. **[.github/copilot-instructions.md](../.github/copilot-instructions.md)** - 当前工作规范

### 第二步：了解刮削功能
3. **[SCRAPER_ARCHITECTURE.md](./SCRAPER_ARCHITECTURE.md)** - 系统架构设计（详细）
4. **[SCRAPER_PHASE12_COMPLETE.md](./SCRAPER_PHASE12_COMPLETE.md)** - 当前进度总结（编译成功）
5. **[SCRAPER_PHASE1_COMPLETE.md](./SCRAPER_PHASE1_COMPLETE.md)** - Phase 1 数据模型详解

### 第三步：📍 **新增 - 调试系统学习** (最重要！)
6. **[SCRAPER_DEBUG_QUICK_START.md](./SCRAPER_DEBUG_QUICK_START.md)** - ⭐ 🔍 快速启动指南 (30 秒)
7. **[SCRAPER_DEBUG_GUIDE.md](./SCRAPER_DEBUG_GUIDE.md)** - 完整调试参考手册
8. **[DEBUG_SYSTEM_IMPLEMENTATION.md](./DEBUG_SYSTEM_IMPLEMENTATION.md)** - 调试系统实现细节

### 第四步：开始实现（选择性）
- 准备 Phase 3 UI 实现
- 实现手动刮削对话框
- 集成搜索结果选择器

---

## 📋 快速导航

### 架构与设计
- **系统架构** → [SCRAPER_ARCHITECTURE.md](./SCRAPER_ARCHITECTURE.md)
  - 数据模型设计
  - 搜索缓存策略
  - 数据流图
  - API 集成方案

### 🔍 **调试系统** (新增)
- **快速启动** → [SCRAPER_DEBUG_QUICK_START.md](./SCRAPER_DEBUG_QUICK_START.md)
  - 30秒启用调试
  - 检查清单
  - 故障排除树
  
- **完整参考** → [SCRAPER_DEBUG_GUIDE.md](./SCRAPER_DEBUG_GUIDE.md)
  - 所有追踪点详解
  - 模块日志说明
  - 问题排查指南
  
- **实现细节** → [DEBUG_SYSTEM_IMPLEMENTATION.md](./DEBUG_SYSTEM_IMPLEMENTATION.md)
  - 设计概览
  - 追踪点列表
  - 编译验证
  - 代码示例

### 实现进度
- **Phase 1-2 总结** → [SCRAPER_PHASE12_COMPLETE.md](./SCRAPER_PHASE12_COMPLETE.md)
  - 编译状态 ✅
  - 文件清单
  - 代码统计
  - 下一步计划

- **Phase 1 详解** → [SCRAPER_PHASE1_COMPLETE.md](./SCRAPER_PHASE1_COMPLETE.md)
  - 数据模型详情
  - Repository 类详解
  - 文件名解析器文档

### 源代码位置
```
后端实现已完成 ✅
├── 调试系统 ✅ (新增)
│   └── lib/core/utils/
│       └── debug_logger.dart (140 行)
│
├── 数据模型
│   └── lib/core/database/
│       ├── isar_manager.dart (加入调试)
│       ├── scraping_metadata.dart
│       ├── scraping_cache.dart
│       ├── scraping_metadata_repository.dart (加入调试)
│       └── scraping_cache_repository.dart
│
├── 文件名解析
│   └── lib/features/scraper/utils/
│       └── file_name_parser.dart
│
├── MusicBrainz 集成 (加入调试)
│   └── lib/features/scraper/data/
│       ├── musicbrainz_client.dart (完整日志)
│       └── musicbrainz_scraper.dart (完整日志)
│
├── Riverpod Providers(加入调试)
│   └── lib/features/scraper/application/
│       └── scraping_provider.dart (完整日志)
│
├── 设置集成 (加入调试开关)
│   └── lib/features/settings/presentation/
│       └── settings_page.dart (加入 DebugLogger 连接)
│
└── 国际化 (加入调试字符串)
    └── lib/l10n/
        ├── app_en.arb (+1 字符串)
        └── app_zh.arb (+1 字符串)

UI 实现待做 ⏳
├── 手动刮削对话框
├── 搜索结果列表
├── 歌曲列表集成
└── 播放器集成
```

---

## 🎯 当前任务优先级

### 🔴 必做 (High Priority)
1. **⭐ 快速验证调试系统**
   - 启用调试模式 (设置 → 开发者)
   - 执行搜索操作
   - 查看调试输出 (应该显示 🎵 等符号)

2. **熟悉日志系统**
   - 阅读 [SCRAPER_DEBUG_QUICK_START.md](./SCRAPER_DEBUG_QUICK_START.md)
   - 理解各种符号含义
   - 学会快速诊断

3. **快速验证后端**
   - 运行 `flutter pub get`
   - 运行 `dart run build_runner build`
   - 检查编译输出（应该是 0 errors）

### 🟡 建议 (Medium Priority)
4. **诊断现有问题**
   - 如果没有歌曲刮削成功
   - 按照调试指南排查问题
   - 记录所有错误信息

5. **实现手动刮削 UI**
   - 创建对话框组件
   - 实现搜索表单
   - 创建结果列表

### 🟢 后续 (Low Priority)
6. **集成到现有 UI**
   - 添加菜单选项
   - 连接 Provider 调用
   - 处理加载状态和错误

7. **后台队列系统**
8. **播放器集成**
9. **测试和优化**

---

## 📊 代码统计

| 阶段 | 文件数 | 代码行数 | 编译 | 调试 |
|------|--------|---------|------|------|
| Phase 1 | 8 | ~1000 | ✅ | ✅ |
| Phase 2 | 3 | ~650 | ✅ | ✅ |
| Debug | 1 | ~140 | ✅ | ✅ |
| **总计** | **12+** | **~1800** | **✅** | **✅** |

---

## ✅ 检查清单

若要开始 UI 实现，请先验证：

- [ ] `flutter pub get` 成功
- [ ] `dart run build_runner build` 成功
- [ ] `dart analyze` 无错误
- [ ] 可以导入 `scraping_provider`
- [ ] 理解 `searchMetadata` 的使用方式
- [ ] **📍 新增**: 启用调试模式并看到 🔍 符号
- [ ] **📍 新增**: 理解至少 3 种主要的调试符号 (🎵, ✅, ❌)

---

## 🔗 关键链接

### 内部文档
- **项目规范** → [AGENTS.md](../AGENTS.md)
- **工作指南** → [.github/copilot-instructions.md](../.github/copilot-instructions.md)
- **整体进度** → [HANDOFF_SUMMARY.md](../HANDOFF_SUMMARY.md)
- **项目档案** → [SCRAPER_PROJECT_ARCHIVE.md](../SCRAPER_PROJECT_ARCHIVE.md)

### 外部资源
- **MusicBrainz API** → https://musicbrainz.org/doc/MusicBrainz_API
- **Cover Art Archive** → https://coverartarchive.org/
- **Flutter Riverpod** → https://riverpod.dev/
- **pub.dev** → https://pub.dev/

---

## 💬 常见问题

### Q: 如何启用调试模式?
A: 
打开设置 → 向下滚动找到"开发者" → 打开"调试模式"开关

或者在代码中:
```dart
DebugLogger.setDebugEnabled(true);
```

### Q: 调试日志去哪里看?
A: 
在终端运行:
```bash
flutter run -v 2>&1 | grep "🎵\|✅\|❌"
```

### Q: 没有搜索结果是什么意思?
A:
检查日志中是否有:
```
⚠️ [MusicBrainzScraper] 搜索未返回结果
```
如果是，说明歌曲不在 MusicBrainz 中或名称不匹配

### Q: 如何清空所有刮削数据重新来过?
A:
在调试控制台:
```dart
await IsarManager.clearAll();
print('✅ 已清空所有数据');
```

---

## 📝 笔记

**编译状态** ✅  
后端代码已验证，调试系统完整实现，可以快速诊断问题。

**关键改进** 🔍  
- 从每个关键操作都添加了日志输出
- 错误信息更详细，包含原因分析
- 调试模式可在设置中启用
- 提供了完整的故障排除指南

**下一步行动** 🚀  
1. 启用调试模式验证系统
2. 根据日志诊断问题根源
3. 实现 Phase 3 UI 如果后端正常

**文档完善度** 📚  
- 3 份完整的调试文档
- 覆盖初级到高级使用场景
- 包含快速参考和详细指南
- 附带故障排除决策树

---

**维护者**: AI Agent (GitHub Copilot)  
**更新频率**: 每个 Phase 完成后更新  
**最后更新**: 2026-04-15 23:59:59



---

## 📚 文档阅读顺序（新工程师必读）

### 第一步：了解项目整体
1. **[AGENTS.md](../AGENTS.md)** - AI Agent 规则和项目身份
2. **[.github/copilot-instructions.md](../.github/copilot-instructions.md)** - 当前工作规范

### 第二步：了解刮削功能
3. **[SCRAPER_ARCHITECTURE.md](./SCRAPER_ARCHITECTURE.md)** - 系统架构设计（详细）
4. **[SCRAPER_PHASE12_COMPLETE.md](./SCRAPER_PHASE12_COMPLETE.md)** - 当前进度总结（编译成功）
5. **[SCRAPER_PHASE1_COMPLETE.md](./SCRAPER_PHASE1_COMPLETE.md)** - Phase 1 数据模型详解

### 第三步：开始实现（选择性）
- 准备 Phase 3 UI 实现
- 实现手动刮削对话框
- 集成搜索结果选择器

---

## 📋 快速导航

### 架构与设计
- **系统架构** → [SCRAPER_ARCHITECTURE.md](./SCRAPER_ARCHITECTURE.md)
  - 数据模型设计
  - 搜索缓存策略
  - 数据流图
  - API 集成方案

### 实现进度
- **Phase 1-2 总结** → [SCRAPER_PHASE12_COMPLETE.md](./SCRAPER_PHASE12_COMPLETE.md)
  - 编译状态 ✅
  - 文件清单
  - 代码统计
  - 下一步计划

- **Phase 1 详解** → [SCRAPER_PHASE1_COMPLETE.md](./SCRAPER_PHASE1_COMPLETE.md)
  - 数据模型详情
  - Repository 类详解
  - 文件名解析器文档

### 源代码位置
```
后端实现已完成 ✅
├── 数据模型
│   └── lib/core/database/
│       ├── isar_manager.dart
│       ├── scraping_metadata.dart
│       ├── scraping_cache.dart
│       ├── scraping_metadata_repository.dart
│       └── scraping_cache_repository.dart
│
├── 文件名解析
│   └── lib/features/scraper/utils/
│       └── file_name_parser.dart
│
├── MusicBrainz 集成
│   └── lib/features/scraper/data/
│       ├── musicbrainz_client.dart
│       └── musicbrainz_scraper.dart
│
├── Riverpod Providers（状态管理）
│   └── lib/features/scraper/application/
│       └── scraping_provider.dart
│
└── 国际化
    └── lib/l10n/
        ├── app_en.arb (+24 字符串)
        └── app_zh.arb (+24 字符串)

UI 实现待做 ⏳
├── 手动刮削对话框
├── 搜索结果列表
├── 歌曲列表集成
└── 播放器集成
```

---

## 🎯 当前任务优先级

### 🔴 必做 (High Priority)
1. **快速验证后端**
   - 运行 `flutter pub get`
   - 运行 `dart run build_runner build`
   - 检查编译输出（应该是 0 errors）

2. **熟悉核心 Provider**
   - `searchMetadata(title, artist)` - 搜索接口
   - `applyManualScrapingResult(id, result)` - 应用结果
   - `scrapingStatsProvider` - 查看统计数据

### 🟡 建议 (Medium Priority)
3. **实现手动刮削 UI**
   - 创建对话框组件
   - 实现搜索表单
   - 创建结果列表

4. **集成到现有 UI**
   - 添加菜单选项
   - 连接 Provider 调用
   - 处理加载状态和错误

### 🟢 后续 (Low Priority)
5. **后台队列系统**
6. **播放器集成**
7. **测试和优化**

---

## 📊 代码统计

| 阶段 | 文件数 | 代码行数 | 编译 |
|------|--------|---------|------|
| Phase 1 | 8 | ~1000 | ✅ |
| Phase 2 | 3 | ~650 | ✅ |
| **总计** | **11** | **~1650** | **✅ 0 errors** |

---

## ✅ 检查清单

若要开始 UI 实现，请先验证：

- [ ] `flutter pub get` 成功
- [ ] `dart run build_runner build` 成功
- [ ] `dart analyze` 无错误
- [ ] 可以导入 `scraping_provider`
- [ ] 理解 `searchMetadata` 的使用方式

---

## 🔗 关键链接

### 内部文档
- **项目规范** → [AGENTS.md](../AGENTS.md)
- **工作指南** → [.github/copilot-instructions.md](../.github/copilot-instructions.md)
- **整体进度** → [HANDOFF_SUMMARY.md](../HANDOFF_SUMMARY.md)

### 外部资源
- **MusicBrainz API** → https://musicbrainz.org/doc/MusicBrainz_API
- **Cover Art Archive** → https://coverartarchive.org/
- **Flutter Riverpod** → https://riverpod.dev/
- **pub.dev** → https://pub.dev/

---

## 💬 常见问题

### Q: 如何验证后端是否正常？
A: 
```bash
cd /workspace/music
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze
```

### Q: 如何测试搜索功能？
A: 
在 Dart 代码中调用：
```dart
final results = await ref.refresh(
  searchMetadata(title: '青花瓷', artist: '周杰伦')
);
```

### Q: ScrapedMetadataResult 和 ScrapingMetadata 有什么区别？
A:
- **ScrapedMetadataResult** - 搜索结果（临时，显示给用户）
- **ScrapingMetadata** - 持久化记录（保存到数据库）

### Q: 如何手动应用刮削结果？
A:
```dart
await ref.refresh(
  applyManualScrapingResult(
    fileId: 'source1::path.flac',
    result: selectedResult
  )
);
```

---

## 📝 笔记

**编译状态** ✅  
后端代码已验证，可以直接开始 UI 实现。所有 Provider 聚合完成。

**下一步行动** 🚀  
创建 Phase 3 UI 实现任务，从手动刮削对话框开始。

---

**维护者**: AI Agent (GitHub Copilot)  
**更新频率**: 每个 Phase 完成后更新  
**最后更新**: 2026-04-15 23:59:59

