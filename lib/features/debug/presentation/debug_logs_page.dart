import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/debug_log_store.dart';
import '../../../core/widgets/studio_chrome.dart';
import '../../../core/widgets/top_snackbar.dart';

/// 调试日志页面
class DebugLogsPage extends StatefulWidget {
  const DebugLogsPage({super.key});

  @override
  State<DebugLogsPage> createState() => _DebugLogsPageState();
}

class _DebugLogsPageState extends State<DebugLogsPage> {
  late ScrollController _scrollController;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    DebugLogStore().addListener(_onLogsUpdated);
  }

  @override
  void dispose() {
    DebugLogStore().removeListener(_onLogsUpdated);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogsUpdated() {
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
    setState(() {});
  }

  Color _getLogColor(String level) {
    return switch (level) {
      'success' => Colors.green,
      'warning' => Colors.orange,
      'error' => Colors.red,
      'network' => Colors.blue,
      'database' => Colors.purple,
      'scraping' => Colors.cyan,
      'performance' => Colors.amber,
      _ => Colors.grey,
    };
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showTopSnackBar(context, '✓ 已复制到剪贴板');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = DebugLogStore().logs;
    final fullText = DebugLogStore().exportAsText();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0),
      appBar: AppBar(
        title: Text('📋 调试日志 (${logs.length} 条)'),
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        foregroundColor: theme.colorScheme.onSurface,
        surfaceTintColor: theme.colorScheme.surfaceContainerLowest,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: '复制全部日志',
            onPressed: () => _copyToClipboard(fullText),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: () {
              DebugLogStore().clearLogs();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: '设置',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: StudioBackdrop(
        maxContentWidth: 1480,
        padding: const EdgeInsets.all(12),
        child: logs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无日志',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 控制面板
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _autoScroll,
                            onChanged: (value) {
                              setState(() {
                                _autoScroll = value ?? true;
                              });
                            },
                          ),
                          const Text('自动滚动'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _copyToClipboard(fullText),
                            icon: const Icon(Icons.copy),
                            label: const Text('复制'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    // 日志列表
                    ...logs.map((log) {
                      final color = _getLogColor(log.level);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: GestureDetector(
                          onLongPress: () =>
                              _copyToClipboard(log.formattedMessage),
                          child: SelectableText(
                            log.formattedMessage,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
      ),
    );
  }
}
