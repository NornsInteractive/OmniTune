# UI Redesign Stage 5 — 全局样式调整 工作计划

## 📋 概览

**阶段**: Stage 5 (最后的全局样式调整)
**状态**: 准备中
**前置条件**: Stage 1-4 完成 ✅
**目标完成日期**: 本会话
**优先级**: 高

---

## 🎯 Stage 5 核心目标

使用 Stage 4 中引入的自定义参数（`interfaceCompactness`、`borderRadius`）来完整应用全局样式调整，实现完全的主题定制化体验。

---

## 📦 工作分解 (WBS)

### Task 5.1: 字体大小规范化
**时间估计**: 20-30 分钟
**难度**: 中等

#### 5.1.1 创建字体缩放提供者
**文件**: `lib/core/models/app_preferences.dart`

**现状**: `fontScaleFactor` 已存在（全局字体缩放）

**需求**: 
- 创建新的 `FontSizeTheme` 数据类
- 定义标准字体大小集合（body, headline 等）
- 根据 `interfaceCompactness` 应用动态调整

**实现方案**:
```dart
class FontSizeTheme {
  static const double baseBodySmall = 12;
  static const double baseBodyMedium = 14;
  static const double baseHeadlineSmall = 20;
  static const double baseHeadlineMedium = 28;
  
  static double bodySmall(double compactness) => baseBodySmall * compactness;
  static double bodyMedium(double compactness) => baseBodyMedium * compactness;
  // ... 其他大小
}
```

#### 5.1.2 修改 TextTheme 构建
**文件**: `lib/app/app.dart` - `_buildTheme()` 方法

**改进**:
- 使用 `customColors.interfaceCompactness` 缩放所有文本大小
- 更新 GoogleFonts 应用的大小
- 确保可读性不受影响

**受影响的 TextTheme 变体**:
- bodySmall, bodyMedium, bodyLarge
- headlineSmall, headlineMedium, headlineLarge
- titleSmall, titleMedium, titleLarge
- labelSmall, labelMedium, labelLarge

#### 5.1.3 UI 组件文本大小验证
**文件**: 需要检查的关键组件
- `lib/features/player/presentation/widgets/mini_player.dart`
- `lib/features/library/presentation/albums_page.dart`
- `lib/features/library/presentation/library_page.dart`
- `lib/features/settings/presentation/settings_page.dart`

**验证清单**:
- [ ] 所有歌曲标题易读
- [ ] 所有按钮文字清晰
- [ ] 列表项标题清晰可见
- [ ] 小标签文字不过小

---

### Task 5.2: 间距与填充规范化
**时间估计**: 30-40 分钟
**难度**: 高

#### 5.2.1 创建间距配置系统
**文件**: `lib/core/models/spacing_theme.dart`（新建）

**设计**:
```dart
class SpacingTheme {
  final double compactness;
  
  // 基础间距值
  double get xxSmall => 2 * compactness;
  double get xSmall => 4 * compactness;
  double get small => 8 * compactness;
  double get medium => 12 * compactness;
  double get large => 16 * compactness;
  double get xLarge => 24 * compactness;
  double get xxLarge => 32 * compactness;
  
  // 常见组合
  EdgeInsets get cardPadding => EdgeInsets.all(large);
  EdgeInsets get buttonPadding => EdgeInsets.symmetric(horizontal: medium, vertical: small);
}
```

#### 5.2.2 应用间距到关键组件
**受影响的文件**:

1. **lib/features/player/presentation/widgets/now_playing_panel.dart**
   - 更新歌曲信息间距
   - 调整播放按钮间距
   - 优化滑块周围间距

2. **lib/features/library/presentation/albums_page.dart**
   - GridView 间距（item spacing）
   - 相册卡片内部 padding
   - 页眉页脚间距

3. **lib/features/library/presentation/library_page.dart**
   - 列表项间距
   - Tab 栏间距
   - 控制按钮间距

4. **lib/features/settings/presentation/settings_page.dart**
   - 设置磁贴间距
   - 分组间距
   - 滑块周围间距

#### 5.2.3 标准化 Padding/Margin 常量
**文件**: 各组件文件

**原则**:
- 使用 `SpacingTheme` 而非硬编码数值
- 检查是否存在 `AppDisplayPreferences` 中的相关方法
- 复用现有的间距方法

---

### Task 5.3: 边框圆角一致性验证
**时间估计**: 15-20 分钟
**难度**: 低

#### 5.3.1 审查所有 BorderRadius 使用
**命令**:
```bash
cd /workspace/music && grep -r "BorderRadius.circular" lib/ --include="*.dart"
```

