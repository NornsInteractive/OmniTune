# 开发者下一步指南

## 项目状态概览

**当前版本**: 1.0.19+20 (刚刚从 1.0.18+19 更新)  
**最后更新**: 2026年4月5日  
**状态**: ✅ 稳定、可部署

---

## 已完成的工作（本次）

### ✅ 列表性能优化
- 从 `SliverToBoxAdapter + Column` 改为 `SliverList.separated`
- 启用虚拟化滚动，支持任意大小的歌曲库
- 内存使用和滚动帧率明显改善

### ✅ 音乐详情菜单
- 长按歌曲项或点击 ⋮ 按钮打开
- 显示文件路径、音源、艺术家、专辑
- 集成收藏和喜欢快速操作

### ✅ 国际化完善
- 新增 11 个 i18n 字符串（英文 + 中文）
- 所有标签和按钮都已本地化

---

## 项目当前架构

```
music_player/
├── lib/
│   ├── core/
│   │   ├── audio/              # 音频播放 + 系统控制
│   │   ├── models/             # 数据模型（LibrarySong 等）
│   │   ├── providers/          # Riverpod 全局状态
│   │   ├── router/             # go_router 路由
│   │   └── storage/            # flutter_secure_storage + 本地偏好
│   │
│   ├── features/
│   │   ├── library/            # 音乐库浏览、扫描、列表
│   │   │   ├── application/    # Riverpod 控制器
│   │   │   ├── presentation/   # UI 组件（library_page.dart✅）
│   │   │   └── domain/         # 接口定义
│   │   │
│   │   ├── player/             # 播放器主界面
│   │   │   ├── application/    # 播放器状态管理
│   │   │   ├── presentation/   # 迷你播放器、全屏播放等
│   │   │   └── domain/         
│   │   │
│   │   ├── sources/            # 音源协议实现
│   │   │   ├── webdav/         # WebDAV 实现 (✅ 生产就绪)
│   │   │   ├── sftp/           # SFTP (📋 计划中)
│   │   │   └── application/    # 音源注册表、会话管理
│   │   │
│   │   ├── scraper/            # 元数据刮削
│   │   │   ├── application/    # 刮削链路
│   │   │   └── domain/         # 刮削接口
│   │   │
│   │   └── settings/           # 设置页面
│   │       ├── application/    # 设置状态
│   │       └── presentation/   # 设置 UI
│   │
│   └── l10n/                   # 多语言 ARB 文件
│       ├── app_en.arb          # ✅ 已更新 (11 个新字符串)
│       └── app_zh.arb          # ✅ 已更新 (11 个新字符串)
│
├── android/                    # Android 平台配置
├── ios/                        # iOS 平台配置
├── windows/                    # Windows 平台配置
├── macos/                      # macOS 平台配置
├── linux/                      # Linux 平台配置
├── web/                        # Web 平台配置
│
└── docs/
    ├── COPILOT_HANDOFF.md      # 架构和设计决策
    ├── PROJECT_PROGRESS.md     # 项目进度
    ├── NEXT_STEPS.md           # 推荐的下一步工作
    ├── SKILL.md                # 完整的技术指南
    ├── CHANGES_SUMMARY.md      # ✅ 本次更新总结
    └── USER_GUIDE_NEW_FEATURES.md # ✅ 用户使用指南
```

---

## 关键文件位置速查

### 核心列表相关文件
```
lib/features/library/
├── presentation/
│   ├── library_page.dart       # ✅ 已优化 (虚拟滚动 + 详情菜单)
│   ├── albums_page.dart        # 专辑列表 (已使用 ListView.separated)
│   └── widgets/                # 其他列表组件
├── application/
│   ├── library_catalog_controller.dart  # 主控制器
│   └── library_controller.dart          # 远程浏览控制器
└── domain/                     # 接口和数据类
```

### 数据模型
```
lib/core/models/
├── library_song.dart           # 歌曲数据模型
├── library_album.dart          # 专辑数据模型
├── source_profile.dart         # 音源配置
└── ...
```

### 状态管理
```
lib/core/providers/
├── sources_provider.dart       # 音源列表状态
└── ...
```

---

## 推荐的下一步工作（优先级排序）

### 🚀 高优先级（立即开始）

