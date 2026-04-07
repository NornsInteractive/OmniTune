# Stage 4 实现详解 — 代码深度解析

## 📚 目录

1. [核心概念](#核心概念)
2. [文件结构](#文件结构)
3. [数据流](#数据流)
4. [关键实现](#关键实现)
5. [集成测试](#集成测试)
6. [常见问题](#常见问题)

---

## 🎯 核心概念

### 三维自定义系统

```
┌─────────────────────────────────────┐
│   CustomThemeColors (Stage 4)       │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────────────────────────┐  │
│  │ 1. primaryColorSeed          │  │
│  │    类型: String? (#RRGGBB)   │  │
│  │    范围: 任意 16 进制颜色     │  │
│  │    用途: 生成全局配色方案     │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ 2. borderRadius              │  │
│  │    类型: double              │  │
│  │    范围: 12.0 - 32.0px       │  │
│  │    用途: 卡片、按钮的圆角    │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │ 3. interfaceCompactness      │  │
│  │    类型: double              │  │
│  │    范围: 0.5 - 1.5           │  │
│  │    用途: 字体、间距、密度    │  │
│  └──────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

### 响应链

```
User Interaction (SettingsPage)
         ↓
AppSettingsController.setCustomThemeColors()
         ↓
libraryPreferencesRepository.save()
         ↓
SecureStorage (flutter_secure_storage)
         ↓
Riverpod State Update
         ↓
MusicApp.build() 重新调用
         ↓
Theme Rebuilt
         ↓
UI Refresh (all dependent widgets)
```

---

## 📁 文件结构

### 核心文件清单

```
lib/
├── core/
│   ├── models/
│   │   ├── app_preferences.dart (修改)
│   │   └── custom_theme_colors.dart (新建)
│   │
│   └── storage/
│       └── library_preferences_repository.dart (修改)
│
├── app/
│   └── app.dart (修改)
│
└── features/
    └── settings/
        ├── application/
        │   └── app_settings_controller.dart (修改)
        │
        └── presentation/
            └── settings_page.dart (修改)
```

### 文件修改统计

| 文件 | 类型 | 行数变化 | 改动内容 |
|------|------|---------|---------|
| custom_theme_colors.dart | 新建 | +150 | 完整数据模型 |
| app_preferences.dart | 修改 | +5 | 添加 customThemeColors 字段 |
| library_preferences_repository.dart | 修改 | +30 | 序列化/反序列化 |
| app_settings_controller.dart | 修改 | +6 | setCustomThemeColors() 方法 |
| settings_page.dart | 修改 | +150 | UI 磁贴和对话框 |
| app.dart | 修改 | +40 | ColorScheme.fromSeed() 和边框圆角 |
| **总计** | — | **+381** | — |

---

## 🔄 数据流

### 完整的状态流动

```
┌─────────────────────────────────┐
│ SettingsPage                    │
│ onTap: () => _showColorPicker() │
└─────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────┐
│ _showColorPickerDialog()                    │
│ - AlertDialog 包含 StatefulBuilder          │
│ - 用户选择颜色后返回 selectedColor         │
│ - onSelected(colorHex) 回调                 │
└─────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────────┐
│ onSelected 回调执行：                                │
│ final updated = preferences.customThemeColors       │
│                   .copyWith(primaryColorSeed: ...) │
│ ref.read(appSettingsControllerProvider.notifier)   │
│    .setCustomThemeColors(updated)                  │
└──────────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────┐
│ AppSettingsController.setCustomThemeColors() │
│ _save((preferences) =>                       │
│   preferences.copyWith(                      │
│     customThemeColors: value                 │
│   )                                          │
│ )                                            │
└──────────────────────────────────────────────┘
           ↓
┌───────────────────────────────────────────────────────┐
│ AppSettingsController._save()                        │
│ 1. state = AsyncData(updatedPreferences)            │
│    (立即更新 Riverpod 状态)                         │
│ 2. await repository.save(updatedPreferences)        │
│    (异步保存到 SecureStorage)                       │
└───────────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────┐
│ libraryPreferencesRepository.save()          │
│ 1. 转换 preferences 为 JSON                  │
│ 2. 包含 customThemeColors.toJson()          │
│ 3. 保存到 SecureStorage                     │
└──────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────┐
│ Riverpod 触发依赖 watch                         │
│ MusicApp.build() 因 appSettingsControllerProvider │
│ 的变化而重新调用                               │
└──────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────┐
│ MusicApp.build() 执行：                         │
│ final preferences = ref.watch(...)              │
│ final customColors = preferences.customTheme.. │
│ final seedColor = customColors.getSeedColor()  │
│ final lightScheme =                            │
│   ColorScheme.fromSeed(seedColor: seedColor)  │
│ theme: _buildTheme(lightScheme, ..., colors) │
│ darkTheme: _buildTheme(darkScheme, ..., cols) │
└─────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────────┐
│ _buildTheme() 执行：                                │
│ final br = customColors.borderRadius                │
│ return baseTheme.copyWith(                          │
│   colorScheme: colorScheme,  // ColorScheme         │
│   cardTheme: CardThemeData(                         │
│     shape: RoundedRectangleBorder(                  │
│       borderRadius: BorderRadius.circular(br)  ✓  │
│     )                                          │
│   )                                                 │
│   ... 其他主题属性 ...                            │
│ )                                                   │
└──────────────────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────────────┐
│ MaterialApp.router 重建                         │
│ - theme 和 darkTheme 更新                      │
│ - 所有依赖 colorScheme 的组件重建             │
│ - 所有依赖 borderRadius 的组件重建            │
└──────────────────────────────────────────────────┘
           ↓
┌────────────────────────────────────────┐
│ 用户看到整个应用的主题立即更新！     │
│ - 颜色变化                             │
│ - 圆角变化                             │
│ - 关闭对话框                           │
└────────────────────────────────────────┘
           ↓
┌────────────────────────────────────────┐
│ 用户关闭应用并稍后重新打开            │
│ librar yPreferencesRepository.load()  │
│ → 从 SecureStorage 恢复 customTheme.. │
│ → 主题自动应用                         │
└────────────────────────────────────────┘
```

---

## 🔧 关键实现

### 1. CustomThemeColors 数据模型

**文件**: `lib/core/models/custom_theme_colors.dart`

```dart
@freezed
class CustomThemeColors with _$CustomThemeColors {
  const factory CustomThemeColors({
    // 十六进制颜色值，如 #FF5722
    String? primaryColorSeed,
    
    // 边框圆角，范围 12-32px
    @Default(20.0) double borderRadius,
    
    // 界面紧凑度，范围 0.5-1.5
    @Default(1.0) double interfaceCompactness,
  }) = _CustomThemeColors;

  factory CustomThemeColors.fromJson(Map<String, dynamic> json) =>
      _$CustomThemeColorsFromJson(json);

  const CustomThemeColors._();

  /// 将十六进制颜色字符串转换为 Color 对象
  Color? getSeedColor() {
    if (primaryColorSeed == null) return null;
    try {
      final hex = primaryColorSeed!.replaceFirst('#', '0xff');
      return Color(int.parse(hex));
    } catch (e) {
      return null; // 验证失败返回 null
    }
  }

  /// 验证颜色十六进制格式
  bool isValidColorHex() =>
      primaryColorSeed == null ||
      RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(primaryColorSeed!);

  /// 验证边框圆角范围
  bool isValidBorderRadius() =>
      borderRadius >= 12.0 && borderRadius <= 32.0;

  /// 验证紧凑度范围
  bool isValidCompactness() =>
      interfaceCompactness >= 0.5 && interfaceCompactness <= 1.5;

  /// 验证整体有效性
  bool isValid() =>
      isValidColorHex() &&
      isValidBorderRadius() &&
      isValidCompactness();
}
```

**关键特点**:
- 使用 `@freezed` 自动生成不可变类和 copyWith()
- 自动生成 `==` 和 `hashCode`
- 自动生成 JSON 序列化
- 独立的验证方法，易于测试

### 2. 存储集成

**文件**: `lib/core/storage/library_preferences_repository.dart`

```dart
class SecureLibraryPreferencesRepository implements LibraryPreferencesRepository {
  static const String _preferencesKey = 'library_preferences';

  @override
  Future<LibraryPreferences> load() async {
    try {
      final json = await _storage.read(key: _preferencesKey);
      if (json == null) {
        return const LibraryPreferences(); // 默认值
      }
      final decoded = jsonDecode(json);
      return LibraryPreferences.fromJson(decoded);
    } catch (e) {
      return const LibraryPreferences(); // 加载失败降级
    }
  }

  @override
  Future<void> save(LibraryPreferences preferences) async {
    try {
      final json = jsonEncode(preferences.toJson());
      await _storage.write(
        key: _preferencesKey,
        value: json,
      );
    } catch (e) {
      // 日志记录错误，但不抛出异常
      debugPrint('Failed to save preferences: $e');
    }
  }
}
```

**LibraryPreferences 中的变更**:

```dart
@freezed
class LibraryPreferences with _$LibraryPreferences {
  const factory LibraryPreferences({
    // ... 其他字段 ...
    @Default(CustomThemeColors()) CustomThemeColors customThemeColors,
  }) = _LibraryPreferences;

  factory LibraryPreferences.fromJson(Map<String, dynamic> json) {
    // 从 JSON 加载时，customThemeColors 可能为 null，使用默认值
    final themJson = json['customThemeColors'] as Map<String, dynamic>?;
    return _$LibraryPreferencesFromJson({
      ...json,
      'customThemeColors': themJson ?? {},
    });
  }
}
```

**关键特点**:
- 自动序列化/反序列化
- 向后兼容（缺失的字段使用默认值）
- 错误处理（加载失败返回默认值）

### 3. 设置 UI 实现

**文件**: `lib/features/settings/presentation/settings_page.dart`

#### 颜色选择对话框

```dart
Future<void> _showColorPickerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String currentColor,
  required void Function(String colorHex) onSelected,
}) {
  var selectedColor = currentColor;
  final colors = [
    '#FF5722', '#FF9800', '#FFC107', '#8BC34A',
    '#4CAF50', '#00BCD4', '#2196F3', '#3F51B5',
  ];

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('选择主题颜色'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('预设颜色：'),
                  const SizedBox(height: 12),
                  
                  // 颜色预设网格
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: colors.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          setState(() => selectedColor = color);
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(color.replaceFirst('#', '0xff'))
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 十六进制输入框
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Hex 颜色值（如 #FF5722）',
                      hintText: currentColor,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      // 实时验证十六进制格式
                      if (value.isNotEmpty &&
                          RegExp(r'^#?[0-9A-Fa-f]{6}$').hasMatch(value)) {
                        setState(() {
                          selectedColor = value.startsWith('#') ? value : '#$value';
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  onSelected(selectedColor);
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('确认'),
              ),
            ],
          );
        },
      );
    },
  );
}
```

#### 边框圆角滑块

```dart
Future<void> _showBorderRadiusSlider({
  required BuildContext context,
  required double initialValue,
  required void Function(double value) onSaved,
}) {
  var value = initialValue;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('边框圆角'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前值显示
                  Text(
                    '${value.toStringAsFixed(1)}px',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  
                  // 滑块（12-32，20 级分割 = 每 1px）
                  Slider(
                    min: 12,
                    max: 32,
                    divisions: 20,
                    value: value,
                    label: '${value.toStringAsFixed(1)}px',
                    onChanged: (nextValue) {
                      setState(() => value = nextValue);
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 范围提示
                  Text(
                    '范围：12.0 - 32.0px',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  onSaved(value);
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('确认'),
              ),
            ],
          );
        },
      );
    },
  );
}
```

### 4. 控制器方法

**文件**: `lib/features/settings/application/app_settings_controller.dart`

```dart
class AppSettingsController extends AsyncNotifier<LibraryPreferences> {
  @override
  Future<LibraryPreferences> build() {
    return ref.read(libraryPreferencesRepositoryProvider).load();
  }

