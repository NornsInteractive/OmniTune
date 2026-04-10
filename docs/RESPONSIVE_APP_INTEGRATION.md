// 响应式自适应应用集成指南
// 
// 此文件展示如何在 Flutter 音乐播放器中集成 ResponsiveApp
// 
// 方案 1: 作为独立的 home 屏幕
// ============================================================================
// 在 app_router.dart 中修改路由配置：
//
// @Riverpod(keepAlive: true)
// GoRouter appRouter(Ref ref) {
//   return GoRouter(
//     initialLocation: '/',
//     routes: [
//       GoRoute(
//         path: '/',
//         builder: (context, state) => const ResponsiveApp(),
//       ),
//       // ... 其他路由
//     ],
//   );
// }
//
// 方案 2: 替代现有 AppShell
// ============================================================================
// ResponsiveApp 已包含完整的导航结构（底部栏/侧边栏/永久抽屉）
// 可以在 app_shell.dart 中使用，或直接作为顶级 widget
//
// 方案 3: 渐进式集成
// ============================================================================
// 第一步：在 lib/shared/widgets/settings_exports.dart 中导出 ResponsiveApp
// 第二步：在需要的地方导入和使用
// 第三步：根据需求灵活选择导航模式
//
// ============================================================================
// ResponsiveApp 特性总结
// ============================================================================
//
// 三种响应式模式：
// 1. Mobile (< 600px)
//    - BottomNavigationBar
//    - 单列紧凑布局
//    - 无迷你播放器（整合到导航）
//
// 2. Tablet (600-900px)
//    - NavigationRail（仅图标）
//    - 宽内容区域
//    - 底部迷你播放器
//
// 3. Desktop (> 900px)
//    - 永久展开 NavigationDrawer
//    - 图标 + 文字导航
//    - 右侧内容区 + 底部迷你播放器
//
// 导航项目（5 个）：
// - Home (首页)
// - Search (搜索)
// - Library (音乐库)
// - Player (正在播放)
// - Settings (设置)
//
// 卡片设计：
// - 背景：ColorScheme.surface
// - 边框：0.5px 使用 ColorScheme.outlineVariant
// - 圆角：12px-16px
// - 无阴影，无渐变
// - Material Design 3 完全兼容
//
// ============================================================================
// 本地化支持
// ============================================================================
// 已在 lib/l10n 中添加的字符串：
// - navigationHome: "Home" / "首页"
// - navigationSearch: "Search" / "搜索"
// - navigationLibrary: "Library" / "音乐库"
// - navigationPlayer: "Now Playing" / "正在播放"
// - navigationSettings: "Settings" / "设置"
//
// ============================================================================
// 快速集成步骤
// ============================================================================
//
// 1. 导入 ResponsiveApp
//    import 'package:music/shared/widgets/responsive_app.dart';
//
// 2. 在主应用中使用
//    MaterialApp(
//      home: const ResponsiveApp(),
//      // ... 其他配置
//    )
//
// 3. 或者在路由中使用
//    GoRoute(
//      path: '/',
//      builder: (context, state) => const ResponsiveApp(),
//    )
//
// 4. ResponsiveApp 会自动：
//    - 根据屏幕宽度选择导航方式
//    - 使用当前主题（AppTheme）
//    - 支持所有本地化语言
//    - 响应屏幕旋转和调整大小
//
// ============================================================================
// 扩展现有页面
// ============================================================================
// 
// 当前 ResponsiveApp 中的页面是占位符。
// 要集成真实的页面内容，修改 _buildContent() 方法：
//
// 示例：
// ```dart
// Widget _buildContent(int index) {
//   final screens = [
//     const HomeScreen(),           // lib/features/home/presentation/home_screen.dart
//     const SearchScreen(),         // lib/features/search/presentation/search_screen.dart  
//     const LibraryPage(),          // 现有的 LibraryPage
//     const NowPlayingPage(),       // 现有的 NowPlayingPage
//     const SettingsPage(),         // 现有的 SettingsPage
//   ];
//   return screens[index];
// }
// ```
//
// ============================================================================
// 注意事项
// ============================================================================
//
// ⚠️ 当前 ResponsiveApp 包含了完整的导航逻辑
// ⚠️ 它会处理路由导航到 /albums, /collection, /player, /settings
// ⚠️ 如果与现有的 AppShell + GoRouter 结合使用，需要调整路由逻辑
// ⚠️ 推荐方案：让 ResponsiveApp 作为独立的顶级 widget
//
// ============================================================================
// 编译和构建
// ============================================================================
//
// 确保本地化代码已生成：
// $ flutter gen-l10n
//
// 编译验证：
// $ flutter analyze
//
// 构建 APK：
// $ bash scripts/build_apk.sh
//
// ============================================================================
