---
name: flutter-music-player
description: >
  Flutter 跨平台音乐播放器开发技能，支持 Windows/Android/iOS/macOS/Linux/Web/Android TV
  多协议(SFTP/FTP/WebDAV/百度网盘/天翼云盘/Jellyfin)、无损音频、歌词同步、封面刮削、
  多语言、主题切换。使用此技能当用户需要：开发 Flutter 音乐播放器、集成音频协议、
  实现跌破同步歌词显示、配置跨平台 UI 适配、设置刮削元数据功能。
---

# Flutter 跨平台音乐播放器开发技能

## 项目概览

构建一个生产级跨平台音乐播放器，目标平台：**Windows · Android · iOS · macOS · Linux · Web · Android TV**

---

## 技术栈选型（优先使用现有库，不重造轮子）

### 核心框架
| 分类 | 包名 | 用途 |
|------|------|------|
| 状态管理 | `flutter_riverpod` | 全局状态、播放状态、设置 |
| 路由 | `go_router` | 跨平台导航 |
| 本地数据库 | `isar` | 音乐库、元数据缓存 |
| 网络 | `dio` | HTTP 请求、WebDAV |

### 音频播放
| 包名 | 用途 | 平台支持 |
|------|------|---------|
| `just_audio` | 核心播放引擎，支持 FLAC/WAV/ALAC/DSD/HiRes | All |
| `just_audio_background` | 后台播放 + 系统媒体控制 | Android/iOS/macOS |
| `audio_service` | 系统通知栏控制 | Android/iOS |
| `just_audio_media_kit` | Windows/Linux 底层支持 | Windows/Linux |

> ⚠️ DSD/Hi-Res (>192kHz) 在 Android 需要配合 `just_audio` + native audio track，iOS 通过 CoreAudio 原生支持。

### 协议支持
| 协议 | 包名 |
|------|------|
| SFTP | `dartssh2` + `ssh_client` |
| FTP | `ftpconnect` |
| WebDAV | `webdav_client` |
| 百度网盘 | 使用官方 REST API + `dio`（无官方 Flutter SDK，需手写） |
| 天翼云盘 | 使用官方 REST API + `dio` |
| Jellyfin | `jellyfin_api_client`（或 openapi 生成） |

### 歌词
| 包名 | 用途 |
|------|------|
| `lrc` | 解析 .lrc 文件 |
| `flutter_lyric` | 歌词滚动 UI 组件 |

### 元数据刮削
| 包名 | 用途 |
|------|------|
| `audio_metadata_reader` | 读取本地/远程音频 ID3/Vorbis/APE 标签 |
| `music_brainz` (HTTP API) | MusicBrainz 刮削封面/元数据 |
| `last_fm` (HTTP API) | Last.fm 刮削 |
| `dio` | 请求 Cover Art Archive、Discogs |

### UI/主题/国际化
| 包名 | 用途 |
|------|------|
| `flutter_adaptive_ui` | 自适应布局（手机/平板/桌面/TV） |
| `dynamic_color` | Material You 动态主色 |
| `flutter_localizations` + `intl` | i18n 多语言 |
| `cached_network_image` | 封面图缓存 |
| `palette_generator` | 从封面提取主题色 |
| `window_manager` | Windows/macOS 窗口控制 |

---

## 项目目录结构

```
music_player/
├── lib/
│   ├── core/
│   │   ├── audio/
│   │   │   ├── player_service.dart        # just_audio 封装
│   │   │   ├── audio_handler.dart         # audio_service handler
│   │   │   └── hires_detector.dart        # Hi-Res 音质检测
│   │   ├── providers/                     # Riverpod providers
│   │   ├── database/                      # Isar schemas
│   │   └── router/                        # go_router 配置
│   ├── features/
│   │   ├── library/                       # 音乐库
│   │   ├── player/                        # 播放器主界面
│   │   │   ├── widgets/
│   │   │   │   ├── lyric_view.dart        # 歌词组件
│   │   │   │   └── cover_art.dart         # 封面组件
│   │   ├── sources/                       # 协议源管理
│   │   │   ├── sftp_source.dart
│   │   │   ├── ftp_source.dart
│   │   │   ├── webdav_source.dart
│   │   │   ├── baidu_source.dart
│   │   │   ├── tianyiyun_source.dart
│   │   │   └── jellyfin_source.dart
│   │   ├── scraper/                       # 刮削模块
│   │   │   ├── musicbrainz_scraper.dart
│   │   │   └── lastfm_scraper.dart
│   │   └── settings/                      # 设置页
│   ├── l10n/                              # 多语言 ARB 文件
│   │   ├── app_zh.arb
│   │   ├── app_en.arb
│   │   └── app_ja.arb
│   └── main.dart
├── android/
├── ios/
├── macos/
├── windows/
├── linux/
└── web/
```

---

## 关键实现模式

### 1. 音频源抽象接口

```dart
abstract class MusicSource {
  String get name;
  Future<List<MusicFile>> listFiles(String path);
  Future<Uri> getStreamUri(MusicFile file);
  Future<void> connect();
  Future<void> disconnect();
}
```
所有协议（SFTP/FTP/WebDAV/百度/天翼/Jellyfin）实现此接口。

### 2. 播放器核心 (just_audio + audio_service)