  // 其他 set* 方法 ...

  /// 设置自定义主题颜色
  /// 包括：颜色种子、边框圆角、界面紧凑度
  Future<void> setCustomThemeColors(CustomThemeColors value) async {
    await _save((preferences) => preferences.copyWith(customThemeColors: value));
  }

  Future<void> _save(
    LibraryPreferences Function(LibraryPreferences preferences) transform,
  ) async {
    final repository = ref.read(libraryPreferencesRepositoryProvider);
    final current = state.valueOrNull ?? await repository.load();
    final next = transform(current);
    
    // 立即更新 UI（乐观更新）
    state = AsyncData(next);
    
    // 异步保存到存储
    await repository.save(next);
  }
}

final appSettingsControllerProvider = AsyncNotifierProvider<
  AppSettingsController,
  LibraryPreferences,
>(
  AppSettingsController.new,
);
```

**关键特点**:
- 遵循现有的 `_save()` 模式
- 乐观更新：立即更新 state，然后异步保存
- 自动触发 Riverpod 依赖重建

### 5. 主题应用

**文件**: `lib/app/app.dart`

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final router = ref.watch(appRouterProvider);
  final preferences = ref.watch(appSettingsControllerProvider).valueOrNull ??
      const LibraryPreferences();

  // 获取自定义主题颜色或使用默认
  final customColors = preferences.customThemeColors;
  
  // 关键！使用自定义的种子颜色生成配色方案
  final seedColor = customColors.getSeedColor() ?? Colors.blue;

  // Material Design 3 自动生成配色方案
  final lightScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.light,
  );
  final darkScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );

  return MaterialApp.router(
    // ... 其他配置 ...
    theme: _buildTheme(lightScheme, Brightness.light, 
                       preferences.interfaceScaleFactor, customColors),
    darkTheme: _buildTheme(darkScheme, Brightness.dark, 
                           preferences.interfaceScaleFactor, customColors),
    // ...
  );
}

ThemeData _buildTheme(
  ColorScheme colorScheme,
  Brightness brightness,
  double interfaceScaleFactor,
  CustomThemeColors customColors,  // ← 新增参数
) {
  final br = customColors.borderRadius;  // ← 提取边框圆角

  // ... 其他主题配置 ...

  return baseTheme.copyWith(
    // ... 文本主题 ...
    
    cardTheme: CardThemeData(
      // ... 其他属性 ...
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(br),  // ← 使用动态值
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      // ... 其他属性 ...
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(br - 8),  // ← 按比例缩放
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      // ... 其他边框 ...
    ),
    
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // ... 其他属性 ...
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(br - 6),  // ← 按比例缩放
        ),
      ),
    ),
    
    // ... 其他主题属性 ...
  );
}
```

