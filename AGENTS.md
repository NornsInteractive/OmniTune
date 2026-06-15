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
项目使用 `build_runner` 生成代码（Riverpod、Isar、JSON 序列化）。
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

## 任务执行协议

### 添加新音乐源协议
1. 在 `lib/features/sources/` 创建 `{protocol}_source.dart`
2. 实现 `MusicSource` 接口（见 SKILL.md）
3. 在 `lib/core/providers/sources_provider.dart` 注册
4. 在 `lib/features/settings/add_source_page.dart` 添加配置 UI
5. 添加对应的 ARB 字符串
6. 写单元测试（mock 网络层）

### 添加新刮削源
1. 在 `lib/features/scraper/` 创建 `{source}_scraper.dart`
2. 实现 `MetadataScraper` 接口
3. 设置合理的 `priority` 值
4. 在 `ScraperChain` 中注册
5. 处理速率限制（API 有限制的加 delay）

### 添加新语言
1. 复制 `lib/l10n/app_en.arb` 为 `app_{locale}.arb`
2. 翻译所有字段
3. 在 `MaterialApp` 的 `supportedLocales` 中添加
4. 运行 `flutter gen-l10n` 验证

### 修改播放逻辑
1. 所有播放操作通过 `PlayerNotifier` 进行
2. 直接操作 `AudioPlayer` 的代码只允许存在于 `player_service.dart`
3. 修改后检查 Android TV 的 D-pad 控制是否仍正常

---

## 目录职责说明

```
lib/core/audio/          → just_audio 封装，audio_service handler
lib/core/database/       → Isar schemas 和 repositories  
lib/core/providers/      → 全局 Riverpod providers
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

# 代码生成（Riverpod + Isar）
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
2. 检查 Isar 中 `scrapedAt` 是否过于新（缓存未过期）
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

# RTK - Rust Token Killer (Codex CLI)

**Usage**: Token-optimized CLI proxy for shell commands.

## Rule

Always prefix shell commands with `rtk`.

Examples:

```bash
rtk git status
rtk cargo test
rtk npm run build
rtk pytest -q
```

## Meta Commands

```bash
rtk gain            # Token savings analytics
rtk gain --history  # Recent command savings history
rtk proxy <cmd>     # Run raw command without filtering
```

## Verification

```bash
rtk --version
rtk gain
which rtk
```

## Mandatory RTK Rule

ALL shell commands MUST be prefixed with `rtk`.

For codebase inspection, do not page through files with repeated `sed -n` unless a precise line range is already known.

Use this order:
1. `rtk find` to locate candidate files.
2. `rtk grep -n "<keyword>" <path>` to locate exact files and line numbers.
3. Only after line numbers are known, use `rtk summary "sed -n '<start>,<end>p' <file>"` to read the smallest necessary snippet.
4. Avoid repeated sequential `sed -n` scans like `1,120`, `121,240`, `241,360`.
5. Avoid full-file `cat` on large files.

Examples:
- use `rtk grep -n "appointmentPhone" .`
- use `rtk grep -n "phone" flutter/nail_ui/lib`
- use `rtk diff` instead of `git diff`
- use `rtk find . -name "*.dart"` instead of raw `find`
