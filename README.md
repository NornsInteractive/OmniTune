# OmniTune

Flutter 跨平台音乐播放器，使用 Riverpod 和 go_router。

## 功能

- WebDAV / OpenList、SFTP、FTP、Samba 和天翼网盘音源。
- 文件浏览、多目录扫描、排除目录、文件夹或元数据专辑分组。
- 播放队列、循环与随机播放、播放缓存、系统媒体控制。
- 自动/手动元数据和歌词刮削，收藏与喜欢。
- 明暗主题、主题颜色、字号和界面密度设置，中英文界面；保留已保存背景的显示。

天翼新建音源提供账号密码和应用授权。TV 扫码/短信的数据读取链路尚未完成，暂不开放。
Web 的 SFTP/FTP/Samba 不可用；天翼直连受服务端跨域策略影响。各平台实际验证范围见项目进度。

## 下载与运行

安装包位于 [GitHub Releases](https://github.com/NornsInteractive/OmniTune/releases)。Android 提供签名 APK 和 AAB；Linux 提供 x86_64 压缩包。

Linux 包基于 Debian 12 构建，需要 glibc 2.36 或更新版本，以及 GTK 3、libsecret、libjsoncpp 和 libmpv。Debian 12 / Ubuntu 24.04 可安装运行依赖：

```bash
sudo apt install libgtk-3-0 libsecret-1-0 libjsoncpp25 libmpv2 gnome-keyring
tar -xzf OmniTune-*-linux-x86_64.tar.gz
cd OmniTune-*-linux-x86_64
./music
```

认证信息需要桌面会话中可用且已解锁的 Secret Service/keyring。不能仅复制 `music` 可执行文件，必须保留包内 `lib/` 和 `data/`。
当前 Android 上传签名与旧 Release 1.0.254 不同，无法覆盖旧安装；请使用原发布签名重建覆盖升级，避免卸载丢失已有数据。

## 开发

```bash
flutter pub get
./scripts/generate_l10n.sh
dart run build_runner build --delete-conflicting-outputs
flutter test
dart analyze
./scripts/build_apk.sh
```

APK 脚本会自动增加版本号，生成 release APK 和 AAB；首次构建生成上传签名文件，后续必须保留同一份签名。

## 文档

- [开发规则](AGENTS.md)：UI 全部由 Antigravity 使用固定 OmniTune 会话实现。
- [开发与架构](docs/DEVELOPMENT.md)：模块、生成代码、测试与平台边界。
- [项目进度与路线图](docs/PROJECT_PROGRESS.md)：会话 ID、待办和验证结果。
- [Web 部署](docs/WEB_DEPLOYMENT.md)：本地服务、WebDAV 代理及 Cloudflare Workers。
- [版本记录](CHANGELOG.md)
