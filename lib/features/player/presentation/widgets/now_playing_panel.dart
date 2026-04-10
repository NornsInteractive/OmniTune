import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:music/l10n/app_localizations.dart';

import '../../../../core/models/app_preferences.dart';
import '../../application/player_controller.dart';
import 'generated_cover_art.dart';
import 'playback_timeline.dart';

class NowPlayingPanel extends ConsumerStatefulWidget {
  const NowPlayingPanel({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<NowPlayingPanel> createState() => _NowPlayingPanelState();
}

class _NowPlayingPanelState extends ConsumerState<NowPlayingPanel> {
  double? _dragValue;
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    if (!playerState.hasTrack) {
      return _buildEmptyState(context, l10n, theme, colorScheme);
    }

    return _buildPlayerContent(context, playerState, controller, l10n, theme, colorScheme);
  }

  /// 构建空状态的优雅卡片
  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDisplayPreferences.getResponsiveBorderRadius(28, 1.0)),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppDisplayPreferences.createSpacingTheme(1.0).lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppDisplayPreferences.getResponsiveBorderRadius(20, 1.0)),
              ),
              child: Icon(Icons.queue_music_rounded, size: 40, color: colorScheme.onPrimaryContainer),
            ),
            SizedBox(height: AppDisplayPreferences.createSpacingTheme(1.0).md),
            Text(
              l10n.playerEmptyTitle,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppDisplayPreferences.createSpacingTheme(1.0).xs),
            Text(
              l10n.playerEmptyDescription,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建播放器主内容
  Widget _buildPlayerContent(
    BuildContext context,
    dynamic playerState,
    dynamic controller,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final currentTrack = playerState.currentTrack!;
    final duration = playerState.duration;
    final maxPosition = duration != null && duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : double.infinity;
    final positionValue =
        _dragValue ??
        playerState.position.inMilliseconds.toDouble().clamp(
          0.0,
          duration != null && duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : double.infinity,
        );

    final subtitle = [
      currentTrack.artistName,
      currentTrack.albumTitle,
      currentTrack.sourceName,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');

    final spacingTheme = AppDisplayPreferences.createSpacingTheme(1.0);
    final borderRadius = AppDisplayPreferences.getResponsiveBorderRadius(24, 1.0);

    // 获取屏幕尺寸用于响应式卡片
    final screenWidth = MediaQuery.of(context).size.width;
    // 响应式布局已通过 SpacingTheme 和 BorderRadius 以及屏幕宽度实现
    final compactness = 1.0;

    // 响应式封面卡片尺寸（基于屏幕宽度和密度，最大 320，最小 200）
    final coverCardSize = (screenWidth * 0.65 * compactness).clamp(200.0, 320.0);

    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ===== 头部：标题区域（固定高度，不被压缩）=====
            LimitedBox(
              maxHeight: 100,
              child: SingleChildScrollView(
                child: _buildHeaderSection(currentTrack, subtitle, theme, colorScheme, spacingTheme, compactness),
              ),
            ),

            // ===== 主体：封面卡片（自动填充剩余空间）=====
            Expanded(
              child: _buildCoverCard(
                currentTrack,
                subtitle,
                colorScheme,
                spacingTheme,
                borderRadius,
                l10n,
                playerState,
                coverCardSize,
              ),
            ),

            // ===== 底部：进度条 + 控制（固定高度，不被压缩）=====
            _buildControlSection(
              playerState,
              controller,
              duration,
              maxPosition,
              positionValue,
              l10n,
              theme,
              colorScheme,
              spacingTheme,
              compactness,
            ),
          ],
        ),
      ),
    );
  }

  /// 头部标题区域
  Widget _buildHeaderSection(
    dynamic track,
    String subtitle,
    ThemeData theme,
    ColorScheme colorScheme,
    dynamic spacing,
    double compactness,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            track.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: colorScheme.onSurface),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (subtitle.isNotEmpty) ...[
            SizedBox(height: spacing.xs),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                // 字体大小随 compactness 缩放
                fontSize: 13 * compactness,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// 中间封面卡片
  Widget _buildCoverCard(
    dynamic track,
    String subtitle,
    ColorScheme colorScheme,
    dynamic spacing,
    double borderRadius,
    AppLocalizations l10n,
    dynamic playerState,
    double coverCardSize,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _showLyrics = !_showLyrics),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.sm),
          child: Container(
            width: coverCardSize,
            height: coverCardSize,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 封面图
                ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: GeneratedCoverArt(
                    title: track.title,
                    subtitle: subtitle,
                    size: coverCardSize,
                    borderRadius: borderRadius,
                  ),
                ),

                // 歌词覆盖层
                if (_showLyrics)
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(spacing.md),
                      child: _CompactLyricsPanel(
                        lyrics: playerState.lyrics,
                        activeIndex: playerState.activeLyricIndex,
                        emptyLabel: l10n.lyricsEmptyLabel,
                      ),
                    ),
                  ),

                // 关闭歌词按钮
                if (_showLyrics)
                  Positioned(
                    top: spacing.sm,
                    right: spacing.sm,
                    child: GestureDetector(
                      onTap: () => setState(() => _showLyrics = false),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppDisplayPreferences.getResponsiveBorderRadius(12, 1.0)),
                        ),
                        child: Icon(Icons.close_rounded, color: colorScheme.onPrimary, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 底部控制区（进度条 + 按钮）
  Widget _buildControlSection(
    dynamic playerState,
    dynamic controller,
    Duration? duration,
    double maxPosition,
    double positionValue,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    dynamic spacing,
    double compactness,
  ) {
    final isEnabled = duration != null && duration.inMilliseconds > 0;

    // 响应式按钮尺寸（基于 compactness）
    final smallButtonSize = (48.0 * compactness).clamp(40.0, 56.0);
    final largeButtonSize = (64.0 * compactness).clamp(52.0, 72.0);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant, width: 0.5)),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            SeekablePlaybackTimeline(
              value: positionValue,
              max: maxPosition,
              cacheSegments: playerState.cacheSegments,
              enabled: isEnabled,
              onChanged: (value) => setState(() => _dragValue = value),
              onChangeEnd: (value) async {
                setState(() => _dragValue = null);
                await controller.seek(Duration(milliseconds: value.round()));
              },
            ),

            SizedBox(height: spacing.sm),

            // 时间显示
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(playerState.position),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: (11 * compactness).clamp(9.0, 13.0),
                    ),
                  ),
                  Text(
                    _formatDuration(duration ?? Duration.zero),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: (11 * compactness).clamp(9.0, 13.0),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: spacing.md),

            // 播放按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 停止按钮
                _buildControlButton(
                  icon: Icons.stop_rounded,
                  onPressed: controller.stop,
                  tooltip: l10n.stopAction,
                  colorScheme: colorScheme,
                  isFilled: false,
                  size: smallButtonSize,
                ),

                SizedBox(width: spacing.lg),

                // 播放/暂停按钮（主按钮）
                _buildControlButton(
                  icon: playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onPressed: controller.togglePlayPause,
                  tooltip: playerState.isPlaying ? l10n.pauseAction : l10n.playAction,
                  colorScheme: colorScheme,
                  isFilled: true,
                  isLarge: true,
                  size: largeButtonSize,
                ),

                SizedBox(width: spacing.lg),

                // 下一首按钮
                _buildControlButton(
                  icon: Icons.skip_next_rounded,
                  onPressed: controller.next,
                  tooltip: 'Next',
                  colorScheme: colorScheme,
                  isFilled: false,
                  size: smallButtonSize,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 控制按钮构建器
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required ColorScheme colorScheme,
    bool isFilled = false,
    bool isLarge = false,
    double size = 48.0,
  }) {
    final borderRadius = AppDisplayPreferences.getResponsiveBorderRadius(16, 1.0);

    // 响应式图标大小（按钮尺寸的 40% 左右）
    final iconSize = size * (isLarge ? 0.44 : 0.5);

    if (isLarge) {
      return GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: colorScheme.primary, width: 0.5),
          ),
          child: Icon(icon, color: colorScheme.onPrimary, size: iconSize),
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isFilled ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isFilled ? colorScheme.primaryContainer : colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
          child: Icon(
            icon,
            color: isFilled ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final hours = totalSeconds ~/ 3600;

    if (hours > 0) {
      final remainingMinutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      return '${hours.toString().padLeft(2, '0')}:$remainingMinutes:$seconds';
    }

    return '$minutes:$seconds';
  }
}

