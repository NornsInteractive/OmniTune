# Stage 5 快速开始指南

## 🎯 5 分钟概览

### 当前状态
```
✅ Stage 1-4 完成 (播放器、相册、库、主题系统)
⏳ Stage 5 开始 (全局样式调整)
📊 进度: 80% → 100%
```

### Stage 5 的核心目标

Stage 4 引入了 3 个自定义参数：
- `primaryColorSeed` — 主题颜色
- `borderRadius` — 边框圆角 (12-32px)
- `interfaceCompactness` — 界面紧凑度 (0.5-1.5)

Stage 5 要做的是：**让这些参数影响整个应用的字体、间距等全局样式**

---

## 🚀 立即开始

### 第 1 步：理解当前架构 (5 分钟)

打开 `lib/app/app.dart`，查看 `_buildTheme()` 方法：

```dart
ThemeData _buildTheme(
  ColorScheme colorScheme,
  Brightness brightness,
  double interfaceScaleFactor,
  CustomThemeColors customColors,  // ← 这个参数
) {
  final br = customColors.borderRadius;  // 已提取，可用
  // ... 应用到 borderRadius.circular(br)
}
```

**注意**: `customColors.interfaceCompactness` 还没有用到！

### 第 2 步：查看计划 (10 分钟)

阅读 `docs/STAGE_5_WORKPLAN.md` 的前 3 个 Task：

- **Task 5.1** — 字体大小规范化 (25 min)
- **Task 5.2** — 间距规范化 (35 min)
- **Task 5.3** — 边框圆角验证 (18 min)

### 第 3 步：选择起点 (立即)

根据时间和优先级：

**快速版本 (1.5 小时)** — 完成 5.1 + 5.2 + 5.3
```
✓ 字体动态缩放
✓ 间距动态调整
✓ 边框圆角统一
✗ 跨平台测试
✗ 性能验证
```

**完整版本 (3.5 小时)** — 完成全部 7 个 Task
```
✓ 所有样式调整
✓ 跨平台测试
✓ 性能验证
✓ 最终验收
```

---

## 🎯 Task 5.1: 字体大小规范化 (25 min)

### 目标
根据 `interfaceCompactness` 动态调整所有文本大小

### 步骤

#### 步骤 1: 打开 `_buildTheme()` 方法
文件: `lib/app/app.dart` 第 50-75 行

#### 步骤 2: 提取参数
```dart
ThemeData _buildTheme(..., CustomThemeColors customColors) {
  final br = customColors.borderRadius;
  final compactness = customColors.interfaceCompactness;  // ← 新增
  
  final baseTheme = ThemeData(...);
  final titleTheme = GoogleFonts.outfitTextTheme(baseTheme.textTheme);
  
  return baseTheme.copyWith(
    textTheme: titleTheme.copyWith(
      // ↓ 在这里应用 compactness 缩放
```

#### 步骤 3: 缩放文本大小
```dart
// 模板
bodyMedium: titleTheme.bodyMedium?.copyWith(
  fontSize: (titleTheme.bodyMedium?.fontSize ?? 14) * compactness,
),

// 应用到所有变体：
// - bodySmall, bodyMedium, bodyLarge
// - headlineSmall, headlineMedium, headlineLarge
// - titleSmall, titleMedium, titleLarge
// - labelSmall, labelMedium, labelLarge
```

#### 步骤 4: 验证编译
```bash
cd /workspace/music && flutter analyze
```

### 检查清单
- [ ] TextTheme 所有主要变体已更新
- [ ] 编译无错误
- [ ] 运行应用，调整紧凑度，观察字体变化

---

## 🎨 Task 5.2: 间距规范化 (35 min)

### 目标
创建间距系统，根据 `interfaceCompactness` 动态调整所有间距

### 步骤

#### 步骤 1: 创建 SpacingTheme 类
文件: `lib/core/models/spacing_theme.dart` (新建)

