# Flutter Music Player — Codex / AI Agent Rules
# 适用于 AGENTS.md (OpenAI Codex) 或 CLAUDE.md (Claude Code)

## 项目身份

**项目名称**: flutter_music_player
**技术**: Flutter 3.x + Dart 3.x
**架构**: Feature-first + Clean Architecture（轻量版）
**状态管理**: Riverpod (code generation)
**目标平台**: Android · iOS · macOS · Windows · Linux · Web · Android TV

---

## Agent 必读规则（执行任何任务前先读）

### 1. 不重造轮子
在实现任何功能前，先检查 `pubspec.yaml` 是否已有相关包。
优先顺序：**已有包 > pub.dev 成熟包 > 自行实现**

查找包的方法：
```bash
flutter pub search <keyword>
# 或访问 https://pub.dev
```

### 2. 代码生成
项目使用 `build_runner` 生成 Riverpod 代码；当前扫描缓存使用 JSON，元数据使用 SharedPreferences。
修改带 `@riverpod`、`@collection`、`@JsonSerializable` 注解的文件后，必须运行：
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 2.1 APK 构建验证
每次完成代码修改后，必须执行一次：
```bash
./scripts/build_apk.sh
```
如果构建失败，必须先修复构建问题，再结束本次任务。

### 3. 平台适配检查
添加新功能时必须考虑所有目标平台：
```
□ Android (手机 + Android TV)
□ iOS
□ macOS
□ Windows  
□ Linux
□ Web
```
不支持某平台的功能必须用 `kIsWeb`、`Platform.isWindows` 等做条件判断，或使用 `dart:io` + `kIsWeb` 组合。

### 4. 禁止行为
- ❌ 禁止硬编码任何颜色值（必须用 `colorScheme`）
- ❌ 禁止硬编码任何显示字符串（必须用 i18n）
- ❌ 禁止在 Widget `build()` 中做网络请求
- ❌ 禁止明文存储凭证（必须用 `flutter_secure_storage`）
- ❌ 禁止阻塞主线程超过 16ms 的操作
- ❌ 禁止直接使用 `setState`（除非是纯本地 UI 状态）

---

### 5. UI 实现与 Antigravity 会话（长期规则）
- 所有 UI 问题、页面设计、组件布局、交互动画、界面重建优化和 UI 回归修复，全部交给 **Antigravity（agy）** 实现；Codex 负责定位、业务逻辑、审查和验证。
- 必须使用 **design-taste-frontend（taste skill）**；Flutter 页面将其视觉、动效和审计原则应用到 Material 原生组件，不能引入 React/CSS 或网页技术替代 Flutter。
- 本项目全部 UI 工作复用同一个 agy 会话，会话名称固定为 **OmniTune**。会话 ID 记录在 `docs/PROJECT_PROGRESS.md`；使用 `agy --conversation <ID>` 明确恢复，禁止用 `--continue` 猜测最近会话。
- 首次创建后使用 `/rename OmniTune` 命名。后续不得为单个页面新建会话；会话不可恢复时先报告原因。
- agy 使用 **Gemini 3.8 Flash**（CLI 模型 `gemini-3.8-flash-high`）；启动时核对当前登录账号，只记录账号前缀。用户明确更换账号后，后续请求重新加载当前认证，不恢复此前账号；本轮用户已从 `mel` 更换为 `wjh`。CLI 返回旧会话错误时，先重启本项目的 agy 进程并核对本轮日志、回复和实际代码变更，不能仅凭残留错误判定当前额度耗尽。
- 明暗主题、i18n、用户主题配置、键鼠和 Android TV D-pad 必须保留；动画遵守系统减少动态效果设置，隐藏页面停止动画。
- 交付 UI 时必须附上测试结果和实际验证范围；未做真机性能测量时不得声称所有平台卡顿已解决。

### 6. 测试与 OpenCode 免费模型（长期规则）
- 所有测试代码、回归用例、测试脚本和性能测试的新增及修改，全部交给 **OpenCode 免费模型** 实现；所有测试执行、静态检查及 ADB 验收也由该免费模型完成。Codex 不执行测试，只负责定位、实现、审查结果和发布。
- 尽量减少 Codex 在测试上的 token：让 OpenCode 写入结果 JSON 与日志，只读取汇总及必要失败摘要，避免重复展开完整日志和测试实现。
- OpenCode 在隔离副本中实现测试，审查补丁后再回写项目；禁止对共享工作区执行 `git stash`、`restore`、`reset`、`checkout`、`clean` 或覆盖已有改动。
- 调用前确认模型输入、输出费用均为 0，明确指定免费模型；免费模型不可用时记录具体原因，不得自动切换收费模型。
- UI 产品代码仍由上述固定的 **OmniTune** agy 会话实现；UI 测试也遵守本条 OpenCode 分工。
- 可以通过 ADB 安装并测试，记录设备、版本、播放场景和实际指标；未经明确授权不得卸载应用、清除数据或替换签名以绕过安装失败。

