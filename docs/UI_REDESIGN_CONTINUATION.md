# UI 重设计继续工作清单 (v1.0.23+24)

## 当前进度
- **完成进度**：60% (3/5 阶段完成)
- **当前版本**：v1.0.23+24
- **分析结果**：零 lint 警告 ✅
- **代码质量**：优秀

---

## 第四阶段：自定义主题系统（后续工作）

### 4.1 在设置页面添加主题自定义部分

**文件**：`lib/features/settings/presentation/settings_page.dart`

**任务**：
- [ ] 在 SettingsPage 中添加新的 _SettingsSection 用于 "主题自定义"
- [ ] 添加颜色选择器 _SettingTile（主题颜色种子选择）
- [ ] 添加边框半径滑块（12.0 - 32.0）
- [ ] 添加界面紧凑度滑块（0.5 - 1.5）
- [ ] 实现实时预览功能

**代码框架**：
```dart
_SettingsSection(
  title: '主题自定义',
  children: [
    _SettingTile(
      icon: Icons.palette_rounded,
      title: '主题颜色',
      subtitle: '选择应用程序主题色...',
      onTap: () => _showColorPickerDialog(...),
    ),
    _SettingTile(
      icon: Icons.rounded_corner,
      title: '边框圆角',
      subtitle: '调整界面圆角大小...',
      onTap: () => _showBorderRadiusSlider(...),
    ),
    _SettingTile(
      icon: Icons.density_medium_rounded,
      title: '界面紧凑度',
      subtitle: '调整界面元素间距...',
      onTap: () => _showCompactnessSlider(...),
    ),
  ],
)
```

### 4.2 创建颜色选择器组件

**文件**：`lib/features/settings/presentation/widgets/color_picker_dialog.dart`（新建）

**任务**：
- [ ] 创建颜色选择器对话框
- [ ] 支持常用颜色预设
- [ ] 支持自定义 Hex 输入
- [ ] 实时颜色预览
- [ ] 保存和取消按钮

### 4.3 应用自定义主题

**文件**：`lib/app/app.dart`

**任务**：
- [ ] 从 LibraryPreferences 获取自定义颜色
- [ ] 在 MaterialApp 中应用自定义主题
- [ ] 使用 ColorScheme.fromSeed() 生成完整主题
- [ ] 应用边框半径到所有圆形样式
- [ ] 根据紧凑度调整间距

**代码框架**：
```dart
final theme = ref.watch(appSettingsControllerProvider).valueOrNull;
final seedColor = theme?.customThemeColors.getSeedColor();

return MaterialApp(
  theme: _buildLightTheme(seedColor, customTheme),
  darkTheme: _buildDarkTheme(seedColor, customTheme),
  // ...
);

ThemeData _buildLightTheme(Color? seedColor, LibraryPreferences prefs) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor ?? Colors.blue,
    brightness: Brightness.light,
  );
  
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    // 应用自定义边框半径
    // 应用自定义间距...
  );
}
```

### 4.4 创建 AppSettingsController 方法

**文件**：`lib/features/settings/application/app_settings_controller.dart`

**任务**：
- [ ] 添加 setCustomThemeColors() 方法
- [ ] 添加 setThemeBorderRadius() 方法
- [ ] 添加 setInterfaceCompactness() 方法
- [ ] 添加 resetThemeToDefault() 方法

---

## 第五阶段：全局样式调整

### 5.1 规范化字体大小

**任务**：
- [ ] 标题：全面使用 titleLarge 或 titleMedium
- [ ] 正文：统一使用 bodyMedium 或 bodySmall
- [ ] 标签：使用 labelLarge/labelMedium/labelSmall
- [ ] 标题：displaySmall 最多用于大标题

**受影响的文件**：
- albums_page.dart
- library_page.dart
- settings_page.dart
- 以及其他所有 UI 文件

### 5.2 规范化间距

**任务**：
- [ ] 确定间距基准值：8px 为基础单位
- [ ] 修改所有 SizedBox 高度：使用 8, 12, 16, 20, 24 的倍数
- [ ] 规范化 padding：使用 12, 16, 20, 24
- [ ] 规范化 margin：保持一致

