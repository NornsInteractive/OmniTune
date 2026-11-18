# OmniTune 各平台应用商店上架与信息提报物料指南 (App Store Listing Kit)

> **Language / 语言切换**: [🇨🇳 简体中文 (Chinese)](#-中文版-chinese-listing-kit) | [🇬🇧 English](#-english-version-english-listing-kit)  
> **Official Website**: [https://norns.cc.cd](https://norns.cc.cd)  
> **Repository**: [https://github.com/NornsInteractive/OmniTune](https://github.com/NornsInteractive/OmniTune) · **Contact**: support@norns.cc.cd  

本文档系统整理了发布 **OmniTune** 至全球及国内主流应用市场所需的完整中英文元数据、宣传文案、分类标签、权限合规申明与审核指引。适用平台包括：
- **全球分发平台**：Google Play Console、Apple App Store、Microsoft Store、F-Droid、GitHub Releases
- **国内主流应用商店**：小米应用商店、华为应用市场、vivo 应用商店、OPPO 软件商店、腾讯应用宝、酷安

您可以直接复制对应板块内容至应用商店提交后台。

---

# 🇨🇳 中文版 (Chinese Listing Kit)

## 1. 基础元数据快速复制表

| 字段名称 | 填写内容 | 备注 / 平台限制 |
| :--- | :--- | :--- |
| **应用名称 (App Name)** | OmniTune | 30 字符内，全平台通用 |
| **应用副标题 (Subtitle)** | 跨平台多音源与云盘音乐播放器 | iOS 30 字符内 / 国内一句话 |
| **应用包名 (Package Name / ID)** | `com.norns.omnitune` | 全局唯一标识符（Android / macOS / iOS） |
| **开发者主体 (Developer)** | Norns Interactive | 组织开发者全称 |
| **主分类 (Primary Category)** | 音频与音乐 / 影音播放 (Music & Audio) | 视听影音类 |
| **次分类 (Secondary Category)** | 实用工具 / 效率 (Tools / Productivity) | 媒体管理与播放工具 |
| **应用定价与内购** | 免费 (Free)，无内购、无订阅、无商业广告 | 纯净开源 |
| **官方网站 (Website)** | https://norns.cc.cd | 官方主页 |
| **开源仓库 (Repository)** | https://github.com/NornsInteractive/OmniTune | 源码与发行页面 |
| **隐私政策链接 (Privacy URL)** | `https://github.com/NornsInteractive/OmniTune/blob/main/PRIVACY.md` | **商店必填项**（含中英文双语） |
| **技术支持链接 (Support URL)** | `https://github.com/NornsInteractive/OmniTune/issues` | 商店用户反馈通道 |
| **客服与开发者邮箱** | `support@norns.cc.cd` | 审核与用户沟通邮箱 |
| **版权归属 (Copyright)** | © 2026 Norns Interactive | 版权所有 |

---

## 2. 简短描述与宣传文案

### Google Play 简短说明 (Short Description - 80 字符上限)
> 跨平台多协议云音乐播放器，聚合 WebDAV、天翼云盘与本地存储，支持平滑歌词与桌面小组件。

### Apple App Store 宣传文本 (Promotional Text - 170 字符上限)
> OmniTune 是一款专注于私有云与本地音乐的跨平台高保真播放器。支持 WebDAV、天翼云盘、本地多目录及各种网络音源，具备精准时间轴滚动歌词、全尺寸全屏桌面小组件与极速无损解码。无广告、免登录、零追踪，还原纯粹音乐世界。

### 国内商店一句话简介 (15 - 30 字符限制)
- **推荐版本 A（突出功能全面）**：`多协议云音乐与本地高保真播放器`（17 字）
- **推荐版本 B（突出云盘与歌词）**：`支持 WebDAV 与云盘的滚动歌词音乐播放器`（24 字）
- **推荐版本 C（突出纯净开源）**：`轻量免登录的跨平台私有云音乐播放器`（18 字）

---

## 3. 完整应用描述 (Full Description - 适用于各大应用商店)

```markdown
OmniTune 是一款轻量、现代、优雅的跨平台多音源聚合音乐播放器。专为音乐发烧友与私有云用户量身打造，打通本地存储与个人云端，让您的数字音乐收藏在手机、平板、桌面电脑与智能电视（Android TV）间自由流淌。

【核心功能亮点】

1. ☁️ 全协议音源聚合，畅连私有音乐库
• 支持多种远程与云端协议：WebDAV、OpenList、天翼云盘（个人云 / 家庭云）、SFTP、FTP、Samba 等；
• 本地多目录聚合：支持选取本机或外接存储的多个指定文件夹，智能防嵌套拦截，自动深度递归检索子目录音频并加入曲库；
• 音源排除过滤：支持自定义排除子目录（过滤录音、系统音频与缓存文件），精细管理您的曲库。

2. 🎼 高保真全格式音频引擎
• 广泛格式解码：流畅解码 FLAC、WAV、APE、Apple Lossless (ALAC)、AAC、MP3、OGG、Opus 等无损与高码率格式；
• 智能内存缓存：支持高达 64 MiB 的原声音频高速流媒体内存预加载与离线缓存，弱网环境下秒起播放、无缝跨曲平滑切歌；
• 丰富播放模式：单曲循环、列表循环、随机播放、顺序播放与后台锁屏媒体中心无缝同步。

3. 📝 毫秒级时间轴滚动歌词
• 精准歌词同步：支持嵌入式歌词、外挂 LRC 歌词解析与平滑滚动高亮；
• 智能在线刮削：支持自动从开放音乐数据库刮削匹配歌曲封面与同步歌词，支持中英文双语歌词与长行自适应；
• 歌词交互微调：支持快速时间轴拖拽定位、单句播放微调，随心找到最感动的那一句。

4. 📱 全尺寸动态桌面小组件 (Android & iOS)
• 多规格自由选用：支持 2×2（三键完整切歌控制）、4×2（带时间戳与进度控制）、4×4（含常驻歌词卡片与待播队列预览）；
• 深度个性化定制：支持封面居左/居右、封面全屏铺满沉浸式填充、遮罩透明度自由调节（0%~100%）、可自定义背景色彩；
• 低功耗极速联动：采用原生轻量 RemoteViews / WidgetKit 架构，省电不耗内存，后台零延迟响应。

5. 🖥️ 深度全端跨平台与大屏 TV 交互
• 跨平台一致体验：Android、iOS、macOS、Windows、Linux 以及现代 Web 浏览器全端通用；
• Android TV 大屏原生支持：专为电视遥控器优化的 D-pad 导航与大字号沉浸布局，躺在沙发即可轻松点播全屋音乐。

6. 🔒 纯粹开源与极致隐私保护
• 零云端留存：纯客户端架构，不设中转服务器，音频直连私有云与本地存储，音乐数据永不离开您的控制；
• 硬件级凭证加密：音源密码通过系统底层硬件加密存储（Android KeyStore / iOS Keychain 等），绝不向云端回传；
• 免注册无干扰：免注册登录，不索取手机号，绝无第三方商业广告 SDK 与用户画像追踪代码。

【官方网站与开源支持】
• 官方主页：https://norns.cc.cd
• 源码仓库：https://github.com/NornsInteractive/OmniTune
• 建议与反馈：support@norns.cc.cd
```

---

## 4. 搜索关键词与分类标签 (Keywords & Tags)

### iOS App Store 关键词 (100 字符上限，英文逗号分隔)
```text
音乐播放器,WebDAV,天翼云盘,网盘音乐,本地音乐,FLAC,无损音乐,桌面小组件,歌词同步,LRC,音频播放器,云音乐,OmniTune
```

### Google Play 标签与分类
- **主类别**：音乐与音频 (Music & Audio)
- **应用标签 (Tags)**：
  - 音乐播放器 (Music Player)
  - 音频播放器 (Audio Player)
  - 离线音乐 (Offline Music)
  - 云存储 (Cloud Storage)
  - 歌词 (Lyrics)
  - 开源软件 (Open Source)

### 国内市场搜索标签与推荐词
- **标签**：音乐播放、本地音乐、网盘播放器、WebDAV、无损音乐、动态歌词、桌面微件、极简播放器、云盘同步
- **同类竞品参考词**：Foobar2000, Poweramp, 海贝音乐, 椒盐音乐, 汽水音乐, AIMP

---

## 5. 权限使用目的申明（商店审核必填材料）

在提报 Google Play、华为应用市场、小米应用商店等平台时，请严格将下述申明复制到“权限使用说明”中：

| 申请权限 | 平台 | 官方申请用途申明（可直接提交） |
| :--- | :--- | :--- |
| **读取音频/媒体文件**<br>`READ_MEDIA_AUDIO`<br>`READ_EXTERNAL_STORAGE` | Android | **业务目的**：用户选择添加本地存储目录作为音乐源时，应用需读取选定文件夹下的音频文件，以解析歌曲信息（ID3 标签、封面、时长）并加入本地播放列表。<br>**承诺**：不读取相册、视频或无关文件。 |
| **所有文件访问权限**<br>`MANAGE_EXTERNAL_STORAGE` | Android 11+ | **业务目的**：作为跨目录本地音乐管理器，允许用户自由指定外部 SD 卡、USB 挂载存储或任意自定义文件夹进行深层子目录音频递归扫描与排除管理。<br>**承诺**：仅在用户显式添加本地音乐源时访问。 |
| **网络访问权限**<br>`INTERNET`<br>`ACCESS_NETWORK_STATE` | 全平台 | **业务目的**：用于流式拉取并播放用户自行配置的私有 WebDAV/云端音乐源，在线刮削公开歌词与专辑封面，以及检查应用最新发布版本。<br>**承诺**：不传输用户个人私密数据。 |
| **前台媒体播放服务**<br>`FOREGROUND_SERVICE`<br>`FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Android | **业务目的**：核心业务功能需要。保证音乐在锁屏或应用退至后台时能够持续稳定播放，并在系统通知栏与锁屏界面常驻原生媒体播控控件。<br>**承诺**：停止播放后即刻释放。 |
| **通知发送权限**<br>`POST_NOTIFICATIONS` | Android 13+ | **业务目的**：用于在状态栏展示当前播放曲目、专辑封面及控制按钮（切歌、暂停、收藏），以及应用版本更新就绪提示。 |
| **屏幕唤醒锁**<br>`WAKE_LOCK` | Android | **业务目的**：防止系统在设备息屏时中断 CPU 导致音频解码暂停。 |

---

## 6. 年龄与内容分级问卷选项参考 (IARC / ESRB / PEGI)

在各商店后台填写“内容分级 / 问卷调查”时，请参考以下选项（OmniTune 评级为 **全年龄 (Everyone / PEGI 3)**）：
- **包含暴力内容吗？** 否 (No)
- **包含性或成人内容吗？** 否 (No)
- **包含粗俗用语或脏话吗？** 否 (No)
- **包含毒品、酒精或烟草参考吗？** 否 (No)
- **是否允许用户之间进行未经审查的公开社交互动/文字私聊？** 否 (No)
- **是否共享用户的精确物理位置？** 否 (No)
- **是否包含数字商品购买或充值？** 否 (No)
- **应用性质概述**：纯净的本地与私有云音频播放工具软件。

---

## 7. 审核员登录与测试指引 (App Reviewer Notes)

提审时在“审核员备注 / 演示账号”一栏填写：
```text
【测试指引】
1. 本应用为免账号体系设计，无需任何登录凭据，安装后即可直接进入完整应用功能。
2. 演示本地播放：应用内置基础提示，亦可点击“设置 -> 音源管理 -> 添加音源”，选择“本地存储”并授权测试音频文件夹即可快速扫描并播放。
3. 演示网络播放：支持标准公开 WebDAV 服务或天翼云盘，点击添加对应协议输入测试地址即可体验云端串流与实时滚动歌词。
4. 本应用不包含广告，不包含内购，无需额外硬件配件。如有任何疑问请联系：support@norns.cc.cd。
```

---

# 🇬🇧 English Version (English Listing Kit)

## 1. Core Metadata Reference Table

| Field Name | Value | Constraints / Notes |
| :--- | :--- | :--- |
| **App Name** | OmniTune | Under 30 characters |
| **Subtitle** | Multi-Source Cloud & Local Music Player | Under 30 characters (iOS / Store Subtitle) |
| **Package Name / App ID** | `com.norns.omnitune` | Unique application identifier |
| **Developer** | Norns Interactive | Organization Name |
| **Primary Category** | Music & Audio | Entertainment / Media Player |
| **Secondary Category** | Tools / Utilities | Media Library Manager |
| **Pricing** | Free (No In-App Purchases, No Subscriptions, No Ads) | Completely free |
| **Official Website** | https://norns.cc.cd | Official portal |
| **Source Code Repository** | https://github.com/NornsInteractive/OmniTune | GitHub project home |
| **Privacy Policy URL** | `https://github.com/NornsInteractive/OmniTune/blob/main/PRIVACY.md` | **Mandatory store field** |
| **Support URL** | `https://github.com/NornsInteractive/OmniTune/issues` | Issue Tracker |
| **Support Email** | `support@norns.cc.cd` | Developer Contact |
| **Copyright** | © 2026 Norns Interactive | All rights reserved |

---

## 2. Short Descriptions & Promotional Copy

### Google Play Short Description (80 Characters Maximum)
> Cross-platform cloud & local music player with WebDAV, lyrics, and widgets.

### Apple App Store Promotional Text (170 Characters Maximum)
> OmniTune is a powerful, privacy-first music player that connects to WebDAV, Cloud189, and local folders. Enjoy lossless audio playback, dynamic lyrics, and home widgets without ads or trackers.

### Store Tagline (Single sentence, 15 - 30 characters)
- **Option A (Comprehensive)**: `Multi-protocol cloud & lossless music player`
- **Option B (Feature-led)**: `Stream from WebDAV & local storage with live lyrics`
- **Option C (Privacy-focused)**: `Lightweight, account-free cloud music player`

---

## 3. Full Application Description

```markdown
OmniTune is a modern, lightweight, and elegant cross-platform music player designed for music lovers and personal cloud enthusiasts. Seamlessly bridging local device storage and remote personal cloud servers, OmniTune lets your digital music collection flow freely across mobile phones, tablets, desktop workstations, and smart Android TVs.

【Key Features】

1. ☁️ Multi-Protocol Cloud & Local Aggregation
• Remote Cloud Protocols: Connect directly to WebDAV, OpenList, Cloud189 (Personal / Family Cloud), SFTP, FTP, Samba, and more;
• Multi-Directory Local Storage: Select multiple local or external storage folders with recursive subdirectory scanning, automated path-nesting conflict guards, and custom folder exclusion rules.

2. 🎼 Hi-Fi Lossless Audio Engine
• Extensive Audio Format Support: Smooth decoding for FLAC, WAV, APE, Apple Lossless (ALAC), AAC, MP3, OGG, Opus, and M4A;
• Low-Latency Memory Buffer: Up to 64 MiB intelligent audio streaming cache for instant track playback and gapless transitions under unstable networks;
• Comprehensive Playback Modes: Loop track, loop queue, shuffle, linear playback, and native lockscreen media session integration.

3. 📝 Synchronized Scrolling Lyrics
• Millisecond Timeline Precision: Built-in support for embedded lyrics and external LRC files with dynamic real-time scrolling and current-line highlight;
• Smart Metadata & Artwork Scraping: Automatic online metadata lookup for missing album art and synchronized lyrics from open music databases;
• Timeline Seeking & Fine-Tuning: Click or drag on any lyric line to jump directly to your favorite musical moment.

4. 📱 Full-Featured Home Screen Widgets (Android & iOS)
• Multiple Layout Sizes: 2×2 (full 3-button playback controls), 4×2 (with progress tracking and timestamps), and 4×4 (including live lyrics capsule and queue preview);
• Deep Aesthetic Customization: Choose cover alignment (left/right), immersive full-bleed album art backgrounds, adjustable scrim darkness (0% to 100%), and custom palette colors;
• Native RemoteViews / WidgetKit: Battery-friendly, low-memory footprint, and instantaneous background responsiveness.

5. 🖥️ Seamless Cross-Platform & Android TV
• Unified Experience: Consistent UI and feature set across Android, iOS, macOS, Windows, Linux, and modern Web browsers;
• Android TV Native D-Pad Navigation: Tailored for TV remotes with focus flows and large typography for living room listening.

6. 🔒 Privacy by Design & Zero Ads
• No Central Cloud Storage: Client-only architecture. Your music streams directly from your personal servers and local storage without passing through any third-party relay;
• Hardware-Backed Security: Credentials and passwords are encrypted inside the operating system's secure vault (Android KeyStore, iOS Keychain);
• Account-Free & Tracker-Free: No registration required, no phone number binding, and zero third-party commercial ad or tracking SDKs.

【Support & Community】
• Website: https://norns.cc.cd
• Repository: https://github.com/NornsInteractive/OmniTune
• Contact: support@norns.cc.cd
```

---

## 4. Search Keywords & Store Tags (ASO)

### Apple App Store Keywords (100 Characters Limit, comma-separated)
```text
music player,webdav,flac,lossless audio,cloud music,lyrics,lrc,local music,audio player,widgets,omnitune
```

### Google Play Store Tags
- Music Player
- Audio Player
- Offline Music
- Cloud Storage
- Lossless Audio
- Lyrics

---

## 5. Permission Declarations for Store Reviewers

Copy and paste these exact statements when answering store permission questionnaires:

| Permission | Purpose & Declaration |
| :--- | :--- |
| **Audio & Media Storage**<br>`READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE` | **Purpose**: Required to scan user-selected local folders for audio files, extract ID3/FLAC metadata, and load tracks into the player library.<br>**Guarantee**: OmniTune never accesses unrelated user photos, videos, or documents. |
| **Manage External Storage**<br>`MANAGE_EXTERNAL_STORAGE` | **Purpose**: Required on Android 11+ to perform deep recursive scanning and custom directory exclusions across custom directories and external SD/USB media.<br>**Guarantee**: Accessed exclusively when the user configures local directory sources. |
| **Network Communication**<br>`INTERNET` / `ACCESS_NETWORK_STATE` | **Purpose**: Required to stream audio from user-configured personal WebDAV / cloud music servers, fetch open lyric metadata, and check for app updates.<br>**Guarantee**: Never transmits personal identifying information. |
| **Foreground Playback Service**<br>`FOREGROUND_SERVICE_MEDIA_PLAYBACK` | **Purpose**: Core functional requirement to keep audio streaming alive when the screen is locked or the application is in the background, displaying system media controls. |
| **Post Notifications**<br>`POST_NOTIFICATIONS` | **Purpose**: Displays the active media notification card (play/pause, skip, artwork, favorite) and informs users when an app update is available. |
| **Wake Lock**<br>`WAKE_LOCK` | **Purpose**: Prevents the CPU from going into deep sleep while playing audio with the screen off. |

---

## 6. App Reviewer Testing Notes (Google Play & Apple Review)

Provide the following text in the reviewer instructions box:

```text
【Reviewer Testing Instructions】
1. OmniTune is an account-free application. No login credentials or account registrations are required to access any feature.
2. Local Music Testing: Open Settings -> Music Sources -> Add Source -> Select "Local Storage" and pick any folder containing sample MP3/FLAC audio files to immediately index and play music.
3. Network Streaming Testing: Supports standard WebDAV or Cloud189 servers for remote streaming, synchronized lyrics, and artwork loading.
4. The application contains NO ads, NO in-app purchases, and requires NO external hardware.
If you have any questions during review, please contact: support@norns.cc.cd.
```

---

## 7. 版本更新说明模板 (What's New Template)

### 中文版 (Chinese - 适合 200~500 字符限制)
```text
【1.0.336 更新日志】
1. 修复桌面小组件封面遮罩透明度设置失效问题，暗度调节（0%~100%）在原生桌面及设置预览中实时生效。
2. 音乐源全新升级：新增“本地存储”音乐源，支持指定本机或外接存储多个目录统一聚合。
3. 严格目录防嵌套冲突：智能拦截父子层级重叠路径，避免重复扫描。
4. 递归子目录深度排查：自动递归检索本地各选定目录下的全部子文件夹曲目，并支持配置排除特定子目录。
5. 优化云盘音源连接性能与多语言界面展示。
```

### English Version (Suitable for Google Play 500 characters limit)
```text
【What's New in Version 1.0.336】
1. Fixed home screen widget cover scrim opacity control: darkness settings (0% to 100%) now update immediately on both widgets and settings preview.
2. Added Local Storage music source: aggregate multiple directories from internal and external storage into one unified library.
3. Path nesting conflict guards: automatically block nested directory structures to prevent duplicate track indexing.
4. Deep recursive directory scanning with customizable subdirectory exclusion rules.
5. Enhanced cloud streaming stability and localized UI improvements.
```
