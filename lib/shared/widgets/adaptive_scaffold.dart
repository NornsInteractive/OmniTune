import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';

/// 自适应脚手架：小屏用底部导航栏，大屏用左侧 NavigationRail
class AdaptiveScaffold extends StatelessWidget {
  /// 主体内容
  final Widget body;

  /// 导航目标列表
  final List<NavigationDestination> destinations;

  /// 当前选中的导航索引
  final int currentIndex;

  /// 导航变化回调
  final ValueChanged<int> onNavigationChanged;

  /// 是否显示 AppBar
  final PreferredSizeWidget? appBar;

  /// FloatingActionButton（仅小屏显示）
  final FloatingActionButton? floatingActionButton;

  /// 抽屉（如果需要）
  final Widget? drawer;

  const AdaptiveScaffold({
    super.key,
    required this.body,
    required this.destinations,
    required this.currentIndex,
    required this.onNavigationChanged,
    this.appBar,
    this.floatingActionButton,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < AppTokens.breakpointSmallScreen;

    // ── 小屏：底部导航栏 ────────────────────────────────────
    if (isSmallScreen) {
      return Scaffold(
        appBar: appBar,
        drawer: drawer,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: AppTokens.dividerThickness, thickness: AppTokens.dividerThickness),
            NavigationBar(
              destinations: destinations,
              selectedIndex: currentIndex,
              onDestinationSelected: onNavigationChanged,
            ),
          ],
        ),
      );
    }

    // ── 大屏：左侧 NavigationRail + 右侧内容 ──────────────
    return Scaffold(
      appBar: appBar,
      body: Row(
        children: [
          // 侧栏导航
          NavigationRail(
            destinations: destinations
                .map((dest) => NavigationRailDestination(icon: dest.icon, label: Text(dest.label)))
                .toList(),
            selectedIndex: currentIndex,
            onDestinationSelected: onNavigationChanged,
          ),
          // 竖分割线
          VerticalDivider(width: AppTokens.dividerThickness, thickness: AppTokens.dividerThickness),
          // 主体内容
          Expanded(child: body),
        ],
      ),
    );
  }
}
