# 缓存和实时更新问题诊断 — v1.0.113+114

**2026-04-16**

## 添加的改进

本版本添加了详细的 DebugLogger 日志，用于诊断两个关键问题：

### ✅ 改进 1: `build()` 中的详细日志
- 记录缓存加载的每个阶段
- 显示从多少个源加载了多少首歌曲
- 显示应用了多少个刮削缓存

### ✅ 改进 2: `_applyCachedScrapingMetadata()` 中的日志
- 显示总共应用了多少个刮削缓存

---

## App 启动流程（现在带日志）

```
App 启动
  ├─ [IsarManager] 初始化中...
  ├─ [IsarManager] SharedPreferences 初始化成功
  │
  ├─ [Lib raryCatalogController.build] 开始加载库
  ├─ [LibraryCatalogController.build] 加载缓存结果: X 个源
  │  ├─ [LibraryCatalogController.build] 源 source_name: X 首歌曲
  │  ├─ [LibraryCatalogController.build] 源 source_name2: Y 首歌曲
  │  ...
  │
  ├─ [LibraryCatalogController.build] 总共 Z 首歌曲，应用刮削数据中...
  ├─ [LibraryCatalogController._applyCachedScrapingMetadata] 已应用 N 个刮削缓存
  │
  └─ [LibraryCatalogController.build] 库加载完成：Z 首歌曲
     
UI 显示库列表 ✓
```

---

## 诊断检查清单

### 检查 1: App 启动是否加载缓存
查看日志是否包含：
```
[LibraryCatalogController.build] 库加载完成：X 首歌曲
```

**如果看不到**，可能是：
- 缓存从未被保存（第一次使用）
- 缓存被清除了
- 缓存保存失败

**解决**: 手动扫描音乐库

### 检查 2: 刮削数据是否被应用
查看日志是否包含：
```
[LibraryCatalogController._applyCachedScrapingMetadata] 已应用 N 个刮削缓存
```

**如果 N = 0**，说明：
- IsarManager 中没有保存任何刮削数据
- 或者歌曲ID不匹配

### 检查 3: 播放时是否保存刮削数据
播放一首歌后查看日志：
```
[PlayerController._scrapeCurrentSongAsync] 刮削完成并已保存到数据库
[IsarManager] 保存元数据: id=songId
[IsarManager] 元数据保存成功
```

### 检查 4: 刮削后是否更新UI
查看日志：
```
[LibraryCatalogController.refreshSongMetadata] 已刷新单个歌曲的元数据显示: songId
```

**如果看不到**，UI 不会实时更新。

---

## 常见问题排查

### 问题: App 重启后列表为空
**排查**:
1. 查看"检查 1"的日志
2. 如果看到"缓存中没有扫描结果" → 先扫描再重启
3. 如果看到"库加载完成：0 首歌曲" → 检查扫描配置是否正确

### 问题: 刮削后名称没有更新
**排查**:
1. 查看"检查 4"的日志
2. 如果看到"已刷新"但 UI 没更新 → Riverpod 状态问题
3. 如果看不到"已刷新" → refreshSongMetadata() 没被调用

---

## 构建信息

✅ Dart 分析: 0 errors  
✅ 代码生成: 10 outputs  
✅ APK 构建: 64.8 MB ✓  

---

## 下一个版本的计划改进

如果本版本的日志显示数据确实被正确保存和加载，但 UI 仍未更新，则：
1. 可能需要修改 Riverpod 的状态管理方式
2. 可能需要使用 `ref.refresh()` 而不是直接修改 `state`
3. 可能需要在 listener 中手动触发 UI 更新

