# 开发与架构

## 代码入口

`lib/main.dart` 初始化应用；`lib/app/` 管理主题、导航和整体布局。
路由位于 `lib/core/router/app_router.dart`，业务按 feature 分为 application / data / domain / presentation。

- 音源：`MusicSource` 定义接口，`music_source_registry.dart` 注册工厂；平台不支持的协议使用条件导入 stub。
- 配置：`source_profile_repository.dart` 使用 flutter_secure_storage 保存音源及认证信息。
- 音乐库：`library_controller.dart` 管理远程浏览，`library_catalog_controller.dart` 管理扫描、分组与收藏。
- 播放：操作通过 `playerControllerProvider.notifier`，AudioPlayer 封装在 `player_service.dart`；不要在 UI 中直接操作播放器。
- 刮削：`scraping_provider.dart` 协调元数据与歌词请求；MusicBrainz、iTunes、Deezer、LRCLIB 的客户端位于 scraper/data。
- 缓存：原生扫描结果写入 JSON，Web 写入 SharedPreferences。`IsarManager` 当前名称沿用历史实现，实际使用 SharedPreferences，并非 Isar 数据库。

## 数据与兼容性

应用更新位于 `lib/features/updates/`，从 Ygg `https://ygg.norns.cc.cd` 的公开更新／下载接口读取 `com.norns.omnitune`、`default` 渠道，按平台与运行时 ABI 筛包；安装版本由 package_info_plus 读取。Android 使用 ota_update 校验平台提供的 SHA-256，再交给系统安装器确认，不提供静默安装。桌面端打开对应 Ygg 下载入口；Web／iOS 不执行 APK 更新。发布管理通过 MCP `/api/mcp` 完成，包源为 GitHub Release，管理凭证不得进入客户端。

用户最新分工：测试代码及测试执行、静态检查、ADB 验收均由 OpenCode 免费模型负责；Codex 只实现、审查结果与发布。测试修改仍在隔离副本交付，不能操作共享工作区的 Git 恢复命令。

保留现有音源键、扫描缓存字段、手动/自动刮削优先级及播放器会话格式。性能改动不要丢失元数据、收藏、播放队列和已保存认证。
天翼密码登录支持验证码回调，应用授权支持 code/refreshToken；cloudTV 模式尚未实现目录和音频读取。

## 生成与验证

```bash
flutter pub get
./scripts/generate_l10n.sh
dart run build_runner build --delete-conflicting-outputs
flutter test
dart analyze
./scripts/build_apk.sh
```

新增显示字符串修改两份 `lib/l10n/app_*.arb`。生成脚本将 Flutter 的输出复制到应用正在使用的 `lib/core/i18n/`，不要手改生成文件。
修改带 Riverpod 等注解的文件或移除对应 provider 后重新运行 build_runner。
格式化仅限修改文件，不顺带重排无关代码。

APK 构建脚本递增 pubspec 版本，并构建 AAB 与 APK。`android/upload-keystore.jks` 和 `android/key.properties` 是上传签名，首次生成后应安全备份，不能提交到 Git、删除或重新生成替换已有发布签名。

Linux 使用 `just_audio_media_kit` 在 `player_service.dart` 创建播放器前注册 libmpv 后端，只在 Linux 启用；Android/iOS/macOS/Web 保持原有后端。Linux 构建依赖 GTK 3/libsecret 开发包，运行依赖 libmpv；`media_kit_libs_linux` 不打包系统 libmpv，需要用户安装。

```bash
flutter build linux --release
```

分发完整 `build/linux/x64/release/bundle/`，不能只分发可执行文件。本次构建环境为 Debian 12 x86_64 / glibc 2.36，其他发行版需检查 ABI 与系统库兼容。
原生音频回归测试需要 Linux/libmpv 和音频输出；无声卡的 CI 可使用临时 ALSA null 配置，或以 `SDL_AUDIODRIVER=dummy flutter test --no-pub` 使用 SDL 虚拟输出，不修改应用的实际输出设置。虚拟输出能验证解码、播放进度、暂停和跳转，不能验证真实扬声器出声。

## UI 工作流

读取 AGENTS.md 和项目进度中的会话 ID。通过 `agy --conversation <ID> --model gemini-3.8-flash-high` 恢复 **OmniTune**，确认账号前缀为 `mel`，使用 design-taste-frontend skill，以 Flutter Material 实现视觉和动画。遇到 CLI 残留的历史额度错误，重启本项目进程并检查本轮回复、日志和实际变更。
Codex 可审查和定位，但全部 UI 实现和回归修复交回同一会话。