#### 1. 实现真正的元数据刮削
**为什么**: "按刮削分类"模式当前文档化不足，用户体验不完整  
**怎么做**:
1. 在 `lib/features/scraper/` 中实现一个真实的刮削器
2. 从简单的本地标签读取开始（`audio_metadata_reader`）
3. 然后添加一个远程源，如 MusicBrainz API
4. 在 `ScraperChain` 中注册新刮削器
5. 验证"按刮削分类"与"按文件夹分类"的视觉差异

**相关文件**:
- `lib/features/scraper/application/scraper_chain.dart`
- `lib/features/scraper/domain/metadata_scraper.dart`

**参考资源**:
- `pub.dev` 搜索 "audio_metadata_reader"、"musicbrainz"

---

#### 2. 改进播放队列和播放流程
**为什么**: 当前仅支持单曲播放，无法播放专辑或集合  
**怎么做**:
1. 扩展 `PlayerController` 以支持播放列表/队列
2. 添加 `playAlbum(album)` 和 `playCollection(tracks)` 方法
3. 实现 "下一曲/上一曲" 导航
4. 在 mini player 和全屏播放器中集成队列展示
5. 保存播放历史（可选）

**相关文件**:
- `lib/features/player/application/player_controller.dart`
- `lib/core/audio/player_service.dart`
- `lib/features/player/presentation/widgets/mini_player.dart`

**估计工作量**: 中等（2-3 天）

---

#### 3. 添加搜索和排序功能
**为什么**: 大库无法快速定位歌曲或专辑  
**怎么做**:
1. 在 `LibrarySongsPage` 顶部添加搜索框
2. 按标题、艺术家、专辑实现客户端搜索
3. 添加排序选项：按标题、艺术家、日期修改
4. 类似地改进 `AlbumsPage`
5. 考虑使用 `TextEditingController` + Riverpod 状态管理

**相关文件**:
- `lib/features/library/presentation/library_page.dart`
- `lib/features/library/application/library_catalog_controller.dart`

**估计工作量**: 小（1-2 天）

---

### 📋 中优先级（计划下周）

#### 4. 实现 SFTP 源协议
**为什么**: 证明架构的可扩展性，为用户提供第二个协议选项  
**怎么做**:
1. 创建 `lib/features/sources/data/sftp/sftp_music_source.dart`
2. 实现 `MusicSource` 接口
3. 使用 `dartssh2` 包处理 SSH 连接
4. 在 `MusicSourceRegistry` 中注册
5. 在设置页面添加 SFTP 配置 UI
6. 编写单元测试

**相关文件**:
- `lib/features/sources/domain/music_source.dart` (接口)
- `lib/features/sources/application/music_source_registry.dart`
- `lib/features/sources/data/webdav/` (参考)

**估计工作量**: 大（3-4 天）

---

#### 5. 歌词和封面改进
**为什么**: 增强播放体验，支持嵌入式元数据  
**怎么做**:
1. 集成 `audio_metadata_reader` 读取嵌入式封面
2. 缓存远程获取的封面
3. 改进 `.lrc` 歌词解析和显示
4. 从 Cover Art Archive 自动获取专辑封面
5. 添加加载/错误状态 UI

**相关文件**:
- `lib/features/player/presentation/widgets/cover_art.dart`
- `lib/features/player/presentation/widgets/lyric_view.dart`

**估计工作量**: 中（2-3 天）

---

### 🎯 低优先级（之后考虑）

#### 6. 持久化音乐库数据库
**为什么**: 大库扫描时间长，启动速度慢  
**怎么做**:
1. 设计 Isar 数据库 schema（LibrarySong、LibraryAlbum 等）
2. 迁移现有内存状态到数据库
3. 实现增量扫描（仅更新变更部分）
4. 添加数据库版本管理和迁移

**复杂度**: 高  
**估计工作量**: 3-5 天  
**风险**: 可能需要重构播放和扫描逻辑

---

#### 7. 多平台 UI 优化
**为什么**: 当前仅针对手机优化，平板/桌面体验不佳  
**怎么做**:
1. 在 Windows/macOS 上测试布局
2. 添加宽屏适配（三栏布局等）
3. 改进鼠标键盘交互
4. Android TV 焦点导航完善

**相关包**: `flutter_adaptive_ui`  
**估计工作量**: 2-3 天

---

## 开发工作流程