class _CompactLyricsPanel extends StatelessWidget {
  const _CompactLyricsPanel({required this.lyrics, required this.activeIndex, required this.emptyLabel});

  final List<LyricLine> lyrics;
  final int activeIndex;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return lyrics.isEmpty
        ? Center(
            child: Text(
              emptyLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          )
        : ListView.separated(
            itemCount: lyrics.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final line = lyrics[index];
              final isActive = index == activeIndex;
              return AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style:
                    (isActive ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall)?.copyWith(
                      color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ) ??
                    const TextStyle(),
                child: Text(line.text, maxLines: 3, overflow: TextOverflow.ellipsis),
              );
            },
          );
  }
}

// 暂时移除 _LyricsPanel，因为当前 UI 不需要完整版歌词面板
// 如果后续需要用到，可以取消下面的注释
/*
class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.lyrics, required this.activeIndex, required this.emptyLabel});

  final List<LyricLine> lyrics;
  final int activeIndex;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: lyrics.isEmpty
          ? Center(
              child: Text(
                emptyLabel,
                style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              itemCount: lyrics.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final line = lyrics[index];
                final isActive = index == activeIndex;
                return AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style:
                      (isActive ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)?.copyWith(
                        color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      ) ??
                      const TextStyle(),
                  child: Text(line.text),
                );
              },
            ),
    );
  }
}
*/
