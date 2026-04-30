# 189CloudTV 登录流程架构图

## 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter 应用                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            Settings / Add Source Page (UI层)             │  │
│  │  • Cloud189 认证模式选择                                 │  │
│  │  • QR 码显示（待实现 UI）                                │  │
│  │  • 短信验证码输入（待实现 UI）                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          ↓                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         AddSourceController (业务逻辑层)                 │  │
│  │  • testCloud189Connection()                              │  │
│  │  • saveCloud189Source()                                  │  │
│  │  • Cloud189SourceDraft (配置数据模型)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          ↓                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │        Cloud189MusicSource (适配层)                      │  │
│  │  • 路由到不同的认证客户端                                │  │
│  │  • _defaultClientFactory()                               │  │
│  │    ├─ OpenList → DioOpenListCloud189RemoteClient         │  │
│  │    ├─ AppAuth → DioCloud189RemoteClient                  │  │
│  │    └─ CloudTV → DioCloud189TVRemoteClient ⭐             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          ↓                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │     DioCloud189TVRemoteClient (新增实现) ⭐              │  │
│  │  implements Cloud189RemoteClient                         │  │
│  │                                                          │  │
│  │  • connect() → 路由到 QR 或 SMS 登录                     │  │
│  │  • readDirectory() → 文件列表（待实现）                 │  │
│  │  • openRead() → 文件下载流（待实现）                     │  │
│  │  • readText() → 文本文件读取（待实现）                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                          ↓                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Dio HTTP 客户端                             │  │
│  │  • 与天翼云盘 API 通信                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                          ↓
        ┌─────────────────────────────────────┐
        │     天翼云盘 API                     │
        │                                     │
        │  https://tv-api.cloud.189.cn       │
        │  https://api.cloud.189.cn          │
        └─────────────────────────────────────┘
```

## QR 码登录流程

```
用户流程                     系统流程                    API流程
────────────────────────────────────────────────────────────────────

                          1. 调用 connect()
                             ↓
                          2. 调用 _loginWithQRCode()
                             ↓
                          3. _requestDeviceQRCode()
                             ├─→ POST qrCodeRequest
                                 ↓
                                 返回 {deviceId, qrContent, checkCode}
                             ↓
显示二维码 ←─────────────── 4. 显示二维码给用户
                             (通过 Cloud189QRCodeResolver 回调)
                             ↓
用手机扫码     ────────→ 5. 用户用手机天翼云盘App扫码
                             ↓
                          6. _pollQRCodeLogin() 开始轮询
                             ├─→ 每 2 秒 POST qrCodeCheckStatus
                                 ↓
确认授权       ────────→      服务器接收确认，返回登录成功
                                 ↓
等待完成       ←─────────── 7. 轮询返回 accessToken/refreshToken
                             ↓
                          8. _establishSession()
                             ├─→ POST getSessionForPC.action
                                 ↓
                                 返回 {sessionKey, sessionSecret}
                             ↓
登录完成 ←─────────────── 9. 建立会话，ready for API 调用
```

## 短信验证码登录流程

```
用户流程                     系统流程                    API流程
────────────────────────────────────────────────────────────────────

                          1. 调用 connect()
                             ↓
                          2. 调用 _loginWithSMS()
                             ↓
                          3. _requestSMSCode()
                             ├─→ POST smsCodeRequest
                                 ↓
OTP 已发送 ←─────────────── 返回 {checkCode, phoneHint}
                             ↓
输入验证码 ───────────────→ 4. 获取用户输入的验证码
                             (通过 Cloud189SMSVerificationResolver 回调)
                             ↓
                          5. _verifySMSCode()
                             ├─→ POST smsCodeVerify
                                 ├─ deviceId
                                 ├─ checkCode
                                 └─ verificationCode (用户输入)
                                 ↓
验证中     ←─────────────── 返回 {accessToken, refreshToken}
                             ↓
                          6. _establishSession()
                             ├─→ POST getSessionForPC.action
                                 ↓
                                 返回 {sessionKey, sessionSecret}
                             ↓
登录完成 ←─────────────── 7. 建立会话，ready for API 调用
```

## 类依赖关系

```
┌──────────────────────┐
│  AddSourceController │
│     (Riverpod)       │
└──────────────────────┘
          ↓
┌──────────────────────┐
│ Cloud189SourceDraft  │
│  (数据模型)          │
└──────────────────────┘
          ↓
┌──────────────────────┐
│ Cloud189MusicSource  │
│  (音源适配器)        │
└──────────────────────┘
          ↓ (根据 authMode)
    ┌─────┴─────┬─────────────┐
    ↓           ↓             ↓
┌────────┐ ┌────────┐ ┌──────────────┐
│ OpenList  │AppAuth │ CloudTV ⭐   │
│  Client   │Client  │  Client      │
└────────┘ └────────┘ └──────────────┘
                            ↓
                   (QR 或 SMS 模式)
                            ↓
                    ┌───────┴────────┐
                    ↓                ↓
              ┌──────────┐     ┌──────────┐
              │QR Login  │     │SMS Login │
              │Resolver  │     │Resolver  │
              └──────────┘     └──────────┘
                    ↓                ↓
              (UI 回调)        (UI 回调)