**检查清单**:
- [ ] 卡片边框圆角使用 `br`
- [ ] 按钮边框圆角使用 `br - 6`
- [ ] 输入框边框圆角使用 `br - 8`
- [ ] 对话框使用一致的圆角值
- [ ] 所有 20-28 范围的硬编码值已转换

#### 5.3.2 更新未统一的边框圆角
**受影响的文件**:
- `lib/features/player/presentation/widgets/*.dart`
- `lib/features/library/presentation/*.dart`
- `lib/core/widgets/*.dart`

**替换规则**:
| 原值 | 新规则 | 说明 |
|------|--------|------|
| 28 | `br` | 最大圆角（卡片） |
| 22-24 | `br - 4` | 中等圆角（对话框） |
| 20 | `br - 8` | 输入框圆角 |
| 12-16 | 固定值 | 小组件保持固定 |

---

### Task 5.4: AppDisplayPreferences 扩展
**时间估计**: 15-20 分钟
**难度**: 低

#### 5.4.1 验证现有方法
**文件**: `lib/core/models/app_preferences.dart`

**检查**:
- `toolbarHeightFor(scale)` ✓ 存在
- `navigationBarHeightFor(scale)` ✓ 存在
- `inputContentPaddingFor(scale)` ✓ 存在
- `buttonPaddingFor(scale)` ✓ 存在
- `segmentedButtonPaddingFor(scale)` ✓ 存在
- `visualDensityFor(scale)` ✓ 存在

#### 5.4.2 可能的新增方法
**考虑添加的方法**:
```dart
static double listItemHeightFor(double compactness) => 56 * compactness;
static EdgeInsets cardPaddingFor(double compactness) => EdgeInsets.all(12 * compactness);
static EdgeInsets tilePaddingFor(double compactness) => EdgeInsets.symmetric(...);
```

---

### Task 5.5: 跨平台样式测试
**时间估计**: 30-45 分钟
**难度**: 高

#### 5.5.1 桌面平台测试
**平台**: Windows, Linux, macOS

**测试清单**:
- [ ] 字体大小在大屏幕上清晰可读
- [ ] 间距比例合理
- [ ] 圆角不会显示异常
- [ ] 触摸目标足够大（鼠标操作）

#### 5.5.2 移动平台测试
**平台**: Android 手机, Android TV, iOS

**测试清单**:
- [ ] 小屏幕（3.5-4.5") 可用性
- [ ] 中屏幕（5-6.5") 外观
- [ ] 大屏幕（6.5"+) 空间利用
- [ ] 平板屏幕（10"+）响应式布局
- [ ] Android TV 10 英寸 D-pad 操作

#### 5.5.3 Web 平台测试
**浏览器**: Chrome, Firefox, Safari

**测试清单**:
- [ ] 响应式设计
- [ ] 触摸 / 鼠标混合操作
- [ ] 字体渲染质量
- [ ] 动画流畅性

---

### Task 5.6: 性能验证
**时间估计**: 20-30 分钟
**难度**: 中等

#### 5.6.1 主线程负载
**检查内容**:
- 主题应用是否导致卡顿
- 列表滚动帧率 (应为 60 fps)
- 对话框打开 / 关闭性能

**命令**:
```bash
flutter run --profile
# 使用 Flutter DevTools 检查性能
```

#### 5.6.2 内存使用
**检查内容**:
- 颜色选择器打开 / 关闭时内存是否释放
- 主题切换时内存尖峰
- 长时间运行时内存泄漏

---

### Task 5.7: 最终验收测试
**时间估计**: 30-45 分钟
**难度**: 中等

#### 5.7.1 功能验收
**用户场景 1**: 完整的主题定制流程
1. 打开设置
2. 更改主题颜色
3. 调整边框圆角
4. 调整界面紧凑度
5. 关闭应用
6. 重新打开应用 → 验证设置已保存

**用户场景 2**: 跨界面一致性
1. 更改颜色 → 验证所有界面更新
2. 更改圆角 → 验证所有卡片、按钮、输入框更新
3. 更改紧凑度 → 验证字体、间距调整

**用户场景 3**: 极端值测试
1. 最小圆角 (12px) → 界面仍可用
2. 最大圆角 (32px) → 界面仍可用
3. 最紧凑 (50%) → 文字可读，按钮可点击
4. 最宽松 (150%) → 不会超出屏幕边界

#### 5.7.2 设计验收
- [ ] 配色符合 Material Design 3 规范
- [ ] 圆角过渡自然
- [ ] 间距比例协调
- [ ] 字体层级清晰
- [ ] 触摸目标最小 48dp

