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
原生音频回归测试需要 Linux/libmpv 和音频输出；无声卡的 CI 可使用临时 ALSA null 配置运行测试，不修改应用的实际输出设置。

## UI 工作流

读取 AGENTS.md 和项目进度中的会话 ID。通过 `agy --conversation <ID>` 恢复 **OmniTune**，使用 design-taste-frontend skill，以 Flutter Material 实现视觉和动画。
Codex 可审查和定位，但全部 UI 实现和回归修复交回同一会话。

## 平台与性能

保留 Android、iOS、macOS、Windows、Linux、Web 和 Android TV 适配。Web 不使用 dart:io；SFTP/FTP/Samba 的入口按平台限制。
TV 必须可用方向键/确认/返回控制，文字按 18sp 最低要求检查。
性能报告区分脚本基准、Widget 重建/懒加载检查与真机 profile 帧耗时，禁止用测试耗时宣称全平台 FPS。
原生缓存序列化在后台 isolate 执行；Web 编码和歌曲对象恢复按 128 首分批让出事件循环。Web 的原始 JSON 解码及 SharedPreferences 写入仍需浏览器 profile 验证。

## 文档维护

仅维护 README、AGENTS、CHANGELOG 与 docs 中当前文档；不要为每次任务新增完成证书、重复交付清单或版本化 README。
历史报告和被删除的旧代码可从 Git 历史查询。