---

## 任务执行协议

### 添加新音乐源协议
1. 在 `lib/features/sources/data/{protocol}/` 创建实现
2. 实现 `lib/features/sources/domain/music_source.dart` 中的 `MusicSource` 接口
3. 在 `lib/features/sources/application/music_source_registry.dart` 注册
4. 交给 Antigravity 在 `lib/features/settings/presentation/add_source_page.dart` 添加配置 UI
5. 添加对应的 ARB 字符串
6. 写单元测试（mock 网络层）

### 添加新刮削源
1. 在 `lib/features/scraper/` 创建 `{source}_scraper.dart`
2. 实现 `MetadataScraper` 接口
3. 设置合理的 `priority` 值
4. 在 `lib/features/scraper/application/scraping_provider.dart` 的现有刮削协调链路中接入
5. 处理速率限制（API 有限制的加 delay）

### 添加新语言
1. 复制 `lib/l10n/app_en.arb` 为 `app_{locale}.arb`
2. 翻译所有字段
3. 在 `MaterialApp` 的 `supportedLocales` 中添加
4. 运行 `flutter gen-l10n` 验证

### 修改播放逻辑
1. 所有播放操作通过 `PlayerController`（`playerControllerProvider.notifier`）进行
2. 直接操作 `AudioPlayer` 的代码只允许存在于 `player_service.dart`
3. 修改后检查 Android TV 的 D-pad 控制是否仍正常

---

## 目录职责说明

```
lib/core/audio/          → just_audio 封装，audio_service handler
lib/core/database/       → JSON 扫描缓存、SharedPreferences 元数据和 repositories
lib/core/router/         → go_router 路由配置
lib/features/library/    → 音乐库浏览、扫描
lib/features/player/     → 播放器界面（迷你播放器、全屏播放）
lib/features/sources/    → 各协议的 MusicSource 实现
lib/features/scraper/    → 元数据/封面刮削
lib/features/settings/   → 设置页（音源管理、主题、语言）
lib/l10n/               → 多语言 ARB 文件
```

---

## 常用命令

```bash
# 获取依赖
flutter pub get

# 代码生成（Riverpod 等注解）
dart run build_runner build --delete-conflicting-outputs

# 生成 l10n
flutter gen-l10n

# 运行测试
flutter test

# 格式化代码
dart format lib/

# 静态分析
dart analyze

# 构建各平台
flutter build apk --release          # Android
flutter build ios --release          # iOS
flutter build macos --release        # macOS
flutter build windows --release      # Windows
flutter build linux --release        # Linux
flutter build web --release          # Web
```

---

## 依赖版本锁定原则

- 使用 `^` 前缀允许次版本更新（如 `^2.5.1`）
- 核心音频包（`just_audio`、`audio_service`）版本变动需全平台测试后才升级
- 升级依赖后运行 `flutter pub upgrade --major-versions` 检查破坏性变更

---

## 调试指南

### 音频播放问题
```dart
// 开启 just_audio 详细日志
AudioPlayer.useAndroidExoplayer; // Android 指定引擎
// Windows/Linux: 检查 libmpv 是否正确打包
```

### 协议连接问题
- SFTP：检查 `dartssh2` 的 `hostKey` 验证设置
- WebDAV：注意 URL 末尾斜杠，某些服务器敏感
- 百度网盘：注意 OAuth2 redirect_uri 白名单

### 刮削不生效
1. 检查 `ScrapedMetadata.priority` 排序
2. 检查元数据缓存是否仍在有效期内
3. MusicBrainz 搜索建议使用 `artist:xxx AND recording:xxx` 格式

---

## 已知平台限制

| 功能 | Web | 说明 |
|------|-----|------|
| SFTP | ❌ | WebSocket 限制 |
| FTP | ❌ | 浏览器安全策略 |
| 本地文件访问 | ⚠️ | 仅 File System Access API |
| 后台播放 | ⚠️ | 依赖 MediaSession API |
| DSD 音频 | ❌ | 无浏览器支持 |

| 功能 | Android TV | 说明 |
|------|-----------|------|
| 触摸手势 | ❌ | 改用 D-pad |
| 小字体 | ⚠️ | 最小 18sp |
| 悬浮窗 | ❌ | TV 不支持 |



Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