#### 5.7.3 可访问性检查
- [ ] 文字对比度 ≥ 4.5:1
- [ ] 所有交互元素可聚焦
- [ ] 屏幕阅读器兼容性
- [ ] 键盘导航可用

---

## 📊 任务时间线

| Task | 时间估计 | 前置条件 | 优先级 |
|------|---------|---------|--------|
| 5.1 字体规范化 | 25 分钟 | Stage 4 完成 | 高 |
| 5.2 间距规范化 | 35 分钟 | 5.1 | 高 |
| 5.3 边框验证 | 18 分钟 | Stage 4 完成 | 中 |
| 5.4 扩展方法 | 18 分钟 | 并行 | 中 |
| 5.5 跨平台测试 | 40 分钟 | 5.1, 5.2, 5.3 | 高 |
| 5.6 性能验证 | 25 分钟 | 5.2 | 中 |
| 5.7 最终验收 | 40 分钟 | 全部 | 高 |

**总计**: ~200 分钟 (3-3.5 小时)

---

## 🔧 实现策略

### 方法 1: 增量更新
**优点**:
- 分块完成，风险低
- 每个 task 都可独立验证
- 逐步积累完整性

**缺点**:
- 需要多次编译验证

### 方法 2: 批量更新
**优点**:
- 速度快
- 一次编译
- 全面性好

**缺点**:
- 如有错误难以定位
- 需要详细的计划

**推荐**: **增量 + 定期编译验证** 的混合方法

---

## 📋 完成检查表

### Pre-Stage 5
- [ ] Stage 1-4 全部完成
- [ ] 零编译错误
- [ ] 零 Lint 警告
- [ ] 代码已格式化

### Task 5.1 - 5.4 完成
- [ ] 字体大小规范化完成
- [ ] 间距系统实现
- [ ] 边框圆角统一
- [ ] 辅助方法扩展

### Task 5.5 - 5.7 完成
- [ ] 7 个平台测试通过
- [ ] 性能验证完成
- [ ] 所有验收用例通过
- [ ] 文档已更新

### Post-Stage 5
- [ ] 最终编译 (flutter analyze)
- [ ] APK 构建成功
- [ ] 版本号更新 (v1.0.24 或更高)
- [ ] 发布准备完成

---

## 🚨 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 字体过小导致可读性差 | 中 | 高 | 提前在各屏幕尺寸测试 |
| 间距调整导致布局溢出 | 中 | 中 | 使用 Flexible/Expanded 包装 |
| 边框圆角值冲突 | 低 | 中 | 分类管理圆角规则 |
| 跨平台渲染差异 | 高 | 低 | 逐平台测试，必要时平台特定处理 |
| 性能下降 | 低 | 高 | 使用 profile 模式测试 |

---

## 📚 参考资源

- Material Design 3 文字规范: https://material.io/design/typography/
- Flutter TextTheme 文档
- Material 间距指南: https://material.io/design/layout/spacing-methods.html
- BorderRadius 最佳实践

---

## 🎉 Stage 5 完成标准

✅ **定义**: 满足以下全部条件时认为 Stage 5 完成

1. **代码质量**
   - flutter analyze 零错误
   - dart format 已应用
   - 无 TODO 注释

2. **功能完整性**
   - 所有 Task 5.1-5.7 完成
   - 用户场景 1-3 全部通过
   - 极端值测试通过

3. **跨平台支持**
   - 7 个目标平台测试通过
   - 响应式设计适配
   - 触摸/鼠标混合支持

4. **文档完善**
   - 此工作计划已标记为完成
   - 最终报告已生成
   - 发布说明已准备

5. **版本就绪**
   - v1.0.24+ 或更高
   - APK 构建成功
   - 无已知缺陷

---

## 📞 常见问题

**Q: 如果某个 task 超时怎么办?**
A: 优先完成关键 task (5.1, 5.2, 5.5), 其他可视为 "nice-to-have"

**Q: 是否需要编写单元测试?**
A: 对 FontSizeTheme, SpacingTheme 编写单元测试，UI 组件测试可延后

**Q: 如何处理向后兼容性?**
A: 所有更改都应基于现有的 customThemeColors 数据，无需数据迁移

**Q: Stage 5 完成后还有工作吗?**
A: 暂无。UI 设计完整后，下个阶段可考虑：
- 新功能 (搜索、播列表)
- 性能优化
- 额外协议支持 (SFTP 等)

---

*Plan Version: 1.0*
*Last Updated: 2025年*
*Status: READY FOR EXECUTION*