```dart
// 使用 just_audio 的 AudioSource.uri() 统一处理所有协议流
final player = AudioPlayer();
await player.setAudioSource(
  AudioSource.uri(await source.getStreamUri(file)),
);
```

**Hi-Res 支持要点：**
- Android：`just_audio` 底层使用 ExoPlayer，支持到 24bit/192kHz PCM
- iOS：CoreAudio 原生支持 32bit float
- Windows/Linux：`just_audio_media_kit` 底层 libmpv，支持 DSD/DXD
- 检测码率：`audio_metadata_reader` 读取 `bitsPerSample` + `sampleRate`

### 3. 歌词同步

```dart
// 使用 lrc 包解析，配合 just_audio position stream
player.positionStream.listen((position) {
  final line = lrcFile.getLyricByTime(position);
  lyricController.scrollTo(line);
});
```

### 4. 封面刮削流程

```
1. 读取本地 ID3/Vorbis 内嵌封面 (audio_metadata_reader)
2. 若无 → 搜索 MusicBrainz (musicbrainz.org/ws/2)
3. 若无 → Last.fm API album.getInfo
4. 若无 → Cover Art Archive 直接请求
5. 缓存到 Isar + 磁盘 (cached_network_image)
```

### 5. 自适应 UI

```dart
// 使用 flutter_adaptive_ui 的 AdaptiveBuilder
AdaptiveBuilder(
  androidDelegate: MobileLayout(),
  windowsDelegate: DesktopLayout(),
  tvDelegate: TvLayout(),        // Android TV 方向键导航
  webDelegate: WebLayout(),
)
```

**各平台 UI 规范：**
- **手机(Android/iOS)**：底部迷你播放器 + 全屏播放页，Material 3 / Cupertino 自适应
- **桌面(Windows/macOS/Linux)**：三栏布局（侧边栏 + 列表 + 播放器），支持窗口拖拽
- **Android TV**：焦点导航，大字体，D-pad 友好
- **Web**：响应式，MediaSession API

---

## pubspec.yaml 核心依赖

```yaml
dependencies:
  # 状态管理
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  
  # 路由
  go_router: ^14.0.0
  
  # 数据库
  isar: ^3.1.0
  isar_flutter_libs: ^3.1.0
  
  # 音频
  just_audio: ^0.9.40
  just_audio_background: ^0.0.1-beta.12
  audio_service: ^0.18.15
  just_audio_media_kit: ^1.0.0  # Windows/Linux
  
  # 协议
  dartssh2: ^2.9.0
  ftpconnect: ^3.0.3
  webdav_client: ^1.2.1
  dio: ^5.4.3
  
  # 歌词
  lrc: ^1.0.2
  flutter_lyric: ^3.0.1
  
  # 元数据
  audio_metadata_reader: ^1.0.0
  
  # UI
  dynamic_color: ^1.7.0
  cached_network_image: ^3.3.1
  palette_generator: ^0.3.3
  window_manager: ^0.3.9
  
  # 国际化
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
```

---

## 多语言配置

在 `pubspec.yaml` 中添加：
```yaml
flutter:
  generate: true
```

`l10n.yaml`：
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

支持语言：`zh_CN`、`zh_TW`、`en`、`ja`、`ko`

---

## 主题系统

```dart
// 使用 dynamic_color + palette_generator 实现封面联动主题
class AppTheme {
  static ThemeData fromSeed(Color seed, Brightness brightness) =>
    ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: brightness),
      useMaterial3: true,
    );
}

// 播放时从封面提取主色
final palette = await PaletteGenerator.fromImageProvider(coverProvider);
ref.read(themeColorProvider.notifier).state = palette.dominantColor?.color;
```

---

## 刮削配置最佳实践

1. **优先级**：本地元数据 > Jellyfin 服务端 > MusicBrainz > Last.fm > Cover Art Archive
2. **批量刮削**：使用 `Isolate` 避免 UI 阻塞
3. **速率限制**：MusicBrainz 限制 1 req/s，需要 `rate_limiter` 或手动 delay
4. **去重**：使用 MusicBrainz Recording ID 作为唯一标识

---

## 平台特殊配置

### Android
- `android/app/src/main/AndroidManifest.xml`：添加 `FOREGROUND_SERVICE`、`READ_EXTERNAL_STORAGE`
- `android/app/build.gradle`：`minSdkVersion 21`，ExoPlayer 扩展（FLAC/Opus）

### Android TV
- `intent-filter` 添加 `LEANBACK_LAUNCHER`
- 使用 `FocusTraversalPolicy` 管理 D-pad 焦点

### iOS/macOS
- `Info.plist`：`NSAppleMusicUsageDescription`、`UIBackgroundModes: audio`
- Entitlements：`com.apple.security.network.client`

### Windows
- `windows/runner/main.cpp`：集成 `window_manager`
- `just_audio_media_kit` 需要 libmpv DLL 打包

### Linux
- 依赖：`libmpv-dev`、`libsecret-1-dev`（用于存储云盘 token）

---

## 参考资源

- [just_audio 官方文档](https://pub.dev/packages/just_audio)
- [audio_service 官方文档](https://pub.dev/packages/audio_service)
- [MusicBrainz API](https://musicbrainz.org/doc/MusicBrainz_API)
- [Last.fm API](https://www.last.fm/api)
- [Jellyfin OpenAPI](https://api.jellyfin.org)
- [Flutter 自适应布局](https://docs.flutter.dev/ui/adaptive-responsive)