---

## 🧪 集成测试

### 手动测试场景

#### 场景 1: 完整的主题定制流程

1. **打开应用**
   - 应用启动，加载保存的主题（或默认主题）

2. **打开设置**
   - 导航到 Settings 页面
   - 向下滚动到"外观设置"部分

3. **选择颜色**
   - 点击"主题颜色"磁贴
   - 对话框打开，显示 8 种预设颜色
   - 选择一种预设颜色，观察预览
   - 或在十六进制输入框中输入 `#FF5722`
   - 点击"确认"
   - **验证**: 整个应用的配色立即改变

4. **调整圆角**
   - 点击"边框圆角"磁贴
   - 对话框打开，显示滑块
   - 拖动滑块到 24px
   - **验证**: 所有卡片、按钮的圆角变大

5. **调整紧凑度**
   - 点击"界面紧凑度"磁贴
   - 对话框打开，显示滑块
   - 拖动滑块到 75%
   - **验证**: 字体、间距相应缩小（Stage 5）

6. **关闭应用**
   - 按系统返回键或 Home 键关闭应用

7. **重新打开应用**
   - **验证**: 自定义主题已保存，应用启动时自动应用

#### 场景 2: 颜色验证

- 选择 `#FF5722` (深橙)
  - **预期**: 亮色模式显示橙色主题，暗色模式显示相应的暗橙色
