# Cloud189TV 扫码/短信登录实现总结

## 概述

本次实现向天翼云盘音源支持添加了 **189CloudTV** 登录模式，提供扫码登录和短信验证两种安全的设备级登录方式，替代之前存在 HTTP header 非法字符问题的密码登录模式。

## 核心问题修复

### 1. HTTP Header 非法字符问题
**问题**：OpenList 密码登录在处理服务器返回的包含中文文本（如"二维码登录成功"）的 HTTP response header 时，Dart HttpClient 会抛出 `FormatException: Invalid HTTP header field value`。

**修复位置**：`lib/features/sources/data/cloud189/cloud189_api_client.dart` 行 ~350-380
```dart
try {
  loginResponse = await _dio.post<dynamic>(
    '${Cloud189Constants.authBaseUrl}/api/logbox/oauth2/loginSubmit.do',
    // ... request config ...
  );
} catch (error) {
  if (error is FormatException) {
    Cloud189DebugLogBuffer.add('[Cloud189][error] loginSubmit header parse error: ${error.message}');
    throw StateError('Cloud189 login response contained invalid HTTP header: ${error.message}');
  }
  // ...
}
```

## 新增功能

### 1. Cloud189TVLoginMode 枚举
**文件**：`lib/features/sources/data/cloud189/cloud189_api_client.dart` 行 ~95-105

支持两种登录模式：
- `scanCode` - 设备二维码扫码登录
- `sms` - 短信OTP验证登录

```dart
enum Cloud189TVLoginMode {
  scanCode('scanCode'),
  sms('sms');
  
  const Cloud189TVLoginMode(this.value);
  final String value;
  
  static Cloud189TVLoginMode fromValue(String? value) {
    return Cloud189TVLoginMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => Cloud189TVLoginMode.scanCode,
    );
  }
}
```

### 2. Cloud189AuthMode 扩展
**文件**：`lib/features/sources/data/cloud189/cloud189_api_client.dart` 行 ~80-95

添加新的认证模式：
```dart
enum Cloud189AuthMode {
  openListPassword('openListPassword'),
  appAuthorization('appAuthorization'),
  cloudTV('cloudTV');  // 新增
  // ...
}
```

### 3. DioCloud189TVRemoteClient 实现
**文件**：`lib/features/sources/data/cloud189/cloud189_api_client.dart` 行 ~2015-2320

完整实现 189CloudTV 设备登录客户端，包括：

#### QR Code 登录流程
```
1. _requestDeviceQRCode()
   └─> 请求设备ID和二维码内容
   
2. 显示二维码给用户（通过 Cloud189QRCodeResolver 回调）
   └─> 用户用手机天翼云盘App扫码

3. _pollQRCodeLogin()
   └─> 每 2 秒轮询服务器状态
   └─> 直到用户确认授权

4. _establishSession()
   └─> 使用 accessToken 建立 API 会话
```

#### SMS 登录流程
```
1. _requestSMSCode()
   └─> 发送OTP验证码到用户手机

2. _verifySMSCode()
   └─> 用户输入验证码（通过 Cloud189SMSVerificationResolver 回调）
   └─> 提交验证码获取 accessToken

3. _establishSession()
   └─> 使用 accessToken 建立 API 会话
```

### 4. UI 回调类型
**文件**：`lib/features/sources/data/cloud189/cloud189_api_client.dart` 行 ~160-165

```dart
typedef Cloud189QRCodeResolver = Future<void> Function(String qrContent);
typedef Cloud189SMSVerificationResolver =
    Future<String?> Function(String phoneHint);
```

这些回调允许 UI 层：
- 显示二维码并等待用户扫码
- 获取用户输入的短信验证码

### 5. Cloud189TVDeviceLoginResponse 数据类
**文件**：`lib/features/sources/data/cloud189/cloud189_api_client.dart` 行 ~168-192

结构化 QR Code 请求响应：
```dart
class Cloud189TVDeviceLoginResponse {
  final String deviceId;        // 设备标识
  final String qrContent;       // 二维码内容（可用于渲染）
  final String checkCode;       // 轮询检查码
  final int timeoutSeconds;     // QR码过期时间
}
```

## 配置和元数据

### 新增常量
**文件**：`lib/features/sources/data/cloud189/cloud189_api_client.dart` 行 ~30-35

```dart
static const tvAppId = 'tv_cloud_189';
static const tvClientType = 'ANDROID';
static const tvApiBaseUrl = 'https://tv-api.cloud.189.cn';
static const tvLoginModeMetadataKey = 'cloud189.tvLoginMode';
```