```dart
class SpacingTheme {
  final double compactness;
  
  const SpacingTheme({required this.compactness});
  
  // 基础间距
  double get xxSmall => 2 * compactness;
  double get xSmall => 4 * compactness;
  double get small => 8 * compactness;
  double get medium => 12 * compactness;
  double get large => 16 * compactness;
  double get xLarge => 24 * compactness;
  double get xxLarge => 32 * compactness;
  
  // 常用组合
  EdgeInsets get cardPadding => EdgeInsets.all(large);
}
```

#### 步骤 2: 在 app.dart 中使用
```dart
final spacing = SpacingTheme(compactness: compactness);

// 然后在 cardTheme 中：
cardTheme: CardThemeData(
  color: colorScheme.surfaceContainerLow,
  elevation: 0,
  margin: EdgeInsets.zero,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(br),
    side: BorderSide(color: colorScheme.outlineVariant),
  ),
  // ↑ 卡片本身的形状不变，内部内容由各组件自己处理
),
```

#### 步骤 3: 在关键组件中应用
主要修改的文件：
- `lib/features/player/presentation/widgets/now_playing_panel.dart`
- `lib/features/library/presentation/albums_page.dart`
- `lib/features/library/presentation/library_page.dart`
- `lib/features/settings/presentation/settings_page.dart`

**方法**: 用 SpacingTheme 替换硬编码的 `SizedBox(height: 16)`

```dart
// 之前
SizedBox(height: 16),

// 之后
SizedBox(height: spacing.large),
```

#### 步骤 4: 验证编译
```bash
flutter analyze
```

### 检查清单
- [ ] SpacingTheme 类创建完成
- [ ] 关键组件已集成 SpacingTheme
- [ ] 编译无错误
- [ ] 运行应用，调整紧凑度，观察间距变化

---

## 🔄 Task 5.3: 边框圆角一致性 (18 min)

### 目标
验证并统一所有 BorderRadius 的使用

### 步骤

#### 步骤 1: 查找所有 BorderRadius
```bash
cd /workspace/music && grep -r "BorderRadius.circular" lib/ --include="*.dart" | wc -l
```

#### 步骤 2: 应用统一规则

应该遵循的规则：

| 值 | 使用位置 | 新规则 |
|----|---------|--------|
| 28 | 卡片 | `br` ✓ (已做) |
| 22-24 | 对话框 | `br - 4` |
| 20 | 输入框/列表 | `br - 8` ✓ (已做) |
| 12-16 | 小组件 | 保持固定 |

#### 步骤 3: 查找并替换
检查这些文件是否有未统一的值：

```bash
grep -n "BorderRadius.circular(2[0-8])" lib/features/**/*.dart
grep -n "BorderRadius.circular(1[0-6])" lib/features/**/*.dart
```

#### 步骤 4: 必要时更新

如果发现有以下模式，需要提取 `br` 变量：

```dart
// 之前 (在对话框或小部件中)
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))

// 之后 (需要访问 customColors)
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(customColors.borderRadius - 4)
)
```

### 检查清单
- [ ] grep 搜索结果已审查
- [ ] 找到的所有硬编码值已评估
- [ ] 必要的更新已应用
- [ ] 编译无错误

---

## ✅ 可选任务 (如有时间)

### Task 5.4: 方法扩展 (18 min)
检查 `AppDisplayPreferences` 是否需要添加新方法支持 `SpacingTheme`

```bash
grep -n "static.*For" lib/core/models/app_preferences.dart
```

如果需要，添加：
```dart
static EdgeInsets cardPaddingFor(double compactness) => EdgeInsets.all(16 * compactness);
```

### Task 5.5+: 测试与验收
运行应用，依次调整：
1. 颜色选择器 — 观察配色变化
2. 边框圆角滑块 — 观察 UI 圆角变化
3. 紧凑度滑块 — 观察字体和间距变化

**在多个平台上测试**:
- Android (手机)
- iOS (如可用)
- Web (Chrome)
- Windows/Linux (如可用)

---

## 🔧 常用命令速记

