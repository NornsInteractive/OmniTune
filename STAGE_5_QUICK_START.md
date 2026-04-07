# 🚀 Stage 5 快速启动指南

## 📋 核心目标

使用 `interfaceCompactness` 参数完成**全局样式调整**，让用户可以控制：
- 📝 **字体大小** (基于紧凑度)
- 📏 **间距大小** (基于紧凑度)
- ✓ **圆角** (已在 Stage 4 完成)

## ⚡ 7 个 Task 概览

```
┌─────────────────────────────────────────┐
│ Task 5.1: 字体大小规范化 (25 min)      │ ← 字体
├─────────────────────────────────────────┤
│ Task 5.2: 间距规范化 (35 min)          │ ← 间距
├─────────────────────────────────────────┤
│ Task 5.3: 圆角验证 (18 min)            │ ← 验证
├─────────────────────────────────────────┤
│ Task 5.4: 方法扩展 (18 min)            │ ← AppDisplayPreferences
├─────────────────────────────────────────┤
│ Task 5.5: 跨平台测试 (40 min)          │ ← 7 个平台
├─────────────────────────────────────────┤
│ Task 5.6: 性能验证 (25 min)            │ ← 帧率、内存
├─────────────────────────────────────────┤
│ Task 5.7: 最终验收 (40 min)            │ ← 验收
└─────────────────────────────────────────┘
总计: 201 分钟 ≈ 3.5 小时
```

## 🎯 Task 5.1 — 字体大小规范化 (25 min)

### 目标
TextTheme 的所有变体根据 `interfaceCompactness` 动态缩放。

### 实现位置
`lib/app/app.dart` → `_buildTheme()` 方法

### 伪代码
```dart
ThemeData _buildTheme(ColorScheme colorScheme, double compactness) {
  // 伸缩系数: 0.5 倍 ~ 1.5 倍
  // compactness 范围: 0.5 ~ 1.5
  
  final scaleFactor = compactness;
  
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: TextTheme(
      // 标题文本 (通常 32sp)
      displayLarge: TextStyle(
        fontSize: 32 * scaleFactor,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        fontSize: 28 * scaleFactor,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        fontSize: 24 * scaleFactor,
        fontWeight: FontWeight.bold,
      ),
      
      // 标题 (通常 20-16sp)
      headlineLarge: TextStyle(fontSize: 20 * scaleFactor),
      headlineMedium: TextStyle(fontSize: 18 * scaleFactor),
      headlineSmall: TextStyle(fontSize: 16 * scaleFactor),
      
      // 正文 (通常 14sp)
      bodyLarge: TextStyle(fontSize: 14 * scaleFactor),
      bodyMedium: TextStyle(fontSize: 14 * scaleFactor),
      bodySmall: TextStyle(fontSize: 12 * scaleFactor),
      
      // 标签 (通常 12sp)
      labelLarge: TextStyle(fontSize: 12 * scaleFactor),
      labelMedium: TextStyle(fontSize: 11 * scaleFactor),
      labelSmall: TextStyle(fontSize: 10 * scaleFactor),
    ),
  );
}
```

### 验证清单
- [ ] 所有 TextTheme 变体都乘以 `scaleFactor`
- [ ] 最小字体不小于 8sp
- [ ] 最大字体不超过 48sp
- [ ] flutter analyze 零错误
- [ ] flutter pub get 通过

---

## 🎯 Task 5.2 — 间距规范化 (35 min)

### 目标
创建 `SpacingTheme`，统一所有 Padding/Margin 的间距。

### 数据类
在 `lib/core/models/` 创建 `spacing_theme.dart`:

```dart
class SpacingTheme {
  // 基础间距单位 (通常 8px)
  final double baseUnit;
  
  // 标准间距 (8, 16, 24, 32, 48 px)
  double get xs => baseUnit * 0.5 * scaleFactor;   // 4px
  double get sm => baseUnit * 1.0 * scaleFactor;   // 8px
  double get md => baseUnit * 2.0 * scaleFactor;   // 16px
  double get lg => baseUnit * 3.0 * scaleFactor;   // 24px
  double get xl => baseUnit * 4.0 * scaleFactor;   // 32px
  double get xxl => baseUnit * 6.0 * scaleFactor;  // 48px
  
  final double scaleFactor; // interfaceCompactness
  
  SpacingTheme({
    this.baseUnit = 8,
    required this.scaleFactor,
  });
}
```

### 应用策略
在所有 UI 文件中替换硬编码的间距：

```dart
// ❌ 旧代码 (硬编码)
Padding(
  padding: EdgeInsets.all(16),
  child: ...,
)

// ✅ 新代码 (动态)
Padding(
  padding: EdgeInsets.all(spacing.md),
  child: ...,
)
```

### 优先级文件 (修改顺序)
1. `lib/features/player/presentation/widgets/` (4 个文件)
2. `lib/features/library/presentation/` (3 个文件)
3. `lib/features/settings/presentation/` (2 个文件)
4. `lib/features/sources/presentation/` (1 个文件)