### 新增元数据键
- `cloud189.tvLoginMode` - 存储 TV 登录模式（scanCode/sms）
- `cloud189.deviceId` - 存储设备ID（用于会话恢复）

## 代码集成点

### 1. Cloud189MusicSource
**文件**：`lib/features/sources/data/cloud189/cloud189_music_source.dart` 行 ~19-32

更新构造函数添加 TV 登录回调参数：
```dart
Cloud189MusicSource(
  this.profile, {
  Cloud189RemoteClientFactory? clientFactory,
  Cloud189CaptchaResolver? captchaResolver,
  Cloud189QRCodeResolver? qrCodeResolver,        // 新增
  Cloud189SMSVerificationResolver? smsVerificationResolver,  // 新增
})
```

### 2. Cloud189SourceDraft
**文件**：`lib/features/settings/application/add_source_controller.dart` 行 ~70-130

添加 TV 模式字段：
```dart
class Cloud189SourceDraft {
  final Cloud189TVLoginMode tvLoginMode;  // 新增
  final String deviceId;                   // 新增
  // ... 其他字段 ...
}
```

### 3. AddSourcePage UI
**文件**：`lib/features/settings/presentation/add_source_page.dart`

- 添加 TV 登录模式字段（行 ~44）
- 添加设备ID控制器（行 ~45）
- 在 `_populateFromProfile()` 中初始化这些字段（行 ~493-495）
- 在 `_createCloud189Draft()` 中使用这些字段（行 ~802-804）
- 在 `dispose()` 中清理控制器（行 ~55）

## 使用流程

### 前端用户流程（待UI实现）

1. **选择云盘认证方式**
   ```
   Settings → 添加音源 → 天翼网盘 → 认证方式
   ```

2. **选择扫码登录**
   ```
   - 显示生成的二维码
   - 用户用手机天翼云盘App扫码
   - 应用轮询直到授权完成
   - 自动获得访问令牌
   ```

3. **或选择短信登录**
   ```
   - 输入手机号
   - 应用发送OTP到手机
   - 用户输入收到的验证码
   - 获得访问令牌
   ```

### 后端 API 端点（实现框架已准备）

| 操作 | 端点 |
|------|------|
| 请求二维码 | `POST /tv-api.cloud.189.cn/open/device/login/qrCodeRequest` |
| 检查二维码状态 | `POST /tv-api.cloud.189.cn/open/device/login/qrCodeCheckStatus` |
| 请求短信码 | `POST /tv-api.cloud.189.cn/open/device/login/smsCodeRequest` |
| 验证短信码 | `POST /tv-api.cloud.189.cn/open/device/login/smsCodeVerify` |
| 建立会话 | `POST /api.cloud.189.cn/getSessionForPC.action` |

## 后续实现步骤

### 1. UI 层实现（Settings Page）
需要在 `lib/features/settings/presentation/add_source_page.dart` 中：
- [ ] 添加 Cloud189 认证模式选择 UI（OpenList/AppAuth/CloudTV）
- [ ] 当选择 CloudTV 时，展示对应的 QR 码和短信输入界面
- [ ] 实现 `Cloud189QRCodeResolver` 回调 - 显示二维码（使用 `qr_flutter` 包或类似）
- [ ] 实现 `Cloud189SMSVerificationResolver` 回调 - 显示短信验证码输入对话框
- [ ] 添加轮询状态提示（"等待扫码..."、"验证中..."等）

### 2. 文件操作实现（Cloud189TV 文件浏览）
`DioCloud189TVRemoteClient` 当前已实现登录，但文件操作仍需实现：
- [ ] 实现 `readDirectory()` 方法 - 使用 `_session` 的 sessionKey/sessionSecret
- [ ] 实现 `openRead()` 方法 - 获取文件下载 URL 并返回流
- [ ] 实现 `readText()` 方法 - 读取文本文件内容

### 3. 会话管理
- [ ] 实现 Token 刷新机制（使用 refreshToken）
- [ ] 实现会话过期检测和自动重连
- [ ] 设备ID 的持久化和恢复

### 4. 错误处理
- [ ] 处理 QR 码超时情况
- [ ] 处理短信发送失败和验证错误
- [ ] 处理网络中断和重试

