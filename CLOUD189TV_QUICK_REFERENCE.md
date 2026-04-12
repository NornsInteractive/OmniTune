# 189CloudTV 模式快速参考

## 三种认证模式对比

| 特性 | OpenList密码 | 应用授权 | 189CloudTV |
|------|-------------|--------|-----------|
| 是否需要用户账户密码 | ✓ 是 | ✗ 否 | ✗ 否 |
| 是否需要手机App | ✗ 否 | ✓ 是 | ✓ 是 |
| 登录方式 | 直接密码 | OAuth授权码 | 扫码/短信 |
| 安全性 | ⚠️ 低 | ✓ 高 | ✓ 最高 |
| HTTP Header问题 | ✗ 有 | ✗ 无 | ✓ 无 |
| 支持设备TV | ⚠️ 有限 | ✗ 否 | ✓ 是 |
| 实现完整度 | ✓ 100% | ✓ 100% | ⚠️ 75% |

## 当前状态

✓ 已完成：
- [ ] HTTP Header 问题修复（try/catch 异常处理）
- [ ] Cloud189AuthMode 枚举添加 `cloudTV` 模式
- [ ] Cloud189TVLoginMode 枚举（scanCode/sms）
- [ ] DioCloud189TVRemoteClient 完整实现
- [ ] 登录流程（QR + SMS）
- [ ] 会话建立（Session 获取）
- [ ] 元数据存储和恢复
- [ ] 代码集成（MusicSource, AddSource Controller）
- [ ] 单元测试更新
- [ ] APK 构建验证 ✓ 成功

⚠️ 部分完成：
- [ ] UI 显示和交互（Settings Page 框架已准备，等待UI实现）

❌ 待实现：
- [ ] 文件浏览（readDirectory）
- [ ] 文件流读取（openRead）
- [ ] 文本文件读取（readText）
- [ ] Token 刷新机制
- [ ] 国际化文本
- [ ] QR 码渲染 UI
- [ ] 短信验证码输入 UI
- [ ] 设备 ID 持久化
- [ ] 端到端测试

## 核心类和类型

### 枚举
```dart
// 认证模式
Cloud189AuthMode.cloudTV

// TV登录方式
Cloud189TVLoginMode.scanCode
Cloud189TVLoginMode.sms
```

### 实现类
```dart
// TV客户端
DioCloud189TVRemoteClient(
  tvLoginMode: Cloud189TVLoginMode.scanCode,
  qrCodeResolver: (qrContent) { /* 显示二维码 */ },
  smsVerificationResolver: (phoneHint) { /* 获取验证码 */ },
)
```

### UI 回调
```dart
// 二维码显示和扫码等待
typedef Cloud189QRCodeResolver = 
  Future<void> Function(String qrContent);

// 短信验证码获取
typedef Cloud189SMSVerificationResolver = 
  Future<String?> Function(String phoneHint);
```

## API 端点

### 设备登录
```
POST /tv-api.cloud.189.cn/open/device/login/qrCodeRequest
POST /tv-api.cloud.189.cn/open/device/login/qrCodeCheckStatus
POST /tv-api.cloud.189.cn/open/device/login/smsCodeRequest
POST /tv-api.cloud.189.cn/open/device/login/smsCodeVerify
```

### 会话
```
POST /api.cloud.189.cn/getSessionForPC.action
```

### 文件操作（待实现）
```
POST /api.cloud.189.cn/listFiles.action
GET /api.cloud.189.cn/getFileDownloadUrl.action
```

## 元数据键

```dart
Cloud189Constants.authModeMetadataKey           // 'cloud189.authMode'
Cloud189Constants.tvLoginModeMetadataKey        // 'cloud189.tvLoginMode'
Cloud189Constants.debugLoggingMetadataKey       // 'cloud189.debugLogging'
// 新增
'cloud189.deviceId'                             // 设备标识
```

## 文件位置速查

| 功能 | 文件 | 行号 |
|------|------|------|
| HTTP Header 修复 | cloud189_api_client.dart | ~350-380 |
| 枚举定义 | cloud189_api_client.dart | ~80-105 |
| TV 客户端 | cloud189_api_client.dart | ~2015-2320 |
| 回调类型 | cloud189_api_client.dart | ~160-165 |
| MusicSource 集成 | cloud189_music_source.dart | ~19-32 |
| SourceDraft | add_source_controller.dart | ~70-130 |
| UI 字段 | add_source_page.dart | ~44-45 |
| UI 初始化 | add_source_page.dart | ~490-510 |
| 单元测试 | cloud189_source_draft_test.dart | ~8-50 |

## 快速测试步骤

1. **构建 APK**
   ```bash
   cd /workspace/music
   bash scripts/build_apk.sh
   ```

2. **运行静态分析**
   ```bash
   dart analyze
   ```

3. **运行单元测试**
   ```bash
   flutter test
   ```

4. **验证新模式是否被识别**
   ```dart
   // 在测试中
   expect(
     Cloud189AuthMode.cloudTV,
     isNotNull,
   );
   ```

## 调试技巧

### 查看 TV 登录日志
```dart
// 添加音源时启用调试
// Settings → Debug Mode → 启用

// 获取日志
String logs = Cloud189DebugLogBuffer.dump();
print(logs);
```

### 常见日志前缀
```
[Cloud189TV][qrcode]           // QR码登录相关
[Cloud189TV][sms]              // 短信登录相关
[Cloud189TV][error]            // 错误信息
[Cloud189TV]                   // 通用信息
```

## 推荐的 UI 实现库

| 功能 | 推荐库 | 版本 |
|------|--------|------|
| QR 码生成 | `qr_flutter` | ^4.x |
| 文本输入对话框 | Flutter 内置 `showDialog` | - |
| 加载指示器 | Flutter 内置 | - |
| 计时器显示 | Flutter 内置 `Stream` | - |

## 示例代码片段

### QR 码显示（伪代码）
```dart
final qrResolver = (String qrContent) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('扫码授权'),
      content: QrImage(data: qrContent),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('已扫码'),
        ),
      ],
    ),
  );
};
```

### 短信验证码输入（伪代码）
```dart
final smsResolver = (String phoneHint) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      return AlertDialog(
        title: Text('输入验证码'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '已发送至 $phoneHint',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('确认'),
          ),
        ],
      );
    },
  );
};
```

## 常见问题

### Q: 为什么需要 QR 码而不是直接输入验证码？
A: QR 码提供更高的安全性（无法被截获的账户密码），且用户体验更好（不需记住验证码）。

### Q: 短信验证码如何工作？
A: 用户输入手机号 → 服务器发送 OTP → 用户输入验证码 → 获得 Token。

### Q: 设备ID 是什么？
A: 用于标识特定设备，支持会话恢复。当前版本每次登录生成新 ID，后续可持久化。

### Q: 如何处理 QR 码超时？
A: 超时后会抛出 StateError，UI 应捕获并提示用户重新开始登录流程。

### Q: 能否在多个设备间共享 Token？
A: 不推荐。每个设备应有自己的 Token，以便独立管理和撤销权限。

## 下一步行动项

- [ ] 在 Settings Page 实现 Cloud189 模式选择 UI
- [ ] 集成 QR 码显示（使用 qr_flutter）
- [ ] 实现短信验证码输入对话框
- [ ] 实现文件浏览相关的 API 调用
- [ ] 添加国际化文本
- [ ] 端到端集成测试
- [ ] 提交变更和测试反馈
