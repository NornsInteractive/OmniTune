# 🔍 调试系统 - 快速参考卡

**快速启用**: 设置 ⚙️ → 开发者 → 调试模式 ✅

---

## ⚡ 30 秒快速检查

```bash
# 1. 启用调试模式（产品端）
# 打开应用 → 设置 ⚙️ → 找到"开发者" → 打开"调试模式"

# 2. 查看日志
flutter run -v 2>&1 | grep "🎵\|✅\|❌"

# 3. 执行搜索
# 在应用中尝试刮削 → 观察日志输出
```

---

## 🎯 日志符号含义

| 符号 | 含义 | 例子 |
|------|------|------|
| 🎵 | 刮削操作 | 搜索开始、完成 |
| ✅ | 操作成功 | 搜索成功、保存成功 |
| ❌ | 操作失败 | 超时、错误 |
| ⚠️  | 需要注意 | 无结果、缓存过期 |
| 🌐 | 网络请求 | API 调用 |
| 💾 | 数据库 | 保存、读取 |
| 🔍 | 调试启动 | 模式启用 |

---

## 🔴 问题快速诊断

### 没有搜索结果?
```
查找日志: ⚠️ 搜索未返回结果
原因: 歌曲不在 MusicBrainz
→ 在官网验证: https://musicbrainz.org/search
```

### 网络超时?
```
查找日志: ❌ connectionTimeout
原因: 网络连接问题
→ 检查网络、稍后重试
```

### 数据库失败?
```
查找日志: ❌ 保存元数据失败
原因: 存储空间问题
→ 清空数据: await IsarManager.clearAll();
```

### 没有 ✅ 结果?
```
查找日志: 没有 UPSERT 成功
原因: 应用结果没被调用
→ 确保点击了"确定"按钮
```

---

## 📊 完整流程示例

```
🎵 开始搜索
  ↓
🌐 发送网络请求
  ↓
✅ 搜索成功 (X 个结果)
  ↓
ℹ️  选择结果
  ↓
💾 保存到数据库
  ↓
✅ 完成
  ↓
🎵 歌曲元数据已更新
```

---

## 🛠️ 有用的命令

```bash
# 仅看错误
flutter run -v 2>&1 | grep "❌"

# 仅看刮削操作
flutter run -v 2>&1 | grep "🎵"

# 保存日志到文件
flutter run -v > debug.log 2>&1

# 统计每种消息数量
echo "错误数: $(grep '❌' debug.log | wc -l)"
echo "成功数: $(grep '✅' debug.log | wc -l)"
```

---

## 📚 完整文档

| 文档 | 用途 |
|------|------|
| [SCRAPER_DEBUG_QUICK_START.md](docs/SCRAPER_DEBUG_QUICK_START.md) | 快速开始 ⭐ 推荐首先 |
| [SCRAPER_DEBUG_GUIDE.md](docs/SCRAPER_DEBUG_GUIDE.md) | 详细参考 |
| [DEBUG_SYSTEM_IMPLEMENTATION.md](docs/DEBUG_SYSTEM_IMPLEMENTATION.md) | 实现细节 |
| [DEBUG_SYSTEM_COMPLETE_SUMMARY.md](DEBUG_SYSTEM_COMPLETE_SUMMARY.md) | 总体概览 |

---

## ✅ 验证清单

- [ ] 启用调试模式 (设置 → 开发者)
- [ ] 看到 SnackBar: 🔍 调试模式已启用
- [ ] flutter run 时看到日志符号
- [ ] 编译通过 (dart analyze = 0 errors)
- [ ] 能解释至少 3 个日志符号

---

**编译状态**: ✅ 0 errors  
**系统状态**: ✅ 完全就绪  
**建议**: 立即启用并进行诊断  

---