```bash
# 分析编译错误
flutter analyze

# 格式化代码 (完成后运行)
dart format lib/

# 运行应用
flutter run

# 构建 APK
bash scripts/build_apk.sh

# 查找代码
grep -r "searchterm" lib/ --include="*.dart"
```

---

## 📊 预期工作量

| Task | 时间 | 难度 | 优先级 |
|------|------|------|--------|
| 5.1 字体规范化 | 25 min | 中 | 🔴 高 |
| 5.2 间距规范化 | 35 min | 高 | 🔴 高 |
| 5.3 圆角验证 | 18 min | 低 | 🟡 中 |
| 5.4 方法扩展 | 18 min | 低 | 🟢 低 |
| 5.5-7 测试 | 115 min | 中 | 🔴 高 |
| **总计** | **210 min** | — | — |

**快速路线 (1.5h)**: Task 5.1 + 5.2 + 5.3
**完整路线 (3.5h)**: 所有任务

---

## 💡 提示

### 减少错误的方法

1. **逐个编译验证** — 每个 task 完成后立即 `flutter analyze`
2. **保持一致性** — 所有间距值来自 SpacingTheme，不要硬编码
3. **测试极端值** — 调整滑块到最小 (50%) 和最大 (150%) 验证 UI 可用性
4. **跨平台检查** — 至少在手机和 Web 上测试

### 调试技巧

查看当前的 customThemeColors 值：
```dart
// 在任何 build() 方法中
print('Compactness: ${preferences.customThemeColors.interfaceCompactness}');
print('Border Radius: ${preferences.customThemeColors.borderRadius}');
```

---

## 📚 相关文档

- `docs/STAGE_5_WORKPLAN.md` — 详细的工作计划
- `docs/STAGE_4_COMPLETION_REPORT.md` — Stage 4 总结
- `lib/core/models/custom_theme_colors.dart` — 主题数据模型
- `lib/app/app.dart` — 主题应用逻辑

---

## 🎉 成功标准

Stage 5 完成时应该能够：

✅ 打开设置
✅ 调整"界面紧凑度"滑块 (50% - 150%)
✅ 观察整个应用的字体、间距、圆角动态变化
✅ 关闭应用，重新打开，设置已保存
✅ 所有平台上 UI 仍然可用和美观

---

## 🔄 失败恢复

如果出现编译错误：

1. **检查编译错误**
   ```bash
   flutter analyze
   ```

2. **常见错误**
   - `undefined variable compactness` → 检查是否在 _buildTheme 中提取了变量
   - `undefined class SpacingTheme` → 检查导入语句
   - `TextStyle has no property fontSize` → 使用 `copyWith()` 而非直接赋值

3. **快速修复**
   - 如果修改过多，恢复到上一个稳定版本：`git checkout -- lib/app/app.dart`
   - 从单个文件开始，验证每个更改

---

## 📞 快速问题排查

**Q: 字体变化不明显**
A: 确保已更新所有 TextTheme 变体，不只是 bodyMedium

**Q: 间距调整后 UI 错乱**
A: 检查是否有 hardcoded padding/margin 没有替换，使用 grep 查找：
```bash
grep -n "SizedBox(height: [0-9]" lib/features/**/*.dart
grep -n "padding: EdgeInsets" lib/features/**/*.dart
```

**Q: 编译后看不到变化**
A: 
1. 热重启而不是热重载：`R` 而不是 `r`
2. 关闭应用并重新运行：`flutter run`
3. 清理构建缓存：`flutter clean && flutter pub get`

---

## ✨ 最后的话

Stage 4 已经打下了坚实的基础（颜色、圆角）。

Stage 5 要做的就是"完成拼图"，让字体和间距也动态响应用户的偏好。

一旦完成，用户将能够：
- 🎨 选择任意颜色
- 📐 调整圆角从锐角到圆润
- 📏 调整紧凑度从拥挤到宽松
- 🔤 观看字体和间距随之变化

**预计 3-3.5 小时内完成所有工作。**

祝编码愉快！🚀

---

*快速指南版本: 1.0*
*最后更新: 2025年*
*项目: flutter_music_player*
