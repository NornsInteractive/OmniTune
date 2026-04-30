# 刮削功能实现 - Phase 3-4 计划

**日期**: 2026-04-15  
**优先级**: 🔴 HIGH - 用户直接需求  
**估计工时**: 4-5 小时  
**依赖**: Phase 1-2 已完成 ✅  

---

## 📋 任务分解

### Phase 3: 手动刮削 UI 对话框（2-3 小时）

#### 文件：`lib/features/scraper/presentation/manual_scraping_dialog.dart`

```dart
class ManualScrapingDialog extends StatefulWidget {
  // 参数
  final String initialFilename;        // 从文件名自动填充
  final String? initialArtist;         // 可选：当前歌曲艺术家
  final String sourceId;               // 源 ID（用于数据库）
  final String filePath;               // 文件路径（用于数据库）
  
  // 回调
  final Function(ScrapedMetadataResult)? onApply;
  
  // UI 状态
  _DialogState {
    TextEditingController titleController;
    TextEditingController artistController;
    List<ScrapedMetadataResult> searchResults;
    bool isLoading = false;
    String? errorMessage;
    int? selectedIndex;
  }
}

class _DialogState extends State<ManualScrapingDialog> {
  // 初始化：解析文件名
  @override
  void initState() {
    _parseAndFillForm();
  }

  void _parseAndFillForm() {
    final parser = FileNameParser();
    final parsed = parser.parse(widget.initialFilename);
    titleController.text = parsed.title ?? '';
    artistController.text = widget.initialArtist ?? parsed.artist ?? '';
  }

  // 搜索
  void _search() {
    setState(() { isLoading = true; });
    
    final results = await ref.refresh(
      searchMetadata(
        title: titleController.text,
        artist: artistController.text.isNotEmpty 
          ? artistController.text 
          : null,
      )
    );
    
    setState(() {
      searchResults = results;
      isLoading = false;
    });
  }

  // UI 结构
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.manualScrapingTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 输入区域
            _buildInputSection(),
            SizedBox(height: 16),
            
            // 搜索按钮
            ElevatedButton.icon(
              onPressed: isLoading ? null : _search,
              icon: Icon(Icons.search),
              label: Text(AppLocalizations.of(context)!.scrapingSearchButton),
            ),
            SizedBox(height: 16),
            
            // 搜索结果
            if (isLoading)
              LoadingIndicator()
            else if (errorMessage != null)
              ErrorWidget(message: errorMessage!)
            else if (searchResults.isEmpty)
              EmptyStateWidget()
            else
              _buildResultsList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.cancelLabel),
        ),
        ElevatedButton(
          onPressed: selectedIndex != null ? _applyResult : null,
          child: Text(AppLocalizations.of(context)!.confirmLabel),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Column(
      children: [
        TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.scrapingSongName,
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: artistController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.scrapingArtistName,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          final result = searchResults[index];
          return ListTile(
            selected: selectedIndex == index,
            onTap: () => setState(() { selectedIndex = index; }),
            leading: result.coverUrl != null
              ? Image.network(
                  result.coverUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.music_note),
                )
              : Icon(Icons.music_note),
            title: Text(result.title),
            subtitle: Text(result.artist ?? ''),
            trailing: Chip(
              label: Text(
                '${(result.score * 100).toStringAsFixed(0)}%'
              ),
            ),
          );
        },
      ),
    );
  }

  void _applyResult() {
    if (selectedIndex == null) return;
    
    final result = searchResults[selectedIndex!];
    widget.onApply?.call(result);
    
    // 保存到数据库
    await ref.refresh(
      applyManualScrapingResult(
        fileId: '${widget.sourceId}::${widget.filePath}',
        result: result,
      )
    );
    
    Navigator.pop(context);
  }
}
```

#### 关键特性：
- ✅ 自动从文件名提取初始值
- ✅ 实时搜索 MusicBrainz
- ✅ 显示匹配度百分比
- ✅ 封面缩略图预览
- ✅ 选择应用到数据库
- ✅ 错误处理和加载状态

#### 测试清单：
```
□ 对话框打开时文件名正确填充
□ 点击搜索，结果在 3 秒内返回
□ 无搜索结果时显示"未找到"
□ 选择结果后确认按钮启用
□ 确认后数据保存成功
```

---

### Phase 4: 集成到现有 UI（2 小时）

#### 4.1 歌曲列表集成
位置：`lib/features/library/presentation/song_list.dart`

```dart
// 在现有"更多"菜单中添加：
PopupMenuButton<String>(
  onSelected: (value) {
    if (value == 'manual_scraping') {
      _showManualScrapingDialog(context, song);
    }
  },
  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
    // 现有选项...
    
    // 新增：手动刮削
    PopupMenuItem<String>(
      value: 'manual_scraping',
      child: Row(
        children: [
          Icon(Icons.auto_fix_high),
          SizedBox(width: 8),
          Text(AppLocalizations.of(context)!.manualScrapingLabel),
        ],
      ),
    ),
  ],
);

void _showManualScrapingDialog(BuildContext context, LibrarySong song) {
  showDialog(
    context: context,
    builder: (context) => ManualScrapingDialog(
      initialFilename: song.filename,
      initialArtist: song.artist,
      sourceId: song.sourceId,
      filePath: song.filePath,
      onApply: (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.scrapingResultApplied
            ),
          ),
        );
        // 刷新歌曲列表
        setState(() {});
      },
    ),
  );
}
```