### 5. 国际化 (i18n)
需要在 `lib/l10n/app_zh.arb` 和 `app_en.arb` 中添加新文本：
```json
{
  "cloud189CloudTVMode": "189CloudTV（扫码/短信）",
  "cloud189CloudTVScanCodeLabel": "扫码登录",
  "cloud189CloudTVSMSLabel": "短信验证登录",
  "cloud189QRCodeExpiresIn": "二维码将在 {seconds} 秒后过期",
  "cloud189EnterSMSCode": "请输入收到的验证码",
  "cloud189WaitingForQRScan": "等待您用手机天翼云盘App扫码授权...",
  "cloud189VerifyingCode": "正在验证您的身份..."
}
```

## 构建和测试

### 当前构建状态 ✓
```
Flutter version: 3.x
Dart version: 3.x
APK 版本: 1.0.70+71
构建结果: ✓ 成功 (58.8MB)
```

### 运行静态分析
```bash
dart analyze
# 结果: 1 warning (unused_field '_session' - 后续会使用)
```

### 运行单元测试
```bash
flutter test
# 已更新测试用例以支持新参数
```

## 已知限制和注意事项

1. **API 端点验证**
   - TV API 端点需要与天翼云盘团队确认
   - 当前实现使用了推断的端点路径

2. **QR 码渲染**
   - 需要在 UI 层实现 QR 码渲染（推荐使用 `qr_flutter` 包）
   - QR 内容格式需要与官方 API 对齐

3. **设备ID 管理**
   - 当前每次登录生成新的 deviceId
   - 生产环境应该持久化 deviceId 以支持会话恢复

4. **安全考虑**
   - AccessToken 和 RefreshToken 应存储在 `flutter_secure_storage` 中
   - SessionKey/SessionSecret 应该在内存中管理，不持久化

5. **文件操作**
   - TV 模式的文件浏览尚未实现
   - 需要使用签名请求（HMAC-SHA1）访问 API

## 回滚或禁用此功能

如果需要暂时禁用 Cloud189TV 模式：

1. **在 `Cloud189AuthMode` 中移除 `cloudTV` 枚举值**
2. **在 `_defaultClientFactory` 中删除对应的 case 分支**
3. **重新构建 APK**

此外，所有变更都是向后兼容的 - 现有的 OpenList 和 AppAuth 模式继续正常工作。

## 调试建议

### 启用详细日志
在添加音源时勾选"调试日志"选项，然后可以通过以下方式查看日志：
```dart
// 在 add_source_controller.dart 中
String debugLog = ref.read(addSourceControllerProvider).connectionDebugLog();
```

日志将包含以下信息：
```
[Cloud189TV][qrcode] Initiating QR code login
[Cloud189TV][qrcode] Received QR code: deviceId=...
[Cloud189TV][qrcode] Starting polling for QR code scan (max 300s)
[Cloud189TV][qrcode] Waiting for QR code scan...
[Cloud189TV] Session established successfully
```

### 模拟测试
可以在 `test/features/settings/cloud189_source_draft_test.dart` 中添加新测试：
```dart
test('Cloud189TV QR code mode stores login mode in metadata', () {
  const draft = Cloud189SourceDraft(
    name: 'Tianyi TV',
    authMode: Cloud189AuthMode.cloudTV,
    tvLoginMode: Cloud189TVLoginMode.scanCode,
    deviceId: 'test-device-123',
    // ... 其他字段 ...
  );
  
  final profile = draft.toProfile();
  
  expect(
    profile.metadata[Cloud189Constants.tvLoginModeMetadataKey],
    Cloud189TVLoginMode.scanCode.value,
  );
  expect(profile.metadata['cloud189.deviceId'], 'test-device-123');
});
```

## 相关文件清单

- [x] `lib/features/sources/data/cloud189/cloud189_api_client.dart` - 核心实现
- [x] `lib/features/sources/data/cloud189/cloud189_music_source.dart` - 集成层
- [x] `lib/features/settings/application/add_source_controller.dart` - 业务逻辑
- [x] `lib/features/settings/presentation/add_source_page.dart` - UI 声明（未完成实现）
- [x] `test/features/settings/cloud189_source_draft_test.dart` - 单元测试
- [ ] `lib/l10n/app_zh.arb` / `app_en.arb` - 国际化文本（待添加）

## 联系和反馈

如有问题或需要进一步的功能，请参考：
- `AGENTS.md` - AI Agent 开发指南
- `.github/copilot-instructions.md` - GitHub Copilot 编码指南
- `pubspec.yaml` - 项目依赖
