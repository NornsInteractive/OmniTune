# ⚡ Stage 5 快速参考卡

## 🎯 一页纸总结

### 任务清单
```
□ Task 5.1: 字体规范化 (25分)
  └─ 编辑 lib/app/app.dart
  └─ _buildTheme() 中所有 fontSize 乘以 scaleFactor

□ Task 5.2: 间距规范化 (35分)
  └─ 创建 lib/core/models/spacing_theme.dart
  └─ 替换所有硬编码 padding/margin

□ Task 5.3: 圆角验证 (18分)
  └─ grep -r "BorderRadius.circular" lib/
  └─ 确保都用动态值

□ Task 5.4: 方法扩展 (18分)
  └─ AppDisplayPreferences 添加 2 个方法

□ Task 5.5: 跨平台测试 (40分)
  └─ 7 个平台 × 3 个值 = 21 场景

□ Task 5.6: 性能验证 (25分)
  └─ 帧率、内存、编译时间

□ Task 5.7: 最终验收 (40分)
  └─ 用户场景、设计审查、可访问性
```

### 关键概念
```
interfaceCompactness:  0.5 ~ 1.5 (用户在设置中控制)
scaleFactor:           同 interfaceCompactness
baseUnit:              8px (基础间距)

应用到:
  • TextTheme 所有变体 (displayLarge → labelSmall)
  • Padding/Margin (xs ~ xxl)
  • 圆角半径 (已在 customThemeColors.borderRadius)
```

### 核心代码模式

**字体缩放:**
```dart
fontSize: 32 * scaleFactor  // 32sp * 0.5 ~ 1.5
```

**间距缩放:**
```dart
padding: EdgeInsets.all(spacing.md)  // spacing = SpacingTheme
```

**圆角统一:**
```dart
BorderRadius.circular(customThemeColors.borderRadius)
```

### 文件位置

| 用途 | 文件 | 行号 |
|------|------|------|
| 修改主题 | `lib/app/app.dart` | _buildTheme() |
| 创建间距 | `lib/core/models/spacing_theme.dart` | 新建 |
| 更新偏好 | `lib/core/models/app_preferences.dart` | 添加方法 |
| 测试情况 | 各 UI 文件 | 替换间距 |

### 验证命令

```bash
# 编译检查
flutter analyze

# 依赖检查
flutter pub get

# 运行测试
flutter test

# 性能分析
flutter run --profile

# 特定平台
flutter run -d android
flutter run -d ios
flutter run -d web
```

### 紧急救援

**编译出错?**
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

**忘记怎么做?**
```bash
cat STAGE_5_QUICK_START.md    # 快速指南
cat STAGE_5_WORKPLAN.md       # 详细计划
cat STAGE_4_SUMMARY.md        # 参考实现
```

**卡住了?**
1. 检查是否有 null safety 问题
2. 检查是否有硬编码值
3. 查看 Stage 4 的类似实现
4. 运行 flutter analyze 看错误

### 进度追踪

```
时间线:
Task 1️⃣  (25') --→ Task 2️⃣  (35') --→ Task 3️⃣  (18')
                           ↓
Task 4️⃣  (18') --→ Task 5️⃣  (40') --→ Task 6️⃣  (25')
                           ↓
                     Task 7️⃣  (40')
                           ↓
                        ✅ 完成!
```

### 成功标志

当你看到这些，说明完成了！

```
✅ flutter analyze: No issues found!
✅ 字体在 50% 明显较小，150% 明显较大
✅ 间距在 50% 很紧凑，150% 很宽松
✅ 所有 7 个平台都能启动
✅ 帧率稳定 ≥ 60fps
✅ 内存稳定 < 150MB
✅ 9 个 Task 全部完成
```

### 开始！

```bash
cd /workspace/music
cat STAGE_5_QUICK_START.md   # 5 分钟阅读
vim lib/app/app.dart        # 开始修改
```

---

**预计耗时:** 3.5 小时
**难度:** ⭐⭐⭐ (中等，跟 Stage 4 类似)
**关键:** 不要硬编码任何值！

**记住:** 每个 Task 完成后都要 `flutter analyze`！

---

*"编码快乐！"* 🚀