#### 4.2 播放器集成
位置：`lib/features/player/presentation/widgets/now_playing_panel.dart`

```dart
// 在歌曲信息区添加操作按钮
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    // 更新封面按钮
    IconButton(
      icon: Icon(Icons.image),
      tooltip: AppLocalizations.of(context)!.scrapingUpdateCoverAction,
      onPressed: () => _showCoverUpdateDialog(context),
    ),
    
    // 获取歌词按钮
    IconButton(
      icon: Icon(Icons.description),
      tooltip: AppLocalizations.of(context)!.scrapingUpdateLyricsAction,
      onPressed: () => _showLyricsDialog(context),
    ),
  ],
);

void _showCoverUpdateDialog(BuildContext context) {
  // 调用 ManualScrapingDialog，只更新封面
  showDialog(
    context: context,
    builder: (context) => ManualScrapingDialog(
      initialFilename: currentSong.filename,
      sourceId: currentSong.sourceId,
      filePath: currentSong.filePath,
      onApply: (result) {
        if (result.coverUrl != null) {
          // 重新加载封面
          setState(() {
            currentSong.displayCoverUrl = result.coverUrl;
          });
        }
      },
    ),
  );
}
```

#### 4.3 打开对话框时的语境
所有调用点应该遵循这个模式：

```dart
showDialog(
  context: context,
  builder: (dialogContext) => ManualScrapingDialog(
    initialFilename: song.filenameWithoutExtension,
    initialArtist: song.artist,
    sourceId: song.sourceId,
    filePath: song.filePath,
    onApply: (selectedResult) {
      // 1. 保存到数据库（由 dialog 内部处理）
      // 2. 刷新 UI（由 onApply 回调处理）
      ScaffoldMessenger.of(context).showSnackBar(...);
      Navigator.pop(dialogContext);
    },
  ),
);
```

---

## 🎯 实现步骤

### 步骤 1: 空结构创建
```bash
# 创建 UI 目录
mkdir -p lib/features/scraper/presentation

# 创建文件
touch lib/features/scraper/presentation/manual_scraping_dialog.dart
```

### 步骤 2: 导入必需的包
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/core/models/library_song.dart';
import 'package:music/features/scraper/application/scraping_provider.dart';
import 'package:music/features/scraper/utils/file_name_parser.dart';
import 'package:music/l10n/app_localizations.dart';
```

### 步骤 3: 编写完整的对话框类

### 步骤 4: 在歌曲列表中添加菜单选项

### 步骤 5: 在播放器中添加按钮

### 步骤 6: 测试和调试

---

## 🧪 测试案例

### 负面测试
```
□ 搜索无结果时显示友好提示
□ 网络超时时显示重试选项
□ 用户取消操作不保存数据
□ 搜索中点击返回不会崩溃
```

### 正面测试
```
□ 标准流程：输入 → 搜索 → 选择 → 确认 → 保存
□ 中文标题搜索正确（"青花瓷"）
□ 带艺术家的精确搜索有效
□ 选择结果后界面刷新显示新元数据
```

### 集成测试
```
□ 从歌曲列表打开对话框
□ 从播放器打开对话框
□ 同时打开多个对话框（并发）
```

---

## 💻 编码风格检查表

在提交前确保：

- [ ] 使用 `AppLocalizations.of(context)!.keyName` 获取所有显示字符串
- [ ] 使用 `Theme.of(context).colorScheme` 获取所有颜色
- [ ] 所有网络调用都通过 Riverpod providers
- [ ] 使用 `flutter_riverpod` 的 `ref` 而不是 `context`
- [ ] 遵循现有的文件结构和命名约定
- [ ] 添加 null-safe 检查
- [ ] 使用 const Widget 优化性能

---

## 🚨 常见问题

### Q: 如何处理网络超时？
A: Dio 客户端已配置 10 秒超时，自动触发 `DioException`
```dart
try {
  final results = await ref.refresh(searchMetadata(...));
} on DioException catch (e) {
  if (e.type == DioExceptionType.connectionTimeout) {
    // 显示重试按钮
  }
}
```

### Q: 搜索后如何刷新结果？
A: 声明 searchResults 为 State 变量，setState 会重建 widget

### Q: 如何验证 onApply 被调用了？
A: 在回调中添加日志或者 ScaffoldMessenger 显示确认消息

---

## 📝 提交清单

完成后请确保：

1. ✅ 所有代码通过 `dart analyze` 检查
2. ✅ 没有 null 安全警告
3. ✅ 文件名遵循 `snake_case` 约定
4. ✅ UI 字符串都使用本地化
5. ✅ 添加了注释说明复杂逻辑
6. ✅ 已测试中文和英文显示
7. ✅ 测试了网络错误场景

---

## 🔗 相关文档

- [SCRAPER_ARCHITECTURE.md](./SCRAPER_ARCHITECTURE.md) - 系统设计
- [SCRAPER_PHASE12_COMPLETE.md](./SCRAPER_PHASE12_COMPLETE.md) - 后端总结
- [AGENTS.md](../AGENTS.md) - 项目规范

---

**预期完成日期**: 2026-04-16  
**优先级**: 🔴 (用户直接需求)  
**难度**: 🟢 (中等)