- 选择 `#2196F3` (蓝色)
  - **预期**: Material Design 3 蓝色配色方案生效
- 选择无效的十六进制值 (如 `#GGGGGG`)
  - **预期**: 输入框不接受，颜色不变

#### 场景 3: 边框圆角极端值

- 设置最小值: 12px
  - **预期**: 所有圆角变锐利，但仍可正常操作

- 设置最大值: 32px
  - **预期**: 所有圆角变非常圆润，UI 仍整洁

- 设置中间值: 20px
  - **预期**: 柔和的圆角，Material Design 3 风格

### 自动化测试清单

#### 单元测试

```dart
test('CustomThemeColors validates color hex', () {
  final valid = CustomThemeColors(primaryColorSeed: '#FF5722');
  expect(valid.isValidColorHex(), true);

  final invalid = CustomThemeColors(primaryColorSeed: '#GGGGGG');
  expect(invalid.isValidColorHex(), false);
});

test('CustomThemeColors converts hex to Color', () {
  final colors = CustomThemeColors(primaryColorSeed: '#FF5722');
  final color = colors.getSeedColor();
  expect(color, isNotNull);
  expect(color?.value, equals(Color(0xFFFF5722).value));
});

test('CustomThemeColors validates border radius range', () {
  final valid = CustomThemeColors(borderRadius: 20.0);
  expect(valid.isValidBorderRadius(), true);

  final tooSmall = CustomThemeColors(borderRadius: 10.0);
  expect(tooSmall.isValidBorderRadius(), false);

  final tooBig = CustomThemeColors(borderRadius: 40.0);
  expect(tooBig.isValidBorderRadius(), false);
});

test('CustomThemeColors serialization roundtrip', () {
  final original = CustomThemeColors(
    primaryColorSeed: '#FF5722',
    borderRadius: 24.0,
    interfaceCompactness: 1.2,
  );

  final json = original.toJson();
  final restored = CustomThemeColors.fromJson(json);

  expect(restored, equals(original));
});
```

