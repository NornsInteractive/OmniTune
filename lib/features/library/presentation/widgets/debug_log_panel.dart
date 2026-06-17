import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:music/core/i18n/localizations.dart';

import '../../../../core/utils/debug_log_store.dart';
import '../../../../core/widgets/top_snackbar.dart';

/// 日志显示面板
class DebugLogPanel extends StatefulWidget {
  const DebugLogPanel({
    super.key,
    this.maxHeight = 300,
    this.showClearButton = true,
  });

  final double maxHeight;
  final bool showClearButton;

  @override
  State<DebugLogPanel> createState() => _DebugLogPanelState();
}

class _DebugLogPanelState extends State<DebugLogPanel> {
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
      // 使用 Future.delayed 确保 ListView 完成布局后再滚动
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final logs = DebugLogStore().logs;

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '📋 ${l10n.debugLogsTitle} (${logs.length})',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                if (widget.showClearButton)
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    iconSize: 18,
                    tooltip: l10n.clearAction,
                    onPressed: () {
                      DebugLogStore().clearLogs();
                      setState(() {});
                    },
                  ),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _autoScroll,
                    onChanged: (value) {
                      setState(() {
                        _autoScroll = value ?? true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(l10n.autoScrollLabel, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          // 日志列表
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      l10n.noLogsAvailable,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final color = _getLogColor(log.level);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          log.formattedMessage,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: color,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 日志弹窗
class DebugLogDialog extends StatefulWidget {
  const DebugLogDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const DebugLogDialog(),
    );
  }

  @override
  State<DebugLogDialog> createState() => _DebugLogDialogState();
}

class _DebugLogDialogState extends State<DebugLogDialog> {
  late ScrollController _scrollController;
  final bool _autoScroll = true;

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
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final logs = DebugLogStore().logs;

    return AlertDialog(
      title: Text('📋 ${l10n.debugLogsTitle} (${logs.length})'),
      content: SizedBox(
        width: double.maxFinite,
        child: logs.isEmpty
            ? Center(
                child: Text(
                  l10n.noLogsAvailable,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final color = _getLogColor(log.level);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      log.formattedMessage,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            DebugLogStore().clearLogs();
            setState(() {});
          },
          child: Text(l10n.clearAction),
        ),
        TextButton(
          onPressed: () {
            // 导出日志到剪贴板
            final text = DebugLogStore().exportAsText();
            Clipboard.setData(ClipboardData(text: text));
            showTopSnackBar(
              context,
              '${l10n.logsExportedToClipboard} (${text.length} chars)',
            );
          },
          child: Text(l10n.copyLogsAction),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.closeAction),
        ),
      ],
    );
  }
}
