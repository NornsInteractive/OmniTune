import 'package:flutter/material.dart';

import '../../application/player_controller.dart';

class PlaybackTimeline extends StatelessWidget {
  const PlaybackTimeline({
    super.key,
    required this.progress,
    required this.cacheSegments,
    this.height = 6,
    this.showThumb = false,
    this.thumbFraction = 0,
    this.backgroundColor,
    this.cacheColor,
    this.progressColor,
    this.thumbColor,
  });

  final double progress;
  final List<CacheProgressSegment> cacheSegments;
  final double height;
  final bool showThumb;
  final double thumbFraction;
  final Color? backgroundColor;
  final Color? cacheColor;
  final Color? progressColor;
  final Color? thumbColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalizedProgress = progress.clamp(0, 1).toDouble();
    final normalizedThumb = thumbFraction.clamp(0, 1).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final thumbDiameter = showThumb ? 18.0 : 0.0;
        final usableWidth = constraints.maxWidth - thumbDiameter;
        final thumbLeft = usableWidth <= 0
            ? 0.0
            : usableWidth * normalizedThumb;

        return SizedBox(
          height: showThumb ? 28 : height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                left: showThumb ? thumbDiameter / 2 : 0,
                right: showThumb ? thumbDiameter / 2 : 0,
                child: Center(
                  child: CustomPaint(
                    size: Size(double.infinity, height),
                    painter: _PlaybackTimelinePainter(
                      progress: normalizedProgress,
                      cacheSegments: cacheSegments,
                      backgroundColor:
                          backgroundColor ??
                          colorScheme.outlineVariant.withValues(alpha: 0.42),
                      cacheColor:
                          cacheColor ??
                          colorScheme.onSurface.withValues(alpha: 0.18),
                      progressColor: progressColor ?? colorScheme.primary,
                    ),
                  ),
                ),
              ),
              if (showThumb)
                Positioned(
                  left: thumbLeft,
                  top: (28 - thumbDiameter) / 2,
                  child: Container(
                    width: thumbDiameter,
                    height: thumbDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: thumbColor ?? colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SeekablePlaybackTimeline extends StatefulWidget {
  const SeekablePlaybackTimeline({
    super.key,
    required this.value,
    required this.max,
    required this.cacheSegments,
    required this.onChanged,
    required this.onChangeEnd,
    this.enabled = true,
  });

  final double value;
  final double max;
  final List<CacheProgressSegment> cacheSegments;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final bool enabled;

  @override
  State<SeekablePlaybackTimeline> createState() =>
      _SeekablePlaybackTimelineState();
}

class _SeekablePlaybackTimelineState extends State<SeekablePlaybackTimeline> {
  double? _lastInteractionValue;

  @override
  Widget build(BuildContext context) {
    final normalizedMax = widget.max <= 0 ? 1.0 : widget.max;
    final progress = widget.value / normalizedMax;

    return LayoutBuilder(
      builder: (context, constraints) {
        double valueFromDx(double dx) {
          final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
          final fraction = (dx / width).clamp(0.0, 1.0);
          return fraction * normalizedMax;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.enabled
              ? (details) {
                  final value = valueFromDx(details.localPosition.dx);
                  _lastInteractionValue = value;
                  widget.onChanged(value);
                  widget.onChangeEnd(value);
                }
              : null,
          onHorizontalDragStart: widget.enabled
              ? (details) {
                  final value = valueFromDx(details.localPosition.dx);
                  _lastInteractionValue = value;
                  widget.onChanged(value);
                }
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (details) {
                  final value = valueFromDx(details.localPosition.dx);
                  _lastInteractionValue = value;
                  widget.onChanged(value);
                }
              : null,
          onHorizontalDragEnd: widget.enabled
              ? (_) {
                  final value = _lastInteractionValue;
                  if (value != null) {
                    widget.onChangeEnd(value);
                  }
                  _lastInteractionValue = null;
                }
              : null,
          child: PlaybackTimeline(
            progress: progress,
            cacheSegments: widget.cacheSegments,
            showThumb: true,
            thumbFraction: progress,
            height: 8,
          ),
        );
      },
    );
  }
}

class _PlaybackTimelinePainter extends CustomPainter {
  _PlaybackTimelinePainter({
    required this.progress,
    required this.cacheSegments,
    required this.backgroundColor,
    required this.cacheColor,
    required this.progressColor,
  });

  final double progress;
  final List<CacheProgressSegment> cacheSegments;
  final Color backgroundColor;
  final Color cacheColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );

    final backgroundPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(track, backgroundPaint);

    final cachePaint = Paint()..color = cacheColor;
    for (final segment in cacheSegments) {
      final start = size.width * segment.startFraction.clamp(0, 1);
      final end = size.width * segment.endFraction.clamp(0, 1);
      if (end <= start) {
        continue;
      }
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(start, 0, end - start, size.height),
        radius,
      );
      canvas.drawRRect(rect, cachePaint);
    }

    final playedWidth = size.width * progress.clamp(0, 1);
    if (playedWidth > 0) {
      final progressPaint = Paint()..color = progressColor;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, playedWidth, size.height),
        radius,
      );
      canvas.drawRRect(rect, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlaybackTimelinePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.cacheColor != cacheColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.cacheSegments.length != cacheSegments.length ||
        !_sameSegments(oldDelegate.cacheSegments, cacheSegments);
  }

  bool _sameSegments(
    List<CacheProgressSegment> left,
    List<CacheProgressSegment> right,
  ) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index].startFraction != right[index].startFraction ||
          left[index].endFraction != right[index].endFraction) {
        return false;
      }
    }

    return true;
  }
}