**建议的间距体系**：
```dart
const double spacing8 = 8.0;   // 最小间距
const double spacing12 = 12.0;  // 小间距
const double spacing16 = 16.0;  // 标准间距
const double spacing20 = 20.0;  // 大间距
const double spacing24 = 24.0;  // 超大间距
```

### 5.3 规范化边框圆角

**任务**：
- [ ] 容器和卡片：24px 标准，紧凑模式 16px
- [ ] 按钮：16px 标准
- [ ] 小元素：12px（图标背景）
- [ ] 大容器：32px（仅在需要时）

**受影响的文件**：
- 所有使用 BorderRadius.circular() 的文件

### 5.4 跨平台测试

**任务**：
- [ ] 测试 Android 手机（320dp - 600dp）
- [ ] 测试 iPad（600dp - 1000dp+）
- [ ] 测试 Web（响应式）
- [ ] 测试 Desktop（Windows/macOS）
- [ ] 验证深浅主题
- [ ] 检查无障碍功能（字体缩放）

### 5.5 性能优化

**任务**：
- [ ] 检查帧率（目标 60fps）
- [ ] 监测内存使用
- [ ] 优化重建次数
- [ ] 检查动画流畅性

---

## 测试清单

### 功能测试
- [ ] 播放器界面：切换歌词/封面显示
- [ ] 相册网格：滚动和点击
- [ ] 库页面：导航和集合展示
- [ ] 设置页面：保存和应用设置
- [ ] 主题切换：实时生效

### 兼容性测试
- [ ] Android 6.0+
- [ ] iOS 12.0+
- [ ] macOS 10.15+
- [ ] Windows 10+
- [ ] Web (Chrome/Firefox/Safari)

### 性能测试
- [ ] 帧率监测（60fps 目标）
- [ ] 内存泄漏检查
- [ ] CPU 使用率
- [ ] 电池耗电监测

---

## 注释和内联修复

### 待审查的代码
- [ ] now_playing_panel.dart：_CompactLyricsPanel 的列表 maxLines
- [ ] albums_page.dart：Grid 间距优化
- [ ] library_page.dart：Compact 卡片尺寸验证

### 文档更新需要
- [ ] 用户指南：主题自定义说明
- [ ] 开发文档：主题系统架构
- [ ] 版本说明：UI 改进说明

---

## 发布准备

### v1.0.23 发布清单
- [ ] 完成所有 UI 改进
- [ ] 通过全部测试
- [ ] 更新版本号（1.0.23）
- [ ] 更新 build 号（+25, +26 等）
- [ ] 生成 APK 和其他平台包
- [ ] 创建发布说明
- [ ] 提交版本文档

### 预期结果
- ✅ 现代极简 UI 风格
- ✅ 高度可自定义主题
- ✅ 所有平台完全支持
- ✅ 零 lint 警告
- ✅ 完整的国际化支持
- ✅ 60fps 性能

---

## 时间估计

| 任务 | 估计时间 | 状态 |
|------|--------|------|
| 第四阶段（续） | 2-3 小时 | ⏳ 进行中 |
| 第五阶段 | 1-2 小时 | ⏳ 待开始 |
| 测试和修复 | 1 小时 | ⏳ 待开始 |
| 文档和发布 | 30 分钟 | ⏳ 待开始 |
| **总计** | **4.5-6.5 小时** | **⏳** |

---

## 关键约束

1. **不重造轮子**：继续使用现有 Material Design 3 组件
2. **无新依赖**：不添加新的外部包
3. **向后兼容**：保持现有功能不变
4. **国际化**：所有 UI 文本必须使用 l10n
5. **无硬编码**：颜色、大小等都应参数化
6. **零警告**：完全遵守 Dart 分析规则

---

## 联系和支持

**相关文档**：
- `UI_REDESIGN_PLAN_v1.0.23.md` - 原始计划
- `UI_REDESIGN_PROGRESS_v1.0.23.md` - 进度报告
- `.github/copilot-instructions.md` - 项目规则

**关键人员**：
- 设计：遵循 Material Design 3 原则
- 开发：遵循代码规范和最佳实践
- 测试：确保跨平台兼容性

---

*文档版本*：1.0
*最后更新*：UI 重设计会话
*下一步*：完成第四阶段的颜色选择器 UI