#### 集成测试

```dart
testWidgets('Theme color changes apply to entire app', (tester) async {
  await tester.pumpWidget(const MusicApp());
  
  // 获取初始的 ColorScheme
  final initialScheme = Theme.of(tester.context).colorScheme;
  
  // 打开设置并更改颜色
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pumpAndSettle();
  
  // ... 执行颜色选择 ...
  
  // 返回应用
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  
  // 验证配色已改变
  final newScheme = Theme.of(tester.context).colorScheme;
  expect(newScheme, isNot(initialScheme));
});
```

---

## ❓ 常见问题

### Q1: 为什么使用 ColorScheme.fromSeed() ?

**A**: Material Design 3 引入的标准方法，自动生成完整的配色方案：
- primary, onPrimary
- secondary, onSecondary
- tertiary, onTertiary
- surface, onSurface
- error, onError
- ... 共 26 种颜色

这比手动定义每个颜色更一致、更专业。

### Q2: 为什么边框圆角有三种不同的值?

**A**: 视觉层级和可用性：
- **br** (28px): 最大的元素（卡片），需要最圆的角
- **br - 4**: 中等元素（对话框）
- **br - 6**: 交互元素（按钮）
- **br - 8**: 小元素（输入框、列表项）

这样可以创建自然的视觉层级。

### Q3: 为什么保存是异步的，但 UI 立即更新?

**A**: 这是"乐观更新"模式：
1. **立即**: `state = AsyncData(next)` → UI 立即反应，用户体验最佳
2. **后台**: `await repository.save()` → 异步保存到存储，不阻塞 UI

如果保存失败，可以通过错误处理回滚。

### Q4: 如果用户输入无效的十六进制色会怎样?

**A**:
1. `_showColorPickerDialog()` 中的正则表达式阻止提交无效值
2. `CustomThemeColors.getSeedColor()` 返回 null 时，使用默认的 `Colors.blue`
3. 应用不会崩溃，继续使用上一个有效的颜色

### Q5: Stage 5 中 interfaceCompactness 怎样影响字体?

**A** (预计 Stage 5):
```dart
// 在 _buildTheme 中
final compactness = customColors.interfaceCompactness;

bodyMedium: titleTheme.bodyMedium?.copyWith(
  fontSize: (titleTheme.bodyMedium?.fontSize ?? 14) * compactness,
),
```

- 0.5 → 所有字体缩小 50% (50% = 7pt 而不是 14pt)
- 1.0 → 保持默认
- 1.5 → 所有字体放大 50% (21pt 而不是 14pt)

---

## 🚀 下一步

- **即刻**: 验证 Stage 4 在所有平台上正常工作
- **Stage 5**: 使用 `interfaceCompactness` 实现字体和间距动态缩放
- **后续**: 性能优化、跨平台测试

---

*深度解析版本: 1.0*
*涵盖代码: Stage 4 所有文件*
*更新日期: 2025年*