```

## 数据流转

### 存储格式
```
SourceProfile
├─ id: "cloud189_xxx"
├─ protocol: SourceProtocol.cloudDrive
├─ baseUrl: "https://tv-api.cloud.189.cn"
├─ username: "cloud189"
├─ password: "refreshToken 或空"
├─ rootPath: "/"
└─ metadata: {
    "cloud189.authMode": "cloudTV",
    "cloud189.tvLoginMode": "scanCode" | "sms",
    "cloud189.deviceId": "flutter_music_xxx-xxx",
    "cloud189.debugLogging": "true" | "false"
  }
```

### 状态转换
```
         ┌─────────────┐
         │   新建      │
         └──────┬──────┘
                │ 选择 Cloud189TV 认证
                ↓
      ┌─────────────────────┐
      │   等待验证输入      │
      │ (QR 显示/SMS 输入)  │
      └──────┬──────────────┘
             │ 用户授权/验证
             ↓
      ┌─────────────────────┐
      │   建立会话中        │
      │  getSessionForPC    │
      └──────┬──────────────┘
             │ 成功
             ↓
      ┌─────────────────────┐
      │   已就绪            │
      │ (可浏览文件/播放)   │
      └─────────────────────┘
```

## 错误处理流程

```
用户操作
  ↓
API 请求
  ↓
┌─ 成功? ─→ 返回结果
│
└─ 失败
  │
  ├─ 网络错误 → 重试机制 → 最多 N 次
  │  │
  │  └─ 仍失败 → 用户提示 "网络连接失败"
  │
  ├─ FormatException (HTTP Header) → StateError
  │  │
  │  └─ 用户提示 "服务器响应异常"
  │
  ├─ QR 码超时 → 用户提示 "二维码已过期，请重新扫码"
  │  │
  │  └─ 重新开始流程
  │
  ├─ 验证码错误 → 用户提示 "验证码错误，请重新输入"
  │  │
  │  └─ 重新开始 SMS 流程
  │
  └─ 其他 API 错误 → 解析错误信息 → 用户提示
```

## 关键调用序列

### 初始化
```
1. AddSourcePage._initializeProfile()
   → Cloud189SourceDraft.fromProfile()
   → 填充 UI 字段

2. User 选择 "Cloud189TV" 认证模式
   → 设置 _cloud189AuthMode = Cloud189AuthMode.cloudTV
   → 显示相关字段 (tvLoginMode, deviceId)
```

### 测试连接
```
1. User 点击 "测试连接"
   → AddSourceController.testCloud189Connection()
   → Cloud189SourceDraft.toProfile()
   → AddSourceController._testProfile()
   → Cloud189MusicSource(profile, 
                         qrCodeResolver: showQRCode,
                         smsVerificationResolver: getSMSCode)
   → _defaultClientFactory() 创建 DioCloud189TVRemoteClient
   → client.connect()
     ├─ 选择 QR 或 SMS 路径
     ├─ 显示 UI 等待用户输入
     └─ 建立会话
   → client.listFiles("/") 验证连接
```

### 保存配置
```
1. User 点击 "保存"
   → AddSourceController.saveCloud189Source()
   → 同上流程
   → 保存 SourceProfile 到存储
   → 更新活跃源 ID
   → 刷新音乐库
```

## 配置存储路径

```
flutter_secure_storage (安全)
└─ 凭证和 Token
  ├─ password: refreshToken
  ├─ username: 用户名
  └─ 其他敏感信息

SourceProfile (明文)
└─ metadata
  ├─ cloud189.authMode: "cloudTV"
  ├─ cloud189.tvLoginMode: "scanCode" | "sms"
  ├─ cloud189.deviceId: "..." (可加密)
  └─ cloud189.debugLogging: "true" | "false"
```

## 后续扩展点

```
DioCloud189TVRemoteClient
├─ readDirectory() → 需要实现
│  └─ 调用 /api.cloud.189.cn/listFiles.action
│     使用 sessionKey/sessionSecret 签名
│
├─ openRead() → 需要实现
│  └─ 调用 /api.cloud.189.cn/getFileDownloadUrl.action
│     获得 URL → 返回 HTTP Stream
│
└─ readText() → 需要实现
   └─ 调用 openRead() → 读取字节 → 转 UTF-8

刷新机制
├─ _refreshAccessToken() → 已有框架
│  └─ 使用 refreshToken 换新 accessToken
│
└─ _refreshSession() → 已有框架
   └─ 使用新 accessToken 重新建立会话
```

---

**架构设计原则**:
- ✅ 分离关注点：UI ↔ 业务逻辑 ↔ API 适配
- ✅ 可扩展性：支持添加新的认证模式
- ✅ 错误隔离：异常被正确捕获和转换
- ✅ 日志支持：完整的调试日志能力
- ✅ 向后兼容：不影响现有的 OpenList 和 AppAuth 模式
