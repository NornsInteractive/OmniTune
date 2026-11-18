# OmniTune Privacy Policy / 隐私政策

> **Language / 语言切换**: [🇨🇳 简体中文 (Chinese)](#-omnitune-隐私政策-中文版) | [🇬🇧 English](#-omnitune-privacy-policy-english-version)  
> **Official Website**: [https://norns.cc.cd](https://norns.cc.cd)  
> **Repository**: [https://github.com/NornsInteractive/OmniTune](https://github.com/NornsInteractive/OmniTune) · **Contact**: support@norns.cc.cd  

---

## 🇨🇳 OmniTune 隐私政策 (中文版)

**生效日期**：2026 年 11 月 18 日  
**最近更新日期**：2026 年 11 月 18 日  
**开发者/运营主体**：Norns Interactive  
**应用名称**：OmniTune（全功能跨平台音乐播放器）  
**应用包名**：`com.norns.omnitune`  

### 核心隐私原则
OmniTune 是一款轻量、现代的跨平台本地与私有云音乐播放客户端。我们严格遵循**“数据最小化”、“纯本地/私有存储”、“零云端留存”与“零用户画像”**原则。应用完全免账号运行，绝不收集任何个人隐私数据，绝不向任何第三方商业实体出让或交换您的音乐资产与使用信息。

---

### 一、我们如何处理您的数据

1. **音乐资产与私有音源**：
   - **本地目录音源**：当您授权访问本机或可移动存储（如 SD 卡、外接硬盘）的音乐目录时，应用仅在设备本地扫描音频标签信息（ID3、FLAC 元数据、嵌入封面等）并建立本地轻量索引。音频文件与目录绝不会上传至任何中转服务器。
   - **私有云及远程音源（WebDAV、SFTP、FTP、Samba、天翼云盘等）**：所有音频流媒体播放与目录拉取均为您的设备与您指定的远程服务器之间的直接连接。开发者不设中转代理，不监听、不收集亦不存储您的私有音源内容。
2. **账号凭证与密钥安全**：
   - 您配置的远程音源服务器地址、用户名、访问令牌或密码，均使用操作系统底层硬件级加密通道（Android KeyStore、iOS Keychain、macOS Keychain、Linux Secret Service、Windows Data Protection API）通过安全组件保存在本地沙盒中。
   - **我们绝不会将您的任何连接凭证回传至 Norns Interactive 或任何云端服务**。
3. **元数据与歌词刮削**：
   - 当您开启在线刮削补充封面与时间轴滚动歌词时，应用仅将当前音频的歌曲名、艺术家名作为公开查询关键字发送至公共元数据接口（如 MusicBrainz 等）。该过程不携带任何用户身份标识、设备硬件特征或用户私有文件路径。
4. **软件更新与安全校验**：
   - 应用启动或在“关于与更新”面板中检查新版本时，会向官方分发平台（`ygg.norns.cc.cd`）或 GitHub Releases 发送当前客户端平台类型与版本号，获取最新更新日志与安装包 SHA-256 校验和。该请求不收集任何个人可识别信息。
5. **我们坚决不进行的行为**：
   - ❌ 绝不集成任何商业广告投放 SDK
   - ❌ 绝不集成任何第三方统计分析、行为追踪或用户画像 SDK
   - ❌ 绝不收集 IMEI、MEID、MAC 地址、Android ID 或设备硬件序列号
   - ❌ 绝不索取定位（GPS）、相机、通讯录、短信等与音乐播放无关的敏感权限

---

### 二、应用权限申请与使用说明

| 权限名称 / 标识 | 适用平台 | 使用场景与业务目的 | 必要性 |
| :--- | :--- | :--- | :--- |
| **存储 / 音频读取权限**<br>`READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE` / `MANAGE_EXTERNAL_STORAGE` | Android | 读取用户主动选定的本地音乐文件夹、扫描音频与导入离线歌曲。 | 否（仅使用本地目录音源时依赖） |
| **网络通信权限**<br>`INTERNET` / `ACCESS_NETWORK_STATE` | 全平台 | 连接您自行配置的 WebDAV / 云端音乐源播放流媒体，以及在线刮削歌词和检查软件版本。 | 是（使用网络音源与检查更新必须） |
| **前台播放服务权限**<br>`FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Android | 在应用退至后台或锁屏时持续流畅播放音频，并在通知栏与锁屏界面维持系统级媒体播控条。 | 是（后台持续播放必须） |
| **通知发送权限**<br>`POST_NOTIFICATIONS` | Android 13+ | 显示常驻系统媒体通知卡片（含切歌、播放/暂停、喜欢等快捷操作）及版本更新就绪提示。 | 否（关闭不影响主界面播放） |
| **后台唤醒与锁屏播放**<br>`WAKE_LOCK` | Android | 防止设备锁屏休眠导致解码器与音频播放被操作系统意外中断。 | 是（熄屏播放必须） |

---

### 三、数据管理与用户控制权

1. **缓存清理**：您可随时在应用内“设置”中一键清除封面缩略图缓存、刮削歌词缓存与离线播放临时数据。
2. **完全擦除**：在设置中移除音源将立刻删除保存在安全密钥库中的对应连接凭证；卸载应用将彻底清空设备上残留的全部本地索引数据库与应用沙盒数据。
3. **政策变更**：本政策如遇重大更新，将在 GitHub 仓库提交发布说明，并在应用版本更新日志中明示。

---

## 🇬🇧 OmniTune Privacy Policy (English Version)

**Effective Date**: November 18, 2026  
**Last Updated**: November 18, 2026  
**Developer / Operating Entity**: Norns Interactive  
**Application Name**: OmniTune (Cross-Platform Music Player)  
**Package Name / Application ID**: `com.norns.omnitune`  

### Core Architecture & Privacy Principles
OmniTune is a lightweight, modern, client-side music player designed for local files and personal cloud storage. We are firmly committed to **"Data Minimization", "Local-First Storage", "Zero Cloud Retention", and "Zero Behavioral Profiling"**. OmniTune runs completely without user registration or user accounts. We never collect personal data, and we never sell, transmit, or exchange your music assets or activity with any third-party commercial entities.

---

### 1. How We Process and Handle Your Data

1. **Music Assets & Personal Storage Sources**:
   - **Local Storage Sources**: When granting access to local or removable storage directories (e.g. SD cards, external storage), OmniTune scans audio tags (ID3, FLAC metadata, embedded covers) solely on your local device to build a local index. Your audio files are NEVER uploaded to any intermediary servers.
   - **Personal Remote Sources (WebDAV, SFTP, FTP, Samba, Cloud189, etc.)**: All media streaming and directory listing take place directly between your device and your configured remote server. We operate no relay or proxy servers that intercept, monitor, or store your private music content.
2. **Account Credentials & Key Security**:
   - Credentials (server URLs, usernames, passwords, access tokens) for your remote music sources are stored locally in the operating system's hardware-backed secure storage (Android KeyStore, iOS Keychain, macOS Keychain, Linux Secret Service, Windows DPAPI) via encrypted storage mechanisms.
   - **We NEVER transmit your credentials to Norns Interactive or any remote cloud service.**
3. **Metadata & Lyric Scraping**:
   - When enabled, OmniTune queries public metadata databases (such as MusicBrainz) using only the song title and artist as search terms to retrieve synchronized lyrics and album art. These requests contain no personal identity, device hardware IDs, or private file paths.
4. **Software Updates & Integrity Checks**:
   - When checking for updates on startup or in the "About & Updates" panel, the app sends client platform type and version code to our release endpoint (`ygg.norns.cc.cd`) or GitHub Releases to fetch the latest changelog and SHA-256 package checksum. No personally identifiable information is transmitted.
5. **What We NEVER Do**:
   - ❌ Never integrate commercial advertising SDKs
   - ❌ Never integrate analytics, tracking, or profiling SDKs
   - ❌ Never collect device identifiers (IMEI, MEID, MAC address, Android ID, or serial numbers)
   - ❌ Never request unrelated permissions such as GPS Location, Camera, Contacts, or SMS

---

### 2. Device Permissions and Usage

| Permission | Platform | Context & Purpose | Required? |
| :--- | :--- | :--- | :--- |
| **Storage / Audio Access**<br>`READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE` / `MANAGE_EXTERNAL_STORAGE` | Android | Read user-selected local music folders, parse tags, and import tracks into the library. | No (Only needed for local storage sources) |
| **Network Access**<br>`INTERNET` / `ACCESS_NETWORK_STATE` | All Platforms | Connect directly to user-configured WebDAV / cloud music sources, fetch online lyrics, and check for software updates. | Yes (Required for remote sources & updates) |
| **Foreground Service**<br>`FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Android | Maintain continuous, uninterrupted audio playback when the app is in the background or screen is locked. | Yes (Required for background audio playback) |
| **Post Notifications**<br>`POST_NOTIFICATIONS` | Android 13+ | Display persistent media playback notification controls and show update notifications. | No (Optional; core playback unaffected) |
| **Wake Lock**<br>`WAKE_LOCK` | Android | Prevents the CPU from sleeping while audio is playing with the screen turned off. | Yes (Required for lockscreen playback) |

---

### 3. Data Control and Retention

1. **Cache Management**: You can clear cached album artwork, scraped lyrics, and temporary streaming buffers at any time in App Settings.
2. **Complete Erasure**: Removing a music source instantly erases its stored credentials from secure hardware storage. Uninstalling OmniTune completely removes all local indexed catalogs, preferences, and sandboxed data from your device.
3. **Policy Updates**: Any material updates to this policy will be documented in commit release notes on our official GitHub repository.

---

### 4. Contact Us

If you have questions, feedback, or concerns regarding this Privacy Policy or your data privacy, please contact:
- **Email**: `support@norns.cc.cd`
- **GitHub Issues**: [https://github.com/NornsInteractive/OmniTune/issues](https://github.com/NornsInteractive/OmniTune/issues)
- **Official Website**: [https://norns.cc.cd](https://norns.cc.cd)