### 验证清单
- [ ] 创建 `spacing_theme.dart`
- [ ] 添加 9 个间距常量 (xs-xxl)
- [ ] 在优先级文件中应用 (最多 50 处替换)
- [ ] flutter analyze 零错误
- [ ] 在 50%, 100%, 150% 紧凑度下验证布局

---

## 🎯 Task 5.3 — 圆角验证 (18 min)

### 目标
审查所有 `BorderRadius.circular()` 使用，确保一致应用 `customThemeColors.borderRadius`。

### 查找策略
```bash
grep -r "BorderRadius.circular" lib/
```

### 替换策略

```dart
// ❌ 硬编码
BorderRadius.circular(12)

// ✅ 动态 (从 Theme 获取)
BorderRadius.circular(
  Theme.of(context).extension<AppExtension>()?.borderRadius ?? 20
)

// 或使用自定义主题
BorderRadius.circular(customThemeColors.borderRadius)
```

### 关键位置
- [ ] 卡片 (Card 组件)
- [ ] 按钮 (ElevatedButton, TextButton)
- [ ] 输入框 (TextField)
- [ ] 对话框 (AlertDialog)
- [ ] 自定义容器

---

## 🎯 Task 5.4 — 方法扩展 (18 min)

### 目标
在 `AppDisplayPreferences` 中添加辅助方法。

### 新增方法
```dart
class AppDisplayPreferences {
  // 既有方法...
  
  // 新增方法
  static TextTheme scaledTextTheme(
    BuildContext context,
    double interfaceCompactness,
  ) {
    final scaleFactor = interfaceCompactness;
    final baseTheme = Theme.of(context).textTheme;
    
    return baseTheme.copyWith(
      displayLarge: baseTheme.displayLarge?.copyWith(
        fontSize: (baseTheme.displayLarge?.fontSize ?? 32) * scaleFactor,
      ),
      // ... 其他变体
    );
  }
  
  static SpacingTheme createSpacingTheme(double interfaceCompactness) {
    return SpacingTheme(
      baseUnit: 8,
      scaleFactor: interfaceCompactness,
    );
  }
}
```

### 验证清单
- [ ] 添加 `scaledTextTheme()` 方法
- [ ] 添加 `createSpacingTheme()` 方法
- [ ] 方法可在整个应用中使用
- [ ] 文档注释完整

---

## 🎯 Task 5.5 — 跨平台测试 (40 min)

### 测试矩阵
```
┌──────────────────────────────────────┐
│ 平台        │ 紧凑度      │ 状态  │
├──────────────────────────────────────┤
│ Android     │ 50% / 100% / 150% │   │
│ iOS         │ 50% / 100% / 150% │   │
│ Web         │ 50% / 100% / 150% │   │
│ macOS       │ 50% / 100% / 150% │   │
│ Windows     │ 50% / 100% / 150% │   │
│ Linux       │ 50% / 100% / 150% │   │
│ Android TV  │ 100% (固定)      │   │
└──────────────────────────────────────┘
```

### 检查清单 (每个平台)
- [ ] 应用启动无崩溃
- [ ] 字体大小合理 (可读)
- [ ] 间距不重叠
- [ ] 按钮可点击
- [ ] 对话框显示完整
- [ ] 滚动流畅
- [ ] 无性能警告

### 快速测试命令
```bash
# Android
flutter run -d android --release

# iOS
flutter run -d ios --release

# Web
flutter run -d web --release

# 其他平台类似
```

---

## 🎯 Task 5.6 — 性能验证 (25 min)

### 检查项

**主线程负载**
```bash
flutter run --profile
# 查看 DevTools → Performance
# 确保帧率 > 60fps
```

**内存使用**
- 启动内存 < 100MB
- 运行中不持续增长
- 极端紧凑度 (0.5, 1.5) 不爆炸

**编译时间**
```bash
time flutter pub get
time dart run build_runner build --delete-conflicting-outputs
time flutter build apk --release
```

### 目标
- ✓ 帧率 ≥ 60fps (Android/iOS)
- ✓ 内存 < 150MB
- ✓ 编译 < 30s

---

## 🎯 Task 5.7 — 最终验收 (40 min)

### 用户场景验证

**场景 1: 极致紧凑** (50% interfaceCompactness)
```
✓ 字体小但仍可读
✓ 卡片紧凑排列
✓ 无重叠或溢出
✓ 按钮仍可点击
✓ 对话框完全显示
```

**场景 2: 标准** (100% interfaceCompactness)
```
✓ 字体正常大小
✓ 间距舒适
✓ 整体平衡
✓ 与原始设计一致
```

**场景 3: 宽松** (150% interfaceCompactness)
```
✓ 字体大，易读
✓ 间距宽敞
✓ 适合大屏或视力不佳
✓ 布局仍整齐
```