所有测试代码、回归用例、ADB 自动化与性能测试脚本的新增或修改交给 OpenCode 免费模型；调用前确认模型费用为 0，不自动回退到收费模型。Codex 可审查、运行测试并记录证据。此规则也适用于 UI 测试；产品 UI 代码继续由固定 OmniTune agy 会话实现。

## 平台与性能

保留 Android、iOS、macOS、Windows、Linux、Web 和 Android TV 适配。Web 不使用 dart:io；SFTP/FTP/Samba 的入口按平台限制。
TV 必须可用方向键/确认/返回控制，文字按 18sp 最低要求检查。
性能报告区分脚本基准、Widget 重建/懒加载检查与真机 profile 帧耗时，禁止用测试耗时宣称全平台 FPS。
原生缓存序列化在后台 isolate 执行；Web 编码和歌曲对象恢复按 128 首分批让出事件循环。Web 的原始 JSON 解码及 SharedPreferences 写入仍需浏览器 profile 验证。

流式播放缓存使用可扩容缓冲区，下载进度限频 250ms，完成或终止时通知最终状态；保留乱序覆盖和缓存空洞语义。原生播放会话编解码通过 compute 执行，保存与清除串行，旧 `player_session_v1` 字段不变。

OpenCode 免费模型实现的 Android 测试工具：

```bash
python3 scripts/test_android_playback.py --self-test
python3 scripts/test_android_playback.py --capture-only --serial <设备ID> --sample-seconds 30 --output-dir build/validation/android-playback
python3 scripts/measure_android_playback.py --self-test
python3 scripts/measure_android_playback.py --serial <设备ID> --seconds 1800 --output-dir build/validation/long-playback
```

长时采样工具按应用记录 PSS/RSS、系统媒体状态和播放位置。使用原签名的 profile 包并转发 Dart VM Service 后，可通过 `--vm-service-url` 提供本机地址，采集 `Frame` 和 `GPURasterizer::Draw` 的耗时分布；地址不会写入报告。指标来自轮询取得的事件，不代表完整呈现帧率。`logcat.fatal` 仅统计当前 PID 的 Java `FATAL EXCEPTION` 日志差值，不覆盖所有原生崩溃。缺失设备、帧事件、可靠 ANR 或应用网络数据时报告 `not measured`，不可解释为零卡顿、零 ANR 或零网络流量。

实际音乐播放后执行 capture-only，不生成测试音源或修改账号配置。必要时使用 --serve-only 提供临时 WebDAV/WAV 音源，测试文件位于忽略目录。证据包含包 PID 日志、gfxinfo 和实际 SurfaceFlinger 图层记录；不能直接把 gfxinfo 百分比当成 Flutter FPS。

## 系统播放器与缓存边界

媒体操作统一回到 PlayerController，AudioPlayer 仅由 player_service.dart 操作。进度同步最多每秒一次，播放状态、切歌、收藏、模式和主动跳转立即同步；系统队列按播放列表版本更新并每 64 项让出事件循环。封面异步解析后核对当前媒体标识，原生系统只接收缓存文件 URI，缺失时使用现有品牌图。

原生音频缓存按实际保留的缓冲区容量限制为 64 MiB；先回收非活动歌曲，当前歌曲超限后继续转发网络音频而停止追加内存缓存。这不是整个进程的内存上限，也不限制用户配置的磁盘缓存。扫描取消在当前网络请求返回后生效，失败/取消保留旧歌曲及本次已发现歌曲；只有完整成功扫描的音源才删除失效记录。

| 平台 | 当前系统接管范围 | 尚有限制 |
|---|---|---|
| Android / TV | 媒体元数据、封面、播放/暂停、上下首、跳转、收藏/模式动作 | 系统版本决定按钮布局；真实 TV/实体机待验收 |
| iOS / macOS | audio_service 元数据与传输控制；补齐本地网络/客户端权限 | 需 Apple 构建环境与设备验收；系统不保证展示自定义按钮 |
| Linux | MPRIS 元数据、播放/暂停、上下首、绝对位置跳转 | 0.2.1 插件不转发 Stop/相对 Seek；不提供模式和队列交互 |
| Windows | SMTC 元数据、封面、播放/暂停、上下首、停止 | 0.0.3 插件未实现时间轴跳转、队列和模式；需 Windows 构建验收 |
| Web | 浏览器 MediaSession 元数据与支持的媒体动作 | 由浏览器支持情况决定；带查询参数的封面 URL 使用默认图，避免暴露签名凭证 |

不包含 Android Auto、CarPlay 或进程被杀后的冷启动恢复服务。

## 文档维护

仅维护 README、AGENTS、CHANGELOG 与 docs 中当前文档；不要为每次任务新增完成证书、重复交付清单或版本化 README。
历史报告和被删除的旧代码可从 Git 历史查询。