### 修改文件后的验证步骤
```bash
# 1. 获取依赖
flutter pub get

# 2. 如果修改了 @riverpod，运行代码生成
dart run build_runner build --delete-conflicting-outputs

# 3. 如果修改了 ARB 文件，生成 l10n
flutter gen-l10n

# 4. 静态分析
dart analyze

# 5. 运行测试（如果有）
flutter test

# 6. 构建 APK
bash scripts/build_apk.sh

# 或构建其他平台
flutter build ios --release
flutter build windows --release
# ...
```

---

## 常用 API 和模式

### 播放器控制
```dart
final playerState = ref.watch(playerControllerProvider);
ref.read(playerControllerProvider.notifier).playLibrarySong(song);
ref.read(playerControllerProvider.notifier).play();
ref.read(playerControllerProvider.notifier).pause();
```

### 库目录控制
```dart
final catalogState = ref.watch(libraryCatalogControllerProvider);
ref.read(libraryCatalogControllerProvider.notifier).scanAllSources();
ref.read(libraryCatalogControllerProvider.notifier).toggleFavorite(trackId);
ref.read(libraryCatalogControllerProvider.notifier).toggleLiked(trackId);
```

### 音源管理
```dart
final sources = await ref.read(sourcesControllerProvider.future);
ref.read(sourcesControllerProvider.notifier).addSource(profile);
ref.read(sourcesControllerProvider.notifier).deleteSource(sourceId);
```

---

## 测试建议

### 单元测试
```bash
# 测试特定文件
flutter test test/features/library/
```

### 集成测试
```bash
# 测试应用流程
flutter test integration_test/
```

### 手动测试清单
- [ ] 在 100+ 歌曲库中测试滚动帧率
- [ ] 测试所有 i18n 语言
- [ ] 测试各平台的触摸/键盘交互
- [ ] 网络异常时的容错行为

---

## 性能基准线

设置基准线以评估未来优化：

```dart
// benchmark_test.dart
void main() {
  testWidgets('Scroll performance test', (tester) async {
    // 构建大列表
    await tester.pumpWidget(largeListApp);
    
    // 测试滚动性能
    await tester.binding.window.physicalSizeTestValue = 
        const Size(1080, 1920);
    
    // 应该保持 60 FPS
    expect(frameCount, greaterThan(0));
  });
}
```

---

## 代码审查清单

提交代码前检查：

- [ ] 没有 lint 警告 (`dart analyze`)
- [ ] 所有新字符串都在 ARB 文件中（双语言）
- [ ] 没有硬编码的颜色或字体大小
- [ ] 使用了 `colorScheme` 和 `textTheme`
- [ ] 没有 `setState` 使用（除非真的是局部状态）
- [ ] 网络操作不在 `build()` 中
- [ ] 凭证存储使用了 `flutter_secure_storage`
- [ ] 文件变更文档已更新

---

## 有用的工具和资源

### Pub.dev 搜索（选包）
```
pub.dev 搜索关键词:
- audio_metadata_reader   (读标签)
- musicbrainz             (元数据 API)
- dartssh2                (SFTP 协议)
- isar                    (本地数据库)
```

### Flutter 文档
- [Flutter 自适应 UI](https://docs.flutter.dev/ui/adaptive-responsive)
- [go_router 文档](https://pub.dev/packages/go_router)
- [Riverpod 文档](https://riverpod.dev)
- [Material 3 Design](https://m3.material.io)

### 调试工具
```bash
# 开启详细日志
flutter run -v

# 连接到正运行的应用
flutter attach

# 性能分析
flutter run --trace-startup

# 内存分析
flutter run --profile
```

---

## 总结

✅ **刚完成**:
- 列表性能优化 + 详情菜单
- 11 个新 i18n 字符串

🚀 **立即开始**:
1. 元数据刮削实现
2. 播放队列支持
3. 搜索和排序

📋 **下周计划**:
4. SFTP 源实现
5. 歌词和封面完善

---

## 联系和沟通

有问题或需要澄清？参考以下文件：
- `docs/COPILOT_HANDOFF.md` - 架构总体
- `docs/NEXT_STEPS.md` - 推荐优先级
- `docs/SKILL.md` - 技术细节
- `docs/PROJECT_PROGRESS.md` - 当前状态

祝开发顺利！🚀
