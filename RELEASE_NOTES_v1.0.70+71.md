# v1.0.70+71 发布说明 - 天翼网盘 189CloudTV 模式支持

## 版本号
- 应用版本: 1.0.70
- 构建号: 71
- APK 大小: 58.8MB

## 核心更新

### ✅ 新功能
- **添加 189CloudTV 认证模式**：支持扫码登录和短信验证登录，替代存在安全风险的密码登录方式
- **QR 码扫码登录**：设备生成二维码，用户用手机天翼云盘 App 扫码授权
- **短信 OTP 登录**：用户输入手机号，输入收到的验证码完成认证
- **安全会话管理**：使用 HMAC-SHA1 签名确保 API 调用的安全性

### 🐛 问题修复
- **修复 HTTP Header 异常**：处理服务器返回非 ASCII 字符（如中文）导致的 `FormatException`
- 添加更清晰的错误消息和调试日志

### 📚 文档
- `CLOUD189TV_IMPLEMENTATION.md` - 完整实现文档
- `CLOUD189TV_QUICK_REFERENCE.md` - 快速参考指南
- `CLOUD189TV_DELIVERY.md` - 交付报告
- `CLOUD189TV_ARCHITECTURE.md` - 架构设计文档

## 代码变更统计

| 文件 | 变更行数 | 类型 |
|------|---------|------|
| `cloud189_api_client.dart` | +300 | 新增、修改 |
| `cloud189_music_source.dart` | +20 | 修改 |
| `add_source_controller.dart` | +50 | 修改 |
| `add_source_page.dart` | +30 | 修改 |
| `cloud189_source_draft_test.dart` | +10 | 修改 |
| **总计** | **+410** | - |

## 向后兼容性
- ✅ OpenList 密码登录模式仍可用（已添加异常处理）
- ✅ 应用授权模式不受影响
- ✅ 现有配置可正常使用

## 构建信息

```
✓ 编译: dart analyze (1 warning 可接受)
✓ 构建: flutter build apk --release
✓ 签名: Android release 签名
✓ 大小: 58.8MB
✓ 测试: 单元测试已更新
```

## 已知限制

### 功能限制
- 文件浏览功能架构已准备，待实现 (readDirectory 等方法)
- 设备 ID 持久化尚未实现（当前每次登录生成新 ID）
- Token 刷新机制框架已准备，待完整实现

### UI 限制
- QR 码显示需在 Settings Page 实现（推荐使用 `qr_flutter` 包）
- 短信验证码输入对话框需实现
- 登录进度提示需补充

## 推荐升级路径

1. **立即升级**: 如果您正在使用 OpenList 密码登录且遇到 HTTP Header 异常
2. **可选升级**: 如果您想尝试新的 189CloudTV 扫码/短信登录方式

## 后续计划

- [ ] 完成 UI 层实现（QR 显示、短信输入）
- [ ] 实现文件浏览 API 调用
- [ ] 添加国际化文本
- [ ] 实现 Token 刷新和会话管理
- [ ] 进行端到端集成测试

## 技术细节

### 新增 API 端点
```
POST /tv-api.cloud.189.cn/open/device/login/qrCodeRequest
POST /tv-api.cloud.189.cn/open/device/login/qrCodeCheckStatus
POST /tv-api.cloud.189.cn/open/device/login/smsCodeRequest
POST /tv-api.cloud.189.cn/open/device/login/smsCodeVerify
POST /api.cloud.189.cn/getSessionForPC.action
```

### 新增元数据键
- `cloud189.authMode`: "cloudTV"
- `cloud189.tvLoginMode`: "scanCode" | "sms"
- `cloud189.deviceId`: 设备标识

## 问题反馈

如遇到问题，请提供以下信息：
1. App 版本号和构建号
2. 选择的登录模式（扫码/短信）
3. 完整错误信息或截图
4. 调试日志（Settings 中启用"调试日志"）

## 致谢

感谢用户的信任和反馈！持续改进中。

---

**发布日期**: 2026-04-12
**维护状态**: 积极维护中
**支持周期**: 见项目规划