### 设计验收
- [ ] 产品经理/UI 审查通过
- [ ] 颜色正确应用
- [ ] 字体大小适宜
- [ ] 间距美观
- [ ] 响应式设计完整

### 可访问性检查
- [ ] 最小字体 ≥ 10sp
- [ ] 按钮高度 ≥ 48dp
- [ ] 触摸目标 ≥ 48×48dp
- [ ] 颜色对比度满足 WCAG AA

---

## ✅ 验收标准

### 功能完成
- [ ] Task 5.1-5.7 全部完成
- [ ] 零编译错误
- [ ] 零 Lint 警告
- [ ] 所有平台可启动

### 性能要求
- [ ] 帧率 ≥ 60fps
- [ ] 无内存泄漏
- [ ] 主线程不卡顿

### 文档完整
- [ ] STAGE_5_COMPLETION_REPORT.md
- [ ] 代码注释完整
- [ ] 用户指南更新

### 测试覆盖
- [ ] 7 个平台 × 3 个紧凑度 = 21 个场景
- [ ] 所有场景无问题

---

## 📚 快速参考

### 重要文件位置
```
lib/core/models/
  ├─ custom_theme_colors.dart (已有)
  ├─ app_preferences.dart (修改)
  └─ spacing_theme.dart (新建) ← Task 5.2

lib/app/
  └─ app.dart (修改 _buildTheme) ← Task 5.1

lib/features/
  ├─ player/
  ├─ library/
  ├─ settings/
  └─ sources/ ← Task 5.2 应用

.github/
  └─ copilot-instructions.md (参考)
```

### 关键概念
- **interfaceCompactness**: 0.5 ~ 1.5 (用户控制，在设置中)
- **scaleFactor**: 同 interfaceCompactness
- **baseUnit**: 基础间距 8px
- **TextTheme**: Material Design 文本样式

---

## 🎬 执行顺序

```
1️⃣ Task 5.1: 字体规范化 (25 min)
   ↓ (修改 _buildTheme())
   
2️⃣ Task 5.2: 间距规范化 (35 min)
   ↓ (创建 SpacingTheme, 替换 UI)
   
3️⃣ Task 5.3: 圆角验证 (18 min)
   ↓ (审查 BorderRadius 使用)
   
4️⃣ Task 5.4: 方法扩展 (18 min)
   ↓ (AppDisplayPreferences)
   
5️⃣ Task 5.5: 跨平台测试 (40 min)
   ↓ (7 个平台 × 3 个紧凑度)
   
6️⃣ Task 5.6: 性能验证 (25 min)
   ↓ (帧率、内存、编译)
   
7️⃣ Task 5.7: 最终验收 (40 min)
   ↓ (验收清单、可访问性)
   
✅ 完成!
```

---

## 💡 技巧

### 批量替换间距
使用正则表达式查找和替换：

```
查找: padding:\s*EdgeInsets\.all\((\d+)\)
替换: padding: EdgeInsets.all(spacing.${getSize($1)})
```

### 测试不同紧凑度
在 Flutter DevTools 中编辑状态：
1. 打开 Dart DevTools
2. 进入 Riverpod 标签页
3. 修改 `interfaceCompactness` 值
4. 实时看到 UI 变化

### 性能分析
```bash
flutter run --profile

# 在 DevTools Performance 标签
# 记录 10 秒
# 查看帧率图表
# 确保 > 60fps
```

---

## 🚨 常见陷阱

❌ **不要**
- 硬编码任何间距值 (16, 24 等)
- 忽略最小/最大字体限制
- 测试时跳过某些平台
- 忘记 null safety 检查

✅ **应该**
- 使用 `spacing.md` 等常量
- 在极限值 (0.5, 1.5) 下测试
- 覆盖所有 7 个平台
- 始终检查 null

---

## 📞 支持

### 如果卡住了
1. 检查 `STAGE_5_WORKPLAN.md` (详细计划)
2. 查看 `docs/` 中的相关文档
3. 运行 `flutter analyze` 查看错误
4. 参考 Stage 4 的实现模式

### 有疑问？
- Stage 4 中的 `ColorScheme.fromSeed()` 是类似概念
- `AppSettingsController` 中的 `setCustomThemeColors()` 是参考
- `SettingsPage` 中的对话框模式是参考

---

## 🎯 成功标志

当你看到以下情况，说明 Stage 5 完成了！

```
✅ flutter analyze: No issues found!
✅ All 7 platforms launch without crash
✅ Fonts scale properly (50%, 100%, 150%)
✅ Spacing adjusts smoothly
✅ Performance: 60+ fps maintained
✅ Memory: < 150MB
✅ All 9 tasks completed
✅ Documentation generated
```

---

**🚀 准备好开始了吗?**

下一步: 打开 `STAGE_5_WORKPLAN.md` 看详细计划!

或直接从 Task 5.1 开始 (修改 `lib/app/app.dart`)

---

*准备时间: 2026-04-05*
*预计用时: 3.5 小时*
*目标: 完成 UI 重设计的最后 20%*